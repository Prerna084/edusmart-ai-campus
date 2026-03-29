from sqlalchemy import Column, Integer, String, Date, Time, ForeignKey, DateTime
from sqlalchemy.sql import func
from app.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    face_encoding = Column(String)  # Stored as JSON string
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

class Attendance(Base):
    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    date = Column(Date)
    time = Column(Time)
    status = Column(String)
