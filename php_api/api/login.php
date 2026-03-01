<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

ob_start();
ini_set('display_errors', '0');
ini_set('log_errors', '1');
error_reporting(E_ALL);

function login_send_safe_error_response($http_code = 500, $message = 'No se pudo completar el inicio de sesión. Inténtalo de nuevo.', $code = 'LOGIN_INTERNAL_ERROR') {
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
    error_log("[login.php] Excepción no controlada: " . $exception->getMessage() . " en " . $exception->getFile() . ":" . $exception->getLine());
    login_send_safe_error_response();
    exit();
});

register_shutdown_function(function () {
    $error = error_get_last();
    if (!$error) {
        return;
    }

    $fatal_types = array(E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR, E_USER_ERROR);
    if (in_array($error['type'], $fatal_types, true)) {
        error_log("[login.php] Error fatal: " . $error['message'] . " en " . $error['file'] . ":" . $error['line']);
        login_send_safe_error_response();
        exit();
    }
});

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/permissions.php';
include_once '../auth/token_expiration_config.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

$current_api_base_url = get_current_api_base_url();

$data = json_decode(file_get_contents("php://input"));

$client_api_url = normalize_api_base_url($data->url_api ?? null);
$api_url_to_store = !empty($client_api_url) ? $client_api_url : $current_api_base_url;

if (empty($data->nick) || empty($data->contrasena)) {
    http_response_code(400);
    echo json_encode(array("message" => "Faltan el usuario o la contraseña."));
    exit();
}

$query = "SELECT codigo, nick, contrasena, administrador, tipo, activo, accesoweb, codigo_paciente FROM usuario WHERE nick = :nick LIMIT 0,1";
$stmt = $db->prepare($query);
$stmt->bindParam(':nick', $data->nick);
$stmt->execute();

$num = $stmt->rowCount();

if ($num > 0) {
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    $codigo = $row['codigo'];
    $nick = $row['nick'];
    $contrasena_hash = $row['contrasena'];
    $administrador = $row['administrador'];
    $tipo = $row['tipo'];
    $activo = $row['activo'];
    $accesoweb = $row['accesoweb'];
    $codigo_paciente = $row['codigo_paciente'];

    // Verificar contraseña (¡IMPORTANTE! Deberías usar password_hash() y password_verify())
    // Por simplicidad en este ejemplo, se compara texto plano. ¡CAMBIAR EN PRODUCCIÓN!
    if (password_verify($data->contrasena, $contrasena_hash)) {

        if ($activo != 'S' || $accesoweb != 'S') {
            http_response_code(403); // Forbidden
            echo json_encode(array("message" => "Acceso denegado. El usuario no está activo."));
            log_session($db, $codigo, 'Error_Inactivo');
            exit();
        }

        // Generar un token seguro
        $token = bin2hex(random_bytes(32));
        $hours_to_expire = get_registered_user_token_expiration_hours(
            $db,
            $tipo,
            $codigo_paciente
        );
        $token_expiracion = build_token_expiration_datetime_or_null($hours_to_expire);

        // Guardar token y URL API efectiva para el usuario autenticado
        $update_ok = false;
        $update_query = "UPDATE usuario
                         SET token = :token,
                             token_expiracion = :token_expiracion,
                             url_api = :url_api
                         WHERE codigo = :codigo";
        $update_stmt = $db->prepare($update_query);

        if ($update_stmt) {
            $update_stmt->bindParam(':token', $token);
            $update_stmt->bindParam(':token_expiracion', $token_expiracion);
            $update_stmt->bindParam(':url_api', $api_url_to_store);
            $update_stmt->bindParam(':codigo', $codigo);
            $update_ok = $update_stmt->execute();
        }

        // Fallback por compatibilidad si el campo url_api aún no existe en algún entorno
        if (!$update_ok) {
            $fallback_query = "UPDATE usuario SET token = :token, token_expiracion = :token_expiracion WHERE codigo = :codigo";
            $fallback_stmt = $db->prepare($fallback_query);
            if ($fallback_stmt) {
                $fallback_stmt->bindParam(':token', $token);
                $fallback_stmt->bindParam(':token_expiracion', $token_expiracion);
                $fallback_stmt->bindParam(':codigo', $codigo);
                $update_ok = $fallback_stmt->execute();
            }
        }

        if ($update_ok) {
            log_session($db, $codigo, 'OK', $data->dispositivo_tipo ?? null);
            http_response_code(200);
            echo json_encode(array(
                "message" => "Inicio de sesión correcto.",
                "token" => $token,
                "token_expira_horas" => $hours_to_expire,
                "usuario" => array(
                    "codigo" => $codigo,
                    "nick" => $nick,
                    "administrador" => $administrador,
                    "tipo" => $tipo,
                    "codigo_paciente" => $codigo_paciente
                )
            ));
        } else {
            $sql_error = $update_stmt ? $update_stmt->errorInfo() : array('prepare_failed');
            error_log("[login.php] Fallo update token/url_api usuario {$codigo}: " . json_encode($sql_error));
            http_response_code(503);
            echo json_encode(array("message" => "No se pudo actualizar el token."));
        }
    } else {
        http_response_code(401); // Unauthorized
        echo json_encode(array(
            "message" => "Contraseña incorrecta.",
            "code" => "INVALID_PASSWORD"
        ));
        log_session($db, $codigo, 'Error_Pass', $data->dispositivo_tipo ?? null);
    }
} else {
    http_response_code(404);
    echo json_encode(array("message" => "Usuario no encontrado."));
    // Registrar intento con usuario inválido - usar código 0 o especial para usuario no encontrado
    log_session($db, 0, 'Error_Usuario_NoExiste', $data->dispositivo_tipo ?? null);
}

