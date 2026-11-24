from PIL import Image, ImageEnhance


def contrast(img: Image.Image, contrastFactor: float, *, coerce: bool = True) -> Image.Image:
    factor = float(contrastFactor) if coerce else contrastFactor
    return ImageEnhance.Contrast(img).enhance(factor)
