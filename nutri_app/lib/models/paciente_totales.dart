
class PacienteTotales {
  final int codigo;
  final String nombre;
  final int totalPlanes;
  final int totalEntrevistas;
  final int totalRevisiones;
  final int totalMediciones;

  PacienteTotales({
    required this.codigo,
    required this.nombre,
    required this.totalPlanes,
    required this.totalEntrevistas,
    required this.totalRevisiones,
    required this.totalMediciones,
  });

  factory PacienteTotales.fromJson(Map<String, dynamic> json) {
    return PacienteTotales(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"].toString()) ?? 0,
      nombre: json["nombre"] ?? 'Paciente',
      totalPlanes: json["total_planes"] is int
          ? json["total_planes"]
          : int.tryParse(json["total_planes"].toString()) ?? 0,
      totalEntrevistas: json["total_entrevistas"] is int
          ? json["total_entrevistas"]
          : int.tryParse(json["total_entrevistas"].toString()) ?? 0,
      totalRevisiones: json["total_revisiones"] is int
          ? json["total_revisiones"]
          : int.tryParse(json["total_revisiones"].toString()) ?? 0,
      totalMediciones: json["total_mediciones"] is int
          ? json["total_mediciones"]
          : int.tryParse(json["total_mediciones"].toString()) ?? 0,
    );
  }
}
