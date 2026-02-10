-- Tabla para entrenamientos
CREATE TABLE IF NOT EXISTS nu_entrenamientos (
    codigo INT AUTO_INCREMENT PRIMARY KEY,
    codigo_paciente VARCHAR(50) NOT NULL,
    actividad VARCHAR(100) NOT NULL,
    descripcion_actividad VARCHAR(255),
    fecha DATETIME NOT NULL,
    duracion_horas INT NOT NULL DEFAULT 0,
    duracion_minutos INT NOT NULL DEFAULT 0,
    duracion_kilometros DECIMAL(5,2) DEFAULT NULL,
    nivel_esfuerzo INT NOT NULL DEFAULT 5,
    notas TEXT,
    fotos LONGTEXT,
    vueltas INT NOT NULL DEFAULT 0,
    codigo_plan_fit INT NULL,
    codusuario VARCHAR(50),
    fechaa DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_codigo_paciente (codigo_paciente),
    INDEX idx_fecha (fecha),
    INDEX idx_actividad (actividad),
    INDEX idx_codigo_plan_fit (codigo_plan_fit)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
