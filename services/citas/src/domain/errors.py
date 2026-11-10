"""Errores de dominio. La capa HTTP los traduce a códigos de estado."""


class DomainError(Exception):
    """Base de los errores esperados del negocio."""


class ValidationError(DomainError):      # 400
    pass


class ForbiddenError(DomainError):       # 403
    pass


class NotFoundError(DomainError):        # 404
    pass


class ConflictError(DomainError):        # 409
    pass
