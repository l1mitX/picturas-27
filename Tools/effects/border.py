from PIL import Image, ImageOps


def border(
    img: Image.Image,
    borderWidth: int,
    r: int,
    g: int,
    b: int,
    *,
    coerce: bool = True,
) -> Image.Image:
    if coerce:
        borderWidth, r, g, b = map(int, (borderWidth, r, g, b))
    return ImageOps.expand(img, border=borderWidth, fill=(r, g, b))
