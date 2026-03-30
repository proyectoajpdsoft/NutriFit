import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/consejo.dart';
import '../models/receta.dart';
import '../models/suplemento.dart';
import '../models/sustitucion_saludable.dart';
import '../screens/consejos_paciente_screen.dart';
import '../screens/recetas_paciente_screen.dart';
import '../screens/sustituciones_saludables_screen.dart';
import '../services/api_service.dart';

class SuplementoDetailScreen extends StatelessWidget {
  const SuplementoDetailScreen({
    super.key,
    required this.suplemento,
    required this.onExportPdf,
    this.onHashtagTap,
    this.allSuplementos = const <Suplemento>[],
    this.showPremiumRecommendations = false,
    this.onNavigateToSuplemento,
  });

  final Suplemento suplemento;
  final Future<void> Function(Suplemento suplemento) onExportPdf;
  final void Function(String hashtag)? onHashtagTap;
  final List<Suplemento> allSuplementos;
  final bool showPremiumRecommendations;
  final Future<void> Function(Suplemento suplemento)? onNavigateToSuplemento;

  String get _descripcion => (suplemento.descripcion ?? '').trim();

  static final RegExp _doubleBracketRegex = RegExp(r'\[\[([^\[\]]+)\]\]');

  String _buildBaseCopyText() {
    final clean = _replaceStructuredLinks(_descripcion, forDisplay: true);
    return '[Suplemento]\n${suplemento.titulo}\n\n[Descripción]\n$clean';
  }

  Future<String> _buildCopyText(BuildContext context) async {
    final nutricionistaParam =
        await context.read<ApiService>().getParametro('nutricionista_nombre');
    final nutricionistaNombre =
        (nutricionistaParam?['valor']?.toString() ?? '').trim();
    final firma = nutricionistaNombre.isEmpty
        ? 'App NutriFit'
        : 'App NutriFit $nutricionistaNombre';
    return '${_buildBaseCopyText()}\n\n$firma';
  }

  Set<String> _extractHashtags(String text) {
    final regex = RegExp(r'#[A-Za-z0-9_áéíóúÁÉÍÓÚñÑüÜ]+', unicode: true);
    return regex
        .allMatches(text)
        .map((m) => m.group(0) ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  String _withoutHashtagPrefix(String tag) {
    return tag.startsWith('#') ? tag.substring(1) : tag;
  }

  ({String prefix, String type, int codigo})? _parseStructuredLink(
    String raw,
  ) {
    final pattern = RegExp(
      r'^(.*?)\s*enlace_(consejo|receta|sustitucion_saludable|suplemento)_(\d+)\s*$',
      caseSensitive: false,
      unicode: true,
    );
    final match = pattern.firstMatch(raw.trim());
    if (match == null) return null;

    final prefix = (match.group(1) ?? '').trim();
    final type = (match.group(2) ?? '').trim().toLowerCase();
    final codigo = int.tryParse(match.group(3) ?? '');
    if (codigo == null) return null;

    return (prefix: prefix, type: type, codigo: codigo);
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'consejo':
        return 'consejo';
      case 'receta':
        return 'receta';
      case 'sustitucion_saludable':
        return 'sustitución saludable';
      case 'suplemento':
        return 'suplemento';
      default:
        return type;
    }
  }

  String _buildStructuredLinkText(
    ({String prefix, String type, int codigo}) link,
  ) {
    final prefix = link.prefix.isEmpty ? 'Véase' : link.prefix;
    final article = link.type == 'sustitucion_saludable' ? 'la' : 'el';
    return '$prefix enlace a $article ${_typeLabel(link.type)}';
  }

  String _replaceStructuredLinks(String text, {required bool forDisplay}) {
    return text.replaceAllMapped(_doubleBracketRegex, (match) {
      final raw = (match.group(1) ?? '').trim();
      final parsed = _parseStructuredLink(raw);
      if (parsed == null) {
        return forDisplay ? raw : '';
      }
      return _buildStructuredLinkText(parsed);
    });
  }

  Future<void> _openStructuredLink(
    BuildContext context,
    ({String prefix, String type, int codigo}) link,
  ) async {
    String endpoint;
    switch (link.type) {
      case 'consejo':
        endpoint = 'api/consejos.php?codigo=${link.codigo}';
        break;
      case 'receta':
        endpoint = 'api/recetas.php?codigo=${link.codigo}';
        break;
      case 'sustitucion_saludable':
        endpoint = 'api/sustituciones_saludables.php?codigo=${link.codigo}';
        break;
      case 'suplemento':
        final local = allSuplementos
            .where((item) => item.codigo == link.codigo)
            .cast<Suplemento?>()
            .firstWhere((item) => item != null, orElse: () => null);
        if (local != null && onNavigateToSuplemento != null) {
          await onNavigateToSuplemento!(local);
          return;
        }
        endpoint = 'api/suplementos.php?codigo=${link.codigo}';
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tipo de enlace no soportado.')),
        );
        return;
    }

    try {
      final response = await context.read<ApiService>().get(endpoint);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final data = decoded is List && decoded.isNotEmpty
          ? Map<String, dynamic>.from(decoded.first as Map)
          : Map<String, dynamic>.from(decoded as Map);

      if (!context.mounted) return;

      if (link.type == 'suplemento' && onNavigateToSuplemento != null) {
        final title = (data['titulo'] ?? '').toString().trim();
        final suplemento = Suplemento(
          codigo: int.tryParse((data['codigo'] ?? '').toString()),
          titulo: title,
          descripcion: (data['descripcion'] ?? '').toString(),
          activo: (data['activo'] ?? 'S').toString(),
        );
        await onNavigateToSuplemento!(suplemento);
        return;
      }

      if (link.type == 'consejo') {
        final consejo = Consejo.fromJson(data);
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => ConsejoDetailScreen(consejo: consejo),
          ),
        );
        return;
      }

