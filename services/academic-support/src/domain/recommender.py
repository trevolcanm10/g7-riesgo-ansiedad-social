from __future__ import annotations

import math
import unicodedata
from collections import defaultdict
from typing import Any
from zoneinfo import ZoneInfo

from .entities import Recommendation, Resource


EVENT_WEIGHTS = {
    "VIEW": 1.0,
    "CLICK": 2.0,
    "ENROLL": 4.0,
    "COMPLETE": 3.0,
    "DISMISS": 0.0,
    "WITHDRAW": 0.0,
}


def _normalize(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value.casefold().strip())
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch))


def _normalized_set(values: Any) -> set[str]:
    if not isinstance(values, (list, tuple)):
        return set()
    return {_normalize(str(value)) for value in values if str(value).strip()}


def _minute_of_day(value: str) -> int:
    hour_text, minute_text = value.split(":", 1)
    hour, minute = int(hour_text), int(minute_text)
    if hour < 0 or hour > 23 or minute < 0 or minute > 59:
        raise ValueError("Hora inválida")
    return hour * 60 + minute


def _resource_time_matches(
    resource: Resource, slots: list[dict[str, Any]], time_zone: str
) -> bool:
    if resource.start_at is None or not slots:
        return False
    from datetime import timezone

    start = resource.start_at
    if start.tzinfo is None:
        start = start.replace(tzinfo=timezone.utc)
    start = start.astimezone(ZoneInfo(time_zone))
    weekday = start.weekday()
    start_minute = start.hour * 60 + start.minute
    end = resource.end_at or resource.start_at
    if end.tzinfo is None:
        end = end.replace(tzinfo=timezone.utc)
    end = end.astimezone(ZoneInfo(time_zone))
    end_minute = end.hour * 60 + end.minute
    for slot in slots:
        try:
            if int(slot["weekday"]) != weekday:
                continue
            slot_start = _minute_of_day(str(slot["startTime"]))
            slot_end = _minute_of_day(str(slot["endTime"]))
        except (KeyError, TypeError, ValueError):
            continue
        if start_minute < slot_end and end_minute > slot_start:
            return True
    return False


