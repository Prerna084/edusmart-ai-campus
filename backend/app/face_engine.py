"""Face encoding / matching. Uses numpy + PIL for broad compatibility."""
from __future__ import annotations

import io
import json
from typing import Any

import numpy as np
from PIL import Image

# try:
#     import face_recognition

#     _HAS_FR = True
# except ImportError:
#     _HAS_FR = False

# Temporarily disable face recognition due to import warning
_HAS_FR = False


def face_available() -> bool:
    return _HAS_FR


def encode_face_from_bytes(image_bytes: bytes) -> np.ndarray | None:
    if not _HAS_FR:
        return None
    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        arr = np.array(img)
        encodings = face_recognition.face_encodings(arr)
        if encodings:
            return encodings[0]
    except Exception:
        return None
    return None


def encoding_to_json(enc: np.ndarray) -> str:
    return json.dumps(enc.tolist())


def json_to_encoding(s: str) -> np.ndarray:
    return np.array(json.loads(s), dtype=float)


def best_match(
    unknown: np.ndarray,
    users: list[tuple[int, str]],
    tolerance: float = 0.55,
) -> tuple[int | None, float]:
    """Returns (user_id, distance) or (None, inf). users: list of (id, encoding_json)."""
    if not _HAS_FR or unknown is None:
        return None, float("inf")
    best_id: int | None = None
    best_dist = float("inf")
    for uid, enc_json in users:
        if not enc_json:
            continue
        try:
            known = json_to_encoding(enc_json)
            dist = float(face_recognition.face_distance([known], unknown)[0])
            if dist < best_dist:
                best_dist = dist
                best_id = uid
        except Exception:
            continue
    if best_id is not None and best_dist <= tolerance:
        return best_id, best_dist
    return None, best_dist
