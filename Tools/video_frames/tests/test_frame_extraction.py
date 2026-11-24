"""Frame extraction exercises actual FFmpeg outputs without a speech model.

Moved from Tools/video/tests/test_frame_extraction.py without dropping cases
(INV-006). Extraction-only pipelines are a single `video_frames` stage (fixture
case V6_extracao_sozinha), so they call this service's `process_stage`
directly; pipelines that combine services go through the `pipeline` fixture
(video_common.local_pipeline over the shared stage plans, R7).
"""
from pathlib import Path
import hashlib
import subprocess
import sys

import pytest
from PIL import Image

from video_common.probe import probe
from video_frames import frame_extraction, video_frames
from video_frames.frame_extraction import InvalidExtraction, sampling_times, validate_params
from video_frames.video_frames import process_stage


def tool(**params):
    return {"procedure": "extract_frames", "params": params}


def extract(input_path, output_path, tools, progress_cb=None, preview=False):
    """The single stage projects sends for an extraction-only pipeline."""
    return process_stage(input_path, output_path, tools, progress_cb, preview)


@pytest.mark.parametrize("fmt,extension", [("png", ".png"), ("jpeg", ".jpg")])
def test_count_images_and_original_preserved(sample_video, tmp_path, fmt, extension):
    source_hash = hashlib.sha256(Path(sample_video).read_bytes()).hexdigest()
    progress = []
    result = extract(sample_video, str(tmp_path / "result.mp4"),
                     [tool(count=4, format=fmt)], progress.append)
    assert result["output_type"] == "frames"
    assert [f["time"] for f in result["frames"]] == pytest.approx([0, 1, 2, 3], abs=0.05)
    for frame in result["frames"]:
        path = Path(frame["file"])
        assert path.parent == Path(result["output_path"])
        assert path.suffix == extension
        with Image.open(path) as image:
            assert image.size == (320, 240)
            assert image.format == ("PNG" if fmt == "png" else "JPEG")
    assert len({f["file"] for f in result["frames"]}) == 4
    assert hashlib.sha256(Path(sample_video).read_bytes()).hexdigest() == source_hash
    assert progress[-1] == 100 and progress == sorted(progress)
    assert not list(tmp_path.glob("extract-*"))
    assert not list(tmp_path.glob("frame-source-*"))


def test_interval_sampling(sample_video, tmp_path):
    result = extract(sample_video, str(tmp_path / "result.mp4"),
                     [tool(mode="interval", interval=1.5)])
    assert [f["time"] for f in result["frames"]] == pytest.approx([0, 1.5, 3])


def test_preview_contact_sheet_uses_full_edited_timeline(pipeline, sample_video, tmp_path,
                                                         monkeypatch):
    sampled = []
    real_run = frame_extraction.subprocess.run

    def record(cmd, **kwargs):
        if "-frames:v" in cmd:
            sampled.append(float(cmd[cmd.index("-ss") + 1]))
        return real_run(cmd, **kwargs)

    monkeypatch.setattr(frame_extraction.subprocess, "run", record)
    speed = {"procedure": "speed", "params": {"factor": 0.5}}
    result = pipeline(sample_video, str(tmp_path / "preview.mp4"),
                      [speed, tool(count=12)], preview=True)
    assert result["output_type"] == "image"
    assert result["duration"] == pytest.approx(8, abs=0.15)
    assert result["frames"] == 6
    assert len(sampled) == 6 and sampled[-1] > 7
    with Image.open(result["output_path"]) as sheet:
        assert sheet.format == "PNG"
        assert sheet.size == (1152, 480)
    assert not Path(tmp_path / "preview.mp4").exists()


def test_preceding_effects_apply_to_every_frame(pipeline, sample_video, tmp_path):
    resize = {"procedure": "resize", "params": {"width": 80, "height": 60}}
    trim = {"procedure": "trim", "params": {"start": 1, "end": 3}}
    result = pipeline(sample_video, str(tmp_path / "result.mp4"),
                      [trim, resize, tool(count=2)])
    assert result["duration"] == pytest.approx(2, abs=0.15)
    assert [f["time"] for f in result["frames"]] == pytest.approx([0, 1], abs=0.05)
    for frame in result["frames"]:
        with Image.open(frame["file"]) as image:
            assert image.size == (80, 60)


