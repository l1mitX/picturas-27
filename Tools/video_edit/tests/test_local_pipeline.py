import os

import pytest

from video_common.local_pipeline import _find_plan, _stages_with_input_params, run


def test_local_pipeline_brightness(sample_video, tmp_path):
    out = str(tmp_path / "brightness.mp4")
    progress = []
    tools = [{"procedure": "brightness", "params": {"brightness": 1.5}}]

    info = run(tools, sample_video, out, progress_cb=progress.append)

    assert info["video_codec"] == "h264"
    assert os.path.isfile(out)
    assert progress[-1] == 100


def test_local_pipeline_rejects_unknown_fixture(tmp_path):
    with pytest.raises(KeyError, match="is not in"):
        run(
            [{"procedure": "unknown_effect", "params": {}}],
            str(tmp_path / "missing.mp4"),
            str(tmp_path / "out.mp4"),
        )


def test_local_pipeline_uses_test_parameters_for_matching_fixture():
    tools = [{"procedure": "brightness", "params": {"brightness": 0.63}}]
    case = _find_plan(tools, preview=False)

    stages = _stages_with_input_params(case, tools)

    assert stages[0]["tools"] == tools
