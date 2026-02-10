-- Migración para agregar columnas fecham y codusuariom a nu_paciente_entrevista
-- Fecha: 2026-02-05

-- Verificar y agregar columna codusuariom si no existe
SET @dbname = DATABASE();
SET @tablename = "nu_paciente_entrevista";
SET @columnname = "codusuariom";
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (table_name = @tablename)
      AND (table_schema = @dbname)
      AND (column_name = @columnname)
  ) > 0,
  "SELECT 1",
  CONCAT("ALTER TABLE ", @tablename, " ADD ", @columnname, " int(11) DEFAULT NULL AFTER codusuarioa;")
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- Verificar y agregar columna fecham si no existe
SET @columnname = "fecham";
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (table_name = @tablename)
      AND (table_schema = @dbname)
      AND (column_name = @columnname)
  ) > 0,
  "SELECT 1",
  CONCAT("ALTER TABLE ", @tablename, " ADD ", @columnname, " datetime DEFAULT NULL AFTER codusuariom;")
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

SELECT 'Migración completada. Columnas codusuariom y fecham verificadas/agregadas.' AS resultado;
