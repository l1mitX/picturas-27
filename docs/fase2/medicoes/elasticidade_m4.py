"""Medição do M4 do RNF1 (elasticidade; QS-03, REQ-VID-EDIT-011; specs/002-rnf1-capacidade, T021, R10).

Lança o cenário `paralelo` (N edições curtas ao mesmo tempo, as mesmas do `carga_rnf1.py`) com as réplicas do serviço no
mínimo, junta os registos do `video_autoscaler` e dos *workers* e calcula, em cada repetição:

  m4_s               desde a submissão dos trabalhos até uma réplica nova consumir a primeira mensagem (o M4)
  reacao_ajuste_s    desde a submissão até à primeira decisão "up" do `video_autoscaler`
  arranque_s         desde essa decisão até a réplica nova consumir (arranque do contentor + ligação ao RabbitMQ)
  volta_ao_minimo_s  desde o fim do último trabalho até o serviço voltar ao número mínimo de réplicas

e, no fim, o p50 e o máximo de cada um (valor-alvo do M4: ≤ 30 s; mínimo: ≤ 60 s; relatório, Tabela 18).

Registos usados (contrato em specs/002-rnf1-capacidade/contracts/autoscaler-e-workers.md):
  - `video_autoscaler`: uma linha JSON por decisão, {"ts", "service", "pending", "current", "target", "action"};
  - cada *worker*: uma linha JSON {"ts", "event": "first_message", "queue"} quando consome a primeira mensagem.
Os instantes vêm da hora do Docker (`docker compose logs -t`); a hora do *host* (submissão, fim dos trabalhos, volta ao
mínimo) é convertida para a hora do Docker com o desfasamento medido no início (WSL2 pode ter outro relógio).

Uso (na raiz do repositório, com a aplicação do RNF1 a correr em https://localhost:8080 e o `video_autoscaler` ligado):

    python docs/fase2/medicoes/elasticidade_m4.py apos-rnf1 [--reps 5] [--n 4] [--minimo 1]

Escreve docs/fase2/medicoes/resultados/<etiqueta>/elasticidade_m4.json e elasticidade_m4_registos.txt.
Só usa a biblioteca padrão do Python (3.10+) e o `carga_rnf1.py` (mesma pasta).
"""
import argparse
import json
import re
import statistics
import subprocess
import time
from collections import namedtuple
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
LogLine = namedtuple("LogLine", "container ts msg")
_LINE = re.compile(r"^(?P<container>\S+)\s+\|\s+(?P<ts>\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z)\s?(?P<msg>.*)$")


# ------------------------------------------------------------------ leitura dos registos (testado)
def _parse_ts(text):
    text = text.rstrip("Z")
    if "." in text:
        base, frac = text.split(".", 1)
        text = f"{base}.{frac[:6].ljust(6, '0')}"  # o Docker dá nanossegundos; o Python lê até microssegundos
    return datetime.fromisoformat(text).replace(tzinfo=timezone.utc)


def parse_logs(text):
    """Linhas de `docker compose logs --no-color -t` → [LogLine(contentor, hora do Docker, mensagem)]."""
    lines = []
    for raw in text.splitlines():
        m = _LINE.match(raw.strip())
        if m:
            lines.append(LogLine(m["container"], _parse_ts(m["ts"]), m["msg"]))
    return lines


def _json(msg):
    if not msg.startswith("{"):
        return None
    try:
        obj = json.loads(msg)
    except ValueError:
        return None
    return obj if isinstance(obj, dict) else None


def first_messages(lines, queue):
    """{contentor: hora da primeira mensagem consumida} para os *workers* da fila `queue`."""
    firsts = {}
    for line in lines:
        obj = _json(line.msg)
        if obj and obj.get("event") == "first_message" and obj.get("queue") == queue:
            if line.container not in firsts or line.ts < firsts[line.container]:
                firsts[line.container] = line.ts
    return firsts


def autoscaler_events(lines, service):
    """Decisões do `video_autoscaler` para o serviço, por ordem, com a hora do Docker em `log_ts`."""
    events = []
    for line in lines:
        obj = _json(line.msg)
        if obj and "action" in obj and obj.get("service") == service:
            events.append({**obj, "log_ts": line.ts})
    return sorted(events, key=lambda e: e["log_ts"])


def _secs(a, b):
    return round((b - a).total_seconds(), 3)


def round_metrics(t0, t_done, start_replicas, firsts, events, t_back_min):
    """Medidas de uma repetição. Todas as horas no mesmo relógio (o do Docker).

    t0              submissão dos trabalhos
    t_done          fim do último trabalho
    start_replicas  contentores do serviço que já existiam antes da repetição
    firsts          first_messages(...)
    events          autoscaler_events(...)
    t_back_min      quando o serviço voltou ao número mínimo de réplicas (None se não voltou)
    """
    new = sorted(ts for name, ts in firsts.items() if name not in start_replicas and ts >= t0)
    end = t_back_min or t_done
    in_round = [e for e in events if e["log_ts"] >= t0 and (end is None or e["log_ts"] <= end)]
    ups = [e for e in in_round if e.get("action") == "up"]
    targets = [e["target"] for e in in_round if isinstance(e.get("target"), int)]
    return {
        "m4_s": _secs(t0, new[0]) if new else None,
        "reacao_ajuste_s": _secs(t0, ups[0]["log_ts"]) if ups else None,
        "arranque_s": _secs(ups[0]["log_ts"], new[0]) if ups and new else None,
        "volta_ao_minimo_s": _secs(t_done, t_back_min) if t_back_min and t_done else None,
        "replicas_novas": len(new),
        "replicas_max": max(targets) if targets else None,
    }


