import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/password_requirements_checklist.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final _nickController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _edadController = TextEditingController();
  final _alturaController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _optionalDataExpanded = false;

  @override
  void initState() {
    super.initState();
    _refreshPasswordPolicies();
  }

  Future<void> _refreshPasswordPolicies() async {
    final configService = context.read<ConfigService>();
    await configService.loadPasswordPoliciesFromDatabase(_apiService);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      try {
        final exists = await _apiService.checkEmailExists(email);
        if (exists) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.registerEmailUnavailable),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } catch (_) {
        // Si falla esta comprobación puntual, el backend validará en registro.
      }
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.loginPasswordsMismatch),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final edad = int.tryParse(_edadController.text.trim());
      final altura = int.tryParse(_alturaController.text.trim());
      await authService.register(
        _nickController.text,
        _passwordController.text,
        _nameController.text,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        edad: (edad != null && edad > 0) ? edad : null,
        altura: (altura != null && altura > 0) ? altura : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.registerSuccessMessage),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('login');
      }
    } on SocketException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.registerNetworkError),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      final displayMessage =
          errorMessage.isNotEmpty ? errorMessage : l10n.registerGenericError;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final configService = context.watch<ConfigService>();
    final policy = PasswordPolicyRequirements.fromConfig(configService);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navStartRegistration),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 36),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
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
                    Text(l10n.registerCreateAccountTitle,
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.registerFullNameLabel,
                        border: OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? l10n.registerEnterFullName : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nickController,
                      decoration: InputDecoration(
                        labelText: l10n.loginUsernameLabel,
                        border: OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.account_circle),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return l10n.loginEnterUsername;
                        }
                        if (value.length < 3) {
                          return l10n.registerUsernameMinLength;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.registerEmailLabel,
                        border: OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return null;
                        final emailRegex =
                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                        if (!emailRegex.hasMatch(v)) {
                          return l10n.registerInvalidEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 1,
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _optionalDataExpanded = expanded;
                          });
                        },
                        title: Text(
                          l10n.registerAdditionalDataTitle,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _optionalDataExpanded
                              ? l10n.registerAdditionalDataExpandedSubtitle
                              : l10n.registerAdditionalDataCollapsedSubtitle,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
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
                                          l10n.registerAdditionalDataInfo,
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
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _edadController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: l10n.registerAgeLabel,
                                    border: OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.cake_outlined),
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return null;
                                    }
                                    final parsed = int.tryParse(value!.trim());
                                    if (parsed == null ||
                                        parsed <= 0 ||
                                        parsed > 120) {
                                      return l10n.registerInvalidAge;
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _alturaController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: l10n.registerHeightLabel,
                                    border: OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.height),
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return null;
                                    }
                                    final parsed = int.tryParse(value!.trim());
                                    if (parsed == null ||
                                        parsed < 80 ||
                                        parsed > 250) {
                                      return l10n.registerInvalidHeight;
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      decoration: InputDecoration(
                        labelText: l10n.loginPasswordLabel,
                        border: const OutlineInputBorder(),
                        errorMaxLines: 3,
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(
                              () => _passwordVisible = !_passwordVisible),
                        ),
                      ),
                      validator: (value) {
                        final configService = context.read<ConfigService>();

                        if (value!.isEmpty) {
                          return l10n.loginEnterPassword;
                        }

                        return configService.validatePassword(value);
                      },
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    PasswordRequirementsChecklist(
                      policy: policy,
                      password: _passwordController.text,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_confirmPasswordVisible,
                      decoration: InputDecoration(
                        labelText: l10n.registerConfirmPasswordLabel,
                        border: const OutlineInputBorder(),
                        errorMaxLines: 2,
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_confirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(() =>
                              _confirmPasswordVisible =
                                  !_confirmPasswordVisible),
                        ),
                      ),
                      validator: (value) => value!.isEmpty
                          ? l10n.registerConfirmPasswordRequired
                          : null,
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: Text(l10n.registerCreateAccountButton),
                          ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('login'),
                      child: Text(l10n.registerAlreadyHaveAccount),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nickController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _edadController.dispose();
    _alturaController.dispose();
    super.dispose();
  }
}
