import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../services/config_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/receta.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'recetas_paciente_screen.dart';
import '../widgets/image_viewer_dialog.dart';
import '../services/thumbnail_generator.dart';
import '../widgets/paste_image_dialog.dart';
import '../utils/receta_clipboard_parser.dart';

enum _RecetasTopMenuAction {
  buscar,
  filtrar,
  categorias,
  copiarIa,
  actualizar,
  sortTitulo,
  sortRecientes,
  sortPopulares,
  sortCategorias,
  pegarReceta,
  pegarIa,
}

enum _OrdenRecetasList { titulo, recientes, populares, categorias }

class RecetasListScreen extends StatefulWidget {
  const RecetasListScreen({super.key});

  @override
  State<RecetasListScreen> createState() => _RecetasListScreenState();
}

class _RecetasListScreenState extends State<RecetasListScreen> {
  List<Receta> _recetas = [];
  List<Receta> _displayedRecetas = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  bool _isSearchVisible = false;
  bool _filterActivas = true;
  bool _filterInactivas = true;
  bool _filterDestacadas = false;
  Set<int> _selectedCategoryIds = <int>{};
  List<Map<String, dynamic>> _categoryCatalog = <Map<String, dynamic>>[];
  _OrdenRecetasList _orden = _OrdenRecetasList.recientes;
  bool _ordenAscendente = false;
  late ScrollController _scrollController;

  static const int _pageSize = 15;
  int _currentPage = 1;
  bool _hasMoreItems = true;

  static const _prefSearchVisible = 'recetas_show_search';
  static const _prefFilterActivas = 'recetas_filter_activas';
  static const _prefFilterInactivas = 'recetas_filter_inactivas';
  static const _prefFilterDestacadas = 'recetas_filter_destacadas';
  static const _prefFilterCategoryIds = 'recetas_filter_category_ids';
  static const _prefSortField = 'recetas_sort_field';
  static const _prefSortAsc = 'recetas_sort_asc';

  String _aiPrompt =
      'muéstrame, para importar en una app de Nutrición y dietética, 3 recetas de cocina saludables, detallando bien la descripción, siempre poniendo primero los ingredientes y luego la elaboración, con el paso a paso, las categorías las separas (si hay varias) con ";", ejemplo de categorías: Veganas, Vegetarianas, Carnes, Pescados, Guisos, Mariscos, Repostería, etc., al final de la Descripción (Ingredientes y Elaboración), añade varios hashtag descriptivos, para la descripción puedes usar emojics para darle más personalidad (en medio del texto de la descripción, sin abusar), usa saltos de línea para separar párrafos, no es necesario que toda la descripción quede en un único párrafo, en el título no uses emojis. Si la descripción lleva viñetas, usa 🟢 y si hay viñetas con número, usa emojis de números. Te indico el formato para mostrar las recetas (es importante que respetes el formato que te indico a continuación, incluyendo los corchetes):\n[Título]\nxxxxxxx\n[Descripción]\nxxxxxxx\n[Categorías]\nCategoría1;Categoría2;...';

  int get _selectedCategoryCount => _selectedCategoryIds.length;

