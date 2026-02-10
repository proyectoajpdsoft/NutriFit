class RecetaDocumento {
  int? codigo;
  int codigoReceta;
  String tipo; // 'documento' o 'url'
  String? nombre;
  String? documento; // Base64
  String? url;
  int orden;
  DateTime? fechaa;
  int? codusuarioa;
  DateTime? fecham;
  int? codusuariom;

  RecetaDocumento({
    this.codigo,
    required this.codigoReceta,
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

  factory RecetaDocumento.fromJson(Map<String, dynamic> json) {
    return RecetaDocumento(
      codigo:
          json['codigo'] != null ? int.parse(json['codigo'].toString()) : null,
      codigoReceta: int.parse(json['codigo_receta'].toString()),
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
      'codigo_receta': codigoReceta,
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
