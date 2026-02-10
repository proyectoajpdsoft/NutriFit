-- Base de datos para NutriApp

-- Tabla de Pacientes
CREATE TABLE `nu_paciente` (
  `codigo` int(11) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(200) NOT NULL,
  `dni` varchar(10) DEFAULT NULL,
  `fecha_nacimiento` date DEFAULT NULL,
  `sexo` varchar(10) DEFAULT NULL,
  `altura` int(11) DEFAULT NULL,
  `observacion` text,
  `calle` varchar(200) DEFAULT NULL,
  `codigo_postal` int(11) DEFAULT NULL,
  `provincia` varchar(150) DEFAULT NULL,
  `pais` varchar(100) DEFAULT NULL,
  `online` varchar(1) DEFAULT 'S',
  `fechaa` datetime DEFAULT NULL,
  `codusuarioa` int(11) DEFAULT NULL,
  `telefono` varchar(100) DEFAULT NULL,
  `email1` varchar(200) DEFAULT NULL,
  `email2` varchar(200) DEFAULT NULL,
  `peso` decimal(7,2) DEFAULT NULL,
  `edad` int(11) DEFAULT NULL,
  `fecham` datetime DEFAULT NULL,
  `codusuariom` int(11) DEFAULT NULL,
  PRIMARY KEY (`codigo`),
  UNIQUE KEY `codigo_UNIQUE` (`codigo`),
  UNIQUE KEY `nombre_UNIQUE` (`nombre`)
);

-- Tabla de Citas
CREATE TABLE `nu_cita` (
  `codigo` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `asunto` varchar(255) NOT NULL DEFAULT '',
  `ubicacion` varchar(150) DEFAULT NULL,
  `comienzo` datetime DEFAULT NULL,
  `fin` datetime DEFAULT NULL,
  `descripcion` text,
  `codigocategoria` int(10) unsigned DEFAULT NULL,
  `codusuarioa` int(10) unsigned DEFAULT NULL,
  `codusuariom` int(10) unsigned DEFAULT NULL,
  `fechaa` datetime DEFAULT NULL,
  `fecham` datetime DEFAULT NULL,
  `estado` varchar(45) DEFAULT NULL,
  `codigo_paciente` int(11) DEFAULT NULL,
  `codigo_entrevista` int(11) DEFAULT NULL,
  `tipo` varchar(100) DEFAULT NULL,
  `online` varchar(1) DEFAULT NULL,
  PRIMARY KEY (`codigo`),
  KEY `paciente_idx` (`codigo_paciente`),
  CONSTRAINT `paciente_fk` FOREIGN KEY (`codigo_paciente`) REFERENCES `nu_paciente` (`codigo`) ON DELETE SET NULL ON UPDATE CASCADE
);

