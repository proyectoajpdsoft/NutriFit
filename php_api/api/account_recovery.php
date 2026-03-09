<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once '../config/database.php';
require_once '../auth/token_validator.php';

$totp_file_path = __DIR__ . '/../auth/totp.php';
if (file_exists($totp_file_path)) {
    require_once $totp_file_path;
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();
$method = $_SERVER['REQUEST_METHOD'];

$raw_input = file_get_contents('php://input');
$data = json_decode($raw_input);
if (!is_object($data)) {
    $data = (object) [];
}

$action = trim((string)($data->action ?? $_GET['action'] ?? ''));
if ($action === '') {
    http_response_code(400);
    echo json_encode(array('message' => 'Acción no válida.'));
    exit();
}

$public_actions = array(
    'recovery_options',
    'request_password_recovery_email',
    'reset_password_with_email_code',
    'reset_password_with_2fa',
);

$auth_user = null;
if (!in_array($action, $public_actions, true)) {
    $validator = new TokenValidator($db);
    $auth_user = $validator->validateToken();
}

if ($method === 'GET') {
    if ($action === 'email_verification_status') {
        email_verification_status($db, $auth_user);
    } elseif ($action === 'get_smtp_settings') {
        get_smtp_settings($db, $auth_user);
    } else {
        http_response_code(405);
        echo json_encode(array('message' => 'Método no permitido para esta acción.'));
    }
    exit();
}

if ($method !== 'POST') {
    http_response_code(405);
    echo json_encode(array('message' => 'étodo no permitido.'));
    exit();
}

switch ($action) {
    case 'email_verification_status':
        email_verification_status($db, $auth_user);
        break;
    case 'send_email_verification_code':
        send_email_verification_code($db, $auth_user);
        break;
    case 'verify_email_code':
        verify_email_code($db, $auth_user, $data);
        break;
    case 'recovery_options':
        recovery_options($db, $data);
        break;
    case 'request_password_recovery_email':
        request_password_recovery_email($db, $data);
        break;
    case 'reset_password_with_email_code':
        reset_password_with_email_code($db, $data);
        break;
    case 'reset_password_with_2fa':
        reset_password_with_2fa($db, $data);
        break;
    case 'get_smtp_settings':
        get_smtp_settings($db, $auth_user);
        break;
    case 'update_smtp_settings':
        update_smtp_settings($db, $auth_user, $data);
        break;
    case 'encrypt_text_value':
        encrypt_text_value($db, $auth_user, $data);
        break;
    case 'decrypt_text_value':
        decrypt_text_value($db, $auth_user, $data);
        break;
    default:
        http_response_code(400);
        echo json_encode(array('message' => 'Acción no válida.'));
        break;
}

function normalize_bool($value) {
    if (is_bool($value)) {
        return $value;
    }
    $normalized = strtolower(trim((string)$value));
    return in_array($normalized, array('1', 'true', 's', 'si', 'sí', 'y', 'yes'), true);
}

function get_usuario_columns_map($db) {
    $columns = array();
    try {
        $stmt = $db->query('SHOW COLUMNS FROM usuario');
        if ($stmt) {
            while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
                $name = strtolower((string)($row['Field'] ?? ''));
                if ($name !== '') {
                    $columns[$name] = true;
                }
            }
        }
    } catch (Throwable $e) {
    }
    return $columns;
}

function require_usuario_columns($columns_map, $required_names) {
    foreach ($required_names as $name) {
        if (!isset($columns_map[strtolower($name)])) {
            http_response_code(409);
            echo json_encode(array(
                'message' => 'La base de datos no está actualizada. Falta columna: ' . $name,
                'code' => 'MISSING_DB_COLUMN',
            ));
            return false;
        }
    }
    return true;
}

function user_can_manage_smtp($auth_user) {
    $tipo = strtolower(trim((string)($auth_user['tipo'] ?? '')));
    return $tipo === 'nutricionista' || $tipo === 'administrador' || $tipo === 'admin';
}

function get_parametro_valor($db, $nombre) {
    $stmt = $db->prepare('SELECT valor FROM parametro WHERE nombre = :nombre LIMIT 1');
    $stmt->bindParam(':nombre', $nombre, PDO::PARAM_STR);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        return null;
    }
    return (string)($row['valor'] ?? '');
}

