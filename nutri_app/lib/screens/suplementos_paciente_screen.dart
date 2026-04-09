import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/suplemento.dart';
import '../screens/suplemento_detail_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/consejo_receta_pdf_service.dart';
import '../widgets/premium_feature_dialog_helper.dart';
import '../widgets/premium_upsell_card.dart';

enum _OrdenSuplementosPremium { nombre, fecha }

bool _canAccessSuplementosCatalog(AuthService authService) {
  return authService.isPremium ||
      authService.userType == 'Nutricionista' ||
      authService.userType == 'Administrador';
}

Future<void> _showPremiumRequiredForSuplementosCopyPdf(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return PremiumFeatureDialogHelper.show(
    context,
    message: l10n.supplementsPremiumCopyPdfMessage,
  );
}

Future<void> _showPremiumRequiredForSuplementosExplore(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return PremiumFeatureDialogHelper.show(
    context,
    message: l10n.supplementsPremiumExploreMessage,
  );
}

Future<void> _showPremiumRequiredForSuplementosTools(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return PremiumFeatureDialogHelper.show(
    context,
    message: l10n.supplementsPremiumToolsMessage,
  );
}

class SuplementosPacienteScreen extends StatefulWidget {
  const SuplementosPacienteScreen({super.key});

  @override
  State<SuplementosPacienteScreen> createState() =>
      _SuplementosPacienteScreenState();
}

class _SuplementosPacienteScreenState extends State<SuplementosPacienteScreen> {
  static const String _paramNonPremiumPreviewCodes =
      'codigos_suplementos_no_premium';
  static const String _prefsSearchVisible =
      'suplementos_paciente_search_visible';
  static const String _prefsSearchQuery = 'suplementos_paciente_search_query';
  static const String _prefsSearchScope = 'suplementos_paciente_search_scope';

