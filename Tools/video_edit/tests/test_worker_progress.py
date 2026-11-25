import json
import queue
import threading
import time

from video_common.worker import VideoWorker


class FakeChannel:
    def __init__(self):
        self.acked = []

    def exchange_declare(self, **kwargs):
        pass

    def queue_declare(self, **kwargs):
        pass

    def queue_bind(self, **kwargs):
        pass

    def basic_qos(self, **kwargs):
        pass

    def basic_ack(self, delivery_tag):
        self.acked.append(delivery_tag)

    def basic_consume(self, **kwargs):
        return "consumer-1"


class FakeConnection:
    def __init__(self):
        self.channel_instance = FakeChannel()
        self.callbacks = queue.Queue()

    def channel(self):
        return self.channel_instance

    def add_callback_threadsafe(self, callback):
        self.callbacks.put(callback)

    def process_data_events(self, time_limit=0):
        try:
            callback = self.callbacks.get(timeout=time_limit)
        except queue.Empty:
            return
        callback()


def _pump_until(connection, predicate, timeout=2):
    deadline = time.monotonic() + timeout
    while not predicate() and time.monotonic() < deadline:
        connection.process_data_events(time_limit=0.01)
    assert predicate()


def test_last_stage_finishes_at_100_even_if_its_range_ends_at_99():
    worker = VideoWorker.__new__(VideoWorker)
    messages = []
    worker._publish = lambda queue, message: messages.append((queue, message))

    worker._progress(
        {"user": "user-1", "range": [50, 99]},
        False,
        100,
        stage_index=1,
        stage_count=2,
    )

    assert messages[-1][1]["percent"] == 100


def test_intermediate_stage_progress_is_mapped_to_integer_range():
    worker = VideoWorker.__new__(VideoWorker)
    messages = []
    worker._publish = lambda queue, message: messages.append((queue, message))

    worker._progress(
        {"user": "user-1", "range": [0, 50]},
        False,
        100,
        stage_index=0,
        stage_count=2,
    )
    worker._progress(
        {"user": "user-1", "range": [0, 50]},
        False,
        33,
        stage_index=0,
        stage_count=2,
    )

    assert messages[0][1]["percent"] == 50
    assert messages[1][1]["percent"] == 16
    assert all(isinstance(message["percent"], int) for _, message in messages)


def test_callback_publishes_last_stage_completion_as_100(monkeypatch):
    connection = FakeConnection()
    monkeypatch.setattr(VideoWorker, "_connect", lambda self: connection)
    messages = []

    def processor(input_uri, output_uri, tools, progress_cb, preview, source_info):
        progress_cb(100)
        return {"duration": 1}

    worker = VideoWorker(
        "video_edit_queue", "video_edit", "picturas-video-edit-ms", processor
    )
    worker._publish = lambda queue_name, message: messages.append((queue_name, message))
    request = {
        "messageId": "request-1",
        "procedure": "video_edit",
        "parameters": {
            "inputImageURI": "/input.mp4",
            "outputImageURI": "/output.mp4",
            "progress": {"user": "user-1", "range": [50, 99]},
            "stage": {"index": 1, "count": 2},
        },
    }

    worker.callback(
        connection.channel_instance, type("Method", (), {"delivery_tag": 1})(), None,
        json.dumps(request).encode(),
    )
    _pump_until(
        connection,
        lambda: connection.channel_instance.acked == [1]
        and any(queue_name == "ws_queue" for queue_name, _ in messages),
    )

    progress = [message for queue, message in messages if queue == "ws_queue"]
    assert progress[-1]["percent"] == 100
