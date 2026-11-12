"""Regla de privacidad k=5.

Ningun grupo que contenga menos de ``MINIMO_GRUPO`` estudiantes puede salir
del dominio hacia la API. Es una regla de negocio, no una comprobacion de
presentacion: vive en el dominio y se aplica antes de construir cualquier
respuesta.

Motivo: en una institucion de tamano reducido, una categoria con dos o tres
estudiantes es reidentificable por combinarla con otros datos. Publicar un
recuento de un grupo pequeno equivale a publicar datos personales.
"""

from __future__ import annotations

from typing import Iterable, List

from app.domain.entities.perfil_cluster import (
    Grupo,
    PerfilCluster,
    ResultadoPerfilesPrivacidad,
    ResultadoPrivacidad,
)

# Numero minimo de estudiantes por grupo publicable.
MINIMO_GRUPO = 5


def es_publicable(n: int, minimo: int = MINIMO_GRUPO) -> bool:
    """Indica si un grupo con ``n`` estudiantes puede mostrarse."""
    return n >= minimo


def filtrar_grupos(grupos: Iterable[Grupo], minimo: int = MINIMO_GRUPO) -> ResultadoPrivacidad:
    """Descarta los grupos con menos de ``minimo`` estudiantes.

    Devuelve los grupos visibles y cuantos fueron omitidos. Los grupos
    suprimidos no se exponen en ningun campo de la respuesta.
    """
    visibles: List[Grupo] = []
    omitidos = 0

    for grupo in grupos:
        if es_publicable(grupo.n, minimo):
            visibles.append(grupo)
        else:
            omitidos += 1

    return ResultadoPrivacidad(grupos=visibles, omitidos=omitidos)


def filtrar_perfiles(
    perfiles: Iterable[PerfilCluster], minimo: int = MINIMO_GRUPO
) -> ResultadoPerfilesPrivacidad:
    """Aplica la regla k=5 a los perfiles devueltos por el modelo de clustering.

    Un perfil con menos de ``minimo`` estudiantes observados no se publica.
    """
    visibles: List[PerfilCluster] = []
    omitidos = 0

    for perfil in perfiles:
        if es_publicable(perfil.n, minimo):
            visibles.append(perfil)
        else:
            omitidos += 1

    return ResultadoPerfilesPrivacidad(perfiles=visibles, omitidos=omitidos)


def total_omitidos(*resultados) -> int:
    """Suma los grupos omitidos entre varios resultados de privacidad."""
    return sum(resultado.omitidos for resultado in resultados)
