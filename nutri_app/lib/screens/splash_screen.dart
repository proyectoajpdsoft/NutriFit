import 'package:flutter/material.dart';
import 'package:nutri_app/screens/home_screen.dart';
import 'package:nutri_app/screens/login_screen.dart';
import 'package:nutri_app/screens/paciente_home_screen.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    try {
      // Pequeño retraso para que la UI se construya antes de navegar
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      final auth = Provider.of<AuthService>(context, listen: false);

      // Esperar a que AuthService termine su inicialización
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;

      if (auth.isLoggedIn || auth.isGuestMode) {
        if (auth.userType == 'Paciente' || auth.userType == 'Guest') {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PacienteHomeScreen()));
        } else {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } else {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } catch (e) {
      // Capturar cualquier error y mostrarlo
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al iniciar la aplicación:\n$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _errorMessage != null
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        _checkLoginState();
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.tertiary,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.health_and_safety,
                        size: 60,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
      ),
    );
  }
}
