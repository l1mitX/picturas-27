"""RNF1 T009 (R7, H-02): with replicas, two edits may write the same output at the same time.

This happens, e.g., with two previews of the same video requested in quick succession. The temporary
file of each edit must have its own name, so that one edit never overwrites, moves or deletes the
temporary file of the other.
"""
import os
import threading

import video_processor
from video_processor import probe, process_video

TOOLS = [{"procedure": "brightness", "params": {"brightness": 1.3}}]


def _part_files(directory):
    return [name for name in os.listdir(directory) if ".part" in name]


def test_each_edit_gets_its_own_temporary_file(sample_video, tmp_path, monkeypatch):
    out = str(tmp_path / "out.mp4")
    seen = []
    start_encoder = video_processor._start_encoder

    def recording(input_path, out_path, *args):
        seen.append(out_path)
        return start_encoder(input_path, out_path, *args)

    monkeypatch.setattr(video_processor, "_start_encoder", recording)
    process_video(sample_video, out, TOOLS)
    process_video(sample_video, out, TOOLS)

    assert len(seen) == 2 and seen[0] != seen[1]
    for part in seen:
        # Same folder as the output, so that os.replace stays atomic.
        assert os.path.dirname(part) == os.path.dirname(out)
        assert os.path.basename(part).startswith("out.mp4.")
    assert _part_files(tmp_path) == []


def test_concurrent_edits_to_the_same_output_do_not_collide(sample_video, tmp_path):
    out = str(tmp_path / "out.mp4")
    barrier = threading.Barrier(2)
    errors = []

    # Each edit reports its first progress value after its encoder exists; waiting there makes
    # both encoders write their temporary files at the same time.
    def edit_in_step():
        first = {"done": False}

        def progress(pct):
            if not first["done"]:
                first["done"] = True
                barrier.wait(timeout=30)

        try:
            process_video(sample_video, out, TOOLS, progress_cb=progress)
        except Exception as exc:
            errors.append(exc)

    threads = [threading.Thread(target=edit_in_step) for _ in range(2)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=120)

    assert errors == []
    info = probe(out)
    assert info["width"] == 320 and info["height"] == 240
    assert _part_files(tmp_path) == []
