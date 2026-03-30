import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../services/auth_service.dart';
import '../services/config_service.dart';
import '../services/api_service.dart';
import '../models/consejo.dart';
import 'consejos_paciente_screen.dart';
import '../utils/consejos_ai.dart';
import '../widgets/image_viewer_dialog.dart';
import '../services/thumbnail_generator.dart';
import '../widgets/paste_image_dialog.dart';

enum _ConsejosTopMenuAction {
  buscar,
  filtrar,
  categorias,
  copiarIa,
  actualizar,
  sortTitulo,
  sortRecientes,
  sortPopulares,
  sortCategorias,
  pegarConsejo,
  pegarIa,
}

enum _OrdenConsejosList { titulo, recientes, populares, categorias }

class ConsejosListScreen extends StatefulWidget {
  const ConsejosListScreen({super.key});

  @override
  State<ConsejosListScreen> createState() => _ConsejosListScreenState();
}

class _ConsejosListScreenState extends State<ConsejosListScreen> {
  List<Consejo> _consejos = [];
  List<Consejo> _displayedConsejos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  bool _filterActivas = true;
  bool _filterInactivas = true;
  bool _filterConPacientes = false;
  Set<int> _selectedCategoryIds = <int>{};
  _OrdenConsejosList _orden = _OrdenConsejosList.recientes;
  bool _ordenAscendente = false;
  bool _isSearchVisible = false;
  late ScrollController _scrollController;
  String _aiPrompt = defaultConsejosAIPrompt;
  List<Map<String, dynamic>> _categoriasCatalogo = <Map<String, dynamic>>[];

  static const int _pageSize = 15;
  int _currentPage = 1;
  bool _hasMoreItems = true;

  static const _prefSearchVisible = 'consejos_show_search';
  static const _prefFilterActivas = 'consejos_filter_activas';
  static const _prefFilterInactivas = 'consejos_filter_inactivas';
  static const _prefFilterConPacientes = 'consejos_filter_con_pacientes';
  static const _prefFilterCategoryIds = 'consejos_filter_category_ids';
  static const _prefSortField = 'consejos_sort_field';
  static const _prefSortAsc = 'consejos_sort_asc';

  int get _selectedCategoryCount => _selectedCategoryIds.length;

  int get _activeFilterCount {
    var total = 0;
    if (!_filterActivas) total += 1;
    if (!_filterInactivas) total += 1;
    if (_filterConPacientes) total += 1;
    total += _selectedCategoryIds.length;
    return total;
  }

