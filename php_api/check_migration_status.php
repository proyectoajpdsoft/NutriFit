<?php
/**
 * Script de verificación del estado de la migración
 */

require_once 'config/database.php';

header("Content-Type: application/json; charset=UTF-8");

$database = new Database();
$db = $database->getConnection();

$results = [];

try {
    // Verificar tablas antiguas
    $check_old = "SELECT COUNT(*) as total FROM information_schema.TABLES 
                  WHERE TABLE_SCHEMA = DATABASE() 
                  AND TABLE_NAME IN ('nu_consejo_paciente', 'nu_receta_paciente')";
    
    $stmt = $db->prepare($check_old);
    $stmt->execute();
    $old_tables = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Verificar tablas nuevas
    $check_new = "SELECT COUNT(*) as total FROM information_schema.TABLES 
                  WHERE TABLE_SCHEMA = DATABASE() 
                  AND TABLE_NAME IN ('nu_consejo_usuario', 'nu_receta_usuario')";
    
    $stmt = $db->prepare($check_new);
    $stmt->execute();
    $new_tables = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Contar registros
    $count_consejo_usuario = "SELECT COUNT(*) as total FROM nu_consejo_usuario";
    $stmt = $db->prepare($count_consejo_usuario);
    $stmt->execute();
    $consejo_usuario_count = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    $count_receta_usuario = "SELECT COUNT(*) as total FROM nu_receta_usuario";
    $stmt = $db->prepare($count_receta_usuario);
    $stmt->execute();
    $receta_usuario_count = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    $count_consejo_paciente = "SELECT COUNT(*) as total FROM nu_consejo_paciente";
    $stmt = $db->prepare($count_consejo_paciente);
    $stmt->execute();
    $consejo_paciente_count = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    $count_receta_paciente = "SELECT COUNT(*) as total FROM nu_receta_paciente";
    $stmt = $db->prepare($count_receta_paciente);
    $stmt->execute();
    $receta_paciente_count = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Determinar estado
    $status = 'pending';
    if ($new_tables == 2 && $old_tables == 2 && $consejo_usuario_count > 0) {
        $status = 'migrated_but_old_tables_exist';
    } elseif ($new_tables == 2 && $old_tables == 0 && $consejo_usuario_count > 0) {
        $status = 'fully_migrated';
    } elseif ($new_tables == 0 && $old_tables == 2) {
        $status = 'not_started';
    }
    
    $results = [
        'migration_status' => $status,
        'old_tables' => [
            'nu_consejo_paciente' => [
                'exists' => $consejo_paciente_count > 0,
                'total_records' => $consejo_paciente_count
            ],
            'nu_receta_paciente' => [
                'exists' => $receta_paciente_count > 0,
                'total_records' => $receta_paciente_count
            ]
        ],
        'new_tables' => [
            'nu_consejo_usuario' => [
                'exists' => $consejo_usuario_count > 0,
                'total_records' => $consejo_usuario_count
            ],
            'nu_receta_usuario' => [
                'exists' => $receta_usuario_count > 0,
                'total_records' => $receta_usuario_count
            ]
        ],
        'summary' => [
            'tables_count_old' => $old_tables,
            'tables_count_new' => $new_tables,
            'status_message' => match($status) {
                'pending' => '⏳ La migración aún no ha iniciado. Ejecuta migrate_to_usuario_tables.php',
                'not_started' => '⏳ Las tablas antiguas existen pero las nuevas no. Ejecuta migrate_to_usuario_tables.php',
                'migrated_but_old_tables_exist' => '✅ Migración completada pero las tablas antiguas aún existen. Puedes eliminarlas manualmente si deseas.',
                'fully_migrated' => '✅ Migración completada exitosamente. Las tablas antiguas han sido eliminadas.'
            }
        ],
        'next_steps' => match($status) {
            'pending' => ['Ejecutar migrate_to_usuario_tables.php'],
            'not_started' => ['Ejecutar migrate_to_usuario_tables.php'],
            'migrated_but_old_tables_exist' => ['(Opcional) Eliminar tablas antiguas', 'Usar nuevos endpoints en la aplicación'],
            'fully_migrated' => ['Recargar la aplicación Flutter', 'Probar me gusta y favoritos']
        }
    ];
    
    http_response_code(200);
    echo json_encode($results, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Error verificando migración',
        'details' => $e->getMessage()
    ], JSON_PRETTY_PRINT);
}
?>
