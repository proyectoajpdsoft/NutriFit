class SustitucionSaludable {
  SustitucionSaludable({
    this.codigo,
    required this.titulo,
    required this.alimentoOrigen,
    required this.sustitutoPrincipal,
    this.subtitulo = '',
    this.equivalenciaTexto = '',
    this.objetivoMacro = '',
    this.texto = '',
    this.activo = 'S',
    this.mostrarPortada = 'N',
    this.visibleParaTodos = 'S',
    this.imagenPortada,
    this.imagenPortadaNombre,
    this.imagenMiniatura,
    this.totalLikes = 0,
    this.meGusta,
    this.favorito,
    this.fechaa,
    this.codusuarioa,
    this.fecham,
    this.codusuariom,
    List<int>? categoriaIds,
    List<String>? categoriaNombres,
  })  : categoriaIds = categoriaIds ?? <int>[],
        categoriaNombres = categoriaNombres ?? <String>[];

  int? codigo;
  String titulo;
  String subtitulo;
  String alimentoOrigen;
  String sustitutoPrincipal;
  String equivalenciaTexto;
  String objetivoMacro;
  String texto;
  String activo;
  String mostrarPortada;
  String visibleParaTodos;
  String? imagenPortada;
  String? imagenPortadaNombre;
  String? imagenMiniatura;
  int totalLikes;
  String? meGusta;
  String? favorito;
  DateTime? fechaa;
  int? codusuarioa;
  DateTime? fecham;
  int? codusuariom;
  List<int> categoriaIds;
  List<String> categoriaNombres;

  String get resumenPrincipal {
    final equivalencia = equivalenciaTexto.trim();
    if (equivalencia.isNotEmpty) {
      return equivalencia;
    }
    final objetivo = objetivoMacro.trim();
    if (objetivo.isNotEmpty) {
      return objetivo;
    }
    return 'Si no tienes $alimentoOrigen, usa $sustitutoPrincipal';
  }

  factory SustitucionSaludable.fromJson(Map<String, dynamic> json) {
    return SustitucionSaludable(
      codigo: json['codigo'] != null
          ? int.tryParse(json['codigo'].toString())
          : null,
      titulo: (json['titulo'] ?? '').toString(),
      subtitulo: (json['subtitulo'] ?? '').toString(),
      alimentoOrigen: (json['alimento_origen'] ?? '').toString(),
      sustitutoPrincipal: (json['sustituto_principal'] ?? '').toString(),
      equivalenciaTexto: (json['equivalencia_texto'] ?? '').toString(),
      objetivoMacro: (json['objetivo_macro'] ?? '').toString(),
      texto: (json['texto'] ?? '').toString(),
      activo: (json['activo'] ?? 'S').toString(),
      mostrarPortada: (json['mostrar_portada'] ?? 'N').toString(),
      visibleParaTodos: (json['visible_para_todos'] ?? 'S').toString(),
      imagenPortada: json['imagen_portada']?.toString(),
      imagenPortadaNombre: json['imagen_portada_nombre']?.toString(),
      imagenMiniatura: json['imagen_miniatura']?.toString(),
      totalLikes: json['total_likes'] != null
          ? int.tryParse(json['total_likes'].toString()) ?? 0
          : 0,
      meGusta: json['me_gusta']?.toString(),
      favorito: json['favorito']?.toString(),
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
      categoriaIds: _parseIds(json['categorias_ids']),
      categoriaNombres: _parseNames(json['categorias_nombres']),
    );
  }

  static List<int> _parseIds(dynamic value) {
    if (value == null) return <int>[];
    if (value is List) {
      return value
          .map((item) => int.tryParse(item.toString()))
          .whereType<int>()
          .toList(growable: false);
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return <int>[];
    return raw
        .split(',')
        .map((item) => int.tryParse(item.trim()))
        .whereType<int>()
        .toList(growable: false);
  }

  static List<String> _parseNames(dynamic value) {
    if (value == null) return <String>[];
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return <String>[];
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'codigo': codigo,
      'titulo': titulo,
      'subtitulo': subtitulo,
      'alimento_origen': alimentoOrigen,
      'sustituto_principal': sustitutoPrincipal,
      'equivalencia_texto': equivalenciaTexto,
      'objetivo_macro': objetivoMacro,
      'texto': texto,
      'activo': activo,
      'mostrar_portada': mostrarPortada,
      'visible_para_todos': visibleParaTodos,
      'imagen_portada': imagenPortada,
      'imagen_portada_nombre': imagenPortadaNombre,
      'imagen_miniatura': imagenMiniatura,
      'categorias': categoriaIds,
    };
  }
}