class HybridRecommendationEngine:
    """Explainable content ranking with item-based collaborative filtering."""

    def recommend(
        self,
        resources: list[Resource],
        preferences: dict[str, Any],
        interactions: list[dict[str, Any]],
        user_id: int,
        limit: int = 10,
    ) -> list[Recommendation]:
        if not resources:
            return []

        interests = _normalized_set(preferences.get("interests"))
        course_codes = _normalized_set(preferences.get("course_codes"))
        modalities = _normalized_set(preferences.get("preferred_modalities"))
        available_slots = preferences.get("available_slots") or []
        has_profile = bool(interests or course_codes or modalities or available_slots)

        user_history: dict[int, float] = defaultdict(float)
        latest_user_event: dict[int, str] = {}
        resource_users: dict[int, dict[int, float]] = defaultdict(
            lambda: defaultdict(float)
        )
        popularity: dict[int, float] = defaultdict(float)
        for event in interactions:
            event_type = str(event.get("event_type", "")).upper()
            try:
                event_resource = int(event["resource_id"])
                event_user = int(event["user_id"])
            except (KeyError, TypeError, ValueError):
                continue
            if event_user == user_id and event_resource not in latest_user_event:
                latest_user_event[event_resource] = event_type
            weight = EVENT_WEIGHTS.get(event_type, 0.0)
            if weight <= 0:
                continue
            resource_users[event_resource][event_user] += weight
            popularity[event_resource] += weight
            if event_user == user_id:
                user_history[event_resource] += weight

        max_popularity = max(popularity.values(), default=0.0)
        popularity_scores = {
            resource.id: (
                popularity.get(resource.id, 0.0) / max_popularity
                if max_popularity > 0
                else 0.0
            )
            for resource in resources
        }
        collaborative_scores = self._collaborative_scores(
            resources, user_history, resource_users
        )
        max_collaborative = max(collaborative_scores.values(), default=0.0)
        has_collaborative_signal = max_collaborative > 0.0
        if has_collaborative_signal:
            collaborative_scores = {
                resource_id: score / max_collaborative
                for resource_id, score in collaborative_scores.items()
            }

        ranked: list[Recommendation] = []
        for resource in resources:
            if latest_user_event.get(resource.id) in {"DISMISS", "WITHDRAW"}:
                continue
            content_score, matched = self._content_score(
                resource,
                interests,
                course_codes,
                modalities,
                available_slots,
                str(preferences.get("time_zone", "America/Lima")),
            )
            if has_profile:
                base_score = 0.9 * content_score + 0.1 * popularity_scores[resource.id]
            else:
                base_score = popularity_scores[resource.id]

            if has_collaborative_signal:
                score = 0.75 * base_score + 0.25 * collaborative_scores.get(
                    resource.id, 0.0
                )
                mode = "HYBRID"
            else:
                score = base_score
                mode = "CONTENT_BASED" if has_profile else "POPULARITY_FALLBACK"

            reasons = list(matched)
            if has_collaborative_signal and collaborative_scores.get(resource.id, 0.0) > 0:
                reasons.append(
                    "Estudiantes con interacciones similares también la eligieron"
                )
            if not has_profile and not has_collaborative_signal:
                if max_popularity > 0 and popularity.get(resource.id, 0.0) > 0:
                    reasons.append("Sugerencia inicial priorizada por actividad del catálogo")
                else:
                    reasons.append("Sugerencia inicial del catálogo; aún faltan interacciones para ordenar por popularidad")
            if not reasons:
                reasons.append(
                    "Opción disponible; completa tus preferencias para personalizar"
                )

            ranked.append(
                Recommendation(
                    resource=resource,
                    score=score,
                    recommendation_mode=mode,
                    reasons=tuple(reasons),
                )
            )

        ranked.sort(
            key=lambda item: (item.score, item.resource.id),
            reverse=True,
        )
        return ranked[: max(1, min(limit, 50))]

    @staticmethod
    def _content_score(
        resource: Resource,
        interests: set[str],
        course_codes: set[str],
        modalities: set[str],
        available_slots: list[dict[str, Any]],
        time_zone: str,
    ) -> tuple[float, tuple[str, ...]]:
        weights: list[tuple[float, float]] = []
        reasons: list[str] = []

        resource_tags = {_normalize(value) for value in resource.tags}
        resource_courses = {_normalize(value) for value in resource.course_codes}

        if interests:
            overlap = interests.intersection(resource_tags)
            weights.append((0.45, len(overlap) / len(interests)))
            if overlap:
                reasons.append("Coincide con tus intereses: " + ", ".join(sorted(overlap)))
        if course_codes:
            overlap = course_codes.intersection(resource_courses)
            weights.append((0.35, len(overlap) / len(course_codes)))
            if overlap:
                reasons.append("Relacionado con tus cursos: " + ", ".join(sorted(overlap)))
        if available_slots:
            matched_time = _resource_time_matches(resource, available_slots, time_zone)
            weights.append((0.15, 1.0 if matched_time else 0.0))
            if matched_time:
                reasons.append("El horario coincide con tu disponibilidad")
        if modalities:
            modality_match = (
                1.0
                if resource.modality and _normalize(resource.modality) in modalities
                else 0.0
            )
            weights.append((0.05, modality_match))
            if modality_match:
                reasons.append("Coincide con tu modalidad preferida")

        if not weights:
            return 0.0, tuple(reasons)
        total_weight = sum(weight for weight, _ in weights)
        score = sum(weight * value for weight, value in weights) / total_weight
        return score, tuple(reasons)

    @staticmethod
    def _collaborative_scores(
        resources: list[Resource],
        user_history: dict[int, float],
        resource_users: dict[int, dict[int, float]],
    ) -> dict[int, float]:
        if not user_history:
            return {}

        history_ids = set(user_history)
        scores: dict[int, float] = {}
        norms = {
            resource_id: math.sqrt(sum(value * value for value in users.values()))
            for resource_id, users in resource_users.items()
        }
        for candidate in resources:
            candidate_users = resource_users.get(candidate.id, {})
            candidate_norm = norms.get(candidate.id, 0.0)
            if candidate_norm == 0:
                continue
            total = 0.0
            for history_id in history_ids:
                if history_id == candidate.id:
                    continue
                history_users = resource_users.get(history_id, {})
                history_norm = norms.get(history_id, 0.0)
                if history_norm == 0:
                    continue
                common_users = candidate_users.keys() & history_users.keys()
                dot = sum(
                    candidate_users[user] * history_users[user]
                    for user in common_users
                )
                similarity = dot / (candidate_norm * history_norm)
                total += similarity * user_history[history_id]
            if total > 0:
                scores[candidate.id] = total
        return scores
