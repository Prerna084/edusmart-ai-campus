from fastapi import FastAPI, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app.models import Attendance, User, Subject, SyllabusModule, Topic
from app.face_engine import encode_face, find_best_match
import json
from datetime import date, datetime
import numpy as np
from pydantic import BaseModel
import asyncio

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
    Returns all attendance records for today with user names.
    Flutter App dashboard will call this API.
    """
    results = (
        db.query(
            Attendance.id,
            Attendance.date,
            Attendance.time,
            Attendance.status,
            User.name.label("student_name"),
        )
        .join(User, Attendance.user_id == User.id)
        .filter(Attendance.date == date.today())
        .order_by(Attendance.time.desc())
        .all()
    )

    return [
        {
            "id": r.id,
            "student_name": r.student_name,
            "date": r.date.isoformat(),
            "time": r.time.strftime("%I:%M %p"),
            "status": r.status,
        }
        for r in results
    ]

# --- AI Tutor Chatbot Simulator ---
class ChatMessage(BaseModel):
    message: str

@app.post("/tutor/ask")
async def ask_tutor(chat: ChatMessage):
    """
    Simulates an AI Tutor response. 
    Can be easily replaced with an OpenAI, Gemini, or Claude API call.
    """
    await asyncio.sleep(1.5)  # Simulate API thinking time
    
    msg_lower = chat.message.lower()
    response = "I'm your AI Tutor! Ask me anything about your syllabus, Flutter, Python, or AI concepts."
    
    if "flutter" in msg_lower or "riverpod" in msg_lower:
        response = "Flutter is fantastic for responsive UI! By using Riverpod, you can seamlessly tie backend data (like FastAPIs) into an elegant, reactive state without hassle. Need a code snippet for state management?"
    elif "python" in msg_lower or "fastapi" in msg_lower:
        response = "FastAPI is a modern, fast web framework for building APIs with Python. It natively handles async functions making it perfect for operations like AI requests or database interactions."
    elif "hello" in msg_lower or "hi" in msg_lower:
        response = "Hello! I'm here to help you study. Which topic from your syllabus are we tackling today?"
    elif "binary search" in msg_lower or "tree" in msg_lower:
        response = "A Binary Search Tree is a data structure where each node has at most two children. The left child is always smaller, and the right child is always larger than the parent. Want an example in Python?"
    elif "campus" in msg_lower or "attendance" in msg_lower:
        response = "You can log your attendance completely automatically now using the Face Recognition portal on the Home screen. Ensure you've registered your face profile first!"
    else:
        response = f"That's an interesting question about '{chat.message}'. Currently, I'm analyzing that topic based on your current syllabus modules. Would you like me to find a specific resource?"

    return {"response": response}

# ── Syllabus API ─────────────────────────────────────────────────────────────

@app.get("/syllabus")
def get_syllabus(db: Session = Depends(get_db)):
    """
    Returns all subjects with their modules.
    Flutter SyllabusScreen calls this on load.
    """
    subjects = db.query(Subject).all()
    result = []
    for subj in subjects:
        modules = (
            db.query(SyllabusModule)
            .filter(SyllabusModule.subject_id == subj.id)
            .order_by(SyllabusModule.order_index)
            .all()
        )
        module_list = []
        for mod in modules:
            topics = (
                db.query(Topic)
                .filter(Topic.module_id == mod.id)
                .all()
            )
            module_list.append({
                "id": mod.id,
                "title": mod.title,
                "is_completed": bool(mod.is_completed),
                "topics": [{"id": t.id, "title": t.title} for t in topics],
            })
        result.append({
            "id": subj.id,
            "title": subj.title,
            "tag": subj.tag,
            "progress": subj.progress,
            "next_module": subj.next_module,
            "modules": module_list,
        })
    return result


@app.get("/syllabus/topic/{topic_id}")
def get_topic(topic_id: int, db: Session = Depends(get_db)):
    """
    Returns the full rich content for a single topic.
    Flutter TopicDetailScreen calls this when user taps a module.
    """
    topic = db.query(Topic).filter(Topic.id == topic_id).first()
    if not topic:
        raise HTTPException(status_code=404, detail="Topic not found")
    return {
        "id": topic.id,
        "title": topic.title,
        "theory": topic.theory,
        "video_url": topic.video_url,
        "doc_url": topic.doc_url,
        "code_example": topic.code_example,
        "practice_task": topic.practice_task,
    }
