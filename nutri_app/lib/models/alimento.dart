class Alimento {
  int? codigo;
  String nombre;
  int? codigoGrupo;
  String? nombreGrupo;
  List<int> codigoGrupos;
  List<String> nombreGrupos;
  int activo;
  String? observacion;
  String? opcion;
  int totalIngestas;
  String? harvardCategoria; // e.g. 'verdura', 'proteina_blanca'
  String? harvardNombre; // display name
  List<String> harvardCategorias; // multiple tags
  List<String> harvardCategoriasNombres; // multiple display names
  String? harvardColor; // hex like '#4CAF50'
  String? harvardSeccion; // seccion_plato
  bool harvardRecomendado; // true = recommended

  Alimento({
    this.codigo,
    required this.nombre,
    this.codigoGrupo,
    this.nombreGrupo,
    this.codigoGrupos = const [],
    this.nombreGrupos = const [],
    this.activo = 1,
    this.observacion,
    this.opcion,
    this.totalIngestas = 0,
    this.harvardCategoria,
    this.harvardNombre,
    this.harvardCategorias = const [],
    this.harvardCategoriasNombres = const [],
    this.harvardColor,
    this.harvardSeccion,
    this.harvardRecomendado = true,
  });

  factory Alimento.fromJson(Map<String, dynamic> json) {
    final gruposFromCsv = (json['categorias_ids'] ?? '')
        .toString()
        .split(',')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .where((e) => e > 0)
        .toList();
    final nombresFromCsv = (json['categorias_nombres'] ?? '')
        .toString()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final legacyGrupo = int.tryParse(json['codigo_grupo']?.toString() ?? '');

    final codigoGrupos = gruposFromCsv.isNotEmpty
        ? gruposFromCsv
        : (legacyGrupo != null ? <int>[legacyGrupo] : <int>[]);
    final nombreGrupo = json['nombre_grupo']?.toString();
    final nombreGrupos = nombresFromCsv.isNotEmpty
        ? nombresFromCsv
        : ((nombreGrupo ?? '').trim().isNotEmpty
            ? <String>[nombreGrupo!.trim()]
            : <String>[]);
    final harvardCategoriasFromCsv = (json['harvard_categorias'] ?? '')
        .toString()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final harvardNombresFromCsv = (json['harvard_categorias_nombres'] ?? '')
        .toString()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final primaryHarvard = (json['harvard_categoria']?.toString() ?? '').trim();

    final harvardCategorias = harvardCategoriasFromCsv.isNotEmpty
        ? harvardCategoriasFromCsv
        : (primaryHarvard.isNotEmpty ? <String>[primaryHarvard] : <String>[]);
    final primaryHarvardNombre =
        (json['harvard_nombre']?.toString() ?? '').trim();
    final harvardCategoriasNombres = harvardNombresFromCsv.isNotEmpty
        ? harvardNombresFromCsv
        : (primaryHarvardNombre.isNotEmpty
            ? <String>[primaryHarvardNombre]
            : <String>[]);

    return Alimento(
      codigo: int.tryParse(json['codigo']?.toString() ?? ''),
      nombre: (json['nombre'] ?? '').toString(),
      codigoGrupo: codigoGrupos.isNotEmpty ? codigoGrupos.first : legacyGrupo,
      nombreGrupo: nombreGrupos.isNotEmpty ? nombreGrupos.first : nombreGrupo,
      codigoGrupos: codigoGrupos,
      nombreGrupos: nombreGrupos,
      activo: int.tryParse(json['activo']?.toString() ?? '1') ?? 1,
      observacion: json['observacion']?.toString(),
      opcion: json['opcion']?.toString(),
      totalIngestas:
          int.tryParse(json['total_ingestas']?.toString() ?? '0') ?? 0,
      harvardCategoria: primaryHarvard.isNotEmpty ? primaryHarvard : null,
      harvardNombre:
          primaryHarvardNombre.isNotEmpty ? primaryHarvardNombre : null,
      harvardCategorias: harvardCategorias,
      harvardCategoriasNombres: harvardCategoriasNombres,
      harvardColor: (json['harvard_color']?.toString() ?? '').isNotEmpty
          ? json['harvard_color'].toString()
          : null,
      harvardSeccion: (json['harvard_seccion']?.toString() ?? '').isNotEmpty
          ? json['harvard_seccion'].toString()
          : null,
      harvardRecomendado:
          (json['harvard_recomendado']?.toString() ?? '1') == '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'codigo_grupo': codigoGrupo,
      'codigo_grupos': codigoGrupos,
      'activo': activo,
      'observacion': observacion,
      'opcion': opcion,
      'total_ingestas': totalIngestas,
      if (harvardCategoria != null) 'harvard_categoria': harvardCategoria,
      if (harvardCategorias.isNotEmpty) 'harvard_categorias': harvardCategorias,
    };
  }
}
