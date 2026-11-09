import os
from flask import Flask, request
from app.config.settings import Config
from app.infrastructure.persistence.db_models import db
from app.infrastructure.persistence.repository import SQLAlchemySolicitudRepository
from app.infrastructure.ml.scikit_classifier import ScikitLocalClassifier
from app.application.use_cases.solicitud_use_cases import OrientacionUseCases
from app.api.routes.solicitudes_router import create_solicitudes_blueprint

def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    @app.before_request
    def handle_preflight():
        if request.method == 'OPTIONS':
            return app.make_default_options_response()

    @app.after_request
    def add_cors_headers(response):
        response.headers['Access-Control-Allow-Origin'] = os.getenv('CORS_ALLOW_ORIGIN', '*')
        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PATCH, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = (
            'Content-Type, Authorization, Ocp-Apim-Subscription-Key'
        )
        return response

    db.init_app(app)
    with app.app_context():
        db.create_all()

    repository = SQLAlchemySolicitudRepository()
    classifier = ScikitLocalClassifier()
    use_cases = OrientacionUseCases(repository, classifier)

    solicitudes_bp = create_solicitudes_blueprint(use_cases)

    app.register_blueprint(solicitudes_bp, url_prefix='/api/v1/orientacion/solicitudes')

    return app

if __name__ == '__main__':
    app = create_app()
    port = int(os.getenv('PORT', '5000'))
    debug = os.getenv('FLASK_DEBUG', 'true').lower() == 'true'
    app.run(host='0.0.0.0', port=port, debug=debug)
