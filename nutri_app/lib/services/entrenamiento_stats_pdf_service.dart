import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
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
  static final NumberFormat _integerFormat =
      NumberFormat.decimalPattern('es_ES');
  static pw.Font? _cachedEmojiFont;

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
      final logoSize = _parseLogoSize(logoSizeStr);
      final accentColor = _parsePdfColor(accentColorStr) ?? _accentPink;
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
            _formatInteger(resumen.totalActividades),
            _formatMax2Decimals(resumen.promedioActividades),
          ),
          row(
            'Kilómetros',
            _formatNumber(resumen.totalKilometros, decimals: 2),
            _formatMax2Decimals(resumen.promedioKilometros),
          ),
          row(
            'Subida (m)',
            _formatNumber(resumen.totalDesnivel, decimals: 0),
            _formatMax2Decimals(resumen.promedioDesnivel),
          ),
          row(
            'Tiempo',
            _formatDuration(resumen.totalMinutos),
            _formatDuration(resumen.promedioMinutos.round()),
          ),
          row(
            'Peso (kg)',
            _formatNumber(resumen.totalPesoKg, decimals: 1),
            _formatMax2Decimals(resumen.promedioPesoKg),
          ),
          row(
            'Ejercicios',
            _formatInteger(resumen.totalEjercicios),
            _formatMax2Decimals(resumen.promedioEjercicios),
          ),
        ],
      ),
    );
  }

  static String _formatMax2Decimals(double value) {
    final formatted = NumberFormat.decimalPatternDigits(
      locale: 'es_ES',
      decimalDigits: 2,
    ).format(value);
    return formatted
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'[,\.]$'), '');
  }

  static String _formatInteger(num value) {
    return _integerFormat.format(value);
  }

  static String _formatNumber(num value, {required int decimals}) {
    return NumberFormat.decimalPatternDigits(
      locale: 'es_ES',
      decimalDigits: decimals,
    ).format(value);
  }

  static String _formatDuration(int totalMinutes) {
    final safeMinutes = totalMinutes < 0 ? 0 : totalMinutes;
    final days = safeMinutes ~/ (24 * 60);
    final remainingAfterDays = safeMinutes % (24 * 60);
    final hours = remainingAfterDays ~/ 60;
    final minutes = remainingAfterDays % 60;

    if (days > 0) {
      return '${_formatInteger(days)}d ${_formatInteger(hours)}h ${_formatInteger(minutes)}m';
    }
    if (hours > 0) {
      return '${_formatInteger(hours)}h ${_formatInteger(minutes)}m';
    }
    return '${_formatInteger(minutes)}m';
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
}
