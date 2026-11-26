"""Script de carga do RNF1 (REQ-VID-EDIT-011, capacidade) e do N5 do RNF2 (desempenho não pode piorar).

Usa a aplicação como um utilizador: regista utilizadores Premium de teste, cria um projeto por trabalho, carrega o
vídeo, define o pipeline e carrega em *Apply* (POST .../process). Mede o tempo desde o *Apply* até os resultados
ficarem disponíveis para o utilizador (GET .../process/url devolve resultados, o que só acontece depois do commit
da execução no `projects`). Consulta a cada 0,5 s.

Cenários (parâmetros do plano mínimo, fixados pela equipa a 2026-11-18 e usados na baseline; ver
docs/fase2/RNF1-EDIT-011.md, secção 2.3). Usar sempre os mesmos valores em todos os momentos de medição
(base, após o RNF2, após o RNF1), para os resultados serem comparáveis:

  isolado  Trabalho curto sozinho (brilho em sample_10s_720p.mp4). Referência "sem carga" para o M1.
           5 repetições.
  m1       A legenda speech_mandela_177s_1080p.webm; 5 s depois, B aplica brilho a sample_10s_720p.mp4.
           Mede-se o tempo de B (M1). 5 repetições.
  m2       N trabalhos submetidos ao mesmo tempo: 1 legendagem + (N-1) edições de brilho. Só N = 4.
           Mede-se o débito (vídeos/min, M2) e o p95 do tempo de cada trabalho (M3). 3 repetições.
  paralelo N edições curtas (brilho em sample_10s_720p.mp4) submetidas ao mesmo tempo, sem legendagem.
           Mede-se o p95 do tempo de cada trabalho e o débito (M6). É o cenário que as réplicas melhoram;
           o M1 e o M2 são dominados pela legendagem (acrescentado a 2026-11-18, antes do refactoring).
           N = 4, 5 repetições.

Em paralelo amostra CPU e memória dos contentores de vídeo (`docker stats`).

Uso (na raiz do repositório, com a aplicação a correr em https://localhost:8080):

    python docs/fase2/medicoes/carga_rnf1.py <etiqueta> <cenario> [--reps R] [--n 4] [--timeout S] [--pausa S]

--pausa S (acrescentado a 2026-11-26, T003): espera S segundos antes de cada repetição, para o `video_autoscaler`
voltar ao mínimo de réplicas e cada repetição começar com cópias «frias» (decisão T003: M6 oficial com frias). Tem de
ser maior do que a espera antes de descer (COOLDOWN_SECONDS = 60) mais a paragem das réplicas: usar --pausa 120 na
`apos-rnf1`. Sem --pausa (0), o comportamento é o da base e da `apos-rnf2` (repetições seguidas); aí a pausa não muda
nada, porque havia um único *worker*. O CSV regista as réplicas de vídeo no início de cada repetição
(`replicas_inicio`), para confirmar que começou frio. Para medir «quentes» (complementar), subir as réplicas à mão
antes (`--scale video_edit=4`), parar o autoscaler e não usar --pausa, com outra etiqueta (e.g., apos-rnf1-quentes).

Comandos usados na baseline (sem --reps nem --n, o script usa estes mesmos valores):
    python docs/fase2/medicoes/carga_rnf1.py base isolado --reps 5
    python docs/fase2/medicoes/carga_rnf1.py base m1 --reps 5
    python docs/fase2/medicoes/carga_rnf1.py base m2 --reps 3 --n 4
    python docs/fase2/medicoes/carga_rnf1.py base paralelo --reps 5 --n 4

Nos momentos seguintes muda só a etiqueta (e.g., apos-rnf2, apos-rnf1).

Escreve em docs/fase2/medicoes/resultados/<etiqueta>/: carga_<cenario>.csv (uma linha por trabalho),
carga_<cenario>_recursos.csv (amostras do docker stats) e carga_<cenario>_resumo.json.

Só usa a biblioteca padrão do Python (3.10+).
"""
import argparse
import csv
import http.client
import json
import os
import ssl
import statistics
import subprocess
import threading
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

HOST, PORT = "localhost", 8080
CTX = ssl._create_unverified_context()  # certificado auto-assinado da aplicação local
ROOT = Path(__file__).resolve().parents[3]
SAMPLES = ROOT / "samples" / "video"

