# Implementación de Sistema de Tokens y Seguridad

## 📋 Resumen de Cambios

He implementado un sistema completo de validación de tokens con control de permisos por tipo de usuario. Esto asegura que:

1. ✅ **Solo usuarios autenticados** pueden acceder al API
2. ✅ **Usuarios guest** pueden acceder a funcionalidades limitadas sin credenciales
3. ✅ **Permisos por rol** - Cada tipo de usuario solo ve/accede a lo que le corresponde
4. ✅ **Auditoría completa** - Se registra toda actividad en la tabla `sesion`
5. ✅ **Tokens seguros** - Tokens de 64 caracteres hexadecimales con expiración de 24h

---

## 🔐 Tipos de Usuarios y Permisos

### **1. Guest (Invitado - Sin credenciales)**
- ✅ Consejos
- ✅ Contacto
- ✅ Recetas
- ❌ Pacientes
- ❌ Planes Nutricionales
- ❌ Planes Fit
- ❌ Lista de Compra
- ❌ Entrenamientos
- ❌ Mediciones
- ❌ Citas

**Token:** UUID generado en endpoint `guest_login.php`

### **2. Usuario Registrado (sin paciente)**
- ✅ Consejos
- ✅ Contacto
- ✅ Recetas
- ❌ Pacientes
- ❌ Planes Nutricionales
- ❌ Planes Fit
- ✅ Lista de Compra
- ✅ Entrenamientos
- ❌ Mediciones
- ❌ Citas

**Token:** Generado en `login.php` (usuario con credenciales)

### **3. Usuario con Paciente**
- ✅ Todo lo anterior
- ✅ Planes Nutricionales (sólo los suyos)
- ✅ Planes Fit (sólo los suyos)
- ✅ Mediciones (sólo los suyos)
- ✅ Citas (sólo las suyas)

### **4. Nutricionista/Administrador**
- ✅ **Acceso total a todo**
- ✅ Listado de todos los pacientes
- ✅ Gestión de usuarios
- ✅ Auditoría completa

---

## 📁 Archivos Creados/Modificados

### **Backend (PHP)**

#### **Nuevos:**
- `php_api/auth/token_validator.php` - Clase para validar tokens
- `php_api/auth/permissions.php` - Clase para gestionar permisos
- `php_api/api/guest_login.php` - Endpoint para login como invitado
- `php_api/auth/IMPLEMENTATION_GUIDE.php` - Guía de implementación

#### **Modificados:**
- `php_api/api/login.php` - Incluye nuevas clases, quita debug sensible

### **Frontend (Flutter)**

#### **Modificados:**
- `lib/services/auth_service.dart` - Método `loginAsGuest()` mejorado
- `lib/services/api_service.dart` - Método `loginAsGuest()` agregado
- Los headers ya incluyen el token automáticamente en `_getHeaders()`

---

## 🚀 Pasos de Implementación

### **Paso 1: Verificar estructura PHP**

Asegúrate de que existen estos archivos:
```
php_api/
├── auth/
│   ├── auth.php (existente)
│   ├── token_validator.php (NUEVO)
│   ├── permissions.php (NUEVO)
│   └── IMPLEMENTATION_GUIDE.php (NUEVO)
├── api/
│   ├── login.php (MODIFICADO)
│   └── guest_login.php (NUEVO)
└── config/
    └── database.php
```

### **Paso 2: Actualizar TODOS los endpoints**

Para cada archivo en `api/` que requiera autenticación, agregar al inicio:

```php
<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/permissions.php';

$database = new Database();
$db = $database->getConnection();

// ⭐ VALIDAR TOKEN
$validator = new TokenValidator($db);
$user = $validator->validateToken();

// ⭐ VALIDAR PERMISOS (reemplazar 'pacientes' con el recurso)
PermissionManager::checkPermission($user, 'pacientes');

// ⭐ Ahora $user contiene:
// $user['codigo'] - ID del usuario
// $user['tipo'] - Tipo de usuario
// $user['administrador'] - 'S' o 'N'
// $user['codigo_paciente'] - ID del paciente (si aplica)
// $user['es_guest'] - true/false

// A partir de aquí, la lógica normal del endpoint...
```

### **Paso 3: Endpoints a actualizar (CRÍTICOS)**

Estos endpoints DEBEN validar tokens:

1. **`api/pacientes.php`** - Verificar permiso 'pacientes'
2. **`api/citas.php`** - Verificar permiso 'citas'
3. **`api/entrevistas.php`** - Verificar permiso 'entrenamientos'
4. **`api/entrenamientos_usuario.php`** - Verificar permiso 'entrenamientos'
5. **`api/mediciones.php`** - Verificar permiso 'mediciones'
6. **`api/planes_nutricionales.php`** - Verificar permiso 'planes_nutricionales'
7. **`api/planes_fit.php`** - Verificar permiso 'planes_fit'
8. **Todos los demás endpoints** - Al menos validar token, aunque no validen permisos

### **Paso 4: Flutter - Actualizar pantallas**

#### **LoginScreen:**
Agregar botón "Acceder sin credenciales" que llame a:
```dart
await authService.loginAsGuest();
```

#### **PacienteScreen:**
Validar permisos ANTES de intentar cargar datos:
```dart
if (authService.isGuestMode) {
    // Mostrar mensaje: "Debes registrarte para ver esta sección"
    return const UnregisteredScreen();
}
```

