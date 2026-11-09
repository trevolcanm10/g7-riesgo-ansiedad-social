import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../models/escuela_model.dart';

/// DataSource local del catálogo de escuelas profesionales de la UNMSM.
///
/// La lectura del asset está separada del procesamiento: [obtenerEscuelas]
/// lee `assets/data/escuelas.json` mediante [rootBundle] y delega el
/// recorrido de `areas_academicas → facultades → escuelas` en
/// [procesarCatalogo]. No utiliza base de datos ni peticiones HTTP.
class EscuelaLocalDataSource {
  /// Ruta del asset declarado en `pubspec.yaml`.
  static const String rutaAsset = 'assets/data/escuelas.json';

  /// Lee el catálogo desde el asset local y lo procesa.
  Future<List<EscuelaModel>> obtenerEscuelas() async {
    final contenido = await rootBundle.loadString(rutaAsset);
    return procesarCatalogo(contenido);
  }

  /// Procesa el JSON del catálogo: extrae cada escuela conservando su
  /// facultad y área académica, elimina los duplicados exactos y ordena
  /// la lista resultante alfabéticamente.
  List<EscuelaModel> procesarCatalogo(String contenido) {
    final decodificado = jsonDecode(contenido);

    if (decodificado is! Map<String, dynamic>) {
      throw const FormatException('Catálogo de escuelas con estructura inválida');
    }

    final areas = decodificado['areas_academicas'];
    if (areas is! List) {
      throw const FormatException('Catálogo de escuelas sin áreas académicas');
    }

    final escuelas = <EscuelaModel>[];
    final clavesVistas = <String>{};

    for (final area in areas) {
      if (area is! Map<String, dynamic>) continue;
      final nombreArea = area['area'] as String? ?? '';

      final facultades = area['facultades'];
      if (facultades is! List) continue;

      for (final facultad in facultades) {
        if (facultad is! Map<String, dynamic>) continue;
        final nombreFacultad = facultad['nombre'] as String? ?? '';

        final escuelasFacultad = facultad['escuelas'];
        if (escuelasFacultad is! List) continue;

        for (final nombre in escuelasFacultad) {
          if (nombre is! String || nombre.trim().isEmpty) continue;

          final escuela = EscuelaModel.fromJson({
            'nombre': nombre.trim(),
            'facultad': nombreFacultad,
            'area_academica': nombreArea,
          });

          // Evita duplicados exactos: misma escuela, facultad y área.
          final clave =
              '${escuela.nombre}|${escuela.facultad}|${escuela.areaAcademica}';
          if (!clavesVistas.add(clave)) continue;

          escuelas.add(escuela);
        }
      }
    }

    escuelas.sort((a, b) => _compararAlfabeticamente(a.nombre, b.nombre));
    return escuelas;
  }

  /// Compara dos nombres ignorando mayúsculas/minúsculas y acentos.
  int _compararAlfabeticamente(String a, String b) {
    return _sinAcentos(a.toLowerCase()).compareTo(_sinAcentos(b.toLowerCase()));
  }

  /// Convierte el texto a minúsculas sin acentos para comparaciones.
  String _sinAcentos(String texto) {
    const conAcentos = 'áéíóúüñ';
    const sinAcentos = 'aeiouun';
    var resultado = texto;
    for (var i = 0; i < conAcentos.length; i++) {
      resultado = resultado.replaceAll(conAcentos[i], sinAcentos[i]);
    }
    return resultado;
  }
}
