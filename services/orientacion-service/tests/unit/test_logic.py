import pytest
from app.domain.entities.urgencia_service import UrgenciaDomainService
from app.application.use_cases.solicitud_use_cases import OrientacionUseCases
from app.domain.entities.solicitud import SolicitudOrientacion

def test_detector_urgencia_detecta_frase_critica():
    # Escenario 2: Detector de urgencia
    mensaje = "Hola, no me siento seguro en casa y estoy asustado"

    analisis = UrgenciaDomainService.detectar(mensaje)

    assert analisis.es_urgente is True
    assert "no me siento seguro" in analisis.coincidencias[0]
    assert len(analisis.lineas_ayuda) > 0
    assert any("113" in linea for linea in analisis.lineas_ayuda)

def test_clasificacion_inferencia_local(mocker):
    # Escenario 1: Test de clasificación usando mocks (Aislamiento de Lógica)

    # Mock del Repositorio (no tocar la base de datos real)
    mock_repo = mocker.MagicMock()
    mock_repo.save.side_effect = lambda x: x # devuelve la misma entidad guardada

    # Mock del Clasificador ML (Inyección de dependencias falsa para controlar el resultado)
    mock_classifier = mocker.MagicMock()
    mock_classifier.predict.return_value = ("academico", "baja")

    use_cases = OrientacionUseCases(mock_repo, mock_classifier)

    result = use_cases.crear_solicitud(
        estudiante_id="123",
        mensaje="tengo dudas con los exámenes y notas",
        comparte_evaluacion=False,
        eval_id=None
    )

    # Afirmaciones
    solicitud = result["solicitud"]
    assert solicitud.tema_sugerido == "academico"
    assert solicitud.prioridad_sugerida == "baja"
    assert solicitud.urgencia_detectada is False

    # Comprobar que el caso de uso llamó al modelo de machine learning correctamente
    mock_classifier.predict.assert_called_once_with("tengo dudas con los exámenes y notas")
