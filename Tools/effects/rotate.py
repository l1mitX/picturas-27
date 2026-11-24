from PIL import Image


def rotate(
    img: Image.Image, degrees: float, expand: bool = True, *, coerce: bool = True
) -> Image.Image:
    angle = float(degrees) if coerce else degrees
    return img.rotate(angle, expand=expand)
