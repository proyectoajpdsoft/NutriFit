-- Script para habilitar soporte completo de emojis en las tablas de consejos
-- Convierte las tablas y columnas a utf8mb4 para soportar caracteres de 4 bytes (emojis)

-- Convertir tabla nu_consejo
ALTER TABLE `nu_consejo` 
CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Convertir tabla nu_consejo_paciente
ALTER TABLE `nu_consejo_paciente` 
CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Convertir tabla nu_consejo_documento
ALTER TABLE `nu_consejo_documento` 
CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Verificar la conversión (ejecutar después de aplicar los cambios)
-- SELECT 
--   TABLE_NAME, 
--   TABLE_COLLATION 
-- FROM 
--   information_schema.TABLES 
-- WHERE 
--   TABLE_SCHEMA = 'patri_dietista' 
--   AND TABLE_NAME LIKE 'nu_consejo%';

-- Comentarios:
-- utf8mb4 soporta todos los caracteres Unicode incluyendo emojis
-- utf8mb4_unicode_ci es case-insensitive y soporta múltiples idiomas
-- La conexión PHP también debe usar utf8mb4 (ver database.php)
