import datetime
import json
import signal
import threading
import time
import uuid

import pika
import pytz
from pika.exchange_type import ExchangeType

import utils.env as env
from .errors import CODES
from .exceptions import (
    InvalidSpeed,
    InvalidTrim,
    InvalidVideo,
    UnsupportedEffect,
)

EXCHANGE = "picturas"
PROJECT_QUEUE = "project_queue"
WS_QUEUE = "ws_queue"


def now():
    return datetime.datetime.now(pytz.utc)


def _stage_percent(percent, stage_range, is_last_stage):
    if is_last_stage and percent == 100:
        return 100
    start, end = stage_range
    return int(start + (end - start) * percent / 100)


class VideoWorker:
    def __init__(self, queue, procedure, microservice, processor):
        self.queue = queue
        self.procedure = procedure
        self.microservice = microservice
        self.processor = processor
        self._active_thread = None
        self._active_lock = threading.Lock()
        self._stage_complete = threading.Event()
        self._stage_complete.set()
        self._stopping = threading.Event()
        self._cancel_scheduled = threading.Event()
        self._consumer_tag = None
        self._first_message_logged = False
        self._first_message_lock = threading.Lock()
        self._connection = self._connect()
        self._channel = self._connection.channel()
        self._channel.exchange_declare(
            exchange=EXCHANGE, exchange_type=ExchangeType.direct, durable=True
        )
        self._channel.queue_declare(queue=queue, durable=True)
        self._channel.queue_bind(queue=queue, exchange=EXCHANGE, routing_key=queue)
        self._channel.basic_qos(prefetch_count=1)

    @staticmethod
    def _connect():
        credentials = pika.PlainCredentials(env.RABBITMQ_USERNAME, env.RABBITMQ_PASSWORD)
        params = pika.ConnectionParameters(
            env.RABBITMQ_HOST, int(env.RABBITMQ_PORT), "/", credentials
        )
        for _ in range(30):
            try:
                return pika.BlockingConnection(params)
            except pika.exceptions.AMQPConnectionError:
                time.sleep(2)
        raise RuntimeError("Could not connect to RabbitMQ")

    def _publish(self, queue, msg):
        self._channel.basic_publish(
            exchange=EXCHANGE, routing_key=queue, body=json.dumps(msg)
        )

    def _reply_success(self, msg_id, started, input_uri, output_uri, video_info):
        output = {
            "type": video_info.get("output_type", "video"),
            "imageURI": video_info.get("output_path", output_uri),
        }
        if output["type"] == "frames":
            output["frames"] = video_info["frames"]
        self._publish(PROJECT_QUEUE, {
            "messageId": f"video-{uuid.uuid4()}",
            "correlationId": msg_id,
            "timestamp": now().isoformat(),
            "status": "success",
            "output": output,
            "metadata": {
                "processingTime": (now() - started).total_seconds() * 1000,
                "microservice": self.microservice,
                "video": video_info,
            },
        })

    def _reply_error(self, msg_id, started, code, message, input_uri):
        self._publish(PROJECT_QUEUE, {
            "messageId": f"video-{uuid.uuid4()}",
            "correlationId": msg_id,
            "timestamp": now().isoformat(),
            "status": "error",
            "error": {
                "code": code,
                "message": message,
                "msg": message,
                "details": {"inputFileURI": input_uri},
            },
            "metadata": {
                "processingTime": (now() - started).total_seconds() * 1000,
                "microservice": self.microservice,
            },
        })

    def _progress(self, progress, preview, percent, stage_index=0, stage_count=1):
        if not progress or not progress.get("user"):
            return
        stage_range = progress.get("range") or [0, 100]
        mapped = _stage_percent(
            percent,
            stage_range,
            stage_index == stage_count - 1,
        )
        self._publish(WS_QUEUE, {
            "messageId": f"update-client-video-progress-{uuid.uuid4()}",
            "timestamp": now().isoformat(),
            "status": "success",
            "user": progress["user"],
            "projectId": progress.get("projectId"),
            "imgId": progress.get("imgId"),
            "preview": bool(preview),
            "percent": mapped,
        })

    def _log_first_message(self):
        with self._first_message_lock:
            if self._first_message_logged:
                return
            self._first_message_logged = True
        print(
            f"[video] first_message_at={now().isoformat()} queue={self.queue}",
            flush=True,
        )

    def _schedule_cancel(self):
        if self._consumer_tag is None or self._cancel_scheduled.is_set():
            return
        self._cancel_scheduled.set()
        self._connection.add_callback_threadsafe(
            lambda: self._channel.basic_cancel(self._consumer_tag)
        )

    def _handle_sigterm(self, signum, frame):
        self._stopping.set()
        self._schedule_cancel()

    @staticmethod
    def _processing_error(exc):
        if isinstance(exc, UnsupportedEffect):
            return CODES["unsupported_effect"], str(exc)
        if isinstance(exc, InvalidTrim):
            return CODES["invalid_trim"], str(exc)
        if isinstance(exc, InvalidSpeed):
            return CODES["invalid_speed"], str(exc)
        if isinstance(exc, InvalidVideo):
            return CODES["invalid_video"], str(exc)
        return CODES["error_processing"], str(exc)

    def _complete_stage(
        self, ch, delivery_tag, msg_id, started, input_uri, output_uri,
        result, error,
    ):
        try:
            if error is None:
                self._reply_success(
                    msg_id, started, input_uri, output_uri, result
                )
            else:
                code, message = error
                self._reply_error(
                    msg_id, started, code, message, input_uri
                )
            ch.basic_ack(delivery_tag=delivery_tag)
        finally:
            with self._active_lock:
                self._active_thread = None
                self._stage_complete.set()

    def _process_stage(
        self, ch, delivery_tag, msg_id, started, input_uri, output_uri,
        tools, preview, progress, source_info, params,
    ):
        try:
            stage = params.get("stage") or {}
            stage_index = int(stage.get("index", 0))
            stage_count = int(stage.get("count", 1))

            def progress_cb(percent):
                self._connection.add_callback_threadsafe(
                    lambda percent=percent: self._progress(
                        progress, preview, percent, stage_index, stage_count
                    )
                )

            result = self.processor(
                input_uri, output_uri, tools, progress_cb, preview, source_info
            )
            error = None
        except Exception as exc:
            result = None
            error = self._processing_error(exc)

        self._connection.add_callback_threadsafe(
            lambda: self._complete_stage(
                ch, delivery_tag, msg_id, started, input_uri, output_uri,
                result, error,
            )
        )

    def callback(self, ch, method, properties, body):
        self._log_first_message()
        started = now()
        try:
            info = json.loads(body.decode())
            msg_id = info["messageId"]
            params = info["parameters"]
            input_uri = params["inputImageURI"]
            output_uri = params["outputImageURI"]
            tools = params.get("tools") or []
            preview = bool(params.get("preview"))
            progress = params.get("progress") or {}
            source_info = params.get("sourceInfo")
        except (ValueError, KeyError) as exc:
            print(f"[video] invalid message discarded: {exc}", flush=True)
            ch.basic_ack(delivery_tag=method.delivery_tag)
            return

        print(
            f"[video] msg={msg_id} preview={preview} "
            f"tools={[tool.get('procedure') for tool in tools]}",
            flush=True,
        )

        if info.get("procedure") != self.procedure:
            self._reply_error(
                msg_id, started, CODES["wrong_procedure"],
                "The procedure received does not fit into this tool", input_uri
            )
            ch.basic_ack(delivery_tag=method.delivery_tag)
            return

        with self._active_lock:
            if not self._stage_complete.is_set():
                raise RuntimeError("Received a video stage while another is active")
            self._stage_complete.clear()
            thread = threading.Thread(
                target=self._process_stage,
                args=(
                    ch, method.delivery_tag, msg_id, started, input_uri,
                    output_uri, tools, preview, progress, source_info, params,
                ),
                name=f"video-stage-{msg_id}",
            )
            self._active_thread = thread
            thread.start()

    def run(self):
        signal.signal(signal.SIGTERM, self._handle_sigterm)
        try:
            self._consumer_tag = self._channel.basic_consume(
                queue=self.queue, on_message_callback=self.callback, auto_ack=False
            )
            if self._stopping.is_set():
                self._schedule_cancel()
            print(f"[video] waiting for jobs on {self.queue}", flush=True)
            self._channel.start_consuming()

            while not self._stage_complete.is_set():
                self._connection.process_data_events(time_limit=0.1)

            with self._active_lock:
                thread = self._active_thread
            if thread is not None:
                thread.join()
        finally:
            if not getattr(self._connection, "is_closed", False):
                self._connection.close()
