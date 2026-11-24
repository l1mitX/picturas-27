"""Métricas estáticas do RNF2 (modularidade do processamento de vídeo).

Mede N1 (duplicação de efeitos imagem/vídeo), N2 (impacto de mudança nos cenários C1-C3)
e N4 (tamanho e complexidade). N3 (build e imagem Docker) mede-se à parte (ver README.md).

Corre sempre da mesma forma, na base e depois do refactoring, e só lê o código:

    docker run --rm -e COMMIT=$(git rev-parse --short HEAD) -v "<raiz do repositório>:/repo" -w /repo python:3.11-slim \
        sh -c "pip install -q radon==6.0.1 && python docs/fase2/medicoes/rnf2_estaticas.py <etiqueta>"

Escreve docs/fase2/medicoes/resultados/<etiqueta>/rnf2_estaticas.json.
"""
import ast
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOLS = ROOT / "Tools"

# Cenários de mudança de N2: cada um é definido pelo conteúdo que tem de mudar, e não por nomes de
# ficheiros, para que o mesmo cenário encontre os ficheiros certos antes e depois do refactoring.
SCENARIOS = {
    # definição do filtro de brilho (imagem: adjust_brightness; vídeo: brightness). Não conta outras
    # ferramentas que usam ImageEnhance.Brightness internamente (e.g., upgrade_ai), que são outro efeito.
    "C1_filtro_brightness": re.compile(r"def (adjust_)?brightness\b"),
    "C2_versao_whisper": re.compile(r"faster[-_]whisper", re.IGNORECASE),
    "C3_amostragem_fotogramas": re.compile(r"def sampling_times\b"),
}
# Deteção ajustada para a estrutura do RNF2 (T043, R10; registada em README.md). A definição dos cenários
# não muda e o resultado da base é o mesmo:
# - C1 só conta um ficheiro que aplique mesmo o filtro (ImageEnhance.Brightness), e não uma função com esse
#   nome que só chama a função partilhada de Tools/effects/ (e.g., Tools/brightness/brightness.py depois do RNF2);
# - os cenários procuram só no código: comentários e docstrings não contam (e.g., "No faster-whisper here").
SCENARIO_ALSO = {"C1_filtro_brightness": re.compile(r"ImageEnhance\.Brightness\b")}


def code_text(p):
    """Texto de um ficheiro sem comentários nem docstrings, para os cenários de N2."""
    text = p.read_text(encoding="utf-8", errors="ignore")
    if p.suffix == ".py":
        try:
            tree = ast.parse(text)
        except SyntaxError:
            return text
        lines = text.splitlines()
        drop = set()
        for node in ast.walk(tree):
            body = getattr(node, "body", None)
            if isinstance(body, list) and body and isinstance(body[0], ast.Expr) \
                    and isinstance(body[0].value, ast.Constant) and isinstance(body[0].value.value, str):
                drop.update(range(body[0].lineno - 1, body[0].end_lineno))
        lines = ["" if i in drop else line for i, line in enumerate(lines)]
        return "\n".join(re.sub(r"(^|\s)#.*$", "", line) for line in lines)
    if p.suffix == ".txt":
        return "\n".join(re.sub(r"(^|\s)#.*$", "", line) for line in text.splitlines())
    if p.suffix in (".js", ".ts"):
        return "\n".join(re.sub(r"(^|\s)//.*$", "", line) for line in text.splitlines())
    return text


def matches_scenario(scenario, pattern, p):
    text = code_text(p)
    also = SCENARIO_ALSO.get(scenario)
    return bool(pattern.search(text)) and (also is None or bool(also.search(text)))
# Tipos de trabalho de vídeo, identificados pela função que os implementa. Servem para dizer que trabalhos de
# vídeo ficam indisponíveis quando um serviço é reconstruído e reimplantado.
VIDEO_JOBS = {
    "edicao": re.compile(r"def apply_frame_effects\b"),
    "legendagem": re.compile(r"def caption_video\b"),
    "extracao_fotogramas": re.compile(r"def extract_frames\b"),
}
SOURCE_SUFFIXES = {".py", ".js", ".ts", ".txt"}
SKIP_DIRS = {"node_modules", "tests", "__pycache__", ".git", "docs", "samples", "models"}


def rel(p):
    return p.relative_to(ROOT).as_posix()


def source_files():
    for p in ROOT.rglob("*"):
        if p.is_file() and p.suffix in SOURCE_SUFFIXES and not (SKIP_DIRS & set(p.relative_to(ROOT).parts)):
            yield p


# ---------- N1: efeitos com duas implementações (imagem e vídeo) ----------
def n1():
    pairs, video_lines = [], 0
    for vfile in sorted(TOOLS.glob("video*/**/*.py")):
        if "tests" in vfile.parts:
            continue
        tree = ast.parse(vfile.read_text(encoding="utf-8"))
        for fn in [n for n in tree.body if isinstance(n, ast.FunctionDef)]:
            image_impl = TOOLS / fn.name / f"{fn.name}.py"
            if image_impl.exists():
                pairs.append({"efeito": fn.name, "video": f"{rel(vfile)}:{fn.lineno}", "imagem": rel(image_impl)})
                video_lines += fn.end_lineno - fn.lineno + 1
    return {"efeitos_com_duas_implementacoes": len(pairs),
            "linhas_das_copias_no_video": video_lines,
            "pares": pairs}


