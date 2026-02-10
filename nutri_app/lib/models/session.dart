class SessionLog {
  final int id;
  final int codigousuario;
  final String fecha;
  final String? hora;
  final String estado;
  final String? ipLocal;
  final String? ipPublica;
  final String? tipo; // 'Android', 'iOS', 'Web'

  SessionLog({
    required this.id,
    required this.codigousuario,
    required this.fecha,
    this.hora,
    required this.estado,
    this.ipLocal,
    this.ipPublica,
    this.tipo,
  });

  factory SessionLog.fromJson(Map<String, dynamic> json) {
    return SessionLog(
      id: json['id'] ?? 0,
      codigousuario: json['codigousuario'] ?? 0,
      fecha: json['fecha'] ?? '',
      hora: json['hora'],
      estado: json['estado'] ?? '',
      ipLocal: json['ip_local'],
      ipPublica: json['ip_publica'],
      tipo: json['tipo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigousuario': codigousuario,
      'fecha': fecha,
      'hora': hora,
      'estado': estado,
      'ip_local': ipLocal,
      'ip_publica': ipPublica,
      'tipo': tipo,
    };
  }
}

class SessionResponse {
  final List<SessionLog> ultimasSesionesExitosas;
  final List<SessionLog> ultimosIntentosFallidos;
  final int totalSesiones;
  final int totalExitosas;
  final int totalFallidas;
  final List<SessionLog> todasSesiones;

  SessionResponse({
    required this.ultimasSesionesExitosas,
    required this.ultimosIntentosFallidos,
    required this.totalSesiones,
    required this.totalExitosas,
    required this.totalFallidas,
    required this.todasSesiones,
  });

  factory SessionResponse.fromJson(Map<String, dynamic> json) {
    return SessionResponse(
      ultimasSesionesExitosas: (json['ultimas_sesiones_exitosas'] as List?)
              ?.map((s) => SessionLog.fromJson(s))
              .toList() ??
          [],
      ultimosIntentosFallidos: (json['ultimos_intentos_fallidos'] as List?)
              ?.map((s) => SessionLog.fromJson(s))
              .toList() ??
          [],
      totalSesiones: json['total_sesiones'] ?? 0,
      totalExitosas: json['total_exitosas'] ?? 0,
      totalFallidas: json['total_fallidas'] ?? 0,
      todasSesiones: (json['todas_sesiones'] as List?)
              ?.map((s) => SessionLog.fromJson(s))
              .toList() ??
          [],
    );
  }
}
