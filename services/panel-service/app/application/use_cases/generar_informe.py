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
from app.domain.services.privacidad_k5 import MINIMO_GRUPO, es_publicable

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
        for tipo, n in por_tipo:
            # El informe por agregados no expone grupos pequenos: una fila con
            # menos de MINIMO_GRUPO atenciones permite reconstruir el caso
            # individual al cruzarlo con la agenda del personal.
            if not es_publicable(n, MINIMO_GRUPO):
                continue
            filas.append([tipo, "todas", n, ""])

        for modalidad, n in por_modalidad.items():
            if not es_publicable(n, MINIMO_GRUPO):
                continue
            filas.append(["todas", modalidad, n, ""])

        seguimiento = self._repository.contar_por_seguimiento(periodo)
        filas.append(["TOTAL", "todas", self._repository.total_atencioness(periodo), seguimiento])

        buffer = io.StringIO()
        # Excel necesita BOM para interpretar UTF-8 correctamente.
        buffer.write("\ufeff")
        escritor = csv.writer(buffer, lineterminator="\n")
        escritor.writerow(CABECERA)
        for fila in filas:
            escritor.writerow(fila)

        nombre = f"informe_atenciones_{periodo or 'completo'}.csv"
        return nombre, buffer.getvalue()
