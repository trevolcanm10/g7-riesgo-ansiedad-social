import 'dart:async';

import 'package:ansiedad_ml_app/core/app_colors.dart';
import 'package:ansiedad_ml_app/data/repositories/academic_support_repository.dart';
import 'package:ansiedad_ml_app/presentation/pages/academic_support/academic_support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeSupport implements AcademicSupportRepository {
  bool fail = false;
  bool empty = false;
  bool enrolled = false;
  bool includeSynthetic = false;
  Completer<void>? wait;
  final workshop = const SupportResource(
    id: 7,
    type: 'WORKSHOP',
    title: 'Manejo del estrés',
    description: 'Encuentro preventivo',
    availableSeats: 4,
  );
  final syntheticWorkshop = const SupportResource(
    id: 8,
    type: 'WORKSHOP',
    title: 'Taller de ejemplo',
    description: 'Datos de prueba',
    isSynthetic: true,
  );
  @override
  Future<List<SupportResource>> resources(String type) async {
    await wait?.future;
    if (fail) throw StateError('Sin conexión');
    return empty ? [] : [workshop, if (includeSynthetic) syntheticWorkshop];
  }

  @override
  Future<List<SupportResource>> recommendations() async =>
      includeSynthetic ? [syntheticWorkshop] : [workshop];
  @override
  Future<Map<String, dynamic>> preferences() async => {
    'interests': <String>[],
    'courseCodes': <String>[],
    'availableSlots': <dynamic>[],
    'preferredModalities': <String>[],
    'timeZone': 'America/Lima',
  };
  @override
  Future<void> savePreferences(Map<String, dynamic> value) async {}
  @override
  Future<void> interact(int id, String eventType) async {}
  @override
  Future<void> enroll(int id) async {
    enrolled = true;
  }

  @override
  Future<void> cancelEnrollment(int id) async {
    enrolled = false;
  }

  @override
  Future<Set<int>> enrollments() async => enrolled ? {7} : {};
}

Future<void> showCatalog(WidgetTester tester, FakeSupport repo) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: AcademicSupportCatalogScreen(repository: repo, initialTab: 2),
    ),
  );
}

void main() {
  testWidgets('student catalog hides synthetic resources and recommendations', (tester) async {
    final repo = FakeSupport()..includeSynthetic = true;
    await showCatalog(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Manejo del estrés'), findsOneWidget);
    expect(find.text('Taller de ejemplo'), findsNothing);
    expect(find.text('RECOMENDADO PARA TI'), findsNothing);
  });

  testWidgets('support hub keeps existing Orientation access', (tester) async {
    final repo = FakeSupport();
    await tester.pumpWidget(Provider<AcademicSupportRepository>.value(
      value: repo,
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const AcademicSupportScreen(),
        routes: {'/orientacion': (_) => const Scaffold(body: Text('Orientación existente'))},
      ),
    ));
    expect(find.text('Recursos de bienestar'), findsOneWidget);
    expect(find.text('Tutorías entre pares'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Talleres universitarios'), 200);
    expect(find.text('Talleres universitarios'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Orientación UNAYOE'), 200);
    await tester.tap(find.text('Orientación UNAYOE'));
    await tester.pumpAndSettle();
    expect(find.text('Orientación existente'), findsOneWidget);
  });

  testWidgets('catalog shows loading, data and workshop enrollment', (
    tester,
  ) async {
    final repo = FakeSupport()..wait = Completer<void>();
    await showCatalog(tester, repo);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.wait!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Manejo del estrés'), findsOneWidget);
    await tester.tap(find.text('Inscribirme'));
    await tester.pumpAndSettle();
    expect(repo.enrolled, isTrue);
    expect(find.text('Cancelar inscripción'), findsOneWidget);
  });

  testWidgets('catalog shows error and empty states', (tester) async {
    final repo = FakeSupport()..fail = true;
    await showCatalog(tester, repo);
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo conectar'), findsOneWidget);
    repo.fail = false;
    repo.empty = true;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aún no hay contenidos'), findsOneWidget);
  });
}
