# Implementación de Manejo de Expiración de Token

## Resumen

Se ha implementado un sistema integral para manejar la expiración de tokens cuando el usuario está usando la aplicación. Ahora, en lugar de mostrar un error técnico crudo como `"Error: Exception: Error al cargar citas (Código: 401). Respuesta: {"error":"Token inválido o expirado","code":"INVALID_TOKEN"}"`, la app mostrará un diálogo amable indicando al usuario que su sesión ha expirado.

## Cambios Implementados

### 1. **lib/exceptions/auth_exceptions.dart** (CREADO)
Define excepciones personalizadas para errores de autenticación:
- `TokenExpiredException`: Lanzada cuando el token ha expirado (401 + code: INVALID_TOKEN)
- `UnauthorizedException`: Lanzada para otros errores de autenticación 401

### 2. **lib/services/api_service.dart** (MODIFICADO)
- Agregado método `_validateResponse()` que:
  - Detecta respuestas HTTP 401
  - Parsea el JSON para encontrar `code: "INVALID_TOKEN"`
  - Lanza `TokenExpiredException` si el token expiró
  - Lanza `UnauthorizedException` para otros 401
  
- Actualizado en los siguientes métodos para llamar a `_validateResponse()`:
  - `getCitas()` - Cargar citas del paciente
  - `getPacientes()` - Cargar lista de pacientes
  - `getEntrevistas()` - Cargar entrevistas
  - `getRevisiones()` - Cargar revisiones

### 3. **lib/services/auth_error_handler.dart** (CREADO)
Manejador global de errores de autenticación:
- `AuthErrorHandler.handleAuthError()` - Método estático que detecta qué tipo de error es
- `_showTokenExpiredDialog()` - Muestra diálogo amable cuando expira el token
  - Mensaje: "Tu sesión ha expirado. Por favor, inicia sesión nuevamente."
  - Botón: "Iniciar sesión" que limpia la sesión y navega al LoginScreen
- `_showUnauthorizedDialog()` - Muestra diálogo para errores de permiso

### 4. **lib/mixins/auth_error_handler_mixin.dart** (CREADO)
Mixin reutilizable para pantallas que necesitan manejar errores de autenticación:
```dart
class MyScreen extends StatefulWidget with AuthErrorHandlerMixin {
  // Usar: handleAuthError(error) en bloques catch
}
```

### 5. **lib/screens/citas/citas_list_screen.dart** (MODIFICADO)
- Agregado mixin `AuthErrorHandlerMixin`
- Actualizado `FutureBuilder` para manejar `TokenExpiredException` en el snapshot de error
- Actualizado método `_deleteCita()` para capturar y manejar errores de autenticación

### 6. **lib/screens/home_screen.dart** (MODIFICADO)
- Agregado mixin `AuthErrorHandlerMixin`
- Actualizado `_loadPendingCounts()` para capturar y manejar errores de autenticación

## Flujo de Error Actual

1. **Usuario**: Realiza una acción (cargar citas, eliminar cita, etc.)
2. **ApiService**: Hace la llamada HTTP y recibe 401 INVALID_TOKEN
3. **_validateResponse()**: Detecta el error y lanza `TokenExpiredException`
4. **Pantalla**: Captura la excepción en try-catch o FutureBuilder
5. **handleAuthError()**: Muestra el diálogo amable
6. **Usuario**: Ve mensaje "Tu sesión ha expirado" y puede hacer clic en "Iniciar sesión"
7. **AuthService.logout()**: Limpia el token del storage
8. **LoginScreen**: Se muestra automáticamente

## Integración en Otras Pantallas

Para que otras pantallas también manejen la expiración de token, siga estos pasos:

### Para FutureBuilder:
```dart
// 1. Agregar mixin a la clase State
class _MyScreenState extends State<MyScreen> with AuthErrorHandlerMixin {

  // 2. En el FutureBuilder, manejar el error
  if (snapshot.hasError) {
    if (handleAuthError(snapshot.error)) {
      return const SizedBox.shrink(); // El diálogo se mostró automáticamente
    }
    return Center(child: Text('Error: ${snapshot.error}'));
  }
}
```

### Para Try-Catch:
```dart
try {
  final data = await apiService.getPacientes();
  // ...
} catch (e) {
  if (!handleAuthError(e)) {
    // Si no es error de autenticación, mostrar otro error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

## Métodos de ApiService Protegidos Actualmente

Los siguientes métodos ahora tienen protección contra token expirado:
- ✅ `getCitas()` - Carga de citas
- ✅ `getPacientes()` - Carga de pacientes
- ✅ `getEntrevistas()` - Carga de entrevistas
- ✅ `getRevisiones()` - Carga de revisiones
- ⏳ Otros métodos GET/POST/PUT/DELETE (pueden agregarse según sea necesario)

## Pantallas Actualizadas para Mostrar Diálogo

- ✅ CitasListScreen - Maneja en FutureBuilder y _deleteCita()
- ✅ HomeScreen - Maneja en _loadPendingCounts()
- ⏳ PacientesListScreen - Puede agregarse
- ⏳ Otras pantallas - Pueden agregarse siguiendo el mismo patrón

## Prueba Manual

Para verificar que funciona:

1. Inicia la app con una cuenta válida
2. Navega a una pantalla que cargue datos (ej: Citas)
3. Espera a que se cargue
4. Elimina el token manualmente con:
   ```dart
   final storage = const FlutterSecureStorage();
   await storage.delete(key: 'authToken');
   ```
5. Intenta cargar datos nuevamente
6. Deberías ver el diálogo "Tu sesión ha expirado"

## Próximos Pasos (Futuro)

- [ ] Agregar protección a todos los métodos GET/POST/PUT/DELETE en ApiService
- [ ] Crear token expiration parametrizada por tipo de usuario (8h admin, 4h paciente, etc.)
- [ ] Implementar refresh token automático
- [ ] Agregar admin controls: "Revocar token" y "Desactivar usuario"
- [ ] Extender user types para incluir "Usuario" además de "Nutricionista" y "Paciente"

