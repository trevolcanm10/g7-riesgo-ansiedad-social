"""Pruebas del cliente HTTP que resuelve la identidad del personal.

Regla de aislamiento de datos: este servicio no lee la base de datos de
``users``; la identidad se resuelve por HTTP reenviando el token.

La garantia critica es la DEGRADACION: si el servicio de usuarios no
responde, el registro de una atencion no debe fallar. Estas pruebas la
verifican sin tocar la red, sustituyendo ``urllib.request.urlopen``.
"""

from __future__ import annotations

import io
import json
import urllib.error
from unittest import mock

import pytest

from app.infrastructure.clients.personal_externo_client import PersonalExternoClient


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


def _cuerpo(datos: dict) -> str:
    """Serializa un diccionario como respuesta JSON."""
    return json.dumps(datos)


class TestDegradacion:
    """El registro nunca debe depender de la disponibilidad de ``users``."""

    def test_sin_url_base_devuelve_none(self):
        """Sin URL configurada no se intenta consultar nada."""
        cliente = PersonalExternoClient("")
        assert cliente.resolver_identidad("token") is None

    def test_sin_token_devuelve_none(self):
        """Sin token no hay nada que consultar."""
        cliente = PersonalExternoClient("http://usuarios:3001")
        assert cliente.resolver_identidad("") is None

    def test_token_ilegable_devuelve_none(self):
        """Un token vacio o solo espacios no se procesa."""
        cliente = PersonalExternoClient("http://usuarios:3001")
        assert cliente.resolver_identidad("   ") is None

    def test_error_http_devuelve_none(self):
        """Un 401 o 403 del servicio de usuarios degrada sin propagar."""
        error = urllib.error.HTTPError(
            "http://usuarios:3001/users/me", 401, "No autorizado", None, None
        )
        cliente = PersonalExternoClient("http://usuarios:3001")

        with mock.patch(
            "urllib.request.urlopen", side_effect=error
        ):
            assert cliente.resolver_identidad("token") is None

    def test_servicio_inalcanzable_devuelve_none(self):
        """Si ``users`` esta caido, la atencion se registra igual."""
        error = urllib.error.URLError("no se pudo conectar")
        cliente = PersonalExternoClient("http://usuarios:3001")

        with mock.patch(
            "urllib.request.urlopen", side_effect=error
        ):
            assert cliente.resolver_identidad("token") is None

    def test_respuesta_no_200_devuelve_none(self):
        """Cualquier estado distinto de 200 se considera fallido."""
        cliente = PersonalExternoClient("http://usuarios:3001")
        respuesta = RespuestaFalsa("{}", estado=500)

        with mock.patch("urllib.request.urlopen", return_value=respuesta):
            assert cliente.resolver_identidad("token") is None


class TestExito:
    """Cuando ``users`` responde, se extrae el nombre del personal."""

    def test_extrae_nombre_completo(self):
        """Con nombres y apellidos, devuelve el nombre completo."""
        cliente = PersonalExternoClient("http://usuarios:3001")
        respuesta = RespuestaFalsa(_cuerpo({"names": "Ana", "surnames": "Perez"}))

        with mock.patch("urllib.request.urlopen", return_value=respuesta) as llamada:
            assert cliente.resolver_identidad("token") == "Ana Perez"

        peticion = llamada.call_args.args[0]
        assert peticion.full_url == "http://usuarios:3001/users/me"
        assert peticion.get_header("Authorization") == "Bearer token"

    def test_extrae_solo_nombres(self):
        """Sin apellidos, devuelve solo el nombre."""
        cliente = PersonalExternoClient("http://usuarios:3001")
        respuesta = RespuestaFalsa(_cuerpo({"names": "Ana"}))

        with mock.patch("urllib.request.urlopen", return_value=respuesta):
            assert cliente.resolver_identidad("token") == "Ana"

    def test_ignora_barra_final_en_la_url(self):
        """Una URL con barra final no produce una ruta con doble barra."""
        cliente = PersonalExternoClient("http://usuarios:3001/")
        respuesta = RespuestaFalsa(_cuerpo({"names": "Ana", "surnames": "Perez"}))

        with mock.patch("urllib.request.urlopen", return_value=respuesta) as llamada:
            cliente.resolver_identidad("token")

        assert llamada.call_args.args[0].full_url == "http://usuarios:3001/users/me"

    def test_json_invalido_devuelve_none(self):
        """Una respuesta que no es JSON no rompe el registro."""
        cliente = PersonalExternoClient("http://usuarios:3001")
        respuesta = RespuestaFalsa("esto no es json")

        with mock.patch("urllib.request.urlopen", return_value=respuesta):
            assert cliente.resolver_identidad("token") is None

    def test_json_que_no_es_objeto_devuelve_none(self):
        """Una lista JSON no aporta identidad."""
        cliente = PersonalExternoClient("http://usuarios:3001")
        respuesta = RespuestaFalsa(_cuerpo([1, 2, 3]))

        with mock.patch("urllib.request.urlopen", return_value=respuesta):
            assert cliente.resolver_identidad("token") is None

    def test_sin_nombres_devuelve_none(self):
        """Una respuesta sin ``names`` no permite identificar a nadie."""
        cliente = PersonalExternoClient("http://usuarios:3001")
        respuesta = RespuestaFalsa(_cuerpo({"surnames": "Perez", "role": "ADMINISTRADOR"}))

        with mock.patch("urllib.request.urlopen", return_value=respuesta):
            assert cliente.resolver_identidad("token") is None


class TestIntegracionConElCasoDeUso:
    """El caso de uso registra la atencion aunque la identidad no se resuelva."""

    def test_registro_no_falla_sin_servicio_de_usuarios(self):
        """``users`` caido no impide registrar una atencion."""
        from app.application.use_cases.registrar_atencion import RegistrarAtencion

        class RepositorioFalso:
            def guardar(self, atencion):
                return atencion

        class ClusteringFalso:
            def asignar_cluster(self, indicadores):
                return 1

        error = urllib.error.URLError("no se pudo conectar")
        cliente = PersonalExternoClient("http://usuarios:3001")

        with mock.patch("urllib.request.urlopen", side_effect=error):
            caso = RegistrarAtencion(RepositorioFalso(), ClusteringFalso(), cliente)
            atencion = caso.execute(
                estudiante_codigo="20260001",
                modalidad="presencial",
                tipo="orientacion",
                indicadores={
                    "phq9": 8,
                    "gad7": 6,
                    "online_stress": 6,
                    "financial_stress": 5,
                    "exercise_freq": 3,
                    "social_activity": 6,
                    "sleep_hours": 7,
                },
                token="token",
            )

        # La identidad no se pudo resolver, pero la atencion se registro con
        # su perfil de agrupamiento asignado.
        assert atencion.registrado_por is None
        assert atencion.cluster_id == 1

    def test_registro_sin_identidad_no_invoca_al_servicio_de_usuarios(self):
        """Sin token no hay consulta externa que pueda fallar."""
        from app.application.use_cases.registrar_atencion import RegistrarAtencion

        class RepositorioFalso:
            def guardar(self, atencion):
                return atencion

        class ClusteringFalso:
            def asignar_cluster(self, indicadores):
                return None

        cliente = PersonalExternoClient("http://usuarios:3001")
        caso = RegistrarAtencion(RepositorioFalso(), ClusteringFalso(), cliente)

        with mock.patch("urllib.request.urlopen") as llamada:
            atencion = caso.execute(
                estudiante_codigo="20260001",
                modalidad="presencial",
                tipo="orientacion",
            )

        llamada.assert_not_called()
        assert atencion.registrado_por is None
