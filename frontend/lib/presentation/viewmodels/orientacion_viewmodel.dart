import 'package:flutter/foundation.dart';
import '../../domain/entities/solicitud_orientacion.dart';
import '../../data/datasources/remote/orientacion_remote_datasource.dart';
import 'auth_viewmodel.dart';
import 'evaluacion_viewmodel.dart';

/// ViewModel que maneja la lógica de Orientación Confidencial.
/// Conecta la vista con los casos de uso / datasource correspondiente.
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

  // Guarda la alerta de urgencia después del envío si el modelo ML lo detectó
  AlertaUrgencia? ultimaAlerta;

  /// Envía una solicitud confidencial al backend
  Future<bool> enviarSolicitud(String mensaje, bool comparteEvaluacion) async {
    _isLoading = true;
    _error = null;
    ultimaAlerta = null;
    notifyListeners();

    try {
      // Tomamos el código de estudiante del AuthViewModel
      // (O el ID de usuario si está disponible)
      final estudianteId =
          _authVM.usuario?.codigo ??
          _authVM.idUsuario?.toString() ??
          "Estudiante";

      int? evalId;
      if (comparteEvaluacion) {
        final historialEvals = _evaluacionVM?.historial;
        evalId = (historialEvals != null && historialEvals.isNotEmpty)
            ? historialEvals.first.idEvaluacion
            : null;
      }

      final response = await _dataSource.enviarSolicitud(
        estudianteId: estudianteId,
        mensaje: mensaje,
        comparteEvaluacion: comparteEvaluacion,
        evaluacionRiesgoId: evalId,
      );

      ultimaAlerta = response.alertasUrgencia;

      // Actualizamos la lista local añadiendo la nueva solicitud al inicio
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

  /// Carga el historial de solicitudes del backend
  Future<void> cargarHistorial() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final myId =
          _authVM.usuario?.codigo ??
          _authVM.idUsuario?.toString() ??
          "Estudiante";
      final solicitudes = await _dataSource.obtenerHistorial(
        estudianteId: myId,
      );

      // Filtramos solo las de este usuario por defensa en profundidad
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
