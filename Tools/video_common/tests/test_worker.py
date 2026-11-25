import json
import queue
import signal
import threading
import time

import pika

from video_common.worker import VideoWorker


class FakeConnection:
    def __init__(self):
        self.owner_thread = threading.get_ident()
        self.channel_instance = FakeChannel()
        self.callbacks = queue.Queue()
        self.scheduled_from = []
        self.closed = False

    def channel(self):
        return self.channel_instance

    def add_callback_threadsafe(self, callback):
        self.scheduled_from.append(threading.get_ident())
        self.callbacks.put(callback)

    def process_data_events(self, time_limit=0):
        try:
            callback = self.callbacks.get(timeout=time_limit)
        except queue.Empty:
            return
        callback()

    def close(self):
        self.closed = True


class FakeChannel:
    def __init__(self):
        self.events = []
        self.delivery_callback = None
        self.cancelled = threading.Event()
        self.acked = threading.Event()
        self.replied = threading.Event()

    def exchange_declare(self, **kwargs):
        pass

    def queue_declare(self, **kwargs):
        pass

    def queue_bind(self, **kwargs):
        pass

    def basic_qos(self, **kwargs):
        pass

    def basic_consume(self, queue, on_message_callback, auto_ack):
        assert auto_ack is False
        self.delivery_callback = on_message_callback
        return "consumer-1"

    def basic_cancel(self, consumer_tag):
        self.events.append(("cancel", time.monotonic(), threading.get_ident()))
        self.cancelled.set()

    def basic_ack(self, delivery_tag):
        self.events.append(("ack", time.monotonic(), threading.get_ident()))
        self.acked.set()

    def basic_publish(self, exchange, routing_key, body):
        message = json.loads(body)
        event = "reply" if routing_key == "project_queue" else "progress"
        self.events.append((event, time.monotonic(), threading.get_ident(), message))
        if event == "reply":
            self.replied.set()


def _pump_until(connection, predicate, timeout=2):
    deadline = time.monotonic() + timeout
    while not predicate() and time.monotonic() < deadline:
        connection.process_data_events(time_limit=0.01)
    assert predicate()


def _message():
    return {
        "messageId": "request-1",
        "procedure": "video_edit",
        "parameters": {
            "inputImageURI": "/input.mp4",
            "outputImageURI": "/output.mp4",
            "tools": [],
        },
    }


def test_sigterm_finishes_in_flight_stage_before_ack_and_worker_exit(monkeypatch):
    connection = FakeConnection()
    monkeypatch.setattr(VideoWorker, "_connect", lambda self: connection)
    handlers = {}
    monkeypatch.setattr(
        signal,
        "signal",
        lambda signum, handler: handlers.__setitem__(signum, handler),
    )

    started = threading.Event()
    release = threading.Event()
    finished = threading.Event()
    finished_at = []

    def processor(*args):
        started.set()
        assert release.wait(timeout=2)
        finished_at.append(time.monotonic())
        finished.set()
        return {"duration": 1}

    worker = VideoWorker("video_edit_queue", "video_edit", "video-edit", processor)

    def start_consuming():
        delivery = threading.Thread(
            target=connection.channel_instance.delivery_callback,
            args=(
                connection.channel_instance,
                type("Method", (), {"delivery_tag": 1})(),
                None,
                json.dumps(_message()).encode(),
            ),
        )
        delivery.start()
        signal_thread = None
        try:
            assert started.wait(timeout=2)
            assert signal.SIGTERM in handlers

            signal_thread = threading.Thread(
                target=handlers[signal.SIGTERM], args=(signal.SIGTERM, None)
            )
            signal_thread.start()
            _pump_until(connection, connection.channel_instance.cancelled.is_set)
            assert not connection.channel_instance.acked.is_set()

            release.set()
            _pump_until(
                connection,
                lambda: (
                    connection.channel_instance.acked.is_set()
                    and connection.channel_instance.replied.is_set()
                ),
            )
        finally:
            release.set()
            if signal_thread:
                signal_thread.join(timeout=2)
            delivery.join(timeout=2)
        assert not delivery.is_alive()
        if signal_thread:
            assert not signal_thread.is_alive()

    connection.channel_instance.start_consuming = start_consuming
    worker.run()

    assert finished.is_set()
    events = connection.channel_instance.events
    times = {event[0]: event[1] for event in events}
    assert times["cancel"] < times["reply"]
    assert times["cancel"] < times["ack"]
    assert finished_at[0] < times["reply"]
    assert finished_at[0] < times["ack"]
    reply = next(event[3] for event in events if event[0] == "reply")
    assert reply["status"] == "success"
    assert connection.closed


