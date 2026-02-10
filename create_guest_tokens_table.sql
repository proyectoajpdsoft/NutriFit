-- Crear tabla para tokens guest
CREATE TABLE IF NOT EXISTS guest_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    token VARCHAR(255) UNIQUE NOT NULL,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion DATETIME NOT NULL,
    ip_publica VARCHAR(45),
    activo ENUM('S', 'N') DEFAULT 'S',
    INDEX idx_token (token),
    INDEX idx_expiracion (fecha_expiracion)
);