# ---------- N2: ficheiros e serviços afetados por cada cenário ----------
def compose_services():
    """{servico: (contexto, dockerfile)} a partir do docker-compose.yaml (parser mínimo)."""
    services, name, ctx, dockerfile = {}, None, None, None
    in_services = False
    for line in (ROOT / "docker-compose.yaml").read_text(encoding="utf-8").splitlines():
        if re.match(r"^services:\s*$", line):
            in_services = True
            continue
        if in_services and re.match(r"^\S", line):
            in_services = False
        if not in_services:
            continue
        m = re.match(r"^  ([A-Za-z0-9_.-]+):\s*$", line)
        if m:
            if name and ctx:
                services[name] = (ctx, dockerfile or "Dockerfile")
            name, ctx, dockerfile = m.group(1), None, None
            continue
        m = re.match(r"^    build:\s*(\S+)\s*$", line)
        if m:
            ctx = m.group(1)
        m = re.match(r"^      context:\s*(\S+)", line)
        if m:
            ctx = m.group(1)
        m = re.match(r"^      dockerfile:\s*(\S+)", line)
        if m:
            dockerfile = m.group(1)
    if name and ctx:
        services[name] = (ctx, dockerfile or "Dockerfile")
    return services


def service_inputs(ctx, dockerfile):
    """Caminhos (relativos à raiz) que cada imagem copia, segundo as instruções COPY/ADD."""
    base = (ROOT / ctx).resolve()
    df = base / dockerfile
    inputs = []
    if not df.exists():
        return inputs
    for line in df.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\s*(COPY|ADD)\s+(?:--\S+\s+)*(.+)$", line, re.IGNORECASE)
        if not m:
            continue
        parts = m.group(2).split()
        for src in parts[:-1]:
            inputs.append((base / src).resolve())
    return inputs


def is_input(f, inputs):
    f = f.resolve()
    return any(f == i or i in f.parents for i in inputs)


def jobs_of(inputs):
    files = [p for p in source_files() if p.suffix == ".py" and is_input(p, inputs)]
    return {job for job, pat in VIDEO_JOBS.items()
            if any(pat.search(p.read_text(encoding="utf-8", errors="ignore")) for p in files)}


def n2():
    services = {s: service_inputs(*v) for s, v in compose_services().items()}
    result = {}
    for scenario, pattern in SCENARIOS.items():
        files = sorted(p for p in source_files() if matches_scenario(scenario, pattern, p))
        affected = sorted(s for s, inputs in services.items() if any(is_input(f, inputs) for f in files))
        jobs = sorted(set().union(*(jobs_of(services[s]) for s in affected)) if affected else set())
        result[scenario] = {"ficheiros_a_alterar": [rel(f) for f in files],
                            "n_ficheiros": len(files),
                            "servicos_a_reconstruir": affected,
                            "n_servicos": len(affected),
                            "trabalhos_de_video_reimplantados": jobs,
                            "n_trabalhos_de_video_reimplantados": len(jobs)}
    return result


# ---------- N4: tamanho e complexidade ----------
def n4():
    from radon.complexity import cc_visit
    from radon.raw import analyze

    modules = []
    for f in sorted(TOOLS.glob("video*/**/*.py")):
        if "tests" in f.parts or f.name == "__init__.py":
            continue
        src = f.read_text(encoding="utf-8")
        blocks = cc_visit(src)
        cc = [b.complexity for b in blocks]
        modules.append({"ficheiro": rel(f), "sloc": analyze(src).sloc,
                        "cc_max": max(cc, default=0),
                        "cc_media": round(sum(cc) / len(cc), 2) if cc else 0,
                        "bloco_mais_complexo": max(blocks, key=lambda b: b.complexity).name if blocks else None})
    orchestrator = ROOT / "projects" / "routes" / "projects.js"
    text = orchestrator.read_text(encoding="utf-8")
    return {"servicos_de_video": sorted({m["ficheiro"].split("/")[1] for m in modules}),
            "modulos_python_video": modules,
            "sloc_total_video": sum(m["sloc"] for m in modules),
            "orquestrador": {"ficheiro": rel(orchestrator),
                             "linhas": len(text.splitlines()),
                             "linhas_com_ramificacao_imagem_video": len(re.findall(r"^.*(isVideo|media_type).*$", text, re.M))}}


def main():
    label = sys.argv[1] if len(sys.argv) > 1 else "sem-etiqueta"
    commit = os.environ.get("COMMIT")
    if not commit:
        try:
            commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
                                    capture_output=True, text=True).stdout.strip() or None
        except OSError:
            commit = None
    out = {"etiqueta": label, "commit": commit, "N1": n1(), "N2": n2(), "N4": n4()}
    dest = ROOT / "docs" / "fase2" / "medicoes" / "resultados" / label
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "rnf2_estaticas.json").write_text(json.dumps(out, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(out, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
