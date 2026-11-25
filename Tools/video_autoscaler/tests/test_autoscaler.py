"""RNF1 T018: the autoscaler loop (autoscaler.py), with fake RabbitMQ and Docker.

The replica policy itself is tested in test_policy.py (T016); here only what the loop adds: configuration,
reading the queues, one command in progress per service, logging and failures.
"""
import json
import subprocess

import pytest

import autoscaler
from autoscaler import Autoscaler, compose_replicas, compose_scale, load_config, rabbit_pending
from policy import Policy

EDIT = Policy("video_edit", "video_edit_queue", 1, 4, 1, 60)
FRAMES = Policy("video_frames", "video_frames_queue", 1, 2, 1, 60)


class FakeProcess:
    def __init__(self, code=None, stderr=""):
        self.code, self.stderr = code, _Text(stderr)

    def poll(self):
        return self.code


class _Text:
    def __init__(self, text):
        self.text = text

    def read(self):
        return self.text


class World:
    """Queues, replicas, clock and log of one test."""

    def __init__(self, pending, replicas):
        self.pending, self.replicas = dict(pending), dict(replicas)
        self.now, self.events, self.commands = 0.0, [], []
        self.process = FakeProcess(code=None)

    def scaler(self, policies):
        return Autoscaler(
            policies,
            pending=lambda queue: self.pending[queue],
            replicas=lambda service: self.replicas[service],
            scale=self.scale,
            clock=lambda: self.now,
            emit=lambda **fields: self.events.append(fields),
        )

    def scale(self, service, n):
        self.commands.append((service, n))
        return self.process


# ------------------------------------------------------------------ configuration
def test_config_reads_one_policy_per_scale_variable():
    config = load_config({
        "COMPOSE_PROJECT_NAME": "picturas", "POLL_SECONDS": "5", "COOLDOWN_SECONDS": "60",
        "SCALE_VIDEO_EDIT": "video_edit_queue:1:4:1",
        "SCALE_VIDEO_SUBTITLES": "video_subtitles_queue:1:1:1",
        "SCALE_VIDEO_FRAMES": "video_frames_queue:1:2:1",
        "RABBITMQ_USERNAME": "user", "RABBITMQ_PASSWORD": "password",
    })
    assert [(p.service, p.queue, p.min, p.max, p.cooldown_s) for p in config["policies"]] == [
        ("video_edit", "video_edit_queue", 1, 4, 60.0),
        ("video_frames", "video_frames_queue", 1, 2, 60.0),
        ("video_subtitles", "video_subtitles_queue", 1, 1, 60.0),
    ]
    assert config["poll_s"] == 5.0 and config["project"] == "picturas"
    assert config["auth"] == ("user", "password")


@pytest.mark.parametrize("env", [
    {"SCALE_VIDEO_EDIT": "video_edit_queue:1:4:1"},                                  # no project name (R1, care 1)
    {"COMPOSE_PROJECT_NAME": "picturas"},                                            # nothing to scale
    {"COMPOSE_PROJECT_NAME": "picturas", "SCALE_VIDEO_EDIT": "video_edit_queue:0:4:1"},  # min < 1
    {"COMPOSE_PROJECT_NAME": "picturas", "SCALE_VIDEO_EDIT": "video_edit_queue:1:4:1", "POLL_SECONDS": "0"},
])
def test_bad_configuration_is_rejected(env):
    with pytest.raises(ValueError):
        load_config(env)


def test_main_exits_with_an_error_on_bad_configuration(capsys):
    assert autoscaler.main({}) == 2
    assert json.loads(capsys.readouterr().out)["event"] == "config_error"


# ------------------------------------------------------------------ real RabbitMQ and Docker (commands only)
def test_pending_is_ready_plus_unacknowledged():
    calls = []

    class Response:
        def raise_for_status(self):
            pass

        def json(self):
            return {"messages_ready": 3, "messages_unacknowledged": 1}

    def http_get(url, auth, timeout):
        calls.append((url, auth))
        return Response()

    assert rabbit_pending("http://rabbitmq:15672", ("u", "p"), "video_edit_queue", http_get) == 4
    assert calls == [("http://rabbitmq:15672/api/queues/%2F/video_edit_queue", ("u", "p"))]


