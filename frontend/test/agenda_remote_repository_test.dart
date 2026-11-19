import 'dart:convert';
import 'dart:io';

import 'package:ansiedad_ml_app/data/datasources/remote/api_service.dart';
import 'package:ansiedad_ml_app/data/repositories/agenda_remote_repository.dart';
import 'package:ansiedad_ml_app/domain/entities/actividad_academica.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remote agenda uses Flask CRUD JSON, integer IDs and Bearer JWT', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final activities = <Map<String, dynamic>>[];
    final serving = server.forEach((request) async {
      requests.add('${request.method} ${request.uri.path}');
      expect(request.headers.value('authorization'), 'Bearer test-jwt');
      final text = await utf8.decoder.bind(request).join();
      if (text.isNotEmpty) bodies.add(jsonDecode(text) as Map<String, dynamic>);
      Object response;
      if (request.method == 'GET') {
        response = activities;
      } else if (request.method == 'POST') {
        final created = <String, dynamic>{'id': 7, 'user_id': 3, ...bodies.last};
        activities.add(created);
        request.response.statusCode = 201;
        response = created;
      } else if (request.method == 'PATCH') {
        activities[0] = {...activities[0], ...bodies.last};
        response = activities[0];
      } else {
        activities.clear();
        response = {'mensaje': 'Actividad eliminada'};
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
    try {
      final api = ApiService()..setToken('test-jwt');
      final repo = AgendaRemoteRepository(
        api,
        'http://127.0.0.1:${server.port}/actividades',
      );
      expect(await repo.obtener(), isEmpty);
      final item = ActividadAcademica(
        id: 'local-1', titulo: 'Examen', curso: 'Álgebra', tipo: 'examen',
        fecha: DateTime(2026, 11, 15), hora: null,
        duracionEstimadaHoras: 2, prioridad: 'alta', descripcion: 'Tema 1',
        completada: false,
      );
      await repo.guardar([item]);
      expect(bodies.first['activity_date'], '2026-11-15');
      expect(bodies.first['estimated_hours'], 2);
      expect(bodies.first['title'], 'Examen');
      expect(bodies.first.containsKey('actividades'), isFalse);
      final created = (await repo.obtener()).single;
      expect(created.id, '7');
      expect(created.fecha, DateTime(2026, 11, 15));
      await repo.guardar([created.copyWith(completada: true)]);
      expect(bodies.last['completed'], isTrue);
      await repo.guardar([]);
      expect(await repo.obtener(), isEmpty);
      expect(requests, containsAllInOrder([
        'POST /actividades', 'PATCH /actividades/7', 'DELETE /actividades/7',
      ]));
    } finally {
      await server.close(force: true);
      await serving;
    }
  });

  test('classification and alerts use Flask indicators and levels', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final seen = <String, Map<String, dynamic>>{};
    final serving = server.forEach((request) async {
      expect(request.headers.value('authorization'), 'Bearer test-jwt');
      final body = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      seen[request.uri.path] = body;
      final response = request.uri.path == '/clasificacion/semanal'
          ? {
              'nivel_carga': 'MODERADA',
              'probabilidad_nivel': 0.8,
              'probabilidades': {'BAJA': 0.1, 'MODERADA': 0.8, 'ALTA': 0.1},
              'modelo': 'clasificador_semanal',
            }
          : {
              'nivel_carga': 'MODERADA',
              'alertas': [
                {'codigo': 'AB-002', 'mensaje': 'Reparte tareas', 'severidad': 'advertencia'},
              ],
              'recomendacion': 'Planifica descansos',
            };
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
    try {
      final api = ApiService()..setToken('test-jwt');
      final repo = AgendaRemoteRepository(
        api, 'http://127.0.0.1:${server.port}/actividades',
      );
      final indicators = <String, num>{
        'horas_totales': 12, 'num_actividades': 3, 'num_examenes': 1,
        'num_entregas': 1, 'num_urgentes_48h': 0, 'num_prioridad_alta': 2,
        'dias_con_actividades': 2, 'max_horas_dia': 7,
        'concentracion_3dias': 0.8, 'num_sin_duracion': 0,
      };
      final classification = await repo.clasificarSemana(indicators);
      final alerts = await repo.obtenerAlertas(indicators);
      expect(classification.nivel, 'MODERADA');
      expect(classification.probabilidades['MODERADA'], 0.8);
      expect(alerts.nivel, 'MODERADA');
      expect(alerts.alertas.single['codigo'], 'AB-002');
      expect(seen['/clasificacion/semanal'], indicators);
      expect(seen['/alertas/preventivas'], indicators);
    } finally {
      await server.close(force: true);
      await serving;
    }
  });
}
