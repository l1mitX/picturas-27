# Video autoscaler

Service that adjusts the number of replicas of each video service (`video_edit`, `video_subtitles`,
`video_frames`) to the size of its queue (RNF1, DA-1, TAT-02; `specs/002-rnf1-capacidade/research.md`, R1–R3).

## What it does

Every `POLL_SECONDS`, for each video service:

1. reads `messages_ready + messages_unacknowledged` of its queue from the RabbitMQ management API;
2. counts the running replicas of the service;
3. computes the target with `policy.py`: `ceil(pending / per_replica)`, within `[min, max]`. It scales up at once and
   scales down only after the target has stayed below the current count for `COOLDOWN_SECONDS`;
4. when the target changes, runs in the background
   `docker compose -p <project> up -d --no-build --no-recreate --no-deps --scale <service>=<N> <service>`,
   with at most one command in progress per service.

When a replica is removed, Compose sends it `SIGTERM`. The worker (`Tools/video_common/worker.py`) stops consuming,
finishes the stage in progress, acknowledges it and exits (graceful stop, TAT-13), within the service's
`stop_grace_period`.

If the RabbitMQ API or Docker fails, nothing changes and the next poll tries again.

## Configuration (environment variables)

| Variable | Value in `docker-compose.yaml` | Meaning |
|---|---|---|
| `COMPOSE_PROJECT_NAME` | `picturas` | Compose project to adjust. Must be the one the application was started with |
| `COMPOSE_FILE` | `/compose/docker-compose.yaml` | The repository's Compose file, mounted read-only |
| `RABBITMQ_API` | `http://rabbitmq:15672` | RabbitMQ management API |
| `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD` | as the other services | API credentials |
| `POLL_SECONDS` | `5` | Interval between polls |
| `COOLDOWN_SECONDS` | `60` | Wait before removing replicas |
| `SCALE_<SERVICE>` | `video_edit_queue:1:4:1` | `queue:min:max:per_replica`, one per service |

Values decided by the team in T003 (`docs/fase2/T003-decisao-equipa.md`): edit 1–4, subtitles 1–1, frames 1–2,
1 pending message per replica. On a bigger machine, raise the maximums here (and the memory limits of the video
services, `deploy.resources.limits.memory`).

## Log

One JSON line per decision that changes something, read by `docs/fase2/medicoes/elasticidade_m4.py` (M4):

```json
{"ts": "2026-11-25T18:00:05.123+00:00", "service": "video_edit", "pending": 3, "current": 1, "target": 3, "action": "up"}
```

`hold` lines appear only when the pending count or the replica count changes. Failures are logged as
`{"event": "error", "service": ..., "error": ...}`.

```bash
docker compose logs -f video_autoscaler
```

## Risk: the Docker socket

The service mounts `/var/run/docker.sock` to run `docker compose`. Whoever controls this container controls Docker on
the host (it can start any container, with any volume). Mitigations:

- it is the only service with the socket, and it exposes no port;
- it only reads environment variables set in `docker-compose.yaml`; it runs no input from users or messages;
- the Compose file is mounted read-only.

In production, the alternative is an orchestrator with its own autoscaling (e.g., Kubernetes HPA), which the
constitution leaves out of scope for this project.

## Turning it off

To test fixed replicas by hand (e.g., `docker compose up -d --scale video_edit=2`), stop it first, or it will bring
the services back to their minimum after `COOLDOWN_SECONDS`:

```bash
docker compose stop video_autoscaler
```

## Tests

```bash
cd Tools/video_autoscaler && python3 -m pip install -r requirements.txt pytest && python3 -m pytest -q tests
```

The tests use fake RabbitMQ and Docker functions; they need neither running.
