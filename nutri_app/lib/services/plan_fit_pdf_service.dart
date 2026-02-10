import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/entrevista_fit.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/plan_fit.dart';
import 'package:nutri_app/models/plan_fit_ejercicio.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PlanFitPdfService {
  const PlanFitPdfService._();

  static Future<void> generatePlanFitPdf({
    required BuildContext context,
    required ApiService apiService,
    required PlanFit plan,
    List<PlanFitEjercicio>? ejercicios,
    String? fileName,
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

      final pacientes = await apiService.getPacientes();
      final paciente = pacientes.firstWhere(
        (p) => p.codigo == plan.codigoPaciente,
        orElse: () => Paciente(codigo: 0, nombre: 'Paciente'),
      );
      final edad = _calcularEdad(paciente);

      String objetivo = '';
      final codigoEntrevista = plan.codigoEntrevista;
      if (codigoEntrevista != null && codigoEntrevista != 0) {
        final entrevistas =
            await apiService.getEntrevistasFit(plan.codigoPaciente!);
        final entrevista = entrevistas.firstWhere(
          (e) => e.codigo == codigoEntrevista,
          orElse: () => EntrevistaFit(codigo: 0, codigoPaciente: 0),
        );
        objetivo = (entrevista.objetivos ?? '').trim();
      }

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

      final pdf = pw.Document();

      final hasTiempo = ejerciciosPlan.any((e) => (e.tiempo ?? 0) > 0);
      final hasReps = ejerciciosPlan.any((e) => (e.repeticiones ?? 0) > 0);

      final headers = <String>['EJERCICIO'];
      if (hasTiempo) headers.add('TIEMPO');
      if (hasReps) headers.add('REP.');
      headers.addAll(['DESC.', 'NOTAS']);

      final tableData = ejerciciosPlan.map((e) {
        final tiempo = e.tiempo ?? 0;
        final descanso = e.descanso ?? 0;
        final reps = e.repeticiones ?? 0;
        final row = <String>[e.nombre];
        if (hasTiempo) row.add('${tiempo}s');
        if (hasReps) row.add(reps.toString());
        row.add('${descanso}s');
        row.add(e.instrucciones ?? '');
        return row;
      }).toList();

      final ejerciciosConMedia = ejerciciosPlan
          .where((e) =>
              (e.fotoBase64 ?? '').isNotEmpty || (e.urlVideo ?? '').isNotEmpty)
          .toList();

      final exerciseCards = <pw.Widget>[];
      for (int i = 0; i < ejerciciosConMedia.length; i += 2) {
        final left = ejerciciosConMedia[i];
        final right = i + 1 < ejerciciosConMedia.length
            ? ejerciciosConMedia[i + 1]
            : null;

        pw.Widget buildCard(PlanFitEjercicio e) {
          final hasImage = (e.fotoBase64 ?? '').isNotEmpty;
          final hasUrl = (e.urlVideo ?? '').isNotEmpty;
          pw.Widget? imageWidget;

          if (hasImage) {
            final bytes = base64Decode(e.fotoBase64!);
            imageWidget = pw.Container(
              height: 120,
              alignment: pw.Alignment.center,
              child: pw.Image(
                pw.MemoryImage(bytes),
                height: 120,
                fit: pw.BoxFit.contain,
              ),
            );
          } else {
            imageWidget = pw.Container(
              height: 120,
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
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.SizedBox(height: 6),
                imageWidget,
                if (hasUrl) ...[
                  pw.SizedBox(height: 6),
                  pw.UrlLink(
                    destination: e.urlVideo ?? '',
                    child: pw.Text('Cómo se hace...',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.blue)),
                  )
                ],
              ],
            ),
          );
        }

        exerciseCards.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: buildCard(left)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: right != null ? buildCard(right) : pw.Container()),
            ],
          ),
        );
        exerciseCards.add(pw.SizedBox(height: 8));
      }

      final planFecha = _buildPlanDateRange(plan.desde, plan.hasta);
      final recomendaciones = (plan.recomendaciones ?? '').trim();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 16, 24, 24),
          header: (context) => _buildHeader(
            nutricionistaNombre: nutricionistaNombre,
            nutricionistaSubtitulo: nutricionistaSubtitulo,
            pacienteNombre: paciente.nombre,
            edad: edad,
            planFecha: planFecha,
            objetivo: objetivo,
            recomendaciones: recomendaciones,
            pageNumber: context.pageNumber,
            pageCount: context.pagesCount,
          ),
          build: (context) => [
            pw.Table.fromTextArray(
              headers: headers,
              data: tableData,
              headerStyle:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.3,
              ),
              cellAlignments: () {
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
                alignments[col] = pw.Alignment.centerRight;
                col++;
                alignments[col] = pw.Alignment.centerLeft;
                return alignments;
              }(),
              headerAlignments: () {
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
                alignments[col] = pw.Alignment.centerRight;
                col++;
                alignments[col] = pw.Alignment.centerLeft;
                return alignments;
              }(),
              columnWidths: () {
                final widths = <int, pw.TableColumnWidth>{};
                var col = 0;
                widths[col] = const pw.FlexColumnWidth(2.2);
                col++;
                if (hasTiempo) {
                  widths[col] = const pw.FlexColumnWidth(0.8);
                  col++;
                }
                if (hasReps) {
                  widths[col] = const pw.FlexColumnWidth(0.8);
                  col++;
                }
                widths[col] = const pw.FlexColumnWidth(0.8);
                col++;
                widths[col] = const pw.FlexColumnWidth(2.2);
                return widths;
              }(),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(6),
              decoration: const pw.BoxDecoration(color: PdfColors.green100),
              child: pw.Center(
                child: pw.Text(
                  '${plan.rondas ?? 0} rondas en todos los ejercicios',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: const pw.BoxDecoration(color: PdfColors.pink100),
              child: pw.Text('Consejos',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 4),
            ..._buildBulletList(plan.consejos ?? ''),
            pw.SizedBox(height: 8),
            pw.SizedBox(height: 10),
            if (exerciseCards.isNotEmpty) ...[
              pw.Text('Ejercicios',
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
              decoration: const pw.BoxDecoration(color: PdfColors.pink100),
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
      final resolvedFileName = (fileName != null && fileName.trim().isNotEmpty)
          ? fileName.trim()
          : _buildDefaultFileName(plan);
      await Printing.sharePdf(bytes: bytes, filename: resolvedFileName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  static List<pw.Widget> _buildBulletList(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return [
        pw.Text('-',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))
      ];
    }
    return lines
        .map(
          (line) => pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('· ',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
              pw.Expanded(
                child: pw.Text(line,
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
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

  static pw.Widget _buildHeader({
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    required String pacienteNombre,
    required int edad,
    required String planFecha,
    required String objetivo,
    required String recomendaciones,
    required int pageNumber,
    required int pageCount,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const pw.BoxDecoration(color: PdfColors.pink100),
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
                    if (nutricionistaSubtitulo.trim().isNotEmpty)
                      pw.Text(
                        nutricionistaSubtitulo,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                  ],
                ),
              ),
              pw.Text(
                '$pageNumber/$pageCount',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            'ENTRENAMIENTO HIIT',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 6),
        _buildHeaderTable(
          pacienteNombre: pacienteNombre,
          edad: edad,
          planFecha: planFecha,
          objetivo: objetivo,
          recomendaciones: recomendaciones,
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  static pw.Widget _buildHeaderTable({
    required String pacienteNombre,
    required int edad,
    required String planFecha,
    required String objetivo,
    required String recomendaciones,
  }) {
    final rows = <pw.TableRow>[];

    void addRow(String label, String value) {
      if (value.trim().isEmpty) return;
      rows.add(
        pw.TableRow(
          children: [
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: const pw.BoxDecoration(color: PdfColors.green200),
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: const pw.BoxDecoration(color: PdfColors.green100),
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ),
      );
    }

    addRow('Nombre', pacienteNombre);
    if (edad > 0) {
      addRow('Edad', edad.toString());
    }
    addRow('Desde ... Hasta', planFecha);
    addRow('Objetivo', objetivo);
    addRow('Recomendaciones', recomendaciones);

    if (rows.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(3.0),
      },
      children: rows,
    );
  }

  static String _buildPlanDateRange(DateTime? desde, DateTime? hasta) {
    if (desde == null && hasta == null) return '';
    final formatter = DateFormat('dd/MM/yyyy');
    final desdeStr = desde != null ? formatter.format(desde) : '';
    final hastaStr = hasta != null ? formatter.format(hasta) : '';

    if (desdeStr.isNotEmpty && hastaStr.isNotEmpty) {
      return '$desdeStr - $hastaStr';
    }
    if (desdeStr.isNotEmpty) {
      return desdeStr;
    }
    return '';
  }

  static String _buildDefaultFileName(PlanFit plan) {
    final rawNombre = (plan.nombrePaciente ?? '').trim();
    final nombre = rawNombre.isNotEmpty ? rawNombre : 'paciente';
    final safeNombre = nombre.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');
    return 'plan_hiit_${safeNombre.toLowerCase()}.pdf';
  }
}
