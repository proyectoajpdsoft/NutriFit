# Campo "Kilos" en Ejercicios - Implementación Completa

## Resumen
Se ha añadido exitosamente el campo "kilos" a los ejercicios de las actividades en todo el sistema. Este campo permite a los nutricionistas especificar el peso/carga para cada ejercicio del plan fit, y se muestra en todas las visualizaciones de ejercicios junto con tiempo, repeticiones y descanso.

## Cambios Realizados

### 1. Modelos de Datos (Dart)

#### ✅ `lib/models/plan_fit_ejercicio.dart`
- Añadido campo `int? kilos;`
- Actualizado constructor, fromJson() y toJson()
- El campo se guarda y recupera desde la API

#### ✅ `lib/models/entrenamiento_ejercicio.dart`
- Añadido campo `int? kilosPlan;`
- Actualizado constructor, fromJson() y toJson()
- Mantiene consistencia con el patrón de otros campos (tiempoPlan, repeticionesPlan)

### 2. Base de Datos (SQL)

#### ✅ Script: `alter_ejercicios_add_kilos.sql`
Añade la columna `kilos` o `kilos_plan` a las siguientes tablas:

1. **nu_plan_fit_ejercicios_catalogo** → `kilos INT NULL`
   - Catálogo de ejercicios reutilizables

2. **nu_plan_fit_ejercicio** → `kilos INT NULL`
   - Ejercicios asignados a un plan fit específico

3. **nu_entrenamientos_ejercicios** → `kilos_plan INT NULL`
   - Ejercicios de actividades de usuarios (con plan asignado)

**Ejecutar:** `mysql -u usuario -p base_datos < alter_ejercicios_add_kilos.sql`

### 3. API PHP

#### ✅ `php_api/api/plan_fit_ejercicios.php`
**Cambios:**
- Añadido `kilos` en todas las consultas SELECT
- Añadido `kilos` en INSERT INTO para `nu_plan_fit_ejercicio`
- Añadido `kilos` en INSERT INTO para `nu_plan_fit_ejercicios_catalogo`
- Añadido manejo del campo en `create_ejercicio_plan_fit()`
- Añadido manejo del campo en `update_ejercicio_plan_fit()`
- Añadido manejo del campo en `upsert_catalog_ejercicio()`

**Endpoints afectados:**
- GET `?codigo_plan_fit=X` → Retorna ejercicios con campo kilos
- GET `?catalog=1` → Retorna catálogo con campo kilos
- POST crear ejercicio → Acepta y guarda campo kilos
- POST actualizar ejercicio → Acepta y actualiza campo kilos

#### ✅ `php_api/api/entrenamientos_ejercicios.php`
**Cambios:**
- Añadido `kilos_plan` en todas las consultas SELECT
- Añadido `kilos_plan` en INSERT INTO para `nu_entrenamientos_ejercicios`
- Añadido binding del campo en `save_ejercicios_entrenamiento()`

**Endpoints afectados:**
- GET `?codigo_entrenamiento=X` → Retorna ejercicios con kilos_plan
- POST guardar ejercicios → Acepta y guarda kilos_plan

### 4. Interfaz de Usuario (Flutter)

#### ✅ `lib/screens/planes_fit/plan_fit_edit_screen.dart`
**Alta/Edición de Ejercicios:**
- Añadido campo de entrada `kilos` con input numérico (0-1000 kg)
- Icono: `Icons.fitness_center`
- Input compacto con botones +/- (igual que tiempo/descanso/repeticiones)
- Se muestra en fila junto a "Repeticiones"

**Visualización en Cards:**
- Los ejercicios del plan muestran "Kilos: X" si el valor > 0
- Formato: `'Kilos: $kilos'`
- Se muestra junto a Tiempo y Reps

**Selector de Catálogo:**
- Lista de ejercicios del catálogo muestra kilos si > 0
- Al seleccionar ejercicio del catálogo, copia el valor de kilos

#### ✅ `lib/screens/entrenamientos_pacientes_plan_fit_screen.dart`
**Visualización para Nutricionista:**
- Cards de ejercicios muestran un Chip con el campo kilos si > 0
- Icono: `Icons.fitness_center`
- Formato: `'$kilos kg'`
- Se muestra entre "Tiempo" y "Esfuerzo percibido"

