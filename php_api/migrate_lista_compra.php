<?php
/**
 * Migración: Cambiar tabla nu_lista_compra para usar solo codigo_usuario
 * - Remover columna codigo_paciente
 * - Agregar/actualizar columna codigo_usuario como FK principal
 * - Estructura igual a nu_consejo_usuario y nu_receta_usuario
 */

header("Content-Type: application/json; charset=UTF-8");

require_once 'config/database.php';

$database = new Database();
$db = $database->getConnection();

if (!$db) {
    echo json_encode(array("error" => "No se pudo conectar a la base de datos"));
    exit();
}

try {
    echo "Iniciando migración de nu_lista_compra...\n";
    
    // 1. Remover constraint en codigo_paciente si existe
    $constraintQuery = "SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
                       WHERE TABLE_NAME = 'nu_lista_compra' AND COLUMN_NAME = 'codigo_paciente' AND CONSTRAINT_NAME != 'PRIMARY'";
    $stmt = $db->prepare($constraintQuery);
    $stmt->execute();
    $constraint = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($constraint) {
        echo "- Removiendo constraint en codigo_paciente...\n";
        $dropQuery = "ALTER TABLE nu_lista_compra DROP FOREIGN KEY " . $constraint['CONSTRAINT_NAME'];
        $stmt = $db->prepare($dropQuery);
        $stmt->execute();
        echo "  ✓ Constraint removido\n";
    }
    
    // 2. Remover columna codigo_paciente
    $checkPacienteQuery = "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
                           WHERE TABLE_NAME = 'nu_lista_compra' AND COLUMN_NAME = 'codigo_paciente'";
    $stmt = $db->prepare($checkPacienteQuery);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($result) {
        echo "- Removiendo columna codigo_paciente...\n";
        $dropQuery = "ALTER TABLE nu_lista_compra DROP COLUMN codigo_paciente";
        $stmt = $db->prepare($dropQuery);
        $stmt->execute();
        echo "  ✓ Columna codigo_paciente removida\n";
    }
    
    // 3. Verificar si la columna codigo_usuario ya existe
    $checkQuery = "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'nu_lista_compra' AND COLUMN_NAME = 'codigo_usuario'";
    $stmt = $db->prepare($checkQuery);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$result) {
        echo "- Agregando columna codigo_usuario...\n";
        $alterQuery = "ALTER TABLE nu_lista_compra 
                      ADD COLUMN codigo_usuario INT NOT NULL AFTER codigo,
                      ADD FOREIGN KEY (codigo_usuario) REFERENCES usuario(codigo) ON DELETE CASCADE";
        $stmt = $db->prepare($alterQuery);
        $stmt->execute();
        echo "  ✓ Columna codigo_usuario agregada\n";
    } else {
        echo "- Columna codigo_usuario ya existe\n";
    }
    
    echo "\n✓ Migración completada exitosamente\n";
    echo json_encode(array(
        "success" => true,
        "message" => "Migración completada",
        "changes" => array(
            "codigo_paciente" => "Columna removida",
            "codigo_usuario" => "Configurado como FK principal",
        )
    ));
    
} catch (Exception $e) {
    echo json_encode(array(
        "error" => "Error en la migración: " . $e->getMessage()
    ));
}
?>
