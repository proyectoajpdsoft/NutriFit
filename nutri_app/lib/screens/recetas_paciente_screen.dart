import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:youtube_player_flutter/youtube_player_flutter.dart'; // Deshabilitado para web
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/consejo_receta_pdf_service.dart';
import '../models/receta.dart';
import '../models/receta_documento.dart';
import '../widgets/image_viewer_dialog.dart';
import '../widgets/restricted_access_dialog_helper.dart';

bool _canUseRecetasCopyPdf(AuthService authService) {
  return authService.isPremium ||
      authService.userType == 'Nutricionista' ||
      authService.userType == 'Administrador';
}

Future<void> _showPremiumRequiredForRecetasCopyPdf(BuildContext context) {
  return RestrictedAccessDialogHelper.show(
    context,
    title: 'Función Premium',
    message:
        'Para poder Copiar y pasar a PDF las Recetas y Consejos, debes ser usuario Premium.',
    primaryActionLabel: 'Hazte Premium',
    primaryActionIcon: Icons.workspace_premium,
    primaryRouteName: '/premium_info',
  );
}

Future<String> _buildNutriFitClipboardSignature(BuildContext context) async {
  try {
    final nutricionistaParam =
        await context.read<ApiService>().getParametro('nutricionista_nombre');
    final nutricionistaNombre =
        (nutricionistaParam?['valor']?.toString() ?? '').trim();
    return nutricionistaNombre.isEmpty
        ? 'App NutriFit'
        : 'App NutriFit $nutricionistaNombre';
  } catch (_) {
    return 'App NutriFit';
  }
}

class RecetasPacienteScreen extends StatefulWidget {
  const RecetasPacienteScreen({super.key});

  @override
  State<RecetasPacienteScreen> createState() => _RecetasPacienteScreenState();
}

