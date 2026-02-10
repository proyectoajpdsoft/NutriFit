-- ===================================================================
-- Script para implementar DÍAS y CATEGORÍAS en Planes Fit
-- ===================================================================
-- Este script añade soporte para:
-- 1. Organizar ejercicios por días dentro de un plan fit
-- 2. Categorizar ejercicios (Tren inferior, Tren superior, Core)
-- 3. Permitir múltiples categorías por ejercicio
-- ===================================================================

-- PASO 1: Crear tabla de CATEGORÍAS de ejercicios
-- ===================================================================
CREATE TABLE IF NOT EXISTS nu_plan_fit_categorias (
    codigo INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT NULL,
    orden INT DEFAULT 0,
    activo CHAR(1) DEFAULT 'S',
    codusuarioa INT NULL,
    fechaa DATETIME NULL,
    codusuariom INT NULL,
    fecham DATETIME NULL,
    INDEX idx_nombre (nombre),
    INDEX idx_orden (orden)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertar categorías predefinidas
INSERT IGNORE INTO nu_plan_fit_categorias (nombre, descripcion, orden) VALUES
('Tren inferior', 'Ejercicios de piernas, glúteos y pantorrillas', 1),
('Tren superior', 'Ejercicios de pecho, espalda, hombros y brazos', 2),
('Core', 'Ejercicios de abdominales y zona media', 3);

-- PASO 2: Crear tabla de DÍAS de un plan fit
-- ===================================================================
CREATE TABLE IF NOT EXISTS nu_plan_fit_dias (
    codigo INT AUTO_INCREMENT PRIMARY KEY,
    codigo_plan_fit INT NOT NULL,
    numero_dia INT NOT NULL,
    titulo VARCHAR(500) NULL COMMENT 'Ej: Tren superior (pecho + espalda + hombro)',
    descripcion TEXT NULL,
    orden INT DEFAULT 0,
    codusuarioa INT NULL,
    fechaa DATETIME NULL,
    codusuariom INT NULL,
    fecham DATETIME NULL,
    FOREIGN KEY (codigo_plan_fit) REFERENCES nu_plan_nutricional_fit(codigo) ON DELETE CASCADE,
    INDEX idx_plan_fit (codigo_plan_fit),
    INDEX idx_numero_dia (numero_dia),
    INDEX idx_orden (orden),
    UNIQUE KEY unique_plan_numero (codigo_plan_fit, numero_dia)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- PASO 3: Crear tabla de relación EJERCICIO-CATEGORÍA (muchos a muchos)
-- ===================================================================
CREATE TABLE IF NOT EXISTS nu_plan_fit_ejercicios_categorias (
    codigo_ejercicio INT NOT NULL COMMENT 'FK a nu_plan_fit_ejercicios_catalogo',
    codigo_categoria INT NOT NULL,
    PRIMARY KEY (codigo_ejercicio, codigo_categoria),
    FOREIGN KEY (codigo_ejercicio) REFERENCES nu_plan_fit_ejercicios_catalogo(codigo) ON DELETE CASCADE,
    FOREIGN KEY (codigo_categoria) REFERENCES nu_plan_fit_categorias(codigo) ON DELETE CASCADE,
    INDEX idx_ejercicio (codigo_ejercicio),
    INDEX idx_categoria (codigo_categoria)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- PASO 4: Modificar tabla nu_plan_fit_ejercicio para añadir codigo_dia
-- ===================================================================
ALTER TABLE nu_plan_fit_ejercicio 
ADD COLUMN IF NOT EXISTS codigo_dia INT NULL COMMENT 'FK a nu_plan_fit_dias. NULL = ejercicio para todo el plan' AFTER codigo_plan_fit,
ADD INDEX IF NOT EXISTS idx_codigo_dia (codigo_dia);

-- Añadir clave foránea si no existe (requiere verificación manual)
-- Descomentar la siguiente línea solo si la tabla nu_plan_fit_dias ya existe y tienes ejercicios asignados a días:
-- ALTER TABLE nu_plan_fit_ejercicio ADD CONSTRAINT fk_ejercicio_dia FOREIGN KEY (codigo_dia) REFERENCES nu_plan_fit_dias(codigo) ON DELETE CASCADE;

-- ===================================================================
-- VERIFICACIONES
-- ===================================================================
SELECT 'Verificación de tablas creadas:' as msg;

SELECT 
   CASE WHEN COUNT(*) > 0 THEN '✓ OK - nu_plan_fit_categorias existe' 
        ELSE '✗ ERROR - nu_plan_fit_categorias NO existe' 
   END as resultado
FROM information_schema.tables 
WHERE table_name = 'nu_plan_fit_categorias';

SELECT 
   CASE WHEN COUNT(*) > 0 THEN '✓ OK - nu_plan_fit_dias existe' 
        ELSE '✗ ERROR - nu_plan_fit_dias NO existe' 
   END as resultado
FROM information_schema.tables 
WHERE table_name = 'nu_plan_fit_dias';

SELECT 
   CASE WHEN COUNT(*) > 0 THEN '✓ OK - nu_plan_fit_ejercicios_categorias existe' 
        ELSE '✗ ERROR - nu_plan_fit_ejercicios_categorias NO existe' 
   END as resultado
FROM information_schema.tables 
WHERE table_name = 'nu_plan_fit_ejercicios_categorias';

SELECT 
   CASE WHEN COUNT(*) > 0 THEN '✓ OK - codigo_dia existe en nu_plan_fit_ejercicio' 
        ELSE '✗ ERROR - codigo_dia NO existe en nu_plan_fit_ejercicio' 
   END as resultado
FROM information_schema.columns 
WHERE table_name = 'nu_plan_fit_ejercicio' 
  AND column_name = 'codigo_dia';

-- Verificar categorías insertadas
SELECT '---' as separador;
SELECT 'Categorías disponibles:' as msg;
SELECT codigo, nombre, descripcion, orden 
FROM nu_plan_fit_categorias 
ORDER BY orden;

-- ===================================================================
-- INFORMACIÓN DE USO
-- ===================================================================
/*
FLUJO DE DATOS PROPUESTO:

1. CREAR PLAN FIT
   - Tabla: nu_plan_nutricional_fit
   - Campos: codigo_paciente, desde, hasta, semanas, etc.

2. AÑADIR DÍAS AL PLAN (opcional)
   - Tabla: nu_plan_fit_dias
   - Ejemplo INSERT:
     INSERT INTO nu_plan_fit_dias (codigo_plan_fit, numero_dia, titulo, orden) 
     VALUES (1, 1, 'Tren superior (pecho + espalda + hombro)', 1);

3. AÑADIR EJERCICIOS DEL CATÁLOGO
   - Tabla: nu_plan_fit_ejercicios_catalogo
   - Asignar categorías:
     INSERT INTO nu_plan_fit_ejercicios_categorias (codigo_ejercicio, codigo_categoria) 
     VALUES (1, 2); -- Ejercicio 1 es "Tren superior"

4. ASIGNAR EJERCICIOS AL PLAN (Y OPCIONALMENTE A UN DÍA)
   - Tabla: nu_plan_fit_ejercicio
   - codigo_dia = NULL → El ejercicio es para todo el plan
   - codigo_dia = X → El ejercicio es específico del día X

5. FILTRAR EJERCICIOS POR CATEGORÍA EN LA UI
   - SELECT e.* FROM nu_plan_fit_ejercicios_catalogo e
     INNER JOIN nu_plan_fit_ejercicios_categorias ec ON e.codigo = ec.codigo_ejercicio
     WHERE ec.codigo_categoria = 2; -- Tren superior

6. OBTENER EJERCICIOS DE UN DÍA ESPECÍFICO
   - SELECT * FROM nu_plan_fit_ejercicio 
     WHERE codigo_plan_fit = 1 AND codigo_dia = 1 
     ORDER BY orden;

7. OBTENER EJERCICIOS GENERALES DEL PLAN (sin día específico)
   - SELECT * FROM nu_plan_fit_ejercicio 
     WHERE codigo_plan_fit = 1 AND codigo_dia IS NULL 
     ORDER BY orden;

8. OBTENER DÍAS DE UN PLAN CON SUS EJERCICIOS
   - SELECT d.numero_dia, d.titulo, COUNT(e.codigo) as total_ejercicios
     FROM nu_plan_fit_dias d
     LEFT JOIN nu_plan_fit_ejercicio e ON e.codigo_dia = d.codigo
     WHERE d.codigo_plan_fit = 1
     GROUP BY d.codigo
     ORDER BY d.orden;

EJEMPLO DE PDF:
=================================
PLAN FIT - Juan Pérez
Del 01/02/2026 al 28/02/2026
=================================

Día 1: Tren superior (pecho + espalda + hombro)
╔══════════════════════════════════╦═══════╦════════╦══════════════╦══════════╗
║ Ejercicio                        ║ Kilos ║ Series ║ Repeticiones ║ Descanso ║
╠══════════════════════════════════╬═══════╬════════╬══════════════╬══════════╣
║ Press de banca con mancuernas    ║ 12,5  ║ 4      ║ 12           ║ 30-60"   ║
║ Press banca con barra acostado   ║ -     ║ 3      ║ 12           ║ 30-60"   ║
║ Press de hombros en máquina      ║ 25    ║ 3      ║ 12           ║ 30-60"   ║
║ Remo con polea                   ║ 36    ║ 4      ║ 10           ║ 30-60"   ║
╚══════════════════════════════════╩═══════╩════════╩══════════════╩══════════╝

Día 2: Tren inferior (cuádriceps + glúteos)
╔══════════════════════════════════╦═══════╦════════╦══════════════╦══════════╗
║ Ejercicio                        ║ Kilos ║ Series ║ Repeticiones ║ Descanso ║
╠══════════════════════════════════╬═══════╬════════╬══════════════╬══════════╣
║ Sentadilla con barra             ║ 50    ║ 4      ║ 10           ║ 90-120"  ║
║ Prensa de piernas                ║ 100   ║ 3      ║ 12           ║ 60-90"   ║
╚══════════════════════════════════╩═══════╩════════╩══════════════╩══════════╝
*/

-- ===================================================================
-- QUERIES DE EJEMPLO PARA LA API PHP
-- ===================================================================
/*
-- 1. Obtener categorías
SELECT codigo, nombre, descripcion, orden FROM nu_plan_fit_categorias WHERE activo = 'S' ORDER BY orden;

-- 2. Obtener ejercicios del catálogo por categoría
SELECT DISTINCT e.* 
FROM nu_plan_fit_ejercicios_catalogo e
INNER JOIN nu_plan_fit_ejercicios_categorias ec ON e.codigo = ec.codigo_ejercicio
WHERE ec.codigo_categoria = :codigo_categoria
ORDER BY e.nombre;

-- 3. Obtener ejercicios del catálogo con sus categorías
SELECT e.codigo, e.nombre, e.instrucciones, e.url_video, e.tiempo, e.descanso, e.repeticiones, e.kilos,
       GROUP_CONCAT(c.nombre SEPARATOR ', ') as categorias
FROM nu_plan_fit_ejercicios_catalogo e
LEFT JOIN nu_plan_fit_ejercicios_categorias ec ON e.codigo = ec.codigo_ejercicio
LEFT JOIN nu_plan_fit_categorias c ON ec.codigo_categoria = c.codigo
GROUP BY e.codigo
ORDER BY e.nombre;

-- 4. Obtener días de un plan fit
SELECT codigo, numero_dia, titulo, descripcion, orden 
FROM nu_plan_fit_dias 
WHERE codigo_plan_fit = :codigo_plan_fit 
ORDER BY orden, numero_dia;

-- 5. Obtener ejercicios de un día específico
SELECT e.* 
FROM nu_plan_fit_ejercicio e
WHERE e.codigo_plan_fit = :codigo_plan_fit 
  AND e.codigo_dia = :codigo_dia
ORDER BY e.orden, e.codigo;

-- 6. Obtener ejercicios generales del plan (sin día)
SELECT e.* 
FROM nu_plan_fit_ejercicio e
WHERE e.codigo_plan_fit = :codigo_plan_fit 
  AND e.codigo_dia IS NULL
ORDER BY e.orden, e.codigo;

-- 7. Obtener todos los ejercicios del plan agrupados por día
SELECT d.numero_dia, d.titulo, e.*
FROM nu_plan_fit_dias d
LEFT JOIN nu_plan_fit_ejercicio e ON e.codigo_dia = d.codigo
WHERE d.codigo_plan_fit = :codigo_plan_fit
ORDER BY d.orden, d.numero_dia, e.orden, e.codigo;

-- 8. Crear un día
INSERT INTO nu_plan_fit_dias (codigo_plan_fit, numero_dia, titulo, orden, codusuarioa, fechaa) 
VALUES (:codigo_plan_fit, :numero_dia, :titulo, :orden, :codusuario, NOW());

-- 9. Actualizar un día
UPDATE nu_plan_fit_dias 
SET titulo = :titulo, orden = :orden, codusuariom = :codusuario, fecham = NOW()
WHERE codigo = :codigo;

-- 10. Eliminar un día (los ejercicios se eliminan en cascada)
DELETE FROM nu_plan_fit_dias WHERE codigo = :codigo;

-- 11. Asignar categoría a un ejercicio del catálogo
INSERT IGNORE INTO nu_plan_fit_ejercicios_categorias (codigo_ejercicio, codigo_categoria) 
VALUES (:codigo_ejercicio, :codigo_categoria);

-- 12. Eliminar categoría de un ejercicio
DELETE FROM nu_plan_fit_ejercicios_categorias 
WHERE codigo_ejercicio = :codigo_ejercicio AND codigo_categoria = :codigo_categoria;
*/