function upsert_parametro($db, $nombre, $valor, $descripcion, $categoria, $tipo, $codigo_usuario) {
    $check = $db->prepare('SELECT codigo FROM parametro WHERE nombre = :nombre LIMIT 1');
    $check->bindParam(':nombre', $nombre, PDO::PARAM_STR);
    $check->execute();
    $exists = $check->fetch(PDO::FETCH_ASSOC);

    if ($exists) {
        $update = $db->prepare('UPDATE parametro SET valor = :valor, codusuariom = :codusuariom, fecham = NOW() WHERE nombre = :nombre');
        $update->bindParam(':valor', $valor, PDO::PARAM_STR);
        $update->bindParam(':codusuariom', $codigo_usuario, PDO::PARAM_INT);
        $update->bindParam(':nombre', $nombre, PDO::PARAM_STR);
        return $update->execute();
    }

    $insert = $db->prepare('INSERT INTO parametro (nombre, valor, descripcion, categoria, tipo, codusuarioa, fechaa) VALUES (:nombre, :valor, :descripcion, :categoria, :tipo, :codusuarioa, NOW())');
    $insert->bindParam(':nombre', $nombre, PDO::PARAM_STR);
    $insert->bindParam(':valor', $valor, PDO::PARAM_STR);
    $insert->bindParam(':descripcion', $descripcion, PDO::PARAM_STR);
    $insert->bindParam(':categoria', $categoria, PDO::PARAM_STR);
    $insert->bindParam(':tipo', $tipo, PDO::PARAM_STR);
    $insert->bindParam(':codusuarioa', $codigo_usuario, PDO::PARAM_INT);
    return $insert->execute();
}

function parse_param_bool($value, $default = false) {
    if ($value === null) {
        return $default;
    }
    $normalized = strtoupper(trim((string)$value));
    if ($normalized === '') {
        return $default;
    }
    return in_array($normalized, array('1', 'S', 'SI', 'SÍ', 'Y', 'YES', 'TRUE'), true);
}

function get_password_policy($db) {
    $min_length_raw = get_parametro_valor($db, 'complejidad_contraseña_longitud_minima');
    $min_length = intval($min_length_raw);
    if ($min_length <= 0) {
        $min_length = 8;
    }

    return array(
        'min_length' => $min_length,
        'require_upper_lower' => parse_param_bool(get_parametro_valor($db, 'complejidad_contraseña_mayuscula_minuscula'), false),
        'require_numbers' => parse_param_bool(get_parametro_valor($db, 'complejidad_contraseña_numeros'), false),
        'require_special_chars' => parse_param_bool(get_parametro_valor($db, 'complejidad_contraseña_caracteres_especiales'), false),
    );
}

function validate_password_with_policy($password, $policy) {
    $password = (string)$password;
    $min_length = intval($policy['min_length'] ?? 8);
    if ($min_length <= 0) {
        $min_length = 8;
    }

    if (strlen($password) < $min_length) {
        return 'La nueva contraseña debe tener al menos ' . $min_length . ' caracteres.';
    }

    if (!empty($policy['require_upper_lower'])) {
        if (!preg_match('/[A-Z]/', $password)) {
            return 'La nueva contraseña debe contener al menos una letra mayúscula.';
        }
        if (!preg_match('/[a-z]/', $password)) {
            return 'La nueva contraseña debe contener al menos una letra minúscula.';
        }
    }

    if (!empty($policy['require_numbers']) && !preg_match('/[0-9]/', $password)) {
        return 'La nueva contraseña debe contener al menos un número.';
    }

    if (!empty($policy['require_special_chars']) && !preg_match('/[*,.+\-#$?¿!¡_()\/\\%&]/u', $password)) {
        return 'La nueva contraseña debe contener al menos un carácter especial (* , . + - # $ ? ¿ ! ¡ _ ( ) / \\ % &).';
    }

    return null;
}

function smtp_encryption_key() {
    $env = trim((string)getenv('SMTP_ENCRYPTION_KEY'));
    if ($env !== '') {
        return hash('sha256', $env, true);
    }
    $fallback = __FILE__ . '|nutrifit-smtp-v1';
    return hash('sha256', $fallback, true);
}

