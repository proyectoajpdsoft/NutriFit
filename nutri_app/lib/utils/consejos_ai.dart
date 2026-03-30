import 'dart:convert';

const String defaultConsejosAIPrompt =
    'muéstrame, para importar en una app de Nutrición y dietética, 10 consejos de salud, bienestar, ejercicio, alimentación saludable, mitos, mujer, etc, detallando bien la descripción, dado que es para personas sin conocimientos de estos temas, con ejemplos si hace falta y bien descrito y detallado, las categorías las separas (si hay varias) con ";", ejemplo de categorías: Salud, Mitos, Ejercicios, Nutrición, Plantas, Mujer, etc., al final de la Descripción, añade varios hashtag descriptivos, para la descripción puedes usar emojics para darle más personalidad (en medio del texto de la descripción, sin abusar), usa saltos de línea para separar párrafos, no es necesario que toda la descripción quede en un único párrafo, en el título no uses emojis. Si la descripción lleva viñetas, usa 🟢 y si hay viñetas con número, usa emojis de números. Te indico el formato para mostrar los consejos: \n'
    '[Título]\n'
    'xxxxxxx\n'
    '[Descripción]\n'
    'xxxxxxx\n'
    '[Categorías]\n'
    'Categoría1;Categoría2;...';

class ConsejoImportDraft {
  const ConsejoImportDraft({
    required this.titulo,
    required this.descripcion,
    required this.categorias,
  });

  final String titulo;
  final String descripcion;
  final List<String> categorias;
}

class ConsejoClipboardDraft {
  const ConsejoClipboardDraft({
    required this.titulo,
    required this.descripcion,
    this.categorias = const <String>[],
    this.hashtagsAutoGenerados = false,
  });

  final String titulo;
  final String descripcion;
  final List<String> categorias;
  final bool hashtagsAutoGenerados;
}

String normalizeConsejoTitle(String title) {
  return title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'^[-*\d\s\.)]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

ConsejoClipboardDraft? parseConsejoClipboardText(String rawText) {
  final normalized = _normalizeClipboardText(rawText);
  if (normalized.isEmpty) {
    return null;
  }

  final lines = normalized
      .split('\n')
      .map((line) => line.trimRight())
      .toList(growable: false);

  final firstNonEmptyIndex = lines.indexWhere((line) => line.trim().isNotEmpty);
  if (firstNonEmptyIndex < 0) {
    return null;
  }

  final tituloRaw = lines[firstNonEmptyIndex].trim();
  final titulo = _normalizeClipboardTitle(tituloRaw);
  if (titulo.isEmpty) {
    return null;
  }

  final remainingLines =
      lines.skip(firstNonEmptyIndex + 1).toList(growable: false);
  final metadataLine =
      remainingLines.isNotEmpty ? remainingLines.first.trim() : '';
  final categorias = _extractCategoriasFromClipboardMetadata(metadataLine);
  final shouldDiscardMetadataLine = _isClipboardMetadataLine(metadataLine);
  final rawBodyLines = <String>[];

  for (var i = 0; i < remainingLines.length; i++) {
    final line = remainingLines[i].trim();
    if (i == 0 && shouldDiscardMetadataLine) {
      continue;
    }
    if (_normalizedComparableClipboard(line) ==
        _normalizedComparableClipboard(tituloRaw)) {
      continue;
    }
    if (_isDisposableClipboardMetadataLine(line)) {
      continue;
    }
    rawBodyLines.add(remainingLines[i]);
  }

  final bodyLines = _formatClipboardBodyLines(rawBodyLines);
  final descriptionLines = bodyLines.join('\n').trim();

  if (descriptionLines.isEmpty) {
    return null;
  }

  final hasHashtags = _hasClipboardHashtags(descriptionLines);
  final hashtags = hasHashtags
      ? ''
      : _buildAutomaticClipboardHashtags(titulo, descriptionLines);
  final descripcionFinal = hasHashtags || hashtags.isEmpty
      ? descriptionLines
      : '$descriptionLines\n\n$hashtags';

  return ConsejoClipboardDraft(
    titulo: titulo,
    descripcion: descripcionFinal,
    categorias: categorias,
    hashtagsAutoGenerados: !hasHashtags && hashtags.isNotEmpty,
  );
}

bool _isClipboardMetadataLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  final hasDateLikeToken = RegExp(
    r'(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic|jan|feb|apr|aug|sept|oct|nov|dec)\s+\d{1,2},\s+\d{4}',
    caseSensitive: false,
  ).hasMatch(trimmed);

  final looksLikeTags = RegExp(r'\|').hasMatch(trimmed);

  return hasDateLikeToken || looksLikeTags;
}

bool _isDisposableClipboardMetadataLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  final normalized = _normalizedComparableClipboard(trimmed);

  if (normalized.startsWith('compartir') ||
      normalized.startsWith('guardar') ||
      normalized.startsWith('imprimir') ||
      normalized.startsWith('suscrib') ||
      normalized.startsWith('anuncio') ||
      normalized.startsWith('publicidad') ||
      normalized.startsWith('calorias')) {
    return true;
  }

  return false;
}

String _normalizeClipboardTitle(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  // Primero collapsar espacios y trim
  final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');

  // Detectar si está en MAYÚSCULAS FIJAS (solo letras)
  final lettersOnly =
      normalized.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]'), '');
  final isAllCaps =
      lettersOnly.isNotEmpty && lettersOnly == lettersOnly.toUpperCase();

  if (!isAllCaps) {
    return normalized;
  }

  // Convertir a minúsculas y capitalizar
  final lower = normalized.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

String _normalizedComparableClipboard(String raw) {
  return raw.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

List<String> _extractCategoriasFromClipboardMetadata(String metadataLine) {
  final normalized = metadataLine.trim();
  if (normalized.isEmpty) {
    return const <String>[];
  }

  final chunks = normalized
      .split('|')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  if (chunks.length <= 1) {
    return const <String>[];
  }

  final candidateChunks = chunks.skip(1).toList(growable: false);
  final result = <String>[];
  final seen = <String>{};

  for (final chunk in candidateChunks) {
    final rawItems = chunk
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    for (final item in rawItems) {
      final comparable = _normalizedComparableClipboard(item);
      if (comparable.isEmpty) continue;
      if (comparable.contains(RegExp(r'\d{1,2},\s*\d{4}'))) continue;
      if (comparable.length < 3) continue;
      if (seen.add(comparable)) {
        result.add(item);
      }
    }
  }

  return result;
}

List<String> _formatClipboardBodyLines(List<String> lines) {
  final cleaned = <String>[];

  for (final line in lines) {
    final raw = line.trimRight();
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      if (cleaned.isNotEmpty && cleaned.last.isNotEmpty) {
        cleaned.add('');
      }
      continue;
    }

    cleaned.add(trimmed);
  }

  while (cleaned.isNotEmpty && cleaned.first.isEmpty) {
    cleaned.removeAt(0);
  }
  while (cleaned.isNotEmpty && cleaned.last.isEmpty) {
    cleaned.removeLast();
  }

  return cleaned;
}

bool _hasClipboardHashtags(String text) {
  return RegExp(r'(^|\s)#[\p{L}\p{N}_]+', unicode: true).hasMatch(text);
}

String _buildAutomaticClipboardHashtags(String titulo, String descripcion) {
  final titleTokens = _tokenizeForClipboardHashtags(titulo, max: 3);
  final bodyTokens = _tokenizeForClipboardHashtags(descripcion, max: 4);

  final ordered = <String>[];
  for (final token in [...titleTokens, ...bodyTokens]) {
    if (!ordered.contains(token)) {
      ordered.add(token);
    }
  }

  if (ordered.isEmpty) {
    return '#ConsejoSalud';
  }

  return ordered.map((token) => '#$token').join(' ');
}

