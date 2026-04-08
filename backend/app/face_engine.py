import cv2
import numpy as np
import PIL.Image
import PIL.ImageOps
import face_recognition

# Max dimension for processing — to speed up encoding while keeping accuracy.
_MAX_DIMENSION = 800

def _resize_to_fit(pil_img: PIL.Image.Image, max_dim: int = _MAX_DIMENSION) -> PIL.Image.Image:
    \"\"\"Downscale image so neither width nor height exceeds max_dim. Preserves aspect ratio.\"\"\"
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
    
    # face_recognition takes an RGB numpy array
    face_locations = face_recognition.face_locations(image_np)
    
    if len(face_locations) == 0:
        return None
        
    # We take the first face detected
    face_encodings = face_recognition.face_encodings(image_np, face_locations)
    
    if len(face_encodings) == 0:
        return None
        
    return face_encodings[0]


def find_best_match(known_encodings, unknown_encoding, tolerance=0.5):
    if not known_encodings or unknown_encoding is None:
        return None

    # unknown_encoding is passed from encode_face (which is numpy array of length 128)
    unknown_arr = np.array(unknown_encoding, dtype=np.float32)
    
    # Filter out legacy 512-dim color histogram encodings so they don't crash face_distance
    known_encodings_np = []
    known_indices = []
    
    for i, known in enumerate(known_encodings):
        arr = np.array(known, dtype=np.float32)
        if arr.shape == (128,):
            known_encodings_np.append(arr)
            known_indices.append(i)
            
    if not known_encodings_np:
        return None
    
    # Calculate Euclidean distance using face_recognition
    distances = face_recognition.face_distance(known_encodings_np, unknown_arr)
    
    if len(distances) == 0:
        return None

    best_local_index = int(np.argmin(distances))
    if distances[best_local_index] <= tolerance:
        return known_indices[best_local_index], float(distances[best_local_index])

    return None
