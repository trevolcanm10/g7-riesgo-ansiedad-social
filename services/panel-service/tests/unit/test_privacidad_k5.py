"""Pruebas de la regla de privacidad k=5.

Es la proteccion central del modulo: ningun grupo con menos de cinco
estudiantes puede salir del dominio.
"""

from __future__ import annotations

from app.domain.entities.perfil_cluster import Grupo, PerfilCluster
from app.domain.services.privacidad_k5 import (
    MINIMO_GRUPO,
    conteo_publicable,
    es_publicable,
    filtrar_grupos,
    filtrar_perfiles,
    total_publicable,
)


def test_grupos_con_menos_de_cinco_no_se_publican():
    """Un grupo de cuatro estudiantes queda fuera del resultado."""
    grupos = [
        Grupo(etiqueta="orientacion", n=12),
        Grupo(etiqueta="seguimiento", n=4),
    ]

    resultado = filtrar_grupos(grupos)

    assert [grupo.etiqueta for grupo in resultado.grupos] == ["orientacion"]
    assert resultado.omitidos == 1
    assert resultado.total_visible == 12


def test_grupo_De_exactamente_cinco_si_se_publica():
    """Cinco estudiantes es el minimo publicable."""
    grupos = [Grupo(etiqueta="orientacion", n=5)]

    resultado = filtrar_grupos(grupos)

    assert len(resultado.grupos) == 1
    assert resultado.omitidos == 0


def test_grupos_omitidos_no_aparecen_en_la_salida():
    """El contenido de los grupos suprimidos no se filtra por ninguna via."""
    grupos = [
        Grupo(etiqueta="secreto", n=2, extras={"detalle": "identificable"}),
        Grupo(etiqueta="publicable", n=8),
    ]

    resultado = filtrar_grupos(grupos)

    serializado = [grupo.to_dict() for grupo in resultado.grupos]
    assert serializado == [{"etiqueta": "publicable", "n": 8}]
    assert "secreto" not in str(serializado)
    assert "identificable" not in str(serializado)


def test_perfiles_con_menos_de_cinco_no_se_publican():
    """Un cluster con pocos estudiantes observados queda fuera."""
    perfiles = [
        PerfilCluster(cluster=0, n=30, descripcion="Perfil A"),
        PerfilCluster(cluster=1, n=3, descripcion="Perfil B"),
    ]

    resultado = filtrar_perfiles(perfiles)

    assert [perfil.cluster for perfil in resultado.perfiles] == [0]
    assert resultado.omitidos == 1
    assert resultado.total_visible == 30


def test_es_publicable_respeta_el_minimo():
    """El limite se comprueba en el borde."""
    assert es_publicable(MINIMO_GRUPO) is True
    assert es_publicable(MINIMO_GRUPO - 1) is False
    assert es_publicable(0) is False


def test_lista_vacia_no_omite_nada():
    """Sin grupos no hay omisiones."""
    resultado = filtrar_grupos([])

    assert resultado.grupos == []
    assert resultado.omitidos == 0


def test_conteo_publicable_suprime_los_cuentos_pequenos():
    """Un conteo entre 1 y 4 no se publica; el cero si."""
    cero = conteo_publicable(0)
    assert cero.valor == 0
    assert cero.suprimido is False

    pequeno = conteo_publicable(1)
    assert pequeno.valor is None
    assert pequeno.suprimido is True

    assert conteo_publicable(MINIMO_GRUPO - 1).suprimido is True

    completo = conteo_publicable(MINIMO_GRUPO)
    assert completo.valor == MINIMO_GRUPO
    assert completo.suprimido is False


def test_total_publicable_redondea_cuando_hay_grupos_ocultos():
    """Con grupos ocultos el total publicado es una cota inferior."""
    exacto = total_publicable(9, False)
    assert exacto.valor == 9
    assert exacto.estimado is False

    acotado = total_publicable(9, True)
    assert acotado.valor == 5
    assert acotado.estimado is True

    suprimido = total_publicable(3, True)
    assert suprimido.valor is None
    assert suprimido.suprimido is True
