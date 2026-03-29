import cv2
import numpy as np
import time
from datetime import datetime
import json
import face_recognition

from app.database import SessionLocal
from app.models import User, Attendance

# Initialize camera
video = cv2.VideoCapture(0)

db = SessionLocal()

def load_new_faces(last_sync_time=None):
    if last_sync_time is None:
        users = db.query(User).all()
    else:
        users = db.query(User).filter(User.updated_at > last_sync_time).all()

    encodings = []
    ids = []
    max_sync_time = last_sync_time
    
    for user in users:
        enc = np.array(json.loads(user.face_encoding))
        encodings.append(enc)
        ids.append(user.id)
        if max_sync_time is None or (user.updated_at and user.updated_at > max_sync_time):
            max_sync_time = user.updated_at
            
    if max_sync_time is None:
        max_sync_time = datetime.min
        
    return encodings, ids, max_sync_time

known_encodings, known_ids, last_sync_time = load_new_faces(None)
marked_today = set()

RELOAD_INTERVAL = 10  # seconds
last_checked = time.time()

print("Starting CCTV Face Recognition Loop...")

while True:
    current_time = time.time()
    
    # Auto-reload logic
    if current_time - last_checked > RELOAD_INTERVAL:
        new_encs, new_ids, new_sync_time = load_new_faces(last_sync_time)
        if len(new_ids) > 0:
            print(f"🔄 Loaded {len(new_ids)} new users from DB!")
            known_encodings.extend(new_encs)
            known_ids.extend(new_ids)
            last_sync_time = new_sync_time
        last_checked = current_time

    ret, frame = video.read()
    if not ret:
        break

    # Resize for faster processing
    small = cv2.resize(frame, (0, 0), fx=0.25, fy=0.25)
    rgb = small[:, :, ::-1]

    faces = face_recognition.face_locations(rgb)
    encodings = face_recognition.face_encodings(rgb, faces)

    for encoding, face_location in zip(encodings, faces):
        matches = face_recognition.compare_faces(known_encodings, encoding, tolerance=0.5)

        if True in matches:
            idx = matches.index(True)
            user_id = known_ids[idx]
            today = datetime.now().date()

            if (user_id, today) not in marked_today:
                marked_today.add((user_id, today))
                
                attendance = Attendance(
                    user_id=user_id,
                    date=today,
                    time=datetime.now().time(),
                    status="Present"
                )
                db.add(attendance)
                db.commit()
                print(f"✅ Marked Present: User ID {user_id}")

            # Draw rectangle for UI (Optional)
            top, right, bottom, left = [coord * 4 for coord in face_location] # scale back up
            cv2.rectangle(frame, (left, top), (right, bottom), (0, 255, 0), 2)
            cv2.putText(frame, f"ID: {user_id}", (left, top - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)

    cv2.imshow("CCTV Attendance Monitor", frame)
    
    # Press 'q' to quit
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

video.release()
cv2.destroyAllWindows()