@pytest.mark.parametrize("params", [
    {"count": True}, {"count": 0}, {"count": 101}, {"count": 1.5}, {"count": "6"},
    {"count": float("nan")}, {"count": float("inf")},
    {"mode": "interval", "interval": 0}, {"mode": "interval", "interval": -1},
    {"mode": "interval", "interval": True}, {"mode": "interval", "interval": "2"},
    {"mode": "interval", "interval": float("nan")},
    {"mode": "interval", "interval": float("inf")}, {"mode": "invalid"}, {"format": "gif"},
])
def test_invalid_parameters(params):
    with pytest.raises(InvalidExtraction):
        validate_params(params)


def test_interval_resource_limit_and_boundaries():
    times, _ = sampling_times({"mode": "interval", "interval": 0.04}, 4, 25)
    assert len(times) == 100 and times[-1] < 4
    with pytest.raises(InvalidExtraction, match="more than 100"):
        sampling_times({"mode": "interval", "interval": 0.001}, 4, 25)
    assert sampling_times({"mode": "interval", "interval": 10}, 4, 25)[0] == [0]


@pytest.mark.parametrize("tools", [[tool(), {"procedure": "rotate"}], [tool(), tool()]])
def test_extraction_must_be_terminal_once(pipeline, sample_video, tmp_path, tools):
    with pytest.raises(InvalidExtraction, match="once"):
        pipeline(sample_video, str(tmp_path / "result.mp4"), tools)


def test_extractor_failure_leaves_previous_output(sample_video, tmp_path, monkeypatch):
    target = tmp_path / "result.mp4"
    target.write_bytes(b"previous output")
    real_run = frame_extraction.subprocess.run

    def fail(cmd, **kwargs):
        if "-frames:v" in cmd:
            Path(cmd[-1]).write_bytes(b"partial")
            raise RuntimeError("frame encoder failed")
        return real_run(cmd, **kwargs)

    monkeypatch.setattr(frame_extraction.subprocess, "run", fail)
    with pytest.raises(RuntimeError, match="frame encoder failed"):
        extract(sample_video, str(target), [tool()])
    assert target.read_bytes() == b"previous output"
    assert not list(tmp_path.glob("extract-*"))
    assert not list(tmp_path.glob("frame-source-*"))
    assert not list(tmp_path.glob("result-frames-*"))


def test_extraction_does_not_load_speech_model(silent_video, tmp_path, monkeypatch):
    # The frames service does not contain the subtitles code at all; when the
    # whole repository is on the path, make sure it is still never used.
    try:
        from video_subtitles import subtitles
    except ImportError:
        subtitles = None
    if subtitles is not None:
        monkeypatch.setattr(subtitles, "speech_model",
                            lambda: pytest.fail("no captions requested"))
    result = extract(silent_video, str(tmp_path / "result.mp4"), [tool(count=1)])
    assert len(result["frames"]) == 1
    assert "faster_whisper" not in sys.modules


def test_captions_run_before_extraction(pipeline, sample_video, tmp_path, monkeypatch):
    from types import SimpleNamespace
    subtitles = pytest.importorskip("video_subtitles.subtitles")
    seen = []

    def transcribe(path, **kwargs):
        seen.append(path)
        return iter([SimpleNamespace(start=0, end=3, text="Frame captions")]), None

    monkeypatch.setattr(subtitles, "speech_model", lambda: SimpleNamespace(transcribe=transcribe))
    result = pipeline(sample_video, str(tmp_path / "result.mp4"),
                      [{"procedure": "subtitles"}, tool(count=2)])
    assert len(seen) == 1
    assert result["output_type"] == "frames" and len(result["frames"]) == 2


@pytest.mark.parametrize("params", [None, False, [], "count"])
def test_invalid_parameter_container(params):
    with pytest.raises(InvalidExtraction):
        validate_params(params)


