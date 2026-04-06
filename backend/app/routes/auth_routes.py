import secrets

from flask import Blueprint, jsonify, request
from werkzeug.security import check_password_hash, generate_password_hash

from app.extensions import db
from app.models import User

bp = Blueprint("auth", __name__, url_prefix="/api/auth")


@bp.route("/register", methods=["POST"])
def register():
    try:
        data = request.get_json(force=True, silent=True) or {}
        email = (data.get("email") or "").strip().lower()
        password = data.get("password") or ""
        name = (data.get("name") or "").strip()
        role = (data.get("role") or "student").strip().lower()
        semester = (data.get("semester") or "").strip()
        section = (data.get("section") or "").strip()

        if not email or not password or not name:
            return jsonify({"error": "email, password, and name are required"}), 400
        if role not in ("student", "teacher"):
            return jsonify({"error": "role must be student or teacher"}), 400
        if User.query.filter_by(email=email).first():
            return jsonify({"error": "Email already registered"}), 409

        user = User(
            email=email,
            password_hash=generate_password_hash(password),
            name=name,
            role=role,
            semester=semester,
            section=section,
            api_token=secrets.token_urlsafe(32),
        )
        db.session.add(user)
        db.session.commit()
        return jsonify(_user_response(user)), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500


@bp.route("/login", methods=["POST"])
def login():
    try:
        data = request.get_json(force=True, silent=True) or {}
        email = (data.get("email") or "").strip().lower()
        password = data.get("password") or ""
        user = User.query.filter_by(email=email).first()
        if not user or not check_password_hash(user.password_hash, password):
            return jsonify({"error": "Invalid credentials"}), 401
        user.api_token = secrets.token_urlsafe(32)
        db.session.commit()
        return jsonify(_user_response(user)), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500


def _user_response(user: User) -> dict:
    return {
        "token": user.api_token,
        "user": {
            "id": user.id,
            "email": user.email,
            "name": user.name,
            "role": user.role,
            "semester": user.semester,
            "section": user.section,
        },
    }
