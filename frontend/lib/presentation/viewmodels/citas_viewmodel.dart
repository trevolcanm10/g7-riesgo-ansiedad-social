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
    _aplicarYQuitarHorario,
  );

  Future<bool> cancelar(int citaId) =>
      _guardar(() => _repository.cancelar(citaId), _reemplazar);

  Future<bool> reprogramar(int citaId, int slotId) => _guardar(
    () => _repository.reprogramar(citaId, slotId),
    _aplicarYQuitarHorario,
  );

  /// Pone la cita devuelta por el servidor en la lista local (o la agrega).
  void _reemplazar(Cita cita) {
    final i = _citas.indexWhere((c) => c.id == cita.id);
    _citas = [..._citas];
    if (i == -1) {
      _citas.add(cita);
    } else {
      _citas[i] = cita;
    }
  }

  /// Ademas, el horario que la cita ocupa ya no esta libre.
  void _aplicarYQuitarHorario(Cita cita) {
    _reemplazar(cita);
    _horarios = _horarios.where((h) => h.id != cita.slotId).toList();
  }

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

  /// Ejecuta una escritura y aplica la cita devuelta por el servidor a las
  /// listas locales, sin volver a pedirlas: una sola peticion por accion (el
  /// APIM limita las peticiones y recargar tambien podia fallar tras una
  /// escritura ya aplicada). "Tirar para actualizar" sigue recargando todo.
  Future<bool> _guardar(
    Future<Cita> Function() accion,
    void Function(Cita) aplicar,
  ) async {
    if (_guardando) return false;
    final sesion = _sessionVersion;
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      final cita = await accion();
      if (sesion != _sessionVersion) return false;
      aplicar(cita);
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
