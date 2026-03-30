import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:nutri_app/models/charla_diapositiva.dart';
import 'package:nutri_app/models/charla_seminario.dart';
import 'package:nutri_app/screens/charla_seminario_detail_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/widgets/paste_image_dialog.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CharlaSeminarioEditScreen extends StatefulWidget {
  const CharlaSeminarioEditScreen({super.key, this.charla});

  final CharlaSeminario? charla;

  @override
  State<CharlaSeminarioEditScreen> createState() =>
      _CharlaSeminarioEditScreenState();
}

class _CharlaSeminarioEditScreenState extends State<CharlaSeminarioEditScreen> {
  static const String _prefsCategoriasExpanded =
      'charla_edit_categorias_expanded';
  static const String _prefsDescripcionExpanded =
      'charla_edit_descripcion_expanded';
  static const String _prefsTogglesExpanded = 'charla_edit_toggles_expanded';

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descripcionCtrl;

  bool _activo = true;
  bool _mostrarPortada = false;
  bool _visibleParaTodos = false;
  bool _saving = false;
  bool _loadingDetail = false;
  bool _hasChanges = false;
  bool _suspendDirtyTracking = false;
  bool _descripcionExpanded = true;
  bool _togglesExpanded = true;
  bool _categoriasExpanded = true;
  bool _uploadingSlide = false;
  bool _recordingAudio = false;
  int? _recordingSlideCodigo;
  DateTime? _recordingStartedAt;
  String? _recordingFilePath;

  List<Map<String, dynamic>> _categorias = <Map<String, dynamic>>[];
  List<int> _selectedCategoriaIds = <int>[];

  String? _imagenPortadaBase64;
  String? _imagenMiniaturaBase64;
  String? _imagenNombre;

  List<CharlaDiapositiva> _slides = <CharlaDiapositiva>[];
  final Map<int, MemoryImage> _slideCache = <int, MemoryImage>{};

  bool get _editing => widget.charla?.codigo != null;

