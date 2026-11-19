"""Adaptador HTTP para consultar al microservicio de usuarios.

Regla de aislamiento de datos: este servicio no lee la base de datos de
``users``. La identidad del personal se resuelve por HTTP reenviando su
token, tal como lo hace el resto de la plataforma.
"""

from __future__ import annotations

import logging
import urllib.error
import urllib.request
from typing import Optional

from app.application.interfaces.personal_externo_port import IPersonalExternoPort

logger = logging.getLogger(__name__)

# Segundos de espera maxima antes de abandonar la consulta externa.
TIMEOUT_SEGUNDOS = 5


class PersonalExternoClient(IPersonalExternoPort):
    """Resuelve la identidad del personal contra el microservicio ``users``."""

    def __init__(self, url_base: Optional[str] = None, timeout: int = TIMEOUT_SEGUNDOS) -> None:
        self._url_base = (url_base or "").rstrip("/")
        self._timeout = timeout

    def resolver_identidad(self, token: str) -> Optional[str]:
        """Resuelve el nombre del personal a partir de su token.

        Devuelve ``None`` si el servicio no responde o el token no es
        valido. El registro de una atencion no debe fallar por un problema
        de un servicio externo.
        """
        if not self._url_base or not token:
            return None

        url = f"{self._url_base}/users/me"
        peticion = urllib.request.Request(url, method="GET")
        peticion.add_header("Authorization", f"Bearer {token}")
        peticion.add_header("Accept", "application/json")

        try:
            with urllib.request.urlopen(peticion, timeout=self._timeout) as respuesta:
                if respuesta.status != 200:
                    return None
                cuerpo = respuesta.read().decode("utf-8")
        except urllib.error.HTTPError:
            return None
        except urllib.error.URLError as error:
            logger.warning("No se pudo resolver la identidad del personal: %s", error)
            return None
        except Exception as error:  # pragma: no cover - fallo de entorno
            logger.warning("Fallo inesperado al resolver la identidad: %s", error)
            return None

        return self._extraer_nombre(cuerpo)

    @staticmethod
    def _extraer_nombre(cuerpo: str) -> Optional[str]:
        """Extrae el nombre del personal de la respuesta de ``users``."""
        import json

        try:
            datos = json.loads(cuerpo)
        except ValueError:
            return None

        if not isinstance(datos, dict):
            return None

        nombres = datos.get("names")
        apellidos = datos.get("surnames")

        if not nombres:
            return None

        if apellidos:
            return f"{nombres} {apellidos}".strip()

        return str(nombres).strip()
