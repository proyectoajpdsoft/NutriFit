import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/plan_nutri_estructura.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/plan_nutri_pdf_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ─── Private helper ──────────────────────────────────────────────────────────

class _WordRecetaData {
  final String titulo;
  final String texto;
  final int orden;

  const _WordRecetaData({
    required this.titulo,
    required this.texto,
    required this.orden,
  });
}

// ─── Service ──────────────────────────────────────────────────────────────────

class PlanNutriWordService {
  const PlanNutriWordService._();

  static const List<String> _diasOrder = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static const List<String> _ingestaOrder = [
    'Desayuno',
    'Almuerzo',
    'Comida',
    'Merienda',
    'Cena',
  ];

  static const Map<String, String> _diaAbrev = {
    'Lunes': 'Lun.',
    'Martes': 'Mar.',
    'Miércoles': 'Mié.',
    'Jueves': 'Jue.',
    'Viernes': 'Vie.',
    'Sábado': 'Sáb.',
    'Domingo': 'Dom.',
  };

  static List<PlanNutriSemana> _sortedWeeks(List<PlanNutriSemana> semanas) {
    final sorted = [...semanas];
    sorted.sort((a, b) {
      final ordenA = a.orden > 0
          ? a.orden
          : (a.numeroSemana > 0 ? a.numeroSemana : 999999);
      final ordenB = b.orden > 0
          ? b.orden
          : (b.numeroSemana > 0 ? b.numeroSemana : 999999);
      final byOrden = ordenA.compareTo(ordenB);
      if (byOrden != 0) return byOrden;
      final byNumero = a.numeroSemana.compareTo(b.numeroSemana);
      if (byNumero != 0) return byNumero;
      return (a.codigo ?? 0).compareTo(b.codigo ?? 0);
    });
    return sorted;
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  Entry points
  // ════════════════════════════════════════════════════════════════════════════

  static Future<void> generateWithOptions({
    required BuildContext context,
    required ApiService apiService,
    required PlanNutricional plan,
    PlanNutriEstructura? estructura,
    List<Map<String, dynamic>> recetasCatalogo = const <Map<String, dynamic>>[],
    Set<int>? recetasSeleccionadas,
    String? recomendaciones,
  }) async {
    final options = await PlanNutriPdfService.showPdfOptionsDialog(
      context: context,
      dialogTitle: 'Opciones del Word',
    );
    if (options == null) return;
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando Word…'),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final estructuraWord =
          estructura ?? await apiService.getPlanNutriEstructura(plan.codigo);
      final recetasWord = recetasSeleccionadas ??
          estructuraWord.recetas.map((r) => r.codigoReceta).toSet();

      await generateEstructuraDocx(
        context: context,
        apiService: apiService,
        plan: plan,
        estructura: estructuraWord,
        recetasCatalogo: recetasCatalogo,
        recetasSeleccionadas: recetasWord,
        recomendaciones:
            recomendaciones ?? estructuraWord.planIndicacionesVisibleUsuario,
        showRecetas: options.showRecetas,
        showRecomendaciones: options.showRecomendaciones,
        semanaNuevaPagina: options.semanaNuevaPagina,
        showDatosPaciente: options.showDatosPaciente,
        horizontal: options.horizontal,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar Word: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    }
  }

  static Future<void> generateEstructuraDocx({
    required BuildContext context,
    required ApiService apiService,
    required PlanNutricional plan,
    required PlanNutriEstructura estructura,
    required List<Map<String, dynamic>> recetasCatalogo,
    required Set<int> recetasSeleccionadas,
    String? recomendaciones,
    bool showRecetas = true,
    bool showRecomendaciones = true,
    bool semanaNuevaPagina = false,
    bool showDatosPaciente = true,
    bool horizontal = false,
  }) async {
    try {
      // 1. Fetch branding params
      final nutricionistaParam =
          await apiService.getParametro('nutricionista_nombre');
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      // 2. Fetch accent color
      final colorParam =
          await apiService.getParametro('color_fondo_banda_encabezado_pie_pdf');
      final accentHex =
          _parseHexColor(colorParam?['valor']?.toString()) ?? 'FFC0F4';

      // 3. Fetch recipe text (no images for Word)
      final List<_WordRecetaData> recetasData = [];
      if (showRecetas) {
        for (final codigo in recetasSeleccionadas) {
          try {
            final recetaResp =
                await apiService.get('api/recetas.php?codigo=$codigo');
            if (recetaResp.statusCode == 200) {
              final recetaJson =
                  jsonDecode(recetaResp.body) as Map<String, dynamic>;
              final titulo = recetaJson['titulo']?.toString() ?? '';
              final texto = recetaJson['texto']?.toString() ?? '';
              final vinculada = estructura.recetas
                  .where((r) => r.codigoReceta == codigo)
                  .firstOrNull;
              recetasData.add(_WordRecetaData(
                titulo: titulo,
                texto: texto,
                orden: vinculada?.orden ?? 99,
              ));
            }
          } catch (_) {
            // skip recipe if fetch fails
          }
        }
      }
      recetasData.sort((a, b) => a.orden.compareTo(b.orden));

      // 4. Build document body XML
      final dateFmt = DateFormat('dd/MM/yyyy');
      final tituloPlan = (estructura.tituloPlan ?? '').trim().isEmpty
          ? 'Plan nutricional'
          : estructura.tituloPlan!.trim();
      final pacienteTexto =
          plan.nombrePaciente ?? plan.codigoPaciente?.toString() ?? '-';

      String? periodoTexto;
      if (plan.desde != null || plan.hasta != null) {
        final desde = plan.desde != null ? dateFmt.format(plan.desde!) : null;
        final hasta = plan.hasta != null ? dateFmt.format(plan.hasta!) : null;
        periodoTexto = (hasta == null || hasta.isEmpty)
            ? 'Período ${desde ?? '-'}'
            : 'Período desde ${desde ?? '-'} hasta $hasta';
      }
      final objetivoTexto = (estructura.objetivoPlan ?? '').trim();

      // Page dimensions (A4) in twips (1 twip = 1/20 pt, 1pt ≈ 1/72 inch)
      final pageW = horizontal ? 16838 : 11906;
      final pageH = horizontal ? 11906 : 16838;
      const margin = 720; // ~1.27 cm
      final textW = pageW - 2 * margin;

      final body = StringBuffer();

      // — Branding header (colored table row)
      body.write(_buildBrandingHeader(
        nutricionistaNombre: nutricionistaNombre,
        nutricionistaSubtitulo: nutricionistaSubtitulo,
        accentHex: accentHex,
        textW: textW,
      ));

      // — Plan title
      body.write(_para(
        tituloPlan,
        bold: true,
        center: true,
        fontSize: 28,
        spacingBefore: 120,
        spacingAfter: 80,
      ));

      // — Patient info
      if (showDatosPaciente) {
        body.write(_buildPatientInfoTable(
          pacienteTexto: pacienteTexto,
          periodoTexto: periodoTexto,
          objetivoTexto: objetivoTexto,
          textW: textW,
        ));
        body.write(_para('', spacingAfter: 100));
      }

      // — Weekly tables
      bool hasWeekTable = false;
      for (final semana in _sortedWeeks(estructura.semanas)) {
        final tableXml = _buildSemanaTable(
          semana: semana,
          accentHex: accentHex,
          textW: textW,
        );
        if (tableXml == null) continue;

        if (semanaNuevaPagina && hasWeekTable) {
          body.write(_pageBreak());
        } else if (hasWeekTable) {
          body.write(_para('', spacingAfter: 80));
        }

        body.write(_para(
          'Semana ${semana.numeroSemana}',
          bold: true,
          fontSize: 24,
          spacingBefore: 80,
          spacingAfter: 40,
        ));
        body.write(tableXml);
        hasWeekTable = true;
      }

      // — Recommendations
      final recom =
          (recomendaciones ?? estructura.planIndicacionesVisibleUsuario ?? '')
              .trim();
      if (showRecomendaciones && recom.isNotEmpty) {
        body.write(_pageBreak());
        body.write(_para(
          'RECOMENDACIONES',
          bold: true,
          underline: true,
          center: true,
          fontSize: 24,
          spacingBefore: 120,
          spacingAfter: 120,
        ));
        body.write(_buildTextParagraphs(recom));
      }

      // — Recipes
      if (showRecetas && recetasData.isNotEmpty) {
        body.write(_pageBreak());
        body.write(_para(
          'RECETAS',
          bold: true,
          underline: true,
          center: true,
          fontSize: 24,
          spacingBefore: 120,
          spacingAfter: 120,
        ));
        for (final receta in recetasData) {
          body.write(_para(
            receta.titulo,
            bold: true,
            center: true,
            fontSize: 26,
            spacingBefore: 120,
            spacingAfter: 80,
            color: '1A237E',
          ));
          final recipeText = _cleanRecipeText(receta.texto);
          if (recipeText.trim().isNotEmpty) {
            body.write(_buildTextParagraphs(recipeText));
          }
          body.write(_para('', spacingAfter: 60));
          body.write(_horizontalRule());
          body.write(_para('', spacingAfter: 40));
        }
      }

      // — Section properties (page size + margins)
      body.write(_buildSectPr(
        pageW: pageW,
        pageH: pageH,
        margin: margin,
        landscape: horizontal,
      ));

      final documentXml = _wrapBody(body.toString());

      // 5. Pack into DOCX (ZIP)
      final archive = Archive();
      _addUtf8File(archive, '[Content_Types].xml', _contentTypesXml());
      _addUtf8File(archive, '_rels/.rels', _rootRelsXml());
      _addUtf8File(archive, 'word/document.xml', documentXml);
      _addUtf8File(archive, 'word/_rels/document.xml.rels', _documentRelsXml());
      _addUtf8File(archive, 'word/styles.xml', _stylesXml());
      _addUtf8File(archive, 'word/settings.xml', _settingsXml());

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        throw Exception('Error al comprimir el archivo Word');
      }

      final fileName = _buildDocxFileName(plan, estructura);
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      await File(filePath).writeAsBytes(zipBytes);

      if (!context.mounted) return;
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: fileName,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar Word: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  OOXML document builders
  // ════════════════════════════════════════════════════════════════════════════

  static String _wrapBody(String body) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document '
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<w:body>$body</w:body>'
        '</w:document>';
  }

  static String _buildSectPr({
    required int pageW,
    required int pageH,
    required int margin,
    required bool landscape,
  }) {
    final orientAttr = landscape ? ' w:orient="landscape"' : '';
    return '<w:sectPr>'
        '<w:pgSz w:w="$pageW" w:h="$pageH"$orientAttr/>'
        '<w:pgMar w:top="$margin" w:right="$margin" w:bottom="$margin"'
        ' w:left="$margin" w:header="360" w:footer="360" w:gutter="0"/>'
        '</w:sectPr>';
  }

  // ─── Paragraph ──────────────────────────────────────────────────────────────

  static String _para(
    String text, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool center = false,
    bool justify = false,
    int fontSize = 20, // half-points; 20 = 10pt
    String? color,
    int spacingBefore = 0,
    int spacingAfter = 160,
  }) {
    final sb = StringBuffer('<w:p>');
    sb.write('<w:pPr>');
    if (center) {
      sb.write('<w:jc w:val="center"/>');
    } else if (justify) {
      sb.write('<w:jc w:val="both"/>');
    }
    sb.write('<w:spacing w:before="$spacingBefore" w:after="$spacingAfter"/>');
    sb.write('</w:pPr>');

    if (text.isNotEmpty) {
      sb.write('<w:r><w:rPr>');
      if (bold) sb.write('<w:b/>');
      if (italic) sb.write('<w:i/>');
      if (underline) sb.write('<w:u w:val="single"/>');
      sb.write('<w:sz w:val="$fontSize"/>');
      sb.write('<w:szCs w:val="$fontSize"/>');
      if (color != null) sb.write('<w:color w:val="$color"/>');
      sb.write('</w:rPr>');
      sb.write('<w:t xml:space="preserve">${_xmlEscape(text)}</w:t>');
      sb.write('</w:r>');
    }

    sb.write('</w:p>');
    return sb.toString();
  }

