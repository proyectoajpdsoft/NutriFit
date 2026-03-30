class PlanNutriItem {
  int? codigo;
  int? codigoAlimento;
  String? alimentoNombre;
  String? descripcionManual;
  String? cantidad;
  String? unidad;
  int orden;
  String? notas;
  String? opcion;
  String? harvardCategoria; // primary Harvard tag, e.g. 'verdura'
  String? harvardColor; // hex color from nu_harvard_categoria
  String? harvardSeccion; // seccion_plato

  PlanNutriItem({
    this.codigo,
    this.codigoAlimento,
    this.alimentoNombre,
    this.descripcionManual,
    this.cantidad,
    this.unidad,
    this.orden = 1,
    this.notas,
    this.opcion,
    this.harvardCategoria,
    this.harvardColor,
    this.harvardSeccion,
  });

  factory PlanNutriItem.fromJson(Map<String, dynamic> json) {
    return PlanNutriItem(
      codigo: int.tryParse(json['codigo']?.toString() ?? ''),
      codigoAlimento: int.tryParse(json['codigo_alimento']?.toString() ?? ''),
      alimentoNombre: json['alimento_nombre']?.toString(),
      descripcionManual: json['descripcion_manual']?.toString(),
      cantidad: json['cantidad']?.toString(),
      unidad: json['unidad']?.toString(),
      orden: int.tryParse(json['orden']?.toString() ?? '1') ?? 1,
      notas: json['notas']?.toString(),
      opcion: json['opcion']?.toString(),
      harvardCategoria: (json['harvard_categoria']?.toString() ?? '').isNotEmpty
          ? json['harvard_categoria'].toString()
          : null,
      harvardColor: (json['harvard_color']?.toString() ?? '').isNotEmpty
          ? json['harvard_color'].toString()
          : null,
      harvardSeccion: (json['harvard_seccion']?.toString() ?? '').isNotEmpty
          ? json['harvard_seccion'].toString()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'codigo_alimento': codigoAlimento,
      'descripcion_manual': descripcionManual,
      'cantidad': cantidad,
      'unidad': unidad,
      'orden': orden,
      'notas': notas,
      'opcion': opcion,
    };
  }
}

class PlanNutriIngesta {
  int? codigo;
  String tipoIngesta;
  int orden;
  String? observaciones;
  List<PlanNutriItem> items;

  PlanNutriIngesta({
    this.codigo,
    required this.tipoIngesta,
    required this.orden,
    this.observaciones,
    List<PlanNutriItem>? items,
  }) : items = items ?? <PlanNutriItem>[];