  List<Suplemento> _suplementos = [];
  List<Suplemento> _filtered = [];
  bool _isLoading = true;
  bool _searchVisible = false;
  String _searchQuery = '';
  String _searchScope = 'ambos';
  String? _loadErrorMessage;
  List<int>? _nonPremiumPreviewCodes;
  _OrdenSuplementosPremium _orden = _OrdenSuplementosPremium.nombre;
  bool _ordenAscendente = true;

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
        _saveListState();
      }
    });
    _restoreListState().whenComplete(_loadSuplementos);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_suplementos);
    } else {
      final q = _searchQuery.toLowerCase();
      _filtered = _suplementos.where((s) {
        final matchTitle = s.titulo.toLowerCase().contains(q);
        final matchDescription =
            (s.descripcion ?? '').toLowerCase().contains(q);
        switch (_searchScope) {
          case 'titulo':
            return matchTitle;
          case 'descripcion':
            return matchDescription;
          case 'ambos':
          default:
            return matchTitle || matchDescription;
        }
      }).toList();
    }

    int compareNombre(Suplemento a, Suplemento b) =>
        a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());

    switch (_orden) {
      case _OrdenSuplementosPremium.nombre:
        _filtered.sort((a, b) =>
            _ordenAscendente ? compareNombre(a, b) : compareNombre(b, a));
        break;
      case _OrdenSuplementosPremium.fecha:
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
    }
  }

  void _toggleSearchVisibility() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchCtrl.clear();
        _searchQuery = '';
        _applyFilter();
      }
    });
    _saveListState();
  }

  void _applySortSelection(_OrdenSuplementosPremium orden) {
    setState(() {
      if (_orden == orden) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _orden = orden;
        _ordenAscendente = orden == _OrdenSuplementosPremium.nombre;
      }
      _applyFilter();
    });
    _saveListState();
  }

  Future<void> _saveListState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsSearchVisible, _searchVisible);
      await prefs.setString(_prefsSearchQuery, _searchQuery);
      await prefs.setString(_prefsSearchScope, _searchScope);
    } catch (_) {
      // Ignore persistence errors to avoid breaking UI flow.
    }
  }

  Future<void> _restoreListState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _searchVisible = prefs.getBool(_prefsSearchVisible) ?? false;
        _searchQuery = prefs.getString(_prefsSearchQuery) ?? '';
        final restoredScope = prefs.getString(_prefsSearchScope) ?? 'ambos';
        _searchScope =
            {'titulo', 'descripcion', 'ambos'}.contains(restoredScope)
                ? restoredScope
                : 'ambos';
        _searchCtrl.text = _searchQuery;
      });
    } catch (_) {
      // Ignore persistence errors and keep defaults.
    }
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
      return 'El catálogo de suplementos no está disponible temporalmente. Inténtalo más tarde.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection')) {
      return 'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';
    }
    return fallback;
  }

  Future<void> _loadSuplementos() async {
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
      final response = await apiService.get('api/suplementos.php?activos=1');
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final previewCodes = await previewCodesFuture;
        if (!mounted) return;
        setState(() {
          _suplementos = data
              .map((e) =>
                  Suplemento.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _nonPremiumPreviewCodes = previewCodes;
          _applyFilter();
          _loadErrorMessage = null;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suplementos = [];
          _filtered = [];
          _nonPremiumPreviewCodes = null;
          _loadErrorMessage = _friendlyApiError(
            e,
            fallback: 'No se pudieron cargar los suplementos.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportItemPdf(Suplemento s) async {
    try {
      final apiService = context.read<ApiService>();
      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: s.titulo,
        contenido: s.descripcion ?? '',
        tipo: 'suplemento',
        fileName: 'suplemento_${s.titulo.replaceAll(' ', '_').toLowerCase()}',
        preserveEmojis: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e')),
      );
    }
  }

  Future<void> _openDetail(Suplemento s) async {
    final authService = context.read<AuthService>();
    final canAccessFullCatalog = _canAccessSuplementosCatalog(authService);

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SuplementoDetailScreen(
          suplemento: s,
          onExportPdf: canAccessFullCatalog
              ? _exportItemPdf
              : (_) => _showPremiumRequiredForSuplementosCopyPdf(context),
          allSuplementos: _suplementos,
          showPremiumRecommendations: true,
          allowCopyAndPdf: canAccessFullCatalog,
          allowDiscoveryNavigation: canAccessFullCatalog,
          onRequestPremiumAccess: (message) =>
              PremiumFeatureDialogHelper.show(context, message: message),
          onNavigateToSuplemento: canAccessFullCatalog
              ? (target) => _openDetail(target)
              : (target) => _showPremiumRequiredForSuplementosExplore(context),
          onHashtagTap: (hashtag) {
            if (!canAccessFullCatalog) {
              _showPremiumRequiredForSuplementosExplore(context);
              return;
            }
            setState(() {
              _searchVisible = true;
            });
            _searchCtrl.text = hashtag;
            _searchCtrl.selection =
                TextSelection.collapsed(offset: _searchCtrl.text.length);
            _applySearch(hashtag);
            _saveListState();
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
    _saveListState();
  }

  void _applySearchScope(String scope) {
    setState(() {
      _searchScope = scope;
      _applyFilter();
    });
    _saveListState();
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

  List<Suplemento> _buildPreviewSuplementos() {
    final configuredCodes = _nonPremiumPreviewCodes;
    if (configuredCodes != null && configuredCodes.isNotEmpty) {
      final byCode = <int, Suplemento>{
        for (final item in _suplementos)
          if (item.codigo != null) item.codigo!: item,
      };
      final configuredItems = configuredCodes
          .map((code) => byCode[code])
          .whereType<Suplemento>()
          .toList(growable: false);
      if (configuredItems.isNotEmpty) {
        return configuredItems;
      }
    }

    final preview = List<Suplemento>.from(_suplementos);
    preview.sort((a, b) {
      final dateA = a.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byDate = dateB.compareTo(dateA);
      if (byDate != 0) return byDate;
      return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
    });
    return preview.take(3).toList(growable: false);
  }

  String _catalogHighlightCount(int total) {
    if (total <= 0) return '0';
    if (total < 10) return '$total';
    return '${total - (total % 10)}';
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final canAccessFullCatalog = _canAccessSuplementosCatalog(authService);
    final visibleItems =
        canAccessFullCatalog ? _filtered : _buildPreviewSuplementos();
    final totalSuplementos = _suplementos.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Suplementos'),
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
                '$totalSuplementos',
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
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
            tooltip: _searchVisible ? 'Ocultar búsqueda' : 'Buscar',
            onPressed: canAccessFullCatalog
                ? _toggleSearchVisibility
                : () => _showPremiumRequiredForSuplementosTools(context),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (value) {
              if (!canAccessFullCatalog) {
                _showPremiumRequiredForSuplementosTools(context);
                return;
              }

              switch (value) {
                case 'buscar':
                  _toggleSearchVisibility();
                  break;
                case 'actualizar':
                  _loadSuplementos();
                  break;
                case 'sort_nombre':
                  _applySortSelection(_OrdenSuplementosPremium.nombre);
                  break;
                case 'sort_fecha':
                  _applySortSelection(_OrdenSuplementosPremium.fecha);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'buscar',
                child: ListTile(
                  leading: Icon(
                    _searchVisible ? Icons.search_off : Icons.search,
                  ),
                  title: Text(_searchVisible ? 'Ocultar buscar' : 'Buscar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'actualizar',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Actualizar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem<String>(
                value: 'sort_nombre',
                checked: _orden == _OrdenSuplementosPremium.nombre,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Nombre')),
                    if (_orden == _OrdenSuplementosPremium.nombre)
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
                checked: _orden == _OrdenSuplementosPremium.fecha,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Recientes')),
                    if (_orden == _OrdenSuplementosPremium.fecha)
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
                          onPressed: _loadSuplementos,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
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
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              onChanged: _applySearch,
                              decoration: InputDecoration(
                                hintText: 'Buscar suplementos…',
                                prefixIcon: IconButton(
                                  tooltip: _searchQuery.isEmpty
                                      ? 'Buscar'
                                      : 'Limpiar búsqueda',
                                  icon: Icon(
                                    _searchQuery.isEmpty
                                        ? Icons.search
                                        : Icons.clear,
                                  ),
                                  onPressed: _searchQuery.isEmpty
                                      ? null
                                      : () {
                                          _searchCtrl.clear();
                                          _applySearch('');
                                        },
                                ),
                                suffixIcon: IconButton(
                                  tooltip: 'Ocultar búsqueda',
                                  icon:
                                      const Icon(Icons.visibility_off_outlined),
                                  onPressed: _toggleSearchVisibility,
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('Título'),
                                    selected: _searchScope == 'titulo',
                                    onSelected: (value) {
                                      if (value) _applySearchScope('titulo');
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('Descripción'),
                                    selected: _searchScope == 'descripcion',
                                    onSelected: (value) {
                                      if (value) {
                                        _applySearchScope('descripcion');
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('Ambos'),
                                    selected: _searchScope == 'ambos',
                                    onSelected: (value) {
                                      if (value) _applySearchScope('ambos');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: visibleItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.medication_outlined,
                                      size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    canAccessFullCatalog &&
                                            _searchQuery.isNotEmpty
                                        ? 'Sin resultados para "$_searchQuery"'
                                        : _searchQuery.isEmpty
                                            ? 'No hay suplementos disponibles'
                                            : 'No hay suplementos disponibles',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 15),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadSuplementos,
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
                                        title: AppLocalizations.of(context)!
                                            .supplementsPremiumTitle,
                                        subtitle: AppLocalizations.of(context)!
                                            .supplementsPremiumSubtitle,
                                        subtitleHighlight: AppLocalizations.of(
                                                context)!
                                            .supplementsPremiumPreviewHighlight(
                                          _catalogHighlightCount(
                                            _suplementos.length,
                                          ),
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
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundColor: Colors.teal
                                                  .withValues(alpha: 0.12),
                                              child: const Icon(
                                                  Icons.medication_outlined,
                                                  color: Colors.teal,
                                                  size: 22),
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
                                                        fontSize: 15),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
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
                                                          height: 1.4),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.chevron_right,
                                                color: Colors.grey),
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
