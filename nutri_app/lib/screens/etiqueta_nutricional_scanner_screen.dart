import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nutri_app/screens/contacto_nutricionista_screen.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:provider/provider.dart';

class EtiquetaNutricionalScannerScreen extends StatefulWidget {
  const EtiquetaNutricionalScannerScreen({super.key});

  @override
  State<EtiquetaNutricionalScannerScreen> createState() =>
      _EtiquetaNutricionalScannerScreenState();
}

class _EtiquetaNutricionalScannerScreenState
    extends State<EtiquetaNutricionalScannerScreen> {
  final ImagePicker _picker = ImagePicker();

  File? _imagenSeleccionada;
  bool _analizando = false;
  String _textoDetectado = '';
  NutrientesPorPorcion? _nutrientes;

  Future<void> _seleccionarYAnalizar(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 100);
      if (picked == null) {
        return;
      }

      setState(() {
        _imagenSeleccionada = File(picked.path);
        _analizando = true;
        _textoDetectado = '';
        _nutrientes = null;
      });

      if (!Platform.isAndroid && !Platform.isIOS) {
        throw Exception('OCR no disponible en esta plataforma');
      }

      final inputImage = InputImage.fromFilePath(picked.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await recognizer.processImage(inputImage);
      await recognizer.close();

      final raw = recognizedText.text;
      final parsed = NutrientesPorPorcion.parse(raw);

      if (!mounted) return;
      setState(() {
        _textoDetectado = raw;
        _nutrientes = parsed;
        _analizando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analizando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo analizar la etiqueta: $e')),
      );
    }
  }

  bool get _allNutrientsNull =>
      _nutrientes != null &&
      _nutrientes!.azucarGr == null &&
      _nutrientes!.salGr == null &&
      _nutrientes!.grasasGr == null &&
      _nutrientes!.proteinaGr == null;

  @override
  Widget build(BuildContext context) {
    final resultado = _nutrientes;
    final isGuestMode = context.watch<AuthService>().isGuestMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escáner de etiquetas'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Haz una foto o selecciona una imagen para leer la etiqueta nutricional por porción.',
            ),
            if (isGuestMode) ...[
              const SizedBox(height: 12),
              _buildGuestGenericNotice(),
            ],
            const SizedBox(height: 12),
            _buildOrientativeHealthNotice(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _analizando
                        ? null
                        : () => _seleccionarYAnalizar(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Tomar foto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _analizando
                        ? null
                        : () => _seleccionarYAnalizar(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_imagenSeleccionada != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _imagenSeleccionada!,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            if (_analizando) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(child: Text('Analizando etiqueta...')),
            ],
            if (!_analizando && resultado != null) ...[
              const SizedBox(height: 20),
              if (_allNutrientsNull)
                _buildNoDataMessage()
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resultado por porción',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        _NutrienteEstadoTile(
                          titulo: 'Azúcar',
                          unidad: 'g',
                          valor: resultado.azucarGr,
                          estado: _estadoAzucar(resultado.azucarGr),
                        ),
                        _NutrienteEstadoTile(
                          titulo: 'Sal',
                          unidad: 'g',
                          valor: resultado.salGr,
                          estado: _estadoSal(resultado.salGr),
                        ),
                        _NutrienteEstadoTile(
                          titulo: 'Grasas',
                          unidad: 'g',
                          valor: resultado.grasasGr,
                          estado: _estadoGrasas(resultado.grasasGr),
                        ),
                        _NutrienteEstadoTile(
                          titulo: 'Proteína',
                          unidad: 'g',
                          valor: resultado.proteinaGr,
                          estado: _estadoProteina(resultado.proteinaGr),
                        ),
                        if (resultado.porcionGr != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Porción detectada: ${resultado.porcionGr!.toStringAsFixed(0)} g',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
            if (_textoDetectado.isNotEmpty) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Texto detectado (OCR)'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      _textoDetectado,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.camera_enhance_outlined,
                  color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No se han podido leer los valores nutricionales',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Para mejorar el resultado:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text('• Fotografía únicamente la tabla de información nutricional'),
          const Text('• Asegúrate de que haya buena iluminación'),
          const Text('• Mantén el texto nítido y bien enfocado'),
          const Text('• Evita reflejos y sombras sobre la etiqueta'),
          const Text('• Sostén el móvil paralelo a la etiqueta y cerca del texto'),
        ],
      ),
    );
  }

  Widget _buildGuestGenericNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Si quieres información más exacta debes registrarte (es gratis) e indicar tu edad y medidas (peso, cintura, cadera, ...).',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrientativeHealthNotice() {
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
                  'Aviso importante',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Estos cálculos e información son orientativos. Para una valoración personalizada, consulta siempre con un profesional médico o dietista-nutricionista.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContactoNutricionistaScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.support_agent, size: 18),
              label: const Text('Contactar con dietista'),
            ),
          ),
        ],
      ),
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

class _NutrienteEstadoTile extends StatelessWidget {
  const _NutrienteEstadoTile({
    required this.titulo,
    required this.unidad,
    required this.valor,
    required this.estado,
  });

