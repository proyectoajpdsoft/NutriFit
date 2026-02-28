class Receta {
  int? codigo;
  String titulo;
  String texto;
  String activo;
  DateTime? fechaInicio;
  DateTime? fechaFin;
  String mostrarPortada;
  DateTime? fechaInicioPortada;
  DateTime? fechaFinPortada;
  String visibleParaTodos;
  String? imagenPortada; // Base64
  String? imagenPortadaNombre;
  String? imagenMiniatura; // Base64 thumbnail
  DateTime? fechaa;
  int? codusuarioa;
  DateTime? fecham;
  int? codusuariom;
  int? totalLikes;
  int? totalPacientes;
  String? meGusta; // Para pacientes: 'S' o 'N'
  String? favorito; // Para pacientes: 'S' o 'N'
  List<int> categoriaIds;
  List<String> categoriaNombres;

  Receta({
    this.codigo,
    required this.titulo,
    required this.texto,
    this.activo = 'S',
    this.fechaInicio,
    this.fechaFin,
    this.mostrarPortada = 'N',
    this.fechaInicioPortada,
    this.fechaFinPortada,
    this.visibleParaTodos = 'S',
    this.imagenPortada,
    this.imagenPortadaNombre,
    this.imagenMiniatura,
    this.fechaa,
    this.codusuarioa,
    this.fecham,
    this.codusuariom,
    this.totalLikes,
    this.totalPacientes,
    this.meGusta,
    this.favorito,
    List<int>? categoriaIds,
    List<String>? categoriaNombres,
  })  : categoriaIds = categoriaIds ?? <int>[],
        categoriaNombres = categoriaNombres ?? <String>[];

  factory Receta.fromJson(Map<String, dynamic> json) {
    return Receta(
      codigo:
          json['codigo'] != null ? int.parse(json['codigo'].toString()) : null,
      titulo: json['titulo'] ?? '',
      texto: json['texto'] ?? '',
      activo: json['activo'] ?? 'S',
      fechaInicio: json['fecha_inicio'] != null
          ? DateTime.parse(json['fecha_inicio'])
          : null,
      fechaFin:
          json['fecha_fin'] != null ? DateTime.parse(json['fecha_fin']) : null,
      mostrarPortada: json['mostrar_portada'] ?? 'N',
      fechaInicioPortada: json['fecha_inicio_portada'] != null
          ? DateTime.parse(json['fecha_inicio_portada'])
          : null,
      fechaFinPortada: json['fecha_fin_portada'] != null
          ? DateTime.parse(json['fecha_fin_portada'])
          : null,
      visibleParaTodos: json['visible_para_todos'] ?? 'S',
      imagenPortada: json['imagen_portada'],
      imagenPortadaNombre: json['imagen_portada_nombre'],
      imagenMiniatura: json['imagen_miniatura'],
      fechaa: json['fechaa'] != null ? DateTime.parse(json['fechaa']) : null,
      codusuarioa: json['codusuarioa'] != null
          ? int.parse(json['codusuarioa'].toString())
          : null,
      fecham: json['fecham'] != null ? DateTime.parse(json['fecham']) : null,
      codusuariom: json['codusuariom'] != null
          ? int.parse(json['codusuariom'].toString())
          : null,
      totalLikes: json['total_likes'] != null
          ? int.parse(json['total_likes'].toString())
          : 0,
      totalPacientes: json['total_pacientes'] != null
          ? int.parse(json['total_pacientes'].toString())
          : 0,
      meGusta: json['me_gusta'],
      favorito: json['favorito'],
      categoriaIds: _parseIds(json['categorias_ids']),
      categoriaNombres: _parseNames(json['categorias_nombres']),
    );
  }

  static List<int> _parseIds(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((item) => int.tryParse(item.toString()))
          .whereType<int>()
          .toList();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return [];
    return raw
        .split(',')
        .map((item) => int.tryParse(item.trim()))
        .whereType<int>()
        .toList();
  }

  static List<String> _parseNames(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return [];
    return raw.split(',').map((item) => item.trim()).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'titulo': titulo,
      'texto': texto,
      'activo': activo,
      'fecha_inicio': fechaInicio?.toIso8601String().split('T')[0],
      'fecha_fin': fechaFin?.toIso8601String().split('T')[0],
      'mostrar_portada': mostrarPortada,
      'fecha_inicio_portada':
          fechaInicioPortada?.toIso8601String().split('T')[0],
      'fecha_fin_portada': fechaFinPortada?.toIso8601String().split('T')[0],
      'visible_para_todos': visibleParaTodos,
      'imagen_portada': imagenPortada,
      'imagen_portada_nombre': imagenPortadaNombre,
      'imagen_miniatura': imagenMiniatura,
      'codusuarioa': codusuarioa,
      'codusuariom': codusuariom,
      'categorias': categoriaIds,
    };
  }
}
