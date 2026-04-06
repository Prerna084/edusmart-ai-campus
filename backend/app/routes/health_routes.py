from flask import Blueprint, current_app, jsonify

from app.face_engine import face_available

bp = Blueprint("health", __name__, url_prefix="/api")


@bp.route("/health", methods=["GET"])
def health():
    return jsonify(
        {
            "status": "ok",
            "face_module": face_available() and not current_app.config.get("SKIP_FACE"),
            "database": current_app.config.get("SQLALCHEMY_DATABASE_URI", "").split("://")[0],
        }
    ), 200