function smtp_effective_encryption_key($passphrase = null) {
    $passphrase = trim((string)$passphrase);
    $base_key = smtp_encryption_key();
    if ($passphrase === '') {
        return $base_key;
    }
    return hash('sha256', $base_key . '|' . $passphrase, true);
}

function encrypt_secret_value($plain_text, $passphrase = null) {
    $plain_text = (string)$plain_text;
    if ($plain_text === '') {
        return '';
    }

    if (!function_exists('openssl_encrypt')) {
        return $plain_text;
    }

    $iv = random_bytes(16);
    $cipher = openssl_encrypt($plain_text, 'AES-256-CBC', smtp_effective_encryption_key($passphrase), OPENSSL_RAW_DATA, $iv);
    if ($cipher === false) {
        return $plain_text;
    }
    return 'ENC1:' . base64_encode($iv . $cipher);
}

function decrypt_secret_value($encoded_text, $passphrase = null) {
    $encoded_text = (string)$encoded_text;
    if ($encoded_text === '') {
        return '';
    }

    if (strpos($encoded_text, 'ENC1:') !== 0) {
        return $encoded_text;
    }

    if (!function_exists('openssl_decrypt')) {
        return '';
    }

    $payload = base64_decode(substr($encoded_text, 5), true);
    if ($payload === false || strlen($payload) <= 16) {
        return '';
    }

    $iv = substr($payload, 0, 16);
    $cipher = substr($payload, 16);
    $plain = openssl_decrypt($cipher, 'AES-256-CBC', smtp_effective_encryption_key($passphrase), OPENSSL_RAW_DATA, $iv);
    if ($plain === false) {
        return '';
    }

    return $plain;
}

function load_smtp_settings($db) {
    $host = trim((string)get_parametro_valor($db, 'servidor_smtp'));
    $port_raw = trim((string)get_parametro_valor($db, 'puerto_smtp'));
    $user = trim((string)get_parametro_valor($db, 'usuario_smtp'));
    $pass_encrypted = (string)get_parametro_valor($db, 'contrasena_smtp');
    $port = intval($port_raw);
    if ($port <= 0) {
        $port = 587;
    }

    return array(
        'host' => $host,
        'port' => $port,
        'user' => $user,
        'pass' => decrypt_secret_value($pass_encrypted),
    );
}

function smtp_read_response($fp) {
    $response = '';
    while (($line = fgets($fp, 515)) !== false) {
        $response .= $line;
        if (strlen($line) < 4) {
            break;
        }
        if ($line[3] === ' ') {
            break;
        }
    }
    return $response;
}

function smtp_expect_code($response, $allowed_codes) {
    $code = intval(substr($response, 0, 3));
    return in_array($code, $allowed_codes, true);
}

function smtp_write_command($fp, $command, $allowed_codes) {
    fwrite($fp, $command . "\r\n");
    $response = smtp_read_response($fp);
    if (!smtp_expect_code($response, $allowed_codes)) {
        throw new Exception('SMTP comando fallido: ' . trim($response));
    }
    return $response;
}

