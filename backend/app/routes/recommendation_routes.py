from flask import Blueprint, jsonify, request

from app.services.recommendation_service import build_recommendations
from app.utils.auth import require_auth

bp = Blueprint("recommendations", __name__, url_prefix="/api/recommendations")


@bp.route("/me", methods=["GET"])
@require_auth
def for_me():
    if request.api_user.role != "student":
        return jsonify({"error": "Students only"}), 403
    return jsonify(build_recommendations(request.api_user.id)), 200


@bp.route("/student/<int:sid>", methods=["GET"])
@require_auth
def for_student(sid: int):
    u = request.api_user
    if u.role == "teacher" or (u.role == "student" and u.id == sid):
        return jsonify(build_recommendations(sid)), 200
    return jsonify({"error": "Forbidden"}), 403
