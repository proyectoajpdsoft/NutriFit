import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/aditivo.dart';
import '../screens/aditivo_detail_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/consejo_receta_pdf_service.dart';
import '../utils/aditivos_ai.dart';
import '../widgets/peligrosidad_dialog.dart';
import '../widgets/premium_feature_dialog_helper.dart';
import '../widgets/premium_upsell_card.dart';

enum _OrdenAditivosPremium { nombre, tipo, fecha, peligrosidad }

bool _canAccessAditivosCatalog(AuthService authService) {
  return authService.isPremium ||
      authService.userType == 'Nutricionista' ||
      authService.userType == 'Administrador';
}

Future<void> _showPremiumRequiredForAditivosCopyPdf(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return PremiumFeatureDialogHelper.show(
    context,
    message: l10n.additivesPremiumCopyPdfMessage,
  );
}

Future<void> _showPremiumRequiredForAditivosExplore(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return PremiumFeatureDialogHelper.show(
    context,
    message: l10n.additivesPremiumExploreMessage,
  );
}

Future<void> _showPremiumRequiredForAditivosTools(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return PremiumFeatureDialogHelper.show(
    context,
    message: l10n.additivesPremiumToolsMessage,
  );
}

class AditivosPacienteScreen extends StatefulWidget {
  const AditivosPacienteScreen({super.key});

  @override
  State<AditivosPacienteScreen> createState() => _AditivosPacienteScreenState();
}