function smtp_send_mail($smtp, $to_email, $subject, $body_text) {
    $host = (string)($smtp['host'] ?? '');
    $port = intval($smtp['port'] ?? 0);
    $user = (string)($smtp['user'] ?? '');
    $pass = (string)($smtp['pass'] ?? '');

    if ($host === '' || $port <= 0 || $user === '' || $pass === '') {
        throw new Exception('Configuracion SMTP incompleta.');
    }

    $transport_host = $host;
    if ($port === 465) {
        $transport_host = 'ssl://' . $host;
    }

    $fp = @fsockopen($transport_host, $port, $errno, $errstr, 15);
    if (!$fp) {
        throw new Exception('No se pudo conectar al servidor SMTP.');
    }

    try {
        stream_set_timeout($fp, 20);

        $banner = smtp_read_response($fp);
        if (!smtp_expect_code($banner, array(220))) {
            throw new Exception('SMTP no disponible.');
        }

        smtp_write_command($fp, 'EHLO nutrifit.local', array(250));

        if ($port !== 465) {
            $tls_resp = smtp_write_command($fp, 'STARTTLS', array(220));
            if (!smtp_expect_code($tls_resp, array(220))) {
                throw new Exception('No se pudo iniciar TLS SMTP.');
            }
            if (!stream_socket_enable_crypto($fp, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                throw new Exception('No se pudo activar cifrado TLS SMTP.');
            }
            smtp_write_command($fp, 'EHLO nutrifit.local', array(250));
        }

        smtp_write_command($fp, 'AUTH LOGIN', array(334));
        smtp_write_command($fp, base64_encode($user), array(334));
        smtp_write_command($fp, base64_encode($pass), array(235));

        smtp_write_command($fp, 'MAIL FROM:<' . $user . '>', array(250));
        smtp_write_command($fp, 'RCPT TO:<' . $to_email . '>', array(250, 251));
        smtp_write_command($fp, 'DATA', array(354));

        $safe_subject = '=?UTF-8?B?' . base64_encode($subject) . '?=';
        $headers = array(
            'From: NutriFit <' . $user . '>',
            'To: <' . $to_email . '>',
            'Subject: ' . $safe_subject,
            'MIME-Version: 1.0',
            'Content-Type: text/plain; charset=UTF-8',
            'Content-Transfer-Encoding: 8bit',
        );

        $message = implode("\r\n", $headers) . "\r\n\r\n" . $body_text . "\r\n.";
        smtp_write_command($fp, $message, array(250));
        smtp_write_command($fp, 'QUIT', array(221));
    } finally {
        fclose($fp);
    }
}

function random_digits($length) {
    $length = max(1, intval($length));
    $digits = '';
    for ($i = 0; $i < $length; $i++) {
        $digits .= strval(random_int(0, 9));
    }
    return $digits;
}

function random_alnum_mixed($length) {
    $uppercase = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    $lowercase = 'abcdefghijkmnopqrstuvwxyz';
    $numbers = '23456789';
    $all = $uppercase . $lowercase . $numbers;

    $length = max(6, intval($length));
    $chars = array(
        $uppercase[random_int(0, strlen($uppercase) - 1)],
        $lowercase[random_int(0, strlen($lowercase) - 1)],
        $numbers[random_int(0, strlen($numbers) - 1)],
    );

    while (count($chars) < $length) {
        $chars[] = $all[random_int(0, strlen($all) - 1)];
    }

    shuffle($chars);
    return implode('', $chars);
}

function mask_email($email) {
    $email = trim((string)$email);
    if ($email === '' || strpos($email, '@') === false) {
        return '';
    }

    list($local, $domain) = explode('@', $email, 2);
    if ($local === '') {
        return '***@' . $domain;
    }

    $visible = substr($local, 0, 2);
    return $visible . str_repeat('*', max(1, strlen($local) - 2)) . '@' . $domain;
}

function get_user_by_identifier($db, $identifier) {
    $identifier = trim((string)$identifier);
    if ($identifier === '') {
        return null;
    }

    $columns = get_usuario_columns_map($db);
    $query_fields = array(
        'codigo', 'nick', 'email', 'contrasena', 'activo', 'accesoweb',
    );

    $optional = array(
        'email_verificado',
        'codigo_verificacion_email',
        'codigo_verificacion_email_expira',
        'fecha_verificacion_email',
        'codigo_recuperacion_password',
        'codigo_recuperacion_password_expira',
        'two_factor_enabled',
        'two_factor_secret',
        'two_factor_last_counter',
    );

    foreach ($optional as $field) {
        if (isset($columns[$field])) {
            $query_fields[] = $field;
        }
    }

    $query = 'SELECT ' . implode(', ', $query_fields) . ' FROM usuario WHERE nick = :identifier OR email = :identifier LIMIT 1';
    $stmt = $db->prepare($query);
    $stmt->bindParam(':identifier', $identifier, PDO::PARAM_STR);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        return null;
    }
    return $row;
}

function email_verification_status($db, $auth_user) {
    $columns = get_usuario_columns_map($db);
    if (!require_usuario_columns($columns, array('email_verificado', 'fecha_verificacion_email'))) {
        return;
    }

    $codigo = intval($auth_user['codigo'] ?? 0);
    $stmt = $db->prepare('SELECT email, email_verificado, fecha_verificacion_email FROM usuario WHERE codigo = :codigo LIMIT 1');
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        http_response_code(404);
        echo json_encode(array('message' => 'Usuario no encontrado.'));
        return;
    }

    echo json_encode(array(
        'email' => (string)($row['email'] ?? ''),
        'email_verified' => strtoupper((string)($row['email_verificado'] ?? 'N')) === 'S',
        'verification_date' => $row['fecha_verificacion_email'] ?? null,
    ));
}

