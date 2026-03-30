import 'dart:convert';

const String defaultAditivosAIPrompt =
    'muéstrame, con el siguiente formato, 10 aditivos alimentarios, '
    'incluyendo para qué sirven, una explicación detallada y hashtags destacados. '
    'Añade también el campo [Tipo] para su correcta clasificación y el campo [Peligrosidad] de 1 a 5, donde: 1 (seguro), 2 (atención), 3 (alto), 4 (restringido), 5 (prohibido):\n\n'
    '[Título]\n'
    'E-300 Ácido ascórbico\n'
    '[Descripción]\n'
    'Sirve como antioxidante (evita que las frutas, verduras en conserva y carnicerías se oxiden y ennegrezcan) y como conservante natural...\n\n'
    '#ácidoascórbico #antioxidante #oxidación\n'
    '[Tipo]\n'
    'Antioxidantes\n\n'
    '[Peligrosidad]\n'
    '1';

const List<String> defaultAditivoTypes = <String>[
  'Colorantes',
  'Conservantes',
  'Antioxidantes',
  'Espesantes, Emulgentes, Estabilizantes',
  'Reguladores pH y Gasificantes',
  'Potenciadores de sabor',
  'Edulcorantes, Gases, Mejoradores',
  'Mejoradores de harina Humectantes',
  'Antiaglomerantes',
  'Gases',
  'Enzimas',
  'Agente de recubrimiento',
];

