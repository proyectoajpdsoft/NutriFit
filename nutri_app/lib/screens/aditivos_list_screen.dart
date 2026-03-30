import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutri_app/models/aditivo.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/consejo_receta_pdf_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/screens/aditivo_detail_screen.dart';
import 'package:nutri_app/screens/aditivo_edit_screen.dart';
import 'package:nutri_app/utils/aditivos_ai.dart';
import 'package:nutri_app/widgets/peligrosidad_dialog.dart';

enum _OrdenAditivos { nombre, fecha, tipo, peligrosidad }

class AditivosListScreen extends StatefulWidget {
  const AditivosListScreen({super.key});

  @override
  State<AditivosListScreen> createState() => _AditivosListScreenState();
}

class _AditivosListScreenState extends State<AditivosListScreen> {
  static const _prefsSearchVisible = 'Aditivos_search_visible';
  static const _prefsSearchQuery = 'Aditivos_search_query';
  static const _prefsSearchFields = 'Aditivos_search_fields';
  static const _prefsFilterActivo = 'Aditivos_filter_activo';
  static const _prefsFilterTipos = 'Aditivos_filter_tipos';
  static const _prefsFilterTiposMatchAll = 'Aditivos_filter_tipos_match_all';
  static const _prefsFilterPeligrosidades = 'Aditivos_filter_peligrosidades';
  static const _prefsOrden = 'Aditivos_orden';
  static const _prefsOrdenAsc = 'Aditivos_orden_asc';