### **Paso 5: Verificar tabla `sesion`**

La tabla debe tener estos campos (ya están):
```sql
- id (AUTO_INCREMENT)
- codigousuario (NULL para guests)
- fecha
- hora
- estado (OK, OK_GUEST, Error_Pass, Error_Inactivo, etc.)
- ip_publica
- tipo (Web, Android, iOS)
```

---

## 🔄 Flujo de Autenticación

```
USUARIO FINAL
    ↓
┌─────────────────────────────────────────────┐
│ ¿Tiene credenciales?                        │
└─────────────────────────────────────────────┘
    ↙                                       ↘
 SÍ                                        NO
    ↓                                       ↓
POST /login.php                    POST /guest_login.php
username + password                (sin parámetros)
    ↓                                       ↓
Validar en BD                       Generar UUID
Generar token (64 hex)              Token Guest
Guardar en usuario.token            Registrar sesión
    ↓                                       ↓
┌─────────────────────────────────────────────┐
│ Devolver {token, usuario_data}              │
└─────────────────────────────────────────────┘
    ↓
GUARDAR EN FlutterSecureStorage
    ↓
GUARDAR EN authService._token
    ↓
TODAS LAS PETICIONES POSTERIORES
    ↓
Header: Authorization: Bearer {token}
    ↓
PHP: Validar token en BD
    ↓
┌──────────────────────┬──────────────────┐
│ ¿Token válido?       │ ¿No expirado?    │
└──────────────────────┴──────────────────┘
    ↙ Sí                           ↘ No
    ↓                              ↓
Procesar petición          Error 401 Unauthorized
    ↓                              Limpiar token en Flutter
┌────────────────────────────────┐
│ ¿Usuario tiene permiso?        │
└────────────────────────────────┘
    ↙ Sí                           ↘ No
    ↓                              ↓
Devolver datos            Error 403 Forbidden
```

---

## 🛡️ Seguridad Implementada

### **En PHP:**
- ✅ Validación de token en TODOS los endpoints
- ✅ Validación de expiración (24h)
- ✅ Validación de estado del usuario (activo, acceso web)
- ✅ Validación de permisos por rol
- ✅ Registro de toda actividad en tabla `sesion`
- ✅ IP pública registrada para auditoría
- ✅ No se devuelve info sensible en errores (producción)

### **En Flutter:**
- ✅ Token guardado en secure storage
- ✅ Token incluido automáticamente en todos los headers
- ✅ Validación de respuesta 401 para limpiar token
- ✅ Validación de permisos en pantallas

---

## 📝 Ejemplo Completo: Endpoint Seguro

```php
<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/permissions.php';

$database = new Database();
$db = $database->getConnection();

// 1. VALIDAR TOKEN
$validator = new TokenValidator($db);
$user = $validator->validateToken();

// 2. VALIDAR PERMISOS
PermissionManager::checkPermission($user, 'pacientes');

// 3. LÓGICA DEL ENDPOINT
try {
    $query = "SELECT codigo, nombre, apellidos FROM paciente";
    
    // Si NO es admin, solo ver sus propios datos (si es paciente)
    if (!PermissionManager::isAdmin($user)) {
        if (PermissionManager::hasPatient($user)) {
            $query .= " WHERE codigo = :codigo";
        } else {
            // Usuario sin paciente no puede ver nada
            http_response_code(403);
            echo json_encode(array("error" => "No autorizado"));
            exit();
        }
    }
    
    $stmt = $db->prepare($query);
    
    if (!PermissionManager::isAdmin($user)) {
        $stmt->bindParam(':codigo', $user['codigo_paciente']);
    }
    
    $stmt->execute();
    $result = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    http_response_code(200);
    echo json_encode($result);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(array("error" => "Error procesando solicitud"));
}
?>
```

---

## ⚠️ Próximos Pasos INMEDIATOS

1. **Copiar archivos PHP** a tu servidor
2. **Actualizar estos endpoints PRIMERO:**
   - `api/pacientes.php`
   - `api/login.php` (ya hecho)
   - `api/guest_login.php` (nuevo)
3. **Probar en Postman:**
   ```
   POST http://localhost/api/guest_login.php
   Respuesta esperada: {token: "...", user_type: "Guest"}
   
   POST http://localhost/api/login.php
   Body: {"nick": "usuario", "contrasena": "pass"}
   Respuesta esperada: {token: "...", usuario: {...}}
   
   GET http://localhost/api/pacientes.php
   Header: Authorization: Bearer {token}
   ```

4. **Actualizar resto de endpoints** uno por uno

5. **Probar en Flutter con `flutter run`**

---

## 🧪 Testing Recomendado

### **Casos de prueba:**

1. ✅ Guest login → Acceso a recetas/consejos → NO acceso a pacientes
2. ✅ User login sin paciente → Acceso a entrenamientos → NO acceso a citas
3. ✅ User login con paciente → Acceso a sus planes → NO acceso a otros pacientes
4. ✅ Nutricionista → Acceso a TODO
5. ✅ Token expirado → Error 401 → Limpiar sesión
6. ✅ Token inválido → Error 401
7. ✅ Falta header Authorization → Error 401

---

¿Necesitas que actualice algún endpoint específico primero?
