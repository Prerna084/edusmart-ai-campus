from datetime import date, datetime, time

from app.extensions import db


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(160), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(256), nullable=False)
    name = db.Column(db.String(160), nullable=False)
    role = db.Column(db.String(20), nullable=False, default="student")  # student | teacher
    semester = db.Column(db.String(32), default="")
    section = db.Column(db.String(32), default="")
    face_encoding = db.Column(db.Text)  # JSON list of floats
    api_token = db.Column(db.String(128), unique=True, index=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    syllabi = db.relationship("Syllabus", backref="teacher", lazy="dynamic")
    test_papers = db.relationship("TestPaper", backref="student", lazy="dynamic", foreign_keys="TestPaper.student_id")


class Syllabus(db.Model):
    __tablename__ = "syllabi"

    id = db.Column(db.Integer, primary_key=True)
    teacher_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    semester = db.Column(db.String(32), nullable=False)
    section = db.Column(db.String(32), nullable=False)
    title = db.Column(db.String(256), nullable=False)
    content_text = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    week_plans = db.relationship("WeekPlan", backref="syllabus", lazy="dynamic", cascade="all, delete-orphan")


class WeekPlan(db.Model):
    __tablename__ = "week_plans"

    id = db.Column(db.Integer, primary_key=True)
    syllabus_id = db.Column(db.Integer, db.ForeignKey("syllabi.id"), nullable=False)
    week_number = db.Column(db.Integer, nullable=False)
    topics_summary = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    __table_args__ = (db.UniqueConstraint("syllabus_id", "week_number", name="uq_syllabus_week"),)


class TestPaper(db.Model):
    __tablename__ = "test_papers"

    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    syllabus_id = db.Column(db.Integer, db.ForeignKey("syllabi.id"))
    test_type = db.Column(db.String(20), nullable=False)  # daily | weekly
    paper_date = db.Column(db.Date, nullable=False)
    week_number = db.Column(db.Integer)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    questions = db.relationship("Question", backref="test_paper", lazy="joined", cascade="all, delete-orphan")
    submissions = db.relationship("Submission", backref="test_paper", lazy="dynamic")


class Question(db.Model):
    __tablename__ = "questions"

    id = db.Column(db.Integer, primary_key=True)
    test_paper_id = db.Column(db.Integer, db.ForeignKey("test_papers.id"), nullable=False)
    question_text = db.Column(db.Text, nullable=False)
    options_json = db.Column(db.Text, nullable=False)  # JSON array of 4 strings
    correct_index = db.Column(db.Integer, nullable=False)
    topic_tag = db.Column(db.String(200), default="General")


class Submission(db.Model):
    __tablename__ = "submissions"

    id = db.Column(db.Integer, primary_key=True)
    test_paper_id = db.Column(db.Integer, db.ForeignKey("test_papers.id"), nullable=False)
    student_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    score = db.Column(db.Float, nullable=False)
    max_score = db.Column(db.Float, nullable=False)
    weak_topics_json = db.Column(db.Text)  # JSON list
    submitted_at = db.Column(db.DateTime, default=datetime.utcnow)

    answers = db.relationship("Answer", backref="submission", lazy="joined", cascade="all, delete-orphan")


class Answer(db.Model):
    __tablename__ = "answers"

    id = db.Column(db.Integer, primary_key=True)
    submission_id = db.Column(db.Integer, db.ForeignKey("submissions.id"), nullable=False)
    question_id = db.Column(db.Integer, db.ForeignKey("questions.id"), nullable=False)
    selected_index = db.Column(db.Integer, nullable=False)
    is_correct = db.Column(db.Boolean, nullable=False)


class TopicPerformance(db.Model):
    __tablename__ = "topic_performance"

    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    topic = db.Column(db.String(200), nullable=False)
    correct_count = db.Column(db.Integer, default=0)
    wrong_count = db.Column(db.Integer, default=0)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (db.UniqueConstraint("student_id", "topic", name="uq_student_topic"),)


class AttendanceRecord(db.Model):
    __tablename__ = "attendance_records"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    marked_date = db.Column(db.Date, nullable=False)
    marked_time = db.Column(db.Time, nullable=False)
    status = db.Column(db.String(32), default="present")
