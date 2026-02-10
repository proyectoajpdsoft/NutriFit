import 'dart:convert';

Cliente clienteFromJson(String str) => Cliente.fromJson(json.decode(str));
String clienteToJson(Cliente data) => json.encode(data.toJson());

class Cliente {
  int codigo;
  String nombre;
  String? cif;
  String? direccion;
  String? telefono;
  String? poblacion;
  String? provincia;
  int? cp;
  String? personacontacto;
  String? web;
  String? email;
  String? observacion;
  String activo;

  Cliente({
    required this.codigo,
    required this.nombre,
    this.cif,
    this.direccion,
    this.telefono,
    this.poblacion,
    this.provincia,
    this.cp,
    this.personacontacto,
    this.web,
    this.email,
    this.observacion,
    this.activo = 'S',
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"]?.toString() ?? '') ?? 0,
      nombre: json["nombre"] ?? 'Sin Nombre',
      cif: json["cif"],
      direccion: json["direccion"],
      telefono: json["telefono"],
      poblacion: json["poblacion"],
      provincia: json["provincia"],
      cp: json["cp"] is int
          ? json["cp"]
          : int.tryParse(json["cp"]?.toString() ?? ''),
      personacontacto: json["personacontacto"],
      web: json["web"],
      email: json["email"],
      observacion: json["observacion"],
      activo: json["activo"] ?? 'S',
    );
  }

  Map<String, dynamic> toJson() => {
        "codigo": codigo,
        "nombre": nombre,
        "cif": cif,
        "direccion": direccion,
        "telefono": telefono,
        "poblacion": poblacion,
        "provincia": provincia,
        "cp": cp,
        "personacontacto": personacontacto,
        "web": web,
        "email": email,
        "observacion": observacion,
        "activo": activo,
      };
}
