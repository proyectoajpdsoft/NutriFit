import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/video_ejercicio.dart';

class VideoEjercicioDetailScreen extends StatelessWidget {
  const VideoEjercicioDetailScreen({
    super.key,
    required this.video,
    required this.onPlay,
  });

  final VideoEjercicio video;
  final Future<void> Function() onPlay;

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
          ..onTap = () => Navigator.pop(context, tag.replaceFirst('#', '')),
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
    ImageProvider? thumbProvider;
    if (video.imagenMiniatura != null && video.imagenMiniatura!.isNotEmpty) {
      try {
        thumbProvider = MemoryImage(base64Decode(video.imagenMiniatura!));
      } catch (_) {}
    }

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
              onTap: onPlay,
              child: thumbProvider != null
                  ? AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(image: thumbProvider, fit: BoxFit.cover),
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
                        ],
                      ),
                    )
                  : Container(
                      height: 210,
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(
                          video.esYoutube
                              ? Icons.smart_display_outlined
                              : Icons.play_circle_outline,
                          size: 66,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onPlay,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Reproducir vídeo'),
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
              const SizedBox(width: 10),
              Chip(
                label: Text(
                  video.esYoutube
                      ? 'YouTube'
                      : video.esGif
                          ? 'GIF'
                          : 'Vídeo',
                ),
                visualDensity: VisualDensity.compact,
              ),
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
                    onPressed: () => Navigator.pop(
                      context,
                      id != null ? '__catid__:$id' : '__cat__:$c',
                    ),
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
