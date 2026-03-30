import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aditivo.dart';
import '../screens/aditivo_detail_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/consejo_receta_pdf_service.dart';
import '../utils/aditivos_ai.dart';
import '../widgets/peligrosidad_dialog.dart';

enum _OrdenAditivosPremium { nombre, tipo, fecha, peligrosidad }

class AditivosPacienteScreen extends StatefulWidget {
  const AditivosPacienteScreen({super.key});

  @override
  State<AditivosPacienteScreen> createState() => _AditivosPacienteScreenState();
}

class _AditivosPacienteScreenState extends State<AditivosPacienteScreen> {
  List<Aditivo> _aditivos = [];
  List<Aditivo> _filtered = [];
  bool _isLoading = true;
  bool _searchVisible = false;
  String _searchQuery = '';
  Set<String> _searchFields = <String>{'titulo', 'descripcion', 'tipo'};
  List<String> _tiposCatalogo = List<String>.from(defaultAditivoTypes);
  Set<String> _selectedTipos = <String>{};
  bool _tipoMatchAll = false;
  Set<int> _selectedPeligrosidades = <int>{};
  _OrdenAditivosPremium _orden = _OrdenAditivosPremium.nombre;
  bool _ordenAscendente = true;
  String? _loadErrorMessage;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q != _searchQuery) {
        setState(() {
          _searchQuery = q;
          _applyFilter();
        });
      }
    });
    _loadAditivos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchQuery.toLowerCase();
    final qVariants = _buildAditivoSearchVariants(q);
    _filtered = _aditivos.where((s) {
      final matchSearch = _searchQuery.isEmpty
          ? true
          : (_searchFields.contains('titulo') &&
                  _matchesAditivoSearch(s.titulo, qVariants)) ||
              (_searchFields.contains('descripcion') &&
                  _matchesAditivoSearch(s.descripcion, qVariants)) ||
              (_searchFields.contains('tipo') &&
                  _matchesAditivoSearch(s.tipo, qVariants));
      final matchTipo = _matchesSelectedTipos(s.tipo);
      final matchPeligrosidad = _selectedPeligrosidades.isEmpty
          ? true
          : _selectedPeligrosidades
              .contains(_normalizePeligrosidad(s.peligrosidad));
      return matchSearch && matchTipo && matchPeligrosidad;
    }).toList();

    _sortFiltered();
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
    final selected = _selectedTipos.map(_normalizeAditivoTypeValue).toSet();
    final tokens = _extractAditivoTypeTokens(aditivoTipo)
        .map(_normalizeAditivoTypeValue)
        .toSet();
    if (tokens.isEmpty) return false;
    if (_tipoMatchAll) {
      return selected.every(tokens.contains);
    }
    return selected.any(tokens.contains);
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

  void _sortFiltered() {
    int compareNombre(Aditivo a, Aditivo b) =>
        a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());

    switch (_orden) {
      case _OrdenAditivosPremium.nombre:
        _filtered.sort((a, b) =>
            _ordenAscendente ? compareNombre(a, b) : compareNombre(b, a));
        break;
      case _OrdenAditivosPremium.tipo:
        _filtered.sort((a, b) {
          final tipoA = a.tipo.toLowerCase().trim();
          final tipoB = b.tipo.toLowerCase().trim();
          final byTipo = _ordenAscendente
              ? tipoA.compareTo(tipoB)
              : tipoB.compareTo(tipoA);
          if (byTipo != 0) return byTipo;
          return compareNombre(a, b);
        });
        break;
      case _OrdenAditivosPremium.fecha:
        _filtered.sort((a, b) {
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
      case _OrdenAditivosPremium.peligrosidad:
        _filtered.sort((a, b) {
          final peligA = _normalizePeligrosidad(a.peligrosidad) ?? 0;
          final peligB = _normalizePeligrosidad(b.peligrosidad) ?? 0;
          final byPelig = _ordenAscendente
              ? peligA.compareTo(peligB)
              : peligB.compareTo(peligA);
          if (byPelig != 0) return byPelig;
          return compareNombre(a, b);
        });
        break;
    }
  }

  int get _activeFilterCount =>
      _selectedTipos.length + _selectedPeligrosidades.length;

  Future<void> _loadTiposCatalogo() async {
    final api = context.read<ApiService>();
    try {
      final raw = await api.getParametroValor('tipos_aditivos');
      final merged = mergeAditivoTypes(
        <String>[
          ...defaultAditivoTypes,
          ...parseAditivoTypes(raw),
          ..._aditivos.expand((item) => _extractAditivoTypeTokens(item.tipo)),
        ],
      );
      final tiposConAditivos = _aditivos
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
      final tiposConAditivos = _aditivos
          .expand((item) => _extractAditivoTypeTokens(item.tipo))
          .map((tipo) => tipo.trim())
          .where((tipo) => tipo.isNotEmpty)
          .map(_normalizeAditivoTypeValue)
          .toSet();

      final merged = mergeAditivoTypes(
        <String>[
          ...defaultAditivoTypes,
          ..._aditivos.expand((item) => _extractAditivoTypeTokens(item.tipo)),
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

  void _applySortSelection(_OrdenAditivosPremium orden) {
    setState(() {
      if (_orden == orden) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _orden = orden;
        _ordenAscendente = orden == _OrdenAditivosPremium.nombre ||
            orden == _OrdenAditivosPremium.tipo ||
            orden == _OrdenAditivosPremium.peligrosidad;
      }
      _applyFilter();
    });
  }

  Future<void> _showTipoFilterDialog() async {
    await _loadTiposCatalogo();
    final tempSelected = _selectedTipos.toSet();
    var tempMatchAll = _tipoMatchAll;
    var tempPeligrosidades = _selectedPeligrosidades.toSet();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final peligrosidadLabels = {
            1: 'Seguro',
            2: 'Atención',
            3: 'Alto',
            4: 'Restringido',
            5: 'Prohibido',
          };
          final sortedTipos = List<String>.from(_tiposCatalogo)
            ..sort(
              (a, b) => a.toLowerCase().trim().compareTo(
                    b.toLowerCase().trim(),
                  ),
            );
          final selectedTypeCount = tempSelected.length;
          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtrar aditivos',
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          children:
                              List<int>.from([1, 2, 3, 4, 5]).map((nivel) {
                            return Padding(
                              padding: EdgeInsets.only(
                                right: nivel == 5 ? 0 : 8,
                              ),
                              child: FilterChip(
                                label: Text(peligrosidadLabels[nivel]!),
                                selected: tempPeligrosidades.contains(nivel),
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
                  Text(
                    _tiposCatalogo.isEmpty
                        ? 'No hay tipos configurados en tipos_aditivos.'
                        : 'Tipos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          _tiposCatalogo.isEmpty ? null : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (sortedTipos.isNotEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.22,
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
                    subtitle:
                        const Text('Exige todos los tipos seleccionados.'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedTipos = <String>{};
                    _tipoMatchAll = false;
                    _selectedPeligrosidades = <int>{};
                    _applyFilter();
                  });
                  Navigator.pop(dialogContext);
                },
                child: const Text('Limpiar'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedTipos = tempSelected;
                    _tipoMatchAll = tempMatchAll;
                    _selectedPeligrosidades = tempPeligrosidades;
                    _applyFilter();
                  });
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
      ),
    );
  }

  Future<void> _handleMenuAction(String value) async {
    if (value == 'filtrar') {
      await _showTipoFilterDialog();
      return;
    }
    if (value == 'buscar') {
      setState(() {
        _searchVisible = !_searchVisible;
        if (!_searchVisible) {
          _searchCtrl.clear();
          _searchQuery = '';
          _applyFilter();
        }
      });
      return;
    }
    if (value == 'actualizar') {
      await _loadAditivos();
      return;
    }
    if (value == 'sort_nombre') {
      _applySortSelection(_OrdenAditivosPremium.nombre);
      return;
    }
    if (value == 'sort_tipo') {
      _applySortSelection(_OrdenAditivosPremium.tipo);
      return;
    }
    if (value == 'sort_fecha') {
      _applySortSelection(_OrdenAditivosPremium.fecha);
      return;
    }
    if (value == 'sort_peligrosidad') {
      _applySortSelection(_OrdenAditivosPremium.peligrosidad);
    }
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
      return 'El catálogo de Aditivos no está disponible temporalmente. Inténtalo más tarde.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection')) {
      return 'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';
    }
    return fallback;
  }

  Future<void> _loadAditivos() async {
    setState(() {
      _isLoading = true;
      _loadErrorMessage = null;
    });
    try {
      final response =
          await context.read<ApiService>().get('api/aditivos.php?activos=1');
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _aditivos = data
              .map((e) => Aditivo.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _tiposCatalogo = mergeAditivoTypes(
            <String>[
              ..._tiposCatalogo,
              ..._aditivos
                  .expand((item) => _extractAditivoTypeTokens(item.tipo)),
              ..._selectedTipos,
            ],
          );
          _applyFilter();
          _loadErrorMessage = null;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aditivos = [];
          _filtered = [];
          _loadErrorMessage = _friendlyApiError(
            e,
            fallback: 'No se pudieron cargar los Aditivos.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportItemPdf(Aditivo s) async {
    try {
      final apiService = context.read<ApiService>();
      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: s.titulo,
        contenido: s.descripcion ?? '',
        tipo: 'aditivo',
        fileName: 'Aditivo_${s.titulo.replaceAll(' ', '_').toLowerCase()}',
        preserveEmojis: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e')),
      );
    }
  }

  Future<void> _openDetail(Aditivo s) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AditivoDetailScreen(
          aditivo: s,
          onExportPdf: _exportItemPdf,
          allAditivos: _aditivos,
          showPremiumRecommendations: context.read<AuthService>().isPremium,
          onNavigateToAditivo: (target) => _openDetail(target),
          onHashtagTap: (hashtag) {
            setState(() {
              _searchVisible = true;
            });
            _searchCtrl.text = hashtag;
            _searchCtrl.selection =
                TextSelection.collapsed(offset: _searchCtrl.text.length);
            _applySearch(hashtag);
          },
        ),
      ),
    );
  }

  void _applySearch(String value) {
    setState(() {
      _searchQuery = value.trim();
      _applyFilter();
    });
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
      _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredCount = _filtered.length;
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
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) {
                  _searchCtrl.clear();
                  _searchQuery = '';
                  _applyFilter();
                }
              });
            },
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
          ),
          IconButton(
            tooltip: _selectedTipos.isEmpty
                ? 'Filtrar por tipo'
                : 'Filtrar por tipo (${_selectedTipos.length})',
            onPressed: _showTipoFilterDialog,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_alt_outlined),
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
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) => _handleMenuAction(value),
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
                    Text(_searchVisible ? 'Ocultar buscar' : 'Buscar'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'filtrar',
                child: ListTile(
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(width: 18, height: 18),
                      const Icon(Icons.filter_alt, size: 18),
                      if (_selectedTipos.isNotEmpty)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${_selectedTipos.length}',
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
              const PopupMenuItem<String>(
                value: 'actualizar',
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
                checked: _orden == _OrdenAditivosPremium.nombre,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Nombre')),
                    if (_orden == _OrdenAditivosPremium.nombre)
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
                checked: _orden == _OrdenAditivosPremium.tipo,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Tipo')),
                    if (_orden == _OrdenAditivosPremium.tipo)
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
                checked: _orden == _OrdenAditivosPremium.fecha,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Fecha')),
                    if (_orden == _OrdenAditivosPremium.fecha)
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
                checked: _orden == _OrdenAditivosPremium.peligrosidad,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Peligrosidad')),
                    if (_orden == _OrdenAditivosPremium.peligrosidad)
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadErrorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 58,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _loadErrorMessage!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loadAditivos,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (_searchVisible)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          onChanged: _applySearch,
                          decoration: InputDecoration(
                            hintText: 'Buscar aditivos',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Limpiar',
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _applySearch('');
                                    },
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    if (_searchVisible)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('Título'),
                                selected: _searchFields.contains('titulo'),
                                onSelected: (v) =>
                                    _toggleSearchField('titulo', v),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Descripción'),
                                selected: _searchFields.contains('descripcion'),
                                onSelected: (v) =>
                                    _toggleSearchField('descripcion', v),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Tipo'),
                                selected: _searchFields.contains('tipo'),
                                onSelected: (v) =>
                                    _toggleSearchField('tipo', v),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.medication_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'No hay Aditivos disponibles'
                                        : 'Sin resultados para "$_searchQuery"',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 15,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadAditivos,
                              child: ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  40 + MediaQuery.of(context).padding.bottom,
                                ),
                                itemCount: _filtered.length,
                                itemBuilder: (context, index) {
                                  final s = _filtered[index];
                                  final desc = (s.descripcion ?? '').trim();
                                  return Card(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 5),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _openDetail(s),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            GestureDetector(
                                              onTap: () =>
                                                  showAditivoPeligrosidadDialog(
                                                context,
                                                peligrosidad: s.peligrosidad,
                                                titulo: s.titulo,
                                              ),
                                              child: Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: _peligrosidadColor(
                                                          s.peligrosidad)
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
                                                        color:
                                                            _peligrosidadColor(
                                                                s.peligrosidad),
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
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              _peligrosidadColor(
                                                                  s.peligrosidad),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Text(
                                                          _peligrosidadLabel(
                                                              s.peligrosidad),
                                                          style:
                                                              const TextStyle(
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
                                                          FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                    maxLines: 2,
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
                                                        color: Colors.teal
                                                            .withValues(
                                                                alpha: 0.10),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(999),
                                                      ),
                                                      child: Text(
                                                        s.tipo,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.teal,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  if (desc.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      desc,
                                                      maxLines: 3,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors
                                                            .grey.shade600,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: Colors.grey,
                                            ),
                                          ],
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
    );
  }
}
