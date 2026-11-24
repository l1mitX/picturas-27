"""PictuRAS video editing operations."""
import os
import subprocess
import tempfile

from PIL import Image

from video_common.exceptions import (
    InvalidSpeed,
    InvalidTrim,
    InvalidVideo,
    ProcessingError,
    UnsupportedEffect,
)
from video_common.frame_validation import InvalidExtraction, validate_params
from video_common.probe import probe
from effects import SUPPORTED, apply_frame_effects

PREVIEW_SECONDS = float(os.getenv("VIDEO_PREVIEW_SECONDS", "3"))
MIN_SPEED = 0.25
MAX_SPEED = 5.0


def resolve_trim(tools: list, duration: float) -> tuple:
    start, end = 0.0, float(duration)
    for tool in tools:
        if tool.get("procedure") != "trim":
            continue
        params = tool.get("params") or {}
        try:
            t_start = float(params.get("start", 0))
            t_end = float(params.get("end"))
        except (TypeError, ValueError):
            raise InvalidTrim("Trim requires numeric start and end (seconds)")
        length = end - start
        if t_start < 0 or t_end <= t_start:
            raise InvalidTrim("Trim end must be after its start")
        if t_start >= length or t_end > length + 1e-3:
            raise InvalidTrim(
                f"Trim [{t_start}, {t_end}] s is outside the video duration ({length:.2f} s)"
            )
        start, end = start + t_start, start + min(t_end, length)
    return start, end


def resolve_speed(tools: list) -> float:
    factor = 1.0
    for tool in tools:
        if tool.get("procedure") != "speed":
            continue
        try:
            value = float((tool.get("params") or {}).get("factor"))
        except (TypeError, ValueError):
            raise InvalidSpeed("Speed requires a numeric factor")
        if not MIN_SPEED <= value <= MAX_SPEED:
            raise InvalidSpeed(
                f"Speed must be between {MIN_SPEED}x and {MAX_SPEED}x (got {value}x)"
            )
        factor *= value
    return factor


def atempo_chain(factor: float) -> str:
    stages = []
    while factor > 2.0:
        stages.append(2.0)
        factor /= 2.0
    while factor < 0.5:
        stages.append(0.5)
        factor /= 0.5
    stages.append(factor)
    return ",".join(f"atempo={value:.6f}" for value in stages)


def validate_tools(tools: list) -> None:
    extractors = [
        index for index, tool in enumerate(tools)
        if tool.get("procedure") == "extract_frames"
    ]
    if extractors:
        if extractors != [len(tools) - 1]:
            raise InvalidExtraction(
                "Frame extraction must appear once, at the end of the pipeline"
            )
        validate_params(tools[-1].get("params", {}))
    for tool in tools:
        if tool.get("procedure") not in SUPPORTED | {"subtitles", "extract_frames"}:
            raise UnsupportedEffect(
                f"Effect '{tool.get('procedure')}' is not available for video"
            )


def _process_video(input_path: str, output_path: str, tools: list,
                   progress_cb=None, preview: bool = False) -> dict:
    validate_tools(tools)
    speed = resolve_speed(tools)
    info = probe(input_path)
    start, end = resolve_trim(tools, info["duration"])
    if preview:
        end = min(end, start + PREVIEW_SECONDS * speed)
    duration = end - start

    w, h = info["width"], info["height"]
    frame_bytes = w * h * 3
    expected_frames = max(1, round(duration / speed * info["fps"]))

    decode_cmd = [
        "ffmpeg", "-v", "error", "-ss", f"{start:.3f}", "-t", f"{duration:.3f}",
        "-i", input_path, "-map", "0:v:0", "-an",
        "-vf", f"setpts=PTS/{speed:.6f},fps={info['fps_str']}",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-",
    ]

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    tmp_out = output_path + ".part.mp4"
    dec_err = tempfile.TemporaryFile()
    enc_err = tempfile.TemporaryFile()
    decoder = subprocess.Popen(decode_cmd, stdout=subprocess.PIPE, stderr=dec_err)
    encoder = None
    frames = 0
    last_pct = -1

    try:
        while True:
            raw = decoder.stdout.read(frame_bytes)
            if len(raw) < frame_bytes:
                break
            frame = Image.frombytes("RGB", (w, h), raw)
            out = apply_frame_effects(frame, tools)

            if encoder is None:
                encoder = _start_encoder(
                    input_path, tmp_out, out.size, info,
                    start, duration, speed, enc_err
                )
            encoder.stdin.write(out.tobytes())
            frames += 1

            pct = min(99, int(frames * 100 / expected_frames))
            if progress_cb and pct != last_pct and (pct - last_pct >= 2 or pct == 99):
                last_pct = pct
                progress_cb(pct)

        decoder.stdout.close()
        if decoder.wait() != 0:
            raise ProcessingError(_read(dec_err) or "Failed to decode the video")
        if encoder is None:
            raise InvalidVideo("The video has no readable frames in the requested window")
        encoder.stdin.close()
        if encoder.wait() != 0:
            raise ProcessingError(_read(enc_err) or "Failed to encode the video")

        os.replace(tmp_out, output_path)
    except BaseException:
        for process in (decoder, encoder):
            if process and process.poll() is None:
                process.kill()
                process.wait()
        if os.path.exists(tmp_out):
            os.remove(tmp_out)
        raise
    finally:
        dec_err.close()
        enc_err.close()

    if progress_cb:
        progress_cb(100)

    result = probe(output_path)
    result["frames"] = frames
    return result


def _start_encoder(input_path, out_path, size, info, start, duration, speed, err_file):
    ow, oh = size
    cmd = [
        "ffmpeg", "-y", "-v", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{ow}x{oh}",
        "-r", info["fps_str"], "-i", "-",
    ]
    if info["has_audio"]:
        cmd += [
            "-ss", f"{start:.3f}", "-t", f"{duration:.3f}", "-i", input_path,
            "-map", "0:v:0", "-map", "1:a:0", "-c:a", "aac", "-b:a", "128k",
        ]
        if abs(speed - 1.0) > 1e-6:
            cmd += ["-af", atempo_chain(speed)]
    else:
        cmd += ["-map", "0:v:0"]
    cmd += [
        "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2",
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "23",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart",
        "-shortest", "-f", "mp4", out_path,
    ]
    return subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=err_file)


def _read(handle) -> str:
    handle.seek(0)
    return handle.read().decode(errors="replace").strip()[-500:]


def process_video(input_path: str, output_path: str, tools: list,
                  progress_cb=None, preview: bool = False) -> dict:
    """Compatibility entry for existing tests; normal stages call process_stage."""
    return _process_video(
        input_path, output_path, tools, progress_cb=progress_cb, preview=preview
    )
