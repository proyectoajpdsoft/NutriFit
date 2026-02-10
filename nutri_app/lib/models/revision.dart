import 'dart:convert';

Revision revisionFromJson(String str) => Revision.fromJson(json.decode(str));
String revisionToJson(Revision data) => json.encode(data.toJson());

class Revision {
  int codigo;
  int? codigoPaciente;
  String? nombrePaciente;
  String? pacienteActivo;
  String asunto;
  DateTime? fechaPrevista;
  DateTime? fechaRealizacion;
  String semanas;
  String? modificacionDieta;
  String? completada; // 'S' o 'N'
  String? online; // 'S' o 'N'
  double? peso;

  Revision({
    required this.codigo,
    this.codigoPaciente,
    this.nombrePaciente,
    this.pacienteActivo,
    required this.asunto,
    this.fechaPrevista,
    this.fechaRealizacion,
    required this.semanas,
    this.modificacionDieta,
    this.completada,
    this.online,
    this.peso,
  });

  factory Revision.fromJson(Map<String, dynamic> json) {
    DateTime? safeParseDate(String? dateStr) {
      if (dateStr == null) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    return Revision(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"]?.toString() ?? '') ?? 0,
      codigoPaciente: json["codigo_paciente"] is int
          ? json["codigo_paciente"]
          : int.tryParse(json["codigo_paciente"]?.toString() ?? ''),
      nombrePaciente: json["nombre_paciente"],
      pacienteActivo: json["paciente_activo"],
      asunto: json["asunto"] ?? '',
      fechaPrevista: safeParseDate(json["fecha_prevista"]),
      fechaRealizacion: safeParseDate(json["fecha_realizacion"]),
      semanas: json["semanas"] ?? '',
      modificacionDieta: json["modificacion_dieta"],
      completada: json["completada"],
      online: json["online"],
      peso: json["peso"] is double
          ? json["peso"]
          : double.tryParse(json["peso"]?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        "codigo": codigo,
        "codigo_paciente": codigoPaciente,
        "nombre_paciente": nombrePaciente,
        "paciente_activo": pacienteActivo,
        "asunto": asunto,
        "fecha_prevista": fechaPrevista?.toIso8601String(),
        "fecha_realizacion": fechaRealizacion?.toIso8601String(),
        "semanas": semanas,
        "modificacion_dieta": modificacionDieta,
        "completada": completada,
        "online": online,
        "peso": peso,
      };
}
