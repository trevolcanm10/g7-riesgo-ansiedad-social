import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ansiedad_ml_app/core/app_colors.dart';
import 'package:ansiedad_ml_app/domain/entities/evaluacion.dart';
import 'package:ansiedad_ml_app/domain/entities/resultado_ml.dart';
import 'package:ansiedad_ml_app/domain/entities/recomendacion.dart';
import 'package:ansiedad_ml_app/domain/repositories/evaluacion_repository.dart';
import 'package:ansiedad_ml_app/domain/usecases/evaluar_riesgo_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/obtener_historial_usecase.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/evaluacion_viewmodel.dart';
import 'package:ansiedad_ml_app/presentation/pages/evaluacion/evaluacion_screen.dart';

class FormRepository implements EvaluacionRepository {
  Map<String, num>? sent;
  bool failNext = true;
  int calls = 0;
  @override
  Future<List<Evaluacion>> obtenerHistorial() async => [];
  @override
  Future<
    ({
      ResultadoMl resultado,
      List<Recomendacion> recomendaciones,
      String? explicacion,
    })
  >
  evaluarRiesgo(Map<String, num> variables) async {
    sent = Map.of(variables);
    calls++;
    if (failNext) {
      failNext = false;
      throw Exception('El servicio no está disponible. Reintenta.');
    }
    return (
      resultado: ResultadoMl(
        idResultado: 1,
        idEvaluacion: 1,
        idUsuario: 1,
        probabilidadAnsiedad: 0.42,
        nivelRiesgo: 'MEDIO',
      ),
      recomendaciones: <Recomendacion>[],
      explicacion: 'Prueba',
    );
  }
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.text('Siguiente'));
  await tester.pumpAndSettle();
}

Future<void> answer(
  WidgetTester tester,
  String section,
  int count,
  int score,
) async {
  for (var i = 0; i < count; i++) {
    final chip = find.byKey(ValueKey('$section-$i-$score'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'requiere todos los items, conserva respuestas y envia solo totales y GPA',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FormRepository();
      final vm = EvaluacionViewModel(
        EvaluarRiesgoUseCase(repo),
        ObtenerHistorialUseCase(repo),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: vm,
          child: MaterialApp(
            theme: ThemeData(extensions: const [AppColors.light]),
            home: const EvaluacionScreen(),
            routes: {
              '/resultado': (_) =>
                  const Scaffold(body: Text('Resultado de prueba')),
            },
          ),
        ),
      );
      await next(tester);
      expect(find.text('Pregunta 1 de 15'), findsOneWidget);
      expect(repo.sent, isNull);
      await answer(tester, 'phq9_score', 9, 3);
      await next(tester);
      expect(find.text('Pregunta 2 de 15'), findsOneWidget);
      await next(tester);
      expect(find.text('Pregunta 2 de 15'), findsOneWidget);
      await answer(tester, 'gad7_score', 7, 2);
      await tester.tap(find.text('Atrás'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 9; i++) {
        expect(
          tester
              .widget<ChoiceChip>(find.byKey(ValueKey('phq9_score-$i-3')))
              .selected,
          isTrue,
        );
      }
      await next(tester);
      for (var i = 0; i < 7; i++) {
        expect(
          tester
              .widget<ChoiceChip>(find.byKey(ValueKey('gad7_score-$i-2')))
              .selected,
          isTrue,
        );
      }
      for (var i = 0; i < 5; i++) {
        await next(tester);
      }
      expect(find.text('Pregunta 7 de 15'), findsOneWidget);
      await next(tester);
      expect(find.text('Pregunta 7 de 15'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '10');
      await next(tester);
      await tester.tap(find.text('Atrás'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '10',
      );
      for (var i = 0; i < 8; i++) {
        await next(tester);
      }
      await tester.tap(find.text('Terminar Test'));
      await tester.pumpAndSettle();
      expect(find.text('Resultado de prueba'), findsNothing);
      expect(
        find.text('El servicio no está disponible. Reintenta.'),
        findsOneWidget,
      );
      final firstPayload = Map<String, num>.of(repo.sent!);
      // Wait for the failure notice to leave the button unobstructed.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminar Test'));
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(repo.sent, firstPayload);
      // Contrato camelCase de RiskEvaluation: 15 campos, enteros salvo GPA.
      expect(repo.sent!.length, 15);
      expect(repo.sent!['phq9Score'], 27);
      expect(repo.sent!['gad7Score'], 14);
      expect(repo.sent!['gpa'], 2.5);
      for (final key in const [
        'sleepHours',
        'exerciseFreq',
        'socialActivity',
        'onlineStress',
        'familySupport',
        'screenTime',
        'academicStress',
        'dietQuality',
        'selfEfficacy',
        'peerRelationship',
        'financialStress',
        'sleepQuality',
      ]) {
        expect(repo.sent![key], isA<int>(), reason: key);
      }
      expect(find.text('Resultado de prueba'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
