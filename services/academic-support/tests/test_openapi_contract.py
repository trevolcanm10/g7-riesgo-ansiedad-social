from __future__ import annotations

import unittest
from pathlib import Path

import yaml
from jsonschema import RefResolver
from openapi_schema_validator import OAS30Validator
from openapi_spec_validator import validate_spec


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]
OPENAPI_PATH = REPOSITORY_ROOT / "openapi" / "academic-support.yaml"


class AcademicSupportOpenApiContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.spec = yaml.safe_load(OPENAPI_PATH.read_text(encoding="utf-8"))
        validate_spec(cls.spec)

    def test_resource_response_accepts_nullable_modality(self) -> None:
        resource_schema = self.spec["components"]["schemas"]["Resource"]
        resolver = RefResolver.from_schema(self.spec)
        response_validator = OAS30Validator(resource_schema, resolver=resolver)
        resource = {
            "id": 81,
            "type": "MATERIAL",
            "title": "Guía de estudio",
            "description": "Material de apoyo",
            "tags": ["estudio"],
            "courseCodes": [],
            "modality": None,
            "location": None,
            "startAt": None,
            "endAt": None,
            "capacity": None,
            "availableSeats": None,
            "url": "https://example.org/guia",
            "providerUserId": None,
            "isSynthetic": False,
            "createdAt": "2026-11-18T12:00:00Z",
            "updatedAt": "2026-11-18T12:00:00Z",
        }

        response_validator.validate(resource)

    def test_recommendations_reuse_the_resource_response_schema(self) -> None:
        recommendation_resource = self.spec["components"]["schemas"][
            "Recommendation"
        ]["properties"]["resource"]
        self.assertEqual(
            recommendation_resource,
            {"$ref": "#/components/schemas/Resource"},
        )
