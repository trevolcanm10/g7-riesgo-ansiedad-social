import pytest

def test_validacion_campos_obligatorios(client):
    # Escenario 3: Comprobar error 400 si falta 'mensaje' o 'estudiante_id'

    # Intento 1: Faltan ambos campos
    resp1 = client.post('/api/v1/orientacion/solicitudes', json={})
    assert resp1.status_code == 400
    assert "Errores de validación" in resp1.get_json()["error"]

    # Intento 2: Falta mensaje
    resp2 = client.post('/api/v1/orientacion/solicitudes', json={
        "estudiante_id": "123"
    })
    assert resp2.status_code == 400

    # Intento 3: Falta estudiante_id
    resp3 = client.post('/api/v1/orientacion/solicitudes', json={
        "mensaje": "Hola necesito orientacion"
    })
    assert resp3.status_code == 400


def test_creacion_solicitud_con_urgencia(client):
    # Escenario 2 (Integración): Verificar respuesta HTTP ante mensaje urgente

    response = client.post('/api/v1/orientacion/solicitudes', json={
        "estudiante_id": "999",
        "mensaje": "Tengo mucho miedo, no me siento seguro"
    })

    assert response.status_code == 201
    data = response.get_json()

    assert data["urgencia_detectada"] is True
    # El detector heurístico debe haber forzado la prioridad a 'alta'
    assert data["prioridad_sugerida"] == "alta"
    # Debe retornar el bloque de alerta
    assert "alertas_urgencia" in data
    assert len(data["alertas_urgencia"]["lineas_ayuda"]) > 0


def test_flujo_completo_atencion(client):
    # Escenario 4: Flujo de atención completo (Crear -> Patch Atender)

    # 1. Crear solicitud
    resp_create = client.post('/api/v1/orientacion/solicitudes', json={
        "estudiante_id": "555",
        "mensaje": "Problemas para pagar mi matrícula"
    })
    assert resp_create.status_code == 201

    solicitud_creada = resp_create.get_json()
    sol_id = solicitud_creada["id"]
    assert solicitud_creada["estado"] == "pendiente"
    assert solicitud_creada["atendido_por"] is None

    # 2. Atender solicitud
    resp_patch = client.patch(f'/api/v1/orientacion/solicitudes/{sol_id}/atender', json={
        "respuesta_escrita": "Te hemos derivado con la asistenta social",
        "atendido_por": "Lic. María",
        "tema_confirmado": "economico",
        "prioridad_confirmada": "alta"
    })

    assert resp_patch.status_code == 200
    solicitud_actualizada = resp_patch.get_json()

    # Validaciones del cambio de estado
    assert solicitud_actualizada["estado"] == "atendida"
    assert solicitud_actualizada["respuesta_escrita"] == "Te hemos derivado con la asistenta social"
    assert solicitud_actualizada["atendido_por"] == "Lic. María"
    assert solicitud_actualizada["tema_confirmado"] == "economico"
    assert solicitud_actualizada["prioridad_confirmada"] == "alta"
    assert solicitud_actualizada["fecha_atencion"] is not None

    # 3. Verificar filtrado por prioridad efectiva (prioridad_confirmada) y estudiante_id
    resp_list = client.get('/api/v1/orientacion/solicitudes?prioridad=alta&estudiante_id=555')
    assert resp_list.status_code == 200
    lista = resp_list.get_json()
    assert len(lista) == 1
    assert lista[0]["id"] == sol_id
