import 'package:flutter_test/flutter_test.dart';
import 'package:ansiedad_ml_app/domain/entities/evaluation_answers.dart';

void main() {
  test('PHQ-9 tiene exactamente nueve preguntas y GAD-7 siete', () {
    expect(phq9Questions.length, 9);
    expect(gad7Questions.length, 7);
    expect(phq9Options.length, 4);
    expect(gad7Options.length, 4);
  });
  for (final count in [9, 7]) {
    test('$count respuestas: minimo, maximo y suma mixta', () {
      expect(questionnaireScore(List.filled(count, 0), count), 0);
      expect(questionnaireScore(List.filled(count, 3), count), count * 3);
      expect(
        questionnaireScore(List.generate(count, (i) => i % 4), count),
        List.generate(count, (i) => i % 4).reduce((a, b) => a + b),
      );
    });
    test(
      '$count respuestas: rechaza faltantes, cantidad y puntuacion invalidas',
      () {
        for (final answers in <List<int?>>[
          List.filled(count, null),
          [...List.filled(count - 1, 0), null],
          List.filled(count - 1, 0),
          List.filled(count + 1, 0),
          List.filled(count, -1),
          List.filled(count, 4),
        ]) {
          expect(
            () => questionnaireScore(answers, count),
            throwsFormatException,
          );
        }
      },
    );
  }
  for (final entry in {'0': 0.0, '10': 2.5, '20': 5.0, '15.2': 3.8}.entries) {
    test('promedio ${entry.key} convierte a ${entry.value}', () {
      final answers = EvaluationAnswers()..academicAverage = entry.key;
      expect(answers.gpa, entry.value);
    });
  }
  test('promedio invalido: vacio, texto, no finitos y fuera de rango', () {
    for (final value in [
      '',
      '  ',
      'abc',
      'NaN',
      'Infinity',
      '-Infinity',
      '-0.1',
      '20.01',
    ]) {
      expect(validateAcademicAverage(value), isNotNull);
      expect(
        () => (EvaluationAnswers()..academicAverage = value).gpa,
        throwsFormatException,
      );
    }
    expect(validateAcademicAverage(null), isNotNull);
  });
  test(
    'campos RiskEvaluation y reenvio sin conversion acumulativa ni items',
    () {
      final answers = EvaluationAnswers()..academicAverage = '10';
      answers.phq9.fillRange(0, 9, 3);
      answers.gad7.fillRange(0, 7, 2);
      expect(answers.toRiskFields(), {
        'phq9Score': 27,
        'gad7Score': 14,
        'gpa': 2.5,
      });
      final indicators = {'sleep_hours': 7.0};
      final first = answers.toExistingVariables(indicators);
      expect(first, {
        'sleep_hours': 7.0,
        'phq9_score': 27.0,
        'gad7_score': 14.0,
        'gpa': 2.5,
      });
      expect(answers.toExistingVariables(indicators), first);
      expect(answers.academicAverage, '10');
      expect(indicators, {'sleep_hours': 7.0});
    },
  );
}
