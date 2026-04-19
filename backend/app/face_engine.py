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


def _get_lbp_hist(gray_img):
    """
    Calculates Local Binary Patterns (LBP) histogram to capture face texture.
    This is much more robust to lighting and clothing changes than color.
    """
    h, w = gray_img.shape
    # We use a vectorized numpy approach for speed on the server
    lbp = np.zeros((h - 2, w - 2), dtype=np.uint8)
    
    # 8-neighbor weights
    weights = [1, 2, 4, 8, 16, 32, 64, 128]
    offsets = [(-1, -1), (-1, 0), (-1, 1), (0, 1), (1, 1), (1, 0), (1, -1), (0, -1)]
    
    center = gray_img[1:h-1, 1:w-1]
    for i, (dy, dx) in enumerate(offsets):
        neighbor = gray_img[1+dy:h-1+dy, 1+dx:w-1+dx]
        lbp += ((neighbor >= center).astype(np.uint8) * weights[i])
        
    hist, _ = np.histogram(lbp, bins=256, range=(0, 256))
    hist = hist.astype("float32")
    hist /= (hist.sum() + 1e-7)
    return hist


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
    gray_eq = cv2.equalizeHist(gray)

    face_cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
    )
    faces = face_cascade.detectMultiScale(
        gray_eq,
        scaleFactor=1.05,
        minNeighbors=4, # Slightly stricter detection
        minSize=(30, 30),
    )

    if len(faces) == 0:
        return None

    # Sort faces by size (descending) and take the primary one
    faces = sorted(faces, key=lambda f: f[2] * f[3], reverse=True)
    x, y, w, h = faces[0]
    
    # ── 1. Color Signature ──────────────────────────────────────────────────
    # Take the central 70% of the face to exclude background/clothing
    cx_offset, cy_offset = int(w * 0.15), int(h * 0.15)
    cw, ch = int(w * 0.70), int(h * 0.70)
    
    face_roi_color = image_np[y+cy_offset:y+cy_offset+ch, x+cx_offset:x+cx_offset+cw]
    face_roi_ycrcb = cv2.cvtColor(face_roi_color, cv2.COLOR_RGB2YCrCb)
    face_roi_ycrcb = cv2.resize(face_roi_ycrcb, (128, 128))
    
    color_hist = cv2.calcHist([face_roi_ycrcb], [0, 1, 2], None, [8, 8, 8], [0, 256, 0, 256, 0, 256])
    color_hist = cv2.normalize(color_hist, color_hist).flatten()

    # ── 2. Texture Signature (LBP) ──────────────────────────────────────────
    # Texture is more robust than color for distinguishing similar people
    face_roi_gray = gray_eq[y:y+h, x:x+w]
    face_roi_gray = cv2.resize(face_roi_gray, (128, 128))
    texture_hist = _get_lbp_hist(face_roi_gray)

    # ── 3. Hybrid Signature ──────────────────────────────────────────────────
    # Concatenate color (512) and texture (256) into a 768-D vector
    hybrid_signature = np.concatenate([color_hist, texture_hist])
    return hybrid_signature


def find_best_match(known_encodings, unknown_encoding, tolerance=0.6):
    """
    Finds the best match using combined Bhattacharyya distance.
    Stricter tolerance (0.6) reduces false positives.
    """
    if not known_encodings or unknown_encoding is None:
        return None

    unknown_arr = np.array(unknown_encoding, dtype=np.float32)
    distances = []
    
    for known in known_encodings:
        known_arr = np.array(known, dtype=np.float32)
        # Verify shape to handle potential old encodings in DB
        if known_arr.shape == unknown_arr.shape:
            dist = cv2.compareHist(known_arr, unknown_arr, cv2.HISTCMP_BHATTACHARYYA)
            distances.append(dist)
        else:
            distances.append(1.0) # Maximum distance for mismatched shape types

    if not distances:
        return None

    best_match_index = int(np.argmin(distances))
    if distances[best_match_index] <= tolerance:
        return best_match_index, float(distances[best_match_index])

    return None
