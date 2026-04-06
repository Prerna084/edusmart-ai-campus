"""Aggregates for student progress and teacher class analytics."""
from __future__ import annotations

from collections import defaultdict
from typing import Any

from sqlalchemy import func

from app.extensions import db
from app.models import Answer, Question, Submission, Syllabus, TopicPerformance, User


def student_analytics(student_id: int) -> dict[str, Any]:
    subs = (
        Submission.query.filter_by(student_id=student_id)
        .order_by(Submission.submitted_at.desc())
        .limit(50)
        .all()
    )

    timeline = [
        {
            "date": s.submitted_at.isoformat() if s.submitted_at else "",
            "score": s.score,
            "max": s.max_score,
            "percent": round((s.score / s.max_score) * 100, 2) if s.max_score else 0,
        }
        for s in subs
    ]
    avg_pct = sum(t["percent"] for t in timeline) / len(timeline) if timeline else 0.0

    weak_rows = TopicPerformance.query.filter_by(student_id=student_id).all()
    scored = []
    for r in weak_rows:
        tot = r.correct_count + r.wrong_count
        if tot == 0:
            continue
        wrong_rate = (r.wrong_count / tot) * 100
        scored.append({"topic": r.topic, "wrong_rate": round(wrong_rate, 2), "attempts": tot})
    scored.sort(key=lambda x: x["wrong_rate"], reverse=True)
    weak_topics = scored[:15]

    return {
        "student_id": student_id,
        "average_recent_percent": round(avg_pct, 2),
        "submissions_count": len(timeline),
        "timeline": timeline[:20],
        "weak_topics": weak_topics,
    }


def teacher_class_analytics(teacher_id: int, semester: str, section: str) -> dict[str, Any]:
    syllabus = (
        Syllabus.query.filter_by(teacher_id=teacher_id, semester=semester, section=section)
        .order_by(Syllabus.created_at.desc())
        .first()
    )
    students = User.query.filter_by(role="student", semester=semester, section=section).all()
    student_ids = [s.id for s in students]

    if not student_ids:
        return {
            "semester": semester,
            "section": section,
            "student_count": 0,
            "combined_scores": [],
            "class_weak_topics": [],
            "syllabus_title": syllabus.title if syllabus else None,
        }

    subs = (
        Submission.query.filter(Submission.student_id.in_(student_ids))
        .order_by(Submission.submitted_at.desc())
        .limit(500)
        .all()
    )

    by_student: dict[int, list[float]] = defaultdict(list)
    for sub in subs:
        if sub.max_score:
            by_student[sub.student_id].append((sub.score / sub.max_score) * 100)

    combined = []
    for sid in student_ids:
        pts = by_student.get(sid, [])
        avg = sum(pts) / len(pts) if pts else 0.0
        st = next((x for x in students if x.id == sid), None)
        combined.append(
            {
                "student_id": sid,
                "name": st.name if st else "",
                "email": st.email if st else "",
                "average_percent": round(avg, 2),
                "attempts": len(pts),
            }
        )

    wrong_q = (
        db.session.query(Question.topic_tag, func.count(Answer.id))
        .join(Answer, Answer.question_id == Question.id)
        .filter(Answer.is_correct.is_(False))
        .join(Submission, Submission.id == Answer.submission_id)
        .filter(Submission.student_id.in_(student_ids))
        .group_by(Question.topic_tag)
        .order_by(func.count(Answer.id).desc())
        .limit(12)
        .all()
    )
    class_weak = [{"topic": t or "General", "wrong_count": int(c)} for t, c in wrong_q]

    return {
        "semester": semester,
        "section": section,
        "student_count": len(students),
        "combined_scores": sorted(combined, key=lambda x: x["average_percent"]),
        "class_weak_topics": class_weak,
        "syllabus_title": syllabus.title if syllabus else None,
    }
