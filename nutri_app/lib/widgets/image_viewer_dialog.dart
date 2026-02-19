import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';

class ImageViewerDialog extends StatefulWidget {
  final String base64Image;
  final String? title;

  const ImageViewerDialog({
    super.key,
    required this.base64Image,
    this.title,
  });

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  double _currentScale() {
    return _transformationController.value.getMaxScaleOnAxis();
  }

  void _zoomBy(double delta) {
    final current = _currentScale();
    final target = (current + delta).clamp(1.0, 4.0);
    final factor = target / current;
    final matrix = _transformationController.value.clone()..scale(factor);
    _transformationController.value = matrix;
  }

  String _detectImageExtension(List<int> bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'jpg';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'gif';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return 'png';
  }

  String _detectImageMime(List<int> bytes) {
    switch (_detectImageExtension(bytes)) {
      case 'jpg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'png':
      default:
        return 'image/png';
    }
  }

  String _sanitizeFileName(String value) {
    return value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    ScaffoldMessenger.of(rootContext).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _copyImageToClipboard(List<int> bytes) async {
    try {
      if (Platform.isWindows ||
          Platform.isMacOS ||
          Platform.isLinux ||
          Platform.isAndroid ||
          Platform.isIOS) {
        final decoded = img.decodeImage(Uint8List.fromList(bytes));
        if (decoded == null) {
          throw Exception('No se pudo decodificar la imagen');
        }
        final pngBytes = img.encodePng(decoded);
        final item = DataWriterItem();
        item.add(Formats.png(pngBytes));
        await ClipboardWriter.instance.write([item]);
        _showMessage('Imagen copiada al portapapeles');
        return;
      }

      final mime = _detectImageMime(bytes);
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      await Clipboard.setData(ClipboardData(text: dataUrl));
      _showMessage('Imagen copiada como texto');
    } catch (e) {
      _showMessage('No se pudo copiar la imagen: $e');
    }
  }

  Future<void> _saveImageToFile(List<int> bytes) async {
    final extension = _detectImageExtension(bytes);
    final baseName = _sanitizeFileName(widget.title ?? 'imagen');
    final safeName = baseName.isEmpty ? 'imagen' : baseName;
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = '$safeName-$timestamp.$extension';

    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      _showMessage('Imagen guardada en Documentos');
      return;
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar imagen',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
    );

    if (path == null) {
      return;
    }

    final file = File(path);
    await file.writeAsBytes(bytes);
    _showMessage('Imagen guardada');
  }

  @override
  Widget build(BuildContext context) {
    try {
      final imageBytes = base64Decode(widget.base64Image);
      final media = MediaQuery.of(context);
      final maxWidth = media.size.width - 32;
      final maxHeight = media.size.height - 160;

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: SizedBox(
              width: maxWidth,
              height: maxHeight,
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title ?? '',
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        boundaryMargin: const EdgeInsets.all(20),
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Image.memory(
                          imageBytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        IconButton(
                          tooltip: 'Ajustar',
                          icon: const Icon(Icons.fit_screen),
                          onPressed: _resetZoom,
                        ),
                        IconButton(
                          tooltip: 'Zoom +',
                          icon: const Icon(Icons.zoom_in),
                          onPressed: () => _zoomBy(0.1),
                        ),
                        IconButton(
                          tooltip: 'Zoom -',
                          icon: const Icon(Icons.zoom_out),
                          onPressed: () => _zoomBy(-0.1),
                        ),
                        if (Platform.isWindows ||
                            Platform.isMacOS ||
                            Platform.isLinux)
                          IconButton(
                            tooltip: 'Copiar imagen',
                            icon: const Icon(Icons.content_copy),
                            onPressed: () => _copyImageToClipboard(imageBytes),
                          ),
                        IconButton(
                          tooltip: 'Guardar imagen',
                          icon: const Icon(Icons.save_alt),
                          onPressed: () => _saveImageToFile(imageBytes),
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
    } catch (e) {
      return AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Error')),
            IconButton(
              tooltip: 'Cerrar',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: Text('No se puede cargar la imagen: $e'),
      );
    }
  }
}

void showImageViewerDialog({
  required BuildContext context,
  required String base64Image,
  String? title,
}) {
  showDialog(
    context: context,
    builder: (context) => ImageViewerDialog(
      base64Image: base64Image,
      title: title,
    ),
  );
}
