const String defaultSuplementosAIPrompt =
    'muéstrame, con el siguiente formato, 10 suplementos alimenticios, '
    'con su descripción de para qué se usan y si hay alimentos "naturales" '
    'sustitutivos, al final, haces un salto de línea y añades hashtag '
    '(5 o 6) de lo más destacado del suplemento:\n\n'
    '[Título]\n'
    'Magnesio\n'
    '[Descripción]\n'
    'El magnesio es un mineral esencial que participa en más de 300 reacciones '
    'enzimáticas en el cuerpo, incluyendo la producción de energía, la síntesis '
    'de proteínas y la función muscular y nerviosa. Es fundamental para mantener '
    'el ritmo cardíaco, la presión arterial y la salud ósea.\n\n'
    '👉¿Para qué se usa?👈\n'
    '🟢 Para reducir la fatiga y el cansancio, favoreciendo la producción de energía celular.\n'
    '🟢 Para prevenir calambres musculares y favorecer la relajación muscular.\n'
    '🟢 Para combatir el insomnio y mejorar la calidad del sueño, especialmente el magnesio bisglicinato.\n'
    '🟢 Para aliviar el estreñimiento, actuando como un suave laxante osmótico (citrato de magnesio).\n'
    '🟢 Para regular el ritmo cardíaco y mantener la presión arterial dentro de rangos saludables.\n\n'
    '👉Alimentos sustitutivos naturales👈\n'
    '🟢 Frutos secos: almendras, nueces, anacardos.\n'
    '🟢 Semillas: calabaza, chía, lino.\n'
    '🟢 Verduras de hoja verde: espinacas, acelgas.\n'
    '🟢 Legumbres: frijoles negros, lentejas, garbanzos.\n'
    '🟢 Otros: plátano, aguacate, chocolate negro (≥85% cacao).\n\n'
    '#relajante #muscular #energía #sueño #electrolitos\n\n'
    'Repite este formato para 10 suplementos. '
    'Si falta información en algún suplemento, deja el campo [Descripción] con texto mínimo, '
    'pero no omitas [Título] ni [Descripción].';

class SuplementoImportDraft {
  const SuplementoImportDraft({
    required this.titulo,
    required this.descripcion,
  });

  final String titulo;
  final String descripcion;

  Map<String, dynamic> toCreatePayload() {
    return <String, dynamic>{
      'titulo': titulo.trim(),
      'descripcion': descripcion.trim(),
      'activo': 'S',
    };
  }
}

String normalizeSuplementoTitle(String title) {
  return title.trim().toLowerCase();
}

List<SuplementoImportDraft> parseSuplementosFromAI(String rawText) {
  final text = _normalizeClipboardText(rawText);
  if (text.isEmpty) {
    return <SuplementoImportDraft>[];
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

    if (hasTituloTag && hasDescripcionTag) {
      blocks.add(lines);
    }
  }

  return blocks
      .map(_parseSuplementoBlock)
      .whereType<SuplementoImportDraft>()
      .toList(growable: false);
}

SuplementoImportDraft? _parseSuplementoBlock(List<String> lines) {
  String titulo = '';
  final descripcionBuffer = <String>[];
  var collectingDescription = false;
  var waitingTitleValue = false;

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    final normalized = line.trimLeft();

    if (waitingTitleValue) {
      if (_isTituloTag(normalized) || _isDescripcionTag(normalized)) {
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
        !_isDescripcionTag(normalized)) {
      descripcionBuffer.add(line);
      continue;
    }

    if (_isTituloTag(normalized)) {
      collectingDescription = false;
      final extractedTitle =
          _extractTagValueByRegex(normalized, _tituloTagRegex);
      if (extractedTitle.isNotEmpty) {
        titulo = extractedTitle;
        waitingTitleValue = false;
      } else {
        waitingTitleValue = true;
      }
      continue;
    }

    if (_isDescripcionTag(normalized)) {
      collectingDescription = true;
      waitingTitleValue = false;
      final firstLine =
          _extractTagValueByRegex(normalized, _descripcionTagRegex);
      if (firstLine.isNotEmpty) {
        descripcionBuffer.add(firstLine);
      }
      continue;
    }
  }

  final descripcion = descripcionBuffer.join('\n').trim();
  if (titulo.trim().isEmpty || descripcion.isEmpty) {
    return null;
  }

  return SuplementoImportDraft(
    titulo: titulo.trim(),
    descripcion: descripcion,
  );
}

final RegExp _tituloTagRegex = RegExp(
  r'^\[\s*t[ií]tulo\s*\]\s*',
  caseSensitive: false,
);

final RegExp _descripcionTagRegex = RegExp(
  r'^\[\s*descripci[oó]n\s*\]\s*',
  caseSensitive: false,
);

String _extractTagValueByRegex(String line, RegExp tagRegex) {
  return line.replaceFirst(tagRegex, '').trim();
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

bool _isAnyTagLine(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('[') ||
      _isTituloTag(trimmed) ||
      _isDescripcionTag(trimmed);
}

String _normalizeClipboardText(String raw) {
  return raw
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