LONG_JOB = ("speech_mandela_177s_1080p.webm", [{"procedure": "subtitles", "params": {}}])
SHORT_JOB = ("sample_10s_720p.mp4", [{"procedure": "brightness", "params": {"brightness": 1.5}}])
M1_DELAY_S = 5
POLL_S = 0.5


# ------------------------------------------------------------------ HTTP
def req(method, path, body=None, headers=None, timeout=900):
    c = http.client.HTTPSConnection(HOST, PORT, context=CTX, timeout=timeout)
    try:
        c.request(method, path, body=body, headers=headers or {})
        r = c.getresponse()
        return r.status, r.read()
    finally:
        c.close()


def jreq(method, path, payload=None, headers=None):
    h = dict(headers or {})
    body = None
    if payload is not None:
        body = json.dumps(payload)
        h["Content-Type"] = "application/json"
    st, data = req(method, path, body, h)
    try:
        return st, json.loads(data) if data else None
    except ValueError:
        return st, data.decode(errors="replace")


class Client:
    """Um utilizador Premium de teste com um projeto."""

    def __init__(self, tag):
        pw = "T3st-" + uuid.uuid4().hex[:12]
        st, d = jreq("POST", "/api-gateway/users", {"name": f"carga-{tag}",
                                                   "email": f"carga-{uuid.uuid4().hex[:10]}@test.local",
                                                   "password": pw, "type": "premium"})
        if st >= 300:
            raise RuntimeError(f"registo falhou: {st} {d}")
        self.uid, self.auth = d["user"]["_id"], {"Authorization": f"Bearer {d['jwt']}"}
        st, p = jreq("POST", f"/api-gateway/projects/{self.uid}", {"name": f"carga-{tag}"}, self.auth)
        if st >= 300:
            raise RuntimeError(f"criar projeto falhou: {st} {p}")
        self.pid = p["_id"]

    def project(self):
        st, p = jreq("GET", f"/api-gateway/projects/{self.uid}/{self.pid}", headers=self.auth)
        if st >= 300:
            raise RuntimeError(f"GET projeto falhou: {st} {p}")
        return p

    def versioned(self):
        return {**self.auth, "X-Project-Version": str(self.project().get("version", 0))}

    def upload_video(self, path):
        boundary = uuid.uuid4().hex
        ctype = "video/webm" if path.suffix == ".webm" else "video/quicktime" if path.suffix == ".mov" else "video/mp4"
        body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"video\"; filename=\"{path.name}\"\r\n"
                f"Content-Type: {ctype}\r\n\r\n").encode() + path.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
        st, d = req("POST", f"/api-gateway/projects/{self.uid}/{self.pid}/video", body,
                    {**self.versioned(), "Content-Type": f"multipart/form-data; boundary={boundary}"})
        if st >= 300:
            raise RuntimeError(f"upload falhou: {st} {d[:200]}")

    def add_tool(self, tool):
        st, d = jreq("POST", f"/api-gateway/projects/{self.uid}/{self.pid}/tool", tool, self.versioned())
        if st >= 300:
            raise RuntimeError(f"adicionar ferramenta falhou: {st} {d}")

    def results(self):
        """Resultados da execução confirmada (vazio até ao commit; o projeto é novo, sem execuções anteriores)."""
        st, d = jreq("GET", f"/api-gateway/projects/{self.uid}/{self.pid}/process/url", headers=self.auth)
        if st >= 300:
            raise RuntimeError(f"GET resultados falhou: {st} {d}")
        return (d or {}).get("imgs", []) + (d or {}).get("texts", [])

    def process(self):
        return jreq("POST", f"/api-gateway/projects/{self.uid}/{self.pid}/process", {}, self.versioned())


