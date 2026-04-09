import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:provider/provider.dart';

class ProfileImagePicker extends StatefulWidget {
  final String? initialBase64Image;
  final ValueChanged<String?> onImageChanged;

  const ProfileImagePicker({
    super.key,
    this.initialBase64Image,
    required this.onImageChanged,
  });

  @override
  State<ProfileImagePicker> createState() => _ProfileImagePickerState();
}

class _ProfileImagePickerState extends State<ProfileImagePicker> {
  static const Rect _profileCircleNormalizedRect = Rect.fromLTWH(
    0.15,
    0.22,
    0.70,
    0.58,
  );
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  String? _imageBase64;
  // ignore: unused_field
  int _maxImageSizeKb = 500; // Valor por defecto
  int _maxImageWidth = 400; // Valor por defecto
  int _maxImageHeight = 400; // Valor por defecto

  @override
  void initState() {
    super.initState();
    _imageBase64 = widget.initialBase64Image;
    _loadMaxImageSize();
  }

  Future<void> _loadMaxImageSize() async {
    try {
      // Primero intentar cargar el parámetro de dimensiones
      final dimParam = await _apiService.getParametro(
        'usuario_max_imagen_tamaño',
      );
      if (dimParam != null) {
        final width = int.tryParse(dimParam['valor'] ?? '400');
        final height = int.tryParse(dimParam['valor2'] ?? '400');
        if (width != null && height != null && mounted) {
          setState(() {
            _maxImageWidth = width;
            _maxImageHeight = height;
          });
        }
      }

      // Mantener también el parámetro de tamaño en KB como fallback
      final sizeParam = await _apiService.getParametro('usuario_max_imagen_kb');
      if (sizeParam != null) {
        final size = int.tryParse(sizeParam['valor'] ?? '500');
        if (size != null && mounted) {
          setState(() {
            _maxImageSizeKb = size;
          });
        }
      }
    } catch (e) {
      // Si no existen los parámetros, usar valores por defecto
    }
  }

  /// Redimensiona una imagen para que quepa dentro de los límites especificados
  /// Mantiene la relación de aspecto
  Future<File> _resizeImageIfNeeded(File imageFile) async {
    try {
      // Leer la imagen original
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return imageFile;

      // Verificar si necesita redimensionamiento
      if (image.width <= _maxImageWidth && image.height <= _maxImageHeight) {
        return imageFile; // La imagen ya cabe dentro de los límites
      }

      // Calcular el factor de escala manteniendo la relación de aspecto
      double scale = 1.0;

      // Si el ancho excede el límite
      if (image.width > _maxImageWidth) {
        scale = _maxImageWidth / image.width;
      }

      // Si el alto excede el límite y requiere un factor de escala mayor
      if (image.height > _maxImageHeight) {
        final scaleHeight = _maxImageHeight / image.height;
        if (scaleHeight < scale) {
          scale = scaleHeight;
        }
      }

      // Redimensionar la imagen
      final newWidth = (image.width * scale).toInt();
      final newHeight = (image.height * scale).toInt();

      final resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // Guardar la imagen redimensionada en el mismo archivo
      final resizedBytes = img.encodePng(resizedImage);
      await imageFile.writeAsBytes(resizedBytes);

      return imageFile;
    } catch (e) {
      // Si algo falla, devolver la imagen original
      return imageFile;
    }
  }

  Future<void> _pickAndCropImage(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // Paso 1: Seleccionar imagen
      XFile? pickedFile;
      if (source == ImageSource.camera) {
        pickedFile = await _capturarImagenPerfilConCirculo();
      } else {
        pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 85, // Reducir calidad para optimizar tamaño
        );
      }

      if (pickedFile == null) return;

      // Paso 2: Crear archivo desde la imagen seleccionada
      var file = File(pickedFile.path);

      // Paso 3: Redimensionar la imagen si excede los límites
      file = await _resizeImageIfNeeded(file);

      // Paso 4: Convertir a base64 y guardar
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      final fileSize = bytes.length;

      setState(() {
        _imageBase64 = base64String;
      });

