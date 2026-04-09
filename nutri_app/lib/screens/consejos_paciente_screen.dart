import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
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
import '../services/menu_visibility_premium_service.dart';
import '../models/consejo.dart';
import '../models/consejo_documento.dart';
import '../widgets/image_viewer_dialog.dart';
import '../widgets/premium_upsell_card.dart';
import '../widgets/restricted_access_dialog_helper.dart';

bool _canUseConsejosCopyPdf(AuthService authService) {
  return authService.isPremium ||
      authService.userType == 'Nutricionista' ||
      authService.userType == 'Administrador';
}

Future<void> _showPremiumRequiredForConsejosCopyPdf(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return RestrictedAccessDialogHelper.show(
    context,
    title: l10n.commonPremiumFeatureTitle,
    message: l10n.commonRecipesAndTipsPremiumCopyPdfMessage,
    primaryActionLabel: l10n.navPremium,
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

class ConsejosPacienteScreen extends StatefulWidget {
  const ConsejosPacienteScreen({super.key});

  @override
  State<ConsejosPacienteScreen> createState() => _ConsejosPacienteScreenState();
}

class _ConsejosPacienteScreenState extends State<ConsejosPacienteScreen>
    with SingleTickerProviderStateMixin {
  static const int _defaultPageSize = 6;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  List<Consejo> _consejos = [];
  List<Consejo> _consejosPortada = [];
  List<Consejo> _consejosPersonalizados = [];
  List<Consejo> _consejosFavoritos = [];
  bool _isLoading = true;
  bool _isLoadingPortada = true;
  bool _isLoadingPersonalizados = false;
  bool _isLoadingFavoritos = true;
  bool _isLoadingMore = false;
  bool _isLoadingMorePortada = false;
  bool _isLoadingMorePersonalizados = false;
  bool _isLoadingMoreFavoritos = false;
  bool _hasMoreConsejos = true;
  bool _hasMorePortada = true;
  bool _hasMorePersonalizados = true;
  bool _hasMoreFavoritos = true;
  late TabController _tabController;
  String? _patientCode;
  String? _userCode;
  bool _isGuestMode = false;
  bool _isSearchVisible = false;
  String _searchQuery = '';
  String _sortMode = 'fecha';
  bool _sortAscending = false;
  int _currentTabFilteredTotal = 0;
  int _countRequestId = 0;
  bool _categoriasLoading = false;
  List<Map<String, dynamic>> _categoriasCatalogo = [];
  List<int> _selectedCategoriaIds = [];
  bool _categoriaMatchAll = false;
  bool _isMenuPremiumEnabled = false;
  List<int>? _nonPremiumPreviewCodes;
  int _pageSize = _defaultPageSize;
  final Map<String, MemoryImage> _coverImageProviderCache = {};

  String _buildCoverCacheKey(Consejo consejo) {
    final raw = _resolveListCoverBase64(consejo);
    if (raw.isEmpty) return '';
    return '${consejo.codigo ?? 'noid'}:${raw.hashCode}:${raw.length}';
  }

  String _resolveListCoverBase64(Consejo consejo) {
    final portada = (consejo.imagenPortada ?? '').trim();
    if (portada.isNotEmpty) {
      return portada;
    }
    return (consejo.imagenMiniatura ?? '').trim();
  }

  ImageProvider? _getCachedCoverProvider(Consejo consejo) {
    final raw = _resolveListCoverBase64(consejo);
    if (raw.isEmpty) return null;

    final key = _buildCoverCacheKey(consejo);
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

  String? _primaryCategoriaLabel(List<String> categorias) {
    for (final categoria in categorias) {
      final normalized = categoria.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  List<MapEntry<int, String>> _visibleCategoryTags(
    List<int> categoriaIds,
    List<String> categoriaNombres,
  ) {
    final tags = <MapEntry<int, String>>[];
    final total = categoriaIds.length < categoriaNombres.length
        ? categoriaIds.length
        : categoriaNombres.length;

    for (var index = 0; index < total; index++) {
      final id = categoriaIds[index];
      final label = categoriaNombres[index].trim();
      if (id <= 0 || label.isEmpty) {
        continue;
      }
      if (tags.any((tag) => tag.key == id)) {
        continue;
      }
      tags.add(MapEntry(id, label));
      if (tags.length == 2) {
        break;
      }
    }

    return tags;
  }

  Widget _buildCategoryBadge({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isLongTag = label.trim().length > 13;
    final backgroundOpacity = isLongTag ? 0.46 : 0.72;
    final borderOpacity = isLongTag ? 0.56 : 0.9;
    final foregroundOpacity = isLongTag ? 0.82 : 1.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(backgroundOpacity),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(borderOpacity)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: Colors.teal.shade700.withOpacity(foregroundOpacity),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.teal.shade900.withOpacity(foregroundOpacity),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyCategoryFilterFromCard(int categoryId) {
    if (_selectedCategoriaIds.length == 1 &&
        _selectedCategoriaIds.first == categoryId) {
      return;
    }

    setState(() {
      _selectedCategoriaIds = [categoryId];
    });
    _savePreferences();
    _refreshCurrentTabFilteredTotal();
  }

  Widget _buildConsejoCardHeader(
    Consejo consejo,
    ImageProvider? coverProvider, {
    required bool showUnreadBadge,
    required String unreadBadgeText,
  }) {
    final categoryTags = _visibleCategoryTags(
      consejo.categoriaIds,
      consejo.categoriaNombres,
    );

    return SizedBox(
      height: 170,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.teal.shade50,
                    Colors.cyan.shade50,
                    Colors.blueGrey.shade50,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -26,
            right: -18,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ),
          Positioned(
            left: -24,
            bottom: -34,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal.shade100.withOpacity(0.35),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 132,
              height: 112,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.95)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.shade100.withOpacity(0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: coverProvider != null
                  ? RepaintBoundary(
                      child: Image(
                        image: coverProvider,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    )
                  : Icon(
                      Icons.article_outlined,
                      size: 44,
                      color: Colors.teal.shade300,
                    ),
            ),
          ),
          if (categoryTags.isNotEmpty)
            Positioned(
              left: 14,
              bottom: 12,
              child: _buildCategoryBadge(
                label: categoryTags.first.value,
                icon: Icons.local_offer_outlined,
                onTap: () =>
                    _applyCategoryFilterFromCard(categoryTags.first.key),
              ),
            ),
          if (categoryTags.length > 1)
            Positioned(
              right: 14,
              bottom: 12,
              child: _buildCategoryBadge(
                label: categoryTags[1].value,
                icon: Icons.sell_outlined,
                onTap: () => _applyCategoryFilterFromCard(categoryTags[1].key),
              ),
            ),
          if (showUnreadBadge && consejo.leido == 'N')
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fiber_new, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      unreadBadgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<int> _loadConfiguredPageSize() async {
    try {
      final raw = await context.read<ApiService>().getParametroValor(
            'numero_consejos_cargar_paginacion',
          );
      final parsed = int.tryParse((raw ?? '').trim());
      if (parsed == null || parsed <= 0) {
        return _defaultPageSize;
      }
      return parsed > 50 ? 50 : parsed;
    } catch (_) {
      return _defaultPageSize;
    }
  }

  void _showGenericLoadError() {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.privacyDeleteConnectionError),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Consejo> _parseConsejosResponse(String responseBody) {
    final decoded = json.decode(responseBody);
    if (decoded is! List) {
      throw const FormatException('Respuesta inválida');
    }
    return decoded
        .map((item) => Consejo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _patientCode = authService.patientCode;
    _userCode = authService.userCode;
    _isGuestMode = authService.isGuestMode;

    final hasPatient = (_patientCode ?? '').isNotEmpty;
    final tabCount = hasPatient ? 4 : 3;
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        _loadPreferences();
        _refreshCurrentTabFilteredTotal();
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        if (args['openPersonalizados'] == true && hasPatient) {
          _tabController.animateTo(0);
        } else if (args['openDestacados'] == true) {
          _tabController.animateTo(hasPatient ? 1 : 0);
        } else if (args['openTodos'] == true) {
          _tabController.animateTo(hasPatient ? 2 : 1);
        }
      }
    });

    _initializeScreen(hasPatient);
    _loadCategorias();
    _loadPreferences();
    _refreshCurrentTabFilteredTotal();
    _loadMenuPremiumConfig();
  }

  Future<void> _initializeScreen(bool hasPatient) async {
    final configuredPageSize = await _loadConfiguredPageSize();
    if (!mounted) {
      return;
    }
    setState(() {
      _pageSize = configuredPageSize;
    });

    _loadConsejosPortada(reset: true);
    _loadConsejos(reset: true);
    if (hasPatient) {
      _loadConsejosPersonalizados(reset: true);
    }
    _loadConsejosFavoritos(reset: true);
  }

  bool get _canAccessFullCatalog {
    final authService = context.read<AuthService>();
    if (!_isMenuPremiumEnabled) {
      return true;
    }
    return authService.isPremium ||
        MenuVisibilityPremiumService.isPrivilegedUserType(
          authService.userType,
        );
  }

  bool get _isPreviewMode => !_canAccessFullCatalog;

  Future<void> _loadMenuPremiumConfig() async {
    try {
      final apiService = context.read<ApiService>();
      final config = await MenuVisibilityPremiumService.loadConfig(
        apiService: apiService,
        forceRefresh: true,
      );
      final premiumEnabled = MenuVisibilityPremiumService.isPremium(
        config,
        MenuVisibilityPremiumService.consejos,
      );
      List<int>? previewCodes;
      if (premiumEnabled) {
        final raw = await apiService.getParametroValor(
          'codigos_consejos_no_premium',
        );
        previewCodes = _parsePreviewCodes(raw);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isMenuPremiumEnabled = premiumEnabled;
        _nonPremiumPreviewCodes = previewCodes;
      });
    } catch (_) {}
  }

  List<int>? _parsePreviewCodes(String? rawValue) {
    final raw =
        (rawValue ?? '').trim().replaceAll(';', ',').replaceAll('|', ',');
    if (raw.isEmpty) {
      return null;
    }

    final codes = raw
        .split(',')
        .map((item) => int.tryParse(item.trim()))
        .whereType<int>()
        .where((value) => value > 0)
        .toList(growable: false);

    return codes.isEmpty ? null : codes;
  }

  List<Consejo> _allLoadedConsejos() {
    final byKey = <String, Consejo>{};

    void addItems(List<Consejo> items) {
      for (final item in items) {
        final key = item.codigo?.toString() ??
            '${item.titulo.trim().toLowerCase()}|${item.texto.hashCode}';
        byKey.putIfAbsent(key, () => item);
      }
    }

    addItems(_consejosPersonalizados);
    addItems(_consejosPortada);
    addItems(_consejos);
    addItems(_consejosFavoritos);
    return byKey.values.toList(growable: false);
  }

  List<Consejo> _buildPreviewConsejos() {
    final all = _allLoadedConsejos();
    final configuredCodes = _nonPremiumPreviewCodes;
    if (configuredCodes != null && configuredCodes.isNotEmpty) {
      final byCode = <int, Consejo>{
        for (final item in all)
          if (item.codigo != null) item.codigo!: item,
      };
      final configuredItems = configuredCodes
          .map((code) => byCode[code])
          .whereType<Consejo>()
          .toList(growable: false);
      if (configuredItems.isNotEmpty) {
        return configuredItems.take(3).toList(growable: false);
      }
    }

    final preview = List<Consejo>.from(all);
    preview.sort((a, b) {
      final dateA = a.fechaInicio ?? a.fechaa ?? DateTime(1970);
      final dateB = b.fechaInicio ?? b.fechaa ?? DateTime(1970);
      final byDate = dateB.compareTo(dateA);
      if (byDate != 0) {
        return byDate;
      }
      return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
    });
    return preview.take(3).toList(growable: false);
  }

  Widget _buildPreviewBody(double listBottomPadding) {
    final l10n = AppLocalizations.of(context)!;
    final previewItems = _buildPreviewConsejos();
    final totalConsejos = _allLoadedConsejos().length;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 12, 16, listBottomPadding),
      itemCount: previewItems.length + 1,
      itemBuilder: (context, index) {
        if (index == previewItems.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: PremiumUpsellCard(
              title: l10n.tipsPremiumPreviewTitle,
              subtitle: l10n.tipsPremiumPreviewSubtitle,
              subtitleHighlight: totalConsejos > 3
                  ? l10n.tipsPreviewAvailableCount(totalConsejos)
                  : null,
              subtitleHighlightColor: Colors.pink.shade700,
              onPressed: () => Navigator.pushNamed(context, '/premium_info'),
            ),
          );
        }

        return _buildConsejoCard(
          previewItems[index],
          allowSocialActions: false,
          showUnreadBadge: false,
          allowCopyAndPdf: false,
          isPreviewMode: true,
        );
      },
    );
  }

  Future<List<Consejo>> _fetchAllConsejosPersonalizados() async {
    final hasPatient = (_patientCode ?? '').isNotEmpty;
    if (!hasPatient ||
        _isGuestMode ||
        _userCode == null ||
        _userCode!.isEmpty) {
      return <Consejo>[];
    }

    final apiService = context.read<ApiService>();
    final response = await apiService.get(
      'api/consejo_pacientes.php?personalizados_paciente=1&paciente=$_userCode',
    );
    if (response.statusCode != 200) return <Consejo>[];

    final List<dynamic> data = json.decode(response.body);
    return data.map((item) => Consejo.fromJson(item)).toList();
  }

  Future<List<Consejo>> _fetchAllConsejosForCurrentTab() async {
    final apiService = context.read<ApiService>();
    final hasPatient = (_patientCode ?? '').isNotEmpty;
    final tabIndex = _tabController.index;

    if (hasPatient && tabIndex == 0) {
      return _fetchAllConsejosPersonalizados();
    }

    if ((hasPatient && tabIndex == 1) || (!hasPatient && tabIndex == 0)) {
      final patientParam = _patientCode ?? '0';
      var url = 'api/consejos.php?portada=S&paciente_codigo=$patientParam';
      if (_userCode != null && !_isGuestMode) {
        url += '&codigo_usuario=$_userCode';
      }

      final response = await apiService.get(url);
      if (response.statusCode != 200) return <Consejo>[];

      final List<dynamic> data = json.decode(response.body);
      var items = data.map((item) => Consejo.fromJson(item)).toList();

      if (hasPatient) {
        final personalizados = await _fetchAllConsejosPersonalizados();
        final personalesCodigos =
            personalizados.map((c) => c.codigo).whereType<int>().toSet();
        items = items
            .where((c) =>
                c.codigo == null || !personalesCodigos.contains(c.codigo))
            .toList(growable: false);
      }

      return items;
    }

    if ((hasPatient && tabIndex == 2) || (!hasPatient && tabIndex == 1)) {
      final userParam =
          (_isGuestMode || _userCode == null || _userCode!.isEmpty)
              ? '0'
              : _userCode!;
      final response = await apiService.get(
        'api/consejo_pacientes.php?todos_paciente=1&paciente=$userParam',
      );
      if (response.statusCode != 200) return <Consejo>[];

      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => Consejo.fromJson(item)).toList();
    }

    if (_isGuestMode || _userCode == null || _userCode!.isEmpty) {
      return <Consejo>[];
    }

    final response = await apiService.get(
      'api/consejo_usuarios.php?favoritos=1&usuario=$_userCode',
    );
    if (response.statusCode != 200) return <Consejo>[];

    final List<dynamic> data = json.decode(response.body);
    final parsed = <Consejo>[];
    for (final item in data) {
      try {
        parsed.add(Consejo.fromJson(item));
      } catch (_) {}
    }
    return parsed;
  }

  Future<void> _refreshCurrentTabFilteredTotal() async {
    final requestId = ++_countRequestId;
    try {
      final items = await _fetchAllConsejosForCurrentTab();
      final total = _applySearchAndSort(items).length;
      if (!mounted || requestId != _countRequestId) return;
      setState(() {
        _currentTabFilteredTotal = total;
      });
    } catch (_) {
      if (!mounted || requestId != _countRequestId) return;
      setState(() {
        _currentTabFilteredTotal = _getFilteredTabCount();
      });
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sortMode = prefs.getString('consejos_sortMode') ?? 'fecha';
      _sortAscending = prefs.getBool('consejos_sortAscending') ?? false;
      _selectedCategoriaIds = prefs
              .getStringList('consejos_categoriaIds')
              ?.map(int.parse)
              .toList() ??
          <int>[];
      _categoriaMatchAll = prefs.getBool('consejos_categoriaMatchAll') ?? false;
    });
    _refreshCurrentTabFilteredTotal();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString('consejos_sortMode', _sortMode),
      prefs.setBool('consejos_sortAscending', _sortAscending),
      prefs.setStringList('consejos_categoriaIds',
          _selectedCategoriaIds.map((e) => e.toString()).toList()),
      prefs.setBool('consejos_categoriaMatchAll', _categoriaMatchAll),
    ]);
  }

  Future<void> _loadCategorias() async {
    setState(() {
      _categoriasLoading = true;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/consejos.php?categorias=1');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _categoriasCatalogo =
              data.map((item) => Map<String, dynamic>.from(item)).toList();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _categoriasLoading = false;
        });
      }
    }
  }

  bool _matchesCategorias(Consejo consejo) {
    if (_selectedCategoriaIds.isEmpty) return true;
    final ids = consejo.categoriaIds;
    if (ids.isEmpty) return false;
    if (_categoriaMatchAll) {
      return _selectedCategoriaIds.every(ids.contains);
    }
    return _selectedCategoriaIds.any(ids.contains);
  }

  Future<void> _showCategoriaFilterDialog() async {
    final l10n = AppLocalizations.of(context)!;
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
                Expanded(
                  child: Text(
                    l10n.commonFilterByCategories,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonClose,
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
                    _selectedCategoriaIds = [];
                    _categoriaMatchAll = false;
                  });
                  _savePreferences();
                  _refreshCurrentTabFilteredTotal();
                  Navigator.pop(context);
                },
                child: Text(l10n.commonClear),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedCategoriaIds = tempSelected;
                    _categoriaMatchAll = tempMatchAll;
                  });
                  _savePreferences();
                  _refreshCurrentTabFilteredTotal();
                  Navigator.pop(context);
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

  void _updateConsejoInList(List<Consejo> list, Consejo updated) {
    final index = list.indexWhere((item) => item.codigo == updated.codigo);
    if (index == -1) return;
    list[index].meGusta = updated.meGusta;
    list[index].favorito = updated.favorito;
    list[index].totalLikes = updated.totalLikes;
  }

  void _applyConsejoUpdate(Consejo updated, {bool syncFavoritos = true}) {
    if (updated.codigo == null) return;
    setState(() {
      _updateConsejoInList(_consejos, updated);
      _updateConsejoInList(_consejosPortada, updated);

      if (syncFavoritos) {
        final favIndex = _consejosFavoritos
            .indexWhere((item) => item.codigo == updated.codigo);
        if (updated.favorito == 'S') {
          if (favIndex == -1) {
            _consejosFavoritos.insert(0, updated);
          } else {
            _updateConsejoInList(_consejosFavoritos, updated);
          }
        } else if (favIndex != -1) {
          _consejosFavoritos.removeAt(favIndex);
        }
      } else {
        _updateConsejoInList(_consejosFavoritos, updated);
      }
    });
  }

  void _onDetailConsejoUpdated(Consejo updated) {
    _applyConsejoUpdate(updated, syncFavoritos: true);
  }

  DateTime _getConsejoDate(Consejo consejo) {
    return consejo.fechaInicio ??
        consejo.fechaa ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _getPopularScore(Consejo consejo) {
    final likes = consejo.totalLikes ?? 0;
    final alcance = consejo.totalPacientes ?? 0;
    final favoritoActual = consejo.favorito == 'S' ? 2 : 0;
    final meGustaActual = consejo.meGusta == 'S' ? 1 : 0;
    return (likes * 3) + (alcance * 2) + favoritoActual + meGustaActual;
  }

  List<Consejo> _currentTabSource() {
    final hasPatient = (_patientCode ?? '').isNotEmpty;
    final tabIndex = _tabController.index;

    if (hasPatient) {
      if (tabIndex == 0) return _consejosPersonalizados;
      if (tabIndex == 1) {
        final personalesCodigos = _consejosPersonalizados
            .map((c) => c.codigo)
            .whereType<int>()
            .toSet();
        return _consejosPortada
            .where((c) =>
                c.codigo == null || !personalesCodigos.contains(c.codigo))
            .toList(growable: false);
      }
      if (tabIndex == 2) return _consejos;
      return _consejosFavoritos;
    }

    if (tabIndex == 0) return _consejosPortada;
    if (tabIndex == 1) return _consejos;
    return _consejosFavoritos;
  }

  int _currentTabCount() {
    return _currentTabFilteredTotal;
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
    _refreshCurrentTabFilteredTotal();
  }

  List<Consejo> _applySearchAndSort(List<Consejo> source) {
    final query = _searchQuery.trim().toLowerCase();
    var items = source
        .where((consejo) {
          if (query.isEmpty) return true;
          final title = consejo.titulo.toLowerCase();
          final text = consejo.texto.toLowerCase();
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
              ? _getConsejoDate(a).compareTo(_getConsejoDate(b))
              : _getConsejoDate(b).compareTo(_getConsejoDate(a));
        case 'titulo':
          final titleCompare =
              a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
          return _sortAscending ? titleCompare : -titleCompare;
        case 'fecha':
        default:
          final dateCompare = _getConsejoDate(a).compareTo(_getConsejoDate(b));
          if (dateCompare != 0) {
            return _sortAscending ? dateCompare : -dateCompare;
          }
          final titleCompare =
              a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
          return _sortAscending ? titleCompare : -titleCompare;
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
    final hasPatient = (_patientCode ?? '').isNotEmpty;
    final tabIndex = _tabController.index;

    if (hasPatient) {
      if (tabIndex == 0) {
        await _loadConsejosPersonalizados(reset: true);
      } else if (tabIndex == 1) {
        await _loadConsejosPortada(reset: true);
      } else if (tabIndex == 2) {
        await _loadConsejos(reset: true);
      } else {
        await _loadConsejosFavoritos(reset: true);
      }
      return;
    }

    if (tabIndex == 0) {
      await _loadConsejosPortada(reset: true);
    } else if (tabIndex == 1) {
      await _loadConsejos(reset: true);
    } else {
      await _loadConsejosFavoritos(reset: true);
    }
  }

  Future<void> _loadConsejos({bool reset = false}) async {
    final l10n = AppLocalizations.of(context)!;
    if (!reset && (_isLoading || _isLoadingMore || !_hasMoreConsejos)) {
      return;
    }

    final offset = reset ? 0 : _consejos.length;

    setState(() {
      if (reset) {
        _isLoading = true;
        _hasMoreConsejos = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Para guest mode o sin userCode, usar usuario=0 para obtener solo visible_para_todos
      final userParam =
          (_isGuestMode || _userCode == null || _userCode!.isEmpty)
              ? '0'
              : _userCode!;

      // Usar el endpoint correcto: consejo_pacientes.php?todos_paciente=1&paciente=X
      // Esto obtendrá tanto los consejos asignados al paciente como los visible_para_todos
      String url =
          'api/consejo_pacientes.php?todos_paciente=1&paciente=$userParam&limit=$_pageSize&offset=$offset&include_images=0';

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final parsed = _parseConsejosResponse(response.body);
        if (mounted) {
          setState(() {
            _consejos = reset ? parsed : [..._consejos, ...parsed];
            _hasMoreConsejos = parsed.length >= _pageSize;
          });
        }
      } else {
        _showGenericLoadError();
      }
    } catch (_) {
      _showGenericLoadError();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadConsejosPortada({bool reset = false}) async {
    if (!reset &&
        (_isLoadingPortada || _isLoadingMorePortada || !_hasMorePortada)) {
      return;
    }

    final offset = reset ? 0 : _consejosPortada.length;

    setState(() {
      if (reset) {
        _isLoadingPortada = true;
        _hasMorePortada = true;
      } else {
        _isLoadingMorePortada = true;
      }
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Para guest mode o sin patientCode, usar paciente_codigo=0
      final patientParam = _patientCode ?? '0';

      // Construir URL con codigo_usuario si está disponible (para obtener estado de favorito)
      String url =
          'api/consejos.php?portada=S&paciente_codigo=$patientParam&limit=$_pageSize&offset=$offset&include_images=0';
      if (_userCode != null && !_isGuestMode) {
        url += '&codigo_usuario=$_userCode';
      }

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final parsed = _parseConsejosResponse(response.body);
        if (mounted) {
          setState(() {
            _consejosPortada =
                reset ? parsed : [..._consejosPortada, ...parsed];
            _hasMorePortada = parsed.length >= _pageSize;
          });
        }
      } else {
        _showGenericLoadError();
      }
    } catch (_) {
      _showGenericLoadError();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPortada = false;
          _isLoadingMorePortada = false;
        });
      }
    }
  }

  Future<void> _loadConsejosPersonalizados({bool reset = false}) async {
    // Solo cargar para usuarios con paciente
    final hasPatient = (_patientCode ?? '').isNotEmpty;
    if (!hasPatient || _isGuestMode) {
      return;
    }

    if (!reset &&
        (_isLoadingPersonalizados ||
            _isLoadingMorePersonalizados ||
            !_hasMorePersonalizados)) {
      return;
    }

    final offset = reset ? 0 : _consejosPersonalizados.length;

    setState(() {
      if (reset) {
        _isLoadingPersonalizados = true;
        _hasMorePersonalizados = true;
      } else {
        _isLoadingMorePersonalizados = true;
      }
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Obtener SOLO los consejos asignados a este paciente (personalizados, sin visible_para_todos)
      String url =
          'api/consejo_pacientes.php?personalizados_paciente=1&paciente=$_userCode&limit=$_pageSize&offset=$offset&include_images=0';

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final parsed = _parseConsejosResponse(response.body);
        if (mounted) {
          setState(() {
            _consejosPersonalizados =
                reset ? parsed : [..._consejosPersonalizados, ...parsed];
            _hasMorePersonalizados = parsed.length >= _pageSize;
          });
        }
      } else {
        _showGenericLoadError();
      }
    } catch (_) {
      _showGenericLoadError();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPersonalizados = false;
          _isLoadingMorePersonalizados = false;
        });
      }
    }
  }

  Future<void> _loadConsejosFavoritos({bool reset = false}) async {
    // No cargar favoritos en modo guest
    if (_isGuestMode) {
      if (mounted) {
        setState(() {
          _isLoadingFavoritos = false;
          _hasMoreFavoritos = false;
        });
      }
      return;
    }

    // Usar userCode (siempre existe para usuarios registrados)
    if (_userCode == null) {
      if (mounted) {
        setState(() {
          _isLoadingFavoritos = false;
          _hasMoreFavoritos = false;
        });
      }
      return;
    }

    if (!reset &&
        (_isLoadingFavoritos ||
            _isLoadingMoreFavoritos ||
            !_hasMoreFavoritos)) {
      return;
    }

    final offset = reset ? 0 : _consejosFavoritos.length;

    setState(() {
      if (reset) {
        _isLoadingFavoritos = true;
        _hasMoreFavoritos = true;
      } else {
        _isLoadingMoreFavoritos = true;
      }
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/consejo_usuarios.php?favoritos=1&usuario=$_userCode&limit=$_pageSize&offset=$offset&include_images=0',
      );

      if (response.statusCode == 200) {
        final parsed = _parseConsejosResponse(response.body);
        if (mounted) {
          setState(() {
            _consejosFavoritos =
                reset ? parsed : [..._consejosFavoritos, ...parsed];
            _hasMoreFavoritos = parsed.length >= _pageSize;
          });
        }
      } else {
        _showGenericLoadError();
      }
    } catch (_) {
      _showGenericLoadError();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFavoritos = false;
          _isLoadingMoreFavoritos = false;
        });
      }
    }
  }

  Future<void> _toggleLike(Consejo consejo) async {
    final l10n = AppLocalizations.of(context)!;
    // debugPrint('_toggleLike called for consejo: ${consejo.codigo}');

    if (_isGuestMode) {
      // debugPrint('Guest mode - cannot like');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonSignInToLike),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Usar userCode (siempre existe para usuarios registrados)
    if (_userCode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonCouldNotIdentifyUser),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_consejo': consejo.codigo,
        'codigo_usuario': int.parse(_userCode!),
      };

      // debugPrint('Sending toggle_like request: $data');
      final response = await apiService.post(
        'api/consejo_usuarios.php?toggle_like=1',
        body: json.encode(data),
      );
      // debugPrint(
      //   'toggle_like response: ${response.statusCode} - ${response.body}',
      // );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final previousMeGusta = consejo.meGusta ?? 'N';
        final newMeGusta =
            responseData['me_gusta'] ?? (previousMeGusta == 'S' ? 'N' : 'S');
        var totalLikes = consejo.totalLikes ?? 0;
        if (newMeGusta == 'S' && previousMeGusta != 'S') {
          totalLikes += 1;
        } else if (newMeGusta != 'S' && previousMeGusta == 'S') {
          if (totalLikes > 0) totalLikes -= 1;
        }

        consejo.meGusta = newMeGusta;
        consejo.totalLikes = totalLikes;
        _applyConsejoUpdate(consejo, syncFavoritos: false);
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          SnackBar(content: Text(l10n.commonLikeChangeError(errorMessage))));
    }
  }

  Future<void> _toggleFavorito(Consejo consejo) async {
    final l10n = AppLocalizations.of(context)!;
    // debugPrint('_toggleFavorito called for consejo: ${consejo.codigo}');

    if (_isGuestMode) {
      // debugPrint('Guest mode - cannot save favorites');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonSignInToSaveFavorites),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Usar userCode (siempre existe para usuarios registrados)
    if (_userCode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonCouldNotIdentifyUser),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_consejo': consejo.codigo,
        'codigo_usuario': int.parse(_userCode!),
      };

      // debugPrint('Sending toggle_favorito request: $data');
      final response = await apiService.post(
        'api/consejo_usuarios.php?toggle_favorito=1',
        body: json.encode(data),
      );
      // debugPrint(
      //   'toggle_favorito response: ${response.statusCode} - ${response.body}',
      // );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final newFavorito =
            responseData['favorito'] ?? (consejo.favorito == 'S' ? 'N' : 'S');
        consejo.favorito = newFavorito;
        _applyConsejoUpdate(consejo, syncFavoritos: true);
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
          content: Text(l10n.commonFavoriteChangeError(errorMessage))));
    }
  }

  void _viewConsejoDetail(
    Consejo consejo, {
    bool allowSocialActions = true,
    bool isPreviewMode = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConsejoDetailScreen(
          consejo: consejo,
          onFavoritoChanged: _onDetailConsejoUpdated,
          isPreviewMode: isPreviewMode,
          allowSocialActions: allowSocialActions,
        ),
      ),
    ).then((_) {
      // Reload after viewing detail
      _loadConsejos(reset: true);
      _loadConsejosPortada(reset: true);
      _loadConsejosPersonalizados(reset: true);
      _loadConsejosFavoritos(reset: true);
    });
  }

  Widget _buildConsejoCard(Consejo consejo,
      {String unreadBadgeText = 'NUEVO',
      bool allowSocialActions = true,
      bool showUnreadBadge = true,
      bool allowCopyAndPdf = true,
      bool isPreviewMode = false}) {
    final coverProvider = _getCachedCoverProvider(consejo);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _viewConsejoDetail(
          consejo,
          allowSocialActions: allowSocialActions,
          isPreviewMode: isPreviewMode,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConsejoCardHeader(
              consejo,
              coverProvider,
              showUnreadBadge: showUnreadBadge,
              unreadBadgeText: unreadBadgeText,
            ),

            // Acciones (like, favorito, copiar, pdf)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  if (allowSocialActions) ...[
                    IconButton(
                      icon: Icon(
                        consejo.meGusta == 'S'
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: consejo.meGusta == 'S' ? Colors.red : null,
                      ),
                      onPressed: () => _toggleLike(consejo),
                    ),
                    Text(
                      '${consejo.totalLikes ?? 0} me gusta',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        consejo.favorito == 'S'
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: consejo.favorito == 'S' ? Colors.amber : null,
                      ),
                      onPressed: () => _toggleFavorito(consejo),
                    ),
                  ],
                  const Spacer(),
                  if (allowCopyAndPdf) ...[
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => _copyConsejoToClipboard(consejo),
                      tooltip: 'Copiar',
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      onPressed: () => _generateConsejoPdfFromCard(consejo),
                      tooltip: 'PDF',
                    ),
                  ],
                  if (consejo.mostrarPortada == 'S')
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
                    consejo.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  HashtagText(
                    text: consejo.texto.length > 100
                        ? '${consejo.texto.substring(0, 100)}...'
                        : consejo.texto,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  if (consejo.texto.length > 100) const SizedBox(height: 4),
                  if (consejo.texto.length > 100)
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

  Widget _buildGuestFavoritosEmptyCard({required String tipo}) {
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
              l10n.commonGuestFavoritesRequiresRegistration(tipo),
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
              label: Text(l10n.navStartRegistration),
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
    final l10n = AppLocalizations.of(context)!;
    final listBottomPadding = 88.0 + MediaQuery.of(context).padding.bottom;
    final hasPatient = (_patientCode ?? '').isNotEmpty;
    final canAccessFullCatalog = _canAccessFullCatalog;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                l10n.navTips,
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
          if (canAccessFullCatalog && !_isSearchVisible)
            IconButton(
              tooltip: l10n.commonSearch,
              icon: const Icon(Icons.search),
              onPressed: _toggleSearchVisibility,
            ),
          if (canAccessFullCatalog)
            IconButton(
              tooltip: _selectedCategoriaIds.isEmpty
                  ? l10n.commonFilterByCategories
                  : l10n.commonFilterByCategoriesCount(
                      _selectedCategoriaIds.length,
                    ),
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
          if (canAccessFullCatalog)
            PopupMenuButton<String>(
              tooltip: l10n.commonMoreOptions,
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                _handleAppBarMenuAction(value);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'search',
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18),
                      const SizedBox(width: 10),
                      Text(l10n.commonSearch),
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
                    title: Text(l10n.commonFilter),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, size: 18),
                      const SizedBox(width: 10),
                      Text(l10n.commonRefresh),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                CheckedPopupMenuItem<String>(
                  value: 'sort_title',
                  checked: _sortMode == 'titulo',
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.commonSortByTitle)),
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
                      Expanded(child: Text(l10n.commonSortByRecent)),
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
                      Expanded(child: Text(l10n.commonSortByPopular)),
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
        bottom: canAccessFullCatalog
            ? PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: TabBar(
                    controller: _tabController,
                    tabs: [
                      if (hasPatient)
                        Tab(
                          icon: const Icon(Icons.person),
                          text: l10n.commonPersonalTab,
                        ),
                      Tab(
                        icon: const Icon(Icons.star),
                        text: l10n.commonFeaturedTab,
                      ),
                      Tab(
                        icon: const Icon(Icons.article),
                        text: l10n.commonAllTab,
                      ),
                      Tab(
                        icon: const Icon(Icons.bookmark),
                        text: l10n.commonFavoritesTab,
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _isPreviewMode
          ? _buildPreviewBody(listBottomPadding)
          : Column(
              children: [
                if (_isSearchVisible)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: l10n.tipsSearchLabel,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: l10n.commonHideSearch,
                          icon: const Icon(Icons.close),
                          onPressed: _toggleSearchVisibility,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                        _refreshCurrentTabFilteredTotal();
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
                          orElse: () => {
                            'nombre': l10n.commonCategoryFallback(id),
                          },
                        );
                        return Chip(
                          label: Text(match['nombre'].toString()),
                          onDeleted: () {
                            setState(() {
                              _selectedCategoriaIds.remove(id);
                            });
                            _savePreferences();
                            _refreshCurrentTabFilteredTotal();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      if (hasPatient)
                        Builder(
                          builder: (context) {
                            if (_isLoadingPersonalizados) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final items =
                                _applySearchAndSort(_consejosPersonalizados);
                            if (items.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      l10n.tipsNoPersonalizedRecommendations,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _tabController.animateTo(1),
                                      child: Text(l10n.tipsViewGeneralTips),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (_hasMorePersonalizados &&
                                    !_isLoadingMorePersonalizados &&
                                    notification.metrics.pixels >=
                                        notification.metrics.maxScrollExtent -
                                            300) {
                                  _loadConsejosPersonalizados();
                                }
                                return false;
                              },
                              child: ListView.builder(
                                padding:
                                    EdgeInsets.only(bottom: listBottomPadding),
                                itemCount: items.length +
                                    (_isLoadingMorePersonalizados ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= items.length) {
                                    return const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 20),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    );
                                  }
                                  return _buildConsejoCard(
                                    items[index],
                                    unreadBadgeText: l10n.tipsUnreadBadge,
                                    allowSocialActions: false,
                                    showUnreadBadge: true,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      Builder(
                        builder: (context) {
                          if (_isLoadingPortada) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final personalesCodigos = hasPatient
                              ? _consejosPersonalizados
                                  .map((c) => c.codigo)
                                  .whereType<int>()
                                  .toSet()
                              : <int>{};

                          final destacadosSinDuplicados = hasPatient
                              ? _consejosPortada
                                  .where((c) =>
                                      c.codigo == null ||
                                      !personalesCodigos.contains(c.codigo))
                                  .toList()
                              : _consejosPortada;

                          final items =
                              _applySearchAndSort(destacadosSinDuplicados);
                          if (items.isEmpty) {
                            return Center(
                              child: Text(l10n.tipsNoFeaturedAvailable),
                            );
                          }
                          return NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (_hasMorePortada &&
                                  !_isLoadingMorePortada &&
                                  notification.metrics.pixels >=
                                      notification.metrics.maxScrollExtent -
                                          300) {
                                _loadConsejosPortada();
                              }
                              return false;
                            },
                            child: ListView.builder(
                              padding:
                                  EdgeInsets.only(bottom: listBottomPadding),
                              itemCount: items.length +
                                  (_isLoadingMorePortada ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= items.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  );
                                }
                                return _buildConsejoCard(items[index]);
                              },
                            ),
                          );
                        },
                      ),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Builder(
                              builder: (context) {
                                final items = _applySearchAndSort(_consejos);
                                if (items.isEmpty) {
                                  return Center(
                                    child: Text(l10n.tipsNoTipsAvailable),
                                  );
                                }
                                return NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (_hasMoreConsejos &&
                                        !_isLoadingMore &&
                                        notification.metrics.pixels >=
                                            notification
                                                    .metrics.maxScrollExtent -
                                                300) {
                                      _loadConsejos();
                                    }
                                    return false;
                                  },
                                  child: ListView.builder(
                                    padding: EdgeInsets.only(
                                        bottom: listBottomPadding),
                                    itemCount:
                                        items.length + (_isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index >= items.length) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 20),
                                          child: Center(
                                              child:
                                                  CircularProgressIndicator()),
                                        );
                                      }
                                      final consejo = items[index];
                                      final isPersonalNoLeido =
                                          consejo.visibleParaTodos != 'S' &&
                                              consejo.leido == 'N';
                                      final isPersonalizado =
                                          consejo.visibleParaTodos != 'S';
                                      return _buildConsejoCard(
                                        consejo,
                                        unreadBadgeText: l10n.tipsUnreadBadge,
                                        showUnreadBadge: isPersonalNoLeido,
                                        allowSocialActions: !isPersonalizado,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                      Builder(
                        builder: (context) {
                          if (_isLoadingFavoritos) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final items = _applySearchAndSort(_consejosFavoritos);
                          final isWithoutCredentials =
                              _isGuestMode || (_userCode ?? '').isEmpty;
                          if (items.isEmpty) {
                            if (isWithoutCredentials) {
                              return _buildGuestFavoritosEmptyCard(
                                  tipo: 'consejos');
                            }
                            return Center(
                              child: Text(l10n.tipsNoFavoriteTips),
                            );
                          }
                          return NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (_hasMoreFavoritos &&
                                  !_isLoadingMoreFavoritos &&
                                  notification.metrics.pixels >=
                                      notification.metrics.maxScrollExtent -
                                          300) {
                                _loadConsejosFavoritos();
                              }
                              return false;
                            },
                            child: ListView.builder(
                              padding:
                                  EdgeInsets.only(bottom: listBottomPadding),
                              itemCount: items.length +
                                  (_isLoadingMoreFavoritos ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= items.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  );
                                }
                                return _buildConsejoCard(
                                  items[index],
                                  showUnreadBadge: false,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _copyConsejoToClipboard(Consejo consejo) async {
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!_canUseConsejosCopyPdf(authService)) {
      await _showPremiumRequiredForConsejosCopyPdf(context);
      return;
    }

    try {
      final firma = await _buildNutriFitClipboardSignature(context);
      final textToCopy = '${consejo.titulo}\n\n${consejo.texto}\n\n$firma';
      await Clipboard.setData(ClipboardData(text: textToCopy));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonCopiedToClipboard),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonCopyError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateConsejoPdfFromCard(Consejo consejo) async {
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!_canUseConsejosCopyPdf(authService)) {
      await _showPremiumRequiredForConsejosCopyPdf(context);
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Cargar documentos/imágenes inline para este consejo
      final imagenesInlineById = <int, String>{};
      try {
        final codigoCons = consejo.codigo;
        if (codigoCons != null) {
          final docsResponse = await apiService.get(
            'api/consejo_documentos.php?consejo=$codigoCons',
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
        titulo: consejo.titulo,
        contenido: consejo.texto,
        tipo: 'consejo',
        imagenPortadaBase64: consejo.imagenPortada,
        imagenesInlineById: imagenesInlineById,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonGeneratePdfError(e.toString())),
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

// Pantalla de detalle del consejo
class ConsejoDetailScreen extends StatefulWidget {
  final Consejo consejo;
  final Function(Consejo)? onFavoritoChanged;
  final bool isPreviewMode;
  final bool allowSocialActions;

  const ConsejoDetailScreen({
    super.key,
    required this.consejo,
    this.onFavoritoChanged,
    this.isPreviewMode = false,
    this.allowSocialActions = true,
  });

  @override
  State<ConsejoDetailScreen> createState() => _ConsejoDetailScreenState();
}

class _ConsejoDetailScreenState extends State<ConsejoDetailScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  AppLocalizations get l10n => AppLocalizations.of(context)!;

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

  List<ConsejoDocumento> _documentos = [];
  List<Consejo> _relacionados = [];
  bool _isLoading = true;
  bool _isLoadingRelacionados = true;
  int _maxRelacionados = 5;
  late Consejo _consejo;
  final ScrollController _documentosScrollController = ScrollController();
  final ScrollController _relacionadosScrollController = ScrollController();
  // final PageController _imagenesPageController = PageController(); // REMOVIDO: carrusel de imágenes adjuntas
  // int _currentImagenIndex = 0; // REMOVIDO: carrusel de imágenes adjuntas
  // bool _isDraggingImagenesCarousel = false; // REMOVIDO: carrusel de imágenes adjuntas

  @override
  void initState() {
    super.initState();
    _consejo = widget.consejo;
    _loadConsejoDetalleSiHaceFalta();
    _loadDocumentos();
    _loadRelacionados();
    if (!widget.isPreviewMode) {
      _marcarComoLeido();
    }
  }

  Future<void> _loadConsejoDetalleSiHaceFalta() async {
    final codigo = _consejo.codigo;
    if (codigo == null) {
      return;
    }
    if ((_consejo.imagenPortada ?? '').trim().isNotEmpty) {
      return;
    }

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.get('api/consejos.php?codigo=$codigo');
      if (response.statusCode != 200) {
        return;
      }
      final detalle = Consejo.fromJson(
        json.decode(response.body) as Map<String, dynamic>,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _consejo.imagenPortada =
            detalle.imagenPortada ?? _consejo.imagenPortada;
        _consejo.imagenMiniatura =
            detalle.imagenMiniatura ?? _consejo.imagenMiniatura;
        _consejo.imagenPortadaNombre =
            detalle.imagenPortadaNombre ?? _consejo.imagenPortadaNombre;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
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

  double _similarityScore(Consejo base, Consejo candidate) {
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

      if (!widget.allowSocialActions) {
        final userCode = authService.userCode;
        if (userCode == null || userCode.isEmpty) {
          if (mounted) {
            setState(() {
              _maxRelacionados = maxRelacionados;
              _relacionados = [];
            });
          }
          return;
        }

        final response = await apiService.get(
          'api/consejo_pacientes.php?personalizados_paciente=1&paciente=$userCode',
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final personalizados =
              data.map((item) => Consejo.fromJson(item)).where((item) {
            if (item.codigo == null || _consejo.codigo == null) {
              return false;
            }
            return item.codigo != _consejo.codigo;
          }).toList();

          if (mounted) {
            setState(() {
              _maxRelacionados = maxRelacionados;
              _relacionados = personalizados;
            });
          }
        }
        return;
      }

      final patientParam = authService.patientCode ?? '0';
      String url = 'api/consejos.php?paciente=$patientParam';
      if (authService.userCode != null && !authService.isGuestMode) {
        url += '&codigo_usuario=${authService.userCode}';
      }

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final allConsejos = data.map((item) => Consejo.fromJson(item)).toList();

        final candidatos = allConsejos.where((item) {
          if (item.codigo == null || _consejo.codigo == null) {
            return false;
          }
          return item.codigo != _consejo.codigo;
        }).toList();

        final scored = candidatos
            .map((item) => MapEntry(item, _similarityScore(_consejo, item)))
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
                  .cast<ConsejoDocumento?>()
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

  Widget _buildRelacionadoCard(Consejo item) {
    Widget header;
    if ((item.imagenPortada ?? '').trim().isNotEmpty) {
      try {
        header = ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Image.memory(
            base64Decode(item.imagenPortada!),
            height: 95,
            width: double.infinity,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {
        header = Container(
          height: 95,
          color: Colors.grey[200],
          child: const Icon(Icons.image, size: 28),
        );
      }
    } else {
      header = Container(
        height: 95,
        color: Colors.grey[200],
        child: const Icon(Icons.lightbulb_outline, size: 28),
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
                builder: (_) => ConsejoDetailScreen(
                  consejo: item,
                  onFavoritoChanged: widget.onFavoritoChanged,
                  allowSocialActions: widget.allowSocialActions,
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
        'codigo_consejo': _consejo.codigo,
        'codigo_usuario': int.parse(userCode),
        if (patientCode != null && patientCode.isNotEmpty)
          'codigo_paciente': int.parse(patientCode),
      };

      await apiService.post(
        'api/consejo_pacientes.php?marcar_leido=1',
        body: json.encode(data),
      );
    } catch (e) {
      // Ignorar errores al marcar como leído
    }
  }

  Future<void> _loadDocumentos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/consejo_documentos.php?consejo=${_consejo.codigo}',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _documentos =
              data.map((item) => ConsejoDocumento.fromJson(item)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final l10n = AppLocalizations.of(context)!;
    // debugPrint('Detail _toggleLike called for consejo: ${_consejo.codigo}');
    if (widget.isPreviewMode) {
      // debugPrint('Preview mode, skipping');
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final userCode = authService.userCode;

    if (authService.isGuestMode) {
      // debugPrint('Guest mode - cannot like');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonSignInToLike),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Usar userCode (siempre existe para usuarios registrados)
    if (userCode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonCouldNotIdentifyUser),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_consejo': _consejo.codigo,
        'codigo_usuario': int.parse(userCode),
      };

      // debugPrint('Sending detail toggle_like request: $data');
      final response = await apiService.post(
        'api/consejo_usuarios.php?toggle_like=1',
        body: json.encode(data),
      );
      // debugPrint(
      //   'Detail toggle_like response: ${response.statusCode} - ${response.body}',
      // );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _consejo.meGusta = responseData['me_gusta'];
          if (responseData['me_gusta'] == 'S') {
            _consejo.totalLikes = (_consejo.totalLikes ?? 0) + 1;
          } else {
            _consejo.totalLikes = (_consejo.totalLikes ?? 0) - 1;
          }
        });
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          SnackBar(content: Text(l10n.commonLikeChangeError(errorMessage))));
    }
  }

  String? _extractYouTubeVideoId(String url) {
    // Extraer el ID del video de YouTube de diferentes formatos de URL
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([\w-]+)',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  bool _isYouTubeUrl(String? url) {
    if (url == null) return false;
    return _extractYouTubeVideoId(url) != null;
  }

  Future<void> _launchUrl(String url) async {
    final l10n = AppLocalizations.of(context)!;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commonOpenLinkError(e.toString()))),
        );
      }
    }
  }

  Future<void> _openDocumento(ConsejoDocumento doc) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      // Si el documento no tiene contenido, cargarlo desde la API
      String? documentoBase64 = doc.documento;

      if (documentoBase64 == null || documentoBase64.isEmpty) {
        // Cargar el documento completo desde la API
        final apiService = Provider.of<ApiService>(context, listen: false);
        final response = await apiService.get(
          'api/consejo_documentos.php?codigo=${doc.codigo}',
        );

        // debugPrint('Response status: ${response.statusCode}');
        // debugPrint('Response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // debugPrint('Data type: ${data.runtimeType}');
          // debugPrint('Data: $data');

          if (data is Map && data['documento'] != null) {
            documentoBase64 = data['documento'];
            // debugPrint('Documento length from Map: ${documentoBase64?.length}');
          } else if (data is List && data.isNotEmpty) {
            documentoBase64 = data[0]['documento'];
            // debugPrint(
            //   'Documento length from List: ${documentoBase64?.length}',
            // );
          }
        } else {
          if (mounted) Navigator.of(context).pop();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    l10n.commonOpenDocumentError('${response.statusCode}')),
              ),
            );
          }
          return;
        }
      }

      // Verificar que ahora tengamos el documento
      if (documentoBase64 == null || documentoBase64.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.commonDocumentUnavailable)),
          );
        }
        return;
      }

      // Verificar que la cadena base64 tenga un tamaño mínimo razonable
      if (documentoBase64.length < 10) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.commonOpenDocumentError(
                  'Documento inválido (${documentoBase64.length})')),
            ),
          );
        }
        return;
      }

      // Decodificar el documento base64
      Uint8List bytes;
      try {
        bytes = base64Decode(documentoBase64);
      } catch (e) {
        // Si la decodificación falla, intentar sin padding
        String base64String = documentoBase64;
        // Agregar padding si es necesario
        while (base64String.length % 4 != 0) {
          base64String += '=';
        }
        try {
          bytes = base64Decode(base64String);
        } catch (e2) {
          if (mounted) Navigator.of(context).pop();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.commonDecodeError(e2.toString()))),
            );
          }
          return;
        }
      }

      // Obtener directorio temporal
      final dir = await getTemporaryDirectory();

      // Crear nombre de archivo con extensión
      String fileName = doc.nombre ?? 'documento';
      if (!fileName.contains('.')) {
        fileName = '$fileName.pdf'; // Asumir PDF por defecto
      }
      final filePath = '${dir.path}/$fileName';

      // Escribir archivo
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Verificar que el archivo fue creado correctamente
      if (!await file.exists()) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.commonSaveDocumentError)),
          );
        }
        return;
      }

      // Cerrar loading
      if (mounted) Navigator.of(context).pop();

      // Abrir archivo
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonOpenDocumentError(result.message)),
          ),
        );
      }
    } catch (e) {
      // Cerrar loading si está abierto
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commonOpenDocumentError(e.toString()))),
        );
      }
    }
  }

  Future<String?> _getImagenDocumentoBase64(ConsejoDocumento doc) async {
    final local = (doc.documento ?? '').trim();
    if (local.isNotEmpty) {
      return local;
    }

    if (doc.codigo == null) return null;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/consejo_documentos.php?codigo=${doc.codigo}',
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

  Future<void> _openImagenDocumento(ConsejoDocumento doc) async {
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
      orElse: () => ConsejoDocumento(
        codigo: imageId,
        codigoConsejo: _consejo.codigo ?? 0,
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
              label: Text(l10n.commonDownloadDocument),
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
    final texto = _consejo.texto;
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

  Future<void> _toggleFavorito() async {
    // debugPrint('Detail _toggleFavorito called for consejo: ${_consejo.codigo}');
    if (widget.isPreviewMode) {
      // debugPrint('Preview mode, skipping');
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final userCode = authService.userCode;

    if (authService.isGuestMode) {
      // debugPrint('Guest mode - cannot save favorites');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonSignInToSaveFavorites),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Usar userCode (siempre existe para usuarios registrados)
    if (userCode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonCouldNotIdentifyUser),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_consejo': _consejo.codigo,
        'codigo_usuario': int.parse(userCode),
      };

      // debugPrint('Sending detail toggle_favorito request: $data');
      final response = await apiService.post(
        'api/consejo_usuarios.php?toggle_favorito=1',
        body: json.encode(data),
      );
      // debugPrint(
      //   'Detail toggle_favorito response: ${response.statusCode} - ${response.body}',
      // );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _consejo.favorito = responseData['favorito'];
        });

        // Notificar al padre
        if (widget.onFavoritoChanged != null) {
          widget.onFavoritoChanged!(_consejo);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(l10n.commonFavoriteChangeError(errorMessage))),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!_canUseConsejosCopyPdf(authService)) {
      await _showPremiumRequiredForConsejosCopyPdf(context);
      return;
    }

    try {
      final cleanedBody = _consejo.texto
          .replaceAll(_contentTokenRegex, '')
          .replaceAll(RegExp(r'[ \t]+\n'), '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
      final firma = await _buildNutriFitClipboardSignature(context);
      final textToCopy = '${_consejo.titulo}\n\n$cleanedBody\n\n$firma';
      await Clipboard.setData(ClipboardData(text: textToCopy));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonCopiedToClipboard),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonCopyError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateConsejoPdf() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!_canUseConsejosCopyPdf(authService)) {
      await _showPremiumRequiredForConsejosCopyPdf(context);
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
        titulo: _consejo.titulo,
        contenido: _consejo.texto,
        tipo: 'consejo',
        imagenPortadaBase64: _consejo.imagenPortada,
        imagenesInlineById: imagenesInlineById,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonGeneratePdfError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final documentosYEnlaces =
        _documentos.where((doc) => doc.tipo != 'imagen').toList();
    final coverBase64 = ((_consejo.imagenPortada ?? '').trim().isNotEmpty)
        ? _consejo.imagenPortada!
        : (_consejo.imagenMiniatura ?? '').trim();
    final hasPortada = coverBase64.isNotEmpty;
    final isPersonalizadoDetalle = !widget.allowSocialActions;
    final usePinkDetailCards = isPersonalizadoDetalle && !hasPortada;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.tipsDetailTitle),
        actions: [
          if (!widget.isPreviewMode && widget.allowSocialActions) ...[
            IconButton(
              icon: Icon(
                _consejo.favorito == 'S'
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: _consejo.favorito == 'S' ? Colors.amber : null,
              ),
              onPressed: _toggleFavorito,
            ),
            IconButton(
              icon: Icon(
                _consejo.meGusta == 'S'
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: _consejo.meGusta == 'S' ? Colors.red : null,
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
            // Banner de modo preview
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
                        l10n.tipsPreviewBanner,
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Imagen de portada
            if (hasPortada)
              GestureDetector(
                onTap: () => showImageViewerDialog(
                  context: context,
                  base64Image: coverBase64,
                  title: _consejo.titulo,
                ),
                child: Image.memory(
                  base64Decode(coverBase64),
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                16.0,
                16.0,
                16.0,
                72.0 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.allowSocialActions)
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _consejo.meGusta == 'S'
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _consejo.meGusta == 'S' ? Colors.red : null,
                            size: 20,
                          ),
                          onPressed: _toggleLike,
                        ),
                        Text(
                          l10n.commonLikesCount(_consejo.totalLikes ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: _copyToClipboard,
                          tooltip: l10n.commonCopy,
                        ),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, size: 20),
                          onPressed: _generateConsejoPdf,
                          tooltip: l10n.commonGeneratePdf,
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: _copyToClipboard,
                          tooltip: l10n.commonCopy,
                        ),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, size: 20),
                          onPressed: _generateConsejoPdf,
                          tooltip: l10n.commonGeneratePdf,
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Título
                  if (usePinkDetailCards)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.pink[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _consejo.titulo,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    )
                  else
                    Text(
                      _consejo.titulo,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  const SizedBox(height: 16),

                  // Texto completo
                  if (usePinkDetailCards)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.pink[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _buildDetalleTextoConImagenes(),
                    )
                  else
                    _buildDetalleTextoConImagenes(),
                  const SizedBox(height: 24),

                  // Documentos y URLs - Carrusel horizontal
                  if (documentosYEnlaces.isNotEmpty) ...[
                    Text(
                      l10n.commonDocumentsAndLinks,
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
                        height: 160,
                        child: ListView.builder(
                          controller: _documentosScrollController,
                          scrollDirection: Axis.horizontal,
                          itemCount: documentosYEnlaces.length,
                          itemBuilder: (context, index) {
                            final doc = documentosYEnlaces[index];
                            return Container(
                              width: 180,
                              margin: const EdgeInsets.only(right: 12),
                              child: Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    if (doc.tipo == 'url' && doc.url != null) {
                                      _launchUrl(doc.url!);
                                    } else if (doc.tipo == 'documento') {
                                      _openDocumento(doc);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          doc.tipo == 'documento'
                                              ? Icons.insert_drive_file
                                              : _isYouTubeUrl(doc.url)
                                                  ? Icons.play_circle
                                                  : Icons.link,
                                          size: 40,
                                          color: doc.tipo == 'documento'
                                              ? Colors.blue
                                              : _isYouTubeUrl(doc.url)
                                                  ? Colors.red
                                                  : Colors.purple,
                                        ),
                                        const SizedBox(height: 6),
                                        Flexible(
                                          child: Text(
                                            doc.nombre ?? l10n.commonDocument,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (doc.tipo == 'url' &&
                                            doc.url != null) ...[
                                          const SizedBox(height: 3),
                                          Flexible(
                                            child: Text(
                                              doc.url!,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
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
                        Text(
                          l10n.commonYouMayAlsoLike,
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

// Pantalla para mostrar consejos filtrados por hashtag
class ConsejosHashtagScreen extends StatefulWidget {
  final String hashtag;

  const ConsejosHashtagScreen({super.key, required this.hashtag});

  @override
  State<ConsejosHashtagScreen> createState() => _ConsejosHashtagScreenState();
}

class _ConsejosHashtagScreenState extends State<ConsejosHashtagScreen> {
  List<Consejo> _consejos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConsejos();
  }

  Future<void> _loadConsejos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final patientCode = authService.patientCode;

      // Para guests, usar 0 para obtener solo consejos visible_para_todos
      final patientParam =
          (patientCode != null && patientCode.isNotEmpty) ? patientCode : '0';

      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/consejos.php?get_consejos_paciente=1&paciente=$patientParam',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final allConsejos = data.map((item) => Consejo.fromJson(item)).toList();

        // Filtrar consejos que contengan el hashtag
        setState(() {
          _consejos = allConsejos
              .where((consejo) => consejo.texto.contains(widget.hashtag))
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.tipsHashtagTitle(widget.hashtag)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _consejos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tag, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        l10n.tipsHashtagEmpty(widget.hashtag),
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadConsejos,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      88 + MediaQuery.of(context).padding.bottom,
                    ),
                    itemCount: _consejos.length,
                    itemBuilder: (context, index) {
                      final consejo = _consejos[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ConsejoDetailScreen(
                                  consejo: consejo,
                                  onFavoritoChanged: (updatedConsejo) {
                                    setState(() {
                                      final idx = _consejos.indexWhere(
                                        (c) =>
                                            c.codigo == updatedConsejo.codigo,
                                      );
                                      if (idx != -1) {
                                        _consejos[idx] = updatedConsejo;
                                      }
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (consejo.imagenPortada != null)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: Image.memory(
                                    base64Decode(consejo.imagenPortada!),
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      consejo.titulo,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    HashtagText(
                                      text: consejo.texto.length > 150
                                          ? '${consejo.texto.substring(0, 150)}...'
                                          : consejo.texto,
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
                                        Text('${consejo.totalLikes ?? 0}'),
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
                ),
    );
  }
}

// Widget para texto con hashtags clickeables
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
                  builder: (context) => ConsejosHashtagScreen(hashtag: hashtag),
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

// Widget para reproducir videos de YouTube incrustados
