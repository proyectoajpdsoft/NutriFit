# Sistema de Notificaciones de Consejos Leídos

## Descripción General
Se ha implementado un sistema de notificaciones que permite a los pacientes ver y marcar como leídos los consejos destacados (con "Mostrar en portada" activo).

## Cambios Realizados

### 1. Base de Datos
**Archivo:** `consejos_leido_update.sql`

Se agregó el campo `leido` a la tabla `nu_consejo_paciente`:
- Tipo: `varchar(1)`
- Valores: 'S' (leído) / 'N' (no leído)
- Por defecto: 'N'
- Índice: `idx_consejo_paciente_leido` para mejorar rendimiento

**Ejecutar:**
```sql
ALTER TABLE `nu_consejo_paciente` 
ADD COLUMN `leido` varchar(1) DEFAULT 'N' AFTER `fecha_me_gusta`;

CREATE INDEX idx_consejo_paciente_leido ON nu_consejo_paciente(leido);
```

### 2. API - Backend (PHP)
**Archivo:** `php_api/api/consejo_pacientes.php`

#### Nuevos Endpoints:

**a) Marcar consejo como leído**
```
POST api/consejo_pacientes.php?marcar_leido=1
Body: {
  "codigo_consejo": int,
  "codigo_paciente": int
}
```
- Marca un consejo como leído para un paciente específico
- Actualiza el campo `leido` a 'S'

**b) Obtener consejos destacados no leídos**
```
GET api/consejo_pacientes.php?destacados_no_leidos=1&paciente={codigo_paciente}
```
- Devuelve los consejos con `mostrar_portada='S'` que no han sido leídos
- Filtra por consejos activos y dentro del rango de fechas
- Incluye imágenes en base64 y total de likes

#### Modificaciones:
- La función `assign_pacientes()` ahora inicializa el campo `leido='N'` al asignar consejos

### 3. Flutter - Frontend

#### Modelo Consejo
No requiere cambios, ya incluye los campos necesarios.

#### Pantalla Home del Paciente
**Archivo:** `nutri_app/lib/screens/paciente_home_screen.dart`

##### Nuevas Características:

**a) Campanita de Notificaciones (AppBar)**
- Icono de campanita (`notifications_outlined`) en la esquina superior derecha
- Badge rojo con número de consejos destacados no leídos
- Al hacer clic, navega a la pantalla de consejos del paciente

**b) Cards de Consejos Destacados**
- Se muestran hasta 3 consejos destacados no leídos
- Ubicación: Debajo del mensaje de bienvenida, antes de los botones
- Diseño atractivo con icono de bombilla dorada
- Al hacer clic:
  - Se marca automáticamente como leído
  - Muestra diálogo con título, imagen y texto completo
  - Opción de ver todos los consejos

##### Nuevos Métodos:
```dart
_loadConsejosDestacados() // Carga consejos destacados no leídos del paciente
_marcarConsejoLeido(int)   // Marca un consejo como leído
_buildConsejoDestacadoCard() // Widget para mostrar card de consejo
```

##### Estados Agregados:
```dart
List<Consejo> _consejosDestacados = []
int _consejosNoLeidos = 0
```

## Flujo de Usuario

### Nutricionista:
1. Crea un consejo
2. Marca "Mostrar en portada" = Sí
3. Asigna pacientes (o marca "Visible para todos")

### Paciente:
1. Ve campanita con número de consejos no leídos en el home
2. Ve cards de consejos destacados debajo del mensaje de bienvenida
3. Al hacer clic en un consejo:
   - Se marca como leído automáticamente
   - Puede leer el contenido completo
4. El contador de la campanita se actualiza automáticamente

## Ventajas
- ✅ Notificaciones visuales claras para el paciente
- ✅ Seguimiento de consejos leídos/no leídos
- ✅ Prioriza consejos destacados en el home
- ✅ UX intuitiva tipo redes sociales
- ✅ Actualización automática de contadores
- ✅ Máximo 3 consejos mostrados para no saturar

## Notas Técnicas
- Los consejos se marcan como leídos al abrirse, no al cerrarse
- Solo se muestran consejos con `mostrar_portada='S'`
- Los consejos respetan fechas de inicio y fin
- La campanita muestra "99+" si hay más de 99 consejos no leídos
- Las imágenes se cargan en base64 para compatibilidad web/móvil
