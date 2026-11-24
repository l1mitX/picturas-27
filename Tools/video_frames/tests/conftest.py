import os
import subprocess
import sys

import pytest

SERVICE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TOOLS_DIR = os.path.abspath(os.path.join(SERVICE_DIR, ".."))
REPO_ROOT = os.path.abspath(os.path.join(TOOLS_DIR, ".."))

# "import video_frames" / "import video_common" as in the container (/app).
for path in (REPO_ROOT, TOOLS_DIR, SERVICE_DIR):
    if path not in sys.path:
        sys.path.insert(0, path)
# Pipelines that combine services run the edit service in-process through
# video_common.local_pipeline; its modules import "effects" at top level.
for root in (TOOLS_DIR, "/repo/Tools"):
    edit_dir = os.path.join(root, "video_edit")
    if os.path.isdir(edit_dir) and edit_dir not in sys.path:
        sys.path.append(edit_dir)


def make_video(path, seconds=4, size="320x240", fps=25, audio=True, vcodec="libx264"):
    cmd = ["ffmpeg", "-y", "-v", "error",
           "-f", "lavfi", "-i", f"testsrc=size={size}:rate={fps}:duration={seconds}"]
    if audio:
        cmd += ["-f", "lavfi", "-i", f"sine=frequency=440:duration={seconds}",
                "-c:a", "aac"]
    cmd += ["-c:v", vcodec, "-pix_fmt", "yuv420p", "-shortest", path]
    subprocess.run(cmd, check=True)
    return path


@pytest.fixture
def sample_video(tmp_path):
    """Test video: 4 s, 320x240, 25 fps, with audio."""
    return make_video(str(tmp_path / "sample.mp4"))


@pytest.fixture
def silent_video(tmp_path):
    return make_video(str(tmp_path / "silent.mov"), seconds=2, audio=False)


@pytest.fixture
def pipeline():
    """`process_video`-like runner over the stage plans of the shared fixture.

    Needs the whole repository (the edit service and
    projects/tests/fixtures/video_stage_plans.json). Inside this service's own
    image they are absent, so these tests are skipped there; run them on the
    host or with the repository mounted at /repo.
    """
    try:
        from video_common import local_pipeline
        import video_edit.video_edit  # noqa: F401
    except ImportError as exc:
        pytest.skip(f"pipeline tests need the edit service: {exc}")
    if not local_pipeline.FIXTURE.is_file():
        pytest.skip(f"pipeline tests need {local_pipeline.FIXTURE}")

    def process_video(input_path, output_path, tools, progress_cb=None, preview=False):
        return local_pipeline.run(tools, input_path, output_path,
                                  preview=preview, progress_cb=progress_cb)

    return process_video
