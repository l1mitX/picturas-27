"""RNF1 T010 (R8, H-03): with replicas, two workers may load the Whisper model for the first time at once.

The model cache (WHISPER_CACHE_DIR) is a volume shared by every replica. If two replicas start with an
empty cache, only one of them may download the model; the other waits and then reuses the cache.
"""
import os
import sys
import threading
import time
import types

import subtitles


def _fake_whisper(monkeypatch):
    """A WhisperModel that 'downloads' (slowly) only when the cache folder has no model yet."""
    downloads = []
    counter_lock = threading.Lock()

    class WhisperModel:
        def __init__(self, name, device, compute_type, cpu_threads, download_root):
            os.makedirs(download_root, exist_ok=True)  # as faster-whisper does
            marker = os.path.join(download_root, f"{name}.bin")
            if not os.path.exists(marker):
                time.sleep(0.3)  # long enough for the other replica to arrive meanwhile
                with counter_lock:
                    downloads.append(name)
                with open(marker, "w") as handle:
                    handle.write("model")
            self.name = name

    monkeypatch.setitem(sys.modules, "faster_whisper", types.SimpleNamespace(WhisperModel=WhisperModel))
    return downloads


def test_two_replicas_with_an_empty_cache_download_the_model_once(tmp_path, monkeypatch):
    monkeypatch.setenv("WHISPER_CACHE_DIR", str(tmp_path / "whisper"))
    monkeypatch.setenv("WHISPER_MODEL", "small")
    downloads = _fake_whisper(monkeypatch)
    barrier = threading.Barrier(2)
    models, errors = [], []

    def replica():
        try:
            barrier.wait(timeout=10)
            # Without lru_cache: each replica is its own process with its own cache of the model.
            models.append(subtitles.speech_model.__wrapped__())
        except Exception as exc:
            errors.append(exc)

    threads = [threading.Thread(target=replica) for _ in range(2)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=30)

    assert errors == []
    assert len(models) == 2
    assert downloads == ["small"]
