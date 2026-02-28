<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

ob_start();
ini_set('display_errors', '0');
ini_set('log_errors', '1');
error_reporting(E_ALL);

function guest_send_safe_error_response($http_code = 500, $message = 'No se pudo crear la sesión de invitado. Inténtalo de nuevo.', $code = 'GUEST_LOGIN_INTERNAL_ERROR') {
    if (ob_get_length()) {
        ob_clean();
    }

    if (!headers_sent()) {
        http_response_code($http_code);
        header("Content-Type: application/json; charset=UTF-8");
    }

    echo json_encode(array(
        "message" => $message,
        "code" => $code
    ));
}

set_error_handler(function ($severity, $message, $file, $line) {
    if (!(error_reporting() & $severity)) {
        return false;
    }

    throw new ErrorException($message, 0, $severity, $file, $line);
});

set_exception_handler(function ($exception) {
    error_log("[guest_login.php] Excepción no controlada: " . $exception->getMessage() . " en " . $exception->getFile() . ":" . $exception->getLine());
    guest_send_safe_error_response();
    exit();
});

register_shutdown_function(function () {
    $error = error_get_last();
    if (!$error) {
        return;
    }

    $fatal_types = array(E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR, E_USER_ERROR);
    if (in_array($error['type'], $fatal_types, true)) {
        error_log("[guest_login.php] Error fatal: " . $error['message'] . " en " . $error['file'] . ":" . $error['line']);
        guest_send_safe_error_response();
        exit();
    }
});

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/auto_validator.php';
include_once '../auth/token_expiration_config.php';

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
        fecha_expiracion DATETIME NULL,
        ip_publica VARCHAR(45) COLLATE utf8mb4_unicode_ci,
        activo ENUM('S', 'N') DEFAULT 'S',
        INDEX idx_token (token),
        INDEX idx_expiracion (fecha_expiracion)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
    $db->exec($create_table);
    
    $guest_hours_to_expire = get_guest_token_expiration_hours($db);
    $guest_expiration = build_token_expiration_datetime_or_null($guest_hours_to_expire);

    $query = "INSERT INTO guest_tokens 
              (token, fecha_expiracion, ip_publica, activo) 
              VALUES (:token, :fecha_expiracion, :ip_publica, 'S')";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':token', $token);
    $stmt->bindParam(':fecha_expiracion', $guest_expiration);
    $stmt->bindParam(':ip_publica', $ip_publica);
    
    if (!$stmt->execute()) {
        $sql_error = $stmt->errorInfo();
        error_log("[guest_login.php] Fallo insert guest_tokens: " . json_encode($sql_error));
        throw new Exception("No se pudo guardar el token guest en la base de datos");
    }
    
    // También registrar sesión guest en tabla sesion para auditoría
    $query_sesion = "INSERT INTO sesion 
                     (codigousuario, fecha, hora, estado, ip_publica) 
                     VALUES (NULL, CURDATE(), CURTIME(), 'OK_GUEST_LOGIN', :ip_publica)";
    
    $stmt_sesion = $db->prepare($query_sesion);
    $stmt_sesion->bindParam(':ip_publica', $ip_publica);
    if (!$stmt_sesion->execute()) {
        $sql_error = $stmt_sesion->errorInfo();
        error_log("[guest_login.php] Fallo insert sesion guest: " . json_encode($sql_error));
    }
    
    http_response_code(200);
    echo json_encode(array(
        "message" => "Sesión de invitado creada correctamente",
        "token" => $token,
        "user_type" => "Guest",
        "expires_in" => $guest_hours_to_expire > 0 ? ($guest_hours_to_expire * 3600) : 0,
        "token_expira_horas" => $guest_hours_to_expire
    ));
    
} catch (Exception $e) {
    error_log("[guest_login.php] Error en flujo principal: " . $e->getMessage() . " en " . $e->getFile() . ":" . $e->getLine());
    guest_send_safe_error_response();
}
?>