  factory PlanNutriIngesta.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return PlanNutriIngesta(
      codigo: int.tryParse(json['codigo']?.toString() ?? ''),
      tipoIngesta: (json['tipo_ingesta'] ?? '').toString(),
      orden: int.tryParse(json['orden']?.toString() ?? '1') ?? 1,
      observaciones: json['observaciones']?.toString(),
      items: rawItems
          .whereType<Map>()
          .map((e) => PlanNutriItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'tipo_ingesta': tipoIngesta,
      'orden': orden,
      'observaciones': observaciones,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}

class PlanNutriDia {
  int? codigo;
  int diaSemana;
  String nombreDia;
  String? observaciones;
  List<PlanNutriIngesta> ingestas;

  PlanNutriDia({
    this.codigo,
    required this.diaSemana,
    required this.nombreDia,
    this.observaciones,
    List<PlanNutriIngesta>? ingestas,
  }) : ingestas = ingestas ?? <PlanNutriIngesta>[];

  static const Map<String, String> _nombreDiaFix = {
    'Miercoles': 'Miércoles',
    'miercoles': 'Miércoles',
    'MIERCOLES': 'Miércoles',
    'Sabado': 'Sábado',
    'sabado': 'Sábado',
    'SABADO': 'Sábado',
  };

  factory PlanNutriDia.fromJson(Map<String, dynamic> json) {
    final rawIngestas = (json['ingestas'] as List?) ?? const [];
    final rawNombre = (json['nombre_dia'] ?? '').toString();
    return PlanNutriDia(
      codigo: int.tryParse(json['codigo']?.toString() ?? ''),
      diaSemana: int.tryParse(json['dia_semana']?.toString() ?? '0') ?? 0,
      nombreDia: _nombreDiaFix[rawNombre] ?? rawNombre,
      observaciones: json['observaciones']?.toString(),
      ingestas: rawIngestas
          .whereType<Map>()
          .map((e) => PlanNutriIngesta.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'dia_semana': diaSemana,
      'nombre_dia': nombreDia,
      'observaciones': observaciones,
      'ingestas': ingestas.map((e) => e.toJson()).toList(),
    };
  }
}

class PlanNutriSemana {
  int? codigo;
  int numeroSemana;
  int orden;
  String? titulo;
  String? completada;
  List<PlanNutriDia> dias;

  PlanNutriSemana({
    this.codigo,
    required this.numeroSemana,
    this.orden = 1,
    this.titulo,
    this.completada,
    List<PlanNutriDia>? dias,
  }) : dias = dias ?? <PlanNutriDia>[];

  factory PlanNutriSemana.fromJson(Map<String, dynamic> json) {
    final rawDias = (json['dias'] as List?) ?? const [];
    return PlanNutriSemana(
      codigo: int.tryParse(json['codigo']?.toString() ?? ''),
      numeroSemana: int.tryParse(json['numero_semana']?.toString() ?? '1') ?? 1,
      orden: int.tryParse(json['orden']?.toString() ?? '1') ?? 1,
      titulo: json['titulo']?.toString(),
      completada: json['completada']?.toString(),
      dias: rawDias
          .whereType<Map>()
          .map((e) => PlanNutriDia.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'numero_semana': numeroSemana,
      'orden': orden,
      'titulo': titulo,
      'completada': completada,
      'dias': dias.map((e) => e.toJson()).toList(),
    };
  }
}

class PlanNutriRecetaVinculada {
  int codigoReceta;
  String? recetaTitulo;
  int orden;

  PlanNutriRecetaVinculada({
    required this.codigoReceta,
    this.recetaTitulo,
    this.orden = 1,
  });

  factory PlanNutriRecetaVinculada.fromJson(Map<String, dynamic> json) {
    return PlanNutriRecetaVinculada(
      codigoReceta: int.tryParse(json['codigo_receta']?.toString() ?? '0') ?? 0,
      recetaTitulo: json['receta_titulo']?.toString(),
      orden: int.tryParse(json['orden']?.toString() ?? '1') ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo_receta': codigoReceta,
      'receta_titulo': recetaTitulo,
      'orden': orden,
    };
  }
}

class PlanNutriEstructura {
  int codigoPlanNutricional;
  String? tituloPlan;
  String? objetivoPlan;
  String? planIndicaciones;
  String? planIndicacionesVisibleUsuario;
  List<PlanNutriRecetaVinculada> recetas;
  List<PlanNutriSemana> semanas;

  PlanNutriEstructura({
    required this.codigoPlanNutricional,
    this.tituloPlan,
    this.objetivoPlan,
    this.planIndicaciones,
    this.planIndicacionesVisibleUsuario,
    List<PlanNutriRecetaVinculada>? recetas,
    List<PlanNutriSemana>? semanas,
  })  : recetas = recetas ?? <PlanNutriRecetaVinculada>[],
        semanas = semanas ?? <PlanNutriSemana>[];

  factory PlanNutriEstructura.fromJson(Map<String, dynamic> json) {
    final rawRecetas = (json['recetas'] as List?) ?? const [];
    final rawSemanas = (json['semanas'] as List?) ?? const [];
    return PlanNutriEstructura(
      codigoPlanNutricional:
          int.tryParse(json['codigo_plan_nutricional']?.toString() ?? '0') ?? 0,
      tituloPlan: json['titulo_plan']?.toString(),
      objetivoPlan: json['objetivo_plan']?.toString(),
      planIndicaciones: json['plan_indicaciones']?.toString(),
      planIndicacionesVisibleUsuario:
          json['plan_indicaciones_visible_usuario']?.toString() ??
              json['recomendaciones']?.toString(),
      recetas: rawRecetas
          .whereType<Map>()
          .map((e) =>
              PlanNutriRecetaVinculada.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      semanas: rawSemanas
          .whereType<Map>()
          .map((e) => PlanNutriSemana.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo_plan_nutricional': codigoPlanNutricional,
      'titulo_plan': tituloPlan,
      'objetivo_plan': objetivoPlan,
      'plan_indicaciones': planIndicaciones,
      'plan_indicaciones_visible_usuario': planIndicacionesVisibleUsuario,
      'recomendaciones': planIndicacionesVisibleUsuario,
      'recetas': recetas.map((e) => e.toJson()).toList(),
      'semanas': semanas.map((e) => e.toJson()).toList(),
    };
  }
}