class _AditivosPacienteScreenState extends State<AditivosPacienteScreen> {
  static const String _paramNonPremiumPreviewCodes =
      'codigos_aditivos_no_premium';

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
  List<int>? _nonPremiumPreviewCodes;

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
    final l10n = AppLocalizations.of(context)!;
    await _loadTiposCatalogo();
    final tempSelected = _selectedTipos.toSet();
    var tempMatchAll = _tipoMatchAll;
    var tempPeligrosidades = _selectedPeligrosidades.toSet();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final peligrosidadLabels = {
            1: l10n.additivesSeveritySafe,
            2: l10n.additivesSeverityAttention,
            3: l10n.additivesSeverityHigh,
            4: l10n.additivesSeverityRestricted,
            5: l10n.additivesSeverityForbidden,
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
                    l10n.additivesFilterTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                  tooltip: l10n.commonClose,
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
                  Text(
                    l10n.commonSeverity,
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
                        ? l10n.additivesNoConfiguredTypes
                        : l10n.additivesTypesLabel,
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
                    title: Text(l10n.commonMatchAll),
                    subtitle: Text(l10n.commonRequireAllSelected),
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
                child: Text(l10n.commonClear),
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
                    Text(l10n.commonApply),
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
    final l10n = AppLocalizations.of(context)!;
    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (lower.contains('<html') ||
        lower.contains('<!doctype') ||
        lower.contains('404') ||
        lower.contains('not found')) {
      return l10n.additivesCatalogUnavailable;
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection')) {
      return l10n.additivesServerConnectionError;
    }
    return fallback;
  }

  Future<void> _loadAditivos() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _loadErrorMessage = null;
    });
    try {
      final apiService = context.read<ApiService>();
      final previewCodesFuture = apiService
          .getParametroValor(_paramNonPremiumPreviewCodes)
          .then(_parsePreviewCodes)
          .catchError((_) => null);
      final response = await apiService.get('api/aditivos.php?activos=1');
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final previewCodes = await previewCodesFuture;
        if (!mounted) return;
        setState(() {
          _aditivos = data
              .map((e) => Aditivo.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _nonPremiumPreviewCodes = previewCodes;
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
          _nonPremiumPreviewCodes = null;
          _loadErrorMessage = _friendlyApiError(
            e,
            fallback: l10n.additivesLoadFailed,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportItemPdf(Aditivo s) async {
    final l10n = AppLocalizations.of(context)!;
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
        SnackBar(content: Text(l10n.commonGeneratePdfError('$e'))),
      );
    }
  }

  Future<void> _openDetail(Aditivo s) async {
    final authService = context.read<AuthService>();
    final canAccessFullCatalog = _canAccessAditivosCatalog(authService);

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AditivoDetailScreen(
          aditivo: s,
          onExportPdf: canAccessFullCatalog
              ? _exportItemPdf
              : (_) => _showPremiumRequiredForAditivosCopyPdf(context),
          allAditivos: _aditivos,
          showPremiumRecommendations: true,
          allowCopyAndPdf: canAccessFullCatalog,
          allowDiscoveryNavigation: canAccessFullCatalog,
          onRequestPremiumAccess: (message) =>
              PremiumFeatureDialogHelper.show(context, message: message),
          onNavigateToAditivo: canAccessFullCatalog
              ? (target) => _openDetail(target)
              : (target) => _showPremiumRequiredForAditivosExplore(context),
          onHashtagTap: (hashtag) {
            if (!canAccessFullCatalog) {
              _showPremiumRequiredForAditivosExplore(context);
              return;
            }
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

  List<Aditivo> _buildPreviewAditivos() {
    final configuredCodes = _nonPremiumPreviewCodes;
    if (configuredCodes != null && configuredCodes.isNotEmpty) {
      final byCode = <int, Aditivo>{
        for (final item in _aditivos)
          if (item.codigo != null) item.codigo!: item,
      };
      final configuredItems = configuredCodes
          .map((code) => byCode[code])
          .whereType<Aditivo>()
          .toList(growable: false);
      if (configuredItems.isNotEmpty) {
        return configuredItems;
      }
    }

    final preview = List<Aditivo>.from(_aditivos);
    preview.sort((a, b) {
      final dateA = a.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byDate = dateB.compareTo(dateA);
      if (byDate != 0) return byDate;
      return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
    });
    return preview.take(3).toList(growable: false);
  }

  String _catalogHighlightText(int total, String label) {
    final roundedDown = total - (total % 10);
    return ' (con más de $roundedDown $label)';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = context.watch<AuthService>();
    final canAccessFullCatalog = _canAccessAditivosCatalog(authService);
    final visibleItems =
        canAccessFullCatalog ? _filtered : _buildPreviewAditivos();
    final filteredCount = visibleItems.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.navAdditives),
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
            tooltip: _searchVisible ? l10n.commonHideSearch : l10n.commonSearch,
            onPressed: canAccessFullCatalog
                ? () {
                    setState(() {
                      _searchVisible = !_searchVisible;
                      if (!_searchVisible) {
                        _searchCtrl.clear();
                        _searchQuery = '';
                        _applyFilter();
                      }
                    });
                  }
                : () => _showPremiumRequiredForAditivosTools(context),
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
          ),
          IconButton(
            tooltip: _selectedTipos.isEmpty
                ? l10n.commonTypeField
                : '${l10n.commonTypeField} (${_selectedTipos.length})',
            onPressed: canAccessFullCatalog
                ? _showTipoFilterDialog
                : () => _showPremiumRequiredForAditivosTools(context),
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
            tooltip: l10n.commonMoreOptions,
            onSelected: (value) {
              if (!canAccessFullCatalog) {
                _showPremiumRequiredForAditivosTools(context);
                return;
              }
              _handleMenuAction(value);
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
                      _searchVisible
                          ? l10n.commonHideSearch
                          : l10n.commonSearch,
                    ),
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
                  title: Text(l10n.commonFilter),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'actualizar',
                child: Row(
                  children: [
                    const Icon(Icons.refresh, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.commonRefresh),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem<String>(
                value: 'sort_nombre',
                checked: _orden == _OrdenAditivosPremium.nombre,
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.commonSortByName)),
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
                    Expanded(child: Text(l10n.commonSortByType)),
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
                    Expanded(child: Text(l10n.commonSortByDate)),
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
                    Expanded(child: Text(l10n.commonSortBySeverity)),
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
                          label: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (canAccessFullCatalog && _searchVisible)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          onChanged: _applySearch,
                          decoration: InputDecoration(
                            hintText: l10n.additivesSearchHint,
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: l10n.commonClear,
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
                    if (canAccessFullCatalog && _searchVisible)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: Text(l10n.commonTitleField),
                                selected: _searchFields.contains('titulo'),
                                onSelected: (v) =>
                                    _toggleSearchField('titulo', v),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: Text(l10n.commonDescriptionField),
                                selected: _searchFields.contains('descripcion'),
                                onSelected: (v) =>
                                    _toggleSearchField('descripcion', v),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: Text(l10n.commonTypeField),
                                selected: _searchFields.contains('tipo'),
                                onSelected: (v) =>
                                    _toggleSearchField('tipo', v),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: visibleItems.isEmpty
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
                                        ? l10n.additivesEmpty
                                        : l10n.commonNoResultsForQuery(
                                            _searchQuery),
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
                                itemCount: canAccessFullCatalog
                                    ? visibleItems.length
                                    : visibleItems.length + 1,
                                itemBuilder: (context, index) {
                                  if (!canAccessFullCatalog &&
                                      index == visibleItems.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: PremiumUpsellCard(
                                        title: l10n.additivesPremiumTitle,
                                        subtitle: l10n.additivesPremiumSubtitle,
                                        subtitleHighlight:
                                            l10n.additivesCatalogHighlight(
                                          _aditivos.length -
                                              (_aditivos.length % 10),
                                        ),
                                        subtitleHighlightColor:
                                            Colors.pink.shade700,
                                        onPressed: () => Navigator.pushNamed(
                                          context,
                                          '/premium_info',
                                        ),
                                      ),
                                    );
                                  }

                                  final s = visibleItems[index];
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
