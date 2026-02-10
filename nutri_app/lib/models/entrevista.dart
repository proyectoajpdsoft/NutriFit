import 'dart:convert';

Entrevista entrevistaFromJson(String str) =>
    Entrevista.fromJson(json.decode(str));
String entrevistaToJson(Entrevista data) => json.encode(data.toJson());

class Entrevista {
  int codigo;
  int codigoPaciente;
  String? nombrePaciente;
  String? pacienteActivo;
  DateTime? fechaRealizacion;
  String? completada;
  DateTime? fechaPrevista;
  String? online;
  double? peso;
  String? motivo;
  String? objetivos;
  String? dietasAnteriores;
  String? ocupacionHorario;
  String? deporteFrecuencia;
  String? actividadFisica;
  String? fumador;
  String? alcohol;
  String? sueno;
  String? horarioLaboralComidas;
  String? comidasDia;
  String? horarioComidasRegular;
  String? lugarComidas;
  String? quienCompraCasa;
  String? bebidaComida;
  String? preferenciasAlimentarias;
  String? alimentosRechazo;
  String? tipoDietaPreferencia;
  String? cantidadAguaDiaria;
  String? picarEntreHoras;
  String? horaDiaMasApetito;
  String? antojoDulceSalado;
  String? patologia;
  String? antecedentesEnfermedades;
  String? tipoMedicacion;
  String? tipoSuplemento;
  String? intoleranciaAlergia;
  String? hambreEmocional;
  String? estresAnsiedad;
  String? relacionComida;
  String? cicloMenstrual;
  String? lactancia;
  String? h24Desayuno;
  String? h24Almuerzo;
  String? h24Comida;
  String? h24Merienda;
  String? h24Cena;
  String? h24Recena;
  String? pesarAlimentos;
  String? resultadosBascula;
  String? gustaCocinar;
  String? establecimientoCompra;

  Entrevista({
    required this.codigo,
    required this.codigoPaciente,
    this.nombrePaciente,
    this.pacienteActivo,
    this.fechaRealizacion,
    this.completada,
    this.fechaPrevista,
    this.online,
    this.peso,
    this.motivo,
    this.objetivos,
    this.dietasAnteriores,
    this.ocupacionHorario,
    this.deporteFrecuencia,
    this.actividadFisica,
    this.fumador,
    this.alcohol,
    this.sueno,
    this.horarioLaboralComidas,
    this.comidasDia,
    this.horarioComidasRegular,
    this.lugarComidas,
    this.quienCompraCasa,
    this.bebidaComida,
    this.preferenciasAlimentarias,
    this.alimentosRechazo,
    this.tipoDietaPreferencia,
    this.cantidadAguaDiaria,
    this.picarEntreHoras,
    this.horaDiaMasApetito,
    this.antojoDulceSalado,
    this.patologia,
    this.antecedentesEnfermedades,
    this.tipoMedicacion,
    this.tipoSuplemento,
    this.intoleranciaAlergia,
    this.hambreEmocional,
    this.estresAnsiedad,
    this.relacionComida,
    this.cicloMenstrual,
    this.lactancia,
    this.h24Desayuno,
    this.h24Almuerzo,
    this.h24Comida,
    this.h24Merienda,
    this.h24Cena,
    this.h24Recena,
    this.pesarAlimentos,
    this.resultadosBascula,
    this.gustaCocinar,
    this.establecimientoCompra,
  });

