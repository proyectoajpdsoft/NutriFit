-- Añade columnas para datos antropométricos base del usuario
ALTER TABLE usuario
  ADD COLUMN edad INT NULL AFTER codigo_paciente,
  ADD COLUMN altura INT NULL AFTER edad;
