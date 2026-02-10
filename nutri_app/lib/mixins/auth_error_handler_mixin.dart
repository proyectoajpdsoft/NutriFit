import 'package:flutter/material.dart';
import 'package:nutri_app/exceptions/auth_exceptions.dart';
import 'package:nutri_app/services/auth_error_handler.dart';

/// Mixin para manejar errores de autenticación en pantallas
/// Uso: class MyScreen extends StatefulWidget with AuthErrorHandlerMixin
mixin AuthErrorHandlerMixin<T extends StatefulWidget> on State<T> {
  /// Valida si hay un error de autenticación y muestra el diálogo apropiado
  /// Retorna true si es un error de autenticación (se mostró el diálogo)
  /// Retorna false si no es un error de autenticación
  bool handleAuthError(dynamic error) {
    if (error is TokenExpiredException) {
      AuthErrorHandler.handleAuthError(context, error);
      return true;
    } else if (error is UnauthorizedException) {
      AuthErrorHandler.handleAuthError(context, error);
      return true;
    }
    return false;
  }

  /// Retorna true si el error es un error de autenticación
  bool isAuthError(dynamic error) {
    return error is TokenExpiredException || error is UnauthorizedException;
  }
}
