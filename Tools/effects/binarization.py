from PIL import Image, ImageOps


def binarization(
    img: Image.Image,
    threshold: int,
    *,
    output_mode: str = "RGB",
    coerce: bool = True,
) -> Image.Image:
    value = int(threshold) if coerce else threshold
    gray = ImageOps.grayscale(img).point(lambda x: 0 if x < value else 255)
    return gray.convert(output_mode) if output_mode != "L" else gray
