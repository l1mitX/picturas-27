"""RabbitMQ entry point for the PictuRAS video editing stage."""
import os
import sys

if __name__ == "__main__":
    sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from video_common.worker import VideoWorker
try:
    from video_edit.video_processor import process_video
except ModuleNotFoundError:
    from video_processor import process_video


MICROSERVICE = "picturas-video-edit-ms"


def process_stage(input_uri, output_uri, tools, progress_cb,
                  preview=False, source_info=None):
    return process_video(
        input_uri, output_uri, tools,
        progress_cb=progress_cb, preview=preview
    )


if __name__ == "__main__":
    VideoWorker(
        "video_edit_queue",
        "video_edit",
        MICROSERVICE,
        process_stage,
    ).run()
