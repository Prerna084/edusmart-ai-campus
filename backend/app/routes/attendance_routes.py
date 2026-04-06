from datetime import date, datetime

from flask import Blueprint, current_app, jsonify, request

from app.extensions import db
from app.face_engine import best_match, encode_face_from_bytes, encoding_to_json, face_available
from app.models import AttendanceRecord, User
from app.utils.auth import require_auth

bp = Blueprint("attendance", __name__, url_prefix="/api/attendance")


@bp.route("/register-face", methods=["POST"])
@require_auth
def register_face():
    if request.api_user.role != "student":
        return jsonify({"error": "Only students enroll faces"}), 403
    if current_app.config.get("SKIP_FACE") or not face_available():
        return jsonify({"error": "Face module unavailable (install face_recognition or set SKIP_FACE)"}), 503

    if "file" not in request.files:
        return jsonify({"error": "file (image) required"}), 400
    raw = request.files["file"].read()
    enc = encode_face_from_bytes(raw)
    if enc is None:
        return jsonify({"error": "No face detected in image"}), 400

    u = request.api_user
    u.face_encoding = encoding_to_json(enc)
    db.session.commit()
    return jsonify({"message": "Face encoding saved", "user_id": u.id})


@bp.route("/mark", methods=["POST"])
def mark():
    """Public kiosk-style mark: match any enrolled student (MVP). Optional Bearer to restrict later."""
    if current_app.config.get("SKIP_FACE") or not face_available():
        return jsonify({"error": "Face module unavailable"}), 503
    if "file" not in request.files:
        return jsonify({"error": "file (image) required"}), 400

    raw = request.files["file"].read()
    unknown = encode_face_from_bytes(raw)
    if unknown is None:
        return jsonify({"error": "No face detected"}), 400

    users = User.query.filter(User.face_encoding.isnot(None), User.role == "student").all()
    pairs = [(u.id, u.face_encoding) for u in users if u.face_encoding]
    uid, dist = best_match(unknown, pairs)
    if uid is None:
        return jsonify({"error": "No matching student", "distance": dist}), 404

    today = date.today()
    existing = AttendanceRecord.query.filter_by(user_id=uid, marked_date=today).first()
    if existing:
        return jsonify({"message": "Already marked today", "user_id": uid, "duplicate": True})

    rec = AttendanceRecord(
        user_id=uid,
        marked_date=today,
        marked_time=datetime.utcnow().time(),
        status="present",
    )
    db.session.add(rec)
    db.session.commit()
    st = db.session.get(User, uid)
    return jsonify(
        {
            "message": "Attendance recorded",
            "user_id": uid,
            "name": st.name if st else "",
            "distance": dist,
        }
    )


@bp.route("/today", methods=["GET"])
def today_list():
    today = date.today()
    rows = AttendanceRecord.query.filter_by(marked_date=today).all()
    out = []
    for r in rows:
        u = db.session.get(User, r.user_id)
        out.append(
            {
                "user_id": r.user_id,
                "name": u.name if u else "",
                "time": r.marked_time.isoformat() if r.marked_time else "",
                "status": r.status,
            }
        )
    return jsonify({"date": today.isoformat(), "records": out})


@bp.route("/status", methods=["GET"])
@require_auth
def attendance_status():
    """Get attendance status for current user."""
    user = request.api_user
    today = date.today()
    record = AttendanceRecord.query.filter_by(user_id=user.id, marked_date=today).first()
    
    if record:
        return jsonify({
            "user_id": user.id,
            "marked_today": True,
            "time": record.marked_time.isoformat() if record.marked_time else None,
            "status": record.status
        })
    return jsonify({
        "user_id": user.id,
        "marked_today": False,
        "time": None,
        "status": None
    })


@bp.route("/history", methods=["GET"])
@require_auth
def attendance_history():
    """Get attendance history for current user."""
    user = request.api_user
    from_date = request.args.get("from_date")
    to_date = request.args.get("to_date")
    limit = request.args.get("limit", 30, type=int)
    
    query = AttendanceRecord.query.filter_by(user_id=user.id)
    
    if from_date:
        try:
            from_dt = datetime.fromisoformat(from_date).date()
            query = query.filter(AttendanceRecord.marked_date >= from_dt)
        except Exception:
            pass
    
    if to_date:
        try:
            to_dt = datetime.fromisoformat(to_date).date()
            query = query.filter(AttendanceRecord.marked_date <= to_dt)
        except Exception:
            pass
    
    records = query.order_by(AttendanceRecord.marked_date.desc()).limit(limit).all()
    out = [{
        "date": r.marked_date.isoformat(),
        "time": r.marked_time.isoformat() if r.marked_time else None,
        "status": r.status
    } for r in records]
    
    return jsonify({
        "user_id": user.id,
        "total_records": len(out),
        "records": out
    })


@bp.route("/manual-mark", methods=["POST"])
@require_auth
def manual_mark():
    """Manually mark attendance for a student (teacher only)."""
    if request.api_user.role != "teacher":
        return jsonify({"error": "Teachers only"}), 403
    
    data = request.get_json(force=True, silent=True) or {}
    student_id = data.get("student_id")
    marked_date = data.get("marked_date")
    status = data.get("status", "present")
    
    if not student_id or not marked_date:
        return jsonify({"error": "student_id and marked_date required"}), 400
    
    try:
        mark_date = datetime.fromisoformat(marked_date).date()
    except Exception:
        return jsonify({"error": "Invalid date format (use ISO format)"}), 400
    
    student = db.session.get(User, student_id)
    if not student:
        return jsonify({"error": "Student not found"}), 404
    
    existing = AttendanceRecord.query.filter_by(user_id=student_id, marked_date=mark_date).first()
    if existing:
        existing.status = status
    else:
        rec = AttendanceRecord(
            user_id=student_id,
            marked_date=mark_date,
            marked_time=datetime.utcnow().time(),
            status=status
        )
        db.session.add(rec)
    
    db.session.commit()
    return jsonify({
        "message": "Attendance updated",
        "user_id": student_id,
        "date": mark_date.isoformat(),
        "status": status
    })


@bp.route("/statistics", methods=["GET"])
@require_auth
def attendance_statistics():
    """Get attendance statistics for current user."""
    user = request.api_user
    from_date = request.args.get("from_date")
    to_date = request.args.get("to_date")
    
    query = AttendanceRecord.query.filter_by(user_id=user.id)
    
    if from_date:
        try:
            from_dt = datetime.fromisoformat(from_date).date()
            query = query.filter(AttendanceRecord.marked_date >= from_dt)
        except Exception:
            pass
    
    if to_date:
        try:
            to_dt = datetime.fromisoformat(to_date).date()
            query = query.filter(AttendanceRecord.marked_date <= to_dt)
        except Exception:
            pass
    
    records = query.all()
    total = len(records)
    present = len([r for r in records if r.status == "present"])
    absent = len([r for r in records if r.status == "absent"])
    
    attendance_pct = (present / total * 100) if total > 0 else 0
    
    return jsonify({
        "user_id": user.id,
        "total_days": total,
        "present": present,
        "absent": absent,
        "attendance_percentage": round(attendance_pct, 2),
        "period": {
            "from": from_date,
            "to": to_date
        }
    })
