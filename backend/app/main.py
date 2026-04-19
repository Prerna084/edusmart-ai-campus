from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app.models import Attendance, User, StudentProfile, Subject, SyllabusModule, Topic, ScheduledTest, TestResult
from app import schemas
from app.face_engine import encode_face, find_best_match
import json
from datetime import date, datetime
import numpy as np
from pydantic import BaseModel
import asyncio
from fastapi.middleware.cors import CORSMiddleware

# Create the database tables
Base.metadata.create_all(bind=engine)

# Auto-upgrade SQLite / Postgres tables for all models
from sqlalchemy import text
with engine.connect() as conn:
    # Users table upgrades
    for col in [
        ("email", "VARCHAR UNIQUE"),
        ("password_hash", "VARCHAR"),
        ("name", "VARCHAR"),
        ("face_encoding", "TEXT"), # Support longer encoding strings if needed
        ("updated_at", "TIMESTAMP DEFAULT CURRENT_TIMESTAMP")
    ]:
        try:
            conn.execute(text(f"ALTER TABLE users ADD COLUMN {col[0]} {col[1]}"))
        except Exception:
            pass
            
    # Student Profile upgrades
    for col in [
        ("email", "VARCHAR"),
        ("phone", "VARCHAR"),
        ("department", "VARCHAR"),
        ("year", "VARCHAR"),
        ("semester", "VARCHAR"),
        ("batch", "VARCHAR"),
        ("section", "VARCHAR"),
        ("college_id", "VARCHAR UNIQUE")
    ]:
        try:
            conn.execute(text(f"ALTER TABLE student_profiles ADD COLUMN {col[0]} {col[1]}"))
        except Exception:
            pass

    # Scheduled Test upgrades
    for col in [
        ("time_limit_minutes", "INTEGER DEFAULT 15"),
        ("valid_until", "TIMESTAMP"),
        ("max_attempts", "INTEGER DEFAULT 1"),
        ("num_questions", "INTEGER DEFAULT 5"),
        ("difficulty", "VARCHAR DEFAULT 'Mixed Mode'")
    ]:
        try:
            conn.execute(text(f"ALTER TABLE scheduled_tests ADD COLUMN {col[0]} {col[1]}"))
        except Exception:
            pass

    # Test Results upgrades
    for col in [
        ("questions_data", "TEXT"),
        ("user_answers_data", "TEXT"),
        ("teacher_feedback", "TEXT")
    ]:
        try:
            conn.execute(text(f"ALTER TABLE test_results ADD COLUMN {col[0]} {col[1]}"))
        except Exception:
            pass

    try:
        conn.commit()
    except Exception:
        pass
def _auto_seed_syllabus():
    """Seed syllabus data if the subjects table is empty."""
    db = SessionLocal()
    try:
        count = db.query(Subject).count()
        if count == 0:
            print("📚 No syllabus data found — auto-seeding…")
            from app.syllabus_seed import seed
            seed()
            print("✅ Syllabus auto-seed complete.")
        else:
            print(f"📚 Syllabus already has {count} subject(s), skipping seed.")
    except Exception as e:
        print(f"⚠️ Auto-seed failed (non-fatal): {e}")
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ──
    _auto_seed_syllabus()
    yield
    # ── Shutdown ──


