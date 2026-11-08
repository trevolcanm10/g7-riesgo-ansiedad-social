/// Entidad de dominio que representa una Escuela Profesional de la UNMSM.
///
/// Conserva la relación de la escuela con su facultad y su área académica.
/// Es una entidad pura sin dependencias de serialización.
class Escuela {
  final String nombre;
  final String facultad;
  final String areaAcademica;

  const Escuela({
    required this.nombre,
    required this.facultad,
    required this.areaAcademica,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Escuela &&
            runtimeType == other.runtimeType &&
            nombre == other.nombre &&
            facultad == other.facultad &&
            areaAcademica == other.areaAcademica;
  }

  @override
  int get hashCode => Object.hash(nombre, facultad, areaAcademica);

  @override
  String toString() {
    return 'Escuela(nombre: $nombre, facultad: $facultad, '
        'areaAcademica: $areaAcademica)';
  }
}
