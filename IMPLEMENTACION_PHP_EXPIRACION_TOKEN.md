# Guía de Implementación PHP - Expiración de Token y Nuevas Funcionalidades

## Resumen

Se han creado los archivos necesarios para implementar la expiración de token parametrizada y las funcionalidades de administración de usuarios.

## Archivos Creados

### 1. **parametros_expiracion_token.sql**
Ubicación: `D:\Git\Flutter\Nutricion\parametros_expiracion_token.sql`

**Contiene:**
- Parámetros de expiración de token por tipo de usuario:
  - `horas_caducidad_token_nutricionista` = 8 horas
  - `horas_caducidad_token_paciente` = 4 horas
  - `horas_caducidad_token_usuario` = 2 horas
  - `horas_caducidad_token_invitado` = 0 (sin expiración)
  
- Modificación de tabla `usuarios` para incluir tipo 'Usuario'
- Modificación de tabla `sesiones` para incluir `fecha_creacion` y `tipo_usuario`
- Procedimiento almacenado `sp_verificar_token_expirado`
- Función `fn_tiempo_restante_token`

**Ejecución:**
```bash
mysql -u tu_usuario -p nombre_base_datos < parametros_expiracion_token.sql
```

### 2. **auth_v2.php**
Ubicación: `D:\Git\Flutter\Nutricion\php_api\auth\auth_v2.php`

**Funcionalidades:**
- `get_auth_token()` - Extrae token del header Authorization
- `get_token_expiration_hours()` - Obtiene horas de validez según tipo de usuario desde parámetros
- `validate_token_with_expiration()` - Valida token con expiración parametrizada
- `verificar_token()` - Función principal que termina con 401 si el token es inválido
- `get_authenticated_user()` - Obtiene usuario sin terminar ejecución

**Uso en endpoints:**
```php
require_once '../auth/auth_v2.php';

// Verificar autenticación (termina con 401 si falla)
$user = verificar_token();

// Ahora puedes usar $user['codigo'], $user['tipo'], etc.
```

### 3. **usuarios_admin.php**
Ubicación: `D:\Git\Flutter\Nutricion\php_api\api\usuarios_admin.php`

**Endpoints implementados:**

#### Revocar Token (POST)
```
POST /php_api/api/usuarios_admin.php
Authorization: Bearer <token_admin>
Content-Type: application/json

{
  "action": "revoke_token",
  "codigo_usuario": 5
}

Respuesta exitosa:
{
  "success": true,
  "message": "Token(s) revocado(s) exitosamente",
  "sessions_closed": 2
}
```

#### Desactivar Usuario (POST)
```
POST /php_api/api/usuarios_admin.php
Authorization: Bearer <token_admin>
Content-Type: application/json

{
  "action": "deactivate",
  "codigo_usuario": 5
}

Respuesta exitosa:
{
  "success": true,
  "message": "Usuario desactivado exitosamente"
}
```

**Seguridad:**
- Solo usuarios con tipo 'Nutricionista' pueden ejecutar estas acciones
- Responde con 403 Forbidden si el usuario no es administrador

## Actualización de Endpoints Existentes

Para que los endpoints existentes utilicen la nueva validación de expiración, debes:

### Opción 1: Reemplazar auth.php con auth_v2.php

```bash
# Backup del auth.php original
cp php_api/auth/auth.php php_api/auth/auth_old.php

# Copiar auth_v2 como auth
cp php_api/auth/auth_v2.php php_api/auth/auth.php
```

### Opción 2: Actualizar endpoints individualmente

En cada endpoint PHP que requiera autenticación, cambiar:

```php
// Antes
require_once '../auth/auth.php';

// Después
require_once '../auth/auth_v2.php';
$user = verificar_token();
```

## Actualización de ApiService en Flutter

Ya se han agregado los métodos necesarios:

```dart
// Revocar token
Future<bool> revokeUserToken(int codigoUsuario) async

// Desactivar usuario
Future<bool> deactivateUser(int codigoUsuario) async
```

**Nota:** Necesitas actualizar la URL base en estos métodos:

```dart
Uri.parse('${_baseUrl}api/usuarios.php')  // ❌ Incorrecto
Uri.parse('${_baseUrl}api/usuarios_admin.php')  // ✅ Correcto
```

## Verificación de Implementación

