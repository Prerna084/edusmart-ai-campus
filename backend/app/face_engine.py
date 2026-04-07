import cv2
import numpy as np
import PIL.Image
import PIL.ImageOps

def encode_face(image_file):
    try:
        image_file.seek(0)
    except Exception:
        pass

    try:
        pil_img = PIL.Image.open(image_file)
        pil_img = PIL.ImageOps.exif_transpose(pil_img)
        pil_img = pil_img.convert("RGB")
    except Exception:
        return None

    image_np = np.array(pil_img)
    gray = cv2.cvtColor(image_np, cv2.COLOR_RGB2GRAY)

    # Use OpenCV Haar Cascades for face detection
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    faces = face_cascade.detectMultiScale(
        gray,
        scaleFactor=1.05,   # finer scale steps → catches more faces
        minNeighbors=3,     # less strict → fewer false negatives on mobile photos
        minSize=(20, 20),   # smaller min size → catches farther/smaller faces
    )

    # Second-pass fallback: try profile/side-face cascade if frontal fails
    if len(faces) == 0:
        profile_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_profileface.xml')
        faces = profile_cascade.detectMultiScale(
            gray,
            scaleFactor=1.05,
            minNeighbors=3,
            minSize=(20, 20),
        )

    if len(faces) == 0:
        return None

    # Get the first detected face
    x, y, w, h = faces[0]
    face_roi = image_np[y:y+h, x:x+w]

    # Calculate Color Histogram as a pseudo-encoding (quick & lightweight for free tier)
    face_roi = cv2.resize(face_roi, (128, 128))
    hist = cv2.calcHist([face_roi], [0, 1, 2], None, [8, 8, 8], [0, 256, 0, 256, 0, 256])
    hist = cv2.normalize(hist, hist).flatten()

    return hist

def find_best_match(known_encodings, unknown_encoding, tolerance=0.5):
    if not known_encodings:
        return None

    distances = []
    unknown_arr = np.array(unknown_encoding, dtype=np.float32)

    for known in known_encodings:
        known_arr = np.array(known, dtype=np.float32)
        # Use Bhattacharyya distance for histogram comparison (0 = match, 1 = mismatch)
        dist = cv2.compareHist(known_arr, unknown_arr, cv2.HISTCMP_BHATTACHARYYA)
        distances.append(dist)

    best_match_index = int(np.argmin(distances))

    if distances[best_match_index] <= tolerance:
        return best_match_index, float(distances[best_match_index])

    return None

