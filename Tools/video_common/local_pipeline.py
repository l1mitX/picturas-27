"""Local, in-process stage executor used only by tests and hash regression."""
import copy
import json
import os
import tempfile
from pathlib import Path


FIXTURE_CANDIDATES = [
    Path(__file__).resolve().parents[2] / "projects" / "tests" / "fixtures" / "video_stage_plans.json",
    Path("/repo/projects/tests/fixtures/video_stage_plans.json"),
    Path("/app/projects/tests/fixtures/video_stage_plans.json"),
    Path("/projects/tests/fixtures/video_stage_plans.json"),
]
FIXTURE = next(
    (candidate for candidate in FIXTURE_CANDIDATES if candidate.is_file()),
    FIXTURE_CANDIDATES[0],
)


def _load_fixture():
    if not FIXTURE.is_file():
        raise FileNotFoundError(f"Missing video stage fixture: {FIXTURE}")
    with FIXTURE.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    return data.get("casos", [])


def _find_plan(name_or_tools, preview):
    cases = _load_fixture()
    if isinstance(name_or_tools, str):
        for case in cases:
            if case["nome"] == name_or_tools:
                return case
        raise KeyError(
            f"Video pipeline '{name_or_tools}' is not in {FIXTURE}. "
            "Add or obtain the case fixture; local_pipeline never calculates plans."
        )

    sequence = [tool.get("procedure") for tool in name_or_tools]
    matches = [
        case for case in cases
        if [tool.get("procedure") for tool in case.get("tools", [])] == sequence
        and bool(case.get("preview")) == bool(preview)
    ]
    if not matches:
        raise KeyError(
            f"Video pipeline procedures={sequence}, preview={preview} is not in {FIXTURE}. "
            "local_pipeline only executes fixture plans."
        )
    if len(matches) > 1:
        raise KeyError(
            f"Ambiguous fixture match for procedures={sequence}, preview={preview}"
        )
    return matches[0]


def _stages_with_input_params(case, tools):
    stages = copy.deepcopy(case["estagios"])
    cursor = 0
    for stage in stages:
        count = len(stage["tools"])
        stage["tools"] = tools[cursor:cursor + count]
        cursor += count
    if cursor != len(tools):
        raise ValueError(f"Fixture plan '{case['nome']}' does not cover all input tools")
    return stages


def run(name_or_tools, input_path, output_path, preview=False, progress_cb=None):
    """Execute a fixture-defined pipeline directly through service functions."""
    import sys

    repo_root = Path(__file__).resolve().parents[2]
    tools_root = repo_root / "Tools"
    mount_roots = [Path("/repo"), Path("/app"), repo_root]
    for mount_root in mount_roots:
        tools_candidate = mount_root / "Tools"
        if tools_candidate.is_dir() and str(tools_candidate) not in sys.path:
            sys.path.insert(0, str(tools_candidate))
    if str(repo_root) not in sys.path:
        sys.path.insert(0, str(repo_root))
    if str(tools_root) not in sys.path:
        sys.path.insert(0, str(tools_root))

    case = _find_plan(name_or_tools, preview)
    stages = (
        _stages_with_input_params(case, name_or_tools)
        if not isinstance(name_or_tools, str)
        else case["estagios"]
    )

    with tempfile.TemporaryDirectory(prefix="video-local-pipeline-") as work:
        current = str(Path(input_path).resolve())
        source_info = None
        result = None

        for index, stage in enumerate(stages):
            stage_preview = bool(stage.get("preview"))
            stage_range = stage.get("progressRange") or [0, 100]

            def stage_progress(percent):
                if progress_cb:
                    if index == len(stages) - 1 and percent == 100:
                        progress_cb(100)
                    else:
                        start, end = stage_range
                        progress_cb(int(start + (end - start) * percent / 100))

            final_stage = index == len(stages) - 1
            if final_stage and stage["service"] == "video_subtitles":
                final_output = Path(output_path).resolve()
                stage_output = str(Path(work) / "final-subtitles.mp4")
            elif final_stage:
                stage_output = str(Path(output_path).resolve())
            else:
                stage_output = str(Path(work) / f"stage-{index}.mp4")

            service = stage["service"]
            tools = stage["tools"]

            if service == "video_edit":
                from video_edit.video_edit import process_stage
                result = process_stage(
                    current, stage_output, tools, stage_progress,
                    stage_preview, source_info
                )
            elif service == "video_subtitles":
                from video_subtitles.subtitles import caption_video
                from video_common.probe import probe
                info = probe(current)
                result = dict(info)
                caption_video(current, stage_output, info, stage_progress)
                from video_common.probe import probe
                encoded = probe(stage_output)
                encoded["frames"] = round(encoded["duration"] * encoded["fps"])
                result = encoded
            elif service == "video_frames":
                from video_frames.frame_extraction import extract_frames
                from video_common.probe import probe
                info = source_info or probe(
                    current, prefer_video_duration=True
                )
                params = tools[-1].get("params", {}) if tools else {}
                result = extract_frames(
                    current, stage_output, info, params, stage_progress,
                    preview=stage_preview
                )
            else:
                raise RuntimeError(f"Unknown fixture stage service: {service}")

            if final_stage and service == "video_subtitles":
                os.replace(stage_output, final_output)
                stage_output = str(final_output)
            current = stage_output
            source_info = result

        if progress_cb:
            progress_cb(100)
        return result
