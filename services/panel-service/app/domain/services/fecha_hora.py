"""Reloj del dominio: tiempo del servicio en UTC.

El servicio trabaja siempre en UTC. Las columnas ``DATETIME`` de MySQL son
naive (no guardan zona horaria), por lo que el valor que se persiste y el que
se calcula para ``periodo`` deben ser **UTC naive**.

Se centraliza aqui la conversion para no repetirla en cada capa.
"""

from __future__ import annotations

from datetime import datetime, timezone


def ahora_utc() -> datetime:
    """Devuelve el instante actual en UTC, sin informacion de zona horaria.

    Equivale a lo que hacia ``datetime.utcnow()``, pero ese metodo esta
    deprecado desde Python 3.12. El valor resultante es identico: UTC naive.
    """
    return datetime.now(timezone.utc).replace(tzinfo=None)
