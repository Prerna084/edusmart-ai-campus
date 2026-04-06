from flask import Blueprint, jsonify, request

from app.extensions import db
from app.models import AttendanceRecord, TestPaper, User, Assessment, Question
from app.services.analytics_service import student_analytics, teacher_class_analytics
from app.utils.auth import require_auth, require_role
from datetime import date, timedelta, datetime

bp = Blueprint("analytics", __name__, url_prefix="/api/analytics")


@bp.route("/student/me", methods=["GET"])
@require_auth
def my_analytics():
    if request.api_user.role != "student":
        return jsonify({"error": "Students only"}), 403
    return jsonify(student_analytics(request.api_user.id)), 200


@bp.route("/student/<int:sid>", methods=["GET"])
@require_auth
@require_role("teacher")
def student_detail(sid: int):
    return jsonify(student_analytics(sid)), 200


@bp.route("/class", methods=["GET"])
@require_auth
@require_role("teacher")
def class_view():
    semester = request.args.get("semester") or request.api_user.semester or ""
    section = request.args.get("section") or request.api_user.section or ""
    if not semester or not section:
        return jsonify({"error": "semester and section query params (or teacher profile) required"}), 400
    return jsonify(teacher_class_analytics(request.api_user.id, semester, section)), 200


@bp.route("/performance", methods=["GET"])
@require_auth
def performance_analytics():
    """Get detailed performance analytics for current user."""
    user = request.api_user
    from_date = request.args.get("from_date")
    to_date = request.args.get("to_date")
    
    today = date.today()
    date_range = {
        "from": from_date or (today - timedelta(days=30)).isoformat(),
        "to": to_date or today.isoformat()
    }
    
    analytics = {
        "user_id": user.id,
        "name": user.name,
        "role": user.role,
        "date_range": date_range
    }
    
    if user.role == "student":
        # Get test performance
        tests = TestPaper.query.filter_by(student_id=user.id).all()
        total_tests = len(tests)
        
        # Calculate average score if assessments exist
        assessments = Assessment.query.filter_by(student_id=user.id).all()
        avg_score = 0
        if assessments:
            avg_score = sum(a.score for a in assessments) / len(assessments)
        
        # Attendance stats
        attendance = AttendanceRecord.query.filter_by(user_id=user.id).all()
        present = len([a for a in attendance if a.status == "present"])
        total_attendance = len(attendance)
        attendance_pct = (present / total_attendance * 100) if total_attendance > 0 else 0
        
        analytics.update({
            "tests": {
                "total_taken": total_tests,
                "average_score": round(avg_score, 2),
                "total_assessments": len(assessments)
            },
            "attendance": {
                "total_records": total_attendance,
                "present": present,
                "absent": total_attendance - present,
                "attendance_percentage": round(attendance_pct, 2)
            }
        })
    
    else:
        # Teacher analytics
        syllabi_count = db.session.query(db.func.count(db.Table)).select_from(db.Table)
        
        analytics.update({
            "syllabi_published": 0,
            "classes_managed": 0
        })
    
    return jsonify(analytics)


@bp.route("/performance/trends", methods=["GET"])
@require_auth
def performance_trends():
    """Get performance trends over time."""
    user = request.api_user
    if user.role != "student":
        return jsonify({"error": "Students only"}), 403
    
    weeks = request.args.get("weeks", 4, type=int)
    
    trends = []
    for i in range(weeks, 0, -1):
        week_start = date.today() - timedelta(days=7*i)
        week_end = week_start + timedelta(days=6)
        
        assessments = Assessment.query.filter(
            Assessment.student_id == user.id,
            Assessment.assessment_date >= week_start,
            Assessment.assessment_date <= week_end
        ).all()
        
        attendance = AttendanceRecord.query.filter(
            AttendanceRecord.user_id == user.id,
            AttendanceRecord.marked_date >= week_start,
            AttendanceRecord.marked_date <= week_end
        ).all()
        
        week_score = (sum(a.score for a in assessments) / len(assessments)) if assessments else 0
        attendance_pct = (len([a for a in attendance if a.status == "present"]) / len(attendance) * 100) if attendance else 0
        
        trends.append({
            "week": f"Week {6-i}",
            "week_start": week_start.isoformat(),
            "week_end": week_end.isoformat(),
            "average_score": round(week_score, 2),
            "attendance_percentage": round(attendance_pct, 2),
            "assessments_count": len(assessments),
            "attendance_count": len(attendance)
        })
    
    return jsonify({
        "user_id": user.id,
        "weeks": weeks,
        "trends": trends
    })


@bp.route("/exam-performance", methods=["GET"])
@require_auth
def exam_performance():
    """Get exam/test performance breakdown."""
    user = request.api_user
    if user.role != "student":
        return jsonify({"error": "Students only"}), 403
    
    tests = TestPaper.query.filter_by(student_id=user.id).all()
    
    performance_data = []
    for test in tests:
        assessment = Assessment.query.filter_by(student_id=user.id, test_paper_id=test.id).first()
        
        correct_count = len([q for q in test.questions if assessment and assessment.score > 0]) if hasattr(test, 'questions') else 0
        
        performance_data.append({
            "test_id": test.id,
            "test_type": getattr(test, 'test_type', 'daily'),
            "score": assessment.score if assessment else None,
            "created_at": test.created_at.isoformat() if hasattr(test, 'created_at') and test.created_at else None,
            "assessment_date": assessment.assessment_date.isoformat() if assessment and hasattr(assessment, 'assessment_date') else None
        })
    
    return jsonify({
        "user_id": user.id,
        "total_tests": len(tests),
        "performance": performance_data
    })
