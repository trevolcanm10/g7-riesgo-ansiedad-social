import 'package:flutter/foundation.dart';
import '../../domain/entities/solicitud_orientacion.dart';
import '../../data/datasources/remote/orientacion_remote_datasource.dart';
import 'auth_viewmodel.dart';
import 'evaluacion_viewmodel.dart';

/// ViewModel que maneja la lógica de Orientación Confidencial.
/// Conecta la vista con el datasource autenticado de Orientación.
class OrientacionViewModel extends ChangeNotifier {
  final OrientacionRemoteDataSource _dataSource;
  final AuthViewModel _authVM;
  final EvaluacionViewModel? _evaluacionVM;

  OrientacionViewModel(this._dataSource, this._authVM, [this._evaluacionVM]);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<SolicitudOrientacion> _historial = [];
  List<SolicitudOrientacion> get historial => _historial;

  AlertaUrgencia? ultimaAlerta;

  bool get puedeCompartirEvaluacion =>
      (_evaluacionVM?.historial ?? const []).any((e) => e.idEvaluacion > 0);

  /// Envía una solicitud confidencial autenticada al backend.
  Future<bool> enviarSolicitud(String mensaje, bool comparteEvaluacion) async {
    _error = null;
    ultimaAlerta = null;

    if (!_authVM.isAuthenticated || _authVM.idUsuario == null) {
      _error = 'Debes iniciar sesión para enviar una solicitud confidencial.';
      notifyListeners();
      return false;
    }

    int? evalId;
    if (comparteEvaluacion) {
      final validas = (_evaluacionVM?.historial ?? const [])
          .where((e) => e.idEvaluacion > 0)
          .toList();
      if (validas.isEmpty) {
        _error = 'No tienes una evaluación de riesgo registrada para compartir.';
        notifyListeners();
        return false;
      }
      evalId = validas.first.idEvaluacion;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dataSource.enviarSolicitud(
        mensaje: mensaje,
        comparteEvaluacion: comparteEvaluacion,
        evaluacionRiesgoId: evalId,
      );

      ultimaAlerta = response.alertasUrgencia;
      _historial.insert(0, response.solicitud);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Carga el historial de solicitudes del estudiante autenticado.
  Future<void> cargarHistorial() async {
    _error = null;

    if (!_authVM.isAuthenticated || _authVM.idUsuario == null) {
      _error = 'Debes iniciar sesión para consultar tu historial.';
      _historial = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final myId = _authVM.idUsuario!;
      final solicitudes = await _dataSource.obtenerHistorial();
      _historial = solicitudes.where((s) => s.estudianteId == myId).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  void limpiarSesion() {
    _isLoading = false;
    _error = null;
    _historial = [];
    ultimaAlerta = null;
    notifyListeners();
  }
}
