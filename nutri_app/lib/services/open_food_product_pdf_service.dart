import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class OpenFoodProductPdfData {
  const OpenFoodProductPdfData({
    required this.nombre,
    required this.marca,
    required this.barcode,
    required this.quantity,
    required this.servingSize,
    required this.nutriScore,
    required this.novaGroup,
    required this.ingredientes,
    required this.labels,
    required this.categories,
    required this.countries,
    required this.allergens,
    required this.traces,
    required this.additives,
    required this.nutriments,
    required this.rawData,
    required this.fuenteLectura,
  });

  final String nombre;
  final String marca;
  final String barcode;
  final String quantity;
  final String? servingSize;
  final String nutriScore;
  final int? novaGroup;
  final String ingredientes;
  final List<String> labels;
  final List<String> categories;
  final List<String> countries;
  final List<String> allergens;
  final List<String> traces;
  final List<String> additives;
  final Map<String, dynamic> nutriments;
  final Map<String, dynamic> rawData;
  final String fuenteLectura;
}

class OpenFoodProductPdfService {
  const OpenFoodProductPdfService._();

  static const PdfColor _accentPink = PdfColor.fromInt(0xFFFFC0F4);
  static const PdfColor _softPink = PdfColor.fromInt(0xFFFFE6F7);

  static Future<void> generateProductPdf({
    required BuildContext context,
    required ApiService apiService,
    required OpenFoodProductPdfData product,
  }) async {
    try {
      final nutricionistaParam =
          await apiService.getParametro('nutricionista_nombre');
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      Uint8List? logoBytes;
      String logoSizeStr = '';
      final logoParam =
          await apiService.getParametro('logotipo_dietista_documentos');
      if (logoParam != null) {
        final logoBase64 = logoParam['valor']?.toString();
        logoSizeStr = logoParam['valor2']?.toString() ?? '';
        if (logoBase64 != null && logoBase64.trim().isNotEmpty) {
          logoBytes = _decodeBase64Image(logoBase64);
        }
      }

      final colorParam =
          await apiService.getParametro('color_fondo_banda_encabezado_pie_pdf');
      final accentColorStr = colorParam?['valor']?.toString() ?? '';
      final accentColor = _parsePdfColor(accentColorStr) ?? _accentPink;

      final safeNutriments = _sanitizeNutriments(product.nutriments);
      final safeRawData = _sanitizeRawData(product.rawData);

      final pdf = pw.Document();
      final logoSize = _parseLogoSize(logoSizeStr);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 16, 24, 24),
          header: (ctx) => _buildHeader(
            nutricionistaNombre: nutricionistaNombre,
            nutricionistaSubtitulo: nutricionistaSubtitulo,
            logoBytes: logoBytes,
            logoSize: logoSize,
            tituloTexto: product.nombre,
            pageNumber: ctx.pageNumber,
            accentColor: accentColor,
          ),
          footer: (ctx) => _buildFooter(
            nutricionistaNombre: nutricionistaNombre,
            pageNumber: ctx.pageNumber,
            pageCount: ctx.pagesCount,
            accentColor: accentColor,
            tituloTexto: 'Ficha producto',
          ),
          build: (_) => [
            _buildTopInfo(product, accentColor),
            pw.SizedBox(height: 10),
            _buildScores(product),
            pw.SizedBox(height: 10),
            _buildNutritionTable(safeNutriments),
            pw.SizedBox(height: 10),
            _buildIngredients(product.ingredientes),
            pw.SizedBox(height: 8),
            _buildMetaLists(product),
            pw.SizedBox(height: 8),
            _buildRawData(safeRawData),
          ],
        ),
      );

      final bytes = await pdf.save();
      final safeName = product.nombre
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]+'), '')
          .replaceAll(' ', '_');
      final fileName =
          'Producto_${safeName.isEmpty ? 'OpenFood' : safeName}.pdf';
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
              child: pw.Text('$pageNumber/$pageCount', style: footerStyle),
            ),
          ),
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(tituloTexto, style: footerStyle),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTopInfo(
      OpenFoodProductPdfData product, PdfColor accentColor) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _softPink,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Marca: ${_fallback(product.marca)}'),
          pw.Text('Código de barras: ${_fallback(product.barcode)}'),
          pw.Text('Formato: ${_fallback(product.quantity)}'),
          pw.Text('Porción: ${_fallback(product.servingSize)}'),
          pw.Text('Fuente: ${_fallback(product.fuenteLectura)}'),
        ],
      ),
    );
  }

  static pw.Widget _buildScores(OpenFoodProductPdfData product) {
    PdfColor nutriColor(String grade) {
      switch (grade.toLowerCase()) {
        case 'a':
          return PdfColors.green;
        case 'b':
          return PdfColors.lightGreen;
        case 'c':
          return PdfColors.amber;
        case 'd':
          return PdfColors.orange;
        case 'e':
          return PdfColors.red;
        default:
          return PdfColors.grey;
      }
    }

    PdfColor novaColor(int? group) {
      switch (group) {
        case 1:
          return PdfColors.green;
        case 2:
          return PdfColors.lightGreen;
        case 3:
          return PdfColors.amber;
        case 4:
          return PdfColors.red;
        default:
          return PdfColors.grey;
      }
    }

    return pw.Row(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: nutriColor(product.nutriScore)),
          ),
          child: pw.Text(
            'Nutri-Score ${_fallback(product.nutriScore).toUpperCase()}',
            style: pw.TextStyle(
              color: nutriColor(product.nutriScore),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: novaColor(product.novaGroup)),
          ),
          child: pw.Text(
            'NOVA ${product.novaGroup?.toString() ?? '-'}',
            style: pw.TextStyle(
              color: novaColor(product.novaGroup),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildNutritionTable(Map<String, dynamic> nutriments) {
    final entries = nutriments.entries
        .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));

    final visibleEntries = entries.take(70).toList(growable: false);

    if (visibleEntries.isEmpty) {
      return pw.Text('No hay datos nutricionales adicionales.');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Datos nutricionales (Open Food Facts)',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(3),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _softPink),
              children: [
                _cell('Nutriente', bold: true),
                _cell('Valor', bold: true),
              ],
            ),
            ...visibleEntries.map(
              (e) => pw.TableRow(
                children: [
                  _cell(_normalizeKey(e.key)),
                  _cell(_truncate(e.value.toString(), 120)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildIngredients(String ingredientes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Ingredientes',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(_fallback(ingredientes)),
      ],
    );
  }

  static pw.Widget _buildMetaLists(OpenFoodProductPdfData product) {
    String joinList(List<String> values) =>
        values.isEmpty ? '-' : values.take(20).join(', ');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Datos complementarios',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Etiquetas: ${joinList(product.labels)}'),
        pw.Text('Categorías: ${joinList(product.categories)}'),
        pw.Text('Países: ${joinList(product.countries)}'),
        pw.Text('Alérgenos: ${joinList(product.allergens)}'),
        pw.Text('Trazas: ${joinList(product.traces)}'),
        pw.Text('Aditivos: ${joinList(product.additives)}'),
      ],
    );
  }

  static pw.Widget _buildRawData(Map<String, dynamic> rawData) {
    final rows = rawData.entries
        .where((e) =>
            e.key != 'nutriments' &&
            (e.value is String || e.value is num || e.value is bool))
        .toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));

    if (rows.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Datos raw relevantes',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        ...rows.take(40).map(
              (e) => pw.Text('${e.key}: ${_truncate(e.value.toString(), 180)}'),
            ),
      ],
    );
  }

  static Map<String, dynamic> _sanitizeNutriments(
      Map<String, dynamic> nutriments) {
    final result = <String, dynamic>{};

    final preferredKeys = <String>{
      'energy-kcal_serving',
      'energy-kcal_100g',
      'fat_serving',
      'fat_100g',
      'saturated-fat_serving',
      'saturated-fat_100g',
      'carbohydrates_serving',
      'carbohydrates_100g',
      'sugars_serving',
      'sugars_100g',
      'fiber_serving',
      'fiber_100g',
      'proteins_serving',
      'proteins_100g',
      'salt_serving',
      'salt_100g',
      'sodium_serving',
      'sodium_100g',
    };

    for (final key in preferredKeys) {
      final value = nutriments[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      result[key] = _truncate(text, 80);
    }

    if (result.length < 24) {
      final fallback = nutriments.entries.where((e) {
        final value = e.value;
        if (value == null) return false;
        if (value is! String && value is! num && value is! bool) {
          return false;
        }
        return value.toString().trim().isNotEmpty;
      }).take(24 - result.length);

      for (final entry in fallback) {
        result.putIfAbsent(
            entry.key, () => _truncate(entry.value.toString(), 80));
      }
    }

    return result;
  }

  static Map<String, dynamic> _sanitizeRawData(Map<String, dynamic> rawData) {
    const preferredRawKeys = <String>{
      'product_name',
      'brands',
      'code',
      'quantity',
      'serving_size',
      'nutriscore_grade',
      'nova_group',
      'ingredients_text',
      'ingredients_text_es',
      'categories',
      'labels',
      'countries',
      'allergens',
      'traces',
      'additives_n',
      'additives_tags',
      'pnns_groups_1',
      'pnns_groups_2',
    };

    final result = <String, dynamic>{};

    for (final key in preferredRawKeys) {
      if (!rawData.containsKey(key)) continue;
      final value = rawData[key];
      if (value == null) continue;
      if (value is String || value is num || value is bool) {
        final text = value.toString().trim();
        if (text.isEmpty) continue;
        result[key] = _truncate(text, 260);
      }
    }

    if (result.length < 30) {
      for (final entry in rawData.entries) {
        if (result.length >= 30) break;
        final value = entry.value;
        if (value == null) continue;
        if (value is! String && value is! num && value is! bool) continue;
        final text = value.toString().trim();
        if (text.isEmpty) continue;
        result.putIfAbsent(entry.key, () => _truncate(text, 260));
      }
    }

    return result;
  }

  static String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _normalizeKey(String key) {
    return key
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join(' ');
  }

  static String _fallback(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? '-' : text;
  }

  static PdfPoint? _parseLogoSize(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;

    final normalized = value.toLowerCase().replaceAll('x', ',');
    final parts = normalized.split(',').map((e) => e.trim()).toList();
    if (parts.length < 2) return null;

    final width = double.tryParse(parts[0]);
    final height = double.tryParse(parts[1]);
    if (width == null || height == null) return null;
    if (width <= 0 || height <= 0) return null;

    return PdfPoint(width, height);
  }

  static PdfColor? _parsePdfColor(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return null;
    }

    final normalized = value.startsWith('#') ? value.substring(1) : value;
    if (normalized.length == 6) {
      final intValue = int.tryParse('FF$normalized', radix: 16);
      if (intValue != null) {
        return PdfColor.fromInt(intValue);
      }
    } else if (normalized.length == 8) {
      final intValue = int.tryParse(normalized, radix: 16);
      if (intValue != null) {
        return PdfColor.fromInt(intValue);
      }
    }

    return null;
  }

  static Uint8List? _decodeBase64Image(String base64String) {
    var data = base64String.trim();
    if (data.isEmpty) {
      return null;
    }
    const marker = 'base64,';
    final markerIndex = data.indexOf(marker);
    if (markerIndex >= 0) {
      data = data.substring(markerIndex + marker.length);
    }

    try {
      return Uint8List.fromList(base64Decode(data));
    } catch (_) {
      return null;
    }
  }
}
