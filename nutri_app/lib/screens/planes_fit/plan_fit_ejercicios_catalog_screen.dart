import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nutri_app/models/plan_fit.dart';
import 'package:nutri_app/models/plan_fit_categoria.dart';
import 'package:nutri_app/models/plan_fit_ejercicio.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/screens/contacto_nutricionista_screen.dart';
import 'package:nutri_app/screens/planes_fit/plan_fit_ejercicio_catalog_edit_screen.dart';
import 'package:nutri_app/screens/planes_fit/plan_fit_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/services/ejercicios_catalog_pdf_service.dart';
import 'package:nutri_app/services/thumbnail_generator.dart';
import 'package:nutri_app/utils/plan_fit_ejercicios_ai.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/widgets/image_viewer_dialog.dart';
import 'package:nutri_app/widgets/paste_image_dialog.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../widgets/premium_feature_dialog_helper.dart';
import '../../widgets/premium_upsell_card.dart';

enum _OrdenCatalogo { usos, nombre, fechaAlta, categoria }

enum _CatalogSearchField { all, title, instructions, hashtags }

Future<void> _showPremiumRequiredForEjerciciosTools(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return PremiumFeatureDialogHelper.show(
    context,
    message: l10n.exerciseCatalogPremiumToolsMessage,
  );
}

Future<void> _showPremiumRequiredForEjerciciosVideo(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return PremiumFeatureDialogHelper.show(
    context,
    message: l10n.exerciseCatalogPremiumVideoMessage,
  );
}

class PlanFitEjerciciosCatalogScreen extends StatefulWidget {
  final bool openCreateDialog;
  final bool readOnly;
  final bool premiumVisibleOnly;

  const PlanFitEjerciciosCatalogScreen({
    super.key,
    this.openCreateDialog = false,
    this.readOnly = false,
    this.premiumVisibleOnly = false,
  });

  @override
  State<PlanFitEjerciciosCatalogScreen> createState() =>
      _PlanFitEjerciciosCatalogScreenState();
}

class _ImportComparePane extends StatelessWidget {
  const _ImportComparePane({
    required this.title,
    required this.color,
    required this.text,
  });

  final String title;
  final Color color;
  final String text;

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
          SizedBox(
            height: 120,
            child: SingleChildScrollView(
              child: SelectableText(
                text.trim().isEmpty ? '(Sin contenido)' : text,
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

class _PlanFitEjerciciosCatalogScreenState
    extends State<PlanFitEjerciciosCatalogScreen> {
  static const String _paramNonPremiumPreviewCodes =
      'codigos_ejercicios_no_premium';
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  Timer? _addTimer;
  Timer? _removeTimer;

  Widget _buildLongPressNumberField({
    required String label,
    required TextEditingController controller,
    required StateSetter setStateDialog,
    required VoidCallback hasChangesSetter,
    int min = 0,
    int max = 9999,
    IconData? labelIcon,
  }) {
    int getValue() => int.tryParse(controller.text) ?? min;

    void setValue(int v) {
      final next = v.clamp(min, max);
      controller.text = next.toString();
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
      setStateDialog(() {});
      hasChangesSetter();
    }

    void stopTimers() {
      _addTimer?.cancel();
      _addTimer = null;
      _removeTimer?.cancel();
      _removeTimer = null;
    }

    Widget buildStepperButton({
      required IconData icon,
      required VoidCallback onTap,
      required VoidCallback onLongPressStart,
    }) {
      return GestureDetector(
        onTap: onTap,
        onLongPressStart: (_) => onLongPressStart(),
        onLongPressEnd: (_) => stopTimers(),
        onLongPressCancel: stopTimers,
        child: Container(
          width: 38,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 12),
        ),
      );
    }

    return TextField(
      controller: controller,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label.isNotEmpty ? label : null,
        prefixIcon: labelIcon != null ? Icon(labelIcon, size: 18) : null,
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        isDense: true,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 92, minHeight: 40),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildStepperButton(
                icon: Icons.remove,
                onTap: () {
                  final next = getValue() - 1;
                  setValue(next < min ? min : next);
                },
                onLongPressStart: () {
                  stopTimers();
                  _removeTimer = Timer.periodic(
                    const Duration(milliseconds: 80),
                    (t) {
                      final next = getValue() - 1;
                      setValue(next < min ? min : next);
                    },
                  );
                },
              ),
              const SizedBox(width: 4),
              buildStepperButton(
                icon: Icons.add,
                onTap: () {
                  final next = getValue() + 1;
                  setValue(next > max ? max : next);
                },
                onLongPressStart: () {
                  stopTimers();
                  _addTimer = Timer.periodic(const Duration(milliseconds: 80), (
                    t,
                  ) {
                    final next = getValue() + 1;
                    setValue(next > max ? max : next);
                  });
                },
              ),
            ],
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      keyboardType: TextInputType.number,
      onChanged: (text) {
        if (text.isEmpty) {
          return;
        }
        final parsed = int.tryParse(text);
        if (parsed == null) {
          return;
        }
        setValue(parsed);
      },
      onSubmitted: (_) => setValue(getValue()),
      onTapOutside: (_) => setValue(getValue()),
    );
  }

  bool _isDesktopPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS;
  }

  Widget _buildCountCircleBadge(int count) {
    final active = count > 0;
    final backgroundColor =
        active ? Colors.green.shade600 : Colors.grey.shade400;

    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _listScrollController;
  bool _loading = true;
  List<PlanFitEjercicio> _items = [];
  List<PlanFitEjercicio> _displayedItems = [];
  List<PlanFitCategoria> _categorias = [];
  Map<int, int> _ejerciciosPorCategoria = {};
  bool _showFilters = false;
  bool _showChartView = false;
  Set<int> _selectedCategoriaIds = {};
  bool? _filtroPremium; // null=todos, true=solo premium, false=no premium
  _OrdenCatalogo _ordenCatalogo = _OrdenCatalogo.usos;
  _CatalogSearchField _searchField = _CatalogSearchField.all;
  bool _ordenAscendente = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _aiPrompt = defaultPlanFitEjerciciosAIPrompt;
  List<int>? _nonPremiumPreviewCodes;

  static const int _pageSize = 20;

  static const String _filtroPremiumKey = 'plan_fit_catalog_filtro_premium';
  static const String _ordenCatalogoKey = 'plan_fit_catalog_orden';
  static const String _ordenCatalogoAscKey = 'plan_fit_catalog_orden_asc';
  static const String _searchKey = 'plan_fit_catalog_search';
  static const String _searchFieldKey = 'plan_fit_catalog_search_field';

  @override
  void initState() {
    super.initState();
    _listScrollController = ScrollController()..addListener(_onScroll);
    _initStateAsync();
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _canAccessFullCatalog {
    final auth = context.read<AuthService>();
    final userType = (auth.userType ?? '').toLowerCase().trim();
    return auth.isPremium ||
        userType == 'nutricionista' ||
        userType == 'administrador';
  }

  bool get _isNonPremiumPreviewMode {
    return widget.readOnly &&
        widget.premiumVisibleOnly &&
        !_canAccessFullCatalog;
  }

  List<int>? _parsePreviewCodes(String? rawValue) {
    final raw =
        (rawValue ?? '').trim().replaceAll(';', ',').replaceAll('|', ',');
    if (raw.isEmpty) return null;

    final codes = raw
        .split(',')
        .map((item) => int.tryParse(item.trim()))
        .whereType<int>()
        .where((value) => value > 0)
        .toList(growable: false);

    if (codes.isEmpty) return null;
    return codes;
  }

  List<PlanFitEjercicio> _buildPreviewEjercicios(
    List<PlanFitEjercicio> source,
    List<int>? configuredCodes,
  ) {
    if (configuredCodes != null && configuredCodes.isNotEmpty) {
      final byCode = <int, PlanFitEjercicio>{
        for (final item in source)
          if (item.codigo > 0) item.codigo: item,
      };
      final configuredItems = configuredCodes
          .map((code) => byCode[code])
          .whereType<PlanFitEjercicio>()
          .toList(growable: false);
      if (configuredItems.isNotEmpty) {
        return configuredItems;
      }
    }

    final preview = List<PlanFitEjercicio>.from(source);
    preview.sort((a, b) => b.codigo.compareTo(a.codigo));
    return preview.take(3).toList(growable: false);
  }

  String _catalogHighlightCount(int total) {
    if (total <= 0) return '0';
    if (total < 10) return '$total';
    return '${total - (total % 10)}';
  }

  void _onScroll() {
    if (!_listScrollController.hasClients) return;
    if (_listScrollController.position.pixels >=
        _listScrollController.position.maxScrollExtent * 0.8) {
      if (!_loadingMore && _hasMore && !_loading) {
        _loadMore();
      }
    }
  }

  Future<void> _initStateAsync() async {
    await context
        .read<ConfigService>()
        .loadDeleteSwipePercentageFromDatabase(_apiService);
    await _loadAIPrompt();
    await _loadUiState();
    await _loadData();
    // Abrir diálogo de crear si se solicita
    if (mounted && widget.openCreateDialog && !widget.readOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openEjercicioDialog();
      });
    }
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final showFilters = prefs.getBool('plan_fit_catalog_show_filters') ?? false;
    final search = prefs.getString(_searchKey) ?? '';
    final selectedIds =
        prefs.getStringList('plan_fit_catalog_selected_categories') ?? [];
    final storedPremium = prefs.getInt(_filtroPremiumKey);
    final storedOrden = prefs.getInt(_ordenCatalogoKey);
    final storedOrdenAsc = prefs.getBool(_ordenCatalogoAscKey);
    final storedSearchField = prefs.getInt(_searchFieldKey);
    final filtroPremium = storedPremium == null || storedPremium == -1
        ? null
        : storedPremium == 1;
    final ordenCatalogo = storedOrden != null &&
            storedOrden >= 0 &&
            storedOrden < _OrdenCatalogo.values.length
        ? _OrdenCatalogo.values[storedOrden]
        : _OrdenCatalogo.usos;
    final searchField = storedSearchField != null &&
            storedSearchField >= 0 &&
            storedSearchField < _CatalogSearchField.values.length
        ? _CatalogSearchField.values[storedSearchField]
        : _CatalogSearchField.all;
    final ordenAscendente = storedOrdenAsc ?? false;
    if (mounted) {
      setState(() {
        _showFilters = showFilters;
        _searchController.text = search.trim();
        _selectedCategoriaIds = selectedIds
            .map((id) => int.tryParse(id) ?? 0)
            .where((id) => id > 0)
            .toSet();
        _filtroPremium = filtroPremium;
        _ordenCatalogo = ordenCatalogo;
        _searchField = searchField;
        _ordenAscendente = ordenAscendente;
      });
    }
  }

