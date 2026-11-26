"""Tests for the M4 calculations of elasticidade_m4.py (RNF1 T021, R10), with sample logs.

The log formats are the ones in specs/002-rnf1-capacidade/contracts/autoscaler-e-workers.md and data-model.md.
"""
from datetime import datetime, timedelta, timezone

import pytest

from elasticidade_m4 import autoscaler_events, first_messages, parse_logs, round_metrics, summarize

T0 = datetime(2026, 11, 26, 10, 0, 0, tzinfo=timezone.utc)


def at(seconds):
    return T0 + timedelta(seconds=seconds)


LOGS = """\
video_edit-1  | 2026-11-26T09:55:00.000000000Z [video] waiting for jobs on video_edit_queue
video_edit-1  | 2026-11-26T09:58:00.123456789Z {"ts": "2026-11-26T09:58:00Z", "event": "first_message", "queue": "video_edit_queue"}
video_autoscaler-1  | 2026-11-26T10:00:04.500000000Z {"ts": "2026-11-26T10:00:04Z", "service": "video_edit", "pending": 4, "current": 1, "target": 4, "action": "up"}
video_autoscaler-1  | 2026-11-26T10:00:04.600000000Z {"ts": "2026-11-26T10:00:04Z", "service": "video_frames", "pending": 0, "current": 1, "target": 1, "action": "hold"}
video_edit-2  | 2026-11-26T10:00:09.000000000Z [video] waiting for jobs on video_edit_queue
video_edit-2  | 2026-11-26T10:00:09.250000000Z {"ts": "2026-11-26T10:00:09Z", "event": "first_message", "queue": "video_edit_queue"}
video_edit-3  | 2026-11-26T10:00:10.000000000Z {"ts": "2026-11-26T10:00:10Z", "event": "first_message", "queue": "video_edit_queue"}
video_edit-3  | 2026-11-26T10:00:15.000000000Z {"ts": "2026-11-26T10:00:15Z", "event": "first_message", "queue": "video_edit_queue"}
video_frames-1  | 2026-11-26T10:00:11.000000000Z {"ts": "2026-11-26T10:00:11Z", "event": "first_message", "queue": "video_frames_queue"}
video_autoscaler-1  | 2026-11-26T10:00:55.000000000Z {"ts": "2026-11-26T10:00:55Z", "service": "video_edit", "pending": 0, "current": 4, "target": 1, "action": "down"}
"""


# ------------------------------------------------------------------ reading the logs
def test_parse_logs_reads_container_docker_time_and_message():
    lines = parse_logs(LOGS)
    assert lines[0].container == "video_edit-1"
    assert lines[0].ts == datetime(2026, 11, 26, 9, 55, 0, tzinfo=timezone.utc)
    assert lines[1].ts == datetime(2026, 11, 26, 9, 58, 0, 123456, tzinfo=timezone.utc)  # nanoseconds truncated
    assert lines[0].msg.startswith("[video] waiting")


def test_parse_logs_skips_lines_it_cannot_read():
    lines = parse_logs("Attaching to video_edit-1\n\nvideo_edit-1  | not-a-timestamp hello\n" + LOGS)
    assert len(lines) == len(LOGS.strip().splitlines())


def test_first_messages_keeps_the_earliest_per_container_and_queue():
    firsts = first_messages(parse_logs(LOGS), "video_edit_queue")
    assert firsts == {
        "video_edit-1": datetime(2026, 11, 26, 9, 58, 0, 123456, tzinfo=timezone.utc),
        "video_edit-2": at(9.25),
        "video_edit-3": at(10),
    }


def test_autoscaler_events_only_for_the_service():
    events = autoscaler_events(parse_logs(LOGS), "video_edit")
    assert [(e["action"], e["target"], e["log_ts"]) for e in events] == [("up", 4, at(4.5)), ("down", 1, at(55))]


# ------------------------------------------------------------------ one round
def test_round_metrics_m4_is_from_submission_to_first_new_replica_consuming():
    lines = parse_logs(LOGS)
    m = round_metrics(t0=at(0), t_done=at(20), start_replicas={"video_edit-1"},
                      firsts=first_messages(lines, "video_edit_queue"),
                      events=autoscaler_events(lines, "video_edit"), t_back_min=at(52))
    assert m["m4_s"] == pytest.approx(9.25)            # video_edit-2 consumed 9.25 s after submission
    assert m["reacao_ajuste_s"] == pytest.approx(4.5)  # first "up" decision
    assert m["arranque_s"] == pytest.approx(4.75)      # from the decision to the new replica consuming
    assert m["replicas_novas"] == 2
    assert m["replicas_max"] == 4
    assert m["volta_ao_minimo_s"] == pytest.approx(32)  # from the last job done to back at the minimum


def test_a_replica_that_existed_before_the_round_is_not_new():
    lines = parse_logs(LOGS)
    m = round_metrics(t0=at(0), t_done=at(20), start_replicas={"video_edit-1", "video_edit-2"},
                      firsts=first_messages(lines, "video_edit_queue"),
                      events=autoscaler_events(lines, "video_edit"), t_back_min=at(52))
    assert m["m4_s"] == pytest.approx(10)  # only video_edit-3 is new
    assert m["replicas_novas"] == 1


def test_events_before_the_round_are_ignored():
    lines = parse_logs(LOGS)
    m = round_metrics(t0=at(5), t_done=at(20), start_replicas={"video_edit-1"},
                      firsts=first_messages(lines, "video_edit_queue"),
                      events=autoscaler_events(lines, "video_edit"), t_back_min=None)
    assert m["reacao_ajuste_s"] is None  # the "up" at 4.5 s was before this round started
    assert m["volta_ao_minimo_s"] is None


def test_round_without_new_replicas_has_no_m4():
    m = round_metrics(t0=at(0), t_done=at(20), start_replicas={"video_edit-1"},
                      firsts={"video_edit-1": at(-120)}, events=[], t_back_min=at(20))
    assert m["m4_s"] is None
    assert m["replicas_novas"] == 0
    assert m["replicas_max"] is None


# ------------------------------------------------------------------ summary over the repetitions
def test_summarize_gives_p50_and_max_and_counts_missing_rounds():
    rounds = [{"m4_s": v, "volta_ao_minimo_s": w, "reacao_ajuste_s": 1.0, "arranque_s": 2.0}
              for v, w in [(9.0, 32.0), (12.0, 35.0), (10.0, 31.0), (None, None), (11.0, 33.0)]]
    s = summarize(rounds)
    assert s["m4_s"] == {"n": 4, "p50": pytest.approx(10.5), "max": 12.0}
    assert s["volta_ao_minimo_s"]["max"] == 35.0
    assert s["rondas_sem_replica_nova"] == 1


def test_first_messages_reads_the_text_line_the_worker_writes():
    # formato real de Tools/video_common/worker.py (T007): "[video] first_message_at=<hora> queue=<fila>"
    logs = ("video_edit-2  | 2026-11-26T10:00:09.250000000Z [video] first_message_at=2026-11-26T10:00:09.249000+00:00 "
            "queue=video_edit_queue\n"
            "video_frames-1  | 2026-11-26T10:00:11.000000000Z [video] first_message_at=2026-11-26T10:00:11+00:00 "
            "queue=video_frames_queue\n")
    assert first_messages(parse_logs(logs), "video_edit_queue") == {"video_edit-2": at(9.25)}
