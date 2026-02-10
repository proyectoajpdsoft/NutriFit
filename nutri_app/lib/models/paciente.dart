import 'dart:convert';

Paciente pacienteFromJson(String str) => Paciente.fromJson(json.decode(str));
String pacienteToJson(Paciente data) => json.encode(data.toJson());

class Paciente {
  final int codigo;
  final String nombre;
  final String? dni;
  final DateTime? fechaNacimiento;
  final String? sexo; // <-- CAMPO AÑADIDO
  final int? edad;
  final int? altura;
  final double? peso;
  final String? telefono;
  final String? email1;
  final String? email2; // <-- CAMPO AÑADIDO
  final String? online; // 'S' o 'N'
  final String? activo; // 'S' o 'N'
  final String? observacion;
  // Campos añadidos para que coincida con la BD
  final String? calle;
  final String? codigoPostal;
  final String? provincia;
  final String? pais;

  Paciente({
    required this.codigo,
    required this.nombre,
    this.dni,
    this.fechaNacimiento,
    this.sexo, // <-- CAMPO AÑADIDO
    this.edad,
    this.altura,
    this.peso,
    this.telefono,
    this.email1,
    this.email2, // <-- CAMPO AÑADIDO
    this.online,
    this.activo,
    this.observacion,
    // Campos añadidos
    this.calle,
    this.codigoPostal,
    this.provincia,
    this.pais,
  });

  factory Paciente.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para parsear fechas de forma segura
    DateTime? safeParseDate(String? dateStr) {
      if (dateStr == null || dateStr == "0000-00-00") {
        return null;
      }
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null; // Devuelve null si hay un error de formato
      }
    }

    return Paciente(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"].toString()) ?? 0,
      nombre: json["nombre"] ?? 'Nombre no disponible',
      dni: json["dni"],
      fechaNacimiento: safeParseDate(json["fecha_nacimiento"]),
      sexo: json["sexo"], // <-- CAMPO AÑADIDO
      edad: json["edad"] is int
          ? json["edad"]
          : int.tryParse(json["edad"]?.toString() ?? ''),
      altura: json["altura"] is int
          ? json["altura"]
          : int.tryParse(json["altura"]?.toString() ?? ''),
      peso: json["peso"] is double
          ? json["peso"]
          : double.tryParse(json["peso"]?.toString() ?? ''),
      telefono: json["telefono"],
      email1: json["email1"],
      email2: json["email2"], // <-- CAMPO AÑADIDO
      activo: json["activo"], // <-- CAMPO AÑADIDO
      online: json["online"],
      observacion: json["observacion"],
      calle: json["calle"],
      codigoPostal: json["codigo_postal"],
      provincia: json["provincia"],
      pais: json["pais"],
    );
  }

  Map<String, dynamic> toJson() => {
        "codigo": codigo, // Se envía como número
        "nombre": nombre,
        "dni": dni,
        "fecha_nacimiento": fechaNacimiento?.toIso8601String().split('T').first,
        "sexo": sexo, // <-- CAMPO AÑADIDO
        "edad": edad, // Se envía como número
        "altura": altura, // Se envía como número
        "peso": peso, // Se envía como número
        "telefono": telefono,
        "email1": email1,
        "email2": email2, // <-- CAMPO AÑADIDO
        "online": online,
        "activo": activo, // <-- CAMPO AÑADIDO
        "observacion": observacion,
        // Se añaden los campos restantes para que el JSON sea completo
        "calle": calle,
        "codigo_postal": codigoPostal,
        "provincia": provincia,
        "pais": pais,
      };
}
