class RecetaClipboardDraft {
  const RecetaClipboardDraft({
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

class RecetaImportDraft {
  const RecetaImportDraft({
    required this.titulo,
    required this.descripcion,
    required this.categorias,
  });

  final String titulo;
  final String descripcion;
  final List<String> categorias;
}

String normalizeRecetaTitle(String title) {
  return title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'^[-*\d\s\.)]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<RecetaImportDraft> parseRecetasFromAI(String rawText) {
  final text = _normalizeClipboardText(rawText);
  if (text.isEmpty) {
    return <RecetaImportDraft>[];
  }

  final lines = text.split('\n');
  final blocks = <List<String>>[];
  List<String>? currentBlock;

  for (final line in lines) {
    final trimmedLeft = line.trimLeft();
    if (_isTituloTagIA(trimmedLeft)) {
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
    final hasTituloTag =
        RegExp(r'\[\s*t[ií]tulo\s*\]', caseSensitive: false).hasMatch(text);
    final hasDescripcionTag =
        RegExp(r'\[\s*descripci[oó]n\s*\]', caseSensitive: false)
            .hasMatch(text);
    final hasCategoriasTag =
        RegExp(r'\[\s*categor[ií]as\s*\]', caseSensitive: false).hasMatch(text);

    if (hasTituloTag && hasDescripcionTag && hasCategoriasTag) {
      blocks.add(lines);
    }
  }

  return blocks
      .map(_parseRecetaBlockIA)
      .whereType<RecetaImportDraft>()
      .toList(growable: false);
}

RecetaImportDraft? _parseRecetaBlockIA(List<String> lines) {
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
      if (_isTituloTagIA(normalized) ||
          _isDescripcionTagIA(normalized) ||
          _isCategoriasTagIA(normalized)) {
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
        !_isTituloTagIA(normalized) &&
        !_isDescripcionTagIA(normalized) &&
        !_isCategoriasTagIA(normalized)) {
      descripcionBuffer.add(line);
      continue;
    }

    if (collectingCategorias &&
        !_isTituloTagIA(normalized) &&
        !_isDescripcionTagIA(normalized) &&
        !_isCategoriasTagIA(normalized)) {
      final value = normalized.trim();
      if (value.isNotEmpty) {
        categoriasBuffer.add(value);
      }
      continue;
    }

    if (_isTituloTagIA(normalized)) {
      collectingDescription = false;
      collectingCategorias = false;
      final extractedTitle = _extractTagValueIA(normalized);
      if (extractedTitle.isNotEmpty) {
        titulo = _cleanTitleCandidateIA(extractedTitle);
        waitingTitleValue = false;
      } else {
        waitingTitleValue = true;
      }
      continue;
    }

    if (_isDescripcionTagIA(normalized)) {
      collectingDescription = true;
      collectingCategorias = false;
      waitingTitleValue = false;
      final firstLine = _extractTagValueIA(normalized);
      if (firstLine.isNotEmpty) {
        descripcionBuffer.add(firstLine);
      }
      continue;
    }

    if (_isCategoriasTagIA(normalized)) {
      collectingDescription = false;
      collectingCategorias = true;
      waitingTitleValue = false;
      final categoriasLine = _extractTagValueIA(normalized);
      if (categoriasLine.isNotEmpty) {
        categoriasBuffer.add(categoriasLine);
      }
      continue;
    }
  }

  final descripcion = descripcionBuffer.join('\n').trim();
  final categorias = _parseCategoriasIA(categoriasBuffer.join('\n'));
  if (titulo.trim().isEmpty || descripcion.isEmpty) {
    return null;
  }

  return RecetaImportDraft(
    titulo: _cleanTitleCandidateIA(titulo),
    descripcion: descripcion,
    categorias: categorias,
  );
}

List<String> _parseCategoriasIA(String raw) {
  if (raw.trim().isEmpty) return const <String>[];
  final seen = <String>{};
  final result = <String>[];

  for (final item in raw.split(RegExp(r'[;|\n\r]+'))) {
    final value = item.replaceFirst(RegExp(r'^[-*\s]+'), '').trim();
    if (value.isEmpty) continue;
    final key = value.toLowerCase();
    if (!seen.add(key)) continue;
    result.add(value);
  }

  return result;
}

String _extractTagValueIA(String line) {
  final idx = line.indexOf(']');
  if (idx < 0) return '';
  return line
      .substring(idx + 1)
      .replaceFirst(RegExp(r'^\s*[:\-–—]\s*'), '')
      .trim();
}

String _cleanTitleCandidateIA(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'^[-*\d\s\.)]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _isTituloTagIA(String line) {
  return RegExp(r'^\[\s*t[ií]tulo\s*\]', caseSensitive: false).hasMatch(line);
}

bool _isDescripcionTagIA(String line) {
  return RegExp(r'^\[\s*descripci[oó]n\s*\]', caseSensitive: false)
      .hasMatch(line);
}

bool _isCategoriasTagIA(String line) {
  return RegExp(r'^\[\s*categor[ií]as\s*\]', caseSensitive: false)
      .hasMatch(line);
}

RecetaClipboardDraft? parseRecetaClipboardText(String rawText) {
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
  final titulo = _normalizeTitle(tituloRaw);
  if (titulo.isEmpty) {
    return null;
  }

  final remainingLines =
      lines.skip(firstNonEmptyIndex + 1).toList(growable: false);
  final metadataLine =
      remainingLines.isNotEmpty ? remainingLines.first.trim() : '';
  final categorias = _extractCategoriasFromMetadataLine(metadataLine);
  final shouldDiscardMetadataLine = _isMetadataLine(metadataLine);
  final rawBodyLines = <String>[];

  for (var i = 0; i < remainingLines.length; i++) {
    final line = remainingLines[i].trim();
    if (i == 0 && shouldDiscardMetadataLine) {
      continue;
    }
    if (_normalizedComparable(line) == _normalizedComparable(tituloRaw)) {
      continue;
    }
    if (_isDisposableMetadataLine(line)) {
      continue;
    }
    rawBodyLines.add(remainingLines[i]);
  }

  final bodyLines = _formatRecipeBodyLines(rawBodyLines);

  final descriptionLines = bodyLines.join('\n').trim();

  if (descriptionLines.isEmpty) {
    return null;
  }

  final hasHashtags = _hasHashtags(descriptionLines);
  final hashtags =
      hasHashtags ? '' : _buildAutomaticHashtags(titulo, descriptionLines);
  final descripcionFinal = hasHashtags || hashtags.isEmpty
      ? descriptionLines
      : '$descriptionLines\n\n$hashtags';

  return RecetaClipboardDraft(
    titulo: titulo,
    descripcion: descripcionFinal,
    categorias: categorias,
    hashtagsAutoGenerados: !hasHashtags && hashtags.isNotEmpty,
  );
}

bool _isMetadataLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  if (!trimmed.contains('|')) {
    return false;
  }

  final parts =
      trimmed.split('|').map((part) => part.trim()).toList(growable: false);
  if (parts.length < 2) {
    return false;
  }

  return true;
}

bool _isDisposableMetadataLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  if (_isMetadataLine(trimmed)) {
    return true;
  }
  if (RegExp(r'^(https?:\/\/|www\.)', caseSensitive: false).hasMatch(trimmed)) {
    return true;
  }
  if (RegExp(r'^(autor|author)\s*[:|-]', caseSensitive: false)
      .hasMatch(trimmed)) {
    return true;
  }
  if (RegExp(r'^por\s+[a-záéíóúüñ ]+$', caseSensitive: false)
      .hasMatch(trimmed)) {
    return true;
  }
  if (RegExp(r'imagen del portapapeles', caseSensitive: false)
      .hasMatch(trimmed)) {
    return true;
  }
  if (RegExp(
    r'^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2},\s+\d{4}$',
    caseSensitive: false,
  ).hasMatch(trimmed)) {
    return true;
  }
  if (RegExp(r'^\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}$').hasMatch(trimmed)) {
    return true;
  }

  return false;
}

List<String> _formatRecipeBodyLines(List<String> lines) {
  final result = <String>[];

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      if (result.isNotEmpty && result.last.isNotEmpty) {
        result.add('');
      }
      continue;
    }

