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

$totp_file_path = __DIR__ . '/../auth/totp.php';
if (file_exists($totp_file_path)) {
    include_once $totp_file_path;
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

$usuario_columns = get_usuario_columns_map($db);
$has_two_factor_enabled_col = isset($usuario_columns['two_factor_enabled']);
$has_two_factor_secret_col = isset($usuario_columns['two_factor_secret']);
$has_two_factor_last_counter_col = isset($usuario_columns['two_factor_last_counter']);
$has_login_failed_attempts_col = isset($usuario_columns['login_failed_attempts']);
$has_login_blocked_until_col = isset($usuario_columns['login_blocked_until']);
$has_url_api_col = isset($usuario_columns['url_api']);

$current_api_base_url = get_current_api_base_url();

$raw_input = file_get_contents("php://input");
$data = json_decode($raw_input);
if (!is_object($data)) {
    $data = (object) [];
}

$client_api_url = normalize_api_base_url($data->url_api ?? null);
$api_url_to_store = !empty($client_api_url) ? $client_api_url : $current_api_base_url;

$trusted_device_id = sanitize_trusted_device_id($data->trusted_device_id ?? null);
$trusted_device_token = trim((string)($data->trusted_device_token ?? ''));
$trust_device_requested = normalize_bool($data->confiar_dispositivo ?? false);

if (empty($data->nick) || empty($data->contrasena)) {
    http_response_code(400);
    echo json_encode(array("message" => "Faltan el usuario o la contraseña."));
    exit();
}

$query_fields = [
    "codigo", "nick", "contrasena", "administrador", "tipo", "activo", "accesoweb", "codigo_paciente", "edad", "altura"
];
if (isset($usuario_columns['premium_expira_fecha'])) {
    $query_fields[] = "premium_expira_fecha";
}
if (isset($usuario_columns['premium_periodo_meses'])) {
    $query_fields[] = "premium_periodo_meses";
}
if ($has_two_factor_enabled_col) {
    $query_fields[] = "two_factor_enabled";
}
if ($has_two_factor_secret_col) {
    $query_fields[] = "two_factor_secret";
}
if ($has_two_factor_last_counter_col) {
    $query_fields[] = "two_factor_last_counter";
}
if ($has_login_failed_attempts_col) {
    $query_fields[] = "login_failed_attempts";
}
if ($has_login_blocked_until_col) {
    $query_fields[] = "login_blocked_until";
}

$query = "SELECT " . implode(', ', $query_fields) . " FROM usuario WHERE nick = :nick LIMIT 0,1";
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
    $edad = $row['edad'];
    $altura = $row['altura'];
    $premium_expira_fecha = $row['premium_expira_fecha'] ?? null;
    $premium_periodo_meses = $row['premium_periodo_meses'] ?? null;
    $two_factor_enabled = strtoupper(trim((string)($row['two_factor_enabled'] ?? 'N')));
    if ($two_factor_enabled !== 'S') {
        $two_factor_enabled = 'N';
    }
    $two_factor_secret = trim((string)($row['two_factor_secret'] ?? ''));
    $two_factor_last_counter = isset($row['two_factor_last_counter']) && $row['two_factor_last_counter'] !== null
        ? (int)$row['two_factor_last_counter']
        : 0;
    $login_failed_attempts = isset($row['login_failed_attempts']) ? (int)$row['login_failed_attempts'] : 0;
    $login_blocked_until = $row['login_blocked_until'] ?? null;
    $matched_counter = null;

    $max_login_attempts = get_login_max_attempts_from_param($db, 'numero_intentos_maximo_login_fallido', 5);
    $blocked_until_ts = !empty($login_blocked_until) ? strtotime($login_blocked_until) : false;
    if ($blocked_until_ts !== false && $blocked_until_ts > time()) {
        $remaining_seconds = $blocked_until_ts - time();
        http_response_code(429);
        echo json_encode(array(
            "message" => "Cuenta temporalmente bloqueada por demasiados intentos fallidos.",
            "code" => "LOGIN_BLOCKED",
            "retry_after_seconds" => $remaining_seconds
        ));
        log_session($db, $codigo, 'Error_Bloqueado', $data->dispositivo_tipo ?? null);
        exit();
    }

    // Verificar contraseña (¡IMPORTANTE! Deberías usar password_hash() y password_verify())
    // Por simplicidad en este ejemplo, se compara texto plano. ¡CAMBIAR EN PRODUCCIÓN!
    if (password_verify($data->contrasena, $contrasena_hash)) {

        if ($two_factor_enabled === 'S' && $two_factor_secret !== '') {
            if (!function_exists('totp_verify_code')) {
                http_response_code(503);
                echo json_encode(array(
                    "message" => "No se pudo completar la verificación 2FA en este momento.",
                    "code" => "TWO_FACTOR_UNAVAILABLE"
                ));
                log_session($db, $codigo, 'Error_2FA_NoDisponible', $data->dispositivo_tipo ?? null);
                exit();
            }

            $trusted_device_ok = false;
            if ($trusted_device_id !== '' && $trusted_device_token !== '') {
                $trusted_device_ok = verify_trusted_device_token(
                    $trusted_device_token,
                    $codigo,
                    $trusted_device_id,
                    $two_factor_secret
                );
            }

            $codigo_2fa = trim((string)($data->codigo_2fa ?? ''));
            if (!$trusted_device_ok && $codigo_2fa === '') {
                http_response_code(401);
                echo json_encode(array(
                    "message" => "Código 2FA requerido.",
                    "code" => "TWO_FACTOR_REQUIRED"
                ));
                log_session($db, $codigo, 'Error_2FA_Requerido', $data->dispositivo_tipo ?? null);
                exit();
            }

            if (!$trusted_device_ok && !totp_verify_code($two_factor_secret, $codigo_2fa, 1, $matched_counter)) {
                register_failed_login_attempt($db, $codigo, $login_failed_attempts, $max_login_attempts);
                $is_locked_now = ((int)$login_failed_attempts + 1) >= $max_login_attempts;
                http_response_code($is_locked_now ? 429 : 401);
                echo json_encode(array(
                    "message" => $is_locked_now
                        ? "Cuenta temporalmente bloqueada por demasiados intentos fallidos."
                        : "Código 2FA incorrecto.",
                    "code" => $is_locked_now ? "LOGIN_BLOCKED" : "INVALID_2FA_CODE"
                ));
                log_session($db, $codigo, 'Error_2FA', $data->dispositivo_tipo ?? null);
                exit();
            }

            if (!$trusted_device_ok && $matched_counter !== null && (int)$matched_counter <= (int)$two_factor_last_counter) {
                register_failed_login_attempt($db, $codigo, $login_failed_attempts, $max_login_attempts);
                http_response_code(401);
                echo json_encode(array(
                    "message" => "Código 2FA ya utilizado. Espera al siguiente código.",
                    "code" => "REUSED_2FA_CODE"
                ));
                log_session($db, $codigo, 'Error_2FA_Reutilizado', $data->dispositivo_tipo ?? null);
                exit();
            }
        }

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
        $update_sets = [
            "token = :token",
            "token_expiracion = :token_expiracion"
        ];
        if ($has_url_api_col) {
            $update_sets[] = "url_api = :url_api";
        }
        if ($has_login_failed_attempts_col) {
            $update_sets[] = "login_failed_attempts = 0";
        }
        if ($has_login_blocked_until_col) {
            $update_sets[] = "login_blocked_until = NULL";
        }
        if ($has_two_factor_last_counter_col) {
            $update_sets[] = "two_factor_last_counter = :two_factor_last_counter";
        }

        $update_query = "UPDATE usuario SET " . implode(', ', $update_sets) . " WHERE codigo = :codigo";
        $update_stmt = $db->prepare($update_query);

        if ($update_stmt) {
            $update_stmt->bindParam(':token', $token);
            $update_stmt->bindParam(':token_expiracion', $token_expiracion);
            if ($has_url_api_col) {
                $update_stmt->bindParam(':url_api', $api_url_to_store);
            }
            if ($has_two_factor_last_counter_col) {
                $two_factor_counter_to_store = ($two_factor_enabled === 'S' && $matched_counter !== null)
                    ? (int)$matched_counter
                    : (int)$two_factor_last_counter;
                $update_stmt->bindValue(':two_factor_last_counter', $two_factor_counter_to_store, PDO::PARAM_INT);
            }
            $update_stmt->bindParam(':codigo', $codigo);
            $update_ok = $update_stmt->execute();
        }

        // Fallback por compatibilidad si el campo url_api aún no existe en algún entorno
        if (!$update_ok) {
            $fallback_query = "UPDATE usuario
                               SET token = :token,
                                   token_expiracion = :token_expiracion,
                                   login_failed_attempts = 0,
                                   login_blocked_until = NULL,
                                   two_factor_last_counter = :two_factor_last_counter
                               WHERE codigo = :codigo";
            $fallback_stmt = $db->prepare($fallback_query);
            if ($fallback_stmt) {
                $fallback_stmt->bindParam(':token', $token);
                $fallback_stmt->bindParam(':token_expiracion', $token_expiracion);
                $two_factor_counter_to_store = ($two_factor_enabled === 'S' && $matched_counter !== null)
                    ? (int)$matched_counter
                    : (int)$two_factor_last_counter;
                $fallback_stmt->bindValue(':two_factor_last_counter', $two_factor_counter_to_store, PDO::PARAM_INT);
                $fallback_stmt->bindParam(':codigo', $codigo);
                $update_ok = $fallback_stmt->execute();
            }
        }

        if ($update_ok) {
            log_session($db, $codigo, 'OK', $data->dispositivo_tipo ?? null);

            $trusted_device_response_token = null;
            if (
                $two_factor_enabled === 'S' &&
                $two_factor_secret !== '' &&
                $trust_device_requested &&
                $trusted_device_id !== '' &&
                $codigo_2fa !== ''
            ) {
                $trusted_device_response_token = generate_trusted_device_token(
                    $codigo,
                    $trusted_device_id,
                    $two_factor_secret,
                    180
                );
            }

            http_response_code(200);
            echo json_encode(array(
                "message" => "Inicio de sesión correcto.",
                "token" => $token,
                "token_expira_horas" => $hours_to_expire,
                "trusted_device_token" => $trusted_device_response_token,
                "usuario" => array(
                    "codigo" => $codigo,
                    "nick" => $nick,
                    "administrador" => $administrador,
                    "tipo" => $tipo,
                    "codigo_paciente" => $codigo_paciente,
                    "edad" => $edad,
                    "altura" => $altura,
                    "premium_expira_fecha" => $premium_expira_fecha,
                    "premium_periodo_meses" => $premium_periodo_meses
                )
            ));
        } else {
            $sql_error = $update_stmt ? $update_stmt->errorInfo() : array('prepare_failed');
            error_log("[login.php] Fallo update token/url_api usuario {$codigo}: " . json_encode($sql_error));
            http_response_code(503);
            echo json_encode(array("message" => "No se pudo actualizar el token."));
        }
    } else {
        register_failed_login_attempt($db, $codigo, $login_failed_attempts, $max_login_attempts);
        $is_locked_now = ((int)$login_failed_attempts + 1) >= $max_login_attempts;
        http_response_code($is_locked_now ? 429 : 401);
        echo json_encode(array(
            "message" => $is_locked_now
                ? "Cuenta temporalmente bloqueada por demasiados intentos fallidos."
                : "Usuario o contraseña incorrectos.",
            "code" => $is_locked_now ? "LOGIN_BLOCKED" : "INVALID_PASSWORD"
        ));
        log_session($db, $codigo, 'Error_Pass', $data->dispositivo_tipo ?? null);
    }
} else {
    http_response_code(404);
    echo json_encode(array("message" => "Usuario o contraseña incorrectos."));
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

    // Evitar duplicados masivos: un solo registro equivalente por ventana de tiempo.
    $query = "INSERT INTO sesion (codigousuario, fecha, hora, estado, ip_local, ip_publica, tipo)
              SELECT :codigousuario, :fecha, :hora, :estado, :ip_local, :ip_publica, :tipo
              FROM DUAL
              WHERE NOT EXISTS (
                  SELECT 1
                  FROM sesion
                  WHERE codigousuario <=> :codigousuario_check
                    AND estado = :estado_check
                    AND ip_publica <=> :ip_publica_check
                    AND TIMESTAMP(fecha, hora) >= DATE_SUB(NOW(), INTERVAL 20 MINUTE)
                  LIMIT 1
              )";
    try {
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigousuario', $codigo_usuario);
        $stmt->bindParam(':fecha', $fecha);
        $stmt->bindParam(':hora', $hora);
        $stmt->bindParam(':estado', $estado);
        $stmt->bindParam(':ip_local', $ip_local);
        $stmt->bindParam(':ip_publica', $ip_publica);
        $stmt->bindParam(':tipo', $tipo_dispositivo);
        $stmt->bindParam(':codigousuario_check', $codigo_usuario);
        $stmt->bindParam(':estado_check', $estado);
        $stmt->bindParam(':ip_publica_check', $ip_publica);
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

function get_login_max_attempts_from_param($db, $param_name, $default_value) {
    $queries = [
        "SELECT valor1 AS valor_intentos FROM parametro WHERE nombre = :nombre LIMIT 1",
        "SELECT valor AS valor_intentos FROM parametro WHERE nombre = :nombre LIMIT 1",
    ];

    foreach ($queries as $query) {
        try {
            $stmt = $db->prepare($query);
            if (!$stmt) {
                continue;
            }
            $stmt->bindParam(':nombre', $param_name, PDO::PARAM_STR);
            if (!$stmt->execute()) {
                continue;
            }
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$row || !isset($row['valor_intentos']) || $row['valor_intentos'] === null || $row['valor_intentos'] === '') {
                continue;
            }
            $val = (int) floor((float) $row['valor_intentos']);
            return max(1, $val);
        } catch (Exception $e) {
            continue;
        }
    }

    return max(1, (int) $default_value);
}

function get_usuario_columns_map($db) {
    $columns = [];
    try {
        $stmt = $db->query("SHOW COLUMNS FROM usuario");
        if ($stmt) {
            while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
                $name = strtolower((string)($row['Field'] ?? ''));
                if ($name !== '') {
                    $columns[$name] = true;
                }
            }
        }
    } catch (Exception $e) {
        // Si falla, devolvemos vacío y usamos modo mínimo seguro.
    }
    return $columns;
}

