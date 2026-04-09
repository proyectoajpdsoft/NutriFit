import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class TrainingProgressPdfService {
  const TrainingProgressPdfService._();

  static const PdfColor _accentBlue = PdfColor.fromInt(0xFF1565C0);
  static pw.Font? _cachedEmojiFont;

  static Uint8List? decodeBase64Image(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    try {
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  static Future<void> generateProgressPdf({
    required BuildContext context,
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    Uint8List? logoBytes,
    required String logoSizeStr,
    required String accentColorStr,
    required String title,
    required String periodLabel,
    required Uint8List chartImageBytes,
    required List<String> headers,
    required List<List<String>> rows,
    List<int>? rowAccentColorValues,
    required String nutricionistaEmail,
    required String nutricionistaTelegram,
    required String nutricionistaWebUrl,
    required String nutricionistaWebLabel,
    required String nutricionistaInstagramUrl,
    required String nutricionistaInstagramLabel,
    required String nutricionistaFacebookUrl,
    required String nutricionistaFacebookLabel,
  }) async {
    try {
      final accentColor = _parsePdfColor(accentColorStr) ?? _accentBlue;
      final logoSize = _parseLogoSize(logoSizeStr);
      final emojiFont = await _loadEmojiFont();

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 16, 24, 24),
          theme: emojiFont != null
              ? pw.ThemeData.withFont(fontFallback: [emojiFont])
              : null,
          header: (ctx) => _buildHeader(
            nutricionistaNombre: nutricionistaNombre,
            nutricionistaSubtitulo: nutricionistaSubtitulo,
            logoBytes: logoBytes,
            logoSize: logoSize,
            tituloTexto: title,
            pageNumber: ctx.pageNumber,
            accentColor: accentColor,
          ),
          footer: (ctx) => _buildFooter(
            nutricionistaNombre: nutricionistaNombre,
            pageNumber: ctx.pageNumber,
            pageCount: ctx.pagesCount,
            accentColor: accentColor,
            tituloTexto: title,
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
                    'Período: $periodLabel',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
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
              'Resumen de evolución',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _buildSummaryTable(
              headers: headers,
              rows: rows,
              headerColor: accentColor,
              rowAccentColorValues: rowAccentColorValues,
            ),
            pw.SizedBox(height: 12),
            pw.Divider(),
            _buildContactTable(
              accentColor: accentColor,
              nutricionistaEmail: nutricionistaEmail,
              nutricionistaTelegram: nutricionistaTelegram,
              nutricionistaWebUrl: nutricionistaWebUrl,
              nutricionistaWebLabel: nutricionistaWebLabel,
              nutricionistaInstagramUrl: nutricionistaInstagramUrl,
              nutricionistaInstagramLabel: nutricionistaInstagramLabel,
              nutricionistaFacebookUrl: nutricionistaFacebookUrl,
              nutricionistaFacebookLabel: nutricionistaFacebookLabel,
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = title
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final fileName =
          '${safeTitle.isEmpty ? 'Evolucion' : safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF guardado: $fileName'),
          backgroundColor: Colors.green,
        ),
      );

      await OpenFilex.open(filePath);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static pw.Widget _buildGraphSection(Uint8List chartImageBytes) {
    return pw.Container(
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
    );
  }

  static pw.Widget _buildSummaryTable({
    required List<String> headers,
    required List<List<String>> rows,
    required PdfColor headerColor,
    List<int>? rowAccentColorValues,
  }) {
    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: headerColor),
        children: headers
            .map(
              (header) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  header,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 9,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ];

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final accent =
          rowAccentColorValues != null && index < rowAccentColorValues.length
              ? PdfColor.fromInt(rowAccentColorValues[index])
              : null;
      final background = accent == null
          ? null
          : PdfColor(
              0.94 + (accent.red * 0.06),
              0.94 + (accent.green * 0.06),
              0.94 + (accent.blue * 0.06),
            );

      tableRows.add(
        pw.TableRow(
          decoration:
              background == null ? null : pw.BoxDecoration(color: background),
          children: row.asMap().entries.map((entry) {
            final isTrendCell = entry.key == 0 && accent != null;
            return pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                entry.value,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight:
                      isTrendCell ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: isTrendCell ? accent : PdfColors.black,
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: tableRows,
    );
  }

  static pw.Widget _buildHeader({
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    required Uint8List? logoBytes,
    required double logoSize,
    required String tituloTexto,
    required int pageNumber,
    required PdfColor accentColor,
  }) {
    final resolvedLogoWidth = logoSize <= 0 ? 42.0 : logoSize;
    final resolvedLogoHeight = (logoSize * 0.714).clamp(24.0, 60.0);
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
                  width: resolvedLogoWidth,
                  height: resolvedLogoHeight,
                  alignment: pw.Alignment.centerRight,
                  child: pw.Image(
                    pw.MemoryImage(logoBytes),
                    fit: pw.BoxFit.contain,
                  ),
                )
              else
                pw.SizedBox(
                  width: resolvedLogoWidth,
                  height: resolvedLogoHeight,
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

  static pw.Widget _buildContactTable({
    required PdfColor accentColor,
    required String nutricionistaEmail,
    required String nutricionistaTelegram,
    required String nutricionistaWebUrl,
    required String nutricionistaWebLabel,
    required String nutricionistaInstagramUrl,
    required String nutricionistaInstagramLabel,
    required String nutricionistaFacebookUrl,
    required String nutricionistaFacebookLabel,
  }) {
    return pw.Container(
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
    );
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
          pw.Text(
            value.isNotEmpty ? value : '-',
            style: const pw.TextStyle(fontSize: 9),
          ),
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
              child: pw.Text(
                displayText,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue),
              ),
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

  static PdfColor? _parsePdfColor(String input) {
    final hex = input.trim().replaceAll('#', '');
    if (hex.isEmpty) return null;
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    final value = int.tryParse(normalized, radix: 16);
    if (value == null) return null;
    return PdfColor.fromInt(value);
  }

  static double _parseLogoSize(String value) {
    final size = double.tryParse(value.trim().replaceAll(',', '.'));
    if (size == null || size <= 0) {
      return 48;
    }
    return size.clamp(24, 96).toDouble();
  }

  static Future<pw.Font?> _loadEmojiFont() async {
    if (_cachedEmojiFont != null) {
      return _cachedEmojiFont;
    }
    try {
      final data = await rootBundle.load('assets/fonts/NotoEmoji-Regular.ttf');
      _cachedEmojiFont = pw.Font.ttf(data.buffer.asByteData());
      return _cachedEmojiFont;
    } catch (_) {
      return null;
    }
  }

  static String _formatNow(DateTime dateTime) {
    final two = (int value) => value.toString().padLeft(2, '0');
    return '${two(dateTime.day)}/${two(dateTime.month)}/${dateTime.year} ${two(dateTime.hour)}:${two(dateTime.minute)}';
  }
}
