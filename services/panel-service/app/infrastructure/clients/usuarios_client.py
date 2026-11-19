"""Adaptador HTTP para resolver estudiantes contra el microservicio ``users``.

Regla de aislamiento de datos: no se lee la base de datos de ``users``. Se
consulta por HTTP usando el token de la persona que esta operando el panel.
"""

from __future__ import annotations

import json
import logging
import urllib.error
import urllib.parse
import urllib.request
from typing import Optional

from app.application.interfaces.usuarios_port import IUsuariosPort

logger = logging.getLogger(__name__)

# Segundos de espera maxima antes de abandonar la consulta externa.
TIMEOUT_SEGUNDOS = 5


class UsuariosClient(IUsuariosPort):
    """Resuelve el codigo de un estudiante contra el servicio ``users``."""

    def __init__(self, url_base: Optional[str] = None, timeout: int = TIMEOUT_SEGUNDOS) -> None:
        self._url_base = (url_base or "").rstrip("/")
        self._timeout = timeout

    def resolver_id(self, codigo: str, token: str) -> Optional[int]:
        """Devuelve el identificador del estudiante, o ``None``.

        El servicio de usuarios expone ``GET /users/by-code/:code``. Si no
        esta disponible todavia, o el servicio no responde, se devuelve
        ``None`` y la atencion se registra sin correlacion de riesgo.
        """
        if not self._url_base or not token or not codigo:
            return None

        # safe="" escapa tambien la barra: un codigo con "/" no debe alterar
        # el enrutado de la ruta.
        url = f"{self._url_base}/users/by-code/{urllib.parse.quote(codigo, safe='')}"
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
            logger.warning("No se pudo resolver el estudiante %s: %s", codigo, error)
            return None
        except Exception as error:  # pragma: no cover - fallo de entorno
            logger.warning("Fallo inesperado al resolver el estudiante: %s", error)
            return None

        try:
            datos = json.loads(cuerpo)
        except ValueError:
            return None

        if not isinstance(datos, dict):
            return None

        identificador = datos.get("id")
        if isinstance(identificador, int) and identificador > 0:
            return identificador

        return None
