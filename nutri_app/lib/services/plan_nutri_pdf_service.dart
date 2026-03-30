import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/plan_nutri_estructura.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Private data holder for a linked recipe fetched during PDF generation.
class _RecetaData {
  final String titulo;
  final String texto;
  final String? imagenPortada;
  final Map<int, String> imagenesInline;
  final Map<int, _RecetaLinkData> enlacesInline;
  final int orden;

  const _RecetaData({
    required this.titulo,
    required this.texto,
    this.imagenPortada,
    required this.imagenesInline,
    required this.enlacesInline,
    required this.orden,
  });
}

class _RecetaLinkData {
  final String url;
  final String? nombre;

  const _RecetaLinkData({required this.url, this.nombre});
}

class PlanNutriPdfOptions {
  final bool showRecetas;
  final bool showRecomendaciones;
  final bool semanaNuevaPagina;
  final bool showDatosPaciente;
  final bool showImagenesRecetas;
  final bool showEnlacesRecetas;
  final bool horizontal;

  const PlanNutriPdfOptions({
    required this.showRecetas,
    required this.showRecomendaciones,
    required this.semanaNuevaPagina,
    required this.showDatosPaciente,
    required this.showImagenesRecetas,
    required this.showEnlacesRecetas,
    required this.horizontal,
  });
}

class PlanNutriPdfService {
  const PlanNutriPdfService._();
  static const String _pdfOptionsPrefix = 'plan_nutri_pdf';
  static List<pw.Font> _pdfFontFallback = const [];
  static const List<String> _emojiAssetFallbackPaths = [
    'assets/fonts/NotoEmoji-Regular.ttf',
    'assets/fonts/NotoEmoji-Bold.ttf',
    'assets/fonts/NotoEmoji-SemiBold.ttf',
    'assets/fonts/NotoEmoji-Medium.ttf',
    'assets/fonts/NotoEmoji-Light.ttf',
  ];

  static const PdfColor _accentPink = PdfColor.fromInt(0xFFFFC0F4);
  static final RegExp _imageTokenRegex = RegExp(r'\[\[img:(\d+)\]\]');
  static final RegExp _linkTokenRegex = RegExp(r'\[\[enlace:(\d+)\]\]');
  static final RegExp _documentTokenRegex = RegExp(r'\[\[documento:(\d+)\]\]');
  static final RegExp _flowTokenRegex = RegExp(r'\[\[(img|enlace):(\d+)\]\]');

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

