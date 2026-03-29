import face_recognition

def encode_face(image_bytes):
    # Load image from bytes
    image_np = face_recognition.load_image_file(image_bytes)
    # Get encodings
    encodings = face_recognition.face_encodings(image_np)
    
    if len(encodings) > 0:
        return encodings[0]
    return None

def compare_faces(known_encodings, unknown_encoding, tolerance=0.5):
    matches = face_recognition.compare_faces(
        known_encodings, unknown_encoding, tolerance=tolerance
    )
    return matches
