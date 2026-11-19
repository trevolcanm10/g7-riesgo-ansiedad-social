"""Pruebas del cruce entre perfiles de agrupamiento y nivel de riesgo.

Regla de privacidad: dentro de cada perfil tambien se ocultan las celdas de
nivel de riesgo con menos de cinco estudiantes.

El panel pide **conteos por nivel** al microservicio de evaluacion (nunca el
riesgo de un estudiante concreto) y el servicio de evaluacion aplica su propia
regla k=5 del lado servidor. Este caso de uso traduce la respuesta en celdas
publicables y deja constancia del motivo cuando no hay correlacion.
"""

from __future__ import annotations

from app.application.use_cases.obtener_riesgo_por_perfil import ObtenerRiesgoPorPerfil
from app.domain.entities.motivo_riesgo import MotivoRiesgo
from app.domain.entities.perfil_cluster import PerfilCluster
from app.domain.entities.resultado_riesgo import ResultadoRiesgo


class PuertoFalso:
    """Doble del puerto de conteos de riesgo.

    ``respuestas`` puede ser un diccionario con los ids de cada consulta o una
    lista con las respuestas por orden de llamada.
    """

    def __init__(self, respuestas=None, motivo=MotivoRiesgo.DISPONIBLE) -> None:
        self.respuestas = respuestas if respuestas is not None else {}
        self.motivo = motivo
        self.consultas = []
        self.tokens = []

    def contar_riesgos(self, usuario_ids, token):
        self.consultas.append(list(usuario_ids))
        self.tokens.append(token)
        if isinstance(self.respuestas, list):
            indice = min(len(self.consultas) - 1, len(self.respuestas) - 1)
            return self.respuestas[indice]
        for ids, respuesta in self.respuestas.items():
            if list(ids) == list(usuario_ids):
                return respuesta
        return ResultadoRiesgo(total=0, conteos={}, motivo=self.motivo)


def _perfil(cluster: int, n: int) -> PerfilCluster:
    """Construye un perfil de prueba."""
    return PerfilCluster(
        cluster=cluster,
        n=n,
        descripcion="Perfil de prueba",
        nivel_orientativo="moderado",
    )


def _resultado(conteos: dict, total: int | None = None) -> ResultadoRiesgo:
    """Construye la respuesta del microservicio de evaluacion."""
    return ResultadoRiesgo(
        total=total if total is not None else sum(conteos.values()),
        suprimido=False,
        conteos=dict(conteos),
        motivo=MotivoRiesgo.DISPONIBLE,
    )


