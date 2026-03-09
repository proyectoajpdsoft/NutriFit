import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/exceptions/auth_exceptions.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/constants/app_constants.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _TwoFactorDialogResult {
  final String code;
  final bool trustThisDevice;

  const _TwoFactorDialogResult({
    required this.code,
    required this.trustThisDevice,
  });
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final _nickController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;

  bool _isNetworkError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('sockete') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('no address associated with hostname') ||
        normalized.contains('connection refused') ||
        normalized.contains('connection timed out') ||
        normalized.contains('timed out') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('handshakeexception') ||
        normalized.contains('connection reset');
  }

  String _buildLoginErrorMessage(dynamic error) {
    if (error is TwoFactorRequiredException) {
      return error.message;
    }

    final errorMessage = error.toString().replaceFirst('Exception: ', '');
    if (_isNetworkError(errorMessage)) {
      return 'Hay algun problema con la conexión a Internet o la app no tiene permisos para conectarse.';
    }
    if (errorMessage.contains('Cuenta temporalmente bloqueada')) {
      return errorMessage;
    }
    return errorMessage.isNotEmpty
        ? errorMessage
        : 'No se pudo completar el inicio de sesión. Inténtalo de nuevo.';
  }

  String _buildGuestErrorMessage(dynamic error) {
    final errorMessage = error.toString().replaceFirst('Exception: ', '');
    if (_isNetworkError(errorMessage)) {
      return 'Hay algun problema con la conexión a Internet o la app no tiene permisos para conectarse.';
    }
    return 'No se pudo acceder como invitado. Inténtalo de nuevo.';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      String? userType;
      try {
        userType = await authService.login(
          _nickController.text,
          _passwordController.text,
        );
      } on TwoFactorRequiredException {
        if (!mounted) return;
        final otpResult = await _showTwoFactorDialog();
        if (otpResult == null || otpResult.code.isEmpty) {
          throw Exception('Inicio de sesión cancelado por el usuario.');
        }
        userType = await authService.login(
          _nickController.text,
          _passwordController.text,
          twoFactorCode: otpResult.code,
          trustThisDevice: otpResult.trustThisDevice,
        );
      }

      await context.read<ConfigService>().refreshDebugModeFromPreferences();

      // Si el login es exitoso, userType no será null
      if (userType != null && mounted) {
        // Limpiar los campos de contraseña por seguridad
        _passwordController.clear();

        // Navega a la pantalla correcta según el tipo de usuario
        if (userType == 'Paciente' || userType == 'Usuario') {
          Navigator.of(context).pushReplacementNamed('paciente_home');
        } else if (userType == 'Nutricionista' || userType == 'Administrador') {
          Navigator.of(context).pushReplacementNamed('home');
        } else {
          // Tipo de usuario desconocido - logout y mostrar error
          await authService.logout();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tipo de usuario no reconocido'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      // Asegurar que el usuario está deslogueado en caso de error
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();

      final displayMessage = _buildLoginErrorMessage(e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<_TwoFactorDialogResult?> _showTwoFactorDialog() async {
    final codeController = TextEditingController();
    bool trustThisDevice = false;

    return showDialog<_TwoFactorDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Verificación 2FA'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Introduce el código de 6 dígitos de tu aplicación TOTP.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Código 2FA',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  onSubmitted: (_) {
                    final value = codeController.text.trim();
                    if (value.length == 6) {
                      Navigator.of(dialogContext).pop(
                        _TwoFactorDialogResult(
                          code: value,
                          trustThisDevice: trustThisDevice,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: trustThisDevice,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) {
                    setDialogState(() {
                      trustThisDevice = value ?? false;
                    });
                  },
                  title: const Text('Confiar en este dispositivo'),
                  subtitle: const Text(
                    'No se volverá a solicitar 2FA en este dispositivo hasta quitar la confianza desde el perfil.',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
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
                  Navigator.of(dialogContext).pop(
                    _TwoFactorDialogResult(
                      code: value,
                      trustThisDevice: trustThisDevice,
                    ),
                  );
                },
                child: const Text('Validar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitAsGuest() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.loginAsGuest();
      await context.read<ConfigService>().refreshDebugModeFromPreferences();

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('paciente_home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_buildGuestErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    final normalized = value?.toString().trim().toUpperCase() ?? '';
    return normalized == '1' ||
        normalized == 'S' ||
        normalized == 'SI' ||
        normalized == 'SÍ' ||
        normalized == 'TRUE' ||
        normalized == 'YES' ||
        normalized == 'Y';
  }

  Map<String, dynamic> _normalizeRecoveryPasswordPolicy(dynamic rawPolicy) {
    final map = rawPolicy is Map<String, dynamic>
        ? rawPolicy
        : rawPolicy is Map
            ? rawPolicy.cast<String, dynamic>()
            : <String, dynamic>{};

    final minLength = int.tryParse(map['min_length']?.toString() ?? '') ?? 8;
    return {
      'min_length': minLength > 0 ? minLength : 8,
      'require_upper_lower': _asBool(map['require_upper_lower']),
      'require_numbers': _asBool(map['require_numbers']),
      'require_special_chars': _asBool(map['require_special_chars']),
    };
  }

  String? _validateRecoveryPassword(
    String password,
    Map<String, dynamic> policy,
  ) {
    final minLength = policy['min_length'] as int? ?? 8;
    if (password.length < minLength) {
      return 'La nueva contraseña debe tener al menos $minLength caracteres.';
    }

    if (policy['require_upper_lower'] == true) {
      if (!password.contains(RegExp(r'[A-Z]'))) {
        return 'La nueva contraseña debe contener al menos una letra mayúscula.';
      }
      if (!password.contains(RegExp(r'[a-z]'))) {
        return 'La nueva contraseña debe contener al menos una letra minúscula.';
      }
    }

    if (policy['require_numbers'] == true &&
        !password.contains(RegExp(r'[0-9]'))) {
      return 'La nueva contraseña debe contener al menos un número.';
    }

    if (policy['require_special_chars'] == true &&
        !password.contains(RegExp(r'[*,.+\-#$?¿!¡_()\/\\%&]'))) {
      return 'La nueva contraseña debe contener al menos un carácter especial (* , . + - # \$ ? ¿ ! ¡ _ ( ) / \\ % &).';
    }

    return null;
  }

  String _buildRecoveryPasswordHint(Map<String, dynamic> policy) {
    final parts = <String>[
      'Mínimo ${policy['min_length']} caracteres',
    ];
    if (policy['require_upper_lower'] == true) {
      parts.add('mayúsculas y minúsculas');
    }
    if (policy['require_numbers'] == true) {
      parts.add('números');
    }
    if (policy['require_special_chars'] == true) {
      parts.add('carácter especial');
    }
    return 'Requisitos: ${parts.join(', ')}.';
  }

  Future<void> _startRecoveryFlow() async {
    final identifierController = TextEditingController(
      text: _nickController.text.trim(),
    );

    final identifier = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recuperar acceso'),
        content: TextField(
          controller: identifierController,
          decoration: const InputDecoration(
            labelText: 'Usuario o email',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = identifierController.text.trim();
              if (value.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Introduce usuario o email.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    identifierController.dispose();
    if (identifier == null || identifier.isEmpty) {
      return;
    }

    try {
      final options =
          await _apiService.getPasswordRecoveryOptions(identifier: identifier);
      final passwordPolicy =
          _normalizeRecoveryPasswordPolicy(options['password_policy']);
      final methods = (options['methods'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      if (methods.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Este usuario no tiene metodos de recuperacion disponibles.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      String selectedMethod = methods.first;
      if (methods.length > 1) {
        final method = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Selecciona metodo de recuperacion'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (methods.contains('email'))
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Codigo por email'),
                    subtitle: Text(
                      (options['email_masked'] ?? '').toString(),
                    ),
                    onTap: () => Navigator.of(dialogContext).pop('email'),
                  ),
                if (methods.contains('2fa'))
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Codigo 2FA (app autenticador)'),
                    onTap: () => Navigator.of(dialogContext).pop('2fa'),
                  ),
              ],
            ),
          ),
        );

        if (method == null) return;
        selectedMethod = method;
      }

      if (selectedMethod == 'email') {
        await _recoverWithEmail(identifier, passwordPolicy);
      } else {
        await _recoverWithTwoFactor(identifier, passwordPolicy);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _recoverWithEmail(
    String identifier,
    Map<String, dynamic> passwordPolicy,
  ) async {
    final request = await _apiService.requestPasswordRecoveryByEmail(
      identifier: identifier,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            (request['message'] ?? 'Codigo enviado por email.').toString()),
        backgroundColor: Colors.green,
      ),
    );

    final codeController = TextEditingController();
    final passwordController = TextEditingController();
    final repeatController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restablecer contraseña por email'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Código de recuperación',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: repeatController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Repetir nueva contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _buildRecoveryPasswordHint(passwordPolicy),
                style: Theme.of(context).textTheme.bodySmall,
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
            onPressed: () async {
              final code = codeController.text.trim();
              final pwd = passwordController.text;
              final repeat = repeatController.text;
              if (code.isEmpty || pwd.isEmpty || repeat.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Completa todos los campos.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              if (pwd != repeat) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Las contraseñas no coinciden.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              final passwordValidationError =
                  _validateRecoveryPassword(pwd, passwordPolicy);
              if (passwordValidationError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(passwordValidationError),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                await _apiService.resetPasswordWithEmailCode(
                  identifier: identifier,
                  code: code,
                  newPassword: pwd,
                );
                if (!mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.toString().replaceFirst('Exception: ', ''),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Actualizar contraseña'),
          ),
        ],
      ),
    );

    codeController.dispose();
    passwordController.dispose();
    repeatController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada. Ya puedes iniciar sesión.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _recoverWithTwoFactor(
    String identifier,
    Map<String, dynamic> passwordPolicy,
  ) async {
    final codeController = TextEditingController();
    final passwordController = TextEditingController();
    final repeatController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restablecer contraseña con 2FA'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Codigo 2FA',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: repeatController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Repetir nueva contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _buildRecoveryPasswordHint(passwordPolicy),
                style: Theme.of(context).textTheme.bodySmall,
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
            onPressed: () async {
              final code = codeController.text.trim();
              final pwd = passwordController.text;
              final repeat = repeatController.text;
              if (code.length != 6 || pwd.isEmpty || repeat.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Completa los campos correctamente.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              if (pwd != repeat) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Las contraseñas no coinciden.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              final passwordValidationError =
                  _validateRecoveryPassword(pwd, passwordPolicy);
              if (passwordValidationError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(passwordValidationError),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                await _apiService.resetPasswordWithTwoFactor(
                  identifier: identifier,
                  code2fa: code,
                  newPassword: pwd,
                );
                if (!mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.toString().replaceFirst('Exception: ', ''),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Actualizar contraseña'),
          ),
        ],
      ),
    );

    codeController.dispose();
    passwordController.dispose();
    repeatController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada. Ya puedes iniciar sesión.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.tertiary,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/logo-192.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'NutriFit',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nickController,
                  decoration: const InputDecoration(
                      labelText: 'Usuario', border: OutlineInputBorder()),
                  validator: (value) =>
                      value!.isEmpty ? 'Introduce tu usuario' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                      labelText: 'Contraseña',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible),
                      )),
                  validator: (value) =>
                      value!.isEmpty ? 'Introduce tu contraseña' : null,
                ),
                const SizedBox(height: 16),
                _isLoading
                    ? const CircularProgressIndicator()
                    : Column(
                        children: [
                          ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: const Text('Iniciar Sesión'),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _startRecoveryFlow,
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Divider(),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Accede a NutriFit gratis para consultar consejos de salud, de nutrición, vídeos de ejercicios, recetas de cocina, control de peso y mucho más.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontSize: (Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.fontSize ??
                                                  12) +
                                              1,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _submitAsGuest,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            icon: const Icon(Icons.visibility),
                            label: const Text('Acceder sin credenciales'),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/register'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              elevation: 3,
                            ),
                            child: const Text('Regístrate gratis'),
                          ),
                          const SizedBox(height: 2),
                        ],
                      ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    'NutriFit ${AppConstants.appVersion}. Todos los derechos reservados',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
