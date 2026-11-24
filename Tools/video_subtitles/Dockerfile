FROM python:3.11-slim

# ffmpeg/ffprobe and the caption fonts; the only video image with them
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg fonts-dejavu-core fonts-noto-core fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ./video_subtitles ./video_subtitles
COPY ./video_common ./video_common
COPY ./utils ./utils
RUN pip install --no-cache-dir -r ./video_common/requirements.txt
# faster-whisper: only this service depends on it (RE-002)
RUN pip install --no-cache-dir -r ./video_subtitles/requirements.txt

CMD ["python", "-u", "video_subtitles/video_subtitles.py"]
