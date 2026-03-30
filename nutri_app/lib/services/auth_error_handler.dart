import 'package:flutter/material.dart';
import 'package:nutri_app/exceptions/auth_exceptions.dart';
import 'package:nutri_app/services/auth_service.dart';

/// Manejador global de errores de autenticación
/// Captura TokenExpiredException y muestra un diálogo amable al usuario
class AuthErrorHandler {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static bool _redirectInProgress = false;
  static DateTime? _lastSessionExpiredSnackAt;

  static const Duration _sessionSnackCooldown = Duration(seconds: 20);

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
    // Evita redirecciones/snackbars duplicados cuando llegan varios 401 en paralelo.
    if (_redirectInProgress) {
      return;
    }
    _redirectInProgress = true;

    try {
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
        final now = DateTime.now();
        final canShowSnack = _lastSessionExpiredSnackAt == null ||
            now.difference(_lastSessionExpiredSnackAt!) >=
                _sessionSnackCooldown;

        if (canShowSnack) {
          _lastSessionExpiredSnackAt = now;
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text(
                'Tu sesión ha caducado, por favor, vuelve a iniciar sesión',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      _redirectInProgress = false;
    }
  }
}
