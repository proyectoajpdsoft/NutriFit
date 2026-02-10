-- Script para añadir el campo codigo_plan_fit a la tabla existente nu_entrenamientos
-- Ejecutar este script si ya tienes la tabla creada

ALTER TABLE nu_entrenamientos 
ADD COLUMN codigo_plan_fit INT NULL AFTER vueltas,
ADD INDEX idx_codigo_plan_fit (codigo_plan_fit);
