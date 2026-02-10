import 'package:flutter/material.dart';
import 'package:nutri_app/exceptions/auth_exceptions.dart';
import 'package:nutri_app/services/auth_service.dart';

/// Manejador global de errores de autenticación
/// Captura TokenExpiredException y muestra un diálogo amable al usuario
class AuthErrorHandler {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void handleAuthError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onSessionCleared,
  }) {
    if (error is TokenExpiredException) {
      _redirectToLogin(onSessionCleared: onSessionCleared);
    } else if (error is UnauthorizedException) {
      _redirectToLogin(onSessionCleared: onSessionCleared);
    }
  }

  static void handleAuthErrorGlobal(
    dynamic error, {
    VoidCallback? onSessionCleared,
  }) {
    if (error is TokenExpiredException || error is UnauthorizedException) {
      _redirectToLogin(onSessionCleared: onSessionCleared);
    }
  }

  static void _redirectToLogin({
    VoidCallback? onSessionCleared,
  }) async {
    // Limpia la sesión
    await AuthService().logout();
    if (onSessionCleared != null) {
      onSessionCleared();
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil('login', (route) => false);

    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content:
              Text('Tu sesión ha caducado, por favor, vuelve a iniciar sesión'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
}
