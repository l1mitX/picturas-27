from .exceptions import (
    InvalidSpeed,
    InvalidTrim,
    InvalidVideo,
    ProcessingError,
    UnsupportedEffect,
)
from .frame_validation import InvalidExtraction

CODES = {
    "wrong_procedure": 2000,
    "error_processing": 2001,
    "unsupported_effect": 2002,
    "invalid_trim": 2003,
    "invalid_video": 2004,
    "invalid_speed": 2005,
}
