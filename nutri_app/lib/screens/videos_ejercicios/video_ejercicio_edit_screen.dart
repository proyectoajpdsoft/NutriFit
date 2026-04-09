import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../services/thumbnail_generator.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/video_ejercicio.dart';
import '../../widgets/image_viewer_dialog.dart';
import '../../widgets/paste_image_dialog.dart';
import '../../widgets/unsaved_changes_dialog.dart';
import 'video_ejercicio_player_screen.dart';
import '../ai/ai_assistant_screen.dart';

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

  String _tipoMedia = 'youtube';
  String _formato = 'mp4';
  String _visible = 'S';
  String _rutaBaseVideos = '';
  String? _imagenBase64;
  String? _imagenNombre;
  String? _imagenMiniaturaBase64;
  String? _imagenMiniaturaNombre;
  bool _clearImagen = false;
  int? _maxImageWidth;
  int? _maxImageHeight;
  bool _isSaving = false;
  bool _isUploading = false;
  bool _hasChanges = false;
  bool _descripcionExpanded = true;
  bool _tipoMediaExpanded = true;
  bool _urlExpanded = true;
  bool _miniaturaExpanded = true;
  bool _visibleExpanded = true;
  bool _categoriasExpanded = true;
  bool _cardStateReady = false;

  // Subcarpeta dentro de ruta_base_videos_ejercicios donde se sube el fichero
  final _subcarpetaCtrl = TextEditingController();
  bool _categoriasLoading = false;
  List<Map<String, dynamic>> _categoriasCatalogo = [];
  List<int> _selectedCategoriaIds = [];

  bool get _isEditing => widget.video != null;
  static const String _cardStateStorageKey =
      'video_ejercicio_edit_card_expanded_state';

  void _markDirty() {
    if (_hasChanges) {
      setState(() {});
      return;
    }
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
      _imagenBase64 = v.imagen;
      _imagenNombre = v.imagenNombre;
      _imagenMiniaturaBase64 = v.imagenMiniatura;
      _imagenMiniaturaNombre = v.imagenMiniaturaNombre;
      _selectedCategoriaIds = List<int>.from(v.categoriaIds);
    }
    _loadCardExpandedState();
    _loadCategorias();
    _loadImageLimits();
    _loadExistingVideoDetail();
    _loadRutaBaseVideos();
  }

  Future<void> _loadCardExpandedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cardStateStorageKey);

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _descripcionExpanded =
            saved['descripcion'] as bool? ?? _descripcionExpanded;
        _tipoMediaExpanded = saved['tipo_media'] as bool? ?? _tipoMediaExpanded;
        _urlExpanded = saved['url'] as bool? ?? _urlExpanded;
        _miniaturaExpanded = saved['miniatura'] as bool? ?? _miniaturaExpanded;
        _visibleExpanded = saved['visible'] as bool? ?? _visibleExpanded;
        _categoriasExpanded =
            saved['categorias'] as bool? ?? _categoriasExpanded;
      } catch (_) {
        await prefs.remove(_cardStateStorageKey);
      }
    }

    if (!mounted) return;
    setState(() {
      _cardStateReady = true;
    });
  }

  Future<void> _saveCardExpandedState() async {
    if (!_cardStateReady) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cardStateStorageKey,
      jsonEncode({
        'descripcion': _descripcionExpanded,
        'tipo_media': _tipoMediaExpanded,
        'url': _urlExpanded,
        'miniatura': _miniaturaExpanded,
        'visible': _visibleExpanded,
        'categorias': _categoriasExpanded,
      }),
    );
  }

  Future<void> _openAiAssistantForDescription() async {
    final generatedText = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AiAssistantScreen(
          origin: 'video_ejercicio_descripcion',
          title: 'Asistente IA',
          placeholders: {
            'titulo': _tituloCtrl.text.trim(),
            'descripcion': _descripcionCtrl.text.trim(),
          },
        ),
      ),
    );

    if (!mounted || generatedText == null || generatedText.trim().isEmpty) {
      return;
    }

    setState(() {
      _descripcionCtrl.text = generatedText.trim();
      _descripcionCtrl.selection = TextSelection.collapsed(
        offset: _descripcionCtrl.text.length,
      );
      _hasChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Descripción actualizada desde la IA')),
    );
  }

  void _toggleCard(String key) {
    setState(() {
      switch (key) {
        case 'descripcion':
          _descripcionExpanded = !_descripcionExpanded;
          break;
        case 'tipo_media':
          _tipoMediaExpanded = !_tipoMediaExpanded;
          break;
        case 'url':
          _urlExpanded = !_urlExpanded;
          break;
        case 'miniatura':
          _miniaturaExpanded = !_miniaturaExpanded;
          break;
        case 'visible':
          _visibleExpanded = !_visibleExpanded;
          break;
        case 'categorias':
          _categoriasExpanded = !_categoriasExpanded;
          break;
      }
    });
    _saveCardExpandedState();
  }

  void _syncMediaTypeFromUrl(String value) {
    final normalized = value.trim().toLowerCase();
    if (_tipoMedia == 'local' && normalized.contains('youtube.com')) {
      setState(() {
        _tipoMedia = 'youtube';
      });
    }
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

  Future<void> _loadImageLimits() async {
    try {
      final api = context.read<ApiService>();
      final parametro = await api.getParametroByNombre(
        'tamano_maximo_imagenes_videos_ejercicios',
      );
      if (!mounted || parametro == null) return;

      final width = int.tryParse((parametro['valor'] ?? '').toString().trim());
      final height =
          int.tryParse((parametro['valor2'] ?? '').toString().trim());

      setState(() {
        _maxImageWidth = width != null && width > 0 ? width : null;
        _maxImageHeight = height != null && height > 0 ? height : null;
      });
    } catch (_) {
      // Si el parámetro no existe o falla, no bloqueamos el editor.
    }
  }

  Future<void> _loadExistingVideoDetail() async {
    final codigo = widget.video?.codigo;
    if (!_isEditing || codigo == null) return;

    try {
      final api = context.read<ApiService>();
      final detail = await api.getVideoEjercicio(codigo);
      final video = VideoEjercicio.fromJson(detail);

      if (!mounted) return;
      setState(() {
        _imagenBase64 = video.imagen ?? _imagenBase64;
        _imagenNombre = video.imagenNombre ?? _imagenNombre;
        _imagenMiniaturaBase64 =
            video.imagenMiniatura ?? _imagenMiniaturaBase64;
        _imagenMiniaturaNombre =
            video.imagenMiniaturaNombre ?? _imagenMiniaturaNombre;
        if (video.categoriaIds.isNotEmpty) {
          _selectedCategoriaIds = List<int>.from(video.categoriaIds);
        }
      });
    } catch (_) {
      // Si falla el detalle, mantenemos los datos básicos ya cargados.
    }
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

  Future<void> _applyPortadaBytes(
    Uint8List originalBytes,
    String imageName, {
    String? successMessage,
  }) async {
    final resizedBytes = _resizeImageIfNeeded(originalBytes);
    final thumb =
        ThumbnailGenerator.generateThumbnail(resizedBytes) ?? resizedBytes;

    if (!mounted) return;
    setState(() {
      _imagenBase64 = base64Encode(resizedBytes);
      _imagenNombre = imageName;
      _imagenMiniaturaBase64 = base64Encode(thumb);
      _imagenMiniaturaNombre = imageName;
      _clearImagen = false;
    });
    _markDirty();

    if (successMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _pickPortada() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _applyPortadaBytes(bytes, picked.name);
  }

  Future<void> _pastePortada() async {
    final bytes = await showPasteImageDialog(
      context,
      title: 'Pegar imagen',
      description:
          'Genera la imagen en formato base64 o copiala directamente al portapapeles y pulsa en pegar para agregarla a la portada del video.',
    );
    if (bytes == null) return;

    await _applyPortadaBytes(
      bytes,
      'base64',
      successMessage: 'Imagen aplicada a la portada.',
    );
  }

  void _removePortada() {
    setState(() {
      _imagenBase64 = null;
      _imagenNombre = null;
      _imagenMiniaturaBase64 = null;
      _imagenMiniaturaNombre = null;
      _clearImagen = true;
    });
    _markDirty();
  }

  void _viewPortada() {
    final previewBase64 = _imagenBase64 ?? _imagenMiniaturaBase64;
    if (previewBase64 == null) return;

    showImageViewerDialog(
      context: context,
      base64Image: previewBase64,
      title:
          _tituloCtrl.text.isNotEmpty ? _tituloCtrl.text : 'Imagen de portada',
    );
  }

  void _showPortadaMenuAtWidget(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final hasImage = (_imagenBase64 ?? _imagenMiniaturaBase64) != null;

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
        _removePortada();
      } else if (value == 'change' || value == 'add') {
        _pickPortada();
      } else if (value == 'paste') {
        _pastePortada();
      }
    });
  }

  String get _tipoMediaSubtitle {
    if (_tipoMedia == 'youtube') {
      return 'YouTube (URL externa)';
    }
    return _formato == 'gif' ? 'Local (GIF)' : 'Local (MP4)';
  }

  String get _visibleSubtitle {
    return _visible == 'S' ? 'Visible para Premium' : 'No visible';
  }

  Widget _buildCountCircleBadge(int count) {
    final color = count > 0 ? Colors.green : Colors.grey;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCountRectBadge(int count) {
    final color = count > 0 ? Colors.green : Colors.grey;
    return Container(
      constraints: const BoxConstraints(minWidth: 34, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRectStatusBadge(String label, bool active,
      {VoidCallback? onTap}) {
    final badge = Container(
      width: 24,
      height: 22,
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
    if (onTap == null) return badge;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: badge,
      ),
    );
  }

  Widget _buildCollapsibleCard({
    required String title,
    String? subtitle,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
    Widget? titleBadge,
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
                              ),
                            ),
                            if (titleBadge != null) ...[
                              const SizedBox(width: 8),
                              titleBadge,
                            ],
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

  Future<Set<int>?> _showSelectCategoriasDialog(
      Set<int> initialSelected) async {
    final temp = Set<int>.from(initialSelected);
    String searchQuery = '';
    bool showSearch = false;

    return showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) {
          final filtered = _categoriasCatalogo.where((categoria) {
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
                                  (categoria['codigo'] ?? '').toString()) ??
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

  Widget _buildCategoriasCard() {
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
          _saveCardExpandedState();
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
              onPressed: _categoriasLoading
                  ? null
                  : () async {
                      final temp = Set<int>.from(_selectedCategoriaIds);
                      final picked = await _showSelectCategoriasDialog(temp);
                      if (picked == null || !mounted) return;
                      setState(() {
                        _selectedCategoriaIds
                          ..clear()
                          ..addAll(picked);
                      });
                      _markDirty();
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
              child: _categoriasLoading
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 140,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    )
                  : _selectedCategoriaIds.isEmpty
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
                              children: _categoriasCatalogo
                                  .where((cat) {
                                    final codigo = int.tryParse(
                                            (cat['codigo'] ?? '').toString()) ??
                                        0;
                                    return _selectedCategoriaIds
                                        .contains(codigo);
                                  })
                                  .map(
                                    (cat) => Chip(
                                      label: Text(
                                          (cat['nombre'] ?? '').toString()),
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

  Future<void> _openVideoUrl() async {
    final url = _buildVideoUrl(_rutaVideoCtrl.text).trim();
    if (url.isEmpty) return;

    try {
      final opened = await launchUrlString(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la URL del vídeo.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la URL del vídeo: $e')),
      );
    }
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
        if (_imagenBase64 != null) 'imagen': _imagenBase64,
        if (_imagenNombre != null) 'imagen_nombre': _imagenNombre,
        if (_imagenMiniaturaBase64 != null)
          'imagen_miniatura': _imagenMiniaturaBase64,
        if (_imagenMiniaturaNombre != null)
          'imagen_miniatura_nombre': _imagenMiniaturaNombre,
        if (_isEditing && _clearImagen) 'clear_imagen': true,
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
              tooltip: 'Asistente IA',
              onPressed: _openAiAssistantForDescription,
              icon: const Icon(Icons.auto_awesome_outlined),
            ),
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
        body: !_cardStateReady
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ─── Título ───
                    TextFormField(
                      controller: _tituloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.fromLTRB(12, 16, 12, 12),
                      ),
                      minLines: 2,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      onChanged: (_) => _markDirty(),
                    ),
                    const SizedBox(height: 16),

                    _buildCollapsibleCard(
                      title: 'Descripción',
                      expanded: _descripcionExpanded,
                      onToggle: () => _toggleCard('descripcion'),
                      titleBadge: _buildCountRectBadge(
                        _descripcionCtrl.text.trim().length,
                      ),
                      actions: [
                        IconButton(
                          tooltip: 'Asistente IA',
                          onPressed: _openAiAssistantForDescription,
                          icon: const Icon(Icons.auto_awesome_outlined),
                        ),
                      ],
                      child: TextFormField(
                        controller: _descripcionCtrl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Escribe la descripción del vídeo',
                        ),
                        minLines: 6,
                        maxLines: 8,
                        onChanged: (_) => _markDirty(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildCollapsibleCard(
                      title: 'Tipo de medio',
                      subtitle: _tipoMediaSubtitle,
                      expanded: _tipoMediaExpanded,
                      onToggle: () => _toggleCard('tipo_media'),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _tipoMedia,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'local',
                                  child: Text('Local (mp4/gif)')),
                              DropdownMenuItem(
                                  value: 'youtube',
                                  child: Text('YouTube (URL externa)')),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _tipoMedia = v);
                                _markDirty();
                              }
                            },
                          ),
                          if (_tipoMedia == 'local') ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _formato,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Formato',
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'mp4', child: Text('MP4')),
                                DropdownMenuItem(
                                    value: 'gif', child: Text('GIF')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _formato = v);
                                  _markDirty();
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildCollapsibleCard(
                      title: 'URL del vídeo',
                      expanded: _urlExpanded,
                      onToggle: () => _toggleCard('url'),
                      actions: [
                        IconButton(
                          onPressed: _rutaVideoCtrl.text.trim().isEmpty
                              ? null
                              : _openVideoUrl,
                          icon: const Icon(Icons.open_in_new),
                          tooltip: 'Ir a la URL',
                        ),
                      ],
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _rutaVideoCtrl,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              hintText: _tipoMedia == 'local'
                                  ? 'ej: tren_inferior.mp4 o carpeta/tren_inferior.mp4'
                                  : 'https://...',
                              helperText: _tipoMedia == 'local' &&
                                      _rutaBaseVideos.isNotEmpty
                                  ? 'URL base: $_rutaBaseVideos'
                                  : (_tipoMedia == 'local'
                                      ? 'Introduce el nombre del fichero (ej: cardio.mp4)'
                                      : null),
                              helperMaxLines: 2,
                            ),
                            keyboardType: TextInputType.url,
                            onChanged: (value) {
                              _syncMediaTypeFromUrl(value);
                              _markDirty();
                            },
                          ),
                          if (_tipoMedia == 'local')
                            ..._buildUploadSection(context),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCollapsibleCard(
                      title: 'Portada',
                      expanded: _miniaturaExpanded,
                      onToggle: () => _toggleCard('miniatura'),
                      actions: [
                        IconButton(
                          onPressed: _pickPortada,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          tooltip: 'Añadir imagen',
                        ),
                        IconButton(
                          onPressed: _pastePortada,
                          icon: const Icon(Icons.content_paste_rounded),
                          tooltip: 'Pegar imagen',
                        ),
                        if ((_imagenBase64 ?? _imagenMiniaturaBase64) != null)
                          IconButton(
                            onPressed: _removePortada,
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
                                    if (_imagenMiniaturaBase64 != null) {
                                      _viewPortada();
                                    } else {
                                      _showPortadaMenuAtWidget(context);
                                    }
                                  },
                                  onLongPress: () {
                                    _showPortadaMenuAtWidget(context);
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
                                      child: (_imagenBase64 ??
                                                  _imagenMiniaturaBase64) !=
                                              null
                                          ? Image.memory(
                                              base64Decode(
                                                  _imagenMiniaturaBase64 ??
                                                      _imagenBase64!),
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
                              (_imagenBase64 ?? _imagenMiniaturaBase64) != null
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
                          if (_maxImageWidth != null &&
                              _maxImageHeight != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Si la portada supera ${_maxImageWidth}x${_maxImageHeight} px, se reducirá.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildCategoriasCard(),
                    const SizedBox(height: 16),

                    _buildCollapsibleCard(
                      title: 'Visible para Premium',
                      expanded: _visibleExpanded,
                      onToggle: () => _toggleCard('visible'),
                      badges: [
                        _buildRectStatusBadge(
                          'P',
                          _visible == 'S',
                          onTap: () {
                            setState(
                                () => _visible = _visible == 'S' ? 'N' : 'S');
                            _markDirty();
                          },
                        ),
                      ],
                      child: SwitchListTile.adaptive(
                        value: _visible == 'S',
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) {
                          setState(() => _visible = v ? 'S' : 'N');
                          _markDirty();
                        },
                        title: const Text('Visible para Premium'),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }
}
