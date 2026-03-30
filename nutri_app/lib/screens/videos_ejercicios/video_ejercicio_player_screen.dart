import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../models/video_ejercicio.dart';

class VideoEjercicioPlayerScreen extends StatefulWidget {
  final VideoEjercicio video;
  final String videoUrl;

  const VideoEjercicioPlayerScreen({
    super.key,
    required this.video,
    required this.videoUrl,
  });

  @override
  State<VideoEjercicioPlayerScreen> createState() =>
      _VideoEjercicioPlayerScreenState();
}

class _VideoEjercicioPlayerScreenState
    extends State<VideoEjercicioPlayerScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitializing = true;
  String? _errorMessage;
  Timer? _initWatchdog;

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
      ));
      lastEnd = match.end;
    }

    if (lastEnd < texto.length) {
      spans.add(TextSpan(text: texto.substring(lastEnd), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  // Disable content-encoding so the server sends raw bytes, which is
  // required for HTTP range requests / seeking to work correctly.
  static const _httpHeaders = <String, String>{
    'Accept-Encoding': 'identity',
  };

  /// Detecta URLs de vídeos alojados en el servidor PHP (php_api/med/) y las
  /// reescribe al proxy video_stream.php, que maneja Range requests
  /// correctamente desde PHP, evitando el bloqueo WAF del servidor.
  ///
  /// Ejemplo:
  ///   https://host/php_api/med/video.mp4
  ///   → https://host/php_api/api/video_stream.php?file=video.mp4
  static String _toProxyUrlIfNeeded(String url) {
    final medPattern = RegExp(
      r'^(https?://[^/]+/[^?#]*/php_api/)med/(.+)$',
      caseSensitive: false,
    );
    final match = medPattern.firstMatch(url);
    if (match != null) {
      final base = match.group(1)!;
      final filename = match.group(2)!;
      return '${base}api/video_stream.php?file=${Uri.encodeComponent(filename)}';
    }
    return url;
  }

  Future<void> _initPlayer() async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });
    _chewieController?.dispose();
    _chewieController = null;
    await _videoController?.dispose();
    _videoController = null;
    _initWatchdog?.cancel();

    final rawUrl = _toProxyUrlIfNeeded(widget.videoUrl.trim());
    final normalizedUrl = Uri.encodeFull(rawUrl);
    final isAbsoluteUrl = normalizedUrl.startsWith('http://') ||
        normalizedUrl.startsWith('https://');
    if (!isAbsoluteUrl) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'URL de vídeo inválida (debe ser http/https): $rawUrl';
        });
      }
      return;
    }

    _initWatchdog = Timer(const Duration(seconds: 35), () {
      if (!mounted || !_isInitializing) return;
      setState(() {
        _isInitializing = false;
        _errorMessage =
            'El reproductor tardó demasiado en iniciar. Comprueba la URL o abre el vídeo externamente.';
      });
    });

    final uri = Uri.parse(normalizedUrl);

    try {
      debugPrint(
          '[VideoPlayer] Intentando reproducir URL: "${widget.videoUrl}"');
      try {
        _videoController = VideoPlayerController.networkUrl(
          uri,
          httpHeaders: _httpHeaders,
        );
        await _videoController!.initialize().timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException(
                'El servidor tardó demasiado. Comprueba la conexión o '
                'asegúrate de que el vídeo está en formato compatible (MP4 faststart).',
              ),
            );
      } on PlatformException catch (e) {
        final msg = (e.message ?? e.toString()).toLowerCase();
        final isTextureChannelIssue =
            msg.contains('createfortextureview') || msg.contains('pigeon');

        if (!isTextureChannelIssue) rethrow;

        debugPrint(
          '[VideoPlayer] Fallback a PlatformView por error TextureView: $e',
        );
        await _videoController?.dispose();

        _videoController = VideoPlayerController.networkUrl(
          uri,
          httpHeaders: _httpHeaders,
          viewType: VideoViewType.platformView,
        );
        await _videoController!.initialize().timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException(
                'El servidor tardó demasiado. Comprueba la conexión o '
                'asegúrate de que el vídeo está en formato compatible (MP4 faststart).',
              ),
            );
      }

      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
      );
      _initWatchdog?.cancel();
      setState(() => _isInitializing = false);
    } catch (e) {
      _initWatchdog?.cancel();
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = e is TimeoutException
              ? (e.message ?? 'Tiempo de espera agotado')
              : 'No se pudo reproducir el vídeo: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _initWatchdog?.cancel();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _openExternalUrl() async {
    final rawUrl = widget.videoUrl.trim();
    if (rawUrl.isEmpty) return;
    try {
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
          const SnackBar(content: Text('No se pudo abrir la URL externa.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir URL externa: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.video.titulo),
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _initPlayer,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _openExternalUrl,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Abrir externamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio > 0
                          ? _videoController!.value.aspectRatio
                          : 16 / 9,
                      child: Chewie(controller: _chewieController!),
                    ),
                    if (widget.video.descripcion != null &&
                        widget.video.descripcion!.isNotEmpty)
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildHashtagText(
                            widget.video.descripcion!,
                            baseStyle: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
