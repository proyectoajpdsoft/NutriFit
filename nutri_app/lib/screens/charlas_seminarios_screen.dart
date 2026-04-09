import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/models/charla_seminario.dart';
import 'package:nutri_app/screens/charla_seminario_detail_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/widgets/premium_feature_dialog_helper.dart';
import 'package:nutri_app/widgets/premium_upsell_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _OrdenCharlas { nombre, fechaAlta, popular }

enum _TopActionCharlas {
  buscar,
  filtrar,
  actualizar,
  ordenarNombre,
  ordenarFecha,
  ordenarPopular,
}

Future<void> _showPremiumRequiredForCharlasTools(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return PremiumFeatureDialogHelper.show(
    context,
    message: l10n.charlasPremiumToolsMessage,
  );
}

Future<void> _showPremiumRequiredForCharlasContent(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return PremiumFeatureDialogHelper.show(
    context,
    message: l10n.charlasPremiumContentMessage,
  );
}

class CharlasSeminariosScreen extends StatefulWidget {
  const CharlasSeminariosScreen({super.key, this.initialSearchQuery = ''});

  final String initialSearchQuery;

  @override
  State<CharlasSeminariosScreen> createState() =>
      _CharlasSeminariosScreenState();
}

class _CharlasSeminariosScreenState extends State<CharlasSeminariosScreen>
    with SingleTickerProviderStateMixin {
  static const String _paramNonPremiumPreviewCodes =
      'codigos_charlas_no_premium';
  static const String _prefsSearchVisible = 'charlas_seminarios_search_visible';
  static const String _prefsSearchQuery = 'charlas_seminarios_search_query';
  static const String _prefsOrden = 'charlas_seminarios_orden';
  static const String _prefsOrdenAsc = 'charlas_seminarios_orden_asc';
  static const String _prefsSelectedCategoriasKey =
      'charlas_seminarios_selected_categorias';
  static const String _prefsCategoriaMatchAllKey =
      'charlas_seminarios_categoria_match_all';

  final Map<String, MemoryImage> _thumbCache = <String, MemoryImage>{};

  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  List<CharlaSeminario> _destacadas = <CharlaSeminario>[];
  List<CharlaSeminario> _todas = <CharlaSeminario>[];
  List<CharlaSeminario> _favoritas = <CharlaSeminario>[];
  List<Map<String, dynamic>> _categoriasCatalogo = <Map<String, dynamic>>[];

  bool _loadingDestacadas = true;
  bool _loadingTodas = true;
  bool _loadingFavoritas = true;
  bool _loadingCategorias = false;
  bool _showFilters = false;
  String _searchQuery = '';
  List<int>? _nonPremiumPreviewCodes;
  List<int> _selectedCategoriaIds = <int>[];
  bool _categoriaMatchAll = false;
  _OrdenCharlas _orden = _OrdenCharlas.nombre;
  bool _ordenAscendente = true;

  String? get _userCode => context.read<AuthService>().userCode;
  bool get _canAccessFullCatalog {
    final authService = context.read<AuthService>();
    final userType = (authService.userType ?? '').toLowerCase().trim();
    return authService.isPremium ||
        userType == 'nutricionista' ||
        userType == 'administrador';
  }

  bool get _isPreviewMode => !_canAccessFullCatalog;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchQuery = widget.initialSearchQuery.trim();
    _showFilters = _searchQuery.isNotEmpty;
    _searchCtrl.text = _searchQuery;
    _restoreListState().whenComplete(() {
      if (!mounted) return;
      if (_isPreviewMode) {
        _loadingFavoritas = false;
      } else {
        _loadCategorias();
      }
      _loadDestacadas();
      _loadTodas();
      if (!_isPreviewMode) {
        _loadFavoritas();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _thumbCache.clear();
    super.dispose();
  }

  // ─── LOADERS ────────────────────────────────────────────────────

  Future<void> _loadDestacadas() async {
    setState(() => _loadingDestacadas = true);
    try {
      final previewCodesFuture = _isPreviewMode
          ? context
              .read<ApiService>()
              .getParametroValor(_paramNonPremiumPreviewCodes)
              .then(_parsePreviewCodes)
              .catchError((_) => null)
          : Future<List<int>?>.value(null);
      final response = await context.read<ApiService>().get(
            'api/charlas_seminarios.php?portada=1',
          );
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final previewCodes = await previewCodesFuture;
        setState(() {
          _destacadas = data
              .map(
                (e) => CharlaSeminario.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(growable: false);
          _nonPremiumPreviewCodes = previewCodes;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _destacadas = <CharlaSeminario>[]);
    } finally {
      if (mounted) setState(() => _loadingDestacadas = false);
    }
  }

  Future<void> _loadTodas() async {
    setState(() => _loadingTodas = true);
    try {
      final response = await context.read<ApiService>().get(
            'api/charlas_seminarios.php?publico=1',
          );
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _todas = data
              .map(
                (e) => CharlaSeminario.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(growable: false);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _todas = <CharlaSeminario>[]);
    } finally {
      if (mounted) setState(() => _loadingTodas = false);
    }
  }

  Future<void> _loadFavoritas() async {
    if (_isPreviewMode) {
      if (mounted) {
        setState(() {
          _favoritas = <CharlaSeminario>[];
          _loadingFavoritas = false;
        });
      }
      return;
    }
    setState(() => _loadingFavoritas = true);
    try {
      final response = await context.read<ApiService>().get(
            'api/charlas_seminarios.php?favoritos=1',
          );
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _favoritas = data
              .map(
                (e) => CharlaSeminario.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(growable: false);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _favoritas = <CharlaSeminario>[]);
    } finally {
      if (mounted) setState(() => _loadingFavoritas = false);
    }
  }

  Future<void> _refreshAll() async {
    if (_isPreviewMode) {
      await Future.wait([_loadDestacadas(), _loadTodas()]);
      return;
    }
    await Future.wait([_loadDestacadas(), _loadTodas(), _loadFavoritas()]);
  }

  Future<void> _loadCategorias() async {
    if (_isPreviewMode) {
      if (mounted) {
        setState(() {
          _categoriasCatalogo = <Map<String, dynamic>>[];
          _loadingCategorias = false;
        });
      }
      return;
    }
    setState(() => _loadingCategorias = true);
    try {
      final response = await context.read<ApiService>().get(
            'api/charlas_seminarios.php?categorias=1',
          );
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _categoriasCatalogo = data
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(growable: false);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _categoriasCatalogo = <Map<String, dynamic>>[]);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingCategorias = false);
      }
    }
  }

  Future<void> _saveListState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsSearchVisible, _showFilters);
      await prefs.setString(_prefsSearchQuery, _searchQuery);
      await prefs.setInt(_prefsOrden, _orden.index);
      await prefs.setBool(_prefsOrdenAsc, _ordenAscendente);
      await prefs.setStringList(_prefsSelectedCategoriasKey,
          _selectedCategoriaIds.map((e) => e.toString()).toList());
      await prefs.setBool(_prefsCategoriaMatchAllKey, _categoriaMatchAll);
    } catch (_) {
      // Ignorar fallos de persistencia para no romper el flujo de UI.
    }
  }

  Future<void> _restoreListState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _showFilters = prefs.getBool(_prefsSearchVisible) ?? _showFilters;
        _searchQuery = prefs.getString(_prefsSearchQuery) ?? _searchQuery;
        _searchCtrl.text = _searchQuery;
        _selectedCategoriaIds =
            (prefs.getStringList(_prefsSelectedCategoriasKey) ??
                    const <String>[])
                .map((e) => int.tryParse(e) ?? 0)
                .where((e) => e > 0)
                .toList(growable: false);
        _categoriaMatchAll =
            prefs.getBool(_prefsCategoriaMatchAllKey) ?? _categoriaMatchAll;

        final restoredOrden = prefs.getInt(_prefsOrden);
        _orden = restoredOrden != null &&
                restoredOrden >= 0 &&
                restoredOrden < _OrdenCharlas.values.length
            ? _OrdenCharlas.values[restoredOrden]
            : _orden;

        _ordenAscendente = prefs.getBool(_prefsOrdenAsc) ?? _ordenAscendente;

        if (_isPreviewMode) {
          _showFilters = false;
          _searchQuery = '';
          _searchCtrl.clear();
          _selectedCategoriaIds = <int>[];
          _categoriaMatchAll = false;
        }
      });
    } catch (_) {
      // Ignorar fallos de restauración para mantener valores por defecto.
    }
  }

  void _toggleFiltersVisibility() {
    if (_isPreviewMode) {
      _showPremiumRequiredForCharlasTools(context);
      return;
    }
    final next = !_showFilters;
    setState(() {
      _showFilters = next;
      if (!next) {
        _searchQuery = '';
        _searchCtrl.clear();
      }
    });
    _saveListState();
  }

  void _applySortSelection(_OrdenCharlas orden) {
    if (_isPreviewMode) {
      _showPremiumRequiredForCharlasTools(context);
      return;
    }
    setState(() {
      if (_orden == orden) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _orden = orden;
        _ordenAscendente = orden == _OrdenCharlas.nombre;
      }
    });
    if (_orden == _OrdenCharlas.popular) {
      _ordenAscendente = false;
    }
    _saveListState();
  }

  Future<void> _handleTopAction(_TopActionCharlas action) async {
    if (_isPreviewMode) {
      await _showPremiumRequiredForCharlasTools(context);
      return;
    }
    switch (action) {
      case _TopActionCharlas.buscar:
        _toggleFiltersVisibility();
        break;
      case _TopActionCharlas.filtrar:
        await _showCategoriaFilterDialog();
        break;
      case _TopActionCharlas.actualizar:
        await _refreshAll();
        break;
      case _TopActionCharlas.ordenarNombre:
        _applySortSelection(_OrdenCharlas.nombre);
        break;
      case _TopActionCharlas.ordenarFecha:
        _applySortSelection(_OrdenCharlas.fechaAlta);
        break;
      case _TopActionCharlas.ordenarPopular:
        _applySortSelection(_OrdenCharlas.popular);
        break;
    }
  }

  // ─── TOGGLE LIKE / FAVORITO ───────────────────────────────────────

  Future<void> _toggleLike(CharlaSeminario item) async {
    if (_isPreviewMode) {
      await _showPremiumRequiredForCharlasTools(context);
      return;
    }
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) return;

    final prev = item.meGusta ?? 'N';
    try {
      final response = await context.read<ApiService>().post(
            'api/charlas_seminarios.php?toggle_like=1',
            body: jsonEncode(<String, dynamic>{
              'codigo_charla': item.codigo,
              'codigo_usuario': int.parse(userCode),
            }),
          );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        item.meGusta = (data['me_gusta'] ?? 'N').toString();
        if (prev != 'S' && item.meGusta == 'S') {
          item.totalLikes += 1;
        } else if (prev == 'S' && item.meGusta != 'S' && item.totalLikes > 0) {
          item.totalLikes -= 1;
        }
        _syncItem(item);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorito(CharlaSeminario item) async {
    if (_isPreviewMode) {
      await _showPremiumRequiredForCharlasTools(context);
      return;
    }
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) return;

    try {
      final response = await context.read<ApiService>().post(
            'api/charlas_seminarios.php?toggle_favorito=1',
            body: jsonEncode(<String, dynamic>{
              'codigo_charla': item.codigo,
              'codigo_usuario': int.parse(userCode),
            }),
          );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        item.favorito = (data['favorito'] ?? 'N').toString();
        _syncItem(item);
        if (item.favorito != 'S') {
          setState(() {
            _favoritas.removeWhere((f) => f.codigo == item.codigo);
          });
        }
      }
    } catch (_) {}
  }

  void _syncItem(CharlaSeminario updated) {
    setState(() {
      _updateInList(_destacadas, updated);
      _updateInList(_todas, updated);
      _updateInList(_favoritas, updated);
    });
  }

  void _updateInList(List<CharlaSeminario> list, CharlaSeminario updated) {
    final idx = list.indexWhere((e) => e.codigo == updated.codigo);
    if (idx >= 0) {
      list[idx].meGusta = updated.meGusta;
      list[idx].favorito = updated.favorito;
      list[idx].totalLikes = updated.totalLikes;
    }
  }

  List<int>? _parsePreviewCodes(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    final codes = rawValue
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .where((value) => value > 0)
        .toList();

    if (codes.isEmpty) {
      return null;
    }

    return codes.toSet().toList();
  }

  List<CharlaSeminario> _buildPreviewCharlas(
    List<CharlaSeminario> source,
    List<int>? previewCodes,
  ) {
    if (source.isEmpty) {
      return <CharlaSeminario>[];
    }

    if (previewCodes != null && previewCodes.isNotEmpty) {
      final byCode = <int, CharlaSeminario>{
        for (final charla in source)
          if (charla.codigo != null) charla.codigo!: charla,
      };
      final selected = previewCodes
          .map((code) => byCode[code])
          .whereType<CharlaSeminario>()
          .toList();
      if (selected.isNotEmpty) {
        return selected;
      }
    }

    final sorted = List<CharlaSeminario>.from(source)
      ..sort((a, b) => (b.codigo ?? 0).compareTo(a.codigo ?? 0));

    return sorted.take(3).toList();
  }

  String _catalogHighlightCount(int total) {
    if (total <= 0) {
      return '0';
    }
    if (total < 10) {
      return '$total';
    }
    final rounded = (total ~/ 10) * 10;
    return '$rounded+';
  }

  // ─── HELPERS ─────────────────────────────────────────────────────

  ImageProvider? _thumbProvider(CharlaSeminario item) {
    final raw = (item.imagenMiniatura ?? item.imagenPortada ?? '').trim();
    if (raw.isEmpty) return null;
    final key = '${item.codigo}:${raw.hashCode}';
    final cached = _thumbCache[key];
    if (cached != null) return cached;
    try {
      final img = MemoryImage(base64Decode(raw));
      _thumbCache[key] = img;
      return img;
    } catch (_) {
      return null;
    }
  }

  List<CharlaSeminario> _applySearchAndFilters(List<CharlaSeminario> items) {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = items.where((item) {
      final matchesSearch = q.isEmpty
          ? true
          : [
              item.titulo,
              item.descripcion,
              item.categoriaNombres.join(' '),
            ].join(' ').toLowerCase().contains(q);

      return matchesSearch && _matchesCategorias(item);
    }).toList(growable: false);

    int compareByNombre(CharlaSeminario a, CharlaSeminario b) =>
        a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());

    int compareByPopular(CharlaSeminario a, CharlaSeminario b) {
      final likesCmp = a.totalLikes.compareTo(b.totalLikes);
      if (likesCmp != 0) return likesCmp;

      final leidosCmp = a.ultimaDiapositivaVista.compareTo(
        b.ultimaDiapositivaVista,
      );
      if (leidosCmp != 0) return leidosCmp;

      final favoritoCmp = (a.favorito == 'S' ? 1 : 0).compareTo(
        b.favorito == 'S' ? 1 : 0,
      );
      if (favoritoCmp != 0) return favoritoCmp;

      return compareByNombre(a, b);
    }

    filtered.sort((a, b) {
      final byNombre = compareByNombre(a, b);
      switch (_orden) {
        case _OrdenCharlas.nombre:
          return _ordenAscendente ? byNombre : -byNombre;
        case _OrdenCharlas.fechaAlta:
          final dateA = a.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
          final byDate = _ordenAscendente
              ? dateA.compareTo(dateB)
              : dateB.compareTo(dateA);
          return byDate != 0 ? byDate : byNombre;
        case _OrdenCharlas.popular:
          final byPopular = compareByPopular(a, b);
          return _ordenAscendente ? byPopular : -byPopular;
      }
    });

    return filtered;
  }

  bool _matchesCategorias(CharlaSeminario item) {
    if (_selectedCategoriaIds.isEmpty) {
      return true;
    }
    if (item.categoriaIds.isEmpty) {
      return false;
    }
    if (_categoriaMatchAll) {
      return _selectedCategoriaIds.every(item.categoriaIds.contains);
    }
    return _selectedCategoriaIds.any(item.categoriaIds.contains);
  }

  Future<void> _showCategoriaFilterDialog() async {
    if (_isPreviewMode) {
      await _showPremiumRequiredForCharlasTools(context);
      return;
    }
    if (_categoriasCatalogo.isEmpty && !_loadingCategorias) {
      await _loadCategorias();
    }
    List<int> tempSelected = List<int>.from(_selectedCategoriaIds);
    bool tempAll = _categoriaMatchAll;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filtrar por categorías',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loadingCategorias)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_categoriasCatalogo.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No hay categorías disponibles.'),
                    )
                  else
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.38,
                        ),
                        child: Scrollbar(
                          thumbVisibility: _categoriasCatalogo.length > 8,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categoriasCatalogo.map((cat) {
                                final id =
                                    int.tryParse(cat['codigo'].toString()) ?? 0;
                                final name = cat['nombre'].toString();
                                return FilterChip(
                                  label: Text(name),
                                  selected: tempSelected.contains(id),
                                  onSelected: (selected) {
                                    setDialogState(() {
                                      if (selected) {
                                        tempSelected.add(id);
                                      } else {
                                        tempSelected.remove(id);
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
                    value: tempAll,
                    onChanged: (value) => setDialogState(() => tempAll = value),
                    title: const Text('Coincidir todas'),
                    subtitle:
                        const Text('Exige todas las categorías elegidas.'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategoriaIds = <int>[];
                    _categoriaMatchAll = false;
                  });
                  _saveListState();
                  Navigator.pop(dialogContext);
                },
                child: const Text('Limpiar'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedCategoriaIds = tempSelected;
                    _categoriaMatchAll = tempAll;
                  });
                  _saveListState();
                  Navigator.pop(dialogContext);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Aplicar'),
                    const SizedBox(width: 6),
                    Container(
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tempSelected.isEmpty
                            ? Colors.grey.shade500
                            : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${tempSelected.length}',
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
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    final hasSearch = _searchQuery.trim().isNotEmpty;
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Buscar charla o seminario…',
        prefixIcon: IconButton(
          tooltip: hasSearch ? 'Limpiar búsqueda' : 'Buscar',
          onPressed: hasSearch
              ? () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                  _saveListState();
                }
              : null,
          icon: Icon(hasSearch ? Icons.clear : Icons.search),
        ),
        suffixIcon: IconButton(
          tooltip: _showFilters ? 'Ocultar búsqueda' : 'Mostrar búsqueda',
          onPressed: _toggleFiltersVisibility,
          icon: Icon(
            _showFilters ? Icons.visibility_off_outlined : Icons.visibility,
          ),
        ),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) {
        setState(() => _searchQuery = v.trim());
        _saveListState();
      },
    );
  }

  // ─── NAVIGATION ──────────────────────────────────────────────────

  Future<void> _openCharla(CharlaSeminario item) async {
    final result = await Navigator.push<CharlaSeminario?>(
      context,
      MaterialPageRoute(
        builder: (_) => CharlaSeminarioDetailScreen(
          charla: item,
          previewMode: _isPreviewMode,
        ),
      ),
    );
    if (result != null && mounted) {
      _syncItem(result);
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Charlas y Seminarios'),
        actions: [
          if (!_showFilters)
            IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.search),
              onPressed: _isPreviewMode
                  ? () => _showPremiumRequiredForCharlasTools(context)
                  : _toggleFiltersVisibility,
            ),
          IconButton(
            tooltip: _selectedCategoriaIds.isEmpty
                ? 'Filtrar categorias'
                : 'Filtrar categorias (${_selectedCategoriaIds.length})',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_alt_outlined),
                if (_selectedCategoriaIds.isNotEmpty)
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
            onPressed: _isPreviewMode
                ? () => _showPremiumRequiredForCharlasTools(context)
                : _showCategoriaFilterDialog,
          ),
          PopupMenuButton<_TopActionCharlas>(
            tooltip: 'Más opciones',
            onSelected: _handleTopAction,
            itemBuilder: (context) => [
              const PopupMenuItem<_TopActionCharlas>(
                value: _TopActionCharlas.buscar,
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18),
                    SizedBox(width: 10),
                    Text('Buscar'),
                  ],
                ),
              ),
              PopupMenuItem<_TopActionCharlas>(
                value: _TopActionCharlas.filtrar,
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
              const PopupMenuItem<_TopActionCharlas>(
                value: _TopActionCharlas.actualizar,
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 10),
                    Text('Actualizar'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem<_TopActionCharlas>(
                value: _TopActionCharlas.ordenarNombre,
                checked: _orden == _OrdenCharlas.nombre,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Título')),
                    if (_orden == _OrdenCharlas.nombre)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<_TopActionCharlas>(
                value: _TopActionCharlas.ordenarFecha,
                checked: _orden == _OrdenCharlas.fechaAlta,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Recientes')),
                    if (_orden == _OrdenCharlas.fechaAlta)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<_TopActionCharlas>(
                value: _TopActionCharlas.ordenarPopular,
                checked: _orden == _OrdenCharlas.popular,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Populares')),
                    if (_orden == _OrdenCharlas.popular)
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
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            if (_isPreviewMode && index == 2) {
              Future.microtask(
                () => _showPremiumRequiredForCharlasTools(context),
              );
              _tabController.animateTo(0);
            }
          },
          tabs: const [
            Tab(text: 'Destacadas'),
            Tab(text: 'Todas'),
            Tab(text: 'Favoritas'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_showFilters && !_isPreviewMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _buildSearchField(),
            ),
          if (_selectedCategoriaIds.isNotEmpty && !_isPreviewMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                height: 40,
                child: Scrollbar(
                  thumbVisibility: _selectedCategoriaIds.length > 4,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _selectedCategoriaIds.map((id) {
                        final category = _categoriasCatalogo.firstWhere(
                          (item) =>
                              int.tryParse(item['codigo'].toString()) == id,
                          orElse: () =>
                              <String, dynamic>{'nombre': 'Categoría $id'},
                        );
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            label: Text(category['nombre'].toString()),
                            onDeleted: () {
                              setState(() {
                                _selectedCategoriaIds.remove(id);
                              });
                              _saveListState();
                            },
                          ),
                        );
                      }).toList(growable: false),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics:
                  _isPreviewMode ? const NeverScrollableScrollPhysics() : null,
              children: [
                _buildTab(
                  _destacadas,
                  _loadingDestacadas,
                  emptyText: 'No hay charlas destacadas.',
                ),
                _buildTab(
                  _todas,
                  _loadingTodas,
                  emptyText: 'No hay charlas disponibles.',
                  addUpsell: _isPreviewMode,
                ),
                _buildTab(
                  _favoritas,
                  _loadingFavoritas,
                  emptyText: 'No tienes charlas favoritas aún.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    List<CharlaSeminario> items,
    bool loading, {
    required String emptyText,
    bool addUpsell = false,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final shown = _isPreviewMode
        ? _buildPreviewCharlas(items, _nonPremiumPreviewCodes)
        : _applySearchAndFilters(items);

    if (shown.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _searchQuery.isNotEmpty
                ? 'Sin resultados para "$_searchQuery".'
                : emptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: addUpsell ? shown.length + 1 : shown.length,
        itemBuilder: (context, index) {
          if (addUpsell && index == shown.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
              child: PremiumUpsellCard(
                title: AppLocalizations.of(context)!.charlasPremiumTitle,
                subtitle: AppLocalizations.of(context)!.charlasPremiumSubtitle,
                subtitleHighlight: AppLocalizations.of(context)!
                    .charlasPremiumPreviewHighlight(
                  _catalogHighlightCount(_todas.length),
                ),
                onPressed: () => Navigator.pushNamed(context, '/premium_info'),
              ),
            );
          }
          return _buildCharlaCard(shown[index]);
        },
      ),
    );
  }

  Widget _buildCharlaCard(CharlaSeminario item) {
    final isPreviewMode = _isPreviewMode;
    final thumb = _thumbProvider(item);
    final hasSlides = item.totalDiapositivas > 0;
    final meGusta = item.meGusta == 'S';
    final esFavorito = item.favorito == 'S';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasSlides ? () => _openCharla(item) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniatura
            SizedBox(
              width: 100,
              height: 100,
              child: thumb != null
                  ? Image(image: thumb, fit: BoxFit.cover)
                  : Container(
                      color: Colors.deepPurple.shade50,
                      child: Icon(
                        Icons.present_to_all_rounded,
                        size: 40,
                        color: Colors.deepPurple.shade300,
                      ),
                    ),
            ),
            // Contenido
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.descripcion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.descripcion,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.view_carousel_outlined,
                          size: 14,
                          color: hasSlides ? Colors.deepPurple : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasSlides
                              ? '${item.totalDiapositivas} diap.'
                              : 'Sin diapositivas',
                          style: TextStyle(
                            fontSize: 11,
                            color: hasSlides ? Colors.deepPurple : Colors.grey,
                          ),
                        ),
                        if (item.categoriaNombres.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.label_outline,
                            size: 13,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              item.categoriaNombres.join(', '),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isPreviewMode) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Vista previa disponible. El contenido completo es Premium.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.deepOrange,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Acciones
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  icon: Icon(
                    meGusta ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: meGusta ? Colors.red : Colors.black38,
                  ),
                  onPressed: () => _toggleLike(item),
                ),
                if (item.totalLikes > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${item.totalLikes}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  icon: Icon(
                    esFavorito ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                    color: esFavorito ? Colors.amber.shade700 : Colors.black38,
                  ),
                  onPressed: () => _toggleFavorito(item),
                ),
                if (hasSlides)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 6),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.deepPurple.shade300,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
