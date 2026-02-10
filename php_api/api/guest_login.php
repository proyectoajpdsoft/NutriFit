<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/auto_validator.php';

$database = new Database();
$db = $database->getConnection();

/**
 * Endpoint: guest_login
 * Genera un token para usuarios sin credenciales
 * 
 * Método: POST
 * Sin parámetros requeridos
 * 
 * Respuesta:
 * {
 *   "token": "uuid-generado",
 *   "user_type": "Guest",
 *   "message": "Sesión de invitado creada"
 * }
 */

// Función para obtener IP del cliente
function getClientIP() {
    if (!empty($_SERVER['HTTP_CLIENT_IP'])) {
        return $_SERVER['HTTP_CLIENT_IP'];
    } elseif (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        return explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'])[0];
    } else {
        return $_SERVER['REMOTE_ADDR'] ?? 'UNKNOWN';
    }
}

try {
    // Generar un token único para guest (UUID v4)
    $token = sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
    
    $ip_publica = getClientIP();
    
    // Crear tabla guest_tokens si no existe
    $create_table = "CREATE TABLE IF NOT EXISTS guest_tokens (
        id INT AUTO_INCREMENT PRIMARY KEY,
        token VARCHAR(255) UNIQUE NOT NULL COLLATE utf8mb4_unicode_ci,
        fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
        fecha_expiracion DATETIME NOT NULL,
        ip_publica VARCHAR(45) COLLATE utf8mb4_unicode_ci,
        activo ENUM('S', 'N') DEFAULT 'S',
        INDEX idx_token (token),
        INDEX idx_expiracion (fecha_expiracion)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
    $db->exec($create_table);
    
    // Guardar el token guest en tabla guest_tokens (válido por 24 horas)
    $query = "INSERT INTO guest_tokens 
              (token, fecha_expiracion, ip_publica, activo) 
              VALUES (:token, DATE_ADD(NOW(), INTERVAL 24 HOUR), :ip_publica, 'S')";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':token', $token);
    $stmt->bindParam(':ip_publica', $ip_publica);
    
    if (!$stmt->execute()) {
        throw new Exception("No se pudo guardar el token guest en la base de datos");
    }
    
    // También registrar sesión guest en tabla sesion para auditoría
    $query_sesion = "INSERT INTO sesion 
                     (codigousuario, fecha, hora, estado, ip_publica) 
                     VALUES (NULL, CURDATE(), CURTIME(), 'OK_GUEST_LOGIN', :ip_publica)";
    
    $stmt_sesion = $db->prepare($query_sesion);
    $stmt_sesion->bindParam(':ip_publica', $ip_publica);
    $stmt_sesion->execute();
    
    http_response_code(200);
    echo json_encode(array(
        "message" => "Sesión de invitado creada correctamente",
        "token" => $token,
        "user_type" => "Guest",
        "expires_in" => 86400
    ));
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(array(
        "error" => "Error creando sesión de invitado",
        "details" => $e->getMessage()
    ));
}
?>
