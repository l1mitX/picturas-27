from PIL import Image, ImageEnhance


def brightness(img: Image.Image, brightness: float, *, coerce: bool = True) -> Image.Image:
    factor = float(brightness) if coerce else brightness
    return ImageEnhance.Brightness(img).enhance(factor)
