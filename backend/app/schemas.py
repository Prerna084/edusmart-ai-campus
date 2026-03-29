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
