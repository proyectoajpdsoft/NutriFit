import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/models/session.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/widgets/profile_image_picker.dart';
import 'package:nutri_app/widgets/app_language_dropdown.dart';
import 'package:nutri_app/widgets/delete_account_confirmation_helper.dart';
import 'package:nutri_app/screens/register_screen.dart';
import 'package:nutri_app/screens/contacto_nutricionista_screen.dart';
import 'package:nutri_app/widgets/password_requirements_checklist.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class PacienteProfileEditScreen extends StatefulWidget {
  final Usuario? usuario;
  final bool expandEmailVerification;

  const PacienteProfileEditScreen({
    super.key,
    this.usuario,
    this.expandEmailVerification = false,
  });

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
  final FocusNode _emailFocusNode = FocusNode();
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
  bool _loadingTrustedDevice = false;
  bool _isCurrentDeviceTrusted = false;
  bool _loadingEmailVerification = false;
  bool _checkingEmailAvailability = false;
  bool _emailVerified = false;
  String? _emailAvailabilityError;
  String? _emailFormatError;
  String? _emailVerificationDate;
  DateTime? _emailVerificationCodeExpiresAt;
  bool _emailVerificationCardExpanded = false;
  bool _twoFactorCardExpanded = false;
  bool _passwordCardExpanded = false;
  bool _mvpCardExpanded = false;
  bool _pendingOpenEmailVerification = false;

  // Estado de validación de contraseña
  late ConfigService _configService;

  @override
  void initState() {
    super.initState();
    _configService = context.read<ConfigService>();
    _pendingOpenEmailVerification = widget.expandEmailVerification;
    _refreshPasswordPolicies();
    _loadMaxImageDimensions();
    _loadUserData();
    _loadTwoFactorStatus();
    _loadEmailVerificationStatus();
  }

  // Validación en tiempo real cuando el email está completo
  void _validateEmailInRealTime() {
    final email = _emailController.text.trim();
    final currentEmail = (_fullUsuario?.email ?? '').trim();

    // Si el email está vacío o no está completo (sin @), marcar como error de formato
    if (email.isEmpty || !email.contains('@')) {
      if (_emailFormatError != null || _emailAvailabilityError != null) {
        setState(() {
          _emailFormatError = null;
          _emailAvailabilityError = null;
        });
      }
      return;
    }

    // Si es el mismo email actual, limpiar errores
    if (email.toLowerCase() == currentEmail.toLowerCase()) {
      if (_emailFormatError != null || _emailAvailabilityError != null) {
        setState(() {
          _emailFormatError = null;
          _emailAvailabilityError = null;
        });
      }
      return;
    }

    // Si no es válido formato, mostrar error de formato
    if (!_isValidEmailFormat(email)) {
      if (_emailFormatError == null && mounted) {
        setState(() {
          _emailFormatError =
              AppLocalizations.of(context)!.profileEditInvalidEmail;
        });
      }
      return;
    }

    // Formato es válido, limpiar error de formato
    if (_emailFormatError != null && mounted) {
      setState(() {
        _emailFormatError = null;
      });
    }

    // Ya está validando, no duplicar
    if (_checkingEmailAvailability) return;

    // Validar en BD de forma asincrónica
    _checkEmailExistsInBackground(email);
  }

  void _checkEmailExistsInBackground(String email) {
    _checkingEmailAvailability = true;
    _emailExistsInAnotherUser(email).then((exists) {
      if (!mounted) return;

      if (exists) {
        setState(() {
          _emailAvailabilityError =
              AppLocalizations.of(context)!.profileEditEmailInUse;
        });
      } else if (_emailAvailabilityError != null) {
        setState(() {
          _emailAvailabilityError = null;
        });
      }
    }).catchError((_) {
      // No bloquear si falla la validación remota
      if (_emailAvailabilityError != null && mounted) {
        setState(() {
          _emailAvailabilityError = null;
        });
      }
    }).whenComplete(() {
      _checkingEmailAvailability = false;
    });
  }

  void _maybeOpenEmailVerificationWindow() {
    if (!_pendingOpenEmailVerification || !mounted) return;
    _pendingOpenEmailVerification = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showEmailVerificationWindow();
    });
  }

  Future<void> _refreshPasswordPolicies() async {
    await _configService.loadPasswordPoliciesFromDatabase(_apiService);
    if (!mounted) return;
    setState(() {});
  }

  bool _hasActivePremiumBadge() {
    final usuario = _fullUsuario;
    if (usuario == null) return false;

    final tipo = (usuario.tipo ?? '').trim().toLowerCase();
    if (tipo != 'premium') {
      return false;
    }

    final expiry = usuario.premiumHastaFecha ?? usuario.premiumExpiraFecha;
    if (expiry == null) {
      return true;
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final expiryDate = DateTime(expiry.year, expiry.month, expiry.day);
    return !expiryDate.isBefore(todayDate);
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
        if (_emailVerified) {
          _emailVerificationCodeExpiresAt = null;
        }
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

  bool _isValidEmailFormat(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email.trim());
  }

  DateTime? _tryParseServerDateTime(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }

    final normalized = raw.contains(' ') && !raw.contains('T')
        ? raw.replaceFirst(' ', 'T')
        : raw;
    final parsed = DateTime.tryParse(normalized);
    return parsed?.toLocal();
  }

  Future<bool> _emailExistsInAnotherUser(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return false;
    }

    return _apiService.checkEmailExists(
      normalizedEmail,
      excludeCodigo: _fullUsuario?.codigo,
    );
  }

  Future<bool> _updateProfileWithEmail(
    String email, {
    bool includePassword = false,
  }) async {
    final usuarioData = {
      'codigo': _fullUsuario?.codigo.toString(),
      'nick': _nick,
      'nombre': _fullUsuario?.nombre,
      'email': email,
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
    if (usuarioData['altura'] == null || (usuarioData['altura'] as int) <= 0) {
      usuarioData['altura'] = null;
    }

    if (includePassword && _newPassword.isNotEmpty) {
      usuarioData['contrasena'] = _newPassword;
    }

    final success = await _apiService.updateUsuario(usuarioData);
    if (success) {
      _fullUsuario?.email = email.isEmpty ? null : email;
      _fullUsuario?.nick = _nick;
      _fullUsuario?.edad = usuarioData['edad'] as int?;
      _fullUsuario?.altura = usuarioData['altura'] as int?;
      _fullUsuario?.imgPerfil = _imageBase64;
    }
    return success;
  }

  Future<void> _saveEmailToProfile() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      throw Exception(l10n.profileEditEmailRequiredForVerification);
    }
    if (!_isValidEmailFormat(email)) {
      throw Exception('${l10n.profileEditInvalidEmail}.');
    }

    final currentEmail = (_fullUsuario?.email ?? '').trim();
    final sameEmail = currentEmail.toLowerCase() == email.toLowerCase();
    if (sameEmail) {
      return;
    }

    final emailExists = await _emailExistsInAnotherUser(email);
    if (emailExists) {
      throw Exception('${l10n.profileEditEmailInUse}.');
    }

    await _updateProfileWithEmail(email);
    if (!mounted) {
      return;
    }

    setState(() {
      _emailVerified = false;
      _emailVerificationDate = null;
      _emailVerificationCodeExpiresAt = null;
      _hasChanges = false;
    });
  }

  Future<void> _sendEmailVerificationCode() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileEditEmailRequiredForVerification),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isValidEmailFormat(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.profileEditInvalidEmail}.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Si hay error de disponibilidad, no continuar
    if (_emailAvailabilityError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_emailAvailabilityError!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _saveEmailToProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _loadingEmailVerification = true;
    });

    try {
      final resp = await _apiService.sendEmailVerificationCode();
      final expiresAt = _tryParseServerDateTime(resp['expires_at']?.toString());
      if (!mounted) return;
      setState(() {
        _emailVerificationCodeExpiresAt = expiresAt;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (resp['message'] ?? l10n.profileEditEmailCodeSentGeneric)
                .toString(),
          ),
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

  Future<void> _verifyEmailCode(String code) async {
    final l10n = AppLocalizations.of(context)!;
    final value = code.trim();
    if (value.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileEditEmailCodeLengthError),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _loadingEmailVerification = true;
    });

    try {
      final resp = await _apiService.verifyEmailCode(code: value);
      await _loadEmailVerificationStatus();
      if (!mounted) return;
      setState(() {
        _emailVerificationCodeExpiresAt = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (resp['message'] ?? l10n.profileEditEmailVerifiedGeneric)
                .toString(),
          ),
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
    final l10n = AppLocalizations.of(context)!;
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileEditEmailCodeDialogTitle),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.profileEditEmailCodeTenDigitsLabel,
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(codeController.text.trim()),
            child: Text(l10n.profileEditValidateEmailCodeAction),
          ),
        ],
      ),
    );
    codeController.dispose();

    if (code == null || code.isEmpty) {
      return;
    }

    await _verifyEmailCode(code);
  }

  Future<void> _showEmailVerificationWindow() async {
    final l10n = AppLocalizations.of(context)!;
    final codeController = TextEditingController();
    final userType =
        (context.read<AuthService>().userType ?? '').trim().toLowerCase();
    final isNutricionista = userType == 'nutricionista' ||
        userType == 'administrador' ||
        userType == 'admin' ||
        userType == 'nutritionist';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final email = _emailController.text.trim();
        final hasEmail = email.isNotEmpty;
        var codeSent = _emailVerificationCodeExpiresAt != null;
        var isBusy = false;
        String? inlineMessage;
        Color inlineMessageColor = Colors.orange.shade800;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.profileEditVerifyEmailTitle),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.lightBlue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.lightBlue.shade200),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(
                                text: '',
                              ),
                              TextSpan(
                                text: l10n.profileEditVerifyEmailIntroPrefix,
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(dialogContext).pop();
                                    Navigator.pushNamed(
                                      context,
                                      '/premium_info',
                                    );
                                  },
                                  child: Text(
                                    l10n.profileEditVerifyEmailPremiumLink,
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.profileEditFollowTheseSteps,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Punto 1
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.looks_one,
                                  color: Colors.teal.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.profileEditSendCodeInstruction(
                                      hasEmail
                                          ? email
                                          : l10n.profileEditYourEmail,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Botón "Enviar código" / "Volver a enviar"
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: (!hasEmail || isBusy)
                                    ? null
                                    : () async {
                                        var dialogClosed = false;
                                        if (!dialogContext.mounted) return;
                                        setDialogState(() {
                                          isBusy = true;
                                          inlineMessage = null;
                                        });
                                        try {
                                          await _saveEmailToProfile();
                                          final resp = await _apiService
                                              .sendEmailVerificationCode();
                                          final expiresAt =
                                              _tryParseServerDateTime(
                                            resp['expires_at']?.toString(),
                                          );
                                          if (!mounted ||
                                              !dialogContext.mounted) {
                                            dialogClosed = true;
                                            return;
                                          }
                                          setState(() {
                                            _emailVerificationCodeExpiresAt =
                                                expiresAt;
                                          });
                                          if (!dialogContext.mounted) {
                                            dialogClosed = true;
                                            return;
                                          }
                                          setDialogState(() {
                                            inlineMessage = l10n
                                                .profileEditEmailCodeSentInfo;
                                            inlineMessageColor =
                                                Colors.orange.shade800;
                                            codeSent = true;
                                          });
                                        } catch (e) {
                                          if (!dialogContext.mounted) {
                                            dialogClosed = true;
                                            return;
                                          }
                                          setDialogState(() {
                                            final detailed =
                                                e.toString().replaceFirst(
                                                      'Exception: ',
                                                      '',
                                                    );
                                            inlineMessage = isNutricionista
                                                ? detailed
                                                : l10n
                                                    .profileEditEmailSendFailed;
                                            inlineMessageColor = Colors.red;
                                          });
                                        } finally {
                                          if (mounted &&
                                              dialogContext.mounted &&
                                              !dialogClosed) {
                                            setDialogState(() {
                                              isBusy = false;
                                            });
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.send_outlined),
                                label: Text(
                                  codeSent
                                      ? l10n.profileEditResendCodeAction
                                      : l10n.profileEditSendCodeAction,
                                ),
                              ),
                            ),
                            if (codeSent && hasEmail) ...[
                              const SizedBox(height: 12),
                              // Punto 2
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.looks_two,
                                    color: Colors.teal.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.profileEditVerifyCodeInstruction,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: codeController,
                                keyboardType: TextInputType.number,
                                maxLength: 10,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  labelText:
                                      l10n.profileEditVerificationCodeLabel,
                                  border: OutlineInputBorder(),
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: (!hasEmail || isBusy)
                                      ? null
                                      : () async {
                                          var dialogClosed = false;
                                          final code =
                                              codeController.text.trim();
                                          if (code.length != 10) {
                                            if (!dialogContext.mounted) return;
                                            setDialogState(() {
                                              inlineMessage = l10n
                                                  .profileEditEmailCodeLengthError;
                                              inlineMessageColor =
                                                  Colors.orange;
                                            });
                                            return;
                                          }

                                          if (!dialogContext.mounted) return;
                                          setDialogState(() {
                                            isBusy = true;
                                            inlineMessage = null;
                                          });
                                          try {
                                            final resp = await _apiService
                                                .verifyEmailCode(code: code);
                                            await _loadEmailVerificationStatus();
                                            if (!mounted) {
                                              dialogClosed = true;
                                              return;
                                            }
                                            if (!dialogContext.mounted) {
                                              dialogClosed = true;
                                              return;
                                            }
                                            dialogClosed = true;
                                            Navigator.of(dialogContext).pop();
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                this.context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    (resp['message'] ??
                                                            'Email verificado.')
                                                        .toString(),
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            });
                                          } catch (e) {
                                            if (!dialogContext.mounted) {
                                              dialogClosed = true;
                                              return;
                                            }
                                            setDialogState(() {
                                              inlineMessage =
                                                  e.toString().replaceFirst(
                                                        'Exception: ',
                                                        '',
                                                      );
                                              inlineMessageColor = Colors.red;
                                            });
                                          } finally {
                                            if (mounted &&
                                                dialogContext.mounted &&
                                                !dialogClosed) {
                                              setDialogState(() {
                                                isBusy = false;
                                              });
                                            }
                                          }
                                        },
                                  icon: const Icon(Icons.verified_outlined),
                                  label: Text(l10n.commonValidate),
                                ),
                              ),
                            ],
                            if (!hasEmail) ...[
                              const SizedBox(height: 8),
                              Text(
                                l10n.profileEditEmailRequiredInProfile,
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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
              actions: [
                TextButton(
                  onPressed:
                      isBusy ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.commonClose),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
  }

  Future<void> _showChangeEmailDialog() async {
    final currentEmail = _emailController.text.trim();
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ChangeEmailDialog(
        currentEmail: currentEmail,
        wasVerified: _emailVerified,
        isValidEmailFormat: _isValidEmailFormat,
        emailExistsInAnotherUser: _emailExistsInAnotherUser,
      ),
    );

    if (updated == null || !mounted) {
      return;
    }

    setState(() {
      _emailController.text = updated;
      _emailVerified = false;
      _emailAvailabilityError = null;
      _emailVerificationDate = null;
      _emailVerificationCodeExpiresAt = null;
      _hasChanges = true;
    });

    _validateEmailInRealTime();
  }

  Future<void> _showTwoFactorWindow() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_twoFactorEnabled) {
      await _activarTwoFactor();
      return;
    }

    await _loadTrustedDeviceStatus();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            l10n.profileEditTwoFactorDialogTitle,
            style: Theme.of(dialogContext).textTheme.titleMedium,
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.security, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            l10n.profileEditTwoFactorEnabledStatus,
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.profileEditTwoFactorEnabledBody,
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isCurrentDeviceTrusted
                        ? Colors.lightGreen.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isCurrentDeviceTrusted
                          ? Colors.lightGreen.shade200
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Text(
                    _isCurrentDeviceTrusted
                        ? l10n.profileEditTrustedDeviceEnabledBody
                        : l10n.profileEditTrustedDeviceDisabledBody,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _isCurrentDeviceTrusted
                      ? OutlinedButton.icon(
                          onPressed:
                              (_loadingTwoFactor || _loadingTrustedDevice)
                                  ? null
                                  : () async {
                                      await _quitarConfianzaDispositivo();
                                      if (!mounted) return;
                                      await _loadTrustedDeviceStatus();
                                      if (!mounted) return;
                                      Navigator.of(dialogContext).pop();
                                    },
                          icon: const Icon(Icons.phonelink_erase_outlined),
                          label:
                              Text(l10n.profileEditRemoveTrustedDeviceAction),
                        )
                      : ElevatedButton.icon(
                          onPressed:
                              (_loadingTwoFactor || _loadingTrustedDevice)
                                  ? null
                                  : () async {
                                      await _establecerConfianzaDispositivoActual();
                                      if (!mounted) return;
                                      Navigator.of(dialogContext).pop();
                                    },
                          icon: const Icon(Icons.phonelink_lock_outlined),
                          label: Text(l10n.profileEditSetTrustedDeviceAction),
                        ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: (_loadingTwoFactor || _loadingTrustedDevice)
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: Text(l10n.profileEditCancelProcess),
                  ),
                ),
                if (_loadingTrustedDevice) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 2),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadTrustedDeviceStatus() async {
    if (!mounted) return;
    if (!_twoFactorEnabled) {
      setState(() {
        _isCurrentDeviceTrusted = false;
        _loadingTrustedDevice = false;
      });
      return;
    }

    final authService = context.read<AuthService>();
    final nick = (authService.userNick ?? '').trim();
    if (nick.isEmpty) {
      setState(() {
        _isCurrentDeviceTrusted = false;
        _loadingTrustedDevice = false;
      });
      return;
    }

    setState(() {
      _loadingTrustedDevice = true;
    });

    try {
      final token = await authService.getTrustedDeviceTokenForNick(nick);
      if (!mounted) return;
      setState(() {
        _isCurrentDeviceTrusted = (token ?? '').trim().isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCurrentDeviceTrusted = false;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingTrustedDevice = false;
      });
    }
  }

  Future<void> _establecerConfianzaDispositivoActual() async {
    final l10n = AppLocalizations.of(context)!;
    final goToLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileEditSetTrustedDeviceTitle),
        content: Text(
          l10n.profileEditSetTrustedDeviceBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profileEditGoToLogin),
          ),
        ],
      ),
    );

    if (goToLogin != true || !mounted) return;

    await context.read<AuthService>().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('login', (_) => false);
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
      await _loadTrustedDeviceStatus();
    } catch (_) {
      // Si falla la consulta, mantenemos el estado actual sin bloquear.
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingTwoFactor = false;
      });
    }
  }

  Future<void> _activarTwoFactor() async {
    final l10n = AppLocalizations.of(context)!;
    if (!mounted) return;
    setState(() {
      _loadingTwoFactor = true;
    });

    try {
      final setup = await _apiService.setupTwoFactor();
      final secret = (setup['secret'] ?? '').toString().trim();
      final manualKey = (setup['manual_key'] ?? '').toString().trim();
      final otpauthUrl = (setup['otpauth_url'] ?? '').toString().trim();
      final effectiveKey = manualKey.isNotEmpty ? manualKey : secret;

      if (!mounted) return;

      final codeController = TextEditingController();

      Future<String> saveQrImage({
        required String qrData,
        required String filePrefix,
        required bool useDownloads,
      }) async {
        final safeData = qrData.trim();
        if (safeData.isEmpty) {
          throw Exception('No hay datos para guardar el QR.');
        }

        final painter = QrPainter(
          data: safeData,
          version: QrVersions.auto,
          color: Colors.black,
          emptyColor: Colors.white,
        );
        final imageData = await painter.toImageData(
          1024,
          format: ui.ImageByteFormat.png,
        );

        if (imageData == null) {
          throw Exception('No se pudo generar el contenido del QR.');
        }

        final bytes = imageData.buffer.asUint8List();

        Directory targetDir;
        if (useDownloads &&
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          targetDir = await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
        } else {
          targetDir = await getApplicationDocumentsDirectory();
        }

        final fileName =
            '${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';
        final filePath = '${targetDir.path}${Platform.pathSeparator}$fileName';

        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);
        return filePath;
      }

      final code = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          String? dialogError;
          String? dialogNotice;
          bool showMoreOptions = false;
          bool showOtpauthInfo = false;

          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(l10n.profileEditActivateTwoFactorTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.lightBlue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.lightBlue.shade200),
                      ),
                      child: Text(
                        l10n.profileEditActivateTwoFactorIntro,
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.profileEditFollowTheseSteps,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.looks_one,
                                color: Colors.teal.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.profileEditTwoFactorStep1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.looks_two,
                                color: Colors.teal.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.teal.shade100,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.profileEditTwoFactorSetupKeyLabel,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        effectiveKey,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            await Clipboard.setData(
                                              ClipboardData(text: effectiveKey),
                                            );
                                            if (!dialogContext.mounted) return;
                                            setDialogState(() {
                                              dialogNotice =
                                                  l10n.profileEditKeyCopied;
                                              dialogError = null;
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.copy,
                                            size: 16,
                                          ),
                                          label: Text(l10n.premiumCopyConcept
                                              .replaceAll(' concepto', '')),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  showMoreOptions = !showMoreOptions;
                                });
                              },
                              icon: Icon(
                                showMoreOptions
                                    ? Icons.expand_less
                                    : Icons.more_horiz,
                              ),
                              label: Text(
                                showMoreOptions
                                    ? l10n.profileEditHideOptions
                                    : l10n.profileEditMoreOptions,
                              ),
                            ),
                          ),
                          if (showMoreOptions) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final qrData = otpauthUrl.isNotEmpty
                                        ? otpauthUrl
                                        : effectiveKey;
                                    try {
                                      if (Platform.isWindows ||
                                          Platform.isLinux ||
                                          Platform.isMacOS) {
                                        final path = await saveQrImage(
                                          qrData: qrData,
                                          filePrefix: 'nutrifit_2fa_qr',
                                          useDownloads: true,
                                        );
                                        if (!dialogContext.mounted) return;
                                        setDialogState(() {
                                          dialogNotice =
                                              l10n.profileEditQrSavedDownloads(
                                                  path);
                                          dialogError = null;
                                        });
                                      } else {
                                        final path = await saveQrImage(
                                          qrData: qrData,
                                          filePrefix: 'nutrifit_2fa_qr',
                                          useDownloads: false,
                                        );
                                        await Share.shareXFiles([
                                          XFile(path),
                                        ], text: 'QR 2FA de NutriFit');
                                        if (!dialogContext.mounted) return;
                                        setDialogState(() {
                                          dialogNotice =
                                              l10n.profileEditQrShared;
                                          dialogError = null;
                                        });
                                      }
                                    } catch (e) {
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        dialogError = e.toString().replaceFirst(
                                              'Exception: ',
                                              '',
                                            );
                                      });
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.share_outlined,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Compartir / Guardar en...',
                                  ),
                                ),
                                if (otpauthUrl.isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: otpauthUrl),
                                      );
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        dialogNotice =
                                            l10n.profileEditOtpUrlCopied;
                                        dialogError = null;
                                        showOtpauthInfo = true;
                                      });
                                    },
                                    icon: const Icon(Icons.link, size: 16),
                                    label: Text(l10n.profileEditCopyUrl),
                                  ),
                              ],
                            ),
                            if (showOtpauthInfo && otpauthUrl.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blueGrey.shade200,
                                  ),
                                ),
                                child: Text(
                                  l10n.profileEditOtpUrlInfo,
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.looks_3, color: Colors.teal.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.profileEditTwoFactorConfirmCodeInstruction,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.loginTwoFactorCodeLabel,
                              border: const OutlineInputBorder(),
                              counterText: '',
                              errorText: dialogError,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Text(
                          dialogError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (dialogNotice != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Text(
                          dialogNotice!,
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.commonCancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final value = codeController.text.trim();
                    if (value.length != 6) {
                      setDialogState(() {
                        dialogError = l10n.loginCodeMustHave6Digits;
                      });
                      return;
                    }
                    Navigator.pop(dialogContext, value);
                  },
                  child: Text(l10n.profileEditActivateTwoFactorAction),
                ),
              ],
            ),
          );
        },
      );

      codeController.dispose();

      if (code == null || code.isEmpty) {
        return;
      }

      await _apiService.enableTwoFactor(secret: secret, code: code);
      if (!mounted) return;
      // Diferir SnackBar y setState hasta después de que el diálogo esté
      // completamente desmontado, para evitar el crash _dependents.isEmpty.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profileEditTwoFactorActivated),
            backgroundColor: Colors.green,
          ),
        );
        await _loadTwoFactorStatus();
      });
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage.isEmpty
                ? l10n.profileEditTwoFactorActivateFailed
                : errorMessage,
          ),
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

  // ignore: unused_element
  Future<void> _guardarQr2fa({
    required String qrData,
    required String filePrefix,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final safeData = qrData.trim();
    if (safeData.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileEditNoQrData),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final painter = QrPainter(
        data: safeData,
        version: QrVersions.auto,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      final imageData = await painter.toImageData(
        1024,
        format: ui.ImageByteFormat.png,
      );

      if (imageData == null) {
        throw Exception('No se pudo generar el contenido del QR.');
      }

      final bytes = imageData.buffer.asUint8List();

      Directory targetDir;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        targetDir = await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      final fileName =
          '${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${targetDir.path}${Platform.pathSeparator}$fileName';

      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileEditQrSavedPath(filePath)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileEditQrSaveFailed('$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _desactivarTwoFactor() async {
    final l10n = AppLocalizations.of(context)!;
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileEditDeactivateTwoFactorTitle),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.profileEditCurrentCodeSixDigitsLabel,
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
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
              Navigator.pop(context, value);
            },
            child: Text(l10n.profileEditDeactivateTwoFactorAction),
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
        SnackBar(
          content: Text(l10n.profileEditTwoFactorDeactivated),
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
            errorMessage.isEmpty
                ? l10n.profileEditTwoFactorDeactivateFailed
                : errorMessage,
          ),
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
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileEditRemoveTrustedDeviceTitle),
        content: Text(
          l10n.profileEditRemoveTrustedDeviceBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profileEditRemoveTrustedDeviceActionShort),
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
        SnackBar(
          content: Text(l10n.profileEditTrustedDeviceRemoved),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileEditTrustedDeviceRemoveFailed('$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showMvpInfoDialog() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileEditMvpDialogTitle),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.profileEditMvpWhatIsTitle,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.profileEditMvpWhatIsBody,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.profileEditMvpFormulasTitle,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text('1) IMC = peso (kg) / altura (m)²'),
                Text(l10n.profileEditMvpOriginBmi),
                const SizedBox(height: 10),
                const Text('2) Cintura/Altura = cintura (cm) / altura (cm)'),
                Text(l10n.profileEditMvpOriginWhtr),
                const SizedBox(height: 10),
                const Text('3) Cintura/Cadera = cintura (cm) / cadera (cm)'),
                Text(l10n.profileEditMvpOriginWhr),
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
                              l10n.profileEditImportantNotice,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.profileEditMvpImportantNoticeBody,
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
            Padding(padding: const EdgeInsets.all(12), child: child),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
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

  // ignore: unused_element
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
              text: 'Email',
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
            'Verifica tu email para poder recuperar el acceso por correo si olvidas tu contraseña y para suscribirte a una cuenta Premium. Introduce tu cuenta de email y pulsa en "Enviar código", recibirás un código por correo, cópialo y pulsa en "Validar código", lo pegas y tu correo habrá quedado verificado.',
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
                  label: const Text('1º Enviar código'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _loadingEmailVerification ? null : _verifyEmailCodeDialog,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('2º Validar código'),
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
      final dimParam = await _apiService.getParametro(
        'usuario_max_imagen_tamaño',
      );
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
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(10, 8, 12, 0),
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Cambios sin guardar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Cancelar',
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
              ),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.of(dialogContext).pop('cancel'),
            ),
          ],
        ),
        content: const Text(
          'Tienes cambios sin guardar. Si sales ahora, se perderán.',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop('cancel'),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop('discard'),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );

    if (action == 'discard') {
      return true;
    }

    return false;
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
    _emailFocusNode.dispose();
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
            final usuario = await _apiService.getUsuario(
              widget.usuario!.codigo,
            );
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
            _maybeOpenEmailVerificationWindow();
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
            _maybeOpenEmailVerificationWindow();
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
          _maybeOpenEmailVerificationWindow();
        }
      } else {
        // Nuevo usuario - no hay datos que cargar
        setState(() {
          _isLoading = false;
        });
        _maybeOpenEmailVerificationWindow();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _maybeOpenEmailVerificationWindow();
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

  Future<void> _showDeleteUserWindow() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(
            l10n.privacyDeleteDialogTitle,
            style: Theme.of(dialogContext).textTheme.titleMedium,
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.privacyDeleteDialogIntro,
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.privacyDeleteDialogBody,
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.privacyDeleteDialogWarning,
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await _deleteMyAccountLopd();
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: Text(l10n.privacyDeleteMyData),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMyAccountLopd() async {
    final confirmedStep2 = await showTypedDeleteAccountConfirmation(context);
    if (!confirmedStep2 || !mounted) {
      return;
    }

    try {
      await _apiService.deleteCurrentUserWithDetails();
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

  Future<bool> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    {
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
        return false;
      }

      // Validar que el nick no exista (si ha cambiado)
      if (_nick != _fullUsuario?.nick) {
        try {
          final usuarios = await _apiService.getUsuarios();
          final nickExists = usuarios.any(
            (u) =>
                u.nick.toLowerCase() == _nick.toLowerCase() &&
                u.codigo != _fullUsuario?.codigo,
          );

          if (nickExists) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Este nick ya está en uso. Por favor, elija otro.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
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
          return false;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al validar el nick: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      }

      // Validar email duplicado (si cambia)
      final currentEmail = (_fullUsuario?.email ?? '').trim().toLowerCase();
      final formEmail = _emailController.text.trim().toLowerCase();
      if (formEmail.isNotEmpty && formEmail != currentEmail) {
        try {
          final emailExists = await _emailExistsInAnotherUser(
            _emailController.text.trim(),
          );
          if (emailExists) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Esta cuenta de email no puede usarse, indique otra',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
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
          return false;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al validar el email: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      }

      try {
        final success = await _updateProfileWithEmail(
          _emailController.text.trim(),
          includePassword: true,
        );
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Perfil actualizado correctamente'),
                backgroundColor: Colors.green,
              ),
            );
          }
          return true;
        }
        return false;
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
        return false;
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
        return false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(l10n.navEditProfile),
        ),
        body: const Center(child: CircularProgressIndicator()),
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
    final l10n = AppLocalizations.of(context)!;
    final bottomSafeInset = MediaQuery.of(context).padding.bottom;
    final hasEmail = _emailController.text.trim().isNotEmpty;
    final isVerifiedEmail = hasEmail && _emailVerified;
    final hasActivePremium = _hasActivePremiumBadge();

    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(l10n.navEditProfile),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: _submitForm),
          ],
        ),
        body: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: l10n.profileEditProfileTab),
                  Tab(text: l10n.profileEditSessionsTab),
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
                            if (hasActivePremium) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.amber.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.workspace_premium,
                                      color: Colors.amber.shade800,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.profileEditPremiumBadgeTitle,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                          Text(
                                            l10n.profileEditPremiumBadgeBody,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Avatar de perfil + estado 2FA (arriba derecha)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Center(
                                    child: ProfileImagePicker(
                                      initialBase64Image: _imageBase64,
                                      onImageChanged: _handleImageChanged,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 220,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_twoFactorEnabled)
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            onTap: _showTwoFactorWindow,
                                            child: Container(
                                              margin:
                                                  const EdgeInsets.only(top: 6),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.green.shade300,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.verified,
                                                    size: 22,
                                                    color:
                                                        Colors.green.shade700,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '2FA',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.green.shade800,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (_twoFactorEnabled)
                                        const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.language,
                                            size: 18,
                                            color: Colors.grey.shade700,
                                          ),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: AppLanguageDropdown(
                                              compact: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Nick
                            TextFormField(
                              controller: _nickController,
                              decoration: InputDecoration(
                                labelText: l10n.profileEditNickLabel,
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                      ? l10n.profileEditNickRequired
                                      : null,
                              onSaved: (value) => _nick = value!,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _emailController,
                                    focusNode: _emailFocusNode,
                                    enabled: true,
                                    readOnly: isVerifiedEmail,
                                    keyboardType: TextInputType.emailAddress,
                                    onChanged: (_) {
                                      _validateEmailInRealTime();
                                    },
                                    decoration: InputDecoration(
                                      labelText: l10n.profileEditEmailLabel,
                                      border: const OutlineInputBorder(),
                                      errorText: _emailFormatError ??
                                          (!_checkingEmailAvailability &&
                                                  _emailAvailabilityError !=
                                                      null
                                              ? l10n.profileEditEmailInUse
                                              : null),
                                      suffixIcon: isVerifiedEmail
                                          ? Icon(
                                              Icons.verified,
                                              color: Colors.green.shade700,
                                            )
                                          : null,
                                    ),
                                    validator: (value) {
                                      final v = (value ?? '').trim();
                                      if (v.isEmpty) return null;
                                      if (!_isValidEmailFormat(v)) {
                                        return l10n.profileEditInvalidEmail;
                                      }
                                      if (_emailAvailabilityError != null) {
                                        return l10n.profileEditEmailInUse;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                if (isVerifiedEmail) ...[
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: l10n.profileEditChangeEmailTooltip,
                                    child: SizedBox(
                                      height: 56,
                                      width: 56,
                                      child: OutlinedButton(
                                        onPressed: _showChangeEmailDialog,
                                        child: const Icon(
                                          Icons.alternate_email,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (!_emailVerified)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      onPressed: (_emailController.text
                                                  .trim()
                                                  .isNotEmpty &&
                                              _isValidEmailFormat(
                                                _emailController.text.trim(),
                                              ) &&
                                              _emailAvailabilityError == null)
                                          ? _showEmailVerificationWindow
                                          : null,
                                      icon: const Icon(
                                        Icons.mark_email_read_outlined,
                                      ),
                                      label:
                                          Text(l10n.profileEditVerifyEmailCta),
                                    ),
                                  ),
                                if (!_emailVerified && !_twoFactorEnabled)
                                  const SizedBox(width: 8),
                                if (!_twoFactorEnabled)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _showTwoFactorWindow,
                                      icon: const Icon(Icons.security_outlined),
                                      label: Text(
                                        l10n.profileEditTwoFactorShortLabel,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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
                                  Expanded(
                                    child: Text(
                                      l10n.profileEditBmiCardTitle,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l10n.profileEditBmiInfoTooltip,
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
                                        color: Colors.orange.shade200,
                                      ),
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
                                            l10n.profileEditBmiCardBody,
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
                                    decoration: InputDecoration(
                                      labelText: l10n.profileEditAgeLabel,
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return null;
                                      }
                                      final parsed = int.tryParse(
                                        value!.trim(),
                                      );
                                      if (parsed == null ||
                                          parsed <= 0 ||
                                          parsed > 120) {
                                        return l10n.profileEditInvalidAge;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _alturaController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: l10n.profileEditHeightLabel,
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return null;
                                      }
                                      final parsed = int.tryParse(
                                        value!.trim(),
                                      );
                                      if (parsed == null ||
                                          parsed < 80 ||
                                          parsed > 250) {
                                        return l10n.profileEditInvalidHeight;
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
                              title: Text(
                                l10n.profileEditPasswordCardTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.profileEditPasswordHint,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: l10n.profileEditPasswordLabel,
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return null;
                                      }
                                      final error = _getPasswordValidationError(
                                        value,
                                      );
                                      return error;
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        _newPassword = value;
                                      });
                                    },
                                    onSaved: (value) =>
                                        _newPassword = value ?? '',
                                  ),
                                  const SizedBox(height: 16),
                                  PasswordRequirementsChecklist(
                                    policy:
                                        PasswordPolicyRequirements.fromConfig(
                                      _configService,
                                    ),
                                    password: _newPassword,
                                  ),
                                  const SizedBox(height: 16),
                                  if (_newPassword.isNotEmpty)
                                    TextFormField(
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        labelText: l10n
                                            .profileEditPasswordConfirmLabel,
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (_newPassword.isNotEmpty &&
                                            (value == null || value.isEmpty)) {
                                          return l10n
                                              .profileEditPasswordConfirmRequired;
                                        }
                                        if (value != null &&
                                            value != _newPassword) {
                                          return l10n
                                              .profileEditPasswordMismatch;
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

                            const SizedBox(height: 24),

                            // Botón de guardar
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitForm,
                                child: Text(l10n.profileEditSaveChanges),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _showDeleteUserWindow,
                                icon: const Icon(Icons.delete_forever),
                                label: Text(l10n.profileEditDeleteMyData),
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

class _ChangeEmailDialog extends StatefulWidget {
  const _ChangeEmailDialog({
    required this.currentEmail,
    required this.wasVerified,
    required this.isValidEmailFormat,
    required this.emailExistsInAnotherUser,
  });

  final String currentEmail;
  final bool wasVerified;
  final bool Function(String) isValidEmailFormat;
  final Future<bool> Function(String) emailExistsInAnotherUser;

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  late final TextEditingController _emailController;
  String? _errorText;
  bool _checkingAvailability = false;
  bool _emailAvailable = false;
  String _availabilityCheckedEmail = '';
  int _validationToken = 0;

  String get _currentEmailNormalized =>
      widget.currentEmail.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.currentEmail);
    _validateInline();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _canAccept() {
    final value = _emailController.text.trim();
    if (value.isEmpty) {
      return false;
    }
    if (!widget.isValidEmailFormat(value)) {
      return false;
    }
    if (value.toLowerCase() == _currentEmailNormalized) {
      return false;
    }
    if (_checkingAvailability) {
      return false;
    }

    final normalized = value.toLowerCase();
    return _availabilityCheckedEmail == normalized && _emailAvailable;
  }

  void _validateInline() {
    final l10n = AppLocalizations.of(context)!;
    final value = _emailController.text.trim();

    if (value.isEmpty) {
      setState(() {
        _errorText = l10n.profileEditChangeEmailRequired;
        _checkingAvailability = false;
        _emailAvailable = false;
        _availabilityCheckedEmail = '';
      });
      return;
    }

    if (!widget.isValidEmailFormat(value)) {
      setState(() {
        _errorText = l10n.profileEditInvalidEmail;
        _checkingAvailability = false;
        _emailAvailable = false;
        _availabilityCheckedEmail = '';
      });
      return;
    }

    if (value.toLowerCase() == _currentEmailNormalized) {
      setState(() {
        _errorText = l10n.profileEditChangeEmailMustDiffer;
        _checkingAvailability = false;
        _emailAvailable = false;
        _availabilityCheckedEmail = '';
      });
      return;
    }

    _checkEmailAvailability(value);
  }

  Future<void> _checkEmailAvailability(String email) async {
    final l10n = AppLocalizations.of(context)!;
    final normalized = email.trim().toLowerCase();
    final token = ++_validationToken;

    setState(() {
      _checkingAvailability = true;
      _errorText = null;
      _availabilityCheckedEmail = '';
      _emailAvailable = false;
    });

    try {
      final exists = await widget.emailExistsInAnotherUser(email);
      if (!mounted || token != _validationToken) return;

      setState(() {
        _checkingAvailability = false;
        _availabilityCheckedEmail = normalized;
        _emailAvailable = !exists;
        _errorText = exists ? l10n.profileEditEmailInUse : null;
      });
    } catch (_) {
      if (!mounted || token != _validationToken) return;
      setState(() {
        _checkingAvailability = false;
        _availabilityCheckedEmail = '';
        _emailAvailable = false;
        _errorText = l10n.profileEditChangeEmailValidationFailed;
      });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    _validateInline();

    final value = _emailController.text.trim();
    final normalized = value.toLowerCase();
    final needsAvailabilityCheck = value.isNotEmpty &&
        widget.isValidEmailFormat(value) &&
        normalized != _currentEmailNormalized &&
        _availabilityCheckedEmail != normalized;

    if (needsAvailabilityCheck) {
      await _checkEmailAvailability(value);
    }

    if (!_canAccept()) {
      setState(() {
        _errorText ??= l10n.profileEditChangeEmailReview;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.profileEditChangeEmailTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.wasVerified) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.profileEditChangeEmailVerifiedWarning,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.profileEditChangeEmailNewLabel,
              border: const OutlineInputBorder(),
              errorText: _errorText,
              suffixIcon: _checkingAvailability
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: (_) {
              _validateInline();
            },
            onSubmitted: (_) {
              _submit();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: _canAccept() ? _submit : null,
          child: Text(l10n.profileEditAccept),
        ),
      ],
    );
  }
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
    final l10n = AppLocalizations.of(context)!;
    final fechaFormato = sesion.fecha;
    final horaFormato = sesion.hora ?? l10n.profileEditNotAvailable;
    final tipoDispositivo = sesion.tipo ?? l10n.profileEditNotAvailable;
    final ipPublica = sesion.ipPublica ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Text(
              '${l10n.profileEditSessionDate}: $fechaFormato',
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
              '${l10n.profileEditSessionTime}: $horaFormato',
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
              '${l10n.profileEditSessionDevice}: $tipoDispositivo',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 16),
        Text(
          l10n.profileEditSessionIp,
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
                  '${l10n.profileEditSessionPublicIp}: $ipPublica',
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
    final l10n = AppLocalizations.of(context)!;
    final authService = context.read<AuthService>();
    final usuarioCode = authService.userCode;

    if (usuarioCode == null || usuarioCode.isEmpty) {
      return Center(child: Text(l10n.profileEditUserCodeUnavailable));
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
                    Text(
                      l10n.profileEditSessionDataUnavailable,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.profileEditRetry),
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
            return Center(child: Text(l10n.profileEditNoSessionData));
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
                      Row(
                        children: [
                          const Icon(Icons.security, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            l10n.profileEditSuccessfulSessionsTitle,
                            style: const TextStyle(
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
                            i == 0
                                ? l10n.profileEditCurrentSession
                                : l10n.profileEditPreviousSession,
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
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            l10n.profileEditNoSuccessfulSessions,
                          ),
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
                        Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(
                              l10n.profileEditFailedAttemptsTitle,
                              style: const TextStyle(
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
                            l10n.profileEditAttemptLabel(i + 1),
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
                        Expanded(
                          child: Text(
                            l10n.profileEditNoFailedAttempts,
                            style: const TextStyle(
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
                      Text(
                        l10n.profileEditSessionStatsTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.analytics,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.profileEditTotalSessions(
                              sessionData.totalSesiones,
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.profileEditSuccessfulAttempts(
                              sessionData.totalExitosas,
                            ),
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
                            l10n.profileEditFailedAttempts(
                              sessionData.totalFallidas,
                            ),
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
