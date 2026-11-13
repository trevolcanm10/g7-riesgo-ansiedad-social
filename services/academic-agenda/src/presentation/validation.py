from datetime import date


VALID_TYPES = {"tarea", "examen", "proyecto", "lectura", "otro"}
VALID_PRIORITIES = {"baja", "media", "alta"}


def validate_activity_payload(payload: dict, partial: bool = False) -> dict:
    """Valida y devuelve los campos de una actividad academica."""
    if not isinstance(payload, dict):
        raise ValueError("El cuerpo debe ser un objeto JSON")

    cleaned = {}
    if "title" in payload:
        title = str(payload["title"]).strip()
        if not title:
            raise ValueError("El título es obligatorio")
        cleaned["title"] = title
    elif not partial:
        raise ValueError("Falta el campo obligatorio: title")

    if "course" in payload:
        course = str(payload["course"]).strip()
        if not course:
            raise ValueError("El curso es obligatorio")
        cleaned["course"] = course
    elif not partial:
        raise ValueError("Falta el campo obligatorio: course")

    if "activity_type" in payload:
        at = str(payload["activity_type"]).strip().lower()
        if at not in VALID_TYPES:
            raise ValueError(f"activity_type invalido: {at}")
        cleaned["activity_type"] = at
    elif not partial:
        raise ValueError("Falta el campo obligatorio: activity_type")

    if "activity_date" in payload:
        ad = payload["activity_date"]
        if isinstance(ad, str):
            ad = date.fromisoformat(ad)
        if not isinstance(ad, date):
            raise ValueError("activity_date debe ser una fecha")
        cleaned["activity_date"] = ad
    elif not partial:
        raise ValueError("Falta el campo obligatorio: activity_date")

    if "estimated_hours" in payload:
        eh = payload["estimated_hours"]
        if isinstance(eh, bool) or not isinstance(eh, (int, float)):
            raise ValueError("estimated_hours debe ser numerico")
        if eh < 0:
            raise ValueError("estimated_hours no puede ser negativo")
        cleaned["estimated_hours"] = float(eh)
    elif not partial:
        raise ValueError("Falta el campo obligatorio: estimated_hours")

    if "priority" in payload:
        pr = str(payload["priority"]).strip().lower()
        if pr not in VALID_PRIORITIES:
            raise ValueError(f"priority invalida: {pr}")
        cleaned["priority"] = pr
    elif not partial:
        raise ValueError("Falta el campo obligatorio: priority")

    if "description" in payload:
        cleaned["description"] = str(payload["description"]).strip()
    elif not partial:
        cleaned["description"] = ""

    if "completed" in payload:
        cleaned["completed"] = bool(payload["completed"])
    elif not partial:
        cleaned["completed"] = False

    return cleaned


def validate_classify_payload(payload: dict) -> dict:
    """Valida los indicadores para clasificación semanal (10 características)."""
    if not isinstance(payload, dict):
        raise ValueError("El cuerpo debe ser un objeto JSON")

    expected = [
        "horas_totales",
        "num_actividades",
        "num_examenes",
        "num_entregas",
        "num_urgentes_48h",
        "num_prioridad_alta",
        "dias_con_actividades",
        "max_horas_dia",
        "concentracion_3dias",
        "num_sin_duracion",
    ]
    missing = [name for name in expected if name not in payload]
    if missing:
        raise ValueError(
            "Faltan las siguientes características del contrato: "
            + ", ".join(missing)
        )

    indicators = {}
    for name in expected:
        value = payload[name]
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ValueError(f"{name} debe ser numerico")
        indicators[name] = float(value)
    return indicators
