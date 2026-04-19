from pydantic import BaseModel
from datetime import date, time

class UserCreate(BaseModel):
    name: str

class UserOut(BaseModel):
    id: int
    name: str
    
    class Config:
        from_attributes = True

class AttendanceOut(BaseModel):
    id: int
    user_id: int
    date: date
    time: time
    status: str
    
    class Config:
        from_attributes = True

from typing import Optional
from datetime import datetime

class ScheduleTestRequest(BaseModel):
    topic: str
    time_limit_minutes: Optional[int] = 15
    valid_until: Optional[datetime] = None
    max_attempts: Optional[int] = 1
    num_questions: Optional[int] = 5
    difficulty: Optional[str] = "Mixed Mode"
    scheduled_at: Optional[datetime] = None

class SubmitResultRequest(BaseModel):
    user_id: int
    score: int
    total_questions: int
    questions_data: Optional[str] = None
    user_answers_data: Optional[str] = None

class StudentRegisterRequest(BaseModel):
    name: str
    email: str
    password: str
    batch: Optional[str] = None
    semester: Optional[str] = None
    section: Optional[str] = None

class LoginRequest(BaseModel):
    email: str
    password: str

class ForgotPasswordRequest(BaseModel):
    email: str

class UpdateCollegeIdRequest(BaseModel):
    college_id: str

class UpdatePasswordRequest(BaseModel):
    old_password: str
    new_password: str

# ── Teacher & Study Plan Schemas ────────────────────────────────────────────

class TeacherRegisterRequest(BaseModel):
    name: str
    email: str
    password: str
    department: str
    designation: Optional[str] = "Assistant Professor"

class TeacherSubjectOut(BaseModel):
    id: int
    subject_id: int
    subject_title: str
    semester: str
    batch: str
    section: str
    
    class Config:
        from_attributes = True

class WeeklyStudyPlanOut(BaseModel):
    id: int
    week_number: int
    title: str
    content: str # JSON string
    is_approved: bool
    created_at: datetime

    class Config:
        from_attributes = True
