"""Middleware de autenticacion y autorizacion por token JWT.

El token lo emite el microservicio ``users``. Este servicio verifica la firma
con el mismo ``JWT_SECRET`` compartido, igual que hace ``riskEvaluation``, y
comprueba el rol antes de permitir la operacion.

Nunca se confia en el rol que envie el cliente: el rol se lee del token
firmado.
"""

from __future__ import annotations

import functools
from typing import Callable, Optional

import jwt
from flask import current_app, g, jsonify, request

# Roles autorizados a operar el panel institucional.
ROLES_AUTORIZADOS = ("PERSONAL_UNAYOE", "ADMINISTRADOR")


class ErrorAutenticacion(Exception):
    """Error de autenticacion o autorizacion con su codigo HTTP."""

    def __init__(self, mensaje: str, codigo: int) -> None:
        super().__init__(mensaje)
        self.mensaje = mensaje
        self.codigo = codigo


def _decodificar_token(token: str) -> dict:
    """Verifica la firma del token y devuelve su carga util.

    Lanza :class:`ErrorAutenticacion` si el token es invalido o ha expirado.
    """
    secreto = current_app.config.get("JWT_SECRET")
    if not secreto:
        # Fallo cerrado: sin secreto no se valida ninguna peticion.
        raise ErrorAutenticacion("El servicio no esta configurado para validar tokens.", 500)

    try:
        payload = jwt.decode(
            token,
            secreto,
            algorithms=["HS256"],
            options={"require": ["userId", "role"]},
        )
    except jwt.ExpiredSignatureError:
        raise ErrorAutenticacion("El token ha expirado. Inicie sesion nuevamente.", 401)
    except jwt.InvalidTokenError:
        raise ErrorAutenticacion("El token no es valido.", 401)

    if not isinstance(payload.get("userId"), int) or payload["userId"] <= 0:
        raise ErrorAutenticacion("El token no es valido.", 401)

    return payload


def _token_de_peticion() -> str:
    """Extrae el token Bearer de la cabecera Authorization."""
    cabecera = request.headers.get("Authorization")
    if not cabecera:
        raise ErrorAutenticacion("Se requiere un token de autenticacion.", 401)

    partes = cabecera.split(" ")
    if len(partes) != 2 or partes[0] != "Bearer" or not partes[1]:
        raise ErrorAutenticacion("El formato del token no es valido.", 401)

    return partes[1]


def requiere_autorizacion(funcion: Callable) -> Callable:
    """Exige un token valido y un rol autorizado en el panel."""

    @functools.wraps(funcion)
    def envoltorio(*args, **kwargs):
        try:
            token = _token_de_peticion()
            payload = _decodificar_token(token)

            rol = payload.get("role")
            if rol not in ROLES_AUTORIZADOS:
                raise ErrorAutenticacion(
                    "Su rol no tiene permiso para usar el panel institucional.", 403
                )

            g.token = token
            g.user_id = payload["userId"]
            g.user_rol = rol

            return funcion(*args, **kwargs)
        except ErrorAutenticacion as error:
            return jsonify({"error": error.mensaje}), error.codigo

    return envoltorio


def token_actual() -> Optional[str]:
    """Devuelve el token de la peticion en curso, si lo hay."""
    return getattr(g, "token", None)