  static final RegExp _highlightTokenRegex = RegExp(
    r'👉(?:\uFE0F)?\s*(.*?)\s*👈(?:\uFE0F)?',
    dotAll: true,
  );
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F300}-\u{1F9FF}]|'
    r'[\u{1FA70}-\u{1FAFF}]|'
    r'[\u{1F1E6}-\u{1F1FF}]|'
    r'[\u{2600}-\u{27BF}]|'
    r'[\u{2300}-\u{23FF}]|'
    r'[\u{2000}-\u{206F}]|'
    r'[\u{FE00}-\u{FE0F}]|'
    r'[\u{3000}-\u{303F}]|'
    r'[\u{2070}-\u{209F}]|'
    r'[\u{20A0}-\u{20CF}]|'
    r'[\u{2100}-\u{214F}]|'
    r'[\u{2B50}-\u{2B55}]',
    unicode: true,
  );

  static const List<String> _ingestaOrder = [
    'Desayuno',
    'Almuerzo',
    'Comida',
    'Merienda',
    'Cena',
  ];

  static const List<String> _diasOrder = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static String _pdfDayLabel(String dayName) {
    return _sanitizePdfText(dayName.trim()).toUpperCase();
  }

  // ─── Legacy simple export (used by plan_nutri_paciente_detail_screen) ────────

  static Future<void> export(
    PlanNutricional plan,
    PlanNutriEstructura estructura,
  ) async {
    final theme = await _buildPdfTheme();
    final doc = pw.Document(theme: theme);
    final dateFmt = DateFormat('dd/MM/yyyy');

    String itemLabel(PlanNutriItem item) {
      final titulo = (item.descripcionManual ?? '').trim().isEmpty
          ? 'Sin descripción'
          : item.descripcionManual!.trim();
      final meta = [
        if ((item.cantidad ?? '').trim().isNotEmpty) item.cantidad!.trim(),
        if ((item.unidad ?? '').trim().isNotEmpty) item.unidad!.trim(),
      ].join(' ');
      return meta.isEmpty ? titulo : '$titulo ($meta)';
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          final content = <pw.Widget>[
            pw.Text(
              (estructura.tituloPlan ?? '').trim().isEmpty
                  ? 'Plan nutricional'
                  : estructura.tituloPlan!.trim(),
              style: _textStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Paciente: ${plan.nombrePaciente ?? plan.codigoPaciente ?? ''}',
            ),
            pw.Text(
              'Periodo: ${plan.desde != null ? dateFmt.format(plan.desde!) : '-'} - ${plan.hasta != null ? dateFmt.format(plan.hasta!) : '-'}',
            ),
          ];

          if ((estructura.objetivoPlan ?? '').trim().isNotEmpty) {
            content.add(pw.SizedBox(height: 10));
            content.add(
              pw.Text(
                'Objetivo: ${estructura.objetivoPlan!.trim()}',
                style: _textStyle(fontWeight: pw.FontWeight.bold),
              ),
            );
          }

          if ((estructura.planIndicacionesVisibleUsuario ?? '')
              .trim()
              .isNotEmpty) {
            content.add(pw.SizedBox(height: 10));
            content.add(
              pw.Text(
                'Recomendaciones',
                style: _textStyle(fontWeight: pw.FontWeight.bold),
              ),
            );
            content.add(pw.SizedBox(height: 4));
            content.add(
              pw.Text(estructura.planIndicacionesVisibleUsuario!.trim()),
            );
          }

          if (estructura.recetas.isNotEmpty) {
            content.add(pw.SizedBox(height: 10));
            content.add(
              pw.Text(
                'Recetas',
                style: _textStyle(fontWeight: pw.FontWeight.bold),
              ),
            );
            content.add(pw.SizedBox(height: 4));
            for (final receta in estructura.recetas) {
              content.add(
                pw.Bullet(
                  text: receta.recetaTitulo ?? 'Receta ${receta.codigoReceta}',
                ),
              );
            }
          }

          for (final semana in _sortedWeeks(estructura.semanas)) {
            content.add(pw.SizedBox(height: 14));
            content.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                color: PdfColors.blue100,
                child: pw.Text(
                  'Semana ${semana.numeroSemana}',
                  style: _textStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            );

            for (final dia in semana.dias) {
              content.add(pw.SizedBox(height: 8));
              content.add(
                pw.Text(
                  _pdfDayLabel(dia.nombreDia),
                  style: _textStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              );

              for (final ingesta in dia.ingestas) {
                final items = ingesta.items;
                content.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3, left: 8),
                    child: pw.Text(
                      ingesta.tipoIngesta,
                      style: _textStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey700,
                      ),
                    ),
                  ),
                );
                if (items.isEmpty) {
                  content.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 16, top: 1),
                      child: pw.Text('-', style: _textStyle(fontSize: 10)),
                    ),
                  );
                } else {
                  var opcionIdx = 0;
                  const ords = ['1ª', '2ª', '3ª', '4ª', '5ª', '6ª'];
                  for (final item in items) {
                    final String bulletText;
                    if ((item.opcion ?? '') == 'S') {
                      final ord = opcionIdx < ords.length
                          ? ords[opcionIdx]
                          : '${opcionIdx + 1}ª';
                      opcionIdx++;
                      bulletText = '✔ $ord opción: ${itemLabel(item)}';
                    } else {
                      bulletText = itemLabel(item);
                    }
                    content.add(
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 16, top: 1),
                        child: pw.Bullet(text: bulletText),
                      ),
                    );
                  }
                }
              }
            }
          }

          return content;
        },
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: _buildPdfFileName(plan, estructura),
    );
  }

  // ─── Comprehensive PDF with table, recipes and recommendations ───────────────

  static Future<PlanNutriPdfOptions?> showPdfOptionsDialog({
    required BuildContext context,
    String? dialogTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String key(String suffix) => '${_pdfOptionsPrefix}_$suffix';

    var showRecetas = prefs.getBool(key('show_recetas')) ?? true;
    var showRecomendaciones =
        prefs.getBool(key('show_recomendaciones')) ?? true;
    var semanaNuevaPagina = prefs.getBool(key('semana_nueva_pagina')) ?? false;
    var showDatosPaciente = prefs.getBool(key('show_datos_paciente')) ?? true;
    var showImagenesRecetas =
        prefs.getBool(key('show_imagenes_recetas')) ?? true;
    var showEnlacesRecetas = prefs.getBool(key('show_enlaces_recetas')) ?? true;
    var horizontal = prefs.getBool(key('horizontal')) ?? false;

    return showDialog<PlanNutriPdfOptions>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(dialogTitle ?? 'Opciones del PDF'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        value: showRecetas,
                        onChanged: (value) =>
                            setLocal(() => showRecetas = value),
                        title: const Text('Mostrar recetas'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: showRecomendaciones,
                        onChanged: (value) =>
                            setLocal(() => showRecomendaciones = value),
                        title: const Text('Mostrar recomendaciones'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: semanaNuevaPagina,
                        onChanged: (value) =>
                            setLocal(() => semanaNuevaPagina = value),
                        title: const Text('Semana en nueva página'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: showDatosPaciente,
                        onChanged: (value) =>
                            setLocal(() => showDatosPaciente = value),
                        title: const Text('Mostrar datos paciente'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: showImagenesRecetas,
                        onChanged: (value) =>
                            setLocal(() => showImagenesRecetas = value),
                        title: const Text('Mostrar imágenes en recetas'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: showEnlacesRecetas,
                        onChanged: (value) =>
                            setLocal(() => showEnlacesRecetas = value),
                        title: const Text('Mostrar enlaces en recetas'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Orientación',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      RadioListTile<bool>(
                        value: false,
                        groupValue: horizontal,
                        onChanged: (value) =>
                            setLocal(() => horizontal = value ?? false),
                        title: const Text('Vertical'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<bool>(
                        value: true,
                        groupValue: horizontal,
                        onChanged: (value) =>
                            setLocal(() => horizontal = value ?? false),
                        title: const Text('Horizontal (apaisado)'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    prefs.setBool(key('show_recetas'), showRecetas);
                    prefs.setBool(
                      key('show_recomendaciones'),
                      showRecomendaciones,
                    );
                    prefs.setBool(
                      key('semana_nueva_pagina'),
                      semanaNuevaPagina,
                    );
                    prefs.setBool(
                      key('show_datos_paciente'),
                      showDatosPaciente,
                    );
                    prefs.setBool(
                      key('show_imagenes_recetas'),
                      showImagenesRecetas,
                    );
                    prefs.setBool(
                      key('show_enlaces_recetas'),
                      showEnlacesRecetas,
                    );
                    prefs.setBool(key('horizontal'), horizontal);

                    Navigator.of(dialogContext).pop(
                      PlanNutriPdfOptions(
                        showRecetas: showRecetas,
                        showRecomendaciones: showRecomendaciones,
                        semanaNuevaPagina: semanaNuevaPagina,
                        showDatosPaciente: showDatosPaciente,
                        showImagenesRecetas: showImagenesRecetas,
                        showEnlacesRecetas: showEnlacesRecetas,
                        horizontal: horizontal,
                      ),
                    );
                  },
                  child: const Text('Generar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<void> generateWithOptions({
    required BuildContext context,
    required ApiService apiService,
    required PlanNutricional plan,
    PlanNutriEstructura? estructura,
    List<Map<String, dynamic>> recetasCatalogo = const <Map<String, dynamic>>[],
    Set<int>? recetasSeleccionadas,
    String? recomendaciones,
  }) async {
    final options = await showPdfOptionsDialog(context: context);
    if (options == null) return;

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando PDF…'),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final estructuraPdf =
          estructura ?? await apiService.getPlanNutriEstructura(plan.codigo);
      final recetasPdf = recetasSeleccionadas ??
          estructuraPdf.recetas.map((r) => r.codigoReceta).toSet();

      await generateEstructuraPdf(
        context: context,
        apiService: apiService,
        plan: plan,
        estructura: estructuraPdf,
        recetasCatalogo: recetasCatalogo,
        recetasSeleccionadas: recetasPdf,
        recomendaciones:
            recomendaciones ?? estructuraPdf.planIndicacionesVisibleUsuario,
        showRecetas: options.showRecetas,
        showRecomendaciones: options.showRecomendaciones,
        semanaNuevaPagina: options.semanaNuevaPagina,
        showDatosPaciente: options.showDatosPaciente,
        showImagenesRecetas: options.showImagenesRecetas,
        showEnlacesRecetas: options.showEnlacesRecetas,
        horizontal: options.horizontal,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
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

  static Future<void> generateRecomendacionesPdf({
    required BuildContext context,
    required ApiService apiService,
    required String recomendaciones,
    required String tituloPlan,
    String? pacienteNombre,
  }) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando PDF…'),
        duration: Duration(seconds: 30),
      ),
    );
    try {
      final nutricionistaParam = await apiService.getParametro(
        'nutricionista_nombre',
      );
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      Uint8List? logoBytes;
      String logoSizeStr = '';
      final logoParam = await apiService.getParametro(
        'logotipo_dietista_documentos',
      );
      if (logoParam != null) {
        final logoBase64 = logoParam['valor']?.toString();
        final logoSizeParam = logoParam['valor2']?.toString() ?? '';
        if (logoBase64 != null && logoBase64.trim().isNotEmpty) {
          final decoded = _decodeBase64Image(logoBase64);
          if (decoded != null) {
            logoBytes = decoded;
            logoSizeStr = logoSizeParam;
          }
        }
      }

      final colorParam = await apiService.getParametro(
        'color_fondo_banda_encabezado_pie_pdf',
      );
      final accentColor =
          _parsePdfColor(colorParam?['valor']?.toString()) ?? _accentPink;

      final theme = await _buildPdfTheme();
      final logoSize = _parseLogoSize(logoSizeStr);
      final tituloTexto = _sanitizePdfText(
        tituloPlan.trim().isNotEmpty ? tituloPlan : 'Plan nutricional',
      );

      final pdf = pw.Document(theme: theme);
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 16, 24, 24),
          header: (ctx) => _buildHeader(
            nutricionistaNombre: nutricionistaNombre,
            nutricionistaSubtitulo: nutricionistaSubtitulo,
            logoBytes: logoBytes,
            logoSize: logoSize,
            tituloTexto: tituloTexto,
            pageNumber: ctx.pageNumber,
            accentColor: accentColor,
          ),
          footer: (ctx) => _buildFooter(
            nutricionistaNombre: nutricionistaNombre,
            pageNumber: ctx.pageNumber,
            pageCount: ctx.pagesCount,
            accentColor: accentColor,
            tituloTexto: tituloTexto,
          ),
          build: (ctx) {
            return [
              if ((pacienteNombre ?? '').isNotEmpty) ...[
                pw.Text(
                  'Paciente: ${_sanitizePdfText(pacienteNombre!)}',
                  style: _textStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
              ],
              pw.Text(
                'Recomendaciones',
                style: _textStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                _sanitizePdfText(recomendaciones),
                style: _textStyle(fontSize: 11),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      if (!context.mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'recomendaciones_plan.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
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

  static Future<void> generateEstructuraPdf({
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
    bool showImagenesRecetas = true,
    bool showEnlacesRecetas = true,
    bool horizontal = false,
  }) async {
    try {
      // 1. Parámetros del nutricionista
      final nutricionistaParam = await apiService.getParametro(
        'nutricionista_nombre',
      );
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      Uint8List? logoBytes;
      String logoSizeStr = '';
      final logoParam = await apiService.getParametro(
        'logotipo_dietista_documentos',
      );
      if (logoParam != null) {
        final logoBase64 = logoParam['valor']?.toString();
        final logoSizeParam = logoParam['valor2']?.toString() ?? '';
        if (logoBase64 != null && logoBase64.trim().isNotEmpty) {
          final decoded = _decodeBase64Image(logoBase64);
          if (decoded != null) {
            logoBytes = decoded;
            logoSizeStr = logoSizeParam;
          }
        }
      }

      final colorParam = await apiService.getParametro(
        'color_fondo_banda_encabezado_pie_pdf',
      );
      final accentColor =
          _parsePdfColor(colorParam?['valor']?.toString()) ?? _accentPink;

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

      // 2. Cargar detalle de cada receta seleccionada
      final List<_RecetaData> recetasData = [];
      if (showRecetas) {
        for (final codigo in recetasSeleccionadas) {
          try {
            final recetaResp = await apiService.get(
              'api/recetas.php?codigo=$codigo',
            );
            final docsResp = await apiService.get(
              'api/receta_documentos.php?receta=$codigo',
            );

            if (recetaResp.statusCode == 200) {
              final recetaJson =
                  jsonDecode(recetaResp.body) as Map<String, dynamic>;
              final titulo = recetaJson['titulo']?.toString() ?? '';
              final texto = recetaJson['texto']?.toString() ?? '';
              final imagenPortada = recetaJson['imagen_portada']?.toString();

              final Map<int, String> imagenesInline = {};
              final Map<int, _RecetaLinkData> enlacesInline = {};
              if (docsResp.statusCode == 200) {
                final docsJson = jsonDecode(docsResp.body);
                if (docsJson is List) {
                  for (final doc in docsJson) {
                    final docMap = doc as Map<String, dynamic>;
                    final docCodigo = int.tryParse(
                      docMap['codigo']?.toString() ?? '',
                    );
                    if (docCodigo == null) {
                      continue;
                    }

                    if (docMap['tipo'] == 'imagen') {
                      final docBase64 = docMap['documento']?.toString() ?? '';
                      if (docBase64.isNotEmpty) {
                        imagenesInline[docCodigo] = docBase64;
                      }
                    } else if (docMap['tipo'] == 'url') {
                      final url = (docMap['url'] ?? '').toString().trim();
                      if (url.isNotEmpty) {
                        final nombre =
                            (docMap['nombre'] ?? '').toString().trim();
                        enlacesInline[docCodigo] = _RecetaLinkData(
                          url: url,
                          nombre: nombre.isEmpty ? null : nombre,
                        );
                      }
                    }
                  }
                }
              }

              final vinculada = estructura.recetas
                  .where((r) => r.codigoReceta == codigo)
                  .firstOrNull;
              recetasData.add(
                _RecetaData(
                  titulo: titulo,
                  texto: texto,
                  imagenPortada: imagenPortada,
                  imagenesInline: imagenesInline,
                  enlacesInline: enlacesInline,
                  orden: vinculada?.orden ?? 99,
                ),
              );
            }
          } catch (_) {
            // skip recipe if fetch fails
          }
        }
      }
      recetasData.sort((a, b) => a.orden.compareTo(b.orden));

      // 3. Construir el PDF
      final theme = await _buildPdfTheme();
      final pdf = pw.Document(theme: theme);
      final logoSize = _parseLogoSize(logoSizeStr);
      final dateFmt = DateFormat('dd/MM/yyyy');
      final tituloPlanHeader = _sanitizePdfText(
        (estructura.tituloPlan ?? '').trim().isNotEmpty
            ? estructura.tituloPlan!.trim()
            : 'Plan nutricional',
      );

      final pageFormat =
          horizontal ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.fromLTRB(24, 16, 24, 24),
          header: (ctx) => _buildHeader(
            nutricionistaNombre: nutricionistaNombre,
            nutricionistaSubtitulo: nutricionistaSubtitulo,
            logoBytes: logoBytes,
            logoSize: logoSize,
            tituloTexto: tituloPlanHeader,
            pageNumber: ctx.pageNumber,
            accentColor: accentColor,
          ),
          footer: (ctx) => _buildFooter(
            nutricionistaNombre: nutricionistaNombre,
            pageNumber: ctx.pageNumber,
            pageCount: ctx.pagesCount,
            accentColor: accentColor,
            tituloTexto: tituloPlanHeader,
          ),
          build: (ctx) {
            final content = <pw.Widget>[];

            final pacienteTexto = _sanitizePdfText(
              plan.nombrePaciente ?? plan.codigoPaciente?.toString() ?? '-',
            );
            String? periodoTexto;
            if (plan.desde != null || plan.hasta != null) {
              final desde =
                  plan.desde != null ? dateFmt.format(plan.desde!) : null;
              final hasta =
                  plan.hasta != null ? dateFmt.format(plan.hasta!) : null;
              periodoTexto = (hasta == null || hasta.isEmpty)
                  ? 'Período ${desde ?? '-'}'
                  : 'Período desde ${desde ?? '-'} hasta $hasta';
            }
            final objetivoTexto = _sanitizePdfText(
              estructura.objetivoPlan ?? '',
            );

            if (showDatosPaciente) {
              content.add(
                _buildPlanInfoTable(
                  pacienteTexto: pacienteTexto,
                  periodoTexto: periodoTexto,
                  objetivoTexto: objetivoTexto,
                ),
              );
              content.add(pw.SizedBox(height: 12));
            }

            // Tabla por semana
            var hasWeekTable = false;
            for (final semana in _sortedWeeks(estructura.semanas)) {
              final semTable = _buildSemanaTable(
                semana,
                accentColor,
                horizontal: horizontal,
              );
              if (semTable == null) {
                continue;
              }
              if (semanaNuevaPagina && hasWeekTable) {
                content.add(pw.NewPage());
              }
              content.add(semTable);
              content.add(pw.SizedBox(height: 16));
              hasWeekTable = true;
            }

            // Recomendaciones
            final recom = (recomendaciones ??
                    estructura.planIndicacionesVisibleUsuario ??
                    '')
                .trim();
            if (showRecomendaciones && recom.isNotEmpty) {
              content.add(pw.NewPage());
              content.add(pw.SizedBox(height: 4));
              content.add(
                pw.Center(
                  child: pw.Text(
                    'RECOMENDACIONES',
                    style: _textStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      decoration: pw.TextDecoration.underline,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              );
              content.add(pw.SizedBox(height: 6));
              content.addAll(
                _buildParagraphWidgets(
                  recom,
                  emphasizeMarkedSegments: true,
                  splitOnSingleNewline: true,
                  paragraphSpacing: 14,
                ),
              );
              content.add(pw.SizedBox(height: 16));
            }

            // Recetas
            if (showRecetas && recetasData.isNotEmpty) {
              content.add(pw.NewPage());
              content.add(pw.SizedBox(height: 4));
              content.add(
                pw.Center(
                  child: pw.Text(
                    'RECETAS',
                    style: _textStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      decoration: pw.TextDecoration.underline,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              );
              content.add(pw.SizedBox(height: 8));

              for (final receta in recetasData) {
                // Título arriba (igual que PDF de receta individual), sin emojis
                final tituloSin = _removeEmojis(receta.titulo);
                final portadaImg = showImagenesRecetas
                    ? _decodePdfImage(receta.imagenPortada)
                    : null;

                content.add(
                  pw.Center(
                    child: pw.Text(
                      tituloSin,
                      style: _textStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                );
                content.add(pw.SizedBox(height: 6));

                // Imagen de portada debajo del título
                if (showImagenesRecetas && portadaImg != null) {
                  content.add(
                    pw.Center(
                      child: pw.Container(
                        width: double.infinity,
                        height: 95,
                        child: pw.Image(
                          portadaImg,
                          fit: pw.BoxFit.contain,
                          alignment: pw.Alignment.center,
                        ),
                      ),
                    ),
                  );
                  content.add(pw.SizedBox(height: 10));
                }

                // Texto: quitar emojis preservando 👉👈 para que aparezcan como títulos
                final textoProcessado = _normalizeContextForVisualSections(
                  _removeEmojisKeepingPointers(receta.texto),
                );
                content.addAll(
                  _buildFlowingContent(
                    textoProcessado,
                    imagenesInlineById:
                        showImagenesRecetas ? receta.imagenesInline : const {},
                    enlacesInlineById:
                        showEnlacesRecetas ? receta.enlacesInline : const {},
                    emphasizeMarkedSegments: true,
                    showImages: showImagenesRecetas,
                    showLinks: showEnlacesRecetas,
                  ),
                );

                // URL links from nu_receta_documento (tipo='url') shown at end
                if (showEnlacesRecetas && receta.enlacesInline.isNotEmpty) {
                  final urlLinks = receta.enlacesInline.values.toList();
                  content.add(pw.SizedBox(height: 6));
                  content.add(
                    pw.Text(
                      'Enlaces:',
                      style: _textStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  );
                  content.add(pw.SizedBox(height: 3));
                  for (final linkData in urlLinks) {
                    final widget = _buildRecipeLinkWidget(linkData);
                    if (widget != null) {
                      content.add(widget);
                      content.add(pw.SizedBox(height: 3));
                    }
                  }
                }

                content.add(pw.SizedBox(height: 16));
                content.add(pw.Divider());
                content.add(pw.SizedBox(height: 8));
              }
            }

            // Banda de contacto al final del todo (solo una vez)
            final hasContactInfo = nutricionistaEmail.trim().isNotEmpty ||
                nutricionistaTelegram.trim().isNotEmpty ||
                nutricionistaWebUrl.trim().isNotEmpty ||
                nutricionistaWebLabel.trim().isNotEmpty ||
                nutricionistaInstagramUrl.trim().isNotEmpty ||
                nutricionistaInstagramLabel.trim().isNotEmpty ||
                nutricionistaFacebookUrl.trim().isNotEmpty ||
                nutricionistaFacebookLabel.trim().isNotEmpty;
            if (hasContactInfo) {
              content.add(pw.SizedBox(height: 12));
              content.add(pw.Divider());
              content.add(pw.SizedBox(height: 6));
              content.add(
                _buildContactBand(
                  accentColor: accentColor,
                  email: nutricionistaEmail,
                  telegram: nutricionistaTelegram,
                  webUrl: nutricionistaWebUrl,
                  webLabel: nutricionistaWebLabel,
                  instagramUrl: nutricionistaInstagramUrl,
                  instagramLabel: nutricionistaInstagramLabel,
                  facebookUrl: nutricionistaFacebookUrl,
                  facebookLabel: nutricionistaFacebookLabel,
                ),
              );
            }

            return content;
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName = _buildPdfFileName(plan, estructura);
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      await File(filePath).writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF guardado: $fileName'),
          backgroundColor: Colors.green,
        ),
      );
      final openResult = await OpenFilex.open(filePath);
      if (!context.mounted) return;
      if (openResult.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF generado pero no se pudo abrir automáticamente. Ruta: $filePath',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
          ),
        );
      }
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

  // ─── Table builder ────────────────────────────────────────────────────────────

  static pw.Widget? _buildSemanaTable(
    PlanNutriSemana semana,
    PdfColor accentColor, {
    bool horizontal = false,
  }) {
    final diaByNombre = <String, PlanNutriDia>{};
    for (final dia in semana.dias) {
      diaByNombre[dia.nombreDia] = dia;
    }

    // Solo días que tienen al menos un ítem
    final diasConItems = _diasOrder.where((d) {
      final dia = diaByNombre[d];
      if (dia == null) return false;
      return dia.ingestas.any((ing) => ing.items.isNotEmpty);
    }).toList();

    if (diasConItems.isEmpty) return null;

    // Tipos de ingesta presentes en al menos un día
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

    final headerFontSize = horizontal ? 7.2 : 6.2;
    final mealFontSize = horizontal ? 8.2 : 7.5;
    final cellFontSize = horizontal ? 7.8 : 7.0;
    final mealColWidth = horizontal ? 68.0 : 56.0;

    String normalizeItemText(String raw, {required bool addTrailingDot}) {
      final clean = _sanitizePdfText(raw.trim());
      if (clean.isEmpty || !addTrailingDot) return clean;
      if (clean.endsWith('.') || clean.endsWith('!') || clean.endsWith('?')) {
        return clean;
      }
      return '$clean.';
    }

    final rows = <pw.TableRow>[];

    rows.add(
      pw.TableRow(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            decoration: const pw.BoxDecoration(
              color: PdfColors.lightGreen100,
              border: pw.Border(
                right: pw.BorderSide(color: PdfColors.grey700, width: 0.55),
              ),
            ),
            child: pw.Center(
              child: pw.Text(
                'Sem ${semana.numeroSemana}',
                style: _textStyle(
                  fontSize: headerFontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          ...diasConItems.asMap().entries.map(
                (entry) => pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: accentColor,
                    border: entry.key < diasConItems.length - 1
                        ? const pw.Border(
                            right: pw.BorderSide(
                              color: PdfColors.grey700,
                              width: 0.55,
                            ),
                          )
                        : null,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      _pdfDayLabel(entry.value),
                      style: _textStyle(
                        fontSize: headerFontSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );

    for (final ingestaTipo in ingestasOrdered) {
      final valoresPorDia = <String?>[];
      for (final dNombre in diasConItems) {
        final dia = diaByNombre[dNombre];
        if (dia == null) {
          valoresPorDia.add(null);
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
          valoresPorDia.add(null);
          continue;
        }

        final lines = () {
          final opItems =
              ingestaDia!.items.where((i) => (i.opcion ?? '') == 'S').toList();
          final normItems =
              ingestaDia.items.where((i) => (i.opcion ?? '') != 'S').toList();
          final built = <String>[];
          const ords = ['1ª', '2ª', '3ª', '4ª', '5ª', '6ª'];
          for (var idx = 0; idx < opItems.length; idx++) {
            final ord = idx < ords.length ? ords[idx] : '${idx + 1}ª';
            final name =
                _sanitizePdfText((opItems[idx].descripcionManual ?? '').trim());
            if (name.isNotEmpty) built.add('✔ $ord opción: $name');
          }
          final addDot = normItems.length > 1;
          for (final ni in normItems) {
            final s = normalizeItemText((ni.descripcionManual ?? '').trim(),
                addTrailingDot: addDot);
            if (s.isNotEmpty) built.add(s);
          }
          return built;
        }();
        valoresPorDia.add(lines.isEmpty ? null : lines.join('\n'));
      }

      final allNonEmpty = valoresPorDia.every((v) => v != null && v.isNotEmpty);
      final primerValor = allNonEmpty ? valoresPorDia.first ?? '' : '';
      final sameForAll = allNonEmpty &&
          valoresPorDia.every((v) => (v ?? '').trim() == primerValor.trim());
      final midIndex = diasConItems.length ~/ 2;

      rows.add(
        pw.TableRow(
          children: [
            pw.Container(
              alignment: pw.Alignment.center,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: PdfColors.grey700, width: 0.55),
                ),
              ),
              child: pw.Text(
                ingestaTipo,
                style: _textStyle(
                  fontSize: mealFontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            ...diasConItems.asMap().entries.map((entry) {
              final dayIndex = entry.key;
              final dNombre = entry.value;

              if (sameForAll) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    border: dayIndex < diasConItems.length - 1
                        ? const pw.Border(
                            right: pw.BorderSide(
                              color: PdfColors.grey700,
                              width: 0.55,
                            ),
                          )
                        : null,
                  ),
                  child: dayIndex == midIndex
                      ? pw.Text(
                          primerValor,
                          style: _textStyle(
                            fontSize: cellFontSize,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        )
                      : pw.SizedBox(),
                );
              }

              final dia = diaByNombre[dNombre];
              if (dia == null) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  decoration: pw.BoxDecoration(
                    border: dayIndex < diasConItems.length - 1
                        ? const pw.Border(
                            right: pw.BorderSide(
                              color: PdfColors.grey700,
                              width: 0.55,
                            ),
                          )
                        : null,
                  ),
                  child: pw.SizedBox(),
                );
              }

              PlanNutriIngesta? ingesta;
              for (final ing in dia.ingestas) {
                if (ing.tipoIngesta == ingestaTipo) {
                  ingesta = ing;
                  break;
                }
              }
              if (ingesta == null || ingesta.items.isEmpty) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  decoration: pw.BoxDecoration(
                    border: dayIndex < diasConItems.length - 1
                        ? const pw.Border(
                            right: pw.BorderSide(
                              color: PdfColors.grey700,
                              width: 0.55,
                            ),
                          )
                        : null,
                  ),
                  child: pw.SizedBox(),
                );
              }

              final lines = () {
                final opItems = ingesta!.items
                    .where((i) => (i.opcion ?? '') == 'S')
                    .toList();
                final normItems = ingesta.items
                    .where((i) => (i.opcion ?? '') != 'S')
                    .toList();
                final built = <String>[];
                const ords = ['1ª', '2ª', '3ª', '4ª', '5ª', '6ª'];
                for (var idx = 0; idx < opItems.length; idx++) {
                  final ord = idx < ords.length ? ords[idx] : '${idx + 1}ª';
                  final name = _sanitizePdfText(
                      (opItems[idx].descripcionManual ?? '').trim());
                  if (name.isNotEmpty) built.add('✔ $ord opción: $name');
                }
                final addDot = normItems.length > 1;
                for (final ni in normItems) {
                  final s = normalizeItemText(
                      (ni.descripcionManual ?? '').trim(),
                      addTrailingDot: addDot);
                  if (s.isNotEmpty) built.add(s);
                }
                return built;
              }();

              return pw.Container(
                padding: const pw.EdgeInsets.all(3),
                decoration: pw.BoxDecoration(
                  border: dayIndex < diasConItems.length - 1
                      ? const pw.Border(
                          right: pw.BorderSide(
                            color: PdfColors.grey700,
                            width: 0.55,
                          ),
                        )
                      : null,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: lines
                      .map(
                        (l) => pw.Text(
                          l,
                          style: _textStyle(fontSize: cellFontSize),
                        ),
                      )
                      .toList(),
                ),
              );
            }),
          ],
        ),
      );
    }

    final columnWidths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(mealColWidth),
    };
    for (var i = 0; i < diasConItems.length; i++) {
      columnWidths[i + 1] = const pw.FlexColumnWidth(1);
    }

    return pw.Table(
      border: const pw.TableBorder(
        top: pw.BorderSide(color: PdfColors.grey700, width: 0.55),
        bottom: pw.BorderSide(color: PdfColors.grey700, width: 0.55),
        left: pw.BorderSide(color: PdfColors.grey700, width: 0.55),
        right: pw.BorderSide(color: PdfColors.grey700, width: 0.55),
        horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 0.55),
      ),
      columnWidths: columnWidths,
      children: rows,
    );
  }

  static pw.Widget _buildPlanInfoTable({
    required String pacienteTexto,
    required String? periodoTexto,
    required String objetivoTexto,
  }) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        children: [
          _buildInfoLabelCell('Paciente'),
          _buildInfoValueCell(pacienteTexto),
          _buildInfoLabelCell('Período'),
          _buildInfoValueCell(_sanitizePdfText(periodoTexto ?? '-')),
        ],
      ),
      if (objetivoTexto.trim().isNotEmpty)
        pw.TableRow(
          children: [
            _buildInfoLabelCell('Objetivo'),
            _buildInfoValueCell(objetivoTexto),
            _buildInfoValueCell('', alignRight: false),
            _buildInfoValueCell('', alignRight: false),
          ],
        ),
    ];

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
      ),
      child: pw.Table(
        columnWidths: const {
          0: pw.FixedColumnWidth(54),
          1: pw.FlexColumnWidth(1.6),
          2: pw.FixedColumnWidth(52),
          3: pw.FlexColumnWidth(1.4),
        },
        children: rows,
      ),
    );
  }

  static pw.Widget _buildInfoLabelCell(String label) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(4, 3, 4, 3),
      decoration: const pw.BoxDecoration(color: PdfColors.blue100),
      child: pw.Text(
        label,
        style: _textStyle(fontSize: 8.6, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildInfoValueCell(
    String value, {
    bool alignRight = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(4, 3, 4, 3),
      child: pw.Text(
        value,
        style: _textStyle(fontSize: 8.6),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  // ─── Header / Footer ─────────────────────────────────────────────────────────

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
                      style: _textStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (nutricionistaSubtitulo.trim().isNotEmpty)
                      pw.Text(
                        nutricionistaSubtitulo,
                        style: _textStyle(fontSize: 9),
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
        if (pageNumber == 1) ...[
          pw.Center(
            child: pw.Text(
              tituloTexto,
              style: _textStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 6),
        ],
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
    final footerStyle = _textStyle(fontSize: 9);
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

  static pw.Widget _buildContactBand({
    required PdfColor accentColor,
    required String email,
    required String telegram,
    required String webUrl,
    required String webLabel,
    required String instagramUrl,
    required String instagramLabel,
    required String facebookUrl,
    required String facebookLabel,
  }) {
    String normalizedWeb() {
      final label = _sanitizePdfText(webLabel.trim());
      final url = _sanitizePdfText(webUrl.trim());
      if (label.isNotEmpty) return label;
      return url;
    }

    String normalizedInstagram() {
      final label = _sanitizePdfText(instagramLabel.trim());
      final url = _sanitizePdfText(instagramUrl.trim());
      if (label.isNotEmpty) return label;
      return url;
    }

    String normalizedFacebook() {
      final label = _sanitizePdfText(facebookLabel.trim());
      final url = _sanitizePdfText(facebookUrl.trim());
      if (label.isNotEmpty) return label;
      return url;
    }

    String? emailLink() {
      final raw = email.trim();
      if (raw.isEmpty || !raw.contains('@')) return null;
      return 'mailto:$raw';
    }

    String? telegramLink() {
      final raw = telegram.trim();
      if (raw.isEmpty) return null;
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return raw;
      }
      final username = raw.replaceFirst('@', '').trim();
      if (username.isEmpty) return null;
      return 'https://t.me/$username';
    }

    String? webLink() => _normalizeUrlForPdfLink(webUrl);
    String? instagramLink() => _normalizeUrlForPdfLink(instagramUrl);
    String? facebookLink() => _normalizeUrlForPdfLink(facebookUrl);

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
              _buildContactItem(
                label: 'Email',
                value: email,
                iconText: '@',
                linkUrl: emailLink(),
              ),
              _buildContactItem(
                label: 'Telegram',
                value: telegram,
                iconText: 'TG',
                linkUrl: telegramLink(),
              ),
              _buildContactItem(
                label: 'Web',
                value: normalizedWeb(),
                iconText: 'W',
                linkUrl: webLink(),
              ),
            ],
          ),
          pw.TableRow(
            children: [
              _buildContactItem(
                label: 'Instagram',
                value: normalizedInstagram(),
                iconText: 'IG',
                linkUrl: instagramLink(),
              ),
              _buildContactItem(
                label: 'Facebook',
                value: normalizedFacebook(),
                iconText: 'FB',
                linkUrl: facebookLink(),
              ),
              pw.SizedBox(),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildContactItem({
    required String label,
    required String value,
    required String iconText,
    String? linkUrl,
  }) {
    final safeValue = _sanitizePdfText(value.trim());

    final valueWidget = (safeValue.isNotEmpty && linkUrl != null)
        ? pw.UrlLink(
            destination: linkUrl,
            child: pw.Text(
              safeValue,
              style: _textStyle(
                fontSize: 8,
                color: PdfColors.blue,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          )
        : pw.Text(
            safeValue,
            style: _textStyle(fontSize: 8),
          );

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                width: 16,
                height: 16,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(
                  iconText,
                  style: _textStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                _sanitizePdfText(label),
                style: _textStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          valueWidget,
        ],
      ),
    );
  }

  static String? _normalizeUrlForPdfLink(String rawUrl) {
    final raw = rawUrl.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    return 'https://$raw';
  }

  // ─── Flowing content (inline images + text paragraphs) ───────────────────────

  static List<pw.Widget> _buildFlowingContent(
    String text, {
    Map<int, String>? imagenesInlineById,
    Map<int, _RecetaLinkData>? enlacesInlineById,
    bool emphasizeMarkedSegments = false,
    bool showImages = true,
    bool showLinks = false,
  }) {
    final normalized = _removeHashtagOnlyLines(
      text,
    ).replaceAll('\r\n', '\n').trim();
    final withoutDocuments =
        normalized.replaceAll(_documentTokenRegex, '').trim();
    final withoutLinksIfDisabled = showLinks
        ? withoutDocuments
        : withoutDocuments.replaceAll(_linkTokenRegex, '').trim();

    if (withoutLinksIfDisabled.isEmpty) {
      return [pw.Text('', style: _textStyle(fontSize: 11))];
    }

    final imageMap = imagenesInlineById ?? const <int, String>{};
    final linkMap = enlacesInlineById ?? const <int, _RecetaLinkData>{};
    final hasImages =
        showImages && _imageTokenRegex.hasMatch(withoutLinksIfDisabled);
    final hasLinks =
        showLinks && _linkTokenRegex.hasMatch(withoutLinksIfDisabled);

    if (!hasImages && !hasLinks) {
      return _buildParagraphWidgets(
        withoutLinksIfDisabled,
        emphasizeMarkedSegments: emphasizeMarkedSegments,
      );
    }

    final widgets = <pw.Widget>[];
    int cursor = 0;

    for (final match in _flowTokenRegex.allMatches(withoutLinksIfDisabled)) {
      if (match.start > cursor) {
        widgets.addAll(
          _buildParagraphWidgets(
            withoutLinksIfDisabled.substring(cursor, match.start),
            emphasizeMarkedSegments: emphasizeMarkedSegments,
          ),
        );
      }
      final tokenType = match.group(1);
      final tokenId = int.tryParse(match.group(2) ?? '');

      if (tokenType == 'img' && showImages && tokenId != null) {
        final base64 = imageMap[tokenId];
        final img = _decodePdfImage(base64);
        if (img != null) {
          widgets.add(
            pw.Center(
              child: pw.Container(
                width: double.infinity,
                constraints: const pw.BoxConstraints(maxHeight: 110),
                child: pw.Image(
                  img,
                  fit: pw.BoxFit.contain,
                  alignment: pw.Alignment.center,
                ),
              ),
            ),
          );
        }
        widgets.add(pw.SizedBox(height: 8));
      } else if (tokenType == 'enlace' && showLinks && tokenId != null) {
        final linkData = linkMap[tokenId];
        final linkWidget = _buildRecipeLinkWidget(linkData);
        if (linkWidget != null) {
          widgets.add(linkWidget);
          widgets.add(pw.SizedBox(height: 8));
        }
      }

      cursor = match.end;
    }

    if (cursor < withoutLinksIfDisabled.length) {
      widgets.addAll(
        _buildParagraphWidgets(
          withoutLinksIfDisabled.substring(cursor),
          emphasizeMarkedSegments: emphasizeMarkedSegments,
        ),
      );
    }

    return widgets;
  }

  static List<pw.Widget> _buildParagraphWidgets(
    String text, {
    bool emphasizeMarkedSegments = false,
    bool splitOnSingleNewline = false,
    double paragraphSpacing = 14,
  }) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return [];

    final paragraphSplitRegex =
        splitOnSingleNewline ? RegExp(r'\n+') : RegExp(r'\n{2,}');

    final paragraphs = normalized
        .split(paragraphSplitRegex)
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final widgets = <pw.Widget>[];
    final markerOnlyRegex = RegExp(r'^👉\s*([^👈]+?)\s*👈$');
    for (var i = 0; i < paragraphs.length; i++) {
      if (emphasizeMarkedSegments) {
        // Párrafo que es solo 👉título👈 -> renderizar como título grande
        final markerMatch = markerOnlyRegex.firstMatch(paragraphs[i]);
        if (markerMatch != null) {
          final titleText =
              _sanitizePdfText((markerMatch.group(1) ?? '').trim());
          if (titleText.isNotEmpty) {
            widgets.add(
              pw.Text(
                titleText,
                style: _textStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            );
          }
        } else {
          final rich = _buildRichTextWithMarkers(paragraphs[i]);
          if (rich != null) {
            widgets.add(rich);
          }
        }
      } else {
        for (final chunk in _chunkText(paragraphs[i], 700)) {
          final safeChunk = _sanitizePdfText(chunk);
          if (safeChunk.isEmpty) continue;
          widgets.add(
            pw.Text(
              safeChunk,
              style: _textStyle(fontSize: 11, height: 1.5),
              textAlign: pw.TextAlign.justify,
            ),
          );
        }
      }
      if (i < paragraphs.length - 1) {
        widgets.add(pw.SizedBox(height: paragraphSpacing));
      }
    }
    return widgets;
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

  static String _normalizeContextForVisualSections(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final output = <String>[];
    final sectionLineRegex = RegExp(r'^\s*👉\s*[^👈]+\s*👈\s*$');
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

  static pw.RichText? _buildRichTextWithMarkers(String paragraph) {
    final normalStyle = _textStyle(fontSize: 11, height: 1.5);
    final emphasisStyle = _textStyle(
      fontSize: 12,
      height: 1.5,
      fontWeight: pw.FontWeight.bold,
    );

    final spans = <pw.InlineSpan>[];
    int cursor = 0;

    for (final match in _highlightTokenRegex.allMatches(paragraph)) {
      if (match.start > cursor) {
        final plain = _stripUnsupportedPdfChars(
          paragraph.substring(cursor, match.start),
        );
        if (plain.isNotEmpty) {
          spans.add(pw.TextSpan(text: plain, style: normalStyle));
        }
      }

      final highlighted = _stripUnsupportedPdfChars(match.group(1) ?? '');
      if (highlighted.trim().isNotEmpty) {
        spans.add(pw.TextSpan(text: highlighted, style: emphasisStyle));
      }

      cursor = match.end;
    }

    if (cursor < paragraph.length) {
      final tail = _stripUnsupportedPdfChars(paragraph.substring(cursor));
      if (tail.isNotEmpty) {
        spans.add(pw.TextSpan(text: tail, style: normalStyle));
      }
    }

    if (spans.isEmpty) {
      final plain = _stripUnsupportedPdfChars(paragraph);
      if (plain.isEmpty) return null;
      spans.add(pw.TextSpan(text: plain, style: normalStyle));
    }

    return pw.RichText(
      textAlign: pw.TextAlign.justify,
      text: pw.TextSpan(children: spans),
    );
  }

  static List<String> _chunkText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];
    final chunks = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = (start + maxLen < text.length) ? start + maxLen : text.length;
      if (end < text.length) {
        final lastSpace = text.lastIndexOf(' ', end);
        if (lastSpace > start + 40) end = lastSpace;
      }
      final part = text.substring(start, end).trim();
      if (part.isNotEmpty) chunks.add(part);
      start = end;
    }
    return chunks;
  }

  // ─── Utilities ────────────────────────────────────────────────────────────────

  static pw.TextStyle _textStyle({
    pw.Font? font,
    double? fontSize,
    double? height,
    pw.FontWeight? fontWeight,
    pw.FontStyle? fontStyle,
    PdfColor? color,
    pw.BoxDecoration? background,
    pw.TextDecoration? decoration,
    double? letterSpacing,
    double? wordSpacing,
    List<pw.Font>? fontFallback,
  }) {
    return pw.TextStyle(
      font: font,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      background: background,
      decoration: decoration,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      fontFallback: fontFallback ?? _pdfFontFallback,
    );
  }

  static String _stripUnsupportedPdfChars(String text) {
    return text.replaceAll('�', '');
  }

  static String _removeHashtagOnlyLines(String text) {
    return text.replaceAll('\r\n', '\n').split('\n').where((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return true;
      final words = trimmed
          .split(RegExp(r'\s+'))
          .map((word) => word.trim())
          .where((word) => word.isNotEmpty)
          .toList();
      if (words.isEmpty) return true;
      final allHashtags = words.every((word) => word.startsWith('#'));
      return !allHashtags;
    }).join('\n');
  }

  static String _sanitizePdfText(String text) {
    final cleaned = _stripUnsupportedPdfChars(text);
    return cleaned
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .join('\n');
  }

  static String _removeEmojis(String text) {
    final cleaned = text.replaceAll(_emojiRegex, '').replaceAll('�', '');
    return cleaned
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .join('\n');
  }

  static Future<pw.ThemeData> _buildPdfTheme() async {
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();
    final boldItalic = await PdfGoogleFonts.notoSansBoldItalic();

    final fallbacks = <pw.Font>[];

    Future<void> addSystemFallback(String path) async {
      try {
        final file = File(path);
        if (!file.existsSync()) return;
        final bytes = await file.readAsBytes();
        fallbacks.add(pw.Font.ttf(bytes.buffer.asByteData()));
      } catch (_) {
        // If a local system font cannot be loaded, continue with other options.
      }
    }

    Future<void> addFallback(Future<pw.Font> Function() loader) async {
      try {
        fallbacks.add(await loader());
      } catch (_) {
        // If a fallback font cannot be downloaded, keep generating the PDF.
      }
    }

    Future<void> addAssetFallback(String assetPath) async {
      try {
        final data = await rootBundle.load(assetPath);
        fallbacks.add(
          pw.Font.ttf(
            data.buffer.asByteData(data.offsetInBytes, data.lengthInBytes),
          ),
        );
      } catch (_) {
        // If an asset font does not exist, continue with other fallbacks.
      }
    }

    for (final assetPath in _emojiAssetFallbackPaths) {
      await addAssetFallback(assetPath);
    }

    if (!kIsWeb) {
      if (Platform.isWindows) {
        await addSystemFallback(r'C:\Windows\Fonts\seguiemj.ttf');
        await addSystemFallback(r'C:\Windows\Fonts\seguisym.ttf');
      } else if (Platform.isAndroid) {
        await addSystemFallback('/system/fonts/NotoColorEmoji.ttf');
      } else if (Platform.isMacOS) {
        // Apple Color Emoji is a TTC – the pdf package may or may not load it;
        // the try/catch in addSystemFallback handles a graceful failure.
        await addSystemFallback('/System/Library/Fonts/Apple Color Emoji.ttc');
        await addSystemFallback('/Library/Fonts/Apple Color Emoji.ttc');
      } else if (Platform.isLinux) {
        await addSystemFallback(
          '/usr/share/fonts/noto-emoji/NotoColorEmoji.ttf',
        );
        await addSystemFallback(
          '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
        );
        await addSystemFallback('/usr/share/fonts/noto/NotoColorEmoji.ttf');
      }
      // iOS: fonts are sandboxed; fall through to Google Fonts below.
    }

    await addFallback(PdfGoogleFonts.notoEmojiRegular);
    await addFallback(PdfGoogleFonts.notoColorEmojiRegular);
    await addFallback(PdfGoogleFonts.notoSansSymbols2Regular);

    _pdfFontFallback = List<pw.Font>.unmodifiable(fallbacks);

    return pw.ThemeData.withFont(
      base: base,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
      fontFallback: _pdfFontFallback,
    );
  }

  static pw.Widget? _buildRecipeLinkWidget(_RecetaLinkData? linkData) {
    if (linkData == null) return null;
    final rawUrl = linkData.url.trim();
    if (rawUrl.isEmpty) return null;

    var destination = rawUrl;
    final hasProtocol =
        destination.startsWith('http://') || destination.startsWith('https://');
    if (!hasProtocol) {
      destination = 'https://$destination';
    }

    final label = (linkData.nombre ?? '').trim().isEmpty
        ? rawUrl
        : linkData.nombre!.trim();

    return pw.Align(
      alignment: pw.Alignment.centerLeft,
      child: pw.UrlLink(
        destination: destination,
        child: pw.Text(
          _sanitizePdfText(label),
          style: _textStyle(
            fontSize: 11,
            color: PdfColors.blue,
            decoration: pw.TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  static String _buildPdfFileName(
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

    return 'Plan_Nutricional_${tituloPlan}_$paciente.pdf';
  }

  static String _sanitizeFileNamePart(String value) {
    final base = _removeEmojis(value).trim();
    if (base.isEmpty) return 'Sin_texto';

    var normalized = base
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

  static PdfPoint? _parseLogoSize(String? sizeStr) {
    if (sizeStr == null || sizeStr.trim().isEmpty) {
      return const PdfPoint(42, 30);
    }
    final parts = sizeStr.split('x');
    if (parts.length == 2) {
      final w = double.tryParse(parts[0].trim());
      final h = double.tryParse(parts[1].trim());
      if (w != null && h != null) return PdfPoint(w, h);
    }
    return const PdfPoint(42, 30);
  }

  static PdfColor? _parsePdfColor(String? value) {
    if (value == null) return null;
    var raw = value.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('#')) raw = raw.substring(1);
    if (raw.length != 6 && raw.length != 8) return null;
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return null;
    final argb = raw.length == 6 ? (0xFF000000 | parsed) : parsed;
    return PdfColor.fromInt(argb);
  }
}
