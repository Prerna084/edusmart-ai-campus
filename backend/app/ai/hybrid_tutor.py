"""Hybrid tutor: OpenAI online + offline rule-based fallback using weak topics."""
from __future__ import annotations

from typing import Any

from flask import current_app


def _offline_reply(message: str, weak_topics: list[str]) -> str:
    m = message.lower().strip()
    focus = ", ".join(weak_topics[:5]) if weak_topics else "your recent quiz topics"

    if any(k in m for k in ("hello", "hi ", "hey")):
        return (
            f"Hi! I'm your offline study assistant. Based on your profile, prioritize: {focus}. "
            "Ask me to explain a definition, compare two concepts, or suggest a revision drill."
        )
    if "explain" in m or "what is" in m or "define" in m:
        return (
            "Offline mode: I can't call the cloud model right now. Try this: "
            "1) State the term in one sentence. 2) Give one example. 3) Contrast it with the closest related idea. "
            f"Relate your answer to: {focus}."
        )
    if "weak" in m or "improve" in m or "help" in m:
        return (
            f"Focus blocks: {focus}. Spend 20 minutes on spaced repetition, then attempt 5 fresh MCQs "
            "without notes. Re-check mistakes against the syllabus headings."
        )
    return (
        "I'm running in offline fallback mode. For deeper explanations, connect OpenAI or review the "
        f"syllabus sections tied to: {focus}. Your question was noted for when online tutoring resumes."
    )


def tutor_reply(message: str, weak_topics: list[str]) -> dict[str, Any]:
    api_key = current_app.config.get("OPENAI_API_KEY") or ""
    model = current_app.config.get("OPENAI_MODEL", "gpt-4o-mini")
    context = ", ".join(weak_topics[:8]) if weak_topics else "general coursework"

    if not api_key:
        return {"mode": "offline", "reply": _offline_reply(message, weak_topics)}

    try:
        from openai import OpenAI

        client = OpenAI(api_key=api_key)
        sys_prompt = (
            "You are a concise CS tutor for B.Tech students. Prefer short paragraphs and bullet steps. "
            f"The student struggles most with: {context}. Tie explanations to those areas when relevant."
        )
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": sys_prompt},
                {"role": "user", "content": message},
            ],
            temperature=0.5,
            max_tokens=600,
        )
        text = (resp.choices[0].message.content or "").strip()
        if text:
            return {"mode": "online", "reply": text}
    except Exception:
        current_app.logger.exception("OpenAI tutor failed; using offline fallback")

    return {"mode": "offline", "reply": _offline_reply(message, weak_topics)}
