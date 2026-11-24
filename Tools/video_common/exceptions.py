class InvalidVideo(Exception):
    """File is not a readable video (corrupted, no video stream, ...)."""


class InvalidTrim(Exception):
    """Trim parameters outside the video duration or with end before start."""


class InvalidSpeed(Exception):
    """Speed factor outside the allowed range or not numeric."""


class ProcessingError(Exception):
    """ffmpeg failure while decoding or encoding."""


class UnsupportedEffect(Exception):
    """Effect is not supported by the video pipeline."""
