from __future__ import annotations


class DomainError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


class NotFoundError(DomainError):
    def __init__(self, message: str = "No se encontró el recurso"):
        super().__init__(message, 404)


class ConflictError(DomainError):
    def __init__(self, message: str):
        super().__init__(message, 409)


class ForbiddenError(DomainError):
    def __init__(self, message: str = "No tienes permiso para esta operación"):
        super().__init__(message, 403)


class ValidationError(DomainError):
    def __init__(self, message: str, errors: list[dict[str, str]] | None = None):
        super().__init__(message, 400)
        self.errors = errors or []