  Future<void> _saveFilterState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('plan_fit_catalog_show_filters', _showFilters);
    await prefs.setString(_searchKey, _searchController.text.trim());
    await prefs.setStringList(
      'plan_fit_catalog_selected_categories',
      _selectedCategoriaIds.map((id) => id.toString()).toList(),
    );
    await prefs.setInt(
      _filtroPremiumKey,
      _filtroPremium == null ? -1 : (_filtroPremium! ? 1 : 0),
    );
    await prefs.setInt(_searchFieldKey, _searchField.index);
    await prefs.setInt(_ordenCatalogoKey, _ordenCatalogo.index);
    await prefs.setBool(_ordenCatalogoAscKey, _ordenAscendente);
  }

  Future<void> _loadAIPrompt() async {
    try {
      final valor = await context
          .read<ApiService>()
          .getParametroValor('ia_prompt_ejercicios');
      if (valor != null && valor.trim().isNotEmpty && mounted) {
        setState(() => _aiPrompt = repairCommonMojibake(valor));
      }
    } catch (_) {
      // Keep default prompt when remote parameter is unavailable.
    }
  }

  Map<String, PlanFitEjercicio> _buildTitleToExisting() {
    final map = <String, PlanFitEjercicio>{};
    for (final item in _items) {
      final key = normalizePlanFitEjercicioTitle(item.nombre);
      if (key.isNotEmpty) {
        map[key] = item;
      }
    }
    return map;
  }

  PlanFitEjercicio? _fuzzyFindExisting(
    String normalizedTitle,
    Map<String, PlanFitEjercicio> titleToExisting,
  ) {
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
      if (next == ' ' || next == '(' || next == ',') {
        return entry.value;
      }
    }

    return null;
  }

  bool _shouldReplaceExistingByContentLength({
    required PlanFitEjercicio existing,
    required PlanFitEjercicioImportDraft draft,
  }) {
    final existingLen = (existing.instrucciones ?? '').trim().length +
        (existing.instruccionesDetalladas ?? '').trim().length;
    final draftLen = draft.instruccionesCortas.trim().length +
        draft.comoSeHace.trim().length;
    return existingLen < draftLen;
  }

  ({int duplicatedInPaste, int alreadyExisting}) _estimateImportConflicts(
    List<PlanFitEjercicioImportDraft> drafts,
  ) {
    final titleToExisting = _buildTitleToExisting();
    final seen = <String>{};
    var duplicatedInPaste = 0;
    var alreadyExisting = 0;

    for (final draft in drafts) {
      final title = normalizePlanFitEjercicioTitle(draft.titulo);
      if (title.isEmpty || !seen.add(title)) {
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

  Map<String, PlanFitCategoria> _buildCategoriaNameMap() {
    final map = <String, PlanFitCategoria>{};
    for (final categoria in _categorias) {
      final key = normalizePlanFitCategoriaName(categoria.nombre);
      if (key.isNotEmpty) {
        map[key] = categoria;
      }
    }
    return map;
  }

  ({List<int> matchedIds, List<String> missingCategorias})
      _resolveCategoriasForDraft(
    PlanFitEjercicioImportDraft draft,
    Map<String, PlanFitCategoria> categoriaNameMap,
  ) {
    final matched = <int>{};
    final missing = <String>{};

    for (final nombre in draft.categorias) {
      final key = normalizePlanFitCategoriaName(nombre);
      if (key.isEmpty) continue;
      final categoria = categoriaNameMap[key];
      if (categoria == null) {
        missing.add(nombre.trim());
      } else {
        matched.add(categoria.codigo);
      }
    }

    return (
      matchedIds: matched.toList(growable: false),
      missingCategorias: missing.toList(growable: false),
    );
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
          width: 680,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copia este prompt y pégalo en tu IA favorita para generar ejercicios con formato compatible:',
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
    required PlanFitEjercicio existing,
    required PlanFitEjercicioImportDraft draft,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
        title: Row(
          children: [
            const Icon(Icons.compare_arrows_rounded,
                color: Colors.deepPurple, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Comparar contenido',
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
          width: 820,
          height: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ejercicio: ${draft.titulo}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _ImportComparePane(
                  title:
                      'Actual · Instrucciones cortas (${(existing.instrucciones ?? '').trim().length} chars)',
                  color: Colors.orange,
                  text: existing.instrucciones ?? '',
                ),
                const SizedBox(height: 10),
                _ImportComparePane(
                  title:
                      'IA · Instrucciones cortas (${draft.instruccionesCortas.trim().length} chars)',
                  color: Colors.blue,
                  text: draft.instruccionesCortas,
                ),
                const SizedBox(height: 10),
                _ImportComparePane(
                  title:
                      'Actual · Cómo se hace (${(existing.instruccionesDetalladas ?? '').trim().length} chars)',
                  color: Colors.orange,
                  text: existing.instruccionesDetalladas ?? '',
                ),
                const SizedBox(height: 10),
                _ImportComparePane(
                  title:
                      'IA · Cómo se hace (${draft.comoSeHace.trim().length} chars)',
                  color: Colors.blue,
                  text: draft.comoSeHace,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportAssistant() async {
    var detected = <PlanFitEjercicioImportDraft>[];
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
    var categoriasNoEncontradas = <String>{};
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final conflicts = _estimateImportConflicts(detected);
          final estimatedOmissions =
              conflicts.duplicatedInPaste + conflicts.alreadyExisting;
          final titleMap = _buildTitleToExisting();

          final proposedReplacements = <({
            int index,
            PlanFitEjercicioImportDraft draft,
            PlanFitEjercicio existing
          })>[
            for (var i = 0; i < detected.length; i++)
              if (_fuzzyFindExisting(
                normalizePlanFitEjercicioTitle(detected[i].titulo),
                titleMap,
              )
                  case final existing?)
                (index: i, draft: detected[i], existing: existing),
          ];

          final selectedReplacementCount = proposedReplacements
              .where(
                (e) =>
                    replaceChoices[e.index] ??
                    _shouldReplaceExistingByContentLength(
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
                    'Importar Ejercicios con IA',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!compactAfterPaste) ...[
                      _ImportAssistantStepCard(
                        title:
                            'Paso 1: Genera ejercicios con el formato de importación',
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
                        title: 'Paso 2: Copia todos los ejercicios generados.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    _ImportAssistantStepCard(
                      title: 'Paso 3: Pega los ejercicios pulsando en "Pegar".',
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
                                      replacedCount = 0;
                                      omittedCount = 0;
                                      processedCount = 0;
                                      errorText = null;
                                      detected =
                                          <PlanFitEjercicioImportDraft>[];
                                      replaceChoices = <int, bool>{};
                                      categoriasNoEncontradas = <String>{};
                                    });

                                    final data = await Clipboard.getData(
                                      Clipboard.kTextPlain,
                                    );
                                    final text = data?.text ?? '';
                                    final parsed =
                                        parsePlanFitEjerciciosFromAI(text);

                                    if (!mounted) return;

                                    final titleMap = _buildTitleToExisting();
                                    final categoriaMap =
                                        _buildCategoriaNameMap();
                                    final newChoices = <int, bool>{};
                                    final missing = <String>{};

                                    for (var i = 0; i < parsed.length; i++) {
                                      final draft = parsed[i];
                                      final existing = _fuzzyFindExisting(
                                        normalizePlanFitEjercicioTitle(
                                          draft.titulo,
                                        ),
                                        titleMap,
                                      );

                                      if (existing != null) {
                                        newChoices[i] =
                                            _shouldReplaceExistingByContentLength(
                                          existing: existing,
                                          draft: draft,
                                        );
                                      }

                                      final categorias =
                                          _resolveCategoriasForDraft(
                                        draft,
                                        categoriaMap,
                                      );
                                      missing
                                          .addAll(categorias.missingCategorias);
                                    }

                                    setDialogState(() {
                                      analyzing = false;
                                      detected = parsed;
                                      replaceChoices = newChoices;
                                      categoriasNoEncontradas = missing;
                                      if (text.trim().isEmpty) {
                                        errorText =
                                            'El portapapeles está vacío.';
                                      } else if (parsed.isEmpty) {
                                        errorText =
                                            'No se detectaron ejercicios con el formato esperado. Campos obligatorios: [Título] y [Instrucciones cortas]. Campos opcionales: [Cómo se hace], [Repeticiones], [Tiempo], [Peso], [Descanso], [Categorías], [Hashtag], [Foto].';
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
                            label: const Text('Pegar Ejercicios'),
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
                            ? 'Paso 4: Se mostrarán aquí los ejercicios detectados para importarlos.'
                            : 'Paso 4: Se han obtenido ${detected.length} ejercicios.',
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
                                  if (categoriasNoEncontradas.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Categorías no encontradas: ${categoriasNoEncontradas.join('; ')}. Crea esas categorías para asociarlas.',
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  SwitchListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Reemplazar existentes',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    subtitle: const Text(
                                      'Si el título coincide, actualiza instrucciones y métricas.',
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
                                              : Colors.orange.shade100,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: proposedReplacements.length,
                                        itemBuilder: (context, idx) {
                                          final entry =
                                              proposedReplacements[idx];
                                          final iaIC = entry
                                              .draft.instruccionesCortas
                                              .trim()
                                              .length;
                                          final iaID = entry.draft.comoSeHace
                                              .trim()
                                              .length;
                                          final actualIC =
                                              (entry.existing.instrucciones ??
                                                      '')
                                                  .trim()
                                                  .length;
                                          final actualID = (entry.existing
                                                      .instruccionesDetalladas ??
                                                  '')
                                              .trim()
                                              .length;
                                          final checked = replaceChoices[
                                                  entry.index] ??
                                              _shouldReplaceExistingByContentLength(
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
                                                ),
                                              ),
                                              subtitle: Text(
                                                'IA IC:$iaIC · ID:$iaID   |   Actual IC:$actualIC · ID:$actualID',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    'Ejercicios detectados (${detected.length}):',
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
                                            'IC:${d.instruccionesCortas.trim().length} · ID:${d.comoSeHace.trim().length} · Categorías: ${d.categorias.isEmpty ? '-' : d.categorias.join('; ')}${d.foto.isNotEmpty ? ' · 📷foto' : ''}',
                                            style:
                                                const TextStyle(fontSize: 11),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton.icon(
                                    onPressed: importing
                                        ? null
                                        : () async {
                                            final titleToExisting =
                                                _buildTitleToExisting();
                                            final categoriaMap =
                                                _buildCategoriaNameMap();
                                            final processedTitles = <String>{};
                                            var hasServerErrors = false;
                                            final missingFound = <String>{};

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
                                                  normalizePlanFitEjercicioTitle(
                                                draft.titulo,
                                              );

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
                                                titleToExisting,
                                              );
                                              final isExisting =
                                                  existingItem != null;
                                              final shouldReplaceCurrent =
                                                  isExisting
                                                      ? (replaceChoices[i] ??
                                                          _shouldReplaceExistingByContentLength(
                                                            existing:
                                                                existingItem!,
                                                            draft: draft,
                                                          ))
                                                      : false;

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

                                              final categoriasResolved =
                                                  _resolveCategoriasForDraft(
                                                draft,
                                                categoriaMap,
                                              );
                                              missingFound.addAll(
                                                categoriasResolved
                                                    .missingCategorias,
                                              );

                                              final payload = PlanFitEjercicio(
                                                codigo: isExisting
                                                    ? existingItem!.codigo
                                                    : 0,
                                                codigoPlanFit: isExisting
                                                    ? existingItem!
                                                        .codigoPlanFit
                                                    : 0,
                                                nombre: draft.titulo.trim(),
                                                instrucciones: draft
                                                    .instruccionesCortas
                                                    .trim(),
                                                instruccionesDetalladas:
                                                    draft.comoSeHace.trim(),
                                                hashtag: draft.hashtag.trim(),
                                                tiempo: draft.tiempo,
                                                descanso: draft.descanso,
                                                repeticiones:
                                                    draft.repeticiones,
                                                kilos: draft.peso,
                                                visiblePremium: isExisting
                                                    ? existingItem!
                                                        .visiblePremium
                                                    : 'N',
                                              );

                                              Uint8List? draftFotoBytes;
                                              if (draft.foto.isNotEmpty) {
                                                try {
                                                  draftFotoBytes =
                                                      base64Decode(draft.foto);
                                                } catch (_) {
                                                  draftFotoBytes = null;
                                                }
                                              }

                                              try {
                                                if (isExisting &&
                                                    replaceExisting) {
                                                  await _apiService
                                                      .updateCatalogEjercicio(
                                                    payload,
                                                    fotoBytes: draftFotoBytes,
                                                    fotoName:
                                                        draftFotoBytes != null
                                                            ? 'base64'
                                                            : null,
                                                    categorias:
                                                        categoriasResolved
                                                                .matchedIds
                                                                .isNotEmpty
                                                            ? categoriasResolved
                                                                .matchedIds
                                                            : null,
                                                  );
                                                  replacedCount += 1;
                                                } else {
                                                  await _apiService
                                                      .createCatalogEjercicio(
                                                    payload,
                                                    fotoBytes: draftFotoBytes,
                                                    fotoName:
                                                        draftFotoBytes != null
                                                            ? 'base64'
                                                            : null,
                                                    categorias:
                                                        categoriasResolved
                                                                .matchedIds
                                                                .isNotEmpty
                                                            ? categoriasResolved
                                                                .matchedIds
                                                            : null,
                                                  );
                                                  importedCount += 1;
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

                                            await _loadData();
                                            if (!mounted) return;
                                            setDialogState(() {
                                              importing = false;
                                              importFinished = true;
                                              categoriasNoEncontradas =
                                                  missingFound;
                                              if (hasServerErrors) {
                                                errorText =
                                                    'Algún ejercicio no se pudo guardar y se ha contabilizado como omitido.';
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
                                    label: const Text('Importar Ejercicios'),
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
                                'Se han importado $importedCount ejercicios nuevos.',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            if (replacedCount > 0)
                              Text(
                                'Se han reemplazado $replacedCount ejercicios existentes.',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            if (omittedCount > 0)
                              Text(
                                'Se han omitido $omittedCount ejercicios.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            if (categoriasNoEncontradas.isNotEmpty)
                              Text(
                                'Categorías no encontradas: ${categoriasNoEncontradas.join('; ')}. Créalas para futuras importaciones.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            if (errorText != null) ...[
                              const SizedBox(height: 6),
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
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: importing
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        if (importFinished) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Importación finalizada. Nuevos: $importedCount · Reemplazados: $replacedCount · Omitidos: $omittedCount',
                              ),
                              backgroundColor:
                                  errorText == null ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                child: Text(importFinished ? 'Cerrar' : 'Cancelar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _applySortSelection(_OrdenCatalogo orden) {
    setState(() {
      if (_ordenCatalogo == orden) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _ordenCatalogo = orden;
        _ordenAscendente =
            orden == _OrdenCatalogo.nombre || orden == _OrdenCatalogo.categoria;
      }
    });
    _saveFilterState();
    _loadData();
  }

  void _loadMore() {
    if (_isNonPremiumPreviewMode) return;
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final start = (_currentPage - 1) * _pageSize;
      if (start >= _items.length) {
        setState(() {
          _loadingMore = false;
          _hasMore = false;
        });
        return;
      }

      final end = math.min(start + _pageSize, _items.length);
      setState(() {
        _displayedItems.addAll(_items.sublist(start, end));
        _currentPage++;
        _hasMore = end < _items.length;
        _loadingMore = false;
      });
    });
  }

  Future<void> _toggleSearchVisibility() async {
    if (_isNonPremiumPreviewMode) {
      await _showPremiumRequiredForEjerciciosTools(context);
      return;
    }

    setState(() {
      _showFilters = !_showFilters;
      if (!_showFilters) {
        _searchController.clear();
      }
    });
    await _saveFilterState();
    await _loadData();
  }

  Future<void> _toggleFilters({required bool isNutricionista}) async {
    if (_isNonPremiumPreviewMode) {
      await _showPremiumRequiredForEjerciciosTools(context);
      return;
    }

    await _showFiltrarEjerciciosDialog(isNutricionista: isNutricionista);
  }

  void _toggleChartView() {
    setState(() {
      _showChartView = !_showChartView;
    });
  }

  Future<List<PlanFitEjercicio>> _sortEjercicios(
    List<PlanFitEjercicio> ejercicios,
  ) async {
    final sorted = List<PlanFitEjercicio>.from(ejercicios);
    final compareNombre = (PlanFitEjercicio a, PlanFitEjercicio b) =>
        a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());

    switch (_ordenCatalogo) {
      case _OrdenCatalogo.usos:
        sorted.sort((a, b) {
          final byUsos = _ordenAscendente
              ? a.totalUsos.compareTo(b.totalUsos)
              : b.totalUsos.compareTo(a.totalUsos);
          if (byUsos != 0) return byUsos;
          return compareNombre(a, b);
        });
        return sorted;
      case _OrdenCatalogo.nombre:
        sorted.sort((a, b) =>
            _ordenAscendente ? compareNombre(a, b) : compareNombre(b, a));
        return sorted;
      case _OrdenCatalogo.fechaAlta:
        sorted.sort((a, b) {
          final byCodigo = _ordenAscendente
              ? a.codigo.compareTo(b.codigo)
              : b.codigo.compareTo(a.codigo);
          if (byCodigo != 0) return byCodigo;
          return compareNombre(a, b);
        });
        return sorted;
      case _OrdenCatalogo.categoria:
        final categoriaPorEjercicio = <int, String>{};
        await Future.wait(sorted.map((ejercicio) async {
          try {
            final categorias = await _apiService.getEjercicioCategorias(
              ejercicio.codigo,
            );
            final nombreCategoria = categorias
                .map((c) => c.nombre.trim())
                .where((n) => n.isNotEmpty)
                .toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            categoriaPorEjercicio[ejercicio.codigo] =
                nombreCategoria.isNotEmpty ? nombreCategoria.first : '';
          } catch (_) {
            categoriaPorEjercicio[ejercicio.codigo] = '';
          }
        }));
        sorted.sort((a, b) {
          final categoriaA = categoriaPorEjercicio[a.codigo] ?? '';
          final categoriaB = categoriaPorEjercicio[b.codigo] ?? '';
          final byCategoria = _ordenAscendente
              ? categoriaA.toLowerCase().compareTo(categoriaB.toLowerCase())
              : categoriaB.toLowerCase().compareTo(categoriaA.toLowerCase());
          if (byCategoria != 0) return byCategoria;
          return _ordenAscendente ? compareNombre(a, b) : compareNombre(b, a);
        });
        return sorted;
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final authService = context.read<AuthService>();
      final userType = (authService.userType ?? '').toLowerCase().trim();
      final isNutricionista =
          userType == 'nutricionista' || userType == 'administrador';
      final isPremium = authService.isPremium;
      final isPreviewMode = _isNonPremiumPreviewMode;
      List<PlanFitCategoria> categorias = <PlanFitCategoria>[];
      var counts = <int, int>{};

      if (isNutricionista) {
        categorias = await _apiService.getCategorias();
        final countEntries = await Future.wait(
          categorias.map((categoria) async {
            try {
              final list = await _apiService.getCatalogByCategoria(
                categoria.codigo,
                premiumVisibleOnly: widget.premiumVisibleOnly,
              );
              return MapEntry(categoria.codigo, list.length);
            } catch (_) {
              return MapEntry(categoria.codigo, 0);
            }
          }),
        );
        counts = <int, int>{
          for (final entry in countEntries) entry.key: entry.value,
        };
      } else if (isPremium) {
        // Premium users may have planes_fit access when they have a patient
        // associated. Try loading categories and silently ignore if denied.
        try {
          categorias = await _apiService.getCategorias();
        } catch (_) {
          categorias = [];
        }
      }

      List<PlanFitEjercicio> ejercicios;
      final previewCodesFuture = isPreviewMode
          ? _apiService
              .getParametroValor(_paramNonPremiumPreviewCodes)
              .then(_parsePreviewCodes)
              .catchError((_) => null)
          : Future<List<int>?>.value(null);
      final search = _searchController.text.trim();
      final backendSearch =
          _searchField == _CatalogSearchField.title ? search : '';
      // widget.premiumVisibleOnly overrides the filter (guest/public view)
      final premiumOnly = widget.premiumVisibleOnly || _filtroPremium == true;
      final filterNonPremium =
          !widget.premiumVisibleOnly && _filtroPremium == false;
      final effectiveSelectedCategoriaIds =
          (isNutricionista || isPremium) ? _selectedCategoriaIds : <int>{};

      if (effectiveSelectedCategoriaIds.isNotEmpty) {
        final results = await Future.wait(
          effectiveSelectedCategoriaIds.map(
            (id) => _apiService.getCatalogByCategoria(
              id,
              search: backendSearch,
              premiumVisibleOnly: premiumOnly,
            ),
          ),
        );
        final merged = <int, PlanFitEjercicio>{};
        for (final list in results) {
          for (final ejercicio in list) {
            merged[ejercicio.codigo] = ejercicio;
          }
        }
        ejercicios = merged.values.toList();
      } else {
        ejercicios = await _apiService.getPlanFitEjerciciosCatalog(
          search: backendSearch,
          premiumVisibleOnly: premiumOnly,
        );
      }
      // Apply local non-premium filter (API doesn't have a dedicated param for that)
      if (filterNonPremium) {
        ejercicios = ejercicios
            .where((e) => (e.visiblePremium ?? 'N').toUpperCase() != 'S')
            .toList();
      }

      // Apply local search for all relevant fields regardless of backend filtering
      if (search.isNotEmpty) {
        final query = search.toLowerCase();
        ejercicios = ejercicios
            .where((ejercicio) => _matchesSearch(ejercicio, query))
            .toList();
      }

      final sortedEjercicios = await _sortEjercicios(ejercicios);
      final previewCodes = await previewCodesFuture;
      setState(() {
        _categorias = categorias;
        _ejerciciosPorCategoria = counts;
        if (!isNutricionista && !isPremium) {
          _selectedCategoriaIds = <int>{};
        }
        _nonPremiumPreviewCodes = previewCodes;
        _items = sortedEjercicios;
        _displayedItems = isPreviewMode
            ? _buildPreviewEjercicios(sortedEjercicios, previewCodes)
            : <PlanFitEjercicio>[];
        _currentPage = 1;
        _hasMore = isPreviewMode ? false : sortedEjercicios.isNotEmpty;
        _loadingMore = false;
        _loading = false;
      });
      if (!isPreviewMode) {
        _loadMore();
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar catálogo. $errorMessage'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _matchesSearch(PlanFitEjercicio ejercicio, String query) {
    if (query.trim().isEmpty) {
      return true;
    }

    return _buildSearchText(ejercicio, _searchField).contains(query);
  }

  String _buildSearchText(
    PlanFitEjercicio ejercicio,
    _CatalogSearchField field,
  ) {
    switch (field) {
      case _CatalogSearchField.all:
        return [
          ejercicio.nombre,
          ejercicio.instrucciones ?? '',
          ejercicio.instruccionesDetalladas ?? '',
          ejercicio.hashtag ?? '',
        ].join(' ').toLowerCase();
      case _CatalogSearchField.title:
        return ejercicio.nombre.toLowerCase();
      case _CatalogSearchField.instructions:
        return [
          ejercicio.instrucciones ?? '',
          ejercicio.instruccionesDetalladas ?? '',
        ].join(' ').toLowerCase();
      case _CatalogSearchField.hashtags:
        return (ejercicio.hashtag ?? '').toLowerCase();
    }
  }

  List<String> _extractHashtags(String rawText) {
    if (rawText.trim().isEmpty) return const <String>[];
    final tokens = rawText
        .split(RegExp(r'[\s,;\n\r]+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .map((token) {
          final clean = token.replaceAll(RegExp(r'^[#]+'), '');
          return clean.isEmpty ? '' : '#$clean';
        })
        .where((token) => token.isNotEmpty)
        .toSet();
    return tokens.toList(growable: false);
  }

  Future<void> _applyHashtagSearch(String hashtag) async {
    final normalized = hashtag.trim();
    if (normalized.isEmpty) return;
    _searchController.text = normalized;
    setState(() {
      _showFilters = true;
      _searchField = _CatalogSearchField.hashtags;
    });
    await _saveFilterState();
    await _loadData();
  }

  // ─── Chart helpers ──────────────────────────────────────────────────────────

  static const List<Color> _chartPalette = [
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFFE53935),
    Color(0xFF00897B),
    Color(0xFF6D4C41),
    Color(0xFF3949AB),
    Color(0xFFFDD835),
    Color(0xFF00ACC1),
  ];

  Color _pieColorByIndex(int index) =>
      _chartPalette[index % _chartPalette.length];

  List<PlanFitEjercicio> _topUsedEjercicios({int limit = 10}) {
    final list = _items.where((e) => e.totalUsos > 0).toList()
      ..sort((a, b) {
        final cmp = b.totalUsos.compareTo(a.totalUsos);
        return cmp != 0
            ? cmp
            : a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
    return list.length <= limit ? list : list.sublist(0, limit);
  }

  String _truncateName(String name, {int maxChars = 65}) {
    final clean = name.trim();
    return clean.length <= maxChars
        ? clean
        : '${clean.substring(0, maxChars).trimRight()}...';
  }

  String _truncateNameShort(String name, {int maxChars = 30}) {
    final clean = name.trim();
    return clean.length <= maxChars
        ? clean
        : '${clean.substring(0, maxChars).trimRight()}...';
  }

  Widget _metricTag(
      {required String text, required Color color, bool emphasized = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(emphasized ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
          color: color.computeLuminance() > 0.55 ? Colors.black87 : color,
        ),
      ),
    );
  }

  Color _usageBadgeColor(int value, int maxValue) {
    if (value <= 0) return Colors.grey.shade500;
    if (maxValue <= 1) return Colors.blue.shade200;
    final ratio = (value / maxValue).clamp(0.0, 1.0);
    if (ratio <= 0.15) return Colors.blue.shade100;
    if (ratio <= 0.30) return Colors.blue.shade200;
    if (ratio <= 0.45) return Colors.blue.shade300;
    if (ratio <= 0.60) return Colors.blue.shade500;
    if (ratio <= 0.75) return Colors.blue.shade600;
    if (ratio <= 0.90) return Colors.blue.shade700;
    return Colors.blue.shade900;
  }

  Color _usageBadgeTextColor(Color c) =>
      c.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;

  Widget _buildTopUsedEjerciciosChart() {
    final top = _topUsedEjercicios();
    if (top.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child:
              Text('No hay suficientes datos de uso para mostrar el gráfico.'),
        ),
      );
    }

    final total = top.fold<int>(0, (sum, e) => sum + e.totalUsos);
    final sections = top.asMap().entries.map((entry) {
      final i = entry.key;
      final ej = entry.value;
      final pct = total == 0 ? 0 : ((ej.totalUsos / total) * 100).round();
      return PieChartSectionData(
        color: _pieColorByIndex(i),
        value: ej.totalUsos.toDouble(),
        radius: 58,
        title: i < 5 ? '$pct%' : '',
        titleStyle: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      );
    }).toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 10 ejercicios más utilizados en planes fit',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'El gráfico respeta los filtros actuales del catálogo. Pulsa los usos de cada ejercicio para ver los planes.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final stacked = availableWidth < 760;
              final chartWidth = stacked
                  ? availableWidth
                  : (availableWidth * 0.40).clamp(220.0, 400.0);
              final chartHeight =
                  stacked ? (availableWidth * 0.65).clamp(200.0, 340.0) : 300.0;

              final chart = SizedBox(
                height: chartHeight,
                width: chartWidth,
                child: PieChart(PieChartData(
                  sections: sections,
                  sectionsSpace: 1.2,
                  centerSpaceRadius: 32,
                )),
              );

              final legend = Wrap(
                runSpacing: 8,
                children: top.asMap().entries.map((entry) {
                  final i = entry.key;
                  final ej = entry.value;
                  final color = _pieColorByIndex(i);
                  final pct =
                      total == 0 ? 0 : ((ej.totalUsos / total) * 100).round();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Text('${i + 1}. ${_truncateName(ej.nombre)}',
                                  style: const TextStyle(fontSize: 12)),
                              Tooltip(
                                message: 'Ver planes que usan este ejercicio',
                                child: InkWell(
                                  onTap: () => _showPlanesForEjercicio(ej),
                                  borderRadius: BorderRadius.circular(999),
                                  child: _metricTag(
                                      text: '${ej.totalUsos} usos',
                                      color: color),
                                ),
                              ),
                              _metricTag(
                                  text: '$pct%',
                                  color: color,
                                  emphasized: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );

              if (stacked) {
                return Column(
                    children: [chart, const SizedBox(height: 12), legend]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  chart,
                  const SizedBox(width: 16),
                  Expanded(child: legend)
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlanesForEjercicio(PlanFitEjercicio ejercicio) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Planes que usan ${_truncateNameShort(ejercicio.nombre)}',
                style: const TextStyle(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close, size: 18),
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: FutureBuilder<List<PlanFit>>(
            future: _apiService.getPlanesForEjercicio(ejercicio.codigo),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Text(
                  'No se pudieron cargar los planes. ${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                  style: const TextStyle(color: Colors.red),
                );
              }
              final plans = snapshot.data ?? const <PlanFit>[];
              if (plans.isEmpty) {
                return const Text(
                    'Este ejercicio no aparece en ningún plan fit en este momento.');
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    final patientName = (plan.nombrePaciente ?? '').trim();
                    final isCompleted =
                        (plan.completado ?? '').toUpperCase() == 'S';
                    final desde = plan.desde != null
                        ? '${plan.desde!.day.toString().padLeft(2, '0')}/${plan.desde!.month.toString().padLeft(2, '0')}/${plan.desde!.year}'
                        : '';
                    final headerText = (plan.semanas ?? '').isNotEmpty
                        ? plan.semanas!
                        : (desde.isNotEmpty ? desde : 'Plan #${plan.codigo}');
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(headerText,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Row(children: [
                        Expanded(
                          child: Text(
                            patientName.isNotEmpty
                                ? patientName
                                : 'Sin paciente',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Tooltip(
                          message: isCompleted ? 'Completado' : 'No completado',
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.red.shade50
                                  : Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isCompleted
                                    ? Colors.red.shade300
                                    : Colors.blueGrey.shade300,
                              ),
                            ),
                            child: Text(
                              isCompleted ? 'C' : 'NC',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isCompleted
                                    ? Colors.red.shade700
                                    : Colors.blueGrey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ]),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () async {
                        Navigator.of(dialogContext).pop();
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlanFitEditScreen(plan: plan),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Filter panel ────────────────────────────────────────────────────────────

  Widget _buildFiltersPanel() {
    if (!_showFilters) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.exerciseCatalogSearchFieldLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              (_CatalogSearchField.all, l10n.exerciseCatalogSearchFieldAll),
              (
                _CatalogSearchField.title,
                l10n.exerciseCatalogSearchFieldTitle,
              ),
              (
                _CatalogSearchField.instructions,
                l10n.exerciseCatalogSearchFieldInstructions,
              ),
              (
                _CatalogSearchField.hashtags,
                l10n.exerciseCatalogSearchFieldHashtags,
              ),
            ].map((entry) {
              final field = entry.$1;
              final label = entry.$2;
              return ChoiceChip(
                label: Text(label),
                selected: _searchField == field,
                onSelected: (selected) {
                  if (!selected) return;
                  setState(() {
                    _searchField = field;
                  });
                  _saveFilterState();
                  _loadData();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Search
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: l10n.exerciseCatalogSearchLabel,
              hintText: l10n.exerciseCatalogSearchHint,
              border: const OutlineInputBorder(),
              isDense: true,
              prefixIcon: IconButton(
                tooltip: l10n.exerciseCatalogClearSearch,
                icon: Icon(
                  _searchController.text.trim().isEmpty
                      ? Icons.search
                      : Icons.clear,
                ),
                onPressed: _searchController.text.trim().isEmpty
                    ? null
                    : () {
                        _searchController.clear();
                        setState(() {});
                        _loadData();
                      },
              ),
              suffixIcon: IconButton(
                tooltip: l10n.exerciseCatalogHideSearch,
                icon: const Icon(Icons.visibility_off_outlined),
                onPressed: () async {
                  await _toggleSearchVisibility();
                },
              ),
            ),
            onChanged: (_) {
              setState(() {});
              _saveFilterState();
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showFiltrarEjerciciosDialog({
    required bool isNutricionista,
  }) async {
    if (_categorias.isEmpty) {
      await _loadData();
    }

    final tempCategorias = Set<int>.from(_selectedCategoriaIds);
    bool? tempPremium = _filtroPremium;
    String searchQuery = '';
    const showSearchKey = 'plan_fit_catalog_filter_show_search';
    final prefs = await SharedPreferences.getInstance();
    bool showSearch = prefs.getBool(showSearchKey) ?? false;

    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final filtered = _categorias.where((categoria) {
            if (searchQuery.trim().isEmpty) return true;
            final name = categoria.nombre.toLowerCase();
            return name.contains(searchQuery.trim().toLowerCase());
          }).toList();

          return AlertDialog(
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filtrar ejercicios',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(showSearch ? Icons.search_off : Icons.search),
                  tooltip: showSearch ? 'Ocultar buscar' : 'Mostrar buscar',
                  onPressed: () async {
                    showSearch = !showSearch;
                    await prefs.setBool(showSearchKey, showSearch);
                    setDialog(() {});
                  },
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor:
                        showSearch ? Colors.blue.shade50 : Colors.grey.shade200,
                    foregroundColor:
                        showSearch ? Colors.blue.shade700 : Colors.black87,
                    padding: const EdgeInsets.all(8),
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
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isNutricionista) ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Premium'),
                          selected: tempPremium == true,
                          onSelected: (selected) {
                            setDialog(() {
                              tempPremium = selected ? true : null;
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('No Premium'),
                          selected: tempPremium == false,
                          onSelected: (selected) {
                            setDialog(() {
                              tempPremium = selected ? false : null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (showSearch) ...[
                    TextField(
                      onChanged: (value) {
                        setDialog(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar categoría...',
                        prefixIcon: IconButton(
                          tooltip: searchQuery.isNotEmpty
                              ? 'Limpiar búsqueda'
                              : 'Buscar',
                          onPressed: searchQuery.isNotEmpty
                              ? () {
                                  setDialog(() {
                                    searchQuery = '';
                                  });
                                }
                              : null,
                          icon: Icon(
                            searchQuery.isNotEmpty ? Icons.clear : Icons.search,
                            size: 20,
                          ),
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Ocultar búsqueda',
                          onPressed: () async {
                            showSearch = false;
                            await prefs.setBool(showSearchKey, showSearch);
                            setDialog(() {});
                          },
                          icon: const Icon(Icons.visibility_off_outlined,
                              size: 20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: filtered
                            .map(
                              (categoria) => CheckboxListTile(
                                dense: true,
                                value:
                                    tempCategorias.contains(categoria.codigo),
                                title: Text(categoria.nombre),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (checked) {
                                  setDialog(() {
                                    if (checked == true) {
                                      tempCategorias.add(categoria.codigo);
                                    } else {
                                      tempCategorias.remove(categoria.codigo);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialog(() {
                    tempCategorias.clear();
                    tempPremium = null;
                  });
                },
                child: const Text('Limpiar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Aplicar'),
                    const SizedBox(width: 6),
                    if (tempCategorias.isNotEmpty)
                      Container(
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${tempCategorias.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
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
      ),
    );

    if (applied != true) return;

    setState(() {
      _selectedCategoriaIds = tempCategorias;
      _filtroPremium = tempPremium;
    });
    await _saveFilterState();
    await _loadData();
  }

  String _buildCategoriasFiltroTexto() {
    if (_selectedCategoriaIds.isEmpty) {
      return 'Todos';
    }
    final nombres = _categorias
        .where((cat) => _selectedCategoriaIds.contains(cat.codigo))
        .map((cat) => cat.nombre.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (nombres.isEmpty) {
      return 'Todos';
    }
    return nombres.join(', ');
  }

  Future<void> _generateCatalogPdf() async {
    try {
      if (_items.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay ejercicios para exportar.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final nutricionistaParam = await _apiService.getParametro(
        'nutricionista_nombre',
      );
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      final logoParam = await _apiService.getParametro(
        'logotipo_dietista_documentos',
      );
      final logoBase64 = logoParam?['valor']?.toString() ?? '';
      final logoSizeStr = logoParam?['valor2']?.toString() ?? '';
      Uint8List? logoBytes;
      if (logoBase64.isNotEmpty) {
        logoBytes = _decodeBase64Image(logoBase64);
      }

      final accentColorParam = await _apiService.getParametro(
        'color_fondo_banda_encabezado_pie_pdf',
      );
      final accentColorStr = accentColorParam?['valor']?.toString() ?? '';

      final filtroTexto = _buildCategoriasFiltroTexto();
      final tituloPdf = 'Catálogo de ejercicios ($filtroTexto)';

      if (!mounted) return;

      await EjerciciosCatalogPdfService.generateCatalogPdf(
        context: context,
        nutricionistaNombre: nutricionistaNombre,
        nutricionistaSubtitulo: nutricionistaSubtitulo,
        logoBytes: logoBytes,
        logoSizeStr: logoSizeStr,
        accentColorStr: accentColorStr,
        ejercicios: _items,
        tituloTexto: tituloPdf,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int _parseInt(String value, [int fallback = 0]) {
    return int.tryParse(value) ?? fallback;
  }

  static Uint8List? _decodeBase64Image(String base64String) {
    final raw = base64String.trim();
    if (raw.isEmpty) {
      return null;
    }
    var data = raw;
    const marker = 'base64,';
    final index = raw.indexOf(marker);
    if (index >= 0) {
      data = raw.substring(index + marker.length);
    }
    while (data.length % 4 != 0) {
      data += '=';
    }
    try {
      return Uint8List.fromList(base64Decode(data));
    } catch (_) {
      return null;
    }
  }

  Future<void> _showImagePreviewBytes(Uint8List bytes) async {
    showImageViewerDialog(
      context: context,
      base64Image: base64Encode(bytes),
      title: 'Vista previa',
    );
  }

  Future<void> _showImagePreviewBase64(String base64Image) async {
    showImageViewerDialog(
      context: context,
      base64Image: base64Image,
      title: 'Vista previa',
    );
  }

  Future<void> _showEjercicioImage(PlanFitEjercicio ejercicio) async {
    // Si ya tiene fotoBase64, mostrarla directamente
    if ((ejercicio.fotoBase64 ?? '').isNotEmpty) {
      await _showImagePreviewBase64(ejercicio.fotoBase64!);
      return;
    }

    // Si tiene miniatura pero no foto completa, cargarla del servidor
    if ((ejercicio.fotoMiniatura ?? '').isNotEmpty) {
      try {
        final ejercicioConFoto = await _apiService
            .getPlanFitEjercicioCatalogWithFoto(ejercicio.codigo);
        if (ejercicioConFoto != null &&
            (ejercicioConFoto.fotoBase64 ?? '').isNotEmpty) {
          await _showImagePreviewBase64(ejercicioConFoto.fotoBase64!);
        } else {
          // Si no se pudo cargar la foto completa, mostrar la miniatura
          await _showImagePreviewBase64(ejercicio.fotoMiniatura!);
        }
      } catch (e) {
        // En caso de error, mostrar la miniatura
        if ((ejercicio.fotoMiniatura ?? '').isNotEmpty) {
          await _showImagePreviewBase64(ejercicio.fotoMiniatura!);
        }
      }
    }
  }

  String _extractFotoBase64Candidate(String clipboardText) {
    final raw = clipboardText.trim();
    if (raw.isEmpty) {
      return '';
    }

    final match = RegExp(
      r'\[\s*foto\s*\]\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(raw);

    if (match != null) {
      final candidate = (match.group(1) ?? '').trim();
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }

    return raw;
  }

  Future<Uint8List?> _readClipboardImageByFormat(
    ClipboardReader reader,
    FileFormat format,
  ) async {
    final completer = Completer<Uint8List?>();
    final progress = reader.getFile(
      format,
      (file) async {
        try {
          final bytes = await file.readAll();
          if (!completer.isCompleted) {
            completer.complete(bytes);
          }
        } catch (_) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      },
      onError: (_) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    if (progress == null) {
      return null;
    }

    return completer.future;
  }

  Future<Uint8List?> _readImageBytesFromSystemClipboard() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return null;
    }

    try {
      final reader = await clipboard.read();
      final formatsToTry = <FileFormat>[
        Formats.png,
        Formats.jpeg,
        Formats.webp,
        Formats.gif,
        Formats.bmp,
        Formats.tiff,
      ];

      for (final format in formatsToTry) {
        final bytes = await _readClipboardImageByFormat(reader, format);
        if (bytes != null && bytes.isNotEmpty) {
          return bytes;
        }
      }
    } catch (_) {}

    return null;
  }

  bool _canUseSystemClipboardImagePaste() {
    if (kIsWeb) {
      return false;
    }
    try {
      return SystemClipboard.instance != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showPasteImageDialog(PlanFitEjercicio ejercicio) async {
    final bytes = await showPasteImageDialog(
      context,
      title: 'Pegar imagen',
      description:
          'Genera la imagen en formato base64 o copiala directamente al portapapeles y pulsa en pegar para agregarla al ejercicio.',
    );
    if (bytes == null) return;

    final actualizado = PlanFitEjercicio(
      codigo: ejercicio.codigo,
      codigoPlanFit: ejercicio.codigoPlanFit,
      codigoDia: ejercicio.codigoDia,
      codigoEjercicioCatalogo: ejercicio.codigoEjercicioCatalogo,
      nombre: ejercicio.nombre,
      instrucciones: ejercicio.instrucciones,
      instruccionesDetalladas: ejercicio.instruccionesDetalladas,
      hashtag: ejercicio.hashtag,
      urlVideo: ejercicio.urlVideo,
      fotoBase64: ejercicio.fotoBase64,
      fotoNombre: ejercicio.fotoNombre,
      fotoMiniatura: ejercicio.fotoMiniatura,
      tiempo: ejercicio.tiempo,
      descanso: ejercicio.descanso,
      repeticiones: ejercicio.repeticiones,
      kilos: ejercicio.kilos,
      orden: ejercicio.orden,
      visiblePremium: ejercicio.visiblePremium,
      totalUsos: ejercicio.totalUsos,
    );

    try {
      await _apiService.updateCatalogEjercicio(
        actualizado,
        fotoBytes: bytes,
        fotoName: 'base64',
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imagen aplicada al ejercicio.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo aplicar la imagen: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _launchUrlExternal(String url) async {
    final rawUrl = url.trim();
    if (rawUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El ejercicio no tiene URL de vídeo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    var normalizedUrl = rawUrl;
    if (normalizedUrl.startsWith('//')) {
      normalizedUrl = 'https:$normalizedUrl';
    }
    final parsed = Uri.tryParse(normalizedUrl);
    if (parsed == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La URL del vídeo no es válida.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (!parsed.hasScheme) {
      normalizedUrl = 'https://$normalizedUrl';
    }

    try {
      await launchUrlString(
        normalizedUrl,
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        await _externalUrlChannel
            .invokeMethod('openUrl', {'url': normalizedUrl});
        return;
      }
      rethrow;
    } catch (e) {
      if (mounted) {
        final message = e.toString().split('\n').first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir la URL: $message'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _openCategoriaForm({PlanFitCategoria? categoria}) async {
    final isEditing = categoria != null;
    final nombreController = TextEditingController(
      text: categoria?.nombre ?? '',
    );
    final descripcionController = TextEditingController(
      text: categoria?.descripcion ?? '',
    );
    final ordenController = TextEditingController(
      text: (categoria?.orden ?? 0).toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar categoria' : 'Nueva categoria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripcion',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ordenController,
              decoration: const InputDecoration(
                labelText: 'Orden',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nombre = nombreController.text.trim();
              if (nombre.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El nombre no puede estar vacío.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              try {
                if (isEditing) {
                  await _apiService.updateCategoria(
                    categoria.codigo,
                    nombre,
                    descripcion: descripcionController.text.trim().isNotEmpty
                        ? descripcionController.text.trim()
                        : null,
                    orden: _parseInt(ordenController.text, 0),
                  );
                } else {
                  await _apiService.createCategoria(
                    nombre,
                    descripcion: descripcionController.text.trim().isNotEmpty
                        ? descripcionController.text.trim()
                        : null,
                    orden: _parseInt(ordenController.text, 0),
                  );
                }
                Navigator.pop(context, true);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al guardar: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openCategoriasDialog() async {
    bool showSearch = false;
    String search = '';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final screenHeight = MediaQuery.of(context).size.height;
            final dialogHeight = (screenHeight * 0.75).clamp(460.0, 720.0);
            final filteredCategorias = _categorias.where((categoria) {
              if (search.isEmpty) return true;
              final q = search.toLowerCase();
              return categoria.nombre.toLowerCase().contains(q) ||
                  (categoria.descripcion ?? '').toLowerCase().contains(q);
            }).toList();

            return AlertDialog(
              content: SizedBox(
                width: 440,
                height: dialogHeight,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Categorías',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Nueva categoría',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            final saved = await _openCategoriaForm();
                            if (saved) {
                              await _loadData();
                              setStateDialog(() {});
                            }
                          },
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          tooltip: showSearch ? 'Ocultar búsqueda' : 'Buscar',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setStateDialog(() {
                              showSearch = !showSearch;
                              if (!showSearch) {
                                search = '';
                              }
                            });
                          },
                          icon: Icon(
                            showSearch ? Icons.search_off : Icons.search,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          style: IconButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(32, 32),
                          ),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (showSearch)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Buscar categoría',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setStateDialog(() {
                              search = value.trim();
                            });
                          },
                        ),
                      ),
                    if (filteredCategorias.isEmpty)
                      const Expanded(
                        child: Center(child: Text('No hay categorías.')),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: filteredCategorias.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final categoria = filteredCategorias[index];
                            final itemCount =
                                _ejerciciosPorCategoria[categoria.codigo] ?? 0;
                            return Dismissible(
                              key: ValueKey(
                                'cat_${categoria.codigo}_${categoria.nombre}_$index',
                              ),
                              direction: DismissDirection.startToEnd,
                              dismissThresholds: {
                                DismissDirection.startToEnd: context
                                    .watch<ConfigService>()
                                    .deleteSwipeDismissThreshold,
                              },
                              background: Container(
                                color: Colors.red.shade600,
                                alignment: Alignment.centerLeft,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Eliminar',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              confirmDismiss: (_) async {
                                await _deleteCategoria(categoria);
                                await _loadData();
                                setStateDialog(() {});
                                return false;
                              },
                              child: SizedBox(
                                height: 42,
                                child: InkWell(
                                  onTap: () async {
                                    final saved = await _openCategoriaForm(
                                      categoria: categoria,
                                    );
                                    if (saved) {
                                      await _loadData();
                                      setStateDialog(() {});
                                    }
                                  },
                                  onLongPress: () async {
                                    await _openCategoriaMenu(categoria);
                                    await _loadData();
                                    setStateDialog(() {});
                                  },
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            categoria.nombre,
                                            style:
                                                const TextStyle(fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 18,
                                        height: 18,
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: itemCount > 0
                                              ? Colors.green
                                              : Colors.grey.shade500,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          itemCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.more_vert,
                                          size: 20,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        tooltip: 'Más opciones',
                                        onPressed: () async {
                                          await _openCategoriaMenu(categoria);
                                          await _loadData();
                                          setStateDialog(() {});
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openEjercicioDialog({PlanFitEjercicio? ejercicio}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PlanFitEjercicioCatalogEditScreen(
          ejercicio: ejercicio,
          categorias: _categorias,
        ),
      ),
    );

    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _deleteEjercicio(PlanFitEjercicio ejercicio) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar ejercicio'),
        content: Text('¿Eliminar ${ejercicio.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteCatalogEjercicio(ejercicio.codigo);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ejercicio eliminado.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final message = e.toString().replaceFirst('Exception: ', '');
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('No se pudo eliminar'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCategoria(PlanFitCategoria categoria) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar ${categoria.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteCategoria(categoria.codigo);
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _openCategoriaMenu(PlanFitCategoria categoria) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'edit') {
      final saved = await _openCategoriaForm(categoria: categoria);
      if (saved) {
        await _loadData();
      }
    } else if (action == 'delete') {
      await _deleteCategoria(categoria);
    }
  }

  Future<void> _openEjercicioMenu(PlanFitEjercicio ejercicio) async {
    final hasUrl = (ejercicio.urlVideo ?? '').trim().isNotEmpty;
    final isPremium = (ejercicio.visiblePremium ?? 'N').toUpperCase() == 'S';
    final isNutricionista =
        context.read<AuthService>().userType == 'Nutricionista';
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasUrl)
              ListTile(
                leading: const Icon(Icons.open_in_browser),
                title: const Text('Abrir URL'),
                onTap: () => Navigator.pop(context, 'url'),
              ),
            if (isNutricionista)
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Visualizar (vista Premium)'),
                onTap: () => Navigator.pop(context, 'preview_premium'),
              ),
            if (isNutricionista)
              ListTile(
                leading: const Icon(Icons.content_paste_rounded),
                title: const Text('Pegar imagen'),
                onTap: () => Navigator.pop(context, 'paste_image'),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: Icon(
                isPremium ? Icons.workspace_premium_outlined : Icons.block,
              ),
              title: Text(isPremium ? 'No Premium' : 'Premium'),
              onTap: () => Navigator.pop(context, 'premium_toggle'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'url' && hasUrl) {
      await _launchUrlExternal(ejercicio.urlVideo ?? '');
    } else if (action == 'preview_premium' && isNutricionista) {
      await _showPremiumEjercicioDetalle(ejercicio);
    } else if (action == 'paste_image' && isNutricionista) {
      await _showPasteImageDialog(ejercicio);
    } else if (action == 'edit') {
      await _openEjercicioDialog(ejercicio: ejercicio);
    } else if (action == 'premium_toggle') {
      final nuevoPremium = isPremium ? 'N' : 'S';
      final actualizado = PlanFitEjercicio(
        codigo: ejercicio.codigo,
        codigoPlanFit: ejercicio.codigoPlanFit,
        codigoDia: ejercicio.codigoDia,
        codigoEjercicioCatalogo: ejercicio.codigoEjercicioCatalogo,
        nombre: ejercicio.nombre,
        instrucciones: ejercicio.instrucciones,
        instruccionesDetalladas: ejercicio.instruccionesDetalladas,
        hashtag: ejercicio.hashtag,
        urlVideo: ejercicio.urlVideo,
        fotoBase64: ejercicio.fotoBase64,
        fotoNombre: ejercicio.fotoNombre,
        fotoMiniatura: ejercicio.fotoMiniatura,
        tiempo: ejercicio.tiempo,
        descanso: ejercicio.descanso,
        repeticiones: ejercicio.repeticiones,
        kilos: ejercicio.kilos,
        orden: ejercicio.orden,
        visiblePremium: nuevoPremium,
        totalUsos: ejercicio.totalUsos,
      );

      try {
        await _apiService.updateCatalogEjercicio(actualizado);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                nuevoPremium == 'S'
                    ? 'Ejercicio marcado como Premium.'
                    : 'Ejercicio marcado como No Premium.',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final message = e.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo actualizar Premium: $message'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else if (action == 'delete') {
      await _deleteEjercicio(ejercicio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final platform = Theme.of(context).platform;
    final isMobilePlatform =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    final isNutricionista =
        context.read<AuthService>().userType == 'Nutricionista';
    final isPremiumCatalogUser = !isNutricionista;
    final isPreviewMode = _isNonPremiumPreviewMode;
    final count = _items.length;
    final maxUsos =
        _items.fold<int>(0, (m, e) => e.totalUsos > m ? e.totalUsos : m);

    // Count badge in title
    final badgeWidget = Tooltip(
      message: _showChartView ? 'Volver al listado' : 'Ver gráfico de uso',
      child: InkWell(
        onTap: _toggleChartView,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration:
              const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );

    final premiumBadgeWidget = Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ejercicios'),
            if (isNutricionista) ...[const SizedBox(width: 8), badgeWidget],
            if (isPremiumCatalogUser) ...[
              const SizedBox(width: 8),
              premiumBadgeWidget,
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Volver',
        ),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.search_off : Icons.search),
            tooltip: _showFilters ? 'Ocultar buscar' : 'Buscar',
            onPressed: isPreviewMode
                ? () => _showPremiumRequiredForEjerciciosTools(context)
                : _toggleSearchVisibility,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_alt),
                tooltip: 'Filtrar ejercicios',
                onPressed: () => isPreviewMode
                    ? _showPremiumRequiredForEjerciciosTools(context)
                    : _toggleFilters(isNutricionista: isNutricionista),
              ),
              if (_selectedCategoriaIds.isNotEmpty)
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
                      '${_selectedCategoriaIds.length}',
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
          if (isNutricionista)
            PopupMenuButton<String>(
              tooltip: 'Opciones',
              onSelected: (value) {
                switch (value) {
                  case 'buscar':
                    _toggleSearchVisibility();
                    break;
                  case 'categorias':
                    _openCategoriasDialog();
                    break;
                  case 'filtros':
                    _toggleFilters(isNutricionista: true);
                    break;
                  case 'pdf':
                    _generateCatalogPdf();
                    break;
                  case 'chart':
                    _toggleChartView();
                    break;
                  case 'refresh':
                    _loadData();
                    break;
                  case 'copiar_ia':
                    _showAIPromptDialog();
                    break;
                  case 'pegar_ia':
                    _showImportAssistant();
                    break;
                  case 'sort_usos':
                    _applySortSelection(_OrdenCatalogo.usos);
                    break;
                  case 'sort_nombre':
                    _applySortSelection(_OrdenCatalogo.nombre);
                    break;
                  case 'sort_fecha':
                    _applySortSelection(_OrdenCatalogo.fechaAlta);
                    break;
                  case 'sort_categoria':
                    _applySortSelection(_OrdenCatalogo.categoria);
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'buscar',
                  child: ListTile(
                    leading: Icon(
                      _showFilters ? Icons.search_off : Icons.search,
                    ),
                    title: Text(_showFilters ? 'Ocultar buscar' : 'Buscar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'filtros',
                  child: ListTile(
                    leading: Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(width: 18, height: 18),
                        const Icon(Icons.filter_alt, size: 18),
                        if (_selectedCategoriaIds.isNotEmpty)
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
                                '${_selectedCategoriaIds.length}',
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
                if (!widget.readOnly)
                  const PopupMenuItem(
                    value: 'categorias',
                    child: ListTile(
                      leading: Icon(Icons.category),
                      title: Text('Categorías'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf),
                    title: Text('Generar PDF'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (isNutricionista)
                  PopupMenuItem(
                    value: 'chart',
                    child: ListTile(
                      leading: Icon(_showChartView
                          ? Icons.view_list_outlined
                          : Icons.pie_chart_outline),
                      title: Text(_showChartView
                          ? 'Mostrar listado'
                          : 'Mostrar gráfico'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'copiar_ia',
                  child: ListTile(
                    leading: Icon(Icons.auto_awesome, size: 18),
                    title: Text('Copiar IA'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (!widget.readOnly)
                  const PopupMenuItem(
                    value: 'pegar_ia',
                    child: ListTile(
                      leading: Icon(Icons.content_paste_rounded, size: 18),
                      title: Text('Pegar IA'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Actualizar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                CheckedPopupMenuItem(
                  value: 'sort_usos',
                  checked: _ordenCatalogo == _OrdenCatalogo.usos,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Ordenar usos')),
                      if (_ordenCatalogo == _OrdenCatalogo.usos)
                        Icon(
                          _ordenAscendente
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                        ),
                    ],
                  ),
                ),
                CheckedPopupMenuItem(
                  value: 'sort_nombre',
                  checked: _ordenCatalogo == _OrdenCatalogo.nombre,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Ordenar Nombre')),
                      if (_ordenCatalogo == _OrdenCatalogo.nombre)
                        Icon(
                          _ordenAscendente
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                        ),
                    ],
                  ),
                ),
                CheckedPopupMenuItem(
                  value: 'sort_fecha',
                  checked: _ordenCatalogo == _OrdenCatalogo.fechaAlta,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Ordenar Recientes')),
                      if (_ordenCatalogo == _OrdenCatalogo.fechaAlta)
                        Icon(
                          _ordenAscendente
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                        ),
                    ],
                  ),
                ),
                CheckedPopupMenuItem(
                  value: 'sort_categoria',
                  checked: _ordenCatalogo == _OrdenCatalogo.categoria,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Ordenar categoría')),
                      if (_ordenCatalogo == _OrdenCatalogo.categoria)
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
          if (!isNutricionista)
            PopupMenuButton<String>(
              tooltip: 'Opciones',
              onSelected: (value) {
                if (isPreviewMode) {
                  _showPremiumRequiredForEjerciciosTools(context);
                  return;
                }
                switch (value) {
                  case 'buscar':
                    _toggleSearchVisibility();
                    break;
                  case 'filtros':
                    _toggleFilters(isNutricionista: false);
                    break;
                  case 'refresh':
                    _loadData();
                    break;
                  case 'sort_nombre':
                    _applySortSelection(_OrdenCatalogo.nombre);
                    break;
                  case 'sort_fecha':
                    _applySortSelection(_OrdenCatalogo.fechaAlta);
                    break;
                  case 'sort_categoria':
                    _applySortSelection(_OrdenCatalogo.categoria);
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'buscar',
                  child: ListTile(
                    leading: Icon(
                      _showFilters ? Icons.search_off : Icons.search,
                    ),
                    title: Text(_showFilters ? 'Ocultar buscar' : 'Buscar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'filtros',
                  child: ListTile(
                    leading: Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(width: 18, height: 18),
                        const Icon(Icons.filter_alt, size: 18),
                        if (_selectedCategoriaIds.isNotEmpty)
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
                                '${_selectedCategoriaIds.length}',
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
                const PopupMenuItem(
                  value: 'refresh',
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Actualizar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                CheckedPopupMenuItem(
                  value: 'sort_nombre',
                  checked: _ordenCatalogo == _OrdenCatalogo.nombre,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Ordenar Nombre')),
                      if (_ordenCatalogo == _OrdenCatalogo.nombre)
                        Icon(
                          _ordenAscendente
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                        ),
                    ],
                  ),
                ),
                CheckedPopupMenuItem(
                  value: 'sort_fecha',
                  checked: _ordenCatalogo == _OrdenCatalogo.fechaAlta,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Ordenar Recientes')),
                      if (_ordenCatalogo == _OrdenCatalogo.fechaAlta)
                        Icon(
                          _ordenAscendente
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                        ),
                    ],
                  ),
                ),
                CheckedPopupMenuItem(
                  value: 'sort_categoria',
                  checked: _ordenCatalogo == _OrdenCatalogo.categoria,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Ordenar Categoría')),
                      if (_ordenCatalogo == _OrdenCatalogo.categoria)
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
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton(
              onPressed: () => _openEjercicioDialog(),
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildFiltersPanel(),
              if (_loading)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else if (_showChartView)
                Expanded(
                    child: SingleChildScrollView(
                        child: _buildTopUsedEjerciciosChart()))
              else if (_items.isEmpty)
                const Expanded(child: Center(child: Text('Sin ejercicios')))
              else
                Expanded(
                  child: ListView.separated(
                    controller: _listScrollController,
                    padding: EdgeInsets.only(
                      bottom: 96 + MediaQuery.of(context).padding.bottom,
                    ),
                    itemCount: _displayedItems.length +
                        (_hasMore ? 1 : 0) +
                        (isPreviewMode ? 1 : 0),
                    separatorBuilder: (_, index) =>
                        index >= (_displayedItems.length - 1)
                            ? const SizedBox.shrink()
                            : const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (isPreviewMode && index == _displayedItems.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: PremiumUpsellCard(
                            title: l10n.exerciseCatalogPremiumTitle,
                            subtitle: l10n.exerciseCatalogPremiumSubtitle,
                            subtitleHighlight:
                                l10n.exerciseCatalogPremiumPreviewHighlight(
                              _catalogHighlightCount(_items.length),
                            ),
                            subtitleHighlightColor: Colors.pink.shade700,
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/premium_info',
                            ),
                          ),
                        );
                      }
                      if (index >= _displayedItems.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final ejercicio = _displayedItems[index];
                      final isPremium =
                          (ejercicio.visiblePremium ?? 'N').toUpperCase() ==
                              'S';
                      final hasFoto =
                          (ejercicio.fotoMiniatura ?? '').trim().isNotEmpty;
                      final usageColor =
                          _usageBadgeColor(ejercicio.totalUsos, maxUsos);
                      final usageTextColor = _usageBadgeTextColor(usageColor);
                      return Dismissible(
                        key: ValueKey('ej_${ejercicio.codigo}_$index'),
                        direction: widget.readOnly
                            ? DismissDirection.none
                            : DismissDirection.startToEnd,
                        dismissThresholds: {
                          DismissDirection.startToEnd: context
                              .watch<ConfigService>()
                              .deleteSwipeDismissThreshold,
                        },
                        background: Container(
                          color: Colors.red.shade600,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Row(children: [
                            Icon(Icons.delete_outline,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Eliminar',
                                style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                        confirmDismiss: (_) async {
                          if (widget.readOnly) return false;
                          await _deleteEjercicio(ejercicio);
                          return false;
                        },
                        child: Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: InkWell(
                            onTap: widget.readOnly
                                ? () => _showPremiumEjercicioDetalle(
                                      ejercicio,
                                      allowVideoPlayback: !isPreviewMode,
                                    )
                                : () =>
                                    _openEjercicioDialog(ejercicio: ejercicio),
                            onLongPress: widget.readOnly
                                ? null
                                : () => _openEjercicioMenu(ejercicio),
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Thumbnail
                                  GestureDetector(
                                    onTap: widget.readOnly
                                        ? () => _showPremiumEjercicioDetalle(
                                              ejercicio,
                                              allowVideoPlayback:
                                                  !isPreviewMode,
                                            )
                                        : (hasFoto
                                            ? () =>
                                                _showEjercicioImage(ejercicio)
                                            : null),
                                    child: SizedBox(
                                      width: 44,
                                      height: 52,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: hasFoto
                                            ? Container(
                                                color: Colors.grey.shade100,
                                                padding:
                                                    const EdgeInsets.all(2),
                                                child: Image.memory(
                                                  base64Decode(
                                                      ejercicio.fotoMiniatura!),
                                                  fit: BoxFit.contain,
                                                ),
                                              )
                                            : Container(
                                                color: Colors.grey.shade200,
                                                alignment: Alignment.center,
                                                child: Icon(
                                                    Icons.image_not_supported,
                                                    color: Colors.grey.shade500,
                                                    size: 22),
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Name + tags
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ejercicio.nombre,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            if (isNutricionista)
                                              Tooltip(
                                                message: isPremium
                                                    ? 'Visible Premium: sí'
                                                    : 'Visible Premium: no',
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isPremium
                                                        ? Colors.green.shade100
                                                        : Colors.grey.shade300,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                      color: isPremium
                                                          ? Colors
                                                              .green.shade500
                                                          : Colors
                                                              .grey.shade500,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'P',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: isPremium
                                                          ? Colors
                                                              .green.shade800
                                                          : Colors
                                                              .grey.shade800,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if ((ejercicio.tiempo ?? 0) > 0)
                                              _smallChip(
                                                  icon: Icons.schedule,
                                                  label:
                                                      '${ejercicio.tiempo}s'),
                                            if ((ejercicio.repeticiones ?? 0) >
                                                0)
                                              _smallChip(
                                                  icon: Icons.repeat,
                                                  label:
                                                      '×${ejercicio.repeticiones}'),
                                            if ((ejercicio.kilos ?? 0) > 0)
                                              _smallChip(
                                                  icon: Icons
                                                      .fitness_center_outlined,
                                                  label:
                                                      '${ejercicio.kilos} kg'),
                                            if ((ejercicio.descanso ?? 0) > 0)
                                              _smallChip(
                                                  icon: Icons.bedtime_outlined,
                                                  label:
                                                      '${ejercicio.descanso}s'),
                                          ],
                                        ),
                                        if (isNutricionista) ...[
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              _instructionCountChip(
                                                prefix: 'IC',
                                                tooltip:
                                                    'Instrucciones cortas (nº caracteres)',
                                                count:
                                                    (ejercicio.instrucciones ??
                                                            '')
                                                        .trim()
                                                        .length,
                                              ),
                                              _instructionCountChip(
                                                prefix: 'CH',
                                                tooltip: (ejercicio
                                                                .instruccionesDetalladas ??
                                                            '')
                                                        .trim()
                                                        .isNotEmpty
                                                    ? 'Cómo se hace (nº caracteres). Pulsa para ver el detalle'
                                                    : 'Cómo se hace (nº caracteres)',
                                                count: (ejercicio
                                                            .instruccionesDetalladas ??
                                                        '')
                                                    .trim()
                                                    .length,
                                                onTap: (ejercicio
                                                                .instruccionesDetalladas ??
                                                            '')
                                                        .trim()
                                                        .isNotEmpty
                                                    ? () =>
                                                        _showInstruccionesDetalladas(
                                                          ejercicio,
                                                        )
                                                    : null,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Usage badge (nutricionista only)
                                  if (isNutricionista)
                                    Tooltip(
                                      message: ejercicio.totalUsos > 0
                                          ? 'Ver planes que usan este ejercicio'
                                          : 'No aparece en ningún plan',
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: ejercicio.totalUsos > 0
                                              ? () => _showPlanesForEjercicio(
                                                  ejercicio)
                                              : null,
                                          child: Container(
                                            constraints: const BoxConstraints(
                                                minWidth: 24, minHeight: 24),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: usageColor,
                                                shape: BoxShape.circle),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '${ejercicio.totalUsos}',
                                              style: TextStyle(
                                                  color: usageTextColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  // "Cómo se hace" button for readOnly mode with detailed instructions
                                  if (widget.readOnly &&
                                      (ejercicio.instruccionesDetalladas ?? '')
                                          .trim()
                                          .isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.help_outline,
                                          size: 20, color: Colors.blue),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 32, minHeight: 32),
                                      tooltip: 'Cómo se hace',
                                      onPressed: () =>
                                          _showInstruccionesDetalladas(
                                              ejercicio),
                                    ),
                                  // More options button
                                  if (!widget.readOnly)
                                    IconButton(
                                      icon:
                                          const Icon(Icons.more_vert, size: 20),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 32, minHeight: 32),
                                      tooltip: 'Más opciones',
                                      onPressed: () =>
                                          _openEjercicioMenu(ejercicio),
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
          ),
        ),
      ),
    );
  }

  void _showInstruccionesDetalladas(PlanFitEjercicio ejercicio) {
    final instrucciones = (ejercicio.instruccionesDetalladas ?? '').trim();
    if (instrucciones.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${ejercicio.nombre} - Cómo se hace...',
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close, size: 18),
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                minimumSize: const Size(34, 34),
                padding: EdgeInsets.zero,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          height: 460,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: GestureDetector(
                  onLongPress: () async {
                    final textToCopy =
                        await _buildCopiedHowToText(instrucciones);
                    await Clipboard.setData(ClipboardData(text: textToCopy));
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Instrucciones copiadas'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          child: Text(
                            instrucciones,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    children: [
                      TextSpan(
                        text: 'Aviso importante... ',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text:
                            'Antes de realizar este ejercicio, contacta con tu entrenador, para que te guíe y lo personalice acorde a tus necesidades.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      dialogContext,
                      MaterialPageRoute(
                        builder: (_) => const ContactoNutricionistaScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text('Contactar con entrenador'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _extractInstructionTags(String rawText) {
    final normalized = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('•', '\n')
        .replaceAll('·', '\n');

    bool isLeadingInstructionDecorator(int rune) {
      return rune == 0xFE0F ||
          rune == 0x200D ||
          rune == 0x00A9 ||
          rune == 0x00AE ||
          (rune >= 0x2000 && rune <= 0x3300) ||
          (rune >= 0x2600 && rune <= 0x27BF) ||
          (rune >= 0x1F000 && rune <= 0x1FAFF);
    }

    String cleanInstructionStep(String part) {
      var cleaned =
          part.trim().replaceFirst(RegExp(r'^[-*\d\s.)]+'), '').trimLeft();

      while (cleaned.isNotEmpty) {
        final runes = cleaned.runes.toList(growable: false);
        if (runes.isEmpty || !isLeadingInstructionDecorator(runes.first)) {
          break;
        }
        cleaned = String.fromCharCodes(runes.skip(1)).trimLeft();
      }

      return cleaned.trim();
    }

    List<String> parts = normalized
        .split(RegExp(r'\n|;'))
        .map(cleanInstructionStep)
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.length <= 1) {
      parts = normalized
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map(cleanInstructionStep)
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
    }

    if (parts.isEmpty && normalized.trim().isNotEmpty) {
      final fallback = cleanInstructionStep(normalized);
      return fallback.isEmpty ? <String>[] : <String>[fallback];
    }

    return parts;
  }

  Widget _buildPremiumMetricCard({
    required IconData icon,
    required String caption,
    required String value,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[color.withValues(alpha: 0.16), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
              color: color.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionTag(String text, int stepNumber) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE0E5F2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEFF),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFD5DDF2)),
            ),
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5D6C8F),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortInstructionCard(
    String text, {
    bool highlighted = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFE4A8) : const Color(0xFFFFF4DE),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              highlighted ? const Color(0xFFFFC84E) : const Color(0xFFF5D8A6),
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: highlighted
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33FFB300),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: highlighted
                  ? const Color(0xFF2F5FE5)
                  : const Color(0xFFFFE8B8),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: highlighted
                    ? const Color(0xFF1F4BD4)
                    : const Color(0xFFF5D08A),
              ),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: highlighted ? Colors.white : const Color(0xFF7A5608),
              ),
              child: const Text('Instrucciones'),
            ),
          ),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5F4A24),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _buildCopiedHowToText(String rawText) async {
    const warningText =
        'Aviso importante... Antes de realizar este ejercicio, contacta con tu entrenador, para que te guie y lo personalice acorde a tus necesidades.';
    var nutricionistaNombre = 'Nutricionista';

    try {
      final nutricionistaParam = await _apiService.getParametro(
        'nutricionista_nombre',
      );
      final nombre = (nutricionistaParam?['valor'] ?? '').toString().trim();
      if (nombre.isNotEmpty) {
        nutricionistaNombre = nombre;
      }
    } catch (_) {}

    return '${rawText.trim()}\n\n$warningText\n\nApp NutriFit - $nutricionistaNombre';
  }

  Future<void> _showPremiumEjercicioDetalle(
    PlanFitEjercicio ejercicio, {
    bool allowVideoPlayback = true,
  }) async {
    final shortInstructions = (ejercicio.instrucciones ?? '').trim();
    final detailedInstructions =
        (ejercicio.instruccionesDetalladas ?? '').trim();
    final instructionTags = _extractInstructionTags(detailedInstructions);
    final hasDetailedInstructions = detailedInstructions.isNotEmpty;
    const coverSubtitleMaxChars = 50;
    final coverSubtitle = shortInstructions.isNotEmpty
        ? (shortInstructions.length > coverSubtitleMaxChars
            ? '${shortInstructions.substring(0, coverSubtitleMaxChars)}...'
            : shortInstructions)
        : 'Movimiento premium listo para incorporar a tu rutina.';
    final showReadMoreLink = shortInstructions.length > coverSubtitleMaxChars &&
        (hasDetailedInstructions || shortInstructions.isNotEmpty);
    final imageBase64 = (ejercicio.fotoBase64 ?? '').trim().isNotEmpty
        ? ejercicio.fotoBase64!.trim()
        : (ejercicio.fotoMiniatura ?? '').trim();
    final hasImage = imageBase64.isNotEmpty;
    final ImageProvider? coverImageProvider = hasImage
        ? (() {
            try {
              return MemoryImage(base64Decode(imageBase64));
            } catch (_) {
              return null;
            }
          })()
        : null;
    final effectiveVideoUrl = (ejercicio.urlVideo ?? '').trim();
    final hasVideo = effectiveVideoUrl.isNotEmpty;
    final metricCards = <Widget>[
      if ((ejercicio.tiempo ?? 0) > 0)
        _buildPremiumMetricCard(
          icon: Icons.schedule_rounded,
          caption: 'Tiempo',
          value: '${ejercicio.tiempo}s',
          color: const Color(0xFFFF8A3D),
        ),
      if ((ejercicio.repeticiones ?? 0) > 0)
        _buildPremiumMetricCard(
          icon: Icons.repeat_rounded,
          caption: 'Repeticiones',
          value: '${ejercicio.repeticiones}',
          color: const Color(0xFF4F7CFF),
        ),
      if ((ejercicio.kilos ?? 0) > 0)
        _buildPremiumMetricCard(
          icon: Icons.fitness_center_rounded,
          caption: 'Peso',
          value: '${ejercicio.kilos} kg',
          color: const Color(0xFF13A57A),
        ),
      if ((ejercicio.descanso ?? 0) > 0)
        _buildPremiumMetricCard(
          icon: Icons.airline_seat_individual_suite_rounded,
          caption: 'Descanso',
          value: '${ejercicio.descanso}s',
          color: const Color(0xFF8E59FF),
        ),
    ];

    await showDialog<void>(
      context: context,
      builder: (context) {
        bool expandHowTo = false;
        bool highlightHowToShortInstructions = false;
        int howToHighlightVersion = 0;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void triggerHowToFeedback() {
              final currentVersion = ++howToHighlightVersion;
              setStateDialog(() {
                expandHowTo = true;
                highlightHowToShortInstructions = true;
              });

              Future<void>.delayed(const Duration(milliseconds: 950), () {
                if (!context.mounted ||
                    currentVersion != howToHighlightVersion) {
                  return;
                }
                setStateDialog(() {
                  highlightHowToShortInstructions = false;
                });
              });
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 760, maxHeight: 860),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFFFFFCF7), Color(0xFFF5F8FF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x2A000000),
                        blurRadius: 30,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          height: hasImage ? 250 : 160,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                Color(0xFFFFB06A),
                                Color(0xFFFFDFA5),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: hasImage
                                ? () => _showEjercicioImage(ejercicio)
                                : null,
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                if (coverImageProvider != null)
                                  RepaintBoundary(
                                    child: Opacity(
                                      opacity: 0.24,
                                      child: Image(
                                        image: coverImageProvider,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                      ),
                                    ),
                                  ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: <Color>[
                                        Colors.black.withValues(alpha: 0.05),
                                        Colors.black.withValues(alpha: 0.22),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 14,
                                  right: 14,
                                  child: IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.22),
                                    ),
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                    tooltip: 'Cerrar',
                                  ),
                                ),
                                if (hasImage)
                                  Positioned(
                                    top: 16,
                                    left: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.22),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.28),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Icon(
                                            Icons.zoom_in,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Toca para ampliar',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: 22,
                                  right: 22,
                                  bottom: 22,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        ejercicio.nombre,
                                        style: const TextStyle(
                                          color: Color(0xFF2E1D12),
                                          fontSize: 21,
                                          height: 1.1,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      RichText(
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        text: TextSpan(
                                          style: TextStyle(
                                            color: const Color(0xFF4A321E)
                                                .withValues(alpha: 0.95),
                                            fontSize: 14,
                                            height: 1.35,
                                          ),
                                          children: [
                                            TextSpan(text: coverSubtitle),
                                            if (showReadMoreLink)
                                              WidgetSpan(
                                                alignment: PlaceholderAlignment
                                                    .baseline,
                                                baseline:
                                                    TextBaseline.alphabetic,
                                                child: GestureDetector(
                                                  onTap: triggerHowToFeedback,
                                                  child: Text(
                                                    ' Leer más',
                                                    style: TextStyle(
                                                      color: const Color(
                                                        0xFF2F2014,
                                                      ),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      decoration: TextDecoration
                                                          .underline,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                if (metricCards.isNotEmpty) ...[
                                  const SizedBox(height: 0),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: metricCards,
                                  ),
                                ],
                                if (hasDetailedInstructions ||
                                    shortInstructions.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onLongPress: () async {
                                      final sourceText =
                                          detailedInstructions.isNotEmpty
                                              ? detailedInstructions
                                              : shortInstructions;
                                      final textToCopy =
                                          await _buildCopiedHowToText(
                                        sourceText,
                                      );
                                      await Clipboard.setData(
                                        ClipboardData(text: textToCopy),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Instrucciones copiadas'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: Card(
                                      margin: EdgeInsets.zero,
                                      elevation: 0,
                                      color: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          gradient: const LinearGradient(
                                            colors: <Color>[
                                              Color(0xFFEAF2FF),
                                              Color(0xFFF4F8FF),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFBFD3FF),
                                          ),
                                          boxShadow: const <BoxShadow>[
                                            BoxShadow(
                                              color: Color(0x16000000),
                                              blurRadius: 14,
                                              offset: Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            dividerColor: Colors.transparent,
                                          ),
                                          child: ExpansionTile(
                                            key: ValueKey<bool>(expandHowTo),
                                            initiallyExpanded: expandHowTo,
                                            onExpansionChanged: (expanded) {
                                              setStateDialog(() {
                                                expandHowTo = expanded;
                                              });
                                            },
                                            tilePadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 6,
                                            ),
                                            leading: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF4F7CFF)
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.auto_awesome_rounded,
                                                size: 18,
                                                color: Color(0xFF2F5FE5),
                                              ),
                                            ),
                                            childrenPadding:
                                                const EdgeInsets.fromLTRB(
                                              18,
                                              0,
                                              18,
                                              18,
                                            ),
                                            title: const Row(
                                              children: <Widget>[
                                                Expanded(
                                                  child: Text(
                                                    'Cómo se hace...',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Color(0xFF1D3266),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            children: <Widget>[
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (shortInstructions
                                                      .isNotEmpty)
                                                    _buildShortInstructionCard(
                                                      shortInstructions,
                                                      highlighted:
                                                          highlightHowToShortInstructions,
                                                    ),
                                                  if (shortInstructions
                                                          .isNotEmpty &&
                                                      instructionTags
                                                          .isNotEmpty)
                                                    const SizedBox(height: 10),
                                                  ...instructionTags
                                                      .asMap()
                                                      .entries
                                                      .expand(
                                                        (entry) => <Widget>[
                                                          _buildInstructionTag(
                                                            entry.value,
                                                            entry.key + 1,
                                                          ),
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                        ],
                                                      ),
                                                  if (instructionTags
                                                      .isNotEmpty)
                                                    const SizedBox(height: 0),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.amber.shade300,
                                      ),
                                    ),
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Aviso importante... ',
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const TextSpan(
                                            text:
                                                'Antes de realizar este ejercicio, contacta con tu entrenador, para que te guie y lo personalice acorde a tus necesidades.',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ContactoNutricionistaScreen(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.support_agent,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Contactar con entrenador',
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.orange.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (hasVideo) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: allowVideoPlayback
                                            ? () => _launchUrlExternal(
                                                  effectiveVideoUrl,
                                                )
                                            : () =>
                                                _showPremiumRequiredForEjerciciosVideo(
                                                  context,
                                                ),
                                        icon: const Icon(
                                          Icons.play_circle_fill,
                                          size: 18,
                                        ),
                                        label: const Text('Ver vídeo'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.blue.shade700,
                                          side: BorderSide(
                                            color: Colors.blue.shade300,
                                          ),
                                          backgroundColor: Colors.blue.shade50,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _smallChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  Widget _instructionCountChip({
    required String prefix,
    required int count,
    String? tooltip,
    VoidCallback? onTap,
  }) {
    final hasText = count > 0;
    final bgColor = hasText ? Colors.green.shade100 : Colors.grey.shade300;
    final borderColor = hasText ? Colors.green.shade500 : Colors.grey.shade500;
    final textColor = hasText ? Colors.green.shade800 : Colors.grey.shade700;

    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            '$prefix $count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(message: tooltip, child: chip);
    }
    return chip;
  }

  Widget _buildPhotoThumbnailCatalog({
    required bool hasFoto,
    required Uint8List? fotoBytes,
    required String? fotoPath,
    required String fotoMiniatura,
    required String fotoBase64,
    required bool isFotoCatalog,
    required bool removeFoto,
    required VoidCallback onAddOrChange,
    required VoidCallback onDelete,
    required VoidCallback onView,
  }) {
    Widget buildThumbnail() {
      if (removeFoto) {
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.fitness_center,
            size: 48,
            color: Colors.grey.shade400,
          ),
        );
      }

      if (fotoBytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            fotoBytes,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        );
      }

      if (fotoPath != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(fotoPath),
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        );
      }

      // Mostrar miniatura si existe, sino mostrar fotoBase64 (fallback)
      if (fotoMiniatura.isNotEmpty) {
        try {
          final bytes = base64Decode(fotoMiniatura);
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          );
        } catch (_) {}
      }

      if (fotoBase64.isNotEmpty) {
        try {
          final bytes = base64Decode(fotoBase64);
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          );
        } catch (_) {}
      }

      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.fitness_center,
          size: 48,
          color: Colors.grey.shade400,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                if (hasFoto && !removeFoto) {
                  onView();
                } else {
                  _showMenuAtWidget(
                    context,
                    hasFoto,
                    removeFoto,
                    onDelete,
                    onAddOrChange,
                    null,
                  );
                }
              },
              onLongPress: () {
                _showMenuAtWidget(
                  context,
                  hasFoto,
                  removeFoto,
                  onDelete,
                  onAddOrChange,
                  null,
                );
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.shade300, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: buildThumbnail(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          hasFoto && !removeFoto
              ? 'Pulsa para ver | Mantén pulsado para opciones'
              : 'Pulsa para añadir imagen',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }

  void _showMenuAtWidget(
    BuildContext context,
    bool hasFoto,
    bool removeFoto,
    VoidCallback onDelete,
    VoidCallback onAddOrChange,
    VoidCallback? onPaste,
  ) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final menuOptions = <PopupMenuItem<String>>[];
    if (!removeFoto && hasFoto) {
      menuOptions.add(
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar imagen'),
            ],
          ),
        ),
      );
      menuOptions.add(
        const PopupMenuItem(
          value: 'change',
          child: Row(
            children: [
              Icon(Icons.photo_library_outlined),
              SizedBox(width: 8),
              Text('Cambiar imagen'),
            ],
          ),
        ),
      );
      if (onPaste != null) {
        menuOptions.add(
          const PopupMenuItem(
            value: 'paste',
            child: Row(
              children: [
                Icon(Icons.content_paste_rounded),
                SizedBox(width: 8),
                Text('Pegar imagen'),
              ],
            ),
          ),
        );
      }
    } else {
      menuOptions.add(
        const PopupMenuItem(
          value: 'add',
          child: Row(
            children: [
              Icon(Icons.add_photo_alternate_outlined),
              SizedBox(width: 8),
              Text('Añadir imagen'),
            ],
          ),
        ),
      );
      if (onPaste != null) {
        menuOptions.add(
          const PopupMenuItem(
            value: 'paste',
            child: Row(
              children: [
                Icon(Icons.content_paste_rounded),
                SizedBox(width: 8),
                Text('Pegar imagen'),
              ],
            ),
          ),
        );
      }
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy,
      ),
      items: menuOptions,
    ).then((value) {
      if (value == 'delete') {
        onDelete();
      } else if (value == 'paste') {
        onPaste?.call();
      } else if (value == 'change' || value == 'add') {
        onAddOrChange();
      }
    });
  }

  // ignore: unused_element
  void _showPhotoMenu({
    required bool hasFoto,
    required bool removeFoto,
    required VoidCallback onDelete,
    required VoidCallback onAddOrChange,
  }) {
    final menuOptions = <String>[];
    if (!removeFoto && hasFoto) {
      menuOptions.add('Eliminar imagen');
      menuOptions.add('Cambiar imagen');
    } else {
      menuOptions.add('Añadir imagen');
    }

    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(0, 0, 0, 0),
      items: menuOptions
          .map((option) => PopupMenuItem(value: option, child: Text(option)))
          .toList(),
    ).then((value) {
      if (value == 'Eliminar imagen') {
        onDelete();
      } else if (value == 'Cambiar imagen' || value == 'Añadir imagen') {
        onAddOrChange();
      }
    });
  }
}
