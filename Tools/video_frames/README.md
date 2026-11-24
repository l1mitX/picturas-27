# Video frames

RabbitMQ service that runs the terminal `extract_frames` stage of a video pipeline: a fixed count (1–100) or an
interval, PNG or JPEG, at most 100 images per video. Full output is a frame manifest; preview output is a contact sheet.

- Queue: `video_frames_queue`
- Procedure: `video_frames`
- Microservice: `picturas-video-frames-ms`
- Stage tools: exactly `[extract_frames]` (anything else is error 2002)
- `parameters.sourceInfo`: the `video_info` of the previous edit stage, forwarded by `projects`; used instead of probing
  again so the sampled times match the base (R5). Without it the input is probed preferring the video duration
- No `faster-whisper` and no caption fonts

## Tests

Extraction-only tests call `process_stage` directly. The tests that combine extraction with edits or captions go
through `video_common/local_pipeline.py` and need the whole repository; without it they are skipped.

On the host (ffmpeg/ffprobe on the PATH):

```bash
cd Tools/video_frames && python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest -q tests
```

Inside Docker, from the repository root (mounting the repository gives the tests the stage plans in
`projects/tests/fixtures/` and the code of the other video services, used by `local_pipeline.py`):

```bash
docker compose run --rm --no-deps -T -v "<repo>:/repo" -w /repo/Tools/video_frames video_frames \
  sh -c "pip install -q pytest && python -m pytest -q -p no:cacheprovider tests"
```
