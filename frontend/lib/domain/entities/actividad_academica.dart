class ActividadAcademica {
  final String id;
  final String titulo;
  final String curso;
  final String tipo;
  final DateTime fecha;
  final String? hora;
  final double? duracionEstimadaHoras;
  final String prioridad;
  final String descripcion;
  final bool completada;

  const ActividadAcademica({
    required this.id,
    required this.titulo,
    required this.curso,
    required this.tipo,
    required this.fecha,
    required this.hora,
    required this.duracionEstimadaHoras,
    required this.prioridad,
    required this.descripcion,
    required this.completada,
  });

  ActividadAcademica copyWith({bool? completada}) => ActividadAcademica(
    id: id, titulo: titulo, curso: curso, tipo: tipo, fecha: fecha,
    hora: hora, duracionEstimadaHoras: duracionEstimadaHoras,
    prioridad: prioridad, descripcion: descripcion,
    completada: completada ?? this.completada,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'titulo': titulo, 'curso': curso, 'tipo': tipo,
    'fecha': '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
    'hora': hora, 'duracionEstimadaHoras': duracionEstimadaHoras,
    'prioridad': prioridad, 'descripcion': descripcion,
    'estado': completada ? 'completada' : 'pendiente',
  };

  factory ActividadAcademica.fromJson(Map<String, dynamic> json) => ActividadAcademica(
    id: json['id'] as String,
    titulo: json['titulo'] as String,
    curso: json['curso'] as String,
    tipo: json['tipo'] as String,
    fecha: DateTime.parse(json['fecha'] as String),
    hora: json['hora'] as String?,
    duracionEstimadaHoras: (json['duracionEstimadaHoras'] as num?)?.toDouble(),
    prioridad: json['prioridad'] as String,
    descripcion: json['descripcion'] as String? ?? '',
    completada: json['estado'] == 'completada',
  );
}
