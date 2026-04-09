import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/exceptions/auth_exceptions.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/constants/app_constants.dart';
import 'package:nutri_app/widgets/app_version_label.dart';
import 'package:nutri_app/widgets/app_language_dropdown.dart';
import 'package:nutri_app/widgets/password_requirements_checklist.dart';
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

  AppLocalizations get l10n => AppLocalizations.of(context)!;

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

  bool _isInvalidCredentialsError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('usuario o contraseña incorrectos') ||
        normalized.contains('usuario o contrasena incorrectos') ||
        normalized.contains('invalid username or password') ||
        normalized.contains('incorrect username or password');
  }

  String _buildLoginErrorMessage(dynamic error) {
    if (error is TwoFactorRequiredException) {
      return error.message;
    }

    final errorMessage = error.toString().replaceFirst('Exception: ', '');
    if (_isNetworkError(errorMessage)) {
      return l10n.loginNetworkError;
    }
    if (_isInvalidCredentialsError(errorMessage)) {
      return l10n.loginInvalidCredentials;
    }
    if (errorMessage.contains('Cuenta temporalmente bloqueada')) {
      return errorMessage;
    }
    return errorMessage.isNotEmpty ? errorMessage : l10n.loginFailedGeneric;
  }

  String _buildGuestErrorMessage(dynamic error) {
    final errorMessage = error.toString().replaceFirst('Exception: ', '');
    if (_isNetworkError(errorMessage)) {
      return l10n.loginNetworkError;
    }
    return l10n.loginGuestFailedGeneric;
  }

  bool _isNutricionistaTypeValue(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    return value == 'nutricionista' ||
        value == 'administrador' ||
        value == 'admin' ||
        value == 'nutritionist';
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
          return;
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
        if (authService.isPatientAreaUser && userType != 'Guest') {
          Navigator.of(context).pushReplacementNamed('paciente_home');
        } else if (userType == 'Nutricionista' || userType == 'Administrador') {
          Navigator.of(context).pushReplacementNamed('home');
        } else if (userType == 'Guest') {
          Navigator.of(context).pushReplacementNamed('paciente_home');
        } else {
          // Tipo de usuario desconocido - logout y mostrar error
          await authService.logout();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.loginUnknownUserType),
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
            titlePadding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.loginTwoFactorTitle,
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonCancel,
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.loginTwoFactorPrompt,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.loginTwoFactorCodeLabel,
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
                  title: Text(l10n.loginTrustThisDevice),
                  subtitle: Text(
                    l10n.loginTrustThisDeviceSubtitle,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final value = codeController.text.trim();
                  if (value.length != 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.loginCodeMustHave6Digits),
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
                child: Text(l10n.commonValidate),
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

  int _normalizeRecoveryCodeLength(dynamic rawLength) {
    final parsed = int.tryParse(rawLength?.toString() ?? '') ?? 12;
    if (parsed < 4) return 4;
    if (parsed > 32) return 32;
    return parsed;
  }

  bool _normalizeRecoveryCodeAllowAlnum(dynamic rawAllowAlnum) {
    final normalized = rawAllowAlnum?.toString().trim().toUpperCase() ?? 'S';
    return normalized == 'S';
  }

  String? _validateRecoveryPassword(
    String password,
    Map<String, dynamic> policy,
  ) {
    final minLength = policy['min_length'] as int? ?? 8;
    if (password.length < minLength) {
      return l10n.loginPasswordMinLengthError(minLength);
    }

    if (policy['require_upper_lower'] == true) {
      if (!password.contains(RegExp(r'[A-Z]'))) {
        return l10n.loginPasswordUppercaseError;
      }
      if (!password.contains(RegExp(r'[a-z]'))) {
        return l10n.loginPasswordLowercaseError;
      }
    }

    if (policy['require_numbers'] == true &&
        !password.contains(RegExp(r'[0-9]'))) {
      return l10n.loginPasswordNumberError;
    }

    if (policy['require_special_chars'] == true &&
        !password.contains(RegExp(r'[*,.+\-#$?¿!¡_()\/\\%&]'))) {
      return l10n.loginPasswordSpecialError;
    }

    return null;
  }

  Future<void> _startRecoveryFlow() async {
    final identifierController = TextEditingController(
      text: _nickController.text.trim(),
    );

    final identifier = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? inlineError;
        final dialogL10n = AppLocalizations.of(dialogContext)!;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            title: Text(dialogL10n.loginRecoveryTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dialogL10n.loginRecoveryIdentifierIntro,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextField(
                  controller: identifierController,
                  decoration: InputDecoration(
                    labelText: dialogL10n.loginUserOrEmailLabel,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (inlineError != null) {
                      setDialogState(() {
                        inlineError = null;
                      });
                    }
                  },
                ),
                if (inlineError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Text(
                      inlineError!,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: Text(dialogL10n.commonCancel),
              ),
              ElevatedButton(
                onPressed: () {
                  final value = identifierController.text.trim();
                  if (value.isEmpty) {
                    setDialogState(() {
                      inlineError = dialogL10n.loginEnterUserOrEmail;
                    });
                    return;
                  }
                  Navigator.of(dialogContext).pop(value);
                },
                child: Text(dialogL10n.commonContinue),
              ),
            ],
          ),
        );
      },
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
      final recoveryCodeLength =
          _normalizeRecoveryCodeLength(options['recovery_code_length']);
      final recoveryCodeAllowAlnum = _normalizeRecoveryCodeAllowAlnum(
          options['recovery_code_allow_alnum']);
      final isNutricionista =
          _isNutricionistaTypeValue(options['is_nutricionista']) ||
              _isNutricionistaTypeValue(options['user_type']) ||
              _isNutricionistaTypeValue(options['tipo']);
      final methods = (options['methods'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      if (methods.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.loginNoRecoveryMethods),
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
            title: Text(l10n.loginSelectRecoveryMethod),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (methods.contains('email'))
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: Text(l10n.loginRecoveryByEmail),
                    subtitle: Text(
                      (options['email_masked'] ?? '').toString(),
                    ),
                    onTap: () => Navigator.of(dialogContext).pop('email'),
                  ),
                if (methods.contains('2fa'))
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(l10n.loginRecoveryByTwoFactor),
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
        await _recoverWithEmail(
          identifier,
          passwordPolicy,
          recoveryCodeLength: recoveryCodeLength,
          recoveryCodeAllowAlnum: recoveryCodeAllowAlnum,
          isNutricionista: isNutricionista,
        );
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
    Map<String, dynamic> passwordPolicy, {
    required int recoveryCodeLength,
    required bool recoveryCodeAllowAlnum,
    required bool isNutricionista,
  }) async {
    final codeController = TextEditingController();
    final passwordController = TextEditingController();
    final repeatController = TextEditingController();
    final checklistPolicy =
        PasswordPolicyRequirements.fromRecoveryPolicy(passwordPolicy);
    String passwordPreview = '';

    // No enviamos email automáticamente. El usuario lo hará pulsando botón.

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool codeSent = false;
        bool codeValidated = false;
        String? inlineMessage;
        Color inlineMessageColor = Colors.orange;
        final dialogL10n = AppLocalizations.of(dialogContext)!;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      dialogL10n.loginRecoveryTitle,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    tooltip: dialogL10n.commonCancel,
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(dialogCtx).size.height * 0.72,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Info introductoria
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Text(
                            dialogL10n.loginEmailRecoveryIntro,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Paso 1: Enviar código
                        if (!codeSent)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFF00897B)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info,
                                        size: 16, color: Color(0xFF00897B)),
                                    const SizedBox(width: 8),
                                    Text(
                                      dialogL10n.loginRecoveryStep1SendCode,
                                      style: const TextStyle(
                                        color: Color(0xFF00897B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  dialogL10n.loginRecoveryStep1SendCodeBody,
                                  style: TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  icon:
                                      const Icon(Icons.mail_outline, size: 18),
                                  label: Text(dialogL10n.loginSendCode),
                                  onPressed: () async {
                                    try {
                                      await _apiService
                                          .requestPasswordRecoveryByEmail(
                                        identifier: identifier,
                                      );
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        codeSent = true;
                                        inlineMessage = null;
                                      });
                                    } catch (e) {
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        final detailed = e
                                            .toString()
                                            .replaceFirst('Exception: ', '');
                                        inlineMessage = isNutricionista
                                            ? detailed
                                            : dialogL10n
                                                .loginEmailRecoverySendFailedGeneric;
                                        inlineMessageColor = Colors.red;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        // Paso 2: Introducir código (condicional)
                        if (codeSent && !codeValidated) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFF00897B)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info,
                                        size: 16, color: Color(0xFF00897B)),
                                    const SizedBox(width: 8),
                                    Text(
                                      dialogL10n.loginRecoveryStep2VerifyCode,
                                      style: const TextStyle(
                                        color: Color(0xFF00897B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  dialogL10n.loginRecoveryStep2VerifyCodeBody,
                                  style: TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: codeController,
                                  keyboardType: recoveryCodeAllowAlnum
                                      ? TextInputType.text
                                      : TextInputType.number,
                                  textCapitalization: TextCapitalization.none,
                                  maxLength: recoveryCodeLength,
                                  inputFormatters: recoveryCodeAllowAlnum
                                      ? <TextInputFormatter>[
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[A-Za-z0-9]'),
                                          ),
                                        ]
                                      : <TextInputFormatter>[
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                  decoration: InputDecoration(
                                    labelText:
                                        dialogL10n.loginRecoveryCodeLabel,
                                    hintText: recoveryCodeAllowAlnum
                                        ? dialogL10n.loginRecoveryCodeHintAlpha
                                        : dialogL10n
                                            .loginRecoveryCodeHintNumeric,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) {
                                    if (inlineMessage != null) {
                                      setDialogState(() {
                                        inlineMessage = null;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () async {
                                    final code = codeController.text.trim();
                                    if (code.isEmpty) {
                                      setDialogState(() {
                                        inlineMessage =
                                            dialogL10n.loginRecoveryCodeLabel;
                                        inlineMessageColor = Colors.orange;
                                      });
                                      return;
                                    }
                                    try {
                                      await _apiService
                                          .validateEmailRecoveryCode(
                                        identifier: identifier,
                                        code: code,
                                      );
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        codeValidated = true;
                                        codeSent = true;
                                        inlineMessage = null;
                                      });
                                    } catch (e) {
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        inlineMessage = e
                                            .toString()
                                            .replaceFirst('Exception: ', '');
                                        inlineMessageColor = Colors.red;
                                      });
                                    }
                                  },
                                  child: Text(dialogL10n.loginVerifyCode),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Paso 3: Nueva contraseña (condicional)
                        if (codeValidated) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFF00897B)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info,
                                        size: 16, color: Color(0xFF00897B)),
                                    const SizedBox(width: 8),
                                    Text(
                                      dialogL10n.loginRecoveryStep3NewPassword,
                                      style: const TextStyle(
                                        color: Color(0xFF00897B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  dialogL10n.loginRecoveryStep3NewPasswordBody,
                                  style: TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: dialogL10n.loginNewPasswordLabel,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      passwordPreview = value;
                                      if (inlineMessage != null) {
                                        inlineMessage = null;
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: repeatController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText:
                                        dialogL10n.loginRepeatNewPasswordLabel,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) {
                                    if (inlineMessage != null) {
                                      setDialogState(() {
                                        inlineMessage = null;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                PasswordRequirementsChecklist(
                                  policy: checklistPolicy,
                                  password: passwordPreview,
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Mensajes inline
                        if (inlineMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: inlineMessageColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: inlineMessageColor),
                            ),
                            child: Text(
                              inlineMessage!,
                              style: TextStyle(
                                color: inlineMessageColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                if (codeValidated)
                  ElevatedButton(
                    onPressed: () async {
                      final code = codeController.text.trim();
                      final pwd = passwordController.text;
                      final repeat = repeatController.text;
                      if (pwd.isEmpty || repeat.isEmpty) {
                        setDialogState(() {
                          inlineMessage = dialogL10n.loginBothPasswordsRequired;
                          inlineMessageColor = Colors.orange;
                        });
                        return;
                      }
                      if (pwd != repeat) {
                        setDialogState(() {
                          inlineMessage = dialogL10n.loginPasswordsMismatch;
                          inlineMessageColor = Colors.orange;
                        });
                        return;
                      }

                      final passwordValidationError =
                          _validateRecoveryPassword(pwd, passwordPolicy);
                      if (passwordValidationError != null) {
                        setDialogState(() {
                          inlineMessage = passwordValidationError;
                          inlineMessageColor = Colors.orange;
                        });
                        return;
                      }

                      try {
                        await _apiService.resetPasswordWithEmailCode(
                          identifier: identifier,
                          code: code,
                          newPassword: pwd,
                        );
                        if (!dialogContext.mounted) return;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop(true);
                        });
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          inlineMessage =
                              e.toString().replaceFirst('Exception: ', '');
                          inlineMessageColor = Colors.red;
                        });
                      }
                    },
                    child: Text(dialogL10n.loginResetPassword),
                  ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    passwordController.dispose();
    repeatController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.loginPasswordResetSuccess),
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
    final checklistPolicy =
        PasswordPolicyRequirements.fromRecoveryPolicy(passwordPolicy);
    String passwordPreview = '';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool step1Complete = false;
        bool step2Complete = false;
        String? inlineMessage;
        Color inlineMessageColor = Colors.orange;
        final dialogL10n = AppLocalizations.of(dialogContext)!;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      dialogL10n.loginRecoveryTitle,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    tooltip: dialogL10n.commonCancel,
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(dialogCtx).size.height * 0.72,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Intro explicativo
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Text(
                            dialogL10n.loginTwoFactorRecoveryIntro,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!step1Complete)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFF00897B)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info,
                                        size: 16, color: Color(0xFF00897B)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        dialogL10n.loginTwoFactorRecoveryStep1,
                                        style: const TextStyle(
                                          color: Color(0xFF00897B),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  dialogL10n.loginTwoFactorRecoveryStep1Body,
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.check, size: 16),
                                  label: Text(dialogL10n.loginIHaveIt),
                                  onPressed: () {
                                    setDialogState(() {
                                      step1Complete = true;
                                      inlineMessage = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        if (step1Complete && !step2Complete) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFF00897B)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info,
                                        size: 16, color: Color(0xFF00897B)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        dialogL10n.loginTwoFactorRecoveryStep2,
                                        style: const TextStyle(
                                          color: Color(0xFF00897B),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  dialogL10n.loginTwoFactorRecoveryStep2Body,
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: codeController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: dialogL10n
                                        .loginTwoFactorCodeSixDigitsLabel,
                                    hintText: dialogL10n.loginTwoFactorCodeHint,
                                    border: OutlineInputBorder(),
                                    counterText: '',
                                  ),
                                  onChanged: (_) {
                                    if (inlineMessage != null) {
                                      setDialogState(() {
                                        inlineMessage = null;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () async {
                                    final code = codeController.text.trim();
                                    if (code.length != 6) {
                                      setDialogState(() {
                                        inlineMessage = dialogL10n
                                            .loginCodeMustHaveExactly6Digits;
                                        inlineMessageColor = Colors.orange;
                                      });
                                      return;
                                    }
                                    try {
                                      await _apiService
                                          .validateTwoFactorRecoveryCode(
                                        identifier: identifier,
                                        code2fa: code,
                                      );
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        step2Complete = true;
                                        inlineMessage = null;
                                      });
                                    } catch (e) {
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        inlineMessage = e
                                            .toString()
                                            .replaceFirst('Exception: ', '');
                                        inlineMessageColor = Colors.red;
                                      });
                                    }
                                  },
                                  child:
                                      Text(dialogL10n.loginVerifyTwoFactorCode),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (step2Complete) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFF00897B)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info,
                                        size: 16, color: Color(0xFF00897B)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        dialogL10n
                                            .loginRecoveryStep3NewPassword,
                                        style: const TextStyle(
                                          color: Color(0xFF00897B),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  dialogL10n.loginRecoveryStep3NewPasswordBody,
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: dialogL10n.loginNewPasswordLabel,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      passwordPreview = value;
                                      if (inlineMessage != null) {
                                        inlineMessage = null;
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: repeatController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText:
                                        dialogL10n.loginRepeatNewPasswordLabel,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) {
                                    if (inlineMessage != null) {
                                      setDialogState(() {
                                        inlineMessage = null;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                PasswordRequirementsChecklist(
                                  policy: checklistPolicy,
                                  password: passwordPreview,
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Mensajes inline
                        if (inlineMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: inlineMessageColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: inlineMessageColor),
                            ),
                            child: Text(
                              inlineMessage!,
                              style: TextStyle(
                                color: inlineMessageColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                if (step2Complete)
                  ElevatedButton(
                    onPressed: () async {
                      final code = codeController.text.trim();
                      final pwd = passwordController.text;
                      final repeat = repeatController.text;
                      if (pwd.isEmpty || repeat.isEmpty) {
                        setDialogState(() {
                          inlineMessage = dialogL10n.loginBothPasswordsRequired;
                          inlineMessageColor = Colors.orange;
                        });
                        return;
                      }
                      if (pwd != repeat) {
                        setDialogState(() {
                          inlineMessage = dialogL10n.loginPasswordsMismatch;
                          inlineMessageColor = Colors.orange;
                        });
                        return;
                      }

                      final passwordValidationError =
                          _validateRecoveryPassword(pwd, passwordPolicy);
                      if (passwordValidationError != null) {
                        setDialogState(() {
                          inlineMessage = passwordValidationError;
                          inlineMessageColor = Colors.orange;
                        });
                        return;
                      }

                      try {
                        await _apiService.resetPasswordWithTwoFactor(
                          identifier: identifier,
                          code2fa: code,
                          newPassword: pwd,
                        );
                        if (!dialogContext.mounted) return;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop(true);
                        });
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          inlineMessage =
                              e.toString().replaceFirst('Exception: ', '');
                          inlineMessageColor = Colors.red;
                        });
                      }
                    },
                    child: Text(dialogL10n.loginResetPassword),
                  ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    passwordController.dispose();
    repeatController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.loginPasswordUpdatedSuccess),
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
                  decoration: InputDecoration(
                      labelText: l10n.loginUsernameLabel,
                      border: const OutlineInputBorder()),
                  validator: (value) =>
                      value!.isEmpty ? l10n.loginEnterUsername : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                      labelText: l10n.loginPasswordLabel,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible),
                      )),
                  validator: (value) =>
                      value!.isEmpty ? l10n.loginEnterPassword : null,
                ),
                const SizedBox(height: 16),
                _isLoading
                    ? const CircularProgressIndicator()
                    : Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 104,
                                child: AppLanguageDropdown(
                                  compact: true,
                                  compactHeight: 50,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _submit,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize:
                                        const Size(double.infinity, 50),
                                    backgroundColor: Colors.lightGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 3,
                                  ),
                                  child: Text(l10n.loginSignIn),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _startRecoveryFlow,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                l10n.loginForgotPassword,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                                    .withValues(alpha: 0.2),
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
                                    l10n.loginGuestInfo,
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
                          ElevatedButton.icon(
                            onPressed: _submitAsGuest,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: Colors.pink.shade300,
                              foregroundColor: Colors.white,
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.visibility),
                            label: Text(l10n.loginGuestAccess),
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
                            child: Text(l10n.loginRegisterFree),
                          ),
                          const SizedBox(height: 2),
                        ],
                      ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.center,
                  child: AppVersionLabel(
                    prefix: '${AppConstants.appName} ',
                    suffix: '. ${l10n.commonAllRightsReserved}',
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