#### ✅ `lib/screens/entrenamiento_edit_screen.dart`
**Copia desde Plan Fit:**
- Al copiar ejercicios desde un Plan Fit, se copia el campo `kilos`
- Mapeo: `kilosPlan: e.kilos`

#### ✅ `lib/screens/entrenamiento_view_screen.dart`
**Visualización para Usuario/Paciente:**
- Los ejercicios muestran kilos si kilosPlan > 0
- Icono: `Icons.fitness_center`
- Formato: `'$kilosPlan kg'`
- Se muestra entre "Tiempo" y "Esfuerzo percibido"

### 5. Flujo de Datos

```
NUTRICIONISTA (Alta Ejercicio)
       ↓
[Plan Fit Ejercicio] → kilos
       ↓
[Catálogo Ejercicios] → kilos (reutilizable)
       ↓
[Copia a Entrenamiento Usuario] → kilosPlan
       ↓
PACIENTE (Visualización) → ve kilos asignados
```

## Validación

- ✅ Sin errores de compilación en Flutter
- ✅ Modelos correctamente mapeados
- ✅ API endpoints actualizados
- ✅ Visualización en todas las pantallas
- ✅ Campo opcional (NULL permitido)

## Ubicación de Visualización

El campo "kilos" se muestra en:

1. **Plan Fit Edit Screen** (Nutricionista)
   - Formulario de alta/edición de ejercicio
   - Lista de ejercicios del plan
   - Selector de catálogo

2. **Entrenamientos Paciente Plan Fit Screen** (Nutricionista)
   - Cards de ejercicios realizados por pacientes
   - Vista de detalle de cada ejercicio

3. **Entrenamiento Edit Screen** (Paciente)
   - Al copiar ejercicios desde plan fit

4. **Entrenamiento View Screen** (Paciente)
   - Visualización de sus ejercicios asignados
   - Junto a tiempo, repeticiones y esfuerzo

## Pasos Post-Implementación

### 1. Ejecutar Script SQL
```bash
mysql -u usuario -p nombre_base_datos < alter_ejercicios_add_kilos.sql
```

### 2. Verificar Columnas
El script incluye verificaciones automáticas que muestran:
- ✓ OK - kilos existe en nu_plan_fit_ejercicios_catalogo
- ✓ OK - kilos existe en nu_plan_fit_ejercicio
- ✓ OK - kilos_plan existe en nu_entrenamientos_ejercicios

### 3. Recompilar Flutter Web
```bash
flutter build web --release
```

### 4. Pruebas Recomendadas
1. Crear un ejercicio nuevo con kilos
2. Reutilizar ejercicio del catálogo (verificar que copia kilos)
3. Asignar plan fit a usuario
4. Verificar que el paciente ve el campo kilos
5. Verificar que nutricionista ve kilos en seguimiento

## Notas Técnicas

- **Tipo de dato:** INT (número entero)
- **Rango permitido:** 0 - 1000 kg
- **Valor por defecto:** NULL (no obligatorio)
- **Icono utilizado:** `Icons.fitness_center`
- **Posición UI:** Entre "Repeticiones/Tiempo" y "Esfuerzo percibido"

## Archivos Modificados

### Dart (Flutter)
- `lib/models/plan_fit_ejercicio.dart`
- `lib/models/entrenamiento_ejercicio.dart`
- `lib/screens/planes_fit/plan_fit_edit_screen.dart`
- `lib/screens/entrenamientos_pacientes_plan_fit_screen.dart`
- `lib/screens/entrenamiento_edit_screen.dart`
- `lib/screens/entrenamiento_view_screen.dart`

### PHP
- `php_api/api/plan_fit_ejercicios.php`
- `php_api/api/entrenamientos_ejercicios.php`

### SQL
- `alter_ejercicios_add_kilos.sql` (nuevo)

## Compatibilidad

✅ **Retrocompatible:** Los ejercicios existentes sin valor de kilos funcionarán normalmente (NULL)

✅ **Sin impacto en datos existentes:** El script SQL usa `ADD COLUMN IF NOT EXISTS` y permite NULL

✅ **API compatible:** Los clientes antiguos pueden ignorar el campo kilos
