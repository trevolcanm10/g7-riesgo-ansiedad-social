"""Pruebas de la configuracion de conexion segura a la base de datos.

TiDB Cloud exige TLS. El servicio solo lo usa cuando la variable ``DB_SSL``
esta activa, y falla de forma explicita si el certificado indicado no existe.
"""

from __future__ import annotations

import ssl

import pytest

from app.config.settings import construir_engine_options


def test_sin_ssl_no_hay_opciones_de_motor():
    """Si DB_SSL esta apagado no se anade ninguna opcion de conexion."""
    assert construir_engine_options(db_ssl=False) == {}


def test_con_ssl_se_pasa_un_contexto_que_valida_el_certificado():
    """Con DB_SSL el motor recibe un contexto que valida el certificado."""
    opciones = construir_engine_options(db_ssl=True, db_ssl_ca="")

    contexto = opciones["connect_args"]["ssl"]
    assert isinstance(contexto, ssl.SSLContext)
    assert contexto.verify_mode == ssl.CERT_REQUIRED
    assert contexto.check_hostname is True


def test_un_certificado_inexistente_falla_de_forma_explicita(tmp_path):
    """Si el archivo de CA no existe la falla es explicita, no silenciosa."""
    inexistente = str(tmp_path / "ca.pem")

    with pytest.raises(RuntimeError):
        construir_engine_options(db_ssl=True, db_ssl_ca=inexistente)
