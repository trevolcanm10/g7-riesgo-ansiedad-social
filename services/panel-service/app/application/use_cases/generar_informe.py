"""Caso de uso: generar el informe mensual de atenciones.

Produce un CSV que el personal institucional descarga para su registro. El
informe es un agregado por tipo de atencion y modalidad: no incluye
identificadores de estudiantes, por lo que no expone datos personales.
"""

from __future__ import annotations

import csv
import io
from typing import List, Optional, Tuple

from app.application.interfaces.atencion_repository_port import IAtencionRepository
from app.domain.services.privacidad_k5 import (
    MINIMO_GRUPO,
    conteo_publicable,
    es_publicable,
    total_publicable,
)

# Cabecera del informe. Se mantiene estable para que el personal pueda
# procesar el archivo mensualmente.
CABECERA = [
    "tipo_atencion",
    "modalidad",
    "total_atenciones",
    "requieren_seguimiento",
]


class GenerarInforme:
    """Genera el informe CSV de un periodo."""

    def __init__(self, repository: IAtencionRepository) -> None:
        self._repository = repository

    def execute(self, periodo: Optional[str] = None) -> Tuple[str, str]:
        """Devuelve ``(nombre_archivo, contenido_csv)`` del periodo."""
        por_tipo = self._repository.contar_por_dimension("tipo", periodo)
        por_modalidad = dict(self._repository.contar_por_dimension("modalidad", periodo))

        filas: List[List[object]] = []
        grupos_omitidos = 0
        for tipo, n in por_tipo:
            # El informe por agregados no expone grupos pequenos: una fila con
            # menos de MINIMO_GRUPO atenciones permite reconstruir el caso
            # individual al cruzarlo con la agenda del personal.
            if not es_publicable(n, MINIMO_GRUPO):
                grupos_omitidos += 1
                continue
            filas.append([tipo, "todas", n, ""])

        for modalidad, n in por_modalidad.items():
            if not es_publicable(n, MINIMO_GRUPO):
                grupos_omitidos += 1
                continue
            filas.append(["todas", modalidad, n, ""])

        # La fila TOTAL sigue la misma regla de privacidad que la API: si el
        # total es menor que el minimo se escribe "<5"; si hay grupos ocultos
        # se redondea hacia abajo a multiplo del minimo, de modo que el total
        # publicado es una cota inferior y no permite reconstruir el tamano
        # de los grupos que se omitieron.
        total = total_publicable(
            self._repository.total_atenciones(periodo), grupos_omitidos > 0
        )
        seguimiento = conteo_publicable(self._repository.contar_por_seguimiento(periodo))
        filas.append(
            [
                "TOTAL",
                "todas",
                "<5" if total.suprimido else total.valor,
                "<5" if seguimiento.suprimido else seguimiento.valor,
            ]
        )

        buffer = io.StringIO()
        # Excel necesita BOM para interpretar UTF-8 correctamente.
        buffer.write("\ufeff")
        escritor = csv.writer(buffer, lineterminator="\n")
        escritor.writerow(CABECERA)
        for fila in filas:
            escritor.writerow(fila)

        nombre = f"informe_atenciones_{periodo or 'completo'}.csv"
        return nombre, buffer.getvalue()
