import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class EntrenamientoStatsPdfResumen {
  final int totalActividades;
  final double totalKilometros;
  final double totalDesnivel;
  final int totalMinutos;
  final double totalPesoKg;
  final int totalEjercicios;
  final double promedioActividades;
  final double promedioKilometros;
  final double promedioDesnivel;
  final double promedioMinutos;
  final double promedioPesoKg;
  final double promedioEjercicios;
  final bool promedioPorDia;

  const EntrenamientoStatsPdfResumen({
    required this.totalActividades,
    required this.totalKilometros,
    required this.totalDesnivel,
    required this.totalMinutos,
    required this.totalPesoKg,
    required this.totalEjercicios,
    required this.promedioActividades,
    required this.promedioKilometros,
    required this.promedioDesnivel,
    required this.promedioMinutos,
    required this.promedioPesoKg,
    required this.promedioEjercicios,
    required this.promedioPorDia,
  });
}

class EntrenamientoStatsPdfService {
  const EntrenamientoStatsPdfService._();

  static const PdfColor _accentPink = PdfColor.fromInt(0xFFFFC0F4);

  static Future<void> generateStatsPdf({
    required BuildContext context,
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    Uint8List? logoBytes,
    required String logoSizeStr,
    required String accentColorStr,
    required Uint8List chartImageBytes,
    required String periodoLabel,
    required EntrenamientoStatsPdfResumen resumen,
    required bool showActividades,
    required bool showKilometros,
    bool showDesnivel = true,
    required bool showMinutos,
    required bool showPeso,
  }) async {
    try {
      final logoSize = _parseLogoSize(logoSizeStr);
      final accentColor = _parsePdfColor(accentColorStr) ?? _accentPink;

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 16, 24, 24),
          header: (ctx) => _buildHeader(
            nutricionistaNombre: nutricionistaNombre,
            nutricionistaSubtitulo: nutricionistaSubtitulo,
            logoBytes: logoBytes,
            logoSize: logoSize,
            tituloTexto: 'Estadísticas de actividades',
            pageNumber: ctx.pageNumber,
            accentColor: accentColor,
          ),
          footer: (ctx) => _buildFooter(
            nutricionistaNombre: nutricionistaNombre,
            pageNumber: ctx.pageNumber,
            pageCount: ctx.pagesCount,
            accentColor: accentColor,
            tituloTexto: 'Estadísticas de actividades',
          ),
          build: (ctx) => [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Período: $periodoLabel',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Series: ${_seriesVisibles(showActividades, showKilometros, showDesnivel, showMinutos, showPeso)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generado: ${_formatNow(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            _buildGraphSection(chartImageBytes),
            pw.SizedBox(height: 12),
            pw.Text(
              'Resumen del período',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _buildResumenTable(resumen),
          ],
        ),
      );

      final bytes = await pdf.save();
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'Estadisticas_actividades_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF guardado: $fileName'),
          backgroundColor: Colors.green,
        ),
      );

      await OpenFilex.open(filePath);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static pw.Widget _buildGraphSection(Uint8List chartImageBytes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          alignment: pw.Alignment.center,
          child: pw.Container(
            width: 520,
            height: 300,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Center(
              child: pw.Image(
                pw.MemoryImage(chartImageBytes),
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildResumenTable(EntrenamientoStatsPdfResumen resumen) {
    final horasTotal = resumen.totalMinutos ~/ 60;
    final minutosTotal = resumen.totalMinutos % 60;
    final promedioMinutosRedondeado = resumen.promedioMinutos.round();
    final horasProm = promedioMinutosRedondeado ~/ 60;
    final minutosProm = promedioMinutosRedondeado % 60;

    pw.Widget row(String a, String b, String c) {
      return pw.Row(
        children: [
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(a, style: const pw.TextStyle(fontSize: 10)),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(b, style: const pw.TextStyle(fontSize: 10)),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(c, style: const pw.TextStyle(fontSize: 10)),
            ),
          ),
        ],
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            color: PdfColors.grey200,
            padding: const pw.EdgeInsets.all(6),
            child: pw.Row(
              children: [
                _head('Métrica'),
                _head('Total'),
                _head(resumen.promedioPorDia ? 'Promedio diario' : 'Promedio'),
              ],
            ),
          ),
          row(
            'Actividades',
            '${resumen.totalActividades}',
            _formatMax2Decimals(resumen.promedioActividades),
          ),
          row(
            'Kilómetros',
            resumen.totalKilometros.toStringAsFixed(2),
            _formatMax2Decimals(resumen.promedioKilometros),
          ),
          row(
            'Subida (m)',
            resumen.totalDesnivel.toStringAsFixed(0),
            _formatMax2Decimals(resumen.promedioDesnivel),
          ),
          row(
            'Tiempo',
            '${horasTotal}h ${minutosTotal}m',
            '${horasProm}h ${minutosProm}m',
          ),
          row(
            'Peso (kg)',
            resumen.totalPesoKg.toStringAsFixed(1),
            _formatMax2Decimals(resumen.promedioPesoKg),
          ),
          row(
            'Ejercicios',
            resumen.totalEjercicios.toString(),
            _formatMax2Decimals(resumen.promedioEjercicios),
          ),
        ],
      ),
    );
  }

  static String _formatMax2Decimals(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.contains('.')
        ? fixed
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '')
        : fixed;
  }

  static pw.Widget _head(String text) {
    return pw.Expanded(
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static String _seriesVisibles(
    bool showActividades,
    bool showKilometros,
    bool showDesnivel,
    bool showMinutos,
    bool showPeso,
  ) {
    final values = <String>[];
    if (showActividades) values.add('Actividades');
    if (showKilometros) values.add('Kilómetros');
    if (showDesnivel) values.add('Subida');
    if (showMinutos) values.add('Minutos');
    if (showPeso) values.add('Peso');
    if (values.isEmpty) return 'Ninguna';
    return values.join(', ');
  }

  static String _formatNow(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    final hh = date.hour.toString().padLeft(2, '0');
    final mi = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$mi';
  }

  static pw.Widget _buildHeader({
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    Uint8List? logoBytes,
    PdfPoint? logoSize,
    required String tituloTexto,
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
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
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
                    pw.MemoryImage(logoBytes),
                    fit: pw.BoxFit.contain,
                  ),
                )
              else
                pw.SizedBox(
                  width: logoSize?.x ?? 42,
                  height: logoSize?.y ?? 30,
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            tituloTexto,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 6),
      ],
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
              child: pw.Text('$pageNumber/$pageCount', style: footerStyle),
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

  static PdfPoint? _parseLogoSize(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    final parts = cleaned.split('x');
    if (parts.length != 2) return null;
    final width = double.tryParse(parts[0].trim());
    final height = double.tryParse(parts[1].trim());
    if (width == null || height == null) return null;
    return PdfPoint(width, height);
  }

  static PdfColor? _parsePdfColor(String? value) {
    final cleaned = (value ?? '').trim();
    if (cleaned.isEmpty) return null;
    final normalized = cleaned.startsWith('#') ? cleaned.substring(1) : cleaned;
    final argb = int.tryParse(normalized, radix: 16);
    if (argb == null) return null;
    if (normalized.length == 6) {
      return PdfColor.fromInt(0xFF000000 | argb);
    }
    if (normalized.length == 8) {
      return PdfColor.fromInt(argb);
    }
    return null;
  }
}
