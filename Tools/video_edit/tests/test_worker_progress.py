import json

from video_common.worker import VideoWorker


class FakeChannel:
    def __init__(self):
        self.acked = []

    def basic_ack(self, delivery_tag):
        self.acked.append(delivery_tag)


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


def test_callback_publishes_last_stage_completion_as_100():
    worker = VideoWorker.__new__(VideoWorker)
    worker.procedure = "video_edit"
    worker.microservice = "picturas-video-edit-ms"
    messages = []
    worker._publish = lambda queue, message: messages.append((queue, message))

    def processor(input_uri, output_uri, tools, progress_cb, preview, source_info):
        progress_cb(100)
        return {"duration": 1}

    worker.processor = processor
    channel = FakeChannel()
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
        channel, type("Method", (), {"delivery_tag": 1})(), None,
        json.dumps(request).encode(),
    )

    progress = [message for queue, message in messages if queue == "ws_queue"]
    assert progress[-1]["percent"] == 100
    assert channel.acked == [1]
