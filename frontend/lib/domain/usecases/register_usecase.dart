import '../repositories/auth_repository.dart';

/// UseCase para registrar un nuevo usuario.
///
/// Encapsula la lógica de registro contra el microservicio Users,
/// permitiendo que la capa de presentación no conozca los detalles
/// de cómo se realiza el registro.
class RegisterUseCase {
  final AuthRepository _authRepository;

  RegisterUseCase(this._authRepository);

  /// Ejecuta el caso de uso de registro con los 7 campos del contrato Users.
  Future<void> call({
    required String nombres,
    required String apellidos,
    required String codigo,
    required String correo,
    required String contrasena,
    required String escuela,
    required int ciclo,
  }) async {
    return _authRepository.registrar(
      nombres: nombres,
      apellidos: apellidos,
      codigo: codigo,
      correo: correo,
      contrasena: contrasena,
      escuela: escuela,
      ciclo: ciclo,
    );
  }
}
