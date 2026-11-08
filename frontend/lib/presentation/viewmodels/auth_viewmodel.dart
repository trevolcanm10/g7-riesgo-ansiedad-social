import 'package:flutter/foundation.dart';
import '../../../domain/entities/usuario.dart';
import '../../../domain/usecases/login_usecase.dart';
import '../../../domain/usecases/register_usecase.dart';
import '../../../domain/usecases/logout_usecase.dart';
import '../../../domain/usecases/restaurar_sesion_usecase.dart';

/// ViewModel encargado de la autenticación (Login y Registro).
///
/// Ahora recibe UseCases en lugar de ApiService directamente,
/// siguiendo el principio de que la capa de presentación no debe
/// conocer detalles de implementación de la capa de datos.
class AuthViewModel extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final LogoutUseCase _logoutUseCase;

  final RestaurarSesionUseCase? _restore;
  AuthViewModel(
    this._loginUseCase,
    this._registerUseCase,
    this._logoutUseCase, [
    this._restore,
  ]);
  bool isRestoring = false;
  bool sessionChecked = false;
  String? restoreError;
  bool logoutFailed = false;
  int _operation = 0;
  int get sessionRevision => _operation;
  VoidCallback? onSessionReset;
  Future<bool>? _closing;
  bool invalidatedBy401 = false;

  Future<void> invalidarSesion() async {
    if (!_isAuthenticated) return;
    invalidatedBy401 = true;
    await logout();
  }

  Future<void> restaurarSesion() async {
    if (isRestoring || logoutFailed || _isLoading) return;
    final operation = ++_operation;
    isRestoring = true;
    restoreError = null;
    notifyListeners();
    try {
      final result = await _restore?.call();
      if (operation != _operation) return;
      if (_token != result?.token ||
          _usuario?.idUsuario != result?.usuario.idUsuario) {
        onSessionReset?.call();
      }
      _token = result?.token;
      _usuario = result?.usuario;
      _isAuthenticated = result != null;
    } catch (_) {
      if (operation != _operation) return;
      restoreError =
          'No se pudo comprobar la sesión. Verifica la conexión o el almacenamiento y reintenta.';
    } finally {
      if (operation == _operation) {
        isRestoring = false;
        sessionChecked = true;
        notifyListeners();
      }
    }
  }

  // ==========================================
  // ESTADOS
  // ==========================================
  bool _isLoading = false;
  String? _error;
  String? _token;
  bool _isAuthenticated = false;
  Usuario? _usuario;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  Usuario? get usuario => _usuario;
  String? get nombre => _usuario?.nombre;
  String? get correo => _usuario?.correo;
  int? get idUsuario => _usuario?.idUsuario;

  // ==========================================
  // LOGIN
  // ==========================================
  Future<bool> login(String correo, String contrasena) async {
    if (_isLoading) return false;
    final operation = ++_operation;
    isRestoring = false;
    onSessionReset?.call();
    restoreError = null;
    _token = null;
    _usuario = null;
    _isAuthenticated = false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _loginUseCase(
        correo: correo,
        contrasena: contrasena,
      );

      if (operation != _operation) return false;
      _token = result.token;
      _usuario = result.usuario;
      _isAuthenticated = true;
      logoutFailed = false;
      invalidatedBy401 = false;
      return true;
    } catch (e) {
      if (operation != _operation) return false;
      _token = null;
      _usuario = null;
      _isAuthenticated = false;
      _error = e is Exception
          ? e.toString().replaceFirst(RegExp(r'^Exception: '), '')
          : 'No se pudo iniciar sesión. Inténtalo de nuevo.';
      return false;
    } finally {
      if (operation == _operation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ==========================================
  // REGISTRO
  // ==========================================
  Future<bool> registrar({
    required String nombres,
    required String apellidos,
    required String codigo,
    required String correo,
    required String contrasena,
    required String escuela,
    required int ciclo,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _registerUseCase(
        nombres: nombres,
        apellidos: apellidos,
        codigo: codigo,
        correo: correo,
        contrasena: contrasena,
        escuela: escuela,
        ciclo: ciclo,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().contains('Exception')
          ? e.toString()
          : 'Error de conexión con el servidor';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // CERRAR SESIÓN
  // ==========================================
  Future<bool> logout() {
    final pending = _closing;
    if (pending != null) return pending;
    final closing = _cerrarSesion();
    _closing = closing;
    closing.whenComplete(() => _closing = null);
    return closing;
  }

  Future<bool> _cerrarSesion() async {
    ++_operation;
    onSessionReset?.call();
    isRestoring = false;
    restoreError = null;
    _token = null;
    _isAuthenticated = false;
    _usuario = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _logoutUseCase();
      logoutFailed = false;
      _error = null;
      return true;
    } catch (_) {
      logoutFailed = true;
      _error =
          'No se pudo borrar la sesión guardada. Reintenta cerrar sesión antes de salir.';
      return false;
    } finally {
      _isLoading = false;
      sessionChecked = true;
      notifyListeners();
    }
  }

  // ==========================================
  // LIMPIAR ERROR
  // ==========================================
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
