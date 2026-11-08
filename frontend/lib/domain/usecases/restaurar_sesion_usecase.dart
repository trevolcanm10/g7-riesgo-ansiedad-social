import '../repositories/auth_repository.dart';
import '../entities/usuario.dart';

class RestaurarSesionUseCase {
  final AuthRepository _repository;
  RestaurarSesionUseCase(this._repository);
  Future<({String token, Usuario usuario})?> call() =>
      _repository.restaurarSesion();
}
