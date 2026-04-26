from app.database import SessionLocal
from app.models import User, StudentProfile, TeacherProfile
from sqlalchemy import text

db = SessionLocal()
try:
    conn = db.connection()
    # Move passwords to StudentProfile
    conn.execute(text("""
        UPDATE student_profiles 
        SET password_hash = (SELECT password_hash FROM users WHERE users.id = student_profiles.user_id) 
        WHERE password_hash IS NULL
    """))
    # Move passwords to TeacherProfile
    conn.execute(text("""
        UPDATE teacher_profiles 
        SET password_hash = (SELECT password_hash FROM users WHERE users.id = teacher_profiles.user_id) 
        WHERE password_hash IS NULL
    """))
    db.commit()
    print("Passwords migrated successfully!")
except Exception as e:
    print(f"Error: {e}")
finally:
    db.close()
