"""Hybrid MCQ generation: OpenAI when configured, else syllabus-derived templates."""
from __future__ import annotations

import json
import random
import re
from typing import Any

from flask import current_app


def _split_topics(syllabus_text: str, week_summary: str) -> list[str]:
    blob = f"{syllabus_text}\n{week_summary}"
    parts = re.split(r"[\n.;•]+", blob)
    topics = [p.strip() for p in parts if 8 < len(p.strip()) < 200]
    return topics or ["Course fundamentals", "Core concepts", "Practice problems"]


def _fallback_questions(
    syllabus_text: str,
    week_summary: str,
    count: int,
) -> list[dict[str, Any]]:
    topics = _split_topics(syllabus_text, week_summary)
    random.shuffle(topics)
    out: list[dict[str, Any]] = []
    for i in range(count):
        t = topics[i % len(topics)]
        correct = random.randint(0, 3)
        distractors = [
            "A related but incorrect concept from another module",
            "A partially true statement that misses key constraints",
            "A common misconception students report",
            "None of the above (when inappropriate)",
        ]
        random.shuffle(distractors)
        options = []
        for j in range(4):
            if j == correct:
                options.append(f"Correct understanding of: {t[:80]}")
            else:
                options.append(distractors[j % len(distractors)])
        out.append(
            {
                "text": f"Which statement best reflects the learning objective around “{t[:100]}”?",
                "options": options,
                "correct_index": correct,
                "topic": t[:120],
            }
        )
    return out


def generate_questions(
    syllabus_text: str,
    week_summary: str,
    count: int,
) -> list[dict[str, Any]]:
    api_key = current_app.config.get("OPENAI_API_KEY") or ""
    model = current_app.config.get("OPENAI_MODEL", "gpt-4o-mini")
    excerpt = syllabus_text[:12000]
    week = week_summary[:4000]

    if not api_key:
        return _fallback_questions(excerpt, week, count)

    try:
        from openai import OpenAI

        client = OpenAI(api_key=api_key)
        prompt = (
            f"You are an exam author for B.Tech CSE. Using ONLY the syllabus excerpt and weekly plan, "
            f"create exactly {count} distinct multiple-choice questions (4 options each, one correct). "
            "Tag each question with a short topic label from the content.\n"
            'Return STRICT JSON: {"questions":[{"text":string,"options":[4 strings],'
            '"correct_index":0-3,"topic":string}]}\n\n'
            f"SYLLABUS:\n{excerpt}\n\nWEEK PLAN:\n{week}"
        )
        resp = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            temperature=0.4,
        )
        raw = resp.choices[0].message.content or "{}"
        data = json.loads(raw)
        qs = data.get("questions") or []
        normalized = []
        for q in qs[:count]:
            opts = q.get("options") or []
            if len(opts) != 4:
                continue
            ci = int(q.get("correct_index", 0))
            if ci < 0 or ci > 3:
                ci = 0
            normalized.append(
                {
                    "text": str(q.get("text", "")).strip(),
                    "options": [str(o) for o in opts],
                    "correct_index": ci,
                    "topic": str(q.get("topic", "General"))[:200],
                }
            )
        if len(normalized) >= min(1, count):
            while len(normalized) < count:
                normalized.extend(_fallback_questions(excerpt, week, count - len(normalized)))
            return normalized[:count]
    except Exception:
        current_app.logger.exception("OpenAI question generation failed; using fallback")

    return _fallback_questions(excerpt, week, count)
