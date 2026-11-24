"""RabbitMQ entry point for the PictuRAS frame extraction stage.

Runs the terminal `extract_frames` stage planned by `projects`. Full output is a
frame manifest; preview output is a contact sheet.

When an edit stage ran before, `projects` forwards that stage's `video_info` as
`sourceInfo` and it is used instead of probing again (R5): the monolithic worker
sampled with the info returned by the edit, and probing the edited file anew
could change the duration and so the sampled timestamps. With no previous
stage the original is probed preferring the video stream duration, as before.
"""
import os
import sys

if __name__ == "__main__":
    sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from video_common.exceptions import UnsupportedEffect
from video_common.probe import probe
from video_frames.frame_extraction import extract_frames, validate_params

QUEUE = "video_frames_queue"
PROCEDURE = "video_frames"
MICROSERVICE = "picturas-video-frames-ms"

# Fields of the video info that extract_frames reads.
REQUIRED_INFO = ("duration", "fps", "width", "height")


def validate_tools(tools: list) -> None:
    """A frames stage carries exactly one `extract_frames` tool (data-model.md)."""
    procedures = [tool.get("procedure") for tool in tools]
    if procedures != ["extract_frames"]:
        raise UnsupportedEffect(
            f"The frames service only runs a single 'extract_frames' tool, got {procedures}"
        )


def stage_info(input_uri, source_info=None) -> dict:
    """Video info to sample from: `sourceInfo` when complete, else a probe.

    A partial `sourceInfo` is completed with a probe of the input, keeping the
    forwarded values (above all the duration) over the probed ones.
    """
    if source_info and all(key in source_info for key in REQUIRED_INFO):
        return dict(source_info)
    probed = probe(input_uri, prefer_video_duration=True)
    return {**probed, **(source_info or {})}


def process_stage(input_uri, output_uri, tools, progress_cb=None,
                  preview=False, source_info=None):
    validate_tools(tools)
    params = tools[-1].get("params", {})
    # Invalid parameters are rejected before reading the video, as before.
    validate_params(params)
    return extract_frames(input_uri, output_uri, stage_info(input_uri, source_info),
                          params, progress_cb or (lambda _: None), preview=preview)


if __name__ == "__main__":
    from video_common.worker import VideoWorker

    VideoWorker(QUEUE, PROCEDURE, MICROSERVICE, process_stage).run()