function register_failed_login_attempt($db, $codigo_usuario, $current_attempts, $max_attempts) {
    $next_attempts = ((int) $current_attempts) + 1;
    $should_block = $next_attempts >= max(1, (int) $max_attempts);
    $blocked_until = $should_block ? date('Y-m-d H:i:s', strtotime('+15 minutes')) : null;

    $query = "UPDATE usuario
              SET login_failed_attempts = :attempts,
                  login_blocked_until = :blocked_until
              WHERE codigo = :codigo";

    try {
        $stmt = $db->prepare($query);
        $stmt->bindParam(':attempts', $next_attempts, PDO::PARAM_INT);
        $stmt->bindParam(':blocked_until', $blocked_until);
        $stmt->bindParam(':codigo', $codigo_usuario, PDO::PARAM_INT);
        $stmt->execute();
    } catch (Exception $e) {
        error_log("Error al actualizar intentos fallidos de login: " . $e->getMessage());
    }
}

function normalize_bool($value) {
    if (is_bool($value)) {
        return $value;
    }
    $normalized = strtolower(trim((string)$value));
    return in_array($normalized, array('1', 'true', 's', 'si', 'sí', 'y', 'yes'), true);
}

function sanitize_trusted_device_id($value) {
    $id = trim((string)$value);
    if ($id === '') {
        return '';
    }
    if (!preg_match('/^[a-zA-Z0-9_-]{16,128}$/', $id)) {
        return '';
    }
    return $id;
}

