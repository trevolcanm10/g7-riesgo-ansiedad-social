from .solicitud import UrgenciaAnalisis

class UrgenciaDomainService:
    CRITICAL_PHRASES = [
        "no me siento seguro",
        "mi seguridad está en riesgo",
        "necesito ayuda ahora",
        "situación crítica",
        "no tengo un lugar seguro",
        "temo por mi seguridad",
        "necesito atención inmediata"
    ]

    HELP_LINES = [
        "UNAYOE FISI: 999-999-999 (Horario de oficina)",
        "Línea 113 MINSA: Salud Mental, atención 24 horas",
        "SAMU: 106",
        "Policía Nacional: 105"
    ]

    @classmethod
    def detectar(cls, texto: str) -> UrgenciaAnalisis:
        texto_lower = texto.lower()
        coincidencias = [frase for frase in cls.CRITICAL_PHRASES if frase in texto_lower]
        es_urgente = len(coincidencias) > 0

        return UrgenciaAnalisis(
            es_urgente=es_urgente,
            coincidencias=coincidencias,
            lineas_ayuda=cls.HELP_LINES if es_urgente else []
        )
