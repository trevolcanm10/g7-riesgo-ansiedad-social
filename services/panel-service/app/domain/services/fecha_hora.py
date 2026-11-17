"""Reloj del dominio: tiempo del servicio en UTC.

El servicio trabaja siempre en UTC. Las columnas ``DATETIME`` de MySQL son
naive (no guardan zona horaria), por lo que el valor que se persiste y el que
se calcula para ``periodo`` deben ser **UTC naive**.

Se centraliza aqui la conversion para no repetirla en cada capa.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional


# Minutos de tolerancia admitidos para una atencion registrada "un poco" en el
# futuro: cubre los desfases de reloj entre el navegador y el servidor.
TOLERANCIA_FUTURO_MINUTOS = 5

# Antiguedad maxima admitida para una atencion. Una fecha muy antigua altera
# el periodo de las estadisticas y no corresponde a una atencion real.
ANTIGUEDAD_MAXIMA_DIAS = 365


def ahora_utc() -> datetime:
    """Devuelve el instante actual en UTC, sin informacion de zona horaria.

    Equivale a lo que hacia ``datetime.utcnow()``, pero ese metodo esta
    deprecado desde Python 3.12. El valor resultante es identico: UTC naive.
    """
    return datetime.now(timezone.utc).replace(tzinfo=None)


def a_utc_naive(fecha: datetime) -> datetime:
    """Normaliza una fecha a UTC sin informacion de zona horaria.

    Las fechas que llegan del cliente pueden venir con zona horaria; el
    servicio las maneja siempre como UTC naive.
    """
    if fecha.tzinfo is None:
        return fecha
    return fecha.astimezone(timezone.utc).replace(tzinfo=None)


def validar_fecha_atencion(fecha: datetime, ahora: Optional[datetime] = None) -> datetime:
    """Valida la fecha de una atencion y la devuelve normalizada.

    Se rechazan las fechas futuras (con cinco minutos de tolerancia por
    desfase de reloj) y las anteriores a un ano, porque ambas distorsionan el
    periodo con el que se calculan las estadisticas.
    """
    referencia = ahora_utc() if ahora is None else a_utc_naive(ahora)
    momento = a_utc_naive(fecha)
    if momento > referencia + timedelta(minutes=TOLERANCIA_FUTURO_MINUTOS):
        raise ValueError("La fecha de la atencion no puede ser futura.")
    if momento < referencia - timedelta(days=ANTIGUEDAD_MAXIMA_DIAS):
        raise ValueError(
            "La fecha de la atencion no puede ser anterior a un ano."
        )
    return momento
