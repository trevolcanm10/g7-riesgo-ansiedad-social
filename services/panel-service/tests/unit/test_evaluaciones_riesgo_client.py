"""Pruebas del cliente HTTP que consulta los conteos de riesgo.

REGLA DE AISLAMIENTO DE DATOS
------------------------------
Este servicio no lee la base de datos de ``riskEvaluation``: la consulta se
hace por HTTP contra el endpoint agregado ``/risk-evaluations/summary/counts``.
El panel solo pide **conteos por nivel**, nunca el riesgo de un estudiante
concreto, y el servicio de evaluacion aplica la regla k=5 del lado servidor.

La garantia critica es la DEGRADACION: si el servicio de riesgo no responde,
el panel debe mostrar los perfiles sin la correlacion de riesgo **explicando
el motivo**, en lugar de fallar en silencio.

Las pruebas sustituyen ``urllib.request.urlopen`` y no tocan la red.
"""

from __future__ import annotations

import json
import urllib.error
from unittest import mock

from app.domain.entities.motivo_riesgo import MotivoRiesgo
from app.infrastructure.clients.evaluaciones_riesgo_client import (
    EvaluacionesRiesgoClient,
)


class RespuestaFalsa:
    """Doble de la respuesta HTTP de ``urllib.request.urlopen``."""

    def __init__(self, cuerpo: str, estado: int = 200) -> None:
        self.cuerpo = cuerpo.encode("utf-8")
        self.status = estado

    def read(self) -> bytes:
        return self.cuerpo

    def __enter__(self):
        return self

    def __exit__(self, *_exc) -> bool:
        return False


def _cliente(url: str = "https://riesgo.onrender.com", timeout: int = 45):
    return EvaluacionesRiesgoClient(url, timeout=timeout)


def _respuesta(cuerpo: dict, estado: int = 200) -> RespuestaFalsa:
    return RespuestaFalsa(json.dumps(cuerpo), estado)


class TestConfiguracion:
    """El cliente se degrada con un motivo claro cuando falta configuracion."""

    def test_sin_url_base_no_consulta(self):
        cliente = EvaluacionesRiesgoClient("")
        resultado = cliente.contar_riesgos([1, 2, 3], "token")
        assert resultado.motivo is MotivoRiesgo.NO_CONFIGURADO
        assert resultado.conteos == {}
        assert resultado.disponible is False

    def test_sin_ids_devuelve_sin_datos(self):
        resultado = _cliente().contar_riesgos([], "token")
        assert resultado.motivo is MotivoRiesgo.SIN_DATOS

    def test_sin_token_no_consulta(self):
        resultado = _cliente().contar_riesgos([1, 2, 3], "")
        assert resultado.motivo is MotivoRiesgo.NO_AUTORIZADO

    def test_el_timeout_es_configurable(self):
        cliente = _cliente(timeout=45)
        with mock.patch("urllib.request.urlopen") as urlopen:
            urlopen.return_value = _respuesta({"total": 3, "conteos": {"BAJO": 3}})
            cliente.contar_riesgos([1, 2, 3], "token")
        assert urlopen.call_args.kwargs["timeout"] == 45


class TestPeticion:
    """La peticion va al endpoint agregado y manda el token del personal."""

    def test_manda_el_token_en_la_cabecera_authorization(self):
        with mock.patch("urllib.request.urlopen") as urlopen:
            urlopen.return_value = _respuesta({"total": 3, "conteos": {"BAJO": 3}})
            _cliente().contar_riesgos([1, 2, 3], "token-de-prueba")

        peticion = urlopen.call_args.args[0]
        assert peticion.get_method() == "POST"
        assert peticion.get_header("Authorization") == "Bearer token-de-prueba"
        assert peticion.get_header("Content-type") == "application/json"

    def test_consulta_el_endpoint_agregado_con_los_ids(self):
        with mock.patch("urllib.request.urlopen") as urlopen:
            urlopen.return_value = _respuesta({"total": 2, "conteos": {"BAJO": 2}})
            _cliente().contar_riesgos([7, 9], "token")

        peticion = urlopen.call_args.args[0]
        assert peticion.full_url == (
            "https://riesgo.onrender.com/risk-evaluations/summary/counts"
        )
        assert json.loads(peticion.data.decode("utf-8")) == {"userIds": [7, 9]}

    def test_la_url_base_no_puede_dejar_barra_final(self):
        with mock.patch("urllib.request.urlopen") as urlopen:
            urlopen.return_value = _respuesta({"total": 1, "conteos": {"BAJO": 1}})
            _cliente("https://riesgo.onrender.com/").contar_riesgos([1], "token")

        peticion = urlopen.call_args.args[0]
        assert peticion.full_url.startswith("https://riesgo.onrender.com/risk-evaluations/")


