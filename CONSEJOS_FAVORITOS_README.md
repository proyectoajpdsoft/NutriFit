# Sistema de Favoritos para Consejos

## Descripción
Sistema que permite a los pacientes marcar consejos como favoritos y visualizarlos en una pestaña dedicada.

## Cambios en Base de Datos

### Script SQL
Ejecutar el archivo `consejos_favorito_update.sql`:

```sql
ALTER TABLE `nu_consejo_paciente` 
ADD COLUMN `favorito` varchar(1) DEFAULT 'N' AFTER `fecha_me_gusta`,
ADD COLUMN `fecha_favorito` datetime DEFAULT NULL AFTER `favorito`;

CREATE INDEX idx_consejo_paciente_favorito ON nu_consejo_paciente(favorito);
```

## Cambios en API PHP

### Archivo: `php_api/api/consejo_pacientes.php`

**Nuevos endpoints agregados:**

1. **GET con parámetro `favoritos`**: Obtiene los consejos favoritos de un paciente
   - URL: `api/consejo_pacientes.php?favoritos=1&paciente={codigo_paciente}`
   - Respuesta: Array de consejos marcados como favoritos

2. **POST con parámetro `toggle_favorito`**: Marca/desmarca un consejo como favorito
   - URL: `api/consejo_pacientes.php?toggle_favorito=1`
   - Body: `{"codigo_consejo": 3, "codigo_paciente": 31}`
   - Respuesta: `{"message": "Favorito actualizado.", "favorito": "S"}`

**Nuevas funciones:**
- `toggle_favorito()`: Alterna el estado de favorito de un consejo para un paciente
- `get_favoritos($paciente_codigo)`: Obtiene todos los consejos favoritos de un paciente

### Archivo: `php_api/api/consejos.php`

**Modificaciones en consultas SQL:**
- Agregado campo `cp.favorito` en `get_consejos_paciente()`
- Agregado campo `cp.favorito` en `get_consejos_portada_paciente()`

## Cambios en Flutter

### Modelo: `models/consejo.dart`

**Nuevos campos:**
```dart
String? favorito; // 'S' o 'N'
```

### Pantalla: `screens/consejos_paciente_screen.dart`

**Nuevas características:**

1. **Tercer Tab "Favoritos"**:
   - TabController ahora con `length: 3`
   - Nuevo tab con icono `Icons.bookmark`
   - Lista independiente `_consejosFavoritos`

2. **Botón de Favorito en cada tarjeta**:
   - Icono: `Icons.bookmark` (lleno) o `Icons.bookmark_border` (vacío)
   - Color: Amarillo cuando está marcado como favorito
   - Ubicado junto al botón de "me gusta"

3. **Tarjetas completamente clickables**:
   - Toda la tarjeta envuelta en `InkWell`
   - Al hacer tap en cualquier parte se abre el detalle
   - Texto "Toca para ver más" en lugar del botón "Ver más"

4. **Detalle del consejo mejorado**:
   - Botón de favorito en el AppBar
   - Callback `onFavoritoChanged` para actualizar el estado
   - Documentos y URLs mostrados en carrusel horizontal deslizable

**Nuevos métodos:**
- `_loadConsejosFavoritos()`: Carga los consejos favoritos del paciente
- `_toggleFavorito(Consejo consejo)`: Marca/desmarca un consejo como favorito

## Características del Carrusel de Documentos

- **Vista horizontal deslizable**: Los documentos se deslizan de izquierda a derecha
- **Tarjetas de 180px de ancho** con diseño moderno
- **Iconos diferenciados**:
  - 📄 Azul para documentos
  - 🔗 Morado para URLs
- **Vista previa de URL** truncada a 25 caracteres
- **Altura fija de 140px** para mantener consistencia

## Flujo de Usuario

### Marcar como Favorito
1. Usuario ve un consejo en cualquier tab (Destacados o Todos)
2. Toca el icono de bookmark (📖)
3. El icono cambia a bookmark lleno (📕) y se colorea de amarillo
4. El consejo aparece automáticamente en el tab "Favoritos"

### Ver Favoritos
1. Usuario navega al tab "Favoritos"
2. Ve todos sus consejos marcados como favoritos
3. Puede desmarcar tocando nuevamente el icono

### Ver Detalle
1. Usuario toca en cualquier parte de la tarjeta de un consejo
2. Se abre la pantalla de detalle con:
   - Imagen de portada completa
   - Título y texto completo
   - Estadísticas de "me gusta"
   - Carrusel de documentos y URLs (si tiene)
   - Botones de favorito y "me gusta" en el AppBar

## Notas de Implementación

- El campo `favorito` se almacena en `nu_consejo_paciente` (relación consejo-paciente)
- Cada paciente tiene su propia lista de favoritos independiente
- Al marcar/desmarcar favorito se recargan las tres listas (Destacados, Todos, Favoritos)
- El sistema mantiene compatibilidad con el sistema de "me gusta" existente
- Los favoritos se ordenan por fecha de marcado (más recientes primero)

## Testing

1. Ejecutar el script SQL en la base de datos
2. Verificar que los endpoints PHP funcionen correctamente
3. Probar en Flutter:
   - Marcar consejos como favoritos
   - Ver la lista de favoritos
   - Desmarcar favoritos
   - Verificar que el estado persiste al recargar
   - Probar tap en toda la tarjeta para ver detalle
   - Desplazar el carrusel de documentos/URLs