    final formattedHeader = _normalizeRecipeSectionHeader(line);
    if (formattedHeader != null) {
      if (result.isNotEmpty && result.last.isNotEmpty) {
        result.add('');
      }
      result.add(formattedHeader);
      result.add('');
      continue;
    }

    result.add(rawLine.trimRight());
  }

  while (result.isNotEmpty && result.first.isEmpty) {
    result.removeAt(0);
  }
  while (result.isNotEmpty && result.last.isEmpty) {
    result.removeLast();
  }

  return result;
}

String? _normalizeRecipeSectionHeader(String line) {
  final normalized = _normalizedComparable(
    line.replaceAll('👉', '').replaceAll('👈', ''),
  );

  switch (normalized) {
    case 'ingredientes':
      return '👉Ingredientes👈';
    case 'preparacion':
      return '👉Preparación👈';
    case 'elaboracion':
      return '👉Elaboración👈';
    default:
      return null;
  }
}

List<String> _extractCategoriasFromMetadataLine(String line) {
  if (!line.contains('|')) {
    return const <String>[];
  }

  final pipeIndex = line.indexOf('|');
  if (pipeIndex < 0 || pipeIndex + 1 >= line.length) {
    return const <String>[];
  }

  final trailing = line.substring(pipeIndex + 1);
  final secondPipeIndex = trailing.indexOf('|');
  final categoriesChunk =
      (secondPipeIndex >= 0 ? trailing.substring(0, secondPipeIndex) : trailing)
          .trim();
  if (categoriesChunk.isEmpty) {
    return const <String>[];
  }

  final unique = <String>[];
  for (final raw in categoriesChunk.split(',')) {
    final name = _toCategoryLabel(raw.trim());
    if (name.isEmpty) {
      continue;
    }
    if (!unique.any((existing) =>
        _normalizedComparable(existing) == _normalizedComparable(name))) {
      unique.add(name);
    }
  }
  return unique;
}

