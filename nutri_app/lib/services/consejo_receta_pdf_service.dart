import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ConsejoRecetaPdfService {
  const ConsejoRecetaPdfService._();

  static const PdfColor _accentPink = PdfColor.fromInt(0xFFFFC0F4);

  static Future<void> generatePdf({
    required BuildContext context,
    required ApiService apiService,
    required String titulo,
    required String contenido,
    required String tipo, // 'consejo' o 'receta'
    String? fileName,
  }) async {
    try {
      // Obtener parámetros del nutricionista
      final nutricionistaParam =
          await apiService.getParametro('nutricionista_nombre');
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      // Obtener logo
      Uint8List? logoBytes;
      String logoSizeStr = '';
      final logoParam =
          await apiService.getParametro('logotipo_dietista_documentos');
      if (logoParam != null) {
        final logoBase64 = logoParam['valor']?.toString();
        final logoSizeParam = logoParam['valor2']?.toString() ?? '';
        if (logoBase64 != null && logoBase64.trim().isNotEmpty) {
          try {
            logoBytes = base64Decode(logoBase64);
            logoSizeStr = logoSizeParam;
          } catch (_) {
            logoBytes = null;
          }
        }
      }

      // Obtener color de fondo del encabezado y pie
      final colorParam =
          await apiService.getParametro('color_fondo_banda_encabezado_pie_pdf');
      final accentColorStr = colorParam?['valor']?.toString() ?? '';
      final accentColor = _parsePdfColor(accentColorStr) ?? _accentPink;

      final pdf = pw.Document();

      final tituloTipo = tipo == 'receta' ? 'RECETA' : 'CONSEJO';

      // Limpiar emojis del contenido
      final contenidoSinEmojis = _removeEmojis(contenido);
      final tituloSinEmojis = _removeEmojis(titulo);

      final logoSize = _parseLogoSize(logoSizeStr);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 16, 24, 24),
          header: (context) => _buildHeader(
            nutricionistaNombre: nutricionistaNombre,
            nutricionistaSubtitulo: nutricionistaSubtitulo,
            logoBytes: logoBytes,
            logoSize: logoSize,
            titulo_tipo: tituloTipo,
            pageNumber: context.pageNumber,
            accentColor: accentColor,
          ),
          footer: (context) => _buildFooter(
            nutricionistaNombre: nutricionistaNombre,
            pageNumber: context.pageNumber,
            pageCount: context.pagesCount,
            accentColor: accentColor,
            titulo_tipo: tituloTipo,
          ),
          build: (context) => [
            pw.Text(
              tituloSinEmojis,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              contenidoSinEmojis,
              style: const pw.TextStyle(fontSize: 11, height: 1.5),
              textAlign: pw.TextAlign.justify,
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final safeFileName =
          tituloSinEmojis.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');
      final resolvedFileName = (fileName != null && fileName.trim().isNotEmpty)
          ? fileName.trim()
          : '${tipo}_${safeFileName.toLowerCase()}.pdf';

      await Printing.sharePdf(bytes: bytes, filename: resolvedFileName);
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
    required String titulo_tipo,
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
        if (pageNumber == 1)
          pw.Center(
            child: pw.Text(
              titulo_tipo,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
        if (pageNumber == 1) pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _buildFooter({
    required String nutricionistaNombre,
    required int pageNumber,
    required int pageCount,
    required PdfColor accentColor,
    required String titulo_tipo,
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
                titulo_tipo,
                style: footerStyle,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ),
        ],
      ),
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

  static String _removeEmojis(String text) {
    // Expresión regular para detectar y eliminar emojis y otros caracteres especiales Unicode
    final regExp = RegExp(
      r'[\u{1F300}-\u{1F9FF}]|'
      r'[\u{2600}-\u{27BF}]|'
      r'[\u{2300}-\u{23FF}]|'
      r'[\u{2000}-\u{206F}]|'
      r'[\u{3000}-\u{303F}]|'
      r'[\u{2000}-\u{206F}]|'
      r'[\u{2070}-\u{209F}]|'
      r'[\u{20A0}-\u{20CF}]|'
      r'[\u{2100}-\u{214F}]|'
      r'[\u{2B50}-\u{2B55}]',
      unicode: true,
    );
    // Quitar emojis, respetando saltos de línea
    final cleaned = text.replaceAll(regExp, '');
    // Limpiar espacios múltiples en cada línea, pero mantener saltos de línea
    final lines = cleaned
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .join('\n');
    return lines;
  }
}
