"""Create or fetch daily (3Q) and weekly (10Q) tests tied to syllabus + week plan."""
from __future__ import annotations

import json
from datetime import date
from typing import Any

from app.ai.question_ai import generate_questions
from app.extensions import db
from app.models import Question, Syllabus, TestPaper, User, WeekPlan


def _student_syllabus(student: User) -> Syllabus | None:
    return (
        Syllabus.query.filter_by(semester=student.semester or "", section=student.section or "")
        .order_by(Syllabus.created_at.desc())
        .first()
    )


def _week_context(syllabus: Syllabus | None, week_number: int) -> str:
    if not syllabus:
        return "General weekly objectives: review core modules and practice problems."
    wp = WeekPlan.query.filter_by(syllabus_id=syllabus.id, week_number=week_number).first()
    if wp:
        return wp.topics_summary
    return f"Week {week_number}: follow syllabus unit sequence and lab exercises."


def _serialize_paper(paper: TestPaper) -> dict[str, Any]:
    return {
        "paper_id": paper.id,
        "test_type": paper.test_type,
        "paper_date": paper.paper_date.isoformat(),
        "week_number": paper.week_number,
        "syllabus_id": paper.syllabus_id,
        "questions": [
            {
                "id": q.id,
                "text": q.question_text,
                "options": json.loads(q.options_json),
                "topic_tag": q.topic_tag,
            }
            for q in paper.questions
        ],
    }


def get_or_create_daily_test(student: User, week_number: int = 1) -> dict[str, Any]:
    today = date.today()
    existing = TestPaper.query.filter_by(
        student_id=student.id,
        test_type="daily",
        paper_date=today,
    ).first()
    if existing and len(existing.questions) >= 3:
        return _serialize_paper(existing)

    syllabus = _student_syllabus(student)
    syllabus_text = syllabus.content_text if syllabus else "Computer Science and Engineering core topics."
    week_summary = _week_context(syllabus, week_number)

    if existing:
        db.session.delete(existing)
        db.session.commit()

    qs = generate_questions(syllabus_text, week_summary, 3)
    paper = TestPaper(
        student_id=student.id,
        syllabus_id=syllabus.id if syllabus else None,
        test_type="daily",
        paper_date=today,
        week_number=week_number,
    )
    db.session.add(paper)
    db.session.flush()
    for item in qs:
        db.session.add(
            Question(
                test_paper_id=paper.id,
                question_text=item["text"],
                options_json=json.dumps(item["options"]),
                correct_index=item["correct_index"],
                topic_tag=item.get("topic", "General")[:200],
            )
        )
    db.session.commit()
    paper = db.session.get(TestPaper, paper.id)
    return _serialize_paper(paper)


def get_or_create_weekly_test(student: User, week_number: int) -> dict[str, Any]:
    syllabus = _student_syllabus(student)
    if not syllabus:
        raise ValueError("No syllabus uploaded for your semester/section. Ask your teacher.")

    existing = (
        TestPaper.query.filter_by(
            student_id=student.id,
            test_type="weekly",
            syllabus_id=syllabus.id,
            week_number=week_number,
        )
        .order_by(TestPaper.created_at.desc())
        .first()
    )
    if existing and len(existing.questions) >= 10:
        return _serialize_paper(existing)

    if existing:
        db.session.delete(existing)
        db.session.commit()

    week_summary = _week_context(syllabus, week_number)
    qs = generate_questions(syllabus.content_text, week_summary, 10)
    paper = TestPaper(
        student_id=student.id,
        syllabus_id=syllabus.id,
        test_type="weekly",
        paper_date=date.today(),
        week_number=week_number,
    )
    db.session.add(paper)
    db.session.flush()
    for item in qs:
        db.session.add(
            Question(
                test_paper_id=paper.id,
                question_text=item["text"],
                options_json=json.dumps(item["options"]),
                correct_index=item["correct_index"],
                topic_tag=item.get("topic", "General")[:200],
            )
        )
    db.session.commit()
    paper = db.session.get(TestPaper, paper.id)
    return _serialize_paper(paper)