function trusted_device_signing_key() {
    $base = __FILE__ . '|' . PHP_VERSION . '|nutrifit-trusted-device-v1';
    return hash('sha256', $base);
}

function b64url_encode($data) {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

function b64url_decode($data) {
    $remainder = strlen($data) % 4;
    if ($remainder) {
        $data .= str_repeat('=', 4 - $remainder);
    }
    return base64_decode(strtr($data, '-_', '+/'));
}

function generate_trusted_device_token($user_code, $device_id, $two_factor_secret, $expires_days = 180) {
    $payload = array(
        'v' => 1,
        'uid' => (int)$user_code,
        'did' => (string)$device_id,
        'exp' => time() + ((int)$expires_days * 24 * 60 * 60),
        'th' => hash('sha256', (string)$two_factor_secret),
    );

    $payload_json = json_encode($payload);
    $payload_part = b64url_encode($payload_json);
    $signature = hash_hmac('sha256', $payload_part, trusted_device_signing_key());

    return $payload_part . '.' . $signature;
}

function verify_trusted_device_token($token, $user_code, $device_id, $two_factor_secret) {
    $token = trim((string)$token);
    if ($token === '') {
        return false;
    }

    $parts = explode('.', $token);
    if (count($parts) !== 2) {
        return false;
    }

    $payload_part = $parts[0];
    $signature = $parts[1];
    $expected_signature = hash_hmac('sha256', $payload_part, trusted_device_signing_key());
    if (!hash_equals($expected_signature, $signature)) {
        return false;
    }

    $payload_raw = b64url_decode($payload_part);
    if ($payload_raw === false || $payload_raw === '') {
        return false;
    }

    $payload = json_decode($payload_raw, true);
    if (!is_array($payload)) {
        return false;
    }

    if ((int)($payload['v'] ?? 0) !== 1) {
        return false;
    }
    if ((int)($payload['uid'] ?? 0) !== (int)$user_code) {
        return false;
    }
    if ((string)($payload['did'] ?? '') !== (string)$device_id) {
        return false;
    }
    if ((int)($payload['exp'] ?? 0) < time()) {
        return false;
    }

    $expected_th = hash('sha256', (string)$two_factor_secret);
    if (!hash_equals($expected_th, (string)($payload['th'] ?? ''))) {
        return false;
    }

    return true;
}
?>