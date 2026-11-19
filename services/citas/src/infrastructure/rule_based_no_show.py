from src.domain.ports import NoShowPredictor


class RuleBasedNoShowPredictor(NoShowPredictor):
    """Línea base v0 (reglas). Se reemplazará por un modelo entrenado (ver README).

    No usa la prioridad ni ningún dato clínico: solo comportamiento de agenda.
    """
    MODEL = "rule-based-baseline-v0"

    def predict(self, features):
        p = 0.10
        factors = []
        lead = features["lead_days"]
        if lead > 7:
            p += min((lead - 7) * 0.02, 0.15)
            factors.append("Cita agendada con mucha anticipación")
        if features["prior_no_shows"]:
            p += 0.20 * min(features["prior_no_shows"], 3)
            factors.append("Inasistencias previas")
        if features["prior_cancellations"]:
            p += 0.05 * min(features["prior_cancellations"], 4)
            factors.append("Cancelaciones previas")
        if features["reschedule_count"]:
            p += 0.05 * min(features["reschedule_count"], 3)
            factors.append("Cita reprogramada")
        hour = features["hour_local"]
        if hour < 9 or hour >= 17:
            p += 0.05
            factors.append("Horario temprano o tarde")
        return {"probability": round(min(max(p, 0.02), 0.85), 3),
                "factors": factors, "model": self.MODEL}
