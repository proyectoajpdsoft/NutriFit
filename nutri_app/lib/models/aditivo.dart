class Aditivo {
  int? codigo;
  String titulo;
  String descripcion;
  String tipo;
  String activo;
  int? peligrosidad;
  DateTime? fechaa;
  int? codusuarioa;
  DateTime? fecham;
  int? codusuariom;

  Aditivo({
    this.codigo,
    required this.titulo,
    this.descripcion = '',
    this.tipo = 'Colorantes',
    this.activo = 'S',
    this.peligrosidad,
    this.fechaa,
    this.codusuarioa,
    this.fecham,
    this.codusuariom,
  });

  factory Aditivo.fromJson(Map<String, dynamic> json) {
    return Aditivo(
      codigo: json['codigo'] != null
          ? int.tryParse(json['codigo'].toString())
          : null,
      titulo: (json['titulo'] ?? '').toString(),
      descripcion: (json['descripcion'] ?? '').toString(),
      tipo: (json['tipo'] ?? 'Colorantes').toString(),
      activo: (json['activo'] ?? 'S').toString(),
      peligrosidad: json['peligrosidad'] != null
          ? int.tryParse(json['peligrosidad'].toString())
          : null,
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
      'tipo': tipo,
      'activo': activo,
      if (peligrosidad != null) 'peligrosidad': peligrosidad,
      if (codusuarioa != null) 'codusuarioa': codusuarioa,
      if (codusuariom != null) 'codusuariom': codusuariom,
    };
  }
}
