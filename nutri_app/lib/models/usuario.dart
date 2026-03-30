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
  int? premiumPeriodoMeses;
  DateTime? premiumExpiraFecha;
  DateTime? premiumDesdeFecha;
  DateTime? premiumHastaFecha;
  int? premiumPeriodoMesesSolicitado;
  String? premiumFormaPagoSolicitada;
  String? premiumSolicitudPendiente;
  DateTime? premiumFechaSolicitud;
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
    this.premiumPeriodoMeses,
    this.premiumExpiraFecha,
    this.premiumDesdeFecha,
    this.premiumHastaFecha,
    this.premiumPeriodoMesesSolicitado,
    this.premiumFormaPagoSolicitada,
    this.premiumSolicitudPendiente,
    this.premiumFechaSolicitud,
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
      premiumPeriodoMeses: json["premium_periodo_meses"] is int
          ? json["premium_periodo_meses"]
          : int.tryParse(json["premium_periodo_meses"]?.toString() ?? ''),
      premiumExpiraFecha:
          DateTime.tryParse(json["premium_expira_fecha"]?.toString() ?? ''),
      premiumDesdeFecha:
          DateTime.tryParse(json["premium_desde_fecha"]?.toString() ?? ''),
      premiumHastaFecha:
          DateTime.tryParse(json["premium_hasta_fecha"]?.toString() ?? ''),
      premiumPeriodoMesesSolicitado:
          json["premium_periodo_meses_solicitado"] is int
              ? json["premium_periodo_meses_solicitado"]
              : int.tryParse(
                  json["premium_periodo_meses_solicitado"]?.toString() ?? ''),
      premiumFormaPagoSolicitada: json["premium_forma_pago_solicitada"],
      premiumSolicitudPendiente: json["premium_solicitud_pendiente"],
      premiumFechaSolicitud: DateTime.tryParse(
        json["premium_fecha_solicitud"]?.toString() ?? '',
      ),
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
        "premium_periodo_meses": premiumPeriodoMeses,
        "premium_expira_fecha": premiumExpiraFecha?.toIso8601String(),
        "premium_desde_fecha": premiumDesdeFecha?.toIso8601String(),
        "premium_hasta_fecha": premiumHastaFecha?.toIso8601String(),
        "premium_periodo_meses_solicitado": premiumPeriodoMesesSolicitado,
        "premium_forma_pago_solicitada": premiumFormaPagoSolicitada,
        "premium_solicitud_pendiente": premiumSolicitudPendiente,
        "premium_fecha_solicitud": premiumFechaSolicitud?.toIso8601String(),
        "img_perfil": imgPerfil,
      };
}
