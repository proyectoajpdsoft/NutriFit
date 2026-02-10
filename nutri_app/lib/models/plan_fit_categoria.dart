import 'dart:convert';

PlanFitCategoria planFitCategoriaFromJson(String str) =>
    PlanFitCategoria.fromJson(json.decode(str));
String planFitCategoriaToJson(PlanFitCategoria data) =>
    json.encode(data.toJson());

class PlanFitCategoria {
  int codigo;
  String nombre;
  String? descripcion;
  int? orden;
  String? activo;

  PlanFitCategoria({
    required this.codigo,
    required this.nombre,
    this.descripcion,
    this.orden,
    this.activo,
  });

  factory PlanFitCategoria.fromJson(Map<String, dynamic> json) {
    return PlanFitCategoria(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"]?.toString() ?? '') ?? 0,
      nombre: json["nombre"]?.toString() ?? '',
      descripcion: json["descripcion"]?.toString(),
      orden: json["orden"] is int
          ? json["orden"]
          : int.tryParse(json["orden"]?.toString() ?? ''),
      activo: json["activo"]?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        "codigo": codigo,
        "nombre": nombre,
        "descripcion": descripcion,
        "orden": orden,
        "activo": activo,
      };
}
