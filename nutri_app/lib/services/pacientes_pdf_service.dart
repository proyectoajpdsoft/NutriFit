import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/cobro.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PacientesPdfService {
  const PacientesPdfService._();

  static const PdfColor _accentPink = PdfColor.fromInt(0xFFFFC0F4);

  static Future<void> generatePacientesPdf({
    required BuildContext context,
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    Uint8List? logoBytes,
    required String logoSizeStr,
    required String accentColorStr,
    required List<Paciente> pacientes,
    required List<Cobro> cobros,
    required String filtroActivo,
  }) async {
    try {
      final logoSize = _parseLogoSize(logoSizeStr);
      final accentColor = _parsePdfColor(accentColorStr) ?? _accentPink;

      final pdf = pw.Document();
      final tituloTexto = _buildTitleFromFilter(filtroActivo);

      // Map cobros por paciente para rápido acceso
      final cobrosPorPaciente = <int, double>{};
      for (final cobro in cobros) {
        if (cobro.codigoPaciente != null) {
          cobrosPorPaciente[cobro.codigoPaciente!] =
              (cobrosPorPaciente[cobro.codigoPaciente!] ?? 0) + cobro.importe;
        }
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
            _buildPacientesTable(pacientes, cobrosPorPaciente, filtroActivo),
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
    return 'PACIENTES ($estado)';
  }

  static String _buildFileName(String filtroActivo) {
    return 'Pacientes.pdf';
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

  static pw.Widget _buildPacientesTable(
    List<Paciente> pacientes,
    Map<int, double> cobrosPorPaciente,
    String filtroActivo,
  ) {
    final headerStyle =
        pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    const cellStyle = pw.TextStyle(fontSize: 8);
    final cobroStyle = pw.TextStyle(fontSize: 8, font: pw.Font.courier());

    // Determinar qué columnas mostrar
    final mostrarFechaNacimiento =
        pacientes.any((p) => p.fechaNacimiento != null);
    final mostrarEdad = pacientes.any((p) => p.edad != null);
    final mostrarAltura = pacientes.any((p) => p.altura != null);
    final mostrarPeso = pacientes.any((p) => p.peso != null);
    final mostrarActivo = filtroActivo != 'S';

    final rows = <pw.TableRow>[];

    // Construir header dinámicamente
    final headerCells = <pw.Widget>[];
    headerCells.add(_buildHeaderCell('Nombre', headerStyle));
    headerCells.add(
        _buildHeaderCell('Sexo', headerStyle, alignment: pw.Alignment.center));
    if (mostrarFechaNacimiento) {
      headerCells.add(_buildHeaderCell('F. nacim.', headerStyle,
          alignment: pw.Alignment.centerRight));
    }
    if (mostrarEdad) {
      headerCells.add(_buildHeaderCell('Edad', headerStyle,
          alignment: pw.Alignment.centerRight));
    }
    if (mostrarAltura) {
      headerCells.add(_buildHeaderCell('Altura', headerStyle,
          alignment: pw.Alignment.centerRight));
    }
    if (mostrarPeso) {
      headerCells.add(_buildHeaderCell('Peso', headerStyle,
          alignment: pw.Alignment.centerRight));
    }
    headerCells.add(_buildHeaderCell('IMC', headerStyle,
        alignment: pw.Alignment.centerRight));
    if (mostrarActivo) {
      headerCells.add(_buildHeaderCell('Activo', headerStyle,
          alignment: pw.Alignment.center));
    }
    headerCells.add(_buildHeaderCell('Cobrado', headerStyle,
        alignment: pw.Alignment.centerRight));

    rows.add(pw.TableRow(children: headerCells));

    // Data rows
    for (final paciente in pacientes) {
      final nombre = paciente.nombre;
      final sexo = _formatSexo(paciente.sexo);
      final fechaNacimiento = _formatFechaNacimiento(paciente.fechaNacimiento);
      final edad = paciente.edad?.toString() ?? '';
      final altura = paciente.altura?.toString() ?? '';
      final peso = paciente.peso?.toStringAsFixed(2) ?? '';
      final imc = _calculateImc(paciente.altura, paciente.peso);
      final imcNumerico = _calculateImcNumeric(paciente.altura, paciente.peso);
      final imcColor = _getImcColor(imcNumerico);
      final imcStyle = pw.TextStyle(
          fontSize: 8, color: imcColor, fontWeight: pw.FontWeight.bold);
      final activo = paciente.activo == 'S' ? 'Sí' : 'No';
      final cobrado = _formatCobrado(cobrosPorPaciente[paciente.codigo] ?? 0.0);

      final dataCells = <pw.Widget>[];

      // Nombre
      dataCells.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          alignment: pw.Alignment.topLeft,
          child: pw.Text(nombre, style: cellStyle),
        ),
      );

      // Sexo
      dataCells.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          alignment: pw.Alignment.center,
          child: pw.Text(sexo, style: cellStyle),
        ),
      );

      // Fecha Nacimiento (si se muestra)
      if (mostrarFechaNacimiento) {
        dataCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.topRight,
            child: pw.Text(fechaNacimiento, style: cellStyle),
          ),
        );
      }

      // Edad (si se muestra)
      if (mostrarEdad) {
        dataCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.topRight,
            child: pw.Text(edad, style: cellStyle),
          ),
        );
      }

      // Altura (si se muestra)
      if (mostrarAltura) {
        dataCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.topRight,
            child: pw.Text(altura, style: cellStyle),
          ),
        );
      }

      // Peso (si se muestra)
      if (mostrarPeso) {
        dataCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.topRight,
            child: pw.Text(peso, style: cellStyle),
          ),
        );
      }

      // IMC (siempre)
      dataCells.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          alignment: pw.Alignment.topRight,
          child: pw.Text(imc, style: imcStyle),
        ),
      );

      // Activo (si se muestra)
      if (mostrarActivo) {
        dataCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.center,
            child: pw.Text(activo, style: cellStyle),
          ),
        );
      }

      // Cobrado (siempre)
      dataCells.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          alignment: pw.Alignment.topRight,
          child: pw.Text(cobrado, style: cobroStyle),
        ),
      );

      rows.add(pw.TableRow(children: dataCells));
    }

    // Construir columnWidths dinámicamente
    final columnWidths = <int, pw.FlexColumnWidth>{};
    int colIndex = 0;
    columnWidths[colIndex++] = const pw.FlexColumnWidth(2.0); // Nombre
    columnWidths[colIndex++] = const pw.FlexColumnWidth(0.6); // Sexo
    if (mostrarFechaNacimiento) {
      columnWidths[colIndex++] = const pw.FlexColumnWidth(1.0); // F. Nacimiento
    }
    if (mostrarEdad) {
      columnWidths[colIndex++] = const pw.FlexColumnWidth(0.8); // Edad
    }
    if (mostrarAltura) {
      columnWidths[colIndex++] = const pw.FlexColumnWidth(0.8); // Altura
    }
    if (mostrarPeso) {
      columnWidths[colIndex++] = const pw.FlexColumnWidth(0.8); // Peso
    }
    columnWidths[colIndex++] = const pw.FlexColumnWidth(0.8); // IMC
    if (mostrarActivo) {
      columnWidths[colIndex++] = const pw.FlexColumnWidth(0.8); // Activo
    }
    columnWidths[colIndex++] = const pw.FlexColumnWidth(1.2); // Cobrado

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
        width: 0.3,
      ),
      columnWidths: columnWidths,
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

  static String _formatSexo(String? sexo) {
    if (sexo == null) return '';
    final upper = sexo.toUpperCase();
    if (upper.contains('H')) return 'H';
    if (upper.contains('M') || upper.contains('F')) return 'M';
    return upper.isNotEmpty ? upper[0] : '';
  }

  static String _formatFechaNacimiento(DateTime? fecha) {
    if (fecha == null) return '';
    final formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(fecha);
  }

  static String _calculateImc(int? alturaEmCm, double? pesoEnKg) {
    if (alturaEmCm == null || pesoEnKg == null || alturaEmCm == 0) {
      return '';
    }
    final alturaEnM = alturaEmCm / 100.0;
    final imc = pesoEnKg / (alturaEnM * alturaEnM);
    return imc.toStringAsFixed(2);
  }

  static double _calculateImcNumeric(int? alturaEmCm, double? pesoEnKg) {
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

  static String _formatCobrado(double importe) {
    final formatter = NumberFormat('#,##0.00', 'es_ES');
    final formatted = formatter.format(importe);
    return '$formatted EUR';
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