  final String titulo;
  final String unidad;
  final double? valor;
  final _EstadoNutriente estado;

  @override
  Widget build(BuildContext context) {
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

    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      leading: Icon(Icons.circle, size: 14, color: color),
      title: Text(titulo),
      subtitle: Text(etiqueta),
      trailing: Text(
        valor == null ? '-' : '${valor!.toStringAsFixed(2)} $unidad',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
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

  static NutrientesPorPorcion parse(String text) {
    final normalized = _normalizeText(text);
    final lines = normalized
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final porcion = _extractServingSize(lines);

    final azucar = _extractNutrientePorPorcion(
      lines,
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
      keywords: const [
        'sal',
        'salt',
        'sale',
        'sel',
      ],
    );

    final sodio = _extractNutrientePorPorcion(
      lines,
      keywords: const [
        'sodio',
        'sodium',
        'natrium',
      ],
    );

    final grasas = _extractNutrientePorPorcion(
      lines,
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
    text = text.replaceAll(',', '.');
    // Fix common OCR digit/letter substitutions in numeric context.
    // 'o' between two digits: '1o5' → '105'
    text = text.replaceAllMapped(
      RegExp(r'(\d)o(\d)'),
      (m) => '${m.group(1)}0${m.group(2)}',
    );
    // 'o' after a digit immediately before a unit: '1og' → '10g', '1o g' → '10 g'
    text = text.replaceAllMapped(
      RegExp(r'(\d)o(\s*(?:gr?|mg|ml)\b)'),
      (m) => '${m.group(1)}0${m.group(2)}',
    );
    // Isolated 'o' (not preceded by a letter) before decimal point + digit: 'o.5' → '0.5'
    text = text.replaceAllMapped(
      RegExp(r'(?<![a-z])o\.(\d)'),
      (m) => '0.${m.group(1)}',
    );
    // Isolated 'o' (not preceded by a letter) immediately before a unit: 'o g' → '0 g'
    text = text.replaceAllMapped(
      RegExp(r'(?<![a-z])o(\s*(?:gr?|mg|ml)\b)'),
      (m) => '0${m.group(1)}',
    );
    // Isolated 'o' (not preceded by a letter) before digit: 'o5' → '05'
    text = text.replaceAllMapped(
      RegExp(r'(?<![a-z])o(\d)'),
      (m) => '0${m.group(1)}',
    );
    // 'l' between two digits: '1l5' → '115'
    text = text.replaceAllMapped(
      RegExp(r'(\d)l(\d)'),
      (m) => '${m.group(1)}1${m.group(2)}',
    );
    // 'l' after a digit immediately before a unit: '1lg' → '11g', '1l g' → '11 g'
    text = text.replaceAllMapped(
      RegExp(r'(\d)l(\s*(?:gr?|mg|ml)\b)'),
      (m) => '${m.group(1)}1${m.group(2)}',
    );
    return text;
  }

  static final RegExp _valueRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(gr?|mg|ml)\b');

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

  static _ValorUnidad? _extractServingSize(List<String> lines) {
    for (final line in lines) {
      if (!_containsAny(line, _servingHints)) {
        continue;
      }
      final matches = _valueRegex.allMatches(line);
      for (final match in matches) {
        final value = double.tryParse(match.group(1) ?? '');
        final unit = match.group(2);
        if (value != null && unit != null) {
          return _ValorUnidad(value, unit, score: 100);
        }
      }
    }
    return null;
  }

  static _ValorUnidad? _extractNutrientePorPorcion(
    List<String> lines, {
    required List<String> keywords,
  }) {
    _ValorUnidad? best;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!_containsAny(line, keywords)) {
        continue;
      }

      final candidates = <_ValorUnidad>[];
      for (final match in _valueRegex.allMatches(line)) {
        final value = double.tryParse(match.group(1) ?? '');
        final unit = match.group(2);
        if (value == null || unit == null) {
          continue;
        }
        candidates.add(_ValorUnidad(value, unit, score: 0));
      }

      // If no values found on the keyword line, look at the next line.
      // This handles labels where the nutrient name and its value are on
      // separate lines in the OCR output.
      if (candidates.isEmpty && i + 1 < lines.length) {
        final nextLine = lines[i + 1];
        for (final match in _valueRegex.allMatches(nextLine)) {
          final value = double.tryParse(match.group(1) ?? '');
          final unit = match.group(2);
          if (value == null || unit == null) {
            continue;
          }
          candidates.add(_ValorUnidad(value, unit, score: 0));
        }
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
          } else if (!hasPer100 && !hasServing) {
            // No column hints: per-100g usually listed first, so prefer the
            // last value which is more likely to be the per-portion amount.
            if (index == candidates.length - 1) {
              score += 1;
            }
          } else {
            // hasServing && !hasPer100: prefer first value
            if (index == 0) {
              score += 1;
            }
          }
        }

        final scored =
            _ValorUnidad(candidate.value, candidate.unit, score: score);
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
