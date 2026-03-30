class AlimentoGrupo {
  int? codigo;
  String nombre;
  String? descripcion;
  int activo;

  AlimentoGrupo({
    this.codigo,
    required this.nombre,
    this.descripcion,
    this.activo = 1,
  });

  factory AlimentoGrupo.fromJson(Map<String, dynamic> json) {
    return AlimentoGrupo(
      codigo: int.tryParse(json['codigo']?.toString() ?? ''),
      nombre: (json['nombre'] ?? '').toString(),
      descripcion: json['descripcion']?.toString(),
      activo: int.tryParse(json['activo']?.toString() ?? '1') ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'descripcion': descripcion,
      'activo': activo,
    };
  }
}
