import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/suplemento.dart';
import '../screens/suplemento_detail_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/consejo_receta_pdf_service.dart';

enum _OrdenSuplementosPremium { nombre, fecha }

class SuplementosPacienteScreen extends StatefulWidget {
  const SuplementosPacienteScreen({super.key});

  @override
  State<SuplementosPacienteScreen> createState() =>
      _SuplementosPacienteScreenState();
}

class _SuplementosPacienteScreenState extends State<SuplementosPacienteScreen> {
  static const String _prefsSearchVisible =
      'suplementos_paciente_search_visible';
  static const String _prefsSearchQuery = 'suplementos_paciente_search_query';

  List<Suplemento> _suplementos = [];
  List<Suplemento> _filtered = [];
  bool _isLoading = true;
  bool _searchVisible = false;
  String _searchQuery = '';
  String? _loadErrorMessage;
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
      _filtered = _suplementos
          .where((s) =>
              s.titulo.toLowerCase().contains(q) ||
              (s.descripcion ?? '').toLowerCase().contains(q))
          .toList();
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
      final response =
          await context.read<ApiService>().get('api/suplementos.php?activos=1');
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _suplementos = data
              .map((e) =>
                  Suplemento.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
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
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SuplementoDetailScreen(
          suplemento: s,
          onExportPdf: _exportItemPdf,
          allSuplementos: _suplementos,
          showPremiumRecommendations: context.read<AuthService>().isPremium,
          onNavigateToSuplemento: (target) => _openDetail(target),
          onHashtagTap: (hashtag) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suplementos'),
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
            tooltip: _searchVisible ? 'Ocultar búsqueda' : 'Buscar',
            onPressed: _toggleSearchVisibility,
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (value) {
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
                    if (_searchVisible)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                        child: TextField(
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
                              icon: const Icon(Icons.visibility_off_outlined),
                              onPressed: _toggleSearchVisibility,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.medication_outlined,
                                      size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'No hay suplementos disponibles'
                                        : 'Sin resultados para "$_searchQuery"',
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
