import os
from sqlalchemy import text
from app.database import engine

def upgrade():
    with engine.connect() as conn:
        try:
            conn.execute(text("ALTER TABLE scheduled_tests ADD COLUMN time_limit_minutes INTEGER DEFAULT 15"))
        except Exception as e:
            print("Skipped time_limit_minutes", e)
        try:
            conn.execute(text("ALTER TABLE scheduled_tests ADD COLUMN valid_until TIMESTAMP"))
        except Exception as e:
            print("Skipped valid_until", e)
        try:
            conn.execute(text("ALTER TABLE scheduled_tests ADD COLUMN max_attempts INTEGER DEFAULT 1"))
        except Exception as e:
            print("Skipped max_attempts", e)
        conn.commit()
    print("Database upgraded.")

if __name__ == "__main__":
    upgrade()
