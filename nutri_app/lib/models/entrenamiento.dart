class Entrenamiento {
  final int? codigo;
  final String codigoPaciente;
  final String actividad;
  final String? descripcionActividad;
  final DateTime fecha;
  final int duracionHoras;
  final int duracionMinutos;
  final double? duracionKilometros;
  final int nivelEsfuerzo; // 1-10
  final String? notas;
  final String? fotos; // JSON string con rutas de fotos
  final int? vueltas;
  final int? codigoPlanFit;
  final String codUsuario;
  final DateTime? fechaA;
  final bool? validado;
  final DateTime? validadoFecha;
  final int? validadoUsuario;
  final int? ejerciciosTotal;
  final int? ejerciciosRealizados;
  final int? ejerciciosNoRealizados;

  Entrenamiento({
    this.codigo,
    required this.codigoPaciente,
    required this.actividad,
    this.descripcionActividad,
    required this.fecha,
    required this.duracionHoras,
    required this.duracionMinutos,
    this.duracionKilometros,
    required this.nivelEsfuerzo,
    this.notas,
    this.fotos,
    this.vueltas,
    this.codigoPlanFit,
    required this.codUsuario,
    this.fechaA,
    this.validado,
    this.validadoFecha,
    this.validadoUsuario,
    this.ejerciciosTotal,
    this.ejerciciosRealizados,
    this.ejerciciosNoRealizados,
  });

  // Convertir de JSON
  factory Entrenamiento.fromJson(Map<String, dynamic> json) {
    final validadoRaw = json['validado'];
    final validadoValue = validadoRaw == null
        ? null
        : (validadoRaw.toString() == '1' ||
            validadoRaw.toString().toLowerCase() == 'true' ||
            validadoRaw.toString().toUpperCase() == 'S');

    return Entrenamiento(
      codigo: json['codigo'] != null
          ? int.tryParse(json['codigo'].toString())
          : null,
      codigoPaciente: json['codigo_paciente'] ?? '',
      actividad: json['actividad'] ?? '',
      descripcionActividad: json['descripcion_actividad'],
      fecha: DateTime.parse(json['fecha']),
      duracionHoras: int.tryParse(json['duracion_horas'].toString()) ?? 0,
      duracionMinutos: int.tryParse(json['duracion_minutos'].toString()) ?? 0,
      duracionKilometros: json['duracion_kilometros'] != null
          ? double.tryParse(json['duracion_kilometros'].toString())
          : null,
      nivelEsfuerzo: int.tryParse(json['nivel_esfuerzo'].toString()) ?? 5,
      notas: json['notas'],
      fotos: json['fotos'],
      vueltas: json['vueltas'] != null
          ? int.tryParse(json['vueltas'].toString())
          : null,
      codigoPlanFit: json['codigo_plan_fit'] != null
          ? int.tryParse(json['codigo_plan_fit'].toString())
          : null,
      codUsuario: json['codusuario'] ?? '',
      fechaA: json['fechaa'] != null ? DateTime.parse(json['fechaa']) : null,
      validado: validadoValue,
      validadoFecha: json['validado_fecha'] != null
          ? DateTime.tryParse(json['validado_fecha'].toString())
          : null,
      validadoUsuario: json['validado_usuario'] != null
          ? int.tryParse(json['validado_usuario'].toString())
          : null,
      ejerciciosTotal: json['ejercicios_total'] != null
          ? int.tryParse(json['ejercicios_total'].toString())
          : null,
      ejerciciosRealizados: json['ejercicios_realizados'] != null
          ? int.tryParse(json['ejercicios_realizados'].toString())
          : null,
      ejerciciosNoRealizados: json['ejercicios_no_realizados'] != null
          ? int.tryParse(json['ejercicios_no_realizados'].toString())
          : null,
    );
  }

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'codigo_paciente': codigoPaciente,
      'actividad': actividad,
      'descripcion_actividad': descripcionActividad,
      'fecha': fecha.toIso8601String(),
      'duracion_horas': duracionHoras,
      'duracion_minutos': duracionMinutos,
      'duracion_kilometros': duracionKilometros,
      'nivel_esfuerzo': nivelEsfuerzo,
      'notas': notas,
      'fotos': fotos,
      'vueltas': vueltas,
      'codigo_plan_fit': codigoPlanFit,
      'codusuario': codUsuario,
      'validado': validado == true ? 1 : 0,
      'validado_fecha': validadoFecha?.toIso8601String(),
      'validado_usuario': validadoUsuario,
      'ejercicios_total': ejerciciosTotal,
      'ejercicios_realizados': ejerciciosRealizados,
      'ejercicios_no_realizados': ejerciciosNoRealizados,
    };
  }

  // Helper para obtener la duración en minutos totales
  int get duracionTotalMinutos => (duracionHoras * 60) + duracionMinutos;

  // Helper para obtener texto del nivel de esfuerzo
  String get textoNivelEsfuerzo {
    if (nivelEsfuerzo <= 3) {
      return 'Fácil';
    } else if (nivelEsfuerzo <= 6) {
      return 'Moderado';
    } else if (nivelEsfuerzo <= 9) {
      return 'Duro';
    } else {
      return 'Esfuerzo máximo';
    }
  }

  // Helper para obtener descripción del nivel de esfuerzo
  String get descriptionNivelEsfuerzo {
    if (nivelEsfuerzo <= 3) {
      return '¿Qué es fácil?\nPodías hablar con normalidad.\nRespirababas sin problemas.\nTe sentías muy bien';
    } else if (nivelEsfuerzo <= 6) {
      return '¿Qué es moderado?\nPodías hablar, pero de forma entrecortada.\nTe costaba un poco respirar.\nEn tu zona de confort, pero con dificultades.';
    } else if (nivelEsfuerzo <= 9) {
      return '¿Qué es duro?\nCasi no podías hablar.\nRespirababas con dificultad.\nFuera de tu zona de confort.';
    } else {
      return '¿Qué es el esfuerzo máximo?\nHas alcanzado tu límite físico.\nTe has quedado sin aliento.\nNo podías hablar o apenas recordabas quién eras.';
    }
  }

  // Helper para obtener icono del nivel de esfuerzo
  static String getIconoNivelEsfuerzo(int nivel) {
    if (nivel <= 3) return '😊';
    if (nivel <= 6) return '💪';
    if (nivel <= 9) return '🔥';
    return '⚡';
  }
}

