from __future__ import annotations

import re
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse

from ..domain.entities import (
    INTERACTION_TYPES,
    MODALITIES,
    RESOURCE_TYPES,
    Resource,
    UserContext,
)
from ..domain.errors import ConflictError, ForbiddenError, NotFoundError, ValidationError
from ..domain.recommender import HybridRecommendationEngine
from ..domain.repositories import AcademicSupportRepository


PREFERENCE_FIELDS = {
    "interests",
    "courseCodes",
    "availableSlots",
    "preferredModalities",
    "timeZone",
}
RESOURCE_MUTABLE_FIELDS = {
    "title",
    "description",
    "tags",
    "courseCodes",
    "modality",
    "location",
    "startAt",
    "endAt",
    "capacity",
    "url",
}
TIME_PATTERN = re.compile(r"^(?:[01]\d|2[0-3]):[0-5]\d$")


def _require_object(value: Any, message: str = "El cuerpo debe ser un objeto JSON") -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValidationError(message)
    return value


def _reject_unknown(body: dict[str, Any], allowed: set[str]) -> None:
    unknown = sorted(set(body) - allowed)
    if unknown:
        raise ValidationError(
            "El cuerpo contiene campos no reconocidos",
            [{"field": field, "message": "Campo no permitido"} for field in unknown],
        )


def _text(value: Any, field: str, max_length: int, required: bool = False) -> str | None:
    if value is None:
        if required:
            raise ValidationError(f"El campo {field} es obligatorio")
        return None
    if not isinstance(value, str):
        raise ValidationError(f"El campo {field} debe ser texto")
    cleaned = value.strip()
    if required and not cleaned:
        raise ValidationError(f"El campo {field} es obligatorio")
    if len(cleaned) > max_length:
        raise ValidationError(f"El campo {field} excede {max_length} caracteres")
    return cleaned or None


def _string_list(
    value: Any, field: str, max_items: int, max_item_length: int = 80
) -> list[str]:
    if not isinstance(value, list):
        raise ValidationError(f"El campo {field} debe ser una lista")
    if len(value) > max_items:
        raise ValidationError(f"El campo {field} admite hasta {max_items} elementos")
    result: list[str] = []
    seen: set[str] = set()
    for item in value:
        if not isinstance(item, str):
            raise ValidationError(f"Los elementos de {field} deben ser texto")
        cleaned = item.strip()
        if not cleaned or len(cleaned) > max_item_length:
            raise ValidationError(
                f"Cada elemento de {field} debe tener entre 1 y {max_item_length} caracteres"
            )
        key = cleaned.casefold()
        if key not in seen:
            result.append(cleaned)
            seen.add(key)
    return result


def _parse_datetime(value: Any, field: str, required: bool = False) -> datetime | None:
    if value is None:
        if required:
            raise ValidationError(f"El campo {field} es obligatorio")
        return None
    if not isinstance(value, str):
        raise ValidationError(f"El campo {field} debe ser una fecha ISO 8601")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValidationError(f"El campo {field} no es una fecha ISO 8601 válida") from exc
    if parsed.tzinfo is None:
        raise ValidationError(f"El campo {field} debe incluir zona horaria, por ejemplo Z")
    return parsed.astimezone(timezone.utc).replace(tzinfo=None)


def _iso_utc(value: datetime | None) -> str | None:
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


