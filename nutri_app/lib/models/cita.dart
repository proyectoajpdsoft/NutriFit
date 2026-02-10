import 'dart:convert';

Cita citaFromJson(String str) => Cita.fromJson(json.decode(str));
String citaToJson(Cita data) => json.encode(data.toJson());

class Cita {
  final int codigo;
  final int? codigoPaciente;
  final String? nombrePaciente;
  final DateTime? comienzo;
  final DateTime? fin;
  final String? tipo;
  final String? online;
  final String? estado;
  final String asunto;
  final String? descripcion;
  final String? ubicacion;

  Cita({
    required this.codigo,
    this.codigoPaciente,
    this.nombrePaciente,
    this.comienzo,
    this.fin,
    this.tipo,
    this.online,
    this.estado,
    required this.asunto,
    this.descripcion,
    this.ubicacion,
  });

  factory Cita.fromJson(Map<String, dynamic> json) {
    DateTime? safeParseDate(String? dateStr) {
      if (dateStr == null) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    return Cita(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"]?.toString() ?? '') ?? 0,
      codigoPaciente: json["codigo_paciente"] is int
          ? json["codigo_paciente"]
          : int.tryParse(json["codigo_paciente"]?.toString() ?? ''),
      nombrePaciente: json["nombre_paciente"],
      comienzo: safeParseDate(json["comienzo"]),
      fin: safeParseDate(json["fin"]),
      tipo: json["tipo"],
      online: json["online"],
      estado: json["estado"],
      asunto: json["asunto"] ?? '',
      descripcion: json["descripcion"],
      ubicacion: json["ubicacion"],
    );
  }

  Map<String, dynamic> toJson() => {
        "codigo": codigo,
        "codigo_paciente": codigoPaciente,
        "comienzo": comienzo?.toIso8601String(),
        "fin": fin?.toIso8601String(),
        "tipo": tipo,
        "online": online,
        "estado": estado,
        "asunto": asunto,
        "descripcion": descripcion,
        "ubicacion": ubicacion,
      };
}