  List<Aditivo> _items = <Aditivo>[];
  List<Aditivo> _displayed = <Aditivo>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _searchVisible = false;
  bool _pdfLoading = false;
  final Set<int> _togglingActivos = <int>{};
  String _searchQuery = '';
  Set<String> _searchFields = <String>{'titulo', 'descripcion', 'tipo'};
  String _filterActivo = 'todos'; // 'todos' | 'S' | 'N'
  List<String> _tiposCatalogo = List<String>.from(defaultAditivoTypes);
  Set<String> _selectedTipos = <String>{};
  bool _tipoMatchAll = false;
  Set<int> _selectedPeligrosidades = <int>{};
  _OrdenAditivos _ordenAditivos = _OrdenAditivos.nombre;
  bool _ordenAscendente = true;
  String _aiPrompt = defaultAditivosAIPrompt;

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
      return 'Servicio de Aditivos no disponible temporalmente. Inténtalo de nuevo más tarde.';
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
      await prefs.setString(_prefsSearchQuery, _searchQuery);
      await prefs.setStringList(_prefsSearchFields, _searchFields.toList());
      await prefs.setString(_prefsFilterActivo, _filterActivo);
      await prefs.setStringList(_prefsFilterTipos, _selectedTipos.toList());
      await prefs.setBool(_prefsFilterTiposMatchAll, _tipoMatchAll);
      await prefs.setStringList(
        _prefsFilterPeligrosidades,
        _selectedPeligrosidades.map((p) => p.toString()).toList(),
      );
      await prefs.setInt(_prefsOrden, _ordenAditivos.index);
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
        _searchQuery = prefs.getString(_prefsSearchQuery) ?? '';
        _searchTextCtrl.text = _searchQuery;
        final restoredFields =
            prefs.getStringList(_prefsSearchFields) ?? <String>[];
        final normalizedFields = restoredFields
            .where((field) =>
                field == 'titulo' || field == 'descripcion' || field == 'tipo')
            .toSet();
        _searchFields = normalizedFields.isEmpty
            ? <String>{'titulo', 'descripcion', 'tipo'}
            : normalizedFields;
        final restoredActivo =
            prefs.getString(_prefsFilterActivo) ?? _filterActivo;
        final restoredTipos =
            prefs.getStringList(_prefsFilterTipos) ?? <String>[];
        final restoredPeligrosidades =
            prefs.getStringList(_prefsFilterPeligrosidades) ?? <String>[];
        final restoredOrden = prefs.getInt(_prefsOrden);
        final restoredOrdenAsc = prefs.getBool(_prefsOrdenAsc);
        final restoredTiposMatchAll =
            prefs.getBool(_prefsFilterTiposMatchAll) ?? false;
        _filterActivo = {'todos', 'S', 'N'}.contains(restoredActivo)
            ? restoredActivo
            : 'todos';
        _selectedTipos = mergeAditivoTypes(restoredTipos).toSet();
        _selectedPeligrosidades = restoredPeligrosidades
            .map((p) => int.tryParse(p))
            .where((p) => p != null && p >= 1 && p <= 5)
            .cast<int>()
            .toSet();
        _tipoMatchAll = restoredTiposMatchAll;
        _ordenAditivos = restoredOrden != null &&
                restoredOrden >= 0 &&
                restoredOrden < _OrdenAditivos.values.length
            ? _OrdenAditivos.values[restoredOrden]
            : _OrdenAditivos.nombre;
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
          .getParametroValor('ia_prompt_aditivos');
      if (valor != null && valor.isNotEmpty && mounted) {
        setState(() => _aiPrompt = repairCommonMojibake(valor));
      }
    } catch (_) {
      // Mantiene prompt por defecto si no existe parámetro remoto.
    }
  }

  String _normalizeAditivoTypeValue(String value) {
    return repairCommonMojibake(value).trim().toLowerCase();
  }

  List<String> _extractAditivoTypeTokens(String rawType) {
    final cleaned = repairCommonMojibake(rawType).trim();
    if (cleaned.isEmpty) return const <String>[];

    final pieces = cleaned
        .split(RegExp(r'[\n\r,;|/]+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    return pieces.isEmpty ? <String>[cleaned] : pieces;
  }

  bool _matchesSelectedTipos(String aditivoTipo) {
    if (_selectedTipos.isEmpty) return true;

    final normalizedSelections =
        _selectedTipos.map(_normalizeAditivoTypeValue).toSet();
    final tokens = _extractAditivoTypeTokens(aditivoTipo)
        .map(_normalizeAditivoTypeValue)
        .toSet();
    if (tokens.isEmpty) return false;

    if (_tipoMatchAll) {
      return normalizedSelections.every(tokens.contains);
    }
    return normalizedSelections.any(tokens.contains);
  }

  int get _activeFilterCount {
    var total = 0;
    if (_filterActivo != 'todos') total += 1;
    total += _selectedTipos.length;
    return total;
  }

  Future<void> _loadTiposCatalogo() async {
    final api = context.read<ApiService>();
    try {
      final raw = await api.getParametroValor('tipos_aditivos');
      final merged = mergeAditivoTypes(
        <String>[
          ...defaultAditivoTypes,
          ...parseAditivoTypes(raw),
          ..._items.expand((item) => _extractAditivoTypeTokens(item.tipo)),
        ],
      );
      final tiposConAditivos = _items
          .expand((item) => _extractAditivoTypeTokens(item.tipo))
          .map((tipo) => tipo.trim())
          .where((tipo) => tipo.isNotEmpty)
          .map(_normalizeAditivoTypeValue)
          .toSet();

      final filteredMerged = merged
          .where((tipo) =>
              tiposConAditivos.contains(_normalizeAditivoTypeValue(tipo)))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _tiposCatalogo = filteredMerged;
        _selectedTipos = _selectedTipos
            .where((tipo) =>
                tiposConAditivos.contains(_normalizeAditivoTypeValue(tipo)))
            .toSet();
      });
    } catch (_) {
      if (!mounted) return;
      final tiposConAditivos = _items
          .expand((item) => _extractAditivoTypeTokens(item.tipo))
          .map((tipo) => tipo.trim())
          .where((tipo) => tipo.isNotEmpty)
          .map(_normalizeAditivoTypeValue)
          .toSet();

      final merged = mergeAditivoTypes(
        <String>[
          ...defaultAditivoTypes,
          ..._items.expand((item) => _extractAditivoTypeTokens(item.tipo)),
        ],
      );

      final filteredMerged = merged
          .where((tipo) =>
              tiposConAditivos.contains(_normalizeAditivoTypeValue(tipo)))
          .toList(growable: false);

      setState(() {
        _tiposCatalogo = filteredMerged;
        _selectedTipos = _selectedTipos
            .where((tipo) =>
                tiposConAditivos.contains(_normalizeAditivoTypeValue(tipo)))
            .toSet();
      });
    }
  }

  Map<String, Aditivo> _buildTitleToExisting() {
    final map = <String, Aditivo>{};
    for (final item in _items) {
      final k = normalizeAditivoTitle(item.titulo);
      if (k.isNotEmpty) map[k] = item;
    }
    return map;
  }

  /// Returns the existing [Aditivo] that fuzzy-matches [normalizedTitle].
  /// First tries exact match, then checks if one title is a prefix of the
  /// other at a word boundary (space, `(`, or `,`).
  Aditivo? _fuzzyFindExisting(
      String normalizedTitle, Map<String, Aditivo> titleToExisting) {
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
    required Aditivo existing,
    required AditivoImportDraft draft,
  }) {
    final existingLen = existing.descripcion.trim().length;
    final draftLen = draft.descripcion.trim().length;
    return existingLen < draftLen;
  }

  ({int duplicatedInPaste, int alreadyExisting}) _estimateImportConflicts(
    List<AditivoImportDraft> drafts,
  ) {
    final titleToExisting = _buildTitleToExisting();
    final seenTitles = <String>{};
    var duplicatedInPaste = 0;
    var alreadyExisting = 0;

    for (final draft in drafts) {
      final title = normalizeAditivoTitle(draft.titulo);
      if (title.isEmpty || !seenTitles.add(title)) {
        duplicatedInPaste += 1;
      } else if (_fuzzyFindExisting(title, titleToExisting) != null) {
        alreadyExisting += 1;
      }
    }

    return (
      duplicatedInPaste: duplicatedInPaste,
      alreadyExisting: alreadyExisting,
    );
  }

  Future<void> _upsertTiposAditivosParameterFromDrafts(
    List<AditivoImportDraft> drafts,
  ) async {
    final importedTypes = mergeAditivoTypes(
      drafts.map((draft) => draft.tipo),
    );
    if (importedTypes.isEmpty) return;

    try {
      final api = context.read<ApiService>();
      final existing = await api.getParametroByNombre('tipos_aditivos');

      final currentRaw = existing?['valor']?.toString();
      final currentTypes = parseAditivoTypes(currentRaw);
      final mergedTypes = mergeAditivoTypes(
        <String>[
          ...defaultAditivoTypes,
          ...currentTypes,
          ...importedTypes,
        ],
      );
      final newRaw = mergedTypes.join('\n');
      final currentNormalized = mergeAditivoTypes(currentTypes).join('\n');

      if (existing != null && currentNormalized == newRaw) return;

      if (existing == null) {
        await api.createParametro(
          nombre: 'tipos_aditivos',
          valor: newRaw,
          descripcion:
              'Tipos de aditivos para desplegable en edición/importación.',
          categoria: 'aditivos',
          tipo: 'lista',
        );
        return;
      }

      await api.updateParametro(
        codigo: int.tryParse((existing['codigo'] ?? '').toString()),
        nombre: 'tipos_aditivos',
        nombreOriginal: 'tipos_aditivos',
        valor: newRaw,
        valor2: existing['valor2']?.toString(),
        descripcion: (existing['descripcion'] ??
                'Tipos de aditivos para desplegable en edición/importación.')
            .toString(),
        categoria: (existing['categoria'] ?? 'aditivos').toString(),
        tipo: (existing['tipo'] ?? 'lista').toString(),
      );
    } catch (_) {
      // No bloquea la importación si el parámetro no puede escribirse.
    }
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
                'Copia este prompt y pégalo en tu IA favorita para generar Aditivos con formato compatible:',
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
    required Aditivo existing,
    required AditivoImportDraft draft,
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
                  'Aditivo: ${draft.titulo}',
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
    var detected = <AditivoImportDraft>[];
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
          final conflicts = _estimateImportConflicts(detected);
          final estimatedOmissions =
              conflicts.duplicatedInPaste + conflicts.alreadyExisting;
          // Pairs of (draft, existing) for replacement preview
          final titleMap = _buildTitleToExisting();
          final proposedReplacements =
              <({int index, AditivoImportDraft draft, Aditivo existing})>[
            for (var i = 0; i < detected.length; i++)
              if (_fuzzyFindExisting(
                      normalizeAditivoTitle(detected[i].titulo), titleMap)
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
                    'Importar Aditivos con IA',
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
                            'Paso 1: Genera Aditivos con el formato de importación',
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
                        title: 'Paso 2: Copia todos los Aditivos generados.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    _ImportAssistantStepCard(
                      title: 'Paso 3: Pega los Aditivos pulsando en "Pegar".',
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
                                      detected = <AditivoImportDraft>[];
                                      replaceChoices = <int, bool>{};
                                    });

                                    final data = await Clipboard.getData(
                                      Clipboard.kTextPlain,
                                    );
                                    final text = data?.text ?? '';
                                    final parsed = parseAditivosFromAI(text);

                                    if (!mounted) return;
                                    // Precompute fuzzy matches for preview
                                    final titleMap = _buildTitleToExisting();
                                    final newChoices = <int, bool>{};
                                    for (var i = 0; i < parsed.length; i++) {
                                      final d = parsed[i];
                                      final norm =
                                          normalizeAditivoTitle(d.titulo);
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
                                            'No se detectaron aditivos con el formato de importación ([Título], [Descripción], [Tipo]).';
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
                            label: const Text('Pegar Aditivos'),
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
                            ? 'Paso 4: Se mostrarán aquí los Aditivos detectados para importarlos.'
                            : 'Paso 4: Se han obtenido ${detected.length} Aditivos.',
                        child: detected.isEmpty
                            ? null
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (estimatedOmissions > 0)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (conflicts.alreadyExisting > 0)
                                          Text(
                                            replaceExisting
                                                ? '${conflicts.alreadyExisting} se reemplazarán por coincidir con un título existente.'
                                                : '${conflicts.alreadyExisting} se omitirán por coincidir con un título existente.',
                                            style: TextStyle(
                                              color: replaceExisting
                                                  ? Colors.blue.shade700
                                                  : Colors.orange.shade800,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        if (conflicts.duplicatedInPaste > 0)
                                          Text(
                                            '${conflicts.duplicatedInPaste} se omitirán por estar duplicados en el texto pegado.',
                                            style: TextStyle(
                                              color: Colors.orange.shade800,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
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
                                  const SizedBox(height: 6),
                                  Text(
                                    'Aditivos detectados (${detected.length}):',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    constraints:
                                        const BoxConstraints(maxHeight: 220),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: detected.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final d = detected[index];
                                        return ListTile(
                                          dense: true,
                                          title: Text(
                                            d.titulo,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            d.tipo,
                                            style:
                                                const TextStyle(fontSize: 11),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FilledButton.icon(
                                    onPressed: importing
                                        ? null
                                        : () async {
                                            // Map normalizedTitle -> existing item for replace lookup
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

                                            await _upsertTiposAditivosParameterFromDrafts(
                                              detected,
                                            );

                                            for (var i = 0;
                                                i < detected.length;
                                                i++) {
                                              final draft = detected[i];
                                              final normalizedTitle =
                                                  normalizeAditivoTitle(
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
                                                          'api/aditivos.php',
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
                                                            'tipo': draft.tipo
                                                                .trim(),
                                                            'activo': 'S',
                                                            'peligrosidad':
                                                                _normalizePeligrosidad(
                                                              draft.peligrosidad ??
                                                                  existingItem
                                                                      .peligrosidad,
                                                            ),
                                                          }),
                                                        )
                                                    : await context
                                                        .read<ApiService>()
                                                        .post(
                                                          'api/aditivos.php',
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
                                                    'Algún Aditivo no se pudo guardar y se ha contabilizado como omitido.';
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
                                    label: const Text('Importar Aditivos'),
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
                                'Se han importado $importedCount Aditivos nuevos',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (replacedCount > 0) ...[
                              if (importedCount > 0) const SizedBox(height: 4),
                              Text(
                                'Se han reemplazado $replacedCount Aditivos',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (importedCount > 0 || replacedCount > 0)
                              const SizedBox(height: 4),
                            Text(
                              'Se han omitido $omittedCount Aditivos',
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
          content: Text('No hay Aditivos para exportar en PDF.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _pdfLoading = true);
    try {
      final apiService = context.read<ApiService>();

      // Generar descripción del filtro
      final filterDescription = _getFilterDescription();

      // Formatear contenido con tipo y peligrosidad
      final combined = filtered
          .map((aditivo) => [
                aditivo.titulo.toUpperCase(),
                'Tipo: ${aditivo.tipo ?? 'N/A'}',
                'Peligrosidad: ${aditivo.peligrosidad ?? 0}/5',
                aditivo.descripcion,
              ].join('\n'))
          .join('\n\n---\n\n');

      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: 'ADITIVOS ALIMENTARIOS',
        contenido: combined,
        tipo: 'aditivo',
        subtitulo: filterDescription,
        fileName: 'Aditivos',
        preserveEmojis: true,
        isAditivosList: true,
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

  String _getFilterDescription() {
    final filters = <String>[];

    final q = _searchQuery.trim();
    if (q.isNotEmpty) {
      final fields = <String>[];
      if (_searchFields.contains('titulo')) fields.add('titulo');
      if (_searchFields.contains('descripcion')) fields.add('descripcion');
      if (_searchFields.contains('tipo')) fields.add('tipo');
      final scopeText = fields.isEmpty ? 'campos' : fields.join(', ');
      filters.add('Buscar "$q" en: $scopeText');
    }

    if (_filterActivo == 'S') {
      filters.add('Estado: Activos');
    } else if (_filterActivo == 'N') {
      filters.add('Estado: Inactivos');
    }

    if (_selectedPeligrosidades.isNotEmpty) {
      final niveles = _selectedPeligrosidades.toList()..sort();
      filters.add('Peligrosidad: ${niveles.join(', ')}');
    }

    if (_selectedTipos.isNotEmpty) {
      final tipos = _selectedTipos.toList()..sort();
      filters.add('Tipos: ${tipos.join(', ')}');
    }

    if (filters.isEmpty) {
      return 'Filtro actual: Todos';
    }

    return 'Filtro actual: ${filters.join(' | ')}';
  }

  Future<void> _exportItemPdf(Aditivo Aditivo) async {
    try {
      final apiService = context.read<ApiService>();
      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: Aditivo.titulo,
        contenido: Aditivo.descripcion,
        tipo: 'aditivo',
        fileName:
            'Aditivo_${Aditivo.titulo.replaceAll(' ', '_').toLowerCase()}',
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

  Future<void> _openVisualize(Aditivo Aditivo) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AditivoDetailScreen(
          aditivo: Aditivo,
          onExportPdf: _exportItemPdf,
          allAditivos: _items,
          showPremiumRecommendations: context.read<AuthService>().isPremium,
          onNavigateToAditivo: (target) => _openVisualize(target),
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

  Future<void> _toggleActivo(Aditivo s) async {
    final codigo = s.codigo;
    if (codigo == null || _togglingActivos.contains(codigo)) return;

    final nextActivo = s.activo == 'S' ? 'N' : 'S';
    setState(() => _togglingActivos.add(codigo));

    try {
      final response = await context.read<ApiService>().put(
            'api/aditivos.php',
            body: jsonEncode({
              'codigo': s.codigo,
              'titulo': s.titulo,
              'descripcion': s.descripcion,
              'tipo': s.tipo,
              'activo': nextActivo,
              'peligrosidad': _normalizePeligrosidad(s.peligrosidad),
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
              nextActivo == 'S' ? 'Aditivo activado.' : 'Aditivo desactivado.',
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
                    'No se pudo actualizar el estado del Aditivo. Inténtalo de nuevo.',
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
    _loadTiposCatalogo();
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
      final response = await context.read<ApiService>().get('api/aditivos.php');
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _items = data
              .map((e) => Aditivo.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _tiposCatalogo = mergeAditivoTypes(
            <String>[
              ..._tiposCatalogo,
              ..._items.expand((item) => _extractAditivoTypeTokens(item.tipo)),
              ..._selectedTipos,
            ],
          );
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
                fallback: 'No se pudieron cargar los Aditivos en este momento.',
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

  List<Aditivo> _filtered(List<Aditivo> src) {
    final q = _searchQuery.trim().toLowerCase();
    final qVariants = _buildAditivoSearchVariants(q);

    final filtered = src.where((s) {
      final matchQ = q.isEmpty
          ? true
          : (_searchFields.contains('titulo') &&
                  _matchesAditivoSearch(s.titulo, qVariants)) ||
              (_searchFields.contains('descripcion') &&
                  _matchesAditivoSearch(s.descripcion, qVariants)) ||
              (_searchFields.contains('tipo') &&
                  _matchesAditivoSearch(s.tipo, qVariants));
      final matchA = _filterActivo == 'todos' || s.activo == _filterActivo;
      final matchTipo = _matchesSelectedTipos(s.tipo);
      final matchPeligrosidad = _selectedPeligrosidades.isEmpty ||
          (s.peligrosidad != null &&
              _selectedPeligrosidades.contains(s.peligrosidad));
      return matchQ && matchA && matchTipo && matchPeligrosidad;
    }).toList();

    int compareNombre(Aditivo a, Aditivo b) =>
        a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());

    switch (_ordenAditivos) {
      case _OrdenAditivos.nombre:
        filtered.sort((a, b) =>
            _ordenAscendente ? compareNombre(a, b) : compareNombre(b, a));
        break;
      case _OrdenAditivos.fecha:
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
      case _OrdenAditivos.tipo:
        filtered.sort((a, b) {
          final tipoA = a.tipo.toLowerCase().trim();
          final tipoB = b.tipo.toLowerCase().trim();
          final byTipo = _ordenAscendente
              ? tipoA.compareTo(tipoB)
              : tipoB.compareTo(tipoA);
          if (byTipo != 0) return byTipo;
          return compareNombre(a, b);
        });
        break;
      case _OrdenAditivos.peligrosidad:
        filtered.sort((a, b) {
          final peligroA = a.peligrosidad ?? 0;
          final peligroB = b.peligrosidad ?? 0;
          final byPeligro = _ordenAscendente
              ? peligroA.compareTo(peligroB)
              : peligroB.compareTo(peligroA);
          if (byPeligro != 0) return byPeligro;
          return compareNombre(a, b);
        });
        break;
    }

    return filtered;
  }

  void _applySortSelection(_OrdenAditivos orden) {
    setState(() {
      if (_ordenAditivos == orden) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _ordenAditivos = orden;
        _ordenAscendente =
            orden == _OrdenAditivos.nombre || orden == _OrdenAditivos.tipo;
        _ordenAscendente = orden == _OrdenAditivos.nombre ||
            orden == _OrdenAditivos.tipo ||
            orden == _OrdenAditivos.peligrosidad;
      }
      _displayed = [];
      _currentPage = 1;
      _hasMore = true;
    });
    _saveListState();
    _loadMore();
  }

  void _toggleSearchVisibility() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible && _searchQuery.isNotEmpty) {
        _searchTextCtrl.clear();
        _searchQuery = '';
        _displayed = <Aditivo>[];
        _currentPage = 1;
        _hasMore = true;
      }
    });
    _saveListState();
    if (_searchQuery.isEmpty) {
      _loadMore();
    }
  }

  Future<void> _showEditTiposAditivosDialog() async {
    final api = context.read<ApiService>();
    final existing = await api.getParametroByNombre('tipos_aditivos');
    final initial = (existing?['valor'] ?? '').toString();
    final ctrl = TextEditingController(text: initial);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Editar tipos de aditivos',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close),
              tooltip: 'Cerrar',
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Introduce un tipo por línea (parámetro: tipos_aditivos).',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  minLines: 8,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Colorantes\\nConservantes\\nAntioxidantes',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == null) return;

    final cleaned = mergeAditivoTypes(
      result
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty),
    ).join('\n');

    if (existing == null) {
      await api.createParametro(
        nombre: 'tipos_aditivos',
        valor: cleaned,
        descripcion:
            'Tipos de aditivos para desplegable en edición/importación.',
        categoria: 'aditivos',
        tipo: 'lista',
      );
    } else {
      await api.updateParametro(
        codigo: int.tryParse((existing['codigo'] ?? '').toString()),
        nombre: 'tipos_aditivos',
        nombreOriginal: 'tipos_aditivos',
        valor: cleaned,
        valor2: existing['valor2']?.toString(),
        descripcion: (existing['descripcion'] ??
                'Tipos de aditivos para desplegable en edición/importación.')
            .toString(),
        categoria: (existing['categoria'] ?? 'aditivos').toString(),
        tipo: (existing['tipo'] ?? 'lista').toString(),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tipos de aditivos actualizados.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Set<String> _buildAditivoSearchVariants(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const <String>{};

    final variants = <String>{q};
    final compact = q.replaceAll('-', '');
    final eNumero = RegExp(r'^e\d+$');
    final eGuionNumero = RegExp(r'^e-\d+$');

    if (eNumero.hasMatch(compact)) {
      variants.add(compact);
      variants.add('e-${compact.substring(1)}');
    }

    if (eGuionNumero.hasMatch(q)) {
      variants.add('e${q.substring(2)}');
    }

    return variants;
  }

  bool _matchesAditivoSearch(String source, Set<String> queryVariants) {
    final text = source.toLowerCase();
    return queryVariants.any(text.contains);
  }

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

  IconData _peligrosidadIcon(int? value) {
    final normalized = _normalizePeligrosidad(value);
    if (normalized == null) return Icons.help_outline;
    if (normalized >= 4) return Icons.gpp_bad_outlined;
    if (normalized == 3) return Icons.warning_amber_rounded;
    if (normalized == 2) return Icons.report_gmailerrorred_outlined;
    return Icons.verified_user_outlined;
  }

  String _peligrosidadLabel(int? value) =>
      _normalizePeligrosidad(value)?.toString() ?? '?';

  Future<void> _showPeligrosidadDetailsDialog(
    int? peligrosidad,
    String titulo,
  ) async {
    if (!mounted) return;
    await showAditivoPeligrosidadDialog(
      context,
      peligrosidad: peligrosidad,
      titulo: titulo,
    );
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

  void _toggleSearchField(String field, bool selected) {
    final next = Set<String>.from(_searchFields);
    if (selected) {
      next.add(field);
    } else {
      next.remove(field);
    }
    if (next.isEmpty) return;

    setState(() {
      _searchFields = next;
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

  Future<void> _showTipoFilterDialog() async {
    await _loadTiposCatalogo();
    final tempSelected = _selectedTipos.toSet();
    var tempMatchAll = _tipoMatchAll;
    var tempActivos = _filterActivo != 'N';
    var tempInactivos = _filterActivo != 'S';
    var tempPeligrosidades = _selectedPeligrosidades.toSet();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedTypeCount = tempSelected.length;
            final sortedTipos = List<String>.from(_tiposCatalogo)
              ..sort((a, b) =>
                  a.toLowerCase().trim().compareTo(b.toLowerCase().trim()));

            final peligrosidadLabels = {
              1: 'Seguro',
              2: 'Atención',
              3: 'Alto',
              4: 'Restringido',
              5: 'Prohibido',
            };

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtrar Aditivos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar',
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.68,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('Activos'),
                              selected: tempActivos,
                              onSelected: (selected) {
                                setDialogState(() => tempActivos = selected);
                              },
                            ),
                            FilterChip(
                              label: const Text('Inactivos'),
                              selected: tempInactivos,
                              onSelected: (selected) {
                                setDialogState(() => tempInactivos = selected);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        const Text(
                          'Peligrosidad',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 42,
                          child: Scrollbar(
                            thumbVisibility: true,
                            notificationPredicate: (notification) =>
                                notification.metrics.axis == Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List<int>.from([1, 2, 3, 4, 5])
                                    .map((nivel) {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: nivel == 5 ? 0 : 8,
                                    ),
                                    child: FilterChip(
                                      label: Text(peligrosidadLabels[nivel]!),
                                      selected:
                                          tempPeligrosidades.contains(nivel),
                                      onSelected: (selected) {
                                        setDialogState(() {
                                          if (selected) {
                                            tempPeligrosidades.add(nivel);
                                          } else {
                                            tempPeligrosidades.remove(nivel);
                                          }
                                        });
                                      },
                                    ),
                                  );
                                }).toList(growable: false),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        if (sortedTipos.isNotEmpty)
                          Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.22,
                              ),
                              child: Scrollbar(
                                thumbVisibility: sortedTipos.length > 8,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: sortedTipos.map((tipo) {
                                      return FilterChip(
                                        label: Text(tipo),
                                        selected: tempSelected.contains(tipo),
                                        onSelected: (selected) {
                                          setDialogState(() {
                                            if (selected) {
                                              tempSelected.add(tipo);
                                            } else {
                                              tempSelected.remove(tipo);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(growable: false),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          value: tempMatchAll,
                          onChanged: (value) =>
                              setDialogState(() => tempMatchAll = value),
                          title: const Text('Coincidir todas'),
                          subtitle: const Text(
                            'Exige todos los tipos seleccionados.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterActivo = 'todos';
                      _selectedTipos = <String>{};
                      _tipoMatchAll = false;
                      _selectedPeligrosidades = <int>{};
                      _displayed = <Aditivo>[];
                      _currentPage = 1;
                      _hasMore = true;
                    });
                    _saveListState();
                    _loadMore();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Limpiar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    String nextActivo = 'todos';
                    if (tempActivos && !tempInactivos) {
                      nextActivo = 'S';
                    } else if (!tempActivos && tempInactivos) {
                      nextActivo = 'N';
                    }

                    setState(() {
                      _filterActivo = nextActivo;
                      _selectedTipos = tempSelected;
                      _tipoMatchAll = tempMatchAll;
                      _selectedPeligrosidades = tempPeligrosidades;
                      _displayed = <Aditivo>[];
                      _currentPage = 1;
                      _hasMore = true;
                    });
                    _saveListState();
                    _loadMore();
                    Navigator.pop(dialogContext);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Aplicar'),
                      const SizedBox(width: 8),
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              selectedTypeCount > 0 ? Colors.blue : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$selectedTypeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _delete(Aditivo s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar el Aditivo "${s.titulo}"?'),
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
          .delete('api/aditivos.php?codigo=${s.codigo}');
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aditivo eliminado'),
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
                fallback: 'No se pudo eliminar el Aditivo. Inténtalo de nuevo.',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openMenu(Aditivo s) async {
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
              leading: Icon(
                s.activo == 'S' ? Icons.check_circle : Icons.cancel,
                color: s.activo == 'S' ? Colors.green : Colors.red,
              ),
              title: const Text('Activo'),
              onTap: () => Navigator.pop(ctx, 'activo'),
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
          builder: (_) => AditivoEditScreen(aditivo: s),
        ),
      );
      if (result == true) _load();
    } else if (action == 'activo') {
      await _toggleActivo(s);
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
  bool _sharesTitleWord(Aditivo base, Aditivo candidate) {
    if (candidate.codigo == base.codigo) return false;
    final baseWords = _titleWords(base.titulo).toSet();
    return _titleWords(candidate.titulo).any(baseWords.contains);
  }

  Future<void> _showUnificarDialog(Aditivo base) async {
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

    List<Aditivo> _filtered(String q) {
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
                      'A los seleccionados se les reemplazará su descripción por un enlace estructurado al Aditivo principal. Busca y marca los duplicados:',
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
                              ? 'No se encontraron Aditivos con palabras en común con "${base.titulo}"'
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
                          'Se han unificado $unifiedCount Aditivos enlazados al principal.',
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
                                        'Se modificará la descripción de ${toUnify.length} Aditivo${toUnify.length == 1 ? '' : 's'}:',
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
                                                  ? '[[Véase enlace_aditivo_${base.codigo}]]'
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
                                      ? '[[Véase enlace_aditivo_${base.codigo}]]'
                                      : 'Véase ${base.titulo}';
                                  final response =
                                      await context.read<ApiService>().put(
                                            'api/aditivos.php',
                                            body: jsonEncode({
                                              'codigo': s.codigo,
                                              'titulo': s.titulo,
                                              'descripcion': unifiedDescription,
                                              'tipo': s.tipo,
                                              'activo': s.activo,
                                              'peligrosidad':
                                                  _normalizePeligrosidad(
                                                s.peligrosidad,
                                              ),
                                            }),
                                          );
                                  if (response.statusCode == 200 ||
                                      response.statusCode == 201) {
                                    ok++;
                                  } else {
                                    unifyError =
                                        'Algún Aditivo no se pudo actualizar.';
                                  }
                                } catch (_) {
                                  unifyError =
                                      'Error de red al actualizar algún Aditivo.';
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
            const Text('Aditivos'),
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
          IconButton(
            tooltip: _activeFilterCount > 0
                ? 'Filtrar (${_activeFilterCount})'
                : 'Filtrar',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(_activeFilterCount > 0
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined),
                if (_activeFilterCount > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_activeFilterCount',
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
            onPressed: _showTipoFilterDialog,
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) {
              if (value == 'buscar') {
                _toggleSearchVisibility();
                return;
              }
              if (value == 'filtrar') {
                _showTipoFilterDialog();
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
              if (value == 'editar_tipos') {
                _showEditTiposAditivosDialog();
                return;
              }
              if (value == 'sort_nombre') {
                _applySortSelection(_OrdenAditivos.nombre);
                return;
              }
              if (value == 'sort_fecha') {
                _applySortSelection(_OrdenAditivos.fecha);
                return;
              }
              if (value == 'sort_tipo') {
                _applySortSelection(_OrdenAditivos.tipo);
              }
              if (value == 'sort_peligrosidad') {
                _applySortSelection(_OrdenAditivos.peligrosidad);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'buscar',
                child: Row(
                  children: [
                    Icon(
                      _searchVisible ? Icons.search_off : Icons.search,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _searchVisible ? 'Ocultar buscar' : 'Buscar',
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'filtrar',
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.label_outline, size: 18),
                        if (_selectedTipos.isNotEmpty)
                          Positioned(
                            right: -8,
                            top: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_selectedTipos.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _activeFilterCount > 0
                          ? 'Filtrar (${_activeFilterCount})'
                          : 'Filtrar',
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'exportar_pdf',
                enabled: !_pdfLoading,
                child: Row(
                  children: [
                    if (_pdfLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(_pdfLoading ? 'Generando PDF…' : 'Generar PDF'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'copiar_ia',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18),
                    SizedBox(width: 8),
                    Text('Copiar IA'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'pegar_ia',
                child: Row(
                  children: [
                    Icon(Icons.content_paste_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Pegar IA'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'editar_tipos',
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 18),
                    SizedBox(width: 8),
                    Text('Modificar tipos'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'refrescar',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Actualizar'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem<String>(
                value: 'sort_nombre',
                checked: _ordenAditivos == _OrdenAditivos.nombre,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Nombre')),
                    if (_ordenAditivos == _OrdenAditivos.nombre)
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
                checked: _ordenAditivos == _OrdenAditivos.fecha,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Recientes')),
                    if (_ordenAditivos == _OrdenAditivos.fecha)
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
                value: 'sort_tipo',
                checked: _ordenAditivos == _OrdenAditivos.tipo,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar tipo')),
                    if (_ordenAditivos == _OrdenAditivos.tipo)
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
                value: 'sort_peligrosidad',
                checked: _ordenAditivos == _OrdenAditivos.peligrosidad,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar peligrosidad')),
                    if (_ordenAditivos == _OrdenAditivos.peligrosidad)
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
                    Column(
                      children: [
                        TextField(
                          controller: _searchTextCtrl,
                          decoration: InputDecoration(
                            hintText: 'Buscar Aditivos',
                            prefixIcon: IconButton(
                              tooltip: _searchQuery.isNotEmpty
                                  ? 'Limpiar búsqueda'
                                  : 'Buscar',
                              onPressed: _searchQuery.isNotEmpty
                                  ? () {
                                      _searchTextCtrl.clear();
                                      _applySearch('');
                                    }
                                  : null,
                              icon: Icon(_searchQuery.isNotEmpty
                                  ? Icons.clear
                                  : Icons.search),
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'Ocultar búsqueda',
                              onPressed: _toggleSearchVisibility,
                              icon: const Icon(Icons.visibility_off_outlined),
                            ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: _applySearch,
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('Título'),
                                selected: _searchFields.contains('titulo'),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  color: _searchFields.contains('titulo')
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                                backgroundColor: Colors.grey[200],
                                selectedColor: Colors.grey[600],
                                onSelected: (v) =>
                                    _toggleSearchField('titulo', v),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Descripción'),
                                selected: _searchFields.contains('descripcion'),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  color: _searchFields.contains('descripcion')
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                                backgroundColor: Colors.grey[200],
                                selectedColor: Colors.grey[600],
                                onSelected: (v) =>
                                    _toggleSearchField('descripcion', v),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Tipo'),
                                selected: _searchFields.contains('tipo'),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  color: _searchFields.contains('tipo')
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                                backgroundColor: Colors.grey[200],
                                selectedColor: Colors.grey[600],
                                onSelected: (v) =>
                                    _toggleSearchField('tipo', v),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                          child: Text('No hay Aditivos para mostrar'),
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
                              final peligrosidadColor =
                                  _peligrosidadColor(s.peligrosidad);
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
                                          builder: (_) =>
                                              AditivoEditScreen(aditivo: s),
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
                                          GestureDetector(
                                            onTap: () =>
                                                _showPeligrosidadDetailsDialog(
                                              s.peligrosidad,
                                              s.titulo,
                                            ),
                                            child: Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: peligrosidadColor
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Center(
                                                    child: Icon(
                                                      _peligrosidadIcon(
                                                          s.peligrosidad),
                                                      color: peligrosidadColor,
                                                      size: 24,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: -6,
                                                    top: -6,
                                                    child: Container(
                                                      width: 18,
                                                      height: 18,
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            peligrosidadColor,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Text(
                                                        _peligrosidadLabel(
                                                            s.peligrosidad),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
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
                                                if (s.tipo
                                                    .trim()
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 6),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.teal.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              999),
                                                    ),
                                                    child: Text(
                                                      s.tipo,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors
                                                            .teal.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
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
              builder: (_) => const AditivoEditScreen(),
            ),
          );
          if (result == true) _load();
        },
        tooltip: 'Añadir Aditivo',
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
