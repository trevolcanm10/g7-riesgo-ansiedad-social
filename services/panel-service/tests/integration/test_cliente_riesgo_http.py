"""Prueba del cliente de riesgo contra un servidor HTTP real.

El resto de las pruebas sustituyen ``urlopen`` por un doble. Esta prueba
levanta un servidor HTTP de verdad que EXIGE el token del personal: es la
unica forma de comprobar que el panel realmente manda la cabecera
``Authorization`` y no solo que la construye.

No sale a la red: el servidor escucha en el bucle local.
"""

from __future__ import annotations

import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from app.domain.entities.motivo_riesgo import MotivoRiesgo
from app.infrastructure.clients.evaluaciones_riesgo_client import (
    EvaluacionesRiesgoClient,
)

TOKEN_ESPERADO = "token-de-prueba"


class Manejador(BaseHTTPRequestHandler):
    """Servidor minimo que exige el token y devuelve conteos por nivel."""

    ids_recibidos = None

    def do_POST(self):  # noqa: N802 (nombre impuesto por BaseHTTPRequestHandler)
        if self.path != "/risk-evaluations/summary/counts":
            self._responder(404, {"message": "ruta desconocida"})
            return
        if self.headers.get("Authorization") != f"Bearer {TOKEN_ESPERADO}":
            self._responder(401, {"message": "falta el token"})
            return

        longitud = int(self.headers.get("Content-Length", "0"))
        cuerpo = json.loads(self.rfile.read(longitud).decode("utf-8"))
        Manejador.ids_recibidos = cuerpo.get("userIds")
        self._responder(
            200,
            {
                "total": 3,
                "suprimido": False,
                "conteos": {"BAJO": 1, "MEDIO": 1, "ALTO": 1},
            },
        )

    def _responder(self, estado: int, cuerpo: dict) -> None:
        datos = json.dumps(cuerpo).encode("utf-8")
        self.send_response(estado)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(datos)))
        self.end_headers()
        self.wfile.write(datos)

    def log_message(self, *_args) -> None:
        """Silencia el log del servidor de prueba."""


def _arrancar_servidor():
    servidor = ThreadingHTTPServer(("127.0.0.1", 0), Manejador)
    hilo = threading.Thread(target=servidor.serve_forever, daemon=True)
    hilo.start()
    return servidor


def test_sin_token_el_servidor_responde_401_y_el_panel_lo_explica():
    servidor = _arrancar_servidor()
    try:
        url = f"http://127.0.0.1:{servidor.server_address[1]}"
        resultado = EvaluacionesRiesgoClient(url).contar_riesgos([1, 2, 3], "")
    finally:
        servidor.shutdown()
        servidor.server_close()

    assert resultado.motivo is MotivoRiesgo.NO_AUTORIZADO
    assert resultado.disponible is False


def test_con_token_el_servidor_responde_los_conteos():
    servidor = _arrancar_servidor()
    try:
        url = f"http://127.0.0.1:{servidor.server_address[1]}"
        resultado = EvaluacionesRiesgoClient(url).contar_riesgos([4, 5, 6], TOKEN_ESPERADO)
    finally:
        servidor.shutdown()
        servidor.server_close()

    assert resultado.motivo is MotivoRiesgo.DISPONIBLE
    assert resultado.total == 3
    assert resultado.conteos == {"BAJO": 1, "MEDIO": 1, "ALTO": 1}
    assert Manejador.ids_recibidos == [4, 5, 6]