function send_email_verification_code($db, $auth_user) {
    $columns = get_usuario_columns_map($db);
    if (!require_usuario_columns($columns, array('email_verificado', 'codigo_verificacion_email', 'codigo_verificacion_email_expira'))) {
        return;
    }

    $codigo = intval($auth_user['codigo'] ?? 0);
    $stmt = $db->prepare('SELECT email FROM usuario WHERE codigo = :codigo LIMIT 1');
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    $email = trim((string)($row['email'] ?? ''));
    if ($email === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Debes indicar un email en tu perfil para verificarlo.'));
        return;
    }

    $code = random_digits(10);
    $expires = date('Y-m-d H:i:s', strtotime('+15 minutes'));

    $upd = $db->prepare('UPDATE usuario SET codigo_verificacion_email = :codigo_verificacion_email, codigo_verificacion_email_expira = :codigo_verificacion_email_expira, email_verificado = :email_verificado WHERE codigo = :codigo');
    $email_not_verified = 'N';
    $upd->bindParam(':codigo_verificacion_email', $code, PDO::PARAM_STR);
    $upd->bindParam(':codigo_verificacion_email_expira', $expires, PDO::PARAM_STR);
    $upd->bindParam(':email_verificado', $email_not_verified, PDO::PARAM_STR);
    $upd->bindParam(':codigo', $codigo, PDO::PARAM_INT);

    if (!$upd->execute()) {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo generar el código de verificación.'));
        return;
    }

    try {
        $smtp = load_smtp_settings($db);
        $subject = 'NutriFit - Verificación de email';
        $body = "Tu código de verificación para la App NutriFit es: {$code}\n\nEste código caduca en 15 minutos.\n\nSi no solicitaste este código, puedes ignorar este mensaje o eliminarlo directamente.\n\nSaludos,\nEl equipo de NutriFit.";
        smtp_send_mail($smtp, $email, $subject, $body);

        echo json_encode(array(
            'message' => 'Código de verificación enviado al email.',
            'expires_at' => $expires,
        ));
    } catch (Throwable $e) {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo enviar el email de verificación.'));
    }
}

function verify_email_code($db, $auth_user, $data) {
    $columns = get_usuario_columns_map($db);
    if (!require_usuario_columns($columns, array('email_verificado', 'codigo_verificacion_email', 'codigo_verificacion_email_expira', 'fecha_verificacion_email'))) {
        return;
    }

    $code = trim((string)($data->code ?? ''));
    if ($code === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Debes indicar el código de verificación.'));
        return;
    }

    $codigo = intval($auth_user['codigo'] ?? 0);
    $stmt = $db->prepare('SELECT codigo_verificacion_email, codigo_verificacion_email_expira FROM usuario WHERE codigo = :codigo LIMIT 1');
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        http_response_code(404);
        echo json_encode(array('message' => 'Usuario no encontrado.'));
        return;
    }

    $stored_code = trim((string)($row['codigo_verificacion_email'] ?? ''));
    $expires = $row['codigo_verificacion_email_expira'] ?? null;

    if ($stored_code === '' || $stored_code !== $code) {
        http_response_code(401);
        echo json_encode(array('message' => 'Código de verificación no válido.'));
        return;
    }

    if (!empty($expires) && strtotime((string)$expires) < time()) {
        http_response_code(401);
        echo json_encode(array('message' => 'El código de verificación ha caducado.'));
        return;
    }

    $upd = $db->prepare('UPDATE usuario SET email_verificado = :email_verificado, fecha_verificacion_email = NOW(), codigo_verificacion_email = NULL, codigo_verificacion_email_expira = NULL WHERE codigo = :codigo');
    $email_verified = 'S';
    $upd->bindParam(':email_verificado', $email_verified, PDO::PARAM_STR);
    $upd->bindParam(':codigo', $codigo, PDO::PARAM_INT);

    if ($upd->execute()) {
        echo json_encode(array('message' => 'Email verificado correctamente.', 'email_verified' => true));
    } else {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo verificar el email.'));
    }
}

