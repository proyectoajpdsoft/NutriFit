import 'dart:convert';

EntrevistaFit entrevistaFitFromJson(String str) =>
    EntrevistaFit.fromJson(json.decode(str));
String entrevistaFitToJson(EntrevistaFit data) => json.encode(data.toJson());

class EntrevistaFit {
  int codigo;
  int codigoPaciente;
  String? nombrePaciente;
  String? pacienteActivo;
  DateTime? fechaRealizacion;
  String? completada;
  DateTime? fechaPrevista;
  String? online;
  String? motivo;
  String? objetivos;
  String? enfermedadCorazon;
  String? notaDolorPracticaActividad;
  String? notaDolorReposo;
  String? perdidaEquilibrio;
  String? problemaHuesosArticulaciones;
  String? prescipcionMedicacionArterial;
  String? razonImpedimentoEjercicio;
  String? historialDeportivo;
  String? actividadDiaria;
  String? profesion;
  String? disponibilidadHoraria;
  String? disponibilidadInstalaciones;
  String? habitosAlimentarios;
  String? futuroSeguirRitmo;
  String? futuroLogrosProximasSemanas;
  String? futuroProbarNuevosEjercicios;
  String? observacion;

  EntrevistaFit({
    required this.codigo,
    required this.codigoPaciente,
    this.nombrePaciente,
    this.pacienteActivo,
    this.fechaRealizacion,
    this.completada,
    this.fechaPrevista,
    this.online,
    this.motivo,
    this.objetivos,
    this.enfermedadCorazon,
    this.notaDolorPracticaActividad,
    this.notaDolorReposo,
    this.perdidaEquilibrio,
    this.problemaHuesosArticulaciones,
    this.prescipcionMedicacionArterial,
    this.razonImpedimentoEjercicio,
    this.historialDeportivo,
    this.actividadDiaria,
    this.profesion,
    this.disponibilidadHoraria,
    this.disponibilidadInstalaciones,
    this.habitosAlimentarios,
    this.futuroSeguirRitmo,
    this.futuroLogrosProximasSemanas,
    this.futuroProbarNuevosEjercicios,
    this.observacion,
  });

  factory EntrevistaFit.fromJson(Map<String, dynamic> json) {
    DateTime? safeParseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty || dateStr == '0000-00-00') {
        return null;
      }
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    return EntrevistaFit(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"]?.toString() ?? '') ?? 0,
      codigoPaciente: json["codigo_paciente"] is int
          ? json["codigo_paciente"]
          : int.tryParse(json["codigo_paciente"]?.toString() ?? '') ?? 0,
      nombrePaciente: json["nombre_paciente"],
      pacienteActivo: json["paciente_activo"],
      fechaRealizacion: safeParseDate(json["fecha_realizacion"]),
      completada: json["completada"],
      fechaPrevista: safeParseDate(json["fecha_prevista"]),
      online: json["online"],
      motivo: json["motivo"],
      objetivos: json["objetivos"],
      enfermedadCorazon: json["enfermedad_corazon"],
      notaDolorPracticaActividad: json["nota_dolor_practica_actividad"],
      notaDolorReposo: json["nota_dolor_reposo"],
      perdidaEquilibrio: json["perdida_equilibrio"],
      problemaHuesosArticulaciones: json["problema_huesos_articulaciones"],
      prescipcionMedicacionArterial: json["prescipcion_medicacion_arterial"],
      razonImpedimentoEjercicio: json["razon_impedimento_ejercicio"],
      historialDeportivo: json["historial_deportivo"],
      actividadDiaria: json["actividad_diaria"],
      profesion: json["profesion"],
      disponibilidadHoraria: json["disponibilidad_horaria"],
      disponibilidadInstalaciones: json["disponibilidad_instalaciones"],
      habitosAlimentarios: json["habitos_alimentarios"],
      futuroSeguirRitmo: json["futuro_seguir_ritmo"],
      futuroLogrosProximasSemanas: json["futuro_logros_proximas_semanas"],
      futuroProbarNuevosEjercicios: json["futuro_probar_nuevos_ejercicios"],
      observacion: json["observacion"],
    );
  }

  Map<String, dynamic> toJson() => {
        "codigo": codigo,
        "codigo_paciente": codigoPaciente,
        "fecha_realizacion": fechaRealizacion?.toIso8601String(),
        "completada": completada,
        "fecha_prevista": fechaPrevista?.toIso8601String(),
        "online": online,
        "motivo": motivo,
        "objetivos": objetivos,
        "enfermedad_corazon": enfermedadCorazon,
        "nota_dolor_practica_actividad": notaDolorPracticaActividad,
        "nota_dolor_reposo": notaDolorReposo,
        "perdida_equilibrio": perdidaEquilibrio,
        "problema_huesos_articulaciones": problemaHuesosArticulaciones,
        "prescipcion_medicacion_arterial": prescipcionMedicacionArterial,
        "razon_impedimento_ejercicio": razonImpedimentoEjercicio,
        "historial_deportivo": historialDeportivo,
        "actividad_diaria": actividadDiaria,
        "profesion": profesion,
        "disponibilidad_horaria": disponibilidadHoraria,
        "disponibilidad_instalaciones": disponibilidadInstalaciones,
        "habitos_alimentarios": habitosAlimentarios,
        "futuro_seguir_ritmo": futuroSeguirRitmo,
        "futuro_logros_proximas_semanas": futuroLogrosProximasSemanas,
        "futuro_probar_nuevos_ejercicios": futuroProbarNuevosEjercicios,
        "observacion": observacion,
      };
}