class AcademicSupportService:
    def __init__(
        self,
        repository: AcademicSupportRepository,
        recommender: HybridRecommendationEngine,
    ):
        self._repository = repository
        self._recommender = recommender

    def get_preferences(self, user: UserContext) -> dict[str, Any]:
        return self._preferences_to_response(self._repository.get_preferences(user.user_id))

    def save_preferences(self, user: UserContext, raw_body: Any) -> dict[str, Any]:
        body = _require_object(raw_body)
        _reject_unknown(body, PREFERENCE_FIELDS)
        preferences = {
            "interests": _string_list(body.get("interests", []), "interests", 30),
            "course_codes": _string_list(body.get("courseCodes", []), "courseCodes", 40, 30),
            "available_slots": self._validate_slots(body.get("availableSlots", [])),
            "preferred_modalities": self._validate_modalities(
                body.get("preferredModalities", [])
            ),
            "time_zone": self._validate_time_zone(body.get("timeZone", "America/Lima")),
        }
        saved = self._repository.save_preferences(user.user_id, preferences)
        return self._preferences_to_response(saved)

    def list_resources(self, query: dict[str, Any]) -> dict[str, Any]:
        resource_type = query.get("type")
        if resource_type is not None and (not isinstance(resource_type, str) or resource_type not in RESOURCE_TYPES):
            raise ValidationError("El filtro type debe ser TUTORING, WORKSHOP o MATERIAL")
        course_code = query.get("courseCode")
        tag = query.get("tag")
        if course_code is not None and (not isinstance(course_code, str) or not course_code.strip() or len(course_code) > 30):
            raise ValidationError("courseCode debe tener entre 1 y 30 caracteres")
        if tag is not None and (not isinstance(tag, str) or not tag.strip() or len(tag) > 80):
            raise ValidationError("tag debe tener entre 1 y 80 caracteres")
        try:
            limit = int(query.get("limit", 20))
            offset = int(query.get("offset", 0))
        except (TypeError, ValueError) as exc:
            raise ValidationError("limit y offset deben ser números enteros") from exc
        if limit < 1 or limit > 100 or offset < 0 or offset > 10000:
            raise ValidationError("limit debe ser 1-100 y offset debe ser 0-10000")
        records, total = self._repository.list_resources(
            resource_type=resource_type,
            course_code=course_code,
            tag=tag,
            limit=limit,
            offset=offset,
        )
        return {
            "items": [self._resource_to_response(record) for record in records],
            "pagination": {"limit": limit, "offset": offset, "total": total},
        }

    def get_resource(self, resource_id: int) -> dict[str, Any]:
        record = self._repository.get_published_resource(resource_id)
        if record is None:
            raise NotFoundError("No se encontró el recurso publicado")
        return self._resource_to_response(record)

    def create_resource(self, user: UserContext, raw_body: Any) -> dict[str, Any]:
        body = _require_object(raw_body)
        allowed = RESOURCE_MUTABLE_FIELDS | {"type"}
        _reject_unknown(body, allowed)
        if "type" not in body:
            raise ValidationError("El campo type es obligatorio")
        resource_type = body["type"]
        if not isinstance(resource_type, str) or resource_type not in RESOURCE_TYPES:
            raise ValidationError("type debe ser TUTORING, WORKSHOP o MATERIAL")
        if user.role == "ESTUDIANTE" and resource_type != "TUTORING":
            raise ForbiddenError("Los estudiantes solo pueden publicar ofertas de tutoría")
        data = self._normalize_resource(body, resource_type, for_create=True)
        record = self._repository.create_resource(data, user.user_id, user.role)
        return self._resource_to_response(record)

    def update_resource(
        self, user: UserContext, resource_id: int, raw_body: Any
    ) -> dict[str, Any]:
        body = _require_object(raw_body)
        _reject_unknown(body, RESOURCE_MUTABLE_FIELDS)
        if not body:
            raise ValidationError("Envía al menos un campo para actualizar")
        current = self._repository.get_resource_record(resource_id)
        if current is None:
            raise NotFoundError("No se encontró el recurso")

        base = {
            "title": current["title"],
            "description": current["description"],
            "tags": current["tags"],
            "courseCodes": current["course_codes"],
            "modality": current["modality"],
            "location": current["location"],
            "startAt": _iso_utc(current["start_at"]),
            "endAt": _iso_utc(current["end_at"]),
            "capacity": current["capacity"],
            "url": current["url"],
        }
        merged = {**base, **body}
        data = self._normalize_resource(
            merged,
            current["resource_type"],
            for_create=False,
            dates_changed=bool({"startAt", "endAt"} & set(body)),
        )
        update_data = {
            "title": data["title"],
            "description": data["description"],
            "tags": data["tags"],
            "course_codes": data["course_codes"],
            "modality": data["modality"],
            "location": data["location"],
            "start_at": data["start_at"],
            "end_at": data["end_at"],
            "capacity": data["capacity"],
            "url": data["url"],
        }
        record = self._repository.update_resource(
            resource_id, update_data, user.user_id, user.role
        )
        return self._resource_to_response(record)

    def cancel_resource(self, user: UserContext, resource_id: int) -> None:
        self._repository.cancel_resource(resource_id, user.user_id, user.role)

    def recommendations(self, user: UserContext, limit: int) -> dict[str, Any]:
        if limit < 1 or limit > 50:
            raise ValidationError("limit debe estar entre 1 y 50")
        records, preferences, interactions, _ = self._repository.get_recommendation_inputs(
            user.user_id
        )
        resources = [Resource.from_record(record) for record in records]
        ranked = self._recommender.recommend(
            resources=resources,
            preferences=preferences,
            interactions=interactions,
            user_id=user.user_id,
            limit=limit,
        )
        items = [item.to_dict() for item in ranked]
        mode = items[0]["recommendationMode"] if items else "NO_CATALOG"
        return {
            "items": items,
            "recommendationMode": mode,
            "modelVersion": "content-v1+item-cf-v1",
            "generatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        }

    def record_interaction(self, user: UserContext, raw_body: Any) -> dict[str, Any]:
        body = _require_object(raw_body)
        _reject_unknown(body, {"resourceId", "eventType"})
        resource_id = self._positive_id(body.get("resourceId"), "resourceId")
        event_type = body.get("eventType")
        if not isinstance(event_type, str) or event_type not in INTERACTION_TYPES:
            raise ValidationError(
                "eventType debe ser VIEW, CLICK, COMPLETE o DISMISS"
            )
        self._repository.record_interaction(user.user_id, resource_id, event_type)
        return {"resourceId": resource_id, "eventType": event_type, "recorded": True}

    def enroll(self, user: UserContext, resource_id: int) -> dict[str, Any]:
        return self._repository.enroll_in_workshop(user.user_id, resource_id)

    def cancel_enrollment(self, user: UserContext, resource_id: int) -> None:
        self._repository.cancel_workshop_enrollment(user.user_id, resource_id)

    def enrollments(self, user: UserContext) -> list[dict[str, Any]]:
        return self._repository.list_user_enrollments(user.user_id)

    @staticmethod
    def _positive_id(value: Any, field: str) -> int:
        if isinstance(value, bool) or not isinstance(value, int):
            raise ValidationError(f"{field} debe ser un entero positivo")
        parsed = value
        if parsed <= 0:
            raise ValidationError(f"{field} debe ser un entero positivo")
        return parsed

    @staticmethod
    def _validate_time_zone(value: Any) -> str:
        if not isinstance(value, str) or len(value) > 64:
            raise ValidationError("timeZone debe ser una zona IANA válida")
        try:
            ZoneInfo(value)
        except ZoneInfoNotFoundError as exc:
            raise ValidationError("timeZone debe ser una zona IANA válida") from exc
        return value

    @staticmethod
    def _validate_modalities(value: Any) -> list[str]:
        if not isinstance(value, list):
            raise ValidationError("preferredModalities debe ser una lista")
        if len(value) > len(MODALITIES):
            raise ValidationError("preferredModalities contiene demasiados elementos")
        result: list[str] = []
        for modality in value:
            if not isinstance(modality, str) or modality not in MODALITIES:
                raise ValidationError(
                    "Cada modalidad debe ser PRESENCIAL, REMOTO o HIBRIDO"
                )
            if modality not in result:
                result.append(modality)
        return result

    @staticmethod
    def _validate_slots(value: Any) -> list[dict[str, Any]]:
        if not isinstance(value, list):
            raise ValidationError("availableSlots debe ser una lista")
        if len(value) > 14:
            raise ValidationError("availableSlots admite hasta 14 bloques")
        result: list[dict[str, Any]] = []
        for slot in value:
            if not isinstance(slot, dict) or set(slot) != {
                "weekday",
                "startTime",
                "endTime",
            }:
                raise ValidationError(
                    "Cada bloque debe tener weekday, startTime y endTime"
                )
            weekday = slot["weekday"]
            if isinstance(weekday, bool) or not isinstance(weekday, int) or not 0 <= weekday <= 6:
                raise ValidationError("weekday debe ser un entero entre 0 (lunes) y 6 (domingo)")
            start_time = slot["startTime"]
            end_time = slot["endTime"]
            if (
                not isinstance(start_time, str)
                or not TIME_PATTERN.fullmatch(start_time)
                or not isinstance(end_time, str)
                or not TIME_PATTERN.fullmatch(end_time)
            ):
                raise ValidationError("startTime y endTime deben usar el formato HH:MM")
            if start_time >= end_time:
                raise ValidationError("startTime debe ser anterior a endTime")
            result.append(
                {"weekday": weekday, "startTime": start_time, "endTime": end_time}
            )
        return result

    @staticmethod
    def _normalize_resource(
        body: dict[str, Any],
        resource_type: str,
        *,
        for_create: bool,
        dates_changed: bool = False,
    ) -> dict[str, Any]:
        title = _text(body.get("title"), "title", 160, required=True)
        description = _text(body.get("description"), "description", 5000, required=True)
        tags = _string_list(body.get("tags"), "tags", 30)
        course_codes = _string_list(body.get("courseCodes"), "courseCodes", 40, 30)

        modality = body.get("modality")
        if modality is not None and (not isinstance(modality, str) or modality not in MODALITIES):
            raise ValidationError("modality debe ser PRESENCIAL, REMOTO o HIBRIDO")
        location = _text(body.get("location"), "location", 255)
        start_at = _parse_datetime(
            body.get("startAt"),
            "startAt",
            required=resource_type in {"TUTORING", "WORKSHOP"},
        )
        end_at = _parse_datetime(
            body.get("endAt"),
            "endAt",
            required=resource_type in {"TUTORING", "WORKSHOP"},
        )
        capacity = body.get("capacity")
        if capacity is not None:
            if isinstance(capacity, bool) or not isinstance(capacity, int) or capacity < 1:
                raise ValidationError("capacity debe ser un entero positivo")
            if capacity > 10000:
                raise ValidationError("capacity no puede superar 10000")
        url = _text(body.get("url"), "url", 2048)
        if url is not None:
            parsed = urlparse(url)
            if parsed.scheme not in {"http", "https"} or not parsed.netloc:
                raise ValidationError("url debe usar HTTP o HTTPS")

        if resource_type in {"TUTORING", "WORKSHOP"}:
            if modality is None:
                raise ValidationError("modality es obligatorio para actividades con horario")
            if modality in {"PRESENCIAL", "HIBRIDO"} and location is None:
                raise ValidationError("location es obligatorio para actividades presenciales")
            if start_at is None or end_at is None or end_at <= start_at:
                raise ValidationError("endAt debe ser posterior a startAt")
            if for_create and start_at.replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc):
                raise ValidationError("startAt debe estar en el futuro")
            if dates_changed and start_at.replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc):
                raise ValidationError("startAt debe estar en el futuro")
        if resource_type == "WORKSHOP" and (capacity is None or capacity < 1):
            raise ValidationError("capacity es obligatorio para publicar un taller")
        if resource_type == "TUTORING" and capacity is not None:
            raise ValidationError("capacity solo se usa para talleres")
        if resource_type == "MATERIAL" and url is None:
            raise ValidationError("url es obligatorio para publicar un material")
        if resource_type == "MATERIAL" and any(
            value is not None for value in (start_at, end_at, capacity)
        ):
            raise ValidationError("Un material no admite horario ni capacity")
        return {
            "resource_type": resource_type,
            "title": title,
            "description": description,
            "tags": tags,
            "course_codes": course_codes,
            "modality": modality,
            "location": location,
            "start_at": start_at,
            "end_at": end_at,
            "capacity": capacity,
            "url": url,
        }

    @staticmethod
    def _preferences_to_response(preferences: dict[str, Any]) -> dict[str, Any]:
        return {
            "interests": preferences["interests"],
            "courseCodes": preferences["course_codes"],
            "availableSlots": preferences["available_slots"],
            "preferredModalities": preferences["preferred_modalities"],
            "timeZone": preferences.get("time_zone", "America/Lima"),
            "updatedAt": _iso_utc(preferences.get("updated_at")), 
        }

    @staticmethod
    def _resource_to_response(record: dict[str, Any]) -> dict[str, Any]:
        start_at = record.get("start_at")
        end_at = record.get("end_at")
        if start_at is not None and start_at.tzinfo is None:
            start_at = start_at.replace(tzinfo=timezone.utc)
        if end_at is not None and end_at.tzinfo is None:
            end_at = end_at.replace(tzinfo=timezone.utc)
        return {
            "id": int(record["id"]),
            "type": record["resource_type"],
            "title": record["title"],
            "description": record["description"],
            "tags": record["tags"],
            "courseCodes": record["course_codes"],
            "modality": record.get("modality"),
            "location": record.get("location"),
            "startAt": _iso_utc(start_at),
            "endAt": _iso_utc(end_at),
            "capacity": record.get("capacity"),
            "availableSeats": record.get("available_seats"),
            "url": record.get("url"),
            "providerUserId": (
                int(record["creator_user_id"])
                if record["resource_type"] == "TUTORING"
                else None
            ),
            "isSynthetic": bool(record.get("is_synthetic", False)),
            "createdAt": _iso_utc(record.get("created_at")),
            "updatedAt": _iso_utc(record.get("updated_at")),
        }