def test_sigterm_without_in_flight_stage_stops_worker_immediately(monkeypatch):
    connection = FakeConnection()
    monkeypatch.setattr(VideoWorker, "_connect", lambda self: connection)
    handlers = {}
    monkeypatch.setattr(
        signal,
        "signal",
        lambda signum, handler: handlers.__setitem__(signum, handler),
    )
    processor_called = False

    def processor(*args):
        nonlocal processor_called
        processor_called = True
        return {"duration": 1}

    worker = VideoWorker("video_edit_queue", "video_edit", "video-edit", processor)

    def start_consuming():
        assert signal.SIGTERM in handlers
        signal_thread = threading.Thread(
            target=handlers[signal.SIGTERM], args=(signal.SIGTERM, None)
        )
        signal_thread.start()
        _pump_until(connection, connection.channel_instance.cancelled.is_set)
        signal_thread.join(timeout=1)
        assert not signal_thread.is_alive()

    connection.channel_instance.start_consuming = start_consuming
    started_at = time.monotonic()
    worker.run()

    assert time.monotonic() - started_at < 1
    assert not processor_called
    assert not connection.channel_instance.acked.is_set()
    assert connection.closed


def test_worker_connection_uses_active_heartbeat(monkeypatch):
    connection = FakeConnection()
    parameters = []

    def make_connection(params):
        parameters.append(params)
        return connection

    monkeypatch.setattr(pika, "BlockingConnection", make_connection)
    worker = VideoWorker(
        "video_edit_queue", "video_edit", "video-edit", lambda *args: {"duration": 1}
    )

    assert parameters[0].heartbeat != 0


def test_worker_logs_timestamp_for_only_the_first_consumed_message(monkeypatch, capsys):
    connection = FakeConnection()
    monkeypatch.setattr(VideoWorker, "_connect", lambda self: connection)
    worker = VideoWorker(
        "video_edit_queue", "video_edit", "video-edit", lambda *args: {"duration": 1}
    )
    method = type("Method", (), {"delivery_tag": 1})()

    worker.callback(connection.channel_instance, method, None, b"{}")
    worker.callback(connection.channel_instance, method, None, b"{}")

    output = capsys.readouterr().out
    assert output.count("first_message_at=") == 1
    assert "queue=video_edit_queue" in output


def test_worker_marshals_ack_reply_and_progress_to_io_thread(monkeypatch):
    connection = FakeConnection()
    monkeypatch.setattr(VideoWorker, "_connect", lambda self: connection)
    processor_threads = []

    def processor(input_uri, output_uri, tools, progress_cb, preview, source_info):
        processor_threads.append(threading.get_ident())
        progress_cb(50)
        return {"duration": 1}

    worker = VideoWorker("video_edit_queue", "video_edit", "video-edit", processor)
    message = _message()
    message["parameters"]["progress"] = {"user": "user-1"}
    worker.callback(
        connection.channel_instance,
        type("Method", (), {"delivery_tag": 2})(),
        None,
        json.dumps(message).encode(),
    )

    _pump_until(
        connection,
        lambda: (
            connection.channel_instance.acked.is_set()
            and connection.channel_instance.replied.is_set()
            and any(event[0] == "progress" for event in connection.channel_instance.events)
        ),
    )

    assert processor_threads
    assert processor_threads[0] != connection.owner_thread
    assert connection.scheduled_from
    assert all(
        event[2] == connection.owner_thread
        for event in connection.channel_instance.events
    )
