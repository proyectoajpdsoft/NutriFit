class Suplemento {
  int? codigo;
  String titulo;
  String descripcion;
  String activo;
  DateTime? fechaa;
  int? codusuarioa;
  DateTime? fecham;
  int? codusuariom;

  Suplemento({
    this.codigo,
    required this.titulo,
    this.descripcion = '',
    this.activo = 'S',
    this.fechaa,
    this.codusuarioa,
    this.fecham,
    this.codusuariom,
  });

  factory Suplemento.fromJson(Map<String, dynamic> json) {
    return Suplemento(
      codigo: json['codigo'] != null
          ? int.tryParse(json['codigo'].toString())
          : null,
      titulo: (json['titulo'] ?? '').toString(),
      descripcion: (json['descripcion'] ?? '').toString(),
      activo: (json['activo'] ?? 'S').toString(),
      fechaa: json['fechaa'] != null
          ? DateTime.tryParse(json['fechaa'].toString())
          : null,
      codusuarioa: json['codusuarioa'] != null
          ? int.tryParse(json['codusuarioa'].toString())
          : null,
      fecham: json['fecham'] != null
          ? DateTime.tryParse(json['fecham'].toString())
          : null,
      codusuariom: json['codusuariom'] != null
          ? int.tryParse(json['codusuariom'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (codigo != null) 'codigo': codigo,
      'titulo': titulo,
      'descripcion': descripcion,
      'activo': activo,
      if (codusuarioa != null) 'codusuarioa': codusuarioa,
      if (codusuariom != null) 'codusuariom': codusuariom,
    };
  }
}
