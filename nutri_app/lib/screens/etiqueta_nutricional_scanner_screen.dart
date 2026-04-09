import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/screens/contacto_nutricionista_screen.dart';
import 'package:nutri_app/services/open_food_product_pdf_service.dart';
import 'package:nutri_app/services/menu_visibility_premium_service.dart';
import 'package:nutri_app/services/user_settings_service.dart';
import 'package:nutri_app/widgets/image_viewer_dialog.dart'
    show showImageViewerDialog;
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/widgets/premium_feature_dialog_helper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EtiquetaNutricionalScannerScreen extends StatefulWidget {
  const EtiquetaNutricionalScannerScreen({super.key});

  @override
  State<EtiquetaNutricionalScannerScreen> createState() =>
      _EtiquetaNutricionalScannerScreenState();
}

enum _ScannerDetectionMode { auto, barcode, ocr }

class _EtiquetaNutricionalScannerScreenState
    extends State<EtiquetaNutricionalScannerScreen> {
  static const String _trainingPrefsKey = 'ocr_training_entries_v1';
  static const String _trainingRemoteParamName = 'ocr_training_rules_json';
  static const String _detectionModePrefsKey = 'scanner_detection_mode_v1';
  static const String _infoBannerExpandedPrefsKey =
      'scanner_info_banner_expanded_v1';
  static const String _autoHintDismissedKey = 'scanner_hint_auto_v1';
  static const String _barcodeHintDismissedKey = 'scanner_hint_barcode_v1';
  static const String _ocrHintDismissedKey = 'scanner_hint_ocr_v1';
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();

  File? _imagenSeleccionada;
  bool _analizando = false;
  String _textoDetectado = '';
  NutrientesPorPorcion? _nutrientes;
  _OpenFoodFactsProduct? _productoOpenFood;
  String? _barcodeDetectado;
  String _fuenteLectura = '';
  _ScannerDetectionMode _detectionMode = _ScannerDetectionMode.auto;
  bool _modoEntrenamiento = false;
  bool _aprendizajeAplicado = false;
  bool _infoBannerExpanded = true;
  bool _autoHintDismissed = false;
  bool _barcodeHintDismissed = false;
  bool _ocrHintDismissed = false;
  List<_OcrTrainingEntry> _trainingEntries = const [];
  bool _scannerPremiumEnabled = false;

  @override
  void initState() {
    super.initState();
    _cargarModoDeteccion();
    _cargarEstadoInfoBanner();
    _cargarEstadoHints();
    _cargarEntrenamiento();
    _sincronizarReglasRemotasSilencioso();
    _loadMenuPremiumConfig();
  }

  Future<void> _loadMenuPremiumConfig() async {
    try {
      final config = await MenuVisibilityPremiumService.loadConfig(
        apiService: context.read<ApiService>(),
        forceRefresh: true,
      );
      final premiumEnabled = MenuVisibilityPremiumService.isPremium(
        config,
        MenuVisibilityPremiumService.escaner,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _scannerPremiumEnabled = premiumEnabled;
      });
    } catch (_) {}
  }

  bool _canUseScannerPremiumActions(AuthService authService) {
    if (!_scannerPremiumEnabled) {
      return true;
    }
    return authService.isPremium || _esUsuarioAdmin(authService);
  }

  Future<void> _showScannerPremiumRequired() {
    final l10n = AppLocalizations.of(context)!;
    return PremiumFeatureDialogHelper.show(
      context,
      message: l10n.scannerPremiumRequiredMessage,
    );
  }

  String _serializeDetectionMode(_ScannerDetectionMode mode) {
    switch (mode) {
      case _ScannerDetectionMode.auto:
        return 'auto';
      case _ScannerDetectionMode.barcode:
        return 'barcode';
      case _ScannerDetectionMode.ocr:
        return 'ocr';
    }
  }

  _ScannerDetectionMode _parseDetectionMode(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'barcode':
        return _ScannerDetectionMode.barcode;
      case 'ocr':
        return _ScannerDetectionMode.ocr;
      case 'auto':
      default:
        return _ScannerDetectionMode.auto;
    }
  }

  Future<void> _cargarModoDeteccion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_detectionModePrefsKey);
    final mode = _parseDetectionMode(raw);
    if (!mounted) return;
    setState(() {
      _detectionMode = mode;
    });
  }

  Future<void> _guardarModoDeteccion(_ScannerDetectionMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _detectionModePrefsKey, _serializeDetectionMode(mode));
  }

  Future<void> _cargarEstadoInfoBanner() async {
    final prefs = await SharedPreferences.getInstance();
    final isExpanded = prefs.getBool(_infoBannerExpandedPrefsKey) ?? true;
    if (!mounted) return;
    setState(() {
      _infoBannerExpanded = isExpanded;
    });
  }

  Future<void> _guardarEstadoInfoBanner(bool isExpanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_infoBannerExpandedPrefsKey, isExpanded);
  }

  Future<void> _toggleInfoBannerExpanded() async {
    final next = !_infoBannerExpanded;
    if (!mounted) return;
    setState(() {
      _infoBannerExpanded = next;
    });
    await _guardarEstadoInfoBanner(next);
  }

  Future<void> _cargarEstadoHints() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoHintDismissed = prefs.getBool(_autoHintDismissedKey) ?? false;
      _barcodeHintDismissed = prefs.getBool(_barcodeHintDismissedKey) ?? false;
      _ocrHintDismissed = prefs.getBool(_ocrHintDismissedKey) ?? false;
    });
  }

  Future<void> _dismissModeHint(_ScannerDetectionMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = mode == _ScannerDetectionMode.auto
        ? _autoHintDismissedKey
        : mode == _ScannerDetectionMode.barcode
            ? _barcodeHintDismissedKey
            : _ocrHintDismissedKey;
    await prefs.setBool(key, true);
    if (!mounted) return;
    setState(() {
      if (mode == _ScannerDetectionMode.auto) {
        _autoHintDismissed = true;
      } else if (mode == _ScannerDetectionMode.barcode)
        _barcodeHintDismissed = true;
      else
        _ocrHintDismissed = true;
    });
  }

  Future<void> _restoreModeHint(_ScannerDetectionMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = mode == _ScannerDetectionMode.auto
        ? _autoHintDismissedKey
        : mode == _ScannerDetectionMode.barcode
            ? _barcodeHintDismissedKey
            : _ocrHintDismissedKey;
    await prefs.setBool(key, false);
    if (!mounted) return;
    setState(() {
      if (mode == _ScannerDetectionMode.auto) {
        _autoHintDismissed = false;
      } else if (mode == _ScannerDetectionMode.barcode)
        _barcodeHintDismissed = false;
      else
        _ocrHintDismissed = false;
    });
  }

  Future<void> _cargarEntrenamiento() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_trainingPrefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      final entries = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(_OcrTrainingEntry.fromJson)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _trainingEntries = entries;
      });
    } catch (_) {
      // Ignoramos datos corruptos de entrenamiento
    }
  }

  Future<void> _guardarEntrenamiento() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      _trainingEntries.map((entry) => entry.toJson()).toList(growable: false),
    );
    await prefs.setString(_trainingPrefsKey, payload);
  }

  Future<void> _sincronizarReglasRemotasSilencioso() async {
    try {
      final entries = await _descargarReglasServidorPreferente();
      if (entries.isEmpty) {
        return;
      }

      if (!mounted) return;
      setState(() {
        _trainingEntries = entries;
      });
      await _guardarEntrenamiento();
    } catch (_) {
      // Sincronización best-effort: no interrumpe UI si falla.
    }
  }

  Future<List<_OcrTrainingEntry>> _descargarReglasServidorPreferente() async {
    try {
      final response = await _apiService.get('api/ocr_reglas.php');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> rows;
        if (decoded is Map<String, dynamic> && decoded['rules'] is List) {
          rows = decoded['rules'] as List<dynamic>;
        } else if (decoded is List) {
          rows = decoded;
        } else {
          rows = const [];
        }

        return rows
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .map(_OcrTrainingEntry.fromJson)
            .toList(growable: false);
      }
    } catch (_) {
      // Fallback legacy
    }

    final value = await _apiService.getParametroValor(_trainingRemoteParamName);
    if (value == null || value.trim().isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(value);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(_OcrTrainingEntry.fromJson)
        .toList(growable: false);
  }

  Future<void> _limpiarEntrenamiento() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.scannerClearTrainingTitle),
        content: Text(
          l10n.scannerClearTrainingBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.commonClear),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trainingPrefsKey);
    if (!mounted) return;
    setState(() {
      _trainingEntries = const [];
      _aprendizajeAplicado = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.scannerLocalTrainingRemoved),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _exportarEntrenamientoDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final payload = jsonEncode(
      _trainingEntries.map((entry) => entry.toJson()).toList(growable: false),
    );

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.scannerExportRulesTitle),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: SelectableText(
              payload,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Future<void> _importarEntrenamientoDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final imported = await showDialog<List<_OcrTrainingEntry>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.scannerImportRulesTitle),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            maxLines: 12,
            decoration: InputDecoration(
              hintText: l10n.scannerImportRulesHint,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final decoded = jsonDecode(controller.text);
                if (decoded is! List) {
                  throw FormatException(l10n.scannerInvalidFormat);
                }
                final entries = decoded
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .map(_OcrTrainingEntry.fromJson)
                    .toList(growable: false);
                Navigator.pop(context, entries);
              } catch (_) {
                Navigator.pop(context, null);
              }
            },
            child: Text(l10n.commonImport),
          ),
        ],
      ),
    );
    controller.dispose();

    if (imported == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scannerInvalidJsonOrCanceled)),
      );
      return;
    }

    setState(() {
      _trainingEntries = imported;
    });
    await _guardarEntrenamiento();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.scannerImportedRulesCount(imported.length)),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _subirReglasServidor() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final body = jsonEncode({
        'replace': true,
        'entries': _trainingEntries.map((entry) => entry.toJson()).toList(),
      });

      final response = await _apiService.put('api/ocr_reglas.php', body: body);

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.scannerRulesUploaded),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(l10n.scannerRulesUploadError(e.toString()))),
      );
    }
  }

  Future<void> _bajarReglasServidor() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final entries = await _descargarReglasServidorPreferente();
      if (entries.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.scannerNoRemoteRules)),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _trainingEntries = entries;
      });
      await _guardarEntrenamiento();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.scannerDownloadedRulesCount(entries.length)),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(l10n.scannerRulesDownloadError(e.toString()))),
      );
    }
  }

  String _normalizarFirma(String raw) {
    var text = raw.toLowerCase();
    const replacements = {
      'â': 'a',
      'ã': 'a',
      'å': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
      'ß': 'ss',
    };
    replacements.forEach((source, target) {
      text = text.replaceAll(source, target);
    });
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  Set<String> _extraerTokensFirma(String raw) {
    final normalized = _normalizarFirma(raw);
    if (normalized.isEmpty) {
      return <String>{};
    }

    const stopwords = {
      'de',
      'del',
      'la',
      'el',
      'los',
      'las',
      'por',
      'per',
      'pour',
      'pro',
      'and',
      'con',
      'neto',
      'peso',
      'valor',
      'which',
      'dos',
      'das',
      'the',
      'ing',
    };

    final tokens = normalized
        .split(' ')
        .where((token) => token.length >= 4 && !stopwords.contains(token))
        .toSet();

    const preferred = {
      'informacion',
      'nutricional',
      'nutrition',
      'nutritional',
      'azucar',
      'azucares',
      'sugar',
      'sal',
      'salt',
      'grasas',
      'fat',
      'proteina',
      'protein',
      'sodio',
      'sodium',
      'energia',
      'energy',
      'hidratos',
      'carbohydrate',
      'carbohydrates',
      '100g',
      '100ml',
    };

    for (final token in preferred) {
      if (normalized.contains(token)) {
        tokens.add(token);
      }
    }

    return tokens;
  }

  double _similitudTokens(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) {
      return 0;
    }
    final inter = a.intersection(b).length;
    final union = a.union(b).length;
    if (union == 0) {
      return 0;
    }
    return inter / union;
  }

  _OcrTrainingEntry? _buscarMejorEntrenamiento(String ocrText) {
    final tokens = _extraerTokensFirma(ocrText);
    _OcrTrainingEntry? best;
    double bestScore = 0;

    for (final entry in _trainingEntries) {
      final score = _similitudTokens(tokens, entry.tokens);
      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }

    if (bestScore >= 0.45) {
      return best;
    }
    return null;
  }

  NutrientesPorPorcion _aplicarEntrenamientoSiExiste(
    String rawText,
    NutrientesPorPorcion base,
  ) {
    final entry = _buscarMejorEntrenamiento(rawText);
    if (entry == null) {
      _aprendizajeAplicado = false;
      return base;
    }

    _aprendizajeAplicado = true;
    return base.copyWith(
      azucarGr: entry.azucarGr,
      salGr: entry.salGr,
      grasasGr: entry.grasasGr,
      proteinaGr: entry.proteinaGr,
      porcionGr: entry.porcionGr,
    );
  }

  Future<void> _marcarResultadoCorrecto() async {
    final l10n = AppLocalizations.of(context)!;
    if (_textoDetectado.trim().isEmpty || _nutrientes == null) {
      return;
    }

    final tokens = _extraerTokensFirma(_textoDetectado);
    if (tokens.isEmpty) {
      return;
    }

    final current = _nutrientes!;
    final entry = _OcrTrainingEntry(
      tokens: tokens,
      azucarGr: current.azucarGr,
      salGr: current.salGr,
      grasasGr: current.grasasGr,
      proteinaGr: current.proteinaGr,
      porcionGr: current.porcionGr,
      updatedAtIso: DateTime.now().toIso8601String(),
    );

    setState(() {
      _trainingEntries = [..._trainingEntries, entry];
    });
    await _guardarEntrenamiento();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.scannerTrainingMarkedCorrect),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _corregirLecturaDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final current = _nutrientes;
    if (current == null || _textoDetectado.trim().isEmpty) {
      return;
    }

    final azucarCtrl = TextEditingController(
      text: current.azucarGr?.toStringAsFixed(2) ?? '',
    );
    final salCtrl = TextEditingController(
      text: current.salGr?.toStringAsFixed(2) ?? '',
    );
    final grasasCtrl = TextEditingController(
      text: current.grasasGr?.toStringAsFixed(2) ?? '',
    );
    final proteinaCtrl = TextEditingController(
      text: current.proteinaGr?.toStringAsFixed(2) ?? '',
    );
    final porcionCtrl = TextEditingController(
      text: current.porcionGr?.toStringAsFixed(2) ?? '',
    );

    double? parseOrNull(String value) {
      final cleaned = value.replaceAll(',', '.').trim();
      if (cleaned.isEmpty) return null;
      return double.tryParse(cleaned);
    }

    final corrected = await showDialog<NutrientesPorPorcion>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.scannerCorrectOcrValuesTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTrainingField(l10n.scannerSugarField, azucarCtrl),
              _buildTrainingField(l10n.scannerSaltField, salCtrl),
              _buildTrainingField(l10n.scannerFatField, grasasCtrl),
              _buildTrainingField(l10n.scannerProteinField, proteinaCtrl),
              _buildTrainingField(l10n.scannerPortionField, porcionCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                NutrientesPorPorcion(
                  azucarGr: parseOrNull(azucarCtrl.text),
                  salGr: parseOrNull(salCtrl.text),
                  grasasGr: parseOrNull(grasasCtrl.text),
                  proteinaGr: parseOrNull(proteinaCtrl.text),
                  porcionGr: parseOrNull(porcionCtrl.text),
                ),
              );
            },
            child: Text(l10n.scannerSaveCorrection),
          ),
        ],
      ),
    );

    azucarCtrl.dispose();
    salCtrl.dispose();
    grasasCtrl.dispose();
    proteinaCtrl.dispose();
    porcionCtrl.dispose();

    if (corrected == null) {
      return;
    }

    final tokens = _extraerTokensFirma(_textoDetectado);
    if (tokens.isEmpty) {
      return;
    }

    final entry = _OcrTrainingEntry(
      tokens: tokens,
      azucarGr: corrected.azucarGr,
      salGr: corrected.salGr,
      grasasGr: corrected.grasasGr,
      proteinaGr: corrected.proteinaGr,
      porcionGr: corrected.porcionGr,
      updatedAtIso: DateTime.now().toIso8601String(),
    );

    setState(() {
      _nutrientes = corrected;
      _trainingEntries = [..._trainingEntries, entry];
    });
    await _guardarEntrenamiento();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Corrección guardada. Se aplicará a etiquetas similares.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildTrainingField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Future<String?> _detectarCodigoBarras(InputImage inputImage) async {
    final scanner = BarcodeScanner();
    try {
      final barcodes = await scanner.processImage(inputImage);
      for (final barcode in barcodes) {
        final candidate =
            (barcode.rawValue ?? barcode.displayValue ?? '').trim();
        if (candidate.isEmpty) continue;

        final onlyDigits = candidate.replaceAll(RegExp(r'[^0-9]'), '');
        if (onlyDigits.length >= 8 && onlyDigits.length <= 14) {
          return onlyDigits;
        }
      }
      return null;
    } finally {
      await scanner.close();
    }
  }

  Future<_OpenFoodFactsProduct?> _buscarProductoOffPorCodigo(
    String barcode,
  ) async {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
    );
    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'NutriFit/1.0 (OpenFoodFacts Integration)',
      },
    );

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    if (decoded['status'] != 1 || decoded['product'] is! Map<String, dynamic>) {
      return null;
    }

    return _OpenFoodFactsProduct.fromJson(
      decoded['product'] as Map<String, dynamic>,
      barcodeFallback: barcode,
    );
  }

  Future<_OpenFoodFactsProduct?> _buscarProductoOffPorNombre(
    String query,
  ) async {
    final normalized = query.trim();
    if (normalized.length < 3) {
      return null;
    }

    final uri =
        Uri.parse('https://world.openfoodfacts.org/cgi/search.pl').replace(
      queryParameters: {
        'search_terms': normalized,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '10',
      },
    );

    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'NutriFit/1.0 (OpenFoodFacts Integration)',
      },
    );

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final products = decoded['products'];
    if (products is! List) {
      return null;
    }

    for (final item in products) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final parsed = _OpenFoodFactsProduct.fromJson(map);
      if (parsed.hasAnyNutritionalData) {
        return parsed;
      }
    }

    return null;
  }

  NutrientesPorPorcion? _nutrientesDesdeOpenFood(_OpenFoodFactsProduct p) {
    double? toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value.replaceAll(',', '.'));
      }
      return null;
    }

    double? parseServingSizeGr(String? text) {
      if (text == null || text.trim().isEmpty) return null;
      final normalized = text.toLowerCase().replaceAll(',', '.');
      final match = RegExp(
        r'([0-9]+(?:\.[0-9]+)?)\s*(g|ml)\b',
      ).firstMatch(normalized);
      if (match == null) return null;
      return double.tryParse(match.group(1)!);
    }

    final nutriments = p.nutriments;
    final servingSize = parseServingSizeGr(p.servingSize);

    double? resolve(String key) {
      final perServing = toDouble(nutriments['${key}_serving']);
      if (perServing != null) {
        return perServing;
      }

      final per100 = toDouble(nutriments['${key}_100g']);
      if (per100 == null) {
        return null;
      }

      if (servingSize != null && servingSize > 0) {
        return (per100 * servingSize) / 100.0;
      }

      return per100;
    }

    final azucar = resolve('sugars');
    final sal = resolve('salt');
    final grasas = resolve('fat');
    final proteina = resolve('proteins');

    if (azucar == null && sal == null && grasas == null && proteina == null) {
      return null;
    }

    return NutrientesPorPorcion(
      azucarGr: azucar,
      salGr: sal,
      grasasGr: grasas,
      proteinaGr: proteina,
      porcionGr: servingSize,
    );
  }

  String? _extraerNombreProductoProbable(String raw) {
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    const excludedHints = [
      'informacion nutricional',
      'nutrition facts',
      'ingredientes',
      'energia',
      'azucar',
      'grasas',
      'proteina',
      'salt',
      'sodium',
      'kcal',
      '100g',
      '100 ml',
    ];

    for (final line in lines.take(6)) {
      final normalized = line.toLowerCase();
      final hasDigit = RegExp(r'\d').hasMatch(normalized);
      final isExcluded = excludedHints.any(normalized.contains);
      if (!hasDigit && !isExcluded && line.length >= 3) {
        return line;
      }
    }

    return null;
  }

  Future<void> _seleccionarYAnalizar(ImageSource source) async {
    try {
      XFile? picked;
      if (source == ImageSource.camera) {
        picked = await _capturarImagenBarcodeConRecuadro();
      } else {
        picked = await _picker.pickImage(source: source, imageQuality: 85);
      }
      if (picked == null) {
        return;
      }
      final pickedFile = picked;

      setState(() {
        _imagenSeleccionada = File(pickedFile.path);
        _analizando = true;
        _textoDetectado = '';
        _nutrientes = null;
        _productoOpenFood = null;
        _barcodeDetectado = null;
        _fuenteLectura = '';
      });

      if (!Platform.isAndroid && !Platform.isIOS) {
        throw Exception('OCR no disponible en esta plataforma');
      }

      final inputImage = InputImage.fromFilePath(pickedFile.path);
      String? barcode;
      _OpenFoodFactsProduct? offProduct;
      NutrientesPorPorcion? parsed;
      String raw = '';

      if (_detectionMode != _ScannerDetectionMode.ocr) {
        barcode = await _detectarCodigoBarras(inputImage);
        if (barcode != null) {
          offProduct = await _buscarProductoOffPorCodigo(barcode);
          parsed =
              offProduct == null ? null : _nutrientesDesdeOpenFood(offProduct);
          if (parsed != null && offProduct != null) {
            raw = offProduct.nombre;
          }
        }
      }

      if (parsed == null && _detectionMode != _ScannerDetectionMode.barcode) {
        final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final recognizedText = await recognizer.processImage(inputImage);
        await recognizer.close();

        raw = recognizedText.text;
        final parsedBase = NutrientesPorPorcion.parseRecognizedText(
          recognizedText,
        );
        final parsedOcr = _aplicarEntrenamientoSiExiste(raw, parsedBase);

        if (parsedOcr.hasAnyValue) {
          parsed = parsedOcr;
        } else {
          final productName = _extraerNombreProductoProbable(raw);
          if (productName != null) {
            final byName = await _buscarProductoOffPorNombre(productName);
            if (byName != null) {
              offProduct = byName;
              parsed = _nutrientesDesdeOpenFood(byName);
            }
          }
          parsed ??= parsedOcr;
        }
      }

      final l10n = AppLocalizations.of(context)!;
      final detectedSource = switch (_detectionMode) {
        _ScannerDetectionMode.barcode => l10n.scannerSourceBarcode,
        _ScannerDetectionMode.ocr => offProduct != null
            ? l10n.scannerSourceOcrOpenFood
            : l10n.scannerSourceOcrTable,
        _ScannerDetectionMode.auto => barcode != null && offProduct != null
            ? l10n.scannerSourceAutoBarcodeOpenFood
            : (offProduct != null
                ? l10n.scannerSourceAutoOcrOpenFood
                : l10n.scannerSourceAutoOcrTable),
      };

      if (!mounted) return;
      setState(() {
        _textoDetectado = raw;
        _nutrientes = parsed;
        _productoOpenFood = offProduct;
        _barcodeDetectado = barcode;
        _fuenteLectura = detectedSource;
        _analizando = false;
      });

      if (!(parsed?.hasAnyValue ?? false) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.scannerNoNutritionData,
            ),
            duration: Duration(seconds: 6),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.scannerReadCompleted(detectedSource))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _analizando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scannerAnalyzeError(e.toString()))),
      );
    }
  }

  Future<XFile?> _capturarImagenBarcodeConRecuadro() async {
    final frameRect = await _getBarcodeFrameRect();

    if (!Platform.isAndroid && !Platform.isIOS) {
      return _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    }

    final capturedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) =>
            _BarcodeCameraCaptureScreen(frameRectNormalized: frameRect),
      ),
    );

    if (capturedPath == null || capturedPath.trim().isEmpty) {
      return null;
    }

    try {
      final cropped = await _cropImageWithNormalizedRect(
        filePath: capturedPath,
        normalizedRect: frameRect,
      );
      return XFile(cropped ?? capturedPath);
    } catch (_) {
      return XFile(capturedPath);
    }
  }

  Future<Rect> _getBarcodeFrameRect() async {
    final authService = context.read<AuthService>();
    final scope = UserSettingsService.buildScopeKey(
      isGuestMode: authService.isGuestMode,
      userCode: authService.userCode,
      patientCode: authService.patientCode,
      userType: authService.userType,
    );
    final width = await UserSettingsService.getBarcodeFrameWidthNormalized(
      scope,
    );
    final height = await UserSettingsService.getBarcodeFrameHeightNormalized(
      scope,
    );

    return _buildCenteredFrameRect(width: width, height: height, top: 0.36);
  }

  Rect _buildCenteredFrameRect({
    required double width,
    required double height,
    required double top,
  }) {
    final safeWidth = width.clamp(0.1, 1.0);
    final safeHeight = height.clamp(0.1, 1.0);
    final left = ((1.0 - safeWidth) / 2).clamp(0.0, 1.0 - safeWidth);
    final topClamped = top.clamp(0.0, 1.0 - safeHeight);
    return Rect.fromLTWH(left, topClamped, safeWidth, safeHeight);
  }

  Future<String?> _cropImageWithNormalizedRect({
    required String filePath,
    required Rect normalizedRect,
  }) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      return null;
    }

    final bytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return null;
    }

    final left = (decoded.width * normalizedRect.left).round().clamp(
          0,
          decoded.width - 1,
        );
    final top = (decoded.height * normalizedRect.top).round().clamp(
          0,
          decoded.height - 1,
        );

    final maxCropWidth = decoded.width - left;
    final maxCropHeight = decoded.height - top;

    final cropWidth =
        (decoded.width * normalizedRect.width).round().clamp(1, maxCropWidth);
    final cropHeight = (decoded.height * normalizedRect.height)
        .round()
        .clamp(1, maxCropHeight);

    final cropped = img.copyCrop(
      decoded,
      x: left,
      y: top,
      width: cropWidth,
      height: cropHeight,
    );

    final outputPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}nutrifit_barcode_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(img.encodeJpg(cropped, quality: 92));
    return outputFile.path;
  }

  bool _esUsuarioAdmin(AuthService authService) {
    final userType = authService.userType;
    return userType == 'Nutricionista' || userType == 'Administrador';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final resultado = _nutrientes;
    final authService = context.watch<AuthService>();
    final isGuestMode = authService.isGuestMode;
    final isAdmin = _esUsuarioAdmin(authService);
    final canUsePremiumScannerActions =
        _canUseScannerPremiumActions(authService);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scannerTitle)),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.cyan.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.cyan.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _toggleInfoBannerExpanded,
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.cyan.shade800,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.scannerHeaderTitle,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          _buildCompactInfoButton(
                            onPressed: _showUmbralesInfoDialog,
                            tooltip: l10n.scannerHeaderTooltip,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _infoBannerExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.cyan.shade800,
                          ),
                        ],
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: Padding(
                        padding: const EdgeInsets.only(top: 8, right: 28),
                        child: Text(
                          l10n.scannerHeaderBody,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      secondChild: const SizedBox.shrink(),
                      crossFadeState: _infoBannerExpanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 180),
                      sizeCurve: Curves.easeInOut,
                    ),
                  ],
                ),
              ),
              if (isGuestMode) ...[
                const SizedBox(height: 10),
                _buildGuestGenericNotice(),
              ],
              if (_scannerPremiumEnabled && !canUsePremiumScannerActions) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.scannerPremiumBanner,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isAdmin) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.scannerTrainingModeTitle),
                  subtitle: Text(
                    l10n.scannerTrainingModeSubtitle,
                  ),
                  value: _modoEntrenamiento,
                  onChanged: _analizando
                      ? null
                      : (value) {
                          setState(() {
                            _modoEntrenamiento = value;
                          });
                        },
                ),
              ],
              const SizedBox(height: 8),
              _buildDetectionModeSelector(),
              if (_detectionMode == _ScannerDetectionMode.auto &&
                  !_autoHintDismissed) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 6, 4, 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.auto_awesome_outlined,
                          color: Colors.blue.shade700,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.scannerAutoHint,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            _dismissModeHint(_ScannerDetectionMode.auto),
                        child: Tooltip(
                          message: l10n.scannerDismissHintTooltip,
                          child: Icon(Icons.close,
                              size: 14, color: Colors.blue.shade400),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_detectionMode == _ScannerDetectionMode.barcode &&
                  !_barcodeHintDismissed) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 6, 4, 10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.crop_free,
                          color: Colors.indigo.shade700,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.scannerBarcodeHint,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            _dismissModeHint(_ScannerDetectionMode.barcode),
                        child: Tooltip(
                          message: l10n.scannerDismissHintTooltip,
                          child: Icon(Icons.close,
                              size: 14, color: Colors.indigo.shade400),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_detectionMode == _ScannerDetectionMode.ocr &&
                  !_ocrHintDismissed) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 6, 4, 10),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.deepOrange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.text_snippet_outlined,
                          color: Colors.deepOrange.shade700,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.scannerOcrHint,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            _dismissModeHint(_ScannerDetectionMode.ocr),
                        child: Tooltip(
                          message: l10n.scannerDismissHintTooltip,
                          child: Icon(Icons.close,
                              size: 14, color: Colors.deepOrange.shade400),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (_analizando) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 8),
                Center(child: Text(l10n.scannerAnalyzing)),
              ],
              if (!_analizando && _productoOpenFood != null) ...[
                const SizedBox(height: 12),
                _buildOpenFoodProductCard(_productoOpenFood!),
              ],
              if (!_analizando && resultado != null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.scannerResultPerServing,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            _buildCompactInfoButton(
                              onPressed: _showUmbralesInfoDialog,
                              tooltip: l10n.scannerThresholdInfo,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildNutrientesComparisonTable(resultado),
                      ],
                    ),
                  ),
                ),
                if (isAdmin && _modoEntrenamiento) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.scannerMiniTrainingTitle,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _aprendizajeAplicado
                                ? l10n.scannerMiniTrainingApplied
                                : l10n.scannerMiniTrainingPrompt,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _marcarResultadoCorrecto,
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: Text(l10n.scannerTrainingCorrect),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _corregirLecturaDialog,
                                  icon: const Icon(Icons.edit_outlined),
                                  label:
                                      Text(l10n.scannerTrainingCorrectAction),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _exportarEntrenamientoDialog,
                                icon: const Icon(Icons.ios_share_outlined),
                                label: Text(l10n.commonExport),
                              ),
                              OutlinedButton.icon(
                                onPressed: _importarEntrenamientoDialog,
                                icon: const Icon(Icons.download_outlined),
                                label: Text(l10n.commonImport),
                              ),
                              OutlinedButton.icon(
                                onPressed: _bajarReglasServidor,
                                icon: const Icon(Icons.cloud_download_outlined),
                                label: Text(l10n.scannerDownloadServerRules),
                              ),
                              OutlinedButton.icon(
                                onPressed: _subirReglasServidor,
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: Text(l10n.scannerUploadServerRules),
                              ),
                              OutlinedButton.icon(
                                onPressed: _limpiarEntrenamiento,
                                icon: const Icon(Icons.delete_sweep_outlined),
                                label: Text(l10n.scannerClearLocalRules),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
              if (_imagenSeleccionada != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _abrirVisorImagen,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.file(
                          _imagenSeleccionada!,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.zoom_in,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.scannerZoomLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              _buildCaptureQualityNotice(),
              if (_textoDetectado.isNotEmpty) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  title: Text(l10n.scannerDetectedTextTitle),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      child: Text(
                        _textoDetectado,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _buildOrientativeHealthNotice(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirVisorImagen() async {
    final l10n = AppLocalizations.of(context)!;
    final imagen = _imagenSeleccionada;
    if (imagen == null) {
      return;
    }

    try {
      final bytes = await imagen.readAsBytes();
      if (!mounted) return;
      showImageViewerDialog(
        context: context,
        base64Image: base64Encode(bytes),
        title: l10n.scannerImageTitle,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scannerOpenImageError(e.toString()))),
      );
    }
  }

  Widget _buildCompactInfoButton({
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: tooltip ?? l10n.scannerInfoTitle,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          side: BorderSide(color: Colors.blue.shade500, width: 1.4),
          backgroundColor: Colors.amber.shade300,
          minimumSize: const Size(34, 34),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Icon(Icons.info_outline, size: 18, color: Colors.blue),
      ),
    );
  }

  Widget _buildDetectionModeSelector() {
    final l10n = AppLocalizations.of(context)!;
    final canUsePremiumScannerActions =
        _canUseScannerPremiumActions(context.read<AuthService>());

    // ── Botones de configuración de modo (pequeños, tipo toggle) ─────────
    Widget modeButton(
      _ScannerDetectionMode mode,
      IconData icon,
      String tooltip,
    ) {
      final selected = _detectionMode == mode;
      return Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _analizando
              ? null
              : () {
                  setState(() {
                    _detectionMode = mode;
                  });
                  _guardarModoDeteccion(mode);
                },
          onLongPress: _analizando ? null : () => _restoreModeHint(mode),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.14)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                width: selected ? 1.6 : 1.0,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    // ── Botones de acción (anchos, con icono + etiqueta) ─────────────────
    Widget actionButton({
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback? onTap,
    }) {
      final disabled = _analizando;
      return Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disabled ? null : onTap,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: disabled
                  ? Theme.of(context).colorScheme.surface
                  : color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: disabled
                    ? Theme.of(context).dividerColor
                    : color.withValues(alpha: 0.55),
                width: 1.4,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: disabled
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.35)
                      : color,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: disabled
                        ? Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.35)
                        : color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila 1: selector de modo (configuración)
        Row(
          children: [
            Text(
              l10n.scannerModeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.50),
              ),
            ),
            const SizedBox(width: 10),
            modeButton(_ScannerDetectionMode.auto, Icons.auto_awesome,
                l10n.scannerModeAuto),
            const SizedBox(width: 6),
            modeButton(_ScannerDetectionMode.barcode, Icons.qr_code,
                l10n.scannerModeBarcode),
            const SizedBox(width: 6),
            modeButton(_ScannerDetectionMode.ocr, Icons.table_chart_outlined,
                l10n.scannerModeOcrTable),
          ],
        ),
        const SizedBox(height: 10),
        // Fila 2: botones de acción
        Row(
          children: [
            Expanded(
              child: actionButton(
                icon: Icons.search,
                label: l10n.commonSearch,
                color: Colors.blueGrey.shade600,
                onTap: canUsePremiumScannerActions
                    ? _buscarProductoManualDialog
                    : _showScannerPremiumRequired,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: actionButton(
                icon: Icons.photo_camera_outlined,
                label: l10n.commonPhoto,
                color: Colors.deepPurple,
                onTap: canUsePremiumScannerActions
                    ? () => _seleccionarYAnalizar(ImageSource.camera)
                    : _showScannerPremiumRequired,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: actionButton(
                icon: Icons.photo_library_outlined,
                label: l10n.commonGallery,
                color: Colors.teal,
                onTap: canUsePremiumScannerActions
                    ? () => _seleccionarYAnalizar(ImageSource.gallery)
                    : _showScannerPremiumRequired,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _buscarProductoManualDialog() async {
    final l10n = AppLocalizations.of(context)!;
    if (!mounted) return;
    final screenContext = context;
    String draftQuery = '';
    final query = await showDialog<String>(
      context: screenContext,
      useRootNavigator: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.scannerManualSearchTitle),
          content: TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.scannerManualSearchHint,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setDialogState(() {
                draftQuery = value;
              });
            },
            onSubmitted: (value) =>
                Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(draftQuery.trim()),
              child: Text(l10n.commonSearch),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (query == null || query.trim().length < 3) {
      return;
    }
    final searchQuery = query.trim();

    setState(() {
      _analizando = true;
    });

    try {
      final product = await _buscarProductoOffPorNombre(searchQuery);
      if (!mounted) return;

      if (product == null) {
        setState(() {
          _analizando = false;
        });
        ScaffoldMessenger.of(screenContext).showSnackBar(
          SnackBar(
            content: Text(l10n.scannerNoValidProductByName),
          ),
        );
        return;
      }

      final nutrientes = _nutrientesDesdeOpenFood(product);
      setState(() {
        _productoOpenFood = product;
        _barcodeDetectado = product.barcode.isEmpty ? null : product.barcode;
        _nutrientes = nutrientes;
        _fuenteLectura = l10n.scannerManualSearchSource;
        if (_textoDetectado.trim().isEmpty) {
          _textoDetectado = searchQuery;
        }
        _analizando = false;
      });

      ScaffoldMessenger.of(screenContext).showSnackBar(
        SnackBar(content: Text(l10n.scannerProductFound)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analizando = false;
      });
      ScaffoldMessenger.of(
        screenContext,
      ).showSnackBar(
        SnackBar(content: Text(l10n.scannerProductSearchError(e.toString()))),
      );
    }
  }

  Widget _buildOpenFoodProductCard(_OpenFoodFactsProduct product) {
    final l10n = AppLocalizations.of(context)!;
    Color nutriScoreColor(String grade) {
      switch (grade.toLowerCase()) {
        case 'a':
          return Colors.green;
        case 'b':
          return Colors.lightGreen;
        case 'c':
          return Colors.amber;
        case 'd':
          return Colors.orange;
        case 'e':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    Color novaColor(int? group) {
      switch (group) {
        case 1:
          return Colors.green;
        case 2:
          return Colors.lightGreen;
        case 3:
          return Colors.amber;
        case 4:
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    String? formatNutriment(String key, String unit) {
      double? toDouble(dynamic value) {
        if (value is num) return value.toDouble();
        if (value is String) {
          return double.tryParse(value.replaceAll(',', '.'));
        }
        return null;
      }

      final serving = toDouble(product.nutriments['${key}_serving']);
      if (serving != null) {
        return '${serving.toStringAsFixed(2)} $unit por porción';
      }

      final per100 = toDouble(product.nutriments['${key}_100g']);
      if (per100 != null) {
        return '${per100.toStringAsFixed(2)} $unit /100g';
      }

      return null;
    }

    final energiaKcal = formatNutriment('energy-kcal', 'kcal');
    final fibra = formatNutriment('fiber', 'g');
    final grasasSat = formatNutriment('saturated-fat', 'g');
    final carbohidratos = formatNutriment('carbohydrates', 'g');
    final sodio = formatNutriment('sodium', 'g');
    final barcode = _barcodeDetectado ?? product.barcode;

    bool isDangerousAdditive(String additive) {
      final normalized = additive.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]'),
            '',
          );
      const dangerousCodes = {
        'e102',
        'e104',
        'e110',
        'e122',
        'e123',
        'e124',
        'e127',
        'e129',
        'e150d',
        'e211',
        'e249',
        'e250',
        'e251',
        'e252',
        'e320',
        'e321',
        'e621',
        'e950',
        'e951',
        'e952',
        'e954',
        'e955',
      };
      for (final code in dangerousCodes) {
        if (normalized.contains(code)) {
          return true;
        }
      }

      const riskyTerms = {
        'nitrite',
        'nitrito',
        'nitrate',
        'nitrato',
        'benzoate',
        'benzoato',
        'aspartame',
        'aspartamo',
        'cyclamate',
        'ciclamato',
        'saccharin',
        'sacarina',
        'acesulfame',
        'sucralose',
        'sucralosa',
        'monosodiumglutamate',
        'glutamatomonosodico',
      };
      return riskyTerms.any(normalized.contains);
    }

    Widget sectionTitle(String text) {
      return Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.scannerProductName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildCompactInfoButton(
                  onPressed: _showUmbralesInfoDialog,
                  tooltip: l10n.scannerHeaderTooltip,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            sectionTitle(l10n.scannerBrand),
            const SizedBox(height: 4),
            Text(
              product.marca.isEmpty ? l10n.commonUnavailable : product.marca,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            sectionTitle(l10n.scannerFormat),
            const SizedBox(height: 4),
            Text(
              product.quantity.isEmpty
                  ? l10n.commonUnavailable
                  : product.quantity,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            sectionTitle(l10n.scannerBarcodeLabel),
            const SizedBox(height: 4),
            Text(
              barcode.isEmpty ? l10n.commonUnavailable : barcode,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            sectionTitle(l10n.scannerActions),
            const SizedBox(height: 6),
            Row(
              children: [
                Tooltip(
                  message: l10n.scannerAddToShoppingList,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _agregarProductoOpenFoodAListaCompra(product),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.55),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.add_shopping_cart,
                        size: 22,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: l10n.commonGeneratePdf,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _generarPdfProductoOpenFood(product),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.deepPurple.withValues(alpha: 0.55),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 22,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: l10n.commonCopy,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _copiarDatosProductoOpenFood(product),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.teal.withValues(alpha: 0.55),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.content_copy_outlined,
                        size: 22,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            sectionTitle(l10n.scannerNutriScoreNova),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (product.nutriScore.isNotEmpty)
                  Builder(
                    builder: (context) {
                      final scoreColor = nutriScoreColor(product.nutriScore);
                      return ActionChip(
                        onPressed: _showNutriScoreInfoDialog,
                        tooltip: l10n.scannerNutriScoreMeaning,
                        label: Text(
                          'Nutri-Score ${product.nutriScore.toUpperCase()}',
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: scoreColor.withValues(alpha: 0.16),
                        side: BorderSide(
                          color: scoreColor.withValues(alpha: 0.7),
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                if (product.novaGroup != null)
                  Builder(
                    builder: (context) {
                      final groupColor = novaColor(product.novaGroup);
                      return ActionChip(
                        onPressed: _showNovaInfoDialog,
                        tooltip: l10n.scannerNovaMeaning,
                        label: Text(
                          'NOVA ${product.novaGroup}',
                          style: TextStyle(
                            color: groupColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: groupColor.withValues(alpha: 0.14),
                        side: BorderSide(
                          color: groupColor.withValues(alpha: 0.45),
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                if (product.nutriScore.isEmpty && product.novaGroup == null)
                  Text(l10n.commonUnavailable,
                      style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            sectionTitle(l10n.scannerIngredients),
            const SizedBox(height: 4),
            Text(
              product.ingredientes.isEmpty
                  ? l10n.commonUnavailable
                  : product.ingredientes,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            sectionTitle(l10n.scannerNutritionData),
            const SizedBox(height: 4),
            if (energiaKcal != null ||
                fibra != null ||
                grasasSat != null ||
                carbohidratos != null ||
                sodio != null) ...[
              if (energiaKcal != null)
                Text(
                  l10n.scannerEnergyValue(energiaKcal),
                  style: const TextStyle(fontSize: 12),
                ),
              if (carbohidratos != null)
                Text(
                  l10n.scannerCarbohydratesValue(carbohidratos),
                  style: const TextStyle(fontSize: 12),
                ),
              if (fibra != null)
                Text(l10n.scannerFiberValue(fibra),
                    style: const TextStyle(fontSize: 12)),
              if (grasasSat != null)
                Text(
                  l10n.scannerSaturatedFatValue(grasasSat),
                  style: const TextStyle(fontSize: 12),
                ),
              if (sodio != null)
                Text(l10n.scannerSodiumValue(sodio),
                    style: const TextStyle(fontSize: 12)),
            ] else
              Text(l10n.commonUnavailable,
                  style: const TextStyle(fontSize: 12)),
            if (product.additives.isNotEmpty) ...[
              const SizedBox(height: 10),
              sectionTitle(l10n.navAdditives),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: product.additives.map((additive) {
                  final dangerous = isDangerousAdditive(additive);
                  final color = dangerous ? Colors.red : Colors.blueGrey;
                  return Chip(
                    label: Text(
                      additive,
                      style: TextStyle(
                        color: dangerous ? Colors.red.shade900 : null,
                        fontWeight:
                            dangerous ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    backgroundColor: dangerous
                        ? Colors.red.withValues(alpha: 0.12)
                        : color.withValues(alpha: 0.10),
                    side: BorderSide(
                      color: dangerous
                          ? Colors.red.withValues(alpha: 0.45)
                          : color.withValues(alpha: 0.35),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(growable: false),
              ),
            ],
            const SizedBox(height: 10),
            sectionTitle(l10n.scannerAllergensAndTraces),
            const SizedBox(height: 4),
            Text(
              l10n.scannerAllergensValue(
                product.allergens.isEmpty
                    ? l10n.commonUnavailable
                    : product.allergens.take(6).join(', '),
              ),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.scannerTracesValue(
                product.traces.isEmpty
                    ? l10n.commonUnavailable
                    : product.traces.take(6).join(', '),
              ),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            sectionTitle(l10n.scannerFeaturedLabels),
            const SizedBox(height: 6),
            if (product.labels.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: product.labels
                    .take(8)
                    .map(
                      (label) => Chip(
                        label: Text(label),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(growable: false),
              )
            else
              Text(l10n.commonUnavailable,
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _generarPdfProductoOpenFood(
    _OpenFoodFactsProduct product,
  ) async {
    await OpenFoodProductPdfService.generateProductPdf(
      context: context,
      apiService: _apiService,
      product: OpenFoodProductPdfData(
        nombre: product.nombre,
        marca: product.marca,
        barcode: _barcodeDetectado ?? product.barcode,
        quantity: product.quantity,
        servingSize: product.servingSize,
        nutriScore: product.nutriScore,
        novaGroup: product.novaGroup,
        ingredientes: product.ingredientes,
        labels: product.labels,
        categories: product.categories,
        countries: product.countries,
        allergens: product.allergens,
        traces: product.traces,
        additives: product.additives,
        nutriments: product.nutriments,
        rawData: product.rawData,
        fuenteLectura: _fuenteLectura,
      ),
    );
  }

  Future<void> _copiarDatosProductoOpenFood(
    _OpenFoodFactsProduct product,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    String joinList(List<String> values) =>
        values.isEmpty ? '-' : values.join(', ');

    final buffer = StringBuffer()
      ..writeln('Producto: ${product.nombre}')
      ..writeln('Marca: ${product.marca.isEmpty ? '-' : product.marca}')
      ..writeln(
        'Código de barras: ${(_barcodeDetectado ?? product.barcode).isEmpty ? '-' : (_barcodeDetectado ?? product.barcode)}',
      )
      ..writeln('Formato: ${product.quantity.isEmpty ? '-' : product.quantity}')
      ..writeln(
        'Porción: ${(product.servingSize ?? '').trim().isEmpty ? '-' : product.servingSize}',
      )
      ..writeln(
        'Fuente: ${_fuenteLectura.trim().isEmpty ? '-' : _fuenteLectura}',
      )
      ..writeln(
        'Nutri-Score: ${product.nutriScore.isEmpty ? '-' : product.nutriScore.toUpperCase()}',
      )
      ..writeln('NOVA: ${product.novaGroup?.toString() ?? '-'}')
      ..writeln(
        'Ingredientes: ${product.ingredientes.isEmpty ? '-' : product.ingredientes}',
      )
      ..writeln('Etiquetas: ${joinList(product.labels)}')
      ..writeln('Categorías: ${joinList(product.categories)}')
      ..writeln('Países: ${joinList(product.countries)}')
      ..writeln('Alérgenos: ${joinList(product.allergens)}')
      ..writeln('Trazas: ${joinList(product.traces)}')
      ..writeln('Aditivos: ${joinList(product.additives)}')
      ..writeln('\nNutrientes (Open Food Facts):');

    final nutrimentsEntries = product.nutriments.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in nutrimentsEntries) {
      final value = entry.value?.toString() ?? '';
      if (value.trim().isEmpty) continue;
      buffer.writeln('- ${entry.key}: $value');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.scannerCopiedData)),
    );
  }

  Future<void> _agregarProductoOpenFoodAListaCompra(
    _OpenFoodFactsProduct product,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isGuestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scannerRegisterForShoppingList)),
      );
      return;
    }

    final ownerCode = authService.userCode;
    if (ownerCode == null || ownerCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scannerUnknownUser)),
      );
      return;
    }

    final payload = <String, dynamic>{
      'codigo_usuario': int.tryParse(ownerCode) ?? 0,
      'nombre': product.nombre,
      'descripcion': product.marca.trim().isEmpty ? null : product.marca,
      'categoria': _inferirCategoriaListaCompra(product),
      'cantidad': 1,
      'unidad': 'unidades',
      'comprado': 'N',
      'notas': 'Añadido desde escáner nutricional',
      'escaner_fuente':
          _fuenteLectura.trim().isEmpty ? 'Open Food Facts' : _fuenteLectura,
      'off_codigo_barras': (_barcodeDetectado ?? product.barcode).trim().isEmpty
          ? null
          : (_barcodeDetectado ?? product.barcode).trim(),
      'off_nombre_producto': product.nombre,
      'off_marca': product.marca.trim().isEmpty ? null : product.marca,
      'off_nutri_score':
          product.nutriScore.trim().isEmpty ? null : product.nutriScore,
      'off_nova_group': product.novaGroup,
      'off_cantidad': product.quantity.trim().isEmpty ? null : product.quantity,
      'off_porcion': (product.servingSize ?? '').trim().isEmpty
          ? null
          : product.servingSize,
      'off_ingredientes':
          product.ingredientes.trim().isEmpty ? null : product.ingredientes,
      'off_nutriments_json':
          product.nutriments.isEmpty ? null : jsonEncode(product.nutriments),
      'off_raw_json':
          product.rawData.isEmpty ? null : jsonEncode(product.rawData),
    };

    try {
      final existingItem = await _buscarItemListaCompraPorNombre(
        ownerCode: ownerCode,
        nombre: product.nombre,
      );

      final response = existingItem != null
          ? await _apiService.put(
              'api/lista_compra.php',
              body: jsonEncode(
                _fusionarPayloadEscanerConItemExistente(
                  existingItem: existingItem,
                  scannerPayload: payload,
                ),
              ),
            )
          : await _apiService.post(
              'api/lista_compra.php',
              body: jsonEncode(payload),
            );

      if (!mounted) return;

      if (existingItem != null && response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.scannerExistingFoodUpdated),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.scannerProductAddedToShoppingList),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo añadir a la lista (${response.statusCode})',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.scannerAddToShoppingListError(e.toString())),
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _buscarItemListaCompraPorNombre({
    required String ownerCode,
    required String nombre,
  }) async {
    final response =
        await _apiService.get('api/lista_compra.php?usuario=$ownerCode');
    if (response.statusCode != 200) {
      throw Exception('No se pudo consultar la lista de compra');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    final normalizedNombre = _normalizarNombreListaCompra(nombre);

    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      if (_normalizarNombreListaCompra(item['nombre']?.toString() ?? '') ==
          normalizedNombre) {
        return item;
      }
    }

    return null;
  }

  Map<String, dynamic> _fusionarPayloadEscanerConItemExistente({
    required Map<String, dynamic> existingItem,
    required Map<String, dynamic> scannerPayload,
  }) {
    return <String, dynamic>{
      ...existingItem,
      ...scannerPayload,
      'codigo': existingItem['codigo'],
      'codigo_usuario':
          existingItem['codigo_usuario'] ?? scannerPayload['codigo_usuario'],
      'cantidad': existingItem['cantidad'],
      'unidad': existingItem['unidad'],
      'comprado': existingItem['comprado'] ?? 'N',
      'fecha_caducidad': existingItem['fecha_caducidad'],
      'fecha_compra': existingItem['fecha_compra'],
      'notas': existingItem['notas'] ?? scannerPayload['notas'],
    };
  }

  String _normalizarNombreListaCompra(String value) {
    const replacements = <String, String>{
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };

    var normalized = value.trim().toLowerCase();
    replacements.forEach((key, replacement) {
      normalized = normalized.replaceAll(key, replacement);
    });

    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _inferirCategoriaListaCompra(_OpenFoodFactsProduct product) {
    final base = [
      ...product.categories,
      ...product.labels,
      product.nombre,
      product.marca,
    ].join(' ').toLowerCase();

    bool hasAny(List<String> terms) => terms.any(base.contains);

    if (hasAny(['fruta', 'manzana', 'platano', 'banana', 'pera', 'naranja'])) {
      return 'frutas';
    }
    if (hasAny(['verdura', 'vegetal', 'tomate', 'lechuga', 'brocoli'])) {
      return 'verduras';
    }
    if (hasAny(['carne', 'pollo', 'ternera', 'pavo', 'cerdo'])) {
      return 'carnes';
    }
    if (hasAny(['leche', 'yogur', 'queso', 'lacteo'])) {
      return 'lacteos';
    }
    if (hasAny(['pan', 'bolleria', 'bakery', 'galleta'])) {
      return 'panaderia';
    }
    if (hasAny(['congelado', 'frozen'])) {
      return 'congelados';
    }
    if (hasAny(['bebida', 'zumo', 'jugo', 'refresco', 'agua'])) {
      return 'bebidas';
    }
    if (hasAny(['conserva', 'lata', 'enlatado'])) {
      return 'conservas';
    }
    return 'otros';
  }

  Widget _buildContactarDietistaButton() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: FilledButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ContactoNutricionistaScreen(),
            ),
          );
        },
        icon: const Icon(Icons.support_agent, size: 18),
        label: Text(l10n.scannerContactDietitianButton),
      ),
    );
  }

  void _showUmbralesInfoDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.scannerInfoTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.scannerThresholdInfoIntro,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(l10n.scannerThresholdComponent)),
                    DataColumn(label: Text(l10n.scannerThresholdOk)),
                    DataColumn(label: Text(l10n.scannerThresholdCaution)),
                    DataColumn(label: Text(l10n.scannerThresholdHighLow)),
                  ],
                  rows: [
                    DataRow(
                      cells: [
                        DataCell(Text(l10n.scannerThresholdSugar)),
                        const DataCell(Text('≤ 5 g')),
                        const DataCell(Text('> 5 y ≤ 12 g')),
                        const DataCell(Text('> 12 g')),
                      ],
                    ),
                    DataRow(
                      cells: [
                        DataCell(Text(l10n.scannerThresholdSalt)),
                        const DataCell(Text('≤ 0.3 g')),
                        const DataCell(Text('> 0.3 y ≤ 1.0 g')),
                        const DataCell(Text('> 1.0 g')),
                      ],
                    ),
                    DataRow(
                      cells: [
                        DataCell(Text(l10n.scannerThresholdFat)),
                        const DataCell(Text('≤ 10 g')),
                        const DataCell(Text('> 10 y ≤ 17.5 g')),
                        const DataCell(Text('> 17.5 g')),
                      ],
                    ),
                    DataRow(
                      cells: [
                        DataCell(Text(l10n.scannerThresholdProtein)),
                        const DataCell(Text('≥ 10 g')),
                        const DataCell(Text('≥ 5 y < 10 g')),
                        const DataCell(Text('< 5 g')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.scannerThresholdDisclaimer,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              _buildContactarDietistaButton(),
              const SizedBox(height: 12),
              _buildNutriScoreInfoBlock(),
              const SizedBox(height: 10),
              _buildNovaInfoBlock(),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.scannerOcrAccuracyTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.scannerOcrAccuracyBody,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(l10n.scannerOcrTip1),
                    Text(l10n.scannerOcrTip2),
                    Text(l10n.scannerOcrTip3),
                    Text(l10n.scannerOcrTip4),
                    Text(l10n.scannerOcrTip5),
                    Text(l10n.scannerOcrTip6),
                    Text(l10n.scannerOcrTip7),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Widget _buildNutriScoreInfoBlock() {
    final l10n = AppLocalizations.of(context)!;
    Widget row(String label, Color color, String meaning) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: color),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(meaning, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Text(
            l10n.scannerNutriScoreDescription,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          row('A', Colors.green, l10n.scannerNutriScoreA),
          row('B', Colors.lightGreen, l10n.scannerNutriScoreB),
          row('C', Colors.amber, l10n.scannerNutriScoreC),
          row('D', Colors.orange, l10n.scannerNutriScoreD),
          row('E', Colors.red, l10n.scannerNutriScoreE),
        ],
      ),
    );
  }

  Widget _buildNovaInfoBlock() {
    final l10n = AppLocalizations.of(context)!;
    Widget row(int group, Color color, String meaning) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color),
              ),
              child: Text(
                'NOVA $group',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(meaning, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Text(
            l10n.scannerNovaDescription,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          row(1, Colors.green, l10n.scannerNova1),
          row(2, Colors.lightGreen, l10n.scannerNova2),
          row(3, Colors.amber, l10n.scannerNova3),
          row(4, Colors.red, l10n.scannerNova4),
        ],
      ),
    );
  }

  void _showNutriScoreInfoDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nutri-Score'),
        content: SingleChildScrollView(child: _buildNutriScoreInfoBlock()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  void _showNovaInfoDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NOVA'),
        content: SingleChildScrollView(child: _buildNovaInfoBlock()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestGenericNotice() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black),
                children: [
                  TextSpan(text: l10n.scannerGuestAccuracyPromptStart),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: Text(
                        l10n.scannerGuestAccuracyPromptLink,
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  TextSpan(text: l10n.scannerGuestAccuracyPromptEnd),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureQualityNotice() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.only(bottom: 6),
        initiallyExpanded: false,
        title: Row(
          children: [
            const Icon(Icons.tips_and_updates_outlined, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.scannerCaptureTipsTitle,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.scannerCaptureTipsIntro,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.scannerCaptureTipsBody,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrientativeHealthNotice() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Colors.orange.shade800,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.scannerImportantNotice,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.scannerOrientativeNotice,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          _buildContactarDietistaButton(),
        ],
      ),
    );
  }

  String _formatPorcionLabel(double? porcionGr) {
    if (porcionGr == null || porcionGr <= 0) {
      return 'No detectada';
    }
    if ((porcionGr - porcionGr.round()).abs() < 0.01) {
      return '${porcionGr.toStringAsFixed(0)} g';
    }
    return '${porcionGr.toStringAsFixed(2)} g';
  }

  double? _to100g(double? valorPorPorcion, double? porcionGr) {
    if (valorPorPorcion == null) return null;
    if (porcionGr == null || porcionGr <= 0) return valorPorPorcion;
    if ((porcionGr - 100).abs() < 0.01) return valorPorPorcion;
    return (valorPorPorcion * 100.0) / porcionGr;
  }

  String _formatGrValue(double? value) {
    if (value == null) return '-';
    return '${value.toStringAsFixed(2)} g';
  }

  Widget _buildEstadoTag(_EstadoNutriente estado) {
    final color = switch (estado) {
      _EstadoNutriente.ok => Colors.green,
      _EstadoNutriente.precaucion => Colors.orange,
      _EstadoNutriente.alto => Colors.red,
      _EstadoNutriente.sinDato => Colors.grey,
    };

    final etiqueta = switch (estado) {
      _EstadoNutriente.ok => 'OK',
      _EstadoNutriente.precaucion => 'Precaución',
      _EstadoNutriente.alto => 'Alto',
      _EstadoNutriente.sinDato => 'Sin dato',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        etiqueta,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildNutrientesComparisonTable(NutrientesPorPorcion resultado) {
    final l10n = AppLocalizations.of(context)!;
    final porcion = resultado.porcionGr;
    final showPortionColumn =
        porcion != null && porcion > 0 && (porcion - 100).abs() > 0.01;

    final azucar100 = _to100g(resultado.azucarGr, porcion);
    final sal100 = _to100g(resultado.salGr, porcion);
    final grasas100 = _to100g(resultado.grasasGr, porcion);
    final proteina100 = _to100g(resultado.proteinaGr, porcion);

    final rows = <Map<String, dynamic>>[
      {
        'nombre': 'Azúcar',
        'porcion': resultado.azucarGr,
        'cien': azucar100,
        'estado': _estadoAzucar(azucar100),
      },
      {
        'nombre': 'Sal',
        'porcion': resultado.salGr,
        'cien': sal100,
        'estado': _estadoSal(sal100),
      },
      {
        'nombre': 'Grasas',
        'porcion': resultado.grasasGr,
        'cien': grasas100,
        'estado': _estadoGrasas(grasas100),
      },
      {
        'nombre': 'Proteína',
        'porcion': resultado.proteinaGr,
        'cien': proteina100,
        'estado': _estadoProteina(proteina100),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 34,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 52,
            columns: [
              DataColumn(label: Text(l10n.scannerNutrientColumn)),
              if (showPortionColumn)
                DataColumn(
                  label: Text(
                    l10n.scannerServingColumn(_formatPorcionLabel(porcion)),
                  ),
                ),
              const DataColumn(label: Text('100 g')),
              DataColumn(label: Text(l10n.scannerStatus100gColumn)),
            ],
            rows: rows
                .map(
                  (item) => DataRow(
                    cells: [
                      DataCell(Text(item['nombre'] as String)),
                      if (showPortionColumn)
                        DataCell(
                          Text(_formatGrValue(item['porcion'] as double?)),
                        ),
                      DataCell(Text(_formatGrValue(item['cien'] as double?))),
                      DataCell(
                        _buildEstadoTag(item['estado'] as _EstadoNutriente),
                      ),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  _EstadoNutriente _estadoAzucar(double? valor) {
    if (valor == null) return _EstadoNutriente.sinDato;
    if (valor <= 5) return _EstadoNutriente.ok;
    if (valor <= 12) return _EstadoNutriente.precaucion;
    return _EstadoNutriente.alto;
  }

  _EstadoNutriente _estadoSal(double? valor) {
    if (valor == null) return _EstadoNutriente.sinDato;
    if (valor <= 0.3) return _EstadoNutriente.ok;
    if (valor <= 1.0) return _EstadoNutriente.precaucion;
    return _EstadoNutriente.alto;
  }

  _EstadoNutriente _estadoGrasas(double? valor) {
    if (valor == null) return _EstadoNutriente.sinDato;
    if (valor <= 10) return _EstadoNutriente.ok;
    if (valor <= 17.5) return _EstadoNutriente.precaucion;
    return _EstadoNutriente.alto;
  }

  _EstadoNutriente _estadoProteina(double? valor) {
    if (valor == null) return _EstadoNutriente.sinDato;
    if (valor >= 10) return _EstadoNutriente.ok;
    if (valor >= 5) return _EstadoNutriente.precaucion;
    return _EstadoNutriente.alto;
  }
}

enum _EstadoNutriente { ok, precaucion, alto, sinDato }

class NutrientesPorPorcion {
  NutrientesPorPorcion({
    required this.azucarGr,
    required this.salGr,
    required this.grasasGr,
    required this.proteinaGr,
    required this.porcionGr,
  });

  final double? azucarGr;
  final double? salGr;
  final double? grasasGr;
  final double? proteinaGr;
  final double? porcionGr;

  NutrientesPorPorcion copyWith({
    double? azucarGr,
    double? salGr,
    double? grasasGr,
    double? proteinaGr,
    double? porcionGr,
  }) {
    return NutrientesPorPorcion(
      azucarGr: azucarGr ?? this.azucarGr,
      salGr: salGr ?? this.salGr,
      grasasGr: grasasGr ?? this.grasasGr,
      proteinaGr: proteinaGr ?? this.proteinaGr,
      porcionGr: porcionGr ?? this.porcionGr,
    );
  }

  bool get hasAnyValue =>
      azucarGr != null ||
      salGr != null ||
      grasasGr != null ||
      proteinaGr != null;

  static NutrientesPorPorcion parseRecognizedText(
    RecognizedText recognizedText,
  ) {
    final ocrLines = <_OcrLine>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final normalizedText = _normalizeText(line.text);
        if (normalizedText.trim().isEmpty) {
          continue;
        }
        final box = line.boundingBox;
        ocrLines.add(
          _OcrLine(
            text: normalizedText,
            left: box.left,
            right: box.right,
            centerY: (box.top + box.bottom) / 2,
          ),
        );
      }
    }

    final rawText = recognizedText.text;
    final fallback = parse(rawText);

    final preferRightColumn = _hasLikelyDualColumnLayout(ocrLines);

    final porcion = _extractServingFromStructured(ocrLines) ??
        _extractServingSize(_splitNormalizedLines(rawText));

    final azucar = _extractNutrientFromStructured(
      ocrLines,
      preferRightColumn: preferRightColumn,
      keywords: const [
        'azucar',
        'azucares',
        'de los cuales azucares',
        'sugar',
        'sugars',
        'sucre',
        'sucres',
        'zucchero',
        'zuccheri',
        'zucker',
      ],
    );

    final sal = _extractNutrientFromStructured(
      ocrLines,
      preferRightColumn: preferRightColumn,
      keywords: const ['sal', 'salt', 'sale', 'sel'],
    );

    final sodio = _extractNutrientFromStructured(
      ocrLines,
      preferRightColumn: preferRightColumn,
      keywords: const ['sodio', 'sodium', 'natrium'],
    );

    final grasas = _extractNutrientFromStructured(
      ocrLines,
      preferRightColumn: preferRightColumn,
      keywords: const [
        'grasa',
        'grasas',
        'grasas totales',
        'fat',
        'fats',
        'gordura',
        'gorduras',
        'matiere grasse',
        'matieres grasses',
        'lipides',
        'fett',
        'grassi',
      ],
    );

    final proteina = _extractNutrientFromStructured(
      ocrLines,
      preferRightColumn: preferRightColumn,
      keywords: const [
        'proteina',
        'proteinas',
        'protein',
        'proteins',
        'proteine',
        'eiweiss',
      ],
    );

    final salDirecta = _toGrams(sal?.value, sal?.unit);
    final sodioEnGr = _toGrams(sodio?.value, sodio?.unit);
    final salEstimacion = sodioEnGr == null ? null : sodioEnGr * 2.5;

    return NutrientesPorPorcion(
      azucarGr: _toGrams(azucar?.value, azucar?.unit) ?? fallback.azucarGr,
      salGr: salDirecta ?? salEstimacion ?? fallback.salGr,
      grasasGr: _toGrams(grasas?.value, grasas?.unit) ?? fallback.grasasGr,
      proteinaGr:
          _toGrams(proteina?.value, proteina?.unit) ?? fallback.proteinaGr,
      porcionGr: _toGrams(porcion?.value, porcion?.unit) ?? fallback.porcionGr,
    );
  }

  static NutrientesPorPorcion parse(String text) {
    final lines = _splitNormalizedLines(text);
    final preferRightColumn = _hasLikelyDualColumnLayoutFromText(lines);

    final porcion = _extractServingSize(lines);

    final azucar = _extractNutrientePorPorcion(
      lines,
      preferRightColumn: preferRightColumn,
      keywords: const [
        'azucar',
        'azucares',
        'sugar',
        'sugars',
        'sucre',
        'sucres',
        'zucchero',
        'zuccheri',
        'zucker',
      ],
    );

    final sal = _extractNutrientePorPorcion(
      lines,
      preferRightColumn: preferRightColumn,
      keywords: const ['sal', 'salt', 'sale', 'sel'],
    );

    final sodio = _extractNutrientePorPorcion(
      lines,
      preferRightColumn: preferRightColumn,
      keywords: const ['sodio', 'sodium', 'natrium'],
    );

    final grasas = _extractNutrientePorPorcion(
      lines,
      preferRightColumn: preferRightColumn,
      keywords: const [
        'grasa',
        'grasas',
        'fat',
        'fats',
        'gordura',
        'gorduras',
        'matiere grasse',
        'matieres grasses',
        'lipides',
        'fett',
        'grassi',
      ],
    );

    final proteina = _extractNutrientePorPorcion(
      lines,
      preferRightColumn: preferRightColumn,
      keywords: const [
        'proteina',
        'proteinas',
        'protein',
        'proteins',
        'proteine',
        'eiweiss',
      ],
    );

    final salDirecta = _toGrams(sal?.value, sal?.unit);
    final sodioEnGr = _toGrams(sodio?.value, sodio?.unit);
    final salEstimacion = sodioEnGr == null ? null : sodioEnGr * 2.5;

    return NutrientesPorPorcion(
      azucarGr: _toGrams(azucar?.value, azucar?.unit),
      salGr: salDirecta ?? salEstimacion,
      grasasGr: _toGrams(grasas?.value, grasas?.unit),
      proteinaGr: _toGrams(proteina?.value, proteina?.unit),
      porcionGr: _toGrams(porcion?.value, porcion?.unit),
    );
  }

  static List<String> _splitNormalizedLines(String raw) {
    final normalized = _normalizeText(raw);
    return normalized
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  static String _normalizeText(String raw) {
    var text = raw.toLowerCase();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'ã': 'a',
      'å': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
      'ß': 'ss',
    };
    replacements.forEach((source, target) {
      text = text.replaceAll(source, target);
    });
    return text.replaceAll(',', '.');
  }

  static final RegExp _valueRegex = RegExp(
    r'([0-9o]{1,4}(?:\.[0-9o]{1,3})?)\s*(g|mg|ml)\b',
  );
  static final RegExp _numberOnlyRegex = RegExp(
    r'([0-9o]{1,4}(?:\.[0-9o]{1,3})?)',
  );

  static const List<String> _servingHints = [
    'porcion',
    'racion',
    'serving',
    'portion',
    'porzione',
    'porcao',
    'portion size',
    'tamano de porcion',
    'tamanho da porcao',
  ];

  static const List<String> _per100Hints = [
    '100g',
    '100 g',
    '100ml',
    '100 ml',
    'por 100',
    'per 100',
    'pour 100',
    'pro 100',
  ];

  static bool _containsAny(String line, List<String> terms) {
    for (final term in terms) {
      if (line.contains(term)) {
        return true;
      }
    }
    return false;
  }

  static bool _hasLikelyDualColumnLayout(List<_OcrLine> lines) {
    for (final line in lines) {
      final hasPer100 = _containsAny(line.text, _per100Hints);
      final valueCount = _valueRegex.allMatches(line.text).length;
      if (hasPer100 && valueCount >= 2) {
        return true;
      }
    }
    return false;
  }

  static bool _hasLikelyDualColumnLayoutFromText(List<String> lines) {
    for (final line in lines) {
      final hasPer100 = _containsAny(line, _per100Hints);
      final valueCount = _valueRegex.allMatches(line).length;
      if (hasPer100 && valueCount >= 2) {
        return true;
      }
    }
    return false;
  }

  static double? _parseFlexibleNumber(String raw) {
    final normalized = raw.toLowerCase().replaceAll('o', '0').trim();
    return double.tryParse(normalized);
  }

  static _ValorUnidad? _extractServingSize(List<String> lines) {
    for (final line in lines) {
      final lineMatches = _valueRegex.allMatches(line).toList();
      if (_containsAny(line, _per100Hints) && lineMatches.length >= 2) {
        final servingMatch = lineMatches.last;
        final value = _parseFlexibleNumber(servingMatch.group(1) ?? '');
        final unit = servingMatch.group(2);
        if (value != null && unit != null) {
          return _ValorUnidad(value, unit, score: 95);
        }
      }

      if (!_containsAny(line, _servingHints)) {
        continue;
      }
      final matches = _valueRegex.allMatches(line);
      for (final match in matches) {
        final value = _parseFlexibleNumber(match.group(1) ?? '');
        final unit = match.group(2);
        if (value != null && unit != null) {
          return _ValorUnidad(value, unit, score: 100);
        }
      }
    }
    return null;
  }

  static _ValorUnidad? _extractServingFromStructured(List<_OcrLine> lines) {
    _ValorUnidad? best;
    for (final anchor in lines) {
      if (!_containsAny(anchor.text, _servingHints)) {
        continue;
      }

      final neighbors = lines.where((line) {
        final closeVertically = (line.centerY - anchor.centerY).abs() <= 32;
        final atRight = line.left >= anchor.left - 5;
        return closeVertically && atRight;
      });

      for (final neighbor in neighbors) {
        final candidates = _extractValueCandidates(neighbor.text);
        final hasPer100AndDual =
            _containsAny(neighbor.text, _per100Hints) && candidates.length >= 2;

        for (var index = 0; index < candidates.length; index++) {
          final candidate = candidates[index];
          final grams =
              _toGrams(candidate.value, candidate.unit) ?? candidate.value;
          if (grams < 2 || grams > 1000) {
            continue;
          }

          var score = 50 - (neighbor.centerY - anchor.centerY).abs().toInt();
          if (hasPer100AndDual && index == candidates.length - 1) {
            score += 12;
          }
          final scored = _ValorUnidad(
            candidate.value,
            candidate.unit,
            score: score,
          );
          if (best == null || scored.score > best.score) {
            best = scored;
          }
        }
      }
    }
    return best;
  }

  static _ValorUnidad? _extractNutrientFromStructured(
    List<_OcrLine> lines, {
    required List<String> keywords,
    bool preferRightColumn = false,
  }) {
    _ValorUnidad? best;

    for (final anchor in lines) {
      if (!_containsAny(anchor.text, keywords)) {
        continue;
      }

      final nearby = lines.where((line) {
        final verticalDistance = (line.centerY - anchor.centerY).abs();
        final sameRow = verticalDistance <= 14;
        final nextRow = verticalDistance <= 36;
        final rightOrSame = line.left >= anchor.left - 12;
        return (sameRow || nextRow) && rightOrSame;
      });

      for (final candidateLine in nearby) {
        final hasPer100 = _containsAny(candidateLine.text, _per100Hints);
        final valueCandidates = _extractValueCandidates(candidateLine.text);
        for (var idx = 0; idx < valueCandidates.length; idx++) {
          final candidate = valueCandidates[idx];
          final grams = _toGrams(candidate.value, candidate.unit);
          if (grams == null || grams < 0 || grams > 200) {
            continue;
          }

          var score = 100;
          score -= (candidateLine.centerY - anchor.centerY).abs().toInt();
          if (candidateLine.left > anchor.right) {
            score += 10;
          }
          if (hasPer100) {
            score -= 15;
          }
          if (valueCandidates.length > 1 && idx == 0 && hasPer100) {
            score -= 10;
          }
          if (_containsAny(candidateLine.text, _servingHints)) {
            score += 12;
          }
          if (preferRightColumn && valueCandidates.length > 1) {
            if (idx == valueCandidates.length - 1) {
              score += 10;
            } else {
              score -= 8;
            }
          }

          final scored = _ValorUnidad(
            candidate.value,
            candidate.unit,
            score: score,
          );
          if (best == null || scored.score > best.score) {
            best = scored;
          }
        }
      }
    }

    return best;
  }

  static List<_ValorUnidad> _extractValueCandidates(String line) {
    final candidates = <_ValorUnidad>[];
    for (final match in _valueRegex.allMatches(line)) {
      final value = _parseFlexibleNumber(match.group(1) ?? '');
      final unit = match.group(2);
      if (value == null || unit == null) {
        continue;
      }
      candidates.add(_ValorUnidad(value, unit, score: 0));
    }

    if (candidates.isNotEmpty) {
      return candidates;
    }

    if (line.contains('kcal') || line.contains('kj')) {
      return candidates;
    }

    for (final match in _numberOnlyRegex.allMatches(line)) {
      final value = _parseFlexibleNumber(match.group(1) ?? '');
      if (value == null) {
        continue;
      }
      candidates.add(_ValorUnidad(value, 'g', score: 0));
    }

    return candidates;
  }

  static _ValorUnidad? _extractNutrientePorPorcion(
    List<String> lines, {
    required List<String> keywords,
    bool preferRightColumn = false,
  }) {
    _ValorUnidad? best;

    for (final line in lines) {
      if (!_containsAny(line, keywords)) {
        continue;
      }

      final candidates = <_ValorUnidad>[];
      for (final match in _valueRegex.allMatches(line)) {
        final value = _parseFlexibleNumber(match.group(1) ?? '');
        final unit = match.group(2);
        if (value == null || unit == null) {
          continue;
        }
        candidates.add(_ValorUnidad(value, unit, score: 0));
      }

      if (candidates.isEmpty) {
        continue;
      }

      final hasPer100 = _containsAny(line, _per100Hints);
      final hasServing = _containsAny(line, _servingHints);

      for (var index = 0; index < candidates.length; index++) {
        final candidate = candidates[index];
        var score = 0;

        if (hasServing) {
          score += 3;
        }
        if (hasPer100) {
          score -= 2;
        }

        if (candidates.length > 1) {
          if (hasPer100 && hasServing) {
            if (index == 0) {
              score -= 2;
            } else {
              score += 4;
            }
          } else if (hasPer100 && !hasServing) {
            if (index == 0) {
              score += 1;
            } else {
              score -= 1;
            }
          } else {
            if (index == 0) {
              score += 1;
            }
          }
        }

        if (preferRightColumn && candidates.length > 1) {
          if (index == candidates.length - 1) {
            score += 4;
          } else {
            score -= 3;
          }
        }

        final scored = _ValorUnidad(
          candidate.value,
          candidate.unit,
          score: score,
        );
        if (best == null || scored.score > best.score) {
          best = scored;
        }
      }
    }

    return best;
  }

  static double? _toGrams(double? value, String? unit) {
    if (value == null || unit == null) return null;
    if (unit.toLowerCase() == 'mg') {
      return value / 1000.0;
    }
    return value;
  }
}

class _ValorUnidad {
  const _ValorUnidad(this.value, this.unit, {required this.score});

  final double value;
  final String unit;
  final int score;
}

class _BarcodeCameraCaptureScreen extends StatefulWidget {
  const _BarcodeCameraCaptureScreen({required this.frameRectNormalized});

  final Rect frameRectNormalized;

  @override
  State<_BarcodeCameraCaptureScreen> createState() =>
      _BarcodeCameraCaptureScreenState();
}

class _BarcodeCameraCaptureScreenState
    extends State<_BarcodeCameraCaptureScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No se encontro camara disponible.';
          _initializing = false;
        });
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setFlashMode(FlashMode.off);

      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.scannerCameraInitError(
          e.toString(),
        );
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing || !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _capturing = true;
    });

    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.scannerTakePhotoError(e.toString()),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final topLabelRightInset =
        screenWidth < 360 ? 102.0 : (screenWidth < 420 ? 94.0 : 86.0);
    final captureButtonWidth =
        screenWidth < 360 ? 264.0 : (screenWidth < 420 ? 296.0 : 320.0);
    final captureLabelSize = screenWidth < 360 ? 21.0 : 24.0;
    final captureIconSize = screenWidth < 360 ? 30.0 : 34.0;
    final captureHorizontalInset = screenWidth < 360 ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              CameraPreview(_controller!),
            if (_initializing) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (!_initializing && _error == null)
              CustomPaint(
                painter: _BarcodeFocusFramePainter(
                  normalizedRect: widget.frameRectNormalized,
                ),
              ),
            if (!_initializing && _error == null)
              Positioned(
                top: 16,
                left: 16,
                right: topLabelRightInset,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.scannerFrameHint,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (!_initializing && _error == null)
              Positioned(
                top: 14,
                right: 14,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: l10n.commonCancel,
                    onPressed:
                        _capturing ? null : () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 32),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            Positioned(
              left: captureHorizontalInset,
              right: captureHorizontalInset,
              bottom: 16,
              child: Center(
                child: SizedBox(
                  width: captureButtonWidth,
                  child: FilledButton.icon(
                    onPressed: _capturing ? null : _capture,
                    icon: _capturing
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.camera_alt_outlined,
                            size: captureIconSize),
                    label: Text(
                      'Capturar',
                      style: TextStyle(
                        fontSize: captureLabelSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarcodeFocusFramePainter extends CustomPainter {
  const _BarcodeFocusFramePainter({required this.normalizedRect});

  final Rect normalizedRect;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromLTWH(
      size.width * normalizedRect.left,
      size.height * normalizedRect.top,
      size.width * normalizedRect.width,
      size.height * normalizedRect.height,
    );

    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(14)));

    final overlayPath = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(overlayPath, Paint()..color = Colors.black54);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, const Radius.circular(14)),
      borderPaint,
    );

    const corner = 22.0;
    final cornerPaint = Paint()
      ..color = Colors.lightGreenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    void drawCorner(Offset p1, Offset p2, Offset p3) {
      canvas.drawLine(p1, p2, cornerPaint);
      canvas.drawLine(p2, p3, cornerPaint);
    }

    drawCorner(
      Offset(frame.left, frame.top + corner),
      Offset(frame.left, frame.top),
      Offset(frame.left + corner, frame.top),
    );
    drawCorner(
      Offset(frame.right - corner, frame.top),
      Offset(frame.right, frame.top),
      Offset(frame.right, frame.top + corner),
    );
    drawCorner(
      Offset(frame.left, frame.bottom - corner),
      Offset(frame.left, frame.bottom),
      Offset(frame.left + corner, frame.bottom),
    );
    drawCorner(
      Offset(frame.right - corner, frame.bottom),
      Offset(frame.right, frame.bottom),
      Offset(frame.right, frame.bottom - corner),
    );
  }

  @override
  bool shouldRepaint(covariant _BarcodeFocusFramePainter oldDelegate) {
    return oldDelegate.normalizedRect != normalizedRect;
  }
}

class _OcrTrainingEntry {
  const _OcrTrainingEntry({
    required this.tokens,
    required this.azucarGr,
    required this.salGr,
    required this.grasasGr,
    required this.proteinaGr,
    required this.porcionGr,
    required this.updatedAtIso,
  });

  final Set<String> tokens;
  final double? azucarGr;
  final double? salGr;
  final double? grasasGr;
  final double? proteinaGr;
  final double? porcionGr;
  final String updatedAtIso;

  Map<String, dynamic> toJson() {
    return {
      'tokens': tokens.toList(growable: false),
      'azucarGr': azucarGr,
      'salGr': salGr,
      'grasasGr': grasasGr,
      'proteinaGr': proteinaGr,
      'porcionGr': porcionGr,
      'updatedAtIso': updatedAtIso,
    };
  }

  factory _OcrTrainingEntry.fromJson(Map<String, dynamic> json) {
    final rawTokens = json['tokens'];
    final tokenList =
        rawTokens is List ? rawTokens.whereType<String>().toSet() : <String>{};

    double? toDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value.replaceAll(',', '.'));
      }
      return null;
    }

    return _OcrTrainingEntry(
      tokens: tokenList,
      azucarGr: toDouble(json['azucarGr']),
      salGr: toDouble(json['salGr']),
      grasasGr: toDouble(json['grasasGr']),
      proteinaGr: toDouble(json['proteinaGr']),
      porcionGr: toDouble(json['porcionGr']),
      updatedAtIso:
          json['updatedAtIso']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}

class _OcrLine {
  const _OcrLine({
    required this.text,
    required this.left,
    required this.right,
    required this.centerY,
  });

  final String text;
  final double left;
  final double right;
  final double centerY;
}

class _OpenFoodFactsProduct {
  const _OpenFoodFactsProduct({
    required this.nombre,
    required this.marca,
    required this.barcode,
    required this.quantity,
    required this.ingredientes,
    required this.servingSize,
    required this.nutriScore,
    required this.novaGroup,
    required this.labels,
    required this.categories,
    required this.countries,
    required this.allergens,
    required this.traces,
    required this.additives,
    required this.nutriments,
    required this.rawData,
  });

  final String nombre;
  final String marca;
  final String barcode;
  final String quantity;
  final String ingredientes;
  final String? servingSize;
  final String nutriScore;
  final int? novaGroup;
  final List<String> labels;
  final List<String> categories;
  final List<String> countries;
  final List<String> allergens;
  final List<String> traces;
  final List<String> additives;
  final Map<String, dynamic> nutriments;
  final Map<String, dynamic> rawData;

  bool get hasAnyNutritionalData => nutriments.isNotEmpty;

  static List<String> _extractTagList(dynamic source, {String? trimPrefix}) {
    if (source is! List) {
      return const [];
    }

    final values = source
        .whereType<String>()
        .map((value) {
          var normalized = value.trim();
          if (trimPrefix != null && normalized.startsWith(trimPrefix)) {
            normalized = normalized.substring(trimPrefix.length);
          }
          if (normalized.contains(':')) {
            normalized = normalized.split(':').last;
          }
          normalized = normalized.replaceAll('-', ' ').replaceAll('_', ' ');
          if (normalized.isEmpty) return normalized;
          return normalized[0].toUpperCase() + normalized.substring(1);
        })
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return values;
  }

  factory _OpenFoodFactsProduct.fromJson(
    Map<String, dynamic> json, {
    String? barcodeFallback,
  }) {
    final nutrimentsRaw = json['nutriments'];
    return _OpenFoodFactsProduct(
      nombre: (json['product_name'] ?? json['generic_name'] ?? 'Producto')
          .toString(),
      marca: (json['brands'] ?? '').toString(),
      barcode: (json['code'] ?? barcodeFallback ?? '').toString(),
      quantity: (json['quantity'] ?? '').toString(),
      ingredientes:
          (json['ingredients_text_es'] ?? json['ingredients_text'] ?? '')
              .toString(),
      servingSize: json['serving_size']?.toString(),
      nutriScore: (json['nutriscore_grade'] ?? '').toString(),
      novaGroup: json['nova_group'] is num
          ? (json['nova_group'] as num).toInt()
          : int.tryParse((json['nova_group'] ?? '').toString()),
      labels: _extractTagList(json['labels_tags']),
      categories: _extractTagList(json['categories_tags']),
      countries: _extractTagList(json['countries_tags']),
      allergens: _extractTagList(json['allergens_tags']),
      traces: _extractTagList(json['traces_tags']),
      additives: _extractTagList(json['additives_tags']),
      nutriments: nutrimentsRaw is Map<String, dynamic>
          ? nutrimentsRaw
          : nutrimentsRaw is Map
              ? Map<String, dynamic>.from(nutrimentsRaw)
              : <String, dynamic>{},
      rawData: Map<String, dynamic>.from(json),
    );
  }
}
