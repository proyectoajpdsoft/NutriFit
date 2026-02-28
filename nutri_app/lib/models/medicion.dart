import 'dart:convert';

Medicion medicionFromJson(String str) => Medicion.fromJson(json.decode(str));
String medicionToJson(Medicion data) => json.encode(data.toJson());

class Medicion {
  int codigo;
  int codigoPaciente;
  int? codigoUsuario;
  String? nombrePaciente;
  String? pacienteActivo;
  DateTime fecha;
  double? peso;
  double? cadera;
  double? cintura;
  double? muslo;
  double? brazo;
  String? actividadFisica;
  double? pliegueAbdominal;
  double? pliegueCuadricipital;
  double? plieguePeroneal;
  double? pliegueSubescapular;
  double? pligueTricipital;
  double? pliegueSuprailiaco;
  String? observacion;
  String? observacionUsuario;
  String? tipo;
  int? alturaPaciente;

  Medicion({
    required this.codigo,
    required this.codigoPaciente,
    this.codigoUsuario,
    this.nombrePaciente,
    this.pacienteActivo,
    required this.fecha,
    this.peso,
    this.cadera,
    this.cintura,
    this.muslo,
    this.brazo,
    this.actividadFisica,
    this.pliegueAbdominal,
    this.pliegueCuadricipital,
    this.plieguePeroneal,
    this.pliegueSubescapular,
    this.pligueTricipital,
    this.pliegueSuprailiaco,
    this.observacion,
    this.observacionUsuario,
    this.tipo,
    this.alturaPaciente,
  });

  factory Medicion.fromJson(Map<String, dynamic> json) {
    DateTime? safeParseDate(String? dateStr) {
      if (dateStr == null) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    return Medicion(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"]?.toString() ?? '') ?? 0,
      codigoPaciente: json["codigo_paciente"] is int
          ? json["codigo_paciente"]
          : int.tryParse(json["codigo_paciente"]?.toString() ?? '') ?? 0,
      codigoUsuario: json["codigo_usuario"] is int
          ? json["codigo_usuario"]
          : int.tryParse(json["codigo_usuario"]?.toString() ?? ''),
      nombrePaciente: json["nombre_paciente"],
      pacienteActivo: json["paciente_activo"],
      fecha: safeParseDate(json["fecha"]) ?? DateTime.now(),
      peso: json["peso"] is double
          ? json["peso"]
          : double.tryParse(json["peso"]?.toString() ?? ''),
      cadera: json["cadera"] is double
          ? json["cadera"]
          : double.tryParse(json["cadera"]?.toString() ?? ''),
      cintura: json["cintura"] is double
          ? json["cintura"]
          : double.tryParse(json["cintura"]?.toString() ?? ''),
      muslo: json["muslo"] is double
          ? json["muslo"]
          : double.tryParse(json["muslo"]?.toString() ?? ''),
      brazo: json["brazo"] is double
          ? json["brazo"]
          : double.tryParse(json["brazo"]?.toString() ?? ''),
      actividadFisica: json["actividad_fisica"],
      pliegueAbdominal: json["pliegue_abdominal"] == null
          ? null
          : double.parse(json["pliegue_abdominal"]),
      pliegueCuadricipital: json["pliegue_cuadricipital"] == null
          ? null
          : double.parse(json["pliegue_cuadricipital"]),
      plieguePeroneal: json["pliegue_peroneal"] == null
          ? null
          : double.parse(json["pliegue_peroneal"]),
      pliegueSubescapular: json["pliegue_subescapular"] == null
          ? null
          : double.parse(json["pliegue_subescapular"]),
      pligueTricipital: json["pligue_tricipital"] == null
          ? null
          : double.parse(json["pligue_tricipital"]),
      pliegueSuprailiaco: json["pliegue_suprailiaco"] == null
          ? null
          : double.parse(json["pliegue_suprailiaco"]),
      observacion: json["observacion"],
      observacionUsuario: json["observacion_usuario"],
      tipo: json["tipo"],
      alturaPaciente: json["altura_paciente"] is int
          ? json["altura_paciente"]
          : int.tryParse(json["altura_paciente"]?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        "codigo": codigo,
        "codigo_paciente": codigoPaciente,
        "codigo_usuario": codigoUsuario,
        "fecha": fecha.toIso8601String().split('T').first,
        "peso": peso,
        "cadera": cadera,
        "cintura": cintura,
        "muslo": muslo,
        "brazo": brazo,
        "actividad_fisica": actividadFisica,
        "pliegue_abdominal": pliegueAbdominal,
        "pliegue_cuadricipital": pliegueCuadricipital,
        "pliegue_peroneal": plieguePeroneal,
        "pliegue_subescapular": pliegueSubescapular,
        "pligue_tricipital": pligueTricipital,
        "pliegue_suprailiaco": pliegueSuprailiaco,
        "observacion": observacion,
        "observacion_usuario": observacionUsuario,
        "tipo": tipo,
        "altura_paciente": alturaPaciente,
      };
}
