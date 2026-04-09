import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/consejo.dart';
import '../models/receta.dart';
import '../models/aditivo.dart';
import '../models/sustitucion_saludable.dart';
import '../screens/consejos_paciente_screen.dart';
import '../screens/recetas_paciente_screen.dart';
import '../screens/sustituciones_saludables_screen.dart';
import '../services/api_service.dart';
import '../utils/aditivos_ai.dart';
import '../widgets/peligrosidad_dialog.dart';

class AditivoDetailScreen extends StatelessWidget {
  const AditivoDetailScreen({
    super.key,
    required this.aditivo,
    required this.onExportPdf,
    this.onHashtagTap,
    this.allAditivos = const <Aditivo>[],
    this.showPremiumRecommendations = false,
    this.onNavigateToAditivo,
    this.allowCopyAndPdf = true,
    this.allowDiscoveryNavigation = true,
    this.onRequestPremiumAccess,
  });

  final Aditivo aditivo;
  final Future<void> Function(Aditivo aditivo) onExportPdf;
  final void Function(String hashtag)? onHashtagTap;
  final List<Aditivo> allAditivos;
  final bool showPremiumRecommendations;
  final Future<void> Function(Aditivo aditivo)? onNavigateToAditivo;
  final bool allowCopyAndPdf;
  final bool allowDiscoveryNavigation;
  final Future<void> Function(String message)? onRequestPremiumAccess;

  String get _descripcion => (aditivo.descripcion ?? '').trim();

  static final RegExp _doubleBracketRegex = RegExp(r'\[\[([^\[\]]+)\]\]');

  int? _normalizePeligrosidad(int? value) {
    if (value == null) return null;
    if (value < 1 || value > 5) return null;
    return value;
  }

  Color _peligrosidadColor(int? value) {
    final normalized = _normalizePeligrosidad(value);
    if (normalized == null) return Colors.blueGrey;
    if (normalized == 5) return Colors.red.shade800;
    if (normalized == 4) return Colors.red.shade600;
    if (normalized == 3) return Colors.orange.shade700;
    if (normalized == 2) return Colors.amber.shade800;
    return Colors.green.shade700;
  }

  String _peligrosidadNombre(int? value) {
    final normalized = _normalizePeligrosidad(value);
    switch (normalized) {
      case 1:
        return 'Seguro';
      case 2:
        return 'Atención';
      case 3:
        return 'Alto';
      case 4:
        return 'Restringido';
      case 5:
        return 'Prohibido';
      default:
        return 'Sin clasificar';
    }
  }

  String _peligrosidadDescripcion(int? value) {
    final normalized = _normalizePeligrosidad(value);
    switch (normalized) {
      case 1:
        return 'Aditivo bien tolerado y seguro para el consumo general. No se han documentado efectos adversos a las dosis habituales.';
      case 2:
        return 'Aditivo que requiere moderación. Algunas personas pueden presentar sensibilidad o efectos secundarios menores. Se recomienda limitar su consumo.';
      case 3:
        return 'Aditivo con potencial para efectos adversos en consumo frecuente. Personas sensibles, embarazadas o con alergias deben evitarlo. Consulta con tu dietista.';
      case 4:
        return 'Aditivo que debe evitarse o consumirse únicamente bajo supervisión profesional. Vinculado a problemas de salud en estudios científicos.';
      case 5:
        return 'Aditivo prohibido o muy restringido en muchos países. Conocido por efectos adversos significativos para la salud. Evitar completamente en la medida de lo posible.';
      default:
        return 'No hay una peligrosidad asignada para este aditivo.';
    }
  }

  String _peligrosidadColorEmoji(int? value) {
    final normalized = _normalizePeligrosidad(value);
    switch (normalized) {
      case 1:
        return '🟢';
      case 2:
        return '🟡';
      case 3:
        return '🟠';
      case 4:
        return '🔴';
      case 5:
        return '⛔';
      default:
        return '⚪';
    }
  }

  String _buildPeligrosidadTextForCopy() {
    final normalized = _normalizePeligrosidad(aditivo.peligrosidad);
    if (normalized == null) {
      return '[Peligrosidad]\nSin clasificar\n${_peligrosidadDescripcion(null)}';
    }
    return '[Peligrosidad]\n$normalized (${_peligrosidadNombre(normalized)})\nDescripción: ${_peligrosidadDescripcion(normalized)}';
  }

  String _buildPeligrosidadTextForPdf() {
    final normalized = _normalizePeligrosidad(aditivo.peligrosidad);
    if (normalized == null) {
      return '👉 Peligrosidad 👈\n⚪ Sin clasificar\n${_peligrosidadDescripcion(null)}';
    }
    return '👉 Peligrosidad 👈\n${_peligrosidadColorEmoji(normalized)} Nivel $normalized (${_peligrosidadNombre(normalized)})\n${_peligrosidadDescripcion(normalized)}';
  }

