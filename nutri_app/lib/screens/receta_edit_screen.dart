import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/thumbnail_generator.dart';
import '../models/receta.dart';
import '../models/receta_documento.dart';
import '../models/paciente.dart';
import '../widgets/unsaved_changes_dialog.dart';
import '../widgets/image_viewer_dialog.dart';
import '../widgets/paste_image_dialog.dart';

class RecetaEditScreen extends StatefulWidget {
  const RecetaEditScreen({super.key});

  @override
  State<RecetaEditScreen> createState() => _RecetaEditScreenState();
}

class _RecetaEditScreenState extends State<RecetaEditScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');
  static const String _prefsCategoriasSearchVisible =
      'receta_edit_categorias_search_visible';
  static const String _prefsCategoriasExpanded =
      'receta_edit_card_categorias_expanded';
  static const String _prefsIngredientesExpanded =
      'receta_edit_card_ingredientes_expanded';
  static const String _prefsPortadaExpanded =
      'receta_edit_card_portada_expanded';
  static const String _prefsPeriodoExpanded =
      'receta_edit_card_periodo_expanded';
  static const String _prefsActivoPortadaExpanded =
      'receta_edit_card_activo_portada_expanded';
  static const String _prefsPacientesExpanded =
      'receta_edit_card_pacientes_expanded';
  static const String _prefsDocumentosExpanded =
      'receta_edit_card_documentos_expanded';

  final _formKey = GlobalKey<FormState>();
  late Receta _receta;
  bool _isNew = true;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _hasChanges = false;

  final _tituloController = TextEditingController();
  final _textoController = TextEditingController();
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  DateTime? _fechaInicioPortada;
  DateTime? _fechaFinPortada;

  List<Paciente> _allPacientes = [];
  List<int> _selectedPacientes = [];
  List<RecetaDocumento> _documentos = [];
  bool _visibleParaTodos = true; // Por defecto true para recetas
  bool _categoriasLoading = false;
  List<Map<String, dynamic>> _categoriasCatalogo = [];
  List<int> _selectedCategoriaIds = [];
  List<String> _pendingPrefillCategoriaNames = [];
  List<Uint8List> _pendingPrefillBodyImages = [];
  bool _categoriasExpanded = true;
  bool _ingredientesExpanded = true;
  bool _imagenPortadaExpanded = true;
  bool _periodoExpanded = true;
  bool _activoPortadaExpanded = true;
  bool _pacientesExpanded = true;
  bool _documentosExpanded = true;

  Uint8List? _imagenPortadaBytes;
  String? _imagenPortadaNombre;
  Uint8List? _imagenMiniaturaBytes;

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();

    // Solo ejecutar una vez
    if (_isInitialized) return;
    _isInitialized = true;

    await _loadCardsExpandedState();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Receta) {
      _receta = args;
      _isNew = false;

      // Cargar la receta completa desde la API para obtener imagen_portada
      await _loadRecetaCompleta(_receta.codigo!);
    } else if (args is Map<String, dynamic>) {
      _receta = Receta(
        titulo: '',
        texto: '',
        activo: 'S',
        mostrarPortada: 'N',
        visibleParaTodos: 'S',
      );
      _isNew = true;
      _selectedCategoriaIds = [];

      _tituloController.text = (args['prefill_titulo'] ?? '').toString();
      _textoController.text = (args['prefill_texto'] ?? '').toString();
      final categoryNames = args['prefill_categoria_names'];
      if (categoryNames is List) {
        _pendingPrefillCategoriaNames = categoryNames
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      final maybeImage = args['prefill_image_bytes'];
      if (maybeImage is Uint8List && maybeImage.isNotEmpty) {
        _imagenPortadaBytes = maybeImage;
        _imagenPortadaNombre = 'clipboard';
        _imagenMiniaturaBytes = _generateThumbnail(maybeImage) ?? maybeImage;
      }
      final maybeBodyImages = args['prefill_body_images'];
      if (maybeBodyImages is List) {
        _pendingPrefillBodyImages = maybeBodyImages
            .whereType<Uint8List>()
            .where((bytes) => bytes.isNotEmpty)
            .toList(growable: false);
      }

      _loadPacientes();
      _loadCategorias();
    } else {
      _receta = Receta(
        titulo: '',
        texto: '',
        activo: 'S',
        mostrarPortada: 'N',
        visibleParaTodos: 'S', // Por defecto visible para todos
      );
      _isNew = true;
      _selectedCategoriaIds = [];
      _loadPacientes();
      _loadCategorias();
    }
  }

  Future<void> _loadCardsExpandedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _categoriasExpanded = prefs.getBool(_prefsCategoriasExpanded) ?? true;
      _ingredientesExpanded = prefs.getBool(_prefsIngredientesExpanded) ?? true;
      _imagenPortadaExpanded = prefs.getBool(_prefsPortadaExpanded) ?? true;
      _periodoExpanded = prefs.getBool(_prefsPeriodoExpanded) ?? true;
      _activoPortadaExpanded =
          prefs.getBool(_prefsActivoPortadaExpanded) ?? true;
      _pacientesExpanded = prefs.getBool(_prefsPacientesExpanded) ?? true;
      _documentosExpanded = prefs.getBool(_prefsDocumentosExpanded) ?? true;
    });
  }

  Future<void> _saveCardsExpandedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsCategoriasExpanded, _categoriasExpanded);
    await prefs.setBool(_prefsIngredientesExpanded, _ingredientesExpanded);
    await prefs.setBool(_prefsPortadaExpanded, _imagenPortadaExpanded);
    await prefs.setBool(_prefsPeriodoExpanded, _periodoExpanded);
    await prefs.setBool(_prefsActivoPortadaExpanded, _activoPortadaExpanded);
    await prefs.setBool(_prefsPacientesExpanded, _pacientesExpanded);
    await prefs.setBool(_prefsDocumentosExpanded, _documentosExpanded);
  }

  Future<void> _loadRecetaCompleta(int codigo) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/recetas.php?codigo=$codigo');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _receta = Receta.fromJson(data);

        // Inicializar campos del formulario
        _tituloController.text = _receta.titulo;
        _textoController.text = _receta.texto;
        _fechaInicio = _receta.fechaInicio;
        _fechaFin = _receta.fechaFin;
        _fechaInicioPortada = _receta.fechaInicioPortada;
        _fechaFinPortada = _receta.fechaFinPortada;
        _visibleParaTodos = _receta.visibleParaTodos == 'S';

        if (_receta.imagenPortada != null) {
          _imagenPortadaBytes = base64Decode(_receta.imagenPortada!);
          _imagenPortadaNombre = _receta.imagenPortadaNombre;
        }

        if (_receta.imagenMiniatura != null) {
          _imagenMiniaturaBytes = base64Decode(_receta.imagenMiniatura!);
        } else if (_imagenPortadaBytes != null) {
          // Si tiene imagen pero no miniatura, generarla automáticamente
          _imagenMiniaturaBytes = _generateThumbnail(_imagenPortadaBytes!);
        }

        _selectedCategoriaIds = List<int>.from(_receta.categoriaIds);

        _initializeData();
        _loadDocumentos();
        _loadCategorias();
      }
    } catch (e) {
      // debugPrint('Error cargando receta completa: $e');
      // Si falla, usar los datos parciales que tenemos
      _tituloController.text = _receta.titulo;
      _textoController.text = _receta.texto;
      _fechaInicio = _receta.fechaInicio;
      _fechaFin = _receta.fechaFin;
      _fechaInicioPortada = _receta.fechaInicioPortada;
      _fechaFinPortada = _receta.fechaFinPortada;
      _visibleParaTodos = _receta.visibleParaTodos == 'S';
      _selectedCategoriaIds = List<int>.from(_receta.categoriaIds);
      _loadPacientes();
      _loadCategorias();
    }
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
        final categorias =
            data.map((item) => Map<String, dynamic>.from(item)).toList();
        final resolvedIds = _resolveCategoriaIdsByName(
          categorias,
          _pendingPrefillCategoriaNames,
        );
        setState(() {
          _categoriasCatalogo = categorias;
          if (resolvedIds.isNotEmpty) {
            _selectedCategoriaIds = {
              ..._selectedCategoriaIds,
              ...resolvedIds,
            }.toList(growable: false);
          }
        });
        _pendingPrefillCategoriaNames = [];
      }
    } finally {
      if (mounted) {
        setState(() {
          _categoriasLoading = false;
        });
      }
    }
  }

  List<int> _resolveCategoriaIdsByName(
    List<Map<String, dynamic>> catalogo,
    List<String> nombres,
  ) {
    if (nombres.isEmpty) {
      return const <int>[];
    }

    final normalizedTargets = nombres
        .map(_normalizeCategoryName)
        .where((name) => name.isNotEmpty)
        .toSet();
    if (normalizedTargets.isEmpty) {
      return const <int>[];
    }

    final matches = <int>[];
    for (final categoria in catalogo) {
      final codigo = int.tryParse((categoria['codigo'] ?? '').toString());
      final nombre =
          _normalizeCategoryName((categoria['nombre'] ?? '').toString());
      if (codigo != null && normalizedTargets.contains(nombre)) {
        matches.add(codigo);
      }
    }
    return matches;
  }

  String _normalizeCategoryName(String value) {
    return value.trim().toLowerCase();
  }

  Future<Map<String, dynamic>?> _createCategoria(String nombre) async {
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
      'api/recetas.php?categorias=1',
      body: json.encode(payload),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    return null;
  }

  Future<void> _showCategoriasDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final searchController = TextEditingController();
    final newController = TextEditingController();
    bool showSearch = prefs.getBool(_prefsCategoriasSearchVisible) ?? true;
    List<int> tempSelected = List<int>.from(_selectedCategoriaIds);
    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            final query = searchController.text.trim().toLowerCase();
            final items = _categoriasCatalogo.where((cat) {
              if (query.isEmpty) return true;
              final name = (cat['nombre'] ?? '').toString().toLowerCase();
              return name.contains(query);
            }).toList();

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Categorías de la receta',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final nextValue = !showSearch;
                      setStateDialog(() {
                        showSearch = nextValue;
                        if (!showSearch && searchController.text.isNotEmpty) {
                          searchController.clear();
                        }
                      });
                      prefs.setBool(_prefsCategoriasSearchVisible, nextValue);
                    },
                    icon: Icon(showSearch ? Icons.search_off : Icons.search),
                    tooltip:
                        showSearch ? 'Ocultar búsqueda' : 'Mostrar búsqueda',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
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
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    if (showSearch) ...[
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar categoría',
                          prefixIcon: IconButton(
                            tooltip: searchController.text.isNotEmpty
                                ? 'Limpiar búsqueda'
                                : 'Buscar',
                            onPressed: searchController.text.isNotEmpty
                                ? () {
                                    searchController.clear();
                                    setStateDialog(() {});
                                  }
                                : null,
                            icon: Icon(
                              searchController.text.isNotEmpty
                                  ? Icons.clear
                                  : Icons.search,
                            ),
                          ),
                          suffixIcon: IconButton(
                            tooltip: 'Ocultar búsqueda',
                            onPressed: () {
                              setStateDialog(() {
                                showSearch = false;
                                if (searchController.text.isNotEmpty) {
                                  searchController.clear();
                                }
                              });
                              prefs.setBool(
                                _prefsCategoriasSearchVisible,
                                false,
                              );
                            },
                            icon: const Icon(Icons.visibility_off_outlined),
                          ),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setStateDialog(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Expanded(
                      child: _categoriasLoading
                          ? const Center(
                              child: LinearProgressIndicator(minHeight: 2),
                            )
                          : SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: items.map((cat) {
                                  final id =
                                      int.parse(cat['codigo'].toString());
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newController,
                            decoration: const InputDecoration(
                              labelText: 'Nueva categoría',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final created =
                                await _createCategoria(newController.text);
                            if (created != null) {
                              setStateDialog(() {
                                _categoriasCatalogo.add(created);
                                final id =
                                    int.parse(created['codigo'].toString());
                                if (!tempSelected.contains(id)) {
                                  tempSelected.add(id);
                                }
                                newController.clear();
                              });
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategoriaIds = tempSelected;
                    });
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
                          color: tempSelected.isNotEmpty
                              ? Colors.blue
                              : Colors.grey,
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
    } finally {
      searchController.dispose();
      newController.dispose();
    }
  }

  Future<void> _initializeData() async {
    // debugPrint(
    //     '_initializeData: Iniciando carga de datos para receta ${_receta.codigo}');
    await _loadPacientes();
    // debugPrint(
    //     '_initializeData: Pacientes cargados. Total: ${_allPacientes.length}');
    await _loadPacientesAsignados();
    // debugPrint(
    //     '_initializeData: Pacientes asignados cargados. Seleccionados: ${_selectedPacientes.length}');
  }

  Future<void> _loadPacientes() async {
    try {
      // debugPrint('_loadPacientes: Iniciando carga de todos los pacientes');
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/pacientes.php');

      // debugPrint('_loadPacientes: Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // debugPrint('_loadPacientes: Pacientes recibidos: ${data.length}');
        setState(() {
          _allPacientes = data.map((item) => Paciente.fromJson(item)).toList();
        });
        // debugPrint(
        //     '_loadPacientes: _allPacientes actualizado: ${_allPacientes.length}');
      }
    } catch (e) {
      // debugPrint('_loadPacientes: Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar pacientes: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadPacientesAsignados() async {
    if (_isNew) {
      // debugPrint(
      //     '_loadPacientesAsignados: Es una receta nueva, no se cargan pacientes');
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final url = 'api/receta_pacientes.php?receta=${_receta.codigo}';
      // debugPrint('_loadPacientesAsignados: Cargando desde $url');

      final response = await apiService.get(url);

      // debugPrint(
      //     '_loadPacientesAsignados: Status code: ${response.statusCode}');
      // debugPrint('_loadPacientesAsignados: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // debugPrint('_loadPacientesAsignados: Datos parseados: $data');

        final pacientesIds = data
            .map((item) => int.parse(item['codigo_paciente'].toString()))
            .toList();

        // debugPrint('_loadPacientesAsignados: IDs de pacientes: $pacientesIds');

        setState(() {
          _selectedPacientes = pacientesIds;
        });

        // debugPrint(
        //     '_loadPacientesAsignados: _selectedPacientes actualizado: $_selectedPacientes');
      }
    } catch (e) {
      // debugPrint('_loadPacientesAsignados: Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error al cargar pacientes asignados: ${e.toString()}'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _loadDocumentos() async {
    if (_isNew) return;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService
          .get('api/receta_documentos.php?receta=${_receta.codigo}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _documentos =
              data.map((item) => RecetaDocumento.fromJson(item)).toList();
        });
      }
    } catch (e) {
      // Error loading documents
    }
  }

  Future<void> _insertImageTokenAtCursor() async {
    final imageDocs = _documentos
        .where((doc) => doc.tipo == 'imagen' && doc.codigo != null)
        .toList();

    if (imageDocs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay imágenes guardadas para insertar. Guarda primero las imágenes adjuntas.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final selected = await showDialog<RecetaDocumento>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insertar imagen en texto'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: imageDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = imageDocs[index];
              final bytesBase64 = (doc.documento ?? '').trim();

              Widget preview;
              try {
                preview = bytesBase64.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          base64Decode(bytesBase64),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, size: 20),
                      );
              } catch (_) {
                preview = Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 20),
                );
              }

              return ListTile(
                leading: preview,
                title: Text(doc.nombre ?? 'Imagen ${doc.codigo}'),
                subtitle: Text('[[img:${doc.codigo}]]'),
                onTap: () => Navigator.pop(context, doc),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (selected == null || selected.codigo == null) {
      return;
    }

    final token = '[[img:${selected.codigo}]]';
    _insertTokenAtCursor(token);
  }

  Future<void> _insertDocumentoTokenAtCursor() async {
    final documentDocs = _documentos
        .where((doc) => doc.tipo == 'documento' && doc.codigo != null)
        .toList();

    if (documentDocs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay documentos guardados para insertar. Guarda primero documentos adjuntos.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final selected = await showDialog<RecetaDocumento>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insertar documento en texto'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: documentDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = documentDocs[index];
              return ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(doc.nombre ?? 'Documento ${doc.codigo}'),
                subtitle: Text('[[documento:${doc.codigo}]]'),
                onTap: () => Navigator.pop(context, doc),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (selected == null || selected.codigo == null) {
      return;
    }

    final token = '[[documento:${selected.codigo}]]';
    _insertTokenAtCursor(token);
  }

  Future<void> _insertEnlaceTokenAtCursor() async {
    final linkDocs = _documentos
        .where((doc) => doc.tipo == 'url' && doc.codigo != null)
        .toList();

    if (linkDocs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay enlaces guardados para insertar. Guarda primero enlaces adjuntos.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final selected = await showDialog<RecetaDocumento>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insertar enlace en texto'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: linkDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = linkDocs[index];
              return ListTile(
                leading: const Icon(Icons.link),
                title: Text(doc.nombre ?? 'Enlace ${doc.codigo}'),
                subtitle: Text('[[enlace:${doc.codigo}]]'),
                onTap: () => Navigator.pop(context, doc),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (selected == null || selected.codigo == null) {
      return;
    }

    final token = '[[enlace:${selected.codigo}]]';
    _insertTokenAtCursor(token);
  }

  void _insertTokenAtCursor(String token) {
    final text = _textoController.text;
    final selection = _textoController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final safeStart = start.clamp(0, text.length);
    final safeEnd = end.clamp(0, text.length);
    final from = safeStart <= safeEnd ? safeStart : safeEnd;
    final to = safeStart <= safeEnd ? safeEnd : safeStart;

    final updated = text.replaceRange(from, to, token);
    _textoController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: from + token.length),
    );
    _markDirty();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Insertado $token'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// Generate a thumbnail from the full image
  /// Target size: 200x200 pixels, JPEG quality 85%
  Uint8List? _generateThumbnail(Uint8List imageBytes) {
    return ThumbnailGenerator.generateThumbnail(imageBytes);
  }

  Future<void> _pickPortada() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null) {
        Uint8List? bytes;

        // Para web, usar bytes directamente
        if (result.files.single.bytes != null) {
          bytes = result.files.single.bytes;
        }
        // Para móvil/desktop, leer del path
        else if (result.files.single.path != null) {
          final file = File(result.files.single.path!);
          bytes = await file.readAsBytes();
        }

        if (bytes != null) {
          setState(() {
            _imagenPortadaBytes = bytes;
            _imagenPortadaNombre = result.files.single.name;
            // Generate thumbnail
            _imagenMiniaturaBytes = _generateThumbnail(bytes!);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pastePortadaImage() async {
    final bytes = await showPasteImageDialog(
      context,
      title: 'Pegar imagen',
      description:
          'Genera la imagen en formato base64 o copiala directamente al portapapeles y pulsa en pegar para agregarla a la receta.',
    );
    if (bytes == null) return;

    setState(() {
      _imagenPortadaBytes = bytes;
      _imagenPortadaNombre = 'base64';
      _imagenMiniaturaBytes =
          ThumbnailGenerator.generateThumbnail(bytes) ?? bytes;
    });
    _markDirty();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Imagen aplicada a la receta.'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMenuAtWidget(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final hasImage = _imagenPortadaBytes != null;

    final menuOptions = <PopupMenuItem<String>>[];
    if (hasImage) {
      menuOptions.add(
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar imagen'),
            ],
          ),
        ),
      );
      menuOptions.add(
        const PopupMenuItem(
          value: 'change',
          child: Row(
            children: [
              Icon(Icons.photo_library_outlined),
              SizedBox(width: 8),
              Text('Cambiar imagen'),
            ],
          ),
        ),
      );
      menuOptions.add(
        const PopupMenuItem(
          value: 'paste',
          child: Row(
            children: [
              Icon(Icons.content_paste_rounded),
              SizedBox(width: 8),
              Text('Pegar imagen'),
            ],
          ),
        ),
      );
    } else {
      menuOptions.add(
        const PopupMenuItem(
          value: 'add',
          child: Row(
            children: [
              Icon(Icons.add_photo_alternate_outlined),
              SizedBox(width: 8),
              Text('Añadir imagen'),
            ],
          ),
        ),
      );
      menuOptions.add(
        const PopupMenuItem(
          value: 'paste',
          child: Row(
            children: [
              Icon(Icons.content_paste_rounded),
              SizedBox(width: 8),
              Text('Pegar imagen'),
            ],
          ),
        ),
      );
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy,
      ),
      items: menuOptions,
    ).then((value) {
      if (value == 'delete') {
        _removeImage();
      } else if (value == 'change' || value == 'add') {
        _pickPortada();
      } else if (value == 'paste') {
        _pastePortadaImage();
      }
    });
  }

  void _viewImage() {
    if (_imagenPortadaBytes == null) return;

    showImageViewerDialog(
      context: context,
      base64Image: base64Encode(_imagenPortadaBytes!),
      title: _tituloController.text.isNotEmpty
          ? _tituloController.text
          : 'Portada',
    );
  }

  void _removeImage() {
    setState(() {
      _imagenPortadaBytes = null;
      _imagenPortadaNombre = null;
      _imagenMiniaturaBytes = null;
    });
  }

  bool _isYouTubeUrl(String? url) {
    if (url == null) return false;
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([\w-]+)',
      caseSensitive: false,
    );
    return regExp.hasMatch(url);
  }

  Future<void> _openDocumento(RecetaDocumento doc) async {
    final raw = (doc.documento ?? '').trim();
    if (raw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Documento no disponible'),
              behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    try {
      var data = raw;
      const marker = 'base64,';
      final index = data.indexOf(marker);
      if (index >= 0) {
        data = data.substring(index + marker.length);
      }
      while (data.length % 4 != 0) {
        data += '=';
      }
      final bytes = base64Decode(data);
      final dir = await getTemporaryDirectory();
      String fileName = doc.nombre ?? 'documento';
      if (!fileName.contains('.')) {
        fileName = '$fileName.pdf';
      }
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al abrir documento: ${result.message}'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir documento. $errorMessage'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<Uint8List?> _loadImageBytes(RecetaDocumento doc) async {
    try {
      // Si ya tiene los bytes en memoria
      if (doc.documento != null && doc.documento!.trim().isNotEmpty) {
        return base64Decode(doc.documento!);
      }

      // Si no, cargar desde la API
      if (doc.codigo != null) {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final response = await apiService.get(
          'api/consejo_documentos.php?codigo=${doc.codigo}',
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is Map && data['documento'] != null) {
            return base64Decode(data['documento'].toString());
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openImagen(RecetaDocumento doc) async {
    String? imageBase64 = doc.documento;

    if ((imageBase64 ?? '').trim().isEmpty && doc.codigo != null) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final response = await apiService.get(
          'api/receta_documentos.php?codigo=${doc.codigo}',
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is Map && data['documento'] != null) {
            imageBase64 = data['documento'].toString();
          }
        }
      } catch (_) {}
    }

    if ((imageBase64 ?? '').trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Imagen no disponible'),
              behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    if (!mounted) return;
    showImageViewerDialog(
      context: context,
      base64Image: imageBase64!,
      title: doc.nombre ?? 'Imagen',
    );
  }

  Future<void> _openUrl(String? url) async {
    final urlString = (url ?? '').trim();
    if (urlString.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL no disponible')),
        );
      }
      return;
    }

    try {
      await launchUrlString(urlString, mode: LaunchMode.externalApplication);
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        await _externalUrlChannel.invokeMethod('openUrl', {'url': urlString});
        return;
      }
      rethrow;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la URL: $e')),
        );
      }
    }
  }

  Future<void> _addDocumento([RecetaDocumento? existingDoc]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DocumentoDialog(documento: existingDoc),
    );

    if (result != null) {
      // Verificar si son múltiples imágenes
      if (result['multiple'] == true && result['items'] != null) {
        final items = result['items'] as List<Map<String, dynamic>>;
        if (_isNew) {
          // Si es nuevo, agregar todas las imágenes temporalmente
          setState(() {
            for (var item in items) {
              _documentos.add(RecetaDocumento(
                codigoReceta: 0,
                tipo: item['tipo'],
                nombre: item['nombre'],
                documento: item['documento'],
                url: item['url'],
                orden: _documentos.length,
              ));
            }
          });
        } else {
          // Si ya existe la receta, guardar todas en BD
          int savedCount = 0;
          for (var item in items) {
            final success =
                await _saveDocumento(item, null, showMessage: false);
            if (success) savedCount++;
          }
          if (savedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      '$savedCount imagen${savedCount == 1 ? '' : 'es'} agregada${savedCount == 1 ? '' : 's'}')),
            );
            _loadDocumentos();
          }
        }
        return;
      }

      // Proceso normal para un solo documento
      if (_isNew) {
        // Si es nuevo, agregar o editar temporalmente
        setState(() {
          if (existingDoc != null) {
            // Editar documento existente
            final index = _documentos.indexOf(existingDoc);
            if (index != -1) {
              _documentos[index] = RecetaDocumento(
                codigoReceta: 0,
                tipo: result['tipo'],
                nombre: result['nombre'],
                documento: result['documento'],
                url: result['url'],
                orden: existingDoc.orden,
              );
            }
          } else {
            // Agregar nuevo documento
            _documentos.add(RecetaDocumento(
              codigoReceta: 0,
              tipo: result['tipo'],
              nombre: result['nombre'],
              documento: result['documento'],
              url: result['url'],
              orden: _documentos.length,
            ));
          }
        });
      } else {
        // Si ya existe, guardar en BD
        await _saveDocumento(result, existingDoc);
      }
    }
  }

  Future<void> _editDocumento(RecetaDocumento doc) async {
    await _addDocumento(doc);
  }

  Future<bool> _saveDocumento(
      Map<String, dynamic> data, RecetaDocumento? existingDoc,
      {bool showMessage = true}) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      final documento = RecetaDocumento(
        codigo: existingDoc?.codigo,
        codigoReceta: _receta.codigo!,
        tipo: data['tipo'],
        nombre: data['nombre'],
        documento: data['documento'],
        url: data['url'],
        orden: existingDoc?.orden ?? _documentos.length,
      );

      documento.codusuarioa =
          authService.userCode != null ? int.parse(authService.userCode!) : 1;

      final response = existingDoc != null
          ? await apiService.put(
              'api/receta_documentos.php?codigo=${existingDoc.codigo}',
              body: json.encode(documento.toJson()),
            )
          : await apiService.post(
              'api/receta_documentos.php',
              body: json.encode(documento.toJson()),
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(existingDoc != null
                    ? 'Documento actualizado'
                    : 'Documento agregado')),
          );
          _loadDocumentos();
        }
        return true;
      }
      return false;
    } catch (e) {
      if (showMessage) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar documento. $errorMessage')),
        );
      }
      return false;
    }
  }

  Future<void> _deleteDocumento(RecetaDocumento doc) async {
    if (_isNew || doc.codigo == null) {
      setState(() {
        _documentos.remove(doc);
      });
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService
          .delete('api/receta_documentos.php?codigo=${doc.codigo}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Documento eliminado'),
              behavior: SnackBarBehavior.floating),
        );
        _loadDocumentos();
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar documento. $errorMessage'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _markDirty() {
    if (_hasChanges) return;
    setState(() {
      _hasChanges = true;
    });
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges) return true;
    return showUnsavedChangesDialog(context);
  }

  Future<void> _handleBack() async {
    if (await _confirmDiscardChanges()) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<bool> _checkDuplicateTitle(String titulo) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/recetas.php');

      if (response.statusCode == 200) {
        final List<dynamic> recetas = json.decode(response.body);

        // Buscar recetas con el mismo título (ignorando mayúsculas)
        final duplicates = recetas.where((r) {
          final recetaTitulo = r['titulo']?.toString().toLowerCase() ?? '';
          final currentTitulo = titulo.toLowerCase();

          // Si es edición, ignorar la receta actual
          if (!_isNew && r['codigo'] != null) {
            final codigo = int.tryParse(r['codigo'].toString());
            if (codigo == _receta.codigo) {
              return false;
            }
          }

          return recetaTitulo == currentTitulo;
        }).toList();

        if (duplicates.isNotEmpty) {
          // Mostrar diálogo de confirmación
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Título duplicado'),
                content: const Text(
                  'Ya existe una receta con el mismo título. ¿Desea continuar de todas formas?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Continuar'),
                  ),
                ],
              );
            },
          );

          return confirmed ?? false;
        }
      }

      return true; // No hay duplicados, continuar
    } catch (e) {
      // debugPrint('Error al verificar título duplicado: $e');
      return true; // En caso de error, permitir continuar
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Verificar título duplicado
    final canContinue = await _checkDuplicateTitle(_tituloController.text);
    if (!canContinue) {
      return; // Usuario canceló
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      _receta.titulo = _tituloController.text;
      _receta.texto = _textoController.text;
      _receta.fechaInicio = _fechaInicio;
      _receta.fechaFin = _fechaFin;
      _receta.fechaInicioPortada = _fechaInicioPortada;
      _receta.fechaFinPortada = _fechaFinPortada;
      _receta.visibleParaTodos = _visibleParaTodos ? 'S' : 'N';
      _receta.categoriaIds = List<int>.from(_selectedCategoriaIds);

      if (_imagenPortadaBytes != null) {
        _receta.imagenPortada = base64Encode(_imagenPortadaBytes!);
        _receta.imagenPortadaNombre = _imagenPortadaNombre;

        // Generar miniatura si no existe o si falló la generación anterior
        _imagenMiniaturaBytes ??= _generateThumbnail(_imagenPortadaBytes!);
      }

      // Guardar miniatura si existe (puede haberse generado automáticamente)
      if (_imagenMiniaturaBytes != null) {
        _receta.imagenMiniatura = base64Encode(_imagenMiniaturaBytes!);
      }

      if (_isNew) {
        _receta.codusuarioa =
            authService.userCode != null ? int.parse(authService.userCode!) : 1;
        final response = await apiService.post(
          'api/recetas.php',
          body: json.encode(_receta.toJson()),
        );

        if (response.statusCode == 201) {
          final responseData = json.decode(response.body);
          // Asegurarse de que recetaId sea int
          final recetaId = responseData['codigo'] is int
              ? responseData['codigo']
              : int.parse(responseData['codigo'].toString());

          // Solo asignar pacientes si NO es visible para todos
          if (!_visibleParaTodos) {
            await _assignPacientes(recetaId);
          }

          // Guardar documentos
          await _saveDocumentos(recetaId);
          // Adjuntar imagenes del cuerpo prefijadas y reemplazar [[[IMG_N]]] por [[img:codigo]]
          await _attachPrefillBodyImagesAndPatchText(recetaId);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Receta añadida correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
        }
      } else {
        _receta.codusuariom =
            authService.userCode != null ? int.parse(authService.userCode!) : 1;
        final response = await apiService.put(
          'api/recetas.php',
          body: json.encode(_receta.toJson()),
        );

        if (response.statusCode == 200) {
          // Solo actualizar pacientes si NO es visible para todos
          if (!_visibleParaTodos) {
            await _assignPacientes(_receta.codigo!);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Receta modificada correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar receta. $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _assignPacientes(int recetaId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Si es visible para todos, asignar a todos los pacientes
      List<int> pacientesToAssign = _visibleParaTodos
          ? _allPacientes.map((p) => p.codigo).toList()
          : _selectedPacientes;

      // Debug: Ver cuántos pacientes se van a asignar
      // debugPrint(
      //     'Asignando ${pacientesToAssign.length} pacientes a la receta $recetaId');
      // debugPrint('Visible para todos: $_visibleParaTodos');
      // debugPrint('Pacientes seleccionados: $_selectedPacientes');

      // Si no hay pacientes para asignar, no hacer nada
      if (pacientesToAssign.isEmpty) {
        // debugPrint('No hay pacientes para asignar');
        return;
      }

      final data = {
        'codigo_receta': recetaId,
        'codigos_pacientes': pacientesToAssign,
        'codusuarioa':
            authService.userCode != null ? int.parse(authService.userCode!) : 1,
      };

      // debugPrint('Enviando datos: ${json.encode(data)}');

      final response = await apiService.post(
        'api/receta_pacientes.php',
        body: json.encode(data),
      );

      // debugPrint('Respuesta del servidor: ${response.statusCode}');
      // debugPrint('Body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Error al asignar pacientes: ${response.body}');
      }
    } catch (e) {
      // debugPrint('Error en _assignPacientes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al asignar pacientes: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveDocumentos(int recetaId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      for (var doc in _documentos) {
        doc.codigoReceta = recetaId;
        doc.codusuarioa =
            authService.userCode != null ? int.parse(authService.userCode!) : 1;

        await apiService.post(
          'api/receta_documentos.php',
          body: json.encode(doc.toJson()),
        );
      }
    } catch (e) {
      // Error saving documents
    }
  }

  Future<int?> _createImageDocumentoAndReturnCode({
    required int recetaId,
    required Uint8List imageBytes,
    required int orden,
  }) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final payload = <String, dynamic>{
        'codigo_receta': recetaId,
        'tipo': 'imagen',
        'nombre': 'imagen_pega_${orden + 1}.png',
        'documento': base64Encode(imageBytes),
        'orden': orden,
        'codusuarioa':
            authService.userCode != null ? int.parse(authService.userCode!) : 1,
      };

      final response = await apiService.post(
        'api/receta_documentos.php',
        body: json.encode(payload),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        return null;
      }

      final dynamic parsed = json.decode(response.body);
      if (parsed is Map<String, dynamic>) {
        final codigo = int.tryParse((parsed['codigo'] ?? '').toString());
        return codigo;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _attachPrefillBodyImagesAndPatchText(int recetaId) async {
    if (_pendingPrefillBodyImages.isEmpty) {
      return;
    }

    var texto = _textoController.text;
    var changed = false;
    var baseOrden = _documentos.length;

    for (int i = 0; i < _pendingPrefillBodyImages.length; i++) {
      final marker = '[[[IMG_$i]]]';
      final code = await _createImageDocumentoAndReturnCode(
        recetaId: recetaId,
        imageBytes: _pendingPrefillBodyImages[i],
        orden: baseOrden + i,
      );
      if (code != null) {
        texto = texto.replaceAll(marker, '[[img:$code]]');
      } else {
        texto = texto.replaceAll(marker, '');
      }
      changed = true;
    }

    if (!changed) {
      return;
    }

    _textoController.text = texto;
    _receta.texto = texto;
    _receta.codigo = recetaId;
    final authService = Provider.of<AuthService>(context, listen: false);
    _receta.codusuariom =
        authService.userCode != null ? int.parse(authService.userCode!) : 1;
    final apiService = Provider.of<ApiService>(context, listen: false);
    await apiService.put(
      'api/recetas.php',
      body: json.encode(_receta.toJson()),
    );

    _pendingPrefillBodyImages = [];
  }

  String _formatDateLabel(DateTime? date, {String emptyLabel = 'Sin fecha'}) {
    if (date == null) {
      return emptyLabel;
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildCountBadge(
    int count, {
    Color activeColor = Colors.green,
    Color inactiveColor = Colors.grey,
  }) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: count > 0 ? activeColor : inactiveColor,
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
    );
  }

  Widget _buildCountBoxBadge(
    int count, {
    Color activeColor = Colors.green,
    Color inactiveColor = Colors.grey,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 32),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: count > 0 ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatusTag(String label, bool active, {VoidCallback? onTap}) {
    final tag = Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (onTap == null) return tag;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: tag,
      ),
    );
  }

  Widget _buildCollapsibleCard({
    required String title,
    String? subtitle,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
    List<Widget> titleBadges = const [],
    List<Widget> badges = const [],
    List<Widget> actions = const [],
  }) {
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (titleBadges.isNotEmpty)
                              const SizedBox(width: 6),
                            ...titleBadges,
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ...badges,
                  if (badges.isNotEmpty) const SizedBox(width: 8),
                  ...actions,
                  IconButton(
                    onPressed: onToggle,
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    tooltip: expanded ? 'Plegar' : 'Desplegar',
                  ),
                ],
              ),
            ),
          ),
          if (expanded) const Divider(height: 1),
          if (expanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: child,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(_isNew ? 'Nueva Receta' : 'Editar Receta'),
          actions: [
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _save,
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            onChanged: _markDirty,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 40),
              children: [
                // Título
                TextFormField(
                  controller: _tituloController,
                  decoration: const InputDecoration(
                    labelText: 'Título de la receta *',
                    hintText: 'Ej: Ensalada César, Pasta Carbonara',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El título es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildCollapsibleCard(
                  title: 'Categorías',
                  expanded: _categoriasExpanded,
                  onToggle: () {
                    setState(() {
                      _categoriasExpanded = !_categoriasExpanded;
                    });
                    _saveCardsExpandedState();
                  },
                  titleBadges: [
                    _buildCountBadge(_selectedCategoriaIds.length),
                  ],
                  actions: [
                    IconButton(
                      onPressed: _showCategoriasDialog,
                      icon: const Icon(Icons.category),
                      tooltip: 'Seleccionar categorías',
                    ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedCategoriaIds.isEmpty)
                        Text(
                          'Sin categorías seleccionadas',
                          style: TextStyle(color: Colors.grey[600]),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedCategoriaIds.map((id) {
                            final match = _categoriasCatalogo.firstWhere(
                              (cat) =>
                                  int.parse(cat['codigo'].toString()) == id,
                              orElse: () => {'nombre': 'Categoría $id'},
                            );
                            return Chip(
                              label: Text(match['nombre'].toString()),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildCollapsibleCard(
                  title: 'Preparación',
                  expanded: _ingredientesExpanded,
                  onToggle: () {
                    setState(() {
                      _ingredientesExpanded = !_ingredientesExpanded;
                    });
                    _saveCardsExpandedState();
                  },
                  titleBadges: [
                    _buildCountBoxBadge(_textoController.text.length),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _textoController,
                        decoration: const InputDecoration(
                          labelText: 'Preparación',
                          hintText:
                              'Describe los ingredientes y pasos de preparación',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        minLines: 12,
                        maxLines: 16,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Los ingredientes y preparación son obligatorios';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.center,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _insertImageTokenAtCursor,
                              icon: const Icon(Icons.image_outlined),
                              label: const Text('Img'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _insertDocumentoTokenAtCursor,
                              icon:
                                  const Icon(Icons.insert_drive_file_outlined),
                              label: const Text('Doc'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _insertEnlaceTokenAtCursor,
                              icon: const Icon(Icons.link_outlined),
                              label: const Text('Enlace'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Marcadores: [[img:id]], [[documento:id]] y [[enlace:id]].',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildCollapsibleCard(
                  title: 'Portada',
                  subtitle: _imagenPortadaBytes != null
                      ? (_imagenPortadaNombre ?? 'Imagen seleccionada')
                      : 'Sin imagen',
                  expanded: _imagenPortadaExpanded,
                  onToggle: () {
                    setState(() {
                      _imagenPortadaExpanded = !_imagenPortadaExpanded;
                    });
                    _saveCardsExpandedState();
                  },
                  actions: [
                    IconButton(
                      onPressed: _pickPortada,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      tooltip: 'Añadir imagen',
                    ),
                    IconButton(
                      onPressed: _pastePortadaImage,
                      icon: const Icon(Icons.content_paste_rounded),
                      tooltip: 'Pegar imagen',
                    ),
                    if (_imagenPortadaBytes != null)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _imagenPortadaBytes = null;
                            _imagenPortadaNombre = null;
                            _imagenMiniaturaBytes = null;
                          });
                          _markDirty();
                        },
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Eliminar imagen',
                      ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Builder(
                          builder: (BuildContext context) {
                            return GestureDetector(
                              onTap: () {
                                if (_imagenPortadaBytes != null) {
                                  _viewImage();
                                } else {
                                  _showMenuAtWidget(context);
                                }
                              },
                              onLongPress: () {
                                _showMenuAtWidget(context);
                              },
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: _imagenMiniaturaBytes != null
                                      ? Image.memory(
                                          _imagenMiniaturaBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : _imagenPortadaBytes != null
                                          ? Image.memory(
                                              _imagenPortadaBytes!,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: Colors.grey[200],
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.restaurant_menu,
                                                    size: 64,
                                                    color: Colors.grey[400],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Sin imagen',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 14,
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
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _imagenPortadaBytes != null
                              ? 'Toca para ver • Mantén pulsado para opciones'
                              : 'Toca para añadir imagen',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildCollapsibleCard(
                  title: 'Visualización',
                  subtitle:
                      '${_formatDateLabel(_fechaInicio)} - ${_formatDateLabel(_fechaFin)}',
                  expanded: _periodoExpanded,
                  onToggle: () {
                    setState(() {
                      _periodoExpanded = !_periodoExpanded;
                    });
                    _saveCardsExpandedState();
                  },
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Fecha inicio'),
                        subtitle: Text(_formatDateLabel(_fechaInicio)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _fechaInicio ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) {
                                  setState(() {
                                    _fechaInicio = date;
                                  });
                                }
                              },
                            ),
                            if (_fechaInicio != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _fechaInicio = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                      ListTile(
                        title: const Text('Fecha fin'),
                        subtitle: Text(_formatDateLabel(_fechaFin)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _fechaFin ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) {
                                  setState(() {
                                    _fechaFin = date;
                                  });
                                }
                              },
                            ),
                            if (_fechaFin != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _fechaFin = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildCollapsibleCard(
                  title: 'Activo, Portada',
                  expanded: _activoPortadaExpanded,
                  onToggle: () {
                    setState(() {
                      _activoPortadaExpanded = !_activoPortadaExpanded;
                    });
                    _saveCardsExpandedState();
                  },
                  actions: [
                    _buildStatusTag(
                      'A',
                      _receta.activo == 'S',
                      onTap: () {
                        setState(() {
                          _receta.activo = _receta.activo == 'S' ? 'N' : 'S';
                        });
                        _markDirty();
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildStatusTag(
                      'P',
                      _receta.mostrarPortada == 'S',
                      onTap: () {
                        setState(() {
                          _receta.mostrarPortada =
                              _receta.mostrarPortada == 'S' ? 'N' : 'S';
                        });
                        _markDirty();
                      },
                    ),
                  ],
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Activo'),
                        value: _receta.activo == 'S',
                        onChanged: (value) {
                          setState(() {
                            _receta.activo = value ? 'S' : 'N';
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Mostrar en portada'),
                        subtitle:
                            const Text('Aparecerá destacada en el inicio'),
                        value: _receta.mostrarPortada == 'S',
                        onChanged: (value) {
                          setState(() {
                            _receta.mostrarPortada = value ? 'S' : 'N';
                          });
                        },
                      ),
                      if (_receta.mostrarPortada == 'S') ...[
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            'Período destacado en portada',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                        ListTile(
                          title: const Text('Fecha inicio portada'),
                          subtitle: Text(
                            _formatDateLabel(
                              _fechaInicioPortada,
                              emptyLabel: 'Sin fecha (siempre visible)',
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        _fechaInicioPortada ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _fechaInicioPortada = date;
                                    });
                                  }
                                },
                              ),
                              if (_fechaInicioPortada != null)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _fechaInicioPortada = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                        ListTile(
                          title: const Text('Fecha fin portada'),
                          subtitle: Text(
                            _formatDateLabel(
                              _fechaFinPortada,
                              emptyLabel: 'Sin fecha (indefinido)',
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        _fechaFinPortada ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _fechaFinPortada = date;
                                    });
                                  }
                                },
                              ),
                              if (_fechaFinPortada != null)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _fechaFinPortada = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildCollapsibleCard(
                  title: 'Pacientes',
                  expanded: _pacientesExpanded,
                  onToggle: () {
                    setState(() {
                      _pacientesExpanded = !_pacientesExpanded;
                    });
                    _saveCardsExpandedState();
                  },
                  titleBadges: [
                    _buildCountBadge(_selectedPacientes.length),
                  ],
                  badges: [
                    _buildStatusTag(
                      'Todos',
                      _visibleParaTodos,
                      onTap: () {
                        setState(() {
                          _visibleParaTodos = !_visibleParaTodos;
                          if (_visibleParaTodos) {
                            _selectedPacientes.clear();
                          }
                        });
                        _markDirty();
                      },
                    ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        title: const Text('Visible para todos los pacientes'),
                        subtitle: const Text(
                            'La receta aparecerá a todos sin necesidad de seleccionarlos'),
                        value: _visibleParaTodos,
                        onChanged: (value) {
                          setState(() {
                            _visibleParaTodos = value ?? true;
                            if (_visibleParaTodos) {
                              _selectedPacientes.clear();
                            }
                          });
                          _markDirty();
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _visibleParaTodos
                            ? null
                            : () async {
                                final result = await showDialog<List<int>>(
                                  context: context,
                                  builder: (context) => _PacientesSelector(
                                    allPacientes: _allPacientes,
                                    selectedPacientes: _selectedPacientes,
                                  ),
                                );

                                if (result != null) {
                                  setState(() {
                                    _selectedPacientes = result;
                                  });
                                }
                              },
                        icon: const Icon(Icons.people),
                        label: const Text('Seleccionar pacientes'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildCollapsibleCard(
                  title: 'Documentos, URL',
                  expanded: _documentosExpanded,
                  onToggle: () {
                    setState(() {
                      _documentosExpanded = !_documentosExpanded;
                    });
                    _saveCardsExpandedState();
                  },
                  titleBadges: [
                    _buildCountBadge(_documentos.length),
                  ],
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addDocumento,
                      tooltip: 'Añadir documento/url',
                    ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_documentos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No hay documentos'),
                        )
                      else
                        ..._documentos.map((doc) {
                          // Acortar URL o nombre de archivo si tiene más de 20 caracteres
                          String segundaLinea = '';
                          if (doc.tipo == 'url') {
                            segundaLinea = doc.url ?? '';
                          } else {
                            segundaLinea = doc.nombre ?? '';
                          }
                          if (segundaLinea.length > 20) {
                            segundaLinea =
                                '${segundaLinea.substring(0, 20)}...';
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 0,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              leading: SizedBox(
                                width: 50,
                                height: 50,
                                child: doc.tipo == 'imagen'
                                    ? FutureBuilder<Uint8List?>(
                                        future: _loadImageBytes(doc),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                                  ConnectionState.waiting ||
                                              !snapshot.hasData) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Icon(
                                                Icons.image,
                                                size: 30,
                                                color: Colors.grey,
                                              ),
                                            );
                                          }
                                          return ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: Image.memory(
                                              snapshot.data!,
                                              fit: BoxFit.cover,
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: doc.tipo == 'documento'
                                              ? Colors.blue.withOpacity(0.1)
                                              : _isYouTubeUrl(doc.url)
                                                  ? Colors.red.withOpacity(0.1)
                                                  : Colors.purple
                                                      .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Icon(
                                          doc.tipo == 'documento'
                                              ? Icons.file_present
                                              : _isYouTubeUrl(doc.url)
                                                  ? Icons.play_circle
                                                  : Icons.link,
                                          size: 30,
                                          color: doc.tipo == 'documento'
                                              ? Colors.blue
                                              : _isYouTubeUrl(doc.url)
                                                  ? Colors.red
                                                  : Colors.purple,
                                        ),
                                      ),
                              ),
                              title: Text(
                                doc.nombre ?? 'Sin nombre',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    segundaLinea,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (doc.tipo == 'url')
                                        IconButton(
                                          icon: const Icon(
                                            Icons.open_in_browser,
                                            size: 20,
                                          ),
                                          color: Colors.blue,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _openUrl(doc.url),
                                          tooltip: 'Abrir URL',
                                        )
                                      else if (doc.tipo == 'imagen')
                                        IconButton(
                                          icon: const Icon(
                                            Icons.visibility,
                                            size: 20,
                                          ),
                                          color: Colors.teal,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _openImagen(doc),
                                          tooltip: 'Visualizar imagen',
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(
                                            Icons.download,
                                            size: 20,
                                          ),
                                          color: Colors.blue,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _openDocumento(doc),
                                          tooltip: 'Descargar',
                                        ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        color: Colors.blue,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _editDocumento(doc),
                                        tooltip: 'Editar',
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 20,
                                        ),
                                        color: Colors.red,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _deleteDocumento(doc),
                                        tooltip: 'Eliminar',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _textoController.dispose();
    super.dispose();
  }
}

// Dialog para seleccionar pacientes
class _PacientesSelector extends StatefulWidget {
  final List<Paciente> allPacientes;
  final List<int> selectedPacientes;

  const _PacientesSelector({
    required this.allPacientes,
    required this.selectedPacientes,
  });

  @override
  State<_PacientesSelector> createState() => _PacientesSelectorState();
}

class _PacientesSelectorState extends State<_PacientesSelector> {
  static const String _prefsPacientesSearchVisible =
      'receta_edit_pacientes_search_visible';

  late List<int> _selected;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = true;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedPacientes);
    _loadSearchVisibility();
  }

  Future<void> _loadSearchVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showSearch = prefs.getBool(_prefsPacientesSearchVisible) ?? true;
    });
  }

  Future<void> _setSearchVisibility(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsPacientesSearchVisible, value);
  }

  void _toggleSearchVisibility() {
    final nextValue = !_showSearch;
    setState(() {
      _showSearch = nextValue;
      if (!_showSearch && _searchQuery.isNotEmpty) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
    _setSearchVisibility(nextValue);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allPacientes.where((p) {
      if (_searchQuery.isEmpty) return true;
      final fullName = p.nombre.toLowerCase();
      return fullName.contains(_searchQuery.toLowerCase());
    }).toList();

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Seleccionar pacientes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: _toggleSearchVisibility,
            icon: Icon(_showSearch ? Icons.search_off : Icons.search),
            tooltip: _showSearch ? 'Ocultar búsqueda' : 'Mostrar búsqueda',
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
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
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showSearch) ...[
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar paciente',
                  prefixIcon: IconButton(
                    tooltip:
                        _searchQuery.isNotEmpty ? 'Limpiar búsqueda' : 'Buscar',
                    onPressed: _searchQuery.isNotEmpty
                        ? () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          }
                        : null,
                    icon: Icon(
                      _searchQuery.isNotEmpty ? Icons.clear : Icons.search,
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
                    _searchQuery = value.trim();
                  });
                },
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selected =
                          widget.allPacientes.map((p) => p.codigo).toList();
                    });
                  },
                  icon: const Icon(Icons.check_box),
                  label: const Text('Todos'),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selected.clear();
                    });
                  },
                  icon: const Icon(Icons.check_box_outline_blank),
                  label: const Text('Ninguno'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final paciente = filtered[index];
                  final isSelected = _selected.contains(paciente.codigo);

                  return CheckboxListTile(
                    title: Text(paciente.nombre),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(paciente.codigo);
                        } else {
                          _selected.remove(paciente.codigo);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
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
                  color: _selected.isNotEmpty ? Colors.blue : Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${_selected.length}',
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
  }
}

// Dialog para agregar documento
class _DocumentoDialog extends StatefulWidget {
  final RecetaDocumento? documento;

  const _DocumentoDialog({this.documento});

  @override
  State<_DocumentoDialog> createState() => _DocumentoDialogState();
}

class _DocumentoDialogState extends State<_DocumentoDialog> {
  static String _lastSelectedTipo = 'url'; // Recordar último tipo seleccionado

  late String _tipo;
  final _nombreController = TextEditingController();
  final _urlController = TextEditingController();
  Uint8List? _documentoBytes;
  String? _documentoNombre;
  int? _maxImageWidth;
  int? _maxImageHeight;

  // Para múltiples imágenes
  final List<Map<String, dynamic>> _imagenes = [];
  int? _selectedImageIndex;
  final _selectedImageNombreController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadImageLimits();
    if (widget.documento != null) {
      _tipo = widget.documento!.tipo;
      _nombreController.text = widget.documento!.nombre ?? '';
      if (_tipo == 'url') {
        _urlController.text = widget.documento!.url ?? '';
      } else if (widget.documento!.documento != null) {
        _documentoBytes = base64Decode(widget.documento!.documento!);
        _documentoNombre = widget.documento!.nombre;
      }
    } else {
      _tipo = _lastSelectedTipo; // Usar último tipo seleccionado
    }
  }

  Future<void> _loadImageLimits() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final parametro = await apiService
          .getParametro('tamaño_maximo_imagenes_consejos_recetas');

      if (parametro != null) {
        _maxImageWidth = int.tryParse((parametro['valor'] ?? '').toString());
        _maxImageHeight = int.tryParse((parametro['valor2'] ?? '').toString());
      }
    } catch (_) {}
  }

  Uint8List _resizeImageIfNeeded(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;

      final maxWidth = _maxImageWidth;
      final maxHeight = _maxImageHeight;

      if (maxWidth == null ||
          maxHeight == null ||
          maxWidth <= 0 ||
          maxHeight <= 0) {
        return bytes;
      }

      if (image.width <= maxWidth && image.height <= maxHeight) {
        return bytes;
      }

      final widthScale = maxWidth / image.width;
      final heightScale = maxHeight / image.height;
      final scale = widthScale < heightScale ? widthScale : heightScale;

      final resized = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );

      return Uint8List.fromList(img.encodePng(resized));
    } catch (_) {
      return bytes;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si estamos editando o si no es tipo imagen, ocultar el campo nombre (se usará el del carrusel)
    final showNombreField = widget.documento != null || _tipo != 'imagen';

    return AlertDialog(
      title:
          Text(widget.documento != null ? 'Editar adjunto' : 'Agregar adjunto'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'url', label: Text('URL'), icon: Icon(Icons.link)),
                  ButtonSegment(
                      value: 'documento',
                      label: Text('Doc'),
                      icon: Icon(Icons.file_present)),
                  ButtonSegment(
                      value: 'imagen',
                      label: Text('Img'),
                      icon: Icon(Icons.image)),
                ],
                selected: {_tipo},
                onSelectionChanged: (Set<String> selection) {
                  setState(() {
                    _tipo = selection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (showNombreField)
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
              if (showNombreField) const SizedBox(height: 16),
              if (_tipo == 'url')
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    border: OutlineInputBorder(),
                  ),
                )
              else
                Column(
                  children: [
                    if (_documentoNombre != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            // Miniatura de imagen si es tipo imagen
                            if (_tipo == 'imagen' && _documentoBytes != null)
                              GestureDetector(
                                onTap: () {
                                  showImageViewerDialog(
                                    context: context,
                                    base64Image: base64Encode(_documentoBytes!),
                                    title: _nombreController.text.isNotEmpty
                                        ? _nombreController.text
                                        : _documentoNombre!,
                                  );
                                },
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.memory(
                                      _documentoBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const Icon(Icons.attach_file, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _documentoNombre!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('No se ha seleccionado archivo'),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final allowMultiple =
                              _tipo == 'imagen' && widget.documento == null;
                          FilePickerResult? result =
                              await FilePicker.platform.pickFiles(
                            type: _tipo == 'imagen'
                                ? FileType.image
                                : FileType.any,
                            allowMultiple: allowMultiple,
                          );
                          if (result != null) {
                            if (allowMultiple) {
                              // Múltiples imágenes
                              for (var file in result.files) {
                                Uint8List? bytes;
                                if (file.bytes != null) {
                                  bytes = _resizeImageIfNeeded(file.bytes!);
                                } else if (file.path != null) {
                                  final fileObj = File(file.path!);
                                  final readBytes = await fileObj.readAsBytes();
                                  bytes = _resizeImageIfNeeded(readBytes);
                                }

                                if (bytes != null) {
                                  // Extraer nombre sin extensión
                                  String nombreSinExt = file.name;
                                  final lastDot = nombreSinExt.lastIndexOf('.');
                                  if (lastDot > 0) {
                                    nombreSinExt =
                                        nombreSinExt.substring(0, lastDot);
                                  }

                                  setState(() {
                                    _imagenes.add({
                                      'bytes': bytes,
                                      'nombre': nombreSinExt,
                                    });
                                  });
                                }
                              }
                              if (_imagenes.isNotEmpty &&
                                  _selectedImageIndex == null) {
                                setState(() {
                                  _selectedImageIndex = 0;
                                  _selectedImageNombreController.text =
                                      _imagenes[0]['nombre'];
                                });
                              }
                            } else {
                              // Una sola imagen/documento
                              if (result.files.single.bytes != null) {
                                final pickedBytes = _tipo == 'imagen'
                                    ? _resizeImageIfNeeded(
                                        result.files.single.bytes!)
                                    : result.files.single.bytes!;
                                setState(() {
                                  _documentoBytes = pickedBytes;
                                  _documentoNombre = result.files.single.name;
                                });
                              } else if (result.files.single.path != null) {
                                // Para plataformas de escritorio, leer los bytes del archivo
                                final file = File(result.files.single.path!);
                                final bytes = await file.readAsBytes();
                                final pickedBytes = _tipo == 'imagen'
                                    ? _resizeImageIfNeeded(bytes)
                                    : bytes;
                                setState(() {
                                  _documentoBytes = pickedBytes;
                                  _documentoNombre = result.files.single.name;
                                });
                              }
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Error al seleccionar archivo: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.upload_file),
                      label: Text(_documentoNombre != null
                          ? (_tipo == 'imagen'
                              ? 'Cambiar imagen'
                              : 'Cambiar archivo')
                          : (_tipo == 'imagen'
                              ? (_imagenes.isEmpty
                                  ? 'Seleccionar imágenes'
                                  : 'Añadir más imágenes')
                              : 'Seleccionar archivo')),
                    ),
                    if (_tipo == 'imagen' &&
                        _maxImageWidth != null &&
                        _maxImageHeight != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Máximo: ${_maxImageWidth}x${_maxImageHeight}px',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    // Carrusel de miniaturas para múltiples imágenes
                    if (_tipo == 'imagen' && _imagenes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        '${_imagenes.length} imagen${_imagenes.length == 1 ? '' : 'es'} seleccionada${_imagenes.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imagenes.length,
                          itemBuilder: (context, index) {
                            final imagen = _imagenes[index];
                            final isSelected = _selectedImageIndex == index;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImageIndex = index;
                                  _selectedImageNombreController.text =
                                      _imagenes[index]['nombre'];
                                });
                              },
                              child: Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.shade300,
                                    width: isSelected ? 3 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.memory(
                                        imagen['bytes'],
                                        width: 100,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _imagenes.removeAt(index);
                                              if (_selectedImageIndex ==
                                                  index) {
                                                _selectedImageIndex =
                                                    _imagenes.isNotEmpty
                                                        ? 0
                                                        : null;
                                                if (_selectedImageIndex !=
                                                    null) {
                                                  _selectedImageNombreController
                                                          .text =
                                                      _imagenes[0]['nombre'];
                                                } else {
                                                  _selectedImageNombreController
                                                      .clear();
                                                }
                                              } else if (_selectedImageIndex !=
                                                      null &&
                                                  _selectedImageIndex! >
                                                      index) {
                                                _selectedImageIndex =
                                                    _selectedImageIndex! - 1;
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_selectedImageIndex != null) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _selectedImageNombreController,
                          decoration: InputDecoration(
                            labelText:
                                'Nombre para mostrar (imagen ${_selectedImageIndex! + 1})',
                            border: const OutlineInputBorder(),
                            helperText:
                                'Pulse en una miniatura para editar su nombre',
                          ),
                          onChanged: (value) {
                            if (_selectedImageIndex != null) {
                              _imagenes[_selectedImageIndex!]['nombre'] = value
                                      .isEmpty
                                  ? _imagenes[_selectedImageIndex!]['nombre']
                                  : value;
                            }
                          },
                        ),
                      ],
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_tipo == 'url' && _urlController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('La URL es obligatoria')),
              );
              return;
            }

            // Validación para múltiples imágenes
            if (_tipo == 'imagen' && _imagenes.isNotEmpty) {
              // Devolver lista de imágenes
              final resultados = _imagenes.map((img) {
                return {
                  'tipo': 'imagen',
                  'nombre': img['nombre'],
                  'url': null,
                  'documento': base64Encode(img['bytes']),
                };
              }).toList();
              _lastSelectedTipo = _tipo; // Guardar último tipo
              Navigator.pop(context, {'multiple': true, 'items': resultados});
              return;
            }

            // Validación para documento/imagen única
            if ((_tipo == 'documento' || _tipo == 'imagen') &&
                _documentoBytes == null &&
                _imagenes.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(_tipo == 'imagen'
                        ? 'Debe seleccionar una imagen'
                        : 'Debe seleccionar un archivo')),
              );
              return;
            }

            _lastSelectedTipo = _tipo; // Guardar último tipo
            Navigator.pop(context, {
              'tipo': _tipo,
              'nombre': _nombreController.text.isEmpty
                  ? _documentoNombre ?? _urlController.text
                  : _nombreController.text,
              'url': _tipo == 'url' ? _urlController.text : null,
              'documento': (_tipo == 'documento' || _tipo == 'imagen') &&
                      _documentoBytes != null
                  ? base64Encode(_documentoBytes!)
                  : null,
            });
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _urlController.dispose();
    _selectedImageNombreController.dispose();
    super.dispose();
  }
}
