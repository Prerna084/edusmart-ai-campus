import cv2
import numpy as np
import PIL.Image
import PIL.ImageOps

_MAX_DIMENSION = 640

def _resize_to_fit(pil_img: PIL.Image.Image, max_dim: int = _MAX_DIMENSION) -> PIL.Image.Image:
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
        pil_img = _resize_to_fit(pil_img)
    except Exception:
        return None

    image_np = np.array(pil_img)
    gray = cv2.cvtColor(image_np, cv2.COLOR_RGB2GRAY)
    
    # Equalize histogram on grayscale to handle lighting differences
    gray = cv2.equalizeHist(gray)

    face_cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
    )
    faces = face_cascade.detectMultiScale(
        gray,
        scaleFactor=1.05,
        minNeighbors=3,
        minSize=(20, 20),
    )

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
    
    # Take the central 70% of the face bounding box to exclude background/clothing
    # This makes the histogram significantly more reliable!
    cx_offset = int(w * 0.15)
    cy_offset = int(h * 0.15)
    cw = int(w * 0.70)
    ch = int(h * 0.70)
    
    face_roi = image_np[y+cy_offset:y+cy_offset+ch, x+cx_offset:x+cx_offset+cw]

    # Convert to YCrCb for more robust color illumination invariance
    face_roi_ycrcb = cv2.cvtColor(face_roi, cv2.COLOR_RGB2YCrCb)
    face_roi_ycrcb = cv2.resize(face_roi_ycrcb, (128, 128))
    
    hist = cv2.calcHist([face_roi_ycrcb], [0, 1, 2], None, [8, 8, 8], [0, 256, 0, 256, 0, 256])
    hist = cv2.normalize(hist, hist).flatten()

    return hist


def find_best_match(known_encodings, unknown_encoding, tolerance=0.5):
    # Override strict tolerance passed from main.py -- 0.5 is way too strict for Bhattacharyya distance in the wild
    # 0.75 provides a good balance for cropped color histograms.
    realistic_tolerance = 0.75
    
    if not known_encodings or unknown_encoding is None:
        return None

    unknown_arr = np.array(unknown_encoding, dtype=np.float32)
    distances = []
    
    for known in known_encodings:
        known_arr = np.array(known, dtype=np.float32)
        # Verify shape (512 for our 8x8x8 hist) to prevent crashes if different encodings were stored
        if known_arr.shape == unknown_arr.shape:
            dist = cv2.compareHist(known_arr, unknown_arr, cv2.HISTCMP_BHATTACHARYYA)
            distances.append(dist)
        else:
            distances.append(1.0) # Maximum distance for mismatched shape

    if not distances:
        return None

    best_match_index = int(np.argmin(distances))
    if distances[best_match_index] <= realistic_tolerance:
        return best_match_index, float(distances[best_match_index])

    return None
