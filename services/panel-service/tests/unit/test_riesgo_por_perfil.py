"""Pruebas del cruce entre perfiles de agrupamiento y nivel de riesgo.

Regla de privacidad: dentro de cada perfil tambien se ocultan las celdas de
nivel de riesgo con menos de cinco estudiantes.
"""

from __future__ import annotations

from app.application.interfaces.evaluaciones_riesgo_port import EvaluacionRiesgo
from app.application.use_cases.obtener_riesgo_por_perfil import ObtenerRiesgoPorPerfil
from app.domain.entities.perfil_cluster import PerfilCluster


class PuertoFalso:
    """Doble del puerto de evaluaciones de riesgo."""

    def __init__(self, evaluaciones=None) -> None:
        self.evaluaciones = evaluaciones or []
        self.consultado = None

    def listar_evaluaciones(self, usuario_ids):
        self.consultado = list(usuario_ids)
        return list(self.evaluaciones)


def _perfil(cluster: int, n: int) -> PerfilCluster:
    """Construye un perfil de prueba."""
    return PerfilCluster(
        cluster=cluster,
        n=n,
        descripcion="Perfil de prueba",
        nivel_orientativo="moderado",
    )


def _evaluacion(usuario_id: int, nivel: str) -> EvaluacionRiesgo:
    """Construye una evaluacion de riesgo de prueba."""
    return EvaluacionRiesgo(
        usuario_id=usuario_id,
        probabilidad_ansiedad=0.5,
        nivel_riesgo=nivel,
    )


class TestCruce:
    """El cruce cuenta los niveles de riesgo de cada perfil."""

    def test_cuenta_el_nivel_de_riesgo_por_perfil(self):
        """Cada perfil muestra el conteo por nivel de riesgo."""
        puerto = PuertoFalso(
            [
                _evaluacion(1, "ALTO"),
                _evaluacion(2, "ALTO"),
                _evaluacion(3, "ALTO"),
                _evaluacion(4, "ALTO"),
                _evaluacion(5, "ALTO"),
                _evaluacion(6, "ALTO"),
                _evaluacion(7, "ALTO"),
                _evaluacion(8, "ALTO"),
                _evaluacion(9, "MEDIO"),
                _evaluacion(10, "MEDIO"),
                _evaluacion(11, "MEDIO"),
                _evaluacion(12, "MEDIO"),
                _evaluacion(13, "MEDIO"),
            ]
        )
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, omitidas = caso.execute(
            [_perfil(0, 13)], {0: list(range(1, 14))}
        )

        # Las dos celdas con al menos cinco estudiantes se publican.
        assert omitidas == 0
        assert perfiles[0].riesgo == {"ALTO": 8, "MEDIO": 5}
        assert perfiles[0].riesgo_disponible is True

    def test_sin_evaluaciones_devuelve_lista_vacia(self):
        """Si nadie tiene evaluacion, el perfil no muestra niveles."""
        caso = ObtenerRiesgoPorPerfil(PuertoFalso([]))

        perfiles, omitidas = caso.execute(
            [_perfil(0, 6)], {0: [1, 2, 3, 4, 5, 6]}
        )

        assert omitidas == 0
        assert perfiles[0].riesgo == {}
        assert perfiles[0].riesgo_disponible is False

    def test_sin_perfiles_no_consulta_el_servicio(self):
        """Sin perfiles no hay nada que cruzar."""
        puerto = PuertoFalso()
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, omitidas = caso.execute([], {})

        assert perfiles == []
        assert omitidas == 0
        assert puerto.consultado is None

    def test_consulta_los_identificadores_de_todos_los_perfiles(self):
        """Se pide en una sola llamada la evaluacion de todos los estudiantes."""
        puerto = PuertoFalso([_evaluacion(1, "BAJO")])
        caso = ObtenerRiesgoPorPerfil(puerto)

        caso.execute([_perfil(0, 5), _perfil(1, 5)], {0: [1, 2, 3], 1: [4, 5, 6]})

        assert puerto.consultado == [1, 2, 3, 4, 5, 6]

    def test_estudiantes_sin_evaluacion_no_se_cuentan(self):
        """Un estudiante sin evaluacion de riesgo no entra en ningun nivel."""
        # Cinco estudiantes con evaluacion ALTO y uno sin evaluacion.
        puerto = PuertoFalso(
            [_evaluacion(indice, "ALTO") for indice in range(1, 6)]
        )
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, _ = caso.execute([_perfil(0, 6)], {0: [1, 2, 3, 4, 5, 6]})

        # Solo los cinco con evaluacion se cuentan: el sexto no aparece.
        assert perfiles[0].riesgo["ALTO"] == 5


class TestPrivacidadInterna:
    """Las celdas con menos de cinco estudiantes tambien se ocultan."""

    def test_oculta_celda_con_menos_de_cinco(self):
        """Un nivel con cuatro estudiantes no se publica."""
        puerto = PuertoFalso(
            [
                _evaluacion(1, "ALTO"),
                _evaluacion(2, "ALTO"),
                _evaluacion(3, "ALTO"),
                _evaluacion(4, "ALTO"),
                _evaluacion(5, "BAJO"),
                _evaluacion(6, "BAJO"),
                _evaluacion(7, "BAJO"),
                _evaluacion(8, "BAJO"),
                _evaluacion(9, "BAJO"),
                _evaluacion(10, "BAJO"),
            ]
        )
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, omitidas = caso.execute(
            [_perfil(0, 12)], {0: list(range(1, 11))}
        )

        # La celda ALTO (4) se oculta; BAJO (6) si se publica.
        assert "ALTO" not in perfiles[0].riesgo
        assert perfiles[0].riesgo["BAJO"] == 6
        assert omitidas == 1
        assert perfiles[0].riesgo_omitidos == 1

    def test_celda_de_exactamente_cinco_si_se_publica(self):
        """Cinco estudiantes es el minimo publicable."""
        puerto = PuertoFalso(
            [_evaluacion(indice, "ALTO") for indice in range(1, 6)]
        )
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, omitidas = caso.execute([_perfil(0, 8)], {0: list(range(1, 9))})

        assert perfiles[0].riesgo["ALTO"] == 5
        # Las celdas sin estudiantes (MEDIO, BAJO) no cuentan como omitidas:
        # no estan ocultas, simplemente no existen.
        assert omitidas == 0

    def test_celda_vacia_no_cuenta_como_omitida(self):
        """Un nivel de riesgo sin estudiantes no infla el contador."""
        puerto = PuertoFalso(
            [_evaluacion(indice, "ALTO") for indice in range(1, 8)]
        )
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, omitidas = caso.execute([_perfil(0, 8)], {0: list(range(1, 9))})

        assert perfiles[0].riesgo == {"ALTO": 7}
        assert omitidas == 0
