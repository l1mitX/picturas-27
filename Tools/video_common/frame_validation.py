import math


class InvalidExtraction(ValueError):
    """Invalid frame extraction parameters or an excessive output count."""


def validate_params(params):
    if not isinstance(params, dict):
        raise InvalidExtraction("Frame extraction requires parameters")
    mode = params.get("mode", "count")
    fmt = params.get("format", "png")
    if mode not in ("count", "interval") or fmt not in ("png", "jpeg"):
        raise InvalidExtraction("Choose count/interval and PNG/JPEG")
    value = params.get("count", 6) if mode == "count" else params.get("interval", 2)
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise InvalidExtraction("Frame count or interval must be a finite number")
    if mode == "count" and (value != int(value) or not 1 <= value <= 100):
        raise InvalidExtraction("Frame count must be an integer between 1 and 100")
    if mode == "interval" and value <= 0:
        raise InvalidExtraction("Frame interval must be greater than zero")
    return mode, value, fmt
