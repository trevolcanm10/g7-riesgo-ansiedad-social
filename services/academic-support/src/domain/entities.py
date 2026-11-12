from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any


RESOURCE_TYPES = {"TUTORING", "WORKSHOP", "MATERIAL"}
RESOURCE_STATUSES = {"PUBLISHED", "CANCELLED"}
MODALITIES = {"PRESENCIAL", "REMOTO", "HIBRIDO"}
ROLES = {"ESTUDIANTE", "PERSONAL_UNAYOE", "ADMINISTRADOR"}
INTERACTION_TYPES = {"VIEW", "CLICK", "COMPLETE", "DISMISS"}


@dataclass(frozen=True)
class Resource:
    id: int
    resource_type: str
    title: str
    description: str
    tags: tuple[str, ...]
    course_codes: tuple[str, ...]
    modality: str | None
    location: str | None
    start_at: datetime | None
    end_at: datetime | None
    capacity: int | None
    available_seats: int | None
    url: str | None
    creator_user_id: int
    status: str
    is_synthetic: bool
    created_at: datetime | None
    updated_at: datetime | None

    @classmethod
    def from_record(cls, record: dict[str, Any]) -> "Resource":
        return cls(
            id=int(record["id"]),
            resource_type=str(record["resource_type"]),
            title=str(record["title"]),
            description=str(record["description"]),
            tags=tuple(record.get("tags") or ()),
            course_codes=tuple(record.get("course_codes") or ()),
            modality=record.get("modality"),
            location=record.get("location"),
            start_at=record.get("start_at"),
            end_at=record.get("end_at"),
            capacity=record.get("capacity"),
            available_seats=record.get("available_seats"),
            url=record.get("url"),
            creator_user_id=int(record["creator_user_id"]),
            status=str(record["status"]),
            is_synthetic=bool(record.get("is_synthetic", False)),
            created_at=record.get("created_at"),
            updated_at=record.get("updated_at"),
        )


@dataclass(frozen=True)
class UserContext:
    user_id: int
    role: str


@dataclass(frozen=True)
class Recommendation:
    resource: Resource
    score: float
    recommendation_mode: str
    reasons: tuple[str, ...]

    def to_dict(self) -> dict[str, Any]:
        resource = self.resource
        return {
            "resource": {
                "id": resource.id,
                "type": resource.resource_type,
                "title": resource.title,
                "description": resource.description,
                "tags": list(resource.tags),
                "courseCodes": list(resource.course_codes),
                "modality": resource.modality,
                "location": resource.location,
                "startAt": _iso_utc(resource.start_at),
                "endAt": _iso_utc(resource.end_at),
                "capacity": resource.capacity,
                "availableSeats": resource.available_seats,
                "url": resource.url,
                "providerUserId": (
                    resource.creator_user_id
                    if resource.resource_type == "TUTORING"
                    else None
                ),
                "isSynthetic": resource.is_synthetic,
                "createdAt": _iso_utc(resource.created_at),
                "updatedAt": _iso_utc(resource.updated_at),
            },
            "score": round(max(0.0, min(1.0, self.score)), 4),
            "recommendationMode": self.recommendation_mode,
            "reasons": list(self.reasons),
        }


def _iso_utc(value: datetime | None) -> str | None:
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
