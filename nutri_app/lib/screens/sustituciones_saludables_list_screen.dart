import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:nutri_app/models/sustitucion_saludable.dart';
import 'package:nutri_app/screens/sustitucion_saludable_edit_screen.dart';
import 'package:nutri_app/screens/sustituciones_saludables_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/utils/sustituciones_saludables_ai.dart';
import 'package:nutri_app/services/thumbnail_generator.dart';
import 'package:nutri_app/widgets/paste_image_dialog.dart';
import 'package:provider/provider.dart';

enum _SustitucionesTopAction {
  buscar,
  categorias,
  filtrar,
  imagenesCategorias,
  autoAsignacion,
  pegarIa,
  copiarIa,
  actualizar,
  sortNombre,
  sortFechaAlta,
  sortLikes,
  sortCategoria,
}

enum _OrdenSustituciones { nombre, fechaAlta, likes, categoria }

class SustitucionesSaludablesListScreen extends StatefulWidget {
  const SustitucionesSaludablesListScreen({super.key});

  @override
  State<SustitucionesSaludablesListScreen> createState() =>
      _SustitucionesSaludablesListScreenState();
}

class _SustitucionesSaludablesListScreenState
    extends State<SustitucionesSaludablesListScreen> {
  static const int _pageSize = 20;
  static const String _prefSearchVisibleKey = 'sustituciones_search_visible';
  static const String _prefCategoryFilterKey = 'sustituciones_category_filter';
  static const String _prefActivoFilterKey = 'sustituciones_activo_filter';
  static const String _prefPortadaFilterKey = 'sustituciones_portada_filter';
  static const String _prefOrdenKey = 'sustituciones_orden';
  static const String _prefOrdenAscKey = 'sustituciones_orden_asc';

  final ImagePicker _picker = ImagePicker();
  Timer? _searchDebounce;
  late TextEditingController _searchController;

  List<SustitucionSaludable> _items = <SustitucionSaludable>[];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _searchVisible = false;
  int _totalFilteredCount = 0;
  String _searchQuery = '';
  bool _activoActivas = true;
  bool _activoInactivas = true;
  bool _portadaFilter = false;
  Set<int> _categoriaFilter = {};
  List<Map<String, dynamic>> _categoryFilters = <Map<String, dynamic>>[];
  String _aiPrompt = defaultSustitucionesSaludablesAIPrompt;
  _OrdenSustituciones _ordenSustituciones = _OrdenSustituciones.nombre;
  bool _ordenAscendente = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadPrefs();
    _loadAIPrompt();
    _loadCategoryFilters();
    _loadItems(reset: true);
  }

  Future<void> _loadCategoryFilters() async {
    try {
      final categorias = await _fetchCategorias(includeInactive: true);
      if (!mounted) return;
      final validCategoryIds = categorias
          .map((item) => int.tryParse(item['codigo'].toString()))
          .whereType<int>()
          .toSet();
      final invalidCategories = _categoriaFilter
          .where((id) => !validCategoryIds.contains(id))
          .toList();
      setState(() {
        _categoryFilters = categorias;
        if (invalidCategories.isNotEmpty) {
          _categoriaFilter.removeWhere((id) => invalidCategories.contains(id));
        }
      });
      if (invalidCategories.isNotEmpty) {
        SharedPreferences.getInstance().then((p) => _saveCategoryFilter(p));
      }
    } catch (_) {
      // Si falla la carga, se mantiene sin filtros de categoría.
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _searchVisible = prefs.getBool(_prefSearchVisibleKey) ?? false;
      final storedActivo = prefs.getString(_prefActivoFilterKey) ?? 'SN';
      _activoActivas = storedActivo.contains('S');
      _activoInactivas = storedActivo.contains('N');
      _portadaFilter = prefs.getBool(_prefPortadaFilterKey) ?? false;
      final storedCategories = prefs.getString(_prefCategoryFilterKey) ?? '';
      _categoriaFilter = storedCategories.isEmpty
          ? <int>{}
          : storedCategories
              .split(',')
              .map((s) => int.tryParse(s))
              .whereType<int>()
              .toSet();
      final storedOrden = prefs.getInt(_prefOrdenKey);
      _ordenSustituciones = storedOrden != null &&
              storedOrden >= 0 &&
              storedOrden < _OrdenSustituciones.values.length
          ? _OrdenSustituciones.values[storedOrden]
          : _OrdenSustituciones.nombre;
      _ordenAscendente = prefs.getBool(_prefOrdenAscKey) ?? true;
    });
  }

  Future<void> _saveSortPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefOrdenKey, _ordenSustituciones.index);
    await prefs.setBool(_prefOrdenAscKey, _ordenAscendente);
  }

  Future<void> _applySortSelection(_OrdenSustituciones orden) async {
    if (!mounted) return;
    setState(() {
      if (_ordenSustituciones == orden) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _ordenSustituciones = orden;
        _ordenAscendente = orden == _OrdenSustituciones.nombre;
      }
    });
    await _saveSortPrefs();
  }

  int get _selectedCategoryCount => _categoriaFilter.length;

  void _saveCategoryFilter(SharedPreferences prefs) {
    if (_categoriaFilter.isEmpty) {
      prefs.remove(_prefCategoryFilterKey);
    } else {
      prefs.setString(_prefCategoryFilterKey, _categoriaFilter.join(','));
    }
  }

  Future<void> _showSustitucionesFilterDialog() async {
    if (_categoryFilters.isEmpty) {
      await _loadCategoryFilters();
    }
    if (!mounted) return;

    bool tempActivoActivas = _activoActivas;
    bool tempActivoInactivas = _activoInactivas;
    bool tempPortada = _portadaFilter;
    Set<int> tempCategorias = {..._categoriaFilter};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedCategoryCount = tempCategorias.length;
          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtrar sustituciones',
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.68,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Activas'),
                            selected: tempActivoActivas,
                            onSelected: (selected) {
                              setDialogState(
                                  () => tempActivoActivas = selected);
                            },
                          ),
                          FilterChip(
                            label: const Text('Inactivas'),
                            selected: tempActivoInactivas,
                            onSelected: (selected) {
                              setDialogState(
                                  () => tempActivoInactivas = selected);
                            },
                          ),
                          FilterChip(
                            label: const Text('Portada'),
                            selected: tempPortada,
                            onSelected: (selected) {
                              setDialogState(() => tempPortada = selected);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      const Text(
                        'Categorías',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.of(context).size.height * 0.22,
                          ),
                          child: Scrollbar(
                            thumbVisibility: _categoryFilters.length > 8,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _categoryFilters.map((categoria) {
                                  final id = int.tryParse(
                                      categoria['codigo'].toString());
                                  if (id == null) {
                                    return const SizedBox.shrink();
                                  }
                                  final nombre =
                                      categoria['nombre']?.toString() ?? '';
                                  final activo = (categoria['activo']
                                              ?.toString()
                                              .toUpperCase() ??
                                          'S') ==
                                      'S';
                                  final label =
                                      activo ? nombre : '$nombre (Inac)';

                                  return FilterChip(
                                    label: Text(label),
                                    selected: tempCategorias.contains(id),
                                    onSelected: (selected) {
                                      setDialogState(() {
                                        if (selected) {
                                          tempCategorias.add(id);
                                        } else {
                                          tempCategorias.remove(id);
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
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  setState(() {
                    _activoActivas = true;
                    _activoInactivas = true;
                    _portadaFilter = false;
                    _categoriaFilter.clear();
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(_prefActivoFilterKey, 'SN');
                  await prefs.remove(_prefPortadaFilterKey);
                  await prefs.remove(_prefCategoryFilterKey);
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await _loadItems(reset: true);
                },
                child: const Text('Limpiar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _activoActivas = tempActivoActivas;
                    _activoInactivas = tempActivoInactivas;
                    _portadaFilter = tempPortada;
                    _categoriaFilter = tempCategorias;
                  });
                  final prefs = await SharedPreferences.getInstance();
                  final activoStr =
                      '${tempActivoActivas ? 'S' : ''}${tempActivoInactivas ? 'N' : ''}';
                  if (activoStr.isNotEmpty) {
                    await prefs.setString(_prefActivoFilterKey, activoStr);
                  } else {
                    await prefs.setString(_prefActivoFilterKey, 'SN');
                  }
                  if (tempPortada) {
                    await prefs.setBool(_prefPortadaFilterKey, true);
                  } else {
                    await prefs.remove(_prefPortadaFilterKey);
                  }
                  _saveCategoryFilter(prefs);
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await _loadItems(reset: true);
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
                        color: selectedCategoryCount > 0
                            ? Colors.blue
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$selectedCategoryCount',
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
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

  void _scheduleReload() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      _loadItems(reset: true);
    });
  }

  Future<void> _loadAIPrompt() async {
    try {
      final valor = await context
          .read<ApiService>()
          .getParametroValor('ia_prompt_sustituciones_saludables');
      if (valor != null && valor.isNotEmpty && mounted) {
        setState(() => _aiPrompt = valor);
      }
    } catch (_) {
      // Mantiene el prompt por defecto si no existe el parámetro.
    }
  }

  Future<void> _loadItems({bool reset = false}) async {
    final offset = reset ? 0 : _items.length;
    if (!reset && (_loading || _loadingMore || !_hasMore)) {
      return;
    }

    setState(() {
      if (reset) {
        _loading = true;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      if (reset) {
        await _loadTotalFilteredCount();
      }

      final response = await context.read<ApiService>().get(
            _buildApiPath('api/sustituciones_saludables.php', {
              'limit': '$_pageSize',
              'offset': '$offset',
              'q': _searchQuery.trim(),
              'activo': (_activoActivas && _activoInactivas)
                  ? null
                  : (_activoActivas
                      ? 'S'
                      : _activoInactivas
                          ? 'N'
                          : null),
              'portada': _portadaFilter ? 'S' : null,
              'categoria':
                  _categoriaFilter.isEmpty ? null : _categoriaFilter.join(','),
            }),
          );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        if (!mounted) return;
        final items = data
            .map((item) => SustitucionSaludable.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(growable: false);
        setState(() {
          _items = reset ? items : <SustitucionSaludable>[..._items, ...items];
          _hasMore = items.length >= _pageSize;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadTotalFilteredCount() async {
    try {
      final response = await context.read<ApiService>().get(
            _buildApiPath('api/sustituciones_saludables.php', {
              'total': '1',
              'q': _searchQuery.trim(),
              'activo': (_activoActivas && _activoInactivas)
                  ? null
                  : (_activoActivas
                      ? 'S'
                      : _activoInactivas
                          ? 'N'
                          : null),
              'portada': _portadaFilter ? 'S' : null,
              'categoria':
                  _categoriaFilter.isEmpty ? null : _categoriaFilter.join(','),
            }),
          );
      if (response.statusCode != 200 || !mounted) return;

      final data = jsonDecode(response.body);
      final total = int.tryParse((data['total'] ?? '0').toString()) ?? 0;
      if (!mounted) return;
      setState(() => _totalFilteredCount = total);
    } catch (_) {
      // Mantener el último total válido sin interrumpir la carga.
    }
  }

  List<SustitucionSaludable> get _filtered {
    final items = List<SustitucionSaludable>.from(_items);

    int compareByName(SustitucionSaludable a, SustitucionSaludable b) =>
        a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());

    int compareByCategoria(SustitucionSaludable a, SustitucionSaludable b) {
      final catA = (a.categoriaNombres.isNotEmpty ? a.categoriaNombres[0] : '')
          .toLowerCase();
      final catB = (b.categoriaNombres.isNotEmpty ? b.categoriaNombres[0] : '')
          .toLowerCase();
      final byCat = catA.compareTo(catB);
      return byCat != 0 ? byCat : compareByName(a, b);
    }

    items.sort((a, b) {
      final byName = compareByName(a, b);
      switch (_ordenSustituciones) {
        case _OrdenSustituciones.nombre:
          return _ordenAscendente ? byName : -byName;
        case _OrdenSustituciones.fechaAlta:
          final dateA = a.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
          final byDate = _ordenAscendente
              ? dateA.compareTo(dateB)
              : dateB.compareTo(dateA);
          return byDate != 0 ? byDate : byName;
        case _OrdenSustituciones.likes:
          final byLikes = _ordenAscendente
              ? a.totalLikes.compareTo(b.totalLikes)
              : b.totalLikes.compareTo(a.totalLikes);
          return byLikes != 0 ? byLikes : byName;
        case _OrdenSustituciones.categoria:
          return _ordenAscendente
              ? compareByCategoria(a, b)
              : -compareByCategoria(a, b);
      }
    });

    return items;
  }

  Future<void> _deleteItem(SustitucionSaludable item) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminar sustitución'),
            content: Text('¿Eliminar "${item.titulo}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || item.codigo == null) {
      return;
    }

    final response = await context.read<ApiService>().delete(
          'api/sustituciones_saludables.php?codigo=${item.codigo}',
        );
    if (!mounted) return;
    if (response.statusCode == 200) {
      await _loadItems(reset: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sustitución eliminada.')),
      );
    }
  }

  Future<void> _openEdit([SustitucionSaludable? item]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => SustitucionSaludableEditScreen(item: item),
      ),
    );
    if (result == true) {
      await _loadItems(reset: true);
    }
  }

  Future<void> _openPreview(SustitucionSaludable item) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SustitucionSaludableDetailScreen(item: item),
      ),
    );
  }

  Future<void> _openItemMenu(SustitucionSaludable item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Visualizar'),
              onTap: () => Navigator.pop(ctx, 'preview'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(ctx, 'edit'),
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
    if (action == 'preview') {
      await _openPreview(item);
    } else if (action == 'edit') {
      await _openEdit(item);
    } else if (action == 'paste_image') {
      await _showPasteImageDialog(item);
    } else if (action == 'delete') {
      await _deleteItem(item);
    }
  }

  Future<void> _showPasteImageDialog(SustitucionSaludable item) async {
    final bytes = await showPasteImageDialog(
      context,
      title: 'Pegar imagen',
      description:
          'Genera la imagen en formato base64 o copiala directamente al portapapeles y pulsa en pegar para agregarla a la sustitución.',
    );
    if (bytes == null) return;

    try {
      final miniatura = ThumbnailGenerator.generateThumbnail(bytes);
      final payload = <String, dynamic>{
        'codigo': item.codigo,
        'titulo': item.titulo,
        'subtitulo': item.subtitulo,
        'alimento_origen': item.alimentoOrigen,
        'sustituto_principal': item.sustitutoPrincipal,
        'equivalencia_texto': item.equivalenciaTexto,
        'objetivo_macro': item.objetivoMacro,
        'texto': item.texto,
        'activo': item.activo,
        'mostrar_portada': item.mostrarPortada,
        'visible_para_todos': item.visibleParaTodos,
        'imagen_portada': base64Encode(bytes),
        'imagen_portada_nombre': 'base64',
        'imagen_miniatura': miniatura != null ? base64Encode(miniatura) : '',
        'categorias': item.categoriaIds,
      };

      final response = await context.read<ApiService>().put(
            'api/sustituciones_saludables.php',
            body: jsonEncode(payload),
          );

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadItems(reset: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen aplicada a la sustitución.'),
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

  int _estimateImportOmissions(List<SustitucionSaludableImportDraft> drafts) {
    final seenTitles = _items
        .map((item) => normalizeSustitucionSaludableTitle(item.titulo))
        .where((title) => title.isNotEmpty)
        .toSet();
    var omitted = 0;

    for (final draft in drafts) {
      final title = normalizeSustitucionSaludableTitle(draft.titulo);
      if (title.isEmpty || !seenTitles.add(title)) {
        omitted += 1;
      }
    }

    return omitted;
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
                'Copia este prompt y pégalo en tu IA favorita para generar '
                'sustituciones saludables con el formato compatible:',
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

  Future<List<Map<String, dynamic>>> _fetchCategorias({
    bool includeInactive = false,
  }) async {
    final response = await context.read<ApiService>().get(
          includeInactive
              ? 'api/sustituciones_saludables.php?categorias=1&todos=1'
              : 'api/sustituciones_saludables.php?categorias=1',
        );
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar las categorías.');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<int?> _createCategoriaSuggestion(String nombre) async {
    final response = await context.read<ApiService>().post(
          'api/sustituciones_saludables.php?categorias=1',
          body: jsonEncode(<String, dynamic>{'nombre': nombre}),
        );
    if (response.statusCode != 200 && response.statusCode != 201) {
      return null;
    }
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return int.tryParse(data['codigo'].toString());
  }

  Future<bool> _updateCategoria(Map<String, dynamic> payload) async {
    final response = await context.read<ApiService>().put(
          'api/sustituciones_saludables.php?categorias=1',
          body: jsonEncode(payload),
        );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<void> _deleteCategoriaSuggestion(int codigo) async {
    final response = await context.read<ApiService>().delete(
          'api/sustituciones_saludables.php?categorias=1&codigo=$codigo',
        );
    if (response.statusCode == 200) {
      return;
    }

    String message = 'No se pudo eliminar la categoría.';
    try {
      final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      final serverMessage = data['message']?.toString();
      if (serverMessage != null && serverMessage.trim().isNotEmpty) {
        message = serverMessage;
      }
    } catch (_) {}

    throw Exception(message);
  }

  Future<void> _showCategoriasManager() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SustitucionCategoriasManagerDialog(
        onLoadCategorias: _fetchCategorias,
        onCreateCategoria: _createCategoriaSuggestion,
        onUpdateCategoria: _updateCategoria,
        onDeleteCategoria: _deleteCategoriaSuggestion,
        onReloadItems: () => _loadItems(reset: true),
      ),
    );
    await _loadCategoryFilters();
  }

  void _toggleSearch() {
    final next = !_searchVisible;
    setState(() {
      _searchVisible = next;
      if (!next) {
        _searchQuery = '';
        _searchController.clear();
        _loadItems(reset: true);
      }
    });
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_prefSearchVisibleKey, next));
  }

  void _toggleSearchAndFilterVisibility() {
    _toggleSearch();
  }

  void _copiarAIPrompt() {
    Clipboard.setData(ClipboardData(text: _aiPrompt));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prompt copiado al portapapeles.'),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  Future<void> _handleTopAction(_SustitucionesTopAction action) async {
    switch (action) {
      case _SustitucionesTopAction.buscar:
        _toggleSearchAndFilterVisibility();
        break;
      case _SustitucionesTopAction.categorias:
        await _showCategoriasManager();
        break;
      case _SustitucionesTopAction.filtrar:
        await _showSustitucionesFilterDialog();
        break;
      case _SustitucionesTopAction.imagenesCategorias:
        await _showCategoryImageManager();
        break;
      case _SustitucionesTopAction.autoAsignacion:
        await _showAutoAssignCategoriesAssistant();
        break;
      case _SustitucionesTopAction.pegarIa:
        await _showImportAssistant();
        break;
      case _SustitucionesTopAction.copiarIa:
        _copiarAIPrompt();
        break;
      case _SustitucionesTopAction.actualizar:
        await _loadItems(reset: true);
        break;
      case _SustitucionesTopAction.sortNombre:
        await _applySortSelection(_OrdenSustituciones.nombre);
        break;
      case _SustitucionesTopAction.sortFechaAlta:
        await _applySortSelection(_OrdenSustituciones.fechaAlta);
        break;
      case _SustitucionesTopAction.sortLikes:
        await _applySortSelection(_OrdenSustituciones.likes);
        break;
      case _SustitucionesTopAction.sortCategoria:
        await _applySortSelection(_OrdenSustituciones.categoria);
        break;
    }
  }

  Future<SustitucionSaludable?> _fetchItemDetail(int codigo) async {
    final response = await context
        .read<ApiService>()
        .get('api/sustituciones_saludables.php?codigo=$codigo');
    if (response.statusCode != 200) {
      return null;
    }
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return SustitucionSaludable.fromJson(data);
  }

  Future<void> _showAutoAssignCategoriesAssistant() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _AutoAssignCategoriesDialog(
        items: _items,
        onLoadCategorias: _fetchCategorias,
        onCreateCategoria: _createCategoriaSuggestion,
        onLoadItemDetail: _fetchItemDetail,
        onReloadItems: () => _loadItems(reset: true),
      ),
    );
  }

  Future<void> _showCategoryImageManager() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CategoryImageManagerDialog(
        onLoadCategorias: _fetchCategorias,
        onUpdateCategoria: _updateCategoria,
        onReloadItems: () => _loadItems(reset: true),
        picker: _picker,
      ),
    );
  }

  Future<void> _showImportAssistant() async {
    var detected = <SustitucionSaludableImportDraft>[];
    var analyzing = false;
    var importing = false;
    var importFinished = false;
    var importedCount = 0;
    var omittedCount = 0;
    var processedCount = 0;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final estimatedOmissions = _estimateImportOmissions(detected);
          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            title: Row(
              children: [
                const Icon(Icons.content_paste_rounded,
                    color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Importar sustituciones con IA',
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
                    _ImportAssistantStepCard(
                      title:
                          'Paso 1: Genera sustituciones saludables con el formato de importación',
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
                      title:
                          'Paso 2: Copia todas las sustituciones saludables.',
                    ),
                    const SizedBox(height: 12),
                    _ImportAssistantStepCard(
                      title:
                          'Paso 3: Pega las sustituciones saludables, pulsando en "Pegar".',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilledButton.icon(
                            onPressed: analyzing || importing
                                ? null
                                : () async {
                                    setDialogState(() {
                                      analyzing = true;
                                      importFinished = false;
                                      importedCount = 0;
                                      omittedCount = 0;
                                      processedCount = 0;
                                      errorText = null;
                                      detected =
                                          <SustitucionSaludableImportDraft>[];
                                    });

                                    final data = await Clipboard.getData(
                                      Clipboard.kTextPlain,
                                    );
                                    final text = data?.text ?? '';
                                    final parsed =
                                        parseSustitucionesSaludablesFromAI(
                                            text);

                                    if (!mounted) return;
                                    setDialogState(() {
                                      analyzing = false;
                                      detected = parsed;
                                      if (text.trim().isEmpty) {
                                        errorText =
                                            'El portapapeles está vacío.';
                                      } else if (parsed.isEmpty) {
                                        errorText =
                                            'No se detectaron sustituciones saludables con el formato de importación.';
                                      }
                                    });
                                  },
                            icon: analyzing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.content_paste_go_rounded),
                            label: const Text('Pegar sustituciones'),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ImportAssistantStepCard(
                      title: detected.isEmpty
                          ? 'Paso 4: Se mostrarán aquí las sustituciones detectadas para importarlas.'
                          : 'Paso 4: Se han obtenido ${detected.length} sustituciones saludables.',
                      child: detected.isEmpty
                          ? null
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (estimatedOmissions > 0)
                                  Text(
                                    '$estimatedOmissions se omitirán por tener el mismo título.',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (estimatedOmissions > 0)
                                  const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: importing
                                      ? null
                                      : () async {
                                          final existingTitles = _items
                                              .map((item) =>
                                                  normalizeSustitucionSaludableTitle(
                                                    item.titulo,
                                                  ))
                                              .where(
                                                  (title) => title.isNotEmpty)
                                              .toSet();
                                          var hasServerErrors = false;

                                          setDialogState(() {
                                            importing = true;
                                            importFinished = false;
                                            importedCount = 0;
                                            omittedCount = 0;
                                            processedCount = 0;
                                            errorText = null;
                                          });

                                          for (final draft in detected) {
                                            final normalizedTitle =
                                                normalizeSustitucionSaludableTitle(
                                              draft.titulo,
                                            );

                                            if (normalizedTitle.isEmpty ||
                                                !existingTitles.add(
                                                  normalizedTitle,
                                                )) {
                                              omittedCount += 1;
                                              processedCount += 1;
                                              if (mounted) {
                                                setDialogState(() {});
                                              }
                                              continue;
                                            }

                                            try {
                                              final response = await context
                                                  .read<ApiService>()
                                                  .post(
                                                    'api/sustituciones_saludables.php',
                                                    body: jsonEncode(
                                                      draft.toCreatePayload(),
                                                    ),
                                                  );
                                              if (response.statusCode == 200 ||
                                                  response.statusCode == 201) {
                                                importedCount += 1;
                                              } else {
                                                omittedCount += 1;
                                                hasServerErrors = true;
                                                existingTitles.remove(
                                                  normalizedTitle,
                                                );
                                              }
                                            } catch (_) {
                                              omittedCount += 1;
                                              hasServerErrors = true;
                                              existingTitles.remove(
                                                normalizedTitle,
                                              );
                                            }

                                            processedCount += 1;
                                            if (mounted) {
                                              setDialogState(() {});
                                            }
                                          }

                                          await _loadItems(reset: true);
                                          if (!mounted) return;
                                          setDialogState(() {
                                            importing = false;
                                            importFinished = true;
                                            if (hasServerErrors) {
                                              errorText =
                                                  'Alguna sustitución no se pudo guardar y se ha contabilizado como omitida.';
                                            }
                                          });
                                        },
                                  icon: importing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.cloud_upload_outlined),
                                  label: const Text('Importar sustituciones'),
                                ),
                                if (importing) ...[
                                  const SizedBox(height: 12),
                                  LinearProgressIndicator(
                                    value: detected.isEmpty
                                        ? null
                                        : processedCount / detected.length,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Progreso: $processedCount de ${detected.length}',
                                  ),
                                ],
                                if (importFinished) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Se han importado $importedCount sustituciones saludables',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Se han omitido $omittedCount sustituciones saludables',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sustituciones',
              overflow: TextOverflow.ellipsis,
            ),
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
                '$_totalFilteredCount',
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
            tooltip: _searchVisible ? 'Ocultar buscar' : 'Buscar',
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
            onPressed: () => _toggleSearchAndFilterVisibility(),
          ),
          IconButton(
            tooltip: _selectedCategoryCount == 0
                ? 'Filtrar'
                : 'Filtrar (${_selectedCategoryCount})',
            onPressed: () => _handleTopAction(_SustitucionesTopAction.filtrar),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_alt_outlined),
                if (_selectedCategoryCount > 0)
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
                        '$_selectedCategoryCount',
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
          PopupMenuButton<_SustitucionesTopAction>(
            tooltip: 'Más opciones',
            onSelected: _handleTopAction,
            itemBuilder: (context) => [
              PopupMenuItem<_SustitucionesTopAction>(
                value: _SustitucionesTopAction.buscar,
                child: Row(
                  children: [
                    Icon(
                      _searchVisible ? Icons.search_off : Icons.search,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(_searchVisible ? 'Ocultar buscar' : 'Buscar'),
                  ],
                ),
              ),
              PopupMenuItem<_SustitucionesTopAction>(
                value: _SustitucionesTopAction.filtrar,
                child: ListTile(
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(width: 18, height: 18),
                      const Icon(Icons.filter_alt, size: 18),
                      if (_selectedCategoryCount > 0)
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
                              '$_selectedCategoryCount',
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
              const PopupMenuItem<_SustitucionesTopAction>(
                value: _SustitucionesTopAction.categorias,
                child: Row(
                  children: [
                    Icon(Icons.category_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Categorías'),
                  ],
                ),
              ),
              const PopupMenuItem<_SustitucionesTopAction>(
                child: Row(
                  children: [
                    Icon(Icons.image_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Imágenes categorías'),
                  ],
                ),
              ),
              const PopupMenuItem<_SustitucionesTopAction>(
                value: _SustitucionesTopAction.autoAsignacion,
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Autoasignar categorías'),
                  ],
                ),
              ),
              const PopupMenuItem<_SustitucionesTopAction>(
                value: _SustitucionesTopAction.pegarIa,
                child: Row(
                  children: [
                    Icon(Icons.psychology_alt_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Pegar IA'),
                  ],
                ),
              ),
              const PopupMenuItem<_SustitucionesTopAction>(
                value: _SustitucionesTopAction.copiarIa,
                child: Row(
                  children: [
                    Icon(Icons.psychology, size: 18),
                    SizedBox(width: 10),
                    Text('Copiar IA'),
                  ],
                ),
              ),
              const PopupMenuItem<_SustitucionesTopAction>(
                value: _SustitucionesTopAction.actualizar,
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 10),
                    Text('Actualizar'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem<_SustitucionesTopAction>(
                value: _SustitucionesTopAction.sortNombre,
                checked: _ordenSustituciones == _OrdenSustituciones.nombre,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Nombre')),
                    if (_ordenSustituciones == _OrdenSustituciones.nombre)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<_SustitucionesTopAction>(
                value: _SustitucionesTopAction.sortFechaAlta,
                checked: _ordenSustituciones == _OrdenSustituciones.fechaAlta,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Recientes')),
                    if (_ordenSustituciones == _OrdenSustituciones.fechaAlta)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<_SustitucionesTopAction>(
                value: _SustitucionesTopAction.sortLikes,
                checked: _ordenSustituciones == _OrdenSustituciones.likes,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar likes')),
                    if (_ordenSustituciones == _OrdenSustituciones.likes)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<_SustitucionesTopAction>(
                value: _SustitucionesTopAction.sortCategoria,
                checked: _ordenSustituciones == _OrdenSustituciones.categoria,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar categoría')),
                    if (_ordenSustituciones == _OrdenSustituciones.categoria)
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
      body: Column(
        children: [
          if (_searchVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar sustituciones',
                  prefixIcon: IconButton(
                    tooltip:
                        _searchQuery.isNotEmpty ? 'Limpiar búsqueda' : 'Buscar',
                    onPressed: _searchQuery.isNotEmpty
                        ? () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _scheduleReload();
                          }
                        : null,
                    icon: Icon(
                        _searchQuery.isNotEmpty ? Icons.clear : Icons.search),
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Ocultar búsqueda',
                    onPressed: _toggleSearchAndFilterVisibility,
                    icon: const Icon(Icons.visibility_off_outlined),
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim());
                  _scheduleReload();
                },
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? const Center(
                        child: Text('No hay sustituciones para mostrar.'))
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (_hasMore &&
                              !_loadingMore &&
                              notification.metrics.pixels >=
                                  notification.metrics.maxScrollExtent - 300) {
                            _loadItems();
                          }
                          return false;
                        },
                        child: RefreshIndicator(
                          onRefresh: () => _loadItems(reset: true),
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 88),
                            itemCount: items.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= items.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final item = items[index];
                              final thumb = (item.imagenMiniatura ?? '').trim();
                              return Dismissible(
                                key: ValueKey('sust_${item.codigo}'),
                                direction: DismissDirection.startToEnd,
                                dismissThresholds: {
                                  DismissDirection.startToEnd: context
                                      .watch<ConfigService>()
                                      .deleteSwipeDismissThreshold,
                                },
                                confirmDismiss: (_) async {
                                  await _deleteItem(item);
                                  return false;
                                },
                                background: Container(
                                  color: Colors.red.shade600,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text('Eliminar',
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                                child: Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: ListTile(
                                    onTap: () => _openEdit(item),
                                    onLongPress: () => _openItemMenu(item),
                                    leading: thumb.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.memory(
                                              base64Decode(thumb),
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.swap_horiz),
                                          ),
                                    title: Text(item.titulo),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.alimentoOrigen} -> ${item.sustitutoPrincipal}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              item.activo == 'S'
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              size: 16,
                                              color: item.activo == 'S'
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(item.activo == 'S'
                                                ? 'Activo'
                                                : 'Inactivo'),
                                            const SizedBox(width: 12),
                                            if (item.mostrarPortada == 'S')
                                              const Icon(
                                                Icons.star,
                                                size: 16,
                                                color: Colors.amber,
                                              ),
                                            if (item.mostrarPortada == 'S')
                                              const SizedBox(width: 4),
                                            if (item.mostrarPortada == 'S')
                                              const Text('Portada'),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.more_vert),
                                      tooltip: 'Más opciones',
                                      onPressed: () => _openItemMenu(item),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEdit(),
        child: const Icon(Icons.add),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (child != null) ...[
            const SizedBox(height: 10),
            child!,
          ],
        ],
      ),
    );
  }
}

class _SustitucionCategoriasManagerDialog extends StatefulWidget {
  const _SustitucionCategoriasManagerDialog({
    required this.onLoadCategorias,
    required this.onCreateCategoria,
    required this.onUpdateCategoria,
    required this.onDeleteCategoria,
    required this.onReloadItems,
  });

  final Future<List<Map<String, dynamic>>> Function({bool includeInactive})
      onLoadCategorias;
  final Future<int?> Function(String name) onCreateCategoria;
  final Future<bool> Function(Map<String, dynamic> payload) onUpdateCategoria;
  final Future<void> Function(int codigo) onDeleteCategoria;
  final Future<void> Function() onReloadItems;

  @override
  State<_SustitucionCategoriasManagerDialog> createState() =>
      _SustitucionCategoriasManagerDialogState();
}

class _SustitucionCategoriasManagerDialogState
    extends State<_SustitucionCategoriasManagerDialog> {
  bool _loading = true;
  String _search = '';
  bool _showSearch = false;
  List<Map<String, dynamic>> _categorias = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _reload();
    _loadShowSearchPreference();
  }

  Future<void> _loadShowSearchPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _showSearch = prefs.getBool('SustCategories_showSearch') ?? false;
      });
    } catch (_) {
      // Ignorar errores de lectura de preferencias
    }
  }

  Future<void> _saveShowSearchPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('SustCategories_showSearch', _showSearch);
    } catch (_) {
      // Ignorar errores de escritura de preferencias
    }
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final categorias = await widget.onLoadCategorias(includeInactive: true);
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? categoria}) async {
    final nombreCtrl = TextEditingController(
      text: categoria?['nombre']?.toString() ?? '',
    );
    bool activo = (categoria?['activo']?.toString() ?? 'S') == 'S';

    final ok = await showDialog<bool>(
          context: context,
          builder: (editorContext) => StatefulBuilder(
            builder: (context, setLocalState) => AlertDialog(
              title: Text(
                categoria == null ? 'Nueva categoría' : 'Editar categoría',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: activo,
                      onChanged: (value) => setLocalState(() => activo = value),
                      title: const Text('Activo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(editorContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(editorContext, true),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!ok) {
      return;
    }

    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      return;
    }

    try {
      if (categoria == null) {
        final created = await widget.onCreateCategoria(nombre);
        if (created == null) {
          throw Exception('No se pudo crear la categoría.');
        }
      } else {
        final payload = <String, dynamic>{
          'codigo': int.tryParse(categoria['codigo']?.toString() ?? ''),
          'nombre': nombre,
          'activo': activo ? 'S' : 'N',
          'imagen_portada': categoria['imagen_portada'],
          'imagen_portada_nombre': categoria['imagen_portada_nombre'],
          'imagen_miniatura': categoria['imagen_miniatura'],
        };

        final updated = await widget.onUpdateCategoria(payload);
        if (!updated) {
          throw Exception('No se pudo guardar la categoría.');
        }
      }

      await _reload();
      await widget.onReloadItems();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            categoria == null ? 'Categoría creada' : 'Categoría actualizada',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  Future<void> _deleteCategoria(Map<String, dynamic> categoria) async {
    final codigo = int.tryParse(categoria['codigo']?.toString() ?? '');
    if (codigo == null) {
      return;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminar categoría'),
            content: Text(
              'Se eliminará ${categoria['nombre']?.toString() ?? 'la categoría'}. ¿Continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) {
      return;
    }

    try {
      await widget.onDeleteCategoria(codigo);
      await _reload();
      await widget.onReloadItems();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categoría eliminada'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  Future<void> _toggleActivo(Map<String, dynamic> categoria) async {
    final payload = <String, dynamic>{
      'codigo': int.tryParse(categoria['codigo']?.toString() ?? ''),
      'nombre': categoria['nombre']?.toString() ?? '',
      'activo': (categoria['activo']?.toString() ?? 'S') == 'S' ? 'N' : 'S',
      'imagen_portada': categoria['imagen_portada'],
      'imagen_portada_nombre': categoria['imagen_portada_nombre'],
      'imagen_miniatura': categoria['imagen_miniatura'],
    };

    try {
      final updated = await widget.onUpdateCategoria(payload);
      if (!updated) {
        throw Exception('No se pudo actualizar la categoría.');
      }
      await _reload();
      await widget.onReloadItems();
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

  Future<void> _openRowMenu(Map<String, dynamic> categoria) async {
    final activo = (categoria['activo']?.toString() ?? 'S') == 'S';
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                activo ? Icons.cancel_outlined : Icons.check_circle,
              ),
              title: Text(activo ? 'Desactivar' : 'Activar'),
              onTap: () => Navigator.pop(sheetContext, 'toggle'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'toggle') {
      await _toggleActivo(categoria);
    } else if (action == 'edit') {
      await _openEditor(categoria: categoria);
    } else if (action == 'delete') {
      await _deleteCategoria(categoria);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _categorias.where((categoria) {
      if (_search.isEmpty) {
        return true;
      }
      final query = _search.toLowerCase();
      final nombre = categoria['nombre']?.toString().toLowerCase() ?? '';
      return nombre.contains(query);
    }).toList(growable: false)
      ..sort((a, b) {
        final aName = a['nombre']?.toString().toLowerCase() ?? '';
        final bName = b['nombre']?.toString().toLowerCase() ?? '';
        return aName.compareTo(bName);
      });

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      title: Row(
        children: [
          const Icon(Icons.category_outlined, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Categorías de sustituciones',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: _showSearch ? 'Ocultar búsqueda' : 'Buscar',
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              _saveShowSearchPreference();
            },
            style: IconButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva categoría',
            onPressed: _loading ? null : () => _openEditor(),
            style: IconButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showSearch) ...[
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar categoría',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _search = value.trim();
                  });
                },
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 380,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('No hay categorías.'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final categoria = filtered[index];
                            final codigo =
                                categoria['codigo']?.toString() ?? '';
                            final total = int.tryParse(
                                  categoria['total_sustituciones']
                                          ?.toString() ??
                                      '0',
                                ) ??
                                0;
                            final activo =
                                (categoria['activo']?.toString() ?? 'S') == 'S';

                            return Dismissible(
                              key: ValueKey('sust_cat_${codigo}_$index'),
                              direction: DismissDirection.startToEnd,
                              background: Container(
                                color: Colors.red.shade600,
                                alignment: Alignment.centerLeft,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: const Row(
                                  children: [
                                    Icon(Icons.delete_outline,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Eliminar',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              confirmDismiss: (_) async {
                                await _deleteCategoria(categoria);
                                return false;
                              },
                              child: SizedBox(
                                height: 42,
                                child: InkWell(
                                  onTap: () =>
                                      _openEditor(categoria: categoria),
                                  onLongPress: () => _openRowMenu(categoria),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  categoria['nombre']
                                                          ?.toString() ??
                                                      '',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: activo
                                                        ? Colors.black87
                                                        : Colors.black45,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (!activo) ...[
                                                const SizedBox(width: 6),
                                                const Icon(
                                                  Icons.visibility_off_outlined,
                                                  size: 14,
                                                  color: Colors.black45,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 18,
                                        height: 18,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: total > 0
                                              ? Colors.green
                                              : Colors.grey.shade500,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$total',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.more_vert,
                                            size: 20),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        tooltip: 'Más opciones',
                                        onPressed: () =>
                                            _openRowMenu(categoria),
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
        ),
      ),
    );
  }
}

class _AutoAssignCategoriesDialog extends StatefulWidget {
  const _AutoAssignCategoriesDialog({
    required this.items,
    required this.onLoadCategorias,
    required this.onCreateCategoria,
    required this.onLoadItemDetail,
    required this.onReloadItems,
  });

  final List<SustitucionSaludable> items;
  final Future<List<Map<String, dynamic>>> Function() onLoadCategorias;
  final Future<int?> Function(String name) onCreateCategoria;
  final Future<SustitucionSaludable?> Function(int codigo) onLoadItemDetail;
  final Future<void> Function() onReloadItems;

  @override
  State<_AutoAssignCategoriesDialog> createState() =>
      _AutoAssignCategoriesDialogState();
}

class _AutoAssignCategoriesDialogState
    extends State<_AutoAssignCategoriesDialog> {
  List<Map<String, dynamic>> _categorias = <Map<String, dynamic>>[];
  SustitucionCategoriaMatchAnalysis? _analysis;
  Set<String> _selectedSuggestions = <String>{};

  bool _loadingCategorias = true;
  bool _analyzing = false;
  bool _creating = false;
  bool _assigning = false;

  bool _useHashtags = true;
  bool _useTitle = true;
  bool _useDescription = true;

  int _processedItems = 0;
  int _updatedItems = 0;
  int _associationsAdded = 0;
  int _createdCategories = 0;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategorias();
  }

  SustitucionCategoriaMatchOptions get _options =>
      SustitucionCategoriaMatchOptions(
        useHashtags: _useHashtags,
        useTitle: _useTitle,
        useDescription: _useDescription,
      );

  Future<void> _loadCategorias() async {
    setState(() {
      _loadingCategorias = true;
      _error = null;
    });
    try {
      final categorias = await widget.onLoadCategorias();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las categorías: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingCategorias = false);
      }
    }
  }

  Future<void> _runAnalysis() async {
    if (!_options.hasAnySource) {
      setState(() {
        _error = 'Marca al menos una fuente: hashtag, título o descripción.';
      });
      return;
    }

    setState(() {
      _analyzing = true;
      _error = null;
      _message = null;
      _processedItems = 0;
      _updatedItems = 0;
      _associationsAdded = 0;
      _createdCategories = 0;
    });

    final analysis = analyzeSustitucionCategoryMatches(
      items: widget.items,
      existingCategories: _categorias,
      options: _options,
    );

    if (!mounted) return;
    setState(() {
      _analysis = analysis;
      _selectedSuggestions =
          analysis.suggestions.map((item) => item.name).toSet();
      _analyzing = false;
      _message =
          'Se han encontrado ${analysis.assignmentsToAdd} asociaciones potenciales en ${analysis.matchedItems} sustituciones.';
    });
  }

  Future<void> _createSelectedSuggestions() async {
    if (_selectedSuggestions.isEmpty) {
      setState(() {
        _error = 'No hay categorías sugeridas seleccionadas para crear.';
      });
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
      _message = null;
      _createdCategories = 0;
    });

    var created = 0;
    for (final name in _selectedSuggestions.toList(growable: false)) {
      final id = await widget.onCreateCategoria(name);
      if (id != null) {
        created += 1;
      }
    }

    await _loadCategorias();
    await _runAnalysis();
    if (!mounted) return;
    setState(() {
      _creating = false;
      _createdCategories = created;
      _message = 'Se han creado $created categorías nuevas.';
    });
  }

  Future<void> _assignCategories() async {
    final analysis = _analysis;
    if (analysis == null) {
      setState(() {
        _error = 'Primero debes analizar coincidencias.';
      });
      return;
    }
    if (analysis.assignmentsByItemCode.isEmpty) {
      setState(() {
        _message = 'No hay categorías que asignar automáticamente.';
      });
      return;
    }

    setState(() {
      _assigning = true;
      _error = null;
      _message = null;
      _processedItems = 0;
      _updatedItems = 0;
      _associationsAdded = 0;
    });

    for (final entry in analysis.assignmentsByItemCode.entries) {
      final detail = await widget.onLoadItemDetail(entry.key);
      if (detail == null || detail.codigo == null) {
        if (!mounted) return;
        setState(() {
          _processedItems += 1;
        });
        continue;
      }

      final mergedCategorias = <int>{
        ...detail.categoriaIds,
        ...entry.value,
      }.toList(growable: false);

      final payload = detail.toJson()
        ..['codigo'] = detail.codigo
        ..['categorias'] = mergedCategorias;

      try {
        final response = await context.read<ApiService>().put(
              'api/sustituciones_saludables.php',
              body: jsonEncode(payload),
            );
        if (response.statusCode == 200 || response.statusCode == 201) {
          _updatedItems += 1;
          _associationsAdded += entry.value.length;
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _processedItems += 1;
      });
    }

    await widget.onReloadItems();
    await _loadCategorias();
    if (!mounted) return;
    setState(() {
      _assigning = false;
      _message =
          'Se han actualizado $_updatedItems sustituciones y se han añadido $_associationsAdded asociaciones.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestionCount = _analysis?.suggestions.length ?? 0;
    final assignmentCount = _analysis?.assignmentsToAdd ?? 0;
    final itemsToUpdate = _analysis?.matchedItems ?? 0;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.category_outlined, color: Colors.teal),
          SizedBox(width: 8),
          Expanded(child: Text('Asignación automática de categorías')),
        ],
      ),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona dónde buscar coincidencias para asignar categorías existentes. También se sugerirán nuevas categorías basadas en palabras frecuentes.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilterChip(
                    label: const Text('Basarse en hashtag'),
                    selected: _useHashtags,
                    onSelected: _analyzing || _assigning
                        ? null
                        : (value) => setState(() => _useHashtags = value),
                  ),
                  FilterChip(
                    label: const Text('Basarse en título'),
                    selected: _useTitle,
                    onSelected: _analyzing || _assigning
                        ? null
                        : (value) => setState(() => _useTitle = value),
                  ),
                  FilterChip(
                    label: const Text('Basarse en descripción'),
                    selected: _useDescription,
                    onSelected: _analyzing || _assigning
                        ? null
                        : (value) => setState(() => _useDescription = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _loadingCategorias || _analyzing || _assigning
                        ? null
                        : _runAnalysis,
                    icon: _analyzing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.analytics_outlined),
                    label: const Text('Analizar coincidencias'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loadingCategorias || _creating || _assigning
                        ? null
                        : _loadCategorias,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recargar categorías'),
                  ),
                ],
              ),
              if (_loadingCategorias) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _ImportAssistantStepCard(
                title:
                    'Categorías existentes: ${_categorias.length}. Coincidencias detectadas: $assignmentCount en $itemsToUpdate sustituciones.',
                child: assignmentCount == 0
                    ? const Text('No hay coincidencias todavía.')
                    : FilledButton.icon(
                        onPressed:
                            _assigning || _analyzing ? null : _assignCategories,
                        icon: _assigning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.link_outlined),
                        label: const Text('Asignar categorías'),
                      ),
              ),
              if (_assigning) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: itemsToUpdate == 0
                      ? null
                      : _processedItems / itemsToUpdate,
                ),
                const SizedBox(height: 8),
                Text('Progreso: $_processedItems de $itemsToUpdate'),
              ],
              const SizedBox(height: 16),
              _ImportAssistantStepCard(
                title:
                    'Sugerencias de nuevas categorías (>10 coincidencias): $suggestionCount',
                child: suggestionCount == 0
                    ? const Text(
                        'No se han encontrado palabras frecuentes para proponer nuevas categorías.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 220,
                            child: ListView(
                              children:
                                  _analysis!.suggestions.map((suggestion) {
                                final selected = _selectedSuggestions
                                    .contains(suggestion.name);
                                return CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: selected,
                                  onChanged: _creating || _assigning
                                      ? null
                                      : (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedSuggestions
                                                  .add(suggestion.name);
                                            } else {
                                              _selectedSuggestions
                                                  .remove(suggestion.name);
                                            }
                                          });
                                        },
                                  title: Text(suggestion.name),
                                  subtitle: Text(
                                    '${suggestion.matchCount} sustituciones',
                                  ),
                                );
                              }).toList(growable: false),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _creating || _assigning
                                ? null
                                : _createSelectedSuggestions,
                            icon: _creating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_circle_outline),
                            label: const Text('Crear categorías seleccionadas'),
                          ),
                          if (_createdCategories > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Se han creado $_createdCategories categorías nuevas.',
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
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _assigning || _creating ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _CategoryImageManagerDialog extends StatefulWidget {
  const _CategoryImageManagerDialog({
    required this.onLoadCategorias,
    required this.onUpdateCategoria,
    required this.onReloadItems,
    required this.picker,
  });

  final Future<List<Map<String, dynamic>>> Function() onLoadCategorias;
  final Future<bool> Function(Map<String, dynamic> payload) onUpdateCategoria;
  final Future<void> Function() onReloadItems;
  final ImagePicker picker;

  @override
  State<_CategoryImageManagerDialog> createState() =>
      _CategoryImageManagerDialogState();
}

class _CategoryImageManagerDialogState
    extends State<_CategoryImageManagerDialog> {
  List<Map<String, dynamic>> _categorias = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _updating = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategorias();
  }

  Future<void> _loadCategorias() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categorias = await widget.onLoadCategorias();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las categorías: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickAndSaveImage(Map<String, dynamic> categoria) async {
    final picked = await widget.picker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    final decoded = img.decodeImage(bytes);
    final thumbnailBytes = decoded != null
        ? img.encodeJpg(img.copyResize(decoded, width: 320), quality: 86)
        : bytes;

    await _updateCategoria(
      categoria,
      imagenPortadaBase64: base64Encode(bytes),
      imagenMiniaturaBase64: base64Encode(thumbnailBytes),
      imagenNombre: picked.name,
    );
  }

  Future<void> _removeImage(Map<String, dynamic> categoria) async {
    await _updateCategoria(
      categoria,
      imagenPortadaBase64: null,
      imagenMiniaturaBase64: null,
      imagenNombre: null,
    );
  }

  Future<void> _updateCategoria(
    Map<String, dynamic> categoria, {
    required String? imagenPortadaBase64,
    required String? imagenMiniaturaBase64,
    required String? imagenNombre,
  }) async {
    setState(() {
      _updating = true;
      _message = null;
      _error = null;
    });

    final payload = <String, dynamic>{
      'codigo': int.tryParse(categoria['codigo'].toString()),
      'nombre': categoria['nombre']?.toString() ?? '',
      'activo': categoria['activo']?.toString() ?? 'S',
      'imagen_portada': imagenPortadaBase64,
      'imagen_portada_nombre': imagenNombre,
      'imagen_miniatura': imagenMiniaturaBase64,
    };

    final ok = await widget.onUpdateCategoria(payload);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _updating = false;
        _error = 'No se pudo actualizar la imagen de la categoría.';
      });
      return;
    }

    await _loadCategorias();
    await widget.onReloadItems();
    if (!mounted) return;
    setState(() {
      _updating = false;
      _message = imagenPortadaBase64 == null
          ? 'Imagen eliminada correctamente.'
          : 'Imagen de categoría actualizada.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.image_outlined, color: Colors.teal),
          SizedBox(width: 8),
          Expanded(child: Text('Imágenes de categorías')),
        ],
      ),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Asigna una imagen a cada categoría. Las sustituciones sin imagen propia heredarán la imagen de su primera categoría con imagen.',
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: _loading
                  ? const SizedBox.shrink()
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _categorias.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final categoria = _categorias[index];
                        final thumb =
                            (categoria['imagen_miniatura'] ?? '').toString();
                        final portada =
                            (categoria['imagen_portada'] ?? '').toString();
                        final previewBase64 =
                            thumb.isNotEmpty ? thumb : portada;
                        final hasImage = previewBase64.isNotEmpty;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: hasImage
                                ? Image.memory(
                                    base64Decode(previewBase64),
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 56,
                                    height: 56,
                                    color: Colors.green.shade50,
                                    child: const Icon(Icons.image_outlined),
                                  ),
                          ),
                          title: Text(categoria['nombre']?.toString() ?? ''),
                          subtitle: Text(
                            hasImage
                                ? (categoria['imagen_portada_nombre']
                                            ?.toString()
                                            .isNotEmpty ??
                                        false)
                                    ? categoria['imagen_portada_nombre']
                                        .toString()
                                    : 'Imagen asignada'
                                : 'Sin imagen',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Cambiar imagen',
                                onPressed: _updating
                                    ? null
                                    : () => _pickAndSaveImage(categoria),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Quitar imagen',
                                onPressed: _updating || !hasImage
                                    ? null
                                    : () => _removeImage(categoria),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _updating ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
