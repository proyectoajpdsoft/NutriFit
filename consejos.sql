-- Sistema de Consejos para Pacientes

-- Tabla principal de consejos
CREATE TABLE `nu_consejo` (
  `codigo` int(11) NOT NULL AUTO_INCREMENT,
  `titulo` varchar(255) NOT NULL,
  `texto` LONGTEXT,
  `activo` varchar(1) DEFAULT 'S',
  `fecha_inicio` date DEFAULT NULL,
  `fecha_fin` date DEFAULT NULL,
  `mostrar_portada` varchar(1) DEFAULT 'S',
  `imagen_portada` LONGBLOB,
  `imagen_portada_nombre` varchar(255) DEFAULT NULL,
  `fechaa` datetime DEFAULT NULL,
  `codusuarioa` int(11) DEFAULT NULL,
  `fecham` datetime DEFAULT NULL,
  `codusuariom` int(11) DEFAULT NULL,
  PRIMARY KEY (`codigo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de relación consejos-pacientes (con me gusta)
CREATE TABLE `nu_consejo_paciente` (
  `codigo` int(11) NOT NULL AUTO_INCREMENT,
  `codigo_consejo` int(11) NOT NULL,
  `codigo_paciente` int(11) NOT NULL,
  `me_gusta` varchar(1) DEFAULT 'N',
  `fecha_me_gusta` datetime DEFAULT NULL,
  `fechaa` datetime DEFAULT NULL,
  `codusuarioa` int(11) DEFAULT NULL,
  `fecham` datetime DEFAULT NULL,
  `codusuariom` int(11) DEFAULT NULL,
  PRIMARY KEY (`codigo`),
  UNIQUE KEY `consejo_paciente_unique` (`codigo_consejo`, `codigo_paciente`),
  KEY `consejo_paciente_consejo_fk` (`codigo_consejo`),
  KEY `consejo_paciente_paciente_fk` (`codigo_paciente`),
  CONSTRAINT `consejo_paciente_consejo_fk` FOREIGN KEY (`codigo_consejo`) REFERENCES `nu_consejo` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `consejo_paciente_paciente_fk` FOREIGN KEY (`codigo_paciente`) REFERENCES `nu_paciente` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de documentos/URLs del consejo
CREATE TABLE `nu_consejo_documento` (
  `codigo` int(11) NOT NULL AUTO_INCREMENT,
  `codigo_consejo` int(11) NOT NULL,
  `tipo` varchar(20) DEFAULT 'documento', -- 'documento' o 'url'
  `nombre` varchar(255) DEFAULT NULL,
  `documento` LONGBLOB,
  `url` varchar(500) DEFAULT NULL,
  `orden` int(11) DEFAULT 0,
  `fechaa` datetime DEFAULT NULL,
  `codusuarioa` int(11) DEFAULT NULL,
  `fecham` datetime DEFAULT NULL,
  `codusuariom` int(11) DEFAULT NULL,
  PRIMARY KEY (`codigo`),
  KEY `consejo_documento_consejo_fk` (`codigo_consejo`),
  CONSTRAINT `consejo_documento_consejo_fk` FOREIGN KEY (`codigo_consejo`) REFERENCES `nu_consejo` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Índices adicionales para mejorar rendimiento
CREATE INDEX idx_consejo_activo ON nu_consejo(activo);
CREATE INDEX idx_consejo_fechas ON nu_consejo(fecha_inicio, fecha_fin);
CREATE INDEX idx_consejo_portada ON nu_consejo(mostrar_portada);
CREATE INDEX idx_consejo_paciente_megusta ON nu_consejo_paciente(me_gusta);
