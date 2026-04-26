from contextlib import asynccontextmanager
from typing import Optional
from fastapi import FastAPI, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app.models import Attendance, User, StudentProfile, Subject, SyllabusModule, Topic, ScheduledTest, TestResult, TeacherProfile, TeacherSubject, WeeklyStudyPlan, AdminProfile
from app import schemas
from app.face_engine import encode_face, find_best_match
import json
from datetime import date, datetime
import numpy as np
from pydantic import BaseModel
import asyncio
from fastapi.middleware.cors import CORSMiddleware
from app.ai_service import AIService, build_mcq_prompt, build_study_plan_prompt, build_tutor_system, extract_json_array

# Create the database tables
Base.metadata.create_all(bind=engine)

# Auto-upgrade SQLite / Postgres tables for all models
from sqlalchemy import text
print("🛠️ Starting database auto-migration...")
with engine.connect() as conn:
    is_postgres = "postgresql" in str(engine.url)
    print(f"📡 Detected database type: {'PostgreSQL' if is_postgres else 'SQLite/Other'}")
    
    def safe_add_column(table, col_name, col_type):
        """Cross-database column addition helper."""
        try:
            if is_postgres:
                # Postgres 9.6+ supports IF NOT EXISTS
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {col_name} {col_type}"))
            else:
                # SQLite: fails if already exists, which we catch
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {col_name} {col_type}"))
            conn.commit()
            print(f"✅ Added {table}.{col_name} ({col_type})")
        except Exception as e:
            # If postgres transaction is aborted, we must rollback to continue
            try:
                conn.rollback()
            except:
                pass
            print(f"ℹ️ Skipped {table}.{col_name}: {str(e)[:50]}...")
            pass

    for col, ctype in [
        ("email", "VARCHAR UNIQUE"),
        ("college_reg", "VARCHAR UNIQUE"),
        ("name", "VARCHAR"),
        ("role", "VARCHAR DEFAULT 'student'"),
        ("face_encoding", "TEXT"),
        ("updated_at", "TIMESTAMP DEFAULT CURRENT_TIMESTAMP")
    ]:
        safe_add_column("users", col, ctype)

    # ── Cleanup Legacy Constraints ───────────────────────────────────────────
    try:
        if is_postgres:
            conn.execute(text("ALTER TABLE users ALTER COLUMN student_reg DROP NOT NULL"))
            conn.commit()
            print("✅ Dropped NOT NULL constraint from legacy users.student_reg")
    except Exception:
        try:
            conn.rollback()
        except:
            pass

            
    # --- Student Profile table ---
    for col, ctype in [
        ("email", "VARCHAR"),
        ("phone", "VARCHAR"),
        ("department", "VARCHAR"),
        ("year", "VARCHAR"),
        ("semester", "VARCHAR"),
        ("batch", "VARCHAR"),
        ("section", "VARCHAR"),
        ("college_id", "VARCHAR UNIQUE"),
        ("batch_roll", "VARCHAR"),
        ("password_hash", "VARCHAR")
    ]:
        safe_add_column("student_profiles", col, ctype)

    # --- Teacher Profile table ---
    for col, ctype in [
        ("department", "VARCHAR"),
        ("designation", "VARCHAR"),
        ("teacher_reg_no", "VARCHAR UNIQUE"),
        ("password_hash", "VARCHAR")
    ]:
        safe_add_column("teacher_profiles", col, ctype)

    # --- Admin Profile table ---
    for col, ctype in [
        ("password_hash", "VARCHAR")
    ]:
        safe_add_column("admin_profiles", col, ctype)

    # --- Scheduled Test table ---
    for col, ctype in [
        ("time_limit_minutes", "INTEGER DEFAULT 15"),
        ("valid_until", "TIMESTAMP"),
        ("max_attempts", "INTEGER DEFAULT 1"),
        ("num_questions", "INTEGER DEFAULT 5"),
        ("difficulty", "VARCHAR DEFAULT 'Mixed Mode'"),
        ("scheduled_at", "TIMESTAMP")
    ]:
        safe_add_column("scheduled_tests", col, ctype)

    # --- Test Results table ---
    for col, ctype in [
        ("questions_data", "TEXT"),
        ("user_answers_data", "TEXT"),
        ("teacher_feedback", "TEXT")
    ]:
        safe_add_column("test_results", col, ctype)

    # ── AI Logs table (auto-create columns) ──────────────────────────────────
    for col, ctype in [
        ("feature",    "VARCHAR"),
        ("prompt",     "TEXT"),
        ("response",   "TEXT"),
        ("model_used", "VARCHAR"),
        ("is_online",  "INTEGER"),
        ("latency_ms", "INTEGER"),
    ]:
        safe_add_column("ai_logs", col, ctype)
