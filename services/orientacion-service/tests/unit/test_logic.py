import pytest

from app.application.use_cases.solicitud_use_cases import OrientacionUseCases
from app.domain.entities.solicitud import SolicitudOrientacion
from app.domain.entities.urgencia_service import UrgenciaDomainService
from app.domain.errors import ConflictError, ValidationError
from app.infrastructure.ml.scikit_classifier import ScikitLocalClassifier


@pytest.mark.parametrize(
    "mensaje",
    [
        "Quiero morir, no aguanto más",
        "Me quiero hacer daño",
        "Estoy pensando en suicidarme",
        "No me siento segura en mi casa",
        "NO ME SIENTO SEGURO!!! Necesito ayuda ahora",
        "Ya no quiero seguir viviendo, sería mejor muerta",
        "He pensado en quitarme la vida",
        "Ojalá no despertara mañana",
        "Me corto cuando me siento mal",
        "Siento que todos estarían mejor sin mí",
        "No le encuentro sentido a seguir",
        "Quiero desaparecer",
        "Pienso en terminar con todo",
        "No aguanto más",
        "No aguanto más este curso de cálculo, quiero morir",
        "Ya no puedo seguir con mi vida",
        "Sería mejor que yo no existiera",
        "Tengo ganas de no existir",
        "Quisiera dejar de existir",
        "Me quiero matar",
        "Quiero matarme",
        "Me voy a matar",
        "Voy a matarme",
        "Pienso en matarme",
        "No vale la pena vivir",
        "No tiene sentido vivir",
        "No le veo sentido a la vida",
        "Quisiera no haber nacido",
        "Me quiero cortar las venas",
        "Me voy a cortar las venas",
        "Me quiero quitar la vida",
        "Me voy a quitar la vida",
        "Quisiera estar muerto",
        "Me he cortado las venas",
    ],
)
def test_detector_urgencia_detecta_variantes_criticas(mensaje):
    analisis = UrgenciaDomainService.detectar(mensaje)

    assert analisis.es_urgente is True
    assert len(analisis.coincidencias) >= 1
    assert len(analisis.lineas_ayuda) >= 3
    assert any("113" in linea for linea in analisis.lineas_ayuda)
    assert any("106" in linea for linea in analisis.lineas_ayuda)
    assert not any("999-999-999" in linea for linea in analisis.lineas_ayuda)


@pytest.mark.parametrize(
    "mensaje",
    [
        "Tengo dudas sobre las fechas de matrícula del próximo ciclo",
        "Me siento estresado por el examen parcial de algoritmos",
        "Quisiera orientación sobre becas y apoyo económico",
    ],
)
def test_detector_urgencia_no_marca_mensajes_no_criticos(mensaje):
    analisis = UrgenciaDomainService.detectar(mensaje)

    assert analisis.es_urgente is False
    assert analisis.eleva_prioridad is False
    assert analisis.coincidencias == []
    assert analisis.lineas_ayuda == []


@pytest.mark.parametrize(
    "mensaje",
    [
        "No aguanto más este curso de cálculo",
        "No soporto más los exámenes finales",
        "Me corté el cabello ayer y estoy bien",
        "Me mata el calor de esta aula",
        "Mataron mi proyecto de tesis",
        "El profe me mata con tareas",
        "No vale la pena el esfuerzo",
        "No tiene sentido este ejercicio",
        "No le veo sentido a este curso",
        "Quiero matar el tiempo",
        "Voy a cortar el pelo",
        "Se cortó el internet",
        "Tengo que cortar las verduras",
        "Me quiero cortar el pelo",
    ],
)
def test_detector_urgencia_evita_falsos_positivos_no_vitales(mensaje):
    analisis = UrgenciaDomainService.detectar(mensaje)

    assert analisis.es_urgente is False
    assert analisis.coincidencias == []
    assert analisis.lineas_ayuda == []


def test_frustracion_academica_aguda_eleva_prioridad_sin_alerta_suicida():
    analisis = UrgenciaDomainService.detectar(
        "No aguanto más este curso de cálculo"
    )

    assert analisis.es_urgente is False
    assert analisis.eleva_prioridad is True
    assert analisis.lineas_ayuda == []


def test_detector_urgencia_permite_lineas_ayuda_configurables():
    lineas_custom = [
        "UNAYOE FISI: Anexo oficial 1234",
        "Línea 113 MINSA Opción 5",
    ]
    analisis = UrgenciaDomainService.detectar(
        "Necesito ayuda urgente, no aguanto más", help_lines=lineas_custom
    )

    assert analisis.es_urgente is True
    assert analisis.lineas_ayuda == lineas_custom


