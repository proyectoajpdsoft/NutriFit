/// Excepción personalizada para cuando el token ha expirado
class TokenExpiredException implements Exception {
  final String message;
  final dynamic originalError;

  TokenExpiredException({
    this.message =
        'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.',
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Excepción personalizada para errores de autenticación
class UnauthorizedException implements Exception {
  final String message;
  final dynamic originalError;

  UnauthorizedException({
    this.message = 'No tienes permiso para acceder a este recurso.',
    this.originalError,
  });

  @override
  String toString() => message;
}
