class TodoItem {
  int codigo;
  int codigoUsuario;
  String titulo;
  String? descripcion;
  DateTime? fechaTarea;
  String estado; // P = Pendiente, R = Resuelta
  String prioridad; // A = Alta, M = Media, B = Baja
  DateTime? fechaResuelta;
  DateTime? fechaa;
  DateTime? fecham;

  TodoItem({
    required this.codigo,
    required this.codigoUsuario,
    required this.titulo,
    this.descripcion,
    this.fechaTarea,
    this.estado = 'P',
    this.prioridad = 'M',
    this.fechaResuelta,
    this.fechaa,
    this.fecham,
  });

  bool get isResuelta => estado.toUpperCase() == 'R';

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      final raw = value?.toString();
      if (raw == null || raw.isEmpty) {
        return null;
      }
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }

    return TodoItem(
      codigo: json['codigo'] is int
          ? json['codigo']
          : int.tryParse(json['codigo']?.toString() ?? '') ?? 0,
      codigoUsuario: json['codigo_usuario'] is int
          ? json['codigo_usuario']
          : int.tryParse(json['codigo_usuario']?.toString() ?? '') ?? 0,
      titulo: (json['titulo'] ?? '').toString(),
      descripcion: json['descripcion']?.toString(),
      fechaTarea: parseDate(json['fecha_tarea']),
      estado: (json['estado'] ?? 'P').toString(),
      prioridad: (json['prioridad'] ?? 'M').toString(),
      fechaResuelta: parseDate(json['fecha_resuelta']),
      fechaa: parseDate(json['fechaa']),
      fecham: parseDate(json['fecham']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'codigo_usuario': codigoUsuario,
      'titulo': titulo,
      'descripcion': descripcion,
      'fecha_tarea': fechaTarea?.toIso8601String(),
      'estado': estado,
      'prioridad': prioridad,
      'fecha_resuelta': fechaResuelta?.toIso8601String(),
      'fechaa': fechaa?.toIso8601String(),
      'fecham': fecham?.toIso8601String(),
    };
  }
}
