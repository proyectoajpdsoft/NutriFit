import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/constants/app_constants.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
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
    final errorMessage = error.toString().replaceFirst('Exception: ', '');
    if (_isNetworkError(errorMessage)) {
      return 'Hay algun problema con la conexion a Internet o la app no tiene permisos para conectarse.';
    }
    return kDebugMode ? errorMessage : 'Inicio de sesion incorrecto';
  }

  String _buildGuestErrorMessage(dynamic error) {
    final errorMessage = error.toString().replaceFirst('Exception: ', '');
    if (_isNetworkError(errorMessage)) {
      return 'Hay algun problema con la conexion a Internet o la app no tiene permisos para conectarse.';
    }
    return kDebugMode
        ? errorMessage
        : 'No se pudo acceder como invitado. Intentalo de nuevo.';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userType = await authService.login(
          _nickController.text, _passwordController.text);

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

  Future<void> _submitAsGuest() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.loginAsGuest();

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('NutriFit',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(width: 6),
                    Text(
                      AppConstants.appVersion,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
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
                                    'Acceda a NutriFit gratis para consultar consejos de salud, de nutrición, vídeos de ejercicios físicos, recetas de cocina, lista de la compra, registro de actividades, etc.',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
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
                          OutlinedButton(
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/register'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: const Text('Regístrate gratis'),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
