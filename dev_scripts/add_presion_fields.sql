-- Campos de presión arterial por medición
ALTER TABLE nu_paciente_medicion
  ADD COLUMN presion_sistolica INT NULL AFTER brazo,
  ADD COLUMN presion_diastolica INT NULL AFTER presion_sistolica;