  static String _pageBreak() => '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';

  static String _horizontalRule() => '<w:p><w:pPr>'
      '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="808080"/></w:pBdr>'
      '<w:spacing w:before="0" w:after="0"/>'
      '</w:pPr></w:p>';

  // ─── Branding header (colored band) ─────────────────────────────────────────

  static String _buildBrandingHeader({
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    required String accentHex,
    required int textW,
  }) {
    final sb = StringBuffer();
    sb.write('<w:tbl>');
    sb.write('<w:tblPr>');
    sb.write('<w:tblW w:w="$textW" w:type="dxa"/>');
    sb.write(_tblBordersNone());
    sb.write('<w:tblCellMar>');
    sb.write('<w:top w:w="80" w:type="dxa"/>');
    sb.write('<w:left w:w="120" w:type="dxa"/>');
    sb.write('<w:bottom w:w="80" w:type="dxa"/>');
    sb.write('<w:right w:w="120" w:type="dxa"/>');
    sb.write('</w:tblCellMar>');
    sb.write('</w:tblPr>');
    sb.write('<w:tblGrid><w:gridCol w:w="$textW"/></w:tblGrid>');
    sb.write('<w:tr>');
    sb.write('<w:tc>');
    sb.write('<w:tcPr>');
    sb.write('<w:tcW w:w="$textW" w:type="dxa"/>');
    sb.write('<w:shd w:val="clear" w:color="auto" w:fill="$accentHex"/>');
    sb.write('</w:tcPr>');
    // Name line
    sb.write('<w:p>');
    sb.write('<w:pPr><w:spacing w:before="60" w:after="0"/></w:pPr>');
    sb.write(
        '<w:r><w:rPr><w:b/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>');
    sb.write(
        '<w:t xml:space="preserve">${_xmlEscape(nutricionistaNombre)}</w:t>');
    sb.write('</w:r></w:p>');
    // Subtitle line (always add for consistent bottom padding)
    sb.write('<w:p>');
    sb.write('<w:pPr><w:spacing w:before="0" w:after="60"/></w:pPr>');
    if (nutricionistaSubtitulo.trim().isNotEmpty) {
      sb.write('<w:r><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>');
      sb.write(
          '<w:t xml:space="preserve">${_xmlEscape(nutricionistaSubtitulo.trim())}</w:t>');
      sb.write('</w:r>');
    }
    sb.write('</w:p>');
    sb.write('</w:tc>');
    sb.write('</w:tr>');
    sb.write('</w:tbl>');
    return sb.toString();
  }

