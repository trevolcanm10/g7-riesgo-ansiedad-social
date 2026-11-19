import 'dart:convert';
import 'dart:io';

import 'package:ansiedad_ml_app/data/datasources/remote/api_service.dart';
import 'package:ansiedad_ml_app/data/repositories/academic_support_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M5 uses its real endpoints and Bearer JWT', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final calls = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final serving = server.forEach((request) async {
      calls.add(
        '${request.method} ${request.uri.path}${request.uri.hasQuery ? '?${request.uri.query}' : ''}',
      );
      expect(request.headers.value('authorization'), 'Bearer m5-test-token');
      final body = await utf8.decoder.bind(request).join();
      if (body.isNotEmpty) bodies.add(jsonDecode(body) as Map<String, dynamic>);
      Object response = <String, dynamic>{};
      if (request.uri.path == '/resources') {
        response = {
          'items': [
            {
              'id': 7,
              'type': 'WORKSHOP',
              'title': 'Manejo del estrés',
              'description': 'Taller',
              'availableSeats': 2,
            },
          ],
          'pagination': {'total': 1, 'limit': 20, 'offset': 0},
        };
      } else if (request.uri.path == '/recommendations') {
        response = {
          'items': [
            {
              'resource': {
                'id': 7,
                'type': 'WORKSHOP',
                'title': 'Manejo del estrés',
                'description': 'Taller',
              },
              'score': 0.8,
            },
          ],
        };
      } else if (request.uri.path == '/students/me/preferences') {
        response = {
          'interests': ['bienestar'],
          'courseCodes': [],
          'availableSlots': [],
          'preferredModalities': [],
          'timeZone': 'America/Lima',
        };
      } else if (request.uri.path == '/students/me/enrollments') {
        response = {
          'items': [
            {'resourceId': 7, 'status': 'ACTIVE'},
          ],
        };
      }
      if (request.method == 'POST') request.response.statusCode = 201;
      if (request.method == 'DELETE') request.response.statusCode = 204;
      request.response.headers.contentType = ContentType.json;
      if (request.response.statusCode != 204) {
        request.response.write(jsonEncode(response));
      }
      await request.response.close();
    });
    try {
      final repo = HttpAcademicSupportRepository(
        ApiService()..setToken('m5-test-token'),
        'http://127.0.0.1:${server.port}',
      );
      expect(
        (await repo.resources('WORKSHOP')).single.title,
        'Manejo del estrés',
      );
      expect((await repo.recommendations()).single.id, 7);
      expect((await repo.preferences())['interests'], ['bienestar']);
      await repo.savePreferences({
        'interests': ['estrés'],
        'courseCodes': [],
        'availableSlots': [],
        'preferredModalities': [],
        'timeZone': 'America/Lima',
      });
      await repo.interact(7, 'VIEW');
      await repo.enroll(7);
      expect(await repo.enrollments(), {7});
      await repo.cancelEnrollment(7);
      expect(
        calls,
        containsAll([
          'GET /resources?type=WORKSHOP',
          'GET /recommendations',
          'GET /students/me/preferences',
          'PUT /students/me/preferences',
          'POST /interactions',
          'POST /workshops/7/enroll',
          'GET /students/me/enrollments',
          'DELETE /workshops/7/enroll',
        ]),
      );
      expect(bodies[1], {'resourceId': 7, 'eventType': 'VIEW'});
    } finally {
      await server.close(force: true);
      await serving;
    }
  });
}
