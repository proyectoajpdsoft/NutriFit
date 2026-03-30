import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_clipboard/super_clipboard.dart';

String _extractFotoBase64Candidate(String clipboardText) {
  final raw = clipboardText.trim();
  if (raw.isEmpty) {
    return '';
  }

  final match = RegExp(
    r'\[\s*foto\s*\]\s*(.*)$',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(raw);

  if (match != null) {
    final candidate = (match.group(1) ?? '').trim();
    if (candidate.isNotEmpty) {
      return candidate;
    }
  }

  return raw;
}

Uint8List? _decodeBase64Image(String base64String) {
  final raw = base64String.trim();
  if (raw.isEmpty) {
    return null;
  }

  var data = raw;
  const marker = 'base64,';
  final index = raw.indexOf(marker);
  if (index >= 0) {
    data = raw.substring(index + marker.length);
  }

  while (data.length % 4 != 0) {
    data += '=';
  }

  try {
    return Uint8List.fromList(base64Decode(data));
  } catch (_) {
    return null;
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
        if (!completer.isCompleted) {
          completer.complete(bytes);
        }
      } catch (_) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    },
    onError: (_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    },
  );

  if (progress == null) {
    return null;
  }

  return completer.future;
}

Future<Uint8List?> _readImageBytesFromSystemClipboard() async {
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

bool _canUseSystemClipboardImagePaste() {
  if (kIsWeb) {
    return false;
  }
  try {
    return SystemClipboard.instance != null;
  } catch (_) {
    return false;
  }
}

Future<Uint8List?> showPasteImageDialog(
  BuildContext context, {
  String title = 'Pegar imagen',
  String? description,
}) async {
  Uint8List? imageBytes;
  String? errorText;
  bool applying = false;
  final canPasteClipboardImage = _canUseSystemClipboardImagePaste();

  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: !applying,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    description ??
                        'Genera la imagen en formato base64 o copiala directamente al portapapeles y pulsa en pegar para agregarla.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: applying
                            ? null
                            : () async {
                                final data = await Clipboard.getData(
                                  Clipboard.kTextPlain,
                                );
                                final text = data?.text ?? '';
                                final candidate =
                                    _extractFotoBase64Candidate(text);
                                final decoded = _decodeBase64Image(candidate);

                                setDialogState(() {
                                  imageBytes = decoded;
                                  errorText = decoded == null
                                      ? 'No se detectó una imagen base64 válida en el portapapeles.'
                                      : null;
                                });
                              },
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Pegar base64'),
                      ),
                      if (canPasteClipboardImage)
                        FilledButton.icon(
                          onPressed: applying
                              ? null
                              : () async {
                                  final bytes =
                                      await _readImageBytesFromSystemClipboard();
                                  setDialogState(() {
                                    imageBytes = bytes;
                                    errorText = bytes == null
                                        ? 'No se detectó una imagen en el portapapeles del sistema.'
                                        : null;
                                  });
                                },
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Pegar portapapeles'),
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
                  if (imageBytes != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
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
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: applying
                          ? null
                          : () async {
                              final bytes = imageBytes;
                              if (bytes == null) return;
                              setDialogState(() {
                                applying = true;
                                errorText = null;
                              });
                              Navigator.pop(dialogContext, bytes);
                            },
                      icon: applying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(applying ? 'Aplicando...' : 'Aplicar imagen'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: applying ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    ),
  );
}