app = FastAPI(title="Campus AI Academy - CCTV Attendance API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ── Authentication API ───────────────────────────────────────────────────────

@app.post("/auth/register")
def register_student(data: schemas.StudentRegisterRequest, db: Session = Depends(get_db)):
    # Check if email exists
    try:
        existing = db.query(User).filter(User.email == data.email).first()
        if existing:
            raise HTTPException(status_code=400, detail="Email already registered")
        
        # Create user
        new_user = User(
            name=data.name,
            email=data.email,
            password_hash=data.password # Mock hashing for simplicity
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        # Create profile
        profile = StudentProfile(
            user_id=new_user.id,
            email=data.email,
            batch=data.batch,
            semester=data.semester,
            section=data.section
        )
        db.add(profile)
        db.commit()
        
        return {"message": "Student registered successfully", "user_id": new_user.id}
    except Exception as e:
        db.rollback()
        # Handle specific integrity errors if possible, or generic 500 with more info
        if "UNIQUE constraint failed" in str(e) or "duplicate key" in str(e):
             raise HTTPException(status_code=400, detail="Email or College ID already exists")
        print(f"Error during registration: {e}")
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")

@app.post("/auth/login")
def login_student(data: schemas.LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user or user.password_hash != data.password:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    profile = db.query(StudentProfile).filter(StudentProfile.user_id == user.id).first()
    
    return {
        "user_id": user.id,
        "name": user.name,
        "profile": {
            "email": user.email,
            "phone": profile.phone if profile else "",
            "department": profile.department if profile else "",
            "year": profile.year if profile else "",
            "semester": profile.semester if profile else "",
            "batch": profile.batch if profile else "",
            "section": profile.section if profile else "",
            "college_id": profile.college_id if profile else "",
        }
    }

@app.post("/auth/forgot-password")
def forgot_password(data: schemas.ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        # Silently fail or inform? User says: "If the email exists..."
        raise HTTPException(status_code=404, detail="Email not found")
    
    # Generate random password
    import random
    import string
    new_pwd = ''.join(random.choices(string.ascii_letters + string.digits, k=8))
    user.password_hash = new_pwd
    db.commit()
    
    # Mock sending email
    return {"message": "New password generated and sent to email", "temp_password": new_pwd}

@app.post("/students/{user_id}/college-id")
def set_college_id(user_id: int, data: schemas.UpdateCollegeIdRequest, db: Session = Depends(get_db)):
    import re
    if not re.match(r"^[a-zA-Z0-9]+$", data.college_id):
        raise HTTPException(status_code=400, detail="Student ID contains special characters")
    
    profile = db.query(StudentProfile).filter(StudentProfile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Student profile not found")
    
    if profile.college_id:
        raise HTTPException(status_code=403, detail="Student ID is already set and cannot be changed")
    
    profile.college_id = data.college_id
    db.commit()
    return {"message": "Student ID set successfully"}

@app.post("/admin/students/{user_id}/reset-college-id")
def reset_college_id(user_id: int, db: Session = Depends(get_db)):
    profile = db.query(StudentProfile).filter(StudentProfile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Student profile not found")
    
    profile.college_id = None
    db.commit()
    return {"message": "Student ID cleared successfully"}

@app.post("/students/{user_id}/change-password")
def change_password(user_id: int, data: schemas.UpdatePasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if user.password_hash != data.old_password:
        raise HTTPException(status_code=401, detail="Incorrect old password")
    
    user.password_hash = data.new_password
    db.commit()
    return {"message": "Password changed successfully"}


@app.post("/register/")
async def register_user(
    name: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Registers a new user with their face encoding.
    Duplicate-safe:
      - If the uploaded face matches an existing user → returns that user (no new row).
      - If the name already exists with a different face → updates their encoding (no new row).
      - Only inserts a new row when the face AND name are both genuinely new.
    """
    # Reject default Swagger 'string' name
    if name.strip().lower() == "string":
        raise HTTPException(
            status_code=400,
            detail="Please provide a real name, not 'string'.",
        )



    encoding = encode_face(file.file)

    if encoding is None:
        raise HTTPException(
            status_code=400,
            detail=(
                "Could not process the uploaded file or no face found. "
                "Please upload a clear face photo (JPEG or PNG). "
                f"Received filename: '{file.filename}', content-type: '{file.content_type}'."
            ),
        )

    # ── 1. Face-duplicate check ───────────────────────────────────────────────
    existing_users = db.query(User).filter(User.face_encoding != None).all()
    if existing_users:
        known_encodings = [np.array(json.loads(u.face_encoding)) for u in existing_users]
        matched = find_best_match(known_encodings, encoding, tolerance=0.5)
        if matched is not None:
            match_index, distance = matched
            existing = existing_users[match_index]
            return {
                "message": "Already registered — face matched existing record.",
                "already_existed": True,
                "user_id": existing.id,
                "name": existing.name,
                "match_distance": round(distance, 4),
            }

    # ── 2. Name-duplicate check ───────────────────────────────────────────────
    name_clean = name.strip()
    existing_by_name = db.query(User).filter(User.name == name_clean).first()
    if existing_by_name:
        # Same name, different face → update encoding so they don't get locked out
        existing_by_name.face_encoding = json.dumps(encoding.tolist())
        db.commit()
        db.refresh(existing_by_name)
        return {
            "message": "Name already registered — face encoding updated.",
            "already_existed": True,
            "user_id": existing_by_name.id,
            "name": existing_by_name.name,
        }

    # ── 3. Genuinely new — insert ─────────────────────────────────────────────
    new_user = User(name=name_clean, face_encoding=json.dumps(encoding.tolist()))
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return {
        "message": "User registered successfully",
        "already_existed": False,
        "user_id": new_user.id,
        "name": new_user.name,
    }


@app.post("/admin/deduplicate")
def deduplicate_students(db: Session = Depends(get_db)):
    """
    One-shot cleanup: finds all users with duplicate names, keeps the
    record with the lowest ID (earliest registration), re-parents any
    attendance + profile rows to the survivor, then deletes the extras.
    Returns a report of what was merged.
    """
    all_users = db.query(User).order_by(User.id).all()

    # Group by lowercased name
    from collections import defaultdict
    name_map: dict = defaultdict(list)
    for u in all_users:
        name_map[u.name.strip().lower()].append(u)

    merged = []
    for name_key, users in name_map.items():
        if len(users) <= 1:
            continue  # no duplicate

        # Survivor = lowest ID (oldest record)
        survivor = users[0]
        duplicates = users[1:]
        dup_ids = [d.id for d in duplicates]

        # Re-parent attendance rows — skip if survivor already has that date
        for dup in duplicates:
            dup_records = db.query(Attendance).filter(Attendance.user_id == dup.id).all()
            for rec in dup_records:
                conflict = (
                    db.query(Attendance)
                    .filter(
                        Attendance.user_id == survivor.id,
                        Attendance.date == rec.date,
                    )
                    .first()
                )
                if conflict is None:
                    rec.user_id = survivor.id
                else:
                    db.delete(rec)  # duplicate date — discard

        # Re-parent / discard student_profiles
        for dup in duplicates:
            dup_profile = (
                db.query(StudentProfile).filter(StudentProfile.user_id == dup.id).first()
            )
            if dup_profile:
                survivor_profile = (
                    db.query(StudentProfile)
                    .filter(StudentProfile.user_id == survivor.id)
                    .first()
                )
                if survivor_profile is None:
                    dup_profile.user_id = survivor.id  # migrate
                else:
                    db.delete(dup_profile)  # survivor already has one

        db.flush()

        # Delete duplicate user rows
        for dup in duplicates:
            db.delete(dup)

        merged.append({
            "name": survivor.name,
            "survivor_id": survivor.id,
            "removed_ids": dup_ids,
        })

    db.commit()

    return {
        "message": f"Deduplication complete. {len(merged)} name group(s) merged.",
        "merged": merged,
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
        raise HTTPException(
            status_code=400,
            detail=(
                "Could not process the uploaded file or no face found. "
                "Please upload a clear face photo (JPEG or PNG). "
                f"Received filename: '{file.filename}', content-type: '{file.content_type}'."
            ),
        )

    users = db.query(User).filter(User.face_encoding != None).all()
    if not users:
        raise HTTPException(status_code=404, detail="No registered users with face data found.")

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

@app.post("/recognize")
async def recognize_face(
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Uploads a face image and identifies the best matching registered user.
    This endpoint does not mark attendance; it only performs recognition.
    """


    unknown_encoding = encode_face(file.file)

    if unknown_encoding is None:
        raise HTTPException(
            status_code=400,
            detail=(
                "Could not process the uploaded file or no face found. "
                "Please upload a clear face photo (JPEG or PNG). "
                f"Received filename: '{file.filename}', content-type: '{file.content_type}'."
            ),
        )

    users = db.query(User).filter(User.face_encoding != None).all()
    if not users:
        raise HTTPException(status_code=404, detail="No registered users with face data found.")

    known_encodings = [np.array(json.loads(user.face_encoding)) for user in users]
    matched = find_best_match(known_encodings, unknown_encoding, tolerance=0.5)

    if matched is None:
        return {
            "recognized": False,
            "message": "Unknown face",
            "user": None,
            "match_distance": None,
        }

    match_index, distance = matched
    user = users[match_index]

    confidence = max(0.0, min(1.0, 1.0 - float(distance)))

    return {
        "recognized": True,
        "message": "Face recognized",
        "user": {
            "id": user.id,
            "name": user.name,
        },
        "match_distance": float(distance),
        "confidence": round(confidence, 4),
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


@app.get("/attendance/{student_id}")
def get_student_attendance(student_id: int, db: Session = Depends(get_db)):
    """
    Returns full attendance history for one student, newest first.
    Intended for Student Dashboard attendance view.
    """
    user = db.query(User).filter(User.id == student_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Student not found")

    records = (
        db.query(Attendance)
        .filter(Attendance.user_id == student_id)
        .order_by(Attendance.date.desc(), Attendance.time.desc())
        .all()
    )

    attendance_items = [
        {
            "id": r.id,
            "date": r.date.isoformat() if r.date else None,
            "time": r.time.strftime("%I:%M %p") if r.time else None,
            "status": r.status,
        }
        for r in records
    ]

    total_days = len(records)
    present_days = sum(1 for r in records if (r.status or "").lower() == "present")
    attendance_percentage = round((present_days / total_days) * 100, 2) if total_days > 0 else 0.0

    return {
        "student": {
            "id": user.id,
            "name": user.name,
        },
        "summary": {
            "total_days": total_days,
            "present_days": present_days,
            "attendance_percentage": attendance_percentage,
        },
        "attendance": attendance_items,
    }

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

# ── Students API ─────────────────────────────────────────────────────────────

class StudentProfileSchema(BaseModel):
    email: str = ""
    phone: str = ""
    department: str = ""
    year: str = ""
    semester: str = ""
    batch: str = ""

@app.get("/students")
def get_all_students(db: Session = Depends(get_db)):
    """
    Returns all registered students with full metadata and attendance count.
    Used by the Admin Dashboard — Student List screen.
    """
    users = db.query(User).order_by(User.id).all()
    result = []
    for user in users:
        total_attendance = (
            db.query(Attendance)
            .filter(Attendance.user_id == user.id)
            .count()
        )
        profile = db.query(StudentProfile).filter(StudentProfile.user_id == user.id).first()
        result.append({
            "id": user.id,
            "name": user.name,
            "email": user.email or (profile.email if profile else ""),
            "batch": profile.batch if profile else "",
            "semester": profile.semester if profile else "",
            "section": profile.section if profile else "",
            "college_id": profile.college_id if profile else "",
            "total_attendance": total_attendance,
            "registered_at": user.updated_at.isoformat() if user.updated_at else None,
        })
    return result


@app.get("/students/{student_id}/profile")
def get_student_profile(student_id: int, db: Session = Depends(get_db)):
    """
    Returns the extended profile (email, phone, dept, year) for a student.
    Flutter profile screen calls this after a user logs in / registers.
    """
    user = db.query(User).filter(User.id == student_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Student not found")
    profile = db.query(StudentProfile).filter(StudentProfile.user_id == student_id).first()
    return {
        "id": user.id,
        "name": user.name,
        "email": profile.email if profile else "",
        "phone": profile.phone if profile else "",
        "department": profile.department if profile else "",
        "year": profile.year if profile else "",
        "semester": profile.semester if profile else "",
        "batch": profile.batch if profile else "",
    }


@app.put("/students/{student_id}/profile")
def update_student_profile(
    student_id: int,
    data: StudentProfileSchema,
    db: Session = Depends(get_db)
):
    """
    Creates or updates the extended profile for a student.
    Flutter 'Edit Profile' sheet calls this on save.
    """
    user = db.query(User).filter(User.id == student_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Student not found")

    profile = db.query(StudentProfile).filter(StudentProfile.user_id == student_id).first()
    if profile is None:
        profile = StudentProfile(user_id=student_id)
        db.add(profile)

    profile.email = data.email
    profile.phone = data.phone
    profile.department = data.department
    profile.year = data.year
    profile.semester = data.semester
    profile.batch = data.batch
    db.commit()
    db.refresh(profile)
    return {"message": "Profile updated", "student_id": student_id}


@app.delete("/students/{student_id}")
def delete_student(student_id: int, db: Session = Depends(get_db)):
    """
    Deletes a registered student and all their attendance records.
    Admin-only action.
    """
    user = db.query(User).filter(User.id == student_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Student not found")
    db.query(Attendance).filter(Attendance.user_id == student_id).delete()
    db.delete(user)
    db.commit()
    return {"message": f"Student '{user.name}' deleted successfully"}


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


# ── Assessments API ─────────────────────────────────────────────────────────

@app.post("/admin/tests")
def schedule_test(data: schemas.ScheduleTestRequest, db: Session = Depends(get_db)):
    """
    Admin schedules a new test by defining a topic.
    """
    test = ScheduledTest(
        topic=data.topic,
        time_limit_minutes=data.time_limit_minutes,
        valid_until=data.valid_until,
        max_attempts=data.max_attempts,
        num_questions=data.num_questions,
        difficulty=data.difficulty
    )
    db.add(test)
    db.commit()
    db.refresh(test)
    return {"message": "Test scheduled successfully", "test": {
        "id": test.id, "topic": test.topic, "created_at": test.created_at.isoformat() if test.created_at else None,
        "time_limit_minutes": test.time_limit_minutes,
        "valid_until": test.valid_until.isoformat() if test.valid_until else None,
        "max_attempts": test.max_attempts,
        "num_questions": test.num_questions,
        "difficulty": test.difficulty
    }}

@app.get("/tests/scheduled")
def get_scheduled_tests(db: Session = Depends(get_db)):
    """
    Student fetches all active scheduled tests for the announcements tab.
    """
    tests = db.query(ScheduledTest).order_by(ScheduledTest.created_at.desc()).all()
    return [{
        "id": t.id, 
        "topic": t.topic, 
        "time_limit_minutes": t.time_limit_minutes,
        "valid_until": t.valid_until.isoformat() if t.valid_until else None,
        "max_attempts": t.max_attempts,
        "num_questions": t.num_questions,
        "difficulty": t.difficulty,
        "created_at": t.created_at.isoformat() if t.created_at else None
    } for t in tests]

@app.post("/tests/{test_id}/submit")
def submit_test_result(test_id: int, data: schemas.SubmitResultRequest, db: Session = Depends(get_db)):
    """
    Student submits the results of their AI generated assessment wrapper.
    """
    test = db.query(ScheduledTest).filter(ScheduledTest.id == test_id).first()
    if not test:
        raise HTTPException(status_code=404, detail="Test not found")
        
    user = db.query(User).filter(User.id == data.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    result = TestResult(
        test_id=test_id,
        user_id=data.user_id,
        score=data.score,
        total_questions=data.total_questions,
        questions_data=data.questions_data,
        user_answers_data=data.user_answers_data
    )
    db.add(result)
    db.commit()
    db.refresh(result)
    return {"message": "Result submitted successfully", "score": result.score}

@app.get("/admin/tests/results")
def get_test_results(db: Session = Depends(get_db)):
    """
    Admin views all test submissions across all users.
    """
    results = (
        db.query(
            TestResult.id,
            TestResult.score,
            TestResult.total_questions,
            TestResult.completed_at,
            TestResult.questions_data,
            TestResult.user_answers_data,
            TestResult.teacher_feedback,
            User.name.label("student_name"),
            ScheduledTest.topic.label("test_topic"),
            StudentProfile.semester,
            StudentProfile.batch
        )
        .join(User, TestResult.user_id == User.id)
        .join(ScheduledTest, TestResult.test_id == ScheduledTest.id)
        .outerjoin(StudentProfile, User.id == StudentProfile.user_id)
        .order_by(TestResult.completed_at.desc())
        .all()
    )
    
    return [
        {
            "id": r.id,
            "score": r.score,
            "total_questions": r.total_questions,
            "completed_at": r.completed_at.isoformat() if r.completed_at else None,
            "questions_data": r.questions_data,
            "user_answers_data": r.user_answers_data,
            "teacher_feedback": r.teacher_feedback,
            "student_name": r.student_name,
            "test_topic": r.test_topic,
            "semester": r.semester,
            "batch": r.batch
        } for r in results
    ]

class FeedbackRequest(BaseModel):
    feedback: str

@app.post("/admin/tests/results/{result_id}/feedback")
def provide_feedback(result_id: int, data: FeedbackRequest, db: Session = Depends(get_db)):
    result = db.query(TestResult).filter(TestResult.id == result_id).first()
    if not result:
        raise HTTPException(status_code=404, detail="Test result not found")
    result.teacher_feedback = data.feedback
    db.commit()
    return {"message": "Feedback submitted successfully"}

@app.get("/student/{user_id}/tests/results")
def get_student_test_results(user_id: int, db: Session = Depends(get_db)):
    results = db.query(TestResult).filter(TestResult.user_id == user_id).all()
    # Also fetch user attempts count per test
    from sqlalchemy import func
    attempts = db.query(TestResult.test_id, func.count(TestResult.id).label("attempts")).filter(TestResult.user_id == user_id).group_by(TestResult.test_id).all()
    attempts_map = {a.test_id: a.attempts for a in attempts}
    
    return [
        {
            "id": r.id,
            "test_id": r.test_id,
            "score": r.score,
            "total_questions": r.total_questions,
            "teacher_feedback": r.teacher_feedback,
            "completed_at": r.completed_at.isoformat() if r.completed_at else None,
            "attempts": attempts_map.get(r.test_id, 0)
        } for r in results
    ]
    
    return [
        {
            "id": r.id,
            "student_name": r.student_name,
            "topic": r.test_topic,
            "score": r.score,
            "total_questions": r.total_questions,
            "completed_at": r.completed_at.isoformat() if r.completed_at else None
        }
        for r in results
    ]

@app.get("/student/{user_id}/tests/results")
def get_personal_test_results(user_id: int, db: Session = Depends(get_db)):
    """
    Fetch all attempts by a specific student.
    Returns array mapping test_id -> count of attempts to verify lock statuses.
    """
    from sqlalchemy import func
    results = (
        db.query(TestResult.test_id, func.count(TestResult.id).label("attempts"))
        .filter(TestResult.user_id == user_id)
        .group_by(TestResult.test_id)
        .all()
    )
    return [{"test_id": r.test_id, "attempts": r.attempts} for r in results]


if __name__ == "__main__":
    import uvicorn
    # Make sure to run it matching your module structure or directory.
    # Uvicorn looks for app/main.py if you run from the root.
    uvicorn.run("app.main:app", host="0.0.0.0", port=10000)
