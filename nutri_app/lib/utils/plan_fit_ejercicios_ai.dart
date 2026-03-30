import 'dart:convert';

const String defaultPlanFitEjerciciosAIPrompt =
    'Muéstrame un ejercicio de HIIT con el siguiente formato (te muestro un ejemplo):\n'
    '[Título]\n'
    'Escaladores (mountain climbers)\n'
    '[Cómo se hace]\n'
    '1️⃣ Colocarse en posición de plancha alta, con las manos apoyadas en el suelo alineadas debajo de los hombros, el cuerpo recto y el núcleo activado.\n'
    '2️⃣ Llevar una rodilla hacia el pecho, manteniendo la cadera baja y la espalda plana.\n'
    '3️⃣ Regresar la pierna a la posición inicial de forma explosiva y, al mismo tiempo, llevar la otra rodilla hacia el pecho.\n'
    '4️⃣ Alternar las piernas de manera continua y controlada, como si se estuviera corriendo en posición de plancha.\n'
    '5️⃣ Mantener la respiración constante y la mirada hacia el suelo para proteger el cuello.\n'
    '6️⃣ Seguir el movimiento sin dejar que las caderas se eleven o hundan, conservando la tensión abdominal.\n'
    '7️⃣ Finalizar volviendo a la posición de plancha alta o descansando según la repetición establecida.\n'
    '[Instrucciones cortas]\n'
    'En posición de plancha alta, alterna llevando cada rodilla hacia el pecho de forma explosiva y controlada. Mantén el abdomen firme, la cadera baja y el cuerpo alineado sin balancear las caderas.\n'
    '[Repeticiones]\n'
    '30\n'
    '[Tiempo]\n'
    '60\n'
    '[Peso]\n'
    '0\n'
    '[Descanso]\n'
    '25\n'
    '[Categorías]\n'
    'Cardio;Suelo\n'
    '[Hashtag]\n'
    '#escaladores #cardio #suelo #casa #treninferior #resistencia #............\n'
    '[Foto]\n'
    '(opcional: pega aquí el base64 de la imagen del ejercicio)';

class PlanFitEjercicioImportDraft {
  const PlanFitEjercicioImportDraft({
    required this.titulo,
    required this.comoSeHace,
    required this.instruccionesCortas,
    required this.repeticiones,
    required this.tiempo,
    required this.peso,
    required this.descanso,
    required this.categorias,
    required this.hashtag,
    this.foto = '',
  });

  final String titulo;
  final String comoSeHace;
  final String instruccionesCortas;
  final int repeticiones;
  final int tiempo;
  final int peso;
  final int descanso;
  final List<String> categorias;
  final String hashtag;

  /// Base64 de la imagen (sin espacios/saltos). Vacío si no se proporcionó.
  final String foto;
}

