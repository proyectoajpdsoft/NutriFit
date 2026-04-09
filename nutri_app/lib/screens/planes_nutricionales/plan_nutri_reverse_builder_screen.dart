import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/alimento.dart';
import '../../models/alimento_grupo.dart';
import '../../models/plan_nutri_estructura.dart';
import '../../models/plan_nutricional.dart';
import '../../services/api_service.dart';

class PlanNutriReverseBuilderScreen extends StatefulWidget {
  const PlanNutriReverseBuilderScreen({
    super.key,
    this.plan,
    this.onSwitchToNormal,
    this.initialEstructura,
    this.alimentos,
    this.grupos,
    this.planCodigo,
    this.focusWeekIndex,
    this.focusDayIndex,
    this.focusDate,
  });

  /// Standalone mode: when set, the screen loads its own data.
  final PlanNutricional? plan;

  /// Called when the user wants to switch to the normal plan editor.
  final VoidCallback? onSwitchToNormal;

  final PlanNutriEstructura? initialEstructura;
  final List<Alimento>? alimentos;
  final List<AlimentoGrupo>? grupos;
  final int? planCodigo;
  final int? focusWeekIndex;
  final int? focusDayIndex;
  final DateTime? focusDate;

  @override
  State<PlanNutriReverseBuilderScreen> createState() =>
      _PlanNutriReverseBuilderScreenState();
}

class _DraggedAlimentosPayload {
  const _DraggedAlimentosPayload(this.alimentos);

  final List<Alimento> alimentos;
}

class _DraggedIngestaItemPayload {
  const _DraggedIngestaItemPayload({
    required this.weekIndex,
    required this.dayIndex,
    required this.mealIndex,
    required this.itemIndex,
    required this.item,
  });

  final int weekIndex;
  final int dayIndex;
  final int mealIndex;
  final int itemIndex;
  final PlanNutriItem item;
}

enum _QuickItemAction { edit, delete, copy }

