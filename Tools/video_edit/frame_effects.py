"""Per-frame effects of the edit stage (RNF2 T035, TAT-08).

The effects themselves live in Tools/effects/, one file per effect, shared with the image tools.
This module only maps each `procedure` to its function. The video path keeps the parameter
coercion and the RGB output, which are the defaults of the shared functions (research.md R8).
"""
from PIL import Image

from effects.binarization import binarization
from effects.border import border
from effects.brightness import brightness
from effects.contrast import contrast
from effects.cut import cut
from effects.resize import resize
from effects.rotate import rotate
from effects.saturation import saturation
from video_common.exceptions import UnsupportedEffect

FRAME_EFFECTS = {
    "brightness": brightness,
    "contrast": contrast,
    "saturation": saturation,
    "rotate": rotate,
    "resize": resize,
    "binarization": binarization,
    "cut": cut,
    "border": border,
}

TIME_EFFECTS = {"trim", "speed"}
SUPPORTED = set(FRAME_EFFECTS) | TIME_EFFECTS


def apply_frame_effects(img: Image.Image, tools: list) -> Image.Image:
    for tool in tools:
        name = tool["procedure"]
        if name in TIME_EFFECTS:
            continue
        fn = FRAME_EFFECTS.get(name)
        if fn is None:
            raise UnsupportedEffect(f"Effect '{name}' is not available for video")
        img = fn(img, **(tool.get("params") or {}))
        if img.mode != "RGB":
            img = img.convert("RGB")
    return img
