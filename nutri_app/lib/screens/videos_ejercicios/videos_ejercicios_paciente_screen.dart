import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/video_ejercicio.dart';
import '../../widgets/premium_feature_dialog_helper.dart';
import '../../widgets/premium_upsell_card.dart';
import 'video_ejercicio_detail_screen.dart';
import 'video_ejercicio_player_screen.dart';

Future<void> _showPremiumRequiredForVideosTools(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return PremiumFeatureDialogHelper.show(
    context,
    message: l10n.videosPremiumToolsMessage,
  );
}

Future<void> _showPremiumRequiredForVideosPlayback(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return PremiumFeatureDialogHelper.show(
    context,
    message: l10n.videosPremiumPlaybackMessage,
  );
}

class VideosEjerciciosPacienteScreen extends StatefulWidget {
  const VideosEjerciciosPacienteScreen({super.key});

  @override
  State<VideosEjerciciosPacienteScreen> createState() =>
      _VideosEjerciciosPacienteScreenState();
}

class _VideosEjerciciosPacienteScreenState
    extends State<VideosEjerciciosPacienteScreen>
    with SingleTickerProviderStateMixin {
  static const String _paramNonPremiumPreviewCodes =
      'codigos_videos_ejercicios_no_premium';
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  List<VideoEjercicio> _videos = [];
  List<VideoEjercicio> _favoritos = [];
  bool _isLoading = true;
  bool _isLoadingFavoritos = true;
  late TabController _tabController;
  int? _userId;
  bool _isSearchVisible = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _categoriasLoading = false;
  List<Map<String, dynamic>> _categoriasCatalogo = [];
  List<int> _selectedCategoriaIds = [];
  bool _categoriaMatchAll = false;
  String _rutaBaseVideos = '';
  List<int>? _nonPremiumPreviewCodes;
  String? _activeFilterInfo;
  String _sortMode = 'fecha';
  bool _sortAscending = false;
  final Map<String, MemoryImage> _thumbnailCache = {};

  static const String _prefsSortModeKey = 'videos_paciente_sort_mode';
  static const String _prefsSortAscKey = 'videos_paciente_sort_asc';
  static const String _prefsSearchVisibleKey = 'videos_paciente_search_visible';
  static const String _prefsSearchQueryKey = 'videos_paciente_search_query';
  static const String _prefsSelectedCategoriasKey =
      'videos_paciente_selected_categorias';
  static const String _prefsCategoriaMatchAllKey =
      'videos_paciente_categoria_match_all';

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
    final authService = Provider.of<AuthService>(context, listen: false);
    final userCode = authService.userCode;
    _userId = userCode != null ? int.tryParse(userCode) : null;
    _tabController = TabController(length: 2, vsync: this);
    _loadPreferences();
    _loadVideos();
    if (_isPreviewMode) {
      _isLoadingFavoritos = false;
      _categoriasLoading = false;
    } else {
      _loadFavoritos();
      _loadCategorias();
    }
    _loadParametrosVideos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadParametrosVideos() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final valor = await api.getParametroValor('ruta_base_videos_ejercicios');
      if (!mounted) return;
      setState(() {
        _rutaBaseVideos = (valor ?? '').trim();
      });
    } catch (_) {}
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sortMode = prefs.getString(_prefsSortModeKey) ?? 'fecha';
      _sortAscending = prefs.getBool(_prefsSortAscKey) ?? false;
      _isSearchVisible = prefs.getBool(_prefsSearchVisibleKey) ?? false;
      _searchQuery = prefs.getString(_prefsSearchQueryKey) ?? '';
      _searchCtrl.text = _searchQuery;
      _selectedCategoriaIds =
          (prefs.getStringList(_prefsSelectedCategoriasKey) ?? const <String>[])
              .map((e) => int.tryParse(e) ?? 0)
              .where((e) => e > 0)
              .toList();
      _categoriaMatchAll = prefs.getBool(_prefsCategoriaMatchAllKey) ?? false;
      if (_isPreviewMode) {
        _isSearchVisible = false;
        _searchQuery = '';
        _searchCtrl.clear();
        _selectedCategoriaIds = [];
        _categoriaMatchAll = false;
        _activeFilterInfo = null;
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsSortModeKey, _sortMode);
    await prefs.setBool(_prefsSortAscKey, _sortAscending);
    await prefs.setBool(_prefsSearchVisibleKey, _isSearchVisible);
    await prefs.setString(_prefsSearchQueryKey, _searchQuery);
    await prefs.setStringList(
      _prefsSelectedCategoriasKey,
      _selectedCategoriaIds.map((e) => e.toString()).toList(),
    );
    await prefs.setBool(_prefsCategoriaMatchAllKey, _categoriaMatchAll);
  }

  void _applySortSelection(String mode) {
    if (_isPreviewMode) {
      _showPremiumRequiredForVideosTools(context);
      return;
    }
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

  void _toggleSearchVisibility() {
    if (_isPreviewMode) {
      _showPremiumRequiredForVideosTools(context);
      return;
    }
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchCtrl.clear();
        _searchQuery = '';
        _activeFilterInfo = null;
      }
    });
    _savePreferences();
  }

  /// Construye la URL pública del vídeo.
  /// ruta_base_videos_ejercicios contiene la URL base completa
  /// (ej. https://aprendeconpatricia.com/php_api/med/).
  /// rutaVideo contiene solo el nombre/subpath del fichero.
  String _buildVideoUrl(String rutaVideo) {
    final ruta = rutaVideo.trim();
    if (ruta.isEmpty) return '';
    if (ruta.startsWith('http://') || ruta.startsWith('https://')) {
      return ruta;
    }
    if (_rutaBaseVideos.isNotEmpty) {
      final base =
          _rutaBaseVideos.endsWith('/') ? _rutaBaseVideos : '$_rutaBaseVideos/';
      final relativa = ruta.startsWith('/') ? ruta.substring(1) : ruta;
      return '$base$relativa';
    }
    return ruta;
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

  List<VideoEjercicio> _buildPreviewVideos(
    List<VideoEjercicio> source,
    List<int>? previewCodes,
  ) {
    if (source.isEmpty) {
      return <VideoEjercicio>[];
    }

    if (previewCodes != null && previewCodes.isNotEmpty) {
      final byCode = <int, VideoEjercicio>{
        for (final video in source)
          if (video.codigo != null) video.codigo!: video,
      };
      final selected = previewCodes
          .map((code) => byCode[code])
          .whereType<VideoEjercicio>()
          .toList();
      if (selected.isNotEmpty) {
        return selected;
      }
    }

    final sorted = List<VideoEjercicio>.from(source)
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

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      if (_userId == null) {
        if (mounted) {
          setState(() {
            _videos = [];
            _nonPremiumPreviewCodes = null;
            _isLoading = false;
          });
        }
        return;
      }
      final apiService = Provider.of<ApiService>(context, listen: false);
      final previewCodesFuture = _isPreviewMode
          ? apiService
              .getParametroValor(_paramNonPremiumPreviewCodes)
              .then(_parsePreviewCodes)
              .catchError((_) => null)
          : Future<List<int>?>.value(null);
      final rawList = await apiService.getVideosEjerciciosForUser(_userId!);
      final previewCodes = await previewCodesFuture;
      if (mounted) {
        setState(() {
          _videos = rawList.map((e) => VideoEjercicio.fromJson(e)).toList();
          _nonPremiumPreviewCodes = previewCodes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar vídeos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFavoritos() async {
    if (_isPreviewMode || _userId == null) {
      if (mounted) {
        setState(() {
          _favoritos = [];
          _isLoadingFavoritos = false;
        });
      }
      return;
    }
    setState(() => _isLoadingFavoritos = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final rawList = await apiService.getVideosFavoritosForUser(_userId!);
      if (mounted) {
        setState(() {
          _favoritos = rawList.map((e) => VideoEjercicio.fromJson(e)).toList();
        });
      }
    } catch (_) {
      // Tab shows empty list on error
    } finally {
      if (mounted) setState(() => _isLoadingFavoritos = false);
    }
  }

  Future<void> _loadCategorias() async {
    if (_isPreviewMode) {
      if (mounted) {
        setState(() {
          _categoriasCatalogo = [];
          _categoriasLoading = false;
        });
      }
      return;
    }
    setState(() => _categoriasLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response =
          await apiService.get('api/video_ejercicios.php?categorias=1');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _categoriasCatalogo =
                data.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      }
    } finally {
      if (mounted) setState(() => _categoriasLoading = false);
    }
  }

  bool _matchesCategorias(VideoEjercicio v) {
    if (_selectedCategoriaIds.isEmpty) return true;
    if (v.categoriaIds.isEmpty) return false;
    if (_categoriaMatchAll) {
      return _selectedCategoriaIds.every(v.categoriaIds.contains);
    }
    return _selectedCategoriaIds.any(v.categoriaIds.contains);
  }

  List<VideoEjercicio> _filteredAndSorted(List<VideoEjercicio> source) {
    final q = _searchQuery.trim().toLowerCase();
    final list = source.where((v) {
      final matchesSearch = q.isEmpty ||
          v.titulo.toLowerCase().contains(q) ||
          (v.descripcion ?? '').toLowerCase().contains(q) ||
          v.categoriaNombres.any((c) => c.toLowerCase().contains(q));
      return matchesSearch && _matchesCategorias(v);
    }).toList();
    list.sort((a, b) {
      int cmp;
      switch (_sortMode) {
        case 'titulo':
          cmp = a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
          break;
        case 'likes':
          cmp = _compareByPopularity(a, b);
          break;
        case 'fecha':
        default:
          final da = a.fechaa ?? DateTime(2000);
          final db = b.fechaa ?? DateTime(2000);
          cmp = da.compareTo(db);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  int _compareByPopularity(VideoEjercicio a, VideoEjercicio b) {
    final likesCmp = a.totalLikes.compareTo(b.totalLikes);
    if (likesCmp != 0) {
      return likesCmp;
    }

    final favoritosCmp = _boolRank(a.favorito == 'S').compareTo(
      _boolRank(b.favorito == 'S'),
    );
    if (favoritosCmp != 0) {
      return favoritosCmp;
    }

    final meGustaCmp = _boolRank(a.meGusta == 'S').compareTo(
      _boolRank(b.meGusta == 'S'),
    );
    if (meGustaCmp != 0) {
      return meGustaCmp;
    }

    final fechaCmp = (a.fechaa ?? DateTime(2000)).compareTo(
      b.fechaa ?? DateTime(2000),
    );
    if (fechaCmp != 0) {
      return fechaCmp;
    }

    return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
  }

  int _boolRank(bool value) => value ? 1 : 0;

  void _updateVideoState(VideoEjercicio updated) {
    void apply(List<VideoEjercicio> list) {
      final idx = list.indexWhere((e) => e.codigo == updated.codigo);
      if (idx != -1) {
        list[idx].meGusta = updated.meGusta;
        list[idx].favorito = updated.favorito;
        list[idx].totalLikes = updated.totalLikes;
      }
    }

    apply(_videos);
    if (updated.favorito == 'S') {
      if (!_favoritos.any((f) => f.codigo == updated.codigo)) {
        _favoritos.insert(0, updated);
      } else {
        apply(_favoritos);
      }
    } else {
      _favoritos.removeWhere((f) => f.codigo == updated.codigo);
    }
  }

  Future<void> _toggleLike(VideoEjercicio video) async {
    if (_isPreviewMode) {
      await _showPremiumRequiredForVideosTools(context);
      return;
    }
    if (_userId == null) return;
    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.toggleVideoLike(
        videoCodigo: video.codigo!,
        usuarioCodigo: _userId!,
      );
      if (!mounted) return;
      setState(() {
        video.meGusta = result['me_gusta'] ?? 'N';
        video.totalLikes = video.meGusta == 'S'
            ? video.totalLikes + 1
            : (video.totalLikes - 1).clamp(0, 999999);
        _updateVideoState(video);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorito(VideoEjercicio video) async {
    if (_isPreviewMode) {
      await _showPremiumRequiredForVideosTools(context);
      return;
    }
    if (_userId == null) return;
    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.toggleVideoFavorito(
        videoCodigo: video.codigo!,
        usuarioCodigo: _userId!,
      );
      if (!mounted) return;
      setState(() {
        video.favorito = result['favorito'] ?? 'N';
        _updateVideoState(video);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _playVideo(VideoEjercicio video) async {
    if (_isPreviewMode) {
      await _showPremiumRequiredForVideosPlayback(context);
      return;
    }
    final rawUrl = (video.rutaVideo ?? '').trim();
    final isExternalUrl =
        rawUrl.startsWith('http://') || rawUrl.startsWith('https://');

    if (isExternalUrl) {
      bool opened = false;
      try {
        opened = await launchUrlString(
          rawUrl,
          mode: LaunchMode.externalApplication,
        );
      } on PlatformException catch (e) {
        if (e.code == 'channel-error') {
          await _externalUrlChannel.invokeMethod('openUrl', {'url': rawUrl});
          opened = true;
        } else {
          rethrow;
        }
      }
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la URL del vídeo.'),
          ),
        );
      }
    } else if (video.esGif) {
      final gifUrl = _buildVideoUrl(video.rutaVideo ?? '');
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          insetPadding: EdgeInsets.zero,
          child: InteractiveViewer(
            child: Image.network(
              gifUrl,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
    } else {
      final videoUrl = _buildVideoUrl(video.rutaVideo ?? '');
      final isAbsoluteVideoUrl =
          videoUrl.startsWith('http://') || videoUrl.startsWith('https://');
      debugPrint('[VideoEjercicios] rutaVideo en BD: "${video.rutaVideo}"');
      debugPrint('[VideoEjercicios] _rutaBaseVideos: "$_rutaBaseVideos"');
      debugPrint('[VideoEjercicios] URL final construida: "$videoUrl"');
      if (videoUrl.isEmpty || !isAbsoluteVideoUrl) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La URL del vídeo local no es válida. Revisa ruta_base_videos_ejercicios y ruta_video.',
              ),
            ),
          );
        }
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoEjercicioPlayerScreen(
            video: video,
            videoUrl: videoUrl,
          ),
        ),
      );
    }
  }

  Future<void> _openVideoDetail(VideoEjercicio video) async {
    if (_isPreviewMode) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => VideoEjercicioDetailScreen(
            video: video,
            onPlay: () => _showPremiumRequiredForVideosPlayback(context),
            onActionSelected: (_) => _showPremiumRequiredForVideosTools(
              context,
            ),
          ),
        ),
      );
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => VideoEjercicioDetailScreen(
          video: video,
          onPlay: () => _playVideo(video),
        ),
      ),
    );

    if (!mounted) return;
    if (result != null && result.trim().isNotEmpty) {
      if (result.startsWith('__catid__:')) {
        final idRaw = result.replaceFirst('__catid__:', '').trim();
        final id = int.tryParse(idRaw);
        _applyCategoryFilter(categoryId: id, fromTag: true);
        return;
      }
      if (result.startsWith('__cat__:')) {
        final categoryName = result.replaceFirst('__cat__:', '').trim();
        _applyCategoryFilter(categoryName: categoryName, fromTag: true);
        return;
      }
      setState(() {
        _searchQuery = result.trim();
        _isSearchVisible = true;
        _activeFilterInfo = 'Hashtag: #${result.trim()}';
      });
    }
  }

  void _applyCategoryFilter({
    int? categoryId,
    String? categoryName,
    bool fromTag = false,
  }) {
    int? resolvedId = categoryId;
    String? resolvedName = categoryName;
    if (resolvedId == null && categoryName != null && categoryName.isNotEmpty) {
      final match = _categoriasCatalogo.firstWhere(
        (c) =>
            (c['nombre'] ?? '').toString().trim().toLowerCase() ==
            categoryName.trim().toLowerCase(),
        orElse: () => const <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        resolvedId = int.tryParse(match['codigo'].toString());
        resolvedName = (match['nombre'] ?? '').toString();
      }
    }

    if (resolvedId != null && (resolvedName == null || resolvedName.isEmpty)) {
      final match = _categoriasCatalogo.firstWhere(
        (c) => int.tryParse(c['codigo'].toString()) == resolvedId,
        orElse: () => const <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        resolvedName = (match['nombre'] ?? '').toString();
      }
    }

    setState(() {
      if (resolvedId != null) {
        _selectedCategoriaIds = [resolvedId];
        _categoriaMatchAll = false;
        _searchQuery = '';
        _isSearchVisible = false;
        _activeFilterInfo =
            fromTag ? 'Categoría: ${resolvedName ?? resolvedId}' : null;
      } else if (categoryName != null && categoryName.trim().isNotEmpty) {
        _searchQuery = categoryName.trim();
        _isSearchVisible = true;
        _activeFilterInfo =
            fromTag ? 'Categoría: ${categoryName.trim()}' : null;
      }
    });
    _savePreferences();
  }

  String _shortDescription(String text, {int maxChars = 120}) {
    final withoutHashtags = text.replaceAll(
      RegExp(r'(^|\s)#[\wáéíóúÁÉÍÓÚñÑüÜ]+'),
      ' ',
    );
    final normalized = withoutHashtags.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return '';
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars)}...';
  }

  Future<void> _showCategoriaFilterDialog() async {
    if (_isPreviewMode) {
      await _showPremiumRequiredForVideosTools(context);
      return;
    }
    if (_categoriasCatalogo.isEmpty && !_categoriasLoading) {
      await _loadCategorias();
    }
    List<int> tempSelected = List<int>.from(_selectedCategoriaIds);
    bool tempMatchAll = _categoriaMatchAll;
    String searchQuery = '';
    const showSearchKey = 'videos_paciente_filter_show_search';
    final prefs = await SharedPreferences.getInstance();
    bool showSearch = prefs.getBool(showSearchKey) ?? false;

    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final filtered = _categoriasCatalogo.where((cat) {
            if (searchQuery.trim().isEmpty) return true;
            final name = (cat['nombre'] ?? '').toString().toLowerCase();
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
                    setStateDialog(() {});
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
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSearch) ...[
                    TextField(
                      onChanged: (value) {
                        setStateDialog(() {
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
                                  setStateDialog(() {
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
                            setStateDialog(() {});
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
                        children: filtered.map((cat) {
                          final id = int.tryParse('${cat['codigo']}') ?? 0;
                          return CheckboxListTile(
                            dense: true,
                            value: tempSelected.contains(id),
                            title: Text((cat['nombre'] ?? '').toString()),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (checked) {
                              setStateDialog(() {
                                if (checked == true) {
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
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    value: tempMatchAll,
                    onChanged: (v) => setStateDialog(() => tempMatchAll = v),
                    title: const Text('Coincidir todas'),
                    dense: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setStateDialog(() {
                    tempSelected = <int>[];
                    tempMatchAll = false;
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
                    if (tempSelected.isNotEmpty)
                      Container(
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
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
          );
        },
      ),
    );

    if (applied == true) {
      setState(() {
        _selectedCategoriaIds = tempSelected;
        _categoriaMatchAll = tempMatchAll;
        _activeFilterInfo = null;
      });
      _savePreferences();
    }
  }

  // ignore: unused_element
  Widget _buildHashtagText(String texto, {TextStyle? baseStyle}) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'#[\wáéíóúÁÉÍÓÚñÑüÜ]+', caseSensitive: false);
    int lastEnd = 0;
    for (final match in regex.allMatches(texto)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: texto.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }
      final tag = match.group(0)!;
      spans.add(TextSpan(
        text: tag,
        style: (baseStyle ?? const TextStyle()).copyWith(
          color: Colors.blue,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => setState(() {
                _searchQuery = tag.replaceFirst('#', '');
                _isSearchVisible = true;
                _activeFilterInfo = 'Hashtag: $tag';
              }),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < texto.length) {
      spans.add(TextSpan(text: texto.substring(lastEnd), style: baseStyle));
    }
    return RichText(text: TextSpan(children: spans));
  }

  ImageProvider? _thumbnailProviderFor(VideoEjercicio video) {
    final raw = (video.imagenMiniatura ?? '').trim();
    if (raw.isEmpty) return null;
    final cached = _thumbnailCache[raw];
    if (cached != null) {
      return cached;
    }
    try {
      final provider = MemoryImage(base64Decode(raw));
      _thumbnailCache[raw] = provider;
      return provider;
    } catch (_) {
      return null;
    }
  }

  Widget _buildYoutubeOverlayBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: const Icon(
        Icons.smart_display_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildVideoCard(VideoEjercicio video) {
    final isPreviewMode = _isPreviewMode;
    final thumbProvider = _thumbnailProviderFor(video);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _playVideo(video),
              child: thumbProvider != null
                  ? AspectRatio(
                      aspectRatio: 16 / 9,
                      child: RepaintBoundary(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image(
                              image: thumbProvider,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  video.esYoutube
                                      ? Icons.play_circle_outline
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                            if (video.esYoutube)
                              Positioned(
                                right: 10,
                                bottom: 10,
                                child: _buildYoutubeOverlayBadge(),
                              ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      height: 110,
                      color: Colors.grey[200],
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              video.esYoutube
                                  ? Icons.smart_display_outlined
                                  : Icons.play_circle_outline,
                              size: 52,
                              color: Colors.grey[400],
                            ),
                          ),
                          if (video.esYoutube)
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: _buildYoutubeOverlayBadge(),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          InkWell(
            onTap: () => _openVideoDetail(video),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((video.descripcion ?? '').isNotEmpty)
                    Builder(
                      builder: (context) {
                        final shortDescription =
                            _shortDescription(video.descripcion ?? '');
                        if (shortDescription.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            shortDescription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      isPreviewMode
                          ? 'Toca la portada para reproducir. El detalle está disponible, la reproducción completa es Premium'
                          : 'Toca la portada para reproducir o el contenido para ver el detalle',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isPreviewMode ? Colors.deepOrange : Colors.blueGrey,
                        fontStyle: FontStyle.italic,
                        fontWeight:
                            isPreviewMode ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    video.meGusta == 'S'
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: video.meGusta == 'S' ? Colors.red : null,
                  ),
                  onPressed: () => _toggleLike(video),
                ),
                Text('${video.totalLikes}',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    video.favorito == 'S'
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: video.favorito == 'S' ? Colors.amber : null,
                  ),
                  onPressed: () => _toggleFavorito(video),
                ),
                const Spacer(),
                if (!video.esYoutube)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(
                        video.esGif ? 'GIF' : 'Vídeo',
                        style: const TextStyle(fontSize: 11),
                      ),
                      avatar: Icon(
                        video.esGif ? Icons.gif : Icons.play_circle,
                        size: 14,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(List<VideoEjercicio> filtered, bool isLoading) {
    final isPreviewMode = _isPreviewMode;
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _searchQuery.isNotEmpty || _selectedCategoriaIds.isNotEmpty
                ? 'No hay vídeos con ese filtro'
                : 'No hay vídeos disponibles',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _loadVideos();
        if (!isPreviewMode) {
          await _loadFavoritos();
        }
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: isPreviewMode ? filtered.length + 1 : filtered.length,
        itemBuilder: (_, i) {
          if (isPreviewMode && i == filtered.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
              child: PremiumUpsellCard(
                title: AppLocalizations.of(context)!.videosPremiumTitle,
                subtitle: AppLocalizations.of(context)!.videosPremiumSubtitle,
                subtitleHighlight:
                    AppLocalizations.of(context)!.videosPremiumPreviewHighlight(
                  _catalogHighlightCount(_videos.length),
                ),
                onPressed: () => Navigator.pushNamed(context, '/premium_info'),
              ),
            );
          }
          return _buildVideoCard(filtered[i]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPreviewMode = _isPreviewMode;
    final filteredTodos = isPreviewMode
        ? _buildPreviewVideos(_videos, _nonPremiumPreviewCodes)
        : _filteredAndSorted(_videos);
    final filteredFavoritos =
        isPreviewMode ? <VideoEjercicio>[] : _filteredAndSorted(_favoritos);
    final badgeCount = isPreviewMode
        ? _videos.length
        : _tabController.index == 0
            ? filteredTodos.length
            : filteredFavoritos.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(child: Text('Vídeos ejercicios')),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search),
            tooltip: _isSearchVisible ? 'Ocultar buscar' : 'Buscar',
            onPressed: isPreviewMode
                ? () => _showPremiumRequiredForVideosTools(context)
                : _toggleSearchVisibility,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_alt),
                tooltip: 'Filtrar ejercicios',
                onPressed: isPreviewMode
                    ? () => _showPremiumRequiredForVideosTools(context)
                    : _showCategoriaFilterDialog,
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
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (value) async {
              if (isPreviewMode) {
                await _showPremiumRequiredForVideosTools(context);
                return;
              }
              if (value == 'buscar') {
                _toggleSearchVisibility();
                return;
              }
              if (value == 'filtrar') {
                await _showCategoriaFilterDialog();
                return;
              }
              if (value == 'actualizar') {
                await _loadVideos();
                await _loadFavoritos();
                return;
              }
              if (value == 'sort_titulo') {
                _applySortSelection('titulo');
                return;
              }
              if (value == 'sort_fecha') {
                _applySortSelection('fecha');
                return;
              }
              if (value == 'sort_likes') {
                _applySortSelection('likes');
                return;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'buscar',
                child: Row(
                  children: [
                    Icon(
                      _isSearchVisible ? Icons.search_off : Icons.search,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(_isSearchVisible ? 'Ocultar buscar' : 'Buscar'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'filtrar',
                child: Row(
                  children: [
                    Stack(
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
                    SizedBox(width: 10),
                    Text('Filtrar'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'actualizar',
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
                value: 'sort_titulo',
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
                value: 'sort_fecha',
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
                value: 'sort_likes',
                checked: _sortMode == 'likes',
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Populares')),
                    if (_sortMode == 'likes')
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
          onTap: (index) {
            if (isPreviewMode && index == 1) {
              Future.microtask(
                () => _showPremiumRequiredForVideosTools(context),
              );
              _tabController.animateTo(0);
            }
          },
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Favoritos'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isSearchVisible && !isPreviewMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar vídeo de ejercicio',
                  prefixIcon: IconButton(
                    tooltip: _searchQuery.trim().isNotEmpty
                        ? 'Limpiar búsqueda'
                        : 'Buscar',
                    onPressed: _searchQuery.trim().isNotEmpty
                        ? () {
                            setState(() {
                              _searchCtrl.clear();
                              _searchQuery = '';
                              _activeFilterInfo = null;
                            });
                            _savePreferences();
                          }
                        : null,
                    icon: Icon(
                      _searchQuery.trim().isNotEmpty
                          ? Icons.clear
                          : Icons.search,
                    ),
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Ocultar búsqueda',
                    icon: const Icon(Icons.visibility_off_outlined),
                    onPressed: _toggleSearchVisibility,
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  setState(() {
                    _searchQuery = v.trim();
                    _activeFilterInfo = null;
                  });
                  _savePreferences();
                },
              ),
            ),
          if (!isPreviewMode &&
              _activeFilterInfo != null &&
              _activeFilterInfo!.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _activeFilterInfo!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar filtro',
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        _activeFilterInfo = null;
                        _searchCtrl.clear();
                        _searchQuery = '';
                        _selectedCategoriaIds = [];
                        _categoriaMatchAll = false;
                        _isSearchVisible = false;
                      });
                      _savePreferences();
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics:
                  isPreviewMode ? const NeverScrollableScrollPhysics() : null,
              children: [
                _buildTabContent(filteredTodos, _isLoading),
                _buildTabContent(filteredFavoritos, _isLoadingFavoritos),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
