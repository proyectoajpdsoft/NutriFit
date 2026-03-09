import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:nutri_app/models/session.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/widgets/profile_image_picker.dart';
import 'package:nutri_app/screens/register_screen.dart';
import 'package:nutri_app/screens/contacto_nutricionista_screen.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:provider/provider.dart';

class PacienteProfileEditScreen extends StatefulWidget {
  final Usuario? usuario;

  const PacienteProfileEditScreen({super.key, this.usuario});

  @override
  _PacienteProfileEditScreenState createState() =>
      _PacienteProfileEditScreenState();
}

class _PacienteProfileEditScreenState extends State<PacienteProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final TextEditingController _nickController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _edadController = TextEditingController();
  final TextEditingController _alturaController = TextEditingController();
  int _maxImageWidth = 400;
  int _maxImageHeight = 400;

  // Controladores
  late String _nick = '';
  late String _newPassword = '';
  late String _confirmPassword = '';
  String? _imageBase64;
  Usuario? _fullUsuario;
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _loadingTwoFactor = false;
  bool _twoFactorEnabled = false;
  bool _loadingEmailVerification = false;
  bool _emailVerified = false;
  String? _emailVerificationDate;
  bool _emailVerificationCardExpanded = false;
  bool _twoFactorCardExpanded = false;
  bool _passwordCardExpanded = false;
  bool _mvpCardExpanded = false;
  bool _lopdCardExpanded = false;

  // Estado de validación de contraseña
  late ConfigService _configService;
  bool _showPasswordRequirements = false;

  @override
  void initState() {
    super.initState();
    _configService = context.read<ConfigService>();
    _loadMaxImageDimensions();
    _loadUserData();
    _loadTwoFactorStatus();
    _loadEmailVerificationStatus();
  }

  Future<void> _loadEmailVerificationStatus() async {
    if (!mounted) return;
    setState(() {
      _loadingEmailVerification = true;
    });

    try {
      final status = await _apiService.getEmailVerificationStatus();
      if (!mounted) return;
      setState(() {
        _emailVerified = status['email_verified'] == true;
        _emailVerificationDate = status['verification_date']?.toString();
      });
    } catch (_) {
      // Mantener estado por defecto si falla para no bloquear la edicion de perfil.
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingEmailVerification = false;
      });
    }
  }

  Future<void> _sendEmailVerificationCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Primero indica un email en tu perfil y guarda cambios.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _loadingEmailVerification = true;
    });

    try {
      final resp = await _apiService.sendEmailVerificationCode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((resp['message'] ?? 'Codigo enviado.').toString()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingEmailVerification = false;
      });
    }
  }

  Future<void> _verifyEmailCodeDialog() async {
    final codeController = TextEditingController();
    final email = _emailController.text.trim();
    final targetEmail =
        email.isNotEmpty ? email : 'tu direccion de correo electronico';
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verificar email'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Introduce el código de 10 dígitos que ha debido llegarte a tu dirección de correo electrónico $targetEmail y pulsa en "Verificar".',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Código de 10 dígitos',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = codeController.text.trim();
              if (value.length != 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El código debe tener 10 dígitos.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Verificar'),
          ),
        ],
      ),
    );
    codeController.dispose();

    if (code == null || code.isEmpty) {
      return;
    }

    setState(() {
      _loadingEmailVerification = true;
    });

    try {
      final resp = await _apiService.verifyEmailCode(code: code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((resp['message'] ?? 'Email verificado.').toString()),
          backgroundColor: Colors.green,
        ),
      );
      await _loadEmailVerificationStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingEmailVerification = false;
      });
    }
  }

  Future<void> _loadTwoFactorStatus() async {
    if (!mounted) return;
    setState(() {
      _loadingTwoFactor = true;
    });

    try {
      final status = await _apiService.getTwoFactorStatus();
      if (!mounted) return;
      setState(() {
        _twoFactorEnabled = status['enabled'] == true;
      });
    } catch (_) {
      // Si falla la consulta, mantenemos el estado actual sin bloquear la pantalla.
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingTwoFactor = false;
      });
    }
  }

  Future<void> _activarTwoFactor() async {
    if (!mounted) return;
    setState(() {
      _loadingTwoFactor = true;
    });

    try {
      final setup = await _apiService.setupTwoFactor();
      final secret = (setup['secret'] ?? '').toString().trim();
      final manualKey = (setup['manual_key'] ?? '').toString().trim();
      final otpauthUrl = (setup['otpauth_url'] ?? '').toString().trim();

      if (!mounted) return;

      final codeController = TextEditingController();
      final code = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Activar doble factor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.35),
                    ),
                  ),
                  child: const Text(
                    'El doble factor (2FA) añade una capa extra de seguridad: además de tu contraseña, se solicita un código temporal de tu app de autenticación.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '1) Abre tu app de autenticación (Google Authenticator, Microsoft Authenticator, Authy, etc.) y añade una cuenta.',
                ),
                const SizedBox(height: 8),
                const Text(
                  '2) Copia esta clave secreta (puedes usar el botón "Copiar clave"):',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                SelectableText(manualKey.isNotEmpty ? manualKey : secret),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: manualKey.isNotEmpty ? manualKey : secret,
                          ),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Clave copiada al portapapeles'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar clave'),
                    ),
                    if (otpauthUrl.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: otpauthUrl),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('URL otpauth copiada'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('Copiar URL'),
                      ),
                  ],
                ),
                if (otpauthUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.35),
                      ),
                    ),
                    child: const Text(
                      'La opción "Copiar URL" copia un enlace otpauth con toda la configuración 2FA para importarla en apps compatibles. Si tu app no permite importación por enlace, usa "Copiar clave".',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  '3) Introduce el código de 6 dígitos que te aparecerá en la app de autenticación para confirmar:',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Código 2FA',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = codeController.text.trim();
                if (value.length != 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El código debe tener 6 dígitos.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, value);
              },
              child: const Text('Activar'),
            ),
          ],
        ),
      );
      codeController.dispose();

      if (code == null || code.isEmpty) {
        return;
      }

      await _apiService.enableTwoFactor(secret: secret, code: code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doble factor activado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadTwoFactorStatus();
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              errorMessage.isEmpty ? 'No se pudo activar 2FA.' : errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingTwoFactor = false;
      });
    }
  }

  Future<void> _desactivarTwoFactor() async {
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar doble factor (2FA)'),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Código actual de 6 dígitos',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = codeController.text.trim();
              if (value.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El código debe tener 6 dígitos.'),
                  ),
                );
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    codeController.dispose();

    if (code == null || code.isEmpty) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _loadingTwoFactor = true;
    });

    try {
      await _apiService.disableTwoFactor(code: code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doble factor desactivado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadTwoFactorStatus();
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage.isEmpty
              ? 'No se pudo desactivar 2FA.'
              : errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingTwoFactor = false;
      });
    }
  }

  Future<void> _quitarConfianzaDispositivo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar confianza del dispositivo'),
        content: const Text(
          'En este dispositivo se volverá a solicitar el código 2FA en el próximo inicio de sesión. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Quitar confianza'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await context.read<AuthService>().clearTrustedDeviceForCurrentUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confianza del dispositivo eliminada.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo quitar la confianza del dispositivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showMvpInfoDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cálculo MVP y fórmulas'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '¿Qué es el MVP?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'MVP es un conjunto mínimo de indicadores antropométricos para ayudarte a monitorizar de forma sencilla tu evolución de salud: IMC, cintura/altura y cintura/cadera.',
                ),
                const SizedBox(height: 10),
                const Text(
                  'Fórmulas utilizadas y su origen:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text('1) IMC = peso (kg) / altura (m)²'),
                const Text('Origen: OMS (clasificación IMC en adultos).'),
                const SizedBox(height: 10),
                const Text('2) Cintura/Altura = cintura (cm) / altura (cm)'),
                const Text('Origen: índice Waist-to-Height Ratio.'),
                const SizedBox(height: 10),
                const Text('3) Cintura/Cadera = cintura (cm) / cadera (cm)'),
                const Text(
                    'Origen: Waist-Hip Ratio (OMS, obesidad abdominal).'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Colors.orange.shade800,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Aviso importante',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Estos cálculos y clasificaciones son orientativos. Para una valoración personalizada, consulta siempre con un profesional médico, dietista-nutricionista o entrenador personal.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ContactoNutricionistaScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.support_agent, size: 18),
                          label: const Text('Contactar con dietista'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleCard({
    required Widget title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: title),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTwoFactorCard() {
    final statusColor = _twoFactorEnabled ? Colors.green : Colors.red;
    final statusLabel = _twoFactorEnabled ? 'activado' : 'desactivado';

    return _buildCollapsibleCard(
      expanded: _twoFactorCardExpanded,
      onToggle: () {
        setState(() {
          _twoFactorCardExpanded = !_twoFactorCardExpanded;
        });
      },
      title: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          children: [
            const TextSpan(
              text: 'Doble factor (',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: statusLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
            const TextSpan(
              text: ')',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Protege tu cuenta solicitando un código de verificación adicional al iniciar sesión.',
            style: TextStyle(fontSize: 13),
          ),
          if (_loadingTwoFactor) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!_twoFactorEnabled)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loadingTwoFactor ? null : _activarTwoFactor,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Activar 2FA'),
                  ),
                ),
              if (_twoFactorEnabled)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadingTwoFactor ? null : _desactivarTwoFactor,
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('Desactivar 2FA'),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Actualizar estado',
                onPressed: _loadingTwoFactor ? null : _loadTwoFactorStatus,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loadingTwoFactor ? null : _quitarConfianzaDispositivo,
              icon: const Icon(Icons.phonelink_erase_outlined),
              label: const Text('Quitar confianza en este dispositivo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailVerificationCard() {
    final statusColor = _emailVerified ? Colors.green : Colors.orange;
    final statusLabel = _emailVerified ? 'verificado' : 'sin verificar';

    return _buildCollapsibleCard(
      expanded: _emailVerificationCardExpanded,
      onToggle: () {
        setState(() {
          _emailVerificationCardExpanded = !_emailVerificationCardExpanded;
        });
      },
      title: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          children: [
            const TextSpan(
              text: 'Email (',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: statusLabel,
              style: TextStyle(fontWeight: FontWeight.w700, color: statusColor),
            ),
            const TextSpan(
              text: ')',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verifica tu email para poder recuperar el acceso por correo si olvidas tu contrasena.',
            style: TextStyle(fontSize: 13),
          ),
          if (_emailVerified && _emailVerificationDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Fecha de verificacion: $_emailVerificationDate',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (_loadingEmailVerification) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadingEmailVerification
                      ? null
                      : _sendEmailVerificationCode,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Enviar codigo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _loadingEmailVerification ? null : _verifyEmailCodeDialog,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Validar codigo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loadingEmailVerification
                  ? null
                  : _loadEmailVerificationStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar estado'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMaxImageDimensions() async {
    try {
      final dimParam =
          await _apiService.getParametro('usuario_max_imagen_tamaño');
      if (dimParam != null && mounted) {
        final width = int.tryParse(dimParam['valor'] ?? '400');
        final height = int.tryParse(dimParam['valor2'] ?? '400');
        if (width != null && height != null) {
          setState(() {
            _maxImageWidth = width;
            _maxImageHeight = height;
          });
        }
      }
    } catch (e) {
      // Si no existe el parámetro, mantener los valores por defecto
    }
  }

  void _markDirty() {
    if (_hasChanges) return;
    setState(() {
      _hasChanges = true;
    });
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges) return true;
    return showUnsavedChangesDialog(context);
  }

  Future<void> _handleBack() async {
    if (await _confirmDiscardChanges()) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _nickController.dispose();
    _emailController.dispose();
    _edadController.dispose();
    _alturaController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.usuario != null) {
        // Si el nick está vacío, necesitamos cargar el usuario completo desde el API
        if (widget.usuario!.nick.isEmpty && widget.usuario!.codigo > 0) {
          try {
            // Intentar cargar el usuario específico desde el servidor
            final usuario =
                await _apiService.getUsuario(widget.usuario!.codigo);
            setState(() {
              _fullUsuario = usuario;
              _nick = usuario.nick;
              _nickController.text = usuario.nick;
              _emailController.text = usuario.email ?? '';
              _edadController.text = usuario.edad?.toString() ?? '';
              _alturaController.text = usuario.altura?.toString() ?? '';
              _imageBase64 = usuario.imgPerfil;
              _isLoading = false;
            });
          } catch (e) {
            // Si falla (permisos), usar datos locales
            setState(() {
              _fullUsuario = widget.usuario;
              _nick = widget.usuario!.nick;
              _nickController.text = widget.usuario!.nick;
              _emailController.text = widget.usuario!.email ?? '';
              _edadController.text = widget.usuario!.edad?.toString() ?? '';
              _alturaController.text = widget.usuario!.altura?.toString() ?? '';
              _imageBase64 = widget.usuario!.imgPerfil;
              _isLoading = false;
            });
          }
        } else {
          // Usar los datos del usuario que ya tenemos
          setState(() {
            _fullUsuario = widget.usuario;
            _nick = widget.usuario!.nick;
            _nickController.text = widget.usuario!.nick;
            _emailController.text = widget.usuario!.email ?? '';
            _edadController.text = widget.usuario!.edad?.toString() ?? '';
            _alturaController.text = widget.usuario!.altura?.toString() ?? '';
            _imageBase64 = widget.usuario!.imgPerfil;
            _isLoading = false;
          });
        }
      } else {
        // Nuevo usuario - no hay datos que cargar
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos del usuario: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleImageChanged(String? newImage) {
    if (_imageBase64 == newImage) {
      return;
    }

    setState(() {
      _imageBase64 = newImage;
      _hasChanges = true;
    });
  }

  String? _getPasswordValidationError(String password) {
    if (password.isEmpty) return null;

    return _configService.validatePassword(password);
  }

  Widget _buildPasswordRequirementsList() {
    final minLength = _configService.passwordMinLength;
    final requireUpperLower = _configService.passwordRequireUpperLower;
    final requireNumbers = _configService.passwordRequireNumbers;
    final requireSpecialChars = _configService.passwordRequireSpecialChars;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requisitos de contraseña:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 8),
          if (minLength > 0)
            _buildRequirement('Mínimo $minLength caracteres',
                _newPassword.length >= minLength),
          if (requireUpperLower)
            _buildRequirement(
                'Mayúsculas y minúsculas',
                _newPassword.contains(RegExp(r'[A-Z]')) &&
                    _newPassword.contains(RegExp(r'[a-z]'))),
          if (requireNumbers)
            _buildRequirement(
                'Contener números', _newPassword.contains(RegExp(r'[0-9]'))),
          if (requireSpecialChars)
            _buildRequirement('Caracteres especiales (*,.+-#\$?¿!¡_()/\\%&)',
                _newPassword.contains(RegExp(r'[*,.+\-#$?¿!¡_()\/\\%&]'))),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Redimensiona la imagen de perfil si supera las dimensiones máximas
  Future<void> _resizeImageIfNeeded() async {
    if (_imageBase64 == null || _imageBase64!.isEmpty) {
      return;
    }

    try {
      // Decodificar base64 a bytes
      final imageBytes = base64Decode(_imageBase64!);
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        return;
      }

      // Verificar si la imagen supera los límites
      if (image.width <= _maxImageWidth && image.height <= _maxImageHeight) {
        return; // La imagen ya está dentro de los límites
      }

      // Calcular el factor de escala manteniendo la relación de aspecto
      double scale = 1.0;

      if (image.width > _maxImageWidth) {
        scale = _maxImageWidth / image.width;
      }

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

      // Convertir a PNG y luego a base64
      final resizedBytes = img.encodePng(resizedImage);
      _imageBase64 = base64Encode(resizedBytes);
    } catch (e) {
      // Si hay error al redimensionar, mantener la imagen original
      // debugPrint('Error redimensionando imagen: $e');
    }
  }

  Future<bool> _confirmLopdDeletionStep1() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Derecho de supresión de datos (LOPDGDD/RGPD)'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Puedes solicitar la eliminación de tus datos personales conforme al derecho de supresión (art. 17 RGPD y LOPDGDD en España).',
              ),
              SizedBox(height: 10),
              Text(
                'Si continúas, se eliminarán tu usuario y todos los datos asociados: inicios de sesión, chats con el dietista, control de peso, lista de la compra, actividades, tareas, entrenamientos, ejercicios e imágenes.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 10),
              Text(
                'Esta acción es irreversible y cerrará tu sesión.',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<bool> _confirmLopdDeletionStep2() async {
    String confirmationText = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmación final'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para confirmar, escribe ELIMINAR en mayúsculas:',
            ),
            const SizedBox(height: 10),
            TextField(
              autofocus: true,
              onChanged: (value) {
                confirmationText = value;
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'ELIMINAR',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final valid = confirmationText.trim() == 'ELIMINAR';
              if (!valid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Debes escribir ELIMINAR para confirmar.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Eliminar mis datos'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deleteMyAccountLopd() async {
    final confirmedStep1 = await _confirmLopdDeletionStep1();
    if (!confirmedStep1 || !mounted) {
      return;
    }

    final confirmedStep2 = await _confirmLopdDeletionStep2();
    if (!confirmedStep2 || !mounted) {
      return;
    }

    try {
      final result = await _apiService.deleteCurrentUserWithDetails();
      final deletedCounts = result['deleted_counts'] is Map
          ? Map<String, dynamic>.from(result['deleted_counts'] as Map)
          : <String, dynamic>{};
      final totalDeleted = deletedCounts.values.fold<int>(
        0,
        (sum, value) => sum + (int.tryParse(value.toString()) ?? 0),
      );

      FocusManager.instance.primaryFocus?.unfocus();
      if (!mounted) return;
      await context.read<AuthService>().logout();
      if (!mounted) return;

      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('login', (_) => false);
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se ha podido realizar el proceso. Revise la conexión a Internet',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage.isEmpty
                ? 'No se pudo eliminar la cuenta.'
                : errorMessage,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Redimensionar la imagen si excede los límites
      await _resizeImageIfNeeded();

      // Validar que las contraseñas coincidan si se proporciona una nueva
      if (_newPassword.isNotEmpty && _newPassword != _confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Las contraseñas no coinciden'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validar que el nick no exista (si ha cambiado)
      if (_nick != _fullUsuario?.nick) {
        try {
          final usuarios = await _apiService.getUsuarios();
          final nickExists = usuarios.any((u) =>
              u.nick.toLowerCase() == _nick.toLowerCase() &&
              u.codigo != _fullUsuario?.codigo);

          if (nickExists) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Este nick ya está en uso. Por favor, elija otro.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        } on SocketException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se ha podido realizar el proceso. Revise la conexión a Internet',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al validar el nick: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      Map<String, dynamic> usuarioData = {
        'codigo': _fullUsuario?.codigo.toString(),
        'nick': _nick,
        'nombre': _fullUsuario?.nombre,
        'email': _emailController.text.trim(),
        'tipo': _fullUsuario?.tipo,
        'codigo_paciente': _fullUsuario?.codigoPaciente,
        'edad': int.tryParse(_edadController.text.trim()),
        'altura': int.tryParse(_alturaController.text.trim()),
        'activo': _fullUsuario?.activo,
        'accesoweb': _fullUsuario?.accesoweb,
        'administrador': _fullUsuario?.administrador,
        'img_perfil': _imageBase64,
      };

      if (usuarioData['edad'] == null || (usuarioData['edad'] as int) <= 0) {
        usuarioData['edad'] = null;
      }
      if (usuarioData['altura'] == null ||
          (usuarioData['altura'] as int) <= 0) {
        usuarioData['altura'] = null;
      }

      // Solo incluir contraseña si se proporciona una nueva
      if (_newPassword.isNotEmpty) {
        usuarioData['contrasena'] = _newPassword;
      }

      try {
        final success = await _apiService.updateUsuario(usuarioData);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Perfil actualizado correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          }
        }
      } on SocketException {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se ha podido realizar el proceso. Revise la conexión a Internet',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final errorMessage = e.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar datos del usuario. $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Editar Perfil'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final isGuest = authService.isGuestMode;

    if (isGuest) {
      return const RegisterScreen();
    }

    return _buildEditScreen();
  }

  /// Construye la pantalla de edición para usuarios registrados
  Widget _buildEditScreen() {
    final bottomSafeInset = MediaQuery.of(context).padding.bottom;

    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: const Text('Editar Perfil'),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: _submitForm)
          ],
        ),
        body: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Perfil'),
                  Tab(text: 'Inicios de sesión'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        16.0,
                        16.0,
                        16.0,
                        32.0 + bottomSafeInset,
                      ),
                      child: Form(
                        key: _formKey,
                        onChanged: _markDirty,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar de perfil
                            Center(
                              child: ProfileImagePicker(
                                initialBase64Image: _imageBase64,
                                onImageChanged: _handleImageChanged,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Nick
                            TextFormField(
                              controller: _nickController,
                              decoration: const InputDecoration(
                                labelText: 'Nick / Usuario',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                      ? 'El nick es obligatorio'
                                      : null,
                              onSaved: (value) => _nick = value!,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email (opcional)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final v = (value ?? '').trim();
                                if (v.isEmpty) return null;
                                final emailRegex =
                                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                                if (!emailRegex.hasMatch(v)) {
                                  return 'Email no válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            _buildEmailVerificationCard(),
                            const SizedBox(height: 16),

                            _buildTwoFactorCard(),
                            const SizedBox(height: 16),

                            _buildCollapsibleCard(
                              expanded: _mvpCardExpanded,
                              onToggle: () {
                                setState(() {
                                  _mvpCardExpanded = !_mvpCardExpanded;
                                });
                              },
                              title: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Datos adicionales (MVP / IMC)',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Información MVP/IMC',
                                    onPressed: _showMvpInfoDialog,
                                    icon: const Icon(Icons.info_outline),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.orange.shade200),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.orange.shade800,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Para obtener el IMC, MVP y recomendaciones, completa Edad y Altura.',
                                            style: TextStyle(
                                              color: Colors.orange.shade900,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _edadController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Edad',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return null;
                                      }
                                      final parsed =
                                          int.tryParse(value!.trim());
                                      if (parsed == null ||
                                          parsed <= 0 ||
                                          parsed > 120) {
                                        return 'Edad no válida';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _alturaController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Altura (cm)',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return null;
                                      }
                                      final parsed =
                                          int.tryParse(value!.trim());
                                      if (parsed == null ||
                                          parsed < 80 ||
                                          parsed > 250) {
                                        return 'Altura no válida';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildCollapsibleCard(
                              expanded: _passwordCardExpanded,
                              onToggle: () {
                                setState(() {
                                  _passwordCardExpanded =
                                      !_passwordCardExpanded;
                                });
                              },
                              title: const Text(
                                'Cambio de contraseña',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dejar en blanco para no cambiar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Contraseña',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return null;
                                      }
                                      final error =
                                          _getPasswordValidationError(value);
                                      return error;
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        _newPassword = value;
                                        if (value.isNotEmpty &&
                                            !_showPasswordRequirements) {
                                          _showPasswordRequirements = true;
                                        } else if (value.isEmpty) {
                                          _showPasswordRequirements = false;
                                        }
                                      });
                                    },
                                    onSaved: (value) =>
                                        _newPassword = value ?? '',
                                  ),
                                  const SizedBox(height: 16),
                                  if (_showPasswordRequirements) ...[
                                    _buildPasswordRequirementsList(),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_newPassword.isNotEmpty)
                                    TextFormField(
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Confirmar Contraseña',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (_newPassword.isNotEmpty &&
                                            (value == null || value.isEmpty)) {
                                          return 'Debes confirmar la contraseña';
                                        }
                                        if (value != null &&
                                            value != _newPassword) {
                                          return 'Las contraseñas no coinciden';
                                        }
                                        return null;
                                      },
                                      onSaved: (value) =>
                                          _confirmPassword = value ?? '',
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildCollapsibleCard(
                              expanded: _lopdCardExpanded,
                              onToggle: () {
                                setState(() {
                                  _lopdCardExpanded = !_lopdCardExpanded;
                                });
                              },
                              title: const Text(
                                'Eliminación de usuario',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red,
                                ),
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.red.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.privacy_tip_outlined,
                                          color: Colors.red.shade700,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Tienes derecho a solicitar la eliminación completa de tus datos personales. Esta acción borrará tu cuenta y los registros asociados, incluyendo inicios de sesión, chats con el dietista, control de peso, lista de la compra, actividades, tareas, entrenamientos, ejercicios e imágenes.',
                                            style: TextStyle(
                                              color: Colors.red.shade900,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: _deleteMyAccountLopd,
                                        icon: const Icon(Icons.delete_forever),
                                        label: const Text(
                                            'Eliminar todos mis datos'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Botón de guardar
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitForm,
                                child: const Text('Guardar Cambios'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final authService = Provider.of<AuthService>(
                                      context,
                                      listen: false);
                                  await authService.logout();
                                  if (mounted) {
                                    Navigator.of(context)
                                        .pushReplacementNamed('login');
                                  }
                                },
                                icon: const Icon(Icons.logout),
                                label: const Text('Cerrar sesión'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const _UserSessionsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserSessionsTab extends StatefulWidget {
  const _UserSessionsTab();

  @override
  State<_UserSessionsTab> createState() => _UserSessionsTabState();
}

class _UserSessionsTabState extends State<_UserSessionsTab> {
  late Future<SessionResponse> _sessionDataFuture;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  void _loadSessionData() {
    final apiService = context.read<ApiService>();
    final authService = context.read<AuthService>();
    final usuarioCode = authService.userCode;

    if (usuarioCode != null && usuarioCode.isNotEmpty) {
      _sessionDataFuture = apiService.getSessionData(usuarioCode);
    } else {
      _sessionDataFuture = Future.value(
        SessionResponse(
          ultimasSesionesExitosas: [],
          ultimosIntentosFallidos: [],
          totalSesiones: 0,
          totalExitosas: 0,
          totalFallidas: 0,
          todasSesiones: [],
        ),
      );
    }
  }

  IconData _getDeviceIcon(String? tipo) {
    switch (tipo) {
      case 'Android':
        return Icons.android;
      case 'iOS':
        return Icons.apple;
      case 'Web':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }

  Widget _buildSessionInfo(SessionLog sesion) {
    final fechaFormato = sesion.fecha;
    final horaFormato = sesion.hora ?? 'N/A';
    final tipoDispositivo = sesion.tipo ?? 'N/A';
    final ipPublica = sesion.ipPublica ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Text(
              'Fecha: $fechaFormato',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.access_time, size: 18),
            const SizedBox(width: 8),
            Text(
              'Hora: $horaFormato',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(_getDeviceIcon(sesion.tipo), size: 18),
            const SizedBox(width: 8),
            Text(
              'Dispositivo: $tipoDispositivo',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 16),
        const Text(
          'Dirección IP:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.public, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pública: $ipPublica',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final usuarioCode = authService.userCode;

    if (usuarioCode == null || usuarioCode.isEmpty) {
      return const Center(
        child: Text('Código de usuario no disponible'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _loadSessionData();
        });
        await _sessionDataFuture;
      },
      child: FutureBuilder<SessionResponse>(
        future: _sessionDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      onPressed: () {
                        setState(() {
                          _loadSessionData();
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('No hay datos de sesión disponibles'),
            );
          }

          final sessionData = snapshot.data!;
          final ultimasSesionesExitosas = sessionData.ultimasSesionesExitosas;
          final ultimosIntentosFallidos = sessionData.ultimosIntentosFallidos;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.security, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Últimos Inicios de Sesión Exitosos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (ultimasSesionesExitosas.isNotEmpty) ...[
                        for (int i = 0;
                            i < ultimasSesionesExitosas.length;
                            i++) ...[
                          if (i > 0) const Divider(height: 24),
                          Text(
                            i == 0 ? 'Sesión actual:' : 'Sesión anterior:',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSessionInfo(ultimasSesionesExitosas[i]),
                        ],
                      ] else
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('No hay sesiones exitosas registradas'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (ultimosIntentosFallidos.isNotEmpty)
                Card(
                  elevation: 2,
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Últimos Intentos de Acceso Fallidos',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (int i = 0;
                            i < ultimosIntentosFallidos.length;
                            i++) ...[
                          if (i > 0) const Divider(height: 24),
                          Text(
                            'Intento ${i + 1}:',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSessionInfo(ultimosIntentosFallidos[i]),
                        ],
                      ],
                    ),
                  ),
                )
              else if (ultimasSesionesExitosas.isNotEmpty)
                Card(
                  elevation: 2,
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'No hay intentos fallidos registrados.',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Card(
                elevation: 1,
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estadísticas de Sesiones',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.analytics,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Total de sesiones: ${sessionData.totalSesiones}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Intentos exitosos: ${sessionData.totalExitosas}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.error, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Intentos fallidos: ${sessionData.totalFallidas}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          );
        },
      ),
    );
  }
}