  String _buildBaseCopyText() {
    final clean = _replaceStructuredLinks(_descripcion, forDisplay: true);
    return '[Aditivo]\n${aditivo.titulo}\n\n[Descripción]\n$clean\n\n[Tipo]\n${aditivo.tipo}\n\n${_buildPeligrosidadTextForCopy()}';
  }

  Future<void> _showPeligrosidadDetailsDialog(BuildContext context) async {
    await showAditivoPeligrosidadDialog(
      context,
      peligrosidad: aditivo.peligrosidad,
      titulo: aditivo.titulo,
    );
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
      r'^(.*?)\s*enlace_(consejo|receta|sustitucion_saludable|aditivo)_(\d+)\s*$',
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
      case 'aditivo':
        return 'aditivo';
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
    final l10n = AppLocalizations.of(context)!;
    if (!allowDiscoveryNavigation) {
      await _requestPremiumAccess(
        context,
        l10n.additivesPremiumExploreMessage,
      );
      return;
    }

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
      case 'aditivo':
        final local = allAditivos
            .where((item) => item.codigo == link.codigo)
            .cast<Aditivo?>()
            .firstWhere((item) => item != null, orElse: () => null);
        if (local != null && onNavigateToAditivo != null) {
          await onNavigateToAditivo!(local);
          return;
        }
        endpoint = 'api/aditivos.php?codigo=${link.codigo}';
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

      if (link.type == 'aditivo' && onNavigateToAditivo != null) {
        final title = (data['titulo'] ?? '').toString().trim();
        final linkedAditivo = Aditivo(
          codigo: int.tryParse((data['codigo'] ?? '').toString()),
          titulo: title,
          descripcion: (data['descripcion'] ?? '').toString(),
          tipo: (data['tipo'] ?? 'Colorantes').toString(),
          activo: (data['activo'] ?? 'S').toString(),
          peligrosidad: data['peligrosidad'] != null
              ? int.tryParse(data['peligrosidad'].toString())
              : null,
        );
        await onNavigateToAditivo!(linkedAditivo);
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
    return repairCommonMojibake(text)
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
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

  Aditivo? _findAditivoByTitle(String rawTitle) {
    if (allAditivos.isEmpty) return null;

    final target = _normalize(rawTitle);
    if (target.isEmpty) return null;

    for (final item in allAditivos) {
      if (item.codigo == aditivo.codigo) continue;
      if (_normalize(item.titulo) == target) {
        return item;
      }
    }

    for (final item in allAditivos) {
      if (item.codigo == aditivo.codigo) continue;
      final normalizedTitle = _normalize(item.titulo);
      if (normalizedTitle.contains(target) ||
          target.contains(normalizedTitle)) {
        return item;
      }
    }

    return null;
  }

  Future<void> _openReferencedAditivo(
    BuildContext context,
    String rawTitle,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (!allowDiscoveryNavigation) {
      await _requestPremiumAccess(
        context,
        l10n.additivesPremiumExploreMessage,
      );
      return;
    }

    final found = _findAditivoByTitle(rawTitle);
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se encontró "$rawTitle" en el catálogo.'),
        ),
      );
      return;
    }

    if (onNavigateToAditivo != null) {
      await onNavigateToAditivo!(found);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se puede abrir el Aditivo desde esta vista.'),
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

  List<Aditivo> _buildRelatedAditivos() {
    if (!showPremiumRecommendations || allAditivos.isEmpty) {
      return const <Aditivo>[];
    }

    final currentText = '${aditivo.titulo} ${aditivo.descripcion}'.trim();
    final currentTags = _extractHashtags(currentText)
        .map(_withoutHashtagPrefix)
        .map(_normalize)
        .toSet();
    final currentTitleWords = _extractWords(aditivo.titulo);
    final currentDescWords = _extractWords(aditivo.descripcion);

    final scored = <({Aditivo Aditivo, int score})>[];

    for (final candidate in allAditivos) {
      if (candidate.codigo == aditivo.codigo) continue;
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
      scored.add((Aditivo: candidate, score: totalScore));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.Aditivo.titulo.compareTo(b.Aditivo.titulo);
    });

    final withScore = scored.where((entry) => entry.score > 0).toList();
    final withoutScore = scored.where((entry) => entry.score == 0).toList();
    final ordered = <Aditivo>[
      ...withScore.map((entry) => entry.Aditivo),
      ...withoutScore.map((entry) => entry.Aditivo),
    ];

    return ordered.take(10).toList(growable: false);
  }

