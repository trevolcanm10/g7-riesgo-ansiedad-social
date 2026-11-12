"""Pruebas del cliente HTTP que consulta evaluaciones de riesgo.

REGLA DE AISLAMIENTO DE DATOS
------------------------------
Este servicio no lee la base de datos de ``riskEvaluation``: la consulta se
hace por HTTP. La garantia critica es la DEGRADACION: si el servicio de
riesgo no responde, el panel debe mostrar los perfiles sin la correlacion de
riesgo, en lugar de fallar.

Las pruebas sustituyen ``urllib.request.urlopen`` y no tocan la red.
"""

from __future__ import annotations

import json
import urllib.error
from unittest import mock

import pytest

from app.infrastructure.clients.evaluaciones_riesgo_client import (
    EvaluacionesRiesgoClient,
)


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
    """Si el servicio de riesgo no responde, no hay datos de riesgo."""

    def test_sin_url_base_devuelve_lista_vacia(self):
        """Sin URL configurada no se intenta consultar nada."""
        cliente = EvaluacionesRiesgoClient("")
        assert cliente.listar_evaluaciones([1, 2, 3]) == []

    def test_sin_identificadores_devuelve_lista_vacia(self):
        """Sin estudiantes no hay nada que consultar."""
        cliente = EvaluacionesRiesgoClient("http://riesgo:3002")
        assert cliente.listar_evaluaciones([]) == []

    def test_error_http_devuelve_lista_vacia(self):
        """Un 401 o 403 del servicio degrada sin propagar."""
        error = urllib.error.HTTPError(
            "http://riesgo:3002/risk-evaluations/summary", 401, "No autorizado", None, None
        )
        cliente = EvaluacionesRiesgoClient("http://riesgo:3002")

        with mock.patch("urllib.request.urlopen", side_effect=error):
            assert cliente.listar_evaluaciones([1]) == []

    def test_servicio_inalcanzable_devuelve_lista_vacia(self):
        """Si el servicio esta caido, la correlacion simplemente no existe."""
        error = urllib.error.URLError("no se pudo conectar")
        cliente = EvaluacionesRiesgoClient("http://riesgo:3002")

        with mock.patch("urllib.request.urlopen", side_effect=error):
            assert cliente.listar_evaluaciones([1]) == []

    def test_respuesta_no_200_devuelve_lista_vacia(self):
        """Cualquier estado distinto de 200 se considera fallido."""
        cliente = EvaluacionesRiesgoClient("http://riesgo:3002")
        respuesta = RespuestaFalsa("[]", estado=503)

        with mock.patch("urllib.request.urlopen", return_value=respuesta):
            assert cliente.listar_evaluaciones([1]) == []

    def test_json_invalido_devuelve_lista_vacia(self):
        """Una respuesta que no es JSON no rompe el panel."""
        cliente = EvaluacionesRiesgoClient("http://riesgo:3002")
        respuesta = RespuestaFalsa("esto no es json")

        with mock.patch("urllib.request.urlopen", return_value=respuesta):
            assert cliente.listar_evaluaciones([1]) == []

    def test_json_que_no_es_lista_devuelve_lista_vacia(self):
        """Un objeto JSON no es la forma esperada."""
        cliente = EvaluacionesRiesgoClient("http://riesgo:3002")
        respuesta = RespuestaFalsa(json.dumps({"unexpected": True}))

        with mock.patch("urllib.request.urlopen", return_value=respuesta):
            assert cliente.listar_evaluaciones([1]) == []


class TestExito:
    """Cuando el servicio responde, se interpretan las evaluaciones."""

    def test_interpreta_una_evaluacion_valida(self):
        """Extrae usuario, probabilidad, nivel y fecha."""
        cliente = EvaluacionesRiesgoClient("http://riesgo:3002")
        respuesta = RespuestaFalsa(
            json.dumps(
                [
                    {
                        "userId": 7,
                        "anxietyProbability": 0.42,
                        "riskLevel": "MEDIO",
                        "createdAt": "2026-03-15T10:00:00.000Z",
                    }
                ]
            )
        )

        with mock.patch("urllib.request.urlopen", return_value=respuesta) as llamada:
            resultado = cliente.listar_evaluaciones([7])

        assert len(resultado) == 1
        assert resultado[0].usuario_id == 7
        assert resultado[0].nivel_riesgo == "MEDIO"
        assert resultado[0].probabilidad_ansiedad == 0.42

        url = llamada.call_args.args[0].full_url
        assert url.startswith("http://riesgo:3002/risk-evaluations/summary?userIds=")
        assert "7" in url

    def test_descarta_evaluaciones_con_forma_invalida(self):
        """Un nivel desconocido o un id invalido se descartan."""
        cliente = EvaluacionesRiesgoClient("http://riesgo:3002")
        respuesta = RespuestaFalsa(
            json.dumps(
                [
                    {"userId": 7, "anxietyProbability": 0.4, "riskLevel": "MEDIO"},
                    {"userId": 8, "anxietyProbability": 0.4, "riskLevel": "DESCONOCIDO"},
                    {"userId": "nope", "anxietyProbability": 0.4, "riskLevel": "BAJO"},
                    {"userId": 9, "anxietyProbability": "mucho", "riskLevel": "BAJO"},
                ]
            )
        )

        with mock.patch("urllib.request.urlopen", return_value=respuesta):
            resultado = cliente.listar_evaluaciones([7, 8, 9])

        assert [e.usuario_id for e in resultado] == [7]

    def test_pide_los_ids_joined_por_comas(self):
        """Varios estudiantes se piden en una sola peticion."""
        cliente = EvaluacionesRiesgoClient("http://riesgo:3002")
        respuesta = RespuestaFalsa("[]")

        with mock.patch("urllib.request.urlopen", return_value=respuesta) as llamada:
            cliente.listar_evaluaciones([1, 2, 3])

        url = llamada.call_args.args[0].full_url
        assert "userIds=1%2C2%2C3" in url
