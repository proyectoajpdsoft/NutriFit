class CharlaDiapositiva {
  CharlaDiapositiva({
    this.codigo,
    required this.codigoCharla,
    required this.numeroDiapositiva,
    this.imagenDiapositiva,
    this.imagenDiapositivaNombre,
    this.imagenMiniatura,
    this.audioDiapositiva,
    this.audioDiapositivaNombre,
    this.audioDiapositivaMime,
    this.audioDuracionMs,
    this.anchoPx,
    this.altoPx,
    this.duracionPresentacionSeg,
  });

  int? codigo;
  int codigoCharla;
  int numeroDiapositiva;
  String? imagenDiapositiva;
  String? imagenDiapositivaNombre;
  String? imagenMiniatura;
  String? audioDiapositiva;
  String? audioDiapositivaNombre;
  String? audioDiapositivaMime;
  int? audioDuracionMs;
  int? anchoPx;
  int? altoPx;

  /// Duración asignada en la presentación global (segundos). Null = no configurada.
  double? duracionPresentacionSeg;

  factory CharlaDiapositiva.fromJson(Map<String, dynamic> json) {
    return CharlaDiapositiva(
      codigo: json['codigo'] != null
          ? int.tryParse(json['codigo'].toString())
          : null,
      codigoCharla: json['codigo_charla'] != null
          ? int.tryParse(json['codigo_charla'].toString()) ?? 0
          : 0,
      numeroDiapositiva: json['numero_diapositiva'] != null
          ? int.tryParse(json['numero_diapositiva'].toString()) ?? 1
          : 1,
      imagenDiapositiva: json['imagen_diapositiva']?.toString(),
      imagenDiapositivaNombre: json['imagen_diapositiva_nombre']?.toString(),
      imagenMiniatura: json['imagen_miniatura']?.toString(),
      audioDiapositiva: json['audio_diapositiva']?.toString(),
      audioDiapositivaNombre: json['audio_diapositiva_nombre']?.toString(),
      audioDiapositivaMime: json['audio_diapositiva_mime']?.toString(),
      audioDuracionMs: json['audio_duracion_ms'] != null
          ? int.tryParse(json['audio_duracion_ms'].toString())
          : null,
      anchoPx: json['ancho_px'] != null
          ? int.tryParse(json['ancho_px'].toString())
          : null,
      altoPx: json['alto_px'] != null
          ? int.tryParse(json['alto_px'].toString())
          : null,
      duracionPresentacionSeg: json['duracion_presentacion_seg'] != null
          ? double.tryParse(json['duracion_presentacion_seg'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (codigo != null) 'codigo': codigo,
      'codigo_charla': codigoCharla,
      'numero_diapositiva': numeroDiapositiva,
      if (imagenDiapositiva != null) 'imagen_diapositiva': imagenDiapositiva,
      if (imagenDiapositivaNombre != null)
        'imagen_diapositiva_nombre': imagenDiapositivaNombre,
      if (imagenMiniatura != null) 'imagen_miniatura': imagenMiniatura,
      if (audioDiapositiva != null) 'audio_diapositiva': audioDiapositiva,
      if (audioDiapositivaNombre != null)
        'audio_diapositiva_nombre': audioDiapositivaNombre,
      if (audioDiapositivaMime != null)
        'audio_diapositiva_mime': audioDiapositivaMime,
      if (audioDuracionMs != null) 'audio_duracion_ms': audioDuracionMs,
      if (anchoPx != null) 'ancho_px': anchoPx,
      if (altoPx != null) 'alto_px': altoPx,
      if (duracionPresentacionSeg != null)
        'duracion_presentacion_seg': duracionPresentacionSeg,
    };
  }
}