function recovery_options($db, $data) {
    $identifier = trim((string)($data->identifier ?? ''));
    if ($identifier === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Debes indicar usuario o email.'));
        return;
    }

    $user = get_user_by_identifier($db, $identifier);
    if (!$user) {
        http_response_code(404);
        echo json_encode(array('message' => 'Usuario no encontrado.'));
        return;
    }

    $methods = array();
    $two_factor_enabled = strtoupper((string)($user['two_factor_enabled'] ?? 'N')) === 'S';
    $email_verified = strtoupper((string)($user['email_verificado'] ?? 'N')) === 'S';

    if ($email_verified && trim((string)($user['email'] ?? '')) !== '') {
        $methods[] = 'email';
    }
    if ($two_factor_enabled && trim((string)($user['two_factor_secret'] ?? '')) !== '') {
        $methods[] = '2fa';
    }

    echo json_encode(array(
        'nick' => (string)($user['nick'] ?? ''),
        'methods' => $methods,
        'email_masked' => mask_email((string)($user['email'] ?? '')),
        'password_policy' => get_password_policy($db),
    ));
}

function request_password_recovery_email($db, $data) {
    $columns = get_usuario_columns_map($db);
    if (!require_usuario_columns($columns, array('email_verificado', 'codigo_recuperacion_password', 'codigo_recuperacion_password_expira'))) {
        return;
    }

    $identifier = trim((string)($data->identifier ?? ''));
    if ($identifier === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Debes indicar usuario o email.'));
        return;
    }

    $user = get_user_by_identifier($db, $identifier);
    if (!$user) {
        http_response_code(404);
        echo json_encode(array('message' => 'Usuario no encontrado.'));
        return;
    }

    $email = trim((string)($user['email'] ?? ''));
    $email_verified = strtoupper((string)($user['email_verificado'] ?? 'N')) === 'S';
    if ($email === '' || !$email_verified) {
        http_response_code(400);
        echo json_encode(array('message' => 'El usuario no tiene email verificado.'));
        return;
    }

    $recovery_code = random_alnum_mixed(12);
    $expires = date('Y-m-d H:i:s', strtotime('+20 minutes'));

    $upd = $db->prepare('UPDATE usuario SET codigo_recuperacion_password = :codigo_recuperacion_password, codigo_recuperacion_password_expira = :codigo_recuperacion_password_expira WHERE codigo = :codigo');
    $upd->bindParam(':codigo_recuperacion_password', $recovery_code, PDO::PARAM_STR);
    $upd->bindParam(':codigo_recuperacion_password_expira', $expires, PDO::PARAM_STR);
    $upd->bindValue(':codigo', intval($user['codigo']), PDO::PARAM_INT);

    if (!$upd->execute()) {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo generar el código de recuperación.'));
        return;
    }

    try {
        $smtp = load_smtp_settings($db);
        $subject = 'NutriFit - Recuperación de contraseña';
        $body = "Tu código de recuperación es: {$recovery_code}\n\nEste código caduca en 20 minutos.";
        smtp_send_mail($smtp, $email, $subject, $body);

        echo json_encode(array(
            'message' => 'Se ha enviado un código de recuperación al email verificado.',
            'expires_at' => $expires,
            'email_masked' => mask_email($email),
        ));
    } catch (Throwable $e) {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo enviar el email de recuperación. Revisa la configuración SMTP.'));
    }
}