      widget.onImageChanged(_imageBase64);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.profileImagePickerSaved(
                (fileSize / 1024).toStringAsFixed(1),
              ),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showUserFriendlyError(
          l10n.profileImagePickerProcessError,
          technicalDetails: e.toString(),
        );
      }
    }
  }

  Future<XFile?> _capturarImagenPerfilConCirculo() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    }

    final capturedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const _ProfileCircleCameraCaptureScreen(
          circleRectNormalized: _profileCircleNormalizedRect,
        ),
      ),
    );

    if (capturedPath == null || capturedPath.trim().isEmpty) {
      return null;
    }

    try {
      final cropped = await _cropProfileImageWithCircle(
        filePath: capturedPath,
        normalizedRect: _profileCircleNormalizedRect,
      );
      return XFile(cropped ?? capturedPath);
    } catch (_) {
      return XFile(capturedPath);
    }
  }

  Future<String?> _cropProfileImageWithCircle({
    required String filePath,
    required Rect normalizedRect,
  }) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      return null;
    }

    final bytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return null;
    }

    final left = (decoded.width * normalizedRect.left).round().clamp(
          0,
          decoded.width - 1,
        );
    final top = (decoded.height * normalizedRect.top).round().clamp(
          0,
          decoded.height - 1,
        );

    final maxCropWidth = decoded.width - left;
    final maxCropHeight = decoded.height - top;

    final cropWidth =
        (decoded.width * normalizedRect.width).round().clamp(1, maxCropWidth);
    final cropHeight = (decoded.height * normalizedRect.height)
        .round()
        .clamp(1, maxCropHeight);

    final squareSize = math.min(cropWidth, cropHeight);
    final squareX = left + ((cropWidth - squareSize) / 2).round();
    final squareY = top + ((cropHeight - squareSize) / 2).round();

    final croppedSquare = img.copyCrop(
      decoded,
      x: squareX,
      y: squareY,
      width: squareSize,
      height: squareSize,
    );

    final radius = squareSize / 2;
    final center = radius - 0.5;
    final masked = img.Image(
      width: squareSize,
      height: squareSize,
      numChannels: 4,
    );

    for (var y = 0; y < squareSize; y++) {
      for (var x = 0; x < squareSize; x++) {
        final dx = x - center;
        final dy = y - center;
        final distanceSquared = (dx * dx) + (dy * dy);
        if (distanceSquared <= (radius * radius)) {
          final pixel = croppedSquare.getPixel(x, y);
          masked.setPixel(x, y, pixel);
        } else {
          masked.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }

    final outputPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}nutrifit_profile_circle_crop_${DateTime.now().millisecondsSinceEpoch}.png';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(img.encodePng(masked, level: 4));
    return outputFile.path;
  }

  /// Muestra un error de manera controlada según el modo debug y tipo de usuario
  void _showUserFriendlyError(
    String userMessage, {
    String? technicalDetails,
    bool showDetail = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context, listen: false);
    final configService = Provider.of<ConfigService>(context, listen: false);
    final isAdmin = authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';

    String displayMessage = userMessage;

    // Solo mostrar detalles técnicos si:
    // - Estamos en modo debug Y el usuario es administrador
    // - O si showDetail es true (para mensajes específicos como tamaño de imagen)
    if (configService.appMode == AppMode.debug &&
        isAdmin &&
        technicalDetails != null) {
      displayMessage +=
          '\n\n${l10n.profileImagePickerTechnicalDetails}: $technicalDetails';
    } else if (!showDetail && technicalDetails != null) {
      // Para usuarios no admin o en producción, mensaje genérico
      displayMessage = l10n.profileImagePickerOperationFailed;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(displayMessage),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showImageSourceDialog() {
    final l10n = AppLocalizations.of(context)!;
    // En Windows, la cámara no está soportada por image_picker
    final bool isCameraAvailable =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileImagePickerDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCameraAvailable)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(l10n.profileImagePickerTakePhoto),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndCropImage(ImageSource.camera);
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                isCameraAvailable
                    ? l10n.profileImagePickerChooseFromGallery
                    : l10n.profileImagePickerSelectImage,
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndCropImage(ImageSource.gallery);
              },
            ),
            if (_imageBase64 != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  l10n.profileImagePickerRemovePhoto,
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _imageBase64 = null;
                  });
                  widget.onImageChanged(null);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(l10n.commonCancel),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                    color: Colors.grey.shade200,
                  ),
                  child: ClipOval(
                    child: _imageBase64 != null && _imageBase64!.isNotEmpty
                        ? _buildImageWidget()
                        : Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            l10n.profileImagePickerPrompt,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        Center(
          child: Text(
            l10n.profileImagePickerMaxDimensions(
              _maxImageWidth,
              _maxImageHeight,
            ),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }

  Widget _buildImageWidget() {
    try {
      final imageBytes = base64Decode(_imageBase64!);
      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // debugPrint('Error al cargar imagen: $error');
          return Icon(Icons.person, size: 60, color: Colors.grey.shade400);
        },
      );
    } catch (e) {
      // debugPrint('Error decodificando base64: $e');
      // debugPrint(
      //     'Primer 100 chars del base64: ${_imageBase64!.substring(0, math.min(100, _imageBase64!.length))}');
      return Icon(Icons.person, size: 60, color: Colors.grey.shade400);
    }
  }
}

class _ProfileCircleCameraCaptureScreen extends StatefulWidget {
  const _ProfileCircleCameraCaptureScreen({required this.circleRectNormalized});

  final Rect circleRectNormalized;

  @override
  State<_ProfileCircleCameraCaptureScreen> createState() =>
      _ProfileCircleCameraCaptureScreenState();
}

class _ProfileCircleCameraCaptureScreenState
    extends State<_ProfileCircleCameraCaptureScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No se encontro camara disponible.';
          _initializing = false;
        });
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setFlashMode(FlashMode.off);

      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo iniciar la camara: $e';
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing || !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _capturing = true;
    });

    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo tomar la foto: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              CameraPreview(_controller!),
            if (_initializing) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (!_initializing && _error == null)
              CustomPaint(
                painter: _ProfileCircleFocusPainter(
                  normalizedRect: widget.circleRectNormalized,
                ),
              ),
            if (!_initializing && _error == null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Centra tu cara dentro del circulo para recortarla automaticamente',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _capturing ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _capturing ? null : _capture,
                      icon: _capturing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt_outlined),
                      label: const Text('Capturar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCircleFocusPainter extends CustomPainter {
  const _ProfileCircleFocusPainter({required this.normalizedRect});

  final Rect normalizedRect;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromLTWH(
      size.width * normalizedRect.left,
      size.height * normalizedRect.top,
      size.width * normalizedRect.width,
      size.height * normalizedRect.height,
    );

    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()..addOval(frame);

    final overlayPath = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(overlayPath, Paint()..color = Colors.black54);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(frame, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ProfileCircleFocusPainter oldDelegate) {
    return oldDelegate.normalizedRect != normalizedRect;
  }
}
