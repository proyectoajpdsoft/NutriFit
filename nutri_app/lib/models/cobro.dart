import 'dart:convert';

Cobro cobroFromJson(String str) => Cobro.fromJson(json.decode(str));
String cobroToJson(Cobro data) => json.encode(data.toJson());

class Cobro {
  int codigo;
  DateTime fecha;
  double importe;
  String? descripcion;
  int? codigoPaciente;
  String? nombrePaciente;
  int? codigoCliente;
  String? nombreCliente;

  Cobro({
    required this.codigo,
    required this.fecha,
    required this.importe,
    this.descripcion,
    this.codigoPaciente,
    this.nombrePaciente,
    this.codigoCliente,
    this.nombreCliente,
  });

  factory Cobro.fromJson(Map<String, dynamic> json) {
    DateTime? safeParseDate(String? dateStr) {
      if (dateStr == null) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    return Cobro(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"]?.toString() ?? '') ?? 0,
      fecha: safeParseDate(json["fecha"]) ?? DateTime.now(),
      importe: json["importe"] is double
          ? json["importe"]
          : double.tryParse(json["importe"]?.toString() ?? '') ?? 0.0,
      descripcion: json["descripcion"],
      codigoPaciente: json["codigo_paciente"] is int
          ? json["codigo_paciente"]
          : int.tryParse(json["codigo_paciente"]?.toString() ?? ''),
      codigoCliente: json["codigo_cliente"] is int
          ? json["codigo_cliente"]
          : int.tryParse(json["codigo_cliente"]?.toString() ?? ''),
      nombrePaciente: json["nombre_paciente"],
      nombreCliente: json["nombre_cliente"],
    );
  }

  Map<String, dynamic> toJson() => {
        "codigo": codigo.toString(),
        "fecha": fecha.toIso8601String().split('T').first,
        "importe": importe.toString(),
        "descripcion": descripcion,
        "codigo_paciente": codigoPaciente?.toString(),
        "codigocliente": codigoCliente?.toString(),
      };

  // Helper para saber el nombre del pagador
  String get pagadorNombre => nombrePaciente ?? nombreCliente ?? "No asignado";
}
