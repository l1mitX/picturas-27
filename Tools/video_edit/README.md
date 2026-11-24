# Video edit

RabbitMQ service that applies ordinary and temporal effects to videos.

- Queue: `video_edit_queue`
- Procedure: `video_edit`
- Microservice: `picturas-video-edit-ms`
- FFmpeg required
- Faster Whisper and subtitle dependencies are intentionally not included

## Tests

```bash
python3 -m pytest -q tests
```