  // ─── Patient info table ──────────────────────────────────────────────────────

  static String _buildPatientInfoTable({
    required String pacienteTexto,
    required String? periodoTexto,
    required String objetivoTexto,
    required int textW,
  }) {
    const labelFill = 'BBDEFB'; // blue100
    const cellFill = 'E3F2FD'; // blue50
    const borderColor = '90CAF9'; // blue200
    const labelW = 1100;
    final valueW = textW ~/ 2 - labelW;

    final sb = StringBuffer();
    sb.write('<w:tbl>');
    sb.write('<w:tblPr>');
    sb.write('<w:tblW w:w="$textW" w:type="dxa"/>');
    sb.write(_tblBordersSingle(borderColor));
    sb.write('<w:tblCellMar>');
    sb.write('<w:top w:w="60" w:type="dxa"/>');
    sb.write('<w:left w:w="100" w:type="dxa"/>');
    sb.write('<w:bottom w:w="60" w:type="dxa"/>');
    sb.write('<w:right w:w="100" w:type="dxa"/>');
    sb.write('</w:tblCellMar>');
    sb.write('</w:tblPr>');
    sb.write('<w:tblGrid>');
    sb.write('<w:gridCol w:w="$labelW"/>');
    sb.write('<w:gridCol w:w="$valueW"/>');
    sb.write('<w:gridCol w:w="$labelW"/>');
    sb.write('<w:gridCol w:w="$valueW"/>');
    sb.write('</w:tblGrid>');

    // Row 1: Paciente | value | Período | value
    sb.write('<w:tr>');
    sb.write(_infoCell('Paciente', labelFill, labelW, bold: true));
    sb.write(_infoCell(pacienteTexto, cellFill, valueW));
    sb.write(_infoCell('Período', labelFill, labelW, bold: true));
    sb.write(_infoCell(periodoTexto ?? '-', cellFill, valueW));
    sb.write('</w:tr>');

    // Row 2 (only if objetivo set): Objetivo | spanned value
    if (objetivoTexto.trim().isNotEmpty) {
      sb.write('<w:tr>');
      sb.write(_infoCell('Objetivo', labelFill, labelW, bold: true));
      sb.write(_infoCellSpan(objetivoTexto, cellFill, valueW + labelW + valueW,
          gridSpan: 3));
      sb.write('</w:tr>');
    }

    sb.write('</w:tbl>');
    return sb.toString();
  }

