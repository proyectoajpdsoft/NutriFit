import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutri_app/models/suplemento.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/consejo_receta_pdf_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/screens/suplemento_detail_screen.dart';
import 'package:nutri_app/screens/suplemento_edit_screen.dart';
import 'package:nutri_app/utils/suplementos_ai.dart';

enum _OrdenSuplementos { nombre, fecha }

class SuplementosListScreen extends StatefulWidget {
  const SuplementosListScreen({super.key});

  @override
  State<SuplementosListScreen> createState() => _SuplementosListScreenState();
}

class _SuplementosListScreenState extends State<SuplementosListScreen> {
  static const _prefsSearchVisible = 'suplementos_search_visible';
  static const _prefsFilterVisible = 'suplementos_filter_visible';
  static const _prefsSearchQuery = 'suplementos_search_query';
  static const _prefsSearchScope = 'suplementos_search_scope';
  static const _prefsFilterActivo = 'suplementos_filter_activo';
  static const _prefsOrden = 'suplementos_orden';
  static const _prefsOrdenAsc = 'suplementos_orden_asc';

  List<Suplemento> _items = <Suplemento>[];
  List<Suplemento> _displayed = <Suplemento>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _searchVisible = false;
  bool _filterVisible = false;
  bool _pdfLoading = false;
  final Set<int> _togglingActivos = <int>{};
  String _searchQuery = '';
  String _searchScope = 'ambos'; // 'titulo' | 'descripcion' | 'ambos'
  String _filterActivo = 'todos'; // 'todos' | 'S' | 'N'
  _OrdenSuplementos _ordenSuplementos = _OrdenSuplementos.nombre;
  bool _ordenAscendente = true;
  String _aiPrompt = defaultSuplementosAIPrompt;

  static const int _pageSize = 20;
  int _currentPage = 1;
  bool _hasMore = true;

  late final ScrollController _scrollCtrl;
  final TextEditingController _searchTextCtrl = TextEditingController();

