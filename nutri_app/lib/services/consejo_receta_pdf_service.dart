import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:nutri_app/services/api_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ConsejoRecetaPdfService {
  const ConsejoRecetaPdfService._();

  static const PdfColor _accentPink = PdfColor.fromInt(0xFFFFC0F4);
  static final RegExp _imageTokenRegex = RegExp(r'\[\[img:(\d+)\]\]');
  static final RegExp _nonPdfTokenRegex =
      RegExp(r'\[\[(documento|enlace):(\d+)\]\]');
  static pw.Font? _cachedEmojiFont;

  static Future<void> generatePdf({
    required BuildContext context,
    required ApiService apiService,
    required String titulo,
    required String contenido,
    required String tipo, // 'consejo' o 'receta'
    String? imagenPortadaBase64,
    Map<int, String>? imagenesInlineById,
    String? fileName,
    String? subtitulo,
    String? alimentoOrigen,
    String? sustitutoPrincipal,
    String? equivalenciaTexto,
    String? objetivoMacro,
    bool preserveEmojis = false,
    bool isAditivosList = false,
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
          final decodedLogo = _decodeBase64Image(logoBase64);
          if (decodedLogo != null) {
            logoBytes = decodedLogo;
            logoSizeStr = logoSizeParam;
          }
        }
      }

      // Obtener color de fondo del encabezado y pie
      final colorParam =
          await apiService.getParametro('color_fondo_banda_encabezado_pie_pdf');
      final accentColorStr = colorParam?['valor']?.toString() ?? '';
      final accentColor = _parsePdfColor(accentColorStr) ?? _accentPink;

      // Obtener información de contacto
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

      final tituloTipo = tipo == 'receta'
          ? 'RECETA'
          : (tipo == 'sustitucion'
              ? 'SUSTITUCIÓN SALUDABLE'
              : (tipo == 'suplemento'
                  ? 'SUPLEMENTO'
                  : (tipo == 'aditivo'
                      ? (isAditivosList
                          ? 'ADITIVOS ALIMENTARIOS'
                          : 'ADITIVO ALIMENTARIO')
                      : 'CONSEJO')));

      final contenidoProcesado = preserveEmojis
          ? contenido.replaceAll('\r\n', '\n').trim()
          : _removeEmojisKeepingPointers(contenido);
      final tituloProcesado = preserveEmojis ? titulo : _removeEmojis(titulo);
      final subtituloProcesado =
          preserveEmojis ? (subtitulo ?? '') : _removeEmojis(subtitulo ?? '');
      final portadaImage = _decodePdfImage(imagenPortadaBase64);

      final logoSize = _parseLogoSize(logoSizeStr);

      final emojiFont = preserveEmojis ? await _loadEmojiFont() : null;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 16, 24, 24),
          theme: (emojiFont != null)
              ? pw.ThemeData.withFont(fontFallback: [emojiFont])
              : null,
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
          build: (context) {
            final contentWidgets = <pw.Widget>[
              pw.Center(
                child: pw.Text(
                  tituloProcesado,
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (subtituloProcesado.trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    subtituloProcesado.trim(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
              pw.SizedBox(height: 12),
              if (portadaImage != null) ...[
                pw.Center(
                  child: pw.Container(
                    width: double.infinity,
                    height: 190,
                    child: pw.Image(
                      portadaImage,
                      fit: pw.BoxFit.contain,
                      alignment: pw.Alignment.center,
                    ),
                  ),
                ),
                pw.SizedBox(height: 14),
              ],
            ];

            if (tipo == 'sustitucion') {
              contentWidgets.addAll(
                _buildSustitucionContent(
                  contenido: contenidoProcesado,
                  alimentoOrigen: alimentoOrigen ?? '',
                  sustitutoPrincipal: sustitutoPrincipal ?? '',
                  equivalenciaTexto: equivalenciaTexto ?? '',
                  objetivoMacro: objetivoMacro ?? '',
                ),
              );
            } else if (isAditivosList && tipo == 'aditivo') {
              contentWidgets.addAll(
                _buildAditivosListContent(
                  contenidoProcesado,
                  imagenesInlineById: imagenesInlineById,
                ),
              );
            } else {
              contentWidgets.addAll(
                _buildFlowingContent(
                  contenidoProcesado,
                  imagenesInlineById: imagenesInlineById,
                ),
              );
            }

            contentWidgets.addAll([
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.Container(
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
              ),
            ]);

            return contentWidgets;
          },
        ),
      );

      final bytes = await pdf.save();
      final safeFileName =
          tituloProcesado.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');
      final baseFileName = (fileName != null && fileName.trim().isNotEmpty)
          ? fileName.trim()
          : '${tipo}_${safeFileName.toLowerCase()}';
      final resolvedFileName = baseFileName.toLowerCase().endsWith('.pdf')
          ? baseFileName
          : '$baseFileName.pdf';

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

  static Future<pw.Font?> _loadEmojiFont() async {
    if (_cachedEmojiFont != null) return _cachedEmojiFont;
    try {
      final data = await rootBundle.load('assets/fonts/NotoEmoji-Regular.ttf');
      _cachedEmojiFont = pw.Font.ttf(data.buffer.asByteData());
      return _cachedEmojiFont;
    } catch (_) {
      return null;
    }
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

  static String _removeEmojisKeepingPointers(String text) {
    const openToken = '__POINTER_OPEN__';
    const closeToken = '__POINTER_CLOSE__';
    final protectedText =
        text.replaceAll('👉', openToken).replaceAll('👈', closeToken);
    return _removeEmojis(protectedText)
        .replaceAll(openToken, '👉')
        .replaceAll(closeToken, '👈');
  }

  static List<pw.Widget> _buildSustitucionContent({
    required String contenido,
    required String alimentoOrigen,
    required String sustitutoPrincipal,
    required String equivalenciaTexto,
    required String objetivoMacro,
  }) {
    final widgets = <pw.Widget>[];

    widgets.add(
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#E8F5E9'),
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: PdfColor.fromHex('#C8E6C9')),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Cambio recomendado',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _buildSustitucionDetailRow('Si no tienes', alimentoOrigen),
            pw.SizedBox(height: 6),
            _buildSustitucionDetailRow('Usa', sustitutoPrincipal),
            if (equivalenciaTexto.trim().isNotEmpty) ...[
              pw.SizedBox(height: 6),
              _buildSustitucionDetailRow('Equivalencia', equivalenciaTexto),
            ],
            if (objetivoMacro.trim().isNotEmpty) ...[
              pw.SizedBox(height: 6),
              _buildSustitucionDetailRow('Objetivo', objetivoMacro),
            ],
          ],
        ),
      ),
    );

    final notas = contenido.trim();
    if (notas.isNotEmpty) {
      widgets.addAll([
        pw.SizedBox(height: 14),
        pw.Text(
          'Notas y contexto',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
      ]);
      widgets.addAll(_buildEnhancedContextParagraphWidgets(notas));
    }

    return widgets;
  }

  static pw.Widget _buildSustitucionDetailRow(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(
            text: value.trim().isEmpty ? '-' : value.trim(),
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildAditivosListContent(
    String text, {
    Map<int, String>? imagenesInlineById,
  }) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    final items = normalized.split(RegExp(r'\n{2,}---\n{2,}'));

    final widgets = <pw.Widget>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i].trim();
      if (item.isEmpty) continue;

      // Separar líneas
      final lines = item.split('\n');
      if (lines.isEmpty) continue;

      // Primera línea es el nombre del aditivo
      final nombre = lines[0].trim();
      String tipo = '';
      String peligrosidad = '';
      final descripcionLines = <String>[];

      // Procesar líneas restantes
      for (var j = 1; j < lines.length; j++) {
        final line = lines[j].trim();
        if (line.startsWith('Tipo:')) {
          tipo = line.replaceFirst('Tipo:', '').trim();
        } else if (line.startsWith('Peligrosidad:')) {
          peligrosidad = line.replaceFirst('Peligrosidad:', '').trim();
        } else if (line.isNotEmpty) {
          descripcionLines.add(line);
        }
      }

      final descripcion = descripcionLines.join('\n');

      // Agregar nombre en negrita y más grande
      widgets.add(
        pw.Text(
          nombre,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      );

      // Agregar tipo y peligrosidad
      if (tipo.isNotEmpty || peligrosidad.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 4));
        final metaLines = <String>[];
        if (tipo.isNotEmpty) metaLines.add('Tipo: $tipo');
        if (peligrosidad.isNotEmpty)
          metaLines.add('Peligrosidad: $peligrosidad');

        widgets.add(
          pw.Text(
            metaLines.join(' • '),
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
        );
      }

      // Agregar descripción
      if (descripcion.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        widgets.addAll(_buildEnhancedContextParagraphWidgets(descripcion));
      }

      // Separador entre aditivos
      if (i < items.length - 1) {
        widgets.add(pw.SizedBox(height: 12));
        widgets.add(
          pw.Divider(
            color: PdfColors.grey300,
            thickness: 0.5,
          ),
        );
        widgets.add(pw.SizedBox(height: 8));
      }
    }

    return widgets.isEmpty ? [pw.Text('')] : widgets;
  }

  static List<pw.Widget> _buildEnhancedContextParagraphWidgets(String text) {
    final normalized = _normalizeContextForVisualSections(text)
        .replaceAll('\r\n', '\n')
        .trim();
    if (normalized.isEmpty) return [];

    final paragraphs = normalized
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final widgets = <pw.Widget>[];
    final markerOnlyRegex = RegExp(r'^👉\s*([^👈]+?)\s*👈$');
    final tokenRegex = RegExp(
      r'(👉\s*[^👈]+?\s*👈|#[\wáéíóúÁÉÍÓÚñÑüÜ]+)',
      caseSensitive: false,
    );

    for (var i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];
      final markerOnlyMatch = markerOnlyRegex.firstMatch(paragraph);

      if (markerOnlyMatch != null) {
        final titleText = (markerOnlyMatch.group(1) ?? '').trim();
        widgets.add(
          pw.Text(
            titleText,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        );
      } else {
        final spans = <pw.InlineSpan>[];
        var cursor = 0;
        for (final match in tokenRegex.allMatches(paragraph)) {
          if (match.start > cursor) {
            spans.add(
              pw.TextSpan(
                text: paragraph.substring(cursor, match.start),
                style: const pw.TextStyle(fontSize: 11, height: 1.5),
              ),
            );
          }
          final token = match.group(0) ?? '';
          if (token.startsWith('👉') && token.endsWith('👈')) {
            final heading =
                token.replaceAll('👉', '').replaceAll('👈', '').trim();
            spans.add(
              pw.TextSpan(
                text: heading,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          } else {
            spans.add(
              pw.TextSpan(
                text: token,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            );
          }
          cursor = match.end;
        }

        if (cursor < paragraph.length) {
          spans.add(
            pw.TextSpan(
              text: paragraph.substring(cursor),
              style: const pw.TextStyle(fontSize: 11, height: 1.5),
            ),
          );
        }

        widgets.add(
          pw.RichText(
            text: pw.TextSpan(children: spans),
            textAlign: pw.TextAlign.justify,
          ),
        );
      }

      if (i < paragraphs.length - 1) {
        widgets.add(pw.SizedBox(height: 10));
      }
    }

    return widgets;
  }

  static String _normalizeContextForVisualSections(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final output = <String>[];
    final sectionLineRegex = RegExp(r'(^\s*👉\s*[^👈]+\s*👈\s*$)|(^\s*#)');

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();
      final isSectionLine =
          trimmed.isNotEmpty && sectionLineRegex.hasMatch(trimmed);

      if (isSectionLine && output.isNotEmpty && output.last.trim().isNotEmpty) {
        output.add('');
      }

      output.add(line);
    }

    return output.join('\n').trim();
  }

  static List<pw.Widget> _buildFlowingContent(
    String text, {
    Map<int, String>? imagenesInlineById,
  }) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    final normalizedWithoutDocumentTokens =
        normalized.replaceAll(_nonPdfTokenRegex, '').trim();

    if (normalizedWithoutDocumentTokens.isEmpty) {
      return [
        pw.Text(
          '',
          style: const pw.TextStyle(fontSize: 11, height: 1.5),
        ),
      ];
    }

    final imageMap = imagenesInlineById ?? const <int, String>{};
    if (imageMap.isEmpty ||
        !_imageTokenRegex.hasMatch(normalizedWithoutDocumentTokens)) {
      return _buildEnhancedContextParagraphWidgets(
          normalizedWithoutDocumentTokens);
    }

    final widgets = <pw.Widget>[];
    int cursor = 0;

    for (final match
        in _imageTokenRegex.allMatches(normalizedWithoutDocumentTokens)) {
      if (match.start > cursor) {
        final textChunk =
            normalizedWithoutDocumentTokens.substring(cursor, match.start);
        widgets.addAll(_buildEnhancedContextParagraphWidgets(textChunk));
      }

      final imageId = int.tryParse(match.group(1) ?? '');
      final base64Image = imageId != null ? imageMap[imageId] : null;
      final image = _decodePdfImage(base64Image);

      if (image != null) {
        widgets.add(
          pw.Center(
            child: pw.Container(
              width: double.infinity,
              constraints: const pw.BoxConstraints(maxHeight: 220),
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
                alignment: pw.Alignment.center,
              ),
            ),
          ),
        );
      }
      // Si la imagen no se encontró en el mapa, se omite silenciosamente.

      widgets.add(pw.SizedBox(height: 8));
      cursor = match.end;
    }

    if (cursor < normalizedWithoutDocumentTokens.length) {
      widgets.addAll(
        _buildEnhancedContextParagraphWidgets(
            normalizedWithoutDocumentTokens.substring(cursor)),
      );
    }

    return widgets;
  }

  static List<pw.Widget> _buildParagraphWidgets(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return [];

    final paragraphs = normalized
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final widgets = <pw.Widget>[];
    for (var paragraphIndex = 0;
        paragraphIndex < paragraphs.length;
        paragraphIndex++) {
      final paragraph = paragraphs[paragraphIndex];
      final chunks = _chunkText(paragraph, 700);
      for (final chunk in chunks) {
        widgets.add(
          pw.Text(
            chunk,
            style: const pw.TextStyle(fontSize: 11, height: 1.5),
            textAlign: pw.TextAlign.justify,
          ),
        );
      }
      if (paragraphIndex < paragraphs.length - 1) {
        widgets.add(pw.SizedBox(height: 8));
      }
    }

    return widgets;
  }

  static List<String> _chunkText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];
    final chunks = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = (start + maxLen < text.length) ? start + maxLen : text.length;
      if (end < text.length) {
        final lastSpace = text.lastIndexOf(' ', end);
        if (lastSpace > start + 40) {
          end = lastSpace;
        }
      }
      final part = text.substring(start, end).trim();
      if (part.isNotEmpty) {
        chunks.add(part);
      }
      start = end;
    }
    return chunks;
  }

  static pw.MemoryImage? _decodePdfImage(String? base64Image) {
    if (base64Image == null || base64Image.trim().isEmpty) return null;
    try {
      final bytes = _decodeBase64Image(base64Image);
      if (bytes == null || bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _decodeBase64Image(String base64String) {
    var data = base64String.trim();
    if (data.isEmpty) return null;

    const marker = 'base64,';
    final markerIndex = data.indexOf(marker);
    if (markerIndex >= 0) {
      data = data.substring(markerIndex + marker.length);
    } else if (data.contains(',')) {
      data = data.split(',').last.trim();
    }

    while (data.length % 4 != 0) {
      data += '=';
    }

    try {
      final bytes = base64Decode(data);
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
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