# ------------------------------------------------------------------ trabalhos
class Job(threading.Thread):
    def __init__(self, name, role, spec, start_at, timeout):
        super().__init__(daemon=True)
        self.name_, self.role, (self.media, self.tools) = name, role, spec
        self.start_at, self.timeout = start_at, timeout
        self.result = {"trabalho": name, "papel": role, "media": self.media,
                       "pipeline": "+".join(t["procedure"] for t in self.tools)}
        # preparação fora da medição: utilizador, projeto, upload e pipeline
        self.client = Client(name)
        self.client.upload_video(SAMPLES / self.media)
        for t in self.tools:
            self.client.add_tool(t)

    def run(self):
        while (wait := self.start_at - time.perf_counter()) > 0:
            time.sleep(min(wait, 0.05))
        t0 = time.perf_counter()
        st, d = self.client.process()
        self.result["t_submit_rel_s"] = round(t0 - T_ZERO, 3)
        if st >= 300:
            self.result.update(estado=f"erro-submissao-{st}", latencia_s=None, detalhe=str(d)[:200])
            return
        while True:
            try:
                done = len(self.client.results()) > 0
            except Exception as e:  # noqa: BLE001 - erro transitório no GET, tenta outra vez
                done, self.result["detalhe"] = False, str(e)[:200]
            now = time.perf_counter()
            if done:
                self.result.update(estado="ok", latencia_s=round(now - t0, 3), t_fim_rel_s=round(now - T_ZERO, 3))
                return
            if now - t0 > self.timeout:
                self.result.update(estado="timeout", latencia_s=None)
                return
            time.sleep(POLL_S)


# ------------------------------------------------------------------ recursos
class Sampler(threading.Thread):
    def __init__(self):
        super().__init__(daemon=True)
        self.stop, self.rows = False, []

    def run(self):
        while not self.stop:
            out = subprocess.run(["docker", "stats", "--no-stream", "--format",
                                  "{{.Name}};{{.CPUPerc}};{{.MemUsage}}"], capture_output=True, text=True).stdout
            t = round(time.perf_counter() - T_ZERO, 2)
            for line in out.strip().splitlines():
                name, cpu, mem = line.split(";")
                if "video" in name:
                    self.rows.append({"t_rel_s": t, "contentor": name, "cpu_pct": float(cpu.rstrip("%") or 0),
                                      "mem_mib": to_mib(mem.split("/")[0])})


def to_mib(s):
    s = s.strip()
    for unit, f in (("GiB", 1024), ("MiB", 1), ("KiB", 1 / 1024), ("kB", 1 / 1024), ("B", 1 / 2**20)):
        if s.endswith(unit):
            return round(float(s[: -len(unit)]) * f, 1)
    return float(s)


def video_replicas():
    out = subprocess.run(["docker", "ps", "--format", "{{.Names}}"], capture_output=True, text=True).stdout
    return sorted(n for n in out.split() if "video" in n)


# ------------------------------------------------------------------ cenários
def run_round(jobs_spec, timeout):
    """jobs_spec: [(nome, papel, (media, tools), atraso_s)]. Prepara todos, depois arranca-os."""
    global T_ZERO
    prepared = []
    for name, role, spec, delay in jobs_spec:
        prepared.append((Job(name, role, spec, 0, timeout), delay))
    T_ZERO = time.perf_counter() + 1.0
    for job, delay in prepared:
        job.start_at = T_ZERO + delay
    sampler = Sampler()
    sampler.start()
    for job, _ in prepared:
        job.start()
    for job, _ in prepared:
        job.join()
    sampler.stop = True
    sampler.join()
    return [j.result for j, _ in prepared], sampler.rows