  factory Entrevista.fromJson(Map<String, dynamic> json) {
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

    double? safeParseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return Entrevista(
      codigo: json["codigo"] is int
          ? json["codigo"]
          : int.tryParse(json["codigo"]?.toString() ?? '') ?? 0,
      codigoPaciente: json["codigo_paciente"] is int
          ? json["codigo_paciente"]
          : int.tryParse(json["codigo_paciente"]?.toString() ?? '') ?? 0,
      nombrePaciente: json["nombre_paciente"],
      pacienteActivo: json["paciente_activo"],
      fechaRealizacion: safeParseDate(json["fecha_realizacion"]),
      completada: json["completada"] ?? 'N',
      fechaPrevista: safeParseDate(json["fecha_prevista"]),
      online: json["online"] ?? 'N',
      peso: safeParseDouble(json["peso"]),
      motivo: json["motivo"],
      objetivos: json["objetivos"],
      dietasAnteriores: json["dietas_anteriores"],
      ocupacionHorario: json["ocupacion_horario"],
      deporteFrecuencia: json["deporte_frecuencia"],
      actividadFisica: json["actividad_fisica"],
      fumador: json["fumador"] ?? 'N',
      alcohol: json["alcohol"] ?? 'N',
      sueno: json["sueno"],
      horarioLaboralComidas: json["horario_laboral_comidas"],
      comidasDia: json["comidas_dia"],
      horarioComidasRegular: json["horario_comidas_regular"] ?? 'N',
      lugarComidas: json["lugar_comidas"],
      quienCompraCasa: json["quien_compra_casa"],
      bebidaComida: json["bebida_comida"],
      preferenciasAlimentarias: json["preferencias_alimentarias"],
      alimentosRechazo: json["alimentos_rechazo"],
      tipoDietaPreferencia: json["tipo_dieta_preferencia"],
      cantidadAguaDiaria: json["cantidad_agua_diaria"],
      picarEntreHoras: json["picar_entre_horas"] ?? 'N',
      horaDiaMasApetito: json["hora_dia_mas_apetito"],
      antojoDulceSalado: json["antojo_dulce_salado"],
      patologia: json["patologia"],
      antecedentesEnfermedades: json["antecedentes_enfermedades"],
      tipoMedicacion: json["tipo_medicacion"],
      tipoSuplemento: json["tipo_suplemento"],
      intoleranciaAlergia: json["intolerancia_alergia"],
      hambreEmocional: json["hambre_emocional"] ?? 'N',
      estresAnsiedad: json["estres_ansiedad"] ?? 'N',
      relacionComida: json["relacion_comida"],
      cicloMenstrual: json["ciclo_menstrual"],
      lactancia: json["lactancia"] ?? 'N',
      h24Desayuno: json["24_horas_desayuno"],
      h24Almuerzo: json["24_horas_almuerzo"],
      h24Comida: json["24_horas_comida"],
      h24Merienda: json["24_horas_merienda"],
      h24Cena: json["24_horas_cena"],
      h24Recena: json["24_horas_recena"],
      pesarAlimentos: json["pesar_alimentos"] ?? 'N',
      resultadosBascula: json["resultados_bascula"],
      gustaCocinar: json["gusta_cocinar"] ?? 'N',
      establecimientoCompra: json["establecimiento_compra"],
    );
  }

  Map<String, dynamic> toJson() => {
        "codigo": codigo,
        "codigo_paciente": codigoPaciente,
        "nombre_paciente": nombrePaciente,
        "paciente_activo": pacienteActivo,
        "fecha_realizacion": fechaRealizacion?.toIso8601String(),
        "completada": completada,
        "fecha_prevista": fechaPrevista?.toIso8601String(),
        "online": online,
        "peso": peso,
        "motivo": motivo,
        "objetivos": objetivos,
        "dietas_anteriores": dietasAnteriores,
        "ocupacion_horario": ocupacionHorario,
        "deporte_frecuencia": deporteFrecuencia,
        "actividad_fisica": actividadFisica,
        "fumador": fumador,
        "alcohol": alcohol,
        "sueno": sueno,
        "horario_laboral_comidas": horarioLaboralComidas,
        "comidas_dia": comidasDia,
        "horario_comidas_regular": horarioComidasRegular,
        "lugar_comidas": lugarComidas,
        "quien_compra_casa": quienCompraCasa,
        "bebida_comida": bebidaComida,
        "preferencias_alimentarias": preferenciasAlimentarias,
        "alimentos_rechazo": alimentosRechazo,
        "tipo_dieta_preferencia": tipoDietaPreferencia,
        "cantidad_agua_diaria": cantidadAguaDiaria,
        "picar_entre_horas": picarEntreHoras,
        "hora_dia_mas_apetito": horaDiaMasApetito,
        "antojo_dulce_salado": antojoDulceSalado,
        "patologia": patologia,
        "antecedentes_enfermedades": antecedentesEnfermedades,
        "tipo_medicacion": tipoMedicacion,
        "tipo_suplemento": tipoSuplemento,
        "intolerancia_alergia": intoleranciaAlergia,
        "hambre_emocional": hambreEmocional,
        "estres_ansiedad": estresAnsiedad,
        "relacion_comida": relacionComida,
        "ciclo_menstrual": cicloMenstrual,
        "lactancia": lactancia,
        "24_horas_desayuno": h24Desayuno,
        "24_horas_almuerzo": h24Almuerzo,
        "24_horas_comida": h24Comida,
        "24_horas_merienda": h24Merienda,
        "24_horas_cena": h24Cena,
        "24_horas_recena": h24Recena,
        "pesar_alimentos": pesarAlimentos,
        "resultados_bascula": resultadosBascula,
        "gusta_cocinar": gustaCocinar,
        "establecimiento_compra": establecimientoCompra,
      };
}
