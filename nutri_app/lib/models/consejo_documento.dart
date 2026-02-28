class ConsejoDocumento {
  int? codigo;
  int codigoConsejo;
  String tipo; // 'documento', 'url' o 'imagen'
  String? nombre;
  String? documento; // Base64
  String? url;
  int orden;
  DateTime? fechaa;
  int? codusuarioa;
  DateTime? fecham;
  int? codusuariom;

  ConsejoDocumento({
    this.codigo,
    required this.codigoConsejo,
    required this.tipo,
    this.nombre,
    this.documento,
    this.url,
    this.orden = 0,
    this.fechaa,
    this.codusuarioa,
    this.fecham,
    this.codusuariom,
  });

  factory ConsejoDocumento.fromJson(Map<String, dynamic> json) {
    return ConsejoDocumento(
      codigo:
          json['codigo'] != null ? int.parse(json['codigo'].toString()) : null,
      codigoConsejo: int.parse(json['codigo_consejo'].toString()),
      tipo: json['tipo'] ?? 'documento',
      nombre: json['nombre'],
      documento: json['documento'],
      url: json['url'],
      orden: json['orden'] != null ? int.parse(json['orden'].toString()) : 0,
      fechaa: json['fechaa'] != null ? DateTime.parse(json['fechaa']) : null,
      codusuarioa: json['codusuarioa'] != null
          ? int.parse(json['codusuarioa'].toString())
          : null,
      fecham: json['fecham'] != null ? DateTime.parse(json['fecham']) : null,
      codusuariom: json['codusuariom'] != null
          ? int.parse(json['codusuariom'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'codigo_consejo': codigoConsejo,
      'tipo': tipo,
      'nombre': nombre,
      'documento': documento,
      'url': url,
      'orden': orden,
      'codusuarioa': codusuarioa,
      'codusuariom': codusuariom,
    };
  }
}