print("✅ Database auto-migration complete.")
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
    # Ensure role exists and migration runs
    _auto_seed_syllabus()
    
    # Ensure a default admin exists
    db = SessionLocal()
    try:
        admin = db.query(User).filter(User.role == 'admin').first()
        if not admin:
            # Check if default admin email exists but without admin role
            default_email = "admin@edusmart.edu"
            admin = db.query(User).filter(User.email == default_email).first()
            if admin:
                admin.role = 'admin'
                db.commit()
                # Ensure AdminProfile exists
                admin_profile = db.query(AdminProfile).filter(AdminProfile.user_id == admin.id).first()
                if not admin_profile:
                    admin_profile = AdminProfile(user_id=admin.id, password_hash="admin123")
                    db.add(admin_profile)
                    db.commit()
                print(f"👑 Promoted {default_email} to Admin.")
            else:
                # Create default admin from scratch
                new_admin = User(
                    name="System Admin",
                    email=default_email,
                    role="admin"
                )
                db.add(new_admin)
                db.commit()
                db.refresh(new_admin)
                
                new_admin_profile = AdminProfile(
                    user_id=new_admin.id,
                    password_hash="admin123"
                )
                db.add(new_admin_profile)
                db.commit()
                print(f"👑 Created default Admin: {default_email}")
    finally:
        db.close()
        
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
            role="student",
            college_reg=data.college_id
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        # Create profile
        profile = StudentProfile(
            user_id=new_user.id,
            email=data.email,
            password_hash=data.password,
            college_id=data.college_id,
            batch=data.batch,
            semester=data.semester,
            section=data.section
        )
        db.add(profile)
        db.commit()
        
        return {"message": "Student registered successfully", "user_id": new_user.id}
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        # Handle specific integrity errors if possible, or generic 500 with more info
        if "UNIQUE constraint failed" in str(e) or "duplicate key" in str(e):
             raise HTTPException(status_code=400, detail="Email or College ID already exists")
        print(f"Error during registration: {e}")
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")

