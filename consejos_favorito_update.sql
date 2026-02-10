-- Agregar campo favorito a la tabla nu_consejo_paciente

ALTER TABLE `nu_consejo_paciente` 
ADD COLUMN `favorito` varchar(1) DEFAULT 'N' AFTER `fecha_me_gusta`,
ADD COLUMN `fecha_favorito` datetime DEFAULT NULL AFTER `favorito`;

-- Crear índice para favoritos
CREATE INDEX idx_consejo_paciente_favorito ON nu_consejo_paciente(favorito);
