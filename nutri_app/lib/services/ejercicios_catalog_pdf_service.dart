import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:nutri_app/models/plan_fit_ejercicio.dart';

class EjerciciosCatalogPdfService {
  const EjerciciosCatalogPdfService._();

  static const PdfColor _accentPink = PdfColor.fromInt(0xFFFFC0F4);
  static const PdfColor _softPink = PdfColor.fromInt(0xFFFFE6F7);

  static Future<void> generateCatalogPdf({
    required BuildContext context,
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    Uint8List? logoBytes,
    required String logoSizeStr,
    required String accentColorStr,
    required List<PlanFitEjercicio> ejercicios,
    required String tituloTexto,
  }) async {
    try {
      if (ejercicios.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay ejercicios para exportar.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final logoSize = _parseLogoSize(logoSizeStr);
      final accentColor = _parsePdfColor(accentColorStr) ?? _accentPink;

      final pdf = pw.Document();

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
          build: (context) => [_buildEjerciciosTable(ejercicios)],
        ),
      );

      final bytes = await pdf.save();
      const fileName = 'Catalogo_ejercicios.pdf';
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF guardado: Catalogo_ejercicios.pdf'),
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

  static pw.Widget _buildEjerciciosTable(List<PlanFitEjercicio> ejercicios) {
    final headerStyle =
        pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    const cellStyle = pw.TextStyle(fontSize: 8);

    final rows = <pw.TableRow>[];
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _softPink),
        children: [
          _buildHeaderCell('Nombre', headerStyle, pw.TextAlign.left),
          _buildHeaderCell('T (s)', headerStyle, pw.TextAlign.right),
          _buildHeaderCell('R', headerStyle, pw.TextAlign.right),
          _buildHeaderCell('P (kg)', headerStyle, pw.TextAlign.right),
          _buildHeaderCell('D (s)', headerStyle, pw.TextAlign.right),
          _buildHeaderCell('Instrucciones', headerStyle, pw.TextAlign.left),
          _buildHeaderCell('Img', headerStyle, pw.TextAlign.center),
        ],
      ),
    );

    for (final ejercicio in ejercicios) {
      final thumbBytes = _decodeBase64Image(
            (ejercicio.fotoMiniatura ?? '').trim(),
          ) ??
          _decodeBase64Image((ejercicio.fotoBase64 ?? '').trim());

      rows.add(
        pw.TableRow(
          children: [
            _buildTextCell(ejercicio.nombre, cellStyle, pw.TextAlign.left),
            _buildTextCell(
              _formatNumber(ejercicio.tiempo),
              cellStyle,
              pw.TextAlign.right,
            ),
            _buildTextCell(
              _formatNumber(ejercicio.repeticiones),
              cellStyle,
              pw.TextAlign.right,
            ),
            _buildTextCell(
              _formatNumber(ejercicio.kilos),
              cellStyle,
              pw.TextAlign.right,
            ),
            _buildTextCell(
              _formatNumber(ejercicio.descanso),
              cellStyle,
              pw.TextAlign.right,
            ),
            _buildTextCell(
              (ejercicio.instrucciones ?? '').trim(),
              cellStyle,
              pw.TextAlign.left,
            ),
            _buildImageCell(thumbBytes),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FixedColumnWidth(40),
        2: const pw.FixedColumnWidth(32),
        3: const pw.FixedColumnWidth(34),
        4: const pw.FixedColumnWidth(34),
        5: const pw.FlexColumnWidth(4),
        6: const pw.FixedColumnWidth(44),
      },
      children: rows,
    );
  }

  static pw.Widget _buildHeaderCell(
    String text,
    pw.TextStyle style,
    pw.TextAlign align,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: _mapAlign(align),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  static pw.Widget _buildTextCell(
    String text,
    pw.TextStyle style,
    pw.TextAlign align,
  ) {
    final safeText = text.trim().isEmpty ? '-' : text.trim();
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: _mapAlign(align),
      child: pw.Text(safeText, style: style, textAlign: align),
    );
  }

  static pw.Widget _buildImageCell(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.center,
        child: pw.Text('-', style: const pw.TextStyle(fontSize: 8)),
      );
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(2),
      alignment: pw.Alignment.center,
      child: pw.Image(
        pw.MemoryImage(bytes),
        width: 34,
        height: 34,
        fit: pw.BoxFit.cover,
      ),
    );
  }

  static String _formatNumber(int? value) {
    if (value == null || value == 0) {
      return '-';
    }
    return value.toString();
  }

  static Uint8List? _decodeBase64Image(String base64String) {
    var data = base64String.trim();
    if (data.isEmpty) {
      return null;
    }
    const marker = 'base64,';
    final index = data.indexOf(marker);
    if (index >= 0) {
      data = data.substring(index + marker.length);
    }
    while (data.length % 4 != 0) {
      data += '=';
    }
    try {
      return Uint8List.fromList(base64Decode(data));
    } catch (_) {
      return null;
    }
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

  static pw.Alignment _mapAlign(pw.TextAlign align) {
    switch (align) {
      case pw.TextAlign.center:
        return pw.Alignment.center;
      case pw.TextAlign.right:
        return pw.Alignment.centerRight;
      default:
        return pw.Alignment.centerLeft;
    }
  }
}
