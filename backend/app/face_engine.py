import face_recognition
import numpy as np

import PIL.Image
import PIL.ImageOps
import cv2

def encode_face(image_file):
    # Load image using PIL to handle EXIF rotation from mobile cameras
    pil_img = PIL.Image.open(image_file)
    # Fix orientation if EXIF tag exists (prevents sideways faces failing detection)
    pil_img = PIL.ImageOps.exif_transpose(pil_img)
    pil_img = pil_img.convert("RGB")
    
    # Convert to numpy array for face_recognition
    image_np = np.array(pil_img)

    # Resize image if it's too large to prevent MemoryError (OOM)
    max_width = 800
    if image_np.shape[1] > max_width:
        ratio = max_width / image_np.shape[1]
        new_size = (max_width, int(image_np.shape[0] * ratio))
        # cv2 uses (width, height)
        image_np = cv2.resize(image_np, new_size, interpolation=cv2.INTER_AREA)

    # Use hog model. CNN causes MemoryError on standard CPUs without GPU setup.
    detection_passes = (
        {"number_of_times_to_upsample": 1, "model": "hog"},
        {"number_of_times_to_upsample": 2, "model": "hog"},
    )

    for detection_args in detection_passes:
        face_locations = face_recognition.face_locations(image_np, **detection_args)
        if not face_locations:
            continue

        encodings = face_recognition.face_encodings(
            image_np,
            known_face_locations=face_locations,
            num_jitters=2,
        )
        if encodings:
            return encodings[0]

    return None

def compare_faces(known_encodings, unknown_encoding, tolerance=0.5):
    matches = face_recognition.compare_faces(
        known_encodings, unknown_encoding, tolerance=tolerance
    )
    return matches


def find_best_match(known_encodings, unknown_encoding, tolerance=0.5):
    if not known_encodings:
        return None

    distances = face_recognition.face_distance(known_encodings, unknown_encoding)
    best_match_index = int(np.argmin(distances))

    if distances[best_match_index] <= tolerance:
        return best_match_index, float(distances[best_match_index])

    return None
