# Sistema "Visible para Todos" en Consejos

## Descripción
Sistema que permite marcar un consejo como visible para todos los pacientes mediante un campo en la tabla de consejos, en lugar de asignar todos los pacientes manualmente. Esto garantiza que:
- Los pacientes nuevos verán automáticamente estos consejos
- No es necesario actualizar las asignaciones cuando se crean nuevos pacientes
- Se simplifica la gestión de consejos generales

## Cambios en Base de Datos

### Script SQL
Ejecutar el archivo `consejos_visible_para_todos_update.sql`:

```sql
ALTER TABLE `nu_consejo` 
ADD COLUMN `visible_para_todos` varchar(1) DEFAULT 'N' AFTER `mostrar_portada`;

CREATE INDEX idx_consejo_visible_todos ON nu_consejo(visible_para_todos);
```

**Valores:**
- `'S'` = El consejo se muestra a TODOS los pacientes (incluso nuevos)
- `'N'` = El consejo solo se muestra a los pacientes asignados específicamente

## Cambios en API PHP

### Archivo: `php_api/api/consejos.php`

**Función `bind_consejo_params()`:**
- Agregado binding del campo `visible_para_todos`

**Consultas SQL modificadas:**

1. **INSERT**: Agregado campo `visible_para_todos`
2. **UPDATE**: Agregado campo `visible_para_todos`

3. **`get_consejos_paciente()`**: 
   - Cambió de `INNER JOIN` a `LEFT JOIN`
   - Ahora incluye consejos donde:
     - `cp.codigo_paciente = :paciente_codigo` (asignación específica) **O**
     - `c.visible_para_todos = 'S'` (visible para todos)
   - Usa `COALESCE` para campos me_gusta y favorito cuando no hay asignación

4. **`get_consejos_portada_paciente()`**:
   - Cambió de `INNER JOIN` a `LEFT JOIN`
   - Aplica la misma lógica de inclusión
   - Mantiene filtros de destacados y fechas

## Cambios en Flutter

### Modelo: `models/consejo.dart`

**Nuevo campo:**
```dart
String visibleParaTodos; // 'S' o 'N'
```

**Constructor actualizado:**
- Agregado parámetro `visibleParaTodos` con valor por defecto 'N'

**Métodos actualizados:**
- `fromJson()`: Lee `visible_para_todos` del JSON
- `toJson()`: Escribe `visible_para_todos` al JSON

### Pantalla: `screens/consejo_edit_screen.dart`

**Inicialización:**
- Lee el valor de `visibleParaTodos` al cargar un consejo existente
- Convierte 'S'/'N' a `bool` para el checkbox

**Método `_save()`:**
- Establece `_consejo.visibleParaTodos` según el valor del checkbox
- **Solo asigna pacientes específicos si `_visibleParaTodos == false`**
- Si está marcado como visible para todos, NO asigna pacientes individuales

## Flujo de Usuario

### Crear/Editar Consejo

1. **Consejo para pacientes específicos:**
   - Dejar el checkbox "Visible para todos los pacientes" sin marcar
   - Seleccionar pacientes específicos en el diálogo
   - Al guardar: se asignan solo esos pacientes

2. **Consejo para todos los pacientes:**
   - Marcar el checkbox "Visible para todos los pacientes"
   - No es necesario seleccionar pacientes (se ignora la selección)
   - Al guardar: `visible_para_todos = 'S'`, sin asignaciones individuales

### Vista del Paciente

Los pacientes verán:
- Consejos asignados específicamente a ellos
- Consejos marcados como "Visible para todos"
- Pueden dar "me gusta" y marcar como favoritos cualquier consejo que vean

## Ventajas del Sistema

1. ✅ **Automático para nuevos pacientes**: Los pacientes creados después de publicar el consejo lo verán automáticamente
2. ✅ **Menos carga en la BD**: No se crean registros en `nu_consejo_paciente` para consejos generales
3. ✅ **Gestión simplificada**: Un solo campo controla la visibilidad global
4. ✅ **Flexible**: Se pueden combinar consejos generales y específicos
5. ✅ **Retrocompatible**: Los consejos existentes con asignaciones específicas siguen funcionando

## Comportamiento de "Me Gusta" y "Favoritos"

- Los pacientes pueden interactuar con consejos "visibles para todos"
- Al dar "me gusta" o marcar como favorito por primera vez, se crea el registro en `nu_consejo_paciente`
- La consulta usa `LEFT JOIN` y `COALESCE` para manejar consejos sin registro previo

## Casos de Uso

### Caso 1: Consejo general de nutrición
```
Título: "10 Tips para una alimentación saludable"
Visible para todos: ✓ SÍ
Pacientes asignados: (ninguno, se ignora)
Resultado: Todos los pacientes lo ven
```

### Caso 2: Consejo específico post-cirugía
```
Título: "Cuidados después de cirugía bariátrica"
Visible para todos: ☐ NO
Pacientes asignados: María, Juan, Pedro (seleccionados)
Resultado: Solo María, Juan y Pedro lo ven
```

### Caso 3: Cambio de estrategia
```
Un consejo que era específico se puede convertir a "visible para todos":
1. Editar el consejo
2. Marcar "Visible para todos"
3. Guardar
Resultado: Ahora lo ven todos, incluyendo nuevos pacientes
```

## Testing

1. ✅ Ejecutar el script SQL en la base de datos
2. ✅ Crear un consejo con "Visible para todos" marcado
3. ✅ Verificar que NO se crean registros en `nu_consejo_paciente`
4. ✅ Login como paciente existente → debe ver el consejo
5. ✅ Crear un paciente nuevo
6. ✅ Login como el paciente nuevo → debe ver el consejo
7. ✅ Dar "me gusta" → debe crear registro en `nu_consejo_paciente`
8. ✅ Marcar como favorito → debe actualizar el registro
9. ✅ Verificar tab "Favoritos" muestra el consejo
10. ✅ Crear consejo específico para algunos pacientes
11. ✅ Verificar que solo esos pacientes lo ven

## Notas Técnicas

- El campo `visible_para_todos` está en la tabla `nu_consejo` (no en la relación)
- Se usa `DISTINCT` en las consultas SQL para evitar duplicados
- Las consultas verifican ambas condiciones: `(asignación específica) OR (visible para todos)`
- El sistema mantiene compatibilidad con consejos existentes
- Los índices en BD mejoran el rendimiento de las consultas
