from sqlalchemy import Column, Integer, String, Date, Time, ForeignKey, DateTime, Text, Float, UniqueConstraint
from sqlalchemy.sql import func
from app.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=True)
    email = Column(String, unique=True, index=True, nullable=True)
    password_hash = Column(String, nullable=True)
    face_encoding = Column(String, nullable=True)  # Stored as JSON string
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

class Attendance(Base):
    __tablename__ = "attendance"
    __table_args__ = (
        UniqueConstraint("user_id", "date", name="uq_attendance_user_date"),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    date = Column(Date)
    time = Column(Time)
    status = Column(String)


class StudentProfile(Base):
    """Extended profile info for a registered student."""
    __tablename__ = "student_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    email = Column(String, nullable=True)
    phone = Column(String, nullable=True)
    department = Column(String, nullable=True)
    year = Column(String, nullable=True)
    semester = Column(String, nullable=True)
    batch = Column(String, nullable=True)
    section = Column(String, nullable=True)
    college_id = Column(String, unique=True, nullable=True)


# ── Syllabus System ─────────────────────────────────────────────────────────

class Subject(Base):
    """Top-level course (e.g. 'Data Structures & Algorithms')"""
    __tablename__ = "subjects"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    tag = Column(String, nullable=False)          # e.g. CS301
    progress = Column(Float, default=0.0)         # 0.0 → 1.0
    next_module = Column(String, nullable=True)

class SyllabusModule(Base):
    """A chapter/unit inside a Subject (e.g. 'Module 1: Arrays')"""
    __tablename__ = "syllabus_modules"

    id = Column(Integer, primary_key=True, index=True)
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    title = Column(String, nullable=False)
    order_index = Column(Integer, default=0)      # display order
    is_completed = Column(Integer, default=0)     # 0=false, 1=true

class Topic(Base):
    """Rich content for a single topic inside a Module"""
    __tablename__ = "topics"

    id = Column(Integer, primary_key=True, index=True)
    module_id = Column(Integer, ForeignKey("syllabus_modules.id"), nullable=False)
    title = Column(String, nullable=False)
    theory = Column(Text, nullable=True)          # plain text notes
    video_url = Column(String, nullable=True)     # YouTube link
    doc_url = Column(String, nullable=True)       # official docs link
    code_example = Column(Text, nullable=True)    # code snippet
    practice_task = Column(Text, nullable=True)   # what to build


# ── Scheduled Assessments ───────────────────────────────────────────────────

class ScheduledTest(Base):
    __tablename__ = "scheduled_tests"
    
    id = Column(Integer, primary_key=True, index=True)
    topic = Column(String, nullable=False)
    time_limit_minutes = Column(Integer, default=15)
    valid_until = Column(DateTime, nullable=True)
    max_attempts = Column(Integer, default=1)
    num_questions = Column(Integer, default=5)
    difficulty = Column(String, default="Mixed Mode")
    scheduled_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, server_default=func.now())

class TestResult(Base):
    __tablename__ = "test_results"
    
    id = Column(Integer, primary_key=True, index=True)
    test_id = Column(Integer, ForeignKey("scheduled_tests.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    score = Column(Integer, nullable=False)
    total_questions = Column(Integer, nullable=False)
    questions_data = Column(Text, nullable=True)
    user_answers_data = Column(Text, nullable=True)
    teacher_feedback = Column(Text, nullable=True)
    completed_at = Column(DateTime, server_default=func.now())
