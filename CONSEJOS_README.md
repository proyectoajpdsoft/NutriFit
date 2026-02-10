# Sistema de Consejos (Tips)

## Descripción
Sistema de publicación de consejos/tips para pacientes con funcionalidades sociales estilo Instagram. Permite a los nutricionistas crear contenido enriquecido con imágenes, documentos y URLs que los pacientes pueden ver y dar "me gusta".

## Características principales

### Para Nutricionistas
- **Crear y editar consejos** con:
  - Título y texto extenso
  - Imagen de portada
  - Período de visualización (fecha inicio/fin)
  - Estado activo/inactivo
  - Marcador de "mostrar en portada" para destacar
  
- **Asignar pacientes específicos** a cada consejo
- **Adjuntar múltiples documentos o URLs** ordenados
- **Ver estadísticas**: total de likes y pacientes asignados
- **Filtrar** por estado (activo/inactivo) y buscar por texto

### Para Pacientes
- **Vista estilo Instagram** con tarjetas visuales
- **Dos pestañas**:
  - **Destacados**: Consejos marcados como portada y dentro del período de visualización
  - **Todos**: Todos los consejos asignados al paciente
  
- **Dar "me gusta"** (corazón rojo) a los consejos
- **Ver contador de likes** en cada consejo
- **Acceder al detalle completo** con:
  - Texto completo
  - Documentos y URLs adjuntos
  - Botón para abrir URLs externas

## Base de datos

### Tabla `nu_consejo`
Almacena los consejos principales con:
- Información básica (título, texto)
- Imagen de portada (BLOB)
- Período de visualización
- Estado y marcador de portada
- Campos de auditoría

### Tabla `nu_consejo_paciente`
Relación muchos a muchos entre consejos y pacientes con:
- Asignación de consejo a paciente
- Campo `me_gusta` ('S'/'N')
- Fecha del me gusta
- Constraint único por consejo+paciente

### Tabla `nu_consejo_documento`
Documentos y URLs adjuntos con:
- Tipo (documento/url)
- Documento (BLOB) o URL (varchar)
- Ordenación
- CASCADE delete/update

## API PHP

### `consejos.php`
- **GET**: Lista todos los consejos con likes y total pacientes
- **GET ?codigo=X**: Obtiene un consejo específico
- **GET ?paciente=X**: Consejos asignados a un paciente
- **GET ?portada=S&paciente_codigo=X**: Consejos destacados activos para un paciente
- **POST**: Crear nuevo consejo
- **PUT**: Actualizar consejo existente
- **DELETE ?codigo=X**: Eliminar consejo

### `consejo_pacientes.php`
- **GET ?consejo=X**: Lista pacientes asignados a un consejo
- **GET ?paciente=X&consejo_codigo=Y**: Obtiene relación específica
- **POST**: Asignar pacientes a un consejo (reemplaza asignaciones previas)
- **POST ?toggle_like=1**: Alternar me gusta de un paciente
- **DELETE ?consejo=X&paciente=Y**: Desasignar paciente

### `consejo_documentos.php`
- **GET ?consejo=X**: Lista documentos de un consejo
- **GET ?codigo=X**: Obtiene un documento específico
- **POST**: Crear nuevo documento/URL
- **PUT**: Actualizar documento/URL
- **DELETE ?codigo=X**: Eliminar documento

## Modelos Dart

### `Consejo`
Propiedades principales:
- `codigo`, `titulo`, `texto`
- `activo`, `fechaInicio`, `fechaFin`, `mostrarPortada`
- `imagenPortada` (Base64), `imagenPortadaNombre`
- `totalLikes`, `totalPacientes`, `meGusta` (para pacientes)

### `ConsejoDocumento`
- `codigo`, `codigoConsejo`, `tipo`
- `nombre`, `documento` (Base64), `url`
- `orden`

## Pantallas Flutter

### Para Nutricionistas

#### `ConsejosListScreen`
- Lista de todos los consejos con filtros
- Búsqueda por texto
- Filtro por estado (todos/activos/inactivos)
- Tarjetas con miniatura, título, likes, pacientes, iconos de estado
- Menú contextual (editar/eliminar)
- Botón FAB para crear nuevo

#### `ConsejoEditScreen`
- Formulario completo de edición
- TextFields para título y texto
- Selector de imagen de portada con preview
- Date pickers para período de visualización
- Switches para activo/portada
- Selector de pacientes con búsqueda
- Lista de documentos/URLs con agregar/eliminar
- Validación de campos requeridos
- Guardado con asignación de pacientes y documentos

### Para Pacientes

#### `ConsejosPacienteScreen`
- Vista principal con TabBar (Destacados/Todos)
- Tarjetas estilo Instagram con:
  - Imagen de portada a pantalla completa
  - Botón de corazón con contador de likes
  - Título y preview de texto
  - Botón "Ver más"
- Pull to refresh en ambas pestañas
- Toggle de like directo desde lista

#### `ConsejoDetailScreen`
- Imagen de portada grande
- Contador de likes
- Título destacado
- Texto completo
- Botón de like en AppBar
- Lista de documentos/URLs con iconos
- Apertura de URLs en navegador externo

## Navegación

### Rutas definidas en main.dart
- `/consejos_list` → ConsejosListScreen (nutricionistas)
- `/consejo_edit` → ConsejoEditScreen (nutricionistas)
- `/consejos_paciente` → ConsejosPacienteScreen (pacientes)

### Accesos en AppDrawer
- **Nutricionistas**: Opción "Consejos" en menú principal
- **Pacientes**: Opción "Consejos" en menú secundario

### Botón en PacienteHomeScreen
- Tarjeta "Consejos" en grid principal con icono de bombilla

## Flujo de uso

### Nutricionista
1. Crear nuevo consejo desde lista o botón FAB
2. Rellenar título, texto, seleccionar imagen
3. Configurar fechas de visualización (opcional)
4. Activar switch de portada para destacar
5. Seleccionar pacientes a los que asignar
6. Agregar documentos PDF o URLs de interés
7. Guardar → se crean todas las asignaciones y documentos

### Paciente
1. Entrar a "Consejos" desde menú o home
2. Ver destacados en pestaña "Destacados"
3. Dar like/unlike con el corazón
4. Tocar "Ver más" o imagen para ver detalle
5. En detalle: leer texto completo, abrir documentos/URLs
6. Cambiar a pestaña "Todos" para ver todo el historial

## Lógica de filtrado

### Consejos destacados para paciente
Se muestran en la pestaña "Destacados" si:
- `activo = 'S'`
- `mostrar_portada = 'S'`
- `fecha_inicio IS NULL` O `fecha_inicio <= HOY`
- `fecha_fin IS NULL` O `fecha_fin >= HOY`
- Asignado al paciente actual

### Todos los consejos para paciente
Se muestran en "Todos" si:
- `activo = 'S'`
- Asignado al paciente actual
- Sin filtro de fechas ni portada

## Seguridad
- Pacientes solo ven consejos asignados a ellos
- API filtra por `codigo_paciente` en todas las consultas
- Nutricionistas tienen acceso completo CRUD
- Toggle like requiere código de consejo + código de paciente válidos

## Mejoras futuras posibles
- Notificaciones push cuando se publica un nuevo consejo destacado
- Comentarios en consejos
- Compartir consejos por WhatsApp/email
- Galería de imágenes múltiples
- Vídeos embebidos (YouTube/Vimeo)
- Categorías de consejos
- Búsqueda por tags
- Estadísticas avanzadas de engagement
