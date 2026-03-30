import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nutri_app/models/charla_seminario.dart';
import 'package:nutri_app/screens/charla_seminario_edit_screen.dart';
import 'package:nutri_app/screens/charla_seminario_detail_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/services/thumbnail_generator.dart';
import 'package:nutri_app/widgets/paste_image_dialog.dart';
import 'package:provider/provider.dart';

enum _OrdenCharlasList { nombre, fechaAlta }

enum _TopActionCharlasList {
  categorias,
  filtrar,
  actualizar,
  ordenarNombre,
  ordenarFecha,
}

class CharlasSeminariosListScreen extends StatefulWidget {
  const CharlasSeminariosListScreen({super.key});

  @override
  State<CharlasSeminariosListScreen> createState() =>
      _CharlasSeminariosListScreenState();
}

class _CharlasSeminariosListScreenState
    extends State<CharlasSeminariosListScreen> {
  List<CharlaSeminario> _items = <CharlaSeminario>[];
  bool _loading = true;
  bool _showFilters = false;
  String _searchQuery = '';
  String _estadoFiltro = 'todos'; // todos | activos | inactivos | portada
  _OrdenCharlasList _orden = _OrdenCharlasList.fechaAlta;
  bool _ordenAscendente = false;
  final TextEditingController _searchCtrl = TextEditingController();

  bool get _canManageCharlas {
    final userType =
        (context.read<AuthService>().userType ?? '').trim().toLowerCase();
    return userType == 'nutricionista' ||
        userType == 'nutritionist' ||
        userType == 'administrador' ||
        userType == 'admin';
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final response = await context.read<ApiService>().get(
            'api/charlas_seminarios.php',
          );
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _items = data
              .map(
                (e) => CharlaSeminario.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(growable: false);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CharlaSeminario> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    final items = _items.where((item) {
      final text = [
        item.titulo,
        item.descripcion,
        item.categoriaNombres.join(' '),
      ].join(' ').toLowerCase();
      final matchQ = q.isEmpty || text.contains(q);
      final matchA = switch (_estadoFiltro) {
        'activos' => item.activo == 'S',
        'inactivos' => item.activo != 'S',
        'portada' => item.mostrarPortada == 'S',
        _ => true,
      };
      return matchQ && matchA;
    }).toList(growable: false);

    int compareByName(CharlaSeminario a, CharlaSeminario b) =>
        a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());

    items.sort((a, b) {
      final byName = compareByName(a, b);
      switch (_orden) {
        case _OrdenCharlasList.nombre:
          return _ordenAscendente ? byName : -byName;
        case _OrdenCharlasList.fechaAlta:
          final dateA = a.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
          final byDate = _ordenAscendente
              ? dateA.compareTo(dateB)
              : dateB.compareTo(dateA);
          return byDate != 0 ? byDate : byName;
      }
    });

    return items;
  }

  void _toggleFiltersVisibility() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void _applySortSelection(_OrdenCharlasList orden) {
    setState(() {
      if (_orden == orden) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _orden = orden;
        _ordenAscendente = orden == _OrdenCharlasList.nombre;
      }
    });
  }

  Future<void> _handleTopAction(_TopActionCharlasList action) async {
    switch (action) {
      case _TopActionCharlasList.categorias:
        await _openCategoriasDialog();
        break;
      case _TopActionCharlasList.filtrar:
        _toggleFiltersVisibility();
        break;
      case _TopActionCharlasList.actualizar:
        await _loadItems();
        break;
      case _TopActionCharlasList.ordenarNombre:
        _applySortSelection(_OrdenCharlasList.nombre);
        break;
      case _TopActionCharlasList.ordenarFecha:
        _applySortSelection(_OrdenCharlasList.fechaAlta);
        break;
    }
  }

  Widget _buildSearchField() {
    final hasSearch = _searchQuery.trim().isNotEmpty;
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Buscar charla…',
        prefixIcon: IconButton(
          tooltip: hasSearch ? 'Limpiar búsqueda' : 'Buscar',
          onPressed: hasSearch
              ? () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                }
              : null,
          icon: Icon(hasSearch ? Icons.clear : Icons.search),
        ),
        suffixIcon: IconButton(
          tooltip: _showFilters
              ? 'Ocultar buscar y filtros'
              : 'Mostrar buscar y filtros',
          onPressed: _toggleFiltersVisibility,
          icon: Icon(
            _showFilters ? Icons.visibility_off_outlined : Icons.visibility,
          ),
        ),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) => setState(() => _searchQuery = v.trim()),
    );
  }

  Future<void> _deleteItem(CharlaSeminario item) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar charla'),
            content: Text('¿Eliminar "${item.titulo}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || item.codigo == null) return;

    final response = await context.read<ApiService>().delete(
          'api/charlas_seminarios.php?codigo=${item.codigo}',
        );
    if (!mounted) return;
    if (response.statusCode == 200) {
      await _loadItems();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Charla eliminada.')));
    }
  }

  Future<void> _openEdit([CharlaSeminario? item]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CharlaSeminarioEditScreen(charla: item),
      ),
    );
    if (result == true) await _loadItems();
  }

  Future<void> _openPreview(CharlaSeminario item) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CharlaSeminarioDetailScreen(charla: item),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadCategoriasCharlas() async {
    final response = await context.read<ApiService>().get(
          'api/charlas_seminarios.php?categorias=1',
        );
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar las categorías.');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Map<int, int> _buildCategoriasUsageCount() {
    final counts = <int, int>{};
    for (final charla in _items) {
      for (final categoriaId in charla.categoriaIds) {
        counts[categoriaId] = (counts[categoriaId] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> _saveCategoriaCharla({
    int? codigo,
    required String nombre,
  }) async {
    final endpoint = codigo == null
        ? 'api/charlas_seminarios.php?categorias=1'
        : 'api/charlas_seminarios.php?categorias=1&codigo=$codigo';
    final body = jsonEncode(<String, dynamic>{'nombre': nombre});
    final response = codigo == null
        ? await context.read<ApiService>().post(endpoint, body: body)
        : await context.read<ApiService>().put(endpoint, body: body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        (jsonDecode(response.body)['message'] ?? 'No se pudo guardar.')
            .toString(),
      );
    }
  }

  Future<void> _deleteCategoriaCharla(int codigo) async {
    final response = await context.read<ApiService>().delete(
          'api/charlas_seminarios.php?categorias=1&codigo=$codigo',
        );
    if (response.statusCode != 200) {
      throw Exception(
        (jsonDecode(response.body)['message'] ?? 'No se pudo eliminar.')
            .toString(),
      );
    }
  }

  Future<void> _openCategoriaEditor({
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

    try {
      await _saveCategoriaCharla(codigo: codigo, nombre: nombre);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              codigo == null ? 'Categoría creada.' : 'Categoría actualizada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadItems();
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

  Future<void> _confirmDeleteCategoria(int codigo, String nombre) async {
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
      await _deleteCategoriaCharla(codigo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categoría eliminada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadItems();
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

  Future<void> _openCategoriaRowMenu({
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
      await _openCategoriaEditor(codigo: codigo, nombreActual: nombre);
    } else if (action == 'delete') {
      await _confirmDeleteCategoria(codigo, nombre);
    }
  }

  Future<void> _openCategoriasDialog() async {
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
                    await _openCategoriaEditor();
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
                future: _loadCategoriasCharlas(),
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
                                    key:
                                        ValueKey('cat_charla_${codigo}_$index'),
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
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                    confirmDismiss: (_) async {
                                      await _confirmDeleteCategoria(
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
                                          await _openCategoriaEditor(
                                            codigo: codigo,
                                            nombreActual: nombre,
                                          );
                                          setLocal(() {});
                                        },
                                        onLongPress: () async {
                                          await _openCategoriaRowMenu(
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
                                              margin: const EdgeInsets.only(
                                                right: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: count > 0
                                                    ? Colors.green
                                                    : Colors.grey.shade500,
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                count.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.more_vert,
                                                size: 20,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
                                              tooltip: 'Más opciones',
                                              onPressed: () async {
                                                await _openCategoriaRowMenu(
                                                  codigo: codigo,
                                                  nombre: nombre,
                                                );
                                                setLocal(() {});
                                              },
                                            ),
                                            const SizedBox(width: 4),
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

    if (!mounted) return;
    await _loadItems();
  }

  Future<void> _openItemMenu(CharlaSeminario item) async {
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
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Visualizar'),
              onTap: () => Navigator.pop(ctx, 'preview'),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Pegar imagen'),
              onTap: () => Navigator.pop(ctx, 'paste_image'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await _openEdit(item);
    } else if (action == 'preview') {
      await _openPreview(item);
    } else if (action == 'paste_image') {
      await _showPasteImageDialog(item);
    } else if (action == 'delete') {
      await _deleteItem(item);
    }
  }

  Future<void> _showPasteImageDialog(CharlaSeminario item) async {
    final bytes = await showPasteImageDialog(
      context,
      title: 'Pegar imagen',
      description:
          'Genera la imagen en formato base64 o copiala directamente al portapapeles y pulsa en pegar para agregarla a la charla.',
    );
    if (bytes == null) return;

    try {
      final miniatura = ThumbnailGenerator.generateThumbnail(bytes);
      final payload = <String, dynamic>{
        'codigo': item.codigo,
        'titulo': item.titulo,
        'descripcion': item.descripcion,
        'activo': item.activo,
        'mostrar_portada': item.mostrarPortada,
        'visible_para_todos': item.visibleParaTodos,
        'imagen_portada': base64Encode(bytes),
        'imagen_portada_nombre': 'base64',
        'imagen_miniatura': miniatura != null ? base64Encode(miniatura) : '',
        'categorias': item.categoriaIds,
      };

      final response = await context.read<ApiService>().put(
            'api/charlas_seminarios.php',
            body: jsonEncode(payload),
          );

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadItems();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen aplicada a la charla.'),
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

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Charlas'),
        actions: [
          if (_canManageCharlas)
            IconButton(
              tooltip: 'Categorías de charlas',
              onPressed: _openCategoriasDialog,
              icon: const Icon(Icons.category),
            ),
          IconButton(
            tooltip: _showFilters ? 'Ocultar buscar y filtros' : 'Filtrar',
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            onPressed: _toggleFiltersVisibility,
          ),
          PopupMenuButton<_TopActionCharlasList>(
            tooltip: 'Más opciones',
            onSelected: _handleTopAction,
            itemBuilder: (_) {
              final items = <PopupMenuEntry<_TopActionCharlasList>>[];
              if (_canManageCharlas) {
                items.add(
                  const PopupMenuItem<_TopActionCharlasList>(
                    value: _TopActionCharlasList.categorias,
                    child: Row(
                      children: [
                        Icon(Icons.category, size: 18),
                        SizedBox(width: 10),
                        Text('Categorías'),
                      ],
                    ),
                  ),
                );
              }
              items.addAll([
                const PopupMenuItem<_TopActionCharlasList>(
                  value: _TopActionCharlasList.filtrar,
                  child: Row(
                    children: [
                      Icon(Icons.filter_alt, size: 18),
                      SizedBox(width: 10),
                      Text('Filtrar'),
                    ],
                  ),
                ),
                const PopupMenuItem<_TopActionCharlasList>(
                  value: _TopActionCharlasList.actualizar,
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 18),
                      SizedBox(width: 10),
                      Text('Actualizar'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                CheckedPopupMenuItem<_TopActionCharlasList>(
                  value: _TopActionCharlasList.ordenarNombre,
                  checked: _orden == _OrdenCharlasList.nombre,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Ordenar Título')),
                      if (_orden == _OrdenCharlasList.nombre)
                        Icon(
                          _ordenAscendente
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                        ),
                    ],
                  ),
                ),
                CheckedPopupMenuItem<_TopActionCharlasList>(
                  value: _TopActionCharlasList.ordenarFecha,
                  checked: _orden == _OrdenCharlasList.fechaAlta,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Ordenar Recientes')),
                      if (_orden == _OrdenCharlasList.fechaAlta)
                        Icon(
                          _ordenAscendente
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                        ),
                    ],
                  ),
                ),
              ]);
              return items;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  _buildSearchField(),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Todas'),
                          selected: _estadoFiltro == 'todos',
                          onSelected: (v) {
                            if (v) setState(() => _estadoFiltro = 'todos');
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Activas'),
                          selected: _estadoFiltro == 'activos',
                          onSelected: (v) {
                            if (v) setState(() => _estadoFiltro = 'activos');
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Inactivas'),
                          selected: _estadoFiltro == 'inactivos',
                          onSelected: (v) {
                            if (v) setState(() => _estadoFiltro = 'inactivos');
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Portada'),
                          selected: _estadoFiltro == 'portada',
                          onSelected: (v) {
                            if (v) setState(() => _estadoFiltro = 'portada');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.present_to_all_rounded,
                              size: 56,
                              color: Colors.black26,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Sin resultados.'
                                  : 'No hay charlas/seminarios.',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadItems,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: items.length,
                          itemBuilder: (context, index) =>
                              _buildItem(items[index]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _canManageCharlas
          ? FloatingActionButton(
              tooltip: 'Nueva charla',
              onPressed: () => _openEdit(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildItem(CharlaSeminario item) {
    final thumbBytes = item.imagenMiniatura ?? item.imagenPortada;
    Widget? leading;
    if (thumbBytes != null && thumbBytes.isNotEmpty) {
      try {
        leading = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(thumbBytes),
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }
    leading ??= Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.present_to_all_rounded,
        color: Colors.deepPurple,
      ),
    );

    return Dismissible(
      key: ValueKey('charla_${item.codigo ?? item.titulo}'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: {
        DismissDirection.startToEnd:
            context.watch<ConfigService>().deleteSwipeDismissThreshold,
      },
      confirmDismiss: (_) async {
        await _deleteItem(item);
        return false;
      },
      background: Container(
        color: Colors.red.shade600,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Eliminar', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          onTap: () => _openEdit(item),
          onLongPress: () => _openItemMenu(item),
          leading: leading,
          title:
              Text(item.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.descripcion.isNotEmpty)
                Text(
                  item.descripcion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              Row(
                children: [
                  const Icon(
                    Icons.view_carousel_outlined,
                    size: 13,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${item.totalDiapositivas} diap.',
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  if (item.activo != 'S') ...[
                    const SizedBox(width: 8),
                    const Text(
                      'Inactivo',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
