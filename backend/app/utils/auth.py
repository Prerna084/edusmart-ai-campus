from functools import wraps

from flask import jsonify, request

from app.models import User


def require_auth(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify({"error": "Missing or invalid Authorization header"}), 401
        token = auth[7:].strip()
        user = User.query.filter_by(api_token=token).first()
        if not user:
            return jsonify({"error": "Invalid or expired session"}), 401
        request.api_user = user
        return fn(*args, **kwargs)

    return wrapper


def require_role(role: str):
    def deco(fn):
        @wraps(fn)
        def inner(*args, **kwargs):
            from flask import request as rq

            u = getattr(rq, "api_user", None)
            if not u or u.role != role:
                return jsonify({"error": "Forbidden"}), 403
            return fn(*args, **kwargs)

        return inner

    return deco