function reset_password_with_email_code($db, $data) {
    $columns = get_usuario_columns_map($db);
    if (!require_usuario_columns($columns, array('codigo_recuperacion_password', 'codigo_recuperacion_password_expira'))) {
        return;
    }

    $identifier = trim((string)($data->identifier ?? ''));
    $code = trim((string)($data->code ?? ''));
    $new_password = (string)($data->new_password ?? '');

    if ($identifier === '' || $code === '' || $new_password === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Faltan datos para restablecer la contraseña.'));
        return;
    }

    $password_policy = get_password_policy($db);
    $password_validation_error = validate_password_with_policy($new_password, $password_policy);
    if ($password_validation_error !== null) {
        http_response_code(400);
        echo json_encode(array('message' => $password_validation_error));
        return;
    }

    $user = get_user_by_identifier($db, $identifier);
    if (!$user) {
        http_response_code(404);
        echo json_encode(array('message' => 'Usuario no encontrado.'));
        return;
    }

    $stored_code = trim((string)($user['codigo_recuperacion_password'] ?? ''));
    $expires = $user['codigo_recuperacion_password_expira'] ?? null;

    if ($stored_code === '' || !hash_equals($stored_code, $code)) {
        http_response_code(401);
        echo json_encode(array('message' => 'Código de recuperación no válido.'));
        return;
    }

    if (!empty($expires) && strtotime((string)$expires) < time()) {
        http_response_code(401);
        echo json_encode(array('message' => 'El código de recuperación ha caducado.'));
        return;
    }

    $password_hash = password_hash($new_password, PASSWORD_BCRYPT);
    $upd = $db->prepare('UPDATE usuario SET contrasena = :contrasena, codigo_recuperacion_password = NULL, codigo_recuperacion_password_expira = NULL, login_failed_attempts = 0, login_blocked_until = NULL WHERE codigo = :codigo');
    $upd->bindParam(':contrasena', $password_hash, PDO::PARAM_STR);
    $upd->bindValue(':codigo', intval($user['codigo']), PDO::PARAM_INT);

    if ($upd->execute()) {
        echo json_encode(array('message' => 'Contraseña actualizada correctamente.'));
    } else {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo actualizar la contraseña.'));
    }
}

function reset_password_with_2fa($db, $data) {
    $identifier = trim((string)($data->identifier ?? ''));
    $code_2fa = trim((string)($data->code_2fa ?? ''));
    $new_password = (string)($data->new_password ?? '');

    if ($identifier === '' || $code_2fa === '' || $new_password === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Faltan datos para restablecer la contraseña.'));
        return;
    }

    $password_policy = get_password_policy($db);
    $password_validation_error = validate_password_with_policy($new_password, $password_policy);
    if ($password_validation_error !== null) {
        http_response_code(400);
        echo json_encode(array('message' => $password_validation_error));
        return;
    }

    $user = get_user_by_identifier($db, $identifier);
    if (!$user) {
        http_response_code(404);
        echo json_encode(array('message' => 'Usuario no encontrado.'));
        return;
    }

    $two_factor_enabled = strtoupper((string)($user['two_factor_enabled'] ?? 'N')) === 'S';
    $secret = trim((string)($user['two_factor_secret'] ?? ''));
    if (!$two_factor_enabled || $secret === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'El usuario no tiene 2FA activo.'));
        return;
    }

    if (!function_exists('totp_verify_code')) {
        http_response_code(503);
        echo json_encode(array('message' => 'No se pudo completar la verificacion 2FA en este momento.'));
        return;
    }

    $matched_counter = null;
    if (!totp_verify_code($secret, $code_2fa, 1, $matched_counter)) {
        http_response_code(401);
        echo json_encode(array('message' => 'Código 2FA no válido.'));
        return;
    }

    $last_counter = isset($user['two_factor_last_counter']) ? intval($user['two_factor_last_counter']) : 0;
    if ($matched_counter !== null && intval($matched_counter) <= $last_counter) {
        http_response_code(401);
        echo json_encode(array('message' => 'Código 2FA ya utilizado. Espera al siguiente código.'));
        return;
    }

    $password_hash = password_hash($new_password, PASSWORD_BCRYPT);
    $upd = $db->prepare('UPDATE usuario SET contrasena = :contrasena, two_factor_last_counter = :two_factor_last_counter, login_failed_attempts = 0, login_blocked_until = NULL WHERE codigo = :codigo');
    $upd->bindParam(':contrasena', $password_hash, PDO::PARAM_STR);
    $counter_to_store = $matched_counter !== null ? intval($matched_counter) : $last_counter;
    $upd->bindParam(':two_factor_last_counter', $counter_to_store, PDO::PARAM_INT);
    $upd->bindValue(':codigo', intval($user['codigo']), PDO::PARAM_INT);

    if ($upd->execute()) {
        echo json_encode(array('message' => 'Contraseña actualizada correctamente.'));
    } else {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo actualizar la contraseña.'));
    }
}

function get_smtp_settings($db, $auth_user) {
    if (!user_can_manage_smtp($auth_user)) {
        http_response_code(403);
        echo json_encode(array('message' => 'No tienes permisos para gestionar SMTP.'));
        return;
    }

    $smtp = load_smtp_settings($db);
    echo json_encode(array(
        'servidor_smtp' => $smtp['host'],
        'puerto_smtp' => strval($smtp['port']),
        'usuario_smtp' => $smtp['user'],
        'contrasena_smtp' => '',
        'contrasena_guardada' => $smtp['pass'] !== '',
    ));
}

