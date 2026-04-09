class CharlaSeminario {
  CharlaSeminario({
    this.codigo,
    required this.titulo,
    this.descripcion = '',
    this.activo = 'S',
    this.mostrarPortada = 'N',
    this.visibleParaTodos = 'N',
    this.imagenPortada,
    this.imagenPortadaNombre,
    this.imagenMiniatura,
    this.totalDiapositivas = 0,
    this.totalLikes = 0,
    this.meGusta,
    this.favorito,
    this.ultimaDiapositivaVista = 0,
    this.fechaa,
    this.codusuarioa,
    this.fecham,
    this.codusuariom,
    this.audioGlobal,
    this.audioGlobalNombre,
    this.audioGlobalMime,
    this.timelinePresentacionJson,
    List<int>? categoriaIds,
    List<String>? categoriaNombres,
  })  : categoriaIds = categoriaIds ?? <int>[],
        categoriaNombres = categoriaNombres ?? <String>[];

  int? codigo;
  String titulo;
  String descripcion;
  String activo;
  String mostrarPortada;
  String visibleParaTodos;
  String? imagenPortada;
  String? imagenPortadaNombre;
  String? imagenMiniatura;
  int totalDiapositivas;
  int totalLikes;
  String? meGusta;
  String? favorito;
  int ultimaDiapositivaVista;

  /// Audio global base64 (puede ser null si no se ha configurado)
  String? audioGlobal;
  String? audioGlobalNombre;
  String? audioGlobalMime;
  String? timelinePresentacionJson;
  DateTime? fechaa;
  int? codusuarioa;
  DateTime? fecham;
  int? codusuariom;
  List<int> categoriaIds;
  List<String> categoriaNombres;

  factory CharlaSeminario.fromJson(Map<String, dynamic> json) {
    return CharlaSeminario(
      codigo: json['codigo'] != null
          ? int.tryParse(json['codigo'].toString())
          : null,
      titulo: (json['titulo'] ?? '').toString(),
      descripcion: (json['descripcion'] ?? '').toString(),
      activo: (json['activo'] ?? 'S').toString(),
      mostrarPortada: (json['mostrar_portada'] ?? 'N').toString(),
      visibleParaTodos: (json['visible_para_todos'] ?? 'N').toString(),
      imagenPortada: json['imagen_portada']?.toString(),
      imagenPortadaNombre: json['imagen_portada_nombre']?.toString(),
      imagenMiniatura: json['imagen_miniatura']?.toString(),
      totalDiapositivas: json['total_diapositivas'] != null
          ? int.tryParse(json['total_diapositivas'].toString()) ?? 0
          : 0,
      totalLikes: json['total_likes'] != null
          ? int.tryParse(json['total_likes'].toString()) ?? 0
          : 0,
      meGusta: json['me_gusta']?.toString(),
      favorito: json['favorito']?.toString(),
      ultimaDiapositivaVista: json['ultima_diapositiva_vista'] != null
          ? int.tryParse(json['ultima_diapositiva_vista'].toString()) ?? 0
          : 0,
      fechaa: json['fechaa'] != null
          ? DateTime.tryParse(json['fechaa'].toString())
          : null,
      codusuarioa: json['codusuarioa'] != null
          ? int.tryParse(json['codusuarioa'].toString())
          : null,
      fecham: json['fecham'] != null
          ? DateTime.tryParse(json['fecham'].toString())
          : null,
      codusuariom: json['codusuariom'] != null
          ? int.tryParse(json['codusuariom'].toString())
          : null,
      audioGlobal: json['audio_global']?.toString(),
      audioGlobalNombre: json['audio_global_nombre']?.toString(),
      audioGlobalMime: json['audio_global_mime']?.toString(),
      timelinePresentacionJson: json['timeline_presentacion_json']?.toString(),
      categoriaIds: _parseIds(json['categorias_ids']),
      categoriaNombres: _parseNames(json['categorias_nombres']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (codigo != null) 'codigo': codigo,
      'titulo': titulo,
      'descripcion': descripcion,
      'activo': activo,
      'mostrar_portada': mostrarPortada,
      'visible_para_todos': visibleParaTodos,
      if (imagenPortada != null) 'imagen_portada': imagenPortada,
      if (imagenPortadaNombre != null)
        'imagen_portada_nombre': imagenPortadaNombre,
      if (imagenMiniatura != null) 'imagen_miniatura': imagenMiniatura,
      'categorias': categoriaIds,
    };
  }

  static List<int> _parseIds(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return <int>[];
    return raw
        .toString()
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList(growable: false);
  }

  static List<String> _parseNames(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return <String>[];
    return raw
        .toString()
        .split(',')
        .map((e) => e.trim())
        .toList(growable: false);
  }
}
