import math

RANGES = {
    "phq9_score": (0, 27), "gad7_score": (0, 21), "sleep_hours": (3, 10),
    "exercise_freq": (0, 7), "social_activity": (0, 10), "online_stress": (1, 10),
    "gpa": (0, 5), "family_support": (1, 10), "screen_time": (1, 12),
    "academic_stress": (1, 10), "diet_quality": (1, 10), "self_efficacy": (1, 10),
    "peer_relationship": (1, 10), "financial_stress": (1, 10), "sleep_quality": (0, 10),
}


def validate_indicators(payload) -> dict:
    if not isinstance(payload, dict):
        raise ValueError("El cuerpo debe ser un objeto JSON")
    indicators = {}
    for name, (minimum, maximum) in RANGES.items():
        if name not in payload:
            raise ValueError(f"Falta la variable obligatoria: {name}")
        value = payload[name]
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ValueError(f"{name} debe ser numérica")
        if not minimum <= value <= maximum or not math.isfinite(value):
            raise ValueError(f"{name} debe estar entre {minimum} y {maximum}")
        indicators[name] = value
    return indicators
