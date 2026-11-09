import '../../../domain/entities/usuario.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../datasources/remote/api_service.dart';
import '../../../core/constants.dart';
import '../../../domain/services/session_store.dart';

/// Implementación del repositorio de autenticación.
///
/// Esta clase implementa la interfaz AuthRepository utilizando
/// el AuthRemoteDataSource para las llamadas HTTP.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SessionStore _store;
  int _generation = 0;
  Future<void> _storageQueue = Future.value();

  AuthRepositoryImpl(this._remoteDataSource, this._store);

  Future<T> _storage<T>(Future<T> Function() action) {
    final result = _storageQueue.then((_) => action());
    _storageQueue = result.then<void>(
      (_) {},
      onError: (Object e, StackTrace s) {},
    );
    return result;
  }

  @override
  Future<({String token, Usuario usuario})?> restaurarSesion() async {
    final generation = ++_generation;
    final origin = AppConstants.usersOrigin;
    final session = await _storage(_store.read);
    if (generation != _generation) return null;
    if (session == null) return null;
    if (session.usersOrigin != origin) {
      await _storage(_store.delete);
      return null;
    }
    try {
      final usuario = await _remoteDataSource.getMe(
        session.token,
        url: '$origin/users/me',
      );
      if (generation != _generation) return null;
      _remoteDataSource.setSessionToken(session.token);
      return (token: session.token, usuario: usuario.toEntity());
    } on ApiException catch (e) {
      if (generation != _generation) return null;
      if (e.statusCode == 401 || e.statusCode == 404) {
        await _storage(_store.delete);
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<({String token, Usuario usuario})> login({
    required String correo,
    required String contrasena,
  }) async {
    final generation = ++_generation;
    final origin = AppConstants.usersOrigin;
    _remoteDataSource.setSessionToken(null);
    await _storage(_store.delete);
    final result = await _remoteDataSource.login(
      correo: correo,
      contrasena: contrasena,
      url: '$origin/users/login',
    );
    if (generation != _generation) throw Exception('Operación cancelada.');
    try {
      await _storage(() => _store.write(StoredSession(result.token, origin)));
    } catch (_) {
      _remoteDataSource.setSessionToken(null);
      try {
        await _storage(_store.delete);
      } catch (_) {
        /* Keep memory unauthenticated. */
      }
      throw Exception(
        'No se pudo guardar la sesión de forma segura. Inténtalo de nuevo.',
      );
    }
    if (generation != _generation) throw Exception('Operación cancelada.');
    _remoteDataSource.setSessionToken(result.token);
    return (token: result.token, usuario: result.usuario.toEntity());
  }

  @override
  Future<void> registrar({
    required String nombres,
    required String apellidos,
    required String codigo,
    required String correo,
    required String contrasena,
    required String escuela,
    required int ciclo,
  }) async {
    return _remoteDataSource.registrar(
      nombres: nombres,
      apellidos: apellidos,
      codigo: codigo,
      correo: correo,
      contrasena: contrasena,
      escuela: escuela,
      ciclo: ciclo,
    );
  }

  @override
  Future<void> logout() async {
    ++_generation;
    _remoteDataSource.setSessionToken(null);
    await _storage(_store.delete);
  }
}