  String _friendlyApiError(
    Object error, {
    required String fallback,
  }) {
    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (lower.contains('<html') ||
        lower.contains('<!doctype') ||
        lower.contains('404') ||
        lower.contains('not found')) {
      return 'Servicio de suplementos no disponible temporalmente. Inténtalo de nuevo más tarde.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection')) {
      return 'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';
    }
    return fallback;
  }

  Future<void> _saveListState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsSearchVisible, _searchVisible);
      await prefs.setBool(_prefsFilterVisible, _filterVisible);
      await prefs.setString(_prefsSearchQuery, _searchQuery);
      await prefs.setString(_prefsSearchScope, _searchScope);
      await prefs.setString(_prefsFilterActivo, _filterActivo);
      await prefs.setInt(_prefsOrden, _ordenSuplementos.index);
      await prefs.setBool(_prefsOrdenAsc, _ordenAscendente);
    } catch (_) {
      // Ignore persistence failures to avoid breaking UI flow.
    }
  }

  Future<void> _restoreListState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _searchVisible = prefs.getBool(_prefsSearchVisible) ?? false;
        _filterVisible = prefs.getBool(_prefsFilterVisible) ?? false;
        _searchQuery = prefs.getString(_prefsSearchQuery) ?? '';
        _searchTextCtrl.text = _searchQuery;
        final restoredScope =
            prefs.getString(_prefsSearchScope) ?? _searchScope;
        _searchScope =
            {'titulo', 'descripcion', 'ambos'}.contains(restoredScope)
                ? restoredScope
                : 'ambos';
        final restoredActivo =
            prefs.getString(_prefsFilterActivo) ?? _filterActivo;
        final restoredOrden = prefs.getInt(_prefsOrden);
        final restoredOrdenAsc = prefs.getBool(_prefsOrdenAsc);
        _filterActivo = {'todos', 'S', 'N'}.contains(restoredActivo)
            ? restoredActivo
            : 'todos';
        _ordenSuplementos = restoredOrden != null &&
                restoredOrden >= 0 &&
                restoredOrden < _OrdenSuplementos.values.length
            ? _OrdenSuplementos.values[restoredOrden]
            : _OrdenSuplementos.nombre;
        _ordenAscendente = restoredOrdenAsc ?? true;
      });
    } catch (_) {
      // Ignore persistence failures to avoid breaking screen startup.
    }
  }

  Future<void> _loadAIPrompt() async {
    try {
      final valor = await context
          .read<ApiService>()
          .getParametroValor('ia_prompt_suplementos');
      if (valor != null && valor.isNotEmpty && mounted) {
        setState(() => _aiPrompt = valor);
      }
    } catch (_) {
      // Mantiene prompt por defecto si no existe parámetro remoto.
    }
  }

  Map<String, Suplemento> _buildTitleToExisting() {
    final map = <String, Suplemento>{};
    for (final item in _items) {
      final k = normalizeSuplementoTitle(item.titulo);
      if (k.isNotEmpty) map[k] = item;
    }
    return map;
  }

  /// Returns the existing [Suplemento] that fuzzy-matches [normalizedTitle].
  /// First tries exact match, then checks if one title is a prefix of the
  /// other at a word boundary (space, `(`, or `,`).
  Suplemento? _fuzzyFindExisting(
      String normalizedTitle, Map<String, Suplemento> titleToExisting) {
    if (normalizedTitle.isEmpty) return null;
    final exact = titleToExisting[normalizedTitle];
    if (exact != null) return exact;
    for (final entry in titleToExisting.entries) {
      final key = entry.key;
      final shorter =
          normalizedTitle.length <= key.length ? normalizedTitle : key;
      final longer =
          normalizedTitle.length <= key.length ? key : normalizedTitle;
      if (!longer.startsWith(shorter)) continue;
      if (longer.length == shorter.length) return entry.value;
      final next = longer[shorter.length];
      if (next == ' ' || next == '(' || next == ',') return entry.value;
    }
    return null;
  }

  bool _shouldReplaceExistingByDescriptionLength({
    required Suplemento existing,
    required SuplementoImportDraft draft,
  }) {
    final existingLen = existing.descripcion.trim().length;
    final draftLen = draft.descripcion.trim().length;
    return existingLen < draftLen;
  }

  int _estimateImportOmissions(List<SuplementoImportDraft> drafts) {
    final titleToExisting = _buildTitleToExisting();
    final seenTitles = <String>{};
    var omitted = 0;

    for (final draft in drafts) {
      final title = normalizeSuplementoTitle(draft.titulo);
      if (title.isEmpty || !seenTitles.add(title)) {
        omitted += 1;
      } else if (_fuzzyFindExisting(title, titleToExisting) != null) {
        omitted += 1;
      }
    }

    return omitted;
  }

  void _showAIPromptDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Prompt para IA',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copia este prompt y pégalo en tu IA favorita para generar suplementos con formato compatible:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _aiPrompt,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _aiPrompt));
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Prompt copiado al portapapeles.'),
                  backgroundColor: Colors.deepPurple,
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReplaceComparisonDialog({
    required Suplemento existing,
    required SuplementoImportDraft draft,
  }) async {
    var split = 0.5;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
          title: Row(
            children: [
              const Icon(Icons.compare_arrows_rounded,
                  color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Comparar descripciones',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 760,
            height: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suplemento: ${draft.titulo}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const splitterHeight = 14.0;
                      const minPaneHeight = 110.0;
                      final availableHeight =
                          (constraints.maxHeight - splitterHeight)
                              .clamp(0.0, double.infinity);
                      var minRatio = availableHeight <= 0
                          ? 0.2
                          : (minPaneHeight / availableHeight).clamp(0.2, 0.8);
                      var maxRatio = (1 - minRatio).clamp(0.2, 0.8);
                      if (maxRatio < minRatio) {
                        minRatio = 0.5;
                        maxRatio = 0.5;
                      }
                      final effectiveSplit = split.clamp(minRatio, maxRatio);
                      final topHeight = availableHeight * effectiveSplit;
                      final bottomHeight = availableHeight - topHeight;

                      return Column(
                        children: [
                          SizedBox(
                            height: topHeight,
                            child: _ImportComparePane(
                              title:
                                  'Actual (${existing.descripcion.trim().length} chars)',
                              color: Colors.orange,
                              text: existing.descripcion,
                            ),
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.resizeUpDown,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: (details) {
                                if (availableHeight <= 0) return;
                                final deltaRatio =
                                    details.delta.dy / availableHeight;
                                setS(() {
                                  split = (split + deltaRatio)
                                      .clamp(minRatio, maxRatio);
                                });
                              },
                              child: SizedBox(
                                height: splitterHeight,
                                child: Center(
                                  child: Container(
                                    width: 44,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade400,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: bottomHeight,
                            child: _ImportComparePane(
                              title:
                                  'IA (${draft.descripcion.trim().length} chars)',
                              color: Colors.blue,
                              text: draft.descripcion,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImportAssistant() async {
    var detected = <SuplementoImportDraft>[];
    var analyzing = false;
    var importing = false;
    var importFinished = false;
    var compactAfterPaste = false;
    var replaceExisting = false;
    var replaceChoices = <int, bool>{};
    var importedCount = 0;
    var replacedCount = 0;
    var omittedCount = 0;
    var processedCount = 0;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final estimatedOmissions = _estimateImportOmissions(detected);
          // Pairs of (draft, existing) for replacement preview
          final titleMap = _buildTitleToExisting();
          final proposedReplacements =
              <({int index, SuplementoImportDraft draft, Suplemento existing})>[
            for (var i = 0; i < detected.length; i++)
              if (_fuzzyFindExisting(
                      normalizeSuplementoTitle(detected[i].titulo), titleMap)
                  case final existing?)
                (index: i, draft: detected[i], existing: existing),
          ]..sort((a, b) {
                  final aDelta = a.existing.descripcion.trim().length -
                      a.draft.descripcion.trim().length;
                  final bDelta = b.existing.descripcion.trim().length -
                      b.draft.descripcion.trim().length;
                  return bDelta.compareTo(aDelta);
                });
          final selectedReplacementCount = proposedReplacements
              .where(
                (e) =>
                    replaceChoices[e.index] ??
                    _shouldReplaceExistingByDescriptionLength(
                      existing: e.existing,
                      draft: e.draft,
                    ),
              )
              .length;
          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            title: Row(
              children: [
                const Icon(Icons.content_paste_rounded,
                    color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Importar suplementos con IA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: importFinished ? 'Cerrar' : 'Cancelar',
                  onPressed:
                      importing ? null : () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!compactAfterPaste) ...[
                      _ImportAssistantStepCard(
                        title:
                            'Paso 1: Genera suplementos con el formato de importación',
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: importing ? null : _showAIPromptDialog,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Ver prompt de IA'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _ImportAssistantStepCard(
                        title: 'Paso 2: Copia todos los suplementos generados.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    _ImportAssistantStepCard(
                      title:
                          'Paso 3: Pega los suplementos pulsando en "Pegar".',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilledButton.icon(
                            onPressed: analyzing || importing
                                ? null
                                : () async {
                                    setDialogState(() {
                                      compactAfterPaste = true;
                                      analyzing = true;
                                      importFinished = false;
                                      importedCount = 0;
                                      omittedCount = 0;
                                      processedCount = 0;
                                      errorText = null;
                                      detected = <SuplementoImportDraft>[];
                                      replaceChoices = <int, bool>{};
                                    });

                                    final data = await Clipboard.getData(
                                      Clipboard.kTextPlain,
                                    );
                                    final text = data?.text ?? '';
                                    final parsed = parseSuplementosFromAI(text);

                                    if (!mounted) return;
                                    // Precompute fuzzy matches for preview
                                    final titleMap = _buildTitleToExisting();
                                    final newChoices = <int, bool>{};
                                    for (var i = 0; i < parsed.length; i++) {
                                      final d = parsed[i];
                                      final norm =
                                          normalizeSuplementoTitle(d.titulo);
                                      final existing =
                                          _fuzzyFindExisting(norm, titleMap);
                                      if (existing != null) {
                                        newChoices[i] =
                                            _shouldReplaceExistingByDescriptionLength(
                                          existing: existing,
                                          draft: d,
                                        );
                                      }
                                    }
                                    setDialogState(() {
                                      analyzing = false;
                                      detected = parsed;
                                      replaceChoices = newChoices;
                                      if (text.trim().isEmpty) {
                                        errorText =
                                            'El portapapeles está vacío.';
                                      } else if (parsed.isEmpty) {
                                        errorText =
                                            'No se detectaron suplementos con el formato de importación ([Título] y [Descripción]).';
                                      }
                                    });
                                  },
                            icon: analyzing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.content_paste_go_rounded),
                            label: const Text('Pegar suplementos'),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              errorText!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!importFinished)
                      _ImportAssistantStepCard(
                        title: detected.isEmpty
                            ? 'Paso 4: Se mostrarán aquí los suplementos detectados para importarlos.'
                            : 'Paso 4: Se han obtenido ${detected.length} suplementos.',
                        child: detected.isEmpty
                            ? null
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (estimatedOmissions > 0)
                                    Text(
                                      replaceExisting
                                          ? '$estimatedOmissions se reemplazarán por tener el mismo título.'
                                          : '$estimatedOmissions se omitirán por tener el mismo título.',
                                      style: TextStyle(
                                        color: replaceExisting
                                            ? Colors.blue.shade700
                                            : Colors.orange.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  if (estimatedOmissions > 0)
                                    const SizedBox(height: 8),
                                  SwitchListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Reemplazar existentes',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    subtitle: const Text(
                                      'Si el título coincide, actualiza la descripción.',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    value: replaceExisting,
                                    onChanged: importing
                                        ? null
                                        : (v) => setDialogState(() {
                                              replaceExisting = v;
                                            }),
                                  ),
                                  if (proposedReplacements.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      replaceExisting
                                          ? 'Selecciona cuáles reemplazar ($selectedReplacementCount de ${proposedReplacements.length}):'
                                          : 'Coincidencias detectadas: se omitirán si no activas "Reemplazar existentes".',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: replaceExisting
                                            ? Colors.blue.shade700
                                            : Colors.orange.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      constraints:
                                          const BoxConstraints(maxHeight: 260),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: replaceExisting
                                                ? Colors.blue.shade100
                                                : Colors.orange.shade100),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: proposedReplacements.length,
                                        itemBuilder: (context, idx) {
                                          final entry =
                                              proposedReplacements[idx];
                                          final newLen = entry.draft.descripcion
                                              .trim()
                                              .length;
                                          final existingLen = entry
                                              .existing.descripcion
                                              .trim()
                                              .length;
                                          final checked = replaceChoices[
                                                  entry.index] ??
                                              _shouldReplaceExistingByDescriptionLength(
                                                existing: entry.existing,
                                                draft: entry.draft,
                                              );
                                          return InkWell(
                                            onLongPress: importing
                                                ? null
                                                : () =>
                                                    _showReplaceComparisonDialog(
                                                      existing: entry.existing,
                                                      draft: entry.draft,
                                                    ),
                                            child: CheckboxListTile(
                                              dense: true,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              value: checked,
                                              onChanged: importing
                                                  ? null
                                                  : (v) => setDialogState(() {
                                                        replaceChoices[entry
                                                            .index] = v ?? true;
                                                      }),
                                              title: Text(
                                                entry.draft.titulo,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (entry.draft.titulo
                                                          .trim() !=
                                                      entry.existing.titulo
                                                          .trim()) ...[
                                                    Text(
                                                      'Existe como: ${entry.existing.titulo}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey.shade600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                  ],
                                                  Text(
                                                    'IA: $newLen · Actual: $existingLen',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          existingLen > newLen
                                                              ? Colors.orange
                                                                  .shade800
                                                              : Colors.blue
                                                                  .shade700,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  const SizedBox(height: 4),
                                  FilledButton.icon(
                                    onPressed: importing
                                        ? null
                                        : () async {
                                            // Map normalizedTitle → existing item for replace lookup
                                            final titleToExisting =
                                                _buildTitleToExisting();
                                            // Tracks titles already processed in this batch
                                            final processedTitles = <String>{};
                                            var hasServerErrors = false;

                                            setDialogState(() {
                                              importing = true;
                                              importFinished = false;
                                              importedCount = 0;
                                              replacedCount = 0;
                                              omittedCount = 0;
                                              processedCount = 0;
                                              errorText = null;
                                            });

                                            for (var i = 0;
                                                i < detected.length;
                                                i++) {
                                              final draft = detected[i];
                                              final normalizedTitle =
                                                  normalizeSuplementoTitle(
                                                draft.titulo,
                                              );

                                              // Skip empty or intra-batch duplicates
                                              if (normalizedTitle.isEmpty ||
                                                  !processedTitles
                                                      .add(normalizedTitle)) {
                                                omittedCount += 1;
                                                processedCount += 1;
                                                if (mounted) {
                                                  setDialogState(() {});
                                                }
                                                continue;
                                              }

                                              final existingItem =
                                                  _fuzzyFindExisting(
                                                      normalizedTitle,
                                                      titleToExisting);
                                              final isExisting =
                                                  existingItem != null;
                                              final shouldReplaceCurrent =
                                                  isExisting
                                                      ? (replaceChoices[i] ??
                                                          _shouldReplaceExistingByDescriptionLength(
                                                            existing:
                                                                existingItem!,
                                                            draft: draft,
                                                          ))
                                                      : false;

                                              // Skip pre-existing when not replacing or user unchecked
                                              if (isExisting &&
                                                  (!replaceExisting ||
                                                      !shouldReplaceCurrent)) {
                                                omittedCount += 1;
                                                processedCount += 1;
                                                if (mounted) {
                                                  setDialogState(() {});
                                                }
                                                continue;
                                              }

                                              try {
                                                final response = isExisting &&
                                                        replaceExisting
                                                    ? await context
                                                        .read<ApiService>()
                                                        .put(
                                                          'api/suplementos.php',
                                                          body: jsonEncode({
                                                            'codigo':
                                                                existingItem
                                                                    .codigo,
                                                            'titulo': draft
                                                                .titulo
                                                                .trim(),
                                                            'descripcion': draft
                                                                .descripcion
                                                                .trim(),
                                                            'activo': 'S',
                                                          }),
                                                        )
                                                    : await context
                                                        .read<ApiService>()
                                                        .post(
                                                          'api/suplementos.php',
                                                          body: jsonEncode(
                                                            draft
                                                                .toCreatePayload(),
                                                          ),
                                                        );

                                                if (response.statusCode ==
                                                        200 ||
                                                    response.statusCode ==
                                                        201) {
                                                  if (isExisting &&
                                                      replaceExisting) {
                                                    replacedCount += 1;
                                                  } else {
                                                    importedCount += 1;
                                                  }
                                                } else {
                                                  omittedCount += 1;
                                                  hasServerErrors = true;
                                                }
                                              } catch (_) {
                                                omittedCount += 1;
                                                hasServerErrors = true;
                                              }

                                              processedCount += 1;
                                              if (mounted) {
                                                setDialogState(() {});
                                              }
                                            }

                                            await _load();
                                            if (!mounted) return;
                                            setDialogState(() {
                                              importing = false;
                                              importFinished = true;
                                              if (hasServerErrors) {
                                                errorText =
                                                    'Algún suplemento no se pudo guardar y se ha contabilizado como omitido.';
                                              }
                                            });
                                          },
                                    icon: importing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.cloud_upload_outlined),
                                    label: const Text('Importar suplementos'),
                                  ),
                                  if (importing) ...[
                                    const SizedBox(height: 12),
                                    LinearProgressIndicator(
                                      value: detected.isEmpty
                                          ? null
                                          : processedCount / detected.length,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Progreso: $processedCount de ${detected.length}',
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    if (importFinished)
                      _ImportAssistantStepCard(
                        title: 'Resultado de la importación',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (importedCount > 0)
                              Text(
                                'Se han importado $importedCount suplementos nuevos',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (replacedCount > 0) ...[
                              if (importedCount > 0) const SizedBox(height: 4),
                              Text(
                                'Se han reemplazado $replacedCount suplementos',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (importedCount > 0 || replacedCount > 0)
                              const SizedBox(height: 4),
                            Text(
                              'Se han omitido $omittedCount suplementos',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportListPdf() async {
    final filtered = _filtered(_items);
    if (filtered.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay suplementos para exportar en PDF.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _pdfLoading = true);
    try {
      final apiService = context.read<ApiService>();
      final combined = filtered
          .map((s) => '${s.titulo}\n${s.descripcion}')
          .join('\n\n---\n\n');

      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: 'Suplementos',
        contenido: combined,
        tipo: 'suplemento',
        fileName: 'suplementos',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  Future<void> _exportItemPdf(Suplemento suplemento) async {
    try {
      final apiService = context.read<ApiService>();
      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: suplemento.titulo,
        contenido: suplemento.descripcion,
        tipo: 'suplemento',
        fileName:
            'suplemento_${suplemento.titulo.replaceAll(' ', '_').toLowerCase()}',
        preserveEmojis: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openVisualize(Suplemento suplemento) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SuplementoDetailScreen(
          suplemento: suplemento,
          onExportPdf: _exportItemPdf,
          allSuplementos: _items,
          showPremiumRecommendations: context.read<AuthService>().isPremium,
          onNavigateToSuplemento: (target) => _openVisualize(target),
          onHashtagTap: (hashtag) {
            setState(() {
              _searchVisible = true;
            });
            _applySearch(hashtag);
          },
        ),
      ),
    );
  }

  Future<void> _toggleActivo(Suplemento s) async {
    final codigo = s.codigo;
    if (codigo == null || _togglingActivos.contains(codigo)) return;

    final nextActivo = s.activo == 'S' ? 'N' : 'S';
    setState(() => _togglingActivos.add(codigo));

    try {
      final response = await context.read<ApiService>().put(
            'api/suplementos.php',
            body: jsonEncode({
              'codigo': s.codigo,
              'titulo': s.titulo,
              'descripcion': s.descripcion,
              'activo': nextActivo,
            }),
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        setState(() {
          final idx = _items.indexWhere((it) => it.codigo == codigo);
          if (idx >= 0) {
            _items[idx].activo = nextActivo;
          }

          _displayed = [];
          _currentPage = 1;
          _hasMore = true;
        });
        _loadMore();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextActivo == 'S'
                  ? 'Suplemento activado.'
                  : 'Suplemento desactivado.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyApiError(
                e,
                fallback:
                    'No se pudo actualizar el estado del suplemento. Inténtalo de nuevo.',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _togglingActivos.remove(codigo));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    final apiService = Provider.of<ApiService>(context, listen: false);
    context
        .read<ConfigService>()
        .loadDeleteSwipePercentageFromDatabase(apiService);
    _loadAIPrompt();
    _restoreListState().whenComplete(() {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchTextCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent * 0.8) {
      if (!_loadingMore && _hasMore) _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _displayed = [];
      _currentPage = 1;
      _hasMore = true;
    });
    try {
      final response =
          await context.read<ApiService>().get('api/suplementos.php');
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _items = data
              .map((e) =>
                  Suplemento.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
        _loadMore();
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyApiError(
                e,
                fallback:
                    'No se pudieron cargar los suplementos en este momento.',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _loadMore() {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final all = _filtered(_items);
      final start = (_currentPage - 1) * _pageSize;
      final end = start + _pageSize;

      if (start < all.length) {
        setState(() {
          _displayed.addAll(all.sublist(start, end.clamp(0, all.length)));
          _currentPage++;
          _hasMore = end < all.length;
          _loading = false;
          _loadingMore = false;
        });
      } else {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _hasMore = false;
        });
      }
    });
  }

  List<Suplemento> _filtered(List<Suplemento> src) {
    final filtered = src.where((s) {
      final q = _searchQuery.trim().toLowerCase();
      final matchQ = q.isEmpty
          ? true
          : _searchScope == 'titulo'
              ? s.titulo.toLowerCase().contains(q)
              : _searchScope == 'descripcion'
                  ? s.descripcion.toLowerCase().contains(q)
                  : s.titulo.toLowerCase().contains(q) ||
                      s.descripcion.toLowerCase().contains(q);
      final matchA = _filterActivo == 'todos' || s.activo == _filterActivo;
      return matchQ && matchA;
    }).toList();

    int compareNombre(Suplemento a, Suplemento b) =>
        a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());

    switch (_ordenSuplementos) {
      case _OrdenSuplementos.nombre:
        filtered.sort((a, b) =>
            _ordenAscendente ? compareNombre(a, b) : compareNombre(b, a));
        break;
      case _OrdenSuplementos.fecha:
        filtered.sort((a, b) {
          final dateA = a.fechaa;
          final dateB = b.fechaa;
          int byDate;
          if (dateA == null && dateB == null) {
            byDate = 0;
          } else if (dateA == null) {
            byDate = -1;
          } else if (dateB == null) {
            byDate = 1;
          } else {
            byDate = dateA.compareTo(dateB);
          }
          if (!_ordenAscendente) byDate = -byDate;
          if (byDate != 0) return byDate;
          return compareNombre(a, b);
        });
        break;
    }

    return filtered;
  }

  void _applySortSelection(_OrdenSuplementos orden) {
    setState(() {
      if (_ordenSuplementos == orden) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _ordenSuplementos = orden;
        _ordenAscendente = orden == _OrdenSuplementos.nombre;
      }
      _displayed = [];
      _currentPage = 1;
      _hasMore = true;
    });
    _saveListState();
    _loadMore();
  }

  int _activeFilterCount() {
    return _filterActivo == 'todos' ? 0 : 1;
  }

  void _toggleSearchVisibility() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchTextCtrl.clear();
        _searchQuery = '';
        _displayed = [];
        _currentPage = 1;
        _hasMore = true;
      }
    });
    _saveListState();
    _loadMore();
  }

  Future<void> _showFiltroSuplementosDialog() async {
    var tempActivo = _filterActivo;

    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          return AlertDialog(
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filtro suplementos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 340,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Todos'),
                    selected: tempActivo == 'todos',
                    onSelected: (_) {
                      setDialog(() {
                        tempActivo = 'todos';
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Activos'),
                    selected: tempActivo == 'S',
                    onSelected: (_) {
                      setDialog(() {
                        tempActivo = 'S';
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Inactivos'),
                    selected: tempActivo == 'N',
                    onSelected: (_) {
                      setDialog(() {
                        tempActivo = 'N';
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  tempActivo = 'todos';
                  Navigator.pop(context, true);
                },
                child: const Text('Limpiar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );

    if (applied != true) return;

    setState(() {
      _filterActivo = tempActivo;
      _displayed = [];
      _currentPage = 1;
      _hasMore = true;
      _filterVisible = _filterActivo != 'todos';
    });
    _saveListState();
    _loadMore();
  }

  void _applySearch(String value) {
    setState(() {
      _searchQuery = value;
      _displayed = [];
      _currentPage = 1;
      _hasMore = true;
    });
    _saveListState();
    _loadMore();
  }

  void _applySearchScope(String scope) {
    setState(() {
      _searchScope = scope;
      _displayed = [];
      _currentPage = 1;
      _hasMore = true;
    });
    _saveListState();
    _loadMore();
  }

  void _applyFilter(String value) {
    setState(() {
      _filterActivo = value;
      _displayed = [];
      _currentPage = 1;
      _hasMore = true;
    });
    _saveListState();
    _loadMore();
  }

  Future<void> _delete(Suplemento s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar el suplemento "${s.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await context
          .read<ApiService>()
          .delete('api/suplementos.php?codigo=${s.codigo}');
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Suplemento eliminado'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _load();
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyApiError(
                e,
                fallback:
                    'No se pudo eliminar el suplemento. Inténtalo de nuevo.',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openMenu(Suplemento s) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Visualizar'),
              onTap: () => Navigator.pop(ctx, 'visualizar'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.merge_type_rounded),
              title: const Text('Unificar duplicados'),
              onTap: () => Navigator.pop(ctx, 'unificar'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (action == 'edit') {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SuplementoEditScreen(suplemento: s),
        ),
      );
      if (result == true) _load();
    } else if (action == 'visualizar') {
      await _openVisualize(s);
    } else if (action == 'unificar') {
      await _showUnificarDialog(s);
    } else if (action == 'delete') {
      await _delete(s);
    }
  }

  /// Returns the significant words from a supplement title (length > 2,
  /// ignoring stop-words like articles and prepositions).
  static const _stopWords = {
    'de',
    'del',
    'la',
    'las',
    'los',
    'el',
    'en',
    'y',
    'o',
    'a',
    'con',
    'sin',
    'para',
    'por',
    'un',
    'una',
    'unos',
    'unas',
  };

  List<String> _titleWords(String titulo) {
    return titulo
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-záéíóúüñ\s]', caseSensitive: false), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toList();
  }

  /// Returns true if [candidate] shares at least one significant word with [base].
  bool _sharesTitleWord(Suplemento base, Suplemento candidate) {
    if (candidate.codigo == base.codigo) return false;
    final baseWords = _titleWords(base.titulo).toSet();
    return _titleWords(candidate.titulo).any(baseWords.contains);
  }

  Future<void> _showUnificarDialog(Suplemento base) async {
    var searchQuery = '';
    final allCandidates =
        _items.where((s) => _sharesTitleWord(base, s)).toList();
    final allSearchable = _items.where((s) => s.codigo != base.codigo).toList();
    // selected set by codigo
    final selected = <int?>{
      for (final c in allCandidates) c.codigo,
    };
    var unifying = false;
    var done = false;
    var unifiedCount = 0;
    String? unifyError;

    List<Suplemento> _filtered(String q) {
      if (q.trim().isEmpty) return allCandidates;
      final lq = q.trim().toLowerCase();
      return allSearchable
          .where((s) => s.titulo.toLowerCase().contains(lq))
          .toList();
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setS) {
          final visible = _filtered(searchQuery);
          final checkedCount =
              visible.where((s) => selected.contains(s.codigo)).length;
          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            title: Row(
              children: [
                const Icon(Icons.merge_type_rounded,
                    color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Unificar duplicados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed:
                      unifying ? null : () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Base supplement info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.deepPurple.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.deepPurple, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  base.titulo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Desc.: ${base.descripcion.trim().length} carac.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.deepPurple.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'A los seleccionados se les reemplazará su descripción por un enlace estructurado al suplemento principal. Busca y marca los duplicados:',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    // Search field
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar por título...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (v) => setS(() => searchQuery = v),
                    ),
                    const SizedBox(height: 8),
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          allCandidates.isEmpty
                              ? 'No se encontraron suplementos con palabras en común con "${base.titulo}"'
                              : 'Sin resultados para la búsqueda.',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Text(
                            '$checkedCount de ${visible.length} seleccionados',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: unifying
                                ? null
                                : () => setS(() {
                                      for (final s in visible) {
                                        selected.add(s.codigo);
                                      }
                                    }),
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            child: const Text('Todos',
                                style: TextStyle(fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: unifying
                                ? null
                                : () => setS(() {
                                      for (final s in visible) {
                                        selected.remove(s.codigo);
                                      }
                                    }),
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            child: const Text('Ninguno',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 240),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.deepPurple.shade100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: visible.length,
                          itemBuilder: (_, idx) {
                            final s = visible[idx];
                            final isChecked = selected.contains(s.codigo);
                            return CheckboxListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              value: isChecked,
                              onChanged: unifying
                                  ? null
                                  : (v) => setS(() => v == true
                                      ? selected.add(s.codigo)
                                      : selected.remove(s.codigo)),
                              title: Text(
                                s.titulo,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Descripción: ${s.descripcion.trim().length} caracteres',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.deepPurple.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (done) ...[
                      const SizedBox(height: 12),
                      if (unifiedCount > 0)
                        Text(
                          'Se han unificado $unifiedCount suplementos enlazados al principal.',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.deepPurple,
                          ),
                        ),
                      if (unifyError != null)
                        Text(
                          unifyError!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                    if (unifying) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            actions: done
                ? [
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cerrar'),
                    ),
                  ]
                : [
                    FilledButton.icon(
                      icon: const Icon(Icons.merge_type_rounded, size: 16),
                      label: Text(
                        checkedCount == 0
                            ? 'Unificar seleccionados'
                            : 'Unificar $checkedCount seleccionado${checkedCount == 1 ? '' : 's'}',
                      ),
                      onPressed: (unifying || checkedCount == 0)
                          ? null
                          : () async {
                              final toUnify = allCandidates
                                  .where((s) => selected.contains(s.codigo))
                                  .toList();

                              // Confirmation dialog
                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (confirmCtx) => AlertDialog(
                                  title: const Text('Confirmar unificación'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Se modificará la descripción de ${toUnify.length} suplemento${toUnify.length == 1 ? '' : 's'}:',
                                      ),
                                      const SizedBox(height: 8),
                                      ...toUnify.map(
                                        (s) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 2),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                  Icons.arrow_right_rounded,
                                                  size: 16),
                                              Expanded(
                                                child: Text(
                                                  s.titulo,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      RichText(
                                        text: TextSpan(
                                          style: DefaultTextStyle.of(confirmCtx)
                                              .style
                                              .copyWith(fontSize: 13),
                                          children: [
                                            const TextSpan(
                                                text:
                                                    'Su descripción se reemplazará por: '),
                                            TextSpan(
                                              text: base.codigo != null
                                                  ? '[[Véase enlace_suplemento_${base.codigo}]]'
                                                  : 'Véase ${base.titulo}',
                                              style: const TextStyle(
                                                  fontStyle: FontStyle.italic,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(confirmCtx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(confirmCtx, true),
                                      style: FilledButton.styleFrom(
                                          backgroundColor: Colors.deepPurple),
                                      child: const Text('Confirmar'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              setS(() {
                                unifying = true;
                                unifyError = null;
                              });

                              var ok = 0;
                              for (final s in toUnify) {
                                try {
                                  final unifiedDescription = base.codigo != null
                                      ? '[[Véase enlace_suplemento_${base.codigo}]]'
                                      : 'Véase ${base.titulo}';
                                  final response =
                                      await context.read<ApiService>().put(
                                            'api/suplementos.php',
                                            body: jsonEncode({
                                              'codigo': s.codigo,
                                              'titulo': s.titulo,
                                              'descripcion': unifiedDescription,
                                              'activo': s.activo,
                                            }),
                                          );
                                  if (response.statusCode == 200 ||
                                      response.statusCode == 201) {
                                    ok++;
                                  } else {
                                    unifyError =
                                        'Algún suplemento no se pudo actualizar.';
                                  }
                                } catch (_) {
                                  unifyError =
                                      'Error de red al actualizar algún suplemento.';
                                }
                              }

                              await _load();
                              if (!mounted) return;
                              setS(() {
                                unifying = false;
                                done = true;
                                unifiedCount = ok;
                              });
                            },
                    ),
                  ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCount = _filtered(_items).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Suplementos'),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$filteredCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _searchVisible ? 'Ocultar buscar' : 'Buscar',
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
            onPressed: _toggleSearchVisibility,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Filtro suplementos',
                icon: const Icon(Icons.filter_alt),
                onPressed: _showFiltroSuplementosDialog,
              ),
              if (_activeFilterCount() > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${_activeFilterCount()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) {
              if (value == 'buscar') {
                _toggleSearchVisibility();
                return;
              }
              if (value == 'filtros') {
                _showFiltroSuplementosDialog();
                return;
              }
              if (value == 'exportar_pdf') {
                _exportListPdf();
                return;
              }
              if (value == 'refrescar') {
                _load();
                return;
              }
              if (value == 'copiar_ia') {
                _showAIPromptDialog();
                return;
              }
              if (value == 'pegar_ia') {
                _showImportAssistant();
                return;
              }
              if (value == 'sort_nombre') {
                _applySortSelection(_OrdenSuplementos.nombre);
                return;
              }
              if (value == 'sort_fecha') {
                _applySortSelection(_OrdenSuplementos.fecha);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'buscar',
                child: ListTile(
                  leading: Icon(
                    _searchVisible ? Icons.search_off : Icons.search,
                  ),
                  title: Text(_searchVisible ? 'Ocultar buscar' : 'Buscar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'filtros',
                child: ListTile(
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(width: 18, height: 18),
                      const Icon(Icons.filter_alt, size: 18),
                      if (_activeFilterCount() > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            constraints: const BoxConstraints(
                                minWidth: 14, minHeight: 14),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 1),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${_activeFilterCount()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: const Text('Filtrar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'exportar_pdf',
                enabled: !_pdfLoading,
                child: ListTile(
                  leading: _pdfLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  title: Text(_pdfLoading ? 'Generando PDF…' : 'Generar PDF'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'copiar_ia',
                child: ListTile(
                  leading: Icon(Icons.auto_awesome, size: 18),
                  title: Text('Copiar IA'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'pegar_ia',
                child: ListTile(
                  leading: Icon(Icons.content_paste_rounded, size: 18),
                  title: Text('Pegar IA'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'refrescar',
                child: ListTile(
                  leading: Icon(Icons.refresh, size: 18),
                  title: Text('Actualizar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem<String>(
                value: 'sort_nombre',
                checked: _ordenSuplementos == _OrdenSuplementos.nombre,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Nombre')),
                    if (_ordenSuplementos == _OrdenSuplementos.nombre)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<String>(
                value: 'sort_fecha',
                checked: _ordenSuplementos == _OrdenSuplementos.fecha,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Recientes')),
                    if (_ordenSuplementos == _OrdenSuplementos.fecha)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_searchVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    Builder(
                      builder: (context) {
                        final hasSearch = _searchQuery.trim().isNotEmpty;
                        return TextField(
                          controller: _searchTextCtrl,
                          decoration: InputDecoration(
                            labelText: 'Buscar suplementos',
                            prefixIcon: IconButton(
                              tooltip:
                                  hasSearch ? 'Limpiar búsqueda' : 'Buscar',
                              onPressed: hasSearch
                                  ? () {
                                      _searchTextCtrl.clear();
                                      _applySearch('');
                                    }
                                  : null,
                              icon: Icon(
                                hasSearch ? Icons.clear : Icons.search,
                              ),
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'Ocultar búsqueda',
                              onPressed: _toggleSearchVisibility,
                              icon: const Icon(Icons.visibility_off_outlined),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: _applySearch,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Título'),
                            selected: _searchScope == 'titulo',
                            onSelected: (v) {
                              if (v) _applySearchScope('titulo');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Descripción'),
                            selected: _searchScope == 'descripcion',
                            onSelected: (v) {
                              if (v) _applySearchScope('descripcion');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Ambos'),
                            selected: _searchScope == 'ambos',
                            onSelected: (v) {
                              if (v) _applySearchScope('ambos');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: _loading && _displayed.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _displayed.isEmpty
                      ? const Center(
                          child: Text('No hay suplementos para mostrar'),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: EdgeInsets.fromLTRB(
                              0,
                              0,
                              0,
                              96 + MediaQuery.of(context).padding.bottom,
                            ),
                            itemCount:
                                _displayed.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (ctx, index) {
                              if (index == _displayed.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              final s = _displayed[index];
                              final descChars = s.descripcion.trim().length;
                              final isToggling = (s.codigo != null &&
                                  _togglingActivos.contains(s.codigo));
                              return Dismissible(
                                key: ValueKey(
                                    'suplLst_${s.codigo ?? s.titulo}_$index'),
                                direction: DismissDirection.startToEnd,
                                dismissThresholds: {
                                  DismissDirection.startToEnd: context
                                      .watch<ConfigService>()
                                      .deleteSwipeDismissThreshold,
                                },
                                background: Container(
                                  color: Colors.red.shade600,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: const Row(children: [
                                    Icon(Icons.delete_outline,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('Eliminar',
                                        style: TextStyle(color: Colors.white)),
                                  ]),
                                ),
                                confirmDismiss: (_) async {
                                  await _delete(s);
                                  return false;
                                },
                                child: Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  child: InkWell(
                                    onTap: () async {
                                      final result = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SuplementoEditScreen(
                                              suplemento: s),
                                        ),
                                      );
                                      if (result == true) _load();
                                    },
                                    onLongPress: () => _openMenu(s),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.medication_outlined,
                                              color: Colors.teal.shade700,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  s.titulo,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (s.descripcion
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    s.descripcion,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            Colors.grey[700]),
                                                  ),
                                                ],
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    ActionChip(
                                                      avatar: isToggling
                                                          ? const SizedBox(
                                                              width: 14,
                                                              height: 14,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                            )
                                                          : Icon(
                                                              s.activo == 'S'
                                                                  ? Icons
                                                                      .check_circle
                                                                  : Icons
                                                                      .cancel,
                                                              size: 16,
                                                              color: s.activo ==
                                                                      'S'
                                                                  ? Colors.green
                                                                  : Colors.red,
                                                            ),
                                                      label: Text(
                                                        s.activo == 'S'
                                                            ? 'Activo'
                                                            : 'Inactivo',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: s.activo == 'S'
                                                              ? Colors.green
                                                              : Colors.red,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      onPressed: isToggling
                                                          ? null
                                                          : () =>
                                                              _toggleActivo(s),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .blueGrey.shade50,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        border: Border.all(
                                                          color: Colors.blueGrey
                                                              .shade200,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        '$descChars carac.',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.blueGrey
                                                              .shade700,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.more_vert),
                                                      iconSize: 18,
                                                      tooltip: 'Más opciones',
                                                      onPressed: () =>
                                                          _openMenu(s),
                                                    ),
                                                  ],
                                                ),
                                              ],
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
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const SuplementoEditScreen(),
            ),
          );
          if (result == true) _load();
        },
        tooltip: 'Añadir suplemento',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ImportComparePane extends StatelessWidget {
  final String title;
  final Color color;
  final String text;

  const _ImportComparePane({
    required this.title,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                text.trim().isEmpty ? '(Sin descripción)' : text,
                style: const TextStyle(fontSize: 12, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportAssistantStepCard extends StatelessWidget {
  const _ImportAssistantStepCard({
    required this.title,
    this.child,
  });

  final String title;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (child != null) ...[
            const SizedBox(height: 8),
            child!,
          ],
        ],
      ),
    );
  }
}
