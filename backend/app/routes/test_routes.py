import json

from flask import Blueprint, jsonify, request

from app.extensions import db
from app.models import Submission, TestPaper
from app.services.evaluation import evaluate_submission
from app.services.test_service import get_or_create_daily_test, get_or_create_weekly_test
from app.utils.auth import require_auth

bp = Blueprint("tests", __name__, url_prefix="/api/tests")


@bp.route("/daily", methods=["POST"])
@require_auth
def daily():
    if request.api_user.role != "student":
        return jsonify({"error": "Students only"}), 403
    data = request.get_json(force=True, silent=True) or {}
    week_number = int(data.get("week_number", 1))
    try:
        payload = get_or_create_daily_test(request.api_user, week_number=week_number)
        return jsonify(payload), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@bp.route("/weekly", methods=["POST"])
@require_auth
def weekly():
    if request.api_user.role != "student":
        return jsonify({"error": "Students only"}), 403
    data = request.get_json(force=True, silent=True) or {}
    week_number = int(data.get("week_number", 1))
    try:
        payload = get_or_create_weekly_test(request.api_user, week_number=week_number)
        return jsonify(payload), 200
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@bp.route("/<int:paper_id>/submit", methods=["POST"])
@require_auth
def submit(paper_id: int):
    st = request.api_user
    if st.role != "student":
        return jsonify({"error": "Students only"}), 403
    paper = db.session.get(TestPaper, paper_id)
    if not paper or paper.student_id != st.id:
        return jsonify({"error": "Test not found"}), 404
    if Submission.query.filter_by(test_paper_id=paper.id, student_id=st.id).first():
        return jsonify({"error": "Already submitted"}), 409

    data = request.get_json(force=True, silent=True) or {}
    answers = data.get("answers")
    if not isinstance(answers, list):
        return jsonify({"error": "answers array required"}), 400
    try:
        result = evaluate_submission(paper, st, answers)
        return jsonify(result), 200
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@bp.route("/<int:paper_id>", methods=["GET"])
@require_auth
def get_paper(paper_id: int):
    paper = db.session.get(TestPaper, paper_id)
    if not paper or paper.student_id != request.api_user.id:
        return jsonify({"error": "Not found"}), 404
    return jsonify(
        {
            "paper_id": paper.id,
            "test_type": paper.test_type,
            "paper_date": paper.paper_date.isoformat(),
            "week_number": paper.week_number,
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
    )
