"""Replica policy of the video_autoscaler (RNF1, TAT-02; research.md R3).

Pure functions: no Docker, no RabbitMQ, no clock. The caller keeps `below_since` between polls
and passes the current time, so every decision can be tested on its own.

    target = clamp(ceil(pending / per_replica), min, max)

Scaling up happens at once. Scaling down only happens after the target has stayed below the
current count for `cooldown_s` seconds, to avoid flapping and needless graceful stops (TAT-13).
"""
from dataclasses import dataclass
import math


@dataclass(frozen=True)
class Policy:
    """Scaling rules for one video service (data-model.md, "Política de réplicas")."""

    service: str       # Compose service name, e.g. "video_edit"
    queue: str         # RabbitMQ queue it consumes, e.g. "video_edit_queue"
    min: int           # >= 1: there is always a consumer
    max: int           # >= min
    per_replica: int   # pending messages per replica, >= 1
    cooldown_s: float  # wait before removing replicas, >= 0

    def __post_init__(self):
        if not self.service or not self.queue:
            raise ValueError("service and queue are required")
        if self.min < 1:
            raise ValueError(f"{self.service}: min must be >= 1 (got {self.min})")
        if self.max < self.min:
            raise ValueError(f"{self.service}: max must be >= min (got {self.min}..{self.max})")
        if self.per_replica < 1:
            raise ValueError(f"{self.service}: per_replica must be >= 1 (got {self.per_replica})")
        if self.cooldown_s < 0:
            raise ValueError(f"{self.service}: cooldown_s must be >= 0 (got {self.cooldown_s})")


def policy_from_spec(service, spec, cooldown_s):
    """Build a Policy from a SCALE_<SERVICE> value, "queue:min:max:per_replica".

    e.g. policy_from_spec("video_edit", "video_edit_queue:1:4:1", 30)
    (contracts/autoscaler-e-workers.md).
    """
    parts = spec.strip().split(":")
    if len(parts) != 4:
        raise ValueError(f"{service}: expected 'queue:min:max:per_replica', got {spec!r}")
    queue, low, high, per_replica = parts
    try:
        low, high, per_replica = int(low), int(high), int(per_replica)
    except ValueError:
        raise ValueError(f"{service}: min, max and per_replica must be integers, got {spec!r}") from None
    return Policy(service=service, queue=queue, min=low, max=high, per_replica=per_replica,
                  cooldown_s=float(cooldown_s))


def desired_replicas(pending, policy):
    """Replicas the pending work asks for, within [min, max], ignoring the cooldown."""
    if pending < 0:
        raise ValueError(f"pending must be >= 0 (got {pending})")
    wanted = math.ceil(pending / policy.per_replica)
    return max(policy.min, min(policy.max, wanted))


def target_replicas(pending, current, policy, below_since, now):
    """Decide the replica count for one poll.

    pending      messages_ready + messages_unacknowledged of the service's queue (R2)
    current      replicas running now
    below_since  time when the target first fell below `current` (None if it is not below)
    now          current time, in seconds, same clock as `below_since`

    Returns (target, below_since) where `below_since` is the value to pass on the next poll.
    """
    wanted = desired_replicas(pending, policy)
    if wanted >= current:
        # Scale up (or hold) at once; any pending scale-down is cancelled.
        return wanted, None
    since = now if below_since is None else below_since
    if now - since >= policy.cooldown_s:
        return wanted, None
    return current, since


def action(current, target):
    """Event label for the autoscaler log (data-model.md, "Evento")."""
    if target > current:
        return "up"
    if target < current:
        return "down"
    return "hold"
