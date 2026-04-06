from flask import Blueprint, jsonify, request

from app.extensions import db
from app.models import User
from app.utils.auth import require_auth

bp = Blueprint("users", __name__, url_prefix="/api/users")


@bp.route("/profile", methods=["GET"])
@require_auth
def get_profile():
    """Get current user's profile."""
    user = request.api_user
    return jsonify({
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "role": user.role,
        "semester": user.semester,
        "section": user.section,
        "has_face_encoding": bool(user.face_encoding),
        "created_at": user.created_at.isoformat() if user.created_at else ""
    })


@bp.route("/profile", methods=["PUT"])
@require_auth
def update_profile():
    """Update current user's profile."""
    user = request.api_user
    data = request.get_json(force=True, silent=True) or {}
    
    if "name" in data:
        user.name = (data.get("name") or user.name).strip()
    
    if "semester" in data and user.role == "student":
        user.semester = (data.get("semester") or user.semester).strip()
    
    if "section" in data and user.role == "student":
        user.section = (data.get("section") or user.section).strip()
    
    db.session.commit()
    return jsonify({
        "id": user.id,
        "name": user.name,
        "semester": user.semester,
        "section": user.section,
        "message": "Profile updated"
    })


@bp.route("/profile/<int:user_id>", methods=["GET"])
@require_auth
def get_user_profile(user_id: int):
    """Get another user's public profile."""
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404
    
    return jsonify({
        "id": user.id,
        "name": user.name,
        "role": user.role,
        "semester": user.semester if request.api_user.role == "teacher" else None,
        "section": user.section if request.api_user.role == "teacher" else None
    })


@bp.route("/list", methods=["GET"])
@require_auth
def list_users():
    """List users (teachers can see all, students see peers in same semester/section)."""
    request_user = request.api_user
    role_filter = request.args.get("role", "")
    
    query = User.query
    
    if role_filter and request_user.role == "teacher":
        query = query.filter_by(role=role_filter)
    
    if request_user.role == "student":
        # Students see others in their semester/section
        query = query.filter(
            User.semester == request_user.semester,
            User.section == request_user.section
        )
    
    users = query.order_by(User.name).all()
    
    return jsonify({
        "total": len(users),
        "users": [{
            "id": u.id,
            "name": u.name,
            "email": u.email if request_user.role == "teacher" or u.id == request_user.id else None,
            "role": u.role,
            "semester": u.semester if request_user.role == "teacher" else None,
            "section": u.section if request_user.role == "teacher" else None
        } for u in users]
    })


@bp.route("/search", methods=["GET"])
@require_auth
def search_users():
    """Search users by name or email (teachers only)."""
    if request.api_user.role != "teacher":
        return jsonify({"error": "Teachers only"}), 403
    
    query_text = request.args.get("q", "").lower().strip()
    if not query_text:
        return jsonify({"error": "Query parameter 'q' required"}), 400
    
    users = User.query.filter(
        (User.name.ilike(f"%{query_text}%")) |
        (User.email.ilike(f"%{query_text}%"))
    ).order_by(User.name).limit(50).all()
    
    return jsonify({
        "query": query_text,
        "results_count": len(users),
        "results": [{
            "id": u.id,
            "name": u.name,
            "email": u.email,
            "role": u.role,
            "semester": u.semester,
            "section": u.section
        } for u in users]
    })


@bp.route("/change-password", methods=["POST"])
@require_auth
def change_password():
    """Change user's password."""
    from werkzeug.security import generate_password_hash, check_password_hash
    
    user = request.api_user
    data = request.get_json(force=True, silent=True) or {}
    
    current_password = data.get("current_password", "")
    new_password = data.get("new_password", "")
    
    if not current_password or not new_password:
        return jsonify({"error": "current_password and new_password required"}), 400
    
    if not check_password_hash(user.password_hash, current_password):
        return jsonify({"error": "Current password is incorrect"}), 401
    
    if len(new_password) < 6:
        return jsonify({"error": "New password must be at least 6 characters"}), 400
    
    user.password_hash = generate_password_hash(new_password)
    db.session.commit()
    
    return jsonify({"message": "Password changed successfully"})


@bp.route("/stats", methods=["GET"])
@require_auth
def user_stats():
    """Get user statistics (teachers see class stats, students see personal stats)."""
    user = request.api_user
    from app.models import AttendanceRecord, TestPaper
    from datetime import date, timedelta
    
    stats = {
        "user_id": user.id,
        "role": user.role
    }
    
    if user.role == "student":
        # Get personal stats
        today = date.today()
        week_ago = today - timedelta(days=7)
        
        # Attendance
        attendance_this_week = AttendanceRecord.query.filter(
            AttendanceRecord.user_id == user.id,
            AttendanceRecord.marked_date >= week_ago,
            AttendanceRecord.marked_date <= today
        ).all()
        
        # Tests taken
        tests_taken = TestPaper.query.filter_by(student_id=user.id).count()
        
        stats.update({
            "attendance_this_week": len(attendance_this_week),
            "tests_taken": tests_taken,
            "semester": user.semester,
            "section": user.section
        })
    
    else:
        # Teachers see class stats
        from app.models import Syllabus
        
        syllabi_count = Syllabus.query.filter_by(teacher_id=user.id).count()
        
        stats.update({
            "syllabi_count": syllabi_count
        })
    
    return jsonify(stats)
