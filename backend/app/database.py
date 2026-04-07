import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base

# Read from environment variable, fall back to local default
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:password@localhost/attendance_db"
)

engine = create_engine(
    DATABASE_URL, 
    connect_args={"sslmode": "require"} if "onrender.com" in DATABASE_URL or "neon.tech" in DATABASE_URL else {}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()
