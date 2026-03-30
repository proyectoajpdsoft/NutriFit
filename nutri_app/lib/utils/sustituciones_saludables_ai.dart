const String defaultSustitucionesSaludablesAIPrompt =
    'muéstrame algunas sustituciones saludables, para un dietista, '
    'que quiere crear una base de datos de sustituciones saludables, '
    'con estos campos:\n'
    '[Título]\n'
    'Ejemplo: [Título] Torreznos por verduras deshidratadas\n'
    '\n'
    '[Subtítulo]\n'
    'Ejemplo: [Subtítulo] Alternativa para mantener la textura\n'
    '\n'
    '[Si no tienes]\n'
    'Ejemplo: [Si no tienes] Deshidratadora\n'
    '\n'
    '[Usa]\n'
    'Ejemplo: [Usa] Horno a baja temperatura o airfryer\n'
    '\n'
    '[Objetivo o categoría funcional]\n'
    'Ejemplo: [Objetivo o categoría funcional] proteína, aperitivo, preentreno, merienda, ...\n'
    '\n'
    '[Explicación, notas y hashtags]\n'
    'Ejemplo: [Explicación, notas y hashtags]El torrezno es un alimento poco saludable, '
    'principalmente por su elaboración: fritura en abundante aceite. '
    'Os proponemos una sustitución saludable: verduras deshidratadas.\n'
    '👉Ingredientes👈\n'
    'Verduras variadas (zanahoria, berenjena, calabacín, etc.)\n'
    '👉Elaboración👈\n'
    'Las verduras se trocean lo más finas posible, cuanto más finas, '
    'menos tiempo de horno se necesitará. Una vez cortadas se colocan '
    'en un boll y se les agregan especias al gusto (orégano, cúrcuma, etc.), '
    'sal y una cucharada pequeña de aceite. Se mezclan bien para que cojan '
    'las especias, sal y aceite. Se colocan, lo menos amontonadas posible, '
    'sobre una bandeja de horno y se hornean unos 50-120 minutos a baja '
    'temperatura, a unos 110 grados. Hay que ir revisando, estarán listas '
    'cuando se vean casi crujientes.\n'
    '#verduras #torreznos #horno #cortezas #cerdo\n'
    '\n'
    'Como ves, los nombres de los campos los ponemos entre corchetes, '
    'para que se diferencien bien, y en el campo [Explicación, notas y hashtags] '
    'usa el formato que te indico, siempre que lleve una explicación inicial, '
    'el 👉Ingredientes👈, el 👉Elaboración👈 y unos hashtags\n'
    '\n'
    'Muéstrame unas 10 sustituciones saludables con estos campos '
    '(si algún campo no tiene "sentido", lo muestras "vacío", '
    'por ejemplo "[Si no tienes]", pero intenta que siempre tengan datos)';

class SustitucionSaludableImportDraft {
  const SustitucionSaludableImportDraft({
    required this.titulo,
    this.subtitulo = '',
    this.alimentoOrigen = '',
    this.sustitutoPrincipal = '',
    this.equivalenciaTexto = '',
    this.objetivoMacro = '',
    this.texto = '',
  });

  final String titulo;
  final String subtitulo;
  final String alimentoOrigen;
  final String sustitutoPrincipal;
  final String equivalenciaTexto;
  final String objetivoMacro;
  final String texto;

  Map<String, dynamic> toCreatePayload() {
    return <String, dynamic>{
      'titulo': titulo.trim(),
      'subtitulo': subtitulo.trim(),
      'alimento_origen': alimentoOrigen.trim(),
      'sustituto_principal': sustitutoPrincipal.trim(),
      'equivalencia_texto': equivalenciaTexto.trim(),
      'objetivo_macro': objetivoMacro.trim(),
      'texto': texto.trim(),
      'activo': 'S',
      'mostrar_portada': 'N',
      'visible_para_todos': 'S',
      'categorias': <int>[],
    };
  }
}

