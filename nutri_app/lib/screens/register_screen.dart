import 'dart:io';
import 'package:flutter/material.dart';
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
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      try {
        final exists = await _apiService.checkEmailExists(email);
        if (exists) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Esta cuenta de email no puede usarse, indique otra'),
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
        const SnackBar(
          content: Text('Las contraseñas no coinciden'),
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
          const SnackBar(
            content: Text(
                'Usuario registrado correctamente. Por favor, inicia sesión con tus datos (usuario y contraseña)'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('login');
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
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      final displayMessage =
          errorMessage.isNotEmpty ? errorMessage : 'Error al registrarse';

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
    final configService = context.watch<ConfigService>();
    final policy = PasswordPolicyRequirements.fromConfig(configService);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar registro'),
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
                    Text('Crear Cuenta',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Introduce tu nombre' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nickController,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_circle),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Introduce tu usuario';
                        }
                        if (value.length < 3) {
                          return 'El usuario debe tener al menos 3 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
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
                    Card(
                      elevation: 1,
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _optionalDataExpanded = expanded;
                          });
                        },
                        title: const Text(
                          'Datos adicionales',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _optionalDataExpanded
                              ? 'Edad y Altura para IMC/MVP'
                              : 'Edad y Altura (no obligatorios)',
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
                                          'Para habilitar el cálculo de IMC, MVP y métricas de salud, indica Edad y Altura (en centímetros).',
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
                                  decoration: const InputDecoration(
                                    labelText: 'Edad',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.cake_outlined),
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return null;
                                    }
                                    final parsed = int.tryParse(value!.trim());
                                    if (parsed == null ||
                                        parsed <= 0 ||
                                        parsed > 120) {
                                      return 'Edad no válida';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _alturaController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Altura (cm)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.height),
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return null;
                                    }
                                    final parsed = int.tryParse(value!.trim());
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
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
                          return 'Introduce una contraseña';
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
                        labelText: 'Confirmar Contraseña',
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
                      validator: (value) =>
                          value!.isEmpty ? 'Confirma tu contraseña' : null,
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: const Text('Crear cuenta'),
                          ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('login'),
                      child: const Text('¿Ya tienes cuenta? Inicia sesión'),
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
