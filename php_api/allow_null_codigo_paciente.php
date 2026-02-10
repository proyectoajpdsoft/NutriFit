<?php
// Script para permitir NULL en codigo_paciente de nu_consejo_paciente
// Esto permite que usuarios sin paciente asignado puedan dar likes y favoritos a consejos

require_once 'config/database.php';

$database = new Database();
$db = $database->getConnection();

try {
    // Verificar la estructura actual
    $check_query = "SELECT COLUMN_KEY, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS 
                    WHERE TABLE_NAME = 'nu_consejo_paciente' AND COLUMN_NAME = 'codigo_paciente'
                    AND TABLE_SCHEMA = DATABASE()";
    
    $check_stmt = $db->prepare($check_query);
    $check_stmt->execute();
    $current = $check_stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($current && $current['IS_NULLABLE'] == 'NO') {
        // La columna no permite NULL, modificarla
        $sql = "ALTER TABLE nu_consejo_paciente 
                MODIFY codigo_paciente INT NULL";
        
        $db->exec($sql);
        echo json_encode(array(
            "success" => true,
            "message" => "✅ Columna codigo_paciente modificada para permitir NULL",
            "details" => "Los usuarios sin paciente ahora pueden dar likes y favoritos"
        ));
    } else if ($current && $current['IS_NULLABLE'] == 'YES') {
        echo json_encode(array(
            "success" => true,
            "message" => "ℹ️ La columna ya permite NULL",
            "details" => "No se necesitan cambios"
        ));
    } else {
        echo json_encode(array(
            "success" => false,
            "message" => "⚠️ No se pudo verificar la tabla",
            "details" => "Asegúrate de que la tabla nu_consejo_paciente existe"
        ));
    }
    
} catch (Exception $e) {
    echo json_encode(array(
        "success" => false,
        "error" => "Error modificando tabla",
        "details" => $e->getMessage()
    ));
}
?>
