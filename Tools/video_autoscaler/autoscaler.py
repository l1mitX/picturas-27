"""video_autoscaler (RNF1, DA-1, TAT-02): adjusts the replicas of each video service to the size of its queue.

Every POLL_SECONDS, for each video service (research.md R1-R3):
  1. reads messages_ready + messages_unacknowledged of its queue from the RabbitMQ management API (R2);
  2. counts the running replicas of the service;
  3. applies policy.target_replicas (scale up at once, scale down only after COOLDOWN_SECONDS);
  4. when the target changes, runs in the background
       docker compose -p $COMPOSE_PROJECT_NAME up -d --no-build --no-recreate --no-deps --scale <svc>=<N> <svc>
     with at most one command in progress per service, so that a slow scale-down (graceful stop of a replica in the
     middle of a stage, R4) never delays the other services (R1, care 2).

Each decision that changes something is logged as one JSON line (data-model.md, "Evento"), read by
docs/fase2/medicoes/elasticidade_m4.py (R10). If the RabbitMQ API or Docker fails, nothing changes for that service
and the next poll tries again.

Configuration (contracts/autoscaler-e-workers.md): COMPOSE_PROJECT_NAME, RABBITMQ_API, RABBITMQ_USERNAME,
RABBITMQ_PASSWORD, POLL_SECONDS, COOLDOWN_SECONDS and one SCALE_<SERVICE>=queue:min:max:per_replica per service
(e.g. SCALE_VIDEO_EDIT=video_edit_queue:1:4:1). The Compose file is found through COMPOSE_FILE.
"""
from datetime import datetime, timezone
import json
import os
import subprocess
import sys
import time
from urllib.parse import quote

from policy import action, policy_from_spec, target_replicas

SCALE_PREFIX = "SCALE_"


def now_iso():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def log(**fields):
    print(json.dumps({"ts": now_iso(), **fields}), flush=True)


# ------------------------------------------------------------------ configuration
def load_config(env):
    """Policies and settings from the environment. Raises ValueError on a bad or missing value."""
    cooldown = float(env.get("COOLDOWN_SECONDS", "60"))
    poll = float(env.get("POLL_SECONDS", "5"))
    if poll <= 0:
        raise ValueError(f"POLL_SECONDS must be > 0 (got {poll})")
    policies = [
        policy_from_spec(name[len(SCALE_PREFIX):].lower(), value, cooldown)
        for name, value in sorted(env.items())
        if name.startswith(SCALE_PREFIX) and value.strip()
    ]
    if not policies:
        raise ValueError("no SCALE_<SERVICE> variable: nothing to scale")
    project = env.get("COMPOSE_PROJECT_NAME", "").strip()
    if not project:
        raise ValueError("COMPOSE_PROJECT_NAME is required (it must be the project started by the team, R1)")
    return {
        "policies": policies,
        "poll_s": poll,
        "project": project,
        "api": env.get("RABBITMQ_API", "http://rabbitmq:15672").rstrip("/"),
        "auth": (env.get("RABBITMQ_USERNAME", "guest"), env.get("RABBITMQ_PASSWORD", "guest")),
    }


# ------------------------------------------------------------------ real RabbitMQ and Docker
def rabbit_pending(api, auth, queue, http_get=None):
    """messages_ready + messages_unacknowledged of one queue (R2)."""
    if http_get is None:
        import requests
        http_get = requests.get
    response = http_get(f"{api}/api/queues/%2F/{quote(queue, safe='')}", auth=auth, timeout=5)
    response.raise_for_status()
    data = response.json()
    return int(data.get("messages_ready", 0) or 0) + int(data.get("messages_unacknowledged", 0) or 0)


def compose_replicas(project, service, run=subprocess.run):
    """Running replicas of a service in the Compose project."""
    out = run(["docker", "compose", "-p", project, "ps", "-q", "--status", "running", service],
              capture_output=True, text=True, timeout=30, check=True).stdout
    return len([line for line in out.splitlines() if line.strip()])


def compose_scale(project, service, replicas, popen=subprocess.Popen):
    """Starts the scale command in the background and returns the process (R1)."""
    return popen(["docker", "compose", "-p", project, "up", "-d", "--no-build", "--no-recreate", "--no-deps",
                  "--scale", f"{service}={replicas}", service],
                 stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)


# ------------------------------------------------------------------ decisions
class Autoscaler:
    """One poll at a time (tick); the side effects come in as functions, so tests need no Docker."""

    def __init__(self, policies, pending, replicas, scale, clock=time.monotonic, emit=log):
        self.policies = policies
        self.pending, self.replicas, self.scale = pending, replicas, scale
        self.clock, self.emit = clock, emit
        self.below_since = {p.service: None for p in policies}
        self.running = {}     # service -> (process, target) of the command in progress
        self.last_seen = {}   # service -> (pending, current) last logged, to log holds only on change

    def tick(self):
        for policy in self.policies:
            try:
                self._tick_service(policy)
            except Exception as exc:  # noqa: BLE001 - one service failing never stops the others
                self.emit(event="error", service=policy.service, error=str(exc)[:300])

    def _tick_service(self, policy):
        service = policy.service
        if not self._command_finished(service):
            return  # at most one command in progress per service (R1, care 2)

        pending = self.pending(policy.queue)
        current = self.replicas(service)
        target, self.below_since[service] = target_replicas(
            pending, current, policy, self.below_since[service], self.clock())
        decision = action(current, target)

        if decision == "hold":
            if self.last_seen.get(service) != (pending, current):
                self.last_seen[service] = (pending, current)
                self.emit(service=service, pending=pending, current=current, target=target, action="hold")
            return

        self.last_seen[service] = (pending, current)
        self.emit(service=service, pending=pending, current=current, target=target, action=decision)
        self.running[service] = (self.scale(service, target), target)

    def _command_finished(self, service):
        entry = self.running.get(service)
        if entry is None:
            return True
        process, target = entry
        code = process.poll()
        if code is None:
            return False
        del self.running[service]
        if code != 0:
            error = (process.stderr.read() if process.stderr else "") or ""
            self.emit(event="error", service=service, target=target,
                      error=f"docker compose exited with {code}: {error.strip()[-300:]}")
        return True


def main(env=None):
    env = dict(os.environ if env is None else env)
    try:
        config = load_config(env)
    except ValueError as exc:
        log(event="config_error", error=str(exc))
        return 2
    project = config["project"]
    scaler = Autoscaler(
        config["policies"],
        pending=lambda queue: rabbit_pending(config["api"], config["auth"], queue),
        replicas=lambda service: compose_replicas(project, service),
        scale=lambda service, n: compose_scale(project, service, n),
    )
    log(event="start", project=project, poll_s=config["poll_s"],
        policies=[{"service": p.service, "queue": p.queue, "min": p.min, "max": p.max,
                   "per_replica": p.per_replica, "cooldown_s": p.cooldown_s} for p in config["policies"]])
    while True:
        started = time.monotonic()
        scaler.tick()
        time.sleep(max(0.0, config["poll_s"] - (time.monotonic() - started)))


if __name__ == "__main__":
    sys.exit(main())
