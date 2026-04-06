import traceback

from flask import Flask, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

from app.config import Config
from app.extensions import db


def create_app(config_class: type = Config) -> Flask:
    load_dotenv()
    app = Flask(__name__)
    app.config.from_object(config_class)
    db.init_app(app)
    CORS(app, resources={r"/api/*": {"origins": "*"}})

    from app.routes.auth_routes import bp as auth_bp
    from app.routes.attendance_routes import bp as att_bp
    from app.routes.syllabus_routes import bp as syl_bp
    from app.routes.test_routes import bp as test_bp
    from app.routes.analytics_routes import bp as ana_bp
    from app.routes.chat_routes import bp as chat_bp
    from app.routes.recommendation_routes import bp as rec_bp
    from app.routes.health_routes import bp as health_bp
    from app.routes.user_routes import bp as user_bp

    app.register_blueprint(health_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(att_bp)
    app.register_blueprint(syl_bp)
    app.register_blueprint(test_bp)
    app.register_blueprint(ana_bp)
    app.register_blueprint(chat_bp)
    app.register_blueprint(rec_bp)
    app.register_blueprint(user_bp)

    with app.app_context():
        db.create_all()

    @app.errorhandler(404)
    def not_found(_e):
        return jsonify({"error": "Not found"}), 404

    @app.errorhandler(500)
    def server_err(e):
        app.logger.error(traceback.format_exc())
        return jsonify({"error": "Internal server error"}), 500

    return app