  static String _infoCell(String text, String fill, int width,
      {bool bold = false}) {
    return '<w:tc>'
        '<w:tcPr><w:tcW w:w="$width" w:type="dxa"/>'
        '<w:shd w:val="clear" w:color="auto" w:fill="$fill"/></w:tcPr>'
        '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr>'
        '<w:r><w:rPr>${bold ? '<w:b/>' : ''}'
        '<w:sz w:val="17"/><w:szCs w:val="17"/></w:rPr>'
        '<w:t xml:space="preserve">${_xmlEscape(text)}</w:t></w:r></w:p>'
        '</w:tc>';
  }

  static String _infoCellSpan(String text, String fill, int width,
      {required int gridSpan}) {
    return '<w:tc>'
        '<w:tcPr><w:tcW w:w="$width" w:type="dxa"/>'
        '<w:gridSpan w:val="$gridSpan"/>'
        '<w:shd w:val="clear" w:color="auto" w:fill="$fill"/></w:tcPr>'
        '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr>'
        '<w:r><w:rPr><w:sz w:val="17"/><w:szCs w:val="17"/></w:rPr>'
        '<w:t xml:space="preserve">${_xmlEscape(text)}</w:t></w:r></w:p>'
        '</w:tc>';
  }

  // ─── Weekly plan table ───────────────────────────────────────────────────────