class _PlanNutriReverseBuilderScreenState
    extends State<PlanNutriReverseBuilderScreen> {
  static const String _showFiltersPrefsKey = 'plan_nutri_reverse_show_filters';
  static const String _splitterRatioPrefsKey =
      'plan_nutri_reverse_splitter_ratio';
  static const String _detailedViewPrefsKey =
      'plan_nutri_reverse_detailed_view';
  static const double _defaultTopPaneRatio = 0.42;

  final ApiService _apiService = ApiService();
  late PlanNutriEstructura _estructura;
  PlanNutriEstructura? _lastSnapshot;
  late List<Alimento> _alimentos;
  late List<AlimentoGrupo> _grupos;
  bool _savingDrop = false;
  bool _loading = false;
  String? _loadError;

  bool _showFilters = true;
  double _topPaneRatio = _defaultTopPaneRatio;
  bool _detailedWeekView = true;
  int? _compactWeekIndex;
  int? _compactDayIndex;
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<int> _gruposFiltro = {};

  final Set<int> _selectedCodigos = {};
  final Set<int> _expandedWeeks = {};
  final Set<String> _expandedDays = {};
  final Set<String> _expandedIngestas = {};

  final ScrollController _weeksScrollController = ScrollController();
  Timer? _autoScrollTimer;
  double? _autoScrollCurrentStep;
  final Map<int, Timer> _weekHoverTimers = {};
  final Map<String, Timer> _dayHoverTimers = {};

  bool get _focusMode =>
      widget.focusWeekIndex != null && widget.focusDayIndex != null;

  int get _effectivePlanCodigo => widget.plan?.codigo ?? widget.planCodigo!;

  @override
  void initState() {
    super.initState();
    if (widget.plan != null) {
      // Standalone mode: screen loads its own data asynchronously.
      _estructura = PlanNutriEstructura(
        codigoPlanNutricional: widget.plan!.codigo,
        tituloPlan: widget.plan!.tituloPlan,
      );
      _alimentos = [];
      _grupos = [];
      _loading = true;
      _loadData();
    } else {
      // Embedded mode: data is pre-loaded by the calling screen.
      _estructura =
          PlanNutriEstructura.fromJson(widget.initialEstructura!.toJson());
      _estructura.codigoPlanNutricional = widget.planCodigo!;
      _alimentos = List<Alimento>.from(widget.alimentos!);
      _grupos = List<AlimentoGrupo>.from(widget.grupos!);
      _applyFocusExpansion();
      _loadUiState();
    }
  }

  void _applyFocusExpansion() {
    if (!_focusMode) return;
    final weekIndex = widget.focusWeekIndex!;
    final dayIndex = widget.focusDayIndex!;
    if (weekIndex >= 0 && weekIndex < _estructura.semanas.length) {
      final semana = _estructura.semanas[weekIndex];
      if (dayIndex >= 0 && dayIndex < semana.dias.length) {
        _expandedWeeks.add(weekIndex);
        _expandedDays.add(_dayKey(weekIndex, dayIndex));
        for (var mealIndex = 0;
            mealIndex < semana.dias[dayIndex].ingestas.length;
            mealIndex++) {
          _expandedIngestas.add(_ingestaKey(weekIndex, dayIndex, mealIndex));
        }
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final plan = widget.plan!;
      final results = await Future.wait<dynamic>([
        _apiService.getAlimentos(soloActivos: true),
        _apiService.getPlanNutriEstructura(plan.codigo),
      ]);
      final alimentos = results[0] as List<Alimento>;
      final estructura = results[1] as PlanNutriEstructura;

      List<AlimentoGrupo> grupos = [];
      try {
        grupos = await _apiService.getAlimentoGrupos();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _alimentos = alimentos;
        _grupos = grupos;
        _estructura = estructura;
        _estructura.codigoPlanNutricional = plan.codigo;
        _loading = false;
      });
      _applyFocusExpansion();
      _loadUiState();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _weeksScrollController.dispose();
    _autoScrollTimer?.cancel();
    for (final t in _weekHoverTimers.values) {
      t.cancel();
    }
    for (final t in _dayHoverTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _search = '';
    });
  }

  PlanNutriEstructura _cloneEstructura(PlanNutriEstructura value) {
    return PlanNutriEstructura.fromJson(value.toJson());
  }

  Future<bool> _saveCurrentStructure() async {
    _estructura.codigoPlanNutricional = _effectivePlanCodigo;
    final saved = await _apiService.savePlanNutriEstructura(_estructura);
    return saved;
  }

  Future<void> _persistDropWithRollback({
    required PlanNutriEstructura beforeDrop,
  }) async {
    try {
      await _saveCurrentStructure();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alimento añadido a ingesta'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 1200),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estructura = beforeDrop;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el arrastre: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingDrop = false;
        });
      }
    }
  }

  Future<void> _undoLastDrop() async {
    final snapshot = _lastSnapshot;
    if (snapshot == null || _savingDrop) return;

    final current = _cloneEstructura(_estructura);
    setState(() {
      _savingDrop = true;
      _estructura = _cloneEstructura(snapshot);
    });

    try {
      await _saveCurrentStructure();
      if (!mounted) return;
      setState(() {
        _lastSnapshot = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Último arrastre deshecho'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 1200),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estructura = current;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo deshacer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingDrop = false;
        });
      }
    }
  }

  Future<void> _persistStructureChange({
    required PlanNutriEstructura beforeChange,
    required String successMessage,
    String errorPrefix = 'No se pudo guardar el cambio',
  }) async {
    try {
      await _saveCurrentStructure();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 1400),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estructura = beforeChange;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$errorPrefix: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingDrop = false;
        });
      }
    }
  }

  void _startAutoScroll(double step) {
    if (_autoScrollTimer != null && _autoScrollCurrentStep == step) return;
    _autoScrollTimer?.cancel();
    _autoScrollCurrentStep = step;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_weeksScrollController.hasClients) return;
      final pos = _weeksScrollController.position;
      final next = (pos.pixels + step).clamp(0.0, pos.maxScrollExtent);
      _weeksScrollController.jumpTo(next);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollCurrentStep = null;
  }

  void _scheduleExpandWeek(int weekIndex) {
    _weekHoverTimers[weekIndex]?.cancel();
    _weekHoverTimers[weekIndex] = Timer(const Duration(milliseconds: 500), () {
      _weekHoverTimers.remove(weekIndex);
      if (mounted && !_expandedWeeks.contains(weekIndex)) {
        setState(() => _expandedWeeks.add(weekIndex));
      }
    });
  }

  void _cancelExpandWeek(int weekIndex) {
    _weekHoverTimers[weekIndex]?.cancel();
    _weekHoverTimers.remove(weekIndex);
  }

  void _scheduleExpandDay(int weekIndex, int dayIndex) {
    final key = _dayKey(weekIndex, dayIndex);
    _dayHoverTimers[key]?.cancel();
    _dayHoverTimers[key] = Timer(const Duration(milliseconds: 500), () {
      _dayHoverTimers.remove(key);
      if (mounted && !_expandedDays.contains(key)) {
        setState(() {
          _expandedWeeks.add(weekIndex);
          _expandedDays.add(key);
        });
      }
    });
  }

  void _cancelExpandDay(int weekIndex, int dayIndex) {
    final key = _dayKey(weekIndex, dayIndex);
    _dayHoverTimers[key]?.cancel();
    _dayHoverTimers.remove(key);
  }

  String _dayKey(int weekIndex, int dayIndex) => '$weekIndex-$dayIndex';

  String _ingestaKey(int weekIndex, int dayIndex, int mealIndex) =>
      '$weekIndex-$dayIndex-$mealIndex';

  String get _compactWeekPrefsKey =>
      'plan_nutri_reverse_compact_week_$_effectivePlanCodigo';

  String get _compactDayPrefsKey =>
      'plan_nutri_reverse_compact_day_$_effectivePlanCodigo';

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final showFilters = prefs.getBool(_showFiltersPrefsKey) ?? true;
    final splitterRatio =
        prefs.getDouble(_splitterRatioPrefsKey) ?? _defaultTopPaneRatio;
    final detailedWeekView = prefs.getBool(_detailedViewPrefsKey) ?? true;
    final compactWeekIndex = prefs.getInt(_compactWeekPrefsKey);
    final compactDayIndex = prefs.getInt(_compactDayPrefsKey);
    if (!mounted) return;
    setState(() {
      _showFilters = showFilters;
      _topPaneRatio = splitterRatio.clamp(0.15, 0.85);
      _detailedWeekView = detailedWeekView;
      _compactWeekIndex = compactWeekIndex;
      _compactDayIndex = compactDayIndex;
    });
  }

  Future<void> _setShowFilters(bool value) async {
    setState(() {
      _showFilters = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showFiltersPrefsKey, value);
  }

  Future<void> _persistSplitterRatio() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_splitterRatioPrefsKey, _topPaneRatio);
  }

  Future<void> _persistCompactSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (_compactWeekIndex == null) {
      await prefs.remove(_compactWeekPrefsKey);
    } else {
      await prefs.setInt(_compactWeekPrefsKey, _compactWeekIndex!);
    }
    if (_compactDayIndex == null) {
      await prefs.remove(_compactDayPrefsKey);
    } else {
      await prefs.setInt(_compactDayPrefsKey, _compactDayIndex!);
    }
  }

  Future<void> _toggleDetailedWeekView() async {
    final next = !_detailedWeekView;
    setState(() {
      _detailedWeekView = next;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_detailedViewPrefsKey, next);
    await _persistCompactSelection();
  }

  bool _isSemanaCompleted(PlanNutriSemana semana) {
    return (semana.completada ?? 'N').toUpperCase() == 'S';
  }

  Future<void> _showAddAlimentoDialog() async {
    final nombreCtrl = TextEditingController(text: _search.trim());
    final selectedGrupos = <int>{};
    final formKey = GlobalKey<FormState>();
    bool opcion = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuevo alimento'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre *',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'El nombre es obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SizedBox(
                      height: 260,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _grupos
                              .where((g) => g.codigo != null && g.activo == 1)
                              .map(
                                (grupo) => CheckboxListTile(
                                  dense: true,
                                  value: selectedGrupos.contains(grupo.codigo),
                                  title: Text(grupo.nombre),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (checked) {
                                    setDialogState(() {
                                      if (checked == true) {
                                        selectedGrupos.add(grupo.codigo!);
                                      } else {
                                        selectedGrupos.remove(grupo.codigo);
                                      }
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: opcion,
                    onChanged: (value) => setDialogState(() => opcion = value),
                    title: const Text('Opción'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final nuevoAlimento = Alimento(
      nombre: nombreCtrl.text.trim(),
      codigoGrupo: selectedGrupos.isNotEmpty ? selectedGrupos.first : null,
      codigoGrupos: selectedGrupos.toList(),
      activo: 1,
      opcion: opcion ? 'S' : 'N',
    );

    try {
      final nuevoCodigo =
          await _apiService.createAlimentoGetCodigo(nuevoAlimento);
      if (!mounted) return;
      if (nuevoCodigo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('El alimento ya existe en el catálogo, no se añadirá'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      nuevoAlimento.codigo = nuevoCodigo;
      setState(() {
        _alimentos = List<Alimento>.from(_alimentos)
          ..add(nuevoAlimento)
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(
                b.nombre.toLowerCase(),
              ));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alimento "${nuevoAlimento.nombre}" creado'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Alimento> get _alimentosFiltrados {
    final query = _search.trim().toLowerCase();
    return _alimentos.where((alimento) {
      if (alimento.activo != 1) return false;
      if (_gruposFiltro.isNotEmpty) {
        final gruposAlimento = alimento.codigoGrupos.isNotEmpty
            ? alimento.codigoGrupos
            : (alimento.codigoGrupo != null
                ? <int>[alimento.codigoGrupo!]
                : <int>[]);
        final matchGrupo = gruposAlimento.any(_gruposFiltro.contains);
        if (!matchGrupo) return false;
      }
      if (query.isNotEmpty && !alimento.nombre.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList()
      ..sort(
          (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  }

  String _gruposFiltroLabel() {
    if (_gruposFiltro.isEmpty) return 'Categorías: todas';
    final nombres = _grupos
        .where((g) => g.codigo != null && _gruposFiltro.contains(g.codigo))
        .map((g) => g.nombre)
        .toList();
    if (nombres.length <= 2) {
      return 'Categorías: ${nombres.join(', ')}';
    }
    return 'Categorías: ${nombres.length} seleccionadas';
  }

  Future<void> _pickGruposFiltro() async {
    final temp = Set<int>.from(_gruposFiltro);
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Filtrar por categorías'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _grupos
                    .where((g) => g.codigo != null)
                    .map(
                      (grupo) => CheckboxListTile(
                        dense: true,
                        value: temp.contains(grupo.codigo),
                        title: Text(grupo.nombre),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (checked) {
                          setLocal(() {
                            if (checked == true) {
                              temp.add(grupo.codigo!);
                            } else {
                              temp.remove(grupo.codigo);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, <int>{}),
              child: const Text('Limpiar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, temp),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || selected == null) return;
    setState(() {
      _gruposFiltro
        ..clear()
        ..addAll(selected);
    });
  }

  List<Alimento> get _selectedAlimentos {
    return _alimentos
        .where((alimento) => _selectedCodigos.contains(alimento.codigo ?? -1))
        .toList();
  }

  _DraggedAlimentosPayload _payloadForAlimento(Alimento alimento) {
    final selected = _selectedAlimentos;
    final selectedContainsThis =
        selected.any((item) => item.codigo == alimento.codigo);
    if (selected.length > 1 && selectedContainsThis) {
      return _DraggedAlimentosPayload(selected);
    }
    return _DraggedAlimentosPayload([alimento]);
  }

  PlanNutriItem _clonePlanItem(PlanNutriItem item) {
    return PlanNutriItem(
      codigoAlimento: item.codigoAlimento,
      alimentoNombre: item.alimentoNombre,
      descripcionManual: item.descripcionManual,
      cantidad: item.cantidad,
      unidad: item.unidad,
      orden: item.orden,
      notas: item.notas,
    );
  }

  String _itemName(PlanNutriItem item) {
    final text =
        (item.descripcionManual ?? item.alimentoNombre ?? 'Alimento').trim();
    return text.isEmpty ? 'Alimento' : text;
  }

  String _normalizedItemName(PlanNutriItem item) {
    return _itemName(item).toLowerCase().trim();
  }

  bool _ingestaHasDuplicateName(
    PlanNutriIngesta ingesta,
    String normalizedName, {
    int? ignoreIndex,
  }) {
    for (var i = 0; i < ingesta.items.length; i++) {
      if (ignoreIndex != null && i == ignoreIndex) continue;
      if (_normalizedItemName(ingesta.items[i]) == normalizedName) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _confirmDeleteItem(String itemName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar alimento'),
        content: Text('¿Quieres eliminar "$itemName" de esta ingesta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<Alimento?> _pickSingleAlimentoDialog(Alimento? current) async {
    final searchCtrl = TextEditingController(text: current?.nombre ?? '');
    var query = '';

    return showDialog<Alimento>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final filtered = _alimentos.where((alimento) {
            if (alimento.activo != 1) return false;
            if (query.trim().isEmpty) return true;
            return alimento.nombre.toLowerCase().contains(query.toLowerCase());
          }).toList()
            ..sort(
              (a, b) =>
                  a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
            );

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Alimentos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Cancelar',
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Buscar alimento...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setLocal(() {
                      query = value.trim();
                    }),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 320,
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final alimento = filtered[index];
                        return ListTile(
                          dense: true,
                          title: Text(alimento.nombre),
                          onTap: () => Navigator.pop(context, alimento),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, int>?> _pickCopyItemDestination({
    required int sourceWeekIndex,
    required int sourceDayIndex,
    required String sourceMealType,
  }) async {
    int selectedWeekIndex = sourceWeekIndex;
    int? selectedDayIndex;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final semana = _estructura.semanas[selectedWeekIndex];
          final dias = semana.dias;
          final validDaySelected = selectedDayIndex != null &&
              selectedDayIndex! >= 0 &&
              selectedDayIndex! < dias.length &&
              !(selectedWeekIndex == sourceWeekIndex &&
                  selectedDayIndex == sourceDayIndex);

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Copiar alimento',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Cancelar',
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Se copiará a la ingesta "$sourceMealType" del día destino.'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedWeekIndex,
                    decoration: const InputDecoration(
                      labelText: 'Semana',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                      _estructura.semanas.length,
                      (index) {
                        final item = _estructura.semanas[index];
                        final title = (item.titulo ?? '').trim().isEmpty
                            ? 'Semana ${item.numeroSemana}'
                            : 'Semana ${item.numeroSemana} · ${item.titulo}';
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text(title),
                        );
                      },
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setLocal(() {
                        selectedWeekIndex = value;
                        if (selectedWeekIndex == sourceWeekIndex &&
                            selectedDayIndex == sourceDayIndex) {
                          selectedDayIndex = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(dias.length, (dayIndex) {
                          final dia = dias[dayIndex];
                          final sameSource =
                              selectedWeekIndex == sourceWeekIndex &&
                                  dayIndex == sourceDayIndex;
                          return RadioListTile<int>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: dayIndex,
                            groupValue: selectedDayIndex,
                            title: Text(dia.nombreDia),
                            subtitle:
                                sameSource ? const Text('Día origen') : null,
                            onChanged: sameSource
                                ? null
                                : (value) {
                                    setLocal(() {
                                      selectedDayIndex = value;
                                    });
                                  },
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: !validDaySelected
                    ? null
                    : () => Navigator.pop(context, {
                          'weekIndex': selectedWeekIndex,
                          'dayIndex': selectedDayIndex!,
                        }),
                child: const Text('Copiar'),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }

  Future<void> _editIngestaItem({
    required int weekIndex,
    required int dayIndex,
    required int mealIndex,
    required int itemIndex,
  }) async {
    if (_savingDrop) return;
    if (weekIndex < 0 || weekIndex >= _estructura.semanas.length) return;
    final semana = _estructura.semanas[weekIndex];
    if (dayIndex < 0 || dayIndex >= semana.dias.length) return;
    final dia = semana.dias[dayIndex];
    if (mealIndex < 0 || mealIndex >= dia.ingestas.length) return;
    final ingesta = dia.ingestas[mealIndex];
    if (itemIndex < 0 || itemIndex >= ingesta.items.length) return;
    final item = ingesta.items[itemIndex];

    Alimento? selectedAlimento;
    if (item.codigoAlimento != null) {
      final found = _alimentos.where((a) => a.codigo == item.codigoAlimento);
      if (found.isNotEmpty) {
        selectedAlimento = found.first;
      }
    }

    final descripcionCtrl = TextEditingController(
      text: item.descripcionManual ?? '',
    );
    final cantidadCtrl = TextEditingController(text: item.cantidad ?? '');
    final unidadCtrl = TextEditingController(text: item.unidad ?? '');
    final notasCtrl = TextEditingController(text: item.notas ?? '');
    bool opcion = (item.opcion ?? '') == 'S';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          title: Text(
            'Editar ${ingesta.tipoIngesta} de ${dia.nombreDia}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await _pickSingleAlimentoDialog(
                      selectedAlimento,
                    );
                    if (picked != null) {
                      setLocal(() {
                        selectedAlimento = picked;
                        if (descripcionCtrl.text.trim().isEmpty) {
                          descripcionCtrl.text = picked.nombre;
                        }
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Alimento del catálogo',
                      border: const OutlineInputBorder(),
                      suffixIcon: selectedAlimento != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setLocal(() {
                                selectedAlimento = null;
                              }),
                            )
                          : const Icon(Icons.search),
                    ),
                    child: Text(
                      selectedAlimento?.nombre ?? 'Toca para seleccionar...',
                      style: TextStyle(
                        color: selectedAlimento == null
                            ? Colors.grey.shade500
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descripcionCtrl,
                  minLines: 3,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción manual',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cantidadCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: unidadCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Unidad',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notasCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  value: opcion,
                  onChanged: (v) => setLocal(() => opcion = v),
                  title: const Text('Opción'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final descripcionFinal = descripcionCtrl.text.trim().isEmpty
        ? (selectedAlimento?.nombre.trim().isEmpty ?? true)
            ? null
            : selectedAlimento!.nombre.trim()
        : descripcionCtrl.text.trim();
    final normalizedName = (descripcionFinal ?? '').toLowerCase().trim();
    if (normalizedName.isEmpty) return;

    if (_ingestaHasDuplicateName(
      ingesta,
      normalizedName,
      ignoreIndex: itemIndex,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ese alimento ya existe en esta ingesta.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final beforeChange = _cloneEstructura(_estructura);
    setState(() {
      item.codigoAlimento = selectedAlimento?.codigo;
      item.alimentoNombre = selectedAlimento?.nombre ?? descripcionFinal;
      item.descripcionManual = descripcionFinal;
      item.cantidad =
          cantidadCtrl.text.trim().isEmpty ? null : cantidadCtrl.text.trim();
      item.unidad =
          unidadCtrl.text.trim().isEmpty ? null : unidadCtrl.text.trim();
      item.notas = notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim();
      item.opcion = opcion ? 'S' : 'N';
      _savingDrop = true;
      _lastSnapshot = beforeChange;
    });

    await _persistStructureChange(
      beforeChange: beforeChange,
      successMessage: 'Alimento actualizado',
    );
  }

  Future<void> _deleteIngestaItem({
    required int weekIndex,
    required int dayIndex,
    required int mealIndex,
    required int itemIndex,
  }) async {
    if (_savingDrop) return;
    if (weekIndex < 0 || weekIndex >= _estructura.semanas.length) return;
    final semana = _estructura.semanas[weekIndex];
    if (dayIndex < 0 || dayIndex >= semana.dias.length) return;
    final dia = semana.dias[dayIndex];
    if (mealIndex < 0 || mealIndex >= dia.ingestas.length) return;
    final ingesta = dia.ingestas[mealIndex];
    if (itemIndex < 0 || itemIndex >= ingesta.items.length) return;

    final itemName = _itemName(ingesta.items[itemIndex]);
    final confirmed = await _confirmDeleteItem(itemName);
    if (!confirmed) return;

    final beforeChange = _cloneEstructura(_estructura);
    setState(() {
      ingesta.items.removeAt(itemIndex);
      _reindexIngestaItems(ingesta);
      _savingDrop = true;
      _lastSnapshot = beforeChange;
    });

    await _persistStructureChange(
      beforeChange: beforeChange,
      successMessage: 'Alimento eliminado',
    );
  }

  Future<void> _copyIngestaItemToAnotherDay({
    required int weekIndex,
    required int dayIndex,
    required int mealIndex,
    required int itemIndex,
  }) async {
    if (_savingDrop) return;
    if (weekIndex < 0 || weekIndex >= _estructura.semanas.length) return;
    final semana = _estructura.semanas[weekIndex];
    if (dayIndex < 0 || dayIndex >= semana.dias.length) return;
    final dia = semana.dias[dayIndex];
    if (mealIndex < 0 || mealIndex >= dia.ingestas.length) return;
    final sourceIngesta = dia.ingestas[mealIndex];
    if (itemIndex < 0 || itemIndex >= sourceIngesta.items.length) return;
    final sourceItem = sourceIngesta.items[itemIndex];

    final destination = await _pickCopyItemDestination(
      sourceWeekIndex: weekIndex,
      sourceDayIndex: dayIndex,
      sourceMealType: sourceIngesta.tipoIngesta,
    );
    if (destination == null) return;

    final targetWeekIndex = destination['weekIndex']!;
    final targetDayIndex = destination['dayIndex']!;
    if (targetWeekIndex < 0 || targetWeekIndex >= _estructura.semanas.length) {
      return;
    }
    final targetSemana = _estructura.semanas[targetWeekIndex];
    if (targetDayIndex < 0 || targetDayIndex >= targetSemana.dias.length) {
      return;
    }
    final targetDia = targetSemana.dias[targetDayIndex];
    final beforeChange = _cloneEstructura(_estructura);
    var targetIngesta = targetDia.ingestas
        .where((i) => i.tipoIngesta == sourceIngesta.tipoIngesta)
        .firstOrNull;

    if (targetIngesta == null) {
      setState(() {
        targetDia.ingestas.add(
          PlanNutriIngesta(
            tipoIngesta: sourceIngesta.tipoIngesta,
            orden: targetDia.ingestas.length + 1,
          ),
        );
        _reindexDiaIngestas(targetDia);
      });
      targetIngesta = targetDia.ingestas
          .where((i) => i.tipoIngesta == sourceIngesta.tipoIngesta)
          .firstOrNull;
    }

    if (targetIngesta == null) return;

    final normalizedName = _normalizedItemName(sourceItem);
    if (_ingestaHasDuplicateName(targetIngesta, normalizedName)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ese alimento ya existe en la ingesta destino.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      targetIngesta!.items.add(_clonePlanItem(sourceItem));
      _reindexIngestaItems(targetIngesta);
      _savingDrop = true;
      _lastSnapshot = beforeChange;
      _expandedWeeks.add(targetWeekIndex);
      _expandedDays.add(_dayKey(targetWeekIndex, targetDayIndex));
      _expandedIngestas.add(_ingestaKey(
          targetWeekIndex, targetDayIndex, targetIngesta.orden - 1));
    });

    await _persistStructureChange(
      beforeChange: beforeChange,
      successMessage:
          'Alimento copiado a ${targetDia.nombreDia} · ${targetIngesta.tipoIngesta}',
    );
  }

  Future<void> _showItemActionsMenu({
    required int weekIndex,
    required int dayIndex,
    required int mealIndex,
    required int itemIndex,
  }) async {
    if (_savingDrop) return;
    if (weekIndex < 0 || weekIndex >= _estructura.semanas.length) return;
    final semana = _estructura.semanas[weekIndex];
    if (dayIndex < 0 || dayIndex >= semana.dias.length) return;
    final dia = semana.dias[dayIndex];
    if (mealIndex < 0 || mealIndex >= dia.ingestas.length) return;
    final ingesta = dia.ingestas[mealIndex];
    if (itemIndex < 0 || itemIndex >= ingesta.items.length) return;
    final item = ingesta.items[itemIndex];

    final action = await showModalBottomSheet<_QuickItemAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                _itemName(item),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('${dia.nombreDia} · ${ingesta.tipoIngesta}'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(context, _QuickItemAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Copiar'),
              subtitle:
                  const Text('A otro día de esta semana o de otra semana'),
              onTap: () => Navigator.pop(context, _QuickItemAction.copy),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(context, _QuickItemAction.delete),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;
    if (action == _QuickItemAction.edit) {
      await _editIngestaItem(
        weekIndex: weekIndex,
        dayIndex: dayIndex,
        mealIndex: mealIndex,
        itemIndex: itemIndex,
      );
    } else if (action == _QuickItemAction.delete) {
      await _deleteIngestaItem(
        weekIndex: weekIndex,
        dayIndex: dayIndex,
        mealIndex: mealIndex,
        itemIndex: itemIndex,
      );
    } else if (action == _QuickItemAction.copy) {
      await _copyIngestaItemToAnotherDay(
        weekIndex: weekIndex,
        dayIndex: dayIndex,
        mealIndex: mealIndex,
        itemIndex: itemIndex,
      );
    }
  }

  Widget _buildIngestaItemChip({
    required int weekIndex,
    required int dayIndex,
    required int mealIndex,
    required int itemIndex,
    required PlanNutriItem item,
    required _DraggedIngestaItemPayload payload,
    required bool hovering,
  }) {
    return Draggable<_DraggedIngestaItemPayload>(
      data: payload,
      feedback: _buildDragFeedback([
        Alimento(
          nombre: _itemName(item),
          activo: 1,
        ),
      ]),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: Chip(
          label: Text(_itemName(item)),
        ),
      ),
      child: GestureDetector(
        onTap: () => _showItemActionsMenu(
          weekIndex: weekIndex,
          dayIndex: dayIndex,
          mealIndex: mealIndex,
          itemIndex: itemIndex,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: hovering
                ? Border.all(
                    color: Colors.green,
                    width: 2,
                  )
                : null,
          ),
          child: Chip(
            label: Text(_itemName(item)),
          ),
        ),
      ),
    );
  }

  void _reindexIngestaItems(PlanNutriIngesta ingesta) {
    for (var i = 0; i < ingesta.items.length; i++) {
      ingesta.items[i].orden = i + 1;
    }
  }

  void _reindexDiaIngestas(PlanNutriDia dia) {
    for (var i = 0; i < dia.ingestas.length; i++) {
      dia.ingestas[i].orden = i + 1;
    }
  }

  Future<void> _removeItemFromIngestaToAlimentos(
    _DraggedIngestaItemPayload payload,
  ) async {
    if (_savingDrop) return;
    if (payload.weekIndex < 0 ||
        payload.weekIndex >= _estructura.semanas.length) {
      return;
    }
    final sourceSemana = _estructura.semanas[payload.weekIndex];
    if (payload.dayIndex < 0 || payload.dayIndex >= sourceSemana.dias.length) {
      return;
    }
    final sourceDia = sourceSemana.dias[payload.dayIndex];
    if (payload.mealIndex < 0 ||
        payload.mealIndex >= sourceDia.ingestas.length) {
      return;
    }
    final sourceIngesta = sourceDia.ingestas[payload.mealIndex];
    if (payload.itemIndex < 0 ||
        payload.itemIndex >= sourceIngesta.items.length) {
      return;
    }

    final beforeDrop = _cloneEstructura(_estructura);
    setState(() {
      sourceIngesta.items.removeAt(payload.itemIndex);
      _reindexIngestaItems(sourceIngesta);
      _savingDrop = true;
      _lastSnapshot = beforeDrop;
    });
    _persistDropWithRollback(beforeDrop: beforeDrop);
  }

  Future<bool> _confirmDeleteIngesta(PlanNutriIngesta ingesta) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar ingesta'),
        content: Text(
          '¿Quieres eliminar "${ingesta.tipoIngesta}" y todos sus alimentos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteIngesta({
    required int weekIndex,
    required int dayIndex,
    required int mealIndex,
  }) async {
    if (_savingDrop) return;
    if (weekIndex < 0 || weekIndex >= _estructura.semanas.length) return;
    final semana = _estructura.semanas[weekIndex];
    if (dayIndex < 0 || dayIndex >= semana.dias.length) return;
    final dia = semana.dias[dayIndex];
    if (mealIndex < 0 || mealIndex >= dia.ingestas.length) return;

    final beforeDrop = _cloneEstructura(_estructura);
    final dayPrefix = '$weekIndex-$dayIndex-';

    setState(() {
      dia.ingestas.removeAt(mealIndex);
      _reindexDiaIngestas(dia);
      _expandedIngestas.removeWhere((key) => key.startsWith(dayPrefix));
      _savingDrop = true;
      _lastSnapshot = beforeDrop;
    });

    _persistDropWithRollback(beforeDrop: beforeDrop);
  }

  Future<String?> _askMoveOrCopy(
    String itemName,
    String targetIngesta,
  ) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Mover o copiar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Cancelar',
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
              ),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: Text(
          '¿Quieres mover o copiar "$itemName" a "$targetIngesta"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'move'),
            child: const Text('Mover'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'copy'),
            child: const Text('Copiar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDropIngestaItem({
    required _DraggedIngestaItemPayload payload,
    required int targetWeekIndex,
    required int targetDayIndex,
    required int targetMealIndex,
    required int targetInsertIndex,
  }) async {
    if (_savingDrop) return;
    if (targetWeekIndex < 0 || targetWeekIndex >= _estructura.semanas.length) {
      return;
    }
    final targetSemana = _estructura.semanas[targetWeekIndex];
    if (targetDayIndex < 0 || targetDayIndex >= targetSemana.dias.length) {
      return;
    }
    final targetDia = targetSemana.dias[targetDayIndex];
    if (targetMealIndex < 0 || targetMealIndex >= targetDia.ingestas.length) {
      return;
    }

    if (payload.weekIndex < 0 ||
        payload.weekIndex >= _estructura.semanas.length) {
      return;
    }
    final sourceSemana = _estructura.semanas[payload.weekIndex];
    if (payload.dayIndex < 0 || payload.dayIndex >= sourceSemana.dias.length) {
      return;
    }
    final sourceDia = sourceSemana.dias[payload.dayIndex];
    if (payload.mealIndex < 0 ||
        payload.mealIndex >= sourceDia.ingestas.length) {
      return;
    }
    final sourceIngesta = sourceDia.ingestas[payload.mealIndex];
    if (payload.itemIndex < 0 ||
        payload.itemIndex >= sourceIngesta.items.length) {
      return;
    }

    final sameIngesta = payload.weekIndex == targetWeekIndex &&
        payload.dayIndex == targetDayIndex &&
        payload.mealIndex == targetMealIndex;

    final targetIngesta = targetDia.ingestas[targetMealIndex];

    if (sameIngesta) {
      if (targetInsertIndex < 0 ||
          targetInsertIndex > sourceIngesta.items.length) {
        return;
      }

      final beforeDrop = _cloneEstructura(_estructura);

      setState(() {
        final movedItem = sourceIngesta.items.removeAt(payload.itemIndex);
        var insertAt = targetInsertIndex;
        if (insertAt > payload.itemIndex) {
          insertAt--;
        }
        if (insertAt < 0) insertAt = 0;
        if (insertAt > sourceIngesta.items.length) {
          insertAt = sourceIngesta.items.length;
        }
        sourceIngesta.items.insert(insertAt, movedItem);
        _reindexIngestaItems(sourceIngesta);
        _savingDrop = true;
        _lastSnapshot = beforeDrop;
      });

      _persistDropWithRollback(beforeDrop: beforeDrop);
      return;
    }

    final sourceItem = sourceIngesta.items[payload.itemIndex];
    final normalizedName = _normalizedItemName(sourceItem);
    if (_ingestaHasDuplicateName(targetIngesta, normalizedName)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ese alimento ya existe en la ingesta destino.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final action =
        await _askMoveOrCopy(_itemName(sourceItem), targetIngesta.tipoIngesta);
    if (action == null) return;

    final beforeDrop = _cloneEstructura(_estructura);
    setState(() {
      final destination = _estructura.semanas[targetWeekIndex]
          .dias[targetDayIndex].ingestas[targetMealIndex];
      var insertAt = targetInsertIndex;
      if (insertAt < 0) insertAt = 0;
      if (insertAt > destination.items.length) {
        insertAt = destination.items.length;
      }

      if (action == 'move') {
        final src = _estructura.semanas[payload.weekIndex]
            .dias[payload.dayIndex].ingestas[payload.mealIndex];
        if (payload.itemIndex >= 0 && payload.itemIndex < src.items.length) {
          final moved = src.items.removeAt(payload.itemIndex);
          destination.items.insert(insertAt, moved);
          _reindexIngestaItems(src);
          _reindexIngestaItems(destination);
        }
      } else {
        destination.items.insert(insertAt, _clonePlanItem(sourceItem));
        _reindexIngestaItems(destination);
      }

      _savingDrop = true;
      _lastSnapshot = beforeDrop;
      _expandedWeeks.add(targetWeekIndex);
      _expandedDays.add(_dayKey(targetWeekIndex, targetDayIndex));
      _expandedIngestas
          .add(_ingestaKey(targetWeekIndex, targetDayIndex, targetMealIndex));
    });

    _persistDropWithRollback(beforeDrop: beforeDrop);
  }

  Widget _buildDragFeedback(List<Alimento> alimentos) {
    final text = alimentos.length == 1
        ? alimentos.first.nombre
        : '${alimentos.length} alimentos';
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade700,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(blurRadius: 8, color: Colors.black26),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _toggleSelect(Alimento alimento, bool selected) {
    final codigo = alimento.codigo;
    if (codigo == null) return;
    setState(() {
      if (selected) {
        _selectedCodigos.add(codigo);
      } else {
        _selectedCodigos.remove(codigo);
      }
    });
  }

  bool _addAlimentosToIngesta({
    required int weekIndex,
    required int dayIndex,
    required int mealIndex,
    required List<Alimento> alimentos,
  }) {
    if (weekIndex < 0 || weekIndex >= _estructura.semanas.length) return false;
    final semana = _estructura.semanas[weekIndex];
    if (dayIndex < 0 || dayIndex >= semana.dias.length) return false;
    final dia = semana.dias[dayIndex];
    if (mealIndex < 0 || mealIndex >= dia.ingestas.length) return false;

    final ingesta = dia.ingestas[mealIndex];
    final existingCodigos = ingesta.items
        .map((item) => item.codigoAlimento)
        .whereType<int>()
        .toSet();

    var added = 0;
    for (final alimento in alimentos) {
      final codigo = alimento.codigo;
      if (codigo == null) continue;
      if (existingCodigos.contains(codigo)) continue;

      ingesta.items.add(
        PlanNutriItem(
          codigoAlimento: codigo,
          alimentoNombre: alimento.nombre,
          descripcionManual: alimento.nombre,
          orden: ingesta.items.length + 1,
        ),
      );
      existingCodigos.add(codigo);
      added++;
    }

    return added > 0;
  }

  void _toggleWeek(int weekIndex) {
    setState(() {
      if (_expandedWeeks.contains(weekIndex)) {
        _expandedWeeks.remove(weekIndex);
      } else {
        _expandedWeeks.add(weekIndex);
      }
    });
  }

  void _toggleDay(int weekIndex, int dayIndex) {
    final key = _dayKey(weekIndex, dayIndex);
    setState(() {
      if (_expandedDays.contains(key)) {
        _expandedDays.remove(key);
      } else {
        _expandedWeeks.add(weekIndex);
        _expandedDays.add(key);
      }
    });
  }

  void _toggleIngesta(int weekIndex, int dayIndex, int mealIndex) {
    final key = _ingestaKey(weekIndex, dayIndex, mealIndex);
    setState(() {
      if (_expandedIngestas.contains(key)) {
        _expandedIngestas.remove(key);
      } else {
        _expandedWeeks.add(weekIndex);
        _expandedDays.add(_dayKey(weekIndex, dayIndex));
        _expandedIngestas.add(key);
      }
    });
  }

  int _daysWithFoodsForWeek(PlanNutriSemana semana) {
    return semana.dias
        .where((dia) => dia.ingestas.any((ingesta) => ingesta.items.isNotEmpty))
        .length;
  }

  int _ingestasWithFoodsForDay(PlanNutriDia dia) {
    return dia.ingestas.where((ingesta) => ingesta.items.isNotEmpty).length;
  }

  Widget _countBadge({
    required int count,
    required Color color,
  }) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _ratioTag({required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.blueGrey.shade800,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _compactDayLabel(String dayName) {
    switch (dayName.trim().toLowerCase()) {
      case 'lunes':
        return 'L';
      case 'martes':
        return 'M';
      case 'miércoles':
      case 'miercoles':
        return 'X';
      case 'jueves':
        return 'J';
      case 'viernes':
        return 'V';
      case 'sábado':
      case 'sabado':
        return 'S';
      case 'domingo':
        return 'D';
      default:
        return dayName.isEmpty ? '?' : dayName.characters.first.toUpperCase();
    }
  }

  void _ensureCompactSelection(List<MapEntry<int, PlanNutriSemana>> weeks) {
    if (weeks.isEmpty) {
      _compactWeekIndex = null;
      _compactDayIndex = null;
      return;
    }

    if (_focusMode) {
      _compactWeekIndex = widget.focusWeekIndex;
      _compactDayIndex = widget.focusDayIndex;
      return;
    }

    final validWeek = weeks.any((w) => w.key == _compactWeekIndex);
    if (!validWeek) {
      _compactWeekIndex = weeks.first.key;
      _compactDayIndex = 0;
      return;
    }

    final selectedWeek = weeks.firstWhere((w) => w.key == _compactWeekIndex);
    final maxDay = selectedWeek.value.dias.length - 1;
    if (_compactDayIndex == null ||
        _compactDayIndex! < 0 ||
        _compactDayIndex! > maxDay) {
      _compactDayIndex = maxDay >= 0 ? 0 : null;
    }
  }

  void _selectCompactWeek(int weekIndex) {
    setState(() {
      _compactWeekIndex = weekIndex;
      _compactDayIndex = 0;
    });
    unawaited(_persistCompactSelection());
  }

  void _selectCompactDay(int dayIndex) {
    setState(() {
      _compactDayIndex = dayIndex;
    });
    unawaited(_persistCompactSelection());
  }

  Widget _buildCompactIngestaCard({
    required int weekIndex,
    required int dayIndex,
    required String dayKey,
    required PlanNutriIngesta ingesta,
    required int mealIndex,
  }) {
    final ingestaKey = _ingestaKey(weekIndex, dayIndex, mealIndex);
    final ingestaExpanded =
        _focusMode ? true : _expandedIngestas.contains(ingestaKey);

    final dismissKey = ValueKey(
      'compact-$weekIndex-$dayIndex-$mealIndex-${ingesta.tipoIngesta}',
    );

    return DragTarget<_DraggedAlimentosPayload>(
      onWillAcceptWithDetails: (_) => !_savingDrop,
      onAcceptWithDetails: (details) {
        if (_savingDrop) {
          return;
        }
        final beforeDrop = _cloneEstructura(_estructura);
        final added = _addAlimentosToIngesta(
          weekIndex: weekIndex,
          dayIndex: dayIndex,
          mealIndex: mealIndex,
          alimentos: details.data.alimentos,
        );
        if (!added) {
          return;
        }
        setState(() {
          _savingDrop = true;
          _lastSnapshot = beforeDrop;
          _expandedWeeks.add(weekIndex);
          _expandedDays.add(dayKey);
          _expandedIngestas.add(ingestaKey);
        });
        _persistDropWithRollback(beforeDrop: beforeDrop);
      },
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;

        return Dismissible(
          key: dismissKey,
          direction: DismissDirection.startToEnd,
          confirmDismiss: (_) => _confirmDeleteIngesta(ingesta),
          onDismissed: (_) {
            _deleteIngesta(
              weekIndex: weekIndex,
              dayIndex: dayIndex,
              mealIndex: mealIndex,
            );
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Eliminar ingesta',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hovering ? Colors.green : Colors.grey.shade300,
                width: hovering ? 2 : 1,
              ),
              color: hovering ? Colors.green.withAlpha(22) : null,
            ),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  visualDensity:
                      const VisualDensity(horizontal: 0, vertical: -2),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  title: Text(
                    ingesta.tipoIngesta,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _countBadge(
                        count: ingesta.items.length,
                        color: ingesta.items.isEmpty
                            ? Colors.grey.shade500
                            : Colors.green.shade600,
                      ),
                      if (!_focusMode) const SizedBox(width: 6),
                      if (!_focusMode)
                        Icon(
                          ingestaExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                    ],
                  ),
                  onTap: _focusMode
                      ? null
                      : () => _toggleIngesta(
                            weekIndex,
                            dayIndex,
                            mealIndex,
                          ),
                ),
                if (ingestaExpanded)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: 10,
                    ),
                    child: DragTarget<_DraggedIngestaItemPayload>(
                      onWillAcceptWithDetails: (_) => !_savingDrop,
                      onAcceptWithDetails: (details) {
                        _handleDropIngestaItem(
                          payload: details.data,
                          targetWeekIndex: weekIndex,
                          targetDayIndex: dayIndex,
                          targetMealIndex: mealIndex,
                          targetInsertIndex: ingesta.items.length,
                        );
                      },
                      builder: (context, endCandidate, _) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: double.infinity,
                            decoration: endCandidate.isNotEmpty
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green,
                                      width: 1.5,
                                    ),
                                    color: Colors.green.withAlpha(14),
                                  )
                                : null,
                            padding: endCandidate.isNotEmpty
                                ? const EdgeInsets.all(4)
                                : EdgeInsets.zero,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ...List.generate(
                                  ingesta.items.length,
                                  (itemIndex) {
                                    final item = ingesta.items[itemIndex];
                                    final payload = _DraggedIngestaItemPayload(
                                      weekIndex: weekIndex,
                                      dayIndex: dayIndex,
                                      mealIndex: mealIndex,
                                      itemIndex: itemIndex,
                                      item: _clonePlanItem(item),
                                    );
                                    return DragTarget<
                                        _DraggedIngestaItemPayload>(
                                      onWillAcceptWithDetails: (_) =>
                                          !_savingDrop,
                                      onAcceptWithDetails: (details) {
                                        _handleDropIngestaItem(
                                          payload: details.data,
                                          targetWeekIndex: weekIndex,
                                          targetDayIndex: dayIndex,
                                          targetMealIndex: mealIndex,
                                          targetInsertIndex: itemIndex,
                                        );
                                      },
                                      builder: (context, candidate, _) {
                                        final hovering = candidate.isNotEmpty;
                                        return _buildIngestaItemChip(
                                          weekIndex: weekIndex,
                                          dayIndex: dayIndex,
                                          mealIndex: mealIndex,
                                          itemIndex: itemIndex,
                                          item: item,
                                          payload: payload,
                                          hovering: hovering,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
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
  }

  Widget _buildCompactTargetView(
    List<MapEntry<int, PlanNutriSemana>> semanasDestino,
  ) {
    _ensureCompactSelection(semanasDestino);
    if (semanasDestino.isEmpty) {
      return const Center(child: Text('No hay semanas disponibles.'));
    }

    final compactWeek = semanasDestino.firstWhere(
      (entry) => entry.key == _compactWeekIndex,
      orElse: () => semanasDestino.first,
    );
    final compactSemana = compactWeek.value;
    final hasDays = compactSemana.dias.isNotEmpty;
    final compactDayIdx = hasDays
        ? (_compactDayIndex ?? 0).clamp(0, compactSemana.dias.length - 1)
        : null;
    final compactDia = hasDays ? compactSemana.dias[compactDayIdx!] : null;
    final compactDayKey =
        compactDayIdx == null ? null : _dayKey(compactWeek.key, compactDayIdx);

    Widget buildWeekTag({
      required int weekIdx,
      required PlanNutriSemana semana,
    }) {
      final selected = _compactWeekIndex == weekIdx;
      final weekDaysWithFoods = _daysWithFoodsForWeek(semana);
      final weekTotalDays = semana.dias.length;
      final weekComplete =
          weekTotalDays > 0 && weekDaysWithFoods == weekTotalDays;
      final baseColor = weekComplete ? Colors.green : Colors.red;

      return InkWell(
        onTap: _focusMode ? null : () => _selectCompactWeek(weekIdx),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: baseColor.withAlpha(selected ? 40 : 16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? Theme.of(context).colorScheme.primary : baseColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            'S${semana.numeroSemana}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: weekComplete ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ),
      );
    }

    Widget buildDayTag({
      required int dayIdx,
      required PlanNutriDia dia,
    }) {
      final selected = compactDayIdx == dayIdx;
      final ingestasWithFoods = _ingestasWithFoodsForDay(dia);
      final totalIngestas = dia.ingestas.length;
      final dayComplete =
          totalIngestas > 0 && ingestasWithFoods == totalIngestas;
      final baseColor = dayComplete ? Colors.green : Colors.red;

      return InkWell(
        onTap: _focusMode ? null : () => _selectCompactDay(dayIdx),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: baseColor.withAlpha(selected ? 40 : 16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? Theme.of(context).colorScheme.primary : baseColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            _compactDayLabel(dia.nombreDia),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: dayComplete ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ),
      );
    }

    return ListView(
      controller: _weeksScrollController,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...semanasDestino
                .map((entry) => buildWeekTag(
                      weekIdx: entry.key,
                      semana: entry.value,
                    ))
                .toList(),
            if (compactDia != null) const SizedBox(width: 8),
            if (compactDia != null)
              ...compactSemana.dias
                  .asMap()
                  .entries
                  .map((entry) =>
                      buildDayTag(dayIdx: entry.key, dia: entry.value))
                  .toList(),
          ],
        ),
        const SizedBox(height: 10),
        if (compactDia == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('La semana seleccionada no tiene días.'),
          )
        else
          ...compactDia.ingestas.asMap().entries.map((entry) {
            return _buildCompactIngestaCard(
              weekIndex: compactWeek.key,
              dayIndex: compactDayIdx!,
              dayKey: compactDayKey!,
              ingesta: entry.value,
              mealIndex: entry.key,
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final alimentosFiltrados = _alimentosFiltrados;
    final semanasDestino = _focusMode
        ? _estructura.semanas
            .asMap()
            .entries
            .where((entry) => entry.key == widget.focusWeekIndex)
            .toList()
        : _estructura.semanas
            .asMap()
            .entries
            .where((entry) => !_isSemanaCompleted(entry.value))
            .toList();
    final selectedCount = _selectedCodigos.length;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estructurar rápido')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estructurar rápido')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _loadError = null;
                    });
                    _loadData();
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_estructura);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            (() {
              String? dayName;
              if (_focusMode) {
                final weekIndex = widget.focusWeekIndex!;
                final dayIndex = widget.focusDayIndex!;
                if (weekIndex >= 0 && weekIndex < _estructura.semanas.length) {
                  final semana = _estructura.semanas[weekIndex];
                  if (dayIndex >= 0 && dayIndex < semana.dias.length) {
                    dayName = semana.dias[dayIndex].nombreDia;
                  }
                }
              }
              dayName ??= _estructura.semanas.isNotEmpty &&
                      _estructura.semanas.first.dias.isNotEmpty
                  ? _estructura.semanas.first.dias.first.nombreDia
                  : null;
              return dayName == null
                  ? 'Estructurar plan'
                  : 'Estructurar plan - $dayName';
            })(),
          ),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _countBadge(
                  count: selectedCount,
                  color: selectedCount > 0
                      ? Colors.blue.shade700
                      : Colors.grey.shade500,
                ),
              ),
            ),
            IconButton(
              tooltip: _showFilters
                  ? 'Ocultar buscar y filtros'
                  : 'Mostrar buscar y filtros',
              onPressed: () {
                _setShowFilters(!_showFilters);
              },
              icon: Icon(
                _showFilters ? Icons.filter_alt_off : Icons.filter_alt,
              ),
            ),
            if (_selectedCodigos.isNotEmpty)
              IconButton(
                tooltip: 'Limpiar selección',
                onPressed: () {
                  setState(() {
                    _selectedCodigos.clear();
                  });
                },
                icon: const Icon(Icons.clear_all),
              ),
            IconButton(
              tooltip: 'Deshacer último arrastre',
              onPressed:
                  _lastSnapshot == null || _savingDrop ? null : _undoLastDrop,
              icon: const Icon(Icons.undo),
            ),
            if (widget.onSwitchToNormal != null)
              IconButton(
                tooltip: 'Estructurar plan normal',
                icon: const Icon(Icons.table_chart_outlined),
                onPressed: widget.onSwitchToNormal,
              ),
            IconButton(
              tooltip: 'Aplicar cambios',
              icon: const Icon(Icons.check),
              onPressed: () => Navigator.of(context).pop(_estructura),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const splitterHeight = 14.0;
              const minPaneHeight = 170.0;
              final availableHeight = (constraints.maxHeight - splitterHeight)
                  .clamp(0.0, double.infinity);
              var minRatio = availableHeight <= 0
                  ? 0.15
                  : (minPaneHeight / availableHeight).clamp(0.15, 0.85);
              var maxRatio = (1 - minRatio).clamp(0.15, 0.85);
              if (maxRatio < minRatio) {
                minRatio = 0.5;
                maxRatio = 0.5;
              }
              final effectiveRatio = _topPaneRatio.clamp(minRatio, maxRatio);
              final topPaneHeight = availableHeight * effectiveRatio;
              final bottomPaneHeight = availableHeight - topPaneHeight;

              return Column(
                children: [
                  SizedBox(
                    height: topPaneHeight,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_showFilters) ...[
                            const SizedBox(height: 6),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isMobile = constraints.maxWidth < 600;
                                if (isMobile) {
                                  // Mobile layout: search + add on first line, filter on second
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Search + Add button row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _searchCtrl,
                                              decoration: InputDecoration(
                                                labelText: 'Buscar alimento',
                                                border:
                                                    const OutlineInputBorder(),
                                                isDense: true,
                                                prefixIcon: IconButton(
                                                  tooltip: _search.isNotEmpty
                                                      ? 'Borrar búsqueda'
                                                      : 'Buscar',
                                                  onPressed: _search.isNotEmpty
                                                      ? _clearSearch
                                                      : null,
                                                  icon: Icon(
                                                    _search.isNotEmpty
                                                        ? Icons.clear
                                                        : Icons.search,
                                                  ),
                                                ),
                                              ),
                                              onChanged: (value) {
                                                setState(() {
                                                  _search = value;
                                                });
                                              },
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Añadir nuevo alimento',
                                            onPressed: _showAddAlimentoDialog,
                                            icon: const Icon(
                                                Icons.add_circle_outline),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Filter button row
                                      OutlinedButton.icon(
                                        onPressed: _pickGruposFiltro,
                                        icon: const Icon(Icons.filter_list),
                                        label: Text(
                                          _gruposFiltroLabel(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  // Desktop layout: all on one row
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _searchCtrl,
                                          decoration: InputDecoration(
                                            labelText: 'Buscar alimento',
                                            border: const OutlineInputBorder(),
                                            isDense: true,
                                            prefixIcon: IconButton(
                                              tooltip: _search.isNotEmpty
                                                  ? 'Borrar búsqueda'
                                                  : 'Buscar',
                                              onPressed: _search.isNotEmpty
                                                  ? _clearSearch
                                                  : null,
                                              icon: Icon(
                                                _search.isNotEmpty
                                                    ? Icons.clear
                                                    : Icons.search,
                                              ),
                                            ),
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              _search = value;
                                            });
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Añadir nuevo alimento',
                                        onPressed: _showAddAlimentoDialog,
                                        icon: const Icon(
                                            Icons.add_circle_outline),
                                      ),
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        width: 250,
                                        child: OutlinedButton.icon(
                                          onPressed: _pickGruposFiltro,
                                          icon: const Icon(Icons.filter_list),
                                          label: Text(
                                            _gruposFiltroLabel(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 6),
                          Expanded(
                            child: DragTarget<_DraggedIngestaItemPayload>(
                              onWillAcceptWithDetails: (_) => !_savingDrop,
                              onAcceptWithDetails: (details) {
                                _removeItemFromIngestaToAlimentos(details.data);
                              },
                              builder: (context, candidate, _) {
                                final hovering = candidate.isNotEmpty;
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: hovering
                                        ? Border.all(
                                            color: Colors.red.shade400,
                                            width: 2,
                                          )
                                        : null,
                                    color: hovering
                                        ? Colors.red.withAlpha(16)
                                        : null,
                                  ),
                                  child: alimentosFiltrados.isEmpty
                                      ? const Center(
                                          child: Text(
                                              'No hay alimentos con ese filtro.'),
                                        )
                                      : ListView.separated(
                                          itemCount: alimentosFiltrados.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final alimento =
                                                alimentosFiltrados[index];
                                            final codigo =
                                                alimento.codigo ?? -1;
                                            final selected = _selectedCodigos
                                                .contains(codigo);
                                            final payload =
                                                _payloadForAlimento(alimento);

                                            return LongPressDraggable<
                                                _DraggedAlimentosPayload>(
                                              data: payload,
                                              feedback: _buildDragFeedback(
                                                  payload.alimentos),
                                              onDragEnd: (_) =>
                                                  _stopAutoScroll(),
                                              childWhenDragging: Opacity(
                                                opacity: 0.4,
                                                child: _alimentoTile(
                                                  alimento,
                                                  selected,
                                                ),
                                              ),
                                              child: _alimentoTile(
                                                alimento,
                                                selected,
                                              ),
                                            );
                                          },
                                        ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        if (availableHeight <= 0) return;
                        final deltaRatio = details.delta.dy / availableHeight;
                        setState(() {
                          _topPaneRatio = (_topPaneRatio + deltaRatio)
                              .clamp(minRatio, maxRatio);
                        });
                      },
                      onVerticalDragEnd: (_) {
                        _persistSplitterRatio();
                      },
                      onVerticalDragCancel: _persistSplitterRatio,
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
                    height: bottomPaneHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Destino',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Tooltip(
                                message: _detailedWeekView
                                    ? 'Vista detallada activa'
                                    : 'Vista compacta activa',
                                child: IconButton(
                                  icon: Icon(
                                    _detailedWeekView
                                        ? Icons.view_agenda_outlined
                                        : Icons.view_week_outlined,
                                  ),
                                  onPressed: _toggleDetailedWeekView,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _detailedWeekView
                                ? Stack(
                                    children: [
                                      ListView.builder(
                                        controller: _weeksScrollController,
                                        itemCount: semanasDestino.length,
                                        itemBuilder: (context, weekIndex) {
                                          final semanaEntry =
                                              semanasDestino[weekIndex];
                                          final originalWeekIndex =
                                              semanaEntry.key;
                                          final semana = semanaEntry.value;
                                          final weekExpanded = _focusMode
                                              ? true
                                              : _expandedWeeks.contains(
                                                  originalWeekIndex,
                                                );

                                          return Card(
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            child: Column(
                                              children: [
                                                DragTarget<
                                                    _DraggedAlimentosPayload>(
                                                  onMove: (_) =>
                                                      _scheduleExpandWeek(
                                                          originalWeekIndex),
                                                  onLeave: (_) =>
                                                      _cancelExpandWeek(
                                                          originalWeekIndex),
                                                  builder: (context, _, __) {
                                                    final weekDaysWithFoods =
                                                        _daysWithFoodsForWeek(
                                                            semana);
                                                    final weekTotalDays =
                                                        semana.dias.length;

                                                    return ListTile(
                                                      dense: true,
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 12,
                                                        vertical: 0,
                                                      ),
                                                      title: Text(
                                                        'Semana ${semana.numeroSemana}',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      trailing: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          _ratioTag(
                                                            text:
                                                                '$weekDaysWithFoods/$weekTotalDays',
                                                          ),
                                                          if (!_focusMode)
                                                            const SizedBox(
                                                                width: 6),
                                                          if (!_focusMode)
                                                            Icon(
                                                              weekExpanded
                                                                  ? Icons
                                                                      .expand_less
                                                                  : Icons
                                                                      .expand_more,
                                                            ),
                                                        ],
                                                      ),
                                                      onTap: _focusMode
                                                          ? null
                                                          : () => _toggleWeek(
                                                                originalWeekIndex,
                                                              ),
                                                    );
                                                  },
                                                ),
                                                if (weekExpanded)
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(
                                                      8,
                                                      0,
                                                      8,
                                                      8,
                                                    ),
                                                    child: Column(
                                                      children: (_focusMode
                                                              ? <int>[
                                                                  widget
                                                                      .focusDayIndex!
                                                                ]
                                                              : List<
                                                                  int>.generate(
                                                                  semana.dias
                                                                      .length,
                                                                  (index) =>
                                                                      index,
                                                                ))
                                                          .where(
                                                        (dayIndex) =>
                                                            dayIndex >= 0 &&
                                                            dayIndex <
                                                                semana.dias
                                                                    .length,
                                                      )
                                                          .map((dayIndex) {
                                                        final dia = semana
                                                            .dias[dayIndex];
                                                        final dayKey = _dayKey(
                                                            originalWeekIndex,
                                                            dayIndex);
                                                        final dayExpanded =
                                                            _focusMode
                                                                ? true
                                                                : _expandedDays
                                                                    .contains(
                                                                    dayKey,
                                                                  );

                                                        return Card(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                            bottom: 6,
                                                          ),
                                                          child: Column(
                                                            children: [
                                                              DragTarget<
                                                                  _DraggedAlimentosPayload>(
                                                                onMove: (_) =>
                                                                    _scheduleExpandDay(
                                                                  originalWeekIndex,
                                                                  dayIndex,
                                                                ),
                                                                onLeave: (_) =>
                                                                    _cancelExpandDay(
                                                                  originalWeekIndex,
                                                                  dayIndex,
                                                                ),
                                                                builder:
                                                                    (context, _,
                                                                        __) {
                                                                  final dayIngestasTotal = dia
                                                                      .ingestas
                                                                      .length;
                                                                  final dayIngestasWithFoods =
                                                                      _ingestasWithFoodsForDay(
                                                                    dia,
                                                                  );

                                                                  return ListTile(
                                                                    dense: true,
                                                                    visualDensity:
                                                                        VisualDensity
                                                                            .compact,
                                                                    contentPadding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          0,
                                                                    ),
                                                                    title: Text(
                                                                        dia.nombreDia),
                                                                    trailing:
                                                                        Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        _ratioTag(
                                                                          text:
                                                                              '$dayIngestasWithFoods/$dayIngestasTotal',
                                                                        ),
                                                                        if (!_focusMode)
                                                                          const SizedBox(
                                                                              width: 6),
                                                                        if (!_focusMode)
                                                                          Icon(
                                                                            dayExpanded
                                                                                ? Icons.expand_less
                                                                                : Icons.expand_more,
                                                                          ),
                                                                      ],
                                                                    ),
                                                                    onTap: _focusMode
                                                                        ? null
                                                                        : () => _toggleDay(
                                                                              originalWeekIndex,
                                                                              dayIndex,
                                                                            ),
                                                                  );
                                                                },
                                                              ),
                                                              if (dayExpanded)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .only(
                                                                    left: 8,
                                                                    right: 8,
                                                                    bottom: 8,
                                                                  ),
                                                                  child: Column(
                                                                    children: List
                                                                        .generate(
                                                                      dia.ingestas
                                                                          .length,
                                                                      (mealIndex) {
                                                                        final ingesta =
                                                                            dia.ingestas[mealIndex];
                                                                        final ingestaKey =
                                                                            _ingestaKey(
                                                                          originalWeekIndex,
                                                                          dayIndex,
                                                                          mealIndex,
                                                                        );
                                                                        final ingestaExpanded = _focusMode
                                                                            ? true
                                                                            : _expandedIngestas.contains(
                                                                                ingestaKey,
                                                                              );

                                                                        final dismissKey =
                                                                            ValueKey(
                                                                          'detail-$originalWeekIndex-$dayIndex-$mealIndex-${ingesta.tipoIngesta}',
                                                                        );

                                                                        return DragTarget<
                                                                            _DraggedAlimentosPayload>(
                                                                          onWillAcceptWithDetails: (_) =>
                                                                              !_savingDrop,
                                                                          onAcceptWithDetails:
                                                                              (details) {
                                                                            if (_savingDrop) {
                                                                              return;
                                                                            }
                                                                            final beforeDrop =
                                                                                _cloneEstructura(
                                                                              _estructura,
                                                                            );
                                                                            final added =
                                                                                _addAlimentosToIngesta(
                                                                              weekIndex: originalWeekIndex,
                                                                              dayIndex: dayIndex,
                                                                              mealIndex: mealIndex,
                                                                              alimentos: details.data.alimentos,
                                                                            );
                                                                            if (!added) {
                                                                              return;
                                                                            }
                                                                            setState(() {
                                                                              _savingDrop = true;
                                                                              _lastSnapshot = beforeDrop;
                                                                              _expandedWeeks.add(
                                                                                originalWeekIndex,
                                                                              );
                                                                              _expandedDays.add(
                                                                                dayKey,
                                                                              );
                                                                              _expandedIngestas.add(
                                                                                ingestaKey,
                                                                              );
                                                                            });
                                                                            _persistDropWithRollback(
                                                                              beforeDrop: beforeDrop,
                                                                            );
                                                                          },
                                                                          builder: (context,
                                                                              candidate,
                                                                              _) {
                                                                            final hovering =
                                                                                candidate.isNotEmpty;

                                                                            return Dismissible(
                                                                              key: dismissKey,
                                                                              direction: DismissDirection.startToEnd,
                                                                              confirmDismiss: (_) => _confirmDeleteIngesta(
                                                                                ingesta,
                                                                              ),
                                                                              onDismissed: (_) {
                                                                                _deleteIngesta(
                                                                                  weekIndex: originalWeekIndex,
                                                                                  dayIndex: dayIndex,
                                                                                  mealIndex: mealIndex,
                                                                                );
                                                                              },
                                                                              background: Container(
                                                                                margin: const EdgeInsets.only(
                                                                                  bottom: 6,
                                                                                ),
                                                                                decoration: BoxDecoration(
                                                                                  color: Colors.red.shade400,
                                                                                  borderRadius: BorderRadius.circular(
                                                                                    8,
                                                                                  ),
                                                                                ),
                                                                                alignment: Alignment.centerLeft,
                                                                                padding: const EdgeInsets.symmetric(
                                                                                  horizontal: 16,
                                                                                ),
                                                                                child: const Row(
                                                                                  children: [
                                                                                    Icon(
                                                                                      Icons.delete_outline,
                                                                                      color: Colors.white,
                                                                                    ),
                                                                                    SizedBox(width: 8),
                                                                                    Text(
                                                                                      'Eliminar ingesta',
                                                                                      style: TextStyle(
                                                                                        color: Colors.white,
                                                                                        fontWeight: FontWeight.w600,
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                              child: Container(
                                                                                margin: const EdgeInsets.only(
                                                                                  bottom: 6,
                                                                                ),
                                                                                decoration: BoxDecoration(
                                                                                  borderRadius: BorderRadius.circular(
                                                                                    8,
                                                                                  ),
                                                                                  border: Border.all(
                                                                                    color: hovering ? Colors.green : Colors.grey.shade300,
                                                                                    width: hovering ? 2 : 1,
                                                                                  ),
                                                                                  color: hovering
                                                                                      ? Colors.green.withAlpha(
                                                                                          22,
                                                                                        )
                                                                                      : null,
                                                                                ),
                                                                                child: Column(
                                                                                  children: [
                                                                                    ListTile(
                                                                                      dense: true,
                                                                                      visualDensity: VisualDensity.compact,
                                                                                      contentPadding: const EdgeInsets.symmetric(
                                                                                        horizontal: 12,
                                                                                        vertical: 0,
                                                                                      ),
                                                                                      title: Text(
                                                                                        ingesta.tipoIngesta,
                                                                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                                                                      ),
                                                                                      trailing: Row(
                                                                                        mainAxisSize: MainAxisSize.min,
                                                                                        children: [
                                                                                          _countBadge(
                                                                                            count: ingesta.items.length,
                                                                                            color: ingesta.items.isEmpty ? Colors.grey.shade500 : Colors.green.shade600,
                                                                                          ),
                                                                                          if (!_focusMode) const SizedBox(width: 6),
                                                                                          if (!_focusMode)
                                                                                            Icon(
                                                                                              ingestaExpanded ? Icons.expand_less : Icons.expand_more,
                                                                                            ),
                                                                                        ],
                                                                                      ),
                                                                                      onTap: _focusMode
                                                                                          ? null
                                                                                          : () => _toggleIngesta(
                                                                                                originalWeekIndex,
                                                                                                dayIndex,
                                                                                                mealIndex,
                                                                                              ),
                                                                                    ),
                                                                                    if (ingestaExpanded)
                                                                                      Padding(
                                                                                        padding: const EdgeInsets.only(
                                                                                          left: 12,
                                                                                          right: 12,
                                                                                          bottom: 10,
                                                                                        ),
                                                                                        child: DragTarget<_DraggedIngestaItemPayload>(
                                                                                          onWillAcceptWithDetails: (_) => !_savingDrop,
                                                                                          onAcceptWithDetails: (details) {
                                                                                            _handleDropIngestaItem(
                                                                                              payload: details.data,
                                                                                              targetWeekIndex: originalWeekIndex,
                                                                                              targetDayIndex: dayIndex,
                                                                                              targetMealIndex: mealIndex,
                                                                                              targetInsertIndex: ingesta.items.length,
                                                                                            );
                                                                                          },
                                                                                          builder: (context, endCandidate, _) {
                                                                                            return Align(
                                                                                              alignment: Alignment.centerLeft,
                                                                                              child: Container(
                                                                                                width: double.infinity,
                                                                                                decoration: endCandidate.isNotEmpty
                                                                                                    ? BoxDecoration(
                                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                                        border: Border.all(
                                                                                                          color: Colors.green,
                                                                                                          width: 1.5,
                                                                                                        ),
                                                                                                        color: Colors.green.withAlpha(14),
                                                                                                      )
                                                                                                    : null,
                                                                                                padding: endCandidate.isNotEmpty ? const EdgeInsets.all(4) : EdgeInsets.zero,
                                                                                                child: Wrap(
                                                                                                  spacing: 6,
                                                                                                  runSpacing: 6,
                                                                                                  children: [
                                                                                                    ...List.generate(
                                                                                                      ingesta.items.length,
                                                                                                      (itemIndex) {
                                                                                                        final item = ingesta.items[itemIndex];
                                                                                                        final payload = _DraggedIngestaItemPayload(
                                                                                                          weekIndex: originalWeekIndex,
                                                                                                          dayIndex: dayIndex,
                                                                                                          mealIndex: mealIndex,
                                                                                                          itemIndex: itemIndex,
                                                                                                          item: _clonePlanItem(item),
                                                                                                        );
                                                                                                        return DragTarget<_DraggedIngestaItemPayload>(
                                                                                                          onWillAcceptWithDetails: (_) => !_savingDrop,
                                                                                                          onAcceptWithDetails: (details) {
                                                                                                            _handleDropIngestaItem(
                                                                                                              payload: details.data,
                                                                                                              targetWeekIndex: originalWeekIndex,
                                                                                                              targetDayIndex: dayIndex,
                                                                                                              targetMealIndex: mealIndex,
                                                                                                              targetInsertIndex: itemIndex,
                                                                                                            );
                                                                                                          },
                                                                                                          builder: (context, candidate, _) {
                                                                                                            final hovering = candidate.isNotEmpty;
                                                                                                            return _buildIngestaItemChip(
                                                                                                              weekIndex: originalWeekIndex,
                                                                                                              dayIndex: dayIndex,
                                                                                                              mealIndex: mealIndex,
                                                                                                              itemIndex: itemIndex,
                                                                                                              item: item,
                                                                                                              payload: payload,
                                                                                                              hovering: hovering,
                                                                                                            );
                                                                                                          },
                                                                                                        );
                                                                                                      },
                                                                                                    ),
                                                                                                  ],
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
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        height: 60,
                                        child: DragTarget<
                                            _DraggedAlimentosPayload>(
                                          onWillAcceptWithDetails: (_) => false,
                                          onMove: (_) => _startAutoScroll(-8.0),
                                          onLeave: (_) => _stopAutoScroll(),
                                          builder: (_, __, ___) =>
                                              const SizedBox.expand(),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        height: 60,
                                        child: DragTarget<
                                            _DraggedAlimentosPayload>(
                                          onWillAcceptWithDetails: (_) => false,
                                          onMove: (_) => _startAutoScroll(8.0),
                                          onLeave: (_) => _stopAutoScroll(),
                                          builder: (_, __, ___) =>
                                              const SizedBox.expand(),
                                        ),
                                      ),
                                    ],
                                  )
                                : Stack(
                                    children: [
                                      _buildCompactTargetView(semanasDestino),
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        height: 60,
                                        child: DragTarget<
                                            _DraggedAlimentosPayload>(
                                          onWillAcceptWithDetails: (_) => false,
                                          onMove: (_) => _startAutoScroll(-8.0),
                                          onLeave: (_) => _stopAutoScroll(),
                                          builder: (_, __, ___) =>
                                              const SizedBox.expand(),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        height: 60,
                                        child: DragTarget<
                                            _DraggedAlimentosPayload>(
                                          onWillAcceptWithDetails: (_) => false,
                                          onMove: (_) => _startAutoScroll(8.0),
                                          onLeave: (_) => _stopAutoScroll(),
                                          builder: (_, __, ___) =>
                                              const SizedBox.expand(),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _alimentoTile(Alimento alimento, bool selected) {
    final codigo = alimento.codigo;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      leading: const Icon(Icons.drag_indicator, size: 18),
      title: Text(alimento.nombre),
      trailing: Transform.scale(
        scale: 0.9,
        child: Checkbox(
          value: selected,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          onChanged: codigo == null
              ? null
              : (value) => _toggleSelect(alimento, value ?? false),
        ),
      ),
      onTap: codigo == null ? null : () => _toggleSelect(alimento, !selected),
    );
  }
}
