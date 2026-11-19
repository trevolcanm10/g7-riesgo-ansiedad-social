"""Pruebas del cliente HTTP que resuelve el identificador de un estudiante.

Permite correlacionar las atenciones con las evaluaciones de riesgo sin
compartir bases de datos. Igual que el resto de adaptadores, degrada sin
propagar errores: registrar una atencion nunca debe depender de que otro
microservicio responda.
"""

from __future__ import annotations

import json
import urllib.error
from unittest import mock

from app.infrastructure.clients.usuarios_client import UsuariosClient


class RespuestaFalsa:
    """Doble de la respuesta HTTP de ``urllib.request.urlopen``."""

    def __init__(self, cuerpo: str, estado: int = 200) -> None:
        self._cuerpo = cuerpo.encode("utf-8")
        self.status = estado

    def read(self) -> bytes:
        return self._cuerpo

    def __enter__(self) -> "RespuestaFalsa":
        return self

    def __exit__(self, *_args) -> bool:
        return False


class TestDegradacion:
    """Sin identificador resuelto, la atencion se registra igual."""

    def test_sin_url_base_devuelve_none(self):
        """Sin URL configurada no se intenta consultar nada."""
        cliente = UsuariosClient("")
        assert cliente.resolver_id("20260001", "token") is None

    def test_sin_token_devuelve_none(self):
        """Sin token no hay nada que consultar."""
        cliente = UsuariosClient("http://usuarios:3001")
        assert cliente.resolver_id("20260001", "") is None

    def test_sin_codigo_devuelve_none(self):
        """Sin codigo no hay nada que resolver."""
        cliente = UsuariosClient("http://usuarios:3001")
        assert cliente.resolver_id("", "token") is None

    def test_error_http_devuelve_none(self):
        """Un 404 (estudiante inexistente) no es un fallo del panel."""
        error = urllib.error.HTTPError(
            "http://usuarios:3001/users/by-code/20260001", 404, "No encontrado", None, None
        )
        cliente = UsuariosClient("http://usuarios:3001")

        with mock.patch("urllib.request.urlopen", side_effect=error):
            assert cliente.resolver_id("20260001", "token") is None

    def test_servicio_inalcanzable_devuelve_none(self):
        """Si ``users`` esta caido, no se puede resolver el estudiante."""
        error = urllib.error.URLError("no se pudo conectar")
        cliente = UsuariosClient("http://usuarios:3001")

        with mock.patch("urllib.request.urlopen", side_effect=error):
            assert cliente.resolver_id("20260001", "token") is None

    def test_respuesta_sin_id_devuelve_none(self):
        """Una respuesta sin identificador no sirve."""
        cliente = UsuariosClient("http://usuarios:3001")
        respuesta = RespuestaFalsa(json.dumps({"code": "20260001"}))

        with mock.patch("urllib.request.urlopen", return_value=respuesta):
            assert cliente.resolver_id("20260001", "token") is None

    def test_id_invalido_devuelve_none(self):
        """Un identificador no positivo se descarta."""
        cliente = UsuariosClient("http://usuarios:3001")
        respuesta = RespuestaFalsa(json.dumps({"id": 0, "code": "20260001"}))

        with mock.patch("urllib.request.urlopen", return_value=respuesta):
            assert cliente.resolver_id("20260001", "token") is None


class TestExito:
    """Cuando ``users`` responde, se obtiene el identificador."""

    def test_resuelve_el_identificador(self):
        """Devuelve el identificador numerico del estudiante."""
        cliente = UsuariosClient("http://usuarios:3001")
        respuesta = RespuestaFalsa(json.dumps({"id": 42, "code": "20260001"}))

        with mock.patch("urllib.request.urlopen", return_value=respuesta) as llamada:
            assert cliente.resolver_id("20260001", "token") == 42

        peticion = llamada.call_args.args[0]
        assert peticion.full_url == "http://usuarios:3001/users/by-code/20260001"
        assert peticion.get_header("Authorization") == "Bearer token"

    def test_escapa_el_codigo_en_la_url(self):
        """Un codigo con caracteres especiales se escapa correctamente."""
        cliente = UsuariosClient("http://usuarios:3001")
        respuesta = RespuestaFalsa(json.dumps({"id": 42, "code": "2026/001"}))

        with mock.patch("urllib.request.urlopen", return_value=respuesta) as llamada:
            cliente.resolver_id("2026/001", "token")

        assert "2026%2F001" in llamada.call_args.args[0].full_url
