-- Actualización para agregar campo 'leido' a la tabla nu_consejo_paciente

ALTER TABLE `nu_consejo_paciente` 
ADD COLUMN `leido` varchar(1) DEFAULT 'N' AFTER `fecha_me_gusta`;

-- Índice para mejorar rendimiento de búsquedas por estado de lectura
CREATE INDEX idx_consejo_paciente_leido ON nu_consejo_paciente(leido);

-- Comentario: Este campo indica si el paciente ha leído el consejo
-- 'S' = Sí, 'N' = No
