import 'dart:convert';

PlanFit planFitFromJson(String str) => PlanFit.fromJson(json.decode(str));
String planFitToJson(PlanFit data) => json.encode(data.toJson());

class PlanFit {
  int codigo;
  int? codigoPaciente;
  DateTime? desde;
  DateTime? hasta;
  String? semanas;
  String? completado; // 'S' o 'N'
  int? codigoEntrevista;
  String? planDocumentoNombre;
  String? planIndicaciones;
  String? planIndicacionesVisibleUsuario;
  String? url;
  String? nombrePaciente;
  int? rondas;
  String? consejos;
  String? recomendaciones;

  PlanFit({
    required this.codigo,
    this.codigoPaciente,
    this.desde,
    this.hasta,
    this.semanas,
    this.completado,
    this.codigoEntrevista,
    this.planDocumentoNombre,
    this.planIndicaciones,
    this.planIndicacionesVisibleUsuario,
    this.url,
    this.nombrePaciente,
    this.rondas,
    this.consejos,
    this.recomendaciones,
  });

  factory PlanFit.fromJson(Map<String, dynamic> json) {
    DateTime? safeParseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty || dateStr == '0000-00-00') {
        return null;
      }
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    return PlanFit(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"]?.toString() ?? '') ?? 0,
      codigoPaciente: json["codigo_paciente"] is int
          ? json["codigo_paciente"]
          : int.tryParse(json["codigo_paciente"]?.toString() ?? ''),
      nombrePaciente: json["nombre_paciente"],
      desde: safeParseDate(json["desde"]),
      hasta: safeParseDate(json["hasta"]),
      semanas: json["semanas"],
      completado: json["completado"],
      codigoEntrevista: json["codigo_entrevista"] is int
          ? json["codigo_entrevista"]
          : int.tryParse(json["codigo_entrevista"]?.toString() ?? ''),
      planDocumentoNombre: json["plan_documento_nombre"],
      planIndicaciones: json["plan_indicaciones"],
      planIndicacionesVisibleUsuario: json["plan_indicaciones_visible_usuario"],
      url: json["url"],
      rondas: json["rondas"] is int
          ? json["rondas"]
          : int.tryParse(json["rondas"]?.toString() ?? ''),
      consejos: json["consejos"],
      recomendaciones: json["recomendaciones"],
    );
  }

  Map<String, dynamic> toJson() => {
        "codigo": codigo,
        "codigo_paciente": codigoPaciente,
        "desde": desde?.toIso8601String().split('T').first,
        "hasta": hasta?.toIso8601String().split('T').first,
        "semanas": semanas,
        "completado": completado,
        "codigo_entrevista": codigoEntrevista,
        "plan_documento_nombre": planDocumentoNombre,
        "plan_indicaciones": planIndicaciones,
        "plan_indicaciones_visible_usuario": planIndicacionesVisibleUsuario,
        "url": url,
        "rondas": rondas,
        "consejos": consejos,
        "recomendaciones": recomendaciones,
      };
}
