"""Offline evaluation with reproducible synthetic interactions only."""

from __future__ import annotations

import argparse
import json
import random
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


SERVICE_DIR = Path(__file__).resolve().parents[1]
if str(SERVICE_DIR) not in sys.path:
    sys.path.insert(0, str(SERVICE_DIR))

from src.domain.entities import Resource  # noqa: E402
from src.domain.recommender import EVENT_WEIGHTS, HybridRecommendationEngine  # noqa: E402


SEED = 20261112
TOP_K = 5
TOPICS = (
    ("matemáticas", "MAT101"),
    ("programación", "INF101"),
    ("técnicas de estudio", "GEN101"),
)
USERS_PER_TOPIC = 30
RESOURCES_PER_TOPIC = 10
TRAIN_ITEMS_PER_USER = 4


def build_dataset(seed: int) -> tuple[list[Resource], list[dict[str, Any]], list[dict[str, Any]]]:
    rng = random.Random(seed)
    resources: list[Resource] = []
    topic_resource_ids: dict[str, list[int]] = defaultdict(list)
    next_resource_id = 1

    for topic, course_code in TOPICS:
        for resource_number in range(RESOURCES_PER_TOPIC):
            record = {
                "id": next_resource_id,
                "resource_type": "WORKSHOP" if resource_number % 2 == 0 else "MATERIAL",
                "title": f"Actividad sintética {topic} {resource_number + 1}",
                "description": "Recurso generado únicamente para evaluar el ranking.",
                "tags": [topic],
                "course_codes": [course_code],
                "modality": "REMOTO",
                "location": None,
                "start_at": None,
                "end_at": None,
                "capacity": None,
                "available_seats": None,
                "url": f"https://example.org/synthetic/{next_resource_id}",
                "creator_user_id": 9000,
                "status": "PUBLISHED",
                "is_synthetic": True,
            }
            resources.append(Resource.from_record(record))
            topic_resource_ids[topic].append(next_resource_id)
            next_resource_id += 1

    users: list[dict[str, Any]] = []
    interactions: list[dict[str, Any]] = []
    event_types = ("VIEW", "CLICK", "CLICK", "COMPLETE")
    user_id = 10000
    for topic, course_code in TOPICS:
        ids = topic_resource_ids[topic]
        for _ in range(USERS_PER_TOPIC):
            train_ids = set(rng.sample(ids, TRAIN_ITEMS_PER_USER))
            held_out_id = rng.choice([resource_id for resource_id in ids if resource_id not in train_ids])
            users.append(
                {
                    "user_id": user_id,
                    "preferences": {
                        "interests": [topic],
                        "course_codes": [course_code],
                        "preferred_modalities": ["REMOTO"],
                        "available_slots": [],
                        "time_zone": "America/Lima",
                    },
                    "train_resource_ids": train_ids,
                    "held_out_resource_id": held_out_id,
                }
            )
            for resource_id in train_ids:
                interactions.append(
                    {
                        "user_id": user_id,
                        "resource_id": resource_id,
                        "event_type": rng.choice(event_types),
                    }
                )
            user_id += 1

    return resources, users, interactions


def _top_ids(
    resources: list[Resource],
    interactions: list[dict[str, Any]],
    user: dict[str, Any],
    engine: HybridRecommendationEngine,
    recommender: str,
) -> list[int]:
    seen_ids = user["train_resource_ids"]
    candidates = [resource for resource in resources if resource.id not in seen_ids]

    if recommender == "POPULARITY":
        popularity: dict[int, float] = defaultdict(float)
        for event in interactions:
            popularity[int(event["resource_id"])] += EVENT_WEIGHTS.get(
                str(event["event_type"]).upper(), 0.0
            )
        ranked = sorted(
            candidates,
            key=lambda resource: (popularity[resource.id], resource.id),
            reverse=True,
        )
        return [resource.id for resource in ranked[:TOP_K]]

    user_interactions = interactions if recommender == "HYBRID" else []
    recommendations = engine.recommend(
        candidates,
        user["preferences"],
        user_interactions,
        user_id=user["user_id"],
        limit=TOP_K,
    )
    return [item.resource.id for item in recommendations]


def _metrics(
    recommendations: dict[int, list[int]],
    users: list[dict[str, Any]],
    catalog_size: int,
) -> dict[str, float | int]:
    hits = sum(
        user["held_out_resource_id"] in recommendations[user["user_id"]]
        for user in users
    )
    recommended_ids = {
        resource_id
        for user_recommendations in recommendations.values()
        for resource_id in user_recommendations
    }
    total_slots = len(users) * TOP_K
    return {
        "precision_at_5": round(hits / total_slots, 4),
        "hit_rate_at_5": round(hits / len(users), 4),
        "coverage": round(len(recommended_ids) / catalog_size, 4),
        "hits": hits,
        "users": len(users),
        "unique_recommended_resources": len(recommended_ids),
    }


def evaluate(seed: int = SEED) -> dict[str, Any]:
    resources, users, interactions = build_dataset(seed)
    engine = HybridRecommendationEngine()
    results: dict[str, dict[str, float | int]] = {}

    for recommender in ("POPULARITY", "CONTENT_BASED", "HYBRID"):
        lists = {
            user["user_id"]: _top_ids(
                resources, interactions, user, engine, recommender
            )
            for user in users
        }
        results[recommender] = _metrics(lists, users, len(resources))

    return {
        "synthetic_data": True,
        "seed": seed,
        "protocol": {
            "users": len(users),
            "catalog_resources": len(resources),
            "training_interactions": len(interactions),
            "relevant_items_per_user": 1,
            "train_items_per_user": TRAIN_ITEMS_PER_USER,
            "k": TOP_K,
            "candidate_policy": "Exclude the user's training interactions before ranking.",
            "note": "Constructed data only; metrics do not estimate real student outcomes.",
        },
        "metrics": results,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).with_name("evaluation_results.json"),
        help="JSON output path (default: ml/evaluation_results.json)",
    )
    args = parser.parse_args()
    results = evaluate(args.seed)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(results, ensure_ascii=False, indent=2))
    print(f"\nResultados guardados en: {args.output}")


if __name__ == "__main__":
    main()