class SustitucionCategoriaMatchAnalysis {
  const SustitucionCategoriaMatchAnalysis({
    required this.assignmentsByItemCode,
    required this.suggestions,
    required this.matchedItems,
    required this.assignmentsToAdd,
  });

  final Map<int, List<int>> assignmentsByItemCode;
  final List<SustitucionCategoriaSuggestion> suggestions;
  final int matchedItems;
  final int assignmentsToAdd;
}

class SustitucionCategoriaSuggestion {
  const SustitucionCategoriaSuggestion({
    required this.name,
    required this.matchCount,
  });

  final String name;
  final int matchCount;
}

class SustitucionCategoriaMatchOptions {
  const SustitucionCategoriaMatchOptions({
    required this.useHashtags,
    required this.useTitle,
    required this.useDescription,
  });

  final bool useHashtags;
  final bool useTitle;
  final bool useDescription;

  bool get hasAnySource => useHashtags || useTitle || useDescription;
}

String normalizeSustitucionSaludableTitle(String title) {
  return title.trim().toLowerCase();
}

SustitucionCategoriaMatchAnalysis analyzeSustitucionCategoryMatches({
  required List<dynamic> items,
  required List<Map<String, dynamic>> existingCategories,
  required SustitucionCategoriaMatchOptions options,
  int suggestionThreshold = 10,
}) {
  if (!options.hasAnySource) {
    return const SustitucionCategoriaMatchAnalysis(
      assignmentsByItemCode: <int, List<int>>{},
      suggestions: <SustitucionCategoriaSuggestion>[],
      matchedItems: 0,
      assignmentsToAdd: 0,
    );
  }

  final categories = existingCategories
      .map((item) {
        final id = int.tryParse(item['codigo'].toString());
        final name = (item['nombre'] ?? '').toString().trim();
        if (id == null || name.isEmpty) {
          return null;
        }
        return _ExistingCategory(
          id: id,
          name: name,
          normalized: normalizeCategoryMatchText(name),
        );
      })
      .whereType<_ExistingCategory>()
      .where((item) => item.normalized.isNotEmpty)
      .toList(growable: false);

  final existingCategoryNames =
      categories.map((item) => item.normalized).toSet();
  final assignmentsByItemCode = <int, List<int>>{};
  final suggestionCounts = <String, int>{};
  final suggestionDisplay = <String, String>{};
  var matchedItems = 0;
  var assignmentsToAdd = 0;

  for (final dynamic rawItem in items) {
    final item = rawItem as dynamic;
    final itemCode = item.codigo as int?;
    if (itemCode == null) {
      continue;
    }

    final titleText = (item.titulo ?? '').toString();
    final subtitleText = (item.subtitulo ?? '').toString();
    final alimentoText = (item.alimentoOrigen ?? '').toString();
    final sustitutoText = (item.sustitutoPrincipal ?? '').toString();
    final equivalenciaText = (item.equivalenciaTexto ?? '').toString();
    final objetivoText = (item.objetivoMacro ?? '').toString();
    final descriptionText = (item.texto ?? '').toString();

    // Combine all text fields for hashtag extraction so #tags in any field are found.
    final allText =
        '$titleText\n$subtitleText\n$alimentoText\n$sustitutoText\n$equivalenciaText\n$objetivoText\n$descriptionText';
    final hashtags =
        options.useHashtags ? extractNormalizedHashtags(allText) : <String>{};

    // For title matching: include title + subtitle + food name + substitute + equivalence + goal.
    final fullTitleText =
        '$titleText $subtitleText $alimentoText $sustitutoText $equivalenciaText $objetivoText';
    final titleTokens =
        options.useTitle ? extractNormalizedWords(fullTitleText) : <String>{};
    final descriptionTokens = options.useDescription
        ? extractNormalizedWords(descriptionText)
        : <String>{};
    final normalizedTitle =
        options.useTitle ? normalizeCategoryMatchText(fullTitleText) : '';
    final normalizedDescription = options.useDescription
        ? normalizeCategoryMatchText(descriptionText)
        : '';

    final currentIds = <int>{
      ...((item.categoriaIds as List?) ?? <int>[]).whereType<int>()
    };
    final matchedCategoryIds = <int>[];

    for (final category in categories) {
      final matched = _matchesExistingCategory(
        category.normalized,
        normalizedTitle: normalizedTitle,
        normalizedDescription: normalizedDescription,
        titleTokens: titleTokens,
        descriptionTokens: descriptionTokens,
        hashtags: hashtags,
        options: options,
      );
      if (matched && !currentIds.contains(category.id)) {
        matchedCategoryIds.add(category.id);
      }
    }

    if (matchedCategoryIds.isNotEmpty) {
      assignmentsByItemCode[itemCode] = matchedCategoryIds;
      matchedItems += 1;
      assignmentsToAdd += matchedCategoryIds.length;
    }

    final perItemSuggestionTokens = <String>{};
    if (options.useHashtags) {
      perItemSuggestionTokens.addAll(hashtags);
      for (final hashtag in extractOriginalHashtags(allText)) {
        final normalized = normalizeCategoryMatchText(hashtag);
        if (normalized.isEmpty || existingCategoryNames.contains(normalized)) {
          continue;
        }
        suggestionDisplay.putIfAbsent(
          normalized,
          () => capitalizeCategoryName(hashtag),
        );
      }
    }
    if (options.useTitle) {
      for (final token in extractOriginalWords(fullTitleText)) {
        final normalized = normalizeCategoryMatchText(token);
        if (normalized.isEmpty) {
          continue;
        }
        perItemSuggestionTokens.add(normalized);
        suggestionDisplay.putIfAbsent(
          normalized,
          () => capitalizeCategoryName(token),
        );
      }
    }
    if (options.useDescription) {
      for (final token in extractOriginalWords(descriptionText)) {
        final normalized = normalizeCategoryMatchText(token);
        if (normalized.isEmpty) {
          continue;
        }
        perItemSuggestionTokens.add(normalized);
        suggestionDisplay.putIfAbsent(
          normalized,
          () => capitalizeCategoryName(token),
        );
      }
    }

    for (final token in perItemSuggestionTokens) {
      if (_isIgnoredSuggestionToken(token) ||
          existingCategoryNames.contains(token)) {
        continue;
      }
      suggestionCounts.update(token, (value) => value + 1, ifAbsent: () => 1);
    }
  }

  final suggestions = suggestionCounts.entries
      .where((entry) => entry.value > suggestionThreshold)
      .map(
        (entry) => SustitucionCategoriaSuggestion(
          name:
              suggestionDisplay[entry.key] ?? capitalizeCategoryName(entry.key),
          matchCount: entry.value,
        ),
      )
      .toList(growable: false)
    ..sort((a, b) {
      final byCount = b.matchCount.compareTo(a.matchCount);
      if (byCount != 0) {
        return byCount;
      }
      return a.name.compareTo(b.name);
    });

  return SustitucionCategoriaMatchAnalysis(
    assignmentsByItemCode: assignmentsByItemCode,
    suggestions: suggestions,
    matchedItems: matchedItems,
    assignmentsToAdd: assignmentsToAdd,
  );
}

