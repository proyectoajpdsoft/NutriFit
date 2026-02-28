import 'dart:convert';

EntrenamientoEjercicio entrenamientoEjercicioFromJson(String str) =>
    EntrenamientoEjercicio.fromJson(json.decode(str));
String entrenamientoEjercicioToJson(EntrenamientoEjercicio data) =>
    json.encode(data.toJson());

class EntrenamientoEjercicio {
  int codigo;
  int codigoEntrenamiento;
  int? codigoPlanFitEjercicio;
  int? codigoEjercicioCatalogo;
  String nombre;
  String? instrucciones;
  String? urlVideo;
  String? fotoBase64;
  String? fotoNombre;
  String? fotoMiniatura;
  int? tiempoPlan;
  int? descansoPlan;
  int? repeticionesPlan;
  int? kilosPlan;
  int? esfuerzoPercibido;
  int? tiempoRealizado;
  int? repeticionesRealizadas;
  String? sensaciones;
  String? comentarioNutricionista;
  bool? comentarioLeido;
  DateTime? comentarioLeidoFecha;
  bool? sensacionesLeidoNutri;
  DateTime? sensacionesLeidoNutriFecha;
  String? realizado;
  int? orden;
  int? codusuarioa;

  EntrenamientoEjercicio({
    required this.codigo,
    required this.codigoEntrenamiento,
    this.codigoPlanFitEjercicio,
    this.codigoEjercicioCatalogo,
    required this.nombre,
    this.instrucciones,
    this.urlVideo,
    this.fotoBase64,
    this.fotoNombre,
    this.fotoMiniatura,
    this.tiempoPlan,
    this.descansoPlan,
    this.repeticionesPlan,
    this.kilosPlan,
    this.esfuerzoPercibido,
    this.tiempoRealizado,
    this.repeticionesRealizadas,
    this.sensaciones,
    this.comentarioNutricionista,
    this.comentarioLeido,
    this.comentarioLeidoFecha,
    this.sensacionesLeidoNutri,
    this.sensacionesLeidoNutriFecha,
    this.realizado,
    this.orden,
    this.codusuarioa,
  });

  factory EntrenamientoEjercicio.fromJson(Map<String, dynamic> json) {
    return EntrenamientoEjercicio(
      codigo: json['codigo'] is int
          ? json['codigo']
          : int.tryParse(json['codigo']?.toString() ?? '') ?? 0,
      codigoEntrenamiento: json['codigo_entrenamiento'] is int
          ? json['codigo_entrenamiento']
          : int.tryParse(json['codigo_entrenamiento']?.toString() ?? '') ?? 0,
      codigoPlanFitEjercicio: json['codigo_plan_fit_ejercicio'] is int
          ? json['codigo_plan_fit_ejercicio']
          : int.tryParse(json['codigo_plan_fit_ejercicio']?.toString() ?? ''),
      codigoEjercicioCatalogo: json['codigo_ejercicio_catalogo'] is int
          ? json['codigo_ejercicio_catalogo']
          : int.tryParse(json['codigo_ejercicio_catalogo']?.toString() ?? ''),
      nombre: json['nombre']?.toString() ?? '',
      instrucciones: json['instrucciones']?.toString(),
      urlVideo: json['url_video']?.toString(),
      fotoBase64: json['foto']?.toString(),
      fotoNombre: json['foto_nombre']?.toString(),
      fotoMiniatura: json['foto_miniatura']?.toString(),
      tiempoPlan: json['tiempo_plan'] is int
          ? json['tiempo_plan']
          : int.tryParse(json['tiempo_plan']?.toString() ?? ''),
      descansoPlan: json['descanso_plan'] is int
          ? json['descanso_plan']
          : int.tryParse(json['descanso_plan']?.toString() ?? ''),
      repeticionesPlan: json['repeticiones_plan'] is int
          ? json['repeticiones_plan']
          : int.tryParse(json['repeticiones_plan']?.toString() ?? ''),
      kilosPlan: json['kilos_plan'] is int
          ? json['kilos_plan']
          : int.tryParse(json['kilos_plan']?.toString() ?? ''),
      esfuerzoPercibido: json['esfuerzo_percibido'] is int
          ? json['esfuerzo_percibido']
          : int.tryParse(json['esfuerzo_percibido']?.toString() ?? ''),
      tiempoRealizado: json['tiempo_realizado'] is int
          ? json['tiempo_realizado']
          : int.tryParse(json['tiempo_realizado']?.toString() ?? ''),
      repeticionesRealizadas: json['repeticiones_realizadas'] is int
          ? json['repeticiones_realizadas']
          : int.tryParse(json['repeticiones_realizadas']?.toString() ?? ''),
      sensaciones: json['sensaciones']?.toString(),
      comentarioNutricionista: json['comentario_nutricionista']?.toString(),
      comentarioLeido: json['comentario_leido'] == null
          ? null
          : (json['comentario_leido'].toString() == '1' ||
              json['comentario_leido'].toString().toLowerCase() == 'true'),
      comentarioLeidoFecha: json['comentario_leido_fecha'] != null
          ? DateTime.tryParse(json['comentario_leido_fecha'].toString())
          : null,
      sensacionesLeidoNutri: json['sensaciones_leido_nutri'] == null
          ? null
          : (json['sensaciones_leido_nutri'].toString() == '1' ||
              json['sensaciones_leido_nutri'].toString().toLowerCase() ==
                  'true'),
      sensacionesLeidoNutriFecha: json['sensaciones_leido_nutri_fecha'] != null
          ? DateTime.tryParse(
              json['sensaciones_leido_nutri_fecha'].toString(),
            )
          : null,
      realizado: json['realizado']?.toString(),
      orden: json['orden'] is int
          ? json['orden']
          : int.tryParse(json['orden']?.toString() ?? ''),
      codusuarioa: json['codusuarioa'] is int
          ? json['codusuarioa']
          : int.tryParse(json['codusuarioa']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'codigo_entrenamiento': codigoEntrenamiento,
        'codigo_plan_fit_ejercicio': codigoPlanFitEjercicio,
        'codigo_ejercicio_catalogo': codigoEjercicioCatalogo,
        'nombre': nombre,
        'instrucciones': instrucciones,
        'url_video': urlVideo,
        'foto': fotoBase64,
        'foto_nombre': fotoNombre,
        'foto_miniatura': fotoMiniatura,
        'tiempo_plan': tiempoPlan,
        'descanso_plan': descansoPlan,
        'repeticiones_plan': repeticionesPlan,
        'kilos_plan': kilosPlan,
        'esfuerzo_percibido': esfuerzoPercibido,
        'tiempo_realizado': tiempoRealizado,
        'repeticiones_realizadas': repeticionesRealizadas,
        'sensaciones': sensaciones,
        'comentario_nutricionista': comentarioNutricionista,
        'comentario_leido': comentarioLeido == true ? 1 : 0,
        'comentario_leido_fecha': comentarioLeidoFecha?.toIso8601String(),
        'sensaciones_leido_nutri': sensacionesLeidoNutri == true ? 1 : 0,
        'sensaciones_leido_nutri_fecha':
            sensacionesLeidoNutriFecha?.toIso8601String(),
        'realizado': realizado,
        'orden': orden,
        'codusuarioa': codusuarioa,
      };
}