  bool _isPointerHeading(String line) {
    final pattern = RegExp(r'^\s*ðŸ‘‰\s*([^ðŸ‘ˆ]+?)\s*ðŸ‘ˆ\s*$', unicode: true);
    return pattern.hasMatch(line.trim());
  }

  String _pointerHeadingText(String line) {
    final pattern = RegExp(r'^\s*ðŸ‘‰\s*([^ðŸ‘ˆ]+?)\s*ðŸ‘ˆ\s*$', unicode: true);
    final match = pattern.firstMatch(line.trim());
    return (match?.group(1) ?? line).trim();
  }

  Future<void> _requestPremiumAccess(
    BuildContext context,
    String message,
  ) async {
    final callback = onRequestPremiumAccess;
    if (callback != null) {
      await callback(message);
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleHashtagTap(BuildContext context, String tag) {
    final l10n = AppLocalizations.of(context)!;
    if (!allowDiscoveryNavigation) {
      _requestPremiumAccess(
        context,
        l10n.additivesPremiumExploreMessage,
      );
      return;
    }

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
                allAditivos: allAditivos,
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
                  _openReferencedAditivo(context, veaseTarget);
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
      widgets.add(const SizedBox(height: 8));
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
    final related = _buildRelatedAditivos();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          aditivo.titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              final l10n = AppLocalizations.of(context)!;
              if (!allowCopyAndPdf) {
                await _requestPremiumAccess(
                  context,
                  l10n.additivesPremiumCopyPdfMessage,
                );
                return;
              }

              final copyText = await _buildCopyText(context);
              await Clipboard.setData(ClipboardData(text: copyText));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Aditivo copiado al portapapeles.'),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              final l10n = AppLocalizations.of(context)!;
              if (!allowCopyAndPdf) {
                await _requestPremiumAccess(
                  context,
                  l10n.additivesPremiumCopyPdfMessage,
                );
                return;
              }

              final sanitizedDescripcion =
                  _replaceStructuredLinks(_descripcion, forDisplay: true);
              final descripcionConPeligrosidad =
                  '$sanitizedDescripcion\n\n${_buildPeligrosidadTextForPdf()}';
              final toExport = Aditivo(
                codigo: aditivo.codigo,
                titulo: aditivo.titulo,
                descripcion: descripcionConPeligrosidad,
                tipo: aditivo.tipo,
                activo: aditivo.activo,
                peligrosidad: aditivo.peligrosidad,
              );
              await onExportPdf(toExport);
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
              if (_normalizePeligrosidad(aditivo.peligrosidad) != null ||
                  aditivo.tipo.trim().isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_normalizePeligrosidad(aditivo.peligrosidad) != null)
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _showPeligrosidadDetailsDialog(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _peligrosidadColor(aditivo.peligrosidad)
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 16,
                                color: _peligrosidadColor(aditivo.peligrosidad),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Peligrosidad ${_normalizePeligrosidad(aditivo.peligrosidad)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _peligrosidadColor(aditivo.peligrosidad),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (aditivo.tipo.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          aditivo.tipo,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
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
                    Text(
                      'También te puede interesar...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                            onTap: onNavigateToAditivo == null
                                ? null
                                : () {
                                    final l10n = AppLocalizations.of(context)!;
                                    if (!allowDiscoveryNavigation) {
                                      _requestPremiumAccess(
                                        context,
                                        l10n.additivesPremiumExploreMessage,
                                      );
                                      return;
                                    }
                                    onNavigateToAditivo!(item);
                                  },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _peligrosidadColorEmoji(item.peligrosidad),
                                    style: const TextStyle(fontSize: 20),
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
    required this.allAditivos,
    required this.fallbackLabel,
    required this.onTap,
  });

  final String type;
  final int codigo;
  final List<Aditivo> allAditivos;
  final String fallbackLabel;
  final VoidCallback onTap;

  @override
  State<_StructuredLinkTitle> createState() => _StructuredLinkTitleState();
}

class _StructuredLinkTitleState extends State<_StructuredLinkTitle> {
  static final Map<String, String> _titleCache = <String, String>{};

  String get _cacheKey => '${widget.type}:${widget.codigo}';

  String _localAditivoTitle() {
    final found = widget.allAditivos
        .where((item) => item.codigo == widget.codigo)
        .cast<Aditivo?>()
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
      case 'aditivo':
        return 'api/aditivos.php?codigo=${widget.codigo}';
      default:
        return '';
    }
  }

  Future<void> _resolveTitle() async {
    final cached = _titleCache[_cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return;
    }

    if (widget.type == 'aditivo') {
      final localTitle = _localAditivoTitle();
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
      case 'aditivo':
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
