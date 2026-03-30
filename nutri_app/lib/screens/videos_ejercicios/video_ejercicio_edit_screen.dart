import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:convert';
import '../../services/thumbnail_generator.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/video_ejercicio.dart';
import '../../widgets/paste_image_dialog.dart';
import '../../widgets/unsaved_changes_dialog.dart';
import 'video_ejercicio_player_screen.dart';

class VideoEjercicioEditScreen extends StatefulWidget {
  final VideoEjercicio? video;

  const VideoEjercicioEditScreen({super.key, this.video});

  @override
  State<VideoEjercicioEditScreen> createState() =>
      _VideoEjercicioEditScreenState();
}

class _VideoEjercicioEditScreenState extends State<VideoEjercicioEditScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _rutaVideoCtrl = TextEditingController();

  String _tipoMedia = 'local';
  String _formato = 'mp4';
  String _visible = 'S';
  String _rutaBaseVideos = '';
  String? _imagenMiniaturaBase64;
  String? _imagenMiniaturaNombre;
  bool _isSaving = false;
  bool _isUploading = false;
  bool _hasChanges = false;

  // Subcarpeta dentro de ruta_base_videos_ejercicios donde se sube el fichero
  final _subcarpetaCtrl = TextEditingController();
  bool _categoriasLoading = false;
  List<Map<String, dynamic>> _categoriasCatalogo = [];
  List<int> _selectedCategoriaIds = [];

  bool get _isEditing => widget.video != null;

  void _markDirty() {
    if (_hasChanges) return;
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
  void initState() {
    super.initState();
    final v = widget.video;
    if (v != null) {
      _tituloCtrl.text = v.titulo;
      _descripcionCtrl.text = v.descripcion ?? '';
      _rutaVideoCtrl.text = v.rutaVideo ?? '';
      _tipoMedia = v.tipoMedia;
      _formato = v.formato ?? 'mp4';
      _visible = v.visible;
      _imagenMiniaturaBase64 = v.imagenMiniatura;
      _imagenMiniaturaNombre = v.imagenMiniaturaNombre;
      _selectedCategoriaIds = List<int>.from(v.categoriaIds);
    }
    _loadCategorias();
    _loadRutaBaseVideos();
  }

  Future<void> _loadRutaBaseVideos() async {
    try {
      final api = context.read<ApiService>();
      final valor = await api.getParametroValor('ruta_base_videos_ejercicios');
      final ruta = (valor ?? '').trim();
      if (!mounted) return;
      setState(() {
        _rutaBaseVideos = ruta;
      });
      // No pre-rellenamos el campo: el nutricionista solo escribe el nombre/subpath del fichero.
    } catch (_) {
      // Si falla el parámetro, mantenemos funcionamiento manual sin bloquear formulario.
    }
  }

  /// Devuelve la ruta relativa a guardar en BD (solo nombre/subpath del fichero).
  /// La URL completa se reconstruye en reproducción: ruta_base_videos_ejercicios + ruta_video.
  String _buildRutaVideoForSave(String rawRuta) {
    final ruta = rawRuta.trim();
    if (_tipoMedia != 'local') return ruta;
    // Si el usuario pegó la URL completa, la guardamos tal cual.
    if (ruta.startsWith('http://') || ruta.startsWith('https://')) return ruta;
    // Eliminar barra inicial si existe (guardar siempre relativo).
    return ruta.startsWith('/') ? ruta.substring(1) : ruta;
  }

  String _buildVideoUrl(String rutaVideo) {
    final ruta = rutaVideo.trim();
    if (ruta.isEmpty) return '';
    if (ruta.startsWith('http://') || ruta.startsWith('https://')) {
      return ruta;
    }
    if (_rutaBaseVideos.isNotEmpty) {
      final base =
          _rutaBaseVideos.endsWith('/') ? _rutaBaseVideos : '$_rutaBaseVideos/';
      final relativa = ruta.startsWith('/') ? ruta.substring(1) : ruta;
      return '$base$relativa';
    }
    return ruta;
  }

  Future<void> _previewVideo() async {
    final ruta = _buildRutaVideoForSave(_rutaVideoCtrl.text);
    if (ruta.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Introduce una ruta/URL para previsualizar')),
      );
      return;
    }

    final previewVideo = VideoEjercicio(
      codigo: widget.video?.codigo,
      titulo: _tituloCtrl.text.trim().isEmpty
          ? 'Vista previa del vídeo'
          : _tituloCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim(),
      tipoMedia: _tipoMedia,
      rutaVideo: ruta,
      formato: _tipoMedia == 'local' ? _formato : null,
      imagenMiniatura: _imagenMiniaturaBase64 ?? widget.video?.imagenMiniatura,
      imagenMiniaturaNombre:
          _imagenMiniaturaNombre ?? widget.video?.imagenMiniaturaNombre,
      visible: _visible,
      totalLikes: widget.video?.totalLikes ?? 0,
      meGusta: widget.video?.meGusta ?? 'N',
      favorito: widget.video?.favorito ?? 'N',
    );

    final rawUrl = (previewVideo.rutaVideo ?? '').trim();
    final isExternalUrl =
        rawUrl.startsWith('http://') || rawUrl.startsWith('https://');
    if (isExternalUrl) {
      bool opened = false;
      try {
        opened = await launchUrlString(
          rawUrl,
          mode: LaunchMode.externalApplication,
        );
      } on PlatformException catch (e) {
        if (e.code == 'channel-error') {
          await _externalUrlChannel.invokeMethod('openUrl', {'url': rawUrl});
          opened = true;
        } else {
          rethrow;
        }
      }
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la URL del vídeo.'),
          ),
        );
      }
      return;
    }

    if (previewVideo.esGif) {
      final gifUrl = _buildVideoUrl(previewVideo.rutaVideo ?? '');
      if (gifUrl.isEmpty) return;
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          insetPadding: EdgeInsets.zero,
          child: InteractiveViewer(
            child: Image.network(
              gifUrl,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
      return;
    }

    final videoUrl = _buildVideoUrl(previewVideo.rutaVideo ?? '');
    if (videoUrl.isEmpty) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoEjercicioPlayerScreen(
          video: previewVideo,
          videoUrl: videoUrl,
        ),
      ),
    );
  }

  Future<void> _uploadVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'webm', 'mov', 'avi', 'mkv', 'gif'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudieron leer los bytes del fichero')),
      );
      return;
    }

    final sizeMb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);

    setState(() => _isUploading = true);
    try {
      final api = context.read<ApiService>();
      final subcarpeta = _subcarpetaCtrl.text.trim();
      final rutaVideo = await api.uploadVideoEjercicio(
        bytes: bytes,
        filename: file.name,
        subcarpeta: subcarpeta.isNotEmpty ? subcarpeta : null,
      );
      if (!mounted) return;
      setState(() {
        _rutaVideoCtrl.text = rutaVideo;
        // Auto-rellenar título con el nombre del fichero (sin extensión) si está vacío
        if (_tituloCtrl.text.trim().isEmpty) {
          final nameWithoutExt = file.name.contains('.')
              ? file.name.substring(0, file.name.lastIndexOf('.'))
              : file.name;
          _tituloCtrl.text =
              nameWithoutExt.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
        }
      });
      _markDirty();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vídeo subido: $rutaVideo'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir vídeo (${file.name}, $sizeMb MB): $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _rutaVideoCtrl.dispose();
    _subcarpetaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategorias() async {
    setState(() => _categoriasLoading = true);
    try {
      final api = context.read<ApiService>();
      final cats = await api.getVideoCategorias();
      if (mounted) {
        setState(() => _categoriasCatalogo = cats);
      }
    } finally {
      if (mounted) setState(() => _categoriasLoading = false);
    }
  }

  Future<void> _pickMiniatura() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 720,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final thumb = ThumbnailGenerator.generateThumbnail(bytes) ?? bytes;
    setState(() {
      _imagenMiniaturaBase64 = base64Encode(thumb);
      _imagenMiniaturaNombre = picked.name;
    });
  }

  Future<void> _pasteMiniatura() async {
    final bytes = await showPasteImageDialog(
      context,
      title: 'Pegar imagen',
      description:
          'Genera la imagen en formato base64 o copiala directamente al portapapeles y pulsa en pegar para agregarla a la miniatura del video.',
    );
    if (bytes == null) return;

    final thumb = ThumbnailGenerator.generateThumbnail(bytes) ?? bytes;
    if (!mounted) return;
    setState(() {
      _imagenMiniaturaBase64 = base64Encode(thumb);
      _imagenMiniaturaNombre = 'base64';
    });
    _markDirty();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Imagen aplicada a la miniatura.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _createCategoria() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(labelText: 'Nombre de la categoría'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;

    try {
      final api = context.read<ApiService>();
      final authService = context.read<AuthService>();
      final userId = int.tryParse(authService.userCode ?? '1') ?? 1;
      final result = await api.createVideoCategoria(nombre, userId);
      final newId = int.parse(result['codigo'].toString());
      await _loadCategorias();
      if (mounted) {
        setState(() {
          if (!_selectedCategoriaIds.contains(newId)) {
            _selectedCategoriaIds.add(newId);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear categoría: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final api = context.read<ApiService>();
      final authService = context.read<AuthService>();
      final userId = int.tryParse(authService.userCode ?? '1') ?? 1;

      final data = <String, dynamic>{
        if (_isEditing) 'codigo': widget.video!.codigo,
        'titulo': _tituloCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'tipo_media': _tipoMedia,
        'ruta_video': _buildRutaVideoForSave(_rutaVideoCtrl.text),
        'formato': _tipoMedia == 'local' ? _formato : null,
        'visible': _visible,
        'categorias': _selectedCategoriaIds,
        if (_imagenMiniaturaBase64 != null)
          'imagen_miniatura': _imagenMiniaturaBase64,
        if (_imagenMiniaturaNombre != null)
          'imagen_miniatura_nombre': _imagenMiniaturaNombre,
        if (!_isEditing) 'codusuarioa': userId,
        if (_isEditing) 'codusuariom': userId,
      };

      if (_isEditing) {
        await api.updateVideoEjercicio(data);
      } else {
        await api.createVideoEjercicio(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<Widget> _buildUploadSection(BuildContext context) {
    return [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Subir vídeo al servidor',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _subcarpetaCtrl,
              decoration: const InputDecoration(
                labelText: 'Subcarpeta (opcional)',
                hintText: 'ej: cardio  (se crea si no existe)',
                helperText:
                    'Subdirectorio dentro de ruta_base_videos_ejercicios.',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 10),
            if (_isUploading)
              const Column(
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 6),
                  Text('Subiendo vídeo…', style: TextStyle(fontSize: 12)),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _uploadVideo,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Seleccionar y subir fichero'),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar vídeo' : 'Nuevo vídeo'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver',
            onPressed: _handleBack,
          ),
          actions: [
            IconButton(
              tooltip: 'Vista previa',
              onPressed: _previewVideo,
              icon: const Icon(Icons.play_circle_outline),
            ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              IconButton(
                tooltip: 'Guardar',
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Título ───
              TextFormField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(
                    labelText: 'Título *', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                onChanged: (_) => _markDirty(),
              ),
              const SizedBox(height: 16),

              // ─── Descripción ───
              TextFormField(
                controller: _descripcionCtrl,
                decoration: const InputDecoration(
                    labelText: 'Descripción (acepta #hashtags y emoticonos)',
                    border: OutlineInputBorder()),
                maxLines: 4,
                onChanged: (_) => _markDirty(),
              ),
              const SizedBox(height: 16),

              // ─── Tipo de media ───
              DropdownButtonFormField<String>(
                initialValue: _tipoMedia,
                decoration: const InputDecoration(
                    labelText: 'Tipo de media', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: 'local', child: Text('Local (mp4/gif)')),
                  DropdownMenuItem(
                      value: 'youtube', child: Text('YouTube (URL externa)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _tipoMedia = v);
                    _markDirty();
                  }
                },
              ),
              const SizedBox(height: 16),

              // ─── Formato (solo local) ───
              if (_tipoMedia == 'local') ...[
                DropdownButtonFormField<String>(
                  initialValue: _formato,
                  decoration: const InputDecoration(
                      labelText: 'Formato', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'mp4', child: Text('MP4')),
                    DropdownMenuItem(value: 'gif', child: Text('GIF')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _formato = v);
                      _markDirty();
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],

              // ─── Ruta / URL del vídeo ───
              TextFormField(
                controller: _rutaVideoCtrl,
                decoration: InputDecoration(
                  labelText: _tipoMedia == 'youtube'
                      ? 'URL de YouTube'
                      : 'Nombre del fichero de vídeo',
                  hintText: _tipoMedia == 'local'
                      ? 'ej: tren_inferior.mp4 o carpeta/tren_inferior.mp4'
                      : null,
                  helperText: _tipoMedia == 'local' &&
                          _rutaBaseVideos.isNotEmpty
                      ? 'URL base: $_rutaBaseVideos'
                      : (_tipoMedia == 'local'
                          ? 'Introduce el nombre del fichero (ej: cardio.mp4)'
                          : null),
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                onChanged: (_) => _markDirty(),
              ),

              // ─── Subida de vídeo (solo tipo local) ───
              if (_tipoMedia == 'local') ..._buildUploadSection(context),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Miniatura',
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 4),
                        if (_imagenMiniaturaBase64 != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(_imagenMiniaturaBase64!),
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                                child: Icon(Icons.image_outlined,
                                    size: 40, color: Colors.grey)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _pickMiniatura();
                          _markDirty();
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Elegir'),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _pasteMiniatura();
                        },
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Pegar imagen'),
                      ),
                      if (_imagenMiniaturaBase64 != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _imagenMiniaturaBase64 = null;
                              _imagenMiniaturaNombre = null;
                            });
                            _markDirty();
                          },
                          child: const Text('Quitar'),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── Visible ───
              SwitchListTile.adaptive(
                value: _visible == 'S',
                onChanged: (v) {
                  setState(() => _visible = v ? 'S' : 'N');
                  _markDirty();
                },
                title: const Text('Visible para Premium'),
              ),
              const Divider(),

              // ─── Categorías ───
              Row(
                children: [
                  Text('Categorías',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await _createCategoria();
                      _markDirty();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nueva'),
                  ),
                ],
              ),
              if (_categoriasLoading)
                const LinearProgressIndicator(minHeight: 2)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _categoriasCatalogo.map((cat) {
                    final id = int.parse(cat['codigo'].toString());
                    final name = cat['nombre'].toString();
                    final selected = _selectedCategoriaIds.contains(id);
                    return FilterChip(
                      label: Text(name),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedCategoriaIds.add(id);
                          } else {
                            _selectedCategoriaIds.remove(id);
                          }
                        });
                        _markDirty();
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