-- Tabla de Entrevistas
CREATE TABLE `nu_paciente_entrevista` (
  `codigo` int(11) NOT NULL AUTO_INCREMENT,
  `codigo_paciente` int(11) DEFAULT NULL,
  `fecha_realizacion` datetime DEFAULT NULL,
  `observacion` text,
  `completada` varchar(1) DEFAULT NULL,
  `fecha_prevista` datetime DEFAULT NULL,
  `motivo` text,
  `objetivos` text,
  `dietas_anteriores` text,
  `ocupacion_horario` text,
  `deporte_frecuencia` text,
  `actividad_fisica` text,
  `fumador` varchar(255) DEFAULT NULL,
  `alcohol` varchar(255) DEFAULT NULL,
  `sueno` text,
  `horario_laboral_comidas` text,
  `comidas_dia` varchar(255) DEFAULT NULL,
  `horario_comidas_regular` varchar(255) DEFAULT NULL,
  `lugar_comidas` varchar(255) DEFAULT NULL,
  `quien_compra_casa` varchar(255) DEFAULT NULL,
  `bebida_comida` varchar(255) DEFAULT NULL,
  `preferencias_alimentarias` text,
  `alimentos_rechazo` text,
  `tipo_dieta_preferencia` text,
  `cantidad_agua_diaria` varchar(255) DEFAULT NULL,
  `picar_entre_horas` varchar(255) DEFAULT NULL,
  `hora_dia_mas_apetito` varchar(255) DEFAULT NULL,
  `antojo_dulce_salado` varchar(255) DEFAULT NULL,
  `patologia` text,
  `antecedentes_enfermedades` text,
  `tipo_medicacion` text,
  `tipo_suplemento` text,
  `intolerancia_alergia` text,
  `hambre_emocional` text,
  `estres_ansiedad` text,
  `relacion_comida` text,
  `ciclo_menstrual` text,
  `lactancia` varchar(255) DEFAULT NULL,
  `24_horas_desayuno` varchar(255) DEFAULT NULL,
  `24_horas_almuerzo` varchar(255) DEFAULT NULL,
  `24_horas_comida` varchar(255) DEFAULT NULL,
  `24_horas_merienda` varchar(255) DEFAULT NULL,
  `24_horas_cena` varchar(255) DEFAULT NULL,
  `24_horas_recena` varchar(255) DEFAULT NULL,
  `pesar_alimentos` varchar(255) DEFAULT NULL,
  `resultados_bascula` varchar(255) DEFAULT NULL,
  `gusta_cocinar` varchar(255) DEFAULT NULL,
  `establecimiento_compra` varchar(255) DEFAULT NULL,
  `codusuarioa` int(11) DEFAULT NULL,
  `fechaa` datetime DEFAULT NULL,
  `codusuariom` int(11) DEFAULT NULL,
  `fecham` datetime DEFAULT NULL,
  `online` varchar(1) DEFAULT NULL,
  `peso` decimal(7,2) DEFAULT NULL,
  PRIMARY KEY (`codigo`),
  KEY `entrevista_paciente_fk` (`codigo_paciente`),
  CONSTRAINT `entrevista_paciente_fk` FOREIGN KEY (`codigo_paciente`) REFERENCES `nu_paciente` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Tabla de Mediciones
CREATE TABLE `nu_paciente_medicion` (
  `codigo` int(11) NOT NULL AUTO_INCREMENT,
  `codigo_paciente` int(11) NOT NULL,
  `fecha` date DEFAULT NULL,
  `pliegue_abdominal` decimal(7,2) DEFAULT NULL,
  `pliegue_cuadricipital` decimal(7,2) DEFAULT NULL,
  `pliegue_peroneal` decimal(7,2) DEFAULT NULL,
  `pliegue_subescapular` decimal(7,2) DEFAULT NULL,
  `pligue_tricipital` decimal(7,2) DEFAULT NULL,
  `pliegue_suprailiaco` decimal(7,2) DEFAULT NULL,
  `peso` decimal(7,2) DEFAULT NULL,
  `gasto_actividad_fisica` decimal(7,2) DEFAULT NULL,
  `observacion` text,
  `actividad_fisica` varchar(15) DEFAULT NULL,
  `gasto_energetico_total` decimal(7,2) DEFAULT NULL,
  `gasto_termogenico_dieta` decimal(7,2) DEFAULT NULL,
  `gasto_energetico_basal` decimal(7,2) DEFAULT NULL,
  `imc` decimal(7,2) DEFAULT NULL,
  `porcentaje_grasa` decimal(7,2) DEFAULT NULL,
  `porcentaje_magra` decimal(7,2) DEFAULT NULL,
  `pliegue_midaxilar` decimal(7,2) DEFAULT NULL,
  `pliegue_pectoral` decimal(7,2) DEFAULT NULL,
  `pliegue_bicipital` varchar(45) DEFAULT NULL,
  `fechaa` datetime DEFAULT NULL,
  `codusuarioa` int(11) DEFAULT NULL,
  `fecham` datetime DEFAULT NULL,
  `codusuariom` int(11) DEFAULT NULL,
  PRIMARY KEY (`codigo`),
  KEY `medicion_paciente_fk` (`codigo_paciente`),
  CONSTRAINT `medicion_paciente_fk` FOREIGN KEY (`codigo_paciente`) REFERENCES `nu_paciente` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Tabla de Revisiones
CREATE TABLE `nu_paciente_revision` (
  `codigo` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `asunto` varchar(255) NOT NULL DEFAULT '',
  `fecha_prevista` datetime DEFAULT NULL,
  `fecha_realizacion` datetime DEFAULT NULL,
  `semanas` varchar(255) NOT NULL DEFAULT '',
  `modificacion_dieta` text,
  `codigo_paciente` int(11) DEFAULT NULL,
  `completada` varchar(1) DEFAULT NULL,
  `online` varchar(1) DEFAULT NULL,
  `codusuarioa` int(10) unsigned DEFAULT NULL,
  `codusuariom` int(10) unsigned DEFAULT NULL,
  `fechaa` datetime DEFAULT NULL,
  `fecham` datetime DEFAULT NULL,
  `peso` decimal(7,2) DEFAULT NULL,
  PRIMARY KEY (`codigo`),
  KEY `revision_paciente_fk` (`codigo_paciente`),
  CONSTRAINT `revision_paciente_fk` FOREIGN KEY (`codigo_paciente`) REFERENCES `nu_paciente` (`codigo`) ON DELETE SET NULL ON UPDATE CASCADE
);

-- Tabla de Planes Nutricionales
CREATE TABLE `nu_plan_nutricional` (
  `codigo` int(11) NOT NULL AUTO_INCREMENT,
  `codigo_paciente` int(11) DEFAULT NULL,
  `desde` date DEFAULT NULL,
  `hasta` date DEFAULT NULL,
  `semanas` varchar(200) DEFAULT NULL,
  `completado` varchar(1) DEFAULT NULL,
  `codusuarioa` int(11) DEFAULT NULL,
  `fechaa` datetime DEFAULT NULL,
  `codusuariom` int(11) DEFAULT NULL,
  `fecham` datetime DEFAULT NULL,
  `codigo_entrevista` int(11) DEFAULT NULL,
  `plan_documento` LONGBLOB,
  `plan_documento_nombre` VARCHAR(255) DEFAULT NULL,
  `plan_indicaciones` LONGTEXT,
  `plan_indicaciones_visible_usuario` LONGTEXT,
  PRIMARY KEY (`codigo`),
  KEY `plan_paciente_fk` (`codigo_paciente`),
  CONSTRAINT `plan_paciente_fk` FOREIGN KEY (`codigo_paciente`) REFERENCES `nu_paciente` (`codigo`) ON DELETE SET NULL ON UPDATE CASCADE
);

-- Tabla de Clientes/Terceros
CREATE TABLE `tercero` (
  `codigo` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL DEFAULT '',
  `cif` varchar(15) DEFAULT NULL,
  `fechaalta` datetime DEFAULT NULL,
  `direccion` varchar(100) DEFAULT NULL,
  `telefono` varchar(50) DEFAULT NULL,
  `poblacion` varchar(100) DEFAULT NULL,
  `provincia` varchar(50) DEFAULT NULL,
  `cp` int(11) DEFAULT '0',
  `personacontacto` varchar(100) DEFAULT NULL,
  `web` varchar(200) DEFAULT NULL,
  `email` varchar(200) DEFAULT NULL,
  `fax` varchar(50) DEFAULT NULL,
  `pais` varchar(45) DEFAULT NULL,
  `tipo` varchar(10) DEFAULT NULL,
  `observacion` varchar(255) DEFAULT NULL,
  `activo` varchar(1) DEFAULT 'S',
  `codusuarioa` int(10) unsigned DEFAULT NULL,
  `codusuariom` int(10) unsigned DEFAULT NULL,
  `fechaa` datetime DEFAULT NULL,
  `fecham` datetime DEFAULT NULL,
  PRIMARY KEY (`codigo`)
);

-- Tabla de Cobros
CREATE TABLE `cobro` (
  `codigo` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `fecha` date DEFAULT NULL,
  `importe` float(19,4) DEFAULT NULL,
  `codigocliente` int(10) unsigned DEFAULT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  `codusuarioa` int(10) unsigned DEFAULT NULL,
  `codusuariom` int(10) unsigned DEFAULT NULL,
  `fechaa` datetime DEFAULT NULL,
  `fecham` datetime DEFAULT NULL,
  `codigo_paciente` int(11) DEFAULT NULL,
  PRIMARY KEY (`codigo`),
  KEY `cobro_paciente_fk` (`codigo_paciente`),
  KEY `cobro_cliente_fk` (`codigocliente`),
  CONSTRAINT `cobro_paciente_fk` FOREIGN KEY (`codigo_paciente`) REFERENCES `nu_paciente` (`codigo`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `cobro_cliente_fk` FOREIGN KEY (`codigocliente`) REFERENCES `tercero` (`codigo`) ON DELETE SET NULL ON UPDATE CASCADE
);

-- Tabla de Usuarios
CREATE TABLE `usuario` (
  `codigo` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `nick` varchar(20) NOT NULL DEFAULT '',
  `contrasena` varchar(255) DEFAULT NULL, -- Aumentado para hashes modernos
  `codigocliente` int(10) unsigned DEFAULT NULL,
  `codigotecnico` int(10) unsigned DEFAULT NULL,
  `codusuarioa` int(10) unsigned DEFAULT NULL,
  `codusuariom` int(10) unsigned DEFAULT NULL,
  `fechaa` datetime DEFAULT NULL,
  `fecham` datetime DEFAULT NULL,
  `administrador` char(1) DEFAULT 'N',
  `nombre` varchar(100) DEFAULT NULL,
  `accesoweb` char(1) DEFAULT 'S',
  `email` varchar(200) DEFAULT NULL,
  `activo` varchar(1) DEFAULT 'S',
  `tipo` varchar(30) DEFAULT NULL, -- 'Nutricionista', 'Paciente'
  `codigo_paciente` int(11) DEFAULT NULL,
  `token` varchar(255) DEFAULT NULL,
  `token_expiracion` datetime DEFAULT NULL,
  PRIMARY KEY (`codigo`),
  UNIQUE KEY `nick_UNIQUE` (`nick`),
  KEY `usuario_paciente_fk` (`codigo_paciente`),
  CONSTRAINT `usuario_paciente_fk` FOREIGN KEY (`codigo_paciente`) REFERENCES `nu_paciente` (`codigo`) ON DELETE SET NULL ON UPDATE CASCADE
);

-- Tabla de Sesiones (Log de acceso)
CREATE TABLE `sesion` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `codigousuario` int(11) DEFAULT NULL,
  `fecha` date DEFAULT NULL,
  `hora` time DEFAULT NULL,
  `estado` varchar(20) DEFAULT NULL, -- 'OK', 'Error_Pass', 'Error_Usuario_NoExiste', 'Error_Inactivo'
  `ip_local` varchar(45) DEFAULT NULL,
  `ip_publica` varchar(45) DEFAULT NULL,
  `tipo` varchar(20) DEFAULT NULL, -- 'Android', 'iOS', 'Web'
  PRIMARY KEY (`id`),
  KEY `codigousuario_idx` (`codigousuario`)
);
