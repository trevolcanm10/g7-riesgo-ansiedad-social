import '../../domain/entities/escuela.dart';

/// DTO (Data Transfer Object) de una Escuela del catálogo local.
///
/// Maneja la conversión desde JSON de una entrada plana del catálogo
/// y puede convertirse a la entidad de dominio Escuela.
class EscuelaModel {
  final String nombre;
  final String facultad;
  final String areaAcademica;

  EscuelaModel({
    required this.nombre,
    required this.facultad,
    required this.areaAcademica,
  });

  /// Crea un DTO desde una entrada plana del catálogo JSON local.
  factory EscuelaModel.fromJson(Map<String, dynamic> json) {
    return EscuelaModel(
      nombre: json['nombre'] as String? ?? '',
      facultad: json['facultad'] as String? ?? '',
      areaAcademica: json['area_academica'] as String? ?? '',
    );
  }

  /// Convierte el DTO a entidad de dominio.
  Escuela toEntity() {
    return Escuela(
      nombre: nombre,
      facultad: facultad,
      areaAcademica: areaAcademica,
    );
  }
}