List<String> parseAditivoTypes(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <String>[];
  return raw
      .split(RegExp(r'[\n\r,;|]+'))
      .map((item) => repairCommonMojibake(item).trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> mergeAditivoTypes(Iterable<String> sources) {
  final seen = <String>{};
  final result = <String>[];

  for (final raw in sources) {
    final value = repairCommonMojibake(raw).trim();
    if (value.isEmpty) continue;
    final key = normalizeAditivoTitle(value);
    if (key.isEmpty || !seen.add(key)) continue;
    result.add(value);
  }

  return result;
}

class AditivoImportDraft {
  const AditivoImportDraft({
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    this.peligrosidad,
  });

  final String titulo;
  final String descripcion;
  final String tipo;
  final int? peligrosidad;

  Map<String, dynamic> toCreatePayload() {
    return <String, dynamic>{
      'titulo': titulo.trim(),
      'descripcion': descripcion.trim(),
      'tipo': tipo.trim(),
      'activo': 'S',
      if (peligrosidad != null) 'peligrosidad': peligrosidad,
    };
  }
}

String normalizeAditivoTitle(String title) {
  return title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'^[-*\d\s\.)]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<AditivoImportDraft> parseAditivosFromAI(String rawText) {
  final text = _normalizeClipboardText(rawText);
  if (text.isEmpty) {
    return <AditivoImportDraft>[];
  }

  final lines = text.split('\n');
  final blocks = <List<String>>[];
  List<String>? currentBlock;

  for (final line in lines) {
    final trimmedLeft = line.trimLeft();
    if (_isTituloTag(trimmedLeft)) {
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
    final hasDescripcionTag = RegExp(
      r'\[\s*descripcion\s*\]',
      caseSensitive: false,
    ).hasMatch(normalizedAll);
    final hasTipoTag =
        RegExp(r'\[\s*tipo\s*\]', caseSensitive: false).hasMatch(normalizedAll);

    if (hasTituloTag && hasDescripcionTag && hasTipoTag) {
      blocks.add(lines);
    }
  }

  return blocks
      .map(_parseAditivoBlock)
      .whereType<AditivoImportDraft>()
      .toList(growable: false);
}

AditivoImportDraft? _parseAditivoBlock(List<String> lines) {
  String titulo = '';
  final descripcionBuffer = <String>[];
  String tipo = '';
  int? peligrosidad;
  var collectingDescription = false;
  var collectingTipo = false;
  var collectingPeligrosidad = false;
  var waitingTitleValue = false;

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    final normalized = line.trimLeft();

    if (waitingTitleValue) {
      if (_isTituloTag(normalized) ||
          _isDescripcionTag(normalized) ||
          _isTipoTag(normalized) ||
          _isPeligrosidadTag(normalized)) {
        waitingTitleValue = false;
      } else {
        final candidateTitle = normalized.trim();
        if (candidateTitle.isNotEmpty) {
          titulo = candidateTitle;
          waitingTitleValue = false;
          continue;
        }
      }
    }

    if (collectingDescription &&
        !_isTituloTag(normalized) &&
        !_isDescripcionTag(normalized) &&
        !_isTipoTag(normalized) &&
        !_isPeligrosidadTag(normalized)) {
      descripcionBuffer.add(line);
      continue;
    }

    if (collectingTipo &&
        !_isTituloTag(normalized) &&
        !_isDescripcionTag(normalized) &&
        !_isTipoTag(normalized) &&
        !_isPeligrosidadTag(normalized)) {
      final value = normalized.trim();
      if (value.isNotEmpty) {
        tipo = value;
      }
      continue;
    }

    if (collectingPeligrosidad &&
        !_isTituloTag(normalized) &&
        !_isDescripcionTag(normalized) &&
        !_isTipoTag(normalized) &&
        !_isPeligrosidadTag(normalized)) {
      final value = int.tryParse(normalized.trim());
      if (value != null && value >= 1 && value <= 5) {
        peligrosidad = value;
      }
      continue;
    }

    if (_isTituloTag(normalized)) {
      collectingDescription = false;
      collectingTipo = false;
      collectingPeligrosidad = false;
      final extractedTitle = _extractTagValue(normalized);
      if (extractedTitle.isNotEmpty) {
        titulo = _cleanTitleCandidate(extractedTitle);
        waitingTitleValue = false;
      } else {
        waitingTitleValue = true;
      }
      continue;
    }

    if (_isDescripcionTag(normalized)) {
      collectingDescription = true;
      collectingTipo = false;
      collectingPeligrosidad = false;
      waitingTitleValue = false;
      final firstLine = _extractTagValue(normalized);
      if (firstLine.isNotEmpty) {
        descripcionBuffer.add(firstLine);
      }
      continue;
    }

    if (_isTipoTag(normalized)) {
      collectingDescription = false;
      collectingTipo = true;
      collectingPeligrosidad = false;
      waitingTitleValue = false;
      final tipoLinea = _extractTagValue(normalized);
      if (tipoLinea.isNotEmpty) {
        tipo = tipoLinea;
      }
      continue;
    }

    if (_isPeligrosidadTag(normalized)) {
      collectingDescription = false;
      collectingTipo = false;
      collectingPeligrosidad = true;
      waitingTitleValue = false;
      final peligrosidadLinea = int.tryParse(_extractTagValue(normalized));
      if (peligrosidadLinea != null &&
          peligrosidadLinea >= 1 &&
          peligrosidadLinea <= 5) {
        peligrosidad = peligrosidadLinea;
      }
      continue;
    }
  }

  final descripcion = descripcionBuffer.join('\n').trim();
  if (titulo.trim().isEmpty || descripcion.isEmpty || tipo.trim().isEmpty) {
    return null;
  }

  return AditivoImportDraft(
    titulo: _cleanTitleCandidate(titulo),
    descripcion: descripcion,
    tipo: tipo.trim(),
    peligrosidad: peligrosidad,
  );
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

bool _isTituloTag(String line) {
  final normalized = _normalizeTagText(line);
  return RegExp(r'^\[\s*titulo\s*\]', caseSensitive: false)
      .hasMatch(normalized);
}

bool _isDescripcionTag(String line) {
  final normalized = _normalizeTagText(line);
  return RegExp(r'^\[\s*descripcion\s*\]', caseSensitive: false)
      .hasMatch(normalized);
}

bool _isTipoTag(String line) {
  final normalized = _normalizeTagText(line);
  return RegExp(r'^\[\s*tipo\s*\]', caseSensitive: false).hasMatch(normalized);
}

bool _isPeligrosidadTag(String line) {
  final normalized = _normalizeTagText(line);
  return RegExp(r'^\[\s*peligrosidad\s*\]', caseSensitive: false)
      .hasMatch(normalized);
}

bool _isAnyTagLine(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('[') ||
      _isTituloTag(trimmed) ||
      _isDescripcionTag(trimmed) ||
      _isTipoTag(trimmed) ||
      _isPeligrosidadTag(trimmed);
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
  } catch (_) {
    // Fallback to manual replacement table below.
  }

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
      .replaceAll('Ã‘', 'Ñ')
      .replaceAll('Â¡', '¡')
      .replaceAll('Â¿', '¿')
      .replaceAll('â€“', '–')
      .replaceAll('â€”', '—')
      .replaceAll('â€œ', '“')
      .replaceAll('â€', '”')
      .replaceAll('â€˜', '‘')
      .replaceAll('â€™', '’')
      .replaceAll('â€¢', '•')
      .replaceAll('â€¦', '…')
      .replaceAll('â†’', '→');
}

String _normalizeTagText(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll('Ã¡', 'a')
      .replaceAll('Ã©', 'e')
      .replaceAll('Ã­', 'i')
      .replaceAll('Ã³', 'o')
      .replaceAll('Ãº', 'u')
      .replaceAll('Ã¼', 'u')
      .replaceAll('Ã±', 'n')
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
