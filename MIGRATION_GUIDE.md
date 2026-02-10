# Refactorización de Tablas: Paciente → Usuario

## Resumen del Cambio

Se ha realizado una refactorización importante del sistema de "me gusta" y "favoritos" para pasar de un modelo basado en `codigo_paciente` a un modelo basado en `codigo_usuario`. Esto soluciona el problema de sincronización cuando los usuarios se cierran y vuelven a entrar.

## Cambios Realizados

### 1. Base de Datos
- **Nueva tabla**: `nu_consejo_usuario` (reemplaza `nu_consejo_paciente`)
- **Nueva tabla**: `nu_receta_usuario` (reemplaza `nu_receta_paciente`)

### 2. Backend PHP
- **Nuevo endpoint**: `consejo_usuarios.php` (reemplaza `consejo_pacientes.php`)
- **Nuevo endpoint**: `receta_usuarios.php` (reemplaza `receta_pacientes.php`)

### 3. Frontend Flutter
- Todos los endpoints cambian de `consejo_pacientes.php` → `consejo_usuarios.php`
- Todos los endpoints cambian de `receta_pacientes.php` → `receta_usuarios.php`
- Se usa `codigo_usuario` en lugar de `codigo_paciente`

## Instrucciones de Migración

### Paso 1: Ejecutar el Script de Migración
Accede a tu servidor y ejecuta:
```
http://tu-servidor/php_api/migrate_to_usuario_tables.php
```

O si prefieres hacerlo manualmente con SQL:
```sql
-- Crear tabla nu_consejo_usuario
CREATE TABLE IF NOT EXISTS nu_consejo_usuario (
    codigo INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    codigo_consejo INT NOT NULL,
    codigo_usuario INT NOT NULL,
    me_gusta CHAR(1) DEFAULT 'N',
    favorito CHAR(1) DEFAULT 'N',
    leido CHAR(1) DEFAULT 'N',
    fecha_me_gusta DATETIME NULL,
    fecha_favorito DATETIME NULL,
    fechaa DATETIME DEFAULT CURRENT_TIMESTAMP,
    codusuarioa INT DEFAULT 1,
    fecham DATETIME NULL,
    codusuariom INT NULL,
    UNIQUE KEY unique_consejo_usuario (codigo_consejo, codigo_usuario),
    FOREIGN KEY (codigo_consejo) REFERENCES nu_consejo(codigo) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (codigo_usuario) REFERENCES usuario(codigo) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Crear tabla nu_receta_usuario
CREATE TABLE IF NOT EXISTS nu_receta_usuario (
    codigo INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    codigo_receta INT NOT NULL,
    codigo_usuario INT NOT NULL,
    me_gusta CHAR(1) DEFAULT 'N',
    favorito CHAR(1) DEFAULT 'N',
    leido CHAR(1) DEFAULT 'N',
    fecha_me_gusta DATETIME NULL,
    fecha_favorito DATETIME NULL,
    fechaa DATETIME DEFAULT CURRENT_TIMESTAMP,
    codusuarioa INT DEFAULT 1,
    fecham DATETIME NULL,
    codusuariom INT NULL,
    UNIQUE KEY unique_receta_usuario (codigo_receta, codigo_usuario),
    FOREIGN KEY (codigo_receta) REFERENCES nu_receta(codigo) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (codigo_usuario) REFERENCES usuario(codigo) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Migrar datos de nu_consejo_paciente a nu_consejo_usuario
INSERT INTO nu_consejo_usuario (codigo_consejo, codigo_usuario, me_gusta, favorito, leido, fecha_me_gusta, fecha_favorito, fechaa, codusuarioa)
SELECT 
    ncp.codigo_consejo,
    np.codigo_usuario,
    ncp.me_gusta,
    ncp.favorito,
    ncp.leido,
    ncp.fecha_me_gusta,
    ncp.fecha_favorito,
    ncp.fechaa,
    ncp.codusuarioa
FROM nu_consejo_paciente ncp
INNER JOIN nu_paciente np ON ncp.codigo_paciente = np.codigo
WHERE ncp.codigo_paciente IS NOT NULL
ON DUPLICATE KEY UPDATE
    me_gusta = VALUES(me_gusta),
    favorito = VALUES(favorito),
    leido = VALUES(leido);

-- Migrar datos de nu_receta_paciente a nu_receta_usuario
INSERT INTO nu_receta_usuario (codigo_receta, codigo_usuario, me_gusta, favorito, leido, fecha_me_gusta, fecha_favorito, fechaa, codusuarioa)
SELECT 
    nrp.codigo_receta,
    np.codigo_usuario,
    nrp.me_gusta,
    nrp.favorito,
    nrp.leido,
    nrp.fecha_me_gusta,
    nrp.fecha_favorito,
    nrp.fechaa,
    nrp.codusuarioa
FROM nu_receta_paciente nrp
INNER JOIN nu_paciente np ON nrp.codigo_paciente = np.codigo
WHERE nrp.codigo_paciente IS NOT NULL
ON DUPLICATE KEY UPDATE
    me_gusta = VALUES(me_gusta),
    favorito = VALUES(favorito),
    leido = VALUES(leido);
```

