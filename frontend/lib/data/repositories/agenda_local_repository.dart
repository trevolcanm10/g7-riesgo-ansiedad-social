import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/actividad_academica.dart';
import '../../domain/repositories/agenda_repository.dart';

class AgendaLocalRepository implements AgendaRepository {
  final int userId;
  const AgendaLocalRepository(this.userId);
  String get _key => 'academic_agenda_v1_$userId';

  @override
  Future<List<ActividadAcademica>> obtener() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) => ActividadAcademica.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> guardar(List<ActividadAcademica> actividades) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_key, jsonEncode(actividades.map((a) => a.toJson()).toList()));
    if (!saved) throw StateError('No se pudo guardar la agenda local.');
  }
}