def test_clasificacion_inferencia_local_y_regla_urgencia(mocker):
    mock_repo = mocker.MagicMock()
    mock_repo.save.side_effect = lambda x: x

    mock_classifier = mocker.MagicMock()
    mock_classifier.predict.return_value = ("academico", "baja")

    use_cases = OrientacionUseCases(mock_repo, mock_classifier)

    # Caso normal: respeta predicción del clasificador
    result = use_cases.crear_solicitud(
        estudiante_id=123,
        mensaje="Tengo dudas con los exámenes y notas",
        comparte_evaluacion=False,
        eval_id=None,
    )
    solicitud = result["solicitud"]
    assert solicitud.tema_sugerido == "academico"
    assert solicitud.prioridad_sugerida == "baja"
    assert solicitud.urgencia_detectada is False
    mock_classifier.predict.assert_called_once_with(
        "Tengo dudas con los exámenes y notas"
    )

    # Caso crítico: urgencia fuerza prioridad 'alta' aunque ML sugiera 'baja'
    result_urg = use_cases.crear_solicitud(
        estudiante_id=123,
        mensaje="Quiero morir, no aguanto más",
        comparte_evaluacion=False,
        eval_id=None,
    )
    assert result_urg["solicitud"].urgencia_detectada is True
    assert result_urg["solicitud"].prioridad_sugerida == "alta"


def test_coherencia_evaluacion_y_no_reatencion(mocker):
    mock_repo = mocker.MagicMock()
    mock_classifier = mocker.MagicMock()
    use_cases = OrientacionUseCases(mock_repo, mock_classifier)

    with pytest.raises(ValidationError):
        use_cases.crear_solicitud(
            estudiante_id=10,
            mensaje="Consulta de prueba",
            comparte_evaluacion=True,
            eval_id=None,
        )

    with pytest.raises(ValidationError):
        use_cases.crear_solicitud(
            estudiante_id=10,
            mensaje="Consulta de prueba",
            comparte_evaluacion=False,
            eval_id=5,
        )

    ya_atendida = SolicitudOrientacion(
        id=1,
        estudiante_id=10,
        mensaje="Consulta",
        estado="atendida",
    )
    mock_repo.find_by_id.return_value = ya_atendida
    with pytest.raises(ConflictError):
        use_cases.atender_solicitud(
            solicitud_id=1,
            respuesta="Nueva respuesta",
            orientador_id=99,
            actor_role="PERSONAL_UNAYOE",
            tema_conf="academico",
            prio_conf="media",
        )


def test_atender_solicitud_concurrencia_atomica_lanza_conflicto(mocker):
    mock_repo = mocker.MagicMock()
    mock_repo.find_by_id.return_value = SolicitudOrientacion(
        id=99,
        estudiante_id=10,
        mensaje="Consulta pendiente al leer",
        estado="pendiente",
    )
    # Simula que otro worker ganó el UPDATE ... WHERE estado = 'pendiente'
    mock_repo.atender_si_pendiente.return_value = None

    use_cases = OrientacionUseCases(mock_repo, mocker.MagicMock())
    with pytest.raises(ConflictError):
        use_cases.atender_solicitud(
            solicitud_id=99,
            respuesta="Respuesta concurrente",
            orientador_id=77,
            actor_role="PERSONAL_UNAYOE",
            tema_conf="academico",
            prio_conf="alta",
        )


def test_scikit_classifier_fallback_cuando_no_hay_modelos(tmp_path):
    classifier = ScikitLocalClassifier(artifacts_dir=str(tmp_path))

    assert classifier.model_status == "keyword-fallback"
    tema, prioridad = classifier.predict("No puedo pagar la matrícula este ciclo")
    assert tema == "economico"
    assert prioridad in {"alta", "media", "baja"}
    assert classifier.predict("hola") == ("sin_clasificar", "baja")
    assert classifier.predict("asdfgh") == ("sin_clasificar", "baja")


def test_scikit_classifier_con_artefactos_reales_evita_ruido_y_ansiedad_familiar():
    classifier = ScikitLocalClassifier()
    assert classifier.model_status == "trained-tfidf-logreg"

    tema_ansiedad, _ = classifier.predict("Tengo mucha ansiedad por mis exámenes")
    assert tema_ansiedad == "ansiedad_estres"

    assert classifier.predict("hola") == ("sin_clasificar", "baja")
    assert classifier.predict("asdfgh") == ("sin_clasificar", "baja")
