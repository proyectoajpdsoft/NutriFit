<?php
header("Content-Type: application/json; charset=UTF-8");

include_once '../config/database.php';

try {
    $database = new Database();
    $db = $database->getConnection();
    
    http_response_code(200);
    echo json_encode([
        "status" => "success",
        "message" => "Conexión con la base de datos establecida correctamente."
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Fallo en la conexión con la base de datos.",
        "error_details" => $e->getMessage()
    ]);
}
?>