function update_smtp_settings($db, $auth_user, $data) {
    if (!user_can_manage_smtp($auth_user)) {
        http_response_code(403);
        echo json_encode(array('message' => 'No tienes permisos para gestionar SMTP.'));
        return;
    }

    $host = trim((string)($data->servidor_smtp ?? ''));
    $port = intval($data->puerto_smtp ?? 0);
    $user = trim((string)($data->usuario_smtp ?? ''));
    $password = (string)($data->contrasena_smtp ?? '');
    $keep_password = normalize_bool($data->mantener_contrasena ?? false);

    if ($host === '' || $port <= 0 || $user === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Servidor, puerto y usuario SMTP son obligatorios.'));
        return;
    }

    if (!$keep_password && trim($password) === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Debes indicar la contraseña SMTP o marcar mantener contraseña.'));
        return;
    }

    $current_encrypted_pass = (string)get_parametro_valor($db, 'contrasena_smtp');
    $encrypted_password = $current_encrypted_pass;
    if (!$keep_password) {
        $encrypted_password = encrypt_secret_value($password);
    }

    $codigo_usuario = intval($auth_user['codigo'] ?? 1);

    $ok = true;
    $ok = $ok && upsert_parametro(
        $db,
        'servidor_smtp',
        $host,
        'Servidor SMTP para envio de correos transaccionales',
        'Aplicacion',
        'SMTP',
        $codigo_usuario
    );
    $ok = $ok && upsert_parametro(
        $db,
        'puerto_smtp',
        strval($port),
        'Puerto SMTP para envio de correos transaccionales',
        'Aplicacion',
        'SMTP',
        $codigo_usuario
    );
    $ok = $ok && upsert_parametro(
        $db,
        'usuario_smtp',
        $user,
        'Usuario SMTP para envio de correos transaccionales',
        'Aplicacion',
        'SMTP',
        $codigo_usuario
    );
    $ok = $ok && upsert_parametro(
        $db,
        'contrasena_smtp',
        $encrypted_password,
        'Contrasena SMTP cifrada para envio de correos transaccionales',
        'Aplicacion',
        'SMTP',
        $codigo_usuario
    );

    if (!$ok) {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo guardar la configuración SMTP.'));
        return;
    }

    echo json_encode(array('message' => 'Configuración SMTP guardada correctamente.'));
}

function encrypt_text_value($db, $auth_user, $data) {
    if (!user_can_manage_smtp($auth_user)) {
        http_response_code(403);
        echo json_encode(array('message' => 'No tienes permisos para cifrar valores.'));
        return;
    }

    $plain_text = (string)($data->text ?? '');
    if (trim($plain_text) === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Debes indicar un texto a cifrar.'));
        return;
    }

    $passphrase = (string)($data->passphrase ?? '');
    $encrypted = encrypt_secret_value($plain_text, $passphrase);

    if (strpos($encrypted, 'ENC1:') !== 0) {
        http_response_code(500);
        echo json_encode(array('message' => 'No fue posible cifrar el texto en este servidor.'));
        return;
    }

    echo json_encode(array(
        'encrypted_text' => $encrypted,
        'has_passphrase' => trim($passphrase) !== '',
    ));
}

function decrypt_text_value($db, $auth_user, $data) {
    if (!user_can_manage_smtp($auth_user)) {
        http_response_code(403);
        echo json_encode(array('message' => 'No tienes permisos para descifrar valores.'));
        return;
    }

    $encrypted_text = trim((string)($data->text ?? ''));
    if ($encrypted_text === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Debes indicar un texto a descifrar.'));
        return;
    }

    $passphrase = (string)($data->passphrase ?? '');
    $decrypted = decrypt_secret_value($encrypted_text, $passphrase);

    if (strpos($encrypted_text, 'ENC1:') === 0 && $decrypted === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'No se pudo descifrar. Revisa el texto o la palabra de paso.'));
        return;
    }

    echo json_encode(array(
        'decrypted_text' => $decrypted,
        'was_encrypted' => strpos($encrypted_text, 'ENC1:') === 0,
    ));
}