  @override
  void initState() {
    super.initState();
    final apiService = Provider.of<ApiService>(context, listen: false);
    context
        .read<ConfigService>()
        .loadDeleteSwipePercentageFromDatabase(apiService);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadUiState();
    _loadAIPrompt();
    _loadConsejos();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMoreItems) {
        _loadMoreConsejos();
      }
    }
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final showSearch = prefs.getBool(_prefSearchVisible) ?? false;
    final filterActivas = prefs.getBool(_prefFilterActivas) ?? true;
    final filterInactivas = prefs.getBool(_prefFilterInactivas) ?? true;
    final filterPacientes = prefs.getBool(_prefFilterConPacientes) ?? false;
    final selectedCategoryIds =
        prefs.getStringList(_prefFilterCategoryIds) ?? const <String>[];
    final sortField = prefs.getString(_prefSortField) ?? 'recientes';
    final sortAsc = prefs.getBool(_prefSortAsc) ?? false;
    if (mounted) {
      setState(() {
        _isSearchVisible = showSearch;
        _filterActivas = filterActivas;
        _filterInactivas = filterInactivas;
        _filterConPacientes = filterPacientes;
        _selectedCategoryIds = selectedCategoryIds
            .map((value) => int.tryParse(value))
            .whereType<int>()
            .toSet();
        _orden = _orderFromPref(sortField);
        _ordenAscendente = sortAsc;
      });
    }
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSearchVisible, _isSearchVisible);
    await prefs.setBool(_prefFilterActivas, _filterActivas);
    await prefs.setBool(_prefFilterInactivas, _filterInactivas);
    await prefs.setBool(_prefFilterConPacientes, _filterConPacientes);
    await prefs.setStringList(
      _prefFilterCategoryIds,
      _selectedCategoryIds.map((id) => '$id').toList(growable: false),
    );
    await prefs.setString(_prefSortField, _orderToPref(_orden));
    await prefs.setBool(_prefSortAsc, _ordenAscendente);
  }

  _OrdenConsejosList _orderFromPref(String value) {
    switch (value) {
      case 'titulo':
        return _OrdenConsejosList.titulo;
      case 'populares':
        return _OrdenConsejosList.populares;
      case 'categorias':
        return _OrdenConsejosList.categorias;
      case 'recientes':
      default:
        return _OrdenConsejosList.recientes;
    }
  }

  String _orderToPref(_OrdenConsejosList value) {
    switch (value) {
      case _OrdenConsejosList.titulo:
        return 'titulo';
      case _OrdenConsejosList.populares:
        return 'populares';
      case _OrdenConsejosList.categorias:
        return 'categorias';
      case _OrdenConsejosList.recientes:
        return 'recientes';
    }
  }

  Future<void> _loadAIPrompt() async {
    try {
      final valor = await context
          .read<ApiService>()
          .getParametroValor('ia_prompt_consejos');
      if (valor != null && valor.isNotEmpty && mounted) {
        setState(() => _aiPrompt = repairCommonMojibake(valor));
      }
    } catch (_) {
      // Mantiene el prompt por defecto si no existe parámetro remoto.
    }
  }

  bool get _canManageConsejos {
    final userType =
        (context.read<AuthService>().userType ?? '').trim().toLowerCase();
    return userType == 'nutricionista' ||
        userType == 'nutritionist' ||
        userType == 'administrador' ||
        userType == 'admin';
  }

  String _normalizeCategoryName(String value) {
    return value.trim().toLowerCase();
  }

  Future<List<Map<String, dynamic>>> _fetchConsejoCategoriasCatalog() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final response = await apiService.get('api/consejos.php?categorias=1');
    if (response.statusCode != 200) {
      return const <Map<String, dynamic>>[];
    }

    final List<dynamic> data = json.decode(response.body);
    final categories = data
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
    _categoriasCatalogo = List<Map<String, dynamic>>.from(categories);
    return categories;
  }

  Map<int, int> _buildCategoriasUsageCount() {
    final counts = <int, int>{};
    for (final consejo in _consejos) {
      for (final categoriaId in consejo.categoriaIds) {
        counts[categoriaId] = (counts[categoriaId] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> _saveCategoriaConsejo({
    int? codigo,
    required String nombre,
  }) async {
    final endpoint = codigo == null
        ? 'api/consejos.php?categorias=1'
        : 'api/consejos.php?categorias=1&codigo=$codigo';
    final body = jsonEncode(<String, dynamic>{'nombre': nombre});
    final response = codigo == null
        ? await context.read<ApiService>().post(endpoint, body: body)
        : await context.read<ApiService>().put(endpoint, body: body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      String message = 'No se pudo guardar.';
      try {
        message =
            (jsonDecode(response.body)['message'] ?? 'No se pudo guardar.')
                .toString();
      } catch (_) {}
      throw Exception(message);
    }
  }

  Future<void> _deleteCategoriaConsejo(int codigo) async {
    final response = await context.read<ApiService>().delete(
          'api/consejos.php?categorias=1&codigo=$codigo',
        );
    if (response.statusCode != 200) {
      String message = 'No se pudo eliminar.';
      try {
        message =
            (jsonDecode(response.body)['message'] ?? 'No se pudo eliminar.')
                .toString();
      } catch (_) {}
      throw Exception(message);
    }
  }

  Future<void> _openCategoriaConsejoEditor({
    int? codigo,
    String? nombreActual,
  }) async {
    final nombreCtrl = TextEditingController(text: nombreActual ?? '');
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title:
                Text(codigo == null ? 'Nueva categoría' : 'Editar categoría'),
            content: TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) return;

    final normalized = _normalizeCategoryName(nombre);
    final duplicate = _categoriasCatalogo.any((item) {
      final existingName =
          _normalizeCategoryName((item['nombre'] ?? '').toString());
      final existingCode = int.tryParse((item['codigo'] ?? '').toString());
      return existingName == normalized && existingCode != codigo;
    });
    if (duplicate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya existe una categoría con ese nombre.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await _saveCategoriaConsejo(codigo: codigo, nombre: nombre);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            codigo == null ? 'Categoría creada.' : 'Categoría actualizada.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadCategoriasCatalogo();
      await _loadConsejos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDeleteCategoriaConsejo(int codigo, String nombre) async {
    final usageCount = _buildCategoriasUsageCount()[codigo] ?? 0;
    if (usageCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: Text(
            'No se puede eliminar "$nombre" porque hay consejos con esa categoría.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar categoría'),
            content: Text('¿Eliminar "$nombre"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await _deleteCategoriaConsejo(codigo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categoría eliminada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadCategoriasCatalogo();
      await _loadConsejos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openCategoriaConsejoRowMenu({
    required int codigo,
    required String nombre,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'edit') {
      await _openCategoriaConsejoEditor(codigo: codigo, nombreActual: nombre);
    } else if (action == 'delete') {
      await _confirmDeleteCategoriaConsejo(codigo, nombre);
    }
  }

  Future<void> _openCategoriasConsejosDialog() async {
    bool showSearch = true;
    String search = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Categorías',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await _openCategoriaConsejoEditor();
                    setLocal(() {});
                  },
                  icon: const Icon(Icons.add),
                  tooltip: 'Nueva categoría',
                ),
                IconButton(
                  onPressed: () => setLocal(() => showSearch = !showSearch),
                  icon: Icon(showSearch ? Icons.search_off : Icons.search),
                  tooltip: showSearch ? 'Ocultar buscar' : 'Mostrar buscar',
                ),
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              height: 480,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchConsejoCategoriasCatalog(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        snapshot.error
                            .toString()
                            .replaceFirst('Exception: ', ''),
                      ),
                    );
                  }

                  final categories = snapshot.data ?? <Map<String, dynamic>>[];
                  final usage = _buildCategoriasUsageCount();
                  final q = search.trim().toLowerCase();
                  final filtered = categories.where((category) {
                    final nombre = (category['nombre'] ?? '').toString();
                    return q.isEmpty || nombre.toLowerCase().contains(q);
                  }).toList(growable: false);

                  return Column(
                    children: [
                      if (showSearch)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Buscar categoría',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (value) {
                              setLocal(() => search = value.trim());
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('No hay categorías.'))
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final codigo = int.tryParse(
                                    (item['codigo'] ?? '').toString(),
                                  );
                                  final nombre =
                                      (item['nombre'] ?? '').toString();
                                  final count =
                                      codigo == null ? 0 : (usage[codigo] ?? 0);

                                  if (codigo == null) {
                                    return const SizedBox.shrink();
                                  }

                                  return Dismissible(
                                    key: ValueKey(
                                      'cat_consejo_${codigo}_$index',
                                    ),
                                    direction: DismissDirection.startToEnd,
                                    dismissThresholds: {
                                      DismissDirection.startToEnd: context
                                          .watch<ConfigService>()
                                          .deleteSwipeDismissThreshold,
                                    },
                                    background: Container(
                                      color: Colors.red.shade600,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Eliminar',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    confirmDismiss: (_) async {
                                      await _confirmDeleteCategoriaConsejo(
                                        codigo,
                                        nombre,
                                      );
                                      setLocal(() {});
                                      return false;
                                    },
                                    child: SizedBox(
                                      height: 42,
                                      child: InkWell(
                                        onTap: () async {
                                          await _openCategoriaConsejoEditor(
                                            codigo: codigo,
                                            nombreActual: nombre,
                                          );
                                          setLocal(() {});
                                        },
                                        onLongPress: () async {
                                          await _openCategoriaConsejoRowMenu(
                                            codigo: codigo,
                                            nombre: nombre,
                                          );
                                          setLocal(() {});
                                        },
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                ),
                                                child: Text(
                                                  nombre,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 18,
                                              height: 18,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: count > 0
                                                    ? Colors.green
                                                    : Colors.grey,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '$count',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.more_vert,
                                                size: 18,
                                              ),
                                              tooltip: 'Más opciones',
                                              onPressed: () async {
                                                await _openCategoriaConsejoRowMenu(
                                                  codigo: codigo,
                                                  nombre: nombre,
                                                );
                                                setLocal(() {});
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _toggleSearchVisibility() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible && _searchQuery.isNotEmpty) {
        _searchQuery = '';
        _displayedConsejos = [];
        _currentPage = 1;
        _hasMoreItems = true;
      }
    });
    _saveUiState();
    if (_searchQuery.isEmpty) {
      _loadMoreConsejos();
    }
  }

  Future<void> _applySortSelection(_OrdenConsejosList nextOrder) async {
    setState(() {
      if (_orden == nextOrder) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _orden = nextOrder;
        _ordenAscendente = false;
      }
      _displayedConsejos = [];
      _currentPage = 1;
      _hasMoreItems = true;
    });
    await _saveUiState();
    _loadMoreConsejos();
  }

  Future<void> _showConsejosFilterDialog() async {
    await _loadCategoriasCatalogo();
    var tempActivas = _filterActivas;
    var tempInactivas = _filterInactivas;
    var tempConPacientes = _filterConPacientes;
    final tempSelected = Set<int>.from(_selectedCategoryIds);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final sortedCategorias =
              List<Map<String, dynamic>>.from(_categoriasCatalogo)
                ..sort((a, b) => (a['nombre'] ?? '')
                    .toString()
                    .toLowerCase()
                    .compareTo((b['nombre'] ?? '').toString().toLowerCase()));

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtrar Consejos',
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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Activos'),
                          selected: tempActivas,
                          onSelected: (v) =>
                              setDialogState(() => tempActivas = v),
                        ),
                        FilterChip(
                          label: const Text('Inactivos'),
                          selected: tempInactivas,
                          onSelected: (v) =>
                              setDialogState(() => tempInactivas = v),
                        ),
                        FilterChip(
                          label: const Text('Pacientes'),
                          selected: tempConPacientes,
                          onSelected: (v) =>
                              setDialogState(() => tempConPacientes = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (sortedCategorias.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sortedCategorias.map((cat) {
                          final id =
                              int.tryParse((cat['codigo'] ?? '').toString());
                          if (id == null) return const SizedBox.shrink();
                          final name = (cat['nombre'] ?? '').toString();
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
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  setState(() {
                    _filterActivas = true;
                    _filterInactivas = true;
                    _filterConPacientes = false;
                    _selectedCategoryIds = <int>{};
                    _displayedConsejos = [];
                    _currentPage = 1;
                    _hasMoreItems = true;
                  });
                  await _saveUiState();
                  _loadMoreConsejos();
                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                },
                child: const Text('Limpiar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!tempActivas && !tempInactivas) {
                    setDialogState(() {
                      tempActivas = true;
                      tempInactivas = true;
                    });
                  }
                  setState(() {
                    _filterActivas = tempActivas;
                    _filterInactivas = tempInactivas;
                    _filterConPacientes = tempConPacientes;
                    _selectedCategoryIds = tempSelected;
                    _displayedConsejos = [];
                    _currentPage = 1;
                    _hasMoreItems = true;
                  });
                  await _saveUiState();
                  _loadMoreConsejos();
                  if (!mounted) return;
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
                            tempSelected.isNotEmpty ? Colors.blue : Colors.grey,
                        shape: BoxShape.circle,
                      ),
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConsejos() async {
    setState(() {
      _isLoading = true;
      _displayedConsejos = [];
      _currentPage = 1;
      _hasMoreItems = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/consejos.php');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _consejos = data.map((item) {
            try {
              return Consejo.fromJson(item);
            } catch (e) {
              //debugPrint('Error al parsear consejo: $e');
              //debugPrint('Item: $item');
              rethrow;
            }
          }).toList();
        });
        _loadMoreConsejos();
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar consejos. $errorMessage'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _loadMoreConsejos() {
    if (_isLoadingMore || !_hasMoreItems) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Simular un pequeño delay para que el UX sea más claro
    Future.delayed(const Duration(milliseconds: 300), () {
      final filteredAll = _getFilteredConsejos(_consejos);
      final startIndex = (_currentPage - 1) * _pageSize;
      final endIndex = startIndex + _pageSize;

      if (startIndex < filteredAll.length) {
        final newItems = filteredAll.sublist(
          startIndex,
          endIndex > filteredAll.length ? filteredAll.length : endIndex,
        );

        setState(() {
          _displayedConsejos.addAll(newItems);
          _currentPage++;
          _hasMoreItems = endIndex < filteredAll.length;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _hasMoreItems = false;
        });
      }
    });
  }

  List<Consejo> _getFilteredConsejos(List<Consejo> items) {
    final filtered = items.where((consejo) {
      // Filtro por búsqueda (incluye título, texto y nombres de pacientes)
      final matchesSearch = _searchQuery.isEmpty ||
          consejo.titulo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          consejo.texto.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          consejo.pacientesNombres.any((nombre) =>
              nombre.toLowerCase().contains(_searchQuery.toLowerCase()));

      final isActive = consejo.activo == 'S';
      final matchesActivo =
          (isActive && _filterActivas) || (!isActive && _filterInactivas);

      // Filtro por pacientes
      final matchesConPacientes = !_filterConPacientes ||
          (consejo.totalPacientes != null && consejo.totalPacientes! > 0);

      final matchesCategorias = _selectedCategoryIds.isEmpty ||
          _selectedCategoryIds.any((id) => consejo.categoriaIds.contains(id));

      return matchesSearch &&
          matchesActivo &&
          matchesConPacientes &&
          matchesCategorias;
    }).toList(growable: false);

    filtered.sort((a, b) {
      late int result;
      switch (_orden) {
        case _OrdenConsejosList.titulo:
          result = a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
          break;
        case _OrdenConsejosList.recientes:
          final da = a.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
          result = da.compareTo(db);
          break;
        case _OrdenConsejosList.populares:
          result = (a.totalPacientes ?? 0).compareTo(b.totalPacientes ?? 0);
          break;
        case _OrdenConsejosList.categorias:
          final ca = a.categoriaNombres.isNotEmpty
              ? a.categoriaNombres.first.toLowerCase()
              : '';
          final cb = b.categoriaNombres.isNotEmpty
              ? b.categoriaNombres.first.toLowerCase()
              : '';
          result = ca.compareTo(cb);
          break;
      }

      if (result == 0) {
        final ta = a.titulo.toLowerCase();
        final tb = b.titulo.toLowerCase();
        result = ta.compareTo(tb);
      }

      return _ordenAscendente ? result : -result;
    });

    return filtered;
  }

  Map<String, Consejo> _buildTitleToExisting() {
    final map = <String, Consejo>{};
    for (final item in _consejos) {
      final key = normalizeConsejoTitle(item.titulo);
      if (key.isNotEmpty) {
        map[key] = item;
      }
    }
    return map;
  }

  Consejo? _fuzzyFindExisting(
      String normalizedTitle, Map<String, Consejo> titleToExisting) {
    if (normalizedTitle.isEmpty) return null;
    final exact = titleToExisting[normalizedTitle];
    if (exact != null) return exact;

    for (final entry in titleToExisting.entries) {
      final key = entry.key;
      final shorter =
          normalizedTitle.length <= key.length ? normalizedTitle : key;
      final longer =
          normalizedTitle.length <= key.length ? key : normalizedTitle;
      if (!longer.startsWith(shorter)) continue;
      if (longer.length == shorter.length) return entry.value;
      final next = longer[shorter.length];
      if (next == ' ' || next == '(' || next == ',') return entry.value;
    }

    return null;
  }

  bool _shouldReplaceExistingByDescriptionLength({
    required Consejo existing,
    required ConsejoImportDraft draft,
  }) {
    final existingLen = existing.texto.trim().length;
    final draftLen = draft.descripcion.trim().length;
    return existingLen < draftLen;
  }

  ({int duplicatedInPaste, int alreadyExisting}) _estimateImportConflicts(
    List<ConsejoImportDraft> drafts,
  ) {
    final titleToExisting = _buildTitleToExisting();
    final seenTitles = <String>{};
    var duplicatedInPaste = 0;
    var alreadyExisting = 0;

    for (final draft in drafts) {
      final title = normalizeConsejoTitle(draft.titulo);
      if (title.isEmpty || !seenTitles.add(title)) {
        duplicatedInPaste += 1;
      } else if (_fuzzyFindExisting(title, titleToExisting) != null) {
        alreadyExisting += 1;
      }
    }

    return (
      duplicatedInPaste: duplicatedInPaste,
      alreadyExisting: alreadyExisting,
    );
  }

  Future<void> _loadCategoriasCatalogo() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final response = await apiService.get('api/consejos.php?categorias=1');
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar las categorías de consejos.');
    }

    final List<dynamic> data = json.decode(response.body);
    _categoriasCatalogo =
        data.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<Map<String, dynamic>?> _createCategoriaConsejo(String nombre) async {
    final trimmed = nombre.trim();
    if (trimmed.isEmpty) return null;

    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final payload = {
      'nombre': trimmed,
      'codusuarioa':
          authService.userCode != null ? int.parse(authService.userCode!) : 1,
    };

    final response = await apiService.post(
      'api/consejos.php?categorias=1',
      body: json.encode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }

    return null;
  }

  Map<String, dynamic>? _findCategoriaByName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final item in _categoriasCatalogo) {
      final nombre = (item['nombre'] ?? '').toString().trim().toLowerCase();
      if (nombre == normalized) {
        return item;
      }
    }
    return null;
  }

  Future<List<int>> _resolveCategoriaIdsForDraft(
    ConsejoImportDraft draft, {
    required Set<String> selectedNewCategoryNames,
    Set<int> selectedExistingCategoryIds = const <int>{},
  }) async {
    if (_categoriasCatalogo.isEmpty) {
      await _loadCategoriasCatalogo();
    }

    final resolvedIds = <int>[];
    for (final categoria in draft.categorias) {
      final trimmed = categoria.trim();
      if (trimmed.isEmpty) continue;

      Map<String, dynamic>? existing = _findCategoriaByName(trimmed);

      if (existing == null &&
          selectedNewCategoryNames.contains(trimmed.toLowerCase())) {
        existing = await _createCategoriaConsejo(trimmed);
      }
      if (existing != null) {
        final codigo = int.tryParse(existing['codigo'].toString());
        if (codigo != null) {
          resolvedIds.add(codigo);
          final alreadyLoaded = _categoriasCatalogo.any(
            (item) => int.tryParse(item['codigo'].toString()) == codigo,
          );
          if (!alreadyLoaded) {
            _categoriasCatalogo.add(existing);
          }
        }
      }
    }

    return <int>{
      ...resolvedIds,
      ...selectedExistingCategoryIds,
    }.toList(growable: false);
  }

  Future<void> _createConsejoFromDraft(ConsejoImportDraft draft) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final categoriaIds = await _resolveCategoriaIdsForDraft(
      draft,
      selectedNewCategoryNames: <String>{},
    );

    final payload = <String, dynamic>{
      'titulo': draft.titulo.trim(),
      'texto': draft.descripcion.trim(),
      'activo': 'S',
      'mostrar_portada': 'N',
      'visible_para_todos': 'S',
      'codusuarioa':
          authService.userCode != null ? int.parse(authService.userCode!) : 1,
      'categorias': categoriaIds,
    };

    final response = await apiService.post(
      'api/consejos.php',
      body: json.encode(payload),
    );

    if (response.statusCode != 201) {
      throw Exception('No se pudo crear el consejo "${draft.titulo}".');
    }
  }

  Future<void> _updateConsejoFromDraft({
    required Consejo existing,
    required ConsejoImportDraft draft,
    required Set<String> selectedNewCategoryNames,
    Set<int> selectedExistingCategoryIds = const <int>{},
  }) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final detalle = await _fetchConsejoDetalle(existing.codigo) ?? existing;
    final categoriaIds = await _resolveCategoriaIdsForDraft(
      draft,
      selectedNewCategoryNames: selectedNewCategoryNames,
      selectedExistingCategoryIds: selectedExistingCategoryIds,
    );
    final mergedCategoriaIds = <int>{
      ...detalle.categoriaIds,
      ...categoriaIds,
    }.toList(growable: false);

    detalle.titulo = draft.titulo.trim();
    detalle.texto = draft.descripcion.trim();
    detalle.categoriaIds = mergedCategoriaIds;
    detalle.visibleParaTodos = 'S';

    final response = await apiService.put(
      'api/consejos.php',
      body: json.encode(detalle.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo reemplazar el consejo "${draft.titulo}".');
    }
  }

  bool _supportsSystemClipboardImage() {
    try {
      return SystemClipboard.instance != null;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> _readClipboardImageByFormat(
    ClipboardReader reader,
    FileFormat format,
  ) async {
    final completer = Completer<Uint8List?>();
    final progress = reader.getFile(
      format,
      (file) async {
        try {
          final bytes = await file.readAll();
          if (!completer.isCompleted) completer.complete(bytes);
        } catch (_) {
          if (!completer.isCompleted) completer.complete(null);
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    if (progress == null) {
      return null;
    }

    return completer.future;
  }

  Future<Uint8List?> _tryReadSystemClipboardImage() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return null;
    }

    try {
      final reader = await clipboard.read();
      final formatsToTry = <FileFormat>[
        Formats.png,
        Formats.jpeg,
        Formats.webp,
        Formats.gif,
        Formats.bmp,
        Formats.tiff,
      ];

      for (final format in formatsToTry) {
        final bytes = await _readClipboardImageByFormat(reader, format);
        if (bytes != null && bytes.isNotEmpty) {
          return bytes;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<String?> _tryReadSystemClipboardHtmlText() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return null;
    }

    try {
      final reader = await clipboard.read();
      if (!reader.canProvide(Formats.htmlText)) {
        return null;
      }
      final html = await reader.readValue(Formats.htmlText);
      final trimmed = html?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return null;
      }
      return trimmed;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _tryReadSystemClipboardUriText() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return null;
    }

    try {
      final reader = await clipboard.read();
      if (!reader.canProvide(Formats.uri)) {
        return null;
      }
      final uriValue = await reader.readValue(Formats.uri);
      final uriText = uriValue?.uri.toString().trim();
      if (uriText == null || uriText.isEmpty) {
        return null;
      }
      return uriText;
    } catch (_) {
      return null;
    }
  }

  String? _extractImageUrlFromClipboardText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return null;
    }

    final directImageUrl = RegExp(
      r"https?://[^\s<>]+\.(png|jpe?g|webp|gif|bmp|tiff?)(\?[^\s<>]*)?",
      caseSensitive: false,
    ).firstMatch(text);
    if (directImageUrl != null) {
      return directImageUrl.group(0);
    }

    final anyUrl =
        RegExp(r"https?://[^\s<>]+", caseSensitive: false).firstMatch(text);
    return anyUrl?.group(0);
  }

  String? _extractImageSourceFromHtml(String html) {
    final imgSrcMatch = RegExp(
      "<img[^>]+src\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]",
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (imgSrcMatch != null) {
      return imgSrcMatch.group(1)?.trim();
    }

    final cssUrlMatch = RegExp(
      "url\\(\\s*['\\\"]?([^'\\\"\\)]+)['\\\"]?\\s*\\)",
      caseSensitive: false,
    ).firstMatch(html);
    return cssUrlMatch?.group(1)?.trim();
  }

  Uint8List? _decodeImageFromDataUri(String value) {
    final text = value.trim();
    if (!text.toLowerCase().startsWith('data:image/')) {
      return null;
    }
    final markerIndex = text.toLowerCase().indexOf('base64,');
    if (markerIndex < 0) {
      return null;
    }

    var candidate = text.substring(markerIndex + 'base64,'.length);
    if (candidate.length < 64) {
      return null;
    }
    while (candidate.length % 4 != 0) {
      candidate += '=';
    }

    try {
      return Uint8List.fromList(base64Decode(candidate));
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _tryDownloadImageFromUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }

    try {
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close(force: true);
        return null;
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      final bytes = builder.toBytes();
      client.close(force: true);
      if (bytes.isEmpty) {
        return null;
      }

      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _tryResolveImageSource(String source) async {
    final fromDataUri = _decodeImageFromDataUri(source);
    if (fromDataUri != null && fromDataUri.isNotEmpty) {
      return fromDataUri;
    }

    return _tryDownloadImageFromUrl(source);
  }

  Future<Uint8List?> _tryReadImageFromClipboardText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) {
      return null;
    }

    final dataUri = _decodeImageFromDataUri(text);
    if (dataUri != null && dataUri.isNotEmpty) {
      return dataUri;
    }

    final url = _extractImageUrlFromClipboardText(text);
    if (url == null) {
      return null;
    }

    return _tryDownloadImageFromUrl(url);
  }

  Future<void> _showPasteConsejoDialog() async {
    ConsejoClipboardDraft? draft;
    Uint8List? imageBytes;
    Consejo? existingConsejo;
    bool replaceExisting = false;
    String? errorText;
    bool readingClipboard = false;
    bool importing = false;
    List<String> existingCategories = <String>[];
    List<String> missingCategories = <String>[];
    Map<String, bool> createMissingSelections = <String, bool>{};
    Map<String, int?> mapMissingToExistingCategoryId = <String, int?>{};
    List<Map<String, dynamic>> detectedCategoryCatalog =
        <Map<String, dynamic>>[];

    final supportsImageClipboard = _supportsSystemClipboardImage();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget buildCountBadge(int count) {
            final isPositive = count > 0;
            return Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    isPositive ? Colors.green.shade600 : Colors.grey.shade500,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            );
          }

          Widget buildCountPill(int count) {
            final isPositive = count > 0;
            return Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    isPositive ? Colors.green.shade600 : Colors.grey.shade500,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Pegar consejo'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Formato esperado: primera línea título, imagen y líneas siguientes descripción.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: readingClipboard || importing
                          ? null
                          : () async {
                              setDialogState(() {
                                readingClipboard = true;
                                errorText = null;
                              });

                              final data = await Clipboard.getData(
                                Clipboard.kTextPlain,
                              );
                              final clipboardText = data?.text ?? '';
                              final parsed = parseConsejoClipboardText(
                                clipboardText,
                              );

                              final imageFromClipboard = supportsImageClipboard
                                  ? await _tryReadSystemClipboardImage()
                                  : null;
                              final imageFromText =
                                  await _tryReadImageFromClipboardText(
                                clipboardText,
                              );
                              final clipboardHtml = supportsImageClipboard
                                  ? await _tryReadSystemClipboardHtmlText()
                                  : null;
                              final htmlImageSource = clipboardHtml == null
                                  ? null
                                  : _extractImageSourceFromHtml(clipboardHtml);
                              final imageFromHtml = htmlImageSource == null
                                  ? null
                                  : await _tryResolveImageSource(
                                      htmlImageSource,
                                    );
                              final clipboardUri = supportsImageClipboard
                                  ? await _tryReadSystemClipboardUriText()
                                  : null;
                              final imageFromUri = clipboardUri == null
                                  ? null
                                  : await _tryResolveImageSource(clipboardUri);

                              final image = imageFromClipboard ??
                                  imageFromText ??
                                  imageFromHtml ??
                                  imageFromUri;

                              final catalog = parsed == null
                                  ? const <Map<String, dynamic>>[]
                                  : await _fetchConsejoCategoriasCatalog();
                              final existingNormalized = catalog
                                  .map(
                                    (item) => _normalizeCategoryName(
                                      (item['nombre'] ?? '').toString(),
                                    ),
                                  )
                                  .where((item) => item.isNotEmpty)
                                  .toSet();

                              final nextExisting = <String>[];
                              final nextMissing = <String>[];
                              final nextSelections = <String, bool>{};
                              final nextMappings = <String, int?>{};
                              if (parsed != null) {
                                for (final categoria in parsed.categorias) {
                                  final normalizedCategory =
                                      _normalizeCategoryName(categoria);
                                  if (existingNormalized
                                      .contains(normalizedCategory)) {
                                    nextExisting.add(categoria);
                                  } else {
                                    nextMissing.add(categoria);
                                    nextSelections[categoria] = true;
                                    nextMappings[categoria] = null;
                                  }
                                }
                              }

                              if (!mounted) return;
                              setDialogState(() {
                                draft = parsed;
                                imageBytes = image;
                                existingConsejo = parsed == null
                                    ? null
                                    : _fuzzyFindExisting(
                                        normalizeConsejoTitle(parsed.titulo),
                                        _buildTitleToExisting(),
                                      );
                                replaceExisting = false;
                                readingClipboard = false;
                                existingCategories = nextExisting;
                                missingCategories = nextMissing;
                                createMissingSelections = nextSelections;
                                mapMissingToExistingCategoryId = nextMappings;
                                detectedCategoryCatalog = catalog;

                                if (parsed == null) {
                                  errorText =
                                      'No se detectó un consejo válido en el portapapeles.';
                                } else {
                                  errorText = null;
                                }
                              });
                            },
                      icon: readingClipboard
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.content_paste_rounded),
                      label: Text(readingClipboard ? 'Leyendo...' : 'Pegar'),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (draft != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        draft!.titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (existingConsejo != null) ...[
                        const SizedBox(height: 10),
                        Card(
                          margin: EdgeInsets.zero,
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              12,
                            ),
                            title: const Text(
                              'Posible consejo duplicado',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              existingConsejo!.titulo,
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            children: [
                              Text(
                                'Ya existe un consejo con título similar: "${existingConsejo!.titulo}"',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              CheckboxListTile(
                                value: replaceExisting,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title:
                                    const Text('Reemplazar consejo existente'),
                                subtitle: const Text(
                                  'Si está marcado, se actualizará el consejo existente en lugar de abrir uno nuevo.',
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: importing
                                    ? null
                                    : (value) {
                                        setDialogState(() {
                                          replaceExisting = value ?? false;
                                        });
                                      },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          title: const Text(
                            'Portada',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            imageBytes != null
                                ? 'Imagen lista para importar'
                                : 'No se detectó imagen',
                            style: TextStyle(
                              color: imageBytes != null
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          children: [
                            if (imageBytes != null)
                              Container(
                                width: double.infinity,
                                constraints:
                                    const BoxConstraints(maxHeight: 220),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    imageBytes!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            if (imageBytes == null)
                              Text(
                                supportsImageClipboard
                                    ? 'No se detectó imagen en el portapapeles del sistema. Puedes importar solo texto y agregar portada luego.'
                                    : 'Pegado de imagen disponible solo en Windows/macOS/Linux.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (draft!.categorias.isNotEmpty) ...[
                        Card(
                          margin: EdgeInsets.zero,
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              12,
                            ),
                            title: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Categorías',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                buildCountBadge(draft!.categorias.length),
                              ],
                            ),
                            subtitle: missingCategories.isNotEmpty
                                ? Text(
                                    '${missingCategories.length} por crear (seleccionables)',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                            children: [
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 220),
                                child: Scrollbar(
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (missingCategories.isNotEmpty) ...[
                                          Text(
                                            'Categorías inexistentes: marca cuáles crear antes de importar.',
                                            style: TextStyle(
                                              color: Colors.orange.shade800,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          ...missingCategories.map((categoria) {
                                            final selectedCategoryId =
                                                mapMissingToExistingCategoryId[
                                                    categoria];

                                            String? mappedExistingName;
                                            if (selectedCategoryId != null) {
                                              for (final item
                                                  in detectedCategoryCatalog) {
                                                final id = int.tryParse(
                                                  item['codigo'].toString(),
                                                );
                                                if (id == selectedCategoryId) {
                                                  mappedExistingName =
                                                      (item['nombre'] ?? '')
                                                          .toString();
                                                  break;
                                                }
                                              }
                                            }

                                            return InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              onLongPress: importing
                                                  ? null
                                                  : () async {
                                                      final sortedOptions =
                                                          detectedCategoryCatalog
                                                              .where(
                                                                (item) =>
                                                                    int.tryParse(
                                                                      item['codigo']
                                                                          .toString(),
                                                                    ) !=
                                                                    null,
                                                              )
                                                              .toList(
                                                                growable: false,
                                                              )..sort(
                                                              (a, b) => (a[
                                                                          'nombre'] ??
                                                                      '')
                                                                  .toString()
                                                                  .toLowerCase()
                                                                  .compareTo(
                                                                    (b['nombre'] ??
                                                                            '')
                                                                        .toString()
                                                                        .toLowerCase(),
                                                                  ),
                                                            );

                                                      final selected =
                                                          await showDialog<int>(
                                                        context: dialogContext,
                                                        builder: (ctx) =>
                                                            SimpleDialog(
                                                          title: Text(
                                                            'Asignar "$categoria"',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                          children: [
                                                            SimpleDialogOption(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                ctx,
                                                                -1,
                                                              ),
                                                              child: const Text(
                                                                'Ninguna (crear nueva)',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                            ...sortedOptions
                                                                .map((item) {
                                                              final id =
                                                                  int.tryParse(
                                                                item['codigo']
                                                                    .toString(),
                                                              );
                                                              if (id == null) {
                                                                return null;
                                                              }
                                                              return SimpleDialogOption(
                                                                onPressed: () =>
                                                                    Navigator
                                                                        .pop(
                                                                  ctx,
                                                                  id,
                                                                ),
                                                                child: Text(
                                                                  (item['nombre'] ??
                                                                          '')
                                                                      .toString(),
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                ),
                                                              );
                                                            }).whereType<
                                                                    Widget>(),
                                                          ],
                                                        ),
                                                      );

                                                      if (selected == null) {
                                                        return;
                                                      }

                                                      setDialogState(() {
                                                        if (selected == -1) {
                                                          mapMissingToExistingCategoryId[
                                                              categoria] = null;
                                                        } else {
                                                          mapMissingToExistingCategoryId[
                                                                  categoria] =
                                                              selected;
                                                          createMissingSelections[
                                                                  categoria] =
                                                              false;
                                                        }
                                                      });
                                                    },
                                              child: CheckboxListTile(
                                                value: createMissingSelections[
                                                        categoria] ??
                                                    false,
                                                dense: true,
                                                visualDensity:
                                                    const VisualDensity(
                                                  horizontal: -4,
                                                  vertical: -4,
                                                ),
                                                contentPadding: EdgeInsets.zero,
                                                title: Text(
                                                  categoria,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  mappedExistingName != null
                                                      ? 'Asignada a "$mappedExistingName". Mantén pulsado para cambiar.'
                                                      : 'Mantén pulsado para asignar a categoría existente.',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                controlAffinity:
                                                    ListTileControlAffinity
                                                        .leading,
                                                onChanged: selectedCategoryId !=
                                                        null
                                                    ? null
                                                    : (value) {
                                                        setDialogState(
                                                          () {
                                                            createMissingSelections[
                                                                    categoria] =
                                                                value ?? false;
                                                          },
                                                        );
                                                      },
                                              ),
                                            );
                                          }).toList(growable: false),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Card(
                        margin: EdgeInsets.zero,
                        child: ExpansionTile(
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          title: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Descripción',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              buildCountPill(draft!.descripcion.length),
                            ],
                          ),
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(draft!.descripcion),
                                  ),
                                ),
                              ),
                            ),
                            if (draft!.hashtagsAutoGenerados) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Se agregaron hashtags automaticamente.',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    importing ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
              FilledButton.icon(
                onPressed: importing || draft == null
                    ? null
                    : () async {
                        setDialogState(() => importing = true);

                        final mappedExistingIds = <int>{};
                        final mappedExistingNames = <String>{};
                        for (final categoria in missingCategories) {
                          final mappedId =
                              mapMissingToExistingCategoryId[categoria];
                          if (mappedId == null) continue;
                          mappedExistingIds.add(mappedId);
                          final found = detectedCategoryCatalog.firstWhere(
                            (item) =>
                                int.tryParse(item['codigo'].toString()) ==
                                mappedId,
                            orElse: () => const <String, dynamic>{},
                          );
                          final foundName =
                              (found['nombre'] ?? '').toString().trim();
                          if (foundName.isNotEmpty) {
                            mappedExistingNames.add(foundName);
                          }
                        }

                        final selectedToCreate = missingCategories
                            .where(
                              (categoria) =>
                                  createMissingSelections[categoria] ?? false,
                            )
                            .toList(growable: false);

                        for (final categoria in selectedToCreate) {
                          await _createCategoriaConsejo(categoria);
                        }

                        if (existingConsejo != null && replaceExisting) {
                          try {
                            final importDraft = ConsejoImportDraft(
                              titulo: draft!.titulo,
                              descripcion: draft!.descripcion,
                              categorias: draft!.categorias,
                            );
                            await _updateConsejoFromDraft(
                              existing: existingConsejo!,
                              draft: importDraft,
                              selectedNewCategoryNames: selectedToCreate
                                  .map((c) => c.toLowerCase())
                                  .toSet(),
                              selectedExistingCategoryIds: mappedExistingIds,
                            );

                            if (imageBytes != null) {
                              final updated = await _fetchConsejoDetalle(
                                    existingConsejo!.codigo,
                                  ) ??
                                  existingConsejo!;
                              final miniatura =
                                  ThumbnailGenerator.generateThumbnail(
                                imageBytes!,
                              );
                              final payload = <String, dynamic>{
                                'codigo': updated.codigo,
                                'titulo': updated.titulo,
                                'texto': updated.texto,
                                'activo': updated.activo,
                                'mostrar_portada': updated.mostrarPortada,
                                'visible_para_todos': updated.visibleParaTodos,
                                'imagen_portada': base64Encode(imageBytes!),
                                'imagen_portada_nombre': 'base64',
                                'imagen_miniatura': miniatura != null
                                    ? base64Encode(miniatura)
                                    : '',
                                'categorias': updated.categoriaIds,
                              };
                              await context.read<ApiService>().put(
                                    'api/consejos.php',
                                    body: jsonEncode(payload),
                                  );
                            }

                            if (!mounted) return;
                            await _loadConsejos();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Consejo reemplazado.'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.pop(dialogContext);
                            return;
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() {
                              importing = false;
                              errorText =
                                  'No se pudo reemplazar el consejo: ${e.toString().replaceFirst('Exception: ', '')}';
                            });
                            return;
                          }
                        }

                        final finalCategoryNames = <String>{
                          ...existingCategories,
                          ...mappedExistingNames,
                          ...selectedToCreate,
                        }.toList(growable: false);
                        final result = await Navigator.pushNamed(
                          context,
                          '/consejo_edit',
                          arguments: <String, dynamic>{
                            'prefill_titulo': draft!.titulo,
                            'prefill_texto': draft!.descripcion,
                            'prefill_categoria_names': finalCategoryNames,
                            'prefill_image_bytes': imageBytes,
                          },
                        );
                        if (!mounted) return;
                        if (result == true) {
                          await _loadConsejos();
                          if (!mounted) return;
                          Navigator.pop(dialogContext);
                        } else {
                          setDialogState(() => importing = false);
                        }
                      },
                icon: importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.file_download_done_outlined),
                label: Text(importing ? 'Abriendo...' : 'Importar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAIPromptDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Prompt para IA',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copia este prompt y pégalo en tu IA favorita para generar consejos con formato compatible:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _aiPrompt,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _aiPrompt));
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Prompt copiado al portapapeles.'),
                  backgroundColor: Colors.deepPurple,
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReplaceComparisonDialog({
    required Consejo existing,
    required ConsejoImportDraft draft,
  }) async {
    var split = 0.5;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
          title: Row(
            children: [
              const Icon(Icons.compare_arrows_rounded,
                  color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Comparar descripciones',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 760,
            height: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consejo: ${draft.titulo}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const splitterHeight = 14.0;
                      const minPaneHeight = 110.0;
                      final availableHeight =
                          (constraints.maxHeight - splitterHeight)
                              .clamp(0.0, double.infinity);
                      var minRatio = availableHeight <= 0
                          ? 0.2
                          : (minPaneHeight / availableHeight).clamp(0.2, 0.8);
                      var maxRatio = (1 - minRatio).clamp(0.2, 0.8);
                      if (maxRatio < minRatio) {
                        minRatio = 0.5;
                        maxRatio = 0.5;
                      }
                      final effectiveSplit = split.clamp(minRatio, maxRatio);
                      final topHeight = availableHeight * effectiveSplit;
                      final bottomHeight = availableHeight - topHeight;

                      return Column(
                        children: [
                          SizedBox(
                            height: topHeight,
                            child: _ImportComparePane(
                              title:
                                  'Actual (${existing.texto.trim().length} chars)',
                              color: Colors.orange,
                              text: existing.texto,
                            ),
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.resizeUpDown,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: (details) {
                                if (availableHeight <= 0) return;
                                final deltaRatio =
                                    details.delta.dy / availableHeight;
                                setS(() {
                                  split = (split + deltaRatio)
                                      .clamp(minRatio, maxRatio);
                                });
                              },
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
                            height: bottomHeight,
                            child: _ImportComparePane(
                              title:
                                  'IA (${draft.descripcion.trim().length} chars)',
                              color: Colors.blue,
                              text: draft.descripcion,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImportAssistant() async {
    var detected = <ConsejoImportDraft>[];
    var analyzing = false;
    var importing = false;
    var importFinished = false;
    var hideImportButton = false;
    var hidePasteStep = false;
    var compactAfterPaste = false;
    var replaceExisting = false;
    var importChoices = <int, bool>{};
    var replaceChoices = <int, bool>{};
    var newCategoryChoices = <String, bool>{};
    var importedCount = 0;
    var replacedCount = 0;
    var omittedCount = 0;
    var processedCount = 0;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final conflicts = _estimateImportConflicts(detected);
          final estimatedOmissions =
              conflicts.duplicatedInPaste + conflicts.alreadyExisting;
          final titleMap = _buildTitleToExisting();
          final proposedReplacements =
              <({int index, ConsejoImportDraft draft, Consejo existing})>[
            for (var i = 0; i < detected.length; i++)
              if (_fuzzyFindExisting(
                      normalizeConsejoTitle(detected[i].titulo), titleMap)
                  case final existing?)
                (index: i, draft: detected[i], existing: existing),
          ]..sort((a, b) {
                  final aDelta = a.existing.texto.trim().length -
                      a.draft.descripcion.trim().length;
                  final bDelta = b.existing.texto.trim().length -
                      b.draft.descripcion.trim().length;
                  return bDelta.compareTo(aDelta);
                });
          final selectedReplacementCount = proposedReplacements
              .where(
                (e) =>
                    replaceChoices[e.index] ??
                    _shouldReplaceExistingByDescriptionLength(
                      existing: e.existing,
                      draft: e.draft,
                    ),
              )
              .length;
          final selectedImportCount = detected
              .asMap()
              .entries
              .where((entry) => importChoices[entry.key] ?? true)
              .length;
          final pendingNewCategories = newCategoryChoices.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          final selectedNewCategoryNames = newCategoryChoices.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key.toLowerCase())
              .toSet();

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            title: Row(
              children: [
                const Icon(Icons.content_paste_rounded,
                    color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Importar Consejos con IA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: importFinished ? 'Cerrar' : 'Cancelar',
                  onPressed:
                      importing ? null : () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!compactAfterPaste) ...[
                      _ImportAssistantStepCard(
                        title:
                            'Paso 1: Genera Consejos con el formato de importación',
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: importing ? null : _showAIPromptDialog,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Ver prompt de IA'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _ImportAssistantStepCard(
                        title: 'Paso 2: Copia todos los Consejos generados.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!hidePasteStep)
                      _ImportAssistantStepCard(
                        title: hideImportButton
                            ? 'Pega los Consejos pulsando en "Pegar".'
                            : 'Paso 3: Pega los Consejos pulsando en "Pegar".',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FilledButton.icon(
                              onPressed: analyzing || importing
                                  ? null
                                  : () async {
                                      setDialogState(() {
                                        compactAfterPaste = true;
                                        hideImportButton = false;
                                        analyzing = true;
                                        importFinished = false;
                                        importedCount = 0;
                                        replacedCount = 0;
                                        omittedCount = 0;
                                        processedCount = 0;
                                        errorText = null;
                                        detected = <ConsejoImportDraft>[];
                                        importChoices = <int, bool>{};
                                        replaceChoices = <int, bool>{};
                                        newCategoryChoices = <String, bool>{};
                                      });

                                      final data = await Clipboard.getData(
                                        Clipboard.kTextPlain,
                                      );
                                      final text = data?.text ?? '';
                                      final parsed = parseConsejosFromAI(text);
                                      if (parsed.isNotEmpty) {
                                        try {
                                          await _loadCategoriasCatalogo();
                                        } catch (_) {
                                          // Se mostrará al importar si falla la carga.
                                        }
                                      }

                                      if (!mounted) return;

                                      final titleMap = _buildTitleToExisting();
                                      final newReplaceChoices = <int, bool>{};
                                      final newImportChoices = <int, bool>{};
                                      for (var i = 0; i < parsed.length; i++) {
                                        final draft = parsed[i];
                                        newImportChoices[i] = true;
                                        final existing = _fuzzyFindExisting(
                                          normalizeConsejoTitle(draft.titulo),
                                          titleMap,
                                        );
                                        if (existing != null) {
                                          newReplaceChoices[i] =
                                              _shouldReplaceExistingByDescriptionLength(
                                            existing: existing,
                                            draft: draft,
                                          );
                                        }
                                      }

                                      final missingCategoryChoices =
                                          <String, bool>{};
                                      final seenMissing = <String>{};
                                      for (final draft in parsed) {
                                        for (final categoria
                                            in draft.categorias) {
                                          final trimmed = categoria.trim();
                                          if (trimmed.isEmpty) continue;
                                          final key = trimmed.toLowerCase();
                                          if (_findCategoriaByName(trimmed) ==
                                                  null &&
                                              seenMissing.add(key)) {
                                            missingCategoryChoices[trimmed] =
                                                true;
                                          }
                                        }
                                      }

                                      setDialogState(() {
                                        analyzing = false;
                                        detected = parsed;
                                        hidePasteStep = parsed.isNotEmpty;
                                        importChoices = newImportChoices;
                                        replaceChoices = newReplaceChoices;
                                        newCategoryChoices =
                                            missingCategoryChoices;
                                        if (text.trim().isEmpty) {
                                          errorText =
                                              'El portapapeles está vacío.';
                                        } else if (parsed.isEmpty) {
                                          errorText =
                                              'No se detectaron consejos con el formato de importación ([Título], [Descripción], [Categorías]).';
                                        }
                                      });
                                    },
                              icon: analyzing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.content_paste_go_rounded),
                              label: Text(
                                analyzing ? 'Analizando...' : 'Pegar',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Se detectarán títulos, descripciones y categorías. Los títulos coincidentes podrán reemplazarse y las categorías nuevas podrán crearse antes de importar.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!hidePasteStep) const SizedBox(height: 12),
                    if (errorText != null) ...[
                      if (hidePasteStep) const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          errorText!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    if (detected.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      if (!hideImportButton)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text('Detectados: ${detected.length}')),
                            Chip(label: Text('Se omiten: $estimatedOmissions')),
                          ],
                        ),
                      if (!hideImportButton &&
                          pendingNewCategories.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ImportAssistantStepCard(
                          title:
                              'Categorías nuevas detectadas: marca cuáles quieres crear antes de importar',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Las categorías seleccionadas se crearán automáticamente y se asignarán a los consejos importados o reemplazados.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 180),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.teal.shade100,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: pendingNewCategories.length,
                                  itemBuilder: (context, index) {
                                    final key = pendingNewCategories[index];
                                    return CheckboxListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      value: newCategoryChoices[key] ?? false,
                                      onChanged: importing
                                          ? null
                                          : (value) => setDialogState(() {
                                                newCategoryChoices[key] =
                                                    value ?? false;
                                              }),
                                      title: Text(
                                        key,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!hideImportButton) const SizedBox(height: 12),
                      if (!importing && !importFinished)
                        _ImportAssistantStepCard(
                          title: detected.isEmpty
                              ? 'Se mostrarán aquí los Consejos detectados para importarlos.'
                              : 'Se han obtenido ${detected.length} Consejos.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (estimatedOmissions > 0)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (conflicts.alreadyExisting > 0)
                                      Text(
                                        replaceExisting
                                            ? '${conflicts.alreadyExisting} se reemplazarán por coincidir con un título existente.'
                                            : '${conflicts.alreadyExisting} se omitirán por coincidir con un título existente.',
                                        style: TextStyle(
                                          color: replaceExisting
                                              ? Colors.blue.shade700
                                              : Colors.orange.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if (conflicts.duplicatedInPaste > 0)
                                      Text(
                                        '${conflicts.duplicatedInPaste} se omitirán por estar duplicados en el texto pegado.',
                                        style: TextStyle(
                                          color: Colors.orange.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              if (estimatedOmissions > 0)
                                const SizedBox(height: 8),
                              if (proposedReplacements.isNotEmpty)
                                SwitchListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Reemplazar existentes',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  subtitle: const Text(
                                    'Si el título coincide, actualiza la descripción y asigna las categorías seleccionadas.',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  value: replaceExisting,
                                  onChanged: importing
                                      ? null
                                      : (value) => setDialogState(() {
                                            replaceExisting = value;
                                          }),
                                ),
                              if (proposedReplacements.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  replaceExisting
                                      ? 'Selecciona cuáles reemplazar ($selectedReplacementCount de ${proposedReplacements.length}):'
                                      : 'Coincidencias detectadas: se omitirán si no activas "Reemplazar existentes".',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: replaceExisting
                                        ? Colors.blue.shade700
                                        : Colors.orange.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  constraints:
                                      const BoxConstraints(maxHeight: 260),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: replaceExisting
                                          ? Colors.blue.shade100
                                          : Colors.orange.shade100,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: proposedReplacements.length,
                                    itemBuilder: (context, idx) {
                                      final entry = proposedReplacements[idx];
                                      final newLen =
                                          entry.draft.descripcion.trim().length;
                                      final existingLen =
                                          entry.existing.texto.trim().length;
                                      final checked = replaceChoices[
                                              entry.index] ??
                                          _shouldReplaceExistingByDescriptionLength(
                                            existing: entry.existing,
                                            draft: entry.draft,
                                          );
                                      return InkWell(
                                        onLongPress: importing
                                            ? null
                                            : () =>
                                                _showReplaceComparisonDialog(
                                                  existing: entry.existing,
                                                  draft: entry.draft,
                                                ),
                                        child: CheckboxListTile(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          value: checked,
                                          onChanged: importing
                                              ? null
                                              : (value) => setDialogState(() {
                                                    replaceChoices[entry
                                                        .index] = value ?? true;
                                                  }),
                                          title: Text(
                                            entry.draft.titulo,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (entry.draft.titulo.trim() !=
                                                  entry.existing.titulo
                                                      .trim()) ...[
                                                Text(
                                                  'Existe como: ${entry.existing.titulo}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                              ],
                                              Text(
                                                'IA: $newLen · Actual: $existingLen',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: existingLen > newLen
                                                      ? Colors.orange.shade800
                                                      : Colors.blue.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              Text(
                                'Consejos detectados ($selectedImportCount de ${detected.length} seleccionados):',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 220),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: detected.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final item = detected[index];
                                    final selected =
                                        importChoices[index] ?? true;
                                    final duplicate = _fuzzyFindExisting(
                                          normalizeConsejoTitle(item.titulo),
                                          titleMap,
                                        ) !=
                                        null;
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Checkbox(
                                        value: selected,
                                        onChanged: importing
                                            ? null
                                            : (value) => setDialogState(() {
                                                  importChoices[index] =
                                                      value ?? true;
                                                }),
                                      ),
                                      title: Text(item.titulo),
                                      subtitle: Text(
                                        '${item.descripcion.trim().length} carac.',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            duplicate
                                                ? Icons.warning_amber_rounded
                                                : Icons.lightbulb_outline,
                                            color: duplicate
                                                ? Colors.orange
                                                : Colors.blue,
                                          ),
                                          if (duplicate) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              replaceExisting
                                                  ? 'Coincide'
                                                  : 'Omitido',
                                              style: const TextStyle(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (importFinished) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Se han importado $importedCount Consejos nuevos',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Se han omitido $omittedCount Consejos',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    importing ? null : () => Navigator.pop(dialogContext),
                child: Text(importFinished ? 'Cerrar' : 'Cancelar'),
              ),
              if (!hideImportButton)
                FilledButton.icon(
                  onPressed: importing ||
                          detected.isEmpty ||
                          selectedImportCount == 0
                      ? null
                      : () async {
                          final titleToExisting = _buildTitleToExisting();
                          final processedTitles = <String>{};
                          var hasServerErrors = false;

                          setDialogState(() {
                            hideImportButton = true;
                            hidePasteStep = false;
                            importing = true;
                            errorText = null;
                            importFinished = false;
                            importedCount = 0;
                            replacedCount = 0;
                            omittedCount = 0;
                            processedCount = 0;
                          });

                          try {
                            for (var i = 0; i < detected.length; i++) {
                              final draft = detected[i];
                              if (!(importChoices[i] ?? true)) {
                                omittedCount += 1;
                                processedCount += 1;
                                continue;
                              }
                              final normalizedTitle =
                                  normalizeConsejoTitle(draft.titulo);

                              if (normalizedTitle.isEmpty ||
                                  !processedTitles.add(normalizedTitle)) {
                                omittedCount += 1;
                                processedCount += 1;
                                continue;
                              }

                              final existingItem = _fuzzyFindExisting(
                                normalizedTitle,
                                titleToExisting,
                              );
                              final isExisting = existingItem != null;
                              final shouldReplaceCurrent = isExisting
                                  ? (replaceChoices[i] ??
                                      _shouldReplaceExistingByDescriptionLength(
                                        existing: existingItem!,
                                        draft: draft,
                                      ))
                                  : false;

                              if (isExisting &&
                                  (!replaceExisting || !shouldReplaceCurrent)) {
                                omittedCount += 1;
                                processedCount += 1;
                                continue;
                              }

                              try {
                                if (isExisting && replaceExisting) {
                                  await _updateConsejoFromDraft(
                                    existing: existingItem!,
                                    draft: draft,
                                    selectedNewCategoryNames:
                                        selectedNewCategoryNames,
                                  );
                                  replacedCount += 1;
                                } else {
                                  final authService = Provider.of<AuthService>(
                                    context,
                                    listen: false,
                                  );
                                  final apiService = Provider.of<ApiService>(
                                    context,
                                    listen: false,
                                  );
                                  final categoriaIds =
                                      await _resolveCategoriaIdsForDraft(
                                    draft,
                                    selectedNewCategoryNames:
                                        selectedNewCategoryNames,
                                  );
                                  final payload = <String, dynamic>{
                                    'titulo': draft.titulo.trim(),
                                    'texto': draft.descripcion.trim(),
                                    'activo': 'S',
                                    'mostrar_portada': 'N',
                                    'visible_para_todos': 'S',
                                    'codusuarioa': authService.userCode != null
                                        ? int.parse(authService.userCode!)
                                        : 1,
                                    'categorias': categoriaIds,
                                  };
                                  final response = await apiService.post(
                                    'api/consejos.php',
                                    body: json.encode(payload),
                                  );
                                  if (response.statusCode != 201) {
                                    throw Exception();
                                  }
                                  importedCount += 1;
                                }
                                titleToExisting[normalizedTitle] = Consejo(
                                  titulo: draft.titulo,
                                  texto: draft.descripcion,
                                );
                              } catch (_) {
                                omittedCount += 1;
                                hasServerErrors = true;
                              }

                              processedCount += 1;
                              if (mounted) {
                                setDialogState(() {});
                              }
                            }

                            if (!mounted) return;
                            await _loadConsejos();
                            setDialogState(() {
                              importing = false;
                              importFinished = true;
                              if (hasServerErrors) {
                                errorText =
                                    'Algún Consejo no se pudo guardar y se ha contabilizado como omitido.';
                              }
                            });
                          } catch (e) {
                            setDialogState(() {
                              importing = false;
                              errorText = e.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  );
                            });
                          }
                        },
                  icon: importing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label:
                      Text(importing ? 'Importando...' : 'Importar Consejos'),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteConsejo(int codigo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Está seguro de que desea eliminar este consejo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final response =
            await apiService.delete('api/consejos.php?codigo=$codigo');

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Consejo eliminado exitosamente'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadConsejos();
        } else {
          throw Exception('Error al eliminar');
        }
      } catch (e) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar consejo. $errorMessage'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openConsejoMenu(Consejo consejo) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Visualizar'),
              onTap: () => Navigator.pop(context, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Pegar imagen'),
              onTap: () => Navigator.pop(context, 'paste_image'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'view') {
      await _openConsejoPreview(consejo);
    } else if (action == 'edit') {
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/consejo_edit',
        arguments: consejo,
      ).then((result) {
        if (result == true) {
          _loadConsejos();
        }
      });
    } else if (action == 'paste_image') {
      await _showPasteImageDialog(consejo);
    } else if (action == 'delete') {
      await _deleteConsejo(consejo.codigo!);
    }
  }

  Future<void> _showPasteImageDialog(Consejo consejo) async {
    final bytes = await showPasteImageDialog(
      context,
      title: 'Pegar imagen',
      description:
          'Genera la imagen en formato base64 o copiala directamente al portapapeles y pulsa en pegar para agregarla al consejo.',
    );
    if (bytes == null) return;

    try {
      final miniatura = ThumbnailGenerator.generateThumbnail(bytes);
      final payload = <String, dynamic>{
        'codigo': consejo.codigo,
        'titulo': consejo.titulo,
        'texto': consejo.texto,
        'activo': consejo.activo,
        'mostrar_portada': consejo.mostrarPortada,
        'visible_para_todos': consejo.visibleParaTodos,
        'imagen_portada': base64Encode(bytes),
        'imagen_portada_nombre': 'base64',
        'imagen_miniatura': miniatura != null ? base64Encode(miniatura) : '',
      };

      final response = await context.read<ApiService>().put(
            'api/consejos.php',
            body: jsonEncode(payload),
          );

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadConsejos();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen aplicada al consejo.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('No se pudo aplicar la imagen.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al aplicar imagen: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<Consejo?> _fetchConsejoDetalle(int? codigo) async {
    if (codigo == null) return null;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/consejos.php?codigo=$codigo');

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        return Consejo.fromJson(data);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openConsejoImageViewer(Consejo consejo) async {
    final detalle = await _fetchConsejoDetalle(consejo.codigo);
    final imagenPortada = (detalle?.imagenPortada ?? '').trim();
    final imagenFallback =
        (consejo.imagenPortada ?? consejo.imagenMiniatura ?? '').trim();
    final imagen = imagenPortada.isNotEmpty ? imagenPortada : imagenFallback;

    if (!mounted || imagen.isEmpty) return;

    showImageViewerDialog(
      context: context,
      base64Image: imagen,
      title: consejo.titulo,
    );
  }

  Future<void> _openConsejoPreview(Consejo consejo) async {
    final detalle = await _fetchConsejoDetalle(consejo.codigo);
    final consejoPreview = detalle ?? consejo;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConsejoDetailScreen(
          consejo: consejoPreview,
          isPreviewMode: true,
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
            const Text('Consejos'),
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
                '${_getFilteredConsejos(_consejos).length}',
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
            tooltip: _activeFilterCount > 0
                ? 'Filtrar (${_activeFilterCount})'
                : 'Filtrar',
            onPressed: _showConsejosFilterDialog,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(_activeFilterCount > 0
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined),
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
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search),
            onPressed: _toggleSearchVisibility,
            tooltip: _isSearchVisible ? 'Ocultar búsqueda' : 'Buscar',
          ),
          PopupMenuButton<_ConsejosTopMenuAction>(
            tooltip: 'Más opciones',
            onSelected: (value) async {
              if (value == _ConsejosTopMenuAction.buscar) {
                _toggleSearchVisibility();
                return;
              }
              if (value == _ConsejosTopMenuAction.filtrar) {
                await _showConsejosFilterDialog();
                return;
              }
              if (value == _ConsejosTopMenuAction.categorias) {
                await _openCategoriasConsejosDialog();
                return;
              }
              if (value == _ConsejosTopMenuAction.copiarIa) {
                _showAIPromptDialog();
                return;
              }
              if (value == _ConsejosTopMenuAction.actualizar) {
                await _loadConsejos();
                return;
              }
              if (value == _ConsejosTopMenuAction.pegarConsejo) {
                _showPasteConsejoDialog();
                return;
              }
              if (value == _ConsejosTopMenuAction.pegarIa) {
                _showImportAssistant();
                return;
              }
              if (value == _ConsejosTopMenuAction.sortTitulo) {
                await _applySortSelection(_OrdenConsejosList.titulo);
                return;
              }
              if (value == _ConsejosTopMenuAction.sortRecientes) {
                await _applySortSelection(_OrdenConsejosList.recientes);
                return;
              }
              if (value == _ConsejosTopMenuAction.sortPopulares) {
                await _applySortSelection(_OrdenConsejosList.populares);
                return;
              }
              if (value == _ConsejosTopMenuAction.sortCategorias) {
                await _applySortSelection(_OrdenConsejosList.categorias);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<_ConsejosTopMenuAction>(
                value: _ConsejosTopMenuAction.buscar,
                child: Row(
                  children: [
                    Icon(
                      _isSearchVisible ? Icons.search_off : Icons.search,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(_isSearchVisible ? 'Ocultar buscar' : 'Buscar'),
                  ],
                ),
              ),
              PopupMenuItem<_ConsejosTopMenuAction>(
                value: _ConsejosTopMenuAction.filtrar,
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          _activeFilterCount > 0
                              ? Icons.filter_alt
                              : Icons.filter_alt_outlined,
                          size: 18,
                        ),
                        if (_activeFilterCount > 0)
                          Positioned(
                            right: -8,
                            top: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$_activeFilterCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Text('Filtrar'),
                  ],
                ),
              ),
              if (_canManageConsejos)
                const PopupMenuItem<_ConsejosTopMenuAction>(
                  value: _ConsejosTopMenuAction.categorias,
                  child: Row(
                    children: [
                      Icon(Icons.category_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Categorías'),
                    ],
                  ),
                ),
              if (_canManageConsejos)
                const PopupMenuItem<_ConsejosTopMenuAction>(
                  value: _ConsejosTopMenuAction.copiarIa,
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18),
                      SizedBox(width: 8),
                      Text('Copiar IA'),
                    ],
                  ),
                ),
              if (_canManageConsejos)
                const PopupMenuItem<_ConsejosTopMenuAction>(
                  value: _ConsejosTopMenuAction.pegarConsejo,
                  child: Row(
                    children: [
                      Icon(Icons.content_paste, size: 18),
                      SizedBox(width: 8),
                      Text('Pegar consejo'),
                    ],
                  ),
                ),
              if (_canManageConsejos)
                const PopupMenuItem<_ConsejosTopMenuAction>(
                  value: _ConsejosTopMenuAction.pegarIa,
                  child: Row(
                    children: [
                      Icon(Icons.content_paste_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Pegar IA'),
                    ],
                  ),
                ),
              const PopupMenuItem<_ConsejosTopMenuAction>(
                value: _ConsejosTopMenuAction.actualizar,
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Actualizar'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem<_ConsejosTopMenuAction>(
                value: _ConsejosTopMenuAction.sortTitulo,
                checked: _orden == _OrdenConsejosList.titulo,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Título')),
                    if (_orden == _OrdenConsejosList.titulo)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<_ConsejosTopMenuAction>(
                value: _ConsejosTopMenuAction.sortRecientes,
                checked: _orden == _OrdenConsejosList.recientes,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Recientes')),
                    if (_orden == _OrdenConsejosList.recientes)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<_ConsejosTopMenuAction>(
                value: _ConsejosTopMenuAction.sortPopulares,
                checked: _orden == _OrdenConsejosList.populares,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Populares')),
                    if (_orden == _OrdenConsejosList.populares)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<_ConsejosTopMenuAction>(
                value: _ConsejosTopMenuAction.sortCategorias,
                checked: _orden == _OrdenConsejosList.categorias,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Categorías')),
                    if (_orden == _OrdenConsejosList.categorias)
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
      body: SafeArea(
        child: Column(
          children: [
            // Barra de búsqueda y filtros
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (_isSearchVisible)
                    Column(
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar Consejos',
                            prefixIcon: IconButton(
                              tooltip: _searchQuery.isNotEmpty
                                  ? 'Limpiar búsqueda'
                                  : 'Buscar',
                              onPressed: _searchQuery.isNotEmpty
                                  ? () {
                                      setState(() {
                                        _searchQuery = '';
                                        _displayedConsejos = [];
                                        _currentPage = 1;
                                        _hasMoreItems = true;
                                      });
                                      _loadMoreConsejos();
                                    }
                                  : null,
                              icon: Icon(
                                _searchQuery.isNotEmpty
                                    ? Icons.clear
                                    : Icons.search,
                              ),
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'Ocultar búsqueda',
                              onPressed: _toggleSearchVisibility,
                              icon: const Icon(Icons.visibility_off_outlined),
                            ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              _displayedConsejos = [];
                              _currentPage = 1;
                              _hasMoreItems = true;
                            });
                            _loadMoreConsejos();
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Lista de consejos
            Expanded(
              child: _isLoading && _displayedConsejos.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _displayedConsejos.isEmpty
                      ? const Center(
                          child: Text('No hay consejos para mostrar'),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadConsejos,
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _displayedConsejos.length +
                                (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Mostrar indicador de carga al final
                              if (index == _displayedConsejos.length) {
                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Cargando más consejos...',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              final consejo = _displayedConsejos[index];
                              return Dismissible(
                                key: ValueKey(
                                  'consejo_${consejo.codigo ?? consejo.titulo}_$index',
                                ),
                                direction: DismissDirection.startToEnd,
                                dismissThresholds: {
                                  DismissDirection.startToEnd: context
                                      .watch<ConfigService>()
                                      .deleteSwipeDismissThreshold,
                                },
                                background: Container(
                                  color: Colors.red.shade600,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Eliminar',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                                confirmDismiss: (_) async {
                                  await _deleteConsejo(consejo.codigo!);
                                  return false;
                                },
                                child: Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/consejo_edit',
                                        arguments: consejo,
                                      ).then((result) {
                                        if (result == true) {
                                          _loadConsejos();
                                        }
                                      });
                                    },
                                    onLongPress: () =>
                                        _openConsejoMenu(consejo),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          consejo.imagenMiniatura != null
                                              ? GestureDetector(
                                                  onTap: () async {
                                                    await _openConsejoImageViewer(
                                                      consejo,
                                                    );
                                                  },
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: Image.memory(
                                                      base64Decode(
                                                        consejo
                                                            .imagenMiniatura!,
                                                      ),
                                                      width: 60,
                                                      height: 60,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[300],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child:
                                                      const Icon(Icons.article),
                                                ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  consejo.titulo,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  consejo.texto.length > 60
                                                      ? '${consejo.texto.substring(0, 60)}...'
                                                      : consejo.texto,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.favorite,
                                                      size: 14,
                                                      color: Colors.red[300],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${consejo.totalLikes ?? 0}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Icon(
                                                      Icons.people,
                                                      size: 14,
                                                      color: Colors.blue[300],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      consejo.visibleParaTodos ==
                                                              'S'
                                                          ? 'Todos'
                                                          : '${consejo.totalPacientes ?? 0}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    if (consejo
                                                            .mostrarPortada ==
                                                        'S')
                                                      const Icon(
                                                        Icons.star,
                                                        color: Colors.amber,
                                                        size: 16,
                                                      ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      consejo.activo == 'S'
                                                          ? Icons.check_circle
                                                          : Icons.cancel,
                                                      color:
                                                          consejo.activo == 'S'
                                                              ? Colors.green
                                                              : Colors.red,
                                                      size: 16,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.more_vert,
                                                    ),
                                                    tooltip: 'Más opciones',
                                                    onPressed: () =>
                                                        _openConsejoMenu(
                                                      consejo,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/consejo_edit');
          if (result == true) {
            _loadConsejos();
          }
        },
        tooltip: 'Añadir Consejo',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ImportComparePane extends StatelessWidget {
  final String title;
  final Color color;
  final String text;

  const _ImportComparePane({
    required this.title,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                text.trim().isEmpty ? '(Sin descripción)' : text,
                style: const TextStyle(fontSize: 12, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportAssistantStepCard extends StatelessWidget {
  const _ImportAssistantStepCard({
    required this.title,
    this.child,
  });

  final String title;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (child != null) ...[
            const SizedBox(height: 8),
            child!,
          ],
        ],
      ),
    );
  }
}
