FROM python:3.11-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ./video_edit ./video_edit
COPY ./video_common ./video_common
# Shared per-frame effects (Tools/effects/, one file per effect), also used by the image tools
COPY ./effects ./effects
COPY ./utils ./utils
RUN pip install --no-cache-dir -r ./video_common/requirements.txt
RUN pip install --no-cache-dir -r ./video_edit/requirements.txt

CMD ["python", "-u", "video_edit/video_edit.py"]
