import 'package:flutter/foundation.dart';
import '../../domain/entities/cita.dart';
import '../../domain/repositories/citas_repository.dart';

/// ViewModel del personal de UNAYOE: agenda, estados, riesgo y horarios.
class AgendaUnayoeViewModel extends ChangeNotifier {
  final CitasRepository _repository;

  AgendaUnayoeViewModel(this._repository);

  int _sessionVersion = 0;
  bool _cargando = false;
  bool _guardando = false;
  String? _error;
  String? _filtro; // null = todas
  List<Cita> _agenda = [];

  bool get cargando => _cargando;
  bool get guardando => _guardando;
  String? get error => _error;
  String? get filtro => _filtro;
  List<Cita> get agenda => _agenda;

  Future<void> cargarAgenda({String? filtro, bool conservarFiltro = false}) async {
    if (!conservarFiltro) _filtro = filtro;
    final sesion = _sessionVersion;
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _repository.agenda(estado: _filtro);
      if (sesion != _sessionVersion) return;
      _agenda = data;
    } catch (e) {
      if (sesion != _sessionVersion) return;
      _error = _mensaje(e);
    }
    _cargando = false;
    notifyListeners();
  }

  Future<bool> cambiarEstado(int citaId, String estado) =>
      _guardar(() => _repository.cambiarEstado(citaId, estado));

  Future<bool> cancelar(int citaId) =>
      _guardar(() => _repository.cancelar(citaId));

  /// Publica los horarios y devuelve cuantos se crearon (null si fallo).
  Future<int?> publicar(List<DateTime> inicios, {int? personalId}) async {
    if (_guardando) return null;
    final sesion = _sessionVersion;
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      final creados = await _repository.publicarHorarios(
        inicios,
        personalId: personalId,
      );
      if (sesion != _sessionVersion) return null;
      _guardando = false;
      notifyListeners();
      return creados.length;
    } catch (e) {
      if (sesion != _sessionVersion) return null;
      _error = _mensaje(e);
      _guardando = false;
      notifyListeners();
      return null;
    }
  }

  /// Estimacion de inasistencia de una cita. No cambia el estado del VM:
  /// devuelve el error como texto para mostrarlo en el dialogo.
  Future<({RiesgoInasistencia? riesgo, String? error})> riesgo(int citaId) async {
    try {
      return (riesgo: await _repository.riesgoInasistencia(citaId), error: null);
    } catch (e) {
      return (riesgo: null, error: _mensaje(e));
    }
  }

  Future<bool> _guardar(Future<Cita> Function() accion) async {
    if (_guardando) return false;
    final sesion = _sessionVersion;
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      await accion();
      if (sesion != _sessionVersion) return false;
      _agenda = await _repository.agenda(estado: _filtro);
      if (sesion != _sessionVersion) return false;
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
    _filtro = null;
    _agenda = [];
    notifyListeners();
  }
}
