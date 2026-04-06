"""Personalized study plan from stored performance (rule-based; augments weak-topic ranking)."""
from __future__ import annotations

from typing import Any

from app.models import TopicPerformance


def build_recommendations(student_id: int) -> dict[str, Any]:
    rows = TopicPerformance.query.filter_by(student_id=student_id).all()
    ranked: list[tuple[str, float, int]] = []
    for r in rows:
        tot = r.correct_count + r.wrong_count
        if tot == 0:
            continue
        wrong_rate = r.wrong_count / tot
        ranked.append((r.topic, wrong_rate, tot))
    ranked.sort(key=lambda x: (x[1], -x[2]), reverse=True)

    top_weak = [{"topic": t, "priority": i + 1, "wrong_rate": round(wr * 100, 2)} for i, (t, wr, _) in enumerate(ranked[:8])]

    actions = []
    for item in top_weak[:5]:
        actions.append(
            {
                "topic": item["topic"],
                "revision": f"Re-read syllabus section related to “{item['topic']}”, write 5 bullet summaries.",
                "practice": "Attempt 10 new MCQs on this topic without peeking at notes; log mistakes.",
            }
        )

    if not actions:
        actions.append(
            {
                "topic": "General",
                "revision": "Maintain streak: skim last week’s notes for 15 minutes.",
                "practice": "Take the daily 3-question test and one weekly quiz.",
            }
        )

    study_plan = {
        "blocks": [
            {
                "day": "Mon–Wed",
                "focus": [w["topic"] for w in top_weak[:3]] or ["Core syllabus"],
                "tasks": ["Concept map", "Short notes", "Peer discussion"],
            },
            {
                "day": "Thu–Sun",
                "focus": [w["topic"] for w in top_weak[3:6]] or ["Problem solving"],
                "tasks": ["Timed quiz", "Error log review", "Lab-style exercises"],
            },
        ],
        "prediction_note": "Higher wrong_rate topics are prioritized for next week’s adaptive tests.",
    }

    return {
        "student_id": student_id,
        "ranked_weak_topics": top_weak,
        "improvement_actions": actions,
        "study_plan": study_plan,
    }
