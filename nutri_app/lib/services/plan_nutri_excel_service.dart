import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/plan_nutri_estructura.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ─── Service ──────────────────────────────────────────────────────────────────

class PlanNutriExcelService {
  const PlanNutriExcelService._();

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
  //  Entry point
  // ════════════════════════════════════════════════════════════════════════════

  static Future<void> generateWithOptions({
    required BuildContext context,
    required ApiService apiService,
    required PlanNutricional plan,
    PlanNutriEstructura? estructura,
  }) async {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando Excel…'),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final estructuraExcel =
          estructura ?? await apiService.getPlanNutriEstructura(plan.codigo);

      await generateEstructuraXlsx(
        context: context,
        apiService: apiService,
        plan: plan,
        estructura: estructuraExcel,
        showDatosPaciente: true,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar Excel: $e'),
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

  static Future<void> generateEstructuraXlsx({
    required BuildContext context,
    required ApiService apiService,
    required PlanNutricional plan,
    required PlanNutriEstructura estructura,
    bool showDatosPaciente = true,
  }) async {
    try {
      // 1. Fetch accent color
      final colorParam =
          await apiService.getParametro('color_fondo_banda_encabezado_pie_pdf');
      final accentHex =
          _parseHexColor(colorParam?['valor']?.toString()) ?? 'C0F4FF';

      // 2. Build sheet XML
      final sheetXml = _buildSheetXml(
        estructura: estructura,
        plan: plan,
        accentHex: accentHex,
        showDatosPaciente: showDatosPaciente,
      );

      // 3. Pack into XLSX (ZIP)
      final archive = Archive();
      _addUtf8File(archive, '[Content_Types].xml', _contentTypesXml());
      _addUtf8File(archive, '_rels/.rels', _rootRelsXml());
      _addUtf8File(archive, 'xl/workbook.xml', _workbookXml());
      _addUtf8File(archive, 'xl/_rels/workbook.xml.rels', _workbookRelsXml());
      _addUtf8File(archive, 'xl/worksheets/sheet1.xml', sheetXml);
      _addUtf8File(archive, 'xl/styles.xml', _stylesXml(accentHex));

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) throw Exception('Error al comprimir el Excel');

      final fileName = _buildXlsxFileName(plan, estructura);
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
            content: Text('Error al generar Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  Sheet builder
  // ════════════════════════════════════════════════════════════════════════════

  static String _buildSheetXml({
    required PlanNutriEstructura estructura,
    required PlanNutricional plan,
    required String accentHex,
    required bool showDatosPaciente,
  }) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    int row = 1;
    final data = StringBuffer();

    final tituloPlan =
        (estructura.tituloPlan ?? plan.tituloPlan ?? '').trim().isEmpty
            ? 'Plan nutricional'
            : (estructura.tituloPlan ?? plan.tituloPlan)!.trim();
    final pacienteTexto =
        (plan.nombrePaciente ?? plan.codigoPaciente?.toString() ?? '-').trim();

    String? periodoTexto;
    if (plan.desde != null || plan.hasta != null) {
      final desde = plan.desde != null ? dateFmt.format(plan.desde!) : null;
      final hasta = plan.hasta != null ? dateFmt.format(plan.hasta!) : null;
      periodoTexto = (hasta == null || hasta.isEmpty)
          ? 'Desde ${desde ?? '-'}'
          : 'Del ${desde ?? '-'} al $hasta';
    }
    final objetivoTexto =
        (estructura.objetivoPlan ?? plan.objetivoPlan ?? '').trim();

    // — Title row (style 1: bold white on accent)
    data.write(_rowXml(row, [_c(row, 1, tituloPlan, style: 1)]));
    row++;

    // — Patient info
    if (showDatosPaciente) {
      data.write(_rowXml(row, [
        _c(row, 1, 'Paciente: $pacienteTexto'),
        if (periodoTexto != null) _c(row, 4, periodoTexto),
      ]));
      row++;
      if (objetivoTexto.isNotEmpty) {
        data.write(_rowXml(row, [_c(row, 1, 'Objetivo: $objetivoTexto')]));
        row++;
      }
    }

    // — Empty separator
    data.write(_rowXml(row, []));
    row++;

    // — Column headers (style 2: bold on light fill, bordered)
    data.write(_rowXml(row, [
      _c(row, 1, 'Semana', style: 2),
      _c(row, 2, 'Día', style: 2),
      _c(row, 3, 'Ingesta', style: 2),
      _c(row, 4, 'Alimento / Descripción', style: 2),
      _c(row, 5, 'Cantidad', style: 2),
      _c(row, 6, 'Unidad', style: 2),
      _c(row, 7, 'Notas', style: 2),
    ]));
    row++;

    // — Data rows
    for (final semana in _sortedWeeks(estructura.semanas)) {
      final sortedDias = [...semana.dias]..sort((a, b) {
          final ai = _diasOrder.indexOf(a.nombreDia);
          final bi = _diasOrder.indexOf(b.nombreDia);
          return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
        });

      for (final dia in sortedDias) {
        final sortedIngestas = [...dia.ingestas]..sort((a, b) {
            final ai = _ingestaOrder.indexOf(a.tipoIngesta);
            final bi = _ingestaOrder.indexOf(b.tipoIngesta);
            return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
          });

        for (final ingesta in sortedIngestas) {
          if (ingesta.items.isEmpty) {
            data.write(_rowXml(row, [
              _c(row, 1, 'Semana ${semana.numeroSemana}'),
              _c(row, 2, dia.nombreDia),
              _c(row, 3, ingesta.tipoIngesta),
              _c(row, 4, '-'),
            ]));
            row++;
          } else {
            for (final item in ingesta.items) {
              final alimento =
                  (item.alimentoNombre ?? item.descripcionManual ?? '').trim();
              data.write(_rowXml(row, [
                _c(row, 1, 'Semana ${semana.numeroSemana}'),
                _c(row, 2, dia.nombreDia),
                _c(row, 3, ingesta.tipoIngesta),
                _c(row, 4, alimento.isEmpty ? '-' : alimento),
                if ((item.cantidad ?? '').trim().isNotEmpty)
                  _c(row, 5, item.cantidad!.trim()),
                if ((item.unidad ?? '').trim().isNotEmpty)
                  _c(row, 6, item.unidad!.trim()),
                if ((item.notas ?? '').trim().isNotEmpty)
                  _c(row, 7, item.notas!.trim()),
              ]));
              row++;
            }
          }
        }
      }
    }

    // Column widths
    const colsXml = '<cols>'
        '<col min="1" max="1" width="12" customWidth="1"/>'
        '<col min="2" max="2" width="12" customWidth="1"/>'
        '<col min="3" max="3" width="14" customWidth="1"/>'
        '<col min="4" max="4" width="38" customWidth="1"/>'
        '<col min="5" max="5" width="10" customWidth="1"/>'
        '<col min="6" max="6" width="10" customWidth="1"/>'
        '<col min="7" max="7" width="22" customWidth="1"/>'
        '</cols>';

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '$colsXml'
        '<sheetData>${data.toString()}</sheetData>'
        '</worksheet>';
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  Cell / row helpers
  // ════════════════════════════════════════════════════════════════════════════

  /// Convert 1-based column index to letter(s): 1→A, 26→Z, 27→AA …
  static String _colLetter(int col) {
    var c = col;
    var result = '';
    while (c > 0) {
      c--;
      result = String.fromCharCode(65 + c % 26) + result;
      c ~/= 26;
    }
    return result;
  }

  /// Inline-string cell (t="inlineStr").
  static String _c(int row, int col, String text, {int style = 0}) {
    final ref = '${_colLetter(col)}$row';
    final escaped = _esc(text);
    final s = style == 0 ? '' : ' s="$style"';
    return '<c r="$ref" t="inlineStr"$s>'
        '<is><t xml:space="preserve">$escaped</t></is>'
        '</c>';
  }

  static String _rowXml(int row, List<String> cells) =>
      '<row r="$row">${cells.join()}</row>';

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  // ════════════════════════════════════════════════════════════════════════════
  //  XLSX XML parts
  // ════════════════════════════════════════════════════════════════════════════

  static String _contentTypesXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  static String _rootRelsXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static String _workbookXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets>'
      '<sheet name="Plan Nutricional" sheetId="1" r:id="rId1"/>'
      '</sheets>'
      '</workbook>';

  static String _workbookRelsXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  /// Styles:
  ///  xf 0 – normal
  ///  xf 1 – bold white on accent (title / section headers)
  ///  xf 2 – bold dark on light-blue with border (column headers)
  static String _stylesXml(String accentHex) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="3">'
      //  font 0 – normal
      '<font><sz val="10"/><name val="Calibri"/></font>'
      //  font 1 – bold white (for title on accent bg)
      '<font><b/><sz val="12"/><name val="Calibri"/><color rgb="FFFFFFFF"/></font>'
      //  font 2 – bold dark blue (for col headers on light bg)
      '<font><b/><sz val="10"/><name val="Calibri"/><color rgb="FF1A237E"/></font>'
      '</fonts>'
      '<fills count="4">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      //  fill 2 – accent solid
      '<fill><patternFill patternType="solid"><fgColor rgb="FF$accentHex"/></patternFill></fill>'
      //  fill 3 – light blue (#E3F2FD) for column headers
      '<fill><patternFill patternType="solid"><fgColor rgb="FFE3F2FD"/></patternFill></fill>'
      '</fills>'
      '<borders count="2">'
      '<border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border>'
      '<left style="thin"><color rgb="FFBDBDBD"/></left>'
      '<right style="thin"><color rgb="FFBDBDBD"/></right>'
      '<top style="thin"><color rgb="FFBDBDBD"/></top>'
      '<bottom style="thin"><color rgb="FFBDBDBD"/></bottom>'
      '<diagonal/>'
      '</border>'
      '</borders>'
      '<cellStyleXfs count="1">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>'
      '</cellStyleXfs>'
      '<cellXfs count="3">'
      //  0: normal
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      //  1: bold white on accent
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
      //  2: bold dark on light-blue, bordered
      '<xf numFmtId="0" fontId="2" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>'
      '</cellXfs>'
      '</styleSheet>';

  // ════════════════════════════════════════════════════════════════════════════
  //  File naming
  // ════════════════════════════════════════════════════════════════════════════

  static String _buildXlsxFileName(
    PlanNutricional plan,
    PlanNutriEstructura estructura,
  ) {
    final tituloPlanRaw =
        (estructura.tituloPlan ?? plan.tituloPlan ?? '').trim();
    final pacienteRaw = (plan.nombrePaciente ?? '').trim();

    final tituloPlan = _sanitize(
      tituloPlanRaw.isEmpty ? 'Sin_titulo' : tituloPlanRaw,
    );
    final paciente = _sanitize(
      pacienteRaw.isEmpty
          ? 'Paciente_${plan.codigoPaciente ?? plan.codigo}'
          : pacienteRaw,
    );

    return 'Plan_Nutricional_${tituloPlan}_$paciente.xlsx';
  }

  static String _sanitize(String value) {
    var v = value
        .replaceAll(RegExp(r'[áàäâãåÁÀÄÂÃÅ]'), 'a')
        .replaceAll(RegExp(r'[éèëêÉÈËÊ]'), 'e')
        .replaceAll(RegExp(r'[íìïîÍÌÏÎ]'), 'i')
        .replaceAll(RegExp(r'[óòöôõÓÒÖÔÕ]'), 'o')
        .replaceAll(RegExp(r'[úùüûÚÙÜÛ]'), 'u')
        .replaceAll(RegExp(r'[ñÑ]'), 'n')
        .replaceAll(RegExp(r'[çÇ]'), 'c')
        .replaceAll(RegExp(r'[\\/:\.\*\?"<>\|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (v.isEmpty) return 'Sin_texto';
    if (v.length > 60) return v.substring(0, 60);
    return v;
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  Misc helpers
  // ════════════════════════════════════════════════════════════════════════════

  static String? _parseHexColor(String? value) {
    if (value == null) return null;
    var raw = value.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('#')) raw = raw.substring(1);
    if (raw.length == 6) return raw.toUpperCase();
    if (raw.length == 8) return raw.substring(2).toUpperCase();
    return null;
  }

  static void _addUtf8File(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }
}
