import cv2
import numpy as np
import PIL.Image
import PIL.ImageOps

# Max dimension for processing — phone cameras can be 12MP+.
# Cap at 640px to slash peak RAM from ~36 MB → ~1.2 MB per image.
_MAX_DIMENSION = 640

def _resize_to_fit(pil_img: PIL.Image.Image, max_dim: int = _MAX_DIMENSION) -> PIL.Image.Image:
    """Downscale image so neither width nor height exceeds max_dim. Preserves aspect ratio."""
    w, h = pil_img.size
    if max(w, h) <= max_dim:
        return pil_img
    scale = max_dim / max(w, h)
    new_w = max(1, int(w * scale))
    new_h = max(1, int(h * scale))
    return pil_img.resize((new_w, new_h), PIL.Image.LANCZOS)


def encode_face(image_file):
    try:
        image_file.seek(0)
    except Exception:
        pass

    try:
        pil_img = PIL.Image.open(image_file)
        pil_img = PIL.ImageOps.exif_transpose(pil_img)
        pil_img = pil_img.convert("RGB")
        # ✅ Resize FIRST — before converting to numpy — keeps peak RAM low
        pil_img = _resize_to_fit(pil_img)
    except Exception:
        return None

    image_np = np.array(pil_img)
    gray = cv2.cvtColor(image_np, cv2.COLOR_RGB2GRAY)

    # Frontal face detection
    face_cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
    )
    faces = face_cascade.detectMultiScale(
        gray,
        scaleFactor=1.05,
        minNeighbors=3,
        minSize=(20, 20),
    )

    # Fallback: profile/side face
    if len(faces) == 0:
        profile_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + 'haarcascade_profileface.xml'
        )
        faces = profile_cascade.detectMultiScale(
            gray,
            scaleFactor=1.05,
            minNeighbors=3,
            minSize=(20, 20),
        )

    if len(faces) == 0:
        return None

    x, y, w, h = faces[0]
    face_roi = image_np[y:y+h, x:x+w]

    # Color Histogram pseudo-encoding (lightweight for free tier)
    face_roi = cv2.resize(face_roi, (128, 128))
    hist = cv2.calcHist([face_roi], [0, 1, 2], None, [8, 8, 8], [0, 256, 0, 256, 0, 256])
    hist = cv2.normalize(hist, hist).flatten()

    return hist


def find_best_match(known_encodings, unknown_encoding, tolerance=0.5):
    if not known_encodings:
        return None

    unknown_arr = np.array(unknown_encoding, dtype=np.float32)
    distances = [
        cv2.compareHist(np.array(known, dtype=np.float32), unknown_arr, cv2.HISTCMP_BHATTACHARYYA)
        for known in known_encodings
    ]

    best_match_index = int(np.argmin(distances))
    if distances[best_match_index] <= tolerance:
        return best_match_index, float(distances[best_match_index])

    return None
