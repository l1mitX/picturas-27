# Video edit

RabbitMQ service that applies ordinary and temporal effects to videos.

- Queue: `video_edit_queue`
- Procedure: `video_edit`
- Microservice: `picturas-video-edit-ms`
- FFmpeg required
- Faster Whisper and subtitle dependencies are intentionally not included
- Per-frame effects come from `Tools/effects/` (one file per effect, shared with the image tools);
  `frame_effects.py` only maps each `procedure` to its function

## Tests

On the host (ffmpeg/ffprobe on the PATH):

```bash
cd Tools/video_edit && python3 -m pytest -q tests
```

Inside Docker, from the repository root (mounting the repository gives the tests the stage plans in
`projects/tests/fixtures/` and the code of the other video services, used by `local_pipeline.py`):

```bash
docker compose run --rm --no-deps -T -v "<repo>:/repo" -w /repo/Tools/video_edit video_edit \
  sh -c "pip install -q pytest && python -m pytest -q -p no:cacheprovider tests"
```
