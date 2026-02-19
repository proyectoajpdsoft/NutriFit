import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/medicion.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class MedicionesPdfService {
  const MedicionesPdfService._();

  static const PdfColor _accentPink = PdfColor.fromInt(0xFFFFC0F4);
  static const PdfColor _softPink = PdfColor.fromInt(0xFFFFE6F7);
  static const PdfColor _softGreen = PdfColor.fromInt(0xFFE6F7E6);

  static Future<void> generateMedicionesPdf({
    required BuildContext context,
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    Uint8List? logoBytes,
    required String logoSizeStr,
    required String accentColorStr,
    required List<Medicion> mediciones,
    required Map<int, Paciente> pacientesMap,
    required String filtroActivo,
  }) async {
    try {
      final logoSize = _parseLogoSize(logoSizeStr);
      final accentColor = _parsePdfColor(accentColorStr) ?? _accentPink;

      final pdf = pw.Document();
      final tituloTexto =
          'MEDICIONES (${filtroActivo == 'S' ? 'Activos' : 'Todos'})';

      // Agrupar mediciones por paciente
      final Map<int, List<Medicion>> medicionesPorPaciente = {};
      for (final medicion in mediciones) {
        final codigoPaciente = medicion.codigoPaciente;
        if (!medicionesPorPaciente.containsKey(codigoPaciente)) {
          medicionesPorPaciente[codigoPaciente] = [];
        }
        medicionesPorPaciente[codigoPaciente]!.add(medicion);
      }

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
            _buildMedicionesTable(medicionesPorPaciente, pacientesMap),
          ],
        ),
      );

      final bytes = await pdf.save();
      const fileName = 'Mediciones.pdf';
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
              if (logoBytes != null && logoSize != null)
                pw.Image(
                  pw.MemoryImage(logoBytes),
                  width: logoSize.x,
                  height: logoSize.y,
                ),
            ],
          ),
        ),
        if (pageNumber == 1)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Text(
              tituloTexto,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        pw.SizedBox(height: 8),
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
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(color: accentColor),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(nutricionistaNombre, style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(
            child: pw.Center(
              child: pw.Text(
                '$pageNumber/$pageCount',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                tituloTexto,
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMedicionesTable(
    Map<int, List<Medicion>> medicionesPorPaciente,
    Map<int, Paciente> pacientesMap,
  ) {
    final rows = <pw.Widget>[];
    final headerStyle =
        pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    const cellStyle = pw.TextStyle(fontSize: 8);
    final pacienteStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );

    for (final entry in medicionesPorPaciente.entries) {
      final codigoPaciente = entry.key;
      final medicionesDelPaciente = entry.value;
      final paciente = pacientesMap[codigoPaciente];
      final nombrePaciente = paciente?.nombre ??
          medicionesDelPaciente.first.nombrePaciente ??
          'Paciente desconocido';

      // Tabla para nombre del paciente
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

      // Tabla de mediciones principales
      final tableCells = <pw.TableRow>[];

      // Headers principales
      final headerCells = <pw.Widget>[];
      headerCells.add(_buildHeaderCell('Fecha', headerStyle,
          alignment: pw.Alignment.centerLeft));
      headerCells.add(_buildHeaderCell('Peso (kg)', headerStyle,
          alignment: pw.Alignment.centerRight));
      headerCells.add(_buildHeaderCell('IMC', headerStyle,
          alignment: pw.Alignment.centerRight));
      headerCells.add(_buildHeaderCell('Actividad', headerStyle,
          alignment: pw.Alignment.centerLeft));

      tableCells.add(pw.TableRow(children: headerCells));

      // Datos de mediciones
      for (final medicion in medicionesDelPaciente) {
        final fecha = _formatFecha(medicion.fecha);
        final peso = medicion.peso?.toStringAsFixed(2) ?? '';
        final imcNumerico = _calculateImc(paciente?.altura, medicion.peso);
        final imcColor = _getImcColor(imcNumerico);
        final imcStyle = pw.TextStyle(
          fontSize: 8,
          color: imcColor,
          fontWeight: pw.FontWeight.bold,
        );
        final imc = imcNumerico > 0 ? imcNumerico.toStringAsFixed(1) : '';
        final actividad = medicion.actividadFisica ?? '';

        final rowCells = <pw.Widget>[];

        rowCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(fecha, style: cellStyle),
          ),
        );

        rowCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(peso, style: cellStyle),
          ),
        );

        rowCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(imc, style: imcStyle),
          ),
        );

        rowCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(actividad, style: cellStyle),
          ),
        );

        tableCells.add(pw.TableRow(children: rowCells));
      }

      // Construir columnWidths para tabla principal
      final columnWidths = <int, pw.FlexColumnWidth>{};
      columnWidths[0] = const pw.FlexColumnWidth(1.0); // Fecha
      columnWidths[1] = const pw.FlexColumnWidth(0.8); // Peso
      columnWidths[2] = const pw.FlexColumnWidth(0.8); // IMC
      columnWidths[3] = const pw.FlexColumnWidth(1.5); // Actividad

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

      // Agregar secciones de Medidas corporales y Pliegues para cada medición
      for (final medicion in medicionesDelPaciente) {
        // Medidas corporales
        if (_hasMedidasCorporales(medicion)) {
          rows.add(pw.SizedBox(height: 4));

          // Tabla del título
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
                  decoration: const pw.BoxDecoration(color: _softGreen),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Medidas corporales (cm)',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          );

          // Tabla de datos de medidas
          final medidasHeaders = <pw.Widget>[];
          medidasHeaders.add(_buildHeaderCell('Cadera', headerStyle,
              alignment: pw.Alignment.centerRight));
          medidasHeaders.add(_buildHeaderCell('Cintura', headerStyle,
              alignment: pw.Alignment.centerRight));
          medidasHeaders.add(_buildHeaderCell('Muslo', headerStyle,
              alignment: pw.Alignment.centerRight));
          medidasHeaders.add(_buildHeaderCell('Brazo', headerStyle,
              alignment: pw.Alignment.centerRight));

          final medidasDataCells = <pw.Widget>[];
          medidasDataCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(medicion.cadera?.toStringAsFixed(1) ?? '',
                  style: cellStyle),
            ),
          );
          medidasDataCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(medicion.cintura?.toStringAsFixed(1) ?? '',
                  style: cellStyle),
            ),
          );
          medidasDataCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(medicion.muslo?.toStringAsFixed(1) ?? '',
                  style: cellStyle),
            ),
          );
          medidasDataCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(medicion.brazo?.toStringAsFixed(1) ?? '',
                  style: cellStyle),
            ),
          );

          rows.add(
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.3,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.0),
                1: const pw.FlexColumnWidth(1.0),
                2: const pw.FlexColumnWidth(1.0),
                3: const pw.FlexColumnWidth(1.0),
              },
              children: [
                pw.TableRow(children: medidasHeaders),
                pw.TableRow(children: medidasDataCells),
              ],
            ),
          );
        }

        // Pliegues cutáneos
        if (_hasPlieguesCutaneos(medicion)) {
          rows.add(pw.SizedBox(height: 4));

          // Tabla del título
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
                  decoration: const pw.BoxDecoration(color: _softGreen),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Pliegues cutáneos (mm)',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          );

          // Tabla de datos de pliegues
          final plieguesHeaders = <pw.Widget>[];
          plieguesHeaders.add(_buildHeaderCell('Abdominal', headerStyle,
              alignment: pw.Alignment.centerRight));
          plieguesHeaders.add(_buildHeaderCell('Cuadricipital', headerStyle,
              alignment: pw.Alignment.centerRight));
          plieguesHeaders.add(_buildHeaderCell('Peroneal', headerStyle,
              alignment: pw.Alignment.centerRight));
          plieguesHeaders.add(_buildHeaderCell('Subescapular', headerStyle,
              alignment: pw.Alignment.centerRight));
          plieguesHeaders.add(_buildHeaderCell('Tricipital', headerStyle,
              alignment: pw.Alignment.centerRight));
          plieguesHeaders.add(_buildHeaderCell('Suprailíaco', headerStyle,
              alignment: pw.Alignment.centerRight));

          final plieguesDataCells = <pw.Widget>[];
          plieguesDataCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                  medicion.pliegueAbdominal?.toStringAsFixed(1) ?? '',
                  style: cellStyle),
            ),
          );
          plieguesDataCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                  medicion.pliegueCuadricipital?.toStringAsFixed(1) ?? '',
                  style: cellStyle),
            ),
          );
          plieguesDataCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(medicion.plieguePeroneal?.toStringAsFixed(1) ?? '',
                  style: cellStyle),
            ),
          );
          plieguesDataCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                  medicion.pliegueSubescapular?.toStringAsFixed(1) ?? '',
                  style: cellStyle),
            ),
          );
          plieguesDataCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                  medicion.pligueTricipital?.toStringAsFixed(1) ?? '',
                  style: cellStyle),
            ),
          );
          plieguesDataCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                  medicion.pliegueSuprailiaco?.toStringAsFixed(1) ?? '',
                  style: cellStyle),
            ),
          );

          rows.add(
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.3,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.0),
                1: const pw.FlexColumnWidth(1.0),
                2: const pw.FlexColumnWidth(1.0),
                3: const pw.FlexColumnWidth(1.0),
                4: const pw.FlexColumnWidth(1.0),
                5: const pw.FlexColumnWidth(1.0),
              },
              children: [
                pw.TableRow(children: plieguesHeaders),
                pw.TableRow(children: plieguesDataCells),
              ],
            ),
          );
        }

        // Observación
        if (medicion.observacion != null && medicion.observacion!.isNotEmpty) {
          rows.add(pw.SizedBox(height: 4));

          // Tabla del título
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
                  decoration: const pw.BoxDecoration(color: _softGreen),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Observación',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          );

          // Tabla de datos de observación
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
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(4),
                      child:
                          pw.Text(medicion.observacion ?? '', style: cellStyle),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      }

      rows.add(pw.SizedBox(height: 12));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rows,
    );
  }

  static bool _hasMedidasCorporales(Medicion medicion) {
    return medicion.cadera != null ||
        medicion.cintura != null ||
        medicion.muslo != null ||
        medicion.brazo != null;
  }

  static bool _hasPlieguesCutaneos(Medicion medicion) {
    return medicion.pliegueAbdominal != null ||
        medicion.pliegueCuadricipital != null ||
        medicion.plieguePeroneal != null ||
        medicion.pliegueSubescapular != null ||
        medicion.pligueTricipital != null ||
        medicion.pliegueSuprailiaco != null;
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

  static String _formatFecha(DateTime fecha) {
    final formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(fecha);
  }

  static double _calculateImc(int? altura, double? peso) {
    if (altura == null || peso == null) return 0;
    if (altura <= 0 || peso <= 0) return 0;
    final alturaDouble = altura.toDouble();
    return peso / ((alturaDouble / 100) * (alturaDouble / 100));
  }

  static PdfColor _getImcColor(double imc) {
    if (imc < 18.5) {
      return PdfColors.blue;
    } else if (imc < 25) {
      return PdfColors.green;
    } else if (imc < 30) {
      return PdfColors.orange;
    } else {
      return PdfColors.red;
    }
  }

  static PdfPoint? _parseLogoSize(String? sizeStr) {
    if (sizeStr == null || sizeStr.isEmpty) {
      return null;
    }
    final parts = sizeStr.split('x');
    if (parts.length >= 2) {
      final width = double.tryParse(parts[0].trim());
      final height = double.tryParse(parts[1].trim());
      if (width != null && height != null) {
        return PdfPoint(width, height);
      }
    }
    return null;
  }

  static PdfColor? _parsePdfColor(String colorStr) {
    if (colorStr.isEmpty) return null;
    try {
      final cleanColor = colorStr.replaceAll('#', '').replaceAll('0x', '');
      if (cleanColor.isNotEmpty) {
        final colorValue = int.parse(cleanColor, radix: 16);
        return PdfColor.fromInt(colorValue);
      }
    } catch (_) {}
    return null;
  }
}