class _RecetasPacienteScreenState extends State<RecetasPacienteScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 10;

  List<Receta> _recetas = [];
  List<Receta> _recetasPortada = [];
  List<Receta> _recetasFavoritas = [];
  bool _isLoading = true;
  bool _isLoadingPortada = true;
  bool _isLoadingFavoritas = true;
  bool _isLoadingMore = false;
  bool _isLoadingMorePortada = false;
  bool _isLoadingMoreFavoritas = false;
  bool _hasMoreRecetas = true;
  bool _hasMorePortada = true;
  bool _hasMoreFavoritas = true;
  late TabController _tabController;
  String? _patientCode;
  String? _userCode;
  bool _isGuestMode = false;
  bool _isSearchVisible = false;
  String _searchQuery = '';
  String _sortMode = 'fecha';
  bool _sortAscending = false;
  int _totalPortada = 0;
  int _totalRecetas = 0;
  int _totalFavoritas = 0;
  bool _categoriasLoading = false;
  List<Map<String, dynamic>> _categoriasCatalogo = [];
  List<int> _selectedCategoriaIds = [];
  bool _categoriaMatchAll = false;
  final Map<String, MemoryImage> _coverImageProviderCache = {};

  String _buildCoverCacheKey(Receta receta) {
    final raw = (receta.imagenPortada ?? '').trim();
    if (raw.isEmpty) return '';
    return '${receta.codigo ?? 'noid'}:${raw.hashCode}:${raw.length}';
  }

  ImageProvider? _getCachedCoverProvider(Receta receta) {
    final raw = (receta.imagenPortada ?? '').trim();
    if (raw.isEmpty) return null;

    final key = _buildCoverCacheKey(receta);
    final cached = _coverImageProviderCache[key];
    if (cached != null) return cached;

    try {
      final provider = MemoryImage(base64Decode(raw));
      _coverImageProviderCache[key] = provider;
      return provider;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _patientCode = authService.patientCode;
    _userCode = authService.userCode;
    _isGuestMode = authService.isGuestMode;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });

    _loadRecetasPortada(reset: true);
    _loadRecetas(reset: true);
    _loadRecetasFavoritas(reset: true);
    _loadCategorias();
    _loadPreferences();
    _loadTotals();
  }

  Future<void> _loadTotals() async {
    await Future.wait<void>([
      _loadPortadaTotal(),
      _loadRecetasTotal(),
      _loadFavoritasTotal(),
    ]);
  }

  Future<void> _loadPortadaTotal() async {
    try {
      final patientParam = (_patientCode != null && _patientCode!.isNotEmpty)
          ? _patientCode!
          : '0';
      final apiService = context.read<ApiService>();
      String url =
          'api/recetas.php?get_recetas_paciente=1&paciente=$patientParam&total=1&portada=1';
      if (_userCode != null && !_isGuestMode) {
        url += '&codigo_usuario=$_userCode';
      }
      final response = await apiService.get(url);
      if (response.statusCode != 200 || !mounted) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final total = int.tryParse((data['total'] ?? '0').toString()) ?? 0;
      setState(() => _totalPortada = total);
    } catch (_) {}
  }

  Future<void> _loadRecetasTotal() async {
    try {
      final patientParam = (_patientCode != null && _patientCode!.isNotEmpty)
          ? _patientCode!
          : '0';
      final apiService = context.read<ApiService>();
      String url =
          'api/recetas.php?get_recetas_paciente=1&paciente=$patientParam&total=1&q=$_searchQuery';
      if (_userCode != null && !_isGuestMode) {
        url += '&codigo_usuario=$_userCode';
      }
      final response = await apiService.get(url);
      if (response.statusCode != 200 || !mounted) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final total = int.tryParse((data['total'] ?? '0').toString()) ?? 0;
      setState(() => _totalRecetas = total);
    } catch (_) {}
  }

  Future<void> _loadFavoritasTotal() async {
    try {
      final userCode = _userCode;
      if (userCode == null || userCode.isEmpty || _isGuestMode) {
        if (mounted) {
          setState(() => _totalFavoritas = 0);
        }
        return;
      }
      final patientParam = (_patientCode != null && _patientCode!.isNotEmpty)
          ? _patientCode!
          : '0';
      final apiService = context.read<ApiService>();
      final url =
          'api/recetas.php?get_recetas_favoritas=1&paciente=$patientParam&codigo_usuario=$userCode&total=1';
      final response = await apiService.get(url);
      if (response.statusCode != 200 || !mounted) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final total = int.tryParse((data['total'] ?? '0').toString()) ?? 0;
      setState(() => _totalFavoritas = total);
    } catch (_) {}
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sortMode = prefs.getString('recetas_sortMode') ?? 'fecha';
      _sortAscending = prefs.getBool('recetas_sortAscending') ?? false;
      _selectedCategoriaIds = prefs
              .getStringList('recetas_categoriaIds')
              ?.map(int.parse)
              .toList() ??
          <int>[];
      _categoriaMatchAll = prefs.getBool('recetas_categoriaMatchAll') ?? false;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString('recetas_sortMode', _sortMode),
      prefs.setBool('recetas_sortAscending', _sortAscending),
      prefs.setStringList('recetas_categoriaIds',
          _selectedCategoriaIds.map((e) => e.toString()).toList()),
      prefs.setBool('recetas_categoriaMatchAll', _categoriaMatchAll),
    ]);
  }

  Future<void> _loadCategorias() async {
    setState(() {
      _categoriasLoading = true;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/recetas.php?categorias=1');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _categoriasCatalogo =
                data.map((item) => Map<String, dynamic>.from(item)).toList();
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _categoriasLoading = false;
        });
      }
    }
  }

  bool _matchesCategorias(Receta receta) {
    if (_selectedCategoriaIds.isEmpty) return true;
    final ids = receta.categoriaIds;
    if (ids.isEmpty) return false;
    if (_categoriaMatchAll) {
      return _selectedCategoriaIds.every(ids.contains);
    }
    return _selectedCategoriaIds.any(ids.contains);
  }

  Future<void> _showCategoriaFilterDialog() async {
    if (_categoriasCatalogo.isEmpty && !_categoriasLoading) {
      await _loadCategorias();
    }

    List<int> tempSelected = List<int>.from(_selectedCategoriaIds);
    bool tempMatchAll = _categoriaMatchAll;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filtrar por categorías',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
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
                  if (_categoriasLoading)
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
                                final id = int.parse(cat['codigo'].toString());
                                final name = cat['nombre'].toString();
                                final selected = tempSelected.contains(id);
                                return FilterChip(
                                  label: Text(name),
                                  selected: selected,
                                  onSelected: (value) {
                                    setStateDialog(() {
                                      if (value) {
                                        tempSelected.add(id);
                                      } else {
                                        tempSelected.remove(id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: tempMatchAll,
                    onChanged: (value) {
                      setStateDialog(() {
                        tempMatchAll = value;
                      });
                    },
                    title: const Text('Coincidir todas'),
                    subtitle: const Text('Si esta activo, requiere todas'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategoriaIds = [];
                    _categoriaMatchAll = false;
                  });
                  _savePreferences();
                  Navigator.pop(context);
                },
                child: const Text('Limpiar'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedCategoriaIds = tempSelected;
                    _categoriaMatchAll = tempMatchAll;
                  });
                  _savePreferences();
                  Navigator.pop(context);
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
                            tempSelected.isNotEmpty ? Colors.blue : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${tempSelected.length}',
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

  void _updateRecetaInList(List<Receta> list, Receta updated) {
    final index = list.indexWhere((item) => item.codigo == updated.codigo);
    if (index == -1) return;
    list[index].meGusta = updated.meGusta;
    list[index].favorito = updated.favorito;
    list[index].totalLikes = updated.totalLikes;
  }

  void _applyRecetaUpdate(Receta updated, {bool syncFavoritos = true}) {
    if (updated.codigo == null) return;
    setState(() {
      _updateRecetaInList(_recetas, updated);
      _updateRecetaInList(_recetasPortada, updated);

      if (syncFavoritos) {
        final favIndex = _recetasFavoritas
            .indexWhere((item) => item.codigo == updated.codigo);
        if (updated.favorito == 'S') {
          if (favIndex == -1) {
            _recetasFavoritas.insert(0, updated);
          } else {
            _updateRecetaInList(_recetasFavoritas, updated);
          }
        } else if (favIndex != -1) {
          _recetasFavoritas.removeAt(favIndex);
        }
      } else {
        _updateRecetaInList(_recetasFavoritas, updated);
      }
    });
  }

  DateTime _getRecetaDate(Receta receta) {
    return receta.fechaInicio ??
        receta.fechaa ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _getPopularScore(Receta receta) {
    final likes = receta.totalLikes ?? 0;
    final alcance = receta.totalPacientes ?? 0;
    final favoritoActual = receta.favorito == 'S' ? 2 : 0;
    final meGustaActual = receta.meGusta == 'S' ? 1 : 0;
    return (likes * 3) + (alcance * 2) + favoritoActual + meGustaActual;
  }

  List<Receta> _currentTabSource() {
    switch (_tabController.index) {
      case 0:
        return _recetasPortada;
      case 2:
        return _recetasFavoritas;
      case 1:
      default:
        return _recetas;
    }
  }

  int _currentTabCount() {
    final currentItemsCount = _applySearchAndSort(_currentTabSource()).length;
    switch (_tabController.index) {
      case 0:
        return _totalPortada > 0 ? _totalPortada : currentItemsCount;
      case 2:
        return _totalFavoritas > 0 ? _totalFavoritas : currentItemsCount;
      case 1:
      default:
        return _totalRecetas > 0 ? _totalRecetas : currentItemsCount;
    }
  }

  int _getFilteredTabCount() {
    return _applySearchAndSort(_currentTabSource()).length;
  }

  void _toggleSearchVisibility() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchQuery = '';
      }
    });
  }

  List<Receta> _applySearchAndSort(List<Receta> source) {
    final query = _searchQuery.trim().toLowerCase();
    var items = source
        .where((receta) {
          if (query.isEmpty) return true;
          final title = receta.titulo.toLowerCase();
          final text = receta.texto.toLowerCase();
          return title.contains(query) || text.contains(query);
        })
        .where(_matchesCategorias)
        .toList();

    items.sort((a, b) {
      switch (_sortMode) {
        case 'popular':
          final popularCompare = _sortAscending
              ? _getPopularScore(a).compareTo(_getPopularScore(b))
              : _getPopularScore(b).compareTo(_getPopularScore(a));
          if (popularCompare != 0) return popularCompare;
          return _sortAscending
              ? _getRecetaDate(a).compareTo(_getRecetaDate(b))
              : _getRecetaDate(b).compareTo(_getRecetaDate(a));
        case 'titulo':
          final titleCompare =
              a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
          return _sortAscending ? titleCompare : -titleCompare;
        case 'fecha':
        default:
          final dateCompare = _getRecetaDate(a).compareTo(_getRecetaDate(b));
          return _sortAscending ? dateCompare : -dateCompare;
      }
    });

    return items;
  }

  void _applySortSelection(String mode) {
    setState(() {
      if (_sortMode == mode) {
        _sortAscending = !_sortAscending;
      } else {
        _sortMode = mode;
        _sortAscending = mode == 'titulo';
      }
    });
    _savePreferences();
  }

  Future<void> _handleAppBarMenuAction(String action) async {
    switch (action) {
      case 'sort_title':
        _applySortSelection('titulo');
        break;
      case 'sort_recent':
        _applySortSelection('fecha');
        break;
      case 'sort_popular':
        _applySortSelection('popular');
        break;
      case 'refresh':
        await _refreshCurrentTab();
        break;
      case 'filter':
        await _showCategoriaFilterDialog();
        break;
      case 'search':
        _toggleSearchVisibility();
        break;
    }
  }

  Future<void> _refreshCurrentTab() async {
    final tabIndex = _tabController.index;
    if (tabIndex == 0) {
      await _loadRecetasPortada(reset: true);
    } else if (tabIndex == 1) {
      await _loadRecetas(reset: true);
    } else {
      await _loadRecetasFavoritas(reset: true);
    }
  }

  Future<void> _loadRecetas({bool reset = false}) async {
    if (!reset && (_isLoading || _isLoadingMore || !_hasMoreRecetas)) {
      return;
    }

    final offset = reset ? 0 : _recetas.length;

    setState(() {
      if (reset) {
        _isLoading = true;
        _hasMoreRecetas = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final patientParam = (_patientCode != null && _patientCode!.isNotEmpty)
          ? _patientCode!
          : '0';
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Construir URL con codigo_usuario si está disponible (para obtener estado de favorito)
      String url =
          'api/recetas.php?get_recetas_paciente=1&paciente=$patientParam&limit=$_pageSize&offset=$offset';
      if (_userCode != null && !_isGuestMode) {
        url += '&codigo_usuario=$_userCode';
      }

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final parsed = data.map((item) => Receta.fromJson(item)).toList();
        if (mounted) {
          setState(() {
            _recetas = reset ? parsed : [..._recetas, ...parsed];
            _hasMoreRecetas = parsed.length >= _pageSize;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadRecetasPortada({bool reset = false}) async {
    if (!reset &&
        (_isLoadingPortada || _isLoadingMorePortada || !_hasMorePortada)) {
      return;
    }

    final offset = reset ? 0 : _recetasPortada.length;

    setState(() {
      if (reset) {
        _isLoadingPortada = true;
        _hasMorePortada = true;
      } else {
        _isLoadingMorePortada = true;
      }
    });

    try {
      final patientParam = (_patientCode != null && _patientCode!.isNotEmpty)
          ? _patientCode!
          : '0';
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Construir URL con codigo_usuario si está disponible (para obtener estado de favorito)
      String url =
          'api/recetas.php?portada=1&paciente_codigo=$patientParam&limit=$_pageSize&offset=$offset';
      if (_userCode != null && !_isGuestMode) {
        url += '&codigo_usuario=$_userCode';
      }

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final parsed = data.map((item) => Receta.fromJson(item)).toList();
        if (mounted) {
          setState(() {
            _recetasPortada = reset ? parsed : [..._recetasPortada, ...parsed];
            _hasMorePortada = parsed.length >= _pageSize;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPortada = false;
          _isLoadingMorePortada = false;
        });
      }
    }
  }

  Future<void> _loadRecetasFavoritas({bool reset = false}) async {
    // No cargar favoritos en modo guest
    if (_isGuestMode) {
      if (mounted) {
        setState(() {
          _isLoadingFavoritas = false;
          _hasMoreFavoritas = false;
        });
      }
      return;
    }

    // Usar userCode (siempre existe para usuarios registrados)
    if (_userCode == null) {
      if (mounted) {
        setState(() {
          _isLoadingFavoritas = false;
          _hasMoreFavoritas = false;
        });
      }
      return;
    }

    if (!reset &&
        (_isLoadingFavoritas ||
            _isLoadingMoreFavoritas ||
            !_hasMoreFavoritas)) {
      return;
    }

    final offset = reset ? 0 : _recetasFavoritas.length;

    setState(() {
      if (reset) {
        _isLoadingFavoritas = true;
        _hasMoreFavoritas = true;
      } else {
        _isLoadingMoreFavoritas = true;
      }
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/receta_usuarios.php?favoritos=1&usuario=$_userCode&limit=$_pageSize&offset=$offset',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final parsed = <Receta>[];
        for (final item in data) {
          try {
            parsed.add(Receta.fromJson(item));
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            _recetasFavoritas =
                reset ? parsed : [..._recetasFavoritas, ...parsed];
            _hasMoreFavoritas = parsed.length >= _pageSize;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recetasFavoritas = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFavoritas = false;
          _isLoadingMoreFavoritas = false;
        });
      }
    }
  }

  Future<void> _toggleLike(Receta receta) async {
    if (_isGuestMode || _userCode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para dar me gusta'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_receta': receta.codigo,
        'codigo_usuario': int.parse(_userCode!),
      };

      final response = await apiService.post(
        'api/receta_usuarios.php?toggle_like=1',
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final previousMeGusta = receta.meGusta ?? 'N';
        final newMeGusta =
            responseData['me_gusta'] ?? (previousMeGusta == 'S' ? 'N' : 'S');
        var totalLikes = receta.totalLikes ?? 0;
        if (newMeGusta == 'S' && previousMeGusta != 'S') {
          totalLikes += 1;
        } else if (newMeGusta != 'S' && previousMeGusta == 'S') {
          if (totalLikes > 0) totalLikes -= 1;
        }

        receta.meGusta = newMeGusta;
        receta.totalLikes = totalLikes;
        _applyRecetaUpdate(receta, syncFavoritos: false);
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text('Error al cambiar me gusta. $errorMessage'),
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _toggleFavorito(Receta receta) async {
    if (_isGuestMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para guardar favoritos'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Usar userCode (siempre existe para usuarios registrados)
    final codigoReceta = _userCode;
    if (codigoReceta == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No se pudo identificar el usuario'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_receta': receta.codigo,
        'codigo_usuario': int.parse(codigoReceta),
      };

      final response = await apiService.post(
        'api/receta_usuarios.php?toggle_favorito=1',
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final newFavorito =
            responseData['favorito'] ?? (receta.favorito == 'S' ? 'N' : 'S');
        receta.favorito = newFavorito;
        _applyRecetaUpdate(receta, syncFavoritos: true);
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text('Error al cambiar favorito. $errorMessage')));
      }
    }
  }

  Widget _buildRecetaCard(Receta receta) {
    final coverProvider = _getCachedCoverProvider(receta);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecetaDetailScreen(
                receta: receta,
                onFavoritoChanged: (updatedReceta) {
                  setState(() {
                    final idx = _recetas.indexWhere(
                      (r) => r.codigo == updatedReceta.codigo,
                    );
                    if (idx != -1) {
                      _recetas[idx] = updatedReceta;
                    }
                  });
                },
                onFavoritoChangedFromDetail: _loadRecetasFavoritas,
              ),
            ),
          ).then((_) {
            _loadRecetas(reset: true);
            _loadRecetasPortada(reset: true);
            _loadRecetasFavoritas(reset: true);
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de portada
            if (coverProvider != null)
              RepaintBoundary(
                child: Image(
                  image: coverProvider,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              )
            else
              Container(
                height: 250,
                width: double.infinity,
                color: Colors.grey[300],
                child: const Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: Colors.grey,
                ),
              ),

            // Acciones (like, favorito, copiar, pdf)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      receta.meGusta == 'S'
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: receta.meGusta == 'S' ? Colors.red : null,
                    ),
                    onPressed: () => _toggleLike(receta),
                  ),
                  Text(
                    '${receta.totalLikes ?? 0} me gusta',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      receta.favorito == 'S'
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: receta.favorito == 'S' ? Colors.amber : null,
                    ),
                    onPressed: () => _toggleFavorito(receta),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copyRecetaToClipboard(receta),
                    tooltip: 'Copiar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    onPressed: () => _generateRecetaPdfFromCard(receta),
                    tooltip: 'PDF',
                  ),
                  if (receta.mostrarPortada == 'S')
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                ],
              ),
            ),

            // Título y texto
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receta.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  HashtagText(
                    text: receta.texto.length > 100
                        ? '${receta.texto.substring(0, 100)}...'
                        : receta.texto,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  if (receta.texto.length > 100) const SizedBox(height: 4),
                  if (receta.texto.length > 100)
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

  Widget _buildGuestFavoritasEmptyCard({required String tipo}) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.shade100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_outline,
              size: 34,
              color: Colors.purple.shade600,
            ),
            const SizedBox(height: 10),
            Text(
              'Para poder marcar $tipo como favoritas, debes registrarte (es gratis).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.purple.shade800,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              icon: const Icon(Icons.app_registration),
              label: const Text('Iniciar registro'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Recetas',
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
          if (!_isSearchVisible)
            IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.search),
              onPressed: _toggleSearchVisibility,
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
            onPressed: _showCategoriaFilterDialog,
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              _handleAppBarMenuAction(value);
            },
            itemBuilder: (context) => [
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Scrollbar(
            thumbVisibility: true,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.star), text: 'Destacadas'),
                Tab(icon: Icon(Icons.restaurant_menu), text: 'Todas'),
                Tab(icon: Icon(Icons.bookmark), text: 'Favoritas'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isSearchVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Buscar recetas',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Ocultar búsqueda',
                    icon: const Icon(Icons.close),
                    onPressed: _toggleSearchVisibility,
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          if (_selectedCategoriaIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedCategoriaIds.map((id) {
                  final match = _categoriasCatalogo.firstWhere(
                    (cat) => int.parse(cat['codigo'].toString()) == id,
                    orElse: () => {'nombre': 'Categoría $id'},
                  );
                  return Chip(
                    label: Text(match['nombre'].toString()),
                    onDeleted: () {
                      setState(() {
                        _selectedCategoriaIds.remove(id);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: () => _loadRecetasPortada(reset: true),
                  child: Builder(
                    builder: (context) {
                      if (_isLoadingPortada) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final items = _applySearchAndSort(_recetasPortada);
                      if (items.isEmpty) {
                        return const Center(
                          child: Text('No hay recetas destacadas'),
                        );
                      }
                      return NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (_hasMorePortada &&
                              !_isLoadingMorePortada &&
                              notification.metrics.pixels >=
                                  notification.metrics.maxScrollExtent - 300) {
                            _loadRecetasPortada();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount:
                              items.length + (_isLoadingMorePortada ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= items.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }
                            return _buildRecetaCard(items[index]);
                          },
                        ),
                      );
                    },
                  ),
                ),
                RefreshIndicator(
                  onRefresh: () => _loadRecetas(reset: true),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Builder(
                          builder: (context) {
                            final items = _applySearchAndSort(_recetas);
                            if (items.isEmpty) {
                              return const Center(
                                child: Text('No hay recetas disponibles'),
                              );
                            }
                            return NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (_hasMoreRecetas &&
                                    !_isLoadingMore &&
                                    notification.metrics.pixels >=
                                        notification.metrics.maxScrollExtent -
                                            300) {
                                  _loadRecetas();
                                }
                                return false;
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 80),
                                itemCount:
                                    items.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= items.length) {
                                    return const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 20),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    );
                                  }
                                  return _buildRecetaCard(items[index]);
                                },
                              ),
                            );
                          },
                        ),
                ),
                RefreshIndicator(
                  onRefresh: () => _loadRecetasFavoritas(reset: true),
                  child: Builder(
                    builder: (context) {
                      if (_isLoadingFavoritas) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final items = _applySearchAndSort(_recetasFavoritas);
                      final isWithoutCredentials =
                          _isGuestMode || (_userCode ?? '').isEmpty;
                      if (items.isEmpty) {
                        if (isWithoutCredentials) {
                          return _buildGuestFavoritasEmptyCard(tipo: 'recetas');
                        }
                        return const Center(
                          child: Text('No tienes recetas favoritas'),
                        );
                      }
                      return NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (_hasMoreFavoritas &&
                              !_isLoadingMoreFavoritas &&
                              notification.metrics.pixels >=
                                  notification.metrics.maxScrollExtent - 300) {
                            _loadRecetasFavoritas();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount:
                              items.length + (_isLoadingMoreFavoritas ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= items.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }
                            return _buildRecetaCard(items[index]);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyRecetaToClipboard(Receta receta) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!_canUseRecetasCopyPdf(authService)) {
      await _showPremiumRequiredForRecetasCopyPdf(context);
      return;
    }

    try {
      final firma = await _buildNutriFitClipboardSignature(context);
      final textToCopy = '${receta.titulo}\n\n${receta.texto}\n\n$firma';
      await Clipboard.setData(ClipboardData(text: textToCopy));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copiado al portapapeles'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al copiar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateRecetaPdfFromCard(Receta receta) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!_canUseRecetasCopyPdf(authService)) {
      await _showPremiumRequiredForRecetasCopyPdf(context);
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Cargar documentos/imágenes inline para esta receta
      final imagenesInlineById = <int, String>{};
      try {
        final codigoRec = receta.codigo;
        if (codigoRec != null) {
          final docsResponse = await apiService.get(
            'api/receta_documentos.php?receta=$codigoRec',
          );
          if (docsResponse.statusCode == 200) {
            final List<dynamic> docsData = json.decode(docsResponse.body);
            for (final item in docsData) {
              if (item['tipo'] == 'imagen' && item['codigo'] != null) {
                final id = int.tryParse(item['codigo'].toString());
                final base64 = (item['documento'] ?? '').toString().trim();
                if (id != null && base64.isNotEmpty) {
                  imagenesInlineById[id] = base64;
                }
              }
            }
          }
        }
      } catch (_) {}

      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: receta.titulo,
        contenido: receta.texto,
        tipo: 'receta',
        imagenPortadaBase64: receta.imagenPortada,
        imagenesInlineById: imagenesInlineById,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _coverImageProviderCache.clear();
    _tabController.dispose();
    super.dispose();
  }
}

class RecetaDetailScreen extends StatefulWidget {
  final Receta receta;
  final Function(Receta)? onFavoritoChanged;
  final Function()? onFavoritoChangedFromDetail;
  final bool isPreviewMode;

  const RecetaDetailScreen({
    super.key,
    required this.receta,
    this.onFavoritoChanged,
    this.onFavoritoChangedFromDetail,
    this.isPreviewMode = false,
  });

  @override
  State<RecetaDetailScreen> createState() => _RecetaDetailScreenState();
}

class _RecetaDetailScreenState extends State<RecetaDetailScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');
  static final RegExp _contentTokenRegex =
      RegExp(r'\[\[(img|documento|enlace):(\d+)\]\]');
  static final RegExp _genericTokenRegex = RegExp(r'\[\[([^\[\]]+)\]\]');
  static final RegExp _structuredLinkTokenRegex = RegExp(
    r'^(.*?)\s*enlace_(consejo|receta|sustitucion_saludable|aditivo|suplemento)_(\d+)\s*$',
    caseSensitive: false,
    unicode: true,
  );
  static final RegExp _hashtagRegex =
      RegExp(r'#[\wáéíóúÁÉÍÓÚñÑüÜ]+', caseSensitive: false);
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

  List<RecetaDocumento> _documentos = [];
  List<Receta> _relacionados = [];
  bool _isLoading = true;
  bool _isLoadingRelacionados = true;
  int _maxRelacionados = 5;
  late Receta _receta;
  final ScrollController _documentosScrollController = ScrollController();
  final ScrollController _relacionadosScrollController = ScrollController();
  final Map<String, MemoryImage> _detailImageProviderCache = {};

  ImageProvider? _getDetailCachedImageProvider(int? codigo, String? base64) {
    final raw = (base64 ?? '').trim();
    if (raw.isEmpty) return null;
    final key = '${codigo ?? 'noid'}:${raw.hashCode}:${raw.length}';
    final cached = _detailImageProviderCache[key];
    if (cached != null) return cached;
    try {
      final provider = MemoryImage(base64Decode(raw));
      _detailImageProviderCache[key] = provider;
      return provider;
    } catch (_) {
      return null;
    }
  }
  // final PageController _imagenesPageController = PageController(); // REMOVIDO: carrusel de imágenes adjuntas
  // int _currentImagenIndex = 0; // REMOVIDO: carrusel de imágenes adjuntas
  // bool _isDraggingImagenesCarousel = false; // REMOVIDO: carrusel de imágenes adjuntas

  @override
  void initState() {
    super.initState();
    _receta = widget.receta;
    _loadDocumentos();
    _loadRelacionados();
    if (!widget.isPreviewMode) {
      _marcarComoLeido();
    }
  }

  @override
  void dispose() {
    _detailImageProviderCache.clear();
    _documentosScrollController.dispose();
    _relacionadosScrollController.dispose();
    // _imagenesPageController.dispose(); // REMOVIDO: carrusel de imágenes adjuntas
    super.dispose();
  }

  int _parseMaxRelacionados(dynamic rawValue) {
    final parsed = int.tryParse((rawValue ?? '').toString());
    if (parsed == null || parsed <= 0) return 5;
    if (parsed > 20) return 20;
    return parsed;
  }

  String _cleanTextForSimilarity(String text) {
    return text
        .replaceAll(_contentTokenRegex, ' ')
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

  double _similarityScore(Receta base, Receta candidate) {
    final baseCategorias = base.categoriaIds.toSet();
    final candidateCategorias = candidate.categoriaIds.toSet();

    final baseHashtags = _extractHashtags('${base.titulo} ${base.texto}');
    final candidateHashtags =
        _extractHashtags('${candidate.titulo} ${candidate.texto}');

    final baseTitleWords = _extractWords(base.titulo);
    final candidateTitleWords = _extractWords(candidate.titulo);

    final baseBodyWords = _extractWords(base.texto);
    final candidateBodyWords = _extractWords(candidate.texto);

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
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      final maxParam = await apiService
          .getParametro('numero_maximo_relacionados_consejos_recetas');
      final maxRelacionados = _parseMaxRelacionados(maxParam?['valor']);

      final patientParam = authService.patientCode ?? '0';
      String url =
          'api/recetas.php?get_recetas_paciente=1&paciente=$patientParam';
      if (authService.userCode != null && !authService.isGuestMode) {
        url += '&codigo_usuario=${authService.userCode}';
      }

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final allRecetas = data.map((item) => Receta.fromJson(item)).toList();

        final candidatos = allRecetas.where((item) {
          if (item.codigo == null || _receta.codigo == null) {
            return false;
          }
          return item.codigo != _receta.codigo;
        }).toList();

        final scored = candidatos
            .map((item) => MapEntry(item, _similarityScore(_receta, item)))
            .where((entry) => entry.value > 0)
            .toList();

        scored.sort((a, b) {
          final byScore = b.value.compareTo(a.value);
          if (byScore != 0) return byScore;
          final byLikes =
              (b.key.totalLikes ?? 0).compareTo(a.key.totalLikes ?? 0);
          if (byLikes != 0) return byLikes;
          final dateA = a.key.fechaInicio ?? a.key.fechaa ?? DateTime(1970);
          final dateB = b.key.fechaInicio ?? b.key.fechaa ?? DateTime(1970);
          return dateB.compareTo(dateA);
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
          _relacionados = [];
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

  String _buildResumenRelacionado(String text) {
    final cleaned = text
        .replaceAllMapped(_genericTokenRegex, (match) {
          final raw = (match.group(1) ?? '').trim();
          final tokenMatch = RegExp(
            r'^(img|documento|enlace):(\d+)$',
            caseSensitive: false,
          ).firstMatch(raw);
          if (tokenMatch != null) {
            final tokenType = (tokenMatch.group(1) ?? '').toLowerCase();
            final tokenId = int.tryParse(tokenMatch.group(2) ?? '');
            if (tokenType == 'enlace' && tokenId != null) {
              final link = _documentos
                  .where(
                    (item) => item.tipo == 'enlace' && item.codigo == tokenId,
                  )
                  .cast<RecetaDocumento?>()
                  .firstWhere((item) => item != null, orElse: () => null);
              final label = (link?.nombre ?? link?.url ?? '').trim();
              return label.isNotEmpty ? label : 'enlace';
            }
            return '';
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

  Widget _buildRelacionadoCard(Receta item) {
    final relatedCoverProvider =
        _getDetailCachedImageProvider(item.codigo, item.imagenPortada);
    Widget header;
    if (relatedCoverProvider != null) {
      header = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: RepaintBoundary(
          child: Image(
            image: relatedCoverProvider,
            height: 95,
            width: double.infinity,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      );
    } else {
      header = Container(
        height: 95,
        color: Colors.grey[200],
        child: const Icon(Icons.restaurant_menu, size: 28),
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
              MaterialPageRoute(
                builder: (_) => RecetaDetailScreen(
                  receta: item,
                  onFavoritoChanged: widget.onFavoritoChanged,
                  onFavoritoChangedFromDetail:
                      widget.onFavoritoChangedFromDetail,
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
                      _buildResumenRelacionado(item.texto),
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

  Future<void> _marcarComoLeido() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final patientCode = authService.patientCode;
    final userCode = authService.userCode;
    if (userCode == null) return;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_receta': _receta.codigo,
        'codigo_usuario': int.parse(userCode),
        if (patientCode != null && patientCode.isNotEmpty)
          'codigo_paciente': int.parse(patientCode),
      };

      await apiService.post(
        'api/receta_pacientes.php?marcar_leido=1',
        body: json.encode(data),
      );
    } catch (_) {}
  }

  Future<void> _loadDocumentos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/receta_documentos.php?receta=${_receta.codigo}',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _documentos =
              data.map((item) => RecetaDocumento.fromJson(item)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (widget.isPreviewMode) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final userCode = authService.userCode;

    if (authService.isGuestMode || userCode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para dar me gusta'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_receta': _receta.codigo,
        'codigo_usuario': int.parse(userCode),
      };

      final response = await apiService.post(
        'api/receta_usuarios.php?toggle_like=1',
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _receta.meGusta = responseData['me_gusta'];
          if (responseData['me_gusta'] == 'S') {
            _receta.totalLikes = (_receta.totalLikes ?? 0) + 1;
          } else {
            _receta.totalLikes = (_receta.totalLikes ?? 0) - 1;
          }
        });
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
          content: Text('Error al cambiar me gusta. $errorMessage'),
          behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _toggleFavorito() async {
    if (widget.isPreviewMode) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final userCode = authService.userCode;

    if (authService.isGuestMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para guardar favoritos'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Usar userCode (siempre existe para usuarios registrados)
    if (userCode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No se pudo identificar el usuario'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_receta': _receta.codigo,
        'codigo_usuario': int.parse(userCode),
      };

      final response = await apiService.post(
        'api/receta_usuarios.php?toggle_favorito=1',
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _receta.favorito = responseData['favorito'];
        });

        if (widget.onFavoritoChanged != null) {
          widget.onFavoritoChanged!(_receta);
        }

        // Recargar favoritas inmediatamente
        if (widget.onFavoritoChangedFromDetail != null) {
          widget.onFavoritoChangedFromDetail!();
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text('Error al cambiar favorito. $errorMessage')));
      }
    }
  }

  Future<void> _copyToClipboard() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!_canUseRecetasCopyPdf(authService)) {
      await _showPremiumRequiredForRecetasCopyPdf(context);
      return;
    }

    try {
      final cleanedBody = _receta.texto
          .replaceAll(_contentTokenRegex, '')
          .replaceAll(RegExp(r'[ \t]+\n'), '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
      final firma = await _buildNutriFitClipboardSignature(context);
      final textToCopy = '${_receta.titulo}\n\n$cleanedBody\n\n$firma';
      await Clipboard.setData(ClipboardData(text: textToCopy));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copiado al portapapeles'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al copiar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateRecetaPdf() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!_canUseRecetasCopyPdf(authService)) {
      await _showPremiumRequiredForRecetasCopyPdf(context);
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final imagenesInlineById = <int, String>{};
      for (final doc in _documentos) {
        if (doc.tipo == 'imagen' && doc.codigo != null) {
          var base64Image = (doc.documento ?? '').trim();
          // Fallback: si la lista no trajo el binario, pedirlo individualmente
          if (base64Image.isEmpty) {
            base64Image = await _getImagenDocumentoBase64(doc) ?? '';
          }
          if (base64Image.isNotEmpty) {
            imagenesInlineById[doc.codigo!] = base64Image;
          }
        }
      }

      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: _receta.titulo,
        contenido: _receta.texto,
        tipo: 'receta',
        imagenPortadaBase64: _receta.imagenPortada,
        imagenesInlineById: imagenesInlineById,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        await _externalUrlChannel.invokeMethod('openUrl', {'url': url});
        return;
      }
      rethrow;
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir enlace. $errorMessage')),
        );
      }
    }
  }

  Future<void> _openDocumento(RecetaDocumento doc) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      String? documentoBase64 = doc.documento;

      if (documentoBase64 == null || documentoBase64.isEmpty) {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final response = await apiService.get(
          'api/receta_documentos.php?codigo=${doc.codigo}',
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data is Map && data['documento'] != null) {
            documentoBase64 = data['documento'];
          } else if (data is List && data.isNotEmpty) {
            documentoBase64 = data[0]['documento'];
          }
        } else {
          if (mounted) Navigator.of(context).pop();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error al cargar documento: ${response.statusCode}',
                ),
              ),
            );
          }
          return;
        }
      }

      if (documentoBase64 == null || documentoBase64.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El documento no está disponible')),
          );
        }
        return;
      }

      Uint8List bytes;
      try {
        bytes = base64Decode(documentoBase64);
      } catch (e) {
        String base64String = documentoBase64;
        while (base64String.length % 4 != 0) {
          base64String += '=';
        }
        try {
          bytes = base64Decode(base64String);
        } catch (e2) {
          if (mounted) Navigator.of(context).pop();
          if (mounted) {
            final errorMessage = e2.toString().replaceFirst('Exception: ', '');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Error al decodificar documento. $errorMessage')),
            );
          }
          return;
        }
      }

      final dir = await getTemporaryDirectory();

      String fileName = doc.nombre ?? 'documento';
      if (!fileName.contains('.')) {
        fileName = '$fileName.pdf';
      }
      final filePath = '${dir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!await file.exists()) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No se pudo guardar el documento'),
            ),
          );
        }
        return;
      }

      if (mounted) Navigator.of(context).pop();

      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir documento: ${result.message}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir documento. $errorMessage')),
        );
      }
    }
  }

  Future<String?> _getImagenDocumentoBase64(RecetaDocumento doc) async {
    final local = (doc.documento ?? '').trim();
    if (local.isNotEmpty) {
      return local;
    }

    if (doc.codigo == null) return null;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/receta_documentos.php?codigo=${doc.codigo}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['documento'] != null) {
          final value = data['documento'].toString().trim();
          if (value.isNotEmpty) {
            return value;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> _openImagenDocumento(RecetaDocumento doc) async {
    final imageBase64 = await _getImagenDocumentoBase64(doc);
    if (!mounted) return;

    if (imageBase64 == null || imageBase64.isEmpty) {
      // Solo mostrar error a administradores
      final authService = Provider.of<AuthService>(context, listen: false);
      final isAdmin = authService.userType == 'Nutricionista' ||
          authService.userType == 'Administrador';

      if (isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'IMAGEN NO ENCONTRADA. ID: ${doc.codigo}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    showImageViewerDialog(
      context: context,
      base64Image: imageBase64,
      title: doc.nombre ?? 'Imagen',
    );
  }

  Widget _buildInlineImagenDesdeToken(int imageId) {
    final doc = _documentos.firstWhere(
      (item) => item.tipo == 'imagen' && item.codigo == imageId,
      orElse: () => RecetaDocumento(
        codigo: imageId,
        codigoReceta: _receta.codigo ?? 0,
        tipo: 'imagen',
        nombre: 'Imagen $imageId',
      ),
    );

    final hasDoc = doc.codigo != null &&
        _documentos
            .any((item) => item.tipo == 'imagen' && item.codigo == imageId);
    if (!hasDoc) {
      // Solo mostrar error a administradores
      final authService = Provider.of<AuthService>(context, listen: false);
      final isAdmin = authService.userType == 'Nutricionista' ||
          authService.userType == 'Administrador';

      if (!isAdmin) {
        return const SizedBox.shrink();
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[700]!, width: 2),
        ),
        child: Text(
          '⚠️ IMAGEN NO ENCONTRADA. ID: $imageId',
          style: TextStyle(
            color: Colors.red[900],
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final base64Image = (doc.documento ?? '').trim();
    if (base64Image.isEmpty) {
      // Solo mostrar error a administradores
      final authService = Provider.of<AuthService>(context, listen: false);
      final isAdmin = authService.userType == 'Nutricionista' ||
          authService.userType == 'Administrador';

      if (!isAdmin) {
        return const SizedBox.shrink();
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[700]!, width: 2),
        ),
        child: Text(
          '⚠️ IMAGEN NO DISPONIBLE. ID: $imageId',
          style: TextStyle(
            color: Colors.red[900],
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    try {
      final imageBytes = base64Decode(base64Image);
      return GestureDetector(
        onTap: () => _openImagenDocumento(doc),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            imageBytes,
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
      );
    } catch (_) {
      // Solo mostrar error a administradores
      final authService = Provider.of<AuthService>(context, listen: false);
      final isAdmin = authService.userType == 'Nutricionista' ||
          authService.userType == 'Administrador';

      if (!isAdmin) {
        return const SizedBox.shrink();
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[700]!, width: 2),
        ),
        child: Text(
          '⚠️ IMAGEN INVÁLIDA. ID: $imageId',
          style: TextStyle(
            color: Colors.red[900],
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  Widget _buildInlineDocumentoDesdeToken(int documentId) {
    final matchingDocs = _documentos
        .where((item) => item.tipo == 'documento' && item.codigo == documentId)
        .toList();

    if (matchingDocs.isEmpty) {
      // Solo mostrar error a administradores
      final authService = Provider.of<AuthService>(context, listen: false);
      final isAdmin = authService.userType == 'Nutricionista' ||
          authService.userType == 'Administrador';

      if (!isAdmin) {
        return const SizedBox.shrink();
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[700]!, width: 2),
        ),
        child: Text(
          '⚠️ DOCUMENTO NO ENCONTRADO. ID: $documentId',
          style: TextStyle(
            color: Colors.red[900],
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final doc = matchingDocs.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              (doc.nombre ?? '').trim().isNotEmpty
                  ? doc.nombre!.trim()
                  : 'Documento $documentId',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[700],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _openDocumento(doc),
              icon: const Icon(Icons.download),
              label: const Text('Descargar documento'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineEnlaceDesdeToken(int enlaceId) {
    final matchingLinks = _documentos
        .where((item) => item.tipo == 'url' && item.codigo == enlaceId)
        .toList();

    if (matchingLinks.isEmpty) {
      // Solo mostrar error a administradores
      final authService = Provider.of<AuthService>(context, listen: false);
      final isAdmin = authService.userType == 'Nutricionista' ||
          authService.userType == 'Administrador';

      if (!isAdmin) {
        return const SizedBox.shrink();
      }

      return Text(
        '⚠️ ENLACE NO ENCONTRADO. ID: $enlaceId',
        style: TextStyle(
          color: Colors.red[900],
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final linkDoc = matchingLinks.first;
    final url = (linkDoc.url ?? '').trim();
    final nombre = (linkDoc.nombre ?? '').trim();
    final label = nombre.isNotEmpty ? nombre : url;

    if (label.isEmpty) {
      // Solo mostrar error a administradores
      final authService = Provider.of<AuthService>(context, listen: false);
      final isAdmin = authService.userType == 'Nutricionista' ||
          authService.userType == 'Administrador';

      if (!isAdmin) {
        return const SizedBox.shrink();
      }

      return Text(
        '⚠️ ENLACE VACÍO. ID: $enlaceId',
        style: TextStyle(
          color: Colors.red[900],
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (url.isEmpty) {
      return Text(
        label,
        style: TextStyle(
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDetalleTextoConImagenes() {
    final texto = _receta.texto;
    final matches = _contentTokenRegex.allMatches(texto).toList();

    if (matches.isEmpty) {
      return HashtagText(
        text: texto,
        style: const TextStyle(fontSize: 16, height: 1.5),
      );
    }

    final widgets = <Widget>[];
    int cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        final textChunk = texto.substring(cursor, match.start);
        if (textChunk.trim().isNotEmpty) {
          widgets.add(
            HashtagText(
              text: textChunk,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          );
          widgets.add(const SizedBox(height: 12));
        }
      }

      final tokenType = match.group(1) ?? '';
      final tokenId = int.tryParse(match.group(2) ?? '');

      if (tokenId != null && tokenType == 'img') {
        widgets.add(_buildInlineImagenDesdeToken(tokenId));
      } else if (tokenId != null && tokenType == 'documento') {
        widgets.add(_buildInlineDocumentoDesdeToken(tokenId));
      } else if (tokenId != null && tokenType == 'enlace') {
        widgets.add(_buildInlineEnlaceDesdeToken(tokenId));
      } else {
        widgets.add(
          HashtagText(
            text: match.group(0) ?? '',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        );
      }
      widgets.add(const SizedBox(height: 12));

      cursor = match.end;
    }

    if (cursor < texto.length) {
      final trailingText = texto.substring(cursor);
      if (trailingText.trim().isNotEmpty) {
        widgets.add(
          HashtagText(
            text: trailingText,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        );
      }
    }

    if (widgets.isEmpty) {
      return HashtagText(
        text: texto,
        style: const TextStyle(fontSize: 16, height: 1.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final documentosYEnlaces =
        _documentos.where((doc) => doc.tipo != 'imagen').toList();
    final detailCoverProvider =
        _getDetailCachedImageProvider(_receta.codigo, _receta.imagenPortada);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Detalle de la Receta'),
        actions: [
          if (!widget.isPreviewMode) ...[
            IconButton(
              icon: Icon(
                _receta.favorito == 'S'
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: _receta.favorito == 'S' ? Colors.amber : null,
              ),
              onPressed: _toggleFavorito,
            ),
            IconButton(
              icon: Icon(
                _receta.meGusta == 'S' ? Icons.favorite : Icons.favorite_border,
                color: _receta.meGusta == 'S' ? Colors.red : null,
              ),
              onPressed: _toggleLike,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isPreviewMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.blue[100],
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vista Previa - Así verán la receta los usuarios',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (detailCoverProvider != null)
              GestureDetector(
                onTap: () => showImageViewerDialog(
                  context: context,
                  base64Image: _receta.imagenPortada!,
                  title: _receta.titulo,
                ),
                child: RepaintBoundary(
                  child: Image(
                    image: detailCoverProvider,
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 48.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _receta.meGusta == 'S'
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _receta.meGusta == 'S' ? Colors.red : null,
                          size: 20,
                        ),
                        onPressed: _toggleLike,
                      ),
                      Text(
                        '${_receta.totalLikes ?? 0} me gusta',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: _copyToClipboard,
                        tooltip: 'Copiar',
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, size: 20),
                        onPressed: _generateRecetaPdf,
                        tooltip: 'Generar PDF',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _receta.titulo,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetalleTextoConImagenes(),
                  const SizedBox(height: 24),
                  if (documentosYEnlaces.isNotEmpty) ...[
                    const Text(
                      'Documentos y enlaces',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      SizedBox(
                        height: 110,
                        child: Scrollbar(
                          controller: _documentosScrollController,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: _documentosScrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: documentosYEnlaces.length,
                            itemBuilder: (context, index) {
                              final doc = documentosYEnlaces[index];
                              return GestureDetector(
                                onTap: () {
                                  if (doc.tipo == 'url' && doc.url != null) {
                                    _launchUrl(doc.url!);
                                  } else {
                                    _openDocumento(doc);
                                  }
                                },
                                child: Container(
                                  width: 120,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        doc.tipo == 'url'
                                            ? Icons.link
                                            : Icons.insert_drive_file,
                                        size: 32,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        doc.nombre ??
                                            (doc.tipo == 'url'
                                                ? 'Enlace'
                                                : 'Documento'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                  // Sección de relacionados (solo si hay contenido)
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
            ),
          ],
        ),
      ),
    );
  }
}

class RecetasHashtagScreen extends StatefulWidget {
  final String hashtag;

  const RecetasHashtagScreen({super.key, required this.hashtag});

  @override
  State<RecetasHashtagScreen> createState() => _RecetasHashtagScreenState();
}

class _RecetasHashtagScreenState extends State<RecetasHashtagScreen> {
  List<Receta> _recetas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecetas();
  }

  Future<void> _loadRecetas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final patientCode = authService.patientCode;
      final patientParam =
          (patientCode != null && patientCode.isNotEmpty) ? patientCode : '0';

      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/recetas.php?get_recetas_paciente=1&paciente=$patientParam',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final allRecetas = data.map((item) => Receta.fromJson(item)).toList();

        setState(() {
          _recetas = allRecetas
              .where((receta) => receta.texto.contains(widget.hashtag))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Recetas con ${widget.hashtag}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recetas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tag, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No hay recetas con ${widget.hashtag}',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recetas.length,
                  itemBuilder: (context, index) {
                    final receta = _recetas[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RecetaDetailScreen(receta: receta),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (receta.imagenPortada != null)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: Image.memory(
                                  base64Decode(receta.imagenPortada!),
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    receta.titulo,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  HashtagText(
                                    text: receta.texto.length > 150
                                        ? '${receta.texto.substring(0, 150)}...'
                                        : receta.texto,
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.favorite,
                                        size: 16,
                                        color: Colors.red[300],
                                      ),
                                      const SizedBox(width: 4),
                                      Text('${receta.totalLikes ?? 0}'),
                                      const SizedBox(width: 16),
                                      Icon(
                                        Icons.tag,
                                        size: 16,
                                        color: Colors.blue[300],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.hashtag,
                                        style: const TextStyle(
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
}

class HashtagText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const HashtagText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final regExp = RegExp(r'#[\wáéíóúÁÉÍÓÚñÑüÜ]+');
    final matches = regExp.allMatches(text);

    // Definir estilo base con color explícito si no está definido
    final baseStyle =
        style ?? const TextStyle(fontSize: 16, color: Colors.black);
    final baseStyleWithColor = baseStyle.color != null
        ? baseStyle
        : baseStyle.copyWith(color: Colors.black);

    if (matches.isEmpty) {
      return Text(
        text,
        style: baseStyleWithColor,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (final match in matches) {
      // Agregar texto antes del hashtag
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: baseStyleWithColor,
          ),
        );
      }

      // Agregar hashtag clickeable
      final hashtag = match.group(0)!;
      spans.add(
        TextSpan(
          text: hashtag,
          style: baseStyleWithColor.copyWith(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecetasHashtagScreen(hashtag: hashtag),
                ),
              );
            },
        ),
      );

      currentIndex = match.end;
    }

    // Agregar texto restante después del último hashtag
    if (currentIndex < text.length) {
      spans.add(
        TextSpan(text: text.substring(currentIndex), style: baseStyleWithColor),
      );
    }

    return RichText(
      text: TextSpan(style: baseStyleWithColor, children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
