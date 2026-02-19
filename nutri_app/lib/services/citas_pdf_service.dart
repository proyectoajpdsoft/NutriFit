import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/cita.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CitasPdfService {
  const CitasPdfService._();

  static const PdfColor _accentPink = PdfColor.fromInt(0xFFFFC0F4);

  static Future<void> generateCitasPdf({
    required BuildContext context,
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    Uint8List? logoBytes,
    required String logoSizeStr,
    required String accentColorStr,
    required List<Cita> citas,
    required String filtroEstado,
  }) async {
    try {
      final logoSize = _parseLogoSize(logoSizeStr);
      final accentColor = _parsePdfColor(accentColorStr) ?? _accentPink;

      final pdf = pw.Document();
      final tituloTexto = _buildTitleFromFilter(filtroEstado);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 16, 24, 24),
          header: (context) => _buildHeader(
            nutricionistaNombre: nutricionistaNombre,
            nutricionistaSubtitulo: nutricionistaSubtitulo,
            logoBytes: logoBytes,
            logoSize: logoSize,
            tituloTexto: tituloTexto,
            pageNumber: context.pageNumber,
            accentColor: accentColor,
          ),
          footer: (context) => _buildFooter(
            nutricionistaNombre: nutricionistaNombre,
            pageNumber: context.pageNumber,
            pageCount: context.pagesCount,
            accentColor: accentColor,
            tituloTexto: tituloTexto,
          ),
          build: (context) => [
            _buildCitasTable(citas),
          ],
        ),
      );

      final bytes = await pdf.save();
      final fileName = _buildFileName(filtroEstado);
      final dir = await getApplicationDocumentsDirectory();
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static String _buildTitleFromFilter(String filtroEstado) {
    final estado = filtroEstado == 'Todas' ? 'Todas' : 'Pendientes';
    return 'CITAS ($estado)';
  }

  static String _buildFileName(String filtroEstado) {
    return 'Citas.pdf';
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
                    pw.MemoryImage(logoBytes),
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

  static pw.Widget _buildCitasTable(List<Cita> citas) {
    final headerStyle =
        pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    const cellStyle = pw.TextStyle(fontSize: 8);
    final descStyle = pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic);

    final rows = <pw.TableRow>[];

    // Header row
    rows.add(
      pw.TableRow(
        children: [
          _buildHeaderCell('Paciente', headerStyle),
          _buildHeaderCell('Empieza', headerStyle),
          _buildHeaderCell('Acaba', headerStyle),
          _buildHeaderCell('Tipo', headerStyle),
          _buildHeaderCell('Asunto', headerStyle),
        ],
      ),
    );

    // Data rows
    for (final cita in citas) {
      final pacienteNombre = cita.nombrePaciente ?? 'Paciente';
      final comienzo = cita.comienzo != null
          ? DateFormat('dd/MM HH:mm').format(cita.comienzo!)
          : '';
      final fin =
          cita.fin != null ? DateFormat('dd/MM HH:mm').format(cita.fin!) : '';
      final tipo = cita.tipo ?? '';
      final asunto = cita.asunto;

      // Main row with cita data
      rows.add(
        pw.TableRow(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.topLeft,
              child: pw.Text(pacienteNombre, style: cellStyle),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.topLeft,
              child: pw.Text(comienzo, style: cellStyle),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.topLeft,
              child: pw.Text(fin, style: cellStyle),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.topLeft,
              child: pw.Text(tipo, style: cellStyle),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.topLeft,
              child: pw.Text(asunto, style: cellStyle),
            ),
          ],
        ),
      );

      // Description row if present
      if ((cita.descripcion ?? '').trim().isNotEmpty) {
        rows.add(
          pw.TableRow(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Descripción:',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      cita.descripcion ?? '',
                      style: descStyle,
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
              ),
            ],
          ),
        );
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
        width: 0.3,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(0.9),
        2: const pw.FlexColumnWidth(0.9),
        3: const pw.FlexColumnWidth(0.8),
        4: const pw.FlexColumnWidth(2.0),
      },
      children: rows,
    );
  }

  static pw.Widget _buildHeaderCell(String text, pw.TextStyle style) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      alignment: pw.Alignment.centerLeft,
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      child: pw.Text(text, style: style),
    );
  }

  static PdfPoint? _parseLogoSize(String? sizeStr) {
    if (sizeStr == null || sizeStr.trim().isEmpty) {
      return const PdfPoint(42, 30);
    }
    final parts = sizeStr.split('x');
    if (parts.length == 2) {
      final width = double.tryParse(parts[0].trim());
      final height = double.tryParse(parts[1].trim());
      if (width != null && height != null) {
        return PdfPoint(width, height);
      }
    }
    return const PdfPoint(42, 30);
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
}
