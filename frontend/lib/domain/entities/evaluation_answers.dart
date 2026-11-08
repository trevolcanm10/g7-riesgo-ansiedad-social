/// Spanish instruments: Servicio Andaluz de Salud (2023), annexes 1 and 2,
/// printed pages 1 and 5 (PDF pages 8 and 12).
/// https://www.sspa.juntadeandalucia.es/servicioandaluzdesalud/sites/default/files/sincfiles/wsas-media-pdf_publicacion/2023/2.%20Material_organizacion_grafa_2023.pdf
/// Only scored items are used; no clinical interpretation is calculated.
const phq9Questions = <String>[
  'Tener poco interés o disfrutar poco haciendo cosas',
  'Sentirse desanimado/a, deprimido/a o sin esperanza',
  'Tener problemas para dormir (coger el sueño o mantenerlo), o tener más sueño de la cuenta',
  'Sentirse cansado/a o con poca energía',
  'Tener poco apetito o comer demasiado',
  'Sentirse mal consigo mismo/a o sentirse fracasado/a o decepcionado/a de sí mismo/a, o pensar que ha decepcionado a los que le rodean',
  'Tener problemas para concentrarse, como por ejemplo para leer el periódico o ver la televisión',
  'Moverse o hablar tan lentamente que los demás lo han notado. O bien lo contrario, estar tan inquieto/a e intranquilo/a que ha estado moviéndose de arriba para abajo mucho más de lo habitual',
  'En las últimas dos semanas, tener pensamientos sobre que estaría mejor si se muriese o sobre hacerse daño a sí mismo de alguna manera',
];
const gad7Questions = <String>[
  'Sentirse nervioso/a, ansioso/a, o tener los nervios de punta.',
  'No ser capaz de parar o controlar sus preocupaciones/la inquietud.',
  'Sentirse muy inquieto/a sobre diferentes cosas.',
  'Tener dificultad para relajarse.',
  'Estar tan inquieto que le resulte difícil estar sentado/a quieto/a.',
  'Enfadarse o irritarse con facilidad.',
  'Estar asustado/a como si fuese a pasar algo terrible.',
];
const phq9Options = [
  'Nunca',
  'Unos cuantos días',
  'Más de la mitad de los días',
  'Todos a casi todos los días',
];
const gad7Options = [
  'Nunca',
  'Varios días',
  'La mitad de los días',
  'Cada día',
];

int questionnaireScore(List<int?> answers, int expectedCount) {
  if (answers.length != expectedCount ||
      answers.any((answer) => answer == null || answer < 0 || answer > 3)) {
    throw const FormatException(
      'Responde todas las preguntas con valores de 0 a 3.',
    );
  }
  return answers.fold(0, (sum, answer) => sum + answer!);
}

String? validateAcademicAverage(String? text) {
  if (text == null || text.trim().isEmpty) {
    return 'Ingresa tu promedio sobre 20.';
  }
  final value = double.tryParse(text.trim());
  if (value == null || !value.isFinite) {
    return 'Ingresa un número finito válido.';
  }
  if (value < 0 || value > 20) return 'El promedio debe estar entre 0 y 20.';
  return null;
}

/// Ranges and integer requirement of the 15 RiskEvaluation contract fields,
/// mirroring services/riskEvaluation/src/presentation/dtos/CreateRiskEvaluationDTO.ts.
///
/// Every entry maps the camelCase contract key to the snake_case key of the
/// legacy indicator map, plus its inclusive range. GPA is the only decimal.
class _RiskField {
  final String contractKey;
  final String indicatorKey;
  final num min;
  final num max;
  const _RiskField(this.contractKey, this.indicatorKey, this.min, this.max);
}

const _riskFields = <_RiskField>[
  _RiskField('sleepHours', 'sleep_hours', 3, 10),
  _RiskField('exerciseFreq', 'exercise_freq', 0, 7),
  _RiskField('socialActivity', 'social_activity', 0, 10),
  _RiskField('onlineStress', 'online_stress', 1, 10),
  _RiskField('familySupport', 'family_support', 1, 10),
  _RiskField('screenTime', 'screen_time', 1, 12),
  _RiskField('academicStress', 'academic_stress', 1, 10),
  _RiskField('dietQuality', 'diet_quality', 1, 10),
  _RiskField('selfEfficacy', 'self_efficacy', 1, 10),
  _RiskField('peerRelationship', 'peer_relationship', 1, 10),
  _RiskField('financialStress', 'financial_stress', 1, 10),
  _RiskField('sleepQuality', 'sleep_quality', 0, 10),
];

/// Holds raw answers only. Every submission derives a fresh immutable snapshot;
/// converted GPA is never written back into the student's raw average.
class EvaluationAnswers {
  final List<int?> phq9 = List<int?>.filled(9, null);
  final List<int?> gad7 = List<int?>.filled(7, null);
  String academicAverage = '';

  int get phq9Score => questionnaireScore(phq9, 9);
  int get gad7Score => questionnaireScore(gad7, 7);
  double get gpa {
    final error = validateAcademicAverage(academicAverage);
    if (error != null) throw FormatException(error);
    return double.parse(academicAverage.trim()) / 4;
  }

  /// The three fields of the RiskEvaluation contract, without item answers.
  Map<String, num> toRiskFields() => {
    'phq9Score': phq9Score,
    'gad7Score': gad7Score,
    'gpa': gpa,
  };

  /// The 15 fields of the RiskEvaluation contract, in camelCase.
  ///
  /// Reuses the PHQ-9 and GAD-7 totals already computed and converts the
  /// academic average to GPA (average / 4). Every value is validated against
  /// the backend contract: a missing, non-finite or out-of-range indicator
  /// throws [FormatException] instead of being silently coerced.
  Map<String, num> toRiskPayload(Map<String, double> indicators) {
    final payload = <String, num>{
      'phq9Score': phq9Score,
      'gad7Score': gad7Score,
    };

    for (final field in _riskFields) {
      final raw = indicators[field.indicatorKey];
      if (raw == null) {
        throw FormatException('Falta el indicador ${field.indicatorKey}.');
      }
      if (!raw.isFinite) {
        throw FormatException(
          'El indicador ${field.indicatorKey} no es un valor valido.',
        );
      }
      // The contract requires integers: 7.5 hours is not an accepted answer.
      if (raw != raw.round()) {
        throw FormatException(
          'El indicador ${field.indicatorKey} debe ser un numero entero.',
        );
      }
      final value = raw.toInt();
      if (value < field.min || value > field.max) {
        throw FormatException(
          'El indicador ${field.indicatorKey} debe estar entre '
          '${field.min} y ${field.max}.',
        );
      }
      payload[field.contractKey] = value;
    }

    final gpa = this.gpa;
    payload['gpa'] = gpa;
    if (payload.length != 15) {
      throw const FormatException('La evaluacion no tiene los 15 campos.');
    }
    return payload;
  }

  /// Compatibility with the existing transport pending full HTTP integration.
  Map<String, double> toExistingVariables(Map<String, double> indicators) => {
    ...indicators,
    'phq9_score': phq9Score.toDouble(),
    'gad7_score': gad7Score.toDouble(),
    'gpa': gpa,
  };
}
