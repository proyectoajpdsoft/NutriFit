import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:nutri_app/models/video_ejercicio.dart';

class VideosEjerciciosCatalogPdfService {
  const VideosEjerciciosCatalogPdfService._();

  static const PdfColor _accentPink = PdfColor.fromInt(0xFFFFC0F4);
  static const PdfColor _softPink = PdfColor.fromInt(0xFFFFE6F7);

  static Future<void> generateCatalogPdf({
    required BuildContext context,
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    Uint8List? logoBytes,
    required String logoSizeStr,
    required String accentColorStr,
    required List<VideoEjercicio> videos,
    required String tituloTexto,
    String? filtroResumen,
  }) async {
    try {
      if (videos.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay vídeos para exportar.'),
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
          header: (ctx) => _buildHeader(
            nutricionistaNombre: nutricionistaNombre,
            nutricionistaSubtitulo: nutricionistaSubtitulo,
            logoBytes: logoBytes,
            logoSize: logoSize,
            tituloTexto: tituloTexto,
            pageNumber: ctx.pageNumber,
            accentColor: accentColor,
          ),
          footer: (ctx) => _buildFooter(
            nutricionistaNombre: nutricionistaNombre,
            pageNumber: ctx.pageNumber,
            pageCount: ctx.pagesCount,
            accentColor: accentColor,
            tituloTexto: tituloTexto,
          ),
          build: (ctx) => [
            if ((filtroResumen ?? '').trim().isNotEmpty)
              _buildFilterSummaryBox(filtroResumen!.trim()),
            _buildVideosTable(videos),
          ],
        ),
      );

      final bytes = await pdf.save();
      const fileName = 'Catalogo_videos_ejercicios.pdf';
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF guardado: Catalogo_videos_ejercicios.pdf'),
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

  static pw.Widget _buildFilterSummaryBox(String filtroResumen) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Text(
        'Filtros aplicados: $filtroResumen',
        style: const pw.TextStyle(fontSize: 8.5),
      ),
    );
  }

  static pw.Widget _buildVideosTable(List<VideoEjercicio> videos) {
    final headerStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );
    const cellStyle = pw.TextStyle(fontSize: 8);

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _softPink),
        children: [
          _buildHeaderCell('Título', headerStyle, pw.TextAlign.left),
          _buildHeaderCell('Categorías', headerStyle, pw.TextAlign.left),
          _buildHeaderCell('Tipo', headerStyle, pw.TextAlign.center),
          _buildHeaderCell('Visible', headerStyle, pw.TextAlign.center),
          _buildHeaderCell('Likes', headerStyle, pw.TextAlign.right),
          _buildHeaderCell('Descripción', headerStyle, pw.TextAlign.left),
        ],
      ),
    ];

    for (final video in videos) {
      final categorias = video.categoriaNombres.join(', ');
      final tipo = video.esYoutube
          ? 'YouTube'
          : video.esGif
              ? 'GIF'
              : 'Vídeo';
      rows.add(
        pw.TableRow(
          children: [
            _buildTextCell(video.titulo, cellStyle, pw.TextAlign.left),
            _buildTextCell(categorias, cellStyle, pw.TextAlign.left),
            _buildTextCell(tipo, cellStyle, pw.TextAlign.center),
            _buildTextCell(
              (video.visible ?? 'S').toUpperCase() == 'S' ? 'Sí' : 'No',
              cellStyle,
              pw.TextAlign.center,
            ),
            _buildTextCell(
              '${video.totalLikes}',
              cellStyle,
              pw.TextAlign.right,
            ),
            _buildTextCell(
              (video.descripcion ?? '').trim(),
              cellStyle,
              pw.TextAlign.left,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.0),
        1: const pw.FlexColumnWidth(1.7),
        2: const pw.FlexColumnWidth(1.0),
        3: const pw.FlexColumnWidth(0.9),
        4: const pw.FlexColumnWidth(0.8),
        5: const pw.FlexColumnWidth(2.4),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  static pw.Widget _buildHeaderCell(
    String text,
    pw.TextStyle style,
    pw.TextAlign align,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  static pw.Widget _buildTextCell(
    String text,
    pw.TextStyle style,
    pw.TextAlign align,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: style,
        maxLines: 3,
        overflow: pw.TextOverflow.clip,
        textAlign: align,
      ),
    );
  }

  static PdfPoint? _parseLogoSize(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final tokens = text
        .split(RegExp(r'[xX,;\s]+'))
        .where((token) => token.trim().isNotEmpty)
        .toList();

    if (tokens.isEmpty) return null;

    final width = double.tryParse(tokens.first.replaceAll(',', '.'));
    if (width == null || width <= 0) return null;

    final height = tokens.length > 1
        ? double.tryParse(tokens[1].replaceAll(',', '.'))
        : null;

    return PdfPoint(width, (height != null && height > 0) ? height : width);
  }

  static PdfColor? _parsePdfColor(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final normalized = text.startsWith('#') ? text.substring(1) : text;
    if (normalized.length == 6 || normalized.length == 8) {
      final value = int.tryParse(normalized, radix: 16);
      if (value == null) return null;
      final rgb = normalized.length == 8 ? (value & 0xFFFFFF) : value;
      return PdfColor.fromInt(rgb);
    }

    final parts = text
        .split(RegExp(r'[\s,;]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 3) return null;

    final values = parts.take(3).map((part) {
      final parsed = int.tryParse(part);
      if (parsed == null) return null;
      return parsed.clamp(0, 255);
    }).toList();

    if (values.any((value) => value == null)) return null;

    return PdfColor(
      (values[0] as int) / 255,
      (values[1] as int) / 255,
      (values[2] as int) / 255,
    );
  }
}
