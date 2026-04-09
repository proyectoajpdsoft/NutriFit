import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/config_service.dart';
import '../../services/videos_ejercicios_catalog_pdf_service.dart';
import '../../models/video_ejercicio.dart';
import 'video_ejercicio_edit_screen.dart';
import 'video_ejercicio_player_screen.dart';

enum _OrdenVideos { nombre, fechaAlta, likes }

class VideosEjerciciosListScreen extends StatefulWidget {
  const VideosEjerciciosListScreen({super.key});

  @override
  State<VideosEjerciciosListScreen> createState() =>
      _VideosEjerciciosListScreenState();
}

class _VideosEjerciciosListScreenState
    extends State<VideosEjerciciosListScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  static const int _pageSize = 20;

  List<VideoEjercicio> _videos = [];
  bool _isLoading = true;
  String _rutaBaseVideos = '';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  bool _showFilters = true;
  List<Map<String, dynamic>> _categoriasCatalogo = [];
  final Set<int> _selectedCategoriaIds = {};
  _OrdenVideos _ordenVideos = _OrdenVideos.nombre;
  bool _ordenAscendente = true;
  int _visibleVideoCount = _pageSize;
  bool _loadingMore = false;

  static const String _showFiltersKey = 'videos_ejercicios_show_filters';
  static const String _searchKey = 'videos_ejercicios_search';
  static const String _selectedCategoriasKey =
      'videos_ejercicios_selected_categorias';
  static const String _ordenKey = 'videos_ejercicios_orden';
  static const String _ordenAscKey = 'videos_ejercicios_orden_asc';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadUiState();
    _loadCategorias();
    _loadVideos();
    _loadParametrosVideos();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _loadingMore) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent * 0.8) {
      _loadMoreVideos();
    }
  }

  void _resetPaginationState() {
    _visibleVideoCount = _pageSize;
    _loadingMore = false;
  }

  void _scrollToTopIfNeeded() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _loadMoreVideos() {
    final total = _filteredAndSortedVideos().length;
    if (_visibleVideoCount >= total) return;

    setState(() {
      _loadingMore = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _visibleVideoCount =
            (_visibleVideoCount + _pageSize).clamp(0, total).toInt();
        _loadingMore = false;
      });
    });
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final search = prefs.getString(_searchKey) ?? '';
    final showFilters = prefs.getBool(_showFiltersKey) ?? true;
    final selected =
        prefs.getStringList(_selectedCategoriasKey) ?? const <String>[];
    final ordenIdx = prefs.getInt(_ordenKey);
    final ordenAsc = prefs.getBool(_ordenAscKey) ?? true;

    if (!mounted) return;
    setState(() {
      _search = search.trim();
      _searchCtrl.text = _search;
      _showFilters = showFilters;
      _selectedCategoriaIds
        ..clear()
        ..addAll(
          selected.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0),
        );
      _ordenVideos = ordenIdx != null &&
              ordenIdx >= 0 &&
              ordenIdx < _OrdenVideos.values.length
          ? _OrdenVideos.values[ordenIdx]
          : _OrdenVideos.fechaAlta;
      _ordenAscendente = ordenAsc ?? false;
    });
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_searchKey, _search);
    await prefs.setBool(_showFiltersKey, _showFilters);
    await prefs.setStringList(
      _selectedCategoriasKey,
      _selectedCategoriaIds.map((e) => e.toString()).toList(),
    );
    await prefs.setInt(_ordenKey, _ordenVideos.index);
    await prefs.setBool(_ordenAscKey, _ordenAscendente);
  }

  Future<void> _loadCategorias() async {
    try {
      final api = context.read<ApiService>();
      final cats = await api.getVideoCategorias();
      if (!mounted) return;
      setState(() {
        _categoriasCatalogo = cats;
      });
    } catch (_) {}
  }

  Future<void> _loadParametrosVideos() async {
    try {
      final api = context.read<ApiService>();
      final valor = await api.getParametroValor('ruta_base_videos_ejercicios');
      if (!mounted) return;
      setState(() {
        _rutaBaseVideos = (valor ?? '').trim();
      });
    } catch (_) {}
  }

  Future<void> _ensureRutaBaseLoaded() async {
    if (_rutaBaseVideos.trim().isNotEmpty) return;
    await _loadParametrosVideos();
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

  Widget _buildMetaTag({
    IconData? icon,
    required String text,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoListMeta(VideoEjercicio video) {
    final descripcionLength = (video.descripcion ?? '').trim().length;
    final descBackground =
        descripcionLength > 0 ? Colors.green.shade50 : Colors.grey.shade200;
    final descForeground =
        descripcionLength > 0 ? Colors.green.shade800 : Colors.grey.shade700;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _buildMetaTag(
          text: video.esYoutube ? 'YOUTUBE' : 'LOCAL',
          backgroundColor: Colors.blue.shade50,
          foregroundColor: Colors.blue.shade800,
        ),
        _buildMetaTag(
          icon: Icons.favorite,
          text: '${video.totalLikes}',
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red.shade700,
        ),
        _buildMetaTag(
          icon: Icons.notes_rounded,
          text: '$descripcionLength',
          backgroundColor: descBackground,
          foregroundColor: descForeground,
        ),
        _buildMetaTag(
          icon: video.visible == 'S' ? Icons.visibility : Icons.visibility_off,
          text: video.visible == 'S' ? 'VISIBLE' : 'OCULTO',
          backgroundColor:
              video.visible == 'S' ? Colors.teal.shade50 : Colors.grey.shade200,
          foregroundColor: video.visible == 'S'
              ? Colors.teal.shade800
              : Colors.grey.shade700,
        ),
      ],
    );
  }

  Widget _buildHashtagText(String texto, {TextStyle? baseStyle}) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'#[\wáéíóúÁÉÍÓÚñÑüÜ]+', caseSensitive: false);
    int lastEnd = 0;

    for (final match in regex.allMatches(texto)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: texto.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }
      final tag = match.group(0)!;
      spans.add(TextSpan(
        text: tag,
        style: (baseStyle ?? const TextStyle()).copyWith(
          color: Colors.blue,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Hashtag pulsado: $tag')),
            );
          },
      ));
      lastEnd = match.end;
    }

    if (lastEnd < texto.length) {
      spans.add(TextSpan(text: texto.substring(lastEnd), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Future<void> _showPremiumStylePreview(VideoEjercicio video) async {
    ImageProvider? thumbProvider;
    if (video.imagenMiniatura != null && video.imagenMiniatura!.isNotEmpty) {
      try {
        thumbProvider = MemoryImage(base64Decode(video.imagenMiniatura!));
      } catch (_) {}
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Card(
            margin: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 120),
                    );
                    if (!mounted) return;
                    await _playVideo(video);
                  },
                  child: thumbProvider != null
                      ? AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image(image: thumbProvider, fit: BoxFit.cover),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    video.esYoutube
                                        ? Icons.play_circle_outline
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          height: 160,
                          color: Colors.grey[200],
                          child: Center(
                            child: Icon(
                              video.esYoutube
                                  ? Icons.smart_display_outlined
                                  : Icons.play_circle_outline,
                              size: 52,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Text(
                    video.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (video.categoriaNombres.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 4,
                      children: video.categoriaNombres
                          .map(
                            (c) => Chip(
                              label:
                                  Text(c, style: const TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (video.descripcion != null && video.descripcion!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: _buildHashtagText(
                      video.descripcion!,
                      baseStyle:
                          const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await Future<void>.delayed(
                          const Duration(milliseconds: 120),
                        );
                        if (!mounted) return;
                        await _playVideo(video);
                      },
                      icon: const Icon(Icons.play_circle_outline),
                      label: Text(
                        video.esYoutube
                            ? 'Abrir en YouTube'
                            : video.esGif
                                ? 'Ver GIF'
                                : 'Reproducir vídeo',
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          video.meGusta == 'S'
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: video.meGusta == 'S' ? Colors.red : null,
                        ),
                        onPressed: null,
                      ),
                      Text('${video.totalLikes}',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          video.favorito == 'S'
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: video.favorito == 'S' ? Colors.amber : null,
                        ),
                        onPressed: null,
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(
                            video.esYoutube
                                ? 'YouTube'
                                : video.esGif
                                    ? 'GIF'
                                    : 'Vídeo',
                            style: const TextStyle(fontSize: 11),
                          ),
                          avatar: Icon(
                            video.esYoutube
                                ? Icons.smart_display
                                : video.esGif
                                    ? Icons.gif
                                    : Icons.play_circle,
                            size: 14,
                          ),
                          visualDensity: VisualDensity.compact,
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
  }

  Future<void> _playVideo(VideoEjercicio video) async {
    try {
      final rawUrl = (video.rutaVideo ?? '').trim();
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

      if (video.esGif) {
        final gifUrl = _buildVideoUrl(video.rutaVideo ?? '');
        if (gifUrl.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El vídeo no tiene ruta configurada')),
          );
          return;
        }
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

      await _ensureRutaBaseLoaded();
      final videoUrl = _buildVideoUrl(video.rutaVideo ?? '');
      final isAbsoluteVideoUrl =
          videoUrl.startsWith('http://') || videoUrl.startsWith('https://');
      if (videoUrl.isEmpty || !isAbsoluteVideoUrl) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La URL del vídeo local no es válida. Revisa ruta_base_videos_ejercicios y ruta_video.',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoEjercicioPlayerScreen(
            video: video,
            videoUrl: videoUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reproducir: $e')),
      );
    }
  }

  Future<void> _openVideoMenu(VideoEjercicio video) async {
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
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Reproducir vídeo'),
              onTap: () => Navigator.pop(context, 'play'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(context, 'edit'),
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
      await _showPremiumStylePreview(video);
    } else if (action == 'play') {
      await _playVideo(video);
    } else if (action == 'edit') {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoEjercicioEditScreen(video: video),
        ),
      );
      _loadVideos();
    } else if (action == 'delete') {
      await _deleteVideo(video);
    }
  }

  void _toggleFiltersVisibility() {
    _showFiltrarEjerciciosDialog();
  }

  void _toggleSearchVisibility() {
    setState(() {
      _showFilters = !_showFilters;
      if (!_showFilters) {
        _searchCtrl.clear();
        _search = '';
      }
      _resetPaginationState();
    });
    _scrollToTopIfNeeded();
    _saveUiState();
  }

  void _clearSearch() {
    setState(() {
      _searchCtrl.clear();
      _search = '';
      _resetPaginationState();
    });
    _scrollToTopIfNeeded();
    _saveUiState();
  }

  void _applySortSelection(_OrdenVideos orden) {
    setState(() {
      if (_ordenVideos == orden) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _ordenVideos = orden;
        _ordenAscendente = orden == _OrdenVideos.nombre;
      }
      _resetPaginationState();
    });
    _scrollToTopIfNeeded();
    _saveUiState();
  }

  List<VideoEjercicio> _filteredAndSortedVideos() {
    final query = _search.trim().toLowerCase();
    final filtered = _videos.where((video) {
      final matchText = query.isEmpty ||
          video.titulo.toLowerCase().contains(query) ||
          (video.descripcion ?? '').toLowerCase().contains(query) ||
          video.categoriaNombres.any((c) => c.toLowerCase().contains(query));

      final matchCategoria = _selectedCategoriaIds.isEmpty ||
          video.categoriaIds.any(_selectedCategoriaIds.contains);

      return matchText && matchCategoria;
    }).toList();

    filtered.sort((a, b) {
      final byName = a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
      switch (_ordenVideos) {
        case _OrdenVideos.nombre:
          return _ordenAscendente ? byName : -byName;
        case _OrdenVideos.fechaAlta:
          final dateA = a.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.fechaa ?? DateTime.fromMillisecondsSinceEpoch(0);
          final byDate = _ordenAscendente
              ? dateA.compareTo(dateB)
              : dateB.compareTo(dateA);
          return byDate != 0 ? byDate : byName;
        case _OrdenVideos.likes:
          final byLikes = _ordenAscendente
              ? a.totalLikes.compareTo(b.totalLikes)
              : b.totalLikes.compareTo(a.totalLikes);
          return byLikes != 0 ? byLikes : byName;
      }
    });

    return filtered;
  }

  String _buildPdfFilterSummary() {
    final parts = <String>[];
    if (_search.trim().isNotEmpty) {
      parts.add('Buscar: "${_search.trim()}"');
    }
    if (_selectedCategoriaIds.isNotEmpty) {
      final nombres = _categoriasCatalogo
          .where((cat) => _selectedCategoriaIds.contains(cat['codigo']))
          .map((cat) => (cat['nombre'] ?? '').toString())
          .where((name) => name.trim().isNotEmpty)
          .toList();
      if (nombres.isNotEmpty) {
        parts.add('Categorías: ${nombres.join(', ')}');
      }
    }
    final ordenTexto = _ordenVideos == _OrdenVideos.nombre
        ? 'Nombre'
        : _ordenVideos == _OrdenVideos.fechaAlta
            ? 'Fecha alta'
            : 'Likes';
    parts.add('Orden: $ordenTexto ${_ordenAscendente ? '↑' : '↓'}');
    return parts.join(' | ');
  }

  Future<void> _generateCatalogPdf() async {
    try {
      final api = context.read<ApiService>();
      final nutricionistaParam = await api.getParametro('nutricionista_nombre');
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      final logoParam = await api.getParametro('logotipo_dietista_documentos');
      final logoBase64 = logoParam?['valor']?.toString() ?? '';
      final logoSizeStr = logoParam?['valor2']?.toString() ?? '';
      Uint8List? logoBytes;
      if (logoBase64.isNotEmpty) {
        try {
          logoBytes = base64Decode(logoBase64);
        } catch (_) {}
      }

      final accentColorParam =
          await api.getParametro('color_fondo_banda_encabezado_pie_pdf');
      final accentColorStr = accentColorParam?['valor']?.toString() ?? '';

      final videos = _filteredAndSortedVideos();

      if (!mounted) return;
      await VideosEjerciciosCatalogPdfService.generateCatalogPdf(
        context: context,
        nutricionistaNombre: nutricionistaNombre,
        nutricionistaSubtitulo: nutricionistaSubtitulo,
        logoBytes: logoBytes,
        logoSizeStr: logoSizeStr,
        accentColorStr: accentColorStr,
        videos: videos,
        tituloTexto: 'Catálogo de vídeos de ejercicios',
        filtroResumen: _buildPdfFilterSummary(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openCategoriasDialog() async {
    final prefs = await SharedPreferences.getInstance();
    const showSearchKey = 'videos_ejercicios_categorias_show_search';
    bool showSearch = prefs.getBool(showSearchKey) ?? false;
    String search = '';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> addCategoria() async {
            final ctrl = TextEditingController();
            final nombre = await showDialog<String>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Nueva categoría'),
                content: TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Nombre de categoría'),
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
            final auth = context.read<AuthService>();
            final userId = int.tryParse(auth.userCode ?? '1') ?? 1;
            await context
                .read<ApiService>()
                .createVideoCategoria(nombre, userId);
            await _loadCategorias();
            if (mounted) setLocal(() {});
          }

          Future<void> editCategoria(Map<String, dynamic> categoria) async {
            final ctrl = TextEditingController(
              text: (categoria['nombre'] ?? '').toString(),
            );
            final nombre = await showDialog<String>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Editar categoría'),
                content: TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Nombre de categoría'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            );
            if (nombre == null || nombre.isEmpty) return;
            await context.read<ApiService>().updateVideoCategoria(
                  codigo: int.tryParse(categoria['codigo'].toString()) ?? 0,
                  nombre: nombre,
                );
            await _loadCategorias();
            if (mounted) setLocal(() {});
          }

          Future<void> deleteCategoria(Map<String, dynamic> categoria) async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Eliminar categoría'),
                content: Text(
                  '¿Eliminar ${categoria['nombre']}?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            );
            if (confirm != true) return;

            final codigo = int.tryParse(categoria['codigo'].toString()) ?? 0;
            await context.read<ApiService>().deleteVideoCategoria(codigo);
            _selectedCategoriaIds.remove(codigo);
            await _saveUiState();
            await _loadCategorias();
            if (mounted) {
              setState(() {});
              setLocal(() {});
            }
          }

          Future<void> openCategoriaMenu(Map<String, dynamic> categoria) async {
            final action = await showModalBottomSheet<String>(
              context: context,
              builder: (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Editar'),
                      onTap: () => Navigator.pop(context, 'edit'),
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

            if (action == 'edit') {
              await editCategoria(categoria);
            } else if (action == 'delete') {
              await deleteCategoria(categoria);
            }
          }

          final categoriaUsoCount = <int, int>{};
          for (final video in _videos) {
            for (final categoriaId in video.categoriaIds) {
              categoriaUsoCount[categoriaId] =
                  (categoriaUsoCount[categoriaId] ?? 0) + 1;
            }
          }

          final categoriasFiltradas = _categoriasCatalogo.where((categoria) {
            if (search.trim().isEmpty) return true;
            final nombre = (categoria['nombre'] ?? '').toString().toLowerCase();
            return nombre.contains(search.trim().toLowerCase());
          }).toList();

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Categorías',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: addCategoria,
                  icon: const Icon(Icons.add),
                  tooltip: 'Nueva categoría',
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    showSearch = !showSearch;
                    await prefs.setBool(showSearchKey, showSearch);
                    setLocal(() {});
                  },
                  icon: Icon(showSearch ? Icons.search_off : Icons.search),
                  tooltip: showSearch ? 'Ocultar buscar' : 'Mostrar buscar',
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
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
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSearch)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Buscar categoría',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setLocal(() {
                            search = value.trim();
                          });
                        },
                      ),
                    ),
                  Flexible(
                    child: categoriasFiltradas.isEmpty
                        ? const Center(child: Text('Sin categorías'))
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: categoriasFiltradas.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final categoria = categoriasFiltradas[index];
                              final codigo =
                                  int.tryParse('${categoria['codigo']}') ?? 0;
                              final itemCount = categoriaUsoCount[codigo] ?? 0;
                              return SizedBox(
                                height: 42,
                                child: InkWell(
                                  onTap: () => editCategoria(categoria),
                                  onLongPress: () =>
                                      openCategoriaMenu(categoria),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            (categoria['nombre'] ?? '')
                                                .toString(),
                                            style:
                                                const TextStyle(fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 18,
                                        height: 18,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: itemCount > 0
                                              ? Colors.green
                                              : Colors.grey.shade500,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$itemCount',
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
                                            openCategoriaMenu(categoria),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
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
        },
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildFiltersPanel() {
    if (!_showFilters) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Buscar vídeo de ejercicio',
          prefixIcon: IconButton(
            tooltip: _search.trim().isNotEmpty ? 'Limpiar búsqueda' : 'Buscar',
            onPressed: _search.trim().isNotEmpty ? _clearSearch : null,
            icon: Icon(
              _search.trim().isNotEmpty ? Icons.clear : Icons.search,
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
            _search = value.trim();
            _resetPaginationState();
          });
          _scrollToTopIfNeeded();
          _saveUiState();
        },
      ),
    );
  }

  Future<void> _showFiltrarEjerciciosDialog() async {
    if (_categoriasCatalogo.isEmpty) {
      await _loadCategorias();
    }

    final tempSelected = Set<int>.from(_selectedCategoriaIds);
    String searchQuery = '';
    const showSearchKey = 'videos_ejercicios_filter_show_search';
    final prefs = await SharedPreferences.getInstance();
    bool showSearch = prefs.getBool(showSearchKey) ?? false;

    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final filtered = _categoriasCatalogo.where((cat) {
            if (searchQuery.trim().isEmpty) return true;
            final name = (cat['nombre'] ?? '').toString().toLowerCase();
            return name.contains(searchQuery.trim().toLowerCase());
          }).toList();

          return AlertDialog(
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filtrar ejercicios',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(showSearch ? Icons.search_off : Icons.search),
                  tooltip: showSearch ? 'Ocultar buscar' : 'Mostrar buscar',
                  onPressed: () async {
                    showSearch = !showSearch;
                    await prefs.setBool(showSearchKey, showSearch);
                    setDialog(() {});
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
                  onPressed: () => Navigator.pop(context, false),
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
                    TextField(
                      onChanged: (value) {
                        setDialog(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar categoría...',
                        prefixIcon: IconButton(
                          tooltip: searchQuery.isNotEmpty
                              ? 'Limpiar búsqueda'
                              : 'Buscar',
                          onPressed: searchQuery.isNotEmpty
                              ? () {
                                  setDialog(() {
                                    searchQuery = '';
                                  });
                                }
                              : null,
                          icon: Icon(
                            searchQuery.isNotEmpty ? Icons.clear : Icons.search,
                            size: 20,
                          ),
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Ocultar búsqueda',
                          onPressed: () async {
                            showSearch = false;
                            await prefs.setBool(showSearchKey, showSearch);
                            setDialog(() {});
                          },
                          icon: const Icon(Icons.visibility_off_outlined,
                              size: 20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: filtered.map((cat) {
                          final id = int.tryParse('${cat['codigo']}') ?? 0;
                          return CheckboxListTile(
                            dense: true,
                            value: tempSelected.contains(id),
                            title: Text((cat['nombre'] ?? '').toString()),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (checked) {
                              setDialog(() {
                                if (checked == true) {
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
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialog(() {
                    tempSelected.clear();
                  });
                },
                child: const Text('Limpiar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Aplicar'),
                    const SizedBox(width: 6),
                    if (tempSelected.isNotEmpty)
                      Container(
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
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

    if (applied != true) return;
    setState(() {
      _selectedCategoriaIds
        ..clear()
        ..addAll(tempSelected);
      _resetPaginationState();
    });
    _scrollToTopIfNeeded();
    _saveUiState();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      final api = context.read<ApiService>();
      final rawList = await api.getVideosEjercicios();
      if (mounted) {
        setState(() {
          _videos = rawList.map((e) => VideoEjercicio.fromJson(e)).toList();
          _resetPaginationState();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar vídeos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteVideo(VideoEjercicio video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar vídeo'),
        content: Text(
            '¿Eliminar "${video.titulo}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final api = context.read<ApiService>();
      await api.deleteVideoEjercicio(video.codigo!);
      setState(() {
        _videos.removeWhere((v) => v.codigo == video.codigo);
        _resetPaginationState();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vídeo eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final videosFiltrados = _filteredAndSortedVideos();
    final videosVisibles = videosFiltrados.take(_visibleVideoCount).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(child: Text('Vídeos ejercicios')),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${videosFiltrados.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.search_off : Icons.search),
            tooltip: _showFilters ? 'Ocultar buscar' : 'Buscar',
            onPressed: _toggleSearchVisibility,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_alt),
                tooltip: 'Filtrar ejercicios',
                onPressed: _showFiltrarEjerciciosDialog,
              ),
              if (_selectedCategoriaIds.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${_selectedCategoriaIds.length}',
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
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (value) async {
              if (value == 'buscar') {
                _toggleSearchVisibility();
                return;
              }
              if (value == 'categorias') {
                await _openCategoriasDialog();
                return;
              }
              if (value == 'filtros') {
                await _showFiltrarEjerciciosDialog();
                return;
              }
              if (value == 'pdf') {
                await _generateCatalogPdf();
                return;
              }
              if (value == 'actualizar') {
                await _loadVideos();
                return;
              }
              if (value == 'orden_nombre') {
                _applySortSelection(_OrdenVideos.nombre);
                return;
              }
              if (value == 'orden_fecha') {
                _applySortSelection(_OrdenVideos.fechaAlta);
                return;
              }
              if (value == 'orden_likes') {
                _applySortSelection(_OrdenVideos.likes);
                return;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'buscar',
                child: Row(
                  children: [
                    Icon(
                      _showFilters ? Icons.search_off : Icons.search,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(_showFilters ? 'Ocultar buscar' : 'Buscar'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'filtros',
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(width: 18, height: 18),
                        const Icon(Icons.filter_alt, size: 18),
                        if (_selectedCategoriaIds.isNotEmpty)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              constraints: const BoxConstraints(
                                  minWidth: 14, minHeight: 14),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3, vertical: 1),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${_selectedCategoriaIds.length}',
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
                    const SizedBox(width: 10),
                    const Text('Filtrar'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'categorias',
                child: Row(
                  children: [
                    Icon(Icons.category, size: 18),
                    SizedBox(width: 10),
                    Text('Categorías'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Generar PDF'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'actualizar',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 10),
                    Text('Actualizar'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem<String>(
                value: 'orden_nombre',
                checked: _ordenVideos == _OrdenVideos.nombre,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Título')),
                    if (_ordenVideos == _OrdenVideos.nombre)
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
                value: 'orden_fecha',
                checked: _ordenVideos == _OrdenVideos.fechaAlta,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Recientes')),
                    if (_ordenVideos == _OrdenVideos.fechaAlta)
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
                value: 'orden_likes',
                checked: _ordenVideos == _OrdenVideos.likes,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar likes')),
                    if (_ordenVideos == _OrdenVideos.likes)
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VideoEjercicioEditScreen()),
          );
          _loadVideos();
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? const Center(child: Text('No hay vídeos. Toca + para agregar.'))
              : RefreshIndicator(
                  onRefresh: _loadVideos,
                  child: videosFiltrados.isEmpty
                      ? ListView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            _buildFiltersPanel(),
                            const SizedBox(height: 40),
                            const Center(
                              child: Text(
                                'No hay vídeos para el filtro actual',
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: videosVisibles.length +
                              1 +
                              (_loadingMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == 0) return _buildFiltersPanel();
                            if (_loadingMore &&
                                i == videosVisibles.length + 1) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final v = videosVisibles[i - 1];
                            ImageProvider? thumb;
                            if (v.imagenMiniatura != null &&
                                v.imagenMiniatura!.isNotEmpty) {
                              try {
                                thumb = MemoryImage(
                                    base64Decode(v.imagenMiniatura!));
                              } catch (_) {}
                            }
                            return Dismissible(
                              key: Key('video_${v.codigo}'),
                              direction: DismissDirection.startToEnd,
                              dismissThresholds: {
                                DismissDirection.startToEnd: context
                                    .watch<ConfigService>()
                                    .deleteSwipeDismissThreshold,
                              },
                              confirmDismiss: (_) async {
                                await _deleteVideo(v);
                                return false;
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
                              child: ListTile(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VideoEjercicioEditScreen(
                                        video: v,
                                      ),
                                    ),
                                  );
                                  _loadVideos();
                                },
                                onLongPress: () => _openVideoMenu(v),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: thumb != null
                                        ? Image(image: thumb, fit: BoxFit.cover)
                                        : Container(
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.play_circle_outline,
                                              size: 32,
                                            ),
                                          ),
                                  ),
                                ),
                                title: Text(v.titulo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: _buildVideoListMeta(v),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.more_vert),
                                      tooltip: 'Más opciones',
                                      onPressed: () => _openVideoMenu(v),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
