import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/revision.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class RevisionesPdfService {
  const RevisionesPdfService._();

  static const PdfColor _accentPink = PdfColor.fromInt(0xFFFFC0F4);
  static const PdfColor _softPink = PdfColor.fromInt(0xFFFFE6F7);

  static Future<void> generateRevisionesPdf({
    required BuildContext context,
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    Uint8List? logoBytes,
    required String logoSizeStr,
    required String accentColorStr,
    required List<Revision> revisiones,
    required Map<int, Paciente> pacientesMap,
    required String filtroActivo,
  }) async {
    try {
      final logoSize = _parseLogoSize(logoSizeStr);
      final accentColor = _parsePdfColor(accentColorStr) ?? _accentPink;

      final pdf = pw.Document();
      final tituloTexto = _buildTitleFromFilter(filtroActivo);

      // Agrupar revisiones por paciente
      final Map<int, List<Revision>> revisionesPorPaciente = {};
      for (final revision in revisiones) {
        final codigoPaciente = revision.codigoPaciente ?? 0;
        if (!revisionesPorPaciente.containsKey(codigoPaciente)) {
          revisionesPorPaciente[codigoPaciente] = [];
        }
        revisionesPorPaciente[codigoPaciente]!.add(revision);
      }

      // Determinar si hay peso en alguna revisión
      final tienePeso = revisiones.any((r) => r.peso != null);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 16, 24, 24),
          header: (context) => _buildHeader(
            nutricionistaNombre: nutricionistaNombre,
            nutricionistaSubtitulo: nutricionistaSubtitulo,
            logoBytes: logoBytes,
            logoSize: logoSize,
            tituloTexto: tituloTexto,
            pageNumber: context.pageNumber,
            accentColor: accentColor,
          ),
          footer: (context) => _buildFooter(
            nutricionistaNombre: nutricionistaNombre,
            pageNumber: context.pageNumber,
            pageCount: context.pagesCount,
            accentColor: accentColor,
            tituloTexto: tituloTexto,
          ),
          build: (context) => [
            _buildRevisionesTable(
                revisionesPorPaciente, pacientesMap, tienePeso),
          ],
        ),
      );

      final bytes = await pdf.save();
      final fileName = _buildFileName(filtroActivo);
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

  static String _buildTitleFromFilter(String filtroActivo) {
    final estado = filtroActivo == 'S' ? 'Activos' : 'Todos';
    return 'REVISIONES ($estado)';
  }

  static String _buildFileName(String filtroActivo) {
    return 'Revisiones.pdf';
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

  static pw.Widget _buildRevisionesTable(
    Map<int, List<Revision>> revisionesPorPaciente,
    Map<int, Paciente> pacientesMap,
    bool tienePeso,
  ) {
    final rows = <pw.Widget>[];
    final headerStyle =
        pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    const cellStyle = pw.TextStyle(fontSize: 8);
    final pacienteStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );

    // Iterar por cada paciente
    for (final entry in revisionesPorPaciente.entries) {
      final codigoPaciente = entry.key;
      final revisionesDelPaciente = entry.value;
      final paciente = pacientesMap[codigoPaciente];
      final nombrePaciente = paciente?.nombre ??
          revisionesDelPaciente.first.nombrePaciente ??
          'Paciente desconocido';

      // Agregar una tabla solo para el nombre del paciente (una fila, una columna)
      rows.add(
        pw.Table(
          border: pw.TableBorder.all(
            color: PdfColors.grey400,
            width: 0.3,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(10),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _softPink),
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(nombrePaciente, style: pacienteStyle),
                ),
              ],
            ),
          ],
        ),
      );

      // Construir tabla para datos de revisiones de este paciente
      final tableCells = <pw.TableRow>[];

      // 1ª fila: Headers de tabla
      final headerCells = <pw.Widget>[];
      headerCells.add(_buildHeaderCell('Fecha', headerStyle,
          alignment: pw.Alignment.centerLeft));
      headerCells.add(_buildHeaderCell('Asunto', headerStyle,
          alignment: pw.Alignment.centerLeft));
      headerCells.add(_buildHeaderCell('Semanas', headerStyle,
          alignment: pw.Alignment.centerLeft));
      if (tienePeso) {
        headerCells.add(_buildHeaderCell('Peso', headerStyle,
            alignment: pw.Alignment.centerRight));
        headerCells.add(_buildHeaderCell('IMC', headerStyle,
            alignment: pw.Alignment.centerRight));
      }
      headerCells.add(_buildHeaderCell('Mod. dieta', headerStyle,
          alignment: pw.Alignment.centerLeft));

      tableCells.add(pw.TableRow(children: headerCells));

      // 2ª fila en adelante: Datos de revisiones
      for (final revision in revisionesDelPaciente) {
        final fecha = _formatFecha(revision);
        final asunto = revision.asunto;
        final semanas = revision.semanas;
        final peso = revision.peso?.toStringAsFixed(2) ?? '';
        final imcNumerico = _calculateImc(paciente?.altura, revision.peso);
        final imcColor = _getImcColor(imcNumerico);
        final imcStyle = pw.TextStyle(
          fontSize: 8,
          color: imcColor,
          fontWeight: pw.FontWeight.bold,
        );
        final imc = imcNumerico > 0 ? imcNumerico.toStringAsFixed(1) : '';
        final modDieta = revision.modificacionDieta ?? '';

        final rowCells = <pw.Widget>[];

        // Fecha
        rowCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(fecha, style: cellStyle),
          ),
        );

        // Asunto
        rowCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.topLeft,
            child: pw.Text(asunto, style: cellStyle),
          ),
        );

        // Semanas
        rowCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(semanas, style: cellStyle),
          ),
        );

        // Peso (si aplica)
        if (tienePeso) {
          rowCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(peso, style: cellStyle),
            ),
          );

          // IMC (si aplica)
          rowCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(imc, style: imcStyle),
            ),
          );
        }

        // Modificación dieta
        rowCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.topLeft,
            child: pw.Text(modDieta, style: cellStyle),
          ),
        );

        tableCells.add(pw.TableRow(children: rowCells));
      }

      // Construir columnWidths dinámicamente
      final columnWidths = <int, pw.FlexColumnWidth>{};
      int colIndex = 0;
      columnWidths[colIndex++] = const pw.FlexColumnWidth(0.7); // Fecha
      columnWidths[colIndex++] = const pw.FlexColumnWidth(2.0); // Asunto
      columnWidths[colIndex++] = const pw.FlexColumnWidth(0.7); // Semanas
      if (tienePeso) {
        columnWidths[colIndex++] = const pw.FlexColumnWidth(0.6); // Peso
        columnWidths[colIndex++] = const pw.FlexColumnWidth(0.6); // IMC
      }
      columnWidths[colIndex++] = const pw.FlexColumnWidth(2.0); // Mod. dieta

      rows.add(
        pw.Table(
          border: pw.TableBorder.all(
            color: PdfColors.grey400,
            width: 0.3,
          ),
          columnWidths: columnWidths,
          children: tableCells,
        ),
      );

      rows.add(pw.SizedBox(height: 8));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rows,
    );
  }

  static pw.Widget _buildHeaderCell(String text, pw.TextStyle style,
      {pw.Alignment alignment = pw.Alignment.centerLeft}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      alignment: alignment,
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      child: pw.Text(text, style: style),
    );
  }

  static String _formatFecha(Revision revision) {
    final fecha = revision.fechaRealizacion ?? revision.fechaPrevista;
    if (fecha == null) return '';
    final formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(fecha);
  }

  static double _calculateImc(int? alturaEmCm, double? pesoEnKg) {
    if (alturaEmCm == null || pesoEnKg == null || alturaEmCm == 0) {
      return 0.0;
    }
    final alturaEnM = alturaEmCm / 100.0;
    return pesoEnKg / (alturaEnM * alturaEnM);
  }

  static PdfColor _getImcColor(double imc) {
    if (imc == 0.0) {
      return PdfColors.black;
    } else if (imc < 18.5) {
      // Bajo peso - Azul
      return PdfColors.blue;
    } else if (imc < 25.0) {
      // Peso normal - Verde
      return PdfColors.green;
    } else if (imc < 30.0) {
      // Sobrepeso - Naranja
      return PdfColors.orange;
    } else {
      // Obesidad - Rojo
      return PdfColors.red;
    }
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
}
