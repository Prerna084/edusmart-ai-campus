"""Score submissions, persist answers, update topic performance and weak areas."""
from __future__ import annotations

import json
from typing import Any

from app.extensions import db
from app.models import Answer, Question, Submission, TestPaper, TopicPerformance, User


def _bump_topic(student_id: int, topic: str, correct: bool) -> None:
    topic = (topic or "General")[:200]
    row = TopicPerformance.query.filter_by(student_id=student_id, topic=topic).first()
    if not row:
        row = TopicPerformance(student_id=student_id, topic=topic, correct_count=0, wrong_count=0)
        db.session.add(row)
    if correct:
        row.correct_count += 1
    else:
        row.wrong_count += 1


def evaluate_submission(
    paper: TestPaper,
    student: User,
    answers_payload: list[dict[str, Any]],
) -> dict[str, Any]:
    """answers_payload: [{question_id, selected_index}, ...]"""
    q_map = {q.id: q for q in paper.questions}
    if not q_map:
        raise ValueError("Test has no questions")

    correct_n = 0
    weak: list[str] = []
    submission = Submission(
        test_paper_id=paper.id,
        student_id=student.id,
        score=0,
        max_score=float(len(q_map)),
        weak_topics_json="[]",
    )
    db.session.add(submission)
    db.session.flush()

    for item in answers_payload:
        qid = int(item.get("question_id", 0))
        sel = int(item.get("selected_index", -1))
        q = q_map.get(qid)
        if not q:
            continue
        ok = 0 <= sel <= 3 and sel == q.correct_index
        if ok:
            correct_n += 1
        else:
            weak.append(q.topic_tag or "General")
        db.session.add(
            Answer(
                submission_id=submission.id,
                question_id=q.id,
                selected_index=sel,
                is_correct=ok,
            )
        )
        _bump_topic(student.id, q.topic_tag, ok)

    submission.score = float(correct_n)
    submission.max_score = float(len(q_map))
    submission.weak_topics_json = json.dumps(list(dict.fromkeys(weak)))
    db.session.commit()

    accuracy = (correct_n / len(q_map)) * 100 if q_map else 0.0
    return {
        "submission_id": submission.id,
        "score": submission.score,
        "max_score": submission.max_score,
        "accuracy_percent": round(accuracy, 2),
        "weak_topics": list(dict.fromkeys(weak)),
    }