def pct(values, p):
    v = sorted(values)
    if not v:
        return None
    k = (len(v) - 1) * p / 100
    lo, hi = int(k), min(int(k) + 1, len(v) - 1)
    return round(v[lo] + (v[hi] - v[lo]) * (k - lo), 3)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("etiqueta")
    ap.add_argument("cenario", choices=["isolado", "m1", "m2", "paralelo"])
    ap.add_argument("--reps", type=int, default=None)
    ap.add_argument("--n", default="4")
    ap.add_argument("--timeout", type=int, default=1800)
    ap.add_argument("--pausa", type=int, default=0,
                    help="segundos de espera antes de cada repetição (cópias frias; 120 na apos-rnf1)")
    a = ap.parse_args()
    reps = a.reps or {"isolado": 5, "m1": 5, "m2": 3, "paralelo": 5}[a.cenario]

    rows, res_rows = [], []
    rounds = [(n, r) for n in ([int(x) for x in a.n.split(",")] if a.cenario in ("m2", "paralelo") else [None])
              for r in range(1, reps + 1)]
    for n, rep in rounds:
        if a.cenario == "isolado":
            spec = [("B", "curto", SHORT_JOB, 0)]
        elif a.cenario == "m1":
            spec = [("A", "legendagem", LONG_JOB, 0), ("B", "curto", SHORT_JOB, M1_DELAY_S)]
        elif a.cenario == "paralelo":
            spec = [(f"J{i}", "curto", SHORT_JOB, 0) for i in range(1, n + 1)]
        else:
            spec = [("J1", "legendagem", LONG_JOB, 0)] + [(f"J{i}", "curto", SHORT_JOB, 0) for i in range(2, n + 1)]
        if a.pausa:
            print(f"[{a.cenario}] pausa de {a.pausa} s antes da repetição {rep}", flush=True)
            time.sleep(a.pausa)
        replicas_inicio = " ".join(video_replicas())
        results, samples = run_round(spec, a.timeout)
        makespan = max((r.get("t_fim_rel_s") or 0) for r in results) - min(r["t_submit_rel_s"] for r in results)
        for r in results:
            rows.append({"cenario": a.cenario, "n": n or len(spec), "repeticao": rep, **r,
                         "makespan_ronda_s": round(makespan, 3), "replicas_inicio": replicas_inicio})
        for s in samples:
            res_rows.append({"cenario": a.cenario, "n": n or len(spec), "repeticao": rep, **s})
        print(f"[{a.cenario}] n={n or len(spec)} rep={rep}: " +
              ", ".join(f"{r['trabalho']}={r['estado']}:{r.get('latencia_s')}" for r in results), flush=True)

    dest = ROOT / "docs" / "fase2" / "medicoes" / "resultados" / a.etiqueta
    dest.mkdir(parents=True, exist_ok=True)
    for fname, data in ((f"carga_{a.cenario}.csv", rows), (f"carga_{a.cenario}_recursos.csv", res_rows)):
        if data:
            keys = list(dict.fromkeys(k for d in data for k in d))
            with open(dest / fname, "w", newline="", encoding="utf-8") as f:
                w = csv.DictWriter(f, fieldnames=keys)
                w.writeheader()
                w.writerows(data)

    ok = [r for r in rows if r["estado"] == "ok"]
    summary = {"etiqueta": a.etiqueta, "cenario": a.cenario, "data": datetime.now(timezone.utc).isoformat(),
               "replicas_video": video_replicas(), "repeticoes": reps, "pausa_s": a.pausa,
               "falhas": [{k: r.get(k) for k in ("n", "repeticao", "trabalho", "estado", "detalhe")}
                          for r in rows if r["estado"] != "ok"]}
    if a.cenario in ("isolado", "m1"):
        lat = [r["latencia_s"] for r in ok if r["papel"] == "curto"]
        summary["curto_latencia_s"] = {"n": len(lat), "p50": pct(lat, 50), "p95": pct(lat, 95),
                                       "media": round(statistics.mean(lat), 3) if lat else None}
        if a.cenario == "m1":
            leg = [r["latencia_s"] for r in ok if r["papel"] == "legendagem"]
            summary["legendagem_latencia_s"] = {"p50": pct(leg, 50), "p95": pct(leg, 95)}
    else:
        per_n = {}
        for n in sorted({r["n"] for r in rows}):
            rr = [r for r in rows if r["n"] == n]
            ms = sorted({(r["repeticao"], r["makespan_ronda_s"]) for r in rr})
            lat = [r["latencia_s"] for r in rr if r["estado"] == "ok"]
            per_n[str(n)] = {"debito_videos_min_media": round(statistics.mean(n * 60 / m for _, m in ms if m), 3),
                             "makespan_s_p50": pct([m for _, m in ms], 50),
                             "latencia_s_p50": pct(lat, 50), "latencia_s_p95": pct(lat, 95),
                             "latencia_curtos_s_p95": pct([r["latencia_s"] for r in rr
                                                           if r["estado"] == "ok" and r["papel"] == "curto"], 95)}
        summary["por_n"] = per_n
    if res_rows:
        by_c = {}
        for s in res_rows:
            by_c.setdefault(s["contentor"], []).append(s)
        summary["recursos_video"] = {c: {"mem_mib_max": max(x["mem_mib"] for x in v),
                                         "cpu_pct_media": round(statistics.mean(x["cpu_pct"] for x in v), 1),
                                         "cpu_pct_max": max(x["cpu_pct"] for x in v)} for c, v in by_c.items()}
    (dest / f"carga_{a.cenario}_resumo.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False),
                                                       encoding="utf-8")
    print(json.dumps(summary, indent=2, ensure_ascii=False))


T_ZERO = time.perf_counter()

if __name__ == "__main__":
    main()
