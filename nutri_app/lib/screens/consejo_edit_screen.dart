import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/consejo.dart';
import '../models/consejo_documento.dart';
import '../models/paciente.dart';
import '../widgets/unsaved_changes_dialog.dart';
import '../widgets/image_viewer_dialog.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ConsejoEditScreen extends StatefulWidget {
  const ConsejoEditScreen({super.key});

  @override
  State<ConsejoEditScreen> createState() => _ConsejoEditScreenState();
}

class _ConsejoEditScreenState extends State<ConsejoEditScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  final _formKey = GlobalKey<FormState>();
  late Consejo _consejo;
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
  List<ConsejoDocumento> _documentos = [];
  bool _visibleParaTodos = false;
  bool _categoriasLoading = false;
  List<Map<String, dynamic>> _categoriasCatalogo = [];
  List<int> _selectedCategoriaIds = [];

  Uint8List? _imagenPortadaBytes;
  String? _imagenPortadaNombre;
  Uint8List? _imagenMiniaturaBytes;

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();

    // Solo ejecutar una vez
    if (_isInitialized) return;
    _isInitialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Consejo) {
      _consejo = args;
      _isNew = false;

      // Cargar el consejo completo desde la API para obtener imagen_portada
      await _loadConsejoCompleto(_consejo.codigo!);
    } else {
      _consejo = Consejo(
        titulo: '',
        texto: '',
        activo: 'S',
        mostrarPortada: 'N',
        visibleParaTodos: 'N',
      );
      _isNew = true;
      _selectedCategoriaIds = [];
      _loadPacientes();
      _loadCategorias();
    }
  }

  Future<void> _loadConsejoCompleto(int codigo) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/consejos.php?codigo=$codigo');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _consejo = Consejo.fromJson(data);

        // Inicializar campos del formulario
        _tituloController.text = _consejo.titulo;
        _textoController.text = _consejo.texto;
        _fechaInicio = _consejo.fechaInicio;
        _fechaFin = _consejo.fechaFin;
        _fechaInicioPortada = _consejo.fechaInicioPortada;
        _fechaFinPortada = _consejo.fechaFinPortada;
        _visibleParaTodos = _consejo.visibleParaTodos == 'S';

        if (_consejo.imagenPortada != null) {
          _imagenPortadaBytes = base64Decode(_consejo.imagenPortada!);
          _imagenPortadaNombre = _consejo.imagenPortadaNombre;
        }

        if (_consejo.imagenMiniatura != null) {
          _imagenMiniaturaBytes = base64Decode(_consejo.imagenMiniatura!);
        } else if (_imagenPortadaBytes != null) {
          // Si tiene imagen pero no miniatura, generarla automáticamente
          _imagenMiniaturaBytes = _generateThumbnail(_imagenPortadaBytes!);
        }

        _selectedCategoriaIds = List<int>.from(_consejo.categoriaIds);

        _initializeData();
        _loadDocumentos();
        _loadCategorias();
      }
    } catch (e) {
      // debugPrint('Error cargando consejo completo: $e');
      // Si falla, usar los datos parciales que tenemos
      _tituloController.text = _consejo.titulo;
      _textoController.text = _consejo.texto;
      _fechaInicio = _consejo.fechaInicio;
      _fechaFin = _consejo.fechaFin;
      _fechaInicioPortada = _consejo.fechaInicioPortada;
      _fechaFinPortada = _consejo.fechaFinPortada;
      _visibleParaTodos = _consejo.visibleParaTodos == 'S';
      _selectedCategoriaIds = List<int>.from(_consejo.categoriaIds);
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
      'api/consejos.php?categorias=1',
      body: json.encode(payload),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    return null;
  }

  Future<void> _showCategoriasDialog() async {
    final searchController = TextEditingController();
    final newController = TextEditingController();
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
              title: const Text('Categorias del consejo'),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar categoria',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 12),
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
                              labelText: 'Nueva categoria',
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategoriaIds = tempSelected;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Aplicar'),
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
    //     '_initializeData: Iniciando carga de datos para consejo ${_consejo.codigo}');
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
          ),
        );
      }
    }
  }

  Future<void> _loadPacientesAsignados() async {
    if (_isNew) {
      // debugPrint(
      //     '_loadPacientesAsignados: Es un consejo nuevo, no se cargan pacientes');
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final url = 'api/consejo_pacientes.php?consejo=${_consejo.codigo}';
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
                  Text('Error al cargar pacientes asignados: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadDocumentos() async {
    if (_isNew) return;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService
          .get('api/consejo_documentos.php?consejo=${_consejo.codigo}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _documentos =
              data.map((item) => ConsejoDocumento.fromJson(item)).toList();
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
          ),
        );
      }
      return;
    }

    final selected = await showDialog<ConsejoDocumento>(
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
          ),
        );
      }
      return;
    }

    final selected = await showDialog<ConsejoDocumento>(
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
          ),
        );
      }
      return;
    }

    final selected = await showDialog<ConsejoDocumento>(
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
        SnackBar(content: Text('Insertado $token')),
      );
    }
  }

  /// Generate a thumbnail from the full image
  /// Target size: 200x200 pixels, JPEG quality 85%
  Uint8List? _generateThumbnail(Uint8List imageBytes) {
    try {
      // Decode the image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Calculate thumbnail size maintaining aspect ratio
      const int maxSize = 200;
      img.Image thumbnail;

      if (image.width > image.height) {
        thumbnail = img.copyResize(image, width: maxSize);
      } else {
        thumbnail = img.copyResize(image, height: maxSize);
      }

      // Encode as JPEG with 85% quality
      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 85));
    } catch (e) {
      // debugPrint('Error generating thumbnail: $e');
      return null;
    }
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
        ),
      );
    }
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
          child: Text('Eliminar imagen'),
        ),
      );
      menuOptions.add(
        const PopupMenuItem(
          value: 'change',
          child: Text('Cambiar imagen'),
        ),
      );
    } else {
      menuOptions.add(
        const PopupMenuItem(
          value: 'add',
          child: Text('Añadir imagen'),
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
          : 'Imagen de portada',
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

  Future<void> _openDocumento(ConsejoDocumento doc) async {
    final raw = (doc.documento ?? '').trim();
    if (raw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento no disponible')),
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
              content: Text('Error al abrir documento: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir documento. $errorMessage')),
        );
      }
    }
  }

  Future<Uint8List?> _loadImageBytes(ConsejoDocumento doc) async {
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

  Future<void> _openImagen(ConsejoDocumento doc) async {
    String? imageBase64 = doc.documento;

    if ((imageBase64 ?? '').trim().isEmpty && doc.codigo != null) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final response = await apiService.get(
          'api/consejo_documentos.php?codigo=${doc.codigo}',
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
          const SnackBar(content: Text('Imagen no disponible')),
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

  Future<void> _addDocumento([ConsejoDocumento? existingDoc]) async {
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
              _documentos.add(ConsejoDocumento(
                codigoConsejo: 0,
                tipo: item['tipo'],
                nombre: item['nombre'],
                documento: item['documento'],
                url: item['url'],
                orden: _documentos.length,
              ));
            }
          });
        } else {
          // Si ya existe el consejo, guardar todas en BD
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
              _documentos[index] = ConsejoDocumento(
                codigoConsejo: 0,
                tipo: result['tipo'],
                nombre: result['nombre'],
                documento: result['documento'],
                url: result['url'],
                orden: existingDoc.orden,
              );
            }
          } else {
            // Agregar nuevo documento
            _documentos.add(ConsejoDocumento(
              codigoConsejo: 0,
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

  Future<void> _editDocumento(ConsejoDocumento doc) async {
    await _addDocumento(doc);
  }

  Future<bool> _saveDocumento(
      Map<String, dynamic> data, ConsejoDocumento? existingDoc,
      {bool showMessage = true}) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      final documento = ConsejoDocumento(
        codigo: existingDoc?.codigo,
        codigoConsejo: _consejo.codigo!,
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
              'api/consejo_documentos.php?codigo=${existingDoc.codigo}',
              body: json.encode(documento.toJson()),
            )
          : await apiService.post(
              'api/consejo_documentos.php',
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
          SnackBar(
            content: Text('Error al guardar documento. $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _deleteDocumento(ConsejoDocumento doc) async {
    if (_isNew || doc.codigo == null) {
      setState(() {
        _documentos.remove(doc);
      });
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService
          .delete('api/consejo_documentos.php?codigo=${doc.codigo}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento eliminado')),
        );
        _loadDocumentos();
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar documento. $errorMessage'),
          backgroundColor: Colors.red,
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
      final response = await apiService.get('api/consejos.php');

      if (response.statusCode == 200) {
        final List<dynamic> consejos = json.decode(response.body);

        // Buscar consejos con el mismo título (ignorando mayúsculas)
        final duplicates = consejos.where((c) {
          final consejoTitulo = c['titulo']?.toString().toLowerCase() ?? '';
          final currentTitulo = titulo.toLowerCase();

          // Si es edición, ignorar el consejo actual
          if (!_isNew && c['codigo'] != null) {
            final codigo = int.tryParse(c['codigo'].toString());
            if (codigo == _consejo.codigo) {
              return false;
            }
          }

          return consejoTitulo == currentTitulo;
        }).toList();

        if (duplicates.isNotEmpty) {
          // Mostrar diálogo de confirmación
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Título duplicado'),
                content: const Text(
                  'Ya existe un consejo con el mismo título. ¿Desea continuar de todas formas?',
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

      _consejo.titulo = _tituloController.text;
      _consejo.texto = _textoController.text;
      _consejo.fechaInicio = _fechaInicio;
      _consejo.fechaFin = _fechaFin;
      _consejo.fechaInicioPortada = _fechaInicioPortada;
      _consejo.fechaFinPortada = _fechaFinPortada;
      _consejo.visibleParaTodos = _visibleParaTodos ? 'S' : 'N';
      _consejo.categoriaIds = List<int>.from(_selectedCategoriaIds);

      if (_imagenPortadaBytes != null) {
        _consejo.imagenPortada = base64Encode(_imagenPortadaBytes!);
        _consejo.imagenPortadaNombre = _imagenPortadaNombre;

        // Generar miniatura si no existe o si falló la generación anterior
        _imagenMiniaturaBytes ??= _generateThumbnail(_imagenPortadaBytes!);
      }

      // Guardar miniatura si existe (puede haberse generado automáticamente)
      if (_imagenMiniaturaBytes != null) {
        _consejo.imagenMiniatura = base64Encode(_imagenMiniaturaBytes!);
      }

      if (_isNew) {
        _consejo.codusuarioa =
            authService.userCode != null ? int.parse(authService.userCode!) : 1;
        final response = await apiService.post(
          'api/consejos.php',
          body: json.encode(_consejo.toJson()),
        );

        if (response.statusCode == 201) {
          final responseData = json.decode(response.body);
          // Asegurarse de que consejoId sea int
          final consejoId = responseData['codigo'] is int
              ? responseData['codigo']
              : int.parse(responseData['codigo'].toString());

          // Asignar pacientes según corresponda:
          // - Si es visible para todos Y el check está activado, asignar a todos
          // - Si NO es visible para todos, asignar solo a los seleccionados
          await _assignPacientes(consejoId);

          // Guardar documentos
          await _saveDocumentos(consejoId);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Consejo añadido correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
        }
      } else {
        _consejo.codusuariom =
            authService.userCode != null ? int.parse(authService.userCode!) : 1;
        final response = await apiService.put(
          'api/consejos.php',
          body: json.encode(_consejo.toJson()),
        );

        if (response.statusCode == 200) {
          // Asignar pacientes según corresponda:
          // - Si es visible para todos Y el check está activado, asignar a todos
          // - Si NO es visible para todos, asignar solo a los seleccionados
          await _assignPacientes(_consejo.codigo!);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Consejo modificado correctamente'),
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
            content: Text('Error al guardar consejo. $errorMessage'),
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

  Future<void> _assignPacientes(int consejoId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Si es visible para todos, NO asignar pacientes específicos
      // (el consejo aparecerá automáticamente para todos sin registros en nu_consejo_usuario)
      if (_visibleParaTodos) {
        debugPrint(
            'Consejo visible para todos - No se asignan pacientes específicos');
        // Eliminar asignaciones previas si existían
        final data = {
          'codigo_consejo': consejoId,
          'codigos_pacientes':
              [], // Lista vacía para eliminar todas las asignaciones
          'codusuarioa': authService.userCode != null
              ? int.parse(authService.userCode!)
              : 1,
        };

        await apiService.post(
          'api/consejo_pacientes.php',
          body: json.encode(data),
        );
        return;
      }

      // Si NO es visible para todos, asignar solo a los pacientes seleccionados
      List<int> pacientesToAssign = _selectedPacientes;

      // Debug: Ver cuántos pacientes se van a asignar
      debugPrint(
          'Asignando ${pacientesToAssign.length} pacientes al consejo $consejoId');
      debugPrint('Pacientes seleccionados: $_selectedPacientes');

      // Si no hay pacientes para asignar, no hacer nada
      if (pacientesToAssign.isEmpty) {
        debugPrint('No hay pacientes para asignar');
        return;
      }

      final data = {
        'codigo_consejo': consejoId,
        'codigos_pacientes': pacientesToAssign,
        'codusuarioa':
            authService.userCode != null ? int.parse(authService.userCode!) : 1,
      };

      debugPrint('Enviando datos: ${json.encode(data)}');

      final response = await apiService.post(
        'api/consejo_pacientes.php',
        body: json.encode(data),
      );

      debugPrint('Respuesta del servidor: ${response.statusCode}');
      debugPrint('Body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Error al asignar pacientes: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error en _assignPacientes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al asignar pacientes: ${e.toString()}')),
        );
      }
      rethrow; // Re-lanzar la excepción para que se capture arriba
    }
  }

  Future<void> _saveDocumentos(int consejoId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      for (var doc in _documentos) {
        doc.codigoConsejo = consejoId;
        doc.codusuarioa =
            authService.userCode != null ? int.parse(authService.userCode!) : 1;

        await apiService.post(
          'api/consejo_documentos.php',
          body: json.encode(doc.toJson()),
        );
      }
    } catch (e) {
      // Error saving documents
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(_isNew ? 'Nuevo Consejo' : 'Editar Consejo'),
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
        body: Form(
          key: _formKey,
          onChanged: _markDirty,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Título
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El título es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Categorías
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Categorías',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: _showCategoriasDialog,
                            icon: const Icon(Icons.category),
                            iconSize: 30,
                            tooltip: 'Seleccionar categorias',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                                label: Text(match['nombre'].toString()));
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Texto
              TextFormField(
                controller: _textoController,
                decoration: const InputDecoration(
                  labelText: 'Texto *',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El texto es obligatorio';
                  }
                  return null;
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
                      icon: const Icon(Icons.insert_drive_file_outlined),
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
              const SizedBox(height: 16),

              // Imagen de portada
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Imagen de portada',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
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
                                                    Icons.article,
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
              ),
              const SizedBox(height: 16),

              // Fechas
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Período de visualización',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: const Text('Fecha inicio'),
                        subtitle: Text(_fechaInicio != null
                            ? '${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}'
                            : 'Sin fecha'),
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
                        subtitle: Text(_fechaFin != null
                            ? '${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}'
                            : 'Sin fecha'),
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
              ),
              const SizedBox(height: 16),

              // Opciones
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Activo'),
                        value: _consejo.activo == 'S',
                        onChanged: (value) {
                          setState(() {
                            _consejo.activo = value ? 'S' : 'N';
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Mostrar en portada'),
                        subtitle:
                            const Text('Aparecerá destacado en el inicio'),
                        value: _consejo.mostrarPortada == 'S',
                        onChanged: (value) {
                          setState(() {
                            _consejo.mostrarPortada = value ? 'S' : 'N';
                          });
                        },
                      ),
                      // Campos de fechas de portada (solo visibles si mostrarPortada está activo)
                      if (_consejo.mostrarPortada == 'S') ...[
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
                          subtitle: Text(_fechaInicioPortada != null
                              ? '${_fechaInicioPortada!.day}/${_fechaInicioPortada!.month}/${_fechaInicioPortada!.year}'
                              : 'Sin fecha (siempre visible)'),
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
                          subtitle: Text(_fechaFinPortada != null
                              ? '${_fechaFinPortada!.day}/${_fechaFinPortada!.month}/${_fechaFinPortada!.year}'
                              : 'Sin fecha (indefinido)'),
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
              ),
              const SizedBox(height: 16),

              // Pacientes
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pacientes',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _visibleParaTodos
                                ? 'Todos los pacientes'
                                : '${_selectedPacientes.length} seleccionados',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('Visible para todos los pacientes'),
                        subtitle: const Text(
                            'El consejo aparecerá a todos sin necesidad de seleccionarlos'),
                        value: _visibleParaTodos,
                        onChanged: (value) {
                          setState(() {
                            _visibleParaTodos = value ?? false;
                            if (_visibleParaTodos) {
                              _selectedPacientes.clear();
                            }
                          });
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
              ),
              const SizedBox(height: 16),

              // Documentos
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Documentos y URLs',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _addDocumento,
                          ),
                        ],
                      ),
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
                                vertical: 4, horizontal: 0),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
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
                                              child: const Icon(Icons.image,
                                                  size: 30, color: Colors.grey),
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
                                    fontWeight: FontWeight.bold),
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
                                              size: 20),
                                          color: Colors.blue,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _openUrl(doc.url),
                                          tooltip: 'Abrir URL',
                                        )
                                      else if (doc.tipo == 'imagen')
                                        IconButton(
                                          icon: const Icon(Icons.visibility,
                                              size: 20),
                                          color: Colors.teal,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _openImagen(doc),
                                          tooltip: 'Visualizar imagen',
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(Icons.download,
                                              size: 20),
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
                                        icon:
                                            const Icon(Icons.delete, size: 20),
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
              ),
            ],
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
  late List<int> _selected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedPacientes);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allPacientes.where((p) {
      if (_searchQuery.isEmpty) return true;
      final fullName = p.nombre.toLowerCase();
      return fullName.contains(_searchQuery.toLowerCase());
    }).toList();

    return AlertDialog(
      title: const Text('Seleccionar pacientes'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 8),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

// Dialog para agregar documento
class _DocumentoDialog extends StatefulWidget {
  final ConsejoDocumento? documento;

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
