"""Referência de regressão (preservação funcional) para os RNF da Fase 2.

Aplica um conjunto fixo de efeitos a entradas fixas e regista o hash dos píxeis (imagem) ou dos fotogramas e do
áudio descodificados (vídeo). Corre-se na base e depois de cada refactoring: os hashes têm de ser iguais
(REQ-VID-EDIT-009, resultado reproduzível).

Modo "imagem" (ferramentas de imagem, sem RabbitMQ), na raiz do repositório:

    docker run --rm -v "<raiz>:/repo" -w /repo python:3.11-slim sh -c \
      "pip install -q pillow==11.0.0 pika==1.3.2 pytz python-dotenv && \
       python docs/fase2/medicoes/regressao_hashes.py imagem <etiqueta>"

Modo "video" (dentro da imagem do serviço de vídeo, que tem o ffmpeg e o código):

    docker compose run --rm --no-deps -T -v "<raiz>/docs:/docs" -v "<raiz>/samples/video:/samples" video_tool \
      python /docs/fase2/medicoes/regressao_hashes.py video <etiqueta>

Escreve docs/fase2/medicoes/resultados/<etiqueta>/regressao_<modo>.json.

Depois do refactoring, se os pontos de entrada mudarem de nome ou de serviço, só se adaptam as funções
`run_image_tool` e `run_video`; as entradas, os parâmetros e a forma de calcular os hashes não mudam.
"""
import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent

# ---------------------------------------------------------------- imagem
IMAGE_CASES = [
    # (ferramenta, método, argumentos depois de (entrada, saída))
    ("brightness", "adjust_brightness", (1.5,)),
    ("contrast", "contrast_image", (1.3,)),
    ("saturation", "saturation_image", (0.5,)),
    ("rotate", "rotate_image", (90,)),
    ("resize", "resize_image", ((160, 90),)),
    ("binarization", "add_binarization", (128,)),
    ("cut", "cut_image", ((40, 30, 280, 200),)),
    ("border", "add_border", ((255, 0, 0), 10)),
]


def pixel_hash(img):
    h = hashlib.sha256()
    h.update(f"{img.mode}|{img.size}".encode())
    h.update(img.tobytes())
    return h.hexdigest()


def fixed_input_image(path):
    """Imagem de entrada determinística (não depende de ficheiros externos)."""
    from PIL import Image
    w, h = 320, 240
    r = Image.linear_gradient("L").resize((w, h))
    g = Image.radial_gradient("L").resize((w, h))
    b = Image.effect_mandelbrot((w, h), (-2.0, -1.2, 1.0, 1.2), 100)
    Image.merge("RGB", (r, g, b)).save(path)