String _toCategoryLabel(String value) {
  if (value.isEmpty) {
    return '';
  }
  final lower = value.toLowerCase();
  return lower.isEmpty ? '' : lower[0].toUpperCase() + lower.substring(1);
}

String _normalizeTitle(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  // Collapsar espacios múltiples
  final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');

  final lettersOnly =
      normalized.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]'), '');
  final isAllCaps =
      lettersOnly.isNotEmpty && lettersOnly == lettersOnly.toUpperCase();
  if (!isAllCaps) {
    return normalized;
  }

  final lower = normalized.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

String _normalizedComparable(String value) {
  return _stripDiacritics(value.toLowerCase())
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _normalizeClipboardText(String raw) {
  return raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
      .trim();
}

bool _hasHashtags(String text) {
  return RegExp(r'(^|\s)#[^\s#]+').hasMatch(text);
}

String _buildAutomaticHashtags(String titulo, String descripcion) {
  final source = '$titulo\n$descripcion';
  final tokens = _extractMeaningfulTokens(source);
  if (tokens.isEmpty) {
    return '#recetasaludable #nutricion';
  }

  final frequencies = <String, int>{};
  for (final token in tokens) {
    frequencies[token] = (frequencies[token] ?? 0) + 1;
  }

  final sorted = frequencies.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return b.key.length.compareTo(a.key.length);
    });

  final top = sorted.take(8).map((e) => e.key).toList(growable: false);
  return top.map((token) => '#$token').join(' ');
}

List<String> _extractMeaningfulTokens(String source) {
  final normalized = _stripDiacritics(source.toLowerCase());
  final rawTokens = normalized
      .split(RegExp(r'[^a-z0-9]+'))
      .map((t) => t.trim())
      .where((t) => t.length >= 3)
      .where((t) => !_spanishStopwords.contains(t))
      .where((t) => !RegExp(r'^\d+$').hasMatch(t))
      .toList(growable: false);

  return rawTokens;
}

String _stripDiacritics(String input) {
  const map = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  var out = input;
  map.forEach((k, v) {
    out = out.replaceAll(k, v);
  });
  return out;
}

const Set<String> _spanishStopwords = {
  'de',
  'del',
  'la',
  'las',
  'el',
  'los',
  'un',
  'una',
  'unos',
  'unas',
  'y',
  'e',
  'u',
  'a',
  'ante',
  'bajo',
  'cabe',
  'con',
  'contra',
  'desde',
  'durante',
  'en',
  'entre',
  'hacia',
  'hasta',
  'mediante',
  'para',
  'por',
  'segun',
  'sin',
  'sobre',
  'tras',
  'que',
  'como',
  'cuando',
  'donde',
  'porque',
  'muy',
  'mas',
  'menos',
  'tambien',
  'solo',
  'se',
  'su',
  'sus',
  'mi',
  'mis',
  'tu',
  'tus',
  'nuestro',
  'nuestra',
  'nuestros',
  'nuestras',
  'este',
  'esta',
  'estos',
  'estas',
  'eso',
  'esa',
  'esos',
  'esas',
  'ingredientes',
  'preparacion',
  'paso',
  'pasos',
};
