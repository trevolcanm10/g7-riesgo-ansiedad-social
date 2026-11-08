import '../../domain/entities/usuario.dart';

/// Adaptador del contrato Users. No sustituye campos ausentes.
class UsuarioModel {
  final Usuario _usuario;
  UsuarioModel._(this._usuario);

  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    String texto(String campo) {
      final valor = json[campo];
      if (valor is! String || valor.trim().isEmpty) {
        throw const FormatException('Usuario inválido');
      }
      return valor;
    }

    final id = json['id'];
    final ciclo = json['cycle'];
    if (id is! int || id <= 0 || ciclo is! int || ciclo < 1 || ciclo > 12) {
      throw const FormatException('Usuario inválido');
    }
    final fecha = texto('createdAt');
    if (DateTime.tryParse(fecha) == null) {
      throw const FormatException('Fecha de usuario inválida');
    }
    return UsuarioModel._(
      Usuario(
        idUsuario: id,
        nombres: texto('names'),
        apellidos: texto('surnames'),
        codigo: texto('code'),
        correo: texto('email'),
        escuela: texto('school'),
        ciclo: ciclo,
        createdAt: fecha,
      ),
    );
  }

  Usuario toEntity() => _usuario;
  factory UsuarioModel.fromEntity(Usuario usuario) => UsuarioModel._(usuario);
  Map<String, dynamic> toJson() => {
    'id': _usuario.idUsuario,
    'names': _usuario.nombres,
    'surnames': _usuario.apellidos,
    'code': _usuario.codigo,
    'email': _usuario.correo,
    'school': _usuario.escuela,
    'cycle': _usuario.ciclo,
    'createdAt': _usuario.createdAt,
  };
}
