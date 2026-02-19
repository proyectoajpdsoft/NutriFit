import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/plan_fit.dart';
import 'package:nutri_app/models/plan_fit_dia.dart';
import 'package:nutri_app/models/plan_fit_ejercicio.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PlanFitPdfService {
  const PlanFitPdfService._();

  static const PdfColor _accentPink = PdfColor.fromInt(0xFFFFC0F4);
  static const PdfColor _softPink = PdfColor.fromInt(0xFFFFE6F7);

  static Future<void> generatePlanFitPdf({
    required BuildContext context,
    required ApiService apiService,
    required PlanFit plan,
    List<PlanFitEjercicio>? ejercicios,
    String? fileName,
    bool resumen = false,
    bool fichaPorDias = true,
    bool showMiniThumbs = false,
    bool showConsejos = true,
    bool showRecomendaciones = true,
  }) async {
    try {
      if (plan.codigoPaciente == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona un paciente primero.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final ejerciciosPlan = (ejercicios == null || ejercicios.isEmpty)
          ? await apiService.getPlanFitEjercicios(plan.codigo)
          : ejercicios;
      final diasPlan = await apiService.getDiasPlanFit(plan.codigo);

      final pacientes = await apiService.getPacientes();
      final paciente = pacientes.firstWhere(
        (p) => p.codigo == plan.codigoPaciente,
        orElse: () => Paciente(codigo: 0, nombre: 'Paciente'),
      );
      final edad = _calcularEdad(paciente);

      final nutricionistaParam =
          await apiService.getParametro('nutricionista_nombre');
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      final nutricionistaEmailParam =
          await apiService.getParametro('nutricionista_email');
      final nutricionistaEmail =
          nutricionistaEmailParam?['valor']?.toString() ?? '';

      final nutricionistaTelegramParam =
          await apiService.getParametro('nutricionista_usuario_telegram');
      final nutricionistaTelegram =
          nutricionistaTelegramParam?['valor']?.toString() ?? '';

      final nutricionistaWebParam =
          await apiService.getParametro('nutricionista_web');
      final nutricionistaWebUrl =
          nutricionistaWebParam?['valor']?.toString() ?? '';
      final nutricionistaWebLabel =
          nutricionistaWebParam?['valor2']?.toString() ?? '';

      final nutricionistaInstagramParam =
          await apiService.getParametro('nutricionista_url_instagram');
      final nutricionistaInstagramUrl =
          nutricionistaInstagramParam?['valor']?.toString() ?? '';
      final nutricionistaInstagramLabel =
          nutricionistaInstagramParam?['valor2']?.toString() ?? '';

      final nutricionistaFacebookParam =
          await apiService.getParametro('nutricionista_url_facebook');
      final nutricionistaFacebookUrl =
          nutricionistaFacebookParam?['valor']?.toString() ?? '';
      final nutricionistaFacebookLabel =
          nutricionistaFacebookParam?['valor2']?.toString() ?? '';

      final logoParam =
          await apiService.getParametro('logotipo_dietista_documentos');
      final logoBytes =
          _decodeBase64Image(logoParam?['valor']?.toString() ?? '');
      final logoSize = _parseLogoSize(logoParam?['valor2']?.toString() ?? '');

      final accentColorParam =
          await apiService.getParametro('color_fondo_banda_encabezado_pie_pdf');
      final accentColor = _parsePdfColor(
            accentColorParam?['valor']?.toString(),
          ) ??
          _accentPink;

      final rondasStyleParam =
          await apiService.getParametro('color_fondo_rondas_pdf');
      final rondasBgColor = _parsePdfColor(
            rondasStyleParam?['valor']?.toString(),
          ) ??
          PdfColors.green100;
      final rondasFontSize =
          _parseFontSize(rondasStyleParam?['valor2']?.toString()) ?? 10.0;

      final descripcionDiaParam =
          await apiService.getParametro('color_fondo_fila_descripcion_dia');
      final descripcionDiaBgColor = _parsePdfColor(
            descripcionDiaParam?['valor']?.toString(),
          ) ??
          PdfColors.green100;
      final descripcionDiaFontSize =
          _parseFontSize(descripcionDiaParam?['valor2']?.toString()) ?? 8.0;

      final tituloParam =
          await apiService.getParametro('texto_titulo_pdf_planes_fit');
      final tituloTexto = tituloParam?['valor']?.toString().trim();
      final tituloPdfTexto = (tituloTexto != null && tituloTexto.isNotEmpty)
          ? tituloTexto
          : 'ENTRENAMIENTO HIIT';
      final tituloPdfFontSize =
          _parseFontSize(tituloParam?['valor2']?.toString()) ?? 16.0;

      final diaHeaderParam =
          await apiService.getParametro('dia_fila_pdf_plan_fit');
      final diaHeaderBgColor = _parsePdfColor(
            diaHeaderParam?['valor']?.toString(),
          ) ??
          PdfColors.blue100;
      final diaHeaderFontSize =
          _parseFontSize(diaHeaderParam?['valor2']?.toString()) ?? 9.0;

      final pdf = pw.Document();

      final hasTiempo = ejerciciosPlan.any((e) => (e.tiempo ?? 0) > 0);
      final hasReps = ejerciciosPlan.any((e) => (e.repeticiones ?? 0) > 0);
      final hasDescanso = ejerciciosPlan.any((e) => (e.descanso ?? 0) > 0);
      final hasPeso = ejerciciosPlan.any((e) => (e.kilos ?? 0) > 0);

      final includeThumbs = resumen || showMiniThumbs;
      final headers = _buildExerciseHeaders(
        hasTiempo: hasTiempo,
        hasReps: hasReps,
        hasDescanso: hasDescanso,
        hasPeso: hasPeso,
        includeThumbs: includeThumbs,
      );

      final hasDias = diasPlan.isNotEmpty;
      final tableData = _buildExerciseRows(
        ejerciciosPlan,
        hasTiempo: hasTiempo,
        hasReps: hasReps,
        hasDescanso: hasDescanso,
        hasPeso: hasPeso,
      );
      final tableWidgets = includeThumbs
          ? _buildExerciseRowWidgets(
              ejerciciosPlan,
              hasTiempo: hasTiempo,
              hasReps: hasReps,
              hasDescanso: hasDescanso,
              hasPeso: hasPeso,
              includeThumbs: includeThumbs,
            )
          : null;

      final ejerciciosConMedia = ejerciciosPlan
          .where((e) =>
              (e.fotoBase64 ?? '').isNotEmpty || (e.urlVideo ?? '').isNotEmpty)
          .toList();
      final exerciseCards = (!resumen && ejerciciosConMedia.isNotEmpty)
          ? (fichaPorDias && hasDias
              ? _buildExerciseCardsByDay(diasPlan, ejerciciosConMedia)
              : _buildExerciseCardRows(
                  fichaPorDias
                      ? ejerciciosConMedia
                      : _dedupeExerciseCardsByName(ejerciciosConMedia),
                ))
          : <pw.Widget>[];

      final desdeStr = _formatDate(plan.desde);
      final hastaStr = _formatDate(plan.hasta);
      final recomendaciones = (plan.recomendaciones ?? '').trim();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 16, 24, 24),
          header: (context) => _buildHeader(
            nutricionistaNombre: nutricionistaNombre,
            nutricionistaSubtitulo: nutricionistaSubtitulo,
            logoBytes: logoBytes,
            logoSize: logoSize,
            tituloTexto: tituloPdfTexto,
            tituloFontSize: tituloPdfFontSize,
            pacienteNombre: paciente.nombre,
            edad: edad,
            desde: desdeStr,
            hasta: hastaStr,
            recomendaciones: recomendaciones,
            showRecomendaciones: showRecomendaciones,
            pageNumber: context.pageNumber,
            accentColor: accentColor,
          ),
          footer: (context) => _buildFooter(
            nutricionistaNombre: nutricionistaNombre,
            pageNumber: context.pageNumber,
            pageCount: context.pagesCount,
            accentColor: accentColor,
            tituloTexto: tituloPdfTexto,
          ),
          build: (context) => [
            if (!hasDias)
              _buildExercisesTable(
                headers: headers,
                data: tableData,
                dataWidgets: tableWidgets,
                hasTiempo: hasTiempo,
                hasReps: hasReps,
                hasDescanso: hasDescanso,
                hasPeso: hasPeso,
                includeThumbs: includeThumbs,
                descripcionDiaBgColor: descripcionDiaBgColor,
                descripcionDiaFontSize: descripcionDiaFontSize,
                diaHeaderBgColor: diaHeaderBgColor,
                diaHeaderFontSize: diaHeaderFontSize,
              )
            else
              ..._buildDayTables(
                diasPlan,
                ejerciciosPlan,
                includeThumbs: includeThumbs,
                descripcionDiaBgColor: descripcionDiaBgColor,
                descripcionDiaFontSize: descripcionDiaFontSize,
                diaHeaderBgColor: diaHeaderBgColor,
                diaHeaderFontSize: diaHeaderFontSize,
              ),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(color: rondasBgColor),
              child: pw.Center(
                child: pw.Text(
                  '${plan.rondas ?? 0} rondas en todos los ejercicios',
                  style: pw.TextStyle(
                      fontSize: rondasFontSize, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            if (showConsejos) ...[
              pw.Container(
                width: double.infinity,
                padding: resumen
                    ? const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3)
                    : const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: const pw.BoxDecoration(color: _softPink),
                child: pw.Text(
                  'Consejos',
                  style: pw.TextStyle(
                    fontSize: resumen ? 9 : 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              ..._buildBulletList(plan.consejos ?? '', compact: resumen),
            ],
            pw.SizedBox(height: 8),
            pw.SizedBox(height: 10),
            if (!resumen && exerciseCards.isNotEmpty) ...[
              pw.Text('Ficha de ejercicios',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              ...exerciseCards,
            ],
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(color: accentColor),
              child: pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(),
                  1: pw.FlexColumnWidth(),
                  2: pw.FlexColumnWidth(),
                },
                children: [
                  pw.TableRow(
                    children: [
                      _buildInfoCell(
                        label: 'Email',
                        iconText: '@',
                        value: nutricionistaEmail,
                      ),
                      _buildInfoCell(
                        label: 'Telegram',
                        iconText: 'TG',
                        value: nutricionistaTelegram,
                      ),
                      _buildLinkCell(
                        label: 'Web',
                        iconText: 'W',
                        url: nutricionistaWebUrl,
                        text: nutricionistaWebLabel,
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildLinkCell(
                        label: 'Instagram',
                        iconText: 'IG',
                        url: nutricionistaInstagramUrl,
                        text: nutricionistaInstagramLabel,
                      ),
                      _buildLinkCell(
                        label: 'Facebook',
                        iconText: 'FB',
                        url: nutricionistaFacebookUrl,
                        text: nutricionistaFacebookLabel,
                      ),
                      pw.SizedBox(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final pacienteNombre =
          _buildSafeFileName((plan.nombrePaciente ?? paciente.nombre).trim());
      final desdeStrFileName = _formatDateForFileName(plan.desde);
      final hastaStrFileName = _formatDateForFileName(plan.hasta);
      final resolvedFileName = resumen
          ? _buildPlanFileName(
              pacienteNombre, desdeStrFileName, hastaStrFileName, '_resumen')
          : _buildPlanFileName(
              pacienteNombre, desdeStrFileName, hastaStrFileName, '');

      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$resolvedFileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF guardado: $resolvedFileName'),
          backgroundColor: Colors.green,
        ),
      );

      await OpenFilex.open(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static List<String> _buildExerciseHeaders({
    required bool hasTiempo,
    required bool hasReps,
    required bool hasDescanso,
    required bool hasPeso,
    required bool includeThumbs,
  }) {
    final headers = <String>['EJERCICIO'];
    if (hasTiempo) headers.add('TIEMPO');
    if (hasReps) headers.add('REP.');
    if (hasPeso) headers.add('PESO');
    if (hasDescanso) headers.add('DESC.');
    headers.add('NOTAS');
    if (includeThumbs) headers.add('IMG');
    return headers;
  }

  static List<List<String>> _buildExerciseRows(
    List<PlanFitEjercicio> ejercicios, {
    required bool hasTiempo,
    required bool hasReps,
    required bool hasDescanso,
    required bool hasPeso,
  }) {
    return ejercicios.map((e) {
      final tiempo = e.tiempo ?? 0;
      final descanso = e.descanso ?? 0;
      final reps = e.repeticiones ?? 0;
      final kilos = e.kilos ?? 0;
      final row = <String>[e.nombre];
      if (hasTiempo) row.add('${tiempo}s');
      if (hasReps) row.add(reps.toString());
      if (hasPeso) row.add(kilos.toString());
      if (hasDescanso) row.add('${descanso}s');
      row.add(e.instrucciones ?? '');
      return row;
    }).toList();
  }

  static List<List<pw.Widget>> _buildExerciseRowWidgets(
    List<PlanFitEjercicio> ejercicios, {
    required bool hasTiempo,
    required bool hasReps,
    required bool hasDescanso,
    required bool hasPeso,
    required bool includeThumbs,
  }) {
    const textStyle = pw.TextStyle(fontSize: 7);
    return ejercicios.map((e) {
      final tiempo = e.tiempo ?? 0;
      final descanso = e.descanso ?? 0;
      final reps = e.repeticiones ?? 0;
      final kilos = e.kilos ?? 0;
      final row = <pw.Widget>[pw.Text(e.nombre, style: textStyle)];
      if (hasTiempo) row.add(pw.Text('${tiempo}s', style: textStyle));
      if (hasReps) row.add(pw.Text(reps.toString(), style: textStyle));
      if (hasPeso) row.add(pw.Text(kilos.toString(), style: textStyle));
      if (hasDescanso) row.add(pw.Text('${descanso}s', style: textStyle));
      row.add(pw.Text(e.instrucciones ?? '', style: textStyle));
      if (includeThumbs) {
        row.add(_buildMiniThumb(e));
      }
      return row;
    }).toList();
  }

  static List<pw.Widget> _buildDayTables(
    List<PlanFitDia> dias,
    List<PlanFitEjercicio> ejercicios, {
    required bool includeThumbs,
    required PdfColor descripcionDiaBgColor,
    required double descripcionDiaFontSize,
    required PdfColor diaHeaderBgColor,
    required double diaHeaderFontSize,
  }) {
    final sortedDias = [...dias]..sort(
        (a, b) => (a.orden ?? a.numeroDia).compareTo(b.orden ?? b.numeroDia));

    final widgets = <pw.Widget>[];
    for (var i = 0; i < sortedDias.length; i++) {
      final dia = sortedDias[i];
      final ejerciciosDia = ejercicios
          .where((e) => e.codigoDia != null && e.codigoDia == dia.codigo)
          .toList();
      if (ejerciciosDia.isEmpty) {
        continue;
      }
      final dayHasTiempo = ejerciciosDia.any((e) => (e.tiempo ?? 0) > 0);
      final dayHasReps = ejerciciosDia.any((e) => (e.repeticiones ?? 0) > 0);
      final dayHasDescanso = ejerciciosDia.any((e) => (e.descanso ?? 0) > 0);
      final dayHasPeso = ejerciciosDia.any((e) => (e.kilos ?? 0) > 0);
      final dayHeaders = _buildExerciseHeaders(
        hasTiempo: dayHasTiempo,
        hasReps: dayHasReps,
        hasDescanso: dayHasDescanso,
        hasPeso: dayHasPeso,
        includeThumbs: includeThumbs,
      );
      final data = _buildExerciseRows(
        ejerciciosDia,
        hasTiempo: dayHasTiempo,
        hasReps: dayHasReps,
        hasDescanso: dayHasDescanso,
        hasPeso: dayHasPeso,
      );
      final dayWidgets = includeThumbs
          ? _buildExerciseRowWidgets(
              ejerciciosDia,
              hasTiempo: dayHasTiempo,
              hasReps: dayHasReps,
              hasDescanso: dayHasDescanso,
              hasPeso: dayHasPeso,
              includeThumbs: includeThumbs,
            )
          : null;

      // Añadir espaciador antes de cada tabla (excepto la primera) para evitar
      // que se separe la fila del día de la tabla entre páginas
      if (i > 0) {
        widgets.add(pw.SizedBox(height: 12));
      }

      widgets.add(
        _buildExercisesTable(
          headers: dayHeaders,
          data: data,
          dataWidgets: dayWidgets,
          hasTiempo: dayHasTiempo,
          hasReps: dayHasReps,
          hasDescanso: dayHasDescanso,
          hasPeso: dayHasPeso,
          includeThumbs: includeThumbs,
          dayLabel: _buildDayLabel(dia),
          dayDescription: (dia.descripcion ?? '').trim(),
          descripcionDiaBgColor: descripcionDiaBgColor,
          descripcionDiaFontSize: descripcionDiaFontSize,
          diaHeaderBgColor: diaHeaderBgColor,
          diaHeaderFontSize: diaHeaderFontSize,
        ),
      );
    }
    return widgets;
  }

  static List<pw.Widget> _buildExerciseCardRows(
      List<PlanFitEjercicio> ejercicios) {
    final widgets = <pw.Widget>[];
    for (int i = 0; i < ejercicios.length; i += 3) {
      final left = ejercicios[i];
      final middle = i + 1 < ejercicios.length ? ejercicios[i + 1] : null;
      final right = i + 2 < ejercicios.length ? ejercicios[i + 2] : null;
      widgets.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildExerciseCard(left)),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child:
                  middle != null ? _buildExerciseCard(middle) : pw.Container(),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: right != null ? _buildExerciseCard(right) : pw.Container(),
            ),
          ],
        ),
      );
      widgets.add(pw.SizedBox(height: 8));
    }
    return widgets;
  }

  static List<pw.Widget> _buildExerciseCardsByDay(
    List<PlanFitDia> dias,
    List<PlanFitEjercicio> ejercicios,
  ) {
    final sortedDias = [...dias]..sort(
        (a, b) => (a.orden ?? a.numeroDia).compareTo(b.orden ?? b.numeroDia));
    final widgets = <pw.Widget>[];
    for (final dia in sortedDias) {
      final ejerciciosDia = ejercicios
          .where((e) => e.codigoDia != null && e.codigoDia == dia.codigo)
          .toList();
      if (ejerciciosDia.isEmpty) {
        continue;
      }
      final dayWidgets = <pw.Widget>[
        pw.Text(
          'Ejercicios ${_buildDayLabel(dia)}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        ..._buildExerciseCardRows(ejerciciosDia),
      ];
      widgets.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: dayWidgets,
        ),
      );
    }
    return widgets;
  }

  static pw.Widget _buildExerciseCard(PlanFitEjercicio e) {
    final hasImage = (e.fotoBase64 ?? '').isNotEmpty;
    final hasUrl = (e.urlVideo ?? '').isNotEmpty;
    pw.Widget imageWidget;

    if (hasImage) {
      final bytes = base64Decode(e.fotoBase64!);
      imageWidget = pw.Container(
        height: 60,
        alignment: pw.Alignment.center,
        child: pw.Image(
          pw.MemoryImage(bytes),
          height: 60,
          fit: pw.BoxFit.contain,
        ),
      );
    } else {
      imageWidget = pw.Container(
        height: 60,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          borderRadius: pw.BorderRadius.circular(4),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(e.nombre,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 6),
          imageWidget,
          if (hasUrl) ...[
            pw.SizedBox(height: 6),
            pw.UrlLink(
              destination: e.urlVideo ?? '',
              child: pw.Text('Cómo se hace...',
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.blue)),
            )
          ],
        ],
      ),
    );
  }

  static String _buildDayLabel(PlanFitDia dia) {
    final title = (dia.titulo ?? '').trim();
    if (title.isEmpty) {
      return 'Día ${dia.numeroDia}';
    }
    return 'Día ${dia.numeroDia} - $title';
  }

  static pw.Widget _buildExercisesTable({
    required List<String> headers,
    required List<List<String>> data,
    List<List<pw.Widget>>? dataWidgets,
    required bool hasTiempo,
    required bool hasReps,
    required bool hasDescanso,
    required bool hasPeso,
    required bool includeThumbs,
    String? dayLabel,
    String? dayDescription,
    required PdfColor descripcionDiaBgColor,
    required double descripcionDiaFontSize,
    required PdfColor diaHeaderBgColor,
    required double diaHeaderFontSize,
  }) {
    final headerStyle =
        pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);
    final dayStyle = pw.TextStyle(
        fontSize: diaHeaderFontSize, fontWeight: pw.FontWeight.bold);
    const cellStyle = pw.TextStyle(fontSize: 7);
    final alignments = _buildColumnAlignments(
        hasTiempo, hasReps, hasDescanso, hasPeso, includeThumbs);
    final widths = _buildColumnWidths(
        hasTiempo, hasReps, hasDescanso, hasPeso, includeThumbs);
    final rowHeight = includeThumbs ? 24.0 : null;

    final rows = <pw.TableRow>[];
    rows.add(
      pw.TableRow(
        children: List.generate(headers.length, (index) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            alignment: alignments[index],
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            child: pw.Text(headers[index], style: headerStyle),
          );
        }),
      ),
    );

    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      final rowWidgets =
          dataWidgets != null && i < dataWidgets.length ? dataWidgets[i] : null;
      rows.add(
        pw.TableRow(
          children: List.generate(headers.length, (index) {
            if (rowWidgets != null && index < rowWidgets.length) {
              return pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                alignment: alignments[index],
                height: rowHeight,
                child: rowWidgets[index],
              );
            }
            final text = index < row.length ? row[index] : '';
            return pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              alignment: alignments[index],
              height: rowHeight,
              child: pw.Text(text, style: cellStyle),
            );
          }),
        ),
      );
    }

    final table = pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
        width: 0.3,
      ),
      columnWidths: widths,
      children: rows,
    );

    final normalizedDescription = (dayDescription ?? '').trim();

    // Si no hay dayLabel ni descripción, retornar solo la tabla
    if ((dayLabel == null || dayLabel.trim().isEmpty) &&
        normalizedDescription.isEmpty) {
      return table;
    }

    // Construir la estructura de día+tabla+descripción en una unidad que no se separe
    final dayElements = <pw.Widget>[];

    if (dayLabel != null && dayLabel.trim().isNotEmpty) {
      dayElements.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: pw.BoxDecoration(color: diaHeaderBgColor),
          child: pw.Text(dayLabel, style: dayStyle),
        ),
      );
    }

    dayElements.add(table);

    if (normalizedDescription.isNotEmpty) {
      dayElements.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: pw.BoxDecoration(color: descripcionDiaBgColor),
          child: pw.Text(
            normalizedDescription,
            style: pw.TextStyle(fontSize: descripcionDiaFontSize),
          ),
        ),
      );
    }

    // Envolver todo en un Column que actuará como unidad visual
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: dayElements,
    );
  }

  static Map<int, pw.Alignment> _buildColumnAlignments(
    bool hasTiempo,
    bool hasReps,
    bool hasDescanso,
    bool hasPeso,
    bool includeThumbs,
  ) {
    final alignments = <int, pw.Alignment>{};
    var col = 0;
    alignments[col] = pw.Alignment.centerLeft;
    col++;
    if (hasTiempo) {
      alignments[col] = pw.Alignment.centerRight;
      col++;
    }
    if (hasReps) {
      alignments[col] = pw.Alignment.centerRight;
      col++;
    }
    if (hasPeso) {
      alignments[col] = pw.Alignment.centerRight;
      col++;
    }
    if (hasDescanso) {
      alignments[col] = pw.Alignment.centerRight;
      col++;
    }
    alignments[col] = pw.Alignment.centerLeft;
    col++;
    if (includeThumbs) {
      alignments[col] = pw.Alignment.center;
    }
    return alignments;
  }

  static Map<int, pw.TableColumnWidth> _buildColumnWidths(
    bool hasTiempo,
    bool hasReps,
    bool hasDescanso,
    bool hasPeso,
    bool includeThumbs,
  ) {
    final widths = <int, pw.TableColumnWidth>{};
    var col = 0;
    widths[col] = const pw.FlexColumnWidth(2.2);
    col++;
    if (hasTiempo) {
      widths[col] = const pw.FlexColumnWidth(0.6);
      col++;
    }
    if (hasReps) {
      widths[col] = const pw.FlexColumnWidth(0.6);
      col++;
    }
    if (hasPeso) {
      widths[col] = const pw.FlexColumnWidth(0.6);
      col++;
    }
    if (hasDescanso) {
      widths[col] = const pw.FlexColumnWidth(0.6);
      col++;
    }
    widths[col] = const pw.FlexColumnWidth(2.6);
    col++;
    if (includeThumbs) {
      widths[col] = const pw.FlexColumnWidth(0.6);
    }
    return widths;
  }

  static pw.Widget _buildMiniThumb(PlanFitEjercicio ejercicio) {
    const thumbSize = 22.0;
    final base64 = (ejercicio.fotoMiniatura ?? '').isNotEmpty
        ? ejercicio.fotoMiniatura!
        : (ejercicio.fotoBase64 ?? '');
    if (base64.isEmpty) {
      return pw.SizedBox(width: thumbSize, height: thumbSize);
    }
    try {
      final bytes = base64Decode(base64);
      return pw.Container(
        width: thumbSize,
        height: thumbSize,
        alignment: pw.Alignment.center,
        child: pw.Image(
          pw.MemoryImage(bytes),
          width: thumbSize,
          height: thumbSize,
          fit: pw.BoxFit.cover,
        ),
      );
    } catch (_) {
      return pw.SizedBox(width: thumbSize, height: thumbSize);
    }
  }

  static int _calcularEdad(Paciente paciente) {
    if (paciente.edad != null) return paciente.edad!;
    final nacimiento = paciente.fechaNacimiento;
    if (nacimiento == null) return 0;
    final hoy = DateTime.now();
    int edad = hoy.year - nacimiento.year;
    if (hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day)) {
      edad--;
    }
    return edad;
  }

  static List<PlanFitEjercicio> _dedupeExerciseCardsByName(
    List<PlanFitEjercicio> ejercicios,
  ) {
    final seen = <String>{};
    final result = <PlanFitEjercicio>[];
    for (final ejercicio in ejercicios) {
      final nombre = ejercicio.nombre.trim().toLowerCase();
      if (nombre.isEmpty) {
        result.add(ejercicio);
        continue;
      }
      if (seen.add(nombre)) {
        result.add(ejercicio);
      }
    }
    return result;
  }

  static List<pw.Widget> _buildBulletList(
    String text, {
    bool compact = false,
  }) {
    final fontSize = compact ? 8.0 : 9.0;
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return [
        pw.Text('-',
            style: pw.TextStyle(fontSize: fontSize, color: PdfColors.grey700))
      ];
    }
    return lines
        .map(
          (line) => pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('· ',
                  style: pw.TextStyle(
                      fontSize: fontSize, color: PdfColors.grey700)),
              pw.Expanded(
                child: pw.Text(line,
                    style: pw.TextStyle(
                        fontSize: fontSize, color: PdfColors.grey700)),
              ),
            ],
          ),
        )
        .toList();
  }

  static pw.Widget _buildInfoCell({
    required String label,
    required String value,
    String? iconText,
  }) {
    final labelWidget = iconText != null && iconText.trim().isNotEmpty
        ? _buildLabelWithIcon(label: label, iconText: iconText)
        : pw.Text(label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold));
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          labelWidget,
          pw.SizedBox(height: 2),
          pw.Text(value.isNotEmpty ? value : '-',
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _buildLinkCell({
    required String label,
    required String url,
    required String text,
    String? iconText,
  }) {
    final displayText = text.isNotEmpty ? text : (url.isNotEmpty ? url : '-');
    final link = url.trim();
    final labelWidget = iconText != null && iconText.trim().isNotEmpty
        ? _buildLabelWithIcon(label: label, iconText: iconText)
        : pw.Text(label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold));
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          labelWidget,
          pw.SizedBox(height: 2),
          if (link.isNotEmpty)
            pw.UrlLink(
              destination: link,
              child: pw.Text(displayText,
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.blue)),
            )
          else
            pw.Text(displayText, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _buildLabelWithIcon({
    required String label,
    required String iconText,
  }) {
    return pw.Row(
      children: [
        _buildIconBadge(iconText),
        pw.SizedBox(width: 4),
        pw.Text(label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildIconBadge(String text) {
    final trimmed = text.trim();
    return pw.Container(
      width: 14,
      height: 14,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey300,
        shape: pw.BoxShape.circle,
      ),
      child: pw.Text(
        trimmed,
        style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildFooter({
    required String nutricionistaNombre,
    required int pageNumber,
    required int pageCount,
    required PdfColor accentColor,
    required String tituloTexto,
  }) {
    const footerStyle = pw.TextStyle(fontSize: 9);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(color: accentColor),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(nutricionistaNombre, style: footerStyle),
            ),
          ),
          pw.Expanded(
            child: pw.Center(
              child: pw.Text(
                '$pageNumber/$pageCount',
                style: footerStyle,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                tituloTexto,
                style: footerStyle,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHeader({
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    required List<int>? logoBytes,
    required PdfPoint? logoSize,
    required String tituloTexto,
    required double tituloFontSize,
    required String pacienteNombre,
    required int edad,
    required String desde,
    required String hasta,
    required String recomendaciones,
    required bool showRecomendaciones,
    required int pageNumber,
    required PdfColor accentColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(color: accentColor),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      nutricionistaNombre,
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                    if (pageNumber == 1 &&
                        nutricionistaSubtitulo.trim().isNotEmpty)
                      pw.Text(
                        nutricionistaSubtitulo,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                  ],
                ),
              ),
              if (logoBytes != null)
                pw.Container(
                  width: logoSize?.x ?? 42,
                  height: logoSize?.y ?? 30,
                  alignment: pw.Alignment.centerRight,
                  child: pw.Image(
                    pw.MemoryImage(Uint8List.fromList(logoBytes)),
                    fit: pw.BoxFit.contain,
                  ),
                )
              else
                pw.SizedBox(
                    width: logoSize?.x ?? 42, height: logoSize?.y ?? 30),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            tituloTexto,
            style: pw.TextStyle(
                fontSize: tituloFontSize, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 6),
        if (pageNumber == 1)
          _buildHeaderTable(
            pacienteNombre: pacienteNombre,
            edad: edad,
            desde: desde,
            hasta: hasta,
            recomendaciones: recomendaciones,
            showRecomendaciones: showRecomendaciones,
          )
        else
          pw.SizedBox(height: 6),
        pw.SizedBox(height: 12),
      ],
    );
  }

  static pw.Widget _buildHeaderTable({
    required String pacienteNombre,
    required int edad,
    required String desde,
    required String hasta,
    required String recomendaciones,
    required bool showRecomendaciones,
  }) {
    pw.Widget buildCell(
      String text, {
      required PdfColor bg,
      pw.TextStyle? style,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: pw.BoxDecoration(color: bg),
        child: pw.Text(text, style: style),
      );
    }

    final labelStyle =
        pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    const valueStyle = pw.TextStyle(fontSize: 9);
    const notesStyle = pw.TextStyle(fontSize: 7);

    final rows = <pw.Widget>[];

    if (edad > 0) {
      rows.add(
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(2.0),
            2: pw.FlexColumnWidth(1.0),
            3: pw.FlexColumnWidth(0.8),
          },
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 0.2,
          ),
          children: [
            pw.TableRow(
              children: [
                buildCell('Nombre', bg: PdfColors.green200, style: labelStyle),
                buildCell(pacienteNombre,
                    bg: PdfColors.green100, style: valueStyle),
                buildCell('Edad', bg: PdfColors.green200, style: labelStyle),
                buildCell(edad.toString(),
                    bg: PdfColors.green100, style: valueStyle),
              ],
            ),
          ],
        ),
      );
    } else {
      rows.add(
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(3.8),
          },
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 0.2,
          ),
          children: [
            pw.TableRow(
              children: [
                buildCell('Nombre', bg: PdfColors.green200, style: labelStyle),
                buildCell(pacienteNombre,
                    bg: PdfColors.green100, style: valueStyle),
              ],
            ),
          ],
        ),
      );
    }

    if (hasta.trim().isNotEmpty) {
      rows.add(
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(2.0),
            2: pw.FlexColumnWidth(1.0),
            3: pw.FlexColumnWidth(0.8),
          },
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 0.2,
          ),
          children: [
            pw.TableRow(
              children: [
                buildCell('Desde', bg: PdfColors.green200, style: labelStyle),
                buildCell(desde.isNotEmpty ? desde : '-',
                    bg: PdfColors.green100, style: valueStyle),
                buildCell('Hasta', bg: PdfColors.green200, style: labelStyle),
                buildCell(hasta, bg: PdfColors.green100, style: valueStyle),
              ],
            ),
          ],
        ),
      );
    } else {
      rows.add(
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(3.8),
          },
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 0.2,
          ),
          children: [
            pw.TableRow(
              children: [
                buildCell('Desde', bg: PdfColors.green200, style: labelStyle),
                buildCell(desde.isNotEmpty ? desde : '-',
                    bg: PdfColors.green100, style: valueStyle),
              ],
            ),
          ],
        ),
      );
    }

    if (showRecomendaciones) {
      rows.add(
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(),
          },
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 0.2,
          ),
          children: [
            pw.TableRow(
              children: [
                buildCell('Recomendaciones',
                    bg: PdfColors.green200, style: labelStyle),
              ],
            ),
          ],
        ),
      );

      rows.add(
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(),
          },
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 0.2,
          ),
          children: [
            pw.TableRow(
              children: [
                buildCell(
                    recomendaciones.trim().isNotEmpty ? recomendaciones : '-',
                    bg: PdfColors.green100,
                    style: notesStyle),
              ],
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rows,
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    final formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(date);
  }

  static PdfPoint? _parseLogoSize(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final match =
        RegExp(r'^(\d+(?:\.\d+)?)\s*x\s*(\d+(?:\.\d+)?)$').firstMatch(raw);
    if (match == null) return null;
    final height = double.tryParse(match.group(1) ?? '');
    final width = double.tryParse(match.group(2) ?? '');
    if (height == null || width == null) return null;
    return PdfPoint(width, height);
  }

  static PdfColor? _parsePdfColor(String? value) {
    if (value == null) return null;
    var raw = value.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('#')) {
      raw = raw.substring(1);
    }
    if (raw.length != 6 && raw.length != 8) return null;
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return null;
    final argb = raw.length == 6 ? (0xFF000000 | parsed) : parsed;
    return PdfColor.fromInt(argb);
  }

  static double? _parseFontSize(String? value) {
    if (value == null) return null;
    final raw = value.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  static List<int>? _decodeBase64Image(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    var data = raw;
    const marker = 'base64,';
    final index = raw.indexOf(marker);
    if (index >= 0) {
      data = raw.substring(index + marker.length);
    }
    while (data.length % 4 != 0) {
      data += '=';
    }
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }

  static String _buildSafeFileName(String text) {
    // Remove accents and special characters, replace spaces with underscores
    final normalized = text
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
    return normalized;
  }

  static String _formatDateForFileName(DateTime? date) {
    if (date == null) return '';
    final formatter = DateFormat('dd_MM_yyyy');
    return formatter.format(date);
  }

  static String _buildPlanFileName(
    String pacienteNombre,
    String desdeStr,
    String hastaStr,
    String suffix,
  ) {
    if (desdeStr.isEmpty && hastaStr.isEmpty) {
      return 'Plan_HIIT_$pacienteNombre$suffix.pdf';
    } else if (hastaStr.isEmpty) {
      return 'Plan_HIIT_${pacienteNombre}_$desdeStr$suffix.pdf';
    } else {
      return 'Plan_HIIT_${pacienteNombre}_${desdeStr}_$hastaStr$suffix.pdf';
    }
  }
}
