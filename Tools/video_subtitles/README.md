# Video subtitles

RabbitMQ service that runs the `subtitles` stage of a video pipeline: Faster-Whisper (CPU/int8) detects the spoken
language and the captions are burned into an MP4/H.264 + AAC. A video with no audio or no speech is a successful no-op.

- Queue: `video_subtitles_queue`
- Procedure: `video_subtitles`
- Microservice: `picturas-video-subtitles-ms`
- Stage tools: exactly `[subtitles]` (anything else is error 2002)
- The only video service with `faster-whisper` and the caption fonts (RE-002); the model is cached in the
  `whisper_models` volume (`WHISPER_MODEL`, `WHISPER_CPU_THREADS`, `WHISPER_CACHE_DIR`)
- The output is written to a temporary file and moved into place only on success

## Tests

The pipeline tests (`test_subtitles.py`) combine this service with the edit service through
`video_common/local_pipeline.py` and the plans in `projects/tests/fixtures/video_stage_plans.json`, so they need the
whole repository. They run on the host (ffmpeg/ffprobe on the PATH) and are skipped inside this service's image, where
only `test_video_subtitles.py` and the caption unit tests run.

```bash
cd Tools/video_subtitles && python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest -q tests
```
