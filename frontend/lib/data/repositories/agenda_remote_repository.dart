import 'dart:convert';

import '../../domain/entities/actividad_academica.dart';
import '../../domain/repositories/agenda_repository.dart';
import '../datasources/remote/api_service.dart';

/// Adapts the agenda screen's list operations to Flask's per-activity CRUD.
/// ApiService supplies the authenticated user's Bearer token on every call.
class AgendaRemoteRepository implements AgendaRepository {
  final ApiService _apiService;
  final String _base;
  List<ActividadAcademica>? _synced;

  AgendaRemoteRepository(this._apiService, this._base)
      : assert(_base.endsWith('/actividades'));

  @override
  Future<List<ActividadAcademica>> obtener() async {
    final data = await _apiService.getList(_base);
    final items = data
        .map((value) => _fromFlask(value as Map<String, dynamic>))
        .toList();
    _synced = items;
    return items;
  }

  @override
  Future<void> guardar(List<ActividadAcademica> actividades) async {
    final previous = _synced ?? await obtener();
    final oldById = {for (final item in previous) item.id: item};
    final nextIds = actividades.map((item) => item.id).toSet();
    try {
      for (final item in actividades) {
        final old = oldById[item.id];
        if (old == null) {
          await _apiService.post(_base, body: _toFlask(item), expectedStatus: 201);
        } else if (!_samePayload(old, item)) {
          await _apiService.patch('$_base/${old.id}', body: _toFlask(item));
        }
      }
      for (final item in previous) {
        if (!nextIds.contains(item.id)) {
          await _apiService.delete('$_base/${item.id}');
        }
      }
      // Created IDs come from Flask; the screen reloads after saving.
      _synced = null;
    } catch (_) {
      _synced = null;
      rethrow;
    }
  }

  bool _samePayload(ActividadAcademica a, ActividadAcademica b) =>
      jsonEncode(_toFlask(a)) == jsonEncode(_toFlask(b));

  static const _indicatorNames = <String>{
    'horas_totales', 'num_actividades', 'num_examenes', 'num_entregas',
    'num_urgentes_48h', 'num_prioridad_alta', 'dias_con_actividades',
    'max_horas_dia', 'concentracion_3dias', 'num_sin_duracion',
  };
  static const _levels = <String>{'BAJA', 'MODERADA', 'ALTA'};

  Map<String, dynamic> _indicators(Map<String, num> values) {
    if (values.keys.toSet().difference(_indicatorNames).isNotEmpty ||
        _indicatorNames.difference(values.keys.toSet()).isNotEmpty ||
        values.values.any((value) => !value.isFinite)) {
      throw ArgumentError('La clasificación exige diez indicadores numéricos.');
    }
    return Map<String, dynamic>.from(values);
  }

  String _level(Map<String, dynamic> json) {
    final level = json['nivel_carga'];
    if (level is! String || !_levels.contains(level)) {
      throw const FormatException('Nivel de carga desconocido.');
    }
    return level;
  }

  Future<AgendaWeeklyClassification> clasificarSemana(
    Map<String, num> indicators,
  ) async {
    final json = await _apiService.post(
      '${_base.substring(0, _base.length - '/actividades'.length)}/clasificacion/semanal',
      body: _indicators(indicators),
    );
    final probabilities = json['probabilidades'] as Map<String, dynamic>;
    return AgendaWeeklyClassification(
      nivel: _level(json),
      probabilidadNivel: (json['probabilidad_nivel'] as num).toDouble(),
      probabilidades: probabilities.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
  }

  Future<AgendaPreventiveAlerts> obtenerAlertas(
    Map<String, num> indicators,
  ) async {
    final json = await _apiService.post(
      '${_base.substring(0, _base.length - '/actividades'.length)}/alertas/preventivas',
      body: _indicators(indicators),
    );
    return AgendaPreventiveAlerts(
      nivel: _level(json),
      alertas: (json['alertas'] as List<dynamic>)
          .map((item) => Map<String, String>.from(item as Map))
          .toList(),
      recomendacion: json['recomendacion'] as String,
    );
  }

  Map<String, dynamic> _toFlask(ActividadAcademica item) => {
    'title': item.titulo,
    'course': item.curso,
    'activity_type': item.tipo == 'exposicion' ? 'otro' : item.tipo,
    'activity_date':
        '${item.fecha.year.toString().padLeft(4, '0')}-'
        '${item.fecha.month.toString().padLeft(2, '0')}-'
        '${item.fecha.day.toString().padLeft(2, '0')}',
    'estimated_hours': item.duracionEstimadaHoras ?? 0.0,
    'priority': item.prioridad,
    'description': item.descripcion,
    'completed': item.completada,
  };

  ActividadAcademica _fromFlask(Map<String, dynamic> json) =>
      ActividadAcademica(
        id: (json['id'] as num).toInt().toString(),
        titulo: json['title'] as String,
        curso: json['course'] as String,
        tipo: json['activity_type'] as String,
        fecha: DateTime.parse(json['activity_date'] as String),
        hora: null,
        duracionEstimadaHoras: (json['estimated_hours'] as num).toDouble(),
        prioridad: json['priority'] as String,
        descripcion: json['description'] as String? ?? '',
        completada: json['completed'] as bool,
      );
}

class AgendaWeeklyClassification {
  final String nivel;
  final double probabilidadNivel;
  final Map<String, double> probabilidades;

  const AgendaWeeklyClassification({
    required this.nivel,
    required this.probabilidadNivel,
    required this.probabilidades,
  });
}

class AgendaPreventiveAlerts {
  final String nivel;
  final List<Map<String, String>> alertas;
  final String recomendacion;

  const AgendaPreventiveAlerts({
    required this.nivel,
    required this.alertas,
    required this.recomendacion,
  });
}
