import '../entities/usuario.dart';

/// Interfaz abstracta del repositorio de autenticación.
///
/// Define el contrato para operaciones de autenticación sin depender
/// de detalles de implementación (API, almacenamiento local, etc.).
abstract class AuthRepository {
  Future<({String token, Usuario usuario})?> restaurarSesion();

  /// Autentica un usuario con correo y contraseña.
  /// Retorna el token JWT y los datos del usuario si es exitoso.
  Future<({String token, Usuario usuario})> login({
    required String correo,
    required String contrasena,
  });

  /// Registra un nuevo usuario en el microservicio Users (POST /users).
  ///
  /// Contrato de los 7 campos, todos obligatorios:
  /// `names`, `surnames`, `code` (String), `email`, `password`,
  /// `school` (solo el nombre de la escuela) y `cycle` (entero 1-12).
  Future<void> registrar({
    required String nombres,
    required String apellidos,
    required String codigo,
    required String correo,
    required String contrasena,
    required String escuela,
    required int ciclo,
  });

  /// Cierra la sesión del usuario actual.
  Future<void> logout();
}
