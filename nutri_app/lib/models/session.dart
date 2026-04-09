class SessionLog {
  final int id;
  final int codigousuario;
  final String fecha;
  final String? hora;
  final String estado;
  final String? ipLocal;
  final String? ipPublica;
  final String? tipo; // 'Android', 'iOS', 'Web'
  final String? usuarioNick;
  final String? usuarioNombre;

  SessionLog({
    required this.id,
    required this.codigousuario,
    required this.fecha,
    this.hora,
    required this.estado,
    this.ipLocal,
    this.ipPublica,
    this.tipo,
    this.usuarioNick,
    this.usuarioNombre,
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
      usuarioNick: json['usuario_nick'],
      usuarioNombre: json['usuario_nombre'],
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
      'usuario_nick': usuarioNick,
      'usuario_nombre': usuarioNombre,
    };
  }

  bool get isGuest =>
      codigousuario <= 0 ||
      (usuarioNick == null || usuarioNick!.trim().isEmpty);

  String get accesoDisplayName {
    if (!isGuest) {
      return usuarioNick!.trim();
    }
    final ip = (ipPublica ?? '').trim();
    return ip.isEmpty ? 'IP no disponible' : ip;
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

class SessionPagedResponse {
  final List<SessionLog> sesiones;
  final int totalFiltrado;
  final int limit;
  final int offset;
  final bool hasMore;

  SessionPagedResponse({
    required this.sesiones,
    required this.totalFiltrado,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  factory SessionPagedResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['todas_sesiones'] as List?) ?? const [];
    final sesiones = raw
        .map((s) => SessionLog.fromJson(Map<String, dynamic>.from(s)))
        .toList();

    return SessionPagedResponse(
      sesiones: sesiones,
      totalFiltrado: json['total_sesiones'] ?? 0,
      limit: json['limit'] ?? 20,
      offset: json['offset'] ?? 0,
      hasMore: json['has_more'] ?? false,
    );
  }
}
