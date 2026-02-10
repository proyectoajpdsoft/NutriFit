class EntrenamientoActividadCustom {
  final int codigo;
  final String nombre;
  final String icono;
  final DateTime? fechaa;
  final DateTime? fecham;

  EntrenamientoActividadCustom({
    required this.codigo,
    required this.nombre,
    required this.icono,
    this.fechaa,
    this.fecham,
  });

  factory EntrenamientoActividadCustom.fromJson(Map<String, dynamic> json) {
    return EntrenamientoActividadCustom(
      codigo: json['codigo'] is int
          ? json['codigo']
          : int.tryParse(json['codigo']?.toString() ?? '') ?? 0,
      nombre: json['nombre']?.toString() ?? '',
      icono: json['icono']?.toString() ?? '💪',
      fechaa: json['fechaa'] != null
          ? DateTime.tryParse(json['fechaa'].toString())
          : null,
      fecham: json['fecham'] != null
          ? DateTime.tryParse(json['fecham'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'nombre': nombre,
        'icono': icono,
        'fechaa': fechaa?.toIso8601String(),
        'fecham': fecham?.toIso8601String(),
      };
}
