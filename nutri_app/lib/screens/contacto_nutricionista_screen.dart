import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nutri_app/services/api_service.dart';

class ContactoNutricionistaScreen extends StatefulWidget {
  const ContactoNutricionistaScreen({super.key});

  @override
  State<ContactoNutricionistaScreen> createState() =>
      _ContactoNutricionistaScreenState();
}

class _ContactoNutricionistaScreenState
    extends State<ContactoNutricionistaScreen> {
  final ApiService _apiService = ApiService();
  Map<String, String> _contactInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContactInfo();
  }

  Future<void> _loadContactInfo() async {
    try {
      final email = await _getParametroSafe('nutricionista_email');
      final telefono = await _getParametroSafe('nutricionista_telefono');
      final facebook = await _getParametroSafe('nutricionista_url_facebook');
      final instagram = await _getParametroSafe('nutricionista_url_instagram');
      final youtube = await _getParametroSafe('nutricionista_url_youtube');
      final web = await _getParametroSafe('nutricionista_web');
      final whatsapp = await _getParametroSafe('nutricionista_telefono');
      final telegram =
          await _getParametroSafe('nutricionista_usuario_telegram');

      _contactInfo = {
        'email': email ?? '',
        'telefono': telefono ?? '',
        'facebook': facebook ?? '',
        'instagram': instagram ?? '',
        'youtube': youtube ?? '',
        'web': web ?? '',
        'whatsapp': whatsapp ?? '',
        'telegram': telegram ?? '',
      };

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar información de contacto: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _getParametroSafe(String nombre) async {
    try {
      final resultado = await _apiService
          .getParametro(nombre)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        return null;
      });

      if (resultado != null && resultado['valor'] != null) {
        return resultado['valor'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error al cargar parámetro $nombre: $e');
      return null;
    }
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se puede abrir el enlace'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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

  Future<void> _launchPhone(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;

    try {
      final uri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se puede realizar la llamada'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al realizar la llamada: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchTelegram(String username) async {
    if (username.isEmpty) return;

    try {
      // Limpiar el username si tiene @
      final cleanUsername = username.replaceAll('@', '');
      final uri = Uri.parse('https://t.me/$cleanUsername');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Telegram no está instalado'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir Telegram: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addToContacts(String phoneNumber) async {
    try {
      // Mostrar un diálogo con instrucciones sobre cómo agregar el contacto
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dietista agregado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Para contactar por WhatsApp:'),
              const SizedBox(height: 12),
              const Text(
                'Por favor, agrega al dietista manualmente a tus contactos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Nombre: Dietista Online - NutriFit',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              Text(
                'Teléfono: $phoneNumber',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Una vez agregado, podrás enviarle mensajes por WhatsApp.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error al agregar contacto: $e');
    }
  }

  Widget _buildContactItem(
    IconData icon,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Contactar con Dietista'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Formas de contacto',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    // Email
                    _buildContactItem(
                      Icons.email,
                      'Email',
                      _contactInfo['email'] ?? '',
                      () => _launchUrl('mailto:${_contactInfo['email']}'),
                    ),
                    // Teléfono
                    _buildContactItem(
                      Icons.phone,
                      'Llamar',
                      _contactInfo['telefono'] ?? '',
                      () => _launchPhone(_contactInfo['telefono'] ?? ''),
                    ),
                    // WhatsApp
                    if ((_contactInfo['whatsapp'] ?? '').isNotEmpty)
                      Card(
                        child: ListTile(
                          leading: Icon(Icons.chat,
                              color: Theme.of(context).colorScheme.primary),
                          title: const Text('WhatsApp'),
                          subtitle: Text(_contactInfo['whatsapp'] ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Contactar por WhatsApp'),
                                content: const Text(
                                  'Para contactar al dietista por WhatsApp, '
                                  'necesitas agregarlo como contacto primero.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      _addToContacts(
                                          _contactInfo['whatsapp'] ?? '');
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Agregar a contactos'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    // Telegram
                    _buildContactItem(
                      Icons.send,
                      'Telegram',
                      _contactInfo['telegram'] ?? '',
                      () => _launchTelegram(_contactInfo['telegram'] ?? ''),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Síguenos en redes sociales',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    // YouTube
                    _buildContactItem(
                      Icons.video_library,
                      'YouTube',
                      _contactInfo['youtube'] ?? '',
                      () => _launchUrl(_contactInfo['youtube'] ?? ''),
                    ),
                    // Facebook
                    _buildContactItem(
                      Icons.facebook,
                      'Facebook',
                      _contactInfo['facebook'] ?? '',
                      () => _launchUrl(_contactInfo['facebook'] ?? ''),
                    ),
                    // Instagram
                    _buildContactItem(
                      Icons.camera_alt,
                      'Instagram',
                      _contactInfo['instagram'] ?? '',
                      () => _launchUrl(_contactInfo['instagram'] ?? ''),
                    ),
                    // Web
                    _buildContactItem(
                      Icons.language,
                      'Sitio Web',
                      _contactInfo['web'] ?? '',
                      () => _launchUrl(_contactInfo['web'] ?? ''),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