String normalizePlanFitEjercicioTitle(String title) {
  return title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'^[-*\d\s\.)]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String normalizePlanFitCategoriaName(String value) {
  final t = repairCommonMojibake(value).trim().toLowerCase();
  return t
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('û', 'u')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<PlanFitEjercicioImportDraft> parsePlanFitEjerciciosFromAI(String rawText) {
  final text = _normalizeClipboardText(rawText);
  if (text.isEmpty) {
    return <PlanFitEjercicioImportDraft>[];
  }

  final lines = text.split('\n');
  final blocks = <List<String>>[];
  List<String>? currentBlock;

  for (final line in lines) {
    final trimmedLeft = line.trimLeft();
    if (_isTag(trimmedLeft, 'titulo')) {
      if (currentBlock != null &&
          currentBlock.any((item) => item.trim().isNotEmpty)) {
        blocks.add(currentBlock);
      }
      currentBlock = <String>[line];
      continue;
    }

    if (currentBlock != null) {
      currentBlock.add(line);
    }
  }

  if (currentBlock != null &&
      currentBlock.any((item) => item.trim().isNotEmpty)) {
    blocks.add(currentBlock);
  }

  if (blocks.isEmpty) {
    final normalizedAll = _normalizeTagText(text);
    final hasTituloTag = RegExp(r'\[\s*titulo\s*\]', caseSensitive: false)
        .hasMatch(normalizedAll);
    final hasShortTag =
        RegExp(r'\[\s*instrucciones\s+cortas\s*\]', caseSensitive: false)
            .hasMatch(normalizedAll);
    if (hasTituloTag && hasShortTag) {
      blocks.add(lines);
    }
  }

  return blocks
      .map(_parsePlanFitEjercicioBlock)
      .whereType<PlanFitEjercicioImportDraft>()
      .toList(growable: false);
}

PlanFitEjercicioImportDraft? _parsePlanFitEjercicioBlock(List<String> lines) {
  final values = <String, List<String>>{};
  String? currentKey;

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    final normalized = line.trimLeft();

    final detectedKey = _detectTagKey(normalized);
    if (detectedKey != null) {
      currentKey = detectedKey;
      values.putIfAbsent(currentKey, () => <String>[]);
      final firstValue = _extractTagValue(normalized);
      if (firstValue.isNotEmpty) {
        values[currentKey]!.add(firstValue);
      }
      continue;
    }

    if (currentKey != null) {
      values.putIfAbsent(currentKey, () => <String>[]).add(line);
    }
  }

  final titulo = _joinValue(values['titulo']);
  final como = _joinValue(values['como_se_hace']);
  final cortas = _joinValue(values['instrucciones_cortas']);
  final repeticiones = _parseInt(_joinValue(values['repeticiones']));
  final tiempo = _parseInt(_joinValue(values['tiempo']));
  final peso = _parseInt(_joinValue(values['peso']));
  final descanso = _parseInt(_joinValue(values['descanso']));
  final categoriasRaw = _joinValue(values['categorias']);
  final hashtag = _joinValue(values['hashtag']);
  final foto = _joinFotoValue(values['foto']);

  if (titulo.isEmpty || cortas.isEmpty) {
    return null;
  }

  final categorias = categoriasRaw
      .split(';')
      .map((item) => repairCommonMojibake(item).trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  return PlanFitEjercicioImportDraft(
    titulo: _cleanTitleCandidate(titulo),
    comoSeHace: como,
    instruccionesCortas: cortas,
    repeticiones: repeticiones,
    tiempo: tiempo,
    peso: peso,
    descanso: descanso,
    categorias: categorias,
    hashtag: hashtag,
    foto: foto,
  );
}

String _joinValue(List<String>? lines) {
  if (lines == null || lines.isEmpty) return '';
  return lines.map((e) => e.trimRight()).join('\n').trim();
}

/// Join base64 lines stripping ALL whitespace so the result is a clean base64 string.
String _joinFotoValue(List<String>? lines) {
  if (lines == null || lines.isEmpty) return '';
  final joined = lines.map((e) => e.replaceAll(RegExp(r'\s'), '')).join();
  // Reject obvious non-base64 placeholder text
  if (joined.length < 32 || joined.contains('(')) return '';
  return joined;
}

int _parseInt(String text) {
  final normalized = text.trim().replaceAll(RegExp(r'[^\d-]'), '').trim();
  if (normalized.isEmpty) return 0;
  return int.tryParse(normalized) ?? 0;
}

String _extractTagValue(String line) {
  final idx = line.indexOf(']');
  if (idx < 0) return '';
  return line
      .substring(idx + 1)
      .replaceFirst(RegExp(r'^\s*[:\-–—]\s*'), '')
      .trim();
}

String _cleanTitleCandidate(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'^[-*\d\s\.)]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? _detectTagKey(String line) {
  if (_isTag(line, 'titulo')) return 'titulo';
  if (_isTag(line, 'como se hace')) return 'como_se_hace';
  if (_isTag(line, 'instrucciones cortas')) return 'instrucciones_cortas';
  if (_isTag(line, 'repeticiones')) return 'repeticiones';
  if (_isTag(line, 'tiempo')) return 'tiempo';
  if (_isTag(line, 'peso')) return 'peso';
  if (_isTag(line, 'descanso')) return 'descanso';
  if (_isTag(line, 'categorias') || _isTag(line, 'categorías')) {
    return 'categorias';
  }
  if (_isTag(line, 'hashtag')) return 'hashtag';
  if (_isTag(line, 'foto')) return 'foto';
  return null;
}

bool _isTag(String line, String tagText) {
  final normalized = _normalizeTagText(line);
  final needle = _normalizeTagText(tagText);
  return RegExp('^\\[\\s*${RegExp.escape(needle)}\\s*\\]').hasMatch(normalized);
}

String _normalizeClipboardText(String raw) {
  return repairCommonMojibake(raw)
      .replaceAll('\uFEFF', '')
      .replaceAll('\u200B', '')
      .replaceAll('\u200C', '')
      .replaceAll('\u200D', '')
      .replaceAll('\u2060', '')
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u2028', '\n')
      .replaceAll('\u2029', '\n')
      .replaceAll('\u0085', '\n')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
}

String repairCommonMojibake(String text) {
  if (text.isEmpty) return text;

  final likelyMojibake =
      text.contains('Ã') || text.contains('Â') || text.contains('â');
  if (!likelyMojibake) return text;

  try {
    final repaired = utf8.decode(latin1.encode(text));
    if (repaired.isNotEmpty &&
        repaired != text &&
        !repaired.contains('Ã') &&
        !repaired.contains('Â')) {
      return repaired;
    }
  } catch (_) {}

  return text
      .replaceAll('Ã¡', 'á')
      .replaceAll('Ã©', 'é')
      .replaceAll('Ã­', 'í')
      .replaceAll('Ã³', 'ó')
      .replaceAll('Ãº', 'ú')
      .replaceAll('Ã¼', 'ü')
      .replaceAll('Ã±', 'ñ')
      .replaceAll('Ã', 'Á')
      .replaceAll('Ã‰', 'É')
      .replaceAll('Ã', 'Í')
      .replaceAll('Ã“', 'Ó')
      .replaceAll('Ãš', 'Ú')
      .replaceAll('Ãœ', 'Ü')
      .replaceAll('Ã‘', 'Ñ')
      .replaceAll('â€“', '–')
      .replaceAll('â€”', '—')
      .replaceAll('â€˜', '‘')
      .replaceAll('â€™', '’')
      .replaceAll('â€œ', '“')
      .replaceAll('â€\u009d', '”')
      .replaceAll('â€¢', '•')
      .replaceAll('â€¦', '…');
}

String _normalizeTagText(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('û', 'u');
}