@pytest.mark.parametrize("fmt", ["png", "jpeg"])
def test_extraction_only_seeks_original_without_transcoding(silent_video, tmp_path, monkeypatch, fmt):
    # The extraction-only plan has no edit stage; if the edit service is on the
    # path, make sure it is never called.
    try:
        from video_edit import video_edit, video_processor
    except ImportError:
        pass
    else:
        def no_transcode(*a, **k):
            pytest.fail("extraction-only must not transcode")
        monkeypatch.setattr(video_processor, "_process_video", no_transcode)
        monkeypatch.setattr(video_edit, "process_stage", no_transcode)
    result = extract(silent_video, str(tmp_path / "result.mp4"),
                     [tool(count=100, format=fmt)])
    assert result["output_type"] == "frames"
    assert len(result["frames"]) == 100
    assert result["frames"][-1]["time"] < result["duration"]
    for frame in result["frames"]:
        with Image.open(frame["file"]) as image:
            assert image.format == ("PNG" if fmt == "png" else "JPEG")
    assert not list(tmp_path.glob("frame-source-*"))


def test_extraction_uses_video_duration_when_audio_is_longer(sample_video, tmp_path):
    source = tmp_path / "long-audio.mp4"
    subprocess.run(["ffmpeg", "-v", "error", "-i", sample_video,
                    "-f", "lavfi", "-i", "sine=frequency=440:duration=6",
                    "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy", "-c:a", "aac",
                    str(source)], check=True)
    result = extract(str(source), str(tmp_path / "result.mp4"), [tool(count=4)])
    assert result["duration"] == pytest.approx(4, abs=0.1)
    assert [frame["time"] for frame in result["frames"]] == pytest.approx([0, 1, 2, 3], abs=0.05)


# --- New with the split (R5): video info forwarded by projects as sourceInfo ---

def test_source_info_is_used_instead_of_probing(sample_video, tmp_path, monkeypatch):
    """With sourceInfo the edited video is not probed again, so the sampled
    times follow the duration the edit stage reported."""
    info = {**probe(sample_video), "duration": 2.0}
    monkeypatch.setattr(video_frames, "probe",
                        lambda *a, **k: pytest.fail("sourceInfo must avoid a new probe"))
    result = process_stage(sample_video, str(tmp_path / "result.mp4"), [tool(count=4)],
                           source_info=info)
    assert [f["time"] for f in result["frames"]] == pytest.approx([0, 0.5, 1, 1.5])
    assert result["duration"] == 2.0


def test_partial_source_info_is_completed_by_a_probe(sample_video, tmp_path):
    result = process_stage(sample_video, str(tmp_path / "result.mp4"), [tool(count=2)],
                           source_info={"duration": 2.0, "fps": 25.0})
    assert [f["time"] for f in result["frames"]] == pytest.approx([0, 1])
    assert (result["width"], result["height"]) == (320, 240)


def test_without_source_info_probes_the_video_duration(sample_video, tmp_path, monkeypatch):
    calls = []
    real_probe = video_frames.probe

    def recording_probe(path, **kwargs):
        calls.append(kwargs)
        return real_probe(path, **kwargs)

    monkeypatch.setattr(video_frames, "probe", recording_probe)
    process_stage(sample_video, str(tmp_path / "result.mp4"), [tool(count=1)])
    assert calls == [{"prefer_video_duration": True}]


# --- New with the split: the service entry point ---

def test_worker_identity():
    assert video_frames.QUEUE == "video_frames_queue"
    assert video_frames.PROCEDURE == "video_frames"
    assert video_frames.MICROSERVICE == "picturas-video-frames-ms"


@pytest.mark.parametrize("tools", [
    [],
    [{"procedure": "brightness", "params": {"brightness": 1.5}}],
    [tool(), tool()],
    [{"procedure": "subtitles"}, tool()],
])
def test_rejects_anything_but_one_extraction_tool(sample_video, tmp_path, tools):
    from video_common.exceptions import UnsupportedEffect
    with pytest.raises(UnsupportedEffect):
        process_stage(sample_video, str(tmp_path / "result.mp4"), tools)


def test_invalid_parameters_are_rejected_before_reading_the_video(tmp_path):
    with pytest.raises(InvalidExtraction):
        process_stage(str(tmp_path / "missing.mp4"), str(tmp_path / "result.mp4"),
                      [tool(count=0)])