### Paso 2: Verificar la Migración
Ejecuta este script para verificar que todo está correcto:
```
http://tu-servidor/php_api/check_migration_status.php
```

### Paso 3: Recargar la App Flutter
1. Haz un `flutter clean`
2. Haz un `flutter pub get`
3. Ejecuta la app nuevamente

### Paso 4 (Opcional): Eliminar Tablas Antiguas
Una vez verificado que todo funciona correctamente, puedes eliminar las tablas antiguas:
```sql
DROP TABLE IF EXISTS nu_consejo_paciente;
DROP TABLE IF EXISTS nu_receta_paciente;
```

## Ventajas del Nuevo Sistema

✅ **Sin NULL**: El `codigo_usuario` siempre existe para usuarios registrados
✅ **Sincronización correcta**: Los datos se cargan correctamente al recargar la app
✅ **Sin ambigüedades**: Un usuario siempre es un usuario, no depende de si tiene paciente
✅ **Mejor rendimiento**: Las búsquedas son más simples sin operadores NULL-safe
✅ **Cobertura total**: Todos los usuarios registrados pueden dar like/favorito, independientemente de si tienen paciente asignado

## Estructura de las Nuevas Tablas

### nu_consejo_usuario
```
codigo (PK)
codigo_consejo (FK → nu_consejo)
codigo_usuario (FK → usuario) ← KEY CHANGE
me_gusta (S/N)
favorito (S/N)
leido (S/N)
fecha_me_gusta
fecha_favorito
fechaa
codusuarioa
fecham
codusuariom
```

### nu_receta_usuario
```
codigo (PK)
codigo_receta (FK → nu_receta)
codigo_usuario (FK → usuario) ← KEY CHANGE
me_gusta (S/N)
favorito (S/N)
leido (S/N)
fecha_me_gusta
fecha_favorito
fechaa
codusuarioa
fecham
codusuariom
```

## Archivos Modificados

### Backend
- ✅ Creado: `php_api/api/consejo_usuarios.php`
- ✅ Creado: `php_api/api/receta_usuarios.php`
- ✅ Creado: `php_api/migrate_to_usuario_tables.php`

### Frontend
- ✅ Actualizado: `consejos_paciente_screen.dart`
- ✅ Actualizado: `recetas_paciente_screen.dart`

## Pruebas Recomendadas

1. **Usuario con paciente asignado**:
   - Da like a un consejo
   - Recarga la app
   - Verifica que el icono sigue mostrando el like

2. **Usuario sin paciente asignado**:
   - Da like a un consejo
   - Recarga la app
   - Verifica que el icono sigue mostrando el like

3. **Favoritos**:
   - Agrega un consejo/receta a favoritos
   - Recarga la app
   - Verifica que aparece en la pestaña "Favoritos"

## Rollback (si es necesario)

Si necesitas volver atrás:
```sql
-- Restaurar datos desde las nuevas tablas (si las eliminas por error)
INSERT INTO nu_consejo_paciente (...)
SELECT ... FROM nu_consejo_usuario WHERE ...;
```

## Soporte

Si encuentras problemas durante la migración, revisa:
1. Los logs de PHP en `php_api/logs/`
2. Los logs de Flutter en la consola
3. Que la tabla `usuario` existe y tiene el campo `codigo`
4. Que la tabla `nu_paciente` tiene el campo `codigo_usuario`