  static String? _buildSemanaTable({
    required PlanNutriSemana semana,
    required String accentHex,
    required int textW,
  }) {
    const lightGreenFill = 'DCEDC8'; // lightGreen100
    const borderColor = '9E9E9E'; // grey700

    final diaByNombre = <String, PlanNutriDia>{};
    for (final dia in semana.dias) {
      diaByNombre[dia.nombreDia] = dia;
    }

    final diasConItems = _diasOrder.where((d) {
      final dia = diaByNombre[d];
      if (dia == null) return false;
      return dia.ingestas.any((ing) => ing.items.isNotEmpty);
    }).toList();

    if (diasConItems.isEmpty) return null;

    final ingestasPresentes = <String>{};
    for (final dNombre in diasConItems) {
      for (final ing in diaByNombre[dNombre]!.ingestas) {
        if (ing.items.isNotEmpty) ingestasPresentes.add(ing.tipoIngesta);
      }
    }

    final ingestasOrdered = [
      ..._ingestaOrder.where(ingestasPresentes.contains),
      ...ingestasPresentes.where((t) => !_ingestaOrder.contains(t)).toList()
        ..sort(),
    ];

    if (ingestasOrdered.isEmpty) return null;

    const mealColW = 1100; // ~55pt in twips
    final dayColW = (textW - mealColW) ~/ diasConItems.length;
    final actualTableW = mealColW + dayColW * diasConItems.length;

    final sb = StringBuffer();
    sb.write('<w:tbl>');
    sb.write('<w:tblPr>');
    sb.write('<w:tblW w:w="$actualTableW" w:type="dxa"/>');
    sb.write(_tblBordersSingle(borderColor));
    sb.write('<w:tblCellMar>');
    sb.write('<w:top w:w="40" w:type="dxa"/>');
    sb.write('<w:left w:w="60" w:type="dxa"/>');
    sb.write('<w:bottom w:w="40" w:type="dxa"/>');
    sb.write('<w:right w:w="60" w:type="dxa"/>');
    sb.write('</w:tblCellMar>');
    sb.write('</w:tblPr>');

    // Grid
    sb.write('<w:tblGrid>');
    sb.write('<w:gridCol w:w="$mealColW"/>');
    for (var i = 0; i < diasConItems.length; i++) {
      sb.write('<w:gridCol w:w="$dayColW"/>');
    }
    sb.write('</w:tblGrid>');

    // Header row
    sb.write('<w:tr>');
    sb.write(
        _headerCell('Sem ${semana.numeroSemana}', lightGreenFill, mealColW));
    for (final dNombre in diasConItems) {
      sb.write(_headerCell(_diaAbrev[dNombre] ?? dNombre, accentHex, dayColW));
    }
    sb.write('</w:tr>');

    // Data rows
    for (final ingestaTipo in ingestasOrdered) {
      final valoresPorDia = <List<String>>[];
      for (final dNombre in diasConItems) {
        final dia = diaByNombre[dNombre];
        if (dia == null) {
          valoresPorDia.add([]);
          continue;
        }
        PlanNutriIngesta? ingestaDia;
        for (final ing in dia.ingestas) {
          if (ing.tipoIngesta == ingestaTipo) {
            ingestaDia = ing;
            break;
          }
        }
        if (ingestaDia == null || ingestaDia.items.isEmpty) {
          valoresPorDia.add([]);
          continue;
        }
        final lines = ingestaDia.items
            .map((item) => (item.descripcionManual ?? '').trim())
            .where((s) => s.isNotEmpty)
            .toList();
        valoresPorDia.add(lines);
      }

      final allNonEmpty = valoresPorDia.every((v) => v.isNotEmpty);
      final primerValor = allNonEmpty ? valoresPorDia.first.join('\n') : '';
      final sameForAll = allNonEmpty &&
          valoresPorDia.every((v) => v.join('\n').trim() == primerValor.trim());

      sb.write('<w:tr>');
      sb.write(_mealTypeCell(ingestaTipo, mealColW));

      if (sameForAll) {
        final midIndex = diasConItems.length ~/ 2;
        for (var i = 0; i < diasConItems.length; i++) {
          if (i == midIndex) {
            sb.write(
                _dataCell(valoresPorDia[i], dayColW, center: true, bold: true));
          } else {
            sb.write(_dataCell([], dayColW));
          }
        }
      } else {
        for (final lines in valoresPorDia) {
          sb.write(_dataCell(lines, dayColW));
        }
      }

      sb.write('</w:tr>');
    }

    sb.write('</w:tbl>');
    return sb.toString();
  }

