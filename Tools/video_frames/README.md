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

Extraction-only tests call `process_stage` directly and also run inside this service's image. The tests that combine
extraction with edits or captions go through `video_common/local_pipeline.py` and need the whole repository (host).

```bash
cd Tools/video_frames && python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest -q tests
```
