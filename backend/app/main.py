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
    
    msg_lower = chat.message.strip().lower()
    response = "I'm your AI Tutor! Ask me anything about your syllabus, Flutter, Python, or AI concepts."

    basic_intents = ["start with the basics", "from scratch", "fundamentals"]
    affirmative_intents = ["yes", "yeah", "yup", "ok", "okay", "sure", "please"]
    negative_intents = ["no", "nope", "not now", "later"]

    if "dsa" in msg_lower or "algorithm" in msg_lower:
        response = (
            "Great topic. Beginner DSA roadmap:\n"
            "1) Arrays and Strings\n"
            "2) Hashing\n"
            "3) Two Pointers + Sliding Window\n"
            "4) Linked List\n"
            "5) Stack and Queue\n"
            "6) Trees and basic graphs\n\n"
            "Let's start with Arrays first. Say 'arrays basics' or 'arrays practice questions'."
        )
    elif "arrays basics" in msg_lower or ("array" in msg_lower and "basic" in msg_lower):
        response = (
            "Arrays for beginners:\n"
            "- Array stores elements in contiguous memory\n"
            "- Access by index is O(1)\n"
            "- Searching in unsorted array is O(n)\n"
            "- Insert/delete in middle is O(n)\n\n"
            "Core starter problems: find max, reverse array, move zeros, two-sum."
        )
    elif "arrays" in msg_lower or "array" in msg_lower:
        response = (
            "Good choice. For Arrays, do this order:\n"
            "1) Traversal and indexing\n"
            "2) Min/Max and frequency count\n"
            "3) Two-sum\n"
            "4) Prefix sum basics\n"
            "5) Sliding window intro\n\n"
            "Say 'arrays practice questions' and I'll give you a mini set."
        )
    elif "practice" in msg_lower and ("array" in msg_lower or "dsa" in msg_lower or "algorithm" in msg_lower):
        response = (
            "Beginner practice (Arrays):\n"
            "1) Largest element in an array\n"
            "2) Second largest element\n"
            "3) Move all zeros to end\n"
            "4) Left rotate array by one\n"
            "5) Two-sum (return indices)\n\n"
            "If you want, I can send step-by-step hints for each."
        )
    elif any(intent in msg_lower for intent in basic_intents) or msg_lower in {"beginner", "beginners"}:
        response = (
            "Great choice. Let's start with the basics in 3 steps:\n"
            "1) Core concept: understand what the topic solves.\n"
            "2) Small example: build one tiny working example.\n"
            "3) Practice: solve 2 beginner questions and review mistakes.\n\n"
            "Tell me your exact topic (for example: Flutter widgets, Riverpod state, FastAPI routes), and I'll give a beginner roadmap."
        )
    elif msg_lower in affirmative_intents:
        response = (
            "Awesome. Share your topic name and your current level (beginner/intermediate), "
            "and I will give you a step-by-step study plan with examples."
        )
    elif msg_lower in negative_intents:
        response = "No problem. Whenever you're ready, send a topic and I will help you study it step by step."
    elif "flutter" in msg_lower or "riverpod" in msg_lower:
        response = (
            "Flutter basics roadmap:\n"
            "1) Widgets (Stateless vs Stateful)\n"
            "2) Layouts (Row, Column, Expanded, ListView)\n"
            "3) State management (setState -> Riverpod)\n"
            "4) API calls and model parsing\n\n"
            "If you want, I can start with a beginner Riverpod counter example."
        )
    elif "python" in msg_lower or "fastapi" in msg_lower:
        response = (
            "FastAPI basics roadmap:\n"
            "1) Path operations (GET/POST)\n"
            "2) Request body with Pydantic models\n"
            "3) Validation and error handling\n"
            "4) Database integration with SQLAlchemy\n\n"
            "Say 'show example' and I'll provide a simple endpoint + schema."
        )
    elif "binary search" in msg_lower or "tree" in msg_lower:
        response = (
            "Binary Search Tree basics:\n"
            "- Left child values are smaller than parent\n"
            "- Right child values are larger than parent\n"
            "- Average search time is O(log n)\n\n"
            "Would you like insertion and search code in Python?"
        )
    elif "campus" in msg_lower or "attendance" in msg_lower:
        response = (
            "Attendance flow:\n"
            "1) Register face\n"
            "2) Capture image and call /attendance/mark\n"
            "3) View daily status from /attendance/today\n\n"
            "If any step fails, tell me the exact error and I'll debug it with you."
        )
    elif "hello" in msg_lower or msg_lower == "hi":
        response = "Hello! I'm here to help you study. Tell me a topic and your level (beginner/intermediate)."
    else:
        response = (
            f"I can help with '{chat.message}'. "
            "Share your level (beginner/intermediate) and goal (learn basics, solve quiz, or build project), "
            "and I'll give a personalized step-by-step answer."
        )

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
