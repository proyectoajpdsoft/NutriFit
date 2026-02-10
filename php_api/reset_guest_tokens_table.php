<?php
// Script para resetear la tabla guest_tokens
require_once 'config/database.php';

$database = new Database();
$db = $database->getConnection();

try {
    // Primero, eliminar la tabla si existe
    $drop_sql = "DROP TABLE IF EXISTS guest_tokens";
    $db->exec($drop_sql);
    echo "Tabla eliminada si existía.\n";
    
    // Ahora crear la tabla nueva
    $create_sql = "CREATE TABLE guest_tokens (
        id INT AUTO_INCREMENT PRIMARY KEY,
        token VARCHAR(255) UNIQUE NOT NULL COLLATE utf8mb4_unicode_ci,
        fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
        fecha_expiracion DATETIME NOT NULL,
        ip_publica VARCHAR(45) COLLATE utf8mb4_unicode_ci,
        activo ENUM('S', 'N') DEFAULT 'S',
        INDEX idx_token (token),
        INDEX idx_expiracion (fecha_expiracion)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
    
    $db->exec($create_sql);
    echo json_encode(array("message" => "Tabla guest_tokens recreada correctamente"));
    
} catch (Exception $e) {
    echo json_encode(array("error" => "Error al resetear tabla", "details" => $e->getMessage()));
}
?>
