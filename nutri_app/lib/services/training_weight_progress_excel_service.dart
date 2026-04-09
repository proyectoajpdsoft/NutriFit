import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class TrainingWeightProgressExcelService {
  const TrainingWeightProgressExcelService._();

  static bool get _isDesktopPlatform =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static Future<void> exportAnalysis({
    required BuildContext context,
    required String title,
    required String periodLabel,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    if (rows.isEmpty) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay datos para exportar a Excel.'),
        ),
      );
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generando Excel…'),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      final archive = Archive();
      _addUtf8File(archive, '[Content_Types].xml', _contentTypesXml());
      _addUtf8File(archive, '_rels/.rels', _rootRelsXml());
      _addUtf8File(archive, 'xl/workbook.xml', _workbookXml());
      _addUtf8File(archive, 'xl/_rels/workbook.xml.rels', _workbookRelsXml());
      _addUtf8File(
        archive,
        'xl/worksheets/sheet1.xml',
        _sheetXml(
            title: title,
            periodLabel: periodLabel,
            headers: headers,
            rows: rows),
      );
      _addUtf8File(archive, 'xl/styles.xml', _stylesXml());

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        throw Exception('No se pudo comprimir el archivo Excel');
      }

      final fileName = _buildFileName(title);

      if (!context.mounted) {
        return;
      }

      if (_isDesktopPlatform) {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar Excel',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['xlsx'],
        );

        if (savePath == null || savePath.trim().isEmpty) {
          return;
        }

        await File(savePath).writeAsBytes(zipBytes, flush: true);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel guardado en: $savePath'),
            ),
          );
        }
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      await File(filePath).writeAsBytes(zipBytes, flush: true);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: fileName,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar Excel: $error'),
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

  static String _sheetXml({
    required String title,
    required String periodLabel,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final buffer = StringBuffer();
    var rowIndex = 1;

    buffer.write(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );
    buffer.write(
      '<cols>'
      '<col min="1" max="1" width="12" customWidth="1"/>'
      '<col min="2" max="2" width="14" customWidth="1"/>'
      '<col min="3" max="3" width="34" customWidth="1"/>'
      '<col min="4" max="4" width="12" customWidth="1"/>'
      '<col min="5" max="7" width="12" customWidth="1"/>'
      '<col min="8" max="9" width="14" customWidth="1"/>'
      '</cols>',
    );
    buffer.write('<sheetData>');

    buffer.write(_rowXml(rowIndex, <String>[_normalize(title)], style: 1));
    rowIndex++;
    buffer.write(
      _rowXml(rowIndex, <String>['Periodo: ${_normalize(periodLabel)}']),
    );
    rowIndex++;
    buffer.write(
      _rowXml(
        rowIndex,
        <String>[
          'Exportado: ${DateTime.now().toLocal().toIso8601String().substring(0, 19).replaceFirst('T', ' ')}'
        ],
      ),
    );
    rowIndex++;
    buffer.write(_rowXml(rowIndex, const <String>[]));
    rowIndex++;
    buffer.write(_rowXml(rowIndex, headers.map(_normalize).toList(), style: 2));
    rowIndex++;

    for (final row in rows) {
      buffer.write(_rowXml(rowIndex, row.map(_normalize).toList()));
      rowIndex++;
    }

    buffer.write('</sheetData></worksheet>');
    return buffer.toString();
  }

  static String _rowXml(int rowIndex, List<String> values, {int style = 0}) {
    if (values.isEmpty) {
      return '<row r="$rowIndex"/>';
    }

    final cells = StringBuffer('<row r="$rowIndex">');
    for (var columnIndex = 0; columnIndex < values.length; columnIndex++) {
      final value = values[columnIndex];
      if (value.isEmpty) {
        continue;
      }
      cells.write(
        _cellXml(
          rowIndex,
          columnIndex + 1,
          value,
          style: style,
        ),
      );
    }
    cells.write('</row>');
    return cells.toString();
  }

  static String _cellXml(int row, int column, String value, {int style = 0}) {
    final reference = '${_columnName(column)}$row';
    final styleAttr = style == 0 ? '' : ' s="$style"';
    return '<c r="$reference"$styleAttr t="inlineStr"><is><t>${_escapeXml(value)}</t></is></c>';
  }

  static String _columnName(int index) {
    var value = index;
    final name = StringBuffer();
    while (value > 0) {
      final remainder = (value - 1) % 26;
      name.writeCharCode(65 + remainder);
      value = (value - 1) ~/ 26;
    }
    return name.toString().split('').reversed.join();
  }

  static String _contentTypesXml() {
    return '<?xml version="1.0" encoding="UTF-8"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '</Types>';
  }

  static String _rootRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>';
  }

  static String _workbookXml() {
    return '<?xml version="1.0" encoding="UTF-8"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="Evolucion" sheetId="1" r:id="rId1"/></sheets>'
        '</workbook>';
  }

  static String _workbookRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>';
  }

  static String _stylesXml() {
    return '<?xml version="1.0" encoding="UTF-8"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="2">'
        '<font><sz val="11"/><name val="Calibri"/></font>'
        '<font><b/><sz val="11"/><name val="Calibri"/><color rgb="FFFFFFFF"/></font>'
        '</fonts>'
        '<fills count="3">'
        '<fill><patternFill patternType="none"/></fill>'
        '<fill><patternFill patternType="gray125"/></fill>'
        '<fill><patternFill patternType="solid"><fgColor rgb="FF1565C0"/><bgColor indexed="64"/></patternFill></fill>'
        '</fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="3">'
        '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
        '<xf numFmtId="0" fontId="0" fillId="2" borderId="0" xfId="0" applyFill="1"/>'
        '</cellXfs>'
        '</styleSheet>';
  }

  static void _addUtf8File(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  static String _buildFileName(String title) {
    final safeTitle = title
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final datePart = DateTime.now().toIso8601String().substring(0, 10);
    return '${safeTitle.isEmpty ? 'Evolucion_pesos' : safeTitle}_$datePart.xlsx';
  }

  static String _normalize(String value) => value.trim();

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
