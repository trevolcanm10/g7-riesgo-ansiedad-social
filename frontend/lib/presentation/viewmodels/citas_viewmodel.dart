import 'package:flutter/foundation.dart';
import '../../domain/entities/cita.dart';
import '../../domain/repositories/citas_repository.dart';

/// ViewModel de "Agendar cita" y "Mis citas".
class CitasViewModel extends ChangeNotifier {
  final CitasRepository _repository;

  CitasViewModel(this._repository);

  int _sessionVersion = 0;
  bool _cargando = false;
  bool _guardando = false;
  String? _error;
  List<Horario> _horarios = [];
  List<Cita> _citas = [];

  bool get cargando => _cargando;
  bool get guardando => _guardando;
  String? get error => _error;
  List<Horario> get horarios => _horarios;
  List<Cita> get citas => _citas;

  Future<void> cargarHorarios() => _cargar(() async {
    _horarios = await _repository.horariosLibres();
  });

  Future<void> cargarMisCitas() => _cargar(() async {
    _citas = await _repository.misCitas();
  });

  /// Solicita una cita. [prioridad] es ALTA solo si el ultimo resultado fue de
  /// riesgo alto; es informativa y no cambia permisos ni orden en el servidor.
  Future<bool> solicitar({
    required int slotId,
    required String prioridad,
    String? motivo,
  }) => _guardar(
    () => _repository.solicitar(
      slotId: slotId,
      prioridad: prioridad,
      motivo: motivo,
    ),
  );

  Future<bool> cancelar(int citaId) =>
      _guardar(() => _repository.cancelar(citaId));

  Future<bool> reprogramar(int citaId, int slotId) =>
      _guardar(() => _repository.reprogramar(citaId, slotId));

  Future<void> _cargar(Future<void> Function() accion) async {
    final sesion = _sessionVersion;
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      await accion();
    } catch (e) {
      if (sesion != _sessionVersion) return;
      _error = _mensaje(e);
    }
    if (sesion != _sessionVersion) return;
    _cargando = false;
    notifyListeners();
  }

  /// Ejecuta una escritura y, si funciona, refresca ambas listas.
  Future<bool> _guardar(Future<Cita> Function() accion) async {
    if (_guardando) return false;
    final sesion = _sessionVersion;
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      await accion();
      if (sesion != _sessionVersion) return false;
      final resultados = await Future.wait([
        _repository.misCitas(),
        _repository.horariosLibres(),
      ]);
      if (sesion != _sessionVersion) return false;
      _citas = resultados[0] as List<Cita>;
      _horarios = resultados[1] as List<Horario>;
      _guardando = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (sesion != _sessionVersion) return false;
      _error = _mensaje(e);
      _guardando = false;
      notifyListeners();
      return false;
    }
  }

  String _mensaje(Object e) => e is Exception
      ? e.toString().replaceFirst(RegExp(r'^Exception: '), '')
      : 'No se pudo completar la operacion. Intentalo de nuevo.';

  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  void limpiarSesion() {
    _sessionVersion++;
    _cargando = false;
    _guardando = false;
    _error = null;
    _horarios = [];
    _citas = [];
    notifyListeners();
  }
}
