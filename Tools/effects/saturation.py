from PIL import Image, ImageEnhance


def saturation(img: Image.Image, saturationFactor: float, *, coerce: bool = True) -> Image.Image:
    factor = float(saturationFactor) if coerce else saturationFactor
    return ImageEnhance.Color(img).enhance(factor)