function log_session($db, $codigo_usuario, $estado, $tipo_dispositivo = null) {
    // Capturar IP pública percibida por el servidor
    $ip_publica = $_SERVER['REMOTE_ADDR'] ?? null;
    
    // Capturar IP local (si está disponible) - se obtiene del cliente si es enviada
    // En entornos LAN, esto puede venir del header X-Forwarded-For u otro método
    $ip_local = null;
    
    // Obtener fecha y hora actuales
    $fecha = date('Y-m-d');
    $hora = date('H:i:s');

    // Insertar en la tabla sesion con fecha, hora, IPs y tipo de dispositivo
    $query = "INSERT INTO sesion (codigousuario, fecha, hora, estado, ip_local, ip_publica, tipo)
              VALUES (:codigousuario, :fecha, :hora, :estado, :ip_local, :ip_publica, :tipo)";
    try {
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigousuario', $codigo_usuario);
        $stmt->bindParam(':fecha', $fecha);
        $stmt->bindParam(':hora', $hora);
        $stmt->bindParam(':estado', $estado);
        $stmt->bindParam(':ip_local', $ip_local);
        $stmt->bindParam(':ip_publica', $ip_publica);
        $stmt->bindParam(':tipo', $tipo_dispositivo);
        $stmt->execute();
    } catch (Exception $e) {
        // Manejo de errores silencioso para no interrumpir el login
        error_log("Error al registrar sesión: " . $e->getMessage());
    }
}

function get_current_api_base_url() {
    $scheme = 'https';

    if (!empty($_SERVER['HTTP_X_FORWARDED_PROTO'])) {
        $scheme = strtolower(trim(explode(',', $_SERVER['HTTP_X_FORWARDED_PROTO'])[0]));
    } elseif (!empty($_SERVER['REQUEST_SCHEME'])) {
        $scheme = strtolower($_SERVER['REQUEST_SCHEME']);
    } elseif (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') {
        $scheme = 'https';
    } else {
        $scheme = 'http';
    }

    $host = $_SERVER['HTTP_X_FORWARDED_HOST']
        ?? $_SERVER['HTTP_HOST']
        ?? $_SERVER['SERVER_NAME']
        ?? 'localhost';

    $script_name = $_SERVER['SCRIPT_NAME'] ?? '';
    $dir = str_replace('\\', '/', dirname($script_name));
    $dir = rtrim($dir, '/');

    // login.php vive normalmente en /php_api/api/login.php -> base /php_api/
    $base_path = (substr($dir, -4) === '/api') ? substr($dir, 0, -4) : $dir;
    if ($base_path === '.' || $base_path === '/') {
        $base_path = '';
    }

    return $scheme . '://' . $host . $base_path . '/';
}

function normalize_api_base_url($url) {
    $value = trim((string) $url);
    if ($value === '') {
        return '';
    }

    if (!preg_match('#^https?://#i', $value)) {
        return '';
    }

    return rtrim($value, '/') . '/';
}
?>