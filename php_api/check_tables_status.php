<?php
// Script de diagnóstico para verificar el estado de las tablas

require_once 'config/database.php';

header("Content-Type: application/json; charset=UTF-8");

$database = new Database();
$db = $database->getConnection();

$results = [];

try {
    // Verificar nu_consejo_paciente
    $check1 = "SELECT 
                COLUMN_NAME,
                IS_NULLABLE,
                COLUMN_TYPE,
                COLUMN_KEY
               FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_NAME = 'nu_consejo_paciente' 
               AND COLUMN_NAME = 'codigo_paciente'
               AND TABLE_SCHEMA = DATABASE()";
    
    $stmt1 = $db->prepare($check1);
    $stmt1->execute();
    $results['nu_consejo_paciente'] = $stmt1->fetch(PDO::FETCH_ASSOC);
    
    // Verificar nu_receta_paciente
    $check2 = "SELECT 
                COLUMN_NAME,
                IS_NULLABLE,
                COLUMN_TYPE,
                COLUMN_KEY
               FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_NAME = 'nu_receta_paciente' 
               AND COLUMN_NAME = 'codigo_paciente'
               AND TABLE_SCHEMA = DATABASE()";
    
    $stmt2 = $db->prepare($check2);
    $stmt2->execute();
    $results['nu_receta_paciente'] = $stmt2->fetch(PDO::FETCH_ASSOC);
    
    // Contar registros con NULL
    $count1 = "SELECT COUNT(*) as total_nulls FROM nu_consejo_paciente WHERE codigo_paciente IS NULL";
    $stmt_count1 = $db->prepare($count1);
    $stmt_count1->execute();
    $results['nu_consejo_paciente_nulls'] = $stmt_count1->fetch(PDO::FETCH_ASSOC);
    
    $count2 = "SELECT COUNT(*) as total_nulls FROM nu_receta_paciente WHERE codigo_paciente IS NULL";
    $stmt_count2 = $db->prepare($count2);
    $stmt_count2->execute();
    $results['nu_receta_paciente_nulls'] = $stmt_count2->fetch(PDO::FETCH_ASSOC);
    
    echo json_encode($results, JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    echo json_encode([
        "error" => $e->getMessage()
    ], JSON_PRETTY_PRINT);
}
?>
