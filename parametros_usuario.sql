-- Parámetros de configuración para usuarios
-- Ejecutar este script en la base de datos para crear los parámetros necesarios

-- Tamaño máximo de imagen de perfil en KB (por defecto 500 KB)
-- Este es un parámetro GLOBAL (se guarda en la base de datos)
INSERT INTO parametro (nombre, valor, descripcion, categoria, tipo, fechaa, codusuarioa) 
VALUES ('usuario_max_imagen_kb', '500', 'Tamaño máximo permitido para imagen de perfil en KB (rango: 1-3000)', 'Usuario', 'numerico', NOW(), 1)
ON DUPLICATE KEY UPDATE 
    valor = '500',
    descripcion = 'Tamaño máximo permitido para imagen de perfil en KB (rango: 1-3000)',
    categoria = 'Usuario',
    tipo = 'numerico';

-- NOTA: Los valores por defecto de tipo de usuario, activo y acceso 
-- se guardan localmente en cada dispositivo mediante SharedPreferences
-- y no requieren parámetros en la base de datos.