// Actividades predefinidas
class ActividadDeportiva {
  static const List<String> actividadesPredefinidas = [
    'Carrera',
    'Carrera de montaña',
    'Caminata',
    'Senderismo',
    'Ciclismo',
    'Ciclismo de montaña',
    'Bicicleta estática',
    'Natación',
    'Remo',
    'Entrenamiento con pesas',
    'Escaleras',
    'Crossfit',
    'Yoga',
    'Fútbol',
    'Pádel',
    'Alpinismo',
    'Tenis',
    'Pilates',
    'Otro',
  ];

  static String getNombreActividad(String codigo) {
    try {
      return actividadesPredefinidas[int.parse(codigo)];
    } catch (e) {
      return codigo;
    }
  }

  static String getIconoActividad(String actividad) {
    switch (actividad.toLowerCase()) {
      case 'carrera':
      case 'carrera de montaña':
        return '🏃';
      case 'caminata':
      case 'senderismo':
        return '🚶';
      case 'ciclismo':
      case 'ciclismo de montaña':
      case 'bicicleta estática':
        return '🚴';
      case 'natación':
        return '🏊';
      case 'remo':
        return '🚣';
      case 'entrenamiento con pesas':
        return '🏋️';
      case 'escaleras':
        return '🪜';
      case 'crossfit':
        return '⚡';
      case 'yoga':
        return '🧘';
      case 'fútbol':
        return '⚽';
      case 'pádel':
      case 'tenis':
        return '🎾';
      case 'alpinismo':
        return '⛰️';
      case 'pilates':
        return '🤸';
      default:
        return '💪';
    }
  }
}
