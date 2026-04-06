from flask import Blueprint, current_app, jsonify, request

from app.extensions import db
from app.models import Syllabus, WeekPlan, User
from app.utils.auth import require_auth, require_role

bp = Blueprint("syllabus", __name__, url_prefix="/api/syllabus")


@bp.route("", methods=["POST"])
@require_auth
@require_role("teacher")
def upload_syllabus():
    data = request.get_json(force=True, silent=True) or {}
    title = (data.get("title") or "Course Syllabus").strip()
    content = (data.get("content_text") or "").strip()
    semester = (data.get("semester") or request.api_user.semester or "").strip()
    section = (data.get("section") or request.api_user.section or "").strip()
    if not content:
        return jsonify({"error": "content_text required"}), 400
    lim = current_app.config.get("MAX_SYLLABUS_CHARS", 100_000)
    if len(content) > lim:
        return jsonify({"error": f"content_text too long (max {lim})"}), 400

    s = Syllabus(
        teacher_id=request.api_user.id,
        semester=semester,
        section=section,
        title=title,
        content_text=content,
    )
    db.session.add(s)
    db.session.commit()
    return jsonify({"id": s.id, "title": s.title, "semester": s.semester, "section": s.section}), 201


@bp.route("", methods=["GET"])
@require_auth
def list_syllabi():
    u = request.api_user
    if u.role == "teacher":
        items = Syllabus.query.filter_by(teacher_id=u.id).order_by(Syllabus.created_at.desc()).all()
    else:
        items = (
            Syllabus.query.filter_by(semester=u.semester or "", section=u.section or "")
            .order_by(Syllabus.created_at.desc())
            .all()
        )
    return jsonify(
        {
            "syllabi": [
                {
                    "id": x.id,
                    "title": x.title,
                    "semester": x.semester,
                    "section": x.section,
                    "created_at": x.created_at.isoformat() if x.created_at else "",
                    "preview": (x.content_text[:280] + "…") if len(x.content_text) > 280 else x.content_text,
                }
                for x in items
            ]
        }
    )


@bp.route("/<int:syllabus_id>/week-plan", methods=["POST"])
@require_auth
@require_role("teacher")
def add_week_plan(syllabus_id: int):
    s = db.session.get(Syllabus, syllabus_id)
    if not s or s.teacher_id != request.api_user.id:
        return jsonify({"error": "Syllabus not found"}), 404
    data = request.get_json(force=True, silent=True) or {}
    week_number = int(data.get("week_number", 0))
    summary = (data.get("topics_summary") or "").strip()
    if week_number < 1 or not summary:
        return jsonify({"error": "week_number (>=1) and topics_summary required"}), 400
    existing = WeekPlan.query.filter_by(syllabus_id=s.id, week_number=week_number).first()
    if existing:
        existing.topics_summary = summary
    else:
        db.session.add(WeekPlan(syllabus_id=s.id, week_number=week_number, topics_summary=summary))
    db.session.commit()
    return jsonify({"syllabus_id": s.id, "week_number": week_number}), 200


@bp.route("/<int:syllabus_id>/week-plans", methods=["GET"])
@require_auth
def list_week_plans(syllabus_id: int):
    s = db.session.get(Syllabus, syllabus_id)
    if not s:
        return jsonify({"error": "Not found"}), 404
    u = request.api_user
    if u.role == "teacher" and s.teacher_id != u.id:
        return jsonify({"error": "Forbidden"}), 403
    if u.role == "student" and (s.semester != (u.semester or "") or s.section != (u.section or "")):
        return jsonify({"error": "Forbidden"}), 403
    wps = WeekPlan.query.filter_by(syllabus_id=s.id).order_by(WeekPlan.week_number).all()
    return jsonify(
        {
            "week_plans": [
                {"week_number": w.week_number, "topics_summary": w.topics_summary} for w in wps
            ]
        }
    )


@bp.route("/<int:syllabus_id>", methods=["GET"])
@require_auth
def get_syllabus(syllabus_id: int):
    """Get full syllabus details."""
    s = db.session.get(Syllabus, syllabus_id)
    if not s:
        return jsonify({"error": "Syllabus not found"}), 404
    
    u = request.api_user
    # Access control: teachers see their own, students see their semester/section
    if u.role == "teacher" and s.teacher_id != u.id:
        return jsonify({"error": "Forbidden"}), 403
    if u.role == "student" and (s.semester != (u.semester or "") or s.section != (u.section or "")):
        return jsonify({"error": "Forbidden"}), 403
    
    teacher = db.session.get(User, s.teacher_id)
    return jsonify({
        "id": s.id,
        "title": s.title,
        "semester": s.semester,
        "section": s.section,
        "content_text": s.content_text,
        "teacher": {
            "id": s.teacher_id,
            "name": teacher.name if teacher else "Unknown"
        },
        "created_at": s.created_at.isoformat() if s.created_at else ""
    })


@bp.route("/<int:syllabus_id>", methods=["PUT"])
@require_auth
@require_role("teacher")
def update_syllabus(syllabus_id: int):
    """Update syllabus content (teacher only)."""
    s = db.session.get(Syllabus, syllabus_id)
    if not s or s.teacher_id != request.api_user.id:
        return jsonify({"error": "Syllabus not found or access denied"}), 404
    
    data = request.get_json(force=True, silent=True) or {}
    
    if "title" in data:
        s.title = (data.get("title") or s.title).strip()
    
    if "content_text" in data:
        content = (data.get("content_text") or "").strip()
        lim = current_app.config.get("MAX_SYLLABUS_CHARS", 100_000)
        if len(content) > lim:
            return jsonify({"error": f"content_text too long (max {lim})"}), 400
        s.content_text = content
    
    if "semester" in data:
        s.semester = (data.get("semester") or s.semester).strip()
    
    if "section" in data:
        s.section = (data.get("section") or s.section).strip()
    
    db.session.commit()
    return jsonify({
        "id": s.id,
        "title": s.title,
        "semester": s.semester,
        "section": s.section,
        "message": "Syllabus updated"
    })


@bp.route("/<int:syllabus_id>", methods=["DELETE"])
@require_auth
@require_role("teacher")
def delete_syllabus(syllabus_id: int):
    """Delete a syllabus (teacher only)."""
    s = db.session.get(Syllabus, syllabus_id)
    if not s or s.teacher_id != request.api_user.id:
        return jsonify({"error": "Syllabus not found or access denied"}), 404
    
    db.session.delete(s)
    db.session.commit()
    return jsonify({"message": "Syllabus deleted", "id": syllabus_id})


@bp.route("/search", methods=["GET"])
@require_auth
def search_syllabi():
    """Search syllabi by title or content."""
    query_text = request.args.get("q", "").lower().strip()
    if not query_text:
        return jsonify({"error": "Query parameter 'q' required"}), 400
    
    u = request.api_user
    
    if u.role == "teacher":
        syllabi = Syllabus.query.filter_by(teacher_id=u.id).all()
    else:
        syllabi = Syllabus.query.filter_by(
            semester=u.semester or "",
            section=u.section or ""
        ).all()
    
    results = []
    for s in syllabi:
        if query_text in s.title.lower() or query_text in s.content_text.lower():
            results.append({
                "id": s.id,
                "title": s.title,
                "semester": s.semester,
                "section": s.section,
                "preview": (s.content_text[:200] + "…") if len(s.content_text) > 200 else s.content_text,
                "created_at": s.created_at.isoformat() if s.created_at else ""
            })
    
    return jsonify({
        "query": query_text,
        "results_count": len(results),
        "results": results
    })
