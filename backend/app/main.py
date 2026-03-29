from fastapi import FastAPI, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app.models import Attendance, User
from app.face_engine import encode_face
import json
from datetime import date

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


@app.get("/attendance/today")
def get_today_attendance(db: Session = Depends(get_db)):
    """
    Returns all attendance records for today.
    Flutter App dashboard will call this API.
    """
    records = db.query(Attendance).filter(Attendance.date == date.today()).all()
    return records
