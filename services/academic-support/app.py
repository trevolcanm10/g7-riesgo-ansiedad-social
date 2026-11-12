from __future__ import annotations

from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent / ".env", override=False)

from src.application.academic_support_service import AcademicSupportService
from src.config import Settings
from src.domain.recommender import HybridRecommendationEngine
from src.infrastructure.mysql_repository import MySqlAcademicSupportRepository
from src.presentation.http import create_http_app


settings = Settings.from_environment()
repository = MySqlAcademicSupportRepository(settings)
service = AcademicSupportService(repository, HybridRecommendationEngine())
app = create_http_app(settings, service, repository)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=settings.port, debug=False)