def run_image_tool(tools_dir, tool, method, src, dst, args):
    if str(tools_dir) not in sys.path:
        sys.path.insert(0, str(tools_dir))  # para "utils"
    sys.path.insert(0, str(tools_dir / tool))  # módulos próprios da ferramenta (e.g., cut/processor.py)
    try:
        spec = importlib.util.spec_from_file_location(f"tool_{tool}", tools_dir / tool / f"{tool}.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
    finally:
        sys.path.remove(str(tools_dir / tool))
    cls = next(v for k, v in vars(mod).items() if isinstance(v, type) and k.lower() == tool.replace("_", ""))
    obj = cls.__new__(cls)  # sem __init__: não liga ao RabbitMQ
    from utils.img_handler import Img_Handler
    obj._img_handler = Img_Handler()
    getattr(obj, method)(str(src), str(dst), *args)


def mode_image(root):
    from PIL import Image
    tools_dir = root / "Tools"
    results = {}
    with tempfile.TemporaryDirectory() as work:
        work = Path(work)
        src = work / "entrada.png"
        fixed_input_image(src)
        results["_entrada"] = pixel_hash(Image.open(src))
        for tool, method, args in IMAGE_CASES:
            dst = work / f"{tool}.png"
            run_image_tool(tools_dir, tool, method, src, dst, args)
            img = Image.open(dst)
            results[tool] = {"args": repr(args), "tamanho": list(img.size), "hash": pixel_hash(img)}
    return results


# ---------------------------------------------------------------- vídeo
VIDEO_CASES = {
    "V1_brilho": ("sample_10s_720p.mp4", [{"procedure": "brightness", "params": {"brightness": 1.5}}], False),
    "V1p_brilho_preview": ("sample_10s_720p.mp4", [{"procedure": "brightness", "params": {"brightness": 1.5}}], True),
    "V2_contraste_rotacao_corte": ("sample_10s_720p.mp4", [
        {"procedure": "contrast", "params": {"contrastFactor": 1.3}},
        {"procedure": "rotate", "params": {"degrees": 90}},
        {"procedure": "trim", "params": {"start": 2, "end": 6}}], False),
    "V3_velocidade": ("sample_6s.mov", [{"procedure": "speed", "params": {"factor": 2.0}}], False),
    "V4_recorte_moldura_redim": ("sample_10s_720p.mp4", [
        {"procedure": "cut", "params": {"left": 100, "top": 50, "right": 500, "bottom": 350}},
        {"procedure": "border", "params": {"borderWidth": 10, "r": 255, "g": 0, "b": 0}},
        {"procedure": "resize", "params": {"width": 320, "height": 180}}], False),
    "V5_binarizacao_saturacao": ("sample_6s.mov", [
        {"procedure": "saturation", "params": {"saturationFactor": 0.5}},
        {"procedure": "binarization", "params": {"threshold": 128}}], False),
    "V6_extracao_sozinha": ("sample_10s_720p.mp4", [
        {"procedure": "extract_frames", "params": {"mode": "count", "count": 4, "format": "png"}}], False),
    "V7_brilho_e_extracao": ("sample_10s_720p.mp4", [
        {"procedure": "brightness", "params": {"brightness": 1.2}},
        {"procedure": "extract_frames", "params": {"mode": "interval", "interval": 2, "format": "png"}}], False),
    "V8_corte_e_legendas": ("speech_mandela_177s_1080p.webm", [
        {"procedure": "trim", "params": {"start": 0, "end": 15}},
        {"procedure": "subtitles", "params": {}}], False),
}


def media_hash(path):
    def md5_of(stream):
        out = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-map", f"0:{stream}?", "-f", "md5", "-"],
                             capture_output=True, text=True, check=True).stdout.strip()
        return out.removeprefix("MD5=") or None
    frames = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames",
                             "-show_entries", "stream=nb_read_frames,width,height", "-of", "json", str(path)],
                            capture_output=True, text=True, check=True).stdout
    return {"video_md5": md5_of("v"), "audio_md5": md5_of("a"), "stream": json.loads(frames)["streams"][0]}


def run_video(src, dst, tools, preview):
    sys.path.insert(0, "/app")
    from video_processor import process_video
    return process_video(str(src), str(dst), tools, progress_cb=None, preview=preview)


def mode_video(samples):
    from PIL import Image
    results = {}
    with tempfile.TemporaryDirectory() as work:
        for name, (sample, tools, preview) in VIDEO_CASES.items():
            dst = Path(work) / f"{name}.mp4"
            info = run_video(samples / sample, dst, tools, preview)
            entry = {"entrada": sample, "pipeline": [t["procedure"] for t in tools], "preview": preview}
            if isinstance(info, dict) and info.get("output_type") in ("frames", "image"):
                out = Path(info["output_path"])
                files = sorted(out.iterdir()) if out.is_dir() else [out]
                entry["fotogramas"] = {f.name: pixel_hash(Image.open(f)) for f in files
                                       if f.suffix.lower() in (".png", ".jpg", ".jpeg")}
            else:
                entry.update(media_hash(dst))
            results[name] = entry
            print(f"[regressao] {name} ok", flush=True)
    return results


def main():
    mode, label = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "sem-etiqueta")
    if mode == "imagem":
        root = HERE.parents[2]
        results = mode_image(root)
        dest = root / "docs" / "fase2" / "medicoes" / "resultados" / label
    elif mode == "video":
        results = mode_video(Path("/samples"))
        dest = HERE / "resultados" / label
    else:
        raise SystemExit("modo: imagem | video")
    dest.mkdir(parents=True, exist_ok=True)
    (dest / f"regressao_{mode}.json").write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(results, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