class TestCruce:
    """El cruce cuenta los niveles de riesgo de cada perfil."""

    def test_cuenta_el_nivel_de_riesgo_por_perfil(self):
        """Cada perfil muestra el conteo por nivel de riesgo."""
        ids = list(range(1, 9))
        puerto = PuertoFalso({tuple(ids): _resultado({"ALTO": 8})})
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, _, motivo = caso.execute([_perfil(0, 8)], {0: ids})

        assert perfiles[0].riesgo == {"ALTO": 8}
        assert perfiles[0].riesgo_disponible is True
        assert perfiles[0].riesgo_motivo == "disponible"
        assert motivo is MotivoRiesgo.DISPONIBLE

    def test_sin_conteos_devuelve_los_perfiles_sin_correlacion(self):
        """Si el servicio no responde, los perfiles se devuelven sin riesgo."""
        puerto = PuertoFalso(motivo=MotivoRiesgo.SERVICIO_NO_DISPONIBLE)
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, _, motivo = caso.execute([_perfil(0, 8)], {0: list(range(1, 9))})

        assert perfiles[0].riesgo_disponible is False
        assert perfiles[0].riesgo_motivo == "servicio_no_disponible"
        assert motivo is MotivoRiesgo.SERVICIO_NO_DISPONIBLE

    def test_sin_perfiles_no_consulta(self):
        """Sin perfiles no hay nada que cruzar."""
        puerto = PuertoFalso()
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, celdas, motivo = caso.execute([], {})

        assert perfiles == []
        assert celdas == 0
        assert motivo is MotivoRiesgo.SIN_DATOS
        assert puerto.consultas == []

    def test_consulta_los_ids_de_cada_perfil(self):
        """Cada perfil se consulta con sus propios estudiantes."""
        ids_0 = list(range(1, 6))
        ids_1 = list(range(6, 11))
        puerto = PuertoFalso(
            {
                tuple(ids_0): _resultado({"BAJO": 5}),
                tuple(ids_1): _resultado({"MEDIO": 5}),
            }
        )
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, _, _ = caso.execute(
            [_perfil(0, 5), _perfil(1, 5)], {0: ids_0, 1: ids_1}
        )

        assert puerto.consultas == [ids_0, ids_1]
        assert perfiles[0].riesgo == {"BAJO": 5}
        assert perfiles[1].riesgo == {"MEDIO": 5}

    def test_manda_el_token_al_servicio(self):
        """El token del personal se propaga al microservicio de evaluacion."""
        puerto = PuertoFalso({tuple(range(1, 6)): _resultado({"BAJO": 5})})
        caso = ObtenerRiesgoPorPerfil(puerto)

        caso.execute([_perfil(0, 5)], {0: list(range(1, 6))}, "token-de-prueba")

        assert puerto.tokens == ["token-de-prueba"]

    def test_celda_menor_de_cinco_se_oculta(self):
        """Una celda con menos de cinco estudiantes no se publica."""
        ids = list(range(1, 11))
        puerto = PuertoFalso({tuple(ids): _resultado({"BAJO": 8, "ALTO": 2})})
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, celdas, _ = caso.execute([_perfil(0, 10)], {0: ids})

        assert perfiles[0].riesgo == {"BAJO": 8}
        assert perfiles[0].riesgo_omitidos == 1
        assert celdas == 1

    def test_celda_de_cinco_se_muestra(self):
        """Una celda con exactamente cinco estudiantes si se publica."""
        ids = list(range(1, 11))
        puerto = PuertoFalso({tuple(ids): _resultado({"BAJO": 5, "ALTO": 5})})
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, celdas, _ = caso.execute([_perfil(0, 10)], {0: ids})

        assert perfiles[0].riesgo == {"BAJO": 5, "ALTO": 5}
        assert celdas == 0

    def test_celda_vacia_no_cuenta_como_omitida(self):
        """Un nivel sin estudiantes no es una celda oculta."""
        ids = list(range(1, 11))
        puerto = PuertoFalso({tuple(ids): _resultado({"BAJO": 10})})
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, celdas, _ = caso.execute([_perfil(0, 10)], {0: ids})

        assert perfiles[0].riesgo == {"BAJO": 10}
        assert perfiles[0].riesgo_omitidos == 0
        assert celdas == 0

    def test_perfil_sin_estudiantes_no_tiene_correlacion(self):
        """Un perfil sin estudiantes no puede correlacionarse."""
        puerto = PuertoFalso()
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, _, _ = caso.execute([_perfil(0, 0)], {0: []})

        assert perfiles[0].riesgo_disponible is False
        assert perfiles[0].riesgo_motivo == "sin_datos"

    def test_todas_las_celdas_ocultas_dejan_el_perfil_sin_correlacion(self):
        """Si ninguna celda llega al minimo, el perfil no muestra riesgo."""
        ids = list(range(1, 4))
        puerto = PuertoFalso({tuple(ids): _resultado({"BAJO": 3})})
        caso = ObtenerRiesgoPorPerfil(puerto)

        perfiles, celdas, _ = caso.execute([_perfil(0, 3)], {0: ids})

        assert perfiles[0].riesgo == {}
        assert perfiles[0].riesgo_disponible is False
        assert perfiles[0].riesgo_motivo == "suprimido_k5"
        assert celdas == 1

    def test_el_motivo_global_refleja_el_de_los_perfiles(self):
        """Si un perfil tiene datos, el motivo global es que hay correlacion."""
        ids_0 = list(range(1, 6))
        ids_1 = list(range(6, 11))
        puerto = PuertoFalso(
            {
                tuple(ids_0): _resultado({"BAJO": 5}),
                tuple(ids_1): ResultadoRiesgo(
                    motivo=MotivoRiesgo.SERVICIO_NO_DISPONIBLE
                ),
            }
        )
        caso = ObtenerRiesgoPorPerfil(puerto)

        _, _, motivo = caso.execute(
            [_perfil(0, 5), _perfil(1, 5)], {0: ids_0, 1: ids_1}
        )

        assert motivo is MotivoRiesgo.DISPONIBLE