  static String _headerCell(String text, String fillHex, int width) {
    return '<w:tc>'
        '<w:tcPr><w:tcW w:w="$width" w:type="dxa"/>'
        '<w:shd w:val="clear" w:color="auto" w:fill="$fillHex"/></w:tcPr>'
        '<w:p><w:pPr><w:jc w:val="center"/>'
        '<w:spacing w:before="40" w:after="40"/></w:pPr>'
        '<w:r><w:rPr><w:b/><w:sz w:val="14"/><w:szCs w:val="14"/></w:rPr>'
        '<w:t xml:space="preserve">${_xmlEscape(text)}</w:t></w:r></w:p>'
        '</w:tc>';
  }

  static String _mealTypeCell(String text, int width) {
    return '<w:tc>'
        '<w:tcPr><w:tcW w:w="$width" w:type="dxa"/></w:tcPr>'
        '<w:p><w:pPr><w:jc w:val="center"/>'
        '<w:spacing w:before="40" w:after="40"/></w:pPr>'
        '<w:r><w:rPr><w:b/><w:sz w:val="14"/><w:szCs w:val="14"/></w:rPr>'
        '<w:t xml:space="preserve">${_xmlEscape(text)}</w:t></w:r></w:p>'
        '</w:tc>';
  }

  static String _dataCell(
    List<String> lines,
    int width, {
    bool center = false,
    bool bold = false,
  }) {
    if (lines.isEmpty) {
      return '<w:tc>'
          '<w:tcPr><w:tcW w:w="$width" w:type="dxa"/></w:tcPr>'
          '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr>'
          '<w:r><w:rPr><w:sz w:val="14"/><w:szCs w:val="14"/>'
          '<w:color w:val="BDBDBD"/></w:rPr>'
          '<w:t>-</w:t></w:r></w:p>'
          '</w:tc>';
    }

    final sb = StringBuffer();
    sb.write('<w:tc>');
    sb.write('<w:tcPr><w:tcW w:w="$width" w:type="dxa"/></w:tcPr>');
    for (var i = 0; i < lines.length; i++) {
      sb.write('<w:p>');
      sb.write('<w:pPr>');
      if (center) sb.write('<w:jc w:val="center"/>');
      sb.write('<w:spacing w:before="0" w:after="0"/>');
      sb.write('</w:pPr>');
      sb.write('<w:r><w:rPr>');
      if (bold) sb.write('<w:b/>');
      sb.write('<w:sz w:val="14"/><w:szCs w:val="14"/>');
      sb.write('</w:rPr>');
      sb.write('<w:t xml:space="preserve">${_xmlEscape(lines[i])}</w:t>');
      sb.write('</w:r></w:p>');
    }
    sb.write('</w:tc>');
    return sb.toString();
  }

