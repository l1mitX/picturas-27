"""Tests for the replica policy (RNF1 T016; research.md R3; data-model.md "Política de réplicas").

The numbers used here are test values, not the team's parameters (RNF1 T003).
"""
import pytest

from policy import Policy, action, desired_replicas, policy_from_spec, target_replicas

EDIT = Policy(service="video_edit", queue="video_edit_queue", min=1, max=4, per_replica=1, cooldown_s=30)


# ------------------------------------------------------------------ scaling up
def test_scales_up_at_once_to_the_desired_count():
    assert target_replicas(pending=3, current=1, policy=EDIT, below_since=None, now=100.0) == (3, None)


def test_scales_up_at_once_but_never_above_max():
    assert target_replicas(pending=50, current=1, policy=EDIT, below_since=None, now=100.0) == (4, None)


def test_load_back_during_cooldown_cancels_scale_down():
    # Was waiting to go down since t=90, but the queue grew again: keep the replicas, reset the timer.
    assert target_replicas(pending=4, current=4, policy=EDIT, below_since=90.0, now=100.0) == (4, None)


# ------------------------------------------------------------------ minimum
def test_never_below_min_with_empty_queue():
    target, _ = target_replicas(pending=0, current=1, policy=EDIT, below_since=None, now=100.0)
    assert target == 1


def test_never_below_min_after_cooldown():
    policy = Policy(service="video_edit", queue="video_edit_queue", min=2, max=4, per_replica=1, cooldown_s=30)
    assert target_replicas(pending=0, current=4, policy=policy, below_since=0.0, now=100.0) == (2, None)


def test_restores_min_when_current_is_below_it():
    # e.g., a replica died and was not restarted yet
    assert target_replicas(pending=0, current=0, policy=EDIT, below_since=None, now=100.0) == (1, None)


# ------------------------------------------------------------------ scaling down
def test_does_not_scale_down_on_first_low_reading():
    # First time the target is below the current count: hold and start the timer.
    assert target_replicas(pending=0, current=4, policy=EDIT, below_since=None, now=100.0) == (4, 100.0)


def test_does_not_scale_down_before_cooldown():
    assert target_replicas(pending=0, current=4, policy=EDIT, below_since=100.0, now=129.9) == (4, 100.0)


def test_scales_down_after_cooldown():
    assert target_replicas(pending=0, current=4, policy=EDIT, below_since=100.0, now=130.0) == (1, None)


def test_scales_down_to_the_desired_count_not_straight_to_min():
    assert target_replicas(pending=2, current=4, policy=EDIT, below_since=100.0, now=130.0) == (2, None)


def test_zero_cooldown_scales_down_at_once():
    policy = Policy(service="video_frames", queue="video_frames_queue", min=1, max=2, per_replica=1, cooldown_s=0)
    assert target_replicas(pending=0, current=2, policy=policy, below_since=None, now=100.0) == (1, None)


def test_above_max_goes_down_after_cooldown():
    # e.g., someone ran --scale by hand above the maximum
    assert target_replicas(pending=10, current=6, policy=EDIT, below_since=None, now=100.0) == (6, 100.0)
    assert target_replicas(pending=10, current=6, policy=EDIT, below_since=100.0, now=130.0) == (4, None)


def test_steady_state_holds_and_keeps_no_timer():
    assert target_replicas(pending=2, current=2, policy=EDIT, below_since=None, now=100.0) == (2, None)


# ------------------------------------------------------------------ per_replica
@pytest.mark.parametrize("pending, expected", [(0, 1), (1, 1), (2, 1), (3, 2), (4, 2), (5, 3), (6, 3), (7, 3)])
def test_per_replica_rounds_up(pending, expected):
    policy = Policy(service="video_edit", queue="video_edit_queue", min=1, max=3, per_replica=2, cooldown_s=30)
    assert desired_replicas(pending, policy) == expected


def test_per_replica_respected_when_scaling_up():
    policy = Policy(service="video_edit", queue="video_edit_queue", min=1, max=4, per_replica=2, cooldown_s=30)
    assert target_replicas(pending=5, current=1, policy=policy, below_since=None, now=0.0) == (3, None)


def test_negative_pending_is_rejected():
    with pytest.raises(ValueError):
        desired_replicas(-1, EDIT)


# ------------------------------------------------------------------ policy rules
@pytest.mark.parametrize("kwargs", [
    {"min": 0},                       # min >= 1: there is always a consumer
    {"min": 3, "max": 2},             # max >= min
    {"per_replica": 0},               # per_replica >= 1
    {"cooldown_s": -1},               # cooldown_s >= 0
])
def test_invalid_policy_is_rejected(kwargs):
    fields = {"service": "video_edit", "queue": "video_edit_queue", "min": 1, "max": 4, "per_replica": 1,
              "cooldown_s": 30, **kwargs}
    with pytest.raises(ValueError):
        Policy(**fields)


def test_min_equal_to_max_is_allowed():
    policy = Policy(service="video_subtitles", queue="video_subtitles_queue", min=1, max=1, per_replica=1,
                    cooldown_s=30)
    assert target_replicas(pending=9, current=1, policy=policy, below_since=None, now=0.0) == (1, None)


# ------------------------------------------------------------------ SCALE_<SERVICE> spec
def test_policy_from_spec():
    policy = policy_from_spec("video_edit", "video_edit_queue:1:4:1", cooldown_s=30)
    assert policy == EDIT


@pytest.mark.parametrize("spec", ["video_edit_queue:1:4", "video_edit_queue:a:4:1", ":1:4:1", "q:0:4:1"])
def test_policy_from_bad_spec_is_rejected(spec):
    with pytest.raises(ValueError):
        policy_from_spec("video_edit", spec, cooldown_s=30)


# ------------------------------------------------------------------ event action
@pytest.mark.parametrize("current, target, expected", [(1, 3, "up"), (3, 1, "down"), (2, 2, "hold")])
def test_action(current, target, expected):
    assert action(current, target) == expected
