-- Script para añadir el campo duracion_kilometros a la tabla existente nu_entrenamientos
-- Ejecutar si la tabla ya existe sin este campo

ALTER TABLE nu_entrenamientos 
ADD COLUMN duracion_kilometros DECIMAL(5,2) DEFAULT NULL 
AFTER duracion_minutos;