def summarize(rounds):
    """p50 e máximo de cada medida nas repetições (as que faltam não entram)."""
    out = {}
    for key in ("m4_s", "reacao_ajuste_s", "arranque_s", "volta_ao_minimo_s"):
        values = [r[key] for r in rounds if r.get(key) is not None]
        out[key] = {"n": len(values), "p50": statistics.median(values) if values else None,
                    "max": max(values) if values else None}
    out["rondas_sem_replica_nova"] = sum(1 for r in rounds if r.get("m4_s") is None)
    return out


# ------------------------------------------------------------------ Docker (corre só na medição)
def _run(cmd):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)


def clock_offset(samples=5):
    """Desfasamento (s) entre a hora do Docker e a do *host*: hora_docker ≈ hora_host + desfasamento."""
    best = None
    for _ in range(samples):
        before = time.time()
        out = _run(["docker", "compose", "exec", "-T", "projects", "node", "-e", "console.log(Date.now())"])
        after = time.time()
        if out.returncode != 0:
            continue
        rtt = after - before
        offset = int(out.stdout.strip()) / 1000 - (before + after) / 2
        if best is None or rtt < best[0]:
            best = (rtt, offset)
    if best is None:
        raise RuntimeError("não foi possível ler a hora do Docker (o serviço projects está a correr?)")
    return best[1]


def replicas(service):
    """Nomes dos contentores do serviço como aparecem no `docker compose logs` (e.g. video_edit-2)."""
    out = _run(["docker", "ps", "--filter", f"label=com.docker.compose.service={service}",
                "--format", '{{.Label "com.docker.compose.container-number"}}']).stdout
    return {f"{service}-{n}" for n in out.split()}


def wait_for_minimum(service, minimum, timeout_s):
    """Espera até o serviço ter `minimum` réplicas; devolve a hora do *host* em que isso aconteceu (ou None)."""
    limit = time.time() + timeout_s
    while time.time() < limit:
        if len(replicas(service)) <= minimum:
            return datetime.now(timezone.utc)
        time.sleep(1)
    return None


def compose_logs(services, since):
    out = _run(["docker", "compose", "logs", "--no-color", "-t", "--since", since.isoformat(), *services])
    return out.stdout if out.returncode == 0 else ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("etiqueta")
    ap.add_argument("--reps", type=int, default=5)
    ap.add_argument("--n", type=int, default=4)
    ap.add_argument("--servico", default="video_edit")
    ap.add_argument("--fila", default="video_edit_queue")
    ap.add_argument("--minimo", type=int, default=1, help="mínimo de réplicas do serviço (decidido na T003)")
    ap.add_argument("--espera-max", type=int, default=300, help="tempo máximo (s) para voltar ao mínimo")
    ap.add_argument("--timeout", type=int, default=900)
    a = ap.parse_args()

    import carga_rnf1 as carga  # mesmo cenário e mesmos utilizadores de teste do M6

    offset = clock_offset()
    to_docker = lambda t: t + timedelta(seconds=offset)  # noqa: E731
    rounds, log_text = [], []
    for rep in range(1, a.reps + 1):
        if wait_for_minimum(a.servico, a.minimo, a.espera_max) is None:
            print(f"[m4] rep={rep}: o serviço não voltou ao mínimo antes de começar", flush=True)
        start = replicas(a.servico)
        since = datetime.now(timezone.utc) - timedelta(seconds=5)
        spec = [(f"J{i}", "curto", carga.SHORT_JOB, 0) for i in range(1, a.n + 1)]
        wall0, perf0 = time.time(), time.perf_counter()
        results, _ = carga.run_round(spec, a.timeout)
        t0 = datetime.fromtimestamp(wall0 + (carga.T_ZERO - perf0), timezone.utc)
        t_done = t0 + timedelta(seconds=max((r.get("t_fim_rel_s") or 0) for r in results))
        t_back = wait_for_minimum(a.servico, a.minimo, a.espera_max)
        text = compose_logs(["video_autoscaler", a.servico], to_docker(since))
        log_text.append(f"===== repetição {rep}\n{text}")
        lines = parse_logs(text)
        m = round_metrics(to_docker(t0), to_docker(t_done), start, first_messages(lines, a.fila),
                          autoscaler_events(lines, a.servico), to_docker(t_back) if t_back else None)
        m.update(repeticao=rep, replicas_no_inicio=sorted(start),
                 trabalhos=[{k: r.get(k) for k in ("trabalho", "estado", "latencia_s")} for r in results])
        rounds.append(m)
        print(f"[m4] rep={rep}: M4={m['m4_s']} s (decisão {m['reacao_ajuste_s']} s + arranque {m['arranque_s']} s), "
              f"réplicas novas={m['replicas_novas']}, máx={m['replicas_max']}, "
              f"volta ao mínimo={m['volta_ao_minimo_s']} s", flush=True)

    dest = ROOT / "docs" / "fase2" / "medicoes" / "resultados" / a.etiqueta
    dest.mkdir(parents=True, exist_ok=True)
    summary = {"etiqueta": a.etiqueta, "data": datetime.now(timezone.utc).isoformat(), "servico": a.servico,
               "fila": a.fila, "n": a.n, "minimo": a.minimo, "repeticoes": a.reps,
               "desfasamento_docker_host_s": round(offset, 3), "resumo": summarize(rounds), "rondas": rounds}
    (dest / "elasticidade_m4.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    (dest / "elasticidade_m4_registos.txt").write_text("\n".join(log_text), encoding="utf-8")
    print(json.dumps(summary["resumo"], indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
