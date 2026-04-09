import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/screens/chat_screen.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ContactoNutricionistaScreen extends StatefulWidget {
  const ContactoNutricionistaScreen({super.key});

  @override
  State<ContactoNutricionistaScreen> createState() =>
      _ContactoNutricionistaScreenState();
}

class _ContactoNutricionistaScreenState
    extends State<ContactoNutricionistaScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
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
      // debugPrint('Error al cargar información de contacto: $e');
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
      // debugPrint('Error al cargar parámetro $nombre: $e');
      return null;
    }
  }

  String _normalizeWhatsAppPhone(String rawPhone) {
    final trimmed = rawPhone.trim();
    if (trimmed.isEmpty) return '';

    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';

    if (trimmed.startsWith('+')) {
      return '+$digits';
    }

    if (digits.startsWith('00')) {
      return '+${digits.substring(2)}';
    }

    if (digits.startsWith('34')) {
      return '+$digits';
    }

    return '+34$digits';
  }

  Future<void> _copyPhoneNumber(String phoneNumber) async {
    final normalized = phoneNumber.trim();
    if (normalized.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: normalized));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(AppLocalizations.of(context)!.contactDietitianPhoneCopied),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final normalized = _normalizeWhatsAppPhone(phoneNumber);
    if (normalized.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.contactDietitianWhatsappInvalidPhone,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final digitsOnly = normalized.replaceAll(RegExp(r'[^\d]'), '');
    final url = 'https://wa.me/$digitsOnly';

    try {
      await _launchExternalUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.contactDietitianWhatsappOpenError(
              e.toString(),
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // URL Launcher disabled - feature temporarily disabled
  // Future<void> _launchUrl(String url) async {
  //   if (url.isEmpty) return;
  //   try {
  //     final uri = Uri.parse(url);
  //     await PermissionsService.launchUrl(
  //       uri,
  //       mode: url_launcher.LaunchMode.externalApplication,
  //       context: context,
  //     );
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('No se pudo realizar la acción'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   }
  // }
  //
  // Future<void> _launchPhone(String phoneNumber) async {
  //   if (phoneNumber.isEmpty) return;
  //   try {
  //     final uri = Uri(scheme: 'tel', path: phoneNumber);
  //     await PermissionsService.launchUrl(
  //       uri,
  //       context: context,
  //     );
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Error al realizar la llamada: $e'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   }
  // }
  //
  // Future<void> _launchTelegram(String username) async {
  //   if (username.isEmpty) return;
  //   try {
  //     final cleanUsername = username.replaceAll('@', '');
  //     final uri = Uri.parse('https://t.me/$cleanUsername');
  //     await PermissionsService.launchUrl(
  //       uri,
  //       mode: url_launcher.LaunchMode.externalApplication,
  //       context: context,
  //     );
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('No se pudo abrir Telegram'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   }
  // }

  Future<void> _launchExternalUrl(String url) async {
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        await _externalUrlChannel.invokeMethod('openUrl', {'url': url});
        return;
      }
      rethrow;
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

  void _showChatGuestDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.drawerRegistrationRequiredTitle),
        content: Text(l10n.drawerRegistrationRequiredChatMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Cerrar pantalla de contacto
              Navigator.pushNamed(context, '/register');
            },
            child: Text(l10n.navStartRegistration),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.patientContactDietitianTrainer),
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
                      l10n.contactDietitianMethodsTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.mark_chat_unread_outlined,
                            color: Theme.of(context).colorScheme.primary),
                        title: Text(l10n.navChatWithDietitian),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          if (_authService.isGuestMode) {
                            _showChatGuestDialog();
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChatScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    // Email
                    _buildContactItem(
                      Icons.email,
                      l10n.contactDietitianEmailLabel,
                      _contactInfo['email'] ?? '',
                      () => _launchExternalUrl(
                        'mailto:${_contactInfo['email'] ?? ''}',
                      ),
                    ),
                    // Teléfono
                    _buildContactItem(
                      Icons.phone,
                      l10n.contactDietitianCallLabel,
                      _contactInfo['telefono'] ?? '',
                      () => _launchExternalUrl(
                        'tel:${_contactInfo['telefono'] ?? ''}',
                      ),
                    ),
                    // WhatsApp
                    if ((_contactInfo['whatsapp'] ?? '').isNotEmpty)
                      Card(
                        child: ListTile(
                          leading: Icon(Icons.chat,
                              color: Theme.of(context).colorScheme.primary),
                          title: Text(l10n.contactDietitianWhatsappLabel),
                          subtitle: Text(_contactInfo['whatsapp'] ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                titlePadding: const EdgeInsets.fromLTRB(
                                  20,
                                  18,
                                  12,
                                  0,
                                ),
                                contentPadding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  20,
                                ),
                                title: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.contactDietitianWhatsappDialogTitle,
                                        style: Theme.of(dialogContext)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      icon: const Icon(Icons.close),
                                      tooltip: l10n.commonCancel,
                                      style: IconButton.styleFrom(
                                        shape: const CircleBorder(),
                                      ),
                                    ),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.contactDietitianWhatsappDialogBody(
                                        _contactInfo['whatsapp'] ?? '',
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            _copyPhoneNumber(
                                              _contactInfo['whatsapp'] ?? '',
                                            );
                                          },
                                          child: Text(
                                            l10n.contactDietitianCopyPhone,
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.green.shade600,
                                            foregroundColor: Colors.white,
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(dialogContext);
                                            _launchWhatsApp(
                                              _contactInfo['whatsapp'] ?? '',
                                            );
                                          },
                                          child: Text(
                                            l10n.contactDietitianOpenWhatsapp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    // Telegram
                    _buildContactItem(
                      Icons.send,
                      l10n.contactDietitianTelegramLabel,
                      _contactInfo['telegram'] ?? '',
                      () => _launchExternalUrl(
                        'https://t.me/${(_contactInfo['telegram'] ?? '').replaceAll('@', '')}',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.contactDietitianSocialTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    // YouTube
                    _buildContactItem(
                      Icons.video_library,
                      'YouTube',
                      _contactInfo['youtube'] ?? '',
                      () => _launchExternalUrl(_contactInfo['youtube'] ?? ''),
                    ),
                    // Facebook
                    _buildContactItem(
                      Icons.facebook,
                      'Facebook',
                      _contactInfo['facebook'] ?? '',
                      () => _launchExternalUrl(_contactInfo['facebook'] ?? ''),
                    ),
                    // Instagram
                    _buildContactItem(
                      Icons.camera_alt,
                      'Instagram',
                      _contactInfo['instagram'] ?? '',
                      () => _launchExternalUrl(_contactInfo['instagram'] ?? ''),
                    ),
                    // Web
                    _buildContactItem(
                      Icons.language,
                      l10n.contactDietitianWebsiteLabel,
                      _contactInfo['web'] ?? '',
                      () => _launchExternalUrl(_contactInfo['web'] ?? ''),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
