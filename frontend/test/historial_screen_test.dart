import 'package:ansiedad_ml_app/core/app_colors.dart';
import 'package:ansiedad_ml_app/domain/entities/evaluacion.dart';
import 'package:ansiedad_ml_app/domain/entities/recomendacion.dart';
import 'package:ansiedad_ml_app/domain/entities/reporte_ia.dart';
import 'package:ansiedad_ml_app/domain/entities/resultado_ml.dart';
import 'package:ansiedad_ml_app/domain/entities/shap_explanation.dart';
import 'package:ansiedad_ml_app/domain/repositories/evaluacion_repository.dart';
import 'package:ansiedad_ml_app/domain/usecases/evaluar_riesgo_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/obtener_historial_usecase.dart';
import 'package:ansiedad_ml_app/presentation/pages/evaluacion/historial_screen.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/evaluacion_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Repo implements EvaluacionRepository {
  _Repo(this.records, {this.fail = false});
  final List<Evaluacion> records;
  final bool fail;
  int reads = 0;
  @override
  Future<List<Evaluacion>> obtenerHistorial() async {
    reads++;
    if (fail) throw Exception('Error de prueba');
    return records;
  }

  @override
  Future<
    ({
      ResultadoMl resultado,
      List<Recomendacion> recomendaciones,
      String? explicacion,
    })
  >
  evaluarRiesgo(Map<String, num> variables) => throw UnimplementedError();
}

Evaluacion _evaluation(
  int id,
  String date,
  double probability, {
  String level = 'BAJO',
  bool oldRecord = false,
  bool shapFailed = false,
  ReporteIA? report,
}) => Evaluacion(
  idEvaluacion: id,
  idUsuario: 1,
  fechaRealizacion: date,
  phq9Score: 0,
  gad7Score: 0,
  sleepHours: 8,
  exerciseFreq: 0,
  socialActivity: 0,
  onlineStress: 0,
  gpa: 15,
  familySupport: 0,
  screenTime: 0,
  academicStress: 0,
  dietQuality: 0,
  selfEfficacy: 0,
  peerRelationship: 0,
  financialStress: 0,
  sleepQuality: 0,
  resultado: ResultadoMl(
    idResultado: id,
    idEvaluacion: id,
    idUsuario: 1,
    probabilidadAnsiedad: probability,
    nivelRiesgo: level,
    recomendaciones: [
      Recomendacion(
        idRecomendacion: id,
        categoria: 'BAJO',
        titulo: 'Pausa saludable',
        descripcion: 'Descansa entre actividades.',
      ),
    ],
    reporteIA: report,
    shapExplanation: oldRecord
        ? null
        : shapFailed
        ? const ShapExplanation(disponible: false, factores: [])
        : const ShapExplanation(
            disponible: true,
            factores: [
              ShapFactor(
                nombre: 'SleepHours',
                valor: .3,
                direccion: 'disminuye',
              ),
              ShapFactor(nombre: 'PHQ9', valor: .2, direccion: 'aumenta'),
              ShapFactor(nombre: 'GAD7', valor: .1, direccion: 'aumenta'),
              ShapFactor(
                nombre: 'SocialActivity',
                valor: .1,
                direccion: 'disminuye',
              ),
              ShapFactor(
                nombre: 'OnlineStress',
                valor: .1,
                direccion: 'aumenta',
              ),
              ShapFactor(
                nombre: 'FinancialStress',
                valor: .1,
                direccion: 'aumenta',
              ),
              ShapFactor(
                nombre: 'ExerciseFreq',
                valor: .1,
                direccion: 'disminuye',
              ),
            ],
          ),
  ),
);

