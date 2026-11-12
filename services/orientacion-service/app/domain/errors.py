class DomainError(Exception):
    """Base para errores de negocio del dominio Orientación."""


class ValidationError(DomainError):
    """Error de validación de reglas de negocio o parámetros."""


class NotFoundError(DomainError):
    """El recurso solicitado no existe o no es visible para el actor."""


class ForbiddenError(DomainError):
    """El actor no tiene permiso para realizar esta acción."""


class ConflictError(DomainError):
    """Conflicto de estado (p. ej., solicitud ya atendida)."""
