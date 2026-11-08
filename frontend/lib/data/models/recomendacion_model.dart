import '../../domain/entities/recomendacion.dart';

/// DTO (Data Transfer Object) para serializar/deserializar Recomendacion.
///
/// Esta clase maneja la conversión desde/hacia JSON,
/// y puede convertirse a la entidad de dominio Recomendacion.
class RecomendacionModel {
  final int idRecomendacion;
  final String categoria; // 'BAJO', 'MEDIO', 'ALTO'
  final String titulo;
  final String descripcion;

  RecomendacionModel({
    required this.idRecomendacion,
    required this.categoria,
    required this.titulo,
    required this.descripcion,
  });

  /// Crea un DTO desde JSON (respuesta de la API)
  factory RecomendacionModel.fromJson(Map<String, dynamic> json) {
    return RecomendacionModel(
      idRecomendacion: json['id_recomendacion'] ?? 0,
      categoria: json['categoria'] ?? '',
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? '',
    );
  }

  /// Crea un DTO desde una recomendacion del contrato de RiskEvaluation.
  ///
  /// El backend responde camelCase (id, category, title, description). Una
  /// recomendacion incompleta es un error: no se rellena con cadenas vacias,
  /// porque eso mostraria al usuario una recomendacion inventada.
  factory RecomendacionModel.fromRiskEvaluation(Map<String, dynamic> json) {
    final id = json['id'];
    final category = json['category'];
    final title = json['title'];
    final description = json['description'];
    if (id is! int ||
        id <= 0 ||
        category is! String ||
        !{'BAJO', 'MEDIO', 'ALTO'}.contains(category) ||
        title is! String ||
        title.trim().isEmpty ||
        description is! String ||
        description.trim().isEmpty) {
      throw const FormatException(
        'La respuesta del servicio no contiene una recomendacion valida.',
      );
    }
    return RecomendacionModel(
      idRecomendacion: id,
      categoria: category,
      titulo: title,
      descripcion: description,
    );
  }

  /// Convierte el DTO a entidad de dominio
  Recomendacion toEntity() {
    return Recomendacion(
      idRecomendacion: idRecomendacion,
      categoria: categoria,
      titulo: titulo,
      descripcion: descripcion,
    );
  }

  /// Crea un DTO desde una entidad de dominio
  factory RecomendacionModel.fromEntity(Recomendacion recomendacion) {
    return RecomendacionModel(
      idRecomendacion: recomendacion.idRecomendacion,
      categoria: recomendacion.categoria,
      titulo: recomendacion.titulo,
      descripcion: recomendacion.descripcion,
    );
  }

  /// Convierte el DTO a JSON (para enviar a la API)
  Map<String, dynamic> toJson() {
    return {
      'id_recomendacion': idRecomendacion,
      'categoria': categoria,
      'titulo': titulo,
      'descripcion': descripcion,
    };
  }
}