  // ─── Text section helpers ────────────────────────────────────────────────────

  static String _buildTextParagraphs(String text) {
    final sb = StringBuffer();
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return '';

    final paragraphs = normalized
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);

    for (final para in paragraphs) {
      final lines = para.split('\n');
      sb.write('<w:p>');
      sb.write('<w:pPr><w:jc w:val="both"/>'
          '<w:spacing w:before="0" w:after="160" w:line="276" w:lineRule="auto"/>'
          '</w:pPr>');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        sb.write('<w:r><w:rPr><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>');
        sb.write('<w:t xml:space="preserve">${_xmlEscape(line)}</w:t></w:r>');
        if (i < lines.length - 1) {
          sb.write('<w:r><w:br/></w:r>');
        }
      }
      sb.write('</w:p>');
    }
    return sb.toString();
  }

  static String _cleanRecipeText(String text) {
    // Remove inline image/link/document tokens
    var cleaned =
        text.replaceAll(RegExp(r'\[\[(img|enlace|documento):\d+\]\]'), '');
    // Unwrap 👉…👈 emphasis markers (keep inner text)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'👉(?:\uFE0F)?\s*(.*?)\s*👈(?:\uFE0F)?', dotAll: true),
      (m) => m.group(1) ?? '',
    );
    // Remove hashtag-only lines
    cleaned = cleaned.replaceAll('\r\n', '\n').split('\n').where((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return true;
      final words =
          trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      return !words.every((w) => w.startsWith('#'));
    }).join('\n');
    return cleaned.trim();
  }

  // ─── Table border helpers ────────────────────────────────────────────────────

  static String _tblBordersNone() {
    String side(String name) =>
        '<w:$name w:val="none" w:sz="0" w:space="0" w:color="auto"/>';
    return '<w:tblBorders>'
        '${side("top")}${side("left")}${side("bottom")}${side("right")}'
        '${side("insideH")}${side("insideV")}'
        '</w:tblBorders>';
  }

  static String _tblBordersSingle(String color) {
    const sz = '4';
    String side(String name) =>
        '<w:$name w:val="single" w:sz="$sz" w:space="0" w:color="$color"/>';
    return '<w:tblBorders>'
        '${side("top")}${side("left")}${side("bottom")}${side("right")}'
        '${side("insideH")}${side("insideV")}'
        '</w:tblBorders>';
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  Static OOXML content files
  // ════════════════════════════════════════════════════════════════════════════

  static String _contentTypesXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '<Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>'
      '</Types>';

  static String _rootRelsXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/>'
      '</Relationships>';

  static String _documentRelsXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
      'Target="styles.xml"/>'
      '<Relationship Id="rId2" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" '
      'Target="settings.xml"/>'
      '</Relationships>';

  static String _stylesXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
      '<w:name w:val="Normal"/>'
      '<w:rPr><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>'
      '</w:style>'
      '</w:styles>';

  static String _settingsXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:defaultTabStop w:val="709"/>'
      '<w:compat>'
      '<w:compatSetting w:name="compatibilityMode"'
      ' w:uri="http://schemas.microsoft.com/office/word"'
      ' w:val="15"/>'
      '</w:compat>'
      '</w:settings>';

  // ════════════════════════════════════════════════════════════════════════════
  //  Utilities
  // ════════════════════════════════════════════════════════════════════════════

  static void _addUtf8File(Archive archive, String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  static String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String? _parseHexColor(String? value) {
    if (value == null) return null;
    var raw = value.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('#')) raw = raw.substring(1);
    if (raw.length == 6) return raw.toUpperCase();
    if (raw.length == 8) return raw.substring(2).toUpperCase(); // strip alpha
    return null;
  }

  static String _buildDocxFileName(
    PlanNutricional plan,
    PlanNutriEstructura estructura,
  ) {
    final tituloPlanRaw =
        (estructura.tituloPlan ?? plan.tituloPlan ?? '').trim();
    final pacienteRaw = (plan.nombrePaciente ?? '').trim();

    final tituloPlan = _sanitizeFileNamePart(
      tituloPlanRaw.isEmpty ? 'Sin_titulo' : tituloPlanRaw,
    );
    final paciente = _sanitizeFileNamePart(
      pacienteRaw.isEmpty
          ? 'Paciente_${plan.codigoPaciente ?? plan.codigo}'
          : pacienteRaw,
    );

    return 'Plan_Nutricional_${tituloPlan}_$paciente.docx';
  }

  static String _sanitizeFileNamePart(String value) {
    var normalized = value
        .replaceAll(RegExp(r'[áàäâãåÁÀÄÂÃÅ]'), 'a')
        .replaceAll(RegExp(r'[éèëêÉÈËÊ]'), 'e')
        .replaceAll(RegExp(r'[íìïîÍÌÏÎ]'), 'i')
        .replaceAll(RegExp(r'[óòöôõÓÒÖÔÕ]'), 'o')
        .replaceAll(RegExp(r'[úùüûÚÙÜÛ]'), 'u')
        .replaceAll(RegExp(r'[ñÑ]'), 'n')
        .replaceAll(RegExp(r'[çÇ]'), 'c');

    normalized = normalized
        .replaceAll(RegExp(r'[\\/:\.\*\?"<>\|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (normalized.isEmpty) return 'Sin_texto';
    if (normalized.length > 80) return normalized.substring(0, 80);
    return normalized;
  }
}