@app.post("/auth/login")
def login_student(data: schemas.LoginRequest, db: Session = Depends(get_db)):
    try:
        # 1. Check Student Profile
        student_profile = db.query(StudentProfile).filter(StudentProfile.email == data.email).first()
        if student_profile:
            # Auto-migrate password for existing accounts
            if not student_profile.password_hash:
                from sqlalchemy import text
                result = db.execute(text("SELECT password_hash FROM users WHERE id = :uid"), {"uid": student_profile.user_id}).fetchone()
                if result and result[0]:
                    student_profile.password_hash = result[0]
                    db.commit()
                    db.refresh(student_profile)

            if student_profile.password_hash != data.password:
                raise HTTPException(status_code=401, detail="Invalid email or password")
            user = db.query(User).filter(User.id == student_profile.user_id).first()
            return {
                "user_id": user.id,
                "name": user.name,
                "role": user.role,
                "profile": {
                    "email": (student_profile.email if student_profile and student_profile.email else user.email) or "",
                    "phone": student_profile.phone if student_profile else "",
                    "department": student_profile.department if student_profile else "",
                    "year": student_profile.year if student_profile else "",
                    "semester": student_profile.semester if student_profile else "",
                    "batch": student_profile.batch if student_profile else "",
                    "section": student_profile.section if student_profile else "",
                    "college_id": student_profile.college_id if student_profile else "",
                }
            }
            
        # 2. Check Teacher Profile
        user = db.query(User).filter(User.email == data.email).first()
        if user:
            if user.role == "teacher":
                teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == user.id).first()
                if teacher_profile:
                    # Auto-migrate password for existing accounts
                    if not teacher_profile.password_hash:
                        from sqlalchemy import text
                        result = db.execute(text("SELECT password_hash FROM users WHERE id = :uid"), {"uid": teacher_profile.user_id}).fetchone()
                        if result and result[0]:
                            teacher_profile.password_hash = result[0]
                            db.commit()
                            db.refresh(teacher_profile)

                    if teacher_profile.password_hash == data.password:
                        return {
                            "user_id": user.id,
                            "name": user.name,
                            "role": user.role,
                            "profile": {
                                "email": (teacher_profile.email if teacher_profile and getattr(teacher_profile, 'email', None) else user.email) or "",
                                "department": teacher_profile.department,
                                "designation": teacher_profile.designation,
                                "teacher_reg_no": teacher_profile.teacher_reg_no
                            }
                        }
            elif user.role == "admin":
                admin_profile = db.query(AdminProfile).filter(AdminProfile.user_id == user.id).first()
                if admin_profile and admin_profile.password_hash == data.password:
                    return {
                        "user_id": user.id,
                        "name": user.name,
                        "role": user.role,
                        "profile": {
                            "email": user.email
                        }
                    }

        raise HTTPException(status_code=401, detail="Invalid email or password")
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/auth/register-teacher")
def register_teacher(data: schemas.TeacherRegisterRequest, db: Session = Depends(get_db)):
    try:
        existing = db.query(User).filter(User.email == data.email).first()
        if existing:
            raise HTTPException(status_code=400, detail="Email already registered")
        
        new_user = User(
            name=data.name,
            email=data.email,
            role="teacher",
            college_reg=data.teacher_reg_no
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        profile = TeacherProfile(
            user_id=new_user.id,
            password_hash=data.password,
            department=data.department,
            designation=data.designation,
            teacher_reg_no=data.teacher_reg_no
        )
        db.add(profile)
        db.commit()
        
        return {"message": "Teacher registered successfully", "user_id": new_user.id}
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        if "UNIQUE constraint failed" in str(e) or "duplicate key" in str(e):
             raise HTTPException(status_code=400, detail="Email or Teacher Reg No already exists")
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")

@app.post("/auth/forgot-password")
def forgot_password(data: schemas.ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Email not found")
    
    import random
    import string
    new_pwd = ''.join(random.choices(string.ascii_letters + string.digits, k=8))
    
    if user.role == "student":
        profile = db.query(StudentProfile).filter(StudentProfile.user_id == user.id).first()
        if profile: profile.password_hash = new_pwd
    elif user.role == "teacher":
        profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == user.id).first()
        if profile: profile.password_hash = new_pwd
    elif user.role == "admin":
        profile = db.query(AdminProfile).filter(AdminProfile.user_id == user.id).first()
        if profile: profile.password_hash = new_pwd

    db.commit()
    
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
    
    # Also link to users table for face recognition
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.college_reg = data.college_id
        
    db.commit()
    return {"message": "Student ID set successfully"}

@app.post("/admin/students/{user_id}/reset-college-id")
def reset_college_id(user_id: int, db: Session = Depends(get_db)):
    profile = db.query(StudentProfile).filter(StudentProfile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Student profile not found")
    
    profile.college_id = None
    
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.college_reg = None
        
    db.commit()
    return {"message": "Student ID cleared successfully"}

@app.post("/students/{user_id}/change-password")
def change_password(user_id: int, data: schemas.UpdatePasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    is_valid = False
    
    if user.role == "student":
        profile = db.query(StudentProfile).filter(StudentProfile.user_id == user_id).first()
        if profile and profile.password_hash == data.old_password:
            profile.password_hash = data.new_password
            is_valid = True
    elif user.role == "teacher":
        profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == user_id).first()
        if profile and profile.password_hash == data.old_password:
            profile.password_hash = data.new_password
            is_valid = True
    elif user.role == "admin":
        profile = db.query(AdminProfile).filter(AdminProfile.user_id == user_id).first()
        if profile and profile.password_hash == data.old_password:
            profile.password_hash = data.new_password
            is_valid = True

    if not is_valid:
        raise HTTPException(status_code=401, detail="Incorrect old password")
    
    db.commit()
    return {"message": "Password changed successfully"}


@app.post("/register/")
async def register_user(
    name: str = Form(...),
    user_id: Optional[int] = Form(None),
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

    # ── 0. Linked ID check (High Priority) ──────────────────────────────────
    if user_id is not None:
        user_to_update = db.query(User).filter(User.id == user_id).first()
        if not user_to_update:
            raise HTTPException(status_code=404, detail=f"User with ID {user_id} not found")
        
        user_to_update.face_encoding = json.dumps(encoding.tolist())
        db.commit()
        db.refresh(user_to_update)
        return {
            "message": "Face linked to system profile successfully.",
            "already_existed": True,
            "user_id": user_to_update.id,
            "name": user_to_update.name,
        }

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

    users_raw = db.query(User).filter(User.face_encoding != None).all()
    if not users_raw:
        raise HTTPException(status_code=404, detail="No registered users with face data found.")

    known_encodings = []
    users = []
    for u in users_raw:
        try:
            encoding = np.array(json.loads(u.face_encoding))
            known_encodings.append(encoding)
            users.append(u)
        except Exception:
            print(f"⚠️ Skipping corrupted face data for user ID {u.id}")
            continue

    if not known_encodings:
        raise HTTPException(status_code=404, detail="No valid face data found in database.")

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

    users_raw = db.query(User).filter(User.face_encoding != None).all()
    if not users_raw:
        raise HTTPException(status_code=404, detail="No registered users with face data found.")

    known_encodings = []
    users = []
    for u in users_raw:
        try:
            encoding = np.array(json.loads(u.face_encoding))
            known_encodings.append(encoding)
            users.append(u)
        except Exception:
            print(f"⚠️ Skipping corrupted face data for user ID {u.id}")
            continue

    if not known_encodings:
        raise HTTPException(status_code=404, detail="No valid face data found in database.")

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

# ── AI Tutor Chatbot ──────────────────────────────────────────────────────────

class ChatMessage(BaseModel):
    message: str

@app.post("/tutor/ask", response_model=schemas.AITutorResponse)
async def ask_tutor(chat: ChatMessage, db: Session = Depends(get_db)):
    """
    AI Tutor endpoint — Hybrid multi-level fallback:
      1. Gemini 1.5 Flash (online)
      2. Qwen2.5-7B → Mistral 7B → Phi-3.5 → Llama 3.1 (local via Ollama)
    Switching is fully automatic and invisible to the user.
    """
    result = await AIService.generate(
        db=db,
        feature="ask_tutor",
        prompt=chat.message,
        system=build_tutor_system(),
        max_tokens=800,
    )
    if "error" in result:
        raise HTTPException(status_code=503, detail=result["error"])
    return result

# ── Students API ─────────────────────────────────────────────────────────────

class StudentProfileSchema(BaseModel):
    email: str = ""
    phone: str = ""
    department: str = ""
    year: str = ""
    semester: str = ""
    batch: str = ""
    section: str = ""

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
        "email": (profile.email if profile and profile.email else user.email) or "",
        "phone": profile.phone if profile else "",
        "department": profile.department if profile else "",
        "year": profile.year if profile else "",
        "semester": profile.semester if profile else "",
        "batch": profile.batch if profile else "",
        "section": profile.section if profile else "",
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
    profile.section = data.section
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
        difficulty=data.difficulty,
        scheduled_at=data.scheduled_at
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
        "difficulty": test.difficulty,
        "scheduled_at": test.scheduled_at.isoformat() if test.scheduled_at else None
    }}

@app.get("/tests/scheduled")
def get_scheduled_tests(db: Session = Depends(get_db)):
    """
    Student fetches all active scheduled tests for the announcements tab.
    Sorted by scheduled_at desc (latest scheduled test first).
    """
    tests = db.query(ScheduledTest).order_by(
        ScheduledTest.scheduled_at.desc().nullslast(),
        ScheduledTest.id.desc()
    ).all()
    return [{
        "id": t.id, 
        "topic": t.topic, 
        "time_limit_minutes": t.time_limit_minutes,
        "valid_until": t.valid_until.isoformat() if t.valid_until else None,
        "max_attempts": t.max_attempts,
        "num_questions": t.num_questions,
        "difficulty": t.difficulty,
        "created_at": t.created_at.isoformat() if t.created_at else None,
        "scheduled_at": t.scheduled_at.isoformat() if t.scheduled_at else None
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
@app.get("/teachers/{teacher_id}/subjects", response_model=list[schemas.TeacherSubjectOut])
def get_teacher_subjects(teacher_id: int, db: Session = Depends(get_db)):
    assignments = db.query(TeacherSubject, Subject.title).join(Subject, TeacherSubject.subject_id == Subject.id).filter(TeacherSubject.teacher_id == teacher_id).all()
    
    return [
        schemas.TeacherSubjectOut(
            id=a.TeacherSubject.id,
            subject_id=a.TeacherSubject.subject_id,
            subject_title=a.title,
            semester=a.TeacherSubject.semester,
            batch=a.TeacherSubject.batch,
            section=a.TeacherSubject.section
        ) for a in assignments
    ]

@app.post("/teachers/subjects/{assignment_id}/generate-plan")
async def generate_study_plan(assignment_id: int, db: Session = Depends(get_db)):
    """
    Generates a 3-week AI study plan for the given teacher-subject assignment.
    Uses the hybrid AI fallback pipeline automatically.
    """
    assignment = db.query(TeacherSubject).filter(TeacherSubject.id == assignment_id).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    existing = db.query(WeeklyStudyPlan).filter(WeeklyStudyPlan.teacher_subject_id == assignment_id).first()
    if existing:
        return {"message": "Plan already generated."}

    subject = db.query(Subject).filter(Subject.id == assignment.subject_id).first()
    prompt = build_study_plan_prompt(
        subject.title if subject else "Unknown Subject",
        assignment.semester,
        assignment.batch,
    )

    result = await AIService.generate(
        db=db,
        feature="study_plan",
        prompt=prompt,
        system="You are a curriculum designer. Output ONLY valid raw JSON with no markdown.",
        max_tokens=1200,
        temperature=0.5,
    )

    if "error" in result:
        raise HTTPException(status_code=503, detail=result["error"])

    try:
        plans_data = extract_json_array(result["response"])
    except Exception as e:
        print(f"Study plan JSON parse error: {e}\nRaw: {result['response'][:300]}")
        raise HTTPException(status_code=500, detail="AI returned malformed study plan data.")

    plans = []
    for t in plans_data:
        plan = WeeklyStudyPlan(
            teacher_subject_id=assignment.id,
            week_number=t.get("week", len(plans) + 1),
            title=t.get("title", f"Week {len(plans) + 1}"),
            content=json.dumps({
                "topics":             t.get("topics", []),
                "objective":          t.get("objective", ""),
                "suggested_sequence": ["Lecture", "Practice", "Revision"],
                "ai_model":           result["model"],
            }),
        )
        db.add(plan)
        plans.append(plan)

    db.commit()
    return {
        "message": "AI Study Plan generated successfully",
        "weeks":   len(plans),
        "model":   result["model"],
        "is_online": result["is_online"],
    }


@app.post("/admin/tests/generate-mcqs", response_model=schemas.MCQGenerationResponse)
async def generate_mcqs(data: schemas.MCQGenerationRequest, db: Session = Depends(get_db)):
    """
    Generates MCQs for any topic using the hybrid AI fallback pipeline.
    Returns structured JSON questions ready for use in the assessment engine.
    """
    prompt = build_mcq_prompt(data.topic, data.num_questions, data.difficulty)

    result = await AIService.generate(
        db=db,
        feature="mcq_gen",
        prompt=prompt,
        system="You are an expert examiner. Output ONLY a valid JSON array with no markdown or explanation.",
        max_tokens=1000,
        temperature=0.6,
    )

    if "error" in result:
        raise HTTPException(status_code=503, detail=result["error"])

    try:
        questions = extract_json_array(result["response"])
    except Exception as e:
        print(f"MCQ JSON parse error: {e}\nRaw: {result['response'][:300]}")
        raise HTTPException(status_code=500, detail="AI returned malformed MCQ data.")

    return {
        "questions":  questions,
        "model":      result["model"],
        "is_online":  result["is_online"],
        "latency_ms": result["latency_ms"],
    }


@app.get("/admin/ai-logs")
def get_ai_logs(limit: int = 50, db: Session = Depends(get_db)):
    """
    Admin endpoint: returns the most recent AI inference logs.
    Shows which model served each request and whether it was online or local.
    """
    from app.models import AILog
    logs = db.query(AILog).order_by(AILog.created_at.desc()).limit(limit).all()
    return [
        {
            "id":         l.id,
            "feature":    l.feature,
            "model_used": l.model_used,
            "is_online":  bool(l.is_online),
            "latency_ms": l.latency_ms,
            "created_at": l.created_at.isoformat() if l.created_at else None,
        }
        for l in logs
    ]


@app.get("/teachers/subjects/{assignment_id}/plans", response_model=list[schemas.WeeklyStudyPlanOut])
def get_study_plans(assignment_id: int, db: Session = Depends(get_db)):
    return db.query(WeeklyStudyPlan).filter(WeeklyStudyPlan.teacher_subject_id == assignment_id).order_by(WeeklyStudyPlan.week_number).all()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=10000)
