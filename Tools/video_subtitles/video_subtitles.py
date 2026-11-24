"""RabbitMQ entry point for the PictuRAS video subtitles stage.

Runs one `subtitles` stage planned by `projects`: detects the spoken language,
burns the captions into the video and writes MP4/H.264 + AAC. A video with no
audio or no speech is a successful no-op copy, as in the monolithic worker.

The output is written to a temporary file next to the target and moved into
place only on success, so a failure never leaves a partial file.
"""
import os
import sys
import tempfile
from pathlib import Path

if __name__ == "__main__":
    sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from video_common.exceptions import UnsupportedEffect
from video_common.probe import probe
from video_subtitles import subtitles

QUEUE = "video_subtitles_queue"
PROCEDURE = "video_subtitles"
MICROSERVICE = "picturas-video-subtitles-ms"


def validate_tools(tools: list) -> None:
    """A subtitles stage carries exactly one `subtitles` tool (data-model.md)."""
    procedures = [tool.get("procedure") for tool in tools]
    if procedures != ["subtitles"]:
        raise UnsupportedEffect(
            f"The subtitles service only runs a single 'subtitles' tool, got {procedures}"
        )


def process_stage(input_uri, output_uri, tools, progress_cb=None,
                  preview=False, source_info=None):
    """Caption `input_uri` into `output_uri` and return the encoded video info.

    `preview` and `source_info` are accepted for the common worker interface but
    unused: the preview cut happens in an edit stage and captioning always
    probes its own input, as `process_video` did.
    """
    validate_tools(tools)
    progress = progress_cb or (lambda _: None)
    progress(0)
    target = Path(output_uri).resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="captions-", dir=target.parent) as work:
        staged = str(Path(work) / "captioned.mp4")
        subtitles.caption_video(input_uri, staged, probe(input_uri), progress)
        result = probe(staged)
        result["frames"] = round(result["duration"] * result["fps"])
        os.replace(staged, target)
    return result


if __name__ == "__main__":
    from video_common.worker import VideoWorker

    VideoWorker(QUEUE, PROCEDURE, MICROSERVICE, process_stage).run()