String normalizeCategoryMatchText(String text) {
  final lower = text.toLowerCase();
  final folded = lower
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
      .replaceAll('ñ', 'n');
  return folded.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

Set<String> extractNormalizedWords(String text) {
  return extractOriginalWords(text)
      .map(normalizeCategoryMatchText)
      .where((item) => item.isNotEmpty)
      .toSet();
}

Set<String> extractOriginalWords(String text) {
  return RegExp(r"[A-Za-zÁÉÍÓÚáéíóúÑñÜü][A-Za-zÁÉÍÓÚáéíóúÑñÜü0-9_-]*")
      .allMatches(text)
      .map((match) => match.group(0) ?? '')
      .where((item) => item.isNotEmpty)
      .toSet();
}

Set<String> extractNormalizedHashtags(String text) {
  return extractOriginalHashtags(text)
      .map(normalizeCategoryMatchText)
      .where((item) => item.isNotEmpty)
      .toSet();
}

Set<String> extractOriginalHashtags(String text) {
  return RegExp(r'#[A-Za-zÁÉÍÓÚáéíóúÑñÜü0-9_]+')
      .allMatches(text)
      .map((match) => (match.group(0) ?? '').replaceFirst('#', ''))
      .where((item) => item.isNotEmpty)
      .toSet();
}

String capitalizeCategoryName(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final lower = trimmed.toLowerCase();
  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}

bool _matchesExistingCategory(
  String normalizedCategory, {
  required String normalizedTitle,
  required String normalizedDescription,
  required Set<String> titleTokens,
  required Set<String> descriptionTokens,
  required Set<String> hashtags,
  required SustitucionCategoriaMatchOptions options,
}) {
  if (normalizedCategory.isEmpty) {
    return false;
  }

  if (options.useHashtags && hashtags.contains(normalizedCategory)) {
    return true;
  }

  final isMultiWord = normalizedCategory.contains(' ');
  final categoryTokens = isMultiWord
      ? normalizedCategory.split(' ').where((t) => t.isNotEmpty).toSet()
      : <String>{};

  if (options.useTitle) {
    if (isMultiWord) {
      if (_containsWholePhrase(normalizedTitle, normalizedCategory)) {
        return true;
      }
      // Fallback: check if all category tokens appear in title tokens
      if (categoryTokens.isNotEmpty &&
          categoryTokens.every((token) => titleTokens.contains(token))) {
        return true;
      }
    } else if (titleTokens.contains(normalizedCategory)) {
      return true;
    }
  }

  if (options.useDescription) {
    if (isMultiWord) {
      if (_containsWholePhrase(normalizedDescription, normalizedCategory)) {
        return true;
      }
      // Fallback: check if all category tokens appear in description tokens
      if (categoryTokens.isNotEmpty &&
          categoryTokens.every((token) => descriptionTokens.contains(token))) {
        return true;
      }
    } else if (descriptionTokens.contains(normalizedCategory)) {
      return true;
    }
  }

  return false;
}

bool _containsWholePhrase(String normalizedText, String normalizedPhrase) {
  if (normalizedText.isEmpty || normalizedPhrase.isEmpty) {
    return false;
  }
  return ' $normalizedText '.contains(' $normalizedPhrase ');
}

bool _isIgnoredSuggestionToken(String token) {
  const ignored = <String>{
    'para',
    'como',
    'pero',
    'porque',
    'desde',
    'hasta',
    'entre',
    'sobre',
    'durante',
    'contra',
    'hacia',
    'segun',
    'tambien',
    'muy',
    'mas',
    'menos',
    'solo',
    'este',
    'esta',
    'estos',
    'estas',
    'ese',
    'esa',
    'esos',
    'esas',
    'con',
    'sin',
    'del',
    'las',
    'los',
    'una',
    'unas',
    'unos',
    'que',
    'cuando',
    'donde',
    'usar',
    'usa',
    'tiene',
    'tienen',
    'hacer',
    'saludable',
    'saludables',
    'ingredientes',
    'elaboracion',
    'explicacion',
    'notas',
    'hashtags',
    'alternativa',
  };
  return token.length < 4 ||
      ignored.contains(token) ||
      int.tryParse(token) != null;
}

class _ExistingCategory {
  const _ExistingCategory({
    required this.id,
    required this.name,
    required this.normalized,
  });

  final int id;
  final String name;
  final String normalized;
}

List<SustitucionSaludableImportDraft> parseSustitucionesSaludablesFromAI(
  String rawText,
) {
  final text = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (text.isEmpty || !text.contains('[Explicación, notas y hashtags]')) {
    return <SustitucionSaludableImportDraft>[];
  }

  final lines = text.split('\n');
  final blocks = <List<String>>[];
  List<String>? currentBlock;

  for (final line in lines) {
    final trimmedLeft = line.trimLeft();
    if (trimmedLeft.startsWith('[Título]')) {
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

  return blocks
      .map(_parseSustitucionBlock)
      .whereType<SustitucionSaludableImportDraft>()
      .toList(growable: false);
}

SustitucionSaludableImportDraft? _parseSustitucionBlock(List<String> lines) {
  String titulo = '';
  String subtitulo = '';
  String origen = '';
  String sustituto = '';
  String equivalencia = '';
  String objetivo = '';
  final textoBuffer = <String>[];
  var collectingText = false;

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    final normalized = line.trimLeft();

    if (collectingText && !_isTaggedLine(normalized)) {
      textoBuffer.add(line);
      continue;
    }

    if (normalized.startsWith('[Título]')) {
      collectingText = false;
      titulo = _extractTagValue(normalized, '[Título]');
      continue;
    }
    if (normalized.startsWith('[Subtítulo]')) {
      collectingText = false;
      subtitulo = _extractTagValue(normalized, '[Subtítulo]');
      continue;
    }
    if (normalized.startsWith('[Si no tienes]')) {
      collectingText = false;
      final sameLineMatch = RegExp(
        r'^\[Si no tienes\]\s*(.*?)(?:\s*\[(?:Usa|usa)\]\s*(.*))?\s*$',
      ).firstMatch(normalized);
      if (sameLineMatch != null) {
        origen = sameLineMatch.group(1)?.trim() ?? '';
        final inlineSustituto = sameLineMatch.group(2)?.trim() ?? '';
        if (inlineSustituto.isNotEmpty) {
          sustituto = inlineSustituto;
        }
      }
      continue;
    }
    if (normalized.startsWith('[Usa]') || normalized.startsWith('[usa]')) {
      collectingText = false;
      sustituto =
          normalized.replaceFirst(RegExp(r'^\[(?:Usa|usa)\]\s*'), '').trim();
      continue;
    }
    if (normalized.startsWith('[Equivalencia]')) {
      collectingText = false;
      equivalencia = _extractTagValue(normalized, '[Equivalencia]');
      continue;
    }
    if (normalized.startsWith('[Objetivo o categoría funcional]')) {
      collectingText = false;
      objetivo = _extractTagValue(
        normalized,
        '[Objetivo o categoría funcional]',
      );
      continue;
    }
    if (normalized.startsWith('[Explicación, notas y hashtags]')) {
      collectingText = true;
      final firstLine = _extractTagValue(
        normalized,
        '[Explicación, notas y hashtags]',
      );
      if (firstLine.isNotEmpty) {
        textoBuffer.add(firstLine);
      }
      continue;
    }
  }

  final texto = textoBuffer.join('\n').trim();
  if (titulo.trim().isEmpty || texto.isEmpty) {
    return null;
  }

  return SustitucionSaludableImportDraft(
    titulo: titulo,
    subtitulo: subtitulo,
    alimentoOrigen: origen,
    sustitutoPrincipal: sustituto,
    equivalenciaTexto: equivalencia,
    objetivoMacro: objetivo,
    texto: texto,
  );
}

bool _isTaggedLine(String line) {
  return line.startsWith('[Título]') ||
      line.startsWith('[Subtítulo]') ||
      line.startsWith('[Si no tienes]') ||
      line.startsWith('[Usa]') ||
      line.startsWith('[usa]') ||
      line.startsWith('[Equivalencia]') ||
      line.startsWith('[Objetivo o categoría funcional]') ||
      line.startsWith('[Explicación, notas y hashtags]');
}

String _extractTagValue(String line, String tag) {
  return line.replaceFirst(tag, '').trim();
}
