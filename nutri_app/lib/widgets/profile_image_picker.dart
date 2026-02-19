import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
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
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  String? _imageBase64;
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
      final dimParam =
          await _apiService.getParametro('usuario_max_imagen_tamaño');
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
    try {
      // Paso 1: Seleccionar imagen
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85, // Reducir calidad para optimizar tamaño
      );

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
              'Imagen guardada correctamente (${(fileSize / 1024).toStringAsFixed(1)}KB)',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showUserFriendlyError(
          'Error al procesar la imagen',
          technicalDetails: e.toString(),
        );
      }
    }
  }

  /// Muestra un error de manera controlada según el modo debug y tipo de usuario
  void _showUserFriendlyError(String userMessage,
      {String? technicalDetails, bool showDetail = false}) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isAdmin = authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';

    String displayMessage = userMessage;

    // Solo mostrar detalles técnicos si:
    // - Estamos en modo debug Y el usuario es administrador
    // - O si showDetail es true (para mensajes específicos como tamaño de imagen)
    if (kDebugMode && isAdmin && technicalDetails != null) {
      displayMessage += '\n\nDetalles técnicos: $technicalDetails';
    } else if (!showDetail && technicalDetails != null) {
      // Para usuarios no admin o en producción, mensaje genérico
      displayMessage = 'No se ha podido completar la operación. '
          'Por favor, inténtalo de nuevo o contacta con soporte.';
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
    // En Windows, la cámara no está soportada por image_picker
    final bool isCameraAvailable =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar imagen de perfil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCameraAvailable)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndCropImage(ImageSource.camera);
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(isCameraAvailable
                  ? 'Elegir de galería'
                  : 'Seleccionar imagen'),
              onTap: () {
                Navigator.pop(context);
                _pickAndCropImage(ImageSource.gallery);
              },
            ),
            if (_imageBase64 != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar foto',
                    style: TextStyle(color: Colors.red)),
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
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            'Selecciona tu imagen de perfil',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Center(
          child: Text(
            'Máx. ${_maxImageWidth}x${_maxImageHeight}px',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
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