List<String> _tokenizeForClipboardHashtags(String text, {required int max}) {
  final normalized = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (normalized.isEmpty) {
    return const <String>[];
  }

  final stopwords = <String>{
    'de',
    'la',
    'el',
    'y',
    'en',
    'para',
    'con',
    'por',
    'del',
    'las',
    'los',
    'un',
    'una',
    'al',
    'que',
    'se',
    'lo',
    'su',
    'sus',
    'como',
    'más',
    'mas',
  };

  final result = <String>[];
  for (final word in normalized.split(' ')) {
    if (word.length < 3) continue;
    if (stopwords.contains(word)) continue;

    final hashtag = _toPascalClipboardCase(word);
    if (hashtag.isEmpty) continue;
    if (!result.contains(hashtag)) {
      result.add(hashtag);
      if (result.length >= max) break;
    }
  }

  return result;
}

String _toPascalClipboardCase(String value) {
  final cleaned =
      value.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').trim();
  if (cleaned.isEmpty) return '';

  if (cleaned.length == 1) {
    return cleaned.toUpperCase();
  }

  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

List<ConsejoImportDraft> parseConsejosFromAI(String rawText) {
  final text = _normalizeClipboardText(rawText);
  if (text.isEmpty) {
    return <ConsejoImportDraft>[];
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
    final hasCategoriasTag = RegExp(
      r'\[\s*categorias\s*\]',
      caseSensitive: false,
    ).hasMatch(normalizedAll);

    if (hasTituloTag && hasDescripcionTag && hasCategoriasTag) {
      blocks.add(lines);
    }
  }

  return blocks
      .map(_parseConsejoBlock)
      .whereType<ConsejoImportDraft>()
      .toList(growable: false);
}

ConsejoImportDraft? _parseConsejoBlock(List<String> lines) {
  String titulo = '';
  final descripcionBuffer = <String>[];
  final categoriasBuffer = <String>[];
  var collectingDescription = false;
  var collectingCategorias = false;
  var waitingTitleValue = false;

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    final normalized = line.trimLeft();

    if (waitingTitleValue) {
      if (_isTituloTag(normalized) ||
          _isDescripcionTag(normalized) ||
          _isCategoriasTag(normalized)) {
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
        !_isCategoriasTag(normalized)) {
      descripcionBuffer.add(line);
      continue;
    }

    if (collectingCategorias &&
        !_isTituloTag(normalized) &&
        !_isDescripcionTag(normalized) &&
        !_isCategoriasTag(normalized)) {
      final value = normalized.trim();
      if (value.isNotEmpty) {
        categoriasBuffer.add(value);
      }
      continue;
    }

    if (_isTituloTag(normalized)) {
      collectingDescription = false;
      collectingCategorias = false;
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
      collectingCategorias = false;
      waitingTitleValue = false;
      final firstLine = _extractTagValue(normalized);
      if (firstLine.isNotEmpty) {
        descripcionBuffer.add(firstLine);
      }
      continue;
    }

    if (_isCategoriasTag(normalized)) {
      collectingDescription = false;
      collectingCategorias = true;
      waitingTitleValue = false;
      final categoriasLine = _extractTagValue(normalized);
      if (categoriasLine.isNotEmpty) {
        categoriasBuffer.add(categoriasLine);
      }
      continue;
    }
  }

  final descripcion = descripcionBuffer.join('\n').trim();
  final categorias = _parseCategorias(categoriasBuffer.join('\n'));
  if (titulo.trim().isEmpty || descripcion.isEmpty) {
    return null;
  }

  return ConsejoImportDraft(
    titulo: _cleanTitleCandidate(titulo),
    descripcion: descripcion,
    categorias: categorias,
  );
}

List<String> _parseCategorias(String raw) {
  if (raw.trim().isEmpty) return const <String>[];
  final seen = <String>{};
  final result = <String>[];

  for (final item in raw.split(RegExp(r'[;|\n\r]+'))) {
    final value =
        repairCommonMojibake(item).replaceFirst(RegExp(r'^[-*\s]+'), '').trim();
    if (value.isEmpty) continue;
    final key = value.toLowerCase();
    if (!seen.add(key)) continue;
    result.add(value);
  }

  return result;
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

bool _isCategoriasTag(String line) {
  final normalized = _normalizeTagText(line);
  return RegExp(r'^\[\s*categorias\s*\]', caseSensitive: false)
      .hasMatch(normalized);
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
