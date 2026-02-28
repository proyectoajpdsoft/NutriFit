import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ContactNutricionistaDialog extends StatefulWidget {
  const ContactNutricionistaDialog({super.key});

  @override
  State<ContactNutricionistaDialog> createState() =>
      _ContactNutricionistaDialogState();
}

class _ContactNutricionistaDialogState
    extends State<ContactNutricionistaDialog> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  final ApiService _apiService = ApiService();
  Map<String, String> _contactInfo = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadContactInfo();
  }

  Future<void> _loadContactInfo() async {
    if (!mounted) return;

    try {
      // debugPrint('Cargando información de contacto del dietista...');

      // Cargar cada parámetro individualmente con timeout
      final email = await _getParametroSafe('nutricionista_email');
      final telefono = await _getParametroSafe('nutricionista_telefono');
      final facebook = await _getParametroSafe('nutricionista_url_facebook');
      final instagram = await _getParametroSafe('nutricionista_url_instagram');
      final youtube = await _getParametroSafe('nutricionista_url_youtube');
      final web = await _getParametroSafe('nutricionista_web');

      // debugPrint(
      //     'Parámetros cargados: email=$email, telefono=$telefono, web=$web');

      _contactInfo = {
        'email': email ?? '',
        'telefono': telefono ?? '',
        'facebook': facebook ?? '',
        'instagram': instagram ?? '',
        'youtube': youtube ?? '',
        'web': web ?? '',
      };

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      // debugPrint('Error al cargar información de contacto: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<String?> _getParametroSafe(String nombre) async {
    try {
      // debugPrint('Obteniendo parámetro: $nombre');

      final resultado = await _apiService
          .getParametro(nombre)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        // debugPrint('Timeout al obtener parámetro $nombre');
        return null;
      });

      if (resultado != null && resultado['valor'] != null) {
        final valor = resultado['valor'] as String?;
        // debugPrint('Parámetro $nombre obtenido: $valor');
        return valor;
      }

      // debugPrint('Parámetro $nombre no encontrado o sin valor');
      return null;
    } catch (e) {
      // debugPrint('Error al cargar parámetro $nombre: $e');
      return null;
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        await _externalUrlChannel.invokeMethod('openUrl', {'url': url});
        return;
      }
      rethrow;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir el enlace: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildContactItem(
      IconData icon, String label, String value, String url) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text('Contactar por $label'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _launchUrl(url),
      ),
    );
  }

  Widget _buildMoreContactsExpansion() {
    final hasMoreContacts = (_contactInfo['youtube'] ?? '').isNotEmpty ||
        (_contactInfo['facebook'] ?? '').isNotEmpty ||
        (_contactInfo['instagram'] ?? '').isNotEmpty ||
        (_contactInfo['web'] ?? '').isNotEmpty;

    if (!hasMoreContacts) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      title: const Row(
        children: [
          Icon(Icons.more_horiz, size: 20),
          SizedBox(width: 8),
          Text('Más datos de contacto'),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildContactItem(
                Icons.video_library,
                'YouTube',
                _contactInfo['youtube'] ?? '',
                _contactInfo['youtube'] ?? '',
              ),
              _buildContactItem(
                Icons.facebook,
                'Facebook',
                _contactInfo['facebook'] ?? '',
                _contactInfo['facebook'] ?? '',
              ),
              _buildContactItem(
                Icons.camera_alt,
                'Instagram',
                _contactInfo['instagram'] ?? '',
                _contactInfo['instagram'] ?? '',
              ),
              _buildContactItem(
                Icons.language,
                'Web',
                _contactInfo['web'] ?? '',
                _contactInfo['web'] ?? '',
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.info_outline,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('Servicios Personalizados')),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando información de contacto...'),
                  ],
                ),
              ),
            )
          : _hasError
              ? SizedBox(
                  height: 150,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'No se pudo cargar la información de contacto',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Para acceder a planes nutricionales y de entrenamiento personalizados, necesitas contratar los servicios profesionales del dietista online.',
                        style: TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Contactar mediante:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Email URL disabled - feature temporarily disabled
                      // _buildContactItem(
                      //   Icons.email,
                      //   'Email',
                      //   _contactInfo['email'] ?? '',
                      //   'mailto:${_contactInfo['email'] ?? ''}',
                      // ),
                      _buildContactItem(
                        Icons.email,
                        'Email',
                        _contactInfo['email'] ?? '',
                        '', // URL disabled
                      ),
                      // Phone URL disabled - feature temporarily disabled
                      // _buildContactItem(
                      //   Icons.phone,
                      //   'Teléfono',
                      //   _contactInfo['telefono'] ?? '',
                      //   'tel:${_contactInfo['telefono'] ?? ''}',
                      // ),
                      _buildContactItem(
                        Icons.phone,
                        'Teléfono',
                        _contactInfo['telefono'] ?? '',
                        '', // URL disabled
                      ),
                      // WhatsApp URL disabled - feature temporarily disabled
                      // _buildContactItem(
                      //   Icons.chat,
                      //   'WhatsApp',
                      //   _contactInfo['telefono'] ?? '',
                      //   'https://wa.me/${_contactInfo['telefono']?.replaceAll(RegExp(r'[^\d]'), '') ?? ''}',
                      // ),
                      _buildContactItem(
                        Icons.chat,
                        'WhatsApp',
                        _contactInfo['telefono'] ?? '',
                        '', // URL disabled
                      ),
                      // Telegram URL disabled - feature temporarily disabled
                      // if ((_contactInfo['telefono'] ?? '').isNotEmpty)
                      //   _buildContactItem(
                      //     Icons.send,
                      //     'Telegram',
                      //     _contactInfo['telefono'] ?? '',
                      //     'https://t.me/${_contactInfo['telefono']?.replaceAll(RegExp(r'[^\d+]'), '') ?? ''}',
                      //   ),
                      if ((_contactInfo['telefono'] ?? '').isNotEmpty)
                        _buildContactItem(
                          Icons.send,
                          'Telegram',
                          _contactInfo['telefono'] ?? '',
                          '', // URL disabled
                        ),
                      const SizedBox(height: 16),
                      // Acordeón para más datos
                      _buildMoreContactsExpansion(),
                      if (_contactInfo.values.every((v) => v.isEmpty))
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Card(
                            color: Colors.orange,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'No hay información de contacto disponible en la base de datos',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
