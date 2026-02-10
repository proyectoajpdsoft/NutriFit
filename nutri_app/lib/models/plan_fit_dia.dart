import 'dart:convert';

PlanFitDia planFitDiaFromJson(String str) =>
    PlanFitDia.fromJson(json.decode(str));
String planFitDiaToJson(PlanFitDia data) => json.encode(data.toJson());

class PlanFitDia {
  int codigo;
  int codigoPlanFit;
  int numeroDia;
  String? titulo;
  String? descripcion;
  int? orden;
  int? totalEjercicios;

  PlanFitDia({
    required this.codigo,
    required this.codigoPlanFit,
    required this.numeroDia,
    this.titulo,
    this.descripcion,
    this.orden,
    this.totalEjercicios,
  });

  factory PlanFitDia.fromJson(Map<String, dynamic> json) {
    return PlanFitDia(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"]?.toString() ?? '') ?? 0,
      codigoPlanFit: json["codigo_plan_fit"] is int
          ? json["codigo_plan_fit"]
          : int.tryParse(json["codigo_plan_fit"]?.toString() ?? '') ?? 0,
      numeroDia: json["numero_dia"] is int
          ? json["numero_dia"]
          : int.tryParse(json["numero_dia"]?.toString() ?? '') ?? 1,
      titulo: json["titulo"]?.toString(),
      descripcion: json["descripcion"]?.toString(),
      orden: json["orden"] is int
          ? json["orden"]
          : int.tryParse(json["orden"]?.toString() ?? ''),
      totalEjercicios: json["total_ejercicios"] is int
          ? json["total_ejercicios"]
          : int.tryParse(json["total_ejercicios"]?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        "codigo": codigo,
        "codigo_plan_fit": codigoPlanFit,
        "numero_dia": numeroDia,
        "titulo": titulo,
        "descripcion": descripcion,
        "orden": orden,
        "total_ejercicios": totalEjercicios,
      };
}
