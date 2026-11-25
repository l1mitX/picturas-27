# video_autoscaler (RNF1, TAT-02): adjusts the replicas of the video services from the size of
# their queues, through "docker compose up --scale" (research.md R1). Build context: ./Tools.

# Docker CLI and the Compose plugin, taken from the official image (static binaries).
FROM docker:27.3.1-cli AS docker-cli

FROM python:3.11-slim

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-compose \
     /usr/local/libexec/docker/cli-plugins/docker-compose

WORKDIR /app

COPY ./video_autoscaler/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ./video_autoscaler .

CMD ["python", "-u", "autoscaler.py"]