Future<void> _openSingleDetail(WidgetTester tester, Evaluacion record) async {
  final repo = _Repo([record]);
  final vm = EvaluacionViewModel(
    EvaluarRiesgoUseCase(repo),
    ObtenerHistorialUseCase(repo),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: vm,
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const HistorialScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Riesgo Bajo'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('historical detail translates SHAP and preserves AI report', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final report = ReporteIA(
      resumen: 'Resumen real',
      fortalezas: const [],
      factoresPreocupantes: const [],
      recomendaciones: const [],
      plan7Dias: const [],
      temasVideos: const [],
      temasLectura: const [],
      prioridadIntervencion: 'NO DISPONIBLE',
      mensajeMotivacional: 'Mensaje real',
    );
    await _openSingleDetail(
      tester,
      _evaluation(1, '2026-11-13', .24, report: report),
    );
    for (final name in [
      'Horas de sueño',
      'Síntomas depresivos (PHQ-9)',
      'Síntomas de ansiedad (GAD-7)',
      'Actividad social',
      'Estrés en línea',
      'Estrés financiero',
      'Frecuencia de ejercicio',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('aumenta'), findsNWidgets(4));
    expect(find.text('disminuye'), findsNWidgets(3));
    expect(find.textContaining('no son causas clínicas'), findsOneWidget);
    expect(find.text('Orientación general'), findsOneWidget);
    expect(find.textContaining('Prioridad: NO DISPONIBLE'), findsNothing);
    expect(find.text('Resumen real'), findsOneWidget);
    expect(find.text('Pausa saludable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old null SHAP and failed explanation have distinct messages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _openSingleDetail(
      tester,
      _evaluation(1, '2025-01-01', .24, oldRecord: true),
    );
    expect(
      find.textContaining('en esa fecha no se conservaba'),
      findsOneWidget,
    );
    expect(find.textContaining('No se pudo generar'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await _openSingleDetail(
      tester,
      _evaluation(2, '2026-11-13', .24, shapFailed: true),
    );
    expect(find.textContaining('No se pudo generar'), findsOneWidget);
    expect(find.textContaining('en esa fecha no se conservaba'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one history screen shows real evaluations and tracking', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo([
      _evaluation(1, '2026-11-13T09:00:00', .24),
      _evaluation(2, '2026-11-13T12:00:00', .51),
    ]);
    final vm = EvaluacionViewModel(
      EvaluarRiesgoUseCase(repo),
      ObtenerHistorialUseCase(repo),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppColors.light]),
          home: const HistorialScreen(),
          routes: {
            '/evaluacion': (_) => const Scaffold(body: Text('Evaluación')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.reads, 1);
    expect(find.text('Riesgo Bajo'), findsNWidgets(2));
    expect(find.textContaining('#1'), findsOneWidget);
    expect(find.textContaining('#2'), findsOneWidget);
    expect(find.textContaining('Bienestar diario'), findsNothing);
    await tester.tap(find.text('Seguimiento'));
    await tester.pumpAndSettle();
    expect(find.text('Tu evolución'), findsOneWidget);
    expect(find.text('Riesgo Bajo'), findsNothing);
    expect(repo.reads, 1);
    final chart = find.byKey(const ValueKey('history-chart'));
    await tester.ensureVisible(chart);
    await tester.pumpAndSettle();
    final topLeft = tester.getTopLeft(chart);
    final width = tester.getSize(chart).width;
    await tester.tapAt(topLeft + Offset(width - 12, 79));
    await tester.pumpAndSettle();
    expect(find.text('Variación: +27.0 puntos porcentuales'), findsOneWidget);
    expect(find.textContaining('#2'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -380));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.text('Horas de sueño'), findsOneWidget);
    expect(find.text('Pausa saludable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('risk filter shows matching real evaluations only', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo([
      _evaluation(1, '2026-11-13T09:00:00', .24),
      _evaluation(2, '2026-11-13T12:00:00', .51, level: 'MEDIO'),
      _evaluation(3, '2026-11-14T12:00:00', .76, level: 'ALTO'),
    ]);
    final vm = EvaluacionViewModel(
      EvaluarRiesgoUseCase(repo),
      ObtenerHistorialUseCase(repo),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppColors.light]),
          home: const HistorialScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    await tester.tap(find.text('Medio'));
    await tester.pumpAndSettle();
    expect(find.text('Riesgo Moderado'), findsOneWidget);
    expect(find.text('Riesgo Bajo'), findsNothing);
    expect(find.text('Riesgo Alto'), findsNothing);
    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();
    expect(find.text('Riesgo Bajo'), findsOneWidget);
    expect(find.text('Riesgo Moderado'), findsOneWidget);
    expect(find.text('Riesgo Alto'), findsOneWidget);
    expect(repo.reads, 1);
  });

  testWidgets('empty and error states work on a wide viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Future<void> show(_Repo repo) async {
      final vm = EvaluacionViewModel(
        EvaluarRiesgoUseCase(repo),
        ObtenerHistorialUseCase(repo),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: vm,
          child: MaterialApp(
            theme: ThemeData(extensions: const [AppColors.light]),
            home: const HistorialScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(_Repo([]));
    expect(find.text('No hay evaluaciones realizadas aún.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    final failing = _Repo([], fail: true);
    await show(failing);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(failing.reads, 1);
    expect(tester.takeException(), isNull);
  });
}
