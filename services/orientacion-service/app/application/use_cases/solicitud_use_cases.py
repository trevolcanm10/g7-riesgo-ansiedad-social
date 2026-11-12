from typing import Dict, Iterable, List, Optional

from app.application.interfaces.ml_classifier_port import IMLClassifier
from app.application.interfaces.solicitud_repository_port import ISolicitudRepository
from app.domain.entities.solicitud import (
    ESTADOS_VALIDOS,
    PRIORIDADES_VALIDAS,
    Role,
    SolicitudOrientacion,
    TEMAS_VALIDOS,
    utc_now,
)
from app.domain.entities.urgencia_service import UrgenciaDomainService
from app.domain.errors import ConflictError, ForbiddenError, NotFoundError, ValidationError

STAFF_ROLES = {Role.PERSONAL_UNAYOE.value, Role.ADMINISTRADOR.value}


class OrientacionUseCases:
    def __init__(
        self,
        repository: ISolicitudRepository,
        classifier: IMLClassifier,
        help_lines: Optional[Iterable[str]] = None,
    ):
        self.repository = repository
        self.classifier = classifier
        self.help_lines = list(help_lines) if help_lines is not None else None

    def crear_solicitud(
        self,
        estudiante_id: int,
        mensaje: str,
        comparte_evaluacion: bool,
        eval_id: Optional[int],
    ) -> Dict:
        if isinstance(estudiante_id, bool) or not isinstance(estudiante_id, int) or estudiante_id <= 0:
            raise ValidationError("Identificador de estudiante inválido")

        texto_limpio = mensaje.strip() if isinstance(mensaje, str) else ""
        if not texto_limpio:
            raise ValidationError("El mensaje no puede estar vacío")

        if comparte_evaluacion and (eval_id is None or eval_id <= 0):
            raise ValidationError(
                "Debes indicar un evaluacion_riesgo_id válido cuando compartes tu evaluación"
            )
        if not comparte_evaluacion and eval_id is not None:
            raise ValidationError(
                "No puedes enviar evaluacion_riesgo_id si comparte_evaluacion_riesgo es false"
            )

        # Análisis de Dominio (independiente del clasificador ML)
        urgencia = UrgenciaDomainService.detectar(texto_limpio, help_lines=self.help_lines)

        # Inferencia local ML
        tema_sug, prioridad_sug = self.classifier.predict(texto_limpio)

        # Regla de Negocio: una urgencia crítica o sobrecarga aguda fuerza prioridad alta
        if urgencia.es_urgente or urgencia.eleva_prioridad:
            prioridad_sug = "alta"

        solicitud = SolicitudOrientacion(
            estudiante_id=estudiante_id,
            mensaje=texto_limpio,
            comparte_evaluacion_riesgo=comparte_evaluacion,
            evaluacion_riesgo_id=eval_id if comparte_evaluacion else None,
            tema_sugerido=tema_sug,
            prioridad_sugerida=prioridad_sug,
            urgencia_detectada=urgencia.es_urgente,
        )

        guardada = self.repository.save(solicitud)

        return {
            "solicitud": guardada,
            "urgencia": urgencia if urgencia.es_urgente else None,
        }

    def listar_solicitudes(
        self,
        actor_id: int,
        actor_role: str,
        estado: Optional[str] = None,
        prioridad: Optional[str] = None,
        estudiante_id: Optional[int] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[SolicitudOrientacion]:
        if estado is not None and estado not in ESTADOS_VALIDOS:
            raise ValidationError(
                f"estado debe ser uno de: {', '.join(ESTADOS_VALIDOS)}"
            )
        if prioridad is not None and prioridad not in PRIORIDADES_VALIDAS:
            raise ValidationError(
                f"prioridad debe ser una de: {', '.join(PRIORIDADES_VALIDAS)}"
            )
        if limit < 1 or limit > 100:
            raise ValidationError("limit debe estar entre 1 y 100")
        if offset < 0:
            raise ValidationError("offset debe ser mayor o igual a 0")

        if actor_role == Role.ESTUDIANTE.value:
            filtro_estudiante = actor_id
        elif actor_role in STAFF_ROLES:
            filtro_estudiante = estudiante_id
        else:
            raise ForbiddenError("No tienes permisos para listar solicitudes")

        return self.repository.find_all(
            estado=estado,
            prioridad=prioridad,
            estudiante_id=filtro_estudiante,
            limit=limit,
            offset=offset,
        )

    def obtener_solicitud(
        self, solicitud_id: int, actor_id: int, actor_role: str
    ) -> SolicitudOrientacion:
        solicitud = self.repository.find_by_id(solicitud_id)
        if not solicitud:
            raise NotFoundError("Solicitud no encontrada")

        if actor_role == Role.ESTUDIANTE.value and solicitud.estudiante_id != actor_id:
            # Responder 404 para no revelar si existe una solicitud de otro estudiante
            raise NotFoundError("Solicitud no encontrada")

        if actor_role != Role.ESTUDIANTE.value and actor_role not in STAFF_ROLES:
            raise ForbiddenError("No tienes permisos para consultar esta solicitud")

        return solicitud

    def atender_solicitud(
        self,
        solicitud_id: int,
        respuesta: str,
        orientador_id: int,
        actor_role: str,
        tema_conf: Optional[str],
        prio_conf: Optional[str],
    ) -> SolicitudOrientacion:
        if actor_role not in STAFF_ROLES:
            raise ForbiddenError("Solo el personal autorizado puede atender solicitudes")

        if tema_conf is not None and tema_conf not in TEMAS_VALIDOS:
            raise ValidationError(
                f"tema_confirmado debe ser uno de: {', '.join(TEMAS_VALIDOS)}"
            )
        if prio_conf is not None and prio_conf not in PRIORIDADES_VALIDAS:
            raise ValidationError(
                f"prioridad_confirmada debe ser una de: {', '.join(PRIORIDADES_VALIDAS)}"
            )

        solicitud = self.repository.find_by_id(solicitud_id)
        if not solicitud:
            raise NotFoundError("Solicitud no encontrada")

        if solicitud.estado == "atendida":
            raise ConflictError("La solicitud ya fue atendida y no puede sobrescribirse")

        actualizada = self.repository.atender_si_pendiente(
            solicitud_id=solicitud_id,
            respuesta_escrita=respuesta.strip(),
            atendido_por=orientador_id,
            fecha_atencion=utc_now(),
            tema_confirmado=tema_conf,
            prioridad_confirmada=prio_conf,
        )
        if actualizada is None:
            raise ConflictError("La solicitud ya fue atendida y no puede sobrescribirse")
        return actualizada

    def metricas_temas(self, actor_role: str) -> List[dict]:
        if actor_role not in STAFF_ROLES:
            raise ForbiddenError("Solo el personal autorizado puede consultar métricas")
        return self.repository.count_by_tema()