### 1. Verificar parámetros en base de datos
```sql
SELECT * FROM parametros_usuario WHERE nombre LIKE 'horas_caducidad_token%';
```

### 2. Verificar estructura de tabla sesiones
```sql
DESCRIBE sesiones;
-- Debe tener: fecha_creacion, tipo_usuario
```

### 3. Verificar tipos de usuario
```sql
SHOW COLUMNS FROM usuarios LIKE 'tipo';
-- Debe mostrar ENUM('Nutricionista', 'Paciente', 'Usuario', 'Invitado')
```

### 4. Probar expiración de token

Crear un token de prueba y esperar la expiración:

```sql
-- Insertar sesión de prueba (expira en 10 segundos para testing)
INSERT INTO sesiones (codigo_usuario, token, fecha_creacion, tipo_usuario, activo)
VALUES (1, 'test_token_123', DATE_SUB(NOW(), INTERVAL 10 SECOND), 'Usuario', 'S');

-- Intentar usar el token (debe fallar si pasaron 2 horas o más)
```

### 5. Probar revocar token

```bash
curl -X POST http://localhost:8080/apirestnu/api/usuarios_admin.php \
  -H "Authorization: Bearer <token_admin>" \
  -H "Content-Type: application/json" \
  -d '{"action":"revoke_token","codigo_usuario":5}'
```

### 6. Probar desactivar usuario

```bash
curl -X POST http://localhost:8080/apirestnu/api/usuarios_admin.php \
  -H "Authorization: Bearer <token_admin>" \
  -H "Content-Type: application/json" \
  -d '{"action":"deactivate","codigo_usuario":5}'
```

## Flujo de Expiración de Token

1. **Usuario hace login** → Se crea sesión con `fecha_creacion` y `tipo_usuario`
2. **Usuario hace petición** → auth_v2.php valida el token:
   - Obtiene `tipo_usuario` de la sesión
   - Consulta parámetro `horas_caducidad_token_<tipo>`
   - Si es 'Invitado' o el valor es 0 → Sin expiración
   - Calcula: `fecha_expiracion = fecha_creacion + horas_validez`
   - Si `NOW() > fecha_expiracion` → Desactiva sesión y responde 401
3. **App Flutter recibe 401** → Muestra diálogo de sesión expirada
4. **Usuario hace login nuevamente** → Nuevo token válido

## Actualización de login.php

Asegúrate de que login.php incluya `tipo_usuario` al crear la sesión:

```php
// Al crear sesión en login.php
$stmt = $db->prepare("
    INSERT INTO sesiones (codigo_usuario, token, dispositivo_tipo, dispositivo_info, fecha_creacion, tipo_usuario, activo)
    VALUES (:codigo_usuario, :token, :dispositivo_tipo, :dispositivo_info, NOW(), :tipo_usuario, 'S')
");
$stmt->bindParam(':tipo_usuario', $usuario['tipo']); // <-- IMPORTANTE
```

## Compatibilidad con Invitados

Los usuarios invitados (sin credenciales) tienen `tipo = 'Invitado'` y:
- Su token **NO expira** (horas_caducidad_token_invitado = 0)
- No necesitan reiniciar sesión
- Pueden usar la app indefinidamente hasta que cierren sesión manualmente

## Testing Checklist

- [ ] Ejecutar parametros_expiracion_token.sql
- [ ] Verificar parámetros en base de datos
- [ ] Actualizar login.php para incluir tipo_usuario en sesiones
- [ ] Copiar auth_v2.php como auth.php o actualizar includes
- [ ] Copiar usuarios_admin.php a php_api/api/
- [ ] Actualizar URLs en Flutter ApiService (usuarios.php → usuarios_admin.php)
- [ ] Probar login con diferentes tipos de usuario
- [ ] Esperar expiración y verificar que muestra diálogo
- [ ] Probar botón "Revocar token" desde Flutter
- [ ] Probar botón "Desactivar usuario" desde Flutter
- [ ] Verificar que invitados no tienen expiración
- [ ] Verificar que el tipo cambia a "Paciente" al asociar paciente

## Próximos Pasos

1. **Aplicar `_validateResponse()` a TODOS los métodos restantes en ApiService**
2. **Actualizar todos los endpoints PHP** para usar auth_v2.php
3. **Testing exhaustivo** con diferentes tipos de usuario
4. **Documentar** en manual de usuario las nuevas funcionalidades de admin

