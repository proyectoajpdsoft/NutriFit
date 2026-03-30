import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutri_app/models/sustitucion_saludable.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/consejo_receta_pdf_service.dart';
import 'package:provider/provider.dart';

Future<String> _buildNutriFitClipboardSignature(BuildContext context) async {
  final api = context.read<ApiService>();
  final param = await api.getParametro('nutricionista_nombre');
  final nombre = (param?['valor']?.toString() ?? '').trim();
  return nombre.isEmpty ? 'App NutriFit' : 'App NutriFit $nombre';
}

class SustitucionesSaludablesScreen extends StatefulWidget {
  const SustitucionesSaludablesScreen({
    super.key,
    this.initialSearchQuery = '',
    this.initialTabIndex = 0,
    this.initialCategoriaIds = const <int>[],
  });

  final String initialSearchQuery;
  final int initialTabIndex;
  final List<int> initialCategoriaIds;

  @override
  State<SustitucionesSaludablesScreen> createState() =>
      _SustitucionesSaludablesScreenState();
}

class _SustitucionesSaludablesScreenState
    extends State<SustitucionesSaludablesScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 20;

  final Map<String, MemoryImage> _coverCache = <String, MemoryImage>{};
  Timer? _searchDebounce;

  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  List<SustitucionSaludable> _destacadas = <SustitucionSaludable>[];
  List<SustitucionSaludable> _todas = <SustitucionSaludable>[];
  List<SustitucionSaludable> _favoritas = <SustitucionSaludable>[];
  List<Map<String, dynamic>> _categoriasCatalogo = <Map<String, dynamic>>[];

  bool _loadingDestacadas = false;
  bool _loadingTodas = false;
  bool _loadingFavoritas = false;
  bool _loadingMoreDestacadas = false;
  bool _loadingMoreTodas = false;
  bool _loadingMoreFavoritas = false;
  bool _loadingCategorias = false;
  bool _hasMoreDestacadas = true;
  bool _hasMoreTodas = true;
  bool _hasMoreFavoritas = true;
  int _totalDestacadas = 0;
  int _totalTodas = 0;
  int _totalFavoritas = 0;
  bool _searchVisible = false;
  String _searchQuery = '';
  String _sortMode = 'fecha';
  bool _sortAscending = false;
  List<int> _selectedCategoriaIds = <int>[];
  bool _categoriaMatchAll = false;

  bool get _isPremiumEligible {
    final auth = context.read<AuthService>();
    return auth.isPremium ||
        auth.userType == 'Nutricionista' ||
        auth.userType == 'Administrador';
  }

  String? get _userCode => context.read<AuthService>().userCode;

  String get _normalizedSearchQuery => _searchQuery.trim().toLowerCase();

  DateTime _getSustitucionDate(SustitucionSaludable item) {
    return item.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _getPopularScore(SustitucionSaludable item) {
    final likes = item.totalLikes;
    final favoritoActual = item.favorito == 'S' ? 2 : 0;
    final meGustaActual = item.meGusta == 'S' ? 1 : 0;
    return (likes * 3) + favoritoActual + meGustaActual;
  }

  int _currentTabCount() {
    switch (_tabController.index) {
      case 0:
        return _totalDestacadas;
      case 2:
        return _totalFavoritas;
      case 1:
      default:
        return _totalTodas;
    }
  }

  void _toggleSearchVisibility() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchQuery = '';
        _searchCtrl.clear();
      }
    });

    if (!_searchVisible) {
      _reloadSearchResults();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sortMode = prefs.getString('sust_sortMode') ?? 'fecha';
      _sortAscending = prefs.getBool('sust_sortAscending') ?? false;
      _selectedCategoriaIds =
          prefs.getStringList('sust_categoriaIds')?.map(int.parse).toList() ??
              <int>[];
      _categoriaMatchAll = prefs.getBool('sust_categoriaMatchAll') ?? false;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString('sust_sortMode', _sortMode),
      prefs.setBool('sust_sortAscending', _sortAscending),
      prefs.setStringList('sust_categoriaIds',
          _selectedCategoriaIds.map((e) => e.toString()).toList()),
      prefs.setBool('sust_categoriaMatchAll', _categoriaMatchAll),
    ]);
  }

  Future<void> _handleAppBarMenuAction(String value) async {
    switch (value) {
      case 'sort_title':
        setState(() {
          if (_sortMode == 'titulo') {
            _sortAscending = !_sortAscending;
          } else {
            _sortMode = 'titulo';
            _sortAscending = true;
          }
        });
        _savePreferences();
        break;
      case 'sort_recent':
        setState(() {
          if (_sortMode == 'fecha') {
            _sortAscending = !_sortAscending;
          } else {
            _sortMode = 'fecha';
            _sortAscending = false;
          }
        });
        _savePreferences();
        break;
      case 'sort_popular':
        setState(() {
          if (_sortMode == 'popular') {
            _sortAscending = !_sortAscending;
          } else {
            _sortMode = 'popular';
            _sortAscending = false;
          }
        });
        _savePreferences();
        break;
      case 'filter':
        await _showCategoriaFilterDialog();
        break;
      case 'search':
        _toggleSearchVisibility();
        break;
      case 'refresh':
        await _refreshCurrentTab();
        break;
    }
  }

  Future<void> _refreshCurrentTab() async {
    final tabIndex = _tabController.index;
    if (tabIndex == 0) {
      await _loadDestacadas(reset: true);
    } else if (tabIndex == 1) {
      await _loadTodas(reset: true);
    } else {
      await _loadFavoritas(reset: true);
    }
  }

  @override
  void initState() {
    super.initState();
    final initialTabIndex = widget.initialTabIndex.clamp(0, 2);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTabIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _selectedCategoriaIds = List<int>.from(widget.initialCategoriaIds);
    _categoriaMatchAll = false;
    _searchQuery = widget.initialSearchQuery.trim();
    _searchVisible = _searchQuery.isNotEmpty;
    _searchCtrl.text = _searchQuery;
    if (_isPremiumEligible) {
      _loadPreferences();
      _loadCategorias();
      _loadTotals();
      _loadDestacadas();
      _loadTodas();
      _loadFavoritas();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _buildApiPath(String path, Map<String, String?> queryParameters) {
    final sanitized = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value != null && value.isNotEmpty) {
        sanitized[key] = value;
      }
    });
    return Uri(
      path: path,
      queryParameters: sanitized.isEmpty ? null : sanitized,
    ).toString();
  }

  Future<void> _reloadSearchResults() async {
    await _loadTotals();
    await _loadDestacadas(reset: true);
    await _loadTodas(reset: true);
    await _loadFavoritas(reset: true);
  }

  Future<void> _loadTotals() async {
    final searchSnapshot = _searchQuery.trim();
    await Future.wait<void>([
      _loadDestacadasTotal(searchSnapshot),
      _loadTodasTotal(searchSnapshot),
      _loadFavoritasTotal(searchSnapshot),
    ]);
  }

  Future<void> _loadDestacadasTotal(String searchSnapshot) async {
    try {
      final response = await context.read<ApiService>().get(
            _buildApiPath('api/sustituciones_saludables.php', {
              'total': '1',
              'portada': 'S',
              'q': searchSnapshot,
            }),
          );
      if (response.statusCode != 200 || !mounted) {
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final total = int.tryParse((data['total'] ?? '0').toString()) ?? 0;
      if (searchSnapshot != _searchQuery.trim()) {
        return;
      }
      setState(() => _totalDestacadas = total);
    } catch (_) {}
  }

  Future<void> _loadTodasTotal(String searchSnapshot) async {
    try {
      final response = await context.read<ApiService>().get(
            _buildApiPath('api/sustituciones_saludables.php', {
              'total': '1',
              'publico': '1',
              'q': searchSnapshot,
            }),
          );
      if (response.statusCode != 200 || !mounted) {
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final total = int.tryParse((data['total'] ?? '0').toString()) ?? 0;
      if (searchSnapshot != _searchQuery.trim()) {
        return;
      }
      setState(() => _totalTodas = total);
    } catch (_) {}
  }

  Future<void> _loadFavoritasTotal(String searchSnapshot) async {
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) {
      if (mounted) {
        setState(() => _totalFavoritas = 0);
      }
      return;
    }

    try {
      final response = await context.read<ApiService>().get(
            _buildApiPath('api/sustituciones_saludables_usuarios.php', {
              'favoritos': '1',
              'total': '1',
              'usuario': userCode,
              'q': searchSnapshot,
            }),
          );
      if (response.statusCode != 200 || !mounted) {
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final total = int.tryParse((data['total'] ?? '0').toString()) ?? 0;
      if (searchSnapshot != _searchQuery.trim()) {
        return;
      }
      setState(() => _totalFavoritas = total);
    } catch (_) {}
  }

  void _scheduleSearchReload() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || !_isPremiumEligible) {
        return;
      }
      _reloadSearchResults();
    });
  }

  Future<void> _loadCategorias() async {
    setState(() => _loadingCategorias = true);
    try {
      final response = await context
          .read<ApiService>()
          .get('api/sustituciones_saludables.php?categorias=1');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        if (!mounted) return;
        setState(() {
          _categoriasCatalogo = data
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(growable: false);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingCategorias = false);
      }
    }
  }

  Future<void> _loadDestacadas({bool reset = false}) async {
    final searchSnapshot = _searchQuery.trim();
    final offset = reset ? 0 : _destacadas.length;
    if (!reset &&
        (_loadingDestacadas || _loadingMoreDestacadas || !_hasMoreDestacadas)) {
      return;
    }

    setState(() {
      if (reset) {
        _loadingDestacadas = true;
        _hasMoreDestacadas = true;
      } else {
        _loadingMoreDestacadas = true;
      }
    });

    try {
      final response = await context.read<ApiService>().get(
            _buildApiPath('api/sustituciones_saludables.php', {
              'portada': '1',
              'limit': '$_pageSize',
              'offset': '$offset',
              'q': searchSnapshot,
            }),
          );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final items = data
            .map((item) => SustitucionSaludable.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(growable: false);
        if (searchSnapshot != _searchQuery.trim()) return;
        if (!mounted) return;
        setState(() {
          _destacadas =
              reset ? items : <SustitucionSaludable>[..._destacadas, ...items];
          _hasMoreDestacadas = items.length >= _pageSize;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (reset) {
            _destacadas = <SustitucionSaludable>[];
          }
          _hasMoreDestacadas = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingDestacadas = false;
          _loadingMoreDestacadas = false;
        });
      }
    }
  }

  Future<void> _loadTodas({bool reset = false}) async {
    final searchSnapshot = _searchQuery.trim();
    final offset = reset ? 0 : _todas.length;
    if (!reset && (_loadingTodas || _loadingMoreTodas || !_hasMoreTodas)) {
      return;
    }

    setState(() {
      if (reset) {
        _loadingTodas = true;
        _hasMoreTodas = true;
      } else {
        _loadingMoreTodas = true;
      }
    });

    try {
      final response = await context.read<ApiService>().get(
            _buildApiPath('api/sustituciones_saludables.php', {
              'publico': '1',
              'limit': '$_pageSize',
              'offset': '$offset',
              'q': searchSnapshot,
            }),
          );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final items = data
            .map((item) => SustitucionSaludable.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(growable: false);
        if (searchSnapshot != _searchQuery.trim()) return;
        if (!mounted) return;
        setState(() {
          _todas = reset ? items : <SustitucionSaludable>[..._todas, ...items];
          _hasMoreTodas = items.length >= _pageSize;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (reset) {
            _todas = <SustitucionSaludable>[];
          }
          _hasMoreTodas = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingTodas = false;
          _loadingMoreTodas = false;
        });
      }
    }
  }

  Future<void> _loadFavoritas({bool reset = false}) async {
    final userCode = _userCode;
    final searchSnapshot = _searchQuery.trim();
    if (userCode == null || userCode.isEmpty) {
      setState(() {
        _loadingFavoritas = false;
        _loadingMoreFavoritas = false;
        _hasMoreFavoritas = false;
        if (reset) {
          _favoritas = <SustitucionSaludable>[];
        }
      });
      return;
    }

    final offset = reset ? 0 : _favoritas.length;
    if (!reset &&
        (_loadingFavoritas || _loadingMoreFavoritas || !_hasMoreFavoritas)) {
      return;
    }

    setState(() {
      if (reset) {
        _loadingFavoritas = true;
        _hasMoreFavoritas = true;
      } else {
        _loadingMoreFavoritas = true;
      }
    });

    try {
      final response = await context.read<ApiService>().get(
            _buildApiPath('api/sustituciones_saludables_usuarios.php', {
              'favoritos': '1',
              'usuario': userCode,
              'limit': '$_pageSize',
              'offset': '$offset',
              'q': searchSnapshot,
            }),
          );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final items = data
            .map((item) => SustitucionSaludable.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(growable: false);
        if (searchSnapshot != _searchQuery.trim()) return;
        if (!mounted) return;
        setState(() {
          _favoritas =
              reset ? items : <SustitucionSaludable>[..._favoritas, ...items];
          _hasMoreFavoritas = items.length >= _pageSize;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (reset) {
            _favoritas = <SustitucionSaludable>[];
          }
          _hasMoreFavoritas = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingFavoritas = false;
          _loadingMoreFavoritas = false;
        });
      }
    }
  }

  String _cacheKey(SustitucionSaludable item) {
    final raw = (item.imagenPortada ?? item.imagenMiniatura ?? '').trim();
    if (raw.isEmpty) {
      return '';
    }
    return '${item.codigo ?? item.titulo}|${raw.hashCode}';
  }

  MemoryImage? _coverProvider(SustitucionSaludable item) {
    final raw = (item.imagenPortada ?? item.imagenMiniatura ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }

    final key = _cacheKey(item);
    final cached = _coverCache[key];
    if (cached != null) {
      return cached;
    }

    try {
      final provider = MemoryImage(base64Decode(raw));
      _coverCache[key] = provider;
      return provider;
    } catch (_) {
      return null;
    }
  }

  bool _matchesCategorias(SustitucionSaludable item) {
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

  List<SustitucionSaludable> _applySearch(List<SustitucionSaludable> items) {
    final query = _normalizedSearchQuery;
    final filtered = items.where((item) {
      final searchable = [
        item.titulo,
        item.subtitulo,
        item.alimentoOrigen,
        item.sustitutoPrincipal,
        item.equivalenciaTexto,
        item.objetivoMacro,
        item.texto,
        item.categoriaNombres.join(' '),
      ].join(' ').toLowerCase();

      final matchesQuery = query.isEmpty || searchable.contains(query);
      return matchesQuery && _matchesCategorias(item);
    }).toList(growable: false);

    filtered.sort((a, b) {
      switch (_sortMode) {
        case 'popular':
          final popularCompare = _sortAscending
              ? _getPopularScore(a).compareTo(_getPopularScore(b))
              : _getPopularScore(b).compareTo(_getPopularScore(a));
          if (popularCompare != 0) {
            return popularCompare;
          }
          return _sortAscending
              ? _getSustitucionDate(a).compareTo(_getSustitucionDate(b))
              : _getSustitucionDate(b).compareTo(_getSustitucionDate(a));
        case 'titulo':
          final titleCompare =
              a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
          return _sortAscending ? titleCompare : -titleCompare;
        case 'fecha':
        default:
          final dateCompare =
              _getSustitucionDate(a).compareTo(_getSustitucionDate(b));
          if (dateCompare != 0) {
            return _sortAscending ? dateCompare : -dateCompare;
          }
          final titleCompare =
              a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
          return _sortAscending ? titleCompare : -titleCompare;
      }
    });
    return filtered;
  }

  void _syncItem(SustitucionSaludable updated) {
    void patch(List<SustitucionSaludable> list,
        {bool removeWhenNotFav = false}) {
      final index = list.indexWhere((item) => item.codigo == updated.codigo);
      if (index == -1) {
        if (!removeWhenNotFav && updated.favorito == 'S') {
          list.insert(0, updated);
        }
        return;
      }
      if (removeWhenNotFav && updated.favorito != 'S') {
        list.removeAt(index);
        return;
      }
      list[index] = updated;
    }

    setState(() {
      patch(_destacadas);
      patch(_todas);
      patch(_favoritas, removeWhenNotFav: true);
      if (updated.favorito == 'S' &&
          !_favoritas.any((item) => item.codigo == updated.codigo)) {
        _favoritas.insert(0, updated);
      }
    });
  }

  Future<void> _toggleLike(SustitucionSaludable item) async {
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) {
      return;
    }

    final prev = item.meGusta ?? 'N';
    try {
      final response = await context.read<ApiService>().post(
            'api/sustituciones_saludables_usuarios.php?toggle_like=1',
            body: jsonEncode(<String, dynamic>{
              'codigo_sustitucion': item.codigo,
              'codigo_usuario': int.parse(userCode),
            }),
          );
      if (response.statusCode == 200) {
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

  Future<void> _toggleFavorito(SustitucionSaludable item) async {
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) {
      return;
    }

    try {
      final response = await context.read<ApiService>().post(
            'api/sustituciones_saludables_usuarios.php?toggle_favorito=1',
            body: jsonEncode(<String, dynamic>{
              'codigo_sustitucion': item.codigo,
              'codigo_usuario': int.parse(userCode),
            }),
          );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        item.favorito = (data['favorito'] ?? 'N').toString();
        _syncItem(item);
        await _loadFavoritasTotal(_searchQuery.trim());
      }
    } catch (_) {}
  }

  Future<void> _copySustitucionToClipboard(SustitucionSaludable item) async {
    try {
      final description =
          item.texto.isEmpty ? item.resumenPrincipal : item.texto;
      final firma = await _buildNutriFitClipboardSignature(context);
      final textToCopy = '${item.titulo}\n\n$description\n\n$firma';
      await Clipboard.setData(ClipboardData(text: textToCopy));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copiado al portapapeles'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al copiar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generateSustitucionPdfFromCard(
    SustitucionSaludable item,
  ) async {
    try {
      final apiService = context.read<ApiService>();
      final description =
          item.texto.isEmpty ? item.resumenPrincipal : item.texto;
      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: item.titulo,
        contenido: description,
        tipo: 'consejo',
        imagenPortadaBase64: item.imagenPortada,
        fileName:
            'sustitucion_${item.titulo.replaceAll(RegExp(r'[^a-zA-Z0-9_\\-]+'), '_').toLowerCase()}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCategoriaFilterDialog() async {
    if (_categoriasCatalogo.isEmpty && !_loadingCategorias) {
      await _loadCategorias();
    }

    List<int> tempSelected = List<int>.from(_selectedCategoriaIds);
    bool tempAll = _categoriaMatchAll;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Filtrar por categorías',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(dialogContext),
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
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loadingCategorias)
                  const LinearProgressIndicator(minHeight: 2)
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
                  subtitle: const Text('Exige todas las categorías elegidas.'),
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
                _savePreferences();
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
                _savePreferences();
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
      ),
    );
  }

  Future<void> _openDetail(SustitucionSaludable item) async {
    final result = await Navigator.push<SustitucionSaludable>(
      context,
      MaterialPageRoute<SustitucionSaludable>(
        builder: (_) => SustitucionSaludableDetailScreen(
          item: item,
          initialTabIndex: _tabController.index,
        ),
      ),
    );
    if (result != null) {
      _syncItem(result);
    }
  }

  Widget _buildPremiumRequired() {
    return Scaffold(
      appBar: AppBar(title: const Text('Sustituciones')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium,
                size: 54,
                color: Colors.amber.shade700,
              ),
              const SizedBox(height: 16),
              const Text(
                'Esta utilidad está disponible para usuarios Premium.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                'Desde aquí podrás consultar sustituciones saludables, filtros por categorías, favoritos y equivalencias rápidas sin romper tu plan.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/premium_info'),
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Hazte premium'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(SustitucionSaludable item) {
    final cover = _coverProvider(item);
    final description = item.texto.isEmpty ? item.resumenPrincipal : item.texto;
    final isDescriptionTruncated = description.length > 100;
    final shortDescription = isDescriptionTruncated
        ? '${description.substring(0, 100)}...'
        : description;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (cover != null)
                  Image(
                    image: cover,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  )
                else
                  Container(
                    height: 250,
                    width: double.infinity,
                    color: Colors.green.shade50,
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      size: 72,
                      color: Colors.green,
                    ),
                  ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.objetivoMacro.trim().isEmpty
                          ? 'Sustitución premium'
                          : item.objetivoMacro,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _toggleLike(item),
                    icon: Icon(
                      item.meGusta == 'S'
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: item.meGusta == 'S' ? Colors.red : null,
                    ),
                  ),
                  Text(
                    '${item.totalLikes} me gusta',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _toggleFavorito(item),
                    icon: Icon(
                      item.favorito == 'S'
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: item.favorito == 'S' ? Colors.amber : null,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copySustitucionToClipboard(item),
                    tooltip: 'Copiar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    onPressed: () => _generateSustitucionPdfFromCard(item),
                    tooltip: 'PDF',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  HashtagText(
                    text: shortDescription,
                    style: TextStyle(color: Colors.grey[700]),
                    onHashtagTap: (hashtag) {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => SustitucionesSaludablesScreen(
                            initialSearchQuery: hashtag,
                            initialTabIndex: _tabController.index,
                          ),
                        ),
                      );
                    },
                  ),
                  if (isDescriptionTruncated) const SizedBox(height: 4),
                  if (isDescriptionTruncated)
                    const Text(
                      'Toca para ver el detalle completo',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody({
    required bool loading,
    required List<SustitucionSaludable> source,
    required String emptyText,
    required bool hasMore,
    required bool loadingMore,
    required Future<void> Function() onLoadMore,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _applySearch(source);
    if (items.isEmpty) {
      return Center(
        child: Text(emptyText),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (hasMore &&
            !loadingMore &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 300) {
          onLoadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadDestacadas(reset: true);
          await _loadTodas(reset: true);
          await _loadFavoritas(reset: true);
        },
        child: ListView.builder(
          padding: EdgeInsets.only(
            top: 8,
            bottom: 88 + MediaQuery.of(context).padding.bottom,
          ),
          itemCount: items.length + (loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _buildCard(items[index]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPremiumEligible) {
      return _buildPremiumRequired();
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Sustituciones',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_currentTabCount()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!_searchVisible)
            IconButton(
              tooltip: 'Buscar',
              onPressed: _toggleSearchVisibility,
              icon: const Icon(Icons.search),
            ),
          IconButton(
            tooltip: _selectedCategoriaIds.isEmpty
                ? 'Filtrar categorias'
                : 'Filtrar categorias (${_selectedCategoriaIds.length})',
            onPressed: _showCategoriaFilterDialog,
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
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              _handleAppBarMenuAction(value);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18),
                    SizedBox(width: 10),
                    Text('Buscar'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'filter',
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
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 10),
                    Text('Actualizar'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem<String>(
                value: 'sort_title',
                checked: _sortMode == 'titulo',
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Título')),
                    if (_sortMode == 'titulo')
                      Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<String>(
                value: 'sort_recent',
                checked: _sortMode == 'fecha',
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Recientes')),
                    if (_sortMode == 'fecha')
                      Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<String>(
                value: 'sort_popular',
                checked: _sortMode == 'popular',
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Populares')),
                    if (_sortMode == 'popular')
                      Icon(
                        _sortAscending
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
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: 'Destacadas'),
            Tab(icon: Icon(Icons.swap_horiz), text: 'Todas'),
            Tab(icon: Icon(Icons.bookmark), text: 'Favoritas'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_searchVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  labelText: 'Buscar sustituciones o hashtags',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Ocultar búsqueda',
                    icon: const Icon(Icons.close),
                    onPressed: _toggleSearchVisibility,
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _scheduleSearchReload();
                },
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabBody(
                  loading: _loadingDestacadas,
                  source: _destacadas,
                  emptyText: 'No hay sustituciones destacadas.',
                  hasMore: _hasMoreDestacadas,
                  loadingMore: _loadingMoreDestacadas,
                  onLoadMore: () => _loadDestacadas(),
                ),
                _buildTabBody(
                  loading: _loadingTodas,
                  source: _todas,
                  emptyText: 'No hay sustituciones disponibles.',
                  hasMore: _hasMoreTodas,
                  loadingMore: _loadingMoreTodas,
                  onLoadMore: () => _loadTodas(),
                ),
                _buildTabBody(
                  loading: _loadingFavoritas,
                  source: _favoritas,
                  emptyText: 'No tienes sustituciones favoritas todavía.',
                  hasMore: _hasMoreFavoritas,
                  loadingMore: _loadingMoreFavoritas,
                  onLoadMore: () => _loadFavoritas(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SustitucionSaludableDetailScreen extends StatefulWidget {
  const SustitucionSaludableDetailScreen({
    super.key,
    required this.item,
    this.initialTabIndex = 0,
  });

  final SustitucionSaludable item;
  final int initialTabIndex;

  @override
  State<SustitucionSaludableDetailScreen> createState() =>
      _SustitucionSaludableDetailScreenState();
}

class _SustitucionSaludableDetailScreenState
    extends State<SustitucionSaludableDetailScreen> {
  static final RegExp _hashtagRegex =
      RegExp(r'#[\wáéíóúÁÉÍÓÚñÑüÜ]+', caseSensitive: false);
  static final RegExp _genericTokenRegex = RegExp(r'\[\[([^\[\]]+)\]\]');
  static final RegExp _structuredLinkTokenRegex = RegExp(
    r'^(.*?)\s*enlace_(consejo|receta|sustitucion_saludable|aditivo|suplemento)_(\d+)\s*$',
    caseSensitive: false,
    unicode: true,
  );
  static final RegExp _wordRegex =
      RegExp(r'[a-záéíóúñü]{3,}', caseSensitive: false);
  static const Set<String> _stopWords = {
    'para',
    'con',
    'sin',
    'por',
    'que',
    'como',
    'del',
    'las',
    'los',
    'una',
    'uno',
    'unos',
    'unas',
    'pero',
    'sobre',
    'entre',
    'desde',
    'hasta',
    'cuando',
    'donde',
    'este',
    'esta',
    'estos',
    'estas',
    'solo',
    'cada',
    'muy',
    'mas',
    'más',
    'tambien',
    'también',
    'porque',
    'sus',
    'ese',
    'esa',
    'eso',
  };

  late SustitucionSaludable _item;
  bool _loading = true;
  List<SustitucionSaludable> _relacionados = [];
  bool _isLoadingRelacionados = true;
  int _maxRelacionados = 5;
  final ScrollController _relacionadosScrollController = ScrollController();

  Future<void> _openCategoriaFilter({
    required String categoriaNombre,
    int? categoriaId,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SustitucionesSaludablesScreen(
          initialSearchQuery: categoriaId == null ? categoriaNombre : '',
          initialTabIndex: widget.initialTabIndex,
          initialCategoriaIds:
              categoriaId == null ? const <int>[] : <int>[categoriaId],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadDetail();
    _loadRelacionados();
  }

  @override
  void dispose() {
    _relacionadosScrollController.dispose();
    super.dispose();
  }

  String? get _userCode => context.read<AuthService>().userCode;

  String _cleanTextForSimilarity(String text) {
    return text
        .replaceAll(RegExp(r'[^\wáéíóúñü# ]', caseSensitive: false), ' ')
        .toLowerCase();
  }

  Set<String> _extractHashtags(String text) {
    return _hashtagRegex
        .allMatches(text.toLowerCase())
        .map((match) => (match.group(0) ?? '').trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  Set<String> _extractWords(String text) {
    final cleaned = _cleanTextForSimilarity(text);
    return _wordRegex
        .allMatches(cleaned)
        .map((match) => (match.group(0) ?? '').trim())
        .where((word) => word.isNotEmpty && !_stopWords.contains(word))
        .toSet();
  }

  double _jaccardSimilarity(Set<dynamic> a, Set<dynamic> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final intersection = a.intersection(b).length;
    if (intersection == 0) return 0;
    final union = a.union(b).length;
    if (union == 0) return 0;
    return intersection / union;
  }

  double _similarityScore(
    SustitucionSaludable base,
    SustitucionSaludable candidate,
  ) {
    final baseCategorias = base.categoriaIds.toSet();
    final candidateCategorias = candidate.categoriaIds.toSet();

    final baseCombinedText =
        '${base.titulo} ${base.texto} ${base.alimentoOrigen} ${base.sustitutoPrincipal}';
    final candidateCombinedText =
        '${candidate.titulo} ${candidate.texto} ${candidate.alimentoOrigen} ${candidate.sustitutoPrincipal}';

    final baseHashtags = _extractHashtags(baseCombinedText);
    final candidateHashtags = _extractHashtags(candidateCombinedText);

    final baseTitleWords = _extractWords(base.titulo);
    final candidateTitleWords = _extractWords(candidate.titulo);

    final baseBodyWords = _extractWords(baseCombinedText);
    final candidateBodyWords = _extractWords(candidateCombinedText);

    final categoryScore =
        _jaccardSimilarity(baseCategorias, candidateCategorias);
    final hashtagScore = _jaccardSimilarity(baseHashtags, candidateHashtags);
    final titleScore = _jaccardSimilarity(baseTitleWords, candidateTitleWords);
    final bodyScore = _jaccardSimilarity(baseBodyWords, candidateBodyWords);

    var total = (categoryScore * 4.0) +
        (hashtagScore * 5.0) +
        (titleScore * 3.0) +
        (bodyScore * 2.0);

    final crossOverlapA =
        baseTitleWords.intersection(candidateBodyWords).isNotEmpty;
    final crossOverlapB =
        candidateTitleWords.intersection(baseBodyWords).isNotEmpty;
    if (crossOverlapA || crossOverlapB) {
      total += 1.0;
    }

    return total;
  }

  Future<void> _loadRelacionados() async {
    setState(() {
      _isLoadingRelacionados = true;
    });

    try {
      final authService = context.read<AuthService>();
      final apiService = context.read<ApiService>();

      final maxParam = await apiService
          .getParametro('numero_maximo_relacionados_consejos_recetas');
      final parsedMax = int.tryParse((maxParam?['valor'] ?? '').toString());
      final maxRelacionados =
          parsedMax == null || parsedMax <= 0 ? 5 : parsedMax.clamp(1, 20);

      String url = 'api/sustituciones_saludables.php?publico=1&limit=200';
      if (authService.userCode != null && !authService.isGuestMode) {
        url += '&codigo_usuario=${authService.userCode}';
      }

      final response = await apiService.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final allItems = data
            .map(
              (item) => SustitucionSaludable.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();

        final candidatos = allItems.where((item) {
          if (item.codigo == null || _item.codigo == null) {
            return false;
          }
          return item.codigo != _item.codigo;
        }).toList();

        final scored = candidatos
            .map((item) => MapEntry(item, _similarityScore(_item, item)))
            .where((entry) => entry.value > 0)
            .toList();

        scored.sort((a, b) {
          final byScore = b.value.compareTo(a.value);
          if (byScore != 0) return byScore;
          return b.key.totalLikes.compareTo(a.key.totalLikes);
        });

        if (mounted) {
          setState(() {
            _maxRelacionados = maxRelacionados;
            _relacionados =
                scored.map((entry) => entry.key).take(maxRelacionados).toList();
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _relacionados = <SustitucionSaludable>[];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRelacionados = false;
        });
      }
    }
  }

  String _buildResumenRelacionado(SustitucionSaludable item) {
    final cleaned = item.resumenPrincipal
        .replaceAllMapped(_genericTokenRegex, (match) {
          final raw = (match.group(1) ?? '').trim();
          final tokenMatch = RegExp(
            r'^(img|documento|enlace):(\d+)$',
            caseSensitive: false,
          ).firstMatch(raw);
          if (tokenMatch != null) {
            return (tokenMatch.group(1) ?? '').toLowerCase() == 'enlace'
                ? 'enlace'
                : '';
          }

          final structured = _structuredLinkTokenRegex.firstMatch(raw);
          if (structured != null) {
            final prefix = (structured.group(1) ?? '').trim();
            final type = (structured.group(2) ?? '').toLowerCase();
            final article = type == 'sustitucion_saludable' ? 'la' : 'el';
            String typeLabel;
            switch (type) {
              case 'consejo':
                typeLabel = 'consejo';
                break;
              case 'receta':
                typeLabel = 'receta';
                break;
              case 'sustitucion_saludable':
                typeLabel = 'sustitución saludable';
                break;
              case 'aditivo':
                typeLabel = 'aditivo';
                break;
              case 'suplemento':
                typeLabel = 'suplemento';
                break;
              default:
                typeLabel = type;
            }
            final start = prefix.isEmpty ? 'Véase' : prefix;
            return '$start enlace a $article $typeLabel';
          }

          return raw;
        })
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length <= 100) return cleaned;
    return '${cleaned.substring(0, 100)}...';
  }

  Widget _buildRelacionadoCard(SustitucionSaludable item) {
    final relatedImageRaw =
        (item.imagenPortada ?? item.imagenMiniatura ?? '').trim();
    Widget header;
    if (relatedImageRaw.isNotEmpty) {
      try {
        header = ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Image.memory(
            base64Decode(relatedImageRaw),
            height: 95,
            width: double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {
        header = Container(
          height: 95,
          color: Colors.grey[200],
          child: const Icon(Icons.swap_horiz_rounded, size: 28),
        );
      }
    } else {
      header = Container(
        height: 95,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: const Icon(Icons.swap_horiz_rounded, size: 28),
      );
    }

    return SizedBox(
      width: 220,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SustitucionSaludableDetailScreen(
                  item: item,
                  initialTabIndex: widget.initialTabIndex,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _buildResumenRelacionado(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadDetail() async {
    if (_item.codigo == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final response = await context
          .read<ApiService>()
          .get('api/sustituciones_saludables.php?codigo=${_item.codigo}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        if (!mounted) return;
        setState(() {
          _item = SustitucionSaludable.fromJson(data);
        });
      }
    } catch (_) {
      // Mantiene los datos ya cargados de la tarjeta si falla el refresco.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleLike() async {
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) {
      return;
    }
    final prev = _item.meGusta ?? 'N';
    final response = await context.read<ApiService>().post(
          'api/sustituciones_saludables_usuarios.php?toggle_like=1',
          body: jsonEncode(<String, dynamic>{
            'codigo_sustitucion': _item.codigo,
            'codigo_usuario': int.parse(userCode),
          }),
        );
    if (response.statusCode == 200 && mounted) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _item.meGusta = (data['me_gusta'] ?? 'N').toString();
        if (prev != 'S' && _item.meGusta == 'S') {
          _item.totalLikes += 1;
        } else if (prev == 'S' &&
            _item.meGusta != 'S' &&
            _item.totalLikes > 0) {
          _item.totalLikes -= 1;
        }
      });
    }
  }

  Future<void> _toggleFavorito() async {
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) {
      return;
    }
    final response = await context.read<ApiService>().post(
          'api/sustituciones_saludables_usuarios.php?toggle_favorito=1',
          body: jsonEncode(<String, dynamic>{
            'codigo_sustitucion': _item.codigo,
            'codigo_usuario': int.parse(userCode),
          }),
        );
    if (response.statusCode == 200 && mounted) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _item.favorito = (data['favorito'] ?? 'N').toString();
      });
    }
  }

  Future<void> _copyToClipboard() async {
    try {
      final description =
          _item.texto.isEmpty ? _item.resumenPrincipal : _item.texto;
      final firma = await _buildNutriFitClipboardSignature(context);
      final textToCopy = '${_item.titulo}\n\n$description\n\n$firma';
      await Clipboard.setData(ClipboardData(text: textToCopy));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copiado al portapapeles'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al copiar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generatePdf() async {
    try {
      final apiService = context.read<ApiService>();
      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: _item.titulo,
        contenido: _item.texto,
        tipo: 'sustitucion',
        imagenPortadaBase64: _item.imagenPortada,
        subtitulo: _item.subtitulo,
        alimentoOrigen: _item.alimentoOrigen,
        sustitutoPrincipal: _item.sustitutoPrincipal,
        equivalenciaTexto: _item.equivalenciaTexto,
        objetivoMacro: _item.objetivoMacro,
        fileName:
            'sustitucion_${_item.titulo.replaceAll(RegExp(r'[^a-zA-Z0-9_\\-]+'), '_').toLowerCase()}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageRaw =
        (_item.imagenPortada ?? _item.imagenMiniatura ?? '').trim();
    final imageBytes = imageRaw.isNotEmpty ? base64Decode(imageRaw) : null;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final contentBottomPadding = bottomInset > 0 ? bottomInset + 24 : 32.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sustitución saludable'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, contentBottomPadding),
              children: [
                if (imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(
                      imageBytes,
                      height: 260,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (imageBytes == null)
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade100,
                          Colors.orange.shade50,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        size: 78,
                        color: Colors.green,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _toggleLike,
                        icon: Icon(
                          _item.meGusta == 'S'
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _item.meGusta == 'S' ? Colors.red : null,
                        ),
                      ),
                      Text(
                        '${_item.totalLikes} me gusta',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _toggleFavorito,
                        icon: Icon(
                          _item.favorito == 'S'
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: _item.favorito == 'S' ? Colors.amber : null,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: _copyToClipboard,
                        tooltip: 'Copiar',
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        onPressed: _generatePdf,
                        tooltip: 'PDF',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _item.titulo,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                ),
                if (_item.subtitulo.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _item.subtitulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cambio recomendado',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.fastfood_outlined,
                        label: 'Si no tienes',
                        value: _item.alimentoOrigen,
                      ),
                      const SizedBox(height: 10),
                      _DetailRow(
                        icon: Icons.swap_horiz,
                        label: 'Usa',
                        value: _item.sustitutoPrincipal,
                      ),
                      if (_item.equivalenciaTexto.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon: Icons.scale_outlined,
                          label: 'Equivalencia',
                          value: _item.equivalenciaTexto,
                        ),
                      ],
                      if (_item.objetivoMacro.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon: Icons.track_changes_outlined,
                          label: 'Objetivo',
                          value: _item.objetivoMacro,
                        ),
                      ],
                    ],
                  ),
                ),
                if (_item.texto.trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Notas y contexto',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  HashtagText(
                    text: _item.texto,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                    onHashtagTap: (hashtag) {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => SustitucionesSaludablesScreen(
                            initialSearchQuery: hashtag,
                            initialTabIndex: widget.initialTabIndex,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                // Sección de relacionados
                if (!_isLoadingRelacionados && _relacionados.isNotEmpty) ...[
                  const SizedBox(height: 24),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 195,
                    child: ListView.separated(
                      controller: _relacionadosScrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: _relacionados.length > _maxRelacionados
                          ? _maxRelacionados
                          : _relacionados.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) =>
                          _buildRelacionadoCard(_relacionados[index]),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class HashtagText extends StatelessWidget {
  const HashtagText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.onHashtagTap,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final ValueChanged<String>? onHashtagTap;

  @override
  Widget build(BuildContext context) {
    final regExp = RegExp(r'#[\wáéíóúÁÉÍÓÚñÑüÜ]+');
    final matches = regExp.allMatches(text);
    final defaultStyle = DefaultTextStyle.of(context).style;
    final themeStyle = Theme.of(context).textTheme.bodyMedium;
    final baseStyle = (themeStyle ?? defaultStyle)
        .merge(
          const TextStyle(fontSize: 16),
        )
        .merge(style);

    if (matches.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = <InlineSpan>[];
    var currentIndex = 0;

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: baseStyle,
        ));
      }

      final hashtag = match.group(0)!;
      spans.add(
        TextSpan(
          text: hashtag,
          style: baseStyle.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap =
                onHashtagTap == null ? null : () => onHashtagTap!(hashtag),
        ),
      );
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex), style: baseStyle));
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxChipWidth = MediaQuery.of(context).size.width * 0.72;

    return Container(
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.green.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
