from fastapi import FastAPI, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app.models import Attendance, User
from app.face_engine import encode_face, find_best_match
import json
from datetime import date, datetime
import numpy as np

# Create the database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Campus AI Academy - CCTV Attendance API")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.post("/register/")
async def register_user(
    name: str = Form(...), 
    file: UploadFile = File(...), 
    db: Session = Depends(get_db)
):
    """
    Option A: User Registration API (Upload face from Flutter)
    Extracts face encoding and saves to database.
    """
    # Extract the face encoding
    encoding = encode_face(file.file)
    
    if encoding is None:
        raise HTTPException(status_code=400, detail="No face found in the provided image.")
        
    # Convert numpy array to list, then to JSON string
    encoding_json = json.dumps(encoding.tolist())
    
    # Save user to database
    new_user = User(name=name, face_encoding=encoding_json)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return {
        "message": "User registered successfully", 
        "user_id": new_user.id, 
        "name": new_user.name
    }


@app.post("/attendance/mark")
async def mark_attendance(
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Uploads a face image, matches it against registered users, and marks
    attendance once per day.
    """
    unknown_encoding = encode_face(file.file)

    if unknown_encoding is None:
        raise HTTPException(status_code=400, detail="No face found in the provided image.")

    users = db.query(User).all()
    if not users:
        raise HTTPException(status_code=404, detail="No registered users found.")

    known_encodings = [np.array(json.loads(user.face_encoding)) for user in users]
    matched = find_best_match(known_encodings, unknown_encoding, tolerance=0.5)

    if matched is None:
        raise HTTPException(status_code=404, detail="Face not recognized.")

    match_index, distance = matched
    user = users[match_index]
    today = date.today()

    attendance = (
        db.query(Attendance)
        .filter(Attendance.user_id == user.id, Attendance.date == today)
        .first()
    )

    if attendance is None:
        now = datetime.now()
        attendance = Attendance(
            user_id=user.id,
            date=today,
            time=now.time(),
            status="Present"
        )
        db.add(attendance)
        db.commit()
        db.refresh(attendance)
        attendance_marked = True
    else:
        attendance_marked = False

    return {
        "message": "Attendance marked successfully" if attendance_marked else "Attendance already marked today",
        "attendance_marked": attendance_marked,
        "user": {
            "id": user.id,
            "name": user.name,
        },
        "match_distance": distance,
        "attendance": {
            "id": attendance.id,
            "date": attendance.date.isoformat(),
            "time": attendance.time.isoformat(),
            "status": attendance.status,
        },
    }


@app.get("/attendance/today")
def get_today_attendance(db: Session = Depends(get_db)):
    """
    Returns all attendance records for today.
    Flutter App dashboard will call this API.
    """
    records = db.query(Attendance).filter(Attendance.date == date.today()).all()
    return records
