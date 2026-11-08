import '../repositories/auth_repository.dart';

/// UseCase para cerrar sesión.
///
/// Encapsula la lógica de cierre de sesión.
class LogoutUseCase {
  final AuthRepository _authRepository;

  LogoutUseCase(this._authRepository);

  /// Ejecuta el caso de uso de logout.
  Future<void> call() async {
    return _authRepository.logout();
  }
}
