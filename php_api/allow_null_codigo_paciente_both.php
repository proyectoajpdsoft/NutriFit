<?php
// Script para permitir NULL en codigo_paciente de AMBAS tablas:
// - nu_consejo_paciente
// - nu_receta_paciente
// Esto permite que usuarios sin paciente asignado puedan dar likes y favoritos

require_once 'config/database.php';

header("Content-Type: application/json; charset=UTF-8");

$database = new Database();
$db = $database->getConnection();

$results = [];

try {
    // ============================================
    // Tabla 1: nu_consejo_paciente
    // ============================================
    $check_query1 = "SELECT COLUMN_KEY, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS 
                    WHERE TABLE_NAME = 'nu_consejo_paciente' AND COLUMN_NAME = 'codigo_paciente'
                    AND TABLE_SCHEMA = DATABASE()";
    
    $check_stmt1 = $db->prepare($check_query1);
    $check_stmt1->execute();
    $current1 = $check_stmt1->fetch(PDO::FETCH_ASSOC);
    
    if ($current1 && $current1['IS_NULLABLE'] == 'NO') {
        $sql1 = "ALTER TABLE nu_consejo_paciente 
                MODIFY codigo_paciente INT NULL";
        $db->exec($sql1);
        $results['nu_consejo_paciente'] = [
            "success" => true,
            "message" => "✅ Columna modificada para permitir NULL"
        ];
    } else if ($current1 && $current1['IS_NULLABLE'] == 'YES') {
        $results['nu_consejo_paciente'] = [
            "success" => true,
            "message" => "ℹ️ Ya permite NULL"
        ];
    } else {
        $results['nu_consejo_paciente'] = [
            "success" => false,
            "message" => "⚠️ Tabla no encontrada"
        ];
    }
    
    // ============================================
    // Tabla 2: nu_receta_paciente
    // ============================================
    $check_query2 = "SELECT COLUMN_KEY, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS 
                    WHERE TABLE_NAME = 'nu_receta_paciente' AND COLUMN_NAME = 'codigo_paciente'
                    AND TABLE_SCHEMA = DATABASE()";
    
    $check_stmt2 = $db->prepare($check_query2);
    $check_stmt2->execute();
    $current2 = $check_stmt2->fetch(PDO::FETCH_ASSOC);
    
    if ($current2 && $current2['IS_NULLABLE'] == 'NO') {
        $sql2 = "ALTER TABLE nu_receta_paciente 
                MODIFY codigo_paciente INT NULL";
        $db->exec($sql2);
        $results['nu_receta_paciente'] = [
            "success" => true,
            "message" => "✅ Columna modificada para permitir NULL"
        ];
    } else if ($current2 && $current2['IS_NULLABLE'] == 'YES') {
        $results['nu_receta_paciente'] = [
            "success" => true,
            "message" => "ℹ️ Ya permite NULL"
        ];
    } else {
        $results['nu_receta_paciente'] = [
            "success" => false,
            "message" => "⚠️ Tabla no encontrada"
        ];
    }
    
    echo json_encode($results, JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    echo json_encode([
        "success" => false,
        "error" => "Error modificando tablas",
        "details" => $e->getMessage()
    ], JSON_PRETTY_PRINT);
}
?>
