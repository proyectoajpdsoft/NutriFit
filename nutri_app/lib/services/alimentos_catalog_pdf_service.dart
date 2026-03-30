import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:nutri_app/models/alimento.dart';
import 'package:nutri_app/models/harvard_categoria.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AlimentosCatalogPdfService {
  const AlimentosCatalogPdfService._();

  static const PdfColor _accentPink = PdfColor.fromInt(0xFFFFC0F4);
  static const PdfColor _softPink = PdfColor.fromInt(0xFFFFE6F7);
  static const List<String> _emojiAssetFallbackPaths = [
    'assets/fonts/NotoEmoji-Regular.ttf',
    'assets/fonts/NotoEmoji-Bold.ttf',
    'assets/fonts/NotoEmoji-SemiBold.ttf',
    'assets/fonts/NotoEmoji-Medium.ttf',
    'assets/fonts/NotoEmoji-Light.ttf',
  ];

  static Future<void> generateCatalogPdf({
    required BuildContext context,
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    Uint8List? logoBytes,
    required String logoSizeStr,
    required String accentColorStr,
    required List<Alimento> alimentos,
    required List<HarvardCategoria> harvardCategorias,
    String? filtroResumen,
  }) async {
    try {
      if (alimentos.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay alimentos para exportar.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final logoSize = _parseLogoSize(logoSizeStr);
      final accentColor = _parsePdfColor(accentColorStr) ?? _accentPink;
      final pdf = pw.Document();
      final theme = await _buildPdfTheme();

      pdf.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 16, 24, 24),
          header: (pdfContext) => _buildHeader(
            nutricionistaNombre: nutricionistaNombre,
            nutricionistaSubtitulo: nutricionistaSubtitulo,
            logoBytes: logoBytes,
            logoSize: logoSize,
            pageNumber: pdfContext.pageNumber,
            accentColor: accentColor,
          ),
          footer: (pdfContext) => _buildFooter(
            nutricionistaNombre: nutricionistaNombre,
            pageNumber: pdfContext.pageNumber,
            pageCount: pdfContext.pagesCount,
            accentColor: accentColor,
          ),
          build: (pdfContext) => [
            if ((filtroResumen ?? '').trim().isNotEmpty)
              _buildFilterSummaryBox(filtroResumen!.trim()),
            _buildAlimentosTable(alimentos, harvardCategorias),
          ],
        ),
      );

      final bytes = await pdf.save();
      const fileName = 'Catalogo_alimentos.pdf';
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF guardado: Catalogo_alimentos.pdf'),
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
            'Catálogo de alimentos',
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
                'Catálogo de alimentos',
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

  static pw.Widget _buildAlimentosTable(
    List<Alimento> alimentos,
    List<HarvardCategoria> harvardCategorias,
  ) {
    final headerStyle = pw.TextStyle(
      fontSize: 8.5,
      fontWeight: pw.FontWeight.bold,
    );
    const cellStyle = pw.TextStyle(fontSize: 8);
    final harvardMap = {
      for (final categoria in harvardCategorias) categoria.codigo: categoria,
    };

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _softPink),
        children: [
          _buildHeaderCell('Nombre', headerStyle, pw.TextAlign.left),
          _buildHeaderCell('Categorías', headerStyle, pw.TextAlign.left),
          _buildHeaderCell(
            'Categorías Harvard',
            headerStyle,
            pw.TextAlign.left,
          ),
          _buildHeaderCell('Activo', headerStyle, pw.TextAlign.center),
          _buildHeaderCell('Opción', headerStyle, pw.TextAlign.center),
          _buildHeaderCell('Observación', headerStyle, pw.TextAlign.left),
        ],
      ),
    ];

    for (final alimento in alimentos) {
      rows.add(
        pw.TableRow(
          children: [
            _buildTextCell(alimento.nombre, cellStyle, pw.TextAlign.left),
            _buildTextCell(
              _categoriasLabel(alimento),
              cellStyle,
              pw.TextAlign.left,
            ),
            _buildHarvardCell(alimento, harvardMap),
            _buildTextCell(
              alimento.activo == 1 ? 'Sí' : 'No',
              cellStyle,
              pw.TextAlign.center,
            ),
            _buildTextCell(
              (alimento.opcion ?? '').trim().toUpperCase() == 'S' ? 'Sí' : 'No',
              cellStyle,
              pw.TextAlign.center,
            ),
            _buildTextCell(
              (alimento.observacion ?? '').trim(),
              cellStyle,
              pw.TextAlign.left,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.4),
        1: const pw.FlexColumnWidth(2.0),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FixedColumnWidth(42),
        4: const pw.FixedColumnWidth(42),
        5: const pw.FlexColumnWidth(2.3),
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

  static pw.Widget _buildHarvardCell(
    Alimento alimento,
    Map<String, HarvardCategoria> harvardMap,
  ) {
    final assignedCodes = alimento.harvardCategorias.isNotEmpty
        ? alimento.harvardCategorias
        : ((alimento.harvardCategoria ?? '').trim().isNotEmpty
            ? <String>[alimento.harvardCategoria!.trim()]
            : const <String>[]);
    final assignedNames = alimento.harvardCategoriasNombres;

    if (assignedCodes.isEmpty) {
      return _buildTextCell(
          '-', const pw.TextStyle(fontSize: 8), pw.TextAlign.left);
    }

    final badges = <pw.Widget>[];
    final seenKeys = <String>{};
    for (var index = 0; index < assignedCodes.length; index++) {
      final code = assignedCodes[index];
      final categoria = harvardMap[code];
      final displayName =
          index < assignedNames.length && assignedNames[index].trim().isNotEmpty
              ? assignedNames[index].trim()
              : categoria?.nombre ??
                  ((code == alimento.harvardCategoria
                          ? alimento.harvardNombre
                          : null) ??
                      code);
      final uniqueKey =
          '${code.trim().toLowerCase()}|${displayName.trim().toLowerCase()}';
      if (!seenKeys.add(uniqueKey)) {
        continue;
      }
      final color =
          _parsePdfColor(categoria?.colorHex ?? alimento.harvardColor) ??
              PdfColors.grey500;

      badges.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(right: 4, bottom: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: pw.BoxDecoration(
            color: _mixWithWhite(color, 0.82),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            border:
                pw.Border.all(color: _mixWithWhite(color, 0.35), width: 0.5),
          ),
          child: pw.Text(
            displayName,
            style: pw.TextStyle(
              fontSize: 7.2,
              color: color,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.centerLeft,
      child: pw.Wrap(children: badges),
    );
  }

  static String _categoriasLabel(Alimento alimento) {
    if (alimento.nombreGrupos.isNotEmpty) {
      return alimento.nombreGrupos.join(', ');
    }
    final legacy = (alimento.nombreGrupo ?? '').trim();
    return legacy.isEmpty ? '-' : legacy;
  }

  static Future<pw.ThemeData> _buildPdfTheme() async {
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();
    final boldItalic = await PdfGoogleFonts.notoSansBoldItalic();
    final fallbacks = <pw.Font>[];

    for (final assetPath in _emojiAssetFallbackPaths) {
      try {
        final data = await rootBundle.load(assetPath);
        fallbacks.add(
          pw.Font.ttf(
            data.buffer.asByteData(data.offsetInBytes, data.lengthInBytes),
          ),
        );
      } catch (_) {
        // Continue generating the PDF even if one emoji asset cannot be loaded.
      }
    }

    try {
      fallbacks.add(await PdfGoogleFonts.notoEmojiRegular());
    } catch (_) {
      // Asset fallback is the primary source for emoji glyphs.
    }

    try {
      fallbacks.add(await PdfGoogleFonts.notoColorEmojiRegular());
    } catch (_) {
      // Color emoji is optional; monochrome fallback from assets is sufficient.
    }

    return pw.ThemeData.withFont(
      base: base,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
      fontFallback: List<pw.Font>.unmodifiable(fallbacks),
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

  static PdfColor _mixWithWhite(PdfColor color, double ratio) {
    final clamped = ratio.clamp(0.0, 1.0);
    final inverse = 1 - clamped;
    return PdfColor(
      color.red * inverse + clamped,
      color.green * inverse + clamped,
      color.blue * inverse + clamped,
    );
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
