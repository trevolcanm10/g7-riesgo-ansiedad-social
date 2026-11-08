/// Usuario público de Users, sin roles ni credenciales.
class Usuario {
  final int idUsuario;
  final String nombres;
  final String apellidos;
  final String codigo;
  final String correo;
  final String escuela;
  final int ciclo;
  final String createdAt;

  const Usuario({
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.codigo,
    required this.correo,
    required this.escuela,
    required this.ciclo,
    required this.createdAt,
  });

  String get nombre => '$nombres $apellidos'.trim();
}
