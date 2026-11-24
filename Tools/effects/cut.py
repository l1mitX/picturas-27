from PIL import Image


def cut(
    img: Image.Image,
    left: int,
    top: int,
    right: int,
    bottom: int,
    *,
    coerce: bool = True,
) -> Image.Image:
    box = (int(left), int(top), int(right), int(bottom)) if coerce else (
        left,
        top,
        right,
        bottom,
    )
    return img.crop(box)
