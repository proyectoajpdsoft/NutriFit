import 'dart:convert';

Usuario usuarioFromJson(String str) => Usuario.fromJson(json.decode(str));
String usuarioToJson(Usuario data) => json.encode(data.toJson());

class Usuario {
  int codigo;
  String nick;
  String? nombre;
  String? email;
  String? tipo; // 'Nutricionista', 'Paciente'
  String activo; // 'S' o 'N'
  String accesoweb; // 'S' o 'N'
  String administrador; // 'S' o 'N'
  int? codigoPaciente;
  int? edad;
  int? altura;
  String? imgPerfil; // Base64 de la imagen de perfil

  Usuario({
    required this.codigo,
    required this.nick,
    this.nombre,
    this.email,
    this.tipo,
    this.activo = 'S',
    this.accesoweb = 'S',
    this.administrador = 'N',
    this.codigoPaciente,
    this.edad,
    this.altura,
    this.imgPerfil,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"]?.toString() ?? '') ?? 0,
      nick: json["nick"] ?? 'Sin Nick',
      nombre: json["nombre"],
      email: json["email"],
      tipo: json["tipo"],
      activo: json["activo"] ?? 'N',
      accesoweb: json["accesoweb"] ?? 'N',
      administrador: json["administrador"] ?? 'N',
      codigoPaciente: json["codigo_paciente"] is int
          ? json["codigo_paciente"]
          : int.tryParse(json["codigo_paciente"]?.toString() ?? ''),
      edad: json["edad"] is int
          ? json["edad"]
          : int.tryParse(json["edad"]?.toString() ?? ''),
      altura: json["altura"] is int
          ? json["altura"]
          : int.tryParse(json["altura"]?.toString() ?? ''),
      imgPerfil: json["img_perfil"],
    );
  }

  Map<String, dynamic> toJson() => {
        "codigo": codigo.toString(),
        "nick": nick,
        "nombre": nombre,
        "email": email,
        "tipo": tipo,
        "activo": activo,
        "accesoweb": accesoweb,
        "administrador": administrador,
        "codigo_paciente": codigoPaciente?.toString(),
        "edad": edad,
        "altura": altura,
        "img_perfil": imgPerfil,
      };
}
