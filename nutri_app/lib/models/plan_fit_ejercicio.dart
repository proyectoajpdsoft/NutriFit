import 'dart:convert';

PlanFitEjercicio planFitEjercicioFromJson(String str) =>
    PlanFitEjercicio.fromJson(json.decode(str));
String planFitEjercicioToJson(PlanFitEjercicio data) =>
    json.encode(data.toJson());

class PlanFitEjercicio {
  int codigo;
  int codigoPlanFit;
  int? codigoDia;
  int? codigoEjercicioCatalogo;
  String nombre;
  String? instrucciones;
  String? instruccionesDetalladas;
  String? hashtag;
  String? urlVideo;
  String? fotoBase64;
  String? fotoNombre;
  String? fotoMiniatura;
  int? tiempo;
  int? descanso;
  int? repeticiones;
  int? kilos;
  int? orden;
  String? visiblePremium;
  int totalUsos;

  PlanFitEjercicio({
    required this.codigo,
    required this.codigoPlanFit,
    this.codigoDia,
    this.codigoEjercicioCatalogo,
    required this.nombre,
    this.instrucciones,
    this.instruccionesDetalladas,
    this.hashtag,
    this.urlVideo,
    this.fotoBase64,
    this.fotoNombre,
    this.fotoMiniatura,
    this.tiempo,
    this.descanso,
    this.repeticiones,
    this.kilos,
    this.orden,
    this.visiblePremium,
    this.totalUsos = 0,
  });

  factory PlanFitEjercicio.fromJson(Map<String, dynamic> json) {
    return PlanFitEjercicio(
      codigo: json['codigo'] is int
          ? json['codigo']
          : int.tryParse(json['codigo']?.toString() ?? '') ?? 0,
      codigoPlanFit: json['codigo_plan_fit'] is int
          ? json['codigo_plan_fit']
          : int.tryParse(json['codigo_plan_fit']?.toString() ?? '') ?? 0,
      codigoDia: json['codigo_dia'] is int
          ? json['codigo_dia']
          : int.tryParse(json['codigo_dia']?.toString() ?? ''),
      codigoEjercicioCatalogo: json['codigo_ejercicio_catalogo'] is int
          ? json['codigo_ejercicio_catalogo']
          : int.tryParse(json['codigo_ejercicio_catalogo']?.toString() ?? ''),
      nombre: json['nombre']?.toString() ?? '',
      instrucciones: json['instrucciones']?.toString(),
      instruccionesDetalladas: json['instrucciones_detalladas']?.toString(),
      hashtag: json['hashtag']?.toString(),
      urlVideo: json['url_video']?.toString(),
      fotoBase64: json['foto']?.toString(),
      fotoNombre: json['foto_nombre']?.toString(),
      fotoMiniatura: json['foto_miniatura']?.toString(),
      tiempo: json['tiempo'] is int
          ? json['tiempo']
          : int.tryParse(json['tiempo']?.toString() ?? ''),
      descanso: json['descanso'] is int
          ? json['descanso']
          : int.tryParse(json['descanso']?.toString() ?? ''),
      repeticiones: json['repeticiones'] is int
          ? json['repeticiones']
          : int.tryParse(json['repeticiones']?.toString() ?? ''),
      kilos: json['kilos'] is int
          ? json['kilos']
          : int.tryParse(json['kilos']?.toString() ?? ''),
      orden: json['orden'] is int
          ? json['orden']
          : int.tryParse(json['orden']?.toString() ?? ''),
      visiblePremium: json['visible_premium']?.toString(),
      totalUsos: int.tryParse(json['total_usos']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'codigo_plan_fit': codigoPlanFit,
        'codigo_dia': codigoDia,
        'codigo_ejercicio_catalogo': codigoEjercicioCatalogo,
        'nombre': nombre,
        'instrucciones': instrucciones,
        'instrucciones_detalladas': instruccionesDetalladas,
        'hashtag': hashtag,
        'url_video': urlVideo,
        'foto_nombre': fotoNombre,
        'foto_miniatura': fotoMiniatura,
        'tiempo': tiempo,
        'descanso': descanso,
        'repeticiones': repeticiones,
        'kilos': kilos,
        'orden': orden,
        'visible_premium': visiblePremium,
      };
}
