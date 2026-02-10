import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    _imageBase64 = widget.initialBase64Image;
    _loadMaxImageSize();
  }

  Future<void> _loadMaxImageSize() async {
    try {
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
      // Si no existe el parámetro, usar valor por defecto
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
      final File file = File(pickedFile.path);

      // Paso 3: Verificar el tamaño de la imagen
      final int fileSize = await file.length();
      final int maxSizeBytes = _maxImageSizeKb * 1024;

      if (fileSize > maxSizeBytes) {
        if (mounted) {
          _showUserFriendlyError(
            'La imagen seleccionada supera los $_maxImageSizeKb KB (${(fileSize / 1024).toStringAsFixed(1)}KB).\n'
            'Por favor, selecciona una imagen más pequeña.',
            showDetail: true,
          );
        }
        return;
      }

      // Paso 4: Convertir a base64 y guardar
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);

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
                    child: _imageBase64 != null
                        ? Image.memory(
                            base64Decode(_imageBase64!),
                            fit: BoxFit.cover,
                          )
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
            'Máx. $_maxImageSizeKb KB',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      ],
    );
  }
}