  bool get _canManageRecetas {
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

  Future<List<Map<String, dynamic>>> _fetchRecetaCategoriasCatalog() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final response = await apiService.get('api/recetas.php?categorias=1');
    if (response.statusCode != 200) {
      return const <Map<String, dynamic>>[];
    }

    final List<dynamic> data = json.decode(response.body);
    return data
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> _createRecetaCategoria(String nombre) async {
    final trimmed = nombre.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final payload = <String, dynamic>{
      'nombre': trimmed,
      'codusuarioa': authService.userCode != null
          ? int.tryParse(authService.userCode!) ?? 1
          : 1,
    };

    final response = await apiService.post(
      'api/recetas.php?categorias=1',
      body: json.encode(payload),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body) as Map);
    }
    return null;
  }

  Map<int, int> _buildCategoriasUsageCount() {
    final counts = <int, int>{};
    for (final receta in _recetas) {
      for (final categoriaId in receta.categoriaIds) {
        counts[categoriaId] = (counts[categoriaId] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> _saveCategoriaReceta({
    int? codigo,
    required String nombre,
  }) async {
    final endpoint = codigo == null
        ? 'api/recetas.php?categorias=1'
        : 'api/recetas.php?categorias=1&codigo=$codigo';
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

  Future<void> _deleteCategoriaReceta(int codigo) async {
    final response = await context.read<ApiService>().delete(
          'api/recetas.php?categorias=1&codigo=$codigo',
        );
    if (response.statusCode != 200) {
      throw Exception(
        (jsonDecode(response.body)['message'] ?? 'No se pudo eliminar.')
            .toString(),
      );
    }
  }

  Future<void> _openCategoriaRecetaEditor({
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
      await _saveCategoriaReceta(codigo: codigo, nombre: nombre);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            codigo == null ? 'Categoría creada.' : 'Categoría actualizada.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadCategoryCatalog();
      await _loadRecetas();
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

  Future<void> _confirmDeleteCategoriaReceta(int codigo, String nombre) async {
    final usageCount = _buildCategoriasUsageCount()[codigo] ?? 0;
    if (usageCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: Text(
            'No se puede eliminar "$nombre" porque hay recetas con esa categoría.',
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
      await _deleteCategoriaReceta(codigo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categoría eliminada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadCategoryCatalog();
      await _loadRecetas();
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

  Future<void> _openCategoriaRecetaRowMenu({
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
      await _openCategoriaRecetaEditor(codigo: codigo, nombreActual: nombre);
    } else if (action == 'delete') {
      await _confirmDeleteCategoriaReceta(codigo, nombre);
    }
  }

  Future<void> _openCategoriasRecetasDialog() async {
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
                    await _openCategoriaRecetaEditor();
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
                future: _fetchRecetaCategoriasCatalog(),
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
                                        ValueKey('cat_receta_${codigo}_$index'),
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
                                      await _confirmDeleteCategoriaReceta(
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
                                          await _openCategoriaRecetaEditor(
                                            codigo: codigo,
                                            nombreActual: nombre,
                                          );
                                          setLocal(() {});
                                        },
                                        onLongPress: () async {
                                          await _openCategoriaRecetaRowMenu(
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
                                                await _openCategoriaRecetaRowMenu(
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

  Map<String, Receta> _buildTitleToExisting() {
    final map = <String, Receta>{};
    for (final item in _recetas) {
      final key = normalizeRecetaTitle(item.titulo);
      if (key.isNotEmpty) {
        map[key] = item;
      }
    }
    return map;
  }

  Receta? _fuzzyFindExisting(
      String normalizedTitle, Map<String, Receta> titleToExisting) {
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
    required Receta existing,
    required RecetaImportDraft draft,
  }) {
    final existingLen = existing.texto.trim().length;
    final draftLen = draft.descripcion.trim().length;
    return existingLen < draftLen;
  }

  ({int duplicatedInPaste, int alreadyExisting}) _estimateImportConflicts(
    List<RecetaImportDraft> drafts,
  ) {
    final titleToExisting = _buildTitleToExisting();
    final seenTitles = <String>{};
    var duplicatedInPaste = 0;
    var alreadyExisting = 0;

    for (final draft in drafts) {
      final title = normalizeRecetaTitle(draft.titulo);
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
    final response = await apiService.get('api/recetas.php?categorias=1');
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar las categorías de recetas.');
    }

    final List<dynamic> data = json.decode(response.body);
    _categoryCatalog =
        data.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Map<String, dynamic>? _findCategoriaByName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final item in _categoryCatalog) {
      final nombre = (item['nombre'] ?? '').toString().trim().toLowerCase();
      if (nombre == normalized) {
        return item;
      }
    }
    return null;
  }

  Future<List<int>> _resolveCategoriaIdsForDraft(
    RecetaImportDraft draft, {
    required Set<String> selectedNewCategoryNames,
    Set<int> selectedExistingCategoryIds = const <int>{},
  }) async {
    if (_categoryCatalog.isEmpty) {
      await _loadCategoriasCatalogo();
    }

    final resolvedIds = <int>[];
    for (final categoria in draft.categorias) {
      final trimmed = categoria.trim();
      if (trimmed.isEmpty) continue;

      Map<String, dynamic>? existing = _findCategoriaByName(trimmed);

      if (existing == null &&
          selectedNewCategoryNames.contains(trimmed.toLowerCase())) {
        existing = await _createRecetaCategoria(trimmed);
      }
      if (existing != null) {
        final codigo = int.tryParse(existing['codigo'].toString());
        if (codigo != null) {
          resolvedIds.add(codigo);
          final alreadyLoaded = _categoryCatalog.any(
            (item) => int.tryParse(item['codigo'].toString()) == codigo,
          );
          if (!alreadyLoaded) {
            _categoryCatalog.add(existing);
          }
        }
      }
    }

    return <int>{
      ...resolvedIds,
      ...selectedExistingCategoryIds,
    }.toList(growable: false);
  }

  Future<void> _updateRecetaFromDraft({
    required Receta existing,
    required RecetaImportDraft draft,
    required Set<String> selectedNewCategoryNames,
    Set<int> selectedExistingCategoryIds = const <int>{},
  }) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final detalle = await _fetchRecetaDetalle(existing.codigo) ?? existing;
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
      'api/recetas.php',
      body: json.encode(detalle.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo reemplazar la receta "${draft.titulo}".');
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
    return _tryDecodeBase64ImageFromClipboardText(
      text.substring(markerIndex + 'base64,'.length),
    );
  }

  Future<Uint8List?> _tryResolveImageSource(String source) async {
    final fromDataUri = _decodeImageFromDataUri(source);
    if (fromDataUri != null && fromDataUri.isNotEmpty) {
      return fromDataUri;
    }

    return _tryDownloadImageFromUrl(source);
  }

  Uint8List? _tryDecodeBase64ImageFromClipboardText(String rawText) {
    final raw = rawText.trim();
    if (raw.isEmpty) {
      return null;
    }

    final fotoMatch = RegExp(
      r'\[\s*foto\s*\]\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(raw);
    var candidate = (fotoMatch?.group(1) ?? raw).trim();

    final marker = 'base64,';
    final markerIndex = candidate.toLowerCase().indexOf(marker);
    if (markerIndex >= 0) {
      candidate = candidate.substring(markerIndex + marker.length);
    }

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

  Future<Uint8List?> _tryReadImageFromClipboardText(String rawText) async {
    final decodedBase64 = _tryDecodeBase64ImageFromClipboardText(rawText);
    if (decodedBase64 != null && decodedBase64.isNotEmpty) {
      return decodedBase64;
    }

    final url = _extractImageUrlFromClipboardText(rawText);
    if (url == null) {
      return null;
    }

    return _tryDownloadImageFromUrl(url);
  }

  Future<void> _showPasteRecetaDialog() async {
    RecetaClipboardDraft? draft;
    Uint8List? imageBytes;
    Receta? existingReceta;
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
            title: const Text('Pegar receta'),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
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
                                  final parsed = parseRecetaClipboardText(
                                    clipboardText,
                                  );
                                  final imageFromClipboard =
                                      supportsImageClipboard
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
                                      : _extractImageSourceFromHtml(
                                          clipboardHtml,
                                        );
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
                                      : await _tryResolveImageSource(
                                          clipboardUri,
                                        );
                                  final image = imageFromClipboard ??
                                      imageFromText ??
                                      imageFromHtml ??
                                      imageFromUri;
                                  final catalog = parsed == null
                                      ? const <Map<String, dynamic>>[]
                                      : await _fetchRecetaCategoriasCatalog();
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
                                    existingReceta = parsed == null
                                        ? null
                                        : _fuzzyFindExisting(
                                            normalizeRecetaTitle(parsed.titulo),
                                            _buildTitleToExisting(),
                                          );
                                    replaceExisting = false;
                                    readingClipboard = false;
                                    existingCategories = nextExisting;
                                    missingCategories = nextMissing;
                                    createMissingSelections = nextSelections;
                                    mapMissingToExistingCategoryId =
                                        nextMappings;
                                    detectedCategoryCatalog = catalog;

                                    if (parsed == null) {
                                      errorText =
                                          'No se detectó una receta válida en el portapapeles.';
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
                          label:
                              Text(readingClipboard ? 'Leyendo...' : 'Pegar'),
                        ),
                      ],
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
                      if (existingReceta != null) ...[
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
                              'Posible receta duplicada',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              existingReceta!.titulo,
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            children: [
                              Text(
                                'Ya existe una receta con título similar: "${existingReceta!.titulo}"',
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
                                    const Text('Reemplazar receta existente'),
                                subtitle: const Text(
                                  'Si está marcado, se actualizará la receta existente en lugar de abrir una nueva.',
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
                                constraints: const BoxConstraints(
                                  maxHeight: 220,
                                ),
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
                                          ...missingCategories.map(
                                            (categoria) {
                                              final selectedCategoryId =
                                                  mapMissingToExistingCategoryId[
                                                      categoria];
                                              final canCreateSelection =
                                                  selectedCategoryId == null;
                                              final sortedOptions =
                                                  detectedCategoryCatalog
                                                      .where((item) =>
                                                          int.tryParse(item[
                                                                  'codigo']
                                                              .toString()) !=
                                                          null)
                                                      .toList(growable: false)
                                                    ..sort((a, b) => (a[
                                                                'nombre'] ??
                                                            '')
                                                        .toString()
                                                        .toLowerCase()
                                                        .compareTo((b[
                                                                    'nombre'] ??
                                                                '')
                                                            .toString()
                                                            .toLowerCase()));

                                              String? mappedExistingName;
                                              if (selectedCategoryId != null) {
                                                for (final item
                                                    in sortedOptions) {
                                                  final id = int.tryParse(
                                                      item['codigo']
                                                          .toString());
                                                  if (id ==
                                                      selectedCategoryId) {
                                                    mappedExistingName =
                                                        (item['nombre'] ?? '')
                                                            .toString();
                                                    break;
                                                  }
                                                }
                                              }

                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 8),
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  onTap: importing
                                                      ? null
                                                      : () async {
                                                          final selected =
                                                              await showDialog<
                                                                  int>(
                                                            context:
                                                                dialogContext,
                                                            builder: (ctx) =>
                                                                SimpleDialog(
                                                              title: Text(
                                                                  'Asignar "$categoria"',
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          14)),
                                                              children: [
                                                                SimpleDialogOption(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          ctx,
                                                                          -1),
                                                                  child: const Text(
                                                                      'Ninguna (crear nueva)',
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              12)),
                                                                ),
                                                                ...sortedOptions
                                                                    .map(
                                                                        (item) {
                                                                  final id = int
                                                                      .tryParse(
                                                                          item['codigo']
                                                                              .toString());
                                                                  if (id ==
                                                                      null)
                                                                    return null;
                                                                  return SimpleDialogOption(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx,
                                                                            id),
                                                                    child: Text(
                                                                        (item['nombre'] ??
                                                                                '')
                                                                            .toString(),
                                                                        style: const TextStyle(
                                                                            fontSize:
                                                                                12)),
                                                                  );
                                                                }).whereType<
                                                                        Widget>(),
                                                              ],
                                                            ),
                                                          );

                                                          if (selected ==
                                                              null) {
                                                            return;
                                                          }

                                                          setDialogState(() {
                                                            if (selected ==
                                                                -1) {
                                                              mapMissingToExistingCategoryId[
                                                                      categoria] =
                                                                  null;
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
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      CheckboxListTile(
                                                        value:
                                                            createMissingSelections[
                                                                    categoria] ??
                                                                false,
                                                        dense: true,
                                                        visualDensity:
                                                            const VisualDensity(
                                                                horizontal: -4,
                                                                vertical: -4),
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        title: Text(
                                                          categoria,
                                                          style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                        ),
                                                        subtitle: Text(
                                                          mappedExistingName !=
                                                                  null
                                                              ? 'Asignada a "$mappedExistingName". Pulsa para cambiar.'
                                                              : 'Pulsa para asignar a categoría existente.',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 11),
                                                        ),
                                                        controlAffinity:
                                                            ListTileControlAffinity
                                                                .leading,
                                                        onChanged:
                                                            !canCreateSelection
                                                                ? null
                                                                : (value) {
                                                                    setDialogState(
                                                                        () {
                                                                      createMissingSelections[
                                                                              categoria] =
                                                                          value ??
                                                                              false;
                                                                    });
                                                                  },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const Divider(height: 16),
                                        ],
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: draft!.categorias
                                              .map(
                                                (categoria) => Chip(
                                                  label: Text(categoria),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                              )
                                              .toList(growable: false),
                                        ),
                                        if (existingCategories.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Ya existentes (${existingCategories.length})',
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
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
                          await _createRecetaCategoria(categoria);
                        }

                        if (existingReceta != null && replaceExisting) {
                          try {
                            final importDraft = RecetaImportDraft(
                              titulo: draft!.titulo,
                              descripcion: draft!.descripcion,
                              categorias: draft!.categorias,
                            );
                            await _updateRecetaFromDraft(
                              existing: existingReceta!,
                              draft: importDraft,
                              selectedNewCategoryNames: selectedToCreate
                                  .map((c) => c.toLowerCase())
                                  .toSet(),
                              selectedExistingCategoryIds: mappedExistingIds,
                            );

                            if (imageBytes != null) {
                              final updated = await _fetchRecetaDetalle(
                                    existingReceta!.codigo,
                                  ) ??
                                  existingReceta!;
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
                                    'api/recetas.php',
                                    body: jsonEncode(payload),
                                  );
                            }

                            if (!mounted) return;
                            await _loadRecetas();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Receta reemplazada.'),
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
                                  'No se pudo reemplazar la receta: ${e.toString().replaceFirst('Exception: ', '')}';
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
                          '/receta_edit',
                          arguments: <String, dynamic>{
                            'prefill_titulo': draft!.titulo,
                            'prefill_texto': draft!.descripcion,
                            'prefill_categoria_names': finalCategoryNames,
                            'prefill_image_bytes': imageBytes,
                          },
                        );
                        if (!mounted) return;
                        if (result == true) {
                          await _loadRecetas();
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

  Future<void> _showReplaceComparisonDialog({
    required Receta existing,
    required RecetaImportDraft draft,
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
                  'Receta: ${draft.titulo}',
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
    var detected = <RecetaImportDraft>[];
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
              <({int index, RecetaImportDraft draft, Receta existing})>[
            for (var i = 0; i < detected.length; i++)
              if (_fuzzyFindExisting(
                      normalizeRecetaTitle(detected[i].titulo), titleMap)
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
                    'Importar Recetas con IA',
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
                            'Paso 1: Genera Recetas con el formato de importación',
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
                        title: 'Paso 2: Copia todas las Recetas generadas.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!hidePasteStep)
                      _ImportAssistantStepCard(
                        title: hideImportButton
                            ? 'Pega las Recetas pulsando en "Pegar".'
                            : 'Paso 3: Pega las Recetas pulsando en "Pegar".',
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
                                        omittedCount = 0;
                                        processedCount = 0;
                                        errorText = null;
                                        detected = <RecetaImportDraft>[];
                                        importChoices = <int, bool>{};
                                        replaceChoices = <int, bool>{};
                                        newCategoryChoices = <String, bool>{};
                                      });

                                      final data = await Clipboard.getData(
                                        Clipboard.kTextPlain,
                                      );
                                      final text = data?.text ?? '';
                                      final parsed = parseRecetasFromAI(text);
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
                                          normalizeRecetaTitle(draft.titulo),
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
                                              'No se detectaron recetas con el formato de importación ([Título], [Descripción], [Categorías]).';
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
                                'Las categorías seleccionadas se crearán automáticamente y se asignarán a las recetas importadas o reemplazadas.',
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
                              ? 'Se mostrarán aquí las Recetas detectadas para importarlas.'
                              : 'Se han obtenido ${detected.length} Recetas.',
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
                                        '${conflicts.duplicatedInPaste} se omitirán por estar duplicadas en el texto pegado.',
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
                                'Recetas detectadas ($selectedImportCount de ${detected.length} seleccionadas):',
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
                                          normalizeRecetaTitle(item.titulo),
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
                                                : Icons.restaurant_menu,
                                            color: duplicate
                                                ? Colors.orange
                                                : Colors.blue,
                                          ),
                                          if (duplicate) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              replaceExisting
                                                  ? 'Coincide'
                                                  : 'Omitida',
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
                              'Se han importado $importedCount Recetas nuevas',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Se han omitido $omittedCount Recetas',
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
                                  normalizeRecetaTitle(draft.titulo);

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
                                  await _updateRecetaFromDraft(
                                    existing: existingItem!,
                                    draft: draft,
                                    selectedNewCategoryNames:
                                        selectedNewCategoryNames,
                                  );
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
                                    'api/recetas.php',
                                    body: json.encode(payload),
                                  );
                                  if (response.statusCode != 201) {
                                    throw Exception();
                                  }
                                  importedCount += 1;
                                }
                                titleToExisting[normalizedTitle] = Receta(
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
                            await _loadRecetas();
                            setDialogState(() {
                              importing = false;
                              importFinished = true;
                              if (hasServerErrors) {
                                errorText =
                                    'Alguna receta no se pudo guardar y se ha contabilizado como omitida.';
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
                  label: Text(importing ? 'Importando...' : 'Importar Recetas'),
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
                'Copia este prompt y pégalo en tu IA favorita para generar recetas con formato compatible:',
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
    _loadRecetas();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMoreItems) {
        _loadMoreRecetas();
      }
    }
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final showSearch = prefs.getBool(_prefSearchVisible) ?? false;
    final filterActivas = prefs.getBool(_prefFilterActivas) ?? true;
    final filterInactivas = prefs.getBool(_prefFilterInactivas) ?? true;
    final filterDestacadas = prefs.getBool(_prefFilterDestacadas) ?? false;
    final sortField = prefs.getString(_prefSortField) ?? 'recientes';
    final sortAsc = prefs.getBool(_prefSortAsc) ?? false;
    final categoryIds =
        prefs.getStringList(_prefFilterCategoryIds) ?? const <String>[];

    _OrdenRecetasList orderFromPref(String value) {
      switch (value) {
        case 'titulo':
          return _OrdenRecetasList.titulo;
        case 'populares':
          return _OrdenRecetasList.populares;
        case 'categorias':
          return _OrdenRecetasList.categorias;
        default:
          return _OrdenRecetasList.recientes;
      }
    }

    if (mounted) {
      setState(() {
        _isSearchVisible = showSearch;
        _filterActivas = filterActivas;
        _filterInactivas = filterInactivas;
        _filterDestacadas = filterDestacadas;
        _orden = orderFromPref(sortField);
        _ordenAscendente = sortAsc;
        _selectedCategoryIds =
            categoryIds.map((e) => int.tryParse(e)).whereType<int>().toSet();
      });
    }

    await _loadCategoryCatalog();
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    String sortToPref(_OrdenRecetasList order) {
      switch (order) {
        case _OrdenRecetasList.titulo:
          return 'titulo';
        case _OrdenRecetasList.populares:
          return 'populares';
        case _OrdenRecetasList.categorias:
          return 'categorias';
        case _OrdenRecetasList.recientes:
          return 'recientes';
      }
    }

    await prefs.setBool(_prefSearchVisible, _isSearchVisible);
    await prefs.setBool(_prefFilterActivas, _filterActivas);
    await prefs.setBool(_prefFilterInactivas, _filterInactivas);
    await prefs.setBool(_prefFilterDestacadas, _filterDestacadas);
    await prefs.setStringList(
      _prefFilterCategoryIds,
      _selectedCategoryIds.map((e) => e.toString()).toList(growable: false),
    );
    await prefs.setString(_prefSortField, sortToPref(_orden));
    await prefs.setBool(_prefSortAsc, _ordenAscendente);
  }

  Future<void> _loadCategoryCatalog() async {
    final response =
        await context.read<ApiService>().get('api/recetas.php?categorias=1');
    if (response.statusCode != 200) return;
    final List<dynamic> data = json.decode(response.body);
    if (!mounted) return;
    setState(() {
      _categoryCatalog = data
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
    });
  }

  Future<void> _loadRecetas() async {
    setState(() {
      _isLoading = true;
      _displayedRecetas = [];
      _currentPage = 1;
      _hasMoreItems = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/recetas.php');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _recetas = data.map((item) => Receta.fromJson(item)).toList();
        });
        _loadMoreRecetas();
      } else {
        throw Exception('Error al cargar recetas');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar recetas. $errorMessage'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _loadMoreRecetas() {
    if (_isLoadingMore || !_hasMoreItems) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Simular un pequeño delay para que el UX sea más claro
    Future.delayed(const Duration(milliseconds: 300), () {
      final filteredAll = _getFilteredRecetas(_recetas);
      final startIndex = (_currentPage - 1) * _pageSize;
      final endIndex = startIndex + _pageSize;

      if (startIndex < filteredAll.length) {
        final newItems = filteredAll.sublist(
          startIndex,
          endIndex > filteredAll.length ? filteredAll.length : endIndex,
        );

        setState(() {
          _displayedRecetas.addAll(newItems);
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

  List<Receta> _getFilteredRecetas(List<Receta> items) {
    final filtered = items.where((receta) {
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          receta.titulo.toLowerCase().contains(q) ||
          receta.texto.toLowerCase().contains(q);

      final isActive = receta.activo == 'S';
      final matchesEstado =
          (_filterActivas && isActive) || (_filterInactivas && !isActive);

      final matchesDestacadas =
          !_filterDestacadas || receta.mostrarPortada == 'S';

      final matchesCategory = _selectedCategoryIds.isEmpty ||
          receta.categoriaIds.any(_selectedCategoryIds.contains);

      return matchesSearch &&
          matchesEstado &&
          matchesDestacadas &&
          matchesCategory;
    }).toList(growable: false);

    int compareByTitle(Receta a, Receta b) =>
        a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());

    filtered.sort((a, b) {
      switch (_orden) {
        case _OrdenRecetasList.titulo:
          final byTitle = compareByTitle(a, b);
          return _ordenAscendente ? byTitle : -byTitle;
        case _OrdenRecetasList.recientes:
          final dateA = a.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
          final byDate = _ordenAscendente
              ? dateA.compareTo(dateB)
              : dateB.compareTo(dateA);
          return byDate != 0 ? byDate : compareByTitle(a, b);
        case _OrdenRecetasList.populares:
          final likesA = a.totalLikes ?? 0;
          final likesB = b.totalLikes ?? 0;
          final byLikes = _ordenAscendente
              ? likesA.compareTo(likesB)
              : likesB.compareTo(likesA);
          return byLikes != 0 ? byLikes : compareByTitle(a, b);
        case _OrdenRecetasList.categorias:
          final catA = a.categoriaNombres.join(', ').toLowerCase();
          final catB = b.categoriaNombres.join(', ').toLowerCase();
          final byCat =
              _ordenAscendente ? catA.compareTo(catB) : catB.compareTo(catA);
          return byCat != 0 ? byCat : compareByTitle(a, b);
      }
    });

    return filtered;
  }

  Future<void> _applySortSelection(_OrdenRecetasList nextOrder) async {
    setState(() {
      if (_orden == nextOrder) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _orden = nextOrder;
        _ordenAscendente = false;
      }
      _displayedRecetas = [];
      _currentPage = 1;
      _hasMoreItems = true;
    });
    await _saveUiState();
    _loadMoreRecetas();
  }

  void _toggleSearchVisibility() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchQuery = '';
        _displayedRecetas = [];
        _currentPage = 1;
        _hasMoreItems = true;
      }
    });
    _saveUiState();
    if (!_isSearchVisible) {
      _loadMoreRecetas();
    }
  }

  Future<void> _showRecetasFilterDialog() async {
    if (_categoryCatalog.isEmpty) {
      await _loadCategoryCatalog();
    }

    final tempSelected = _selectedCategoryIds.toSet();
    var tempActivas = _filterActivas;
    var tempInactivas = _filterInactivas;
    var tempDestacadas = _filterDestacadas;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final sortedCategorias =
              List<Map<String, dynamic>>.from(_categoryCatalog)
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
                    'Filtrar Recetas',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_canManageRecetas)
                        SizedBox(
                          height: 42,
                          child: Scrollbar(
                            thumbVisibility: true,
                            notificationPredicate: (notification) =>
                                notification.metrics.axis == Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  FilterChip(
                                    label: const Text('Activas'),
                                    selected: tempActivas,
                                    onSelected: (selected) {
                                      setDialogState(
                                          () => tempActivas = selected);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  FilterChip(
                                    label: const Text('Inactivas'),
                                    selected: tempInactivas,
                                    onSelected: (selected) {
                                      setDialogState(
                                          () => tempInactivas = selected);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  FilterChip(
                                    label: const Text('Destacadas'),
                                    selected: tempDestacadas,
                                    onSelected: (selected) {
                                      setDialogState(
                                          () => tempDestacadas = selected);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (_canManageRecetas) const SizedBox(height: 12),
                      if (_canManageRecetas) const Divider(height: 1),
                      if (_canManageRecetas) const SizedBox(height: 12),
                      if (sortedCategorias.isNotEmpty)
                        Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.32,
                            ),
                            child: Scrollbar(
                              thumbVisibility: sortedCategorias.length > 8,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: sortedCategorias.map((cat) {
                                    final id = int.tryParse(
                                        (cat['codigo'] ?? '').toString());
                                    if (id == null)
                                      return const SizedBox.shrink();
                                    final name =
                                        (cat['nombre'] ?? '').toString();
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
                        )
                      else
                        const Text(
                          'No hay categorías para filtrar.',
                          style: TextStyle(color: Colors.black54),
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
                    _filterActivas = true;
                    _filterInactivas = true;
                    _filterDestacadas = false;
                    _selectedCategoryIds = <int>{};
                    _displayedRecetas = [];
                    _currentPage = 1;
                    _hasMoreItems = true;
                  });
                  await _saveUiState();
                  _loadMoreRecetas();
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
                    _filterDestacadas = tempDestacadas;
                    _selectedCategoryIds = tempSelected;
                    _displayedRecetas = [];
                    _currentPage = 1;
                    _hasMoreItems = true;
                  });
                  await _saveUiState();
                  _loadMoreRecetas();
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

  Future<void> _deleteReceta(int codigo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Está seguro de que desea eliminar esta receta?'),
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
            await apiService.delete('api/recetas.php?codigo=$codigo');

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receta eliminada exitosamente'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadRecetas();
        } else {
          throw Exception('Error al eliminar');
        }
      } catch (e) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar receta. $errorMessage'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openRecetaMenu(Receta receta) async {
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
      await _openRecetaPreview(receta);
    } else if (action == 'edit') {
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/receta_edit',
        arguments: receta,
      ).then((result) {
        if (result == true) {
          _loadRecetas();
        }
      });
    } else if (action == 'paste_image') {
      await _showPasteImageDialog(receta);
    } else if (action == 'delete') {
      await _deleteReceta(receta.codigo!);
    }
  }

  Future<void> _showPasteImageDialog(Receta receta) async {
    final bytes = await showPasteImageDialog(
      context,
      title: 'Pegar imagen',
      description:
          'Genera la imagen en formato base64 o copiala directamente al portapapeles y pulsa en pegar para agregarla a la receta.',
    );
    if (bytes == null) return;

    try {
      final miniatura = ThumbnailGenerator.generateThumbnail(bytes);
      final payload = <String, dynamic>{
        'codigo': receta.codigo,
        'titulo': receta.titulo,
        'texto': receta.texto,
        'activo': receta.activo,
        'mostrar_portada': receta.mostrarPortada,
        'visible_para_todos': receta.visibleParaTodos,
        'imagen_portada': base64Encode(bytes),
        'imagen_portada_nombre': 'base64',
        'imagen_miniatura': miniatura != null ? base64Encode(miniatura) : '',
        'categorias': receta.categoriaIds,
      };

      final response = await context.read<ApiService>().put(
            'api/recetas.php',
            body: jsonEncode(payload),
          );

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadRecetas();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen aplicada a la receta.'),
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

  Future<Receta?> _fetchRecetaDetalle(int? codigo) async {
    if (codigo == null) return null;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/recetas.php?codigo=$codigo');

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        return Receta.fromJson(data);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openRecetaImageViewer(Receta receta) async {
    final detalle = await _fetchRecetaDetalle(receta.codigo);
    final imagenPortada = (detalle?.imagenPortada ?? '').trim();
    final imagenFallback =
        (receta.imagenPortada ?? receta.imagenMiniatura ?? '').trim();
    final imagen = imagenPortada.isNotEmpty ? imagenPortada : imagenFallback;

    if (!mounted || imagen.isEmpty) return;

    showImageViewerDialog(
      context: context,
      base64Image: imagen,
      title: receta.titulo,
    );
  }

  Future<void> _openRecetaPreview(Receta receta) async {
    final detalle = await _fetchRecetaDetalle(receta.codigo);
    final recetaPreview = detalle ?? receta;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecetaDetailScreen(
          receta: recetaPreview,
          isPreviewMode: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCount = _getFilteredRecetas(_recetas).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Recetas'),
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
                '$filteredCount',
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
            tooltip: _isSearchVisible ? 'Ocultar buscar' : 'Buscar',
            icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search),
            onPressed: _toggleSearchVisibility,
          ),
          IconButton(
            tooltip: _selectedCategoryCount > 0
                ? 'Filtrar (${_selectedCategoryCount})'
                : 'Filtrar',
            onPressed: _showRecetasFilterDialog,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(_selectedCategoryCount > 0
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined),
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
          PopupMenuButton<_RecetasTopMenuAction>(
            tooltip: 'Más opciones',
            onSelected: (value) async {
              if (value == _RecetasTopMenuAction.buscar) {
                _toggleSearchVisibility();
                return;
              }
              if (value == _RecetasTopMenuAction.filtrar) {
                await _showRecetasFilterDialog();
                return;
              }
              if (value == _RecetasTopMenuAction.categorias) {
                await _openCategoriasRecetasDialog();
                return;
              }
              if (value == _RecetasTopMenuAction.copiarIa) {
                _showAIPromptDialog();
                return;
              }
              if (value == _RecetasTopMenuAction.actualizar) {
                await _loadRecetas();
                return;
              }
              if (value == _RecetasTopMenuAction.sortTitulo) {
                await _applySortSelection(_OrdenRecetasList.titulo);
                return;
              }
              if (value == _RecetasTopMenuAction.sortRecientes) {
                await _applySortSelection(_OrdenRecetasList.recientes);
                return;
              }
              if (value == _RecetasTopMenuAction.sortPopulares) {
                await _applySortSelection(_OrdenRecetasList.populares);
                return;
              }
              if (value == _RecetasTopMenuAction.sortCategorias) {
                await _applySortSelection(_OrdenRecetasList.categorias);
                return;
              }
              if (value == _RecetasTopMenuAction.pegarReceta) {
                await _showPasteRecetaDialog();
                return;
              }
              if (value == _RecetasTopMenuAction.pegarIa) {
                await _showImportAssistant();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<_RecetasTopMenuAction>(
                value: _RecetasTopMenuAction.buscar,
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
              PopupMenuItem<_RecetasTopMenuAction>(
                value: _RecetasTopMenuAction.filtrar,
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          _selectedCategoryCount > 0
                              ? Icons.filter_alt
                              : Icons.filter_alt_outlined,
                          size: 18,
                        ),
                        if (_selectedCategoryCount > 0)
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
                                '$_selectedCategoryCount',
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
              if (_canManageRecetas)
                const PopupMenuItem<_RecetasTopMenuAction>(
                  value: _RecetasTopMenuAction.categorias,
                  child: Row(
                    children: [
                      Icon(Icons.category_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Categorías'),
                    ],
                  ),
                ),
              if (_canManageRecetas)
                const PopupMenuItem<_RecetasTopMenuAction>(
                  value: _RecetasTopMenuAction.copiarIa,
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18),
                      SizedBox(width: 8),
                      Text('Copiar IA'),
                    ],
                  ),
                ),
              if (_canManageRecetas)
                const PopupMenuItem<_RecetasTopMenuAction>(
                  value: _RecetasTopMenuAction.pegarReceta,
                  child: Row(
                    children: [
                      Icon(Icons.content_paste, size: 18),
                      SizedBox(width: 8),
                      Text('Pegar receta'),
                    ],
                  ),
                ),
              if (_canManageRecetas)
                const PopupMenuItem<_RecetasTopMenuAction>(
                  value: _RecetasTopMenuAction.pegarIa,
                  child: Row(
                    children: [
                      Icon(Icons.content_paste_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Pegar IA'),
                    ],
                  ),
                ),
              const PopupMenuItem<_RecetasTopMenuAction>(
                value: _RecetasTopMenuAction.actualizar,
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Actualizar'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem<_RecetasTopMenuAction>(
                value: _RecetasTopMenuAction.sortTitulo,
                checked: _orden == _OrdenRecetasList.titulo,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Título')),
                    if (_orden == _OrdenRecetasList.titulo)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<_RecetasTopMenuAction>(
                value: _RecetasTopMenuAction.sortRecientes,
                checked: _orden == _OrdenRecetasList.recientes,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Recientes')),
                    if (_orden == _OrdenRecetasList.recientes)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<_RecetasTopMenuAction>(
                value: _RecetasTopMenuAction.sortPopulares,
                checked: _orden == _OrdenRecetasList.populares,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Populares')),
                    if (_orden == _OrdenRecetasList.populares)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem<_RecetasTopMenuAction>(
                value: _RecetasTopMenuAction.sortCategorias,
                checked: _orden == _OrdenRecetasList.categorias,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Categorías')),
                    if (_orden == _OrdenRecetasList.categorias)
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
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_isSearchVisible)
                  Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar Recetas',
                          prefixIcon: IconButton(
                            tooltip: _searchQuery.isNotEmpty
                                ? 'Limpiar búsqueda'
                                : 'Buscar',
                            onPressed: _searchQuery.isNotEmpty
                                ? () {
                                    setState(() {
                                      _searchQuery = '';
                                      _displayedRecetas = [];
                                      _currentPage = 1;
                                      _hasMoreItems = true;
                                    });
                                    _loadMoreRecetas();
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
                            _displayedRecetas = [];
                            _currentPage = 1;
                            _hasMoreItems = true;
                          });
                          _loadMoreRecetas();
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista de recetas
          Expanded(
            child: _isLoading && _displayedRecetas.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _displayedRecetas.isEmpty
                    ? const Center(
                        child: Text('No hay recetas para mostrar'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRecetas,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _displayedRecetas.length +
                              (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Mostrar indicador de carga al final
                            if (index == _displayedRecetas.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Cargando más recetas...',
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

                            final receta = _displayedRecetas[index];
                            return Dismissible(
                              key: ValueKey(
                                'receta_${receta.codigo ?? receta.titulo}_$index',
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
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
                                await _deleteReceta(receta.codigo!);
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
                                        '/receta_edit',
                                        arguments: receta,
                                      ).then((result) {
                                        if (result == true) {
                                          _loadRecetas();
                                        }
                                      });
                                    },
                                    onLongPress: () => _openRecetaMenu(receta),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Imagen (using thumbnail for better performance)
                                          receta.imagenMiniatura != null
                                              ? GestureDetector(
                                                  onTap: () async {
                                                    await _openRecetaImageViewer(
                                                        receta);
                                                  },
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: Image.memory(
                                                      base64Decode(receta
                                                          .imagenMiniatura!),
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
                                                  child: const Icon(
                                                      Icons.restaurant_menu),
                                                ),
                                          const SizedBox(width: 12),
                                          // Contenido
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  receta.titulo,
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
                                                  receta.texto.length > 60
                                                      ? '${receta.texto.substring(0, 60)}...'
                                                      : receta.texto,
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
                                                      '${receta.totalLikes ?? 0}',
                                                      style: const TextStyle(
                                                          fontSize: 12),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Icon(
                                                      Icons.people,
                                                      size: 14,
                                                      color: Colors.blue[300],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      receta.visibleParaTodos ==
                                                              'S'
                                                          ? 'Todos'
                                                          : '${receta.totalPacientes ?? 0}',
                                                      style: const TextStyle(
                                                          fontSize: 12),
                                                    ),
                                                    const Spacer(),
                                                    if (receta.mostrarPortada ==
                                                        'S')
                                                      const Icon(Icons.star,
                                                          color: Colors.amber,
                                                          size: 16),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      receta.activo == 'S'
                                                          ? Icons.check_circle
                                                          : Icons.cancel,
                                                      color:
                                                          receta.activo == 'S'
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
                                                        Icons.more_vert),
                                                    tooltip: 'Más opciones',
                                                    onPressed: () =>
                                                        _openRecetaMenu(receta),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/receta_edit');
          if (result == true) {
            _loadRecetas();
          }
        },
        tooltip: 'Añadir Receta',
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
