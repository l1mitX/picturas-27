from PIL import Image


def resize(
    img: Image.Image, width: int, height: int, *, coerce: bool = True
) -> Image.Image:
    dimensions = (int(width), int(height)) if coerce else (width, height)
    return img.resize(dimensions)
