from flask import Blueprint, jsonify, request

from app.ai.hybrid_tutor import tutor_reply
from app.models import TopicPerformance
from app.utils.auth import require_auth

bp = Blueprint("chat", __name__, url_prefix="/api/chat")


@bp.route("", methods=["POST"])
@require_auth
def chat():
    data = request.get_json(force=True, silent=True) or {}
    message = (data.get("message") or "").strip()
    if not message:
        return jsonify({"error": "message required"}), 400

    weak_topics: list[str] = []
    if request.api_user.role == "student":
        rows = TopicPerformance.query.filter_by(student_id=request.api_user.id).all()
        scored = []
        for r in rows:
            tot = r.correct_count + r.wrong_count
            if tot == 0:
                continue
            scored.append((r.topic, r.wrong_count / tot))
        scored.sort(key=lambda x: x[1], reverse=True)
        weak_topics = [t for t, _ in scored[:10]]

    try:
        out = tutor_reply(message, weak_topics)
        return jsonify({"reply": out["reply"], "mode": out["mode"], "context_topics": weak_topics}), 200
    except Exception as e:
        return jsonify({"error": str(e), "reply": "Temporary error. Please retry.", "mode": "error"}), 500