  String _extractApiErrorMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return 'Respuesta vacía del servidor.';
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        final error = decoded['error']?.toString().trim();
        if (error != null && error.isNotEmpty) {
          return error;
        }
      }
    } catch (_) {}
    return trimmed;
  }

  @override
  void initState() {
    super.initState();
    final c = widget.charla;
    _tituloCtrl = TextEditingController(text: c?.titulo ?? '');
    _descripcionCtrl = TextEditingController(text: c?.descripcion ?? '');
    for (final controller in [_tituloCtrl, _descripcionCtrl]) {
      controller.addListener(_markDirty);
    }
    _activo = c?.activo != 'N';
    _mostrarPortada = c?.mostrarPortada == 'S';
    _visibleParaTodos = c?.visibleParaTodos == 'S';
    _selectedCategoriaIds = List<int>.from(c?.categoriaIds ?? <int>[]);
    _imagenPortadaBase64 = c?.imagenPortada;
    _imagenMiniaturaBase64 = c?.imagenMiniatura;
    _imagenNombre = c?.imagenPortadaNombre;
    _restoreUiState();
    _loadCategorias();
    if (_editing) {
      _loadDetail();
    }
  }

  Future<void> _restoreUiState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _descripcionExpanded =
            prefs.getBool(_prefsDescripcionExpanded) ?? _descripcionExpanded;
        _togglesExpanded =
            prefs.getBool(_prefsTogglesExpanded) ?? _togglesExpanded;
        _categoriasExpanded =
            prefs.getBool(_prefsCategoriasExpanded) ?? _categoriasExpanded;
      });
    } catch (_) {
      // Ignorar errores de persistencia.
    }
  }

  Future<void> _saveCategoriasExpanded(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsCategoriasExpanded, value);
    } catch (_) {
      // Ignorar errores de persistencia.
    }
  }

  Future<void> _saveDescripcionExpanded(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsDescripcionExpanded, value);
    } catch (_) {
      // Ignorar errores de persistencia.
    }
  }

  Future<void> _saveTogglesExpanded(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsTogglesExpanded, value);
    } catch (_) {
      // Ignorar errores de persistencia.
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _audioRecorder.dispose();
    _slideCache.clear();
    super.dispose();
  }

  // ─── LOADERS ────────────────────────────────────────────────────

  Future<void> _loadCategorias() async {
    final response = await context.read<ApiService>().get(
          'api/charlas_seminarios.php?categorias=1',
        );
    if (response.statusCode == 200 && mounted) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _categorias = data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      });
    }
  }

  Future<void> _loadDetail() async {
    if (widget.charla?.codigo == null) return;
    setState(() => _loadingDetail = true);
    try {
      final response = await context.read<ApiService>().get(
            'api/charlas_seminarios.php?codigo=${widget.charla!.codigo}',
          );
      if (response.statusCode == 200 && mounted) {
        final data = Map<String, dynamic>.from(
          jsonDecode(response.body) as Map,
        );
        final c = CharlaSeminario.fromJson(data);
        _suspendDirtyTracking = true;
        setState(() {
          _tituloCtrl.text = c.titulo;
          _descripcionCtrl.text = c.descripcion;
          _activo = c.activo != 'N';
          _mostrarPortada = c.mostrarPortada == 'S';
          _visibleParaTodos = c.visibleParaTodos == 'S';
          _selectedCategoriaIds = List<int>.from(c.categoriaIds);
          _imagenPortadaBase64 = c.imagenPortada;
          _imagenMiniaturaBase64 = c.imagenMiniatura;
          _imagenNombre = c.imagenPortadaNombre;
          _hasChanges = false;
        });
        _suspendDirtyTracking = false;
      }
      // Cargar diapositivas
      await _loadSlides();
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  Future<void> _loadSlides() async {
    if (widget.charla?.codigo == null) return;
    final response = await context.read<ApiService>().get(
          'api/charlas_seminarios.php?diapositivas=${widget.charla!.codigo}',
        );
    if (response.statusCode == 200 && mounted) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _slides = data
            .map(
              (e) => CharlaDiapositiva.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(growable: false);
      });
    }
  }

  // ─── IMAGE PICKER ───────────────────────────────────────────────

  Future<void> _pickPortada() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (!mounted) return;
    setState(() {
      _applyPortadaBytes(bytes, picked.name, decoded: decoded);
    });
  }

  void _applyPortadaBytes(
    Uint8List bytes,
    String imageName, {
    img.Image? decoded,
  }) {
    _imagenPortadaBase64 = base64Encode(bytes);
    _imagenNombre = imageName;
    _hasChanges = true;
    final imageDecoded = decoded ?? img.decodeImage(bytes);
    if (imageDecoded != null) {
      final thumb = img.copyResize(imageDecoded, width: 320);
      _imagenMiniaturaBase64 = base64Encode(
        img.encodeJpg(thumb, quality: 85),
      );
    } else {
      _imagenMiniaturaBase64 = base64Encode(bytes);
    }
  }

  Future<void> _pastePortada() async {
    final bytes = await showPasteImageDialog(
      context,
      title: 'Pegar imagen',
      description:
          'Genera la imagen en formato base64 o copiala directamente al portapapeles y pulsa en pegar para agregarla a la charla.',
    );
    if (bytes == null) return;

    if (!mounted) return;
    setState(() {
      _applyPortadaBytes(bytes, 'base64');
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Imagen aplicada a la charla.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showPortadaMenu(BuildContext context) {
    if (_imagenPortadaBase64 == null) {
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: const Text('Añadir foto'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPortada();
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_paste_rounded),
                title: const Text('Pegar imagen'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pastePortada();
                },
              ),
            ],
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Cambiar foto'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPortada();
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste_rounded),
              title: const Text('Pegar imagen'),
              onTap: () {
                Navigator.pop(ctx);
                _pastePortada();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Eliminar foto',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _imagenPortadaBase64 = null;
                  _imagenMiniaturaBase64 = null;
                  _imagenNombre = null;
                  _hasChanges = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountCircleBadge(int count) {
    final active = count > 0;
    final backgroundColor =
        active ? Colors.green.shade600 : Colors.grey.shade400;

    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
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

  Future<Set<int>?> _showSelectCategoriasDialog(
      Set<int> initialSelected) async {
    final temp = Set<int>.from(initialSelected);
    String searchQuery = '';
    bool showSearch = false;

    return showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) {
          final filtered = _categorias.where((categoria) {
            final nombre = (categoria['nombre'] ?? '').toString();
            return searchQuery.isEmpty ||
                nombre.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Seleccionar categorías',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(showSearch ? Icons.search_off : Icons.search),
                  tooltip: showSearch ? 'Ocultar buscar' : 'Mostrar buscar',
                  onPressed: () {
                    setDialog(() {
                      showSearch = !showSearch;
                      if (!showSearch) {
                        searchQuery = '';
                      }
                    });
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
                  onPressed: () => Navigator.pop(dialogContext),
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
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) {
                        setDialog(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar categoría...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  setDialog(() {
                                    searchQuery = '';
                                  });
                                },
                                child: const Icon(Icons.clear, size: 20),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: filtered.map((categoria) {
                          final codigo = int.tryParse(
                                (categoria['codigo'] ?? '').toString(),
                              ) ??
                              0;
                          final nombre = (categoria['nombre'] ?? '').toString();
                          return CheckboxListTile(
                            dense: true,
                            value: temp.contains(codigo),
                            title: Text(nombre),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (checked) {
                              setDialog(() {
                                if (checked == true) {
                                  temp.add(codigo);
                                } else {
                                  temp.remove(codigo);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialog(() {
                    temp.clear();
                  });
                },
                child: const Text('Limpiar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, temp),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Aplicar'),
                    const SizedBox(width: 6),
                    _buildCountCircleBadge(temp.length),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── SLIDE MANUAL ───────────────────────────────────────────────

  Future<void> _addSlideManual() async {
    if (!_editing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guarda la charla primero para añadir diapositivas.'),
        ),
      );
      return;
    }

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (!mounted) return;

    setState(() => _uploadingSlide = true);
    try {
      final thumbBytes = decoded != null
          ? Uint8List.fromList(
              img.encodeJpg(img.copyResize(decoded, width: 480), quality: 80),
            )
          : bytes;

      final body = jsonEncode(<String, dynamic>{
        'imagen_diapositiva': base64Encode(bytes),
        'imagen_diapositiva_nombre': picked.name,
        'imagen_miniatura': base64Encode(thumbBytes),
        if (decoded != null) 'ancho_px': decoded.width,
        if (decoded != null) 'alto_px': decoded.height,
      });

      final response = await context.read<ApiService>().post(
            'api/charlas_seminarios.php?slide=${widget.charla!.codigo}',
            body: body,
          );
      if (!mounted) return;
      if (response.statusCode == 201) {
        await _loadSlides();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir la diapositiva.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingSlide = false);
    }
  }

  Future<void> _deleteSlide(CharlaDiapositiva slide) async {
    if (slide.codigo == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar diapositiva'),
            content: Text(
              '¿Eliminar la diapositiva ${slide.numeroDiapositiva}?',
            ),
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
    if (!confirmed) return;

    final response = await context.read<ApiService>().delete(
          'api/charlas_seminarios.php?slide=${slide.codigo}',
        );
    if (!mounted) return;
    if (response.statusCode == 200) {
      await _loadSlides();
    }
  }

  Future<void> _pickAudioForSlide(CharlaDiapositiva slide) async {
    if (slide.codigo == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['m4a', 'aac', 'mp3', 'wav'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final ext = (file.extension ?? '').toLowerCase();
    final mime = switch (ext) {
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'aac' => 'audio/aac',
      _ => 'audio/mp4',
    };

    final response = await context.read<ApiService>().put(
          'api/charlas_seminarios.php?slide=${slide.codigo}',
          body: jsonEncode(<String, dynamic>{
            'audio_diapositiva': base64Encode(file.bytes!),
            'audio_diapositiva_nombre': file.name,
            'audio_diapositiva_mime': mime,
          }),
        );

    if (!mounted) return;
    if (response.statusCode == 200) {
      await _loadSlides();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio asociado a la diapositiva.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo subir el audio.')),
      );
    }
  }

  Future<void> _removeAudioFromSlide(CharlaDiapositiva slide) async {
    if (slide.codigo == null) return;
    final response = await context.read<ApiService>().put(
          'api/charlas_seminarios.php?slide=${slide.codigo}',
          body: jsonEncode(<String, dynamic>{'clear_audio': 1}),
        );

    if (!mounted) return;
    if (response.statusCode == 200) {
      await _loadSlides();
    }
  }

  void _showAudioOptionsForSlide(CharlaDiapositiva slide) {
    final hasAudio =
        slide.audioDiapositiva != null && slide.audioDiapositiva!.isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              'Audio — diapositiva ${slide.numeroDiapositiva}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.library_music),
              title: const Text('Subir archivo de audio'),
              subtitle: const Text('m4a, aac, mp3, wav…'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAudioForSlide(slide);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic),
              title: const Text('Grabar con micrófono'),
              subtitle: const Text('Graba directamente desde la app'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleRecordForSlide(slide);
              },
            ),
            if (hasAudio)
              ListTile(
                leading: const Icon(Icons.volume_off, color: Colors.red),
                title: const Text(
                  'Eliminar audio',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeAudioFromSlide(slide);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRecordForSlide(CharlaDiapositiva slide) async {
    if (slide.codigo == null) return;

    if (_recordingAudio && _recordingSlideCodigo == slide.codigo) {
      await _stopAndUploadRecording(slide);
      return;
    }

    if (_recordingAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya hay una grabación activa en otra diapositiva.'),
        ),
      );
      return;
    }

    final permissionStatus = await Permission.microphone.request();
    if (!permissionStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se requiere permiso de micrófono.')),
      );
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/charla_${widget.charla!.codigo}_slide_${slide.codigo}_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    if (!mounted) return;
    setState(() {
      _recordingAudio = true;
      _recordingSlideCodigo = slide.codigo;
      _recordingStartedAt = DateTime.now();
      _recordingFilePath = filePath;
    });
  }

  Future<void> _stopAndUploadRecording(CharlaDiapositiva slide) async {
    final filePath = await _audioRecorder.stop();
    final effectivePath = filePath ?? _recordingFilePath;
    final startedAt = _recordingStartedAt;

    if (mounted) {
      setState(() {
        _recordingAudio = false;
        _recordingSlideCodigo = null;
        _recordingStartedAt = null;
        _recordingFilePath = null;
      });
    }

    if (effectivePath == null) return;
    final file = File(effectivePath);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final durationMs = startedAt == null
        ? null
        : DateTime.now().difference(startedAt).inMilliseconds;

    final response = await context.read<ApiService>().put(
          'api/charlas_seminarios.php?slide=${slide.codigo}',
          body: jsonEncode(<String, dynamic>{
            'audio_diapositiva': base64Encode(bytes),
            'audio_diapositiva_nombre': 'slide_${slide.numeroDiapositiva}.m4a',
            'audio_diapositiva_mime': 'audio/mp4',
            if (durationMs != null && durationMs > 0)
              'audio_duracion_ms': durationMs,
          }),
        );

    if (!mounted) return;
    if (response.statusCode == 200) {
      await _loadSlides();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Audio grabado y asociado correctamente.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo subir el audio grabado.')),
      );
    }
  }

  // ─── CATEGORÍAS ─────────────────────────────────────────────────

  Future<void> _createCategoria() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || result.isEmpty) return;

    final auth = context.read<AuthService>();
    final response = await context.read<ApiService>().post(
          'api/charlas_seminarios.php?categorias=1',
          body: jsonEncode(<String, dynamic>{
            'nombre': result,
            'codusuarioa': int.tryParse(auth.userCode ?? '0') ?? 0,
          }),
        );

    if (!mounted) return;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al crear la categoría.')),
        );
        return;
      }
      final codigo = int.tryParse((decoded['codigo'] ?? '').toString()) ?? 0;
      if (codigo > 0) {
        await _loadCategorias();
        if (mounted) {
          setState(() {
            _selectedCategoriaIds.add(codigo);
            _hasChanges = true;
          });
        }
      } else {
        final msg = decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            'Error al crear la categoría.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al crear la categoría.')),
        );
      }
    }
  }

  // ─── SAVE ───────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final body = jsonEncode(<String, dynamic>{
        if (_editing) 'codigo': widget.charla!.codigo,
        'titulo': _tituloCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'activo': _activo ? 'S' : 'N',
        'mostrar_portada': _mostrarPortada ? 'S' : 'N',
        'visible_para_todos': _visibleParaTodos ? 'S' : 'N',
        if (_imagenPortadaBase64 != null)
          'imagen_portada': _imagenPortadaBase64,
        if (_imagenNombre != null) 'imagen_portada_nombre': _imagenNombre,
        if (_imagenMiniaturaBase64 != null)
          'imagen_miniatura': _imagenMiniaturaBase64,
        'categorias': _selectedCategoriaIds,
      });

      final response = _editing
          ? await context.read<ApiService>().put(
                'api/charlas_seminarios.php',
                body: body,
              )
          : await context.read<ApiService>().post(
                'api/charlas_seminarios.php',
                body: body,
              );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editing ? 'Charla actualizada.' : 'Charla creada.'),
          ),
        );
        // Tras una nueva creación, recargar el detalle para obtener el código
        if (!_editing) {
          final respData = jsonDecode(response.body) as Map<String, dynamic>;
          final codigo = int.tryParse(respData['codigo'].toString()) ?? 0;
          if (codigo > 0) {
            Navigator.pop(context, true);
          }
        } else {
          Navigator.pop(context, true);
        }
      } else {
        final msg = _extractApiErrorMessage(response.body);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text('Error (${response.statusCode}): $msg')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────

  void _markDirty() {
    if (_suspendDirtyTracking || _hasChanges) return;
    setState(() => _hasChanges = true);
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges) return true;
    return showUnsavedChangesDialog(context);
  }

  Future<void> _handleBack() async {
    if (await _confirmDiscardChanges()) {
      if (mounted) Navigator.of(context).pop();
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
          title: Text(_editing ? 'Editar charla' : 'Nueva charla'),
          actions: [
            if (_editing && _slides.isNotEmpty)
              IconButton(
                tooltip: 'Vista previa',
                icon: const Icon(Icons.play_circle_outline),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CharlaSeminarioDetailScreen(charla: widget.charla!),
                  ),
                ),
              ),
          ],
        ),
        body: _loadingDetail
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─ Título
                      TextFormField(
                        controller: _tituloCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Título *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El título es obligatorio.'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // ─ Descripción
                      _buildDescripcionSection(),
                      const SizedBox(height: 16),

                      // ─ Switches
                      _buildTogglesSection(),
                      const SizedBox(height: 16),

                      // ─ Categorías
                      _buildCategoriasSection(),
                      const SizedBox(height: 16),

                      // ─ Diapositivas (solo en edición)
                      if (_editing) _buildSlidesSection(),
                      if (_editing) const SizedBox(height: 16),

                      // ─ Imagen de portada (abajo)
                      _buildPortadaSection(),
                      const SizedBox(height: 24),

                      // ─ Guardar
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            _editing ? 'Guardar cambios' : 'Crear charla',
                          ),
                          onPressed: _saving ? null : _save,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCategoriasSection() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade400),
      ),
      child: ExpansionTile(
        initiallyExpanded: _categoriasExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _categoriasExpanded = expanded;
          });
          _saveCategoriasExpanded(expanded);
        },
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Row(
          children: [
            const Text(
              'Categorías',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(width: 6),
            _buildCountCircleBadge(_selectedCategoriaIds.length),
            const Spacer(),
            IconButton(
              onPressed: () async {
                final temp = Set<int>.from(_selectedCategoriaIds);
                final picked = await _showSelectCategoriasDialog(temp);
                if (picked == null || !mounted) return;
                setState(() {
                  _selectedCategoriaIds
                    ..clear()
                    ..addAll(picked);
                  _hasChanges = true;
                });
              },
              tooltip: 'Seleccionar categorías',
              icon: const Icon(Icons.category_outlined, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: _selectedCategoriaIds.isEmpty
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Sin categorías'),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _categorias
                              .where((cat) {
                                final codigo = int.tryParse(
                                        (cat['codigo'] ?? '').toString()) ??
                                    0;
                                return _selectedCategoriaIds.contains(codigo);
                              })
                              .map(
                                (cat) => Chip(
                                  label: Text((cat['nombre'] ?? '').toString()),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescripcionSection() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade400),
      ),
      child: ExpansionTile(
        initiallyExpanded: _descripcionExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _descripcionExpanded = expanded;
          });
          _saveDescripcionExpanded(expanded);
        },
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Row(
          children: [
            const Text(
              'Descripción',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(width: 6),
            _buildCountCircleBadge(_descripcionCtrl.text.length),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextFormField(
              controller: _descripcionCtrl,
              decoration: const InputDecoration(
                hintText: 'Descripción',
                border: InputBorder.none,
                isDense: true,
              ),
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTogglesSection() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade400),
      ),
      child: ExpansionTile(
        initiallyExpanded: _togglesExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _togglesExpanded = expanded;
          });
          _saveTogglesExpanded(expanded);
        },
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Row(
          children: [
            const Text(
              'Visibilidad y estado',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _activo ? Colors.green.shade600 : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _visibleParaTodos
                    ? Colors.green.shade600
                    : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'P',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _mostrarPortada
                    ? Colors.green.shade600
                    : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'D',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: _activo,
                  onChanged: (v) => setState(() {
                    _activo = v;
                    _hasChanges = true;
                  }),
                  title: const Text('Activo'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile.adaptive(
                  value: _visibleParaTodos,
                  onChanged: (v) => setState(() {
                    _visibleParaTodos = v;
                    _hasChanges = true;
                  }),
                  title: const Text('Visible para Premium'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile.adaptive(
                  value: _mostrarPortada,
                  onChanged: (v) => setState(() {
                    _mostrarPortada = v;
                    _hasChanges = true;
                  }),
                  title: const Text('Destacada (en portada)'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortadaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Portada', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _imagenPortadaBase64 == null
              ? () => _showPortadaMenu(context)
              : null,
          onLongPress: _imagenPortadaBase64 != null
              ? () => _showPortadaMenu(context)
              : null,
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _imagenPortadaBase64 != null &&
                    _imagenPortadaBase64!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(_imagenPortadaBase64!),
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined,
                            size: 40, color: Colors.grey[600]),
                        const SizedBox(height: 4),
                        Text(
                          'Toca para añadir foto',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlidesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Diapositivas (${_slides.length})',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const Spacer(),
            if (_uploadingSlide)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                label: const Text('Añadir'),
                onPressed: _addSlideManual,
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_slides.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Sin diapositivas. Añade imágenes manualmente y asocia su audio.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          )
        else
          SizedBox(
            height: 130,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _slides.length,
              onReorder: (oldIndex, newIndex) {
                // Solo reordena visualmente; no persiste sin backend adicional
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final slide = _slides.removeAt(oldIndex);
                  _slides.insert(newIndex, slide);
                });
              },
              itemBuilder: (context, index) {
                final slide = _slides[index];
                final imgKey = slide.numeroDiapositiva;
                MemoryImage? provider = _slideCache[imgKey];
                final raw =
                    (slide.imagenMiniatura ?? slide.imagenDiapositiva ?? '')
                        .trim();
                if (provider == null && raw.isNotEmpty) {
                  try {
                    provider = MemoryImage(base64Decode(raw));
                    _slideCache[imgKey] = provider;
                  } catch (_) {}
                }

                return Padding(
                  key: ValueKey(slide.codigo ?? index),
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 100,
                          height: 130,
                          child: provider != null
                              ? Image(image: provider, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: Text(
                                      '${slide.numeroDiapositiva}',
                                      style: const TextStyle(
                                        color: Colors.black38,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      // Número
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${slide.numeroDiapositiva}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      // Audio status (tappable)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: GestureDetector(
                          onTap: () => _showAudioOptionsForSlide(slide),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: slide.audioDiapositiva != null &&
                                      slide.audioDiapositiva!.isNotEmpty
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  slide.audioDiapositiva != null &&
                                          slide.audioDiapositiva!.isNotEmpty
                                      ? Icons.volume_up
                                      : Icons.add,
                                  size: 9,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  slide.audioDiapositiva != null &&
                                          slide.audioDiapositiva!.isNotEmpty
                                      ? 'AUDIO'
                                      : 'SIN AUDIO',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Acciones audio
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _pickAudioForSlide(slide),
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black54,
                                ),
                                child: const Icon(
                                  Icons.library_music,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _toggleRecordForSlide(slide),
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _recordingAudio &&
                                          _recordingSlideCodigo == slide.codigo
                                      ? Colors.red.shade700
                                      : Colors.black54,
                                ),
                                child: Icon(
                                  _recordingAudio &&
                                          _recordingSlideCodigo == slide.codigo
                                      ? Icons.stop
                                      : Icons.mic,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (slide.audioDiapositiva != null &&
                                slide.audioDiapositiva!.isNotEmpty)
                              GestureDetector(
                                onTap: () => _removeAudioFromSlide(slide),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black54,
                                  ),
                                  child: const Icon(
                                    Icons.volume_off,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Eliminar
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _deleteSlide(slide),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black54,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
