from unittest.mock import patch

from tests.conftest import auth_headers


def test_health_endpoint_ok_y_modelo_cargado(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.get_json()
    assert data["service"] == "orientacion"
    assert data["status"] == "OK"
    assert data["database"] == "OK"
    assert data["classifierModel"] == "trained-tfidf-logreg"


def test_autenticacion_y_autorizacion_por_roles(client):
    # Sin token -> 401
    assert (
        client.post("/api/v1/orientacion/solicitudes", json={"mensaje": "Hola"}).status_code
        == 401
    )
    assert client.get("/api/v1/orientacion/solicitudes").status_code == 401

    # Token expirado -> 401
    expired = auth_headers(user_id=10, role="ESTUDIANTE", exp_offset_seconds=-60)
    assert (
        client.get("/api/v1/orientacion/solicitudes", headers=expired).status_code == 401
    )

    # Token con firma incorrecta -> 401
    wrong_sig = auth_headers(
        user_id=10, role="ESTUDIANTE", secret="otro-secreto-invalido-1234567890"
    )
    assert (
        client.get("/api/v1/orientacion/solicitudes", headers=wrong_sig).status_code
        == 401
    )

    # Personal UNAYOE intentando crear solicitud -> 403
    staff_headers = auth_headers(user_id=900, role="PERSONAL_UNAYOE")
    resp_staff_post = client.post(
        "/api/v1/orientacion/solicitudes",
        headers=staff_headers,
        json={"mensaje": "Mensaje de prueba"},
    )
    assert resp_staff_post.status_code == 403

    # Estudiante intenta atender o ver métricas -> 403
    est_headers = auth_headers(user_id=101, role="ESTUDIANTE")
    resp_est_patch = client.patch(
        "/api/v1/orientacion/solicitudes/1/atender",
        headers=est_headers,
        json={"respuesta_escrita": "Intento no autorizado"},
    )
    assert resp_est_patch.status_code == 403

    resp_est_metrics = client.get(
        "/api/v1/orientacion/solicitudes/metricas/conteo-temas",
        headers=est_headers,
    )
    assert resp_est_metrics.status_code == 403


def test_aislamiento_entre_estudiantes_y_jwt_identidad(client):
    est_1 = auth_headers(user_id=101, role="ESTUDIANTE")
    est_2 = auth_headers(user_id=202, role="ESTUDIANTE")

    # No permite suplantar estudiante_id en el body (extra="forbid")
    resp_spoof = client.post(
        "/api/v1/orientacion/solicitudes",
        headers=est_1,
        json={"estudiante_id": 999, "mensaje": "Intento de suplantación"},
    )
    assert resp_spoof.status_code == 400

    # Estudiante 1 crea una solicitud válida; estudiante_id proviene del JWT (101)
    resp_c1 = client.post(
        "/api/v1/orientacion/solicitudes",
        headers=est_1,
        json={"mensaje": "Necesito orientación sobre mi carga académica"},
    )
    assert resp_c1.status_code == 201
    sol1 = resp_c1.get_json()
    assert sol1["estudiante_id"] == 101

    # Estudiante 2 crea su propia solicitud
    resp_c2 = client.post(
        "/api/v1/orientacion/solicitudes",
        headers=est_2,
        json={"mensaje": "Tengo problemas económicos con la matrícula"},
    )
    assert resp_c2.status_code == 201
    sol2 = resp_c2.get_json()

    # Estudiante 1 lista: solo ve la suya aunque intente pasar ?estudiante_id=202
    resp_list_1 = client.get(
        "/api/v1/orientacion/solicitudes?estudiante_id=202", headers=est_1
    )
    assert resp_list_1.status_code == 200
    items = resp_list_1.get_json()
    assert len(items) == 1
    assert items[0]["id"] == sol1["id"]

    # Estudiante 1 intentando ver detalle de solicitud de Estudiante 2 -> 404
    resp_other = client.get(
        f"/api/v1/orientacion/solicitudes/{sol2['id']}", headers=est_1
    )
    assert resp_other.status_code == 404


def test_validacion_campos_y_coherencia_evaluacion(client):
    est = auth_headers(user_id=101, role="ESTUDIANTE")

    # Cuerpo vacío o sin mensaje
    assert (
        client.post("/api/v1/orientacion/solicitudes", headers=est, json={}).status_code
        == 400
    )
    # Mensaje solo espacios
    assert (
        client.post(
            "/api/v1/orientacion/solicitudes",
            headers=est,
            json={"mensaje": "   "},
        ).status_code
        == 400
    )
    # Mensaje excede 1500 caracteres
    assert (
        client.post(
            "/api/v1/orientacion/solicitudes",
            headers=est,
            json={"mensaje": "a" * 1501},
        ).status_code
        == 400
    )
    # comparte_evaluacion_riesgo=True sin evaluacion_riesgo_id
    assert (
        client.post(
            "/api/v1/orientacion/solicitudes",
            headers=est,
            json={"mensaje": "Hola", "comparte_evaluacion_riesgo": True},
        ).status_code
        == 400
    )
    # comparte_evaluacion_riesgo=False con evaluacion_riesgo_id presente
    assert (
        client.post(
            "/api/v1/orientacion/solicitudes",
            headers=est,
            json={
                "mensaje": "Hola",
                "comparte_evaluacion_riesgo": False,
                "evaluacion_riesgo_id": 12,
            },
        ).status_code
        == 400
    )
    # JSON malformado
    resp_bad_json = client.post(
        "/api/v1/orientacion/solicitudes",
        headers={**est, "Content-Type": "application/json"},
        data="{invalido",
    )
    assert resp_bad_json.status_code == 400


def test_creacion_solicitud_con_urgencia_y_sin_telefonos_ficticios(client):
    est = auth_headers(user_id=303, role="ESTUDIANTE")
    response = client.post(
        "/api/v1/orientacion/solicitudes",
        headers=est,
        json={"mensaje": "No me siento segura en mi casa, quiero morir"},
    )
    assert response.status_code == 201
    data = response.get_json()

    assert data["urgencia_detectada"] is True
    assert data["prioridad_sugerida"] == "alta"
    assert "alertas_urgencia" in data
    lineas = data["alertas_urgencia"]["lineas_ayuda"]
    assert any("113" in linea for linea in lineas)
    assert not any("999-999-999" in linea for linea in lineas)


def test_flujo_completo_atencion_conflicto_y_metricas(client):
    est = auth_headers(user_id=555, role="ESTUDIANTE")
    staff = auth_headers(user_id=77, role="PERSONAL_UNAYOE")

    # 1. Crear solicitud con ML local real
    resp_create = client.post(
        "/api/v1/orientacion/solicitudes",
        headers=est,
        json={
            "mensaje": "No puedo pagar la matrícula este ciclo",
            "comparte_evaluacion_riesgo": True,
            "evaluacion_riesgo_id": 42,
        },
    )
    assert resp_create.status_code == 201
    creada = resp_create.get_json()
    sol_id = creada["id"]
    assert creada["tema_sugerido"] == "economico"
    assert creada["evaluacion_riesgo_id"] == 42

    # 2. Staff intenta enviar atendido_por en payload (debe rechazarse)
    resp_forbid_extra = client.patch(
        f"/api/v1/orientacion/solicitudes/{sol_id}/atender",
        headers=staff,
        json={"respuesta_escrita": "OK", "atendido_por": 999},
    )
    assert resp_forbid_extra.status_code == 400

    # 3. Staff atiende correctamente; atendido_por sale del JWT (77)
    resp_patch = client.patch(
        f"/api/v1/orientacion/solicitudes/{sol_id}/atender",
        headers=staff,
        json={
            "respuesta_escrita": "Te hemos derivado con la asistenta social",
            "tema_confirmado": "economico",
            "prioridad_confirmada": "alta",
        },
    )
    assert resp_patch.status_code == 200
    actualizada = resp_patch.get_json()
    assert actualizada["estado"] == "atendida"
    assert actualizada["atendido_por"] == 77
    assert actualizada["tema_confirmado"] == "economico"
    assert actualizada["prioridad_confirmada"] == "alta"
    assert actualizada["fecha_atencion"] is not None

    # 4. Re-atender una solicitud ya atendida -> 409 Conflict
    resp_repatch = client.patch(
        f"/api/v1/orientacion/solicitudes/{sol_id}/atender",
        headers=staff,
        json={"respuesta_escrita": "Intento de sobrescritura"},
    )
    assert resp_repatch.status_code == 409

    # 5. Filtrado por prioridad efectiva + paginación
    resp_list = client.get(
        "/api/v1/orientacion/solicitudes?prioridad=alta&estudiante_id=555&limit=10&offset=0",
        headers=staff,
    )
    assert resp_list.status_code == 200
    lista = resp_list.get_json()
    assert len(lista) == 1
    assert lista[0]["id"] == sol_id

    # Query inválida -> 400
    assert (
        client.get(
            "/api/v1/orientacion/solicitudes?estado=invalido", headers=staff
        ).status_code
        == 400
    )

    # 6. Métricas de conteo por tema
    resp_metricas = client.get(
        "/api/v1/orientacion/solicitudes/metricas/conteo-temas", headers=staff
    )
    assert resp_metricas.status_code == 200
    assert resp_metricas.get_json() == [{"tema": "economico", "cantidad": 1}]


def test_error_500_no_filtra_detalles_internos(app, client):
    app.config["PROPAGATE_EXCEPTIONS"] = False
    est = auth_headers(user_id=101, role="ESTUDIANTE")

    with patch(
        "app.infrastructure.persistence.repository.SQLAlchemySolicitudRepository.find_all",
        side_effect=RuntimeError("SELECT * FROM secretos_internos falló"),
    ):
        resp = client.get("/api/v1/orientacion/solicitudes", headers=est)

    assert resp.status_code == 500
    body = resp.get_json()
    assert body == {"message": "Error interno del servidor"}
    assert "secretos_internos" not in str(body)
