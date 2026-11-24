FROM python:3.11-slim

# ffmpeg/ffprobe only: no caption fonts and no faster-whisper (RE-002)
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ./video_frames ./video_frames
COPY ./video_common ./video_common
COPY ./utils ./utils
RUN pip install --no-cache-dir -r ./video_common/requirements.txt

CMD ["python", "-u", "video_frames/video_frames.py"]
