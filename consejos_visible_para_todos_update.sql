-- Agregar campo visible_para_todos a la tabla nu_consejo

ALTER TABLE `nu_consejo` 
ADD COLUMN `visible_para_todos` varchar(1) DEFAULT 'N' AFTER `mostrar_portada`;

-- Crear índice para mejorar las consultas
CREATE INDEX idx_consejo_visible_todos ON nu_consejo(visible_para_todos);

-- Comentario: 
-- 'S' = El consejo se muestra a TODOS los pacientes (incluso nuevos)
-- 'N' = El consejo solo se muestra a los pacientes asignados específicamente