def test_replicas_counts_running_containers_of_the_project():
    seen = []

    def run(cmd, **kwargs):
        seen.append(cmd)
        return subprocess.CompletedProcess(cmd, 0, stdout="abc\ndef\n")

    assert compose_replicas("picturas", "video_edit", run) == 2
    assert seen == [["docker", "compose", "-p", "picturas", "ps", "-q", "--status", "running", "video_edit"]]


def test_scale_command_touches_only_the_service():
    seen = []
    compose_scale("picturas", "video_edit", 3, popen=lambda cmd, **kwargs: seen.append(cmd))
    assert seen == [["docker", "compose", "-p", "picturas", "up", "-d", "--no-build", "--no-recreate",
                     "--no-deps", "--scale", "video_edit=3", "video_edit"]]


# ------------------------------------------------------------------ decisions
def test_scales_up_and_logs_the_decision():
    world = World({"video_edit_queue": 3}, {"video_edit": 1})
    world.scaler([EDIT]).tick()
    assert world.commands == [("video_edit", 3)]
    assert world.events == [{"service": "video_edit", "pending": 3, "current": 1, "target": 3, "action": "up"}]


def test_one_command_at_a_time_per_service_without_blocking_the_others():
    world = World({"video_edit_queue": 4, "video_frames_queue": 0}, {"video_edit": 1, "video_frames": 1})
    scaler = world.scaler([EDIT, FRAMES])
    scaler.tick()
    assert world.commands == [("video_edit", 4)]

    # The edit command is still running (e.g., a slow graceful stop): no new edit command, even if the
    # queue changes, but the frames service is still polled and scaled.
    world.pending["video_edit_queue"] = 0
    world.pending["video_frames_queue"] = 2
    world.now = 100
    scaler.tick()
    assert world.commands == [("video_edit", 4), ("video_frames", 2)]

    # Once the edit command ends, the edit service is polled again.
    world.process.code = 0
    world.replicas["video_edit"] = 4
    world.pending["video_edit_queue"] = 4
    scaler.tick()
    assert [e["action"] for e in world.events if e["service"] == "video_edit"] == ["up", "hold"]


def test_scale_down_waits_for_the_cooldown():
    world = World({"video_edit_queue": 0}, {"video_edit": 4})
    scaler = world.scaler([EDIT])
    scaler.tick()                 # t = 0: target below current, cooldown starts
    world.now = 59
    scaler.tick()
    assert world.commands == []
    world.now = 60
    scaler.tick()
    assert world.commands == [("video_edit", 1)]
    assert world.events[-1]["action"] == "down"


def test_hold_is_logged_only_when_something_changes():
    world = World({"video_edit_queue": 1}, {"video_edit": 1})
    scaler = world.scaler([EDIT])
    for _ in range(3):
        scaler.tick()
    world.pending["video_edit_queue"] = 0
    scaler.tick()
    assert [(e["pending"], e["action"]) for e in world.events] == [(1, "hold"), (0, "hold")]


def test_api_failure_changes_nothing_and_the_next_poll_tries_again():
    world = World({"video_edit_queue": 2}, {"video_edit": 1})
    scaler = world.scaler([EDIT])
    scaler.pending = lambda queue: (_ for _ in ()).throw(ConnectionError("rabbitmq down"))
    scaler.tick()
    assert world.commands == []
    assert world.events == [{"event": "error", "service": "video_edit", "error": "rabbitmq down"}]

    scaler.pending = lambda queue: world.pending[queue]
    scaler.tick()
    assert world.commands == [("video_edit", 2)]


def test_failed_docker_command_is_logged_and_retried():
    world = World({"video_edit_queue": 2}, {"video_edit": 1})
    world.process = FakeProcess(code=1, stderr="no such service")
    scaler = world.scaler([EDIT])
    scaler.tick()
    scaler.tick()  # the command failed: logged, and the decision is taken again
    errors = [e for e in world.events if e.get("event") == "error"]
    assert errors and "no such service" in errors[0]["error"]
    assert world.commands == [("video_edit", 2), ("video_edit", 2)]
