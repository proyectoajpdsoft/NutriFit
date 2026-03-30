import 'dart:convert';

PlanNutricional planNutricionalFromJson(String str) =>
    PlanNutricional.fromJson(json.decode(str));
String planNutricionalToJson(PlanNutricional data) =>
    json.encode(data.toJson());

class PlanNutricional {
  int codigo;
  int? codigoPaciente;
  String? tituloPlan;
  String? objetivoPlan;
  DateTime? desde;
  DateTime? hasta;
  String? semanas;
  int? totalSemanas;
  String? usaEstructuraDetallada;
  String? completado; // 'S' o 'N'
  int? codigoEntrevista;
  String? planDocumentoNombre;
  String? planIndicaciones;
  String? planIndicacionesVisibleUsuario;
  String? url;
  String? nombrePaciente; // Campo añadido

  PlanNutricional({
    required this.codigo,
    this.codigoPaciente,
    this.tituloPlan,
    this.objetivoPlan,
    this.desde,
    this.hasta,
    this.semanas,
    this.totalSemanas,
    this.usaEstructuraDetallada,
    this.completado,
    this.codigoEntrevista,
    this.planDocumentoNombre,
    this.planIndicaciones,
    this.planIndicacionesVisibleUsuario,
    this.url,
    this.nombrePaciente, // Inicialización del campo añadido
  });

  factory PlanNutricional.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para parsear fechas de forma segura
    DateTime? safeParseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty || dateStr == '0000-00-00') {
        return null;
      }
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null; // Devuelve null si el formato es incorrecto
      }
    }

    return PlanNutricional(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"]?.toString() ?? '') ?? 0,
      codigoPaciente: json["codigo_paciente"] is int
          ? json["codigo_paciente"]
          : int.tryParse(json["codigo_paciente"]?.toString() ?? ''),
      tituloPlan: json["titulo_plan"],
      objetivoPlan: json["objetivo_plan"],
      nombrePaciente: json["nombre_paciente"], // Campo añadido
      desde: safeParseDate(json["desde"]),
      hasta: safeParseDate(json["hasta"]),
      semanas: json["semanas"],
      totalSemanas: json["total_semanas"] is int
          ? json["total_semanas"]
          : int.tryParse(json["total_semanas"]?.toString() ?? ''),
      usaEstructuraDetallada: json["usa_estructura_detallada"],
      completado: json["completado"],
      codigoEntrevista: json["codigo_entrevista"] is int
          ? json["codigo_entrevista"]
          : int.tryParse(json["codigo_entrevista"]?.toString() ?? ''),
      planDocumentoNombre: json["plan_documento_nombre"],
      planIndicaciones: json["plan_indicaciones"],
      planIndicacionesVisibleUsuario: json["plan_indicaciones_visible_usuario"],
      url: json["url"],
    );
  }

  Map<String, dynamic> toJson() => {
        "codigo": codigo,
        "codigo_paciente": codigoPaciente,
        "titulo_plan": tituloPlan,
        "objetivo_plan": objetivoPlan,
        "desde": desde?.toIso8601String().split('T').first,
        "hasta": hasta?.toIso8601String().split('T').first,
        "semanas": semanas,
        "total_semanas": totalSemanas,
        "usa_estructura_detallada": usaEstructuraDetallada,
        "completado": completado,
        "codigo_entrevista": codigoEntrevista,
        "plan_documento_nombre": planDocumentoNombre,
        "plan_indicaciones": planIndicaciones,
        "plan_indicaciones_visible_usuario": planIndicacionesVisibleUsuario,
        "url": url,
      };
}
