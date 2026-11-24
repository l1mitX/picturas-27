import datetime
import json
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
            env.RABBITMQ_HOST, int(env.RABBITMQ_PORT), "/", credentials, heartbeat=0
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

    def callback(self, ch, method, properties, body):
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
        else:
            try:
                stage = params.get("stage") or {}
                stage_index = int(stage.get("index", 0))
                stage_count = int(stage.get("count", 1))

                def progress_cb(percent):
                    self._progress(
                        progress, preview, percent,
                        stage_index, stage_count,
                    )

                result = self.processor(
                    input_uri, output_uri, tools, progress_cb,
                    preview, source_info
                )
                self._reply_success(msg_id, started, input_uri, output_uri, result)
            except UnsupportedEffect as exc:
                self._reply_error(msg_id, started, CODES["unsupported_effect"], str(exc), input_uri)
            except InvalidTrim as exc:
                self._reply_error(msg_id, started, CODES["invalid_trim"], str(exc), input_uri)
            except InvalidSpeed as exc:
                self._reply_error(msg_id, started, CODES["invalid_speed"], str(exc), input_uri)
            except InvalidVideo as exc:
                self._reply_error(msg_id, started, CODES["invalid_video"], str(exc), input_uri)
            except Exception as exc:
                self._reply_error(
                    msg_id, started, CODES["error_processing"], str(exc), input_uri
                )

        ch.basic_ack(delivery_tag=method.delivery_tag)

    def run(self):
        self._channel.basic_consume(
            queue=self.queue, on_message_callback=self.callback, auto_ack=False
        )
        print(f"[video] waiting for jobs on {self.queue}", flush=True)
        self._channel.start_consuming()
