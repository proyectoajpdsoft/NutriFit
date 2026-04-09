import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/video_ejercicio.dart';

class VideoEjercicioDetailScreen extends StatefulWidget {
  const VideoEjercicioDetailScreen({
    super.key,
    required this.video,
    required this.onPlay,
    this.onActionSelected,
  });

  final VideoEjercicio video;
  final Future<void> Function() onPlay;
  final Future<void> Function(String action)? onActionSelected;

  @override
  State<VideoEjercicioDetailScreen> createState() =>
      _VideoEjercicioDetailScreenState();
}

class _VideoEjercicioDetailScreenState
    extends State<VideoEjercicioDetailScreen> {
  ImageProvider? _thumbProvider;

  @override
  void initState() {
    super.initState();
    _thumbProvider = _buildThumbProvider(widget.video.imagenMiniatura);
  }

  @override
  void didUpdateWidget(covariant VideoEjercicioDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.imagenMiniatura != widget.video.imagenMiniatura) {
      _thumbProvider = _buildThumbProvider(widget.video.imagenMiniatura);
    }
  }

  ImageProvider? _buildThumbProvider(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(value));
    } catch (_) {
      return null;
    }
  }

  Widget _buildYoutubeOverlayBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: const Icon(
        Icons.smart_display_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildHashtagText(
    BuildContext context,
    String texto, {
    TextStyle? baseStyle,
  }) {
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
            final action = tag.replaceFirst('#', '');
            if (widget.onActionSelected != null) {
              widget.onActionSelected!(action);
            } else {
              Navigator.pop(context, action);
            }
          },
      ));
      lastEnd = match.end;
    }

    if (lastEnd < texto.length) {
      spans.add(TextSpan(text: texto.substring(lastEnd), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final thumbProvider = _thumbProvider;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          video.titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onPlay,
              child: thumbProvider != null
                  ? AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RepaintBoundary(
                            child: Image(
                              image: thumbProvider,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          ),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                video.esYoutube
                                    ? Icons.play_circle_outline
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                          ),
                          if (video.esYoutube)
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: _buildYoutubeOverlayBadge(),
                            ),
                        ],
                      ),
                    )
                  : Container(
                      height: 210,
                      color: Colors.grey[200],
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              video.esYoutube
                                  ? Icons.smart_display_outlined
                                  : Icons.play_circle_outline,
                              size: 66,
                              color: Colors.grey[400],
                            ),
                          ),
                          if (video.esYoutube)
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: _buildYoutubeOverlayBadge(),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6FCF97),
              foregroundColor: const Color(0xFF103B20),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            onPressed: widget.onPlay,
            icon: Icon(
              video.esYoutube ? Icons.smart_display_rounded : Icons.play_arrow,
            ),
            label: Text(
              video.esYoutube ? 'Reproducir en YouTube' : 'Reproducir vídeo',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            video.titulo,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                video.meGusta == 'S' ? Icons.favorite : Icons.favorite_border,
                color: video.meGusta == 'S' ? Colors.red : null,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text('${video.totalLikes}'),
              const SizedBox(width: 14),
              Icon(
                video.favorito == 'S' ? Icons.bookmark : Icons.bookmark_border,
                color: video.favorito == 'S' ? Colors.amber : null,
                size: 18,
              ),
              if (!video.esYoutube) ...[
                const SizedBox(width: 10),
                Chip(
                  label: Text(video.esGif ? 'GIF' : 'Vídeo'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          if (video.categoriaNombres.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: video.categoriaNombres.asMap().entries.map(
                (entry) {
                  final idx = entry.key;
                  final c = entry.value;
                  final id = idx < video.categoriaIds.length
                      ? video.categoriaIds[idx]
                      : null;
                  return ActionChip(
                    label: Text(c, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final action =
                          id != null ? '__catid__:$id' : '__cat__:$c';
                      if (widget.onActionSelected != null) {
                        widget.onActionSelected!(action);
                      } else {
                        Navigator.pop(context, action);
                      }
                    },
                  );
                },
              ).toList(),
            ),
          ],
          if (video.descripcion != null && video.descripcion!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildHashtagText(
              context,
              video.descripcion!,
              baseStyle: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
