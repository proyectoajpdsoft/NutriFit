<?php
/**
 * Script de migración: Cambiar tablas de paciente a usuario
 * nu_consejo_paciente -> nu_consejo_usuario
 * nu_receta_paciente -> nu_receta_usuario
 * 
 * Usa codigo_usuario en lugar de codigo_paciente
 */

require_once 'config/database.php';

header("Content-Type: application/json; charset=UTF-8");

$database = new Database();
$db = $database->getConnection();

$results = [];

try {
    // ============================================
    // 1. Crear tabla nu_consejo_usuario
    // ============================================
    $create_consejo = "CREATE TABLE IF NOT EXISTS nu_consejo_usuario (
        codigo INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        codigo_consejo INT NOT NULL,
        codigo_usuario INT NOT NULL,
        me_gusta CHAR(1) DEFAULT 'N',
        favorito CHAR(1) DEFAULT 'N',
        leido CHAR(1) DEFAULT 'N',
        fecha_me_gusta DATETIME NULL,
        fecha_favorito DATETIME NULL,
        fechaa DATETIME DEFAULT CURRENT_TIMESTAMP,
        codusuarioa INT DEFAULT 1,
        fecham DATETIME NULL,
        codusuariom INT NULL,
        UNIQUE KEY unique_consejo_usuario (codigo_consejo, codigo_usuario),
        FOREIGN KEY (codigo_consejo) REFERENCES nu_consejo(codigo) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (codigo_usuario) REFERENCES usuario(codigo) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
    
    $db->exec($create_consejo);
    $results['create_consejo_usuario'] = [
        'status' => 'success',
        'message' => 'Tabla nu_consejo_usuario creada correctamente'
    ];
    
    // ============================================
    // 2. Crear tabla nu_receta_usuario
    // ============================================
    $create_receta = "CREATE TABLE IF NOT EXISTS nu_receta_usuario (
        codigo INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        codigo_receta INT NOT NULL,
        codigo_usuario INT NOT NULL,
        me_gusta CHAR(1) DEFAULT 'N',
        favorito CHAR(1) DEFAULT 'N',
        leido CHAR(1) DEFAULT 'N',
        fecha_me_gusta DATETIME NULL,
        fecha_favorito DATETIME NULL,
        fechaa DATETIME DEFAULT CURRENT_TIMESTAMP,
        codusuarioa INT DEFAULT 1,
        fecham DATETIME NULL,
        codusuariom INT NULL,
        UNIQUE KEY unique_receta_usuario (codigo_receta, codigo_usuario),
        FOREIGN KEY (codigo_receta) REFERENCES nu_receta(codigo) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (codigo_usuario) REFERENCES usuario(codigo) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
    
    $db->exec($create_receta);
    $results['create_receta_usuario'] = [
        'status' => 'success',
        'message' => 'Tabla nu_receta_usuario creada correctamente'
    ];
    
    // ============================================
    // 3. Migrar datos de nu_consejo_paciente a nu_consejo_usuario
    // ============================================
    // Obtener todos los pacientes activos
    $migrate_consejo = "INSERT INTO nu_consejo_usuario (codigo_consejo, codigo_usuario, me_gusta, favorito, leido, fecha_me_gusta, fecha_favorito, fechaa, codusuarioa)
        SELECT 
            ncp.codigo_consejo,
            np.codigo_usuario,
            ncp.me_gusta,
            ncp.favorito,
            ncp.leido,
            ncp.fecha_me_gusta,
            ncp.fecha_favorito,
            ncp.fechaa,
            ncp.codusuarioa
        FROM nu_consejo_paciente ncp
        INNER JOIN nu_paciente np ON ncp.codigo_paciente = np.codigo
        WHERE ncp.codigo_paciente IS NOT NULL
        ON DUPLICATE KEY UPDATE
            me_gusta = VALUES(me_gusta),
            favorito = VALUES(favorito),
            leido = VALUES(leido)";
    
    $db->exec($migrate_consejo);
    $results['migrate_consejo'] = [
        'status' => 'success',
        'message' => 'Datos migrados de nu_consejo_paciente a nu_consejo_usuario'
    ];
    
    // ============================================
    // 4. Migrar datos de nu_receta_paciente a nu_receta_usuario
    // ============================================
    $migrate_receta = "INSERT INTO nu_receta_usuario (codigo_receta, codigo_usuario, me_gusta, favorito, leido, fecha_me_gusta, fecha_favorito, fechaa, codusuarioa)
        SELECT 
            nrp.codigo_receta,
            np.codigo_usuario,
            nrp.me_gusta,
            nrp.favorito,
            nrp.leido,
            nrp.fecha_me_gusta,
            nrp.fecha_favorito,
            nrp.fechaa,
            nrp.codusuarioa
        FROM nu_receta_paciente nrp
        INNER JOIN nu_paciente np ON nrp.codigo_paciente = np.codigo
        WHERE nrp.codigo_paciente IS NOT NULL
        ON DUPLICATE KEY UPDATE
            me_gusta = VALUES(me_gusta),
            favorito = VALUES(favorito),
            leido = VALUES(leido)";
    
    $db->exec($migrate_receta);
    $results['migrate_receta'] = [
        'status' => 'success',
        'message' => 'Datos migrados de nu_receta_paciente a nu_receta_usuario'
    ];
    
    // ============================================
    // 5. Verificar registros migrados
    // ============================================
    $count_consejo = $db->query("SELECT COUNT(*) as total FROM nu_consejo_usuario")->fetch(PDO::FETCH_ASSOC);
    $count_receta = $db->query("SELECT COUNT(*) as total FROM nu_receta_usuario")->fetch(PDO::FETCH_ASSOC);
    
    $results['migration_summary'] = [
        'status' => 'success',
        'message' => 'Migración completada',
        'consejo_usuario_registros' => $count_consejo['total'],
        'receta_usuario_registros' => $count_receta['total'],
        'next_steps' => [
            '1. Actualizar archivos PHP (renombrar y cambiar queries)',
            '2. Actualizar Flutter para usar codigo_usuario',
            '3. Hacer backup de tablas viejas antes de eliminar',
            '4. Eliminar tablas viejas (nu_consejo_paciente, nu_receta_paciente)'
        ]
    ];
    
    http_response_code(200);
    echo json_encode($results, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Error en la migración',
        'details' => $e->getMessage()
    ], JSON_PRETTY_PRINT);
}
?>
