"""The subtitles service entry point, called directly as the worker calls it.

These tests need only this service and video_common, so they also run inside
the service's own image.
"""
from pathlib import Path
from types import SimpleNamespace
import subprocess

import pytest

from video_common.exceptions import UnsupportedEffect
from video_common.probe import probe
from video_subtitles import subtitles, video_subtitles
from video_subtitles.video_subtitles import process_stage

CAPTIONS = [{"procedure": "subtitles", "params": {}}]


class Recognizer:
    def transcribe(self, path, **options):
        return iter([SimpleNamespace(start=0.2, end=1.8, text="Hello from PictuRAS")]), None


def test_worker_identity():
    assert video_subtitles.QUEUE == "video_subtitles_queue"
    assert video_subtitles.PROCEDURE == "video_subtitles"
    assert video_subtitles.MICROSERVICE == "picturas-video-subtitles-ms"


@pytest.mark.parametrize("tools", [
    [],
    [{"procedure": "brightness", "params": {"brightness": 1.5}}],
    [*CAPTIONS, *CAPTIONS],
    [*CAPTIONS, {"procedure": "extract_frames", "params": {}}],
])
def test_rejects_anything_but_one_subtitles_tool(sample_video, tmp_path, tools):
    out = tmp_path / "out.mp4"
    with pytest.raises(UnsupportedEffect):
        process_stage(sample_video, str(out), tools)
    assert not out.exists()


def test_stage_returns_info_of_the_encoded_video(sample_video, tmp_path, monkeypatch):
    """The reply's video_info is what projects forwards as sourceInfo (R5)."""
    monkeypatch.setattr(subtitles, "speech_model", Recognizer)
    out = tmp_path / "stages" / "img-1.mp4"
    progress = []
    result = process_stage(sample_video, str(out), CAPTIONS, progress.append)
    encoded = probe(str(out))
    assert result["duration"] == encoded["duration"]
    assert result["fps"] == encoded["fps"]
    assert result["frames"] == round(encoded["duration"] * encoded["fps"])
    assert result["video_codec"] == "h264" and result["has_audio"]
    assert progress[0] == 0 and progress[-1] == 100 and progress == sorted(progress)
    assert not list(out.parent.glob("captions-*"))


def test_stage_without_audio_is_a_copy(silent_video, tmp_path, monkeypatch):
    monkeypatch.setattr(subtitles, "speech_model", lambda: pytest.fail("model not needed"))
    out = tmp_path / "out.mp4"
    process_stage(silent_video, str(out), CAPTIONS)
    assert out.read_bytes() == Path(silent_video).read_bytes()


def test_stage_failure_leaves_previous_output(sample_video, tmp_path, monkeypatch):
    monkeypatch.setattr(subtitles, "speech_model", Recognizer)
    original_run = subprocess.run

    def fail_caption_encoder(cmd, **kwargs):
        if "-vf" in cmd and "subtitles=" in cmd[cmd.index("-vf") + 1]:
            Path(cmd[-1]).write_bytes(b"partial output")
            return SimpleNamespace(returncode=1, stderr="encoder failed")
        return original_run(cmd, **kwargs)

    monkeypatch.setattr(subtitles.subprocess, "run", fail_caption_encoder)
    out = tmp_path / "out.mp4"
    out.write_bytes(b"previous successful output")
    with pytest.raises(RuntimeError, match="encoder failed"):
        process_stage(sample_video, str(out), CAPTIONS)
    assert out.read_bytes() == b"previous successful output"
    assert not list(tmp_path.glob("captions-*"))


def test_stage_ignores_preview_and_source_info(sample_video, tmp_path, monkeypatch):
    """Captioning probes its own input; the preview cut belongs to an edit stage."""
    monkeypatch.setattr(subtitles, "speech_model", Recognizer)
    out = tmp_path / "out.mp4"
    result = process_stage(sample_video, str(out), CAPTIONS, preview=True,
                           source_info={"duration": 1.0, "fps": 1.0})
    assert result["duration"] == pytest.approx(4, abs=0.15)