      if (link.type == 'receta') {
        final receta = Receta.fromJson(data);
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => RecetaDetailScreen(receta: receta),
          ),
        );
        return;
      }

      if (link.type == 'sustitucion_saludable') {
        final sustitucion = SustitucionSaludable.fromJson(data);
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => SustitucionSaludableDetailScreen(item: sustitucion),
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir ${_typeLabel(link.type)} #${link.codigo}.',
          ),
        ),
      );
    }
  }

  String _normalize(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

  String? _extractVeaseTarget(String line) {
    final regex = RegExp(
      r'^\s*v[eé]ase\s+(.+?)\s*[\.!]?$',
      caseSensitive: false,
      unicode: true,
    );
    final match = regex.firstMatch(line.trim());
    final target = (match?.group(1) ?? '').trim();
    return target.isEmpty ? null : target;
  }

  Suplemento? _findSuplementoByTitle(String rawTitle) {
    if (allSuplementos.isEmpty) return null;

    final target = _normalize(rawTitle);
    if (target.isEmpty) return null;

    for (final item in allSuplementos) {
      if (item.codigo == suplemento.codigo) continue;
      if (_normalize(item.titulo) == target) {
        return item;
      }
    }

    for (final item in allSuplementos) {
      if (item.codigo == suplemento.codigo) continue;
      final normalizedTitle = _normalize(item.titulo);
      if (normalizedTitle.contains(target) ||
          target.contains(normalizedTitle)) {
        return item;
      }
    }

    return null;
  }

  Future<void> _openReferencedSuplemento(
    BuildContext context,
    String rawTitle,
  ) async {
    final found = _findSuplementoByTitle(rawTitle);
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se encontró "$rawTitle" en el catálogo.'),
        ),
      );
      return;
    }

    if (onNavigateToSuplemento != null) {
      await onNavigateToSuplemento!(found);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se puede abrir el suplemento desde esta vista.'),
      ),
    );
  }

  Set<String> _extractWords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toSet();
  }

  bool _hasOnlyBracketTokens(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final plain = trimmed
        .replaceAll(_doubleBracketRegex, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _doubleBracketRegex.hasMatch(trimmed) && plain.isEmpty;
  }

  List<Suplemento> _buildRelatedSuplementos() {
    if (!showPremiumRecommendations || allSuplementos.isEmpty) {
      return const <Suplemento>[];
    }

    final currentText = '${suplemento.titulo} ${suplemento.descripcion}'.trim();
    final currentTags = _extractHashtags(currentText)
        .map(_withoutHashtagPrefix)
        .map(_normalize)
        .toSet();
    final currentTitleWords = _extractWords(suplemento.titulo);
    final currentDescWords = _extractWords(suplemento.descripcion);

    final scored = <({Suplemento suplemento, int score})>[];

    for (final candidate in allSuplementos) {
      if (candidate.codigo == suplemento.codigo) continue;
      if (candidate.activo != 'S') continue;
      if (_hasOnlyBracketTokens(candidate.descripcion)) continue;

      final candidateText =
          '${candidate.titulo} ${candidate.descripcion}'.trim();
      final candidateTags = _extractHashtags(candidateText)
          .map(_withoutHashtagPrefix)
          .map(_normalize)
          .toSet();
      final candidateTitleWords = _extractWords(candidate.titulo);
      final candidateDescWords = _extractWords(candidate.descripcion);

      final tagsScore = candidateTags.intersection(currentTags).length * 5;
      final titleScore =
          candidateTitleWords.intersection(currentTitleWords).length * 3;
      final descScore =
          candidateDescWords.intersection(currentDescWords).length;

      final totalScore = tagsScore + titleScore + descScore;
      scored.add((suplemento: candidate, score: totalScore));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.suplemento.titulo.compareTo(b.suplemento.titulo);
    });

    final withScore = scored.where((entry) => entry.score > 0).toList();
    final withoutScore = scored.where((entry) => entry.score == 0).toList();
    final ordered = <Suplemento>[
      ...withScore.map((entry) => entry.suplemento),
      ...withoutScore.map((entry) => entry.suplemento),
    ];

    return ordered.take(10).toList(growable: false);
  }

  bool _isPointerHeading(String line) {
    final pattern = RegExp(r'^\s*👉\s*([^👈]+?)\s*👈\s*$', unicode: true);
    return pattern.hasMatch(line.trim());
  }

  String _pointerHeadingText(String line) {
    final pattern = RegExp(r'^\s*👉\s*([^👈]+?)\s*👈\s*$', unicode: true);
    final match = pattern.firstMatch(line.trim());
    return (match?.group(1) ?? line).trim();
  }

  void _handleHashtagTap(BuildContext context, String tag) {
    final cleanTag = _withoutHashtagPrefix(tag);
    if (onHashtagTap != null) {
      onHashtagTap!(cleanTag);
      Navigator.pop(context);
      return;
    }

    Clipboard.setData(ClipboardData(text: cleanTag));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Hashtag "$cleanTag" copiado.')),
    );
  }

  Widget _buildLineWithClickableHashtags(BuildContext context, String line) {
    final structuredMatches = _doubleBracketRegex.allMatches(line).toList();
    if (structuredMatches.isNotEmpty) {
      final spans = <InlineSpan>[];
      var cursor = 0;

      void addTextWithHashtags(String chunk) {
        if (chunk.isEmpty) return;

        final regex = RegExp(r'#[A-Za-z0-9_áéíóúÁÉÍÓÚñÑüÜ]+', unicode: true);
        final matches = regex.allMatches(chunk).toList(growable: false);
        if (matches.isEmpty) {
          spans.add(
            TextSpan(
              text: chunk,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: Colors.black87,
              ),
            ),
          );
          return;
        }

        var localCursor = 0;
        for (final match in matches) {
          if (match.start > localCursor) {
            spans.add(
              TextSpan(
                text: chunk.substring(localCursor, match.start),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: Colors.black87,
                ),
              ),
            );
          }

          final tag = chunk.substring(match.start, match.end);
          spans.add(
            TextSpan(
              text: tag,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: Colors.teal,
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  _handleHashtagTap(context, tag);
                },
            ),
          );
          localCursor = match.end;
        }

        if (localCursor < chunk.length) {
          spans.add(
            TextSpan(
              text: chunk.substring(localCursor),
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: Colors.black87,
              ),
            ),
          );
        }
      }

      for (final match in structuredMatches) {
        if (match.start > cursor) {
          addTextWithHashtags(line.substring(cursor, match.start));
        }

        final raw = (match.group(1) ?? '').trim();
        final parsed = _parseStructuredLink(raw);
        if (parsed == null) {
          addTextWithHashtags(raw);
        } else {
          final prefixText = parsed.prefix.trim();
          if (prefixText.isNotEmpty) {
            addTextWithHashtags('$prefixText ');
          }
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _StructuredLinkTitle(
                type: parsed.type,
                codigo: parsed.codigo,
                allSuplementos: allSuplementos,
                fallbackLabel: '${_typeLabel(parsed.type)} #${parsed.codigo}',
                onTap: () => _openStructuredLink(context, parsed),
              ),
            ),
          );
        }

        cursor = match.end;
      }

      if (cursor < line.length) {
        addTextWithHashtags(line.substring(cursor));
      }

      return RichText(text: TextSpan(children: spans));
    }

    final veaseTarget = _extractVeaseTarget(line);
    if (veaseTarget != null) {
      return RichText(
        text: TextSpan(
          children: [
            const TextSpan(
              text: 'Véase ',
              style: TextStyle(
                fontSize: 15,
                height: 1.55,
                color: Colors.black87,
              ),
            ),
            TextSpan(
              text: veaseTarget,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: Colors.teal,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  _openReferencedSuplemento(context, veaseTarget);
                },
            ),
          ],
        ),
      );
    }

    final regex = RegExp(r'#[A-Za-z0-9_áéíóúÁÉÍÓÚñÑüÜ]+', unicode: true);
    final matches = regex.allMatches(line).toList(growable: false);

    if (matches.isEmpty) {
      return Text(
        line,
        style: const TextStyle(fontSize: 15, height: 1.55),
      );
    }

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: line.substring(cursor, match.start),
            style: const TextStyle(
              fontSize: 15,
              height: 1.55,
              color: Colors.black87,
            ),
          ),
        );
      }

      final tag = line.substring(match.start, match.end);
      spans.add(
        TextSpan(
          text: tag,
          style: const TextStyle(
            fontSize: 15,
            height: 1.55,
            color: Colors.teal,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _handleHashtagTap(context, tag);
            },
        ),
      );
      cursor = match.end;
    }

    if (cursor < line.length) {
      spans.add(
        TextSpan(
          text: line.substring(cursor),
          style: const TextStyle(
            fontSize: 15,
            height: 1.55,
            color: Colors.black87,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildDescription(BuildContext context) {
    if (_descripcion.isEmpty) {
      return const Text(
        '(Sin descripción)',
        style: TextStyle(fontSize: 15, height: 1.55),
      );
    }

    final hashtagRegex = RegExp(r'#[A-Za-z0-9_áéíóúÁÉÍÓÚñÑüÜ]+', unicode: true);
    final lines = _descripcion.replaceAll('\r\n', '\n').split('\n');
    final lastNonEmptyIndex =
        lines.lastIndexWhere((line) => line.trim().isNotEmpty);

    if (lastNonEmptyIndex >= 0) {
      final lastLine = lines[lastNonEmptyIndex];
      final cleanedLastLine = lastLine.replaceAll(hashtagRegex, '').trim();
      lines[lastNonEmptyIndex] = cleanedLastLine;
    }

    final widgets = <Widget>[];

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      if (_isPointerHeading(line)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              _pointerHeadingText(line),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
        );
      } else {
        widgets.add(_buildLineWithClickableHashtags(context, line));
      }
    }

    final hashtags = _extractHashtags(_descripcion).toList(growable: false)
      ..sort();

    if (hashtags.isNotEmpty) {
      widgets.add(const SizedBox(height: 14));
      widgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: hashtags
              .map(
                (tag) => ActionChip(
                  label: Text(_withoutHashtagPrefix(tag)),
                  avatar: const Icon(Icons.tag, size: 16),
                  onPressed: () => _handleHashtagTap(context, tag),
                ),
              )
              .toList(growable: false),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final related = _buildRelatedSuplementos();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          suplemento.titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              final copyText = await _buildCopyText(context);
              await Clipboard.setData(ClipboardData(text: copyText));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Suplemento copiado al portapapeles.'),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () {
              final sanitizedDescripcion =
                  _replaceStructuredLinks(_descripcion, forDisplay: true);
              final toExport = Suplemento(
                codigo: suplemento.codigo,
                titulo: suplemento.titulo,
                descripcion: sanitizedDescripcion,
                activo: suplemento.activo,
              );
              onExportPdf(toExport);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDescription(context),
              if (showPremiumRecommendations && related.isNotEmpty) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: Colors.amber.shade600,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'También te puede interesar...',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 170,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: related.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final item = related[index];
                      final previewDescripcion = _replaceStructuredLinks(
                        item.descripcion,
                        forDisplay: true,
                      );
                      return SizedBox(
                        width: 250,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: onNavigateToSuplemento == null
                                ? null
                                : () => onNavigateToSuplemento!(item),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.medication_outlined,
                                    color: Colors.teal,
                                    size: 18,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.titulo,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    previewDescripcion,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.35,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StructuredLinkTitle extends StatefulWidget {
  const _StructuredLinkTitle({
    required this.type,
    required this.codigo,
    required this.allSuplementos,
    required this.fallbackLabel,
    required this.onTap,
  });

  final String type;
  final int codigo;
  final List<Suplemento> allSuplementos;
  final String fallbackLabel;
  final VoidCallback onTap;

  @override
  State<_StructuredLinkTitle> createState() => _StructuredLinkTitleState();
}

class _StructuredLinkTitleState extends State<_StructuredLinkTitle> {
  static final Map<String, String> _titleCache = <String, String>{};

  String get _cacheKey => '${widget.type}:${widget.codigo}';

  String _localSuplementoTitle() {
    final found = widget.allSuplementos
        .where((item) => item.codigo == widget.codigo)
        .cast<Suplemento?>()
        .firstWhere((item) => item != null, orElse: () => null);
    return (found?.titulo ?? '').trim();
  }

  String _endpointForType() {
    switch (widget.type) {
      case 'consejo':
        return 'api/consejos.php?codigo=${widget.codigo}';
      case 'receta':
        return 'api/recetas.php?codigo=${widget.codigo}';
      case 'sustitucion_saludable':
        return 'api/sustituciones_saludables.php?codigo=${widget.codigo}';
      case 'suplemento':
        return 'api/suplementos.php?codigo=${widget.codigo}';
      default:
        return '';
    }
  }

  Future<void> _resolveTitle() async {
    final cached = _titleCache[_cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return;
    }

    if (widget.type == 'suplemento') {
      final localTitle = _localSuplementoTitle();
      if (localTitle.isNotEmpty) {
        _titleCache[_cacheKey] = localTitle;
        return;
      }
    }

    final endpoint = _endpointForType();
    if (endpoint.isEmpty) return;

    try {
      final response = await context.read<ApiService>().get(endpoint);
      if (response.statusCode != 200) return;
      final dynamic decoded = jsonDecode(response.body);
      final Map<String, dynamic> data = decoded is List
          ? (decoded.isNotEmpty
              ? Map<String, dynamic>.from(decoded.first as Map)
              : <String, dynamic>{})
          : Map<String, dynamic>.from(decoded as Map);

      final title = (data['titulo'] ?? '').toString().trim();
      if (title.isNotEmpty) {
        _titleCache[_cacheKey] = title;
      }
    } catch (_) {
      // Silencioso: se mantiene fallback.
    }

    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _resolveTitle();
  }

  @override
  Widget build(BuildContext context) {
    final title = _titleCache[_cacheKey] ?? widget.fallbackLabel;

    IconData typeIcon;
    switch (widget.type) {
      case 'consejo':
        typeIcon = Icons.tips_and_updates_outlined;
        break;
      case 'receta':
        typeIcon = Icons.restaurant_menu_outlined;
        break;
      case 'sustitucion_saludable':
        typeIcon = Icons.swap_horiz_rounded;
        break;
      case 'suplemento':
        typeIcon = Icons.medication_outlined;
        break;
      default:
        typeIcon = Icons.link;
        break;
    }

    return InkWell(
      onTap: widget.onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(typeIcon, size: 15, color: Colors.teal),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              height: 1.55,
              color: Colors.teal,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }
}
