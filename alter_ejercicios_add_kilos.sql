-- Script para añadir el campo 'kilos' a las tablas de ejercicios
-- Ejecutar este script en la base de datos de producción

-- 1. Añadir columna 'kilos' a la tabla del catálogo de ejercicios de plan fit
ALTER TABLE nu_plan_fit_ejercicios_catalogo 
ADD COLUMN IF NOT EXISTS kilos INT NULL AFTER repeticiones;

-- 2. Añadir columna 'kilos' a la tabla de ejercicios de plan fit
ALTER TABLE nu_plan_fit_ejercicio 
ADD COLUMN IF NOT EXISTS kilos INT NULL AFTER repeticiones;

-- 3. Añadir columna 'kilos_plan' a la tabla de ejercicios de entrenamientos
ALTER TABLE nu_entrenamientos_ejercicios 
ADD COLUMN IF NOT EXISTS kilos_plan INT NULL AFTER repeticiones_plan;

-- Verificar que las columnas se añadieron correctamente
SELECT 'Verificación de columnas añadidas:' as msg;
SELECT 
   CASE WHEN COUNT(*) > 0 THEN 'OK - kilos existe en nu_plan_fit_ejercicios_catalogo' 
        ELSE 'ERROR - kilos NO existe en nu_plan_fit_ejercicios_catalogo' 
   END as resultado
FROM information_schema.columns 
WHERE table_name = 'nu_plan_fit_ejercicios_catalogo' 
  AND column_name = 'kilos';

SELECT 
   CASE WHEN COUNT(*) > 0 THEN 'OK - kilos existe en nu_plan_fit_ejercicio' 
        ELSE 'ERROR - kilos NO existe en nu_plan_fit_ejercicio' 
   END as resultado
FROM information_schema.columns 
WHERE table_name = 'nu_plan_fit_ejercicio' 
  AND column_name = 'kilos';

SELECT 
   CASE WHEN COUNT(*) > 0 THEN 'OK - kilos_plan existe en nu_entrenamientos_ejercicios' 
        ELSE 'ERROR - kilos_plan NO existe en nu_entrenamientos_ejercicios' 
   END as resultado
FROM information_schema.columns 
WHERE table_name = 'nu_entrenamientos_ejercicios' 
  AND column_name = 'kilos_plan';
