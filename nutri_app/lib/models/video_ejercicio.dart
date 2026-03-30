class VideoEjercicio {
  int? codigo;
  String titulo;
  String? descripcion;
  String tipoMedia; // 'local' | 'youtube'
  String? rutaVideo; // ruta relativa o URL de YouTube
  String? formato; // 'mp4' | 'gif' | null para YouTube
  String? imagenMiniatura; // base64
  String? imagenMiniaturaNombre;
  String visible; // 'S' | 'N'
  int totalLikes;
  DateTime? fechaa;
  int? codusuarioa;
  DateTime? fecham;
  int? codusuariom;
  String meGusta; // 'S' | 'N'
  String favorito; // 'S' | 'N'
  List<int> categoriaIds;
  List<String> categoriaNombres;

  VideoEjercicio({
    this.codigo,
    required this.titulo,
    this.descripcion,
    this.tipoMedia = 'local',
    this.rutaVideo,
    this.formato,
    this.imagenMiniatura,
    this.imagenMiniaturaNombre,
    this.visible = 'S',
    this.totalLikes = 0,
    this.fechaa,
    this.codusuarioa,
    this.fecham,
    this.codusuariom,
    this.meGusta = 'N',
    this.favorito = 'N',
    List<int>? categoriaIds,
    List<String>? categoriaNombres,
  })  : categoriaIds = categoriaIds ?? <int>[],
        categoriaNombres = categoriaNombres ?? <String>[];

  factory VideoEjercicio.fromJson(Map<String, dynamic> json) {
    return VideoEjercicio(
      codigo:
          json['codigo'] != null ? int.parse(json['codigo'].toString()) : null,
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'],
      tipoMedia: json['tipo_media'] ?? 'local',
      rutaVideo: json['ruta_video'],
      formato: json['formato'],
      imagenMiniatura: json['imagen_miniatura'],
      imagenMiniaturaNombre: json['imagen_miniatura_nombre'],
      visible: json['visible'] ?? 'S',
      totalLikes: json['total_likes'] != null
          ? int.parse(json['total_likes'].toString())
          : 0,
      fechaa: json['fechaa'] != null ? DateTime.tryParse(json['fechaa']) : null,
      codusuarioa: json['codusuarioa'] != null
          ? int.tryParse(json['codusuarioa'].toString())
          : null,
      fecham: json['fecham'] != null ? DateTime.tryParse(json['fecham']) : null,
      codusuariom: json['codusuariom'] != null
          ? int.tryParse(json['codusuariom'].toString())
          : null,
      meGusta: json['me_gusta'] ?? 'N',
      favorito: json['favorito'] ?? 'N',
      categoriaIds: _parseCsv(json['categorias_ids']),
      categoriaNombres: _parseCsvStr(json['categorias_nombres']),
    );
  }

  static List<int> _parseCsv(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return [];
    return raw
        .toString()
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }

  static List<String> _parseCsvStr(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return [];
    return raw.toString().split(',').map((e) => e.trim()).toList();
  }

  Map<String, dynamic> toJson() => {
        if (codigo != null) 'codigo': codigo,
        'titulo': titulo,
        if (descripcion != null) 'descripcion': descripcion,
        'tipo_media': tipoMedia,
        if (rutaVideo != null) 'ruta_video': rutaVideo,
        if (formato != null) 'formato': formato,
        if (imagenMiniatura != null) 'imagen_miniatura': imagenMiniatura,
        if (imagenMiniaturaNombre != null)
          'imagen_miniatura_nombre': imagenMiniaturaNombre,
        'visible': visible,
        'me_gusta': meGusta,
        'favorito': favorito,
        'categorias': categoriaIds,
      };

  bool get esYoutube => tipoMedia.toLowerCase() == 'youtube';
  bool get esLocal => tipoMedia.toLowerCase() == 'local';
  bool get esGif => (formato ?? '').toLowerCase() == 'gif';
}
