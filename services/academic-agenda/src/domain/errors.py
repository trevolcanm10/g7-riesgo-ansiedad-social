class ActivityNotFoundError(Exception):
    """La actividad solicitada no existe o no pertenece al usuario."""


class InvalidActivityError(Exception):
    """Los datos de la actividad no son válidos."""


class ModelsUnavailableError(Exception):
    """El predictor de carga semanal no está disponible."""


class PredictionError(Exception):
    """El predictor no pudo producir una probabilidad válida."""