class TestRespuestaCorrecta:
    """Una respuesta valida produce conteos publicables."""

    def test_conteos_validos_devienen_disponibles(self):
        with mock.patch("urllib.request.urlopen") as urlopen:
            urlopen.return_value = _respuesta(
                {"total": 12, "suprimido": False, "conteos": {"BAJO": 6, "MEDIO": 4, "ALTO": 2}}
            )
            resultado = _cliente().contar_riesgos([1, 2, 3], "token")

        assert resultado.motivo is MotivoRiesgo.DISPONIBLE
        assert resultado.disponible is True
        assert resultado.total == 12
        assert resultado.suprimido is False
        assert resultado.conteos == {"BAJO": 6, "MEDIO": 4, "ALTO": 2}

    def test_descarta_niveles_desconocidos_y_conteos_no_positivos(self):
        with mock.patch("urllib.request.urlopen") as urlopen:
            urlopen.return_value = _respuesta(
                {"total": 6, "conteos": {"BAJO": 5, "CRITICO": 3, "ALTO": 0}}
            )
            resultado = _cliente().contar_riesgos([1, 2, 3], "token")

        assert resultado.conteos == {"BAJO": 5}

    def test_sin_conteos_devuelve_sin_datos(self):
        with mock.patch("urllib.request.urlopen") as urlopen:
            urlopen.return_value = _respuesta({"total": 0, "conteos": {}})
            resultado = _cliente().contar_riesgos([1], "token")

        assert resultado.motivo is MotivoRiesgo.SIN_DATOS
        assert resultado.disponible is False

    def test_conteos_con_forma_invalida_devuelve_sin_datos(self):
        with mock.patch("urllib.request.urlopen") as urlopen:
            urlopen.return_value = _respuesta({"total": 3, "conteos": "muchos"})
            resultado = _cliente().contar_riesgos([1], "token")

        assert resultado.motivo is MotivoRiesgo.SIN_DATOS


class TestSupresionDelServidor:
    """El servicio de evaluacion aplica k=5: avisa cuando suprime."""

    def test_suprimido_devuelve_el_motivo_de_k5(self):
        with mock.patch("urllib.request.urlopen") as urlopen:
            urlopen.return_value = _respuesta(
                {"total": None, "suprimido": True, "conteos": None}
            )
            resultado = _cliente().contar_riesgos([1, 2, 3], "token")

        assert resultado.motivo is MotivoRiesgo.SUPRIMIDO_K5
        assert resultado.suprimido is True
        assert resultado.conteos == {}


class TestDegradacion:
    """Cada fallo del servicio externo se traduce en un motivo distinguible."""

    def test_token_rechazado_devuelve_no_autorizado(self):
        error = urllib.error.HTTPError("url", 401, "Unauthorized", None, None)
        with mock.patch("urllib.request.urlopen", side_effect=error):
            resultado = _cliente().contar_riesgos([1], "token")

        assert resultado.motivo is MotivoRiesgo.NO_AUTORIZADO

    def test_rol_rechazado_devuelve_no_autorizado(self):
        error = urllib.error.HTTPError("url", 403, "Forbidden", None, None)
        with mock.patch("urllib.request.urlopen", side_effect=error):
            resultado = _cliente().contar_riesgos([1], "token")

        assert resultado.motivo is MotivoRiesgo.NO_AUTORIZADO

    def test_endpoint_inexistente_devuelve_servicio_no_disponible(self):
        error = urllib.error.HTTPError("url", 404, "Not Found", None, None)
        with mock.patch("urllib.request.urlopen", side_effect=error):
            resultado = _cliente().contar_riesgos([1], "token")

        assert resultado.motivo is MotivoRiesgo.SERVICIO_NO_DISPONIBLE

    def test_error_de_servidor_devuelve_servicio_no_disponible(self):
        error = urllib.error.HTTPError("url", 500, "Server Error", None, None)
        with mock.patch("urllib.request.urlopen", side_effect=error):
            resultado = _cliente().contar_riesgos([1], "token")

        assert resultado.motivo is MotivoRiesgo.SERVICIO_NO_DISPONIBLE

    def test_servicio_inalcanzable_devuelve_servicio_no_disponible(self):
        with mock.patch("urllib.request.urlopen", side_effect=urllib.error.URLError("no")):
            resultado = _cliente().contar_riesgos([1], "token")

        assert resultado.motivo is MotivoRiesgo.SERVICIO_NO_DISPONIBLE

    def test_estado_distinto_de_200_devuelve_servicio_no_disponible(self):
        with mock.patch("urllib.request.urlopen") as urlopen:
            urlopen.return_value = _respuesta({"total": 1}, estado=204)
            resultado = _cliente().contar_riesgos([1], "token")

        assert resultado.motivo is MotivoRiesgo.SERVICIO_NO_DISPONIBLE

    def test_json_ilegible_devuelve_servicio_no_disponible(self):
        with mock.patch("urllib.request.urlopen") as urlopen:
            urlopen.return_value = RespuestaFalsa("esto no es json")
            resultado = _cliente().contar_riesgos([1], "token")

        assert resultado.motivo is MotivoRiesgo.SERVICIO_NO_DISPONIBLE

    def test_fallo_inesperado_devuelve_servicio_no_disponible(self):
        with mock.patch("urllib.request.urlopen", side_effect=RuntimeError("boom")):
            resultado = _cliente().contar_riesgos([1], "token")

        assert resultado.motivo is MotivoRiesgo.SERVICIO_NO_DISPONIBLE
