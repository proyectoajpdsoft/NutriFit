<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once '../config/database.php';
require_once '../auth/token_validator.php';
require_once '../auth/permissions.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();
$request_method = $_SERVER["REQUEST_METHOD"];

// Permitir registro público (POST con action=register) sin autenticación
// Permitir GET del propio usuario sin permisos especiales
// Permitir PUT del propio usuario sin permisos especiales
// Para otras operaciones, validar token
$requiresAuth = true;
$requiresPermission = true;

if ($request_method === 'POST') {
    $data = json_decode(file_get_contents("php://input"));
    $action = isset($data->action) ? $data->action : 'create';
    
    // Permitir registro sin autenticación
    if ($action === 'register' || $action === 'check_nick' || $action === 'check_email') {
        $requiresAuth = false;
        $requiresPermission = false;
    } elseif ($action === 'delete_self_with_details') {
        // Autoeliminación: requiere usuario autenticado, pero no permisos de administración.
        $requiresPermission = false;
    }
}

if ($request_method === 'GET' && !empty($_GET["codigo"])) {
    // Si está solicitando un usuario específico, validar token pero no permisos especiales
    // Cualquier usuario autenticado puede ver su propia información
    $requiresPermission = false;
}

if ($request_method === 'PUT') {
    // Para actualización, validar token pero verificar permisos después
    // Si está actualizando su propio perfil, no requiere permisos especiales
    $requiresPermission = false;
}

if ($requiresAuth) {
    // Validar token (solo usuarios registrados)
    $validator = new TokenValidator($db);
    $user = $validator->validateToken();
    
    // Solo verificar permisos si es necesario
    if ($requiresPermission) {
        PermissionManager::checkPermission($user, 'usuarios');
    }
    
    // Guardar el usuario validado para usar en update_usuario()
    $GLOBALS['authenticated_user'] = $user;
}

switch($request_method) {
    case 'GET':
        if (isset($_GET["total_usuarios"])) {
            get_total_usuarios();
        } elseif(!empty($_GET["codigo"])) {
            get_usuario(intval($_GET["codigo"]));
        } else {
            get_usuarios();
        }
        break;
    case 'POST':
        handle_post_request();
        break;
    case 'PUT':
        update_usuario();
        break;
    case 'DELETE':
        delete_usuario();
        break;
    default:
        header("HTTP/1.0 405 Method Not Allowed");
        break;
}

function handle_post_request() {
    $data = json_decode(file_get_contents("php://input"));
    $action = isset($data->action) ? $data->action : 'create';
    
    if ($action === 'check_nick') {
        check_nick_exists($data);
    } elseif ($action === 'check_email') {
        check_email_exists($data);
    } elseif ($action === 'register') {
        register_usuario($data);
    } elseif ($action === 'delete_flow_info') {
        get_usuario_delete_flow_info($data);
    } elseif ($action === 'transfer_paciente_asociado') {
        transfer_paciente_asociado($data);
    } elseif ($action === 'delete_with_details') {
        delete_usuario_with_details($data);
    } elseif ($action === 'delete_self_with_details') {
        delete_self_with_details($data);
    } elseif ($action === 'check_dependencies') {
        check_usuario_dependencies($data);
    } elseif ($action === 'delete_cascade') {
        delete_usuario_cascade($data);
    } elseif ($action === 'move_usuario_data') {
        move_usuario_data($data);
    } elseif ($action === 'premium_audit_log') {
        get_usuario_premium_audit_log($data);
    } elseif ($action === 'notify_premium_activation_email') {
        notify_premium_activation_email($data);
    } else {
        create_usuario($data);
    }
}

function get_usuarios() {
    global $db;
    $columns = get_usuario_columns_map_usuarios($db);
    $notDeletedCondition = build_not_deleted_condition_usuarios($db);
    $includeDeleted = isset($_GET['include_deleted']) && $_GET['include_deleted'] === '1';

    $select = "codigo, nick, nombre, email, tipo, activo, accesoweb, administrador, codigo_paciente, edad, altura, img_perfil";
    if (isset($columns['eliminado'])) {
        $select .= ", eliminado";
    }
    if (isset($columns['fecha_eliminacion'])) {
        $select .= ", fecha_eliminacion";
    }
    if (isset($columns['premium_periodo_meses'])) {
        $select .= ", premium_periodo_meses";
    }
    if (isset($columns['premium_expira_fecha'])) {
        $select .= ", premium_expira_fecha";
    }
    if (isset($columns['premium_desde_fecha'])) {
        $select .= ", premium_desde_fecha";
    }
    if (isset($columns['premium_hasta_fecha'])) {
        $select .= ", premium_hasta_fecha";
    }
    if (isset($columns['premium_periodo_meses_solicitado'])) {
        $select .= ", premium_periodo_meses_solicitado";
    }
    if (isset($columns['premium_forma_pago_solicitada'])) {
        $select .= ", premium_forma_pago_solicitada";
    }
    if (isset($columns['premium_solicitud_pendiente'])) {
        $select .= ", premium_solicitud_pendiente";
    }
    if (isset($columns['premium_fecha_solicitud'])) {
        $select .= ", premium_fecha_solicitud";
    }
    if (isset($columns['email_verificado'])) {
        $select .= ", email_verificado";
    }

    // Incluir img_perfil para que se muestre en el listado
    $query = "SELECT $select FROM usuario";
    if (!$includeDeleted) {
        $query .= " WHERE $notDeletedCondition";
    }
    $query .= " ORDER BY nombre";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Convertir img_perfil de BLOB a base64
    foreach ($items as &$item) {
        if ($item['img_perfil'] !== null) {
            $item['img_perfil'] = base64_encode($item['img_perfil']);
        }
    }
    
    echo json_encode($items);
}

function get_total_usuarios() {
    global $db;
    $notDeletedCondition = build_not_deleted_condition_usuarios($db);
    $query = "SELECT COUNT(*) as total FROM usuario WHERE $notDeletedCondition";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($row);
}

function get_usuario($codigo) {
    global $db;
    $columns = get_usuario_columns_map_usuarios($db);
    $notDeletedCondition = build_not_deleted_condition_usuarios($db);
    $includeDeleted = isset($_GET['include_deleted']) && $_GET['include_deleted'] === '1';

    $select = "codigo, nick, nombre, email, tipo, activo, administrador, codigo_paciente, accesoweb, edad, altura, img_perfil";
    if (isset($columns['eliminado'])) {
        $select .= ", eliminado";
    }
    if (isset($columns['fecha_eliminacion'])) {
        $select .= ", fecha_eliminacion";
    }
    if (isset($columns['premium_periodo_meses'])) {
        $select .= ", premium_periodo_meses";
    }
    if (isset($columns['premium_expira_fecha'])) {
        $select .= ", premium_expira_fecha";
    }
    if (isset($columns['premium_desde_fecha'])) {
        $select .= ", premium_desde_fecha";
    }
    if (isset($columns['premium_hasta_fecha'])) {
        $select .= ", premium_hasta_fecha";
    }
    if (isset($columns['premium_periodo_meses_solicitado'])) {
        $select .= ", premium_periodo_meses_solicitado";
    }
    if (isset($columns['premium_forma_pago_solicitada'])) {
        $select .= ", premium_forma_pago_solicitada";
    }
    if (isset($columns['premium_solicitud_pendiente'])) {
        $select .= ", premium_solicitud_pendiente";
    }
    if (isset($columns['premium_fecha_solicitud'])) {
        $select .= ", premium_fecha_solicitud";
    }
    if (isset($columns['email_verificado'])) {
        $select .= ", email_verificado";
    }

    $query = "SELECT $select FROM usuario WHERE codigo = :codigo";
    if (!$includeDeleted) {
        $query .= " AND $notDeletedCondition";
    }
    $query .= " LIMIT 0,1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);
    if($item) {
        // Convertir img_perfil de BLOB a base64 usando PHP
        if ($item['img_perfil'] !== null) {
            $item['img_perfil'] = base64_encode($item['img_perfil']);
        }
        echo json_encode($item);
    } else {
        http_response_code(404);
        echo json_encode(array("message" => "Usuario o contraseña incorrectos."));
    }
}

function get_usuario_premium_audit_log($data) {
    global $db;

    $codigo_usuario = intval($data->codigo_usuario ?? 0);
    if ($codigo_usuario <= 0) {
        http_response_code(400);
        echo json_encode(array('message' => 'Código de usuario no válido.'));
        return;
    }

    if (!usuarios_table_exists($db, 'usuario_premium_auditoria')) {
        http_response_code(200);
        echo json_encode(array());
        return;
    }

    $auditColumns = get_table_columns_map_usuarios($db, 'usuario_premium_auditoria');
    $select = array(
        'id',
        'codigo_usuario',
        'accion',
        'detalle',
        'periodo_meses',
        'forma_pago',
        'codigo_usuario_actor',
        'fecha_accion',
    );
    if (isset($auditColumns['premium_desde'])) {
        $select[] = 'premium_desde';
    }
    if (isset($auditColumns['premium_hasta'])) {
        $select[] = 'premium_hasta';
    }

    $query = 'SELECT ' . implode(', ', $select) . '
              FROM usuario_premium_auditoria
              WHERE codigo_usuario = :codigo_usuario
              ORDER BY fecha_accion DESC, id DESC
              LIMIT 200';

    $stmt = $db->prepare($query);
    $stmt->bindValue(':codigo_usuario', $codigo_usuario, PDO::PARAM_INT);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    http_response_code(200);
    echo json_encode($rows ?: array());
}

function bind_usuario_params($stmt, $data) {
    $data->nick = htmlspecialchars(strip_tags($data->nick));
    $data->nombre = htmlspecialchars(strip_tags($data->nombre ?? ''));
    $data->email = htmlspecialchars(strip_tags($data->email ?? ''));
    
    // Asegurar que activo, accesoweb y administrador sean 'S' o 'N'
    // Maneja: boolean true/false, string 'S'/'N', string 'true'/'false', etc
    $convertToSN = function($value) {
        if ($value === true || $value === 'S' || $value === 'true' || $value === '1' || $value === 1) {
            return 'S';
        }
        return 'N';
    };
    
    $data->activo = $convertToSN($data->activo ?? 'S');
    $data->accesoweb = $convertToSN($data->accesoweb ?? 'S');
    $data->administrador = $convertToSN($data->administrador ?? 'N');
    
    $stmt->bindParam(":nick", $data->nick);
    $stmt->bindParam(":nombre", $data->nombre);
    $stmt->bindParam(":email", $data->email);
    $stmt->bindParam(":tipo", $data->tipo);
    $stmt->bindParam(":activo", $data->activo);
    $stmt->bindParam(":accesoweb", $data->accesoweb);
    $stmt->bindParam(":administrador", $data->administrador);

    $data->codigo_paciente = !empty($data->codigo_paciente) ? $data->codigo_paciente : null;
    $stmt->bindParam(":codigo_paciente", $data->codigo_paciente);

    $edad = null;
    if (isset($data->edad) && $data->edad !== '' && $data->edad !== null) {
        $edad_tmp = intval($data->edad);
        if ($edad_tmp > 0) {
            $edad = $edad_tmp;
        }
    }

    $altura = null;
    if (isset($data->altura) && $data->altura !== '' && $data->altura !== null) {
        $altura_tmp = intval($data->altura);
        if ($altura_tmp > 0) {
            $altura = $altura_tmp;
        }
    }

    $stmt->bindValue(":edad", $edad, $edad === null ? PDO::PARAM_NULL : PDO::PARAM_INT);
    $stmt->bindValue(":altura", $altura, $altura === null ? PDO::PARAM_NULL : PDO::PARAM_INT);
    
    // Manejar imagen de perfil (base64)
    $img_perfil = null;
    if (!empty($data->img_perfil)) {
        // Decodificar base64 a binario
        $img_perfil = base64_decode($data->img_perfil);
    }
    $stmt->bindParam(":img_perfil", $img_perfil, PDO::PARAM_LOB);
}

function get_parametro_valor_usuarios($db, $nombre) {
    $stmt = $db->prepare('SELECT valor FROM parametro WHERE nombre = :nombre LIMIT 1');
    $stmt->bindParam(':nombre', $nombre, PDO::PARAM_STR);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        return null;
    }
    return (string)($row['valor'] ?? '');
}

function apply_template_variables_usuarios($template, $variables) {
    $result = (string)$template;
    foreach ($variables as $key => $value) {
        $result = str_replace('{' . $key . '}', (string)$value, $result);
    }
    return $result;
}

function smtp_encryption_key_usuarios() {
    $env = trim((string)getenv('SMTP_ENCRYPTION_KEY'));
    if ($env !== '') {
        return hash('sha256', $env, true);
    }

    // Compatibilidad con claves SMTP ya guardadas desde account_recovery.php.
    $accountRecoveryPath = realpath(__DIR__ . DIRECTORY_SEPARATOR . 'account_recovery.php');
    if ($accountRecoveryPath === false || $accountRecoveryPath === '') {
        $accountRecoveryPath = __DIR__ . DIRECTORY_SEPARATOR . 'account_recovery.php';
    }

    $fallback = $accountRecoveryPath . '|nutrifit-smtp-v1';
    return hash('sha256', $fallback, true);
}

function smtp_effective_encryption_key_usuarios($passphrase = null) {
    $passphrase = trim((string)$passphrase);
    $base_key = smtp_encryption_key_usuarios();
    if ($passphrase === '') {
        return $base_key;
    }
    return hash('sha256', $base_key . '|' . $passphrase, true);
}

function decrypt_secret_value_usuarios($encoded_text, $passphrase = null) {
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
    $plain = openssl_decrypt($cipher, 'AES-256-CBC', smtp_effective_encryption_key_usuarios($passphrase), OPENSSL_RAW_DATA, $iv);
    if ($plain === false) {
        return '';
    }

    return $plain;
}

function load_smtp_settings_usuarios($db) {
    $host = trim((string)get_parametro_valor_usuarios($db, 'servidor_smtp'));
    $port_raw = trim((string)get_parametro_valor_usuarios($db, 'puerto_smtp'));
    $user = trim((string)get_parametro_valor_usuarios($db, 'usuario_smtp'));
    $pass_encrypted = (string)get_parametro_valor_usuarios($db, 'contrasena_smtp');
    $port = intval($port_raw);
    if ($port <= 0) {
        $port = 587;
    }

    return array(
        'host' => $host,
        'port' => $port,
        'user' => $user,
        'pass' => decrypt_secret_value_usuarios($pass_encrypted),
    );
}

function smtp_read_response_usuarios($fp) {
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

function smtp_expect_code_usuarios($response, $allowed_codes) {
    $code = intval(substr($response, 0, 3));
    return in_array($code, $allowed_codes, true);
}

function smtp_write_command_usuarios($fp, $command, $allowed_codes) {
    fwrite($fp, $command . "\r\n");
    $response = smtp_read_response_usuarios($fp);
    if (!smtp_expect_code_usuarios($response, $allowed_codes)) {
        throw new Exception('SMTP comando fallido: ' . trim($response));
    }
    return $response;
}

function smtp_send_mail_usuarios($smtp, $to_email, $subject, $body_text) {
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

        $banner = smtp_read_response_usuarios($fp);
        if (!smtp_expect_code_usuarios($banner, array(220))) {
            throw new Exception('SMTP no disponible.');
        }

        smtp_write_command_usuarios($fp, 'EHLO nutrifit.local', array(250));

        if ($port !== 465) {
            $tls_resp = smtp_write_command_usuarios($fp, 'STARTTLS', array(220));
            if (!smtp_expect_code_usuarios($tls_resp, array(220))) {
                throw new Exception('No se pudo iniciar TLS SMTP.');
            }
            if (!stream_socket_enable_crypto($fp, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                throw new Exception('No se pudo activar cifrado TLS SMTP.');
            }
            smtp_write_command_usuarios($fp, 'EHLO nutrifit.local', array(250));
        }

        smtp_write_command_usuarios($fp, 'AUTH LOGIN', array(334));
        smtp_write_command_usuarios($fp, base64_encode($user), array(334));
        smtp_write_command_usuarios($fp, base64_encode($pass), array(235));

        smtp_write_command_usuarios($fp, 'MAIL FROM:<' . $user . '>', array(250));
        smtp_write_command_usuarios($fp, 'RCPT TO:<' . $to_email . '>', array(250, 251));
        smtp_write_command_usuarios($fp, 'DATA', array(354));

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
        smtp_write_command_usuarios($fp, $message, array(250));
        smtp_write_command_usuarios($fp, 'QUIT', array(221));
    } finally {
        fclose($fp);
    }
}

function parse_param_bool_usuarios($value, $default = false) {
    if ($value === null) {
        return $default;
    }
    $normalized = strtoupper(trim((string)$value));
    if ($normalized === '') {
        return $default;
    }
    return in_array($normalized, array('1', 'S', 'SI', 'SÍ', 'Y', 'YES', 'TRUE'), true);
}

function get_usuario_columns_map_usuarios($db) {
    static $cache = null;
    if ($cache !== null) {
        return $cache;
    }

    $cache = array();
    try {
        $stmt = $db->query('SHOW COLUMNS FROM usuario');
        $rows = $stmt ? $stmt->fetchAll(PDO::FETCH_ASSOC) : array();
        foreach ($rows as $row) {
            $field = strtolower(trim((string)($row['Field'] ?? '')));
            if ($field !== '') {
                $cache[$field] = true;
            }
        }
    } catch (Throwable $e) {
        $cache = array();
    }

    return $cache;
}

function has_soft_delete_columns_usuarios($db) {
    $columns = get_usuario_columns_map_usuarios($db);
    return isset($columns['eliminado']) && isset($columns['fecha_eliminacion']);
}

function build_not_deleted_condition_usuarios($db, $alias = '') {
    $columns = get_usuario_columns_map_usuarios($db);
    if (!isset($columns['eliminado'])) {
        return '1=1';
    }

    $prefix = trim((string)$alias);
    if ($prefix !== '') {
        $prefix = rtrim($prefix, '.') . '.';
    }

    return "COALESCE({$prefix}eliminado, 'N') <> 'S'";
}

function get_table_columns_map_usuarios($db, $tableName) {
    static $cacheByTable = array();
    $cacheKey = strtolower(trim((string)$tableName));
    if ($cacheKey === '') {
        return array();
    }
    if (isset($cacheByTable[$cacheKey])) {
        return $cacheByTable[$cacheKey];
    }

    $columns = array();
    try {
        $stmt = $db->query('SHOW COLUMNS FROM `' . str_replace('`', '``', $tableName) . '`');
        $rows = $stmt ? $stmt->fetchAll(PDO::FETCH_ASSOC) : array();
        foreach ($rows as $row) {
            $field = strtolower(trim((string)($row['Field'] ?? '')));
            if ($field !== '') {
                $columns[$field] = true;
            }
        }
    } catch (Throwable $e) {
        $columns = array();
    }

    $cacheByTable[$cacheKey] = $columns;
    return $columns;
}

function normalize_premium_period_usuarios($value) {
    $allowed = array(1, 3, 6, 12);
    $period = intval($value);
    return in_array($period, $allowed, true) ? $period : null;
}

function compute_premium_expiration_date_usuarios($months, $baseDate = null) {
    $period = normalize_premium_period_usuarios($months);
    if ($period === null) {
        return null;
    }

    try {
        $base = $baseDate ? new DateTime($baseDate) : new DateTime('now');
    } catch (Throwable $e) {
        $base = new DateTime('now');
    }

    $base->setTime(0, 0, 0);
    $base->modify('+' . $period . ' months');
    return $base->format('Y-m-d');
}

function query_has_placeholder_usuarios($sql, $placeholder) {
    $query = (string)$sql;
    if ($query === '') {
        return false;
    }

    $token = ltrim((string)$placeholder, ':');
    if ($token === '') {
        return false;
    }

    return preg_match('/:' . preg_quote($token, '/') . '\\b/', $query) === 1;
}

function bind_premium_usuario_params($stmt, $period, $expiraFecha, $sql = null) {
    $query = $sql ?? ($stmt->queryString ?? '');

    if (query_has_placeholder_usuarios($query, ':premium_periodo_meses')) {
        if ($period === null) {
            $stmt->bindValue(':premium_periodo_meses', null, PDO::PARAM_NULL);
        } else {
            $stmt->bindValue(':premium_periodo_meses', intval($period), PDO::PARAM_INT);
        }
    }

    if (query_has_placeholder_usuarios($query, ':premium_expira_fecha')) {
        if ($expiraFecha === null || trim((string)$expiraFecha) === '') {
            $stmt->bindValue(':premium_expira_fecha', null, PDO::PARAM_NULL);
        } else {
            $stmt->bindValue(':premium_expira_fecha', $expiraFecha, PDO::PARAM_STR);
        }
    }
}

function normalize_iso_date_usuarios($value) {
    $raw = trim((string)$value);
    if ($raw === '') {
        return null;
    }

    if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $raw)) {
        return $raw;
    }

    try {
        $date = new DateTime($raw);
        return $date->format('Y-m-d');
    } catch (Throwable $e) {
        return null;
    }
}

function normalize_pending_flag_usuarios($value, $default = 'N') {
    $normalized = strtoupper(trim((string)$value));
    if ($normalized === '') {
        $normalized = strtoupper(trim((string)$default));
    }
    return $normalized === 'S' ? 'S' : 'N';
}

function bind_extended_premium_usuario_params(
    $stmt,
    $premiumDesdeFecha,
    $premiumHastaFecha,
    $premiumPeriodoSolicitado,
    $premiumFormaPagoSolicitada,
    $premiumSolicitudPendiente,
    $premiumFechaSolicitud,
    $sql = null
) {
    $query = $sql ?? ($stmt->queryString ?? '');

    if (query_has_placeholder_usuarios($query, ':premium_desde_fecha')) {
        if ($premiumDesdeFecha === null || trim((string)$premiumDesdeFecha) === '') {
            $stmt->bindValue(':premium_desde_fecha', null, PDO::PARAM_NULL);
        } else {
            $stmt->bindValue(':premium_desde_fecha', $premiumDesdeFecha, PDO::PARAM_STR);
        }
    }

    if (query_has_placeholder_usuarios($query, ':premium_hasta_fecha')) {
        if ($premiumHastaFecha === null || trim((string)$premiumHastaFecha) === '') {
            $stmt->bindValue(':premium_hasta_fecha', null, PDO::PARAM_NULL);
        } else {
            $stmt->bindValue(':premium_hasta_fecha', $premiumHastaFecha, PDO::PARAM_STR);
        }
    }

    if (query_has_placeholder_usuarios($query, ':premium_periodo_meses_solicitado')) {
        if ($premiumPeriodoSolicitado === null) {
            $stmt->bindValue(':premium_periodo_meses_solicitado', null, PDO::PARAM_NULL);
        } else {
            $stmt->bindValue(':premium_periodo_meses_solicitado', intval($premiumPeriodoSolicitado), PDO::PARAM_INT);
        }
    }

    if (query_has_placeholder_usuarios($query, ':premium_forma_pago_solicitada')) {
        $value = trim((string)$premiumFormaPagoSolicitada);
        if ($value === '') {
            $stmt->bindValue(':premium_forma_pago_solicitada', null, PDO::PARAM_NULL);
        } else {
            $stmt->bindValue(':premium_forma_pago_solicitada', $value, PDO::PARAM_STR);
        }
    }

    if (query_has_placeholder_usuarios($query, ':premium_solicitud_pendiente')) {
        $stmt->bindValue(':premium_solicitud_pendiente', normalize_pending_flag_usuarios($premiumSolicitudPendiente, 'N'), PDO::PARAM_STR);
    }

    if (query_has_placeholder_usuarios($query, ':premium_fecha_solicitud')) {
        if ($premiumFechaSolicitud === null || trim((string)$premiumFechaSolicitud) === '') {
            $stmt->bindValue(':premium_fecha_solicitud', null, PDO::PARAM_NULL);
        } else {
            $stmt->bindValue(':premium_fecha_solicitud', $premiumFechaSolicitud, PDO::PARAM_STR);
        }
    }
}

function usuarios_table_exists($db, $table_name) {
    try {
        $stmt = $db->prepare('SHOW TABLES LIKE :table');
        $stmt->bindParam(':table', $table_name, PDO::PARAM_STR);
        $stmt->execute();
        return $stmt->rowCount() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function log_usuario_premium_auditoria_usuarios($db, $codigo_usuario_objetivo, $accion, $detalle, $actor_codigo, $periodo_meses = null, $forma_pago = null, $desde = null, $hasta = null) {
    if (!usuarios_table_exists($db, 'usuario_premium_auditoria')) {
        return;
    }

    $auditColumns = get_table_columns_map_usuarios($db, 'usuario_premium_auditoria');

    try {
        $insertColumns = array('codigo_usuario', 'accion', 'detalle', 'periodo_meses', 'forma_pago');
        $insertValues = array(':codigo_usuario', ':accion', ':detalle', ':periodo_meses', ':forma_pago');

        if (isset($auditColumns['premium_desde'])) {
            $insertColumns[] = 'premium_desde';
            $insertValues[] = ':premium_desde';
        }
        if (isset($auditColumns['premium_hasta'])) {
            $insertColumns[] = 'premium_hasta';
            $insertValues[] = ':premium_hasta';
        }

        $insertColumns[] = 'codigo_usuario_actor';
        $insertValues[] = ':codigo_usuario_actor';
        $insertColumns[] = 'fecha_accion';
        $insertValues[] = 'NOW()';

        $stmt = $db->prepare(
            'INSERT INTO usuario_premium_auditoria (' . implode(', ', $insertColumns) . ')
             VALUES (' . implode(', ', $insertValues) . ')'
        );
        $stmt->bindValue(':codigo_usuario', intval($codigo_usuario_objetivo), PDO::PARAM_INT);
        $stmt->bindValue(':accion', trim((string)$accion), PDO::PARAM_STR);
        $stmt->bindValue(':detalle', trim((string)$detalle), PDO::PARAM_STR);

        if ($periodo_meses === null) {
            $stmt->bindValue(':periodo_meses', null, PDO::PARAM_NULL);
        } else {
            $stmt->bindValue(':periodo_meses', intval($periodo_meses), PDO::PARAM_INT);
        }

        $formaPago = trim((string)$forma_pago);
        if ($formaPago === '') {
            $stmt->bindValue(':forma_pago', null, PDO::PARAM_NULL);
        } else {
            $stmt->bindValue(':forma_pago', $formaPago, PDO::PARAM_STR);
        }

        if (isset($auditColumns['premium_desde'])) {
            if ($desde === null || trim((string)$desde) === '') {
                $stmt->bindValue(':premium_desde', null, PDO::PARAM_NULL);
            } else {
                $stmt->bindValue(':premium_desde', $desde, PDO::PARAM_STR);
            }
        }

        if (isset($auditColumns['premium_hasta'])) {
            if ($hasta === null || trim((string)$hasta) === '') {
                $stmt->bindValue(':premium_hasta', null, PDO::PARAM_NULL);
            } else {
                $stmt->bindValue(':premium_hasta', $hasta, PDO::PARAM_STR);
            }
        }

        $stmt->bindValue(':codigo_usuario_actor', intval($actor_codigo), PDO::PARAM_INT);
        $stmt->execute();
    } catch (Throwable $e) {
    }
}

function notify_premium_activation_email($data) {
    global $db;

    $codigo_usuario = intval($data->codigo_usuario ?? 0);
    if ($codigo_usuario <= 0) {
        http_response_code(400);
        echo json_encode(array('message' => 'Código de usuario inválido.'));
        return;
    }

    $periodo_meses = normalize_premium_period_usuarios($data->periodo_meses ?? null);
    if ($periodo_meses === null) {
        http_response_code(400);
        echo json_encode(array('message' => 'Período Premium inválido.'));
        return;
    }

    $premium_desde = normalize_iso_date_usuarios($data->premium_desde_fecha ?? null);
    $premium_hasta = normalize_iso_date_usuarios($data->premium_hasta_fecha ?? null);
    if ($premium_desde === null || $premium_hasta === null) {
        http_response_code(400);
        echo json_encode(array('message' => 'Fechas Premium inválidas.'));
        return;
    }

    $notDeletedCondition = build_not_deleted_condition_usuarios($db);
    $stmt = $db->prepare("SELECT codigo, nick, nombre, email FROM usuario WHERE codigo = :codigo AND $notDeletedCondition LIMIT 1");
    $stmt->bindParam(':codigo', $codigo_usuario, PDO::PARAM_INT);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        http_response_code(404);
        echo json_encode(array('message' => 'Usuario no encontrado.'));
        return;
    }

    $email = trim((string)($row['email'] ?? ''));
    if ($email === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'El usuario no tiene email informado.'));
        return;
    }

    $nick = trim((string)($row['nick'] ?? ''));
    $nombre = trim((string)($row['nombre'] ?? ''));
    $display_name = $nombre !== '' ? $nombre : ($nick !== '' ? $nick : ('usuario #' . $codigo_usuario));
    $periodo_label = $periodo_meses === 1 ? '1 mes' : ($periodo_meses . ' meses');
    $desde_texto = date('d/m/Y', strtotime($premium_desde));
    $hasta_texto = date('d/m/Y', strtotime($premium_hasta));

    $variables = array(
        'codigo_usuario' => strval($codigo_usuario),
        'nick_usuario' => ($nick !== '' ? $nick : '-'),
        'nombre_usuario' => $display_name,
        'email_usuario' => $email,
        'periodo_meses' => strval($periodo_meses),
        'periodo_label' => $periodo_label,
        'premium_desde' => $desde_texto,
        'premium_hasta' => $hasta_texto,
    );

    $subject_template = trim((string)get_parametro_valor_usuarios($db, 'premium_activacion_email_asunto'));
    if ($subject_template === '') {
        $subject_template = 'NutriFit - Tu cuenta Premium ha sido activada';
    }

    $body_template = trim((string)get_parametro_valor_usuarios($db, 'premium_activacion_email_plantilla'));
    if ($body_template === '') {
        $body_template =
            "Hola {nombre_usuario},\n\n" .
            "Tu cuenta Premium de NutriFit ha sido activada correctamente.\n" .
            "Periodo activado: {premium_desde} a {premium_hasta} ({periodo_label}).\n\n" .
            "Gracias por confiar en NutriFit.";
    }

    try {
        $smtp = load_smtp_settings_usuarios($db);
        $subject = apply_template_variables_usuarios($subject_template, $variables);
        $body = apply_template_variables_usuarios($body_template, $variables);
        smtp_send_mail_usuarios($smtp, $email, $subject, $body);

        $actor_codigo = intval(($GLOBALS['authenticated_user']['codigo'] ?? 0));
        log_usuario_premium_auditoria_usuarios(
            $db,
            $codigo_usuario,
            'notificacion_activacion_premium_email',
            'Se envió email de activación Premium al usuario.',
            $actor_codigo,
            $periodo_meses,
            null,
            $premium_desde,
            $premium_hasta
        );

        echo json_encode(array('message' => 'Email de activación Premium enviado al usuario.'));
    } catch (Throwable $e) {
        http_response_code(500);
        $detail = trim((string)$e->getMessage());
        if ($detail === '') {
            $detail = 'Error desconocido al enviar correo.';
        }
        echo json_encode(array('message' => 'No se pudo enviar el email de activación Premium: ' . $detail));
    }
}

function get_password_policy_usuarios($db) {
    $min_length_raw = get_parametro_valor_usuarios($db, 'complejidad_contraseña_longitud_minima');
    $min_length = intval($min_length_raw);
    if ($min_length <= 0) {
        $min_length = 8;
    }

    return array(
        'min_length' => $min_length,
        'require_upper_lower' => parse_param_bool_usuarios(get_parametro_valor_usuarios($db, 'complejidad_contraseña_mayuscula_minuscula'), false),
        'require_numbers' => parse_param_bool_usuarios(get_parametro_valor_usuarios($db, 'complejidad_contraseña_numeros'), false),
        'require_special_chars' => parse_param_bool_usuarios(get_parametro_valor_usuarios($db, 'complejidad_contraseña_caracteres_especiales'), false),
    );
}

function validate_password_with_policy_usuarios($password, $policy) {
    $password = (string)$password;
    $min_length = intval($policy['min_length'] ?? 8);
    if ($min_length <= 0) {
        $min_length = 8;
    }

    if (strlen($password) < $min_length) {
        return 'La contraseña debe tener al menos ' . $min_length . ' caracteres.';
    }

    if (!empty($policy['require_upper_lower'])) {
        if (!preg_match('/[A-Z]/', $password)) {
            return 'La contraseña debe contener al menos una letra mayúscula.';
        }
        if (!preg_match('/[a-z]/', $password)) {
            return 'La contraseña debe contener al menos una letra minúscula.';
        }
    }

    if (!empty($policy['require_numbers']) && !preg_match('/[0-9]/', $password)) {
        return 'La contraseña debe contener al menos un número.';
    }

    if (!empty($policy['require_special_chars']) && !preg_match('/[*,.+\-#$?¿!¡_()\/\\%&]/u', $password)) {
        return 'La contraseña debe contener al menos un carácter especial (* , . + - # $ ? ¿ ! ¡ _ ( ) / \\ % &).';
    }

    return null;
}

/// Verifica si un nick ya existe en la base de datos
function check_nick_exists($data) {
    global $db;
    
    if(empty($data->nick)) {
        http_response_code(400);
        echo json_encode(array("message" => "El nick es obligatorio.", "exists" => false));
        return;
    }
    
    $notDeletedCondition = build_not_deleted_condition_usuarios($db);
    $query = "SELECT COUNT(*) as count FROM usuario WHERE nick = :nick AND $notDeletedCondition";
    $stmt = $db->prepare($query);
    $nick = htmlspecialchars(strip_tags($data->nick));
    $stmt->bindParam(':nick', $nick);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    http_response_code(200);
    echo json_encode(array("exists" => $result['count'] > 0));
}

/// Verifica si un email ya existe en la base de datos
function check_email_exists($data) {
    global $db;

    $email = trim((string)($data->email ?? ''));
    if ($email === '') {
        http_response_code(400);
        echo json_encode(array("message" => "El email es obligatorio.", "exists" => false));
        return;
    }

    $exclude_codigo = isset($data->exclude_codigo) ? intval($data->exclude_codigo) : 0;

    $notDeletedCondition = build_not_deleted_condition_usuarios($db);
    $query = "SELECT COUNT(*) as count FROM usuario WHERE LOWER(email) = LOWER(:email) AND $notDeletedCondition";
    if ($exclude_codigo > 0) {
        $query .= " AND codigo <> :exclude_codigo";
    }

    $stmt = $db->prepare($query);
    $email_clean = htmlspecialchars(strip_tags($email));
    $stmt->bindParam(':email', $email_clean, PDO::PARAM_STR);
    if ($exclude_codigo > 0) {
        $stmt->bindParam(':exclude_codigo', $exclude_codigo, PDO::PARAM_INT);
    }
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);

    http_response_code(200);
    echo json_encode(array("exists" => intval($result['count'] ?? 0) > 0));
}

/// Registra un nuevo usuario (guest registration)
function register_usuario($data) {
    global $db;

    // Validar campos obligatorios
    if(empty($data->nick)) {
        http_response_code(400);
        echo json_encode(array("success" => false, "message" => "El nick es obligatorio."));
        return;
    }
    
    if(empty($data->contrasena)) {
        http_response_code(400);
        echo json_encode(array("success" => false, "message" => "La contraseña es obligatoria."));
        return;
    }
    
    if(empty($data->tipo)) {
        http_response_code(400);
        echo json_encode(array("success" => false, "message" => "El tipo de usuario es obligatorio."));
        return;
    }

    $password_policy = get_password_policy_usuarios($db);
    $password_validation_error = validate_password_with_policy_usuarios($data->contrasena, $password_policy);
    if ($password_validation_error !== null) {
        http_response_code(400);
        echo json_encode(array("success" => false, "message" => $password_validation_error));
        return;
    }
    
    // Verificar si el nick ya existe
    $notDeletedCondition = build_not_deleted_condition_usuarios($db);
    $check_query = "SELECT COUNT(*) as count FROM usuario WHERE nick = :nick AND $notDeletedCondition";
    $check_stmt = $db->prepare($check_query);
    $nick = htmlspecialchars(strip_tags($data->nick));
    $check_stmt->bindParam(':nick', $nick);
    $check_stmt->execute();
    $check_result = $check_stmt->fetch(PDO::FETCH_ASSOC);
    
    if($check_result['count'] > 0) {
        http_response_code(400);
        echo json_encode(array("success" => false, "message" => "El nick ya existe."));
        return;
    }
    
    // Hashear la contraseña
    $contrasena_hash = password_hash($data->contrasena, PASSWORD_BCRYPT);
    $tipo = htmlspecialchars(strip_tags($data->tipo));
    $nombre = htmlspecialchars(strip_tags($data->nombre ?? ''));
    $email = htmlspecialchars(strip_tags($data->email ?? ''));
    $codigo_paciente = null;
    $edad = null;
    $altura = null;

    if (isset($data->edad) && $data->edad !== '' && $data->edad !== null) {
        $edad_tmp = intval($data->edad);
        if ($edad_tmp > 0) {
            $edad = $edad_tmp;
        }
    }

    if (isset($data->altura) && $data->altura !== '' && $data->altura !== null) {
        $altura_tmp = intval($data->altura);
        if ($altura_tmp > 0) {
            $altura = $altura_tmp;
        }
    }
    
    // Insertar usuario
    $insert_query = "INSERT INTO usuario SET
                nick = :nick,
                nombre = :nombre,
                email = :email,
                contrasena = :contrasena,
                tipo = :tipo,
                activo = 'S',
                accesoweb = 'S',
                administrador = 'N',
                codigo_paciente = :codigo_paciente,
                edad = :edad,
                altura = :altura,
                img_perfil = NULL,
                fechaa = NOW(),
                codusuarioa = 1";
    
    $insert_stmt = $db->prepare($insert_query);
    $insert_stmt->bindParam(':nick', $nick);
    $insert_stmt->bindParam(':contrasena', $contrasena_hash);
    $insert_stmt->bindParam(':tipo', $tipo);
    $insert_stmt->bindParam(':nombre', $nombre);
    $insert_stmt->bindParam(':email', $email);
    $insert_stmt->bindParam(':codigo_paciente', $codigo_paciente);
    $insert_stmt->bindValue(':edad', $edad, $edad === null ? PDO::PARAM_NULL : PDO::PARAM_INT);
    $insert_stmt->bindValue(':altura', $altura, $altura === null ? PDO::PARAM_NULL : PDO::PARAM_INT);
    
    if($insert_stmt->execute()) {
        http_response_code(201);
        echo json_encode(array(
            "success" => true,
            "message" => "Usuario registrado correctamente."
        ));
    } else {
        http_response_code(503);
        echo json_encode(array(
            "success" => false,
            "message" => "No se pudo registrar el usuario.",
            "errorInfo" => $insert_stmt->errorInfo()
        ));
    }
}

function create_usuario($data = null) {
    global $db;
    if ($data === null) {
        $data = json_decode(file_get_contents("php://input"));
    }

    if(empty($data->contrasena)) {
        http_response_code(400);
        echo json_encode(array("message" => "La contraseña es obligatoria."));
        return;
    }

    $password_policy = get_password_policy_usuarios($db);
    $password_validation_error = validate_password_with_policy_usuarios($data->contrasena, $password_policy);
    if ($password_validation_error !== null) {
        http_response_code(400);
        echo json_encode(array("message" => $password_validation_error));
        return;
    }
    
    // ¡¡¡IMPORTANTE: Hashear la contraseña!!!
    $contrasena_hash = password_hash($data->contrasena, PASSWORD_BCRYPT);
    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;
    $columns = get_usuario_columns_map_usuarios($db);

    $tipoNuevo = strtolower(trim((string)($data->tipo ?? '')));
    $premiumPeriodoMeses = null;
    $premiumExpiraFecha = null;
    $premiumDesdeFecha = null;
    $premiumHastaFecha = null;
    $premiumPeriodoMesesSolicitado = normalize_premium_period_usuarios($data->premium_periodo_meses_solicitado ?? null);
    $premiumFormaPagoSolicitada = trim((string)($data->premium_forma_pago_solicitada ?? ''));
    $premiumSolicitudPendiente = normalize_pending_flag_usuarios($data->premium_solicitud_pendiente ?? 'N', 'N');
    $premiumFechaSolicitud = null;
    if (!empty($data->premium_fecha_solicitud)) {
        try {
            $premiumFechaSolicitud = (new DateTime((string)$data->premium_fecha_solicitud))->format('Y-m-d');
        } catch (Throwable $e) {
            $premiumFechaSolicitud = null;
        }
    }
    if ($tipoNuevo === 'premium') {
        $premiumPeriodoMeses = normalize_premium_period_usuarios($data->premium_periodo_meses ?? 1);
        if ($premiumPeriodoMeses === null) {
            $premiumPeriodoMeses = 1;
        }
        $premiumExpiraFecha = compute_premium_expiration_date_usuarios($premiumPeriodoMeses);
        $premiumDesdeFecha = normalize_iso_date_usuarios($data->premium_desde_fecha ?? null);
        if ($premiumDesdeFecha === null) {
            $premiumDesdeFecha = date('Y-m-d');
        }
        $premiumHastaFecha = normalize_iso_date_usuarios($data->premium_hasta_fecha ?? null);
        if ($premiumHastaFecha === null) {
            $premiumHastaFecha = $premiumExpiraFecha;
        }
        if ($premiumHastaFecha !== null) {
            $premiumExpiraFecha = $premiumHastaFecha;
        }
        $premiumSolicitudPendiente = 'N';
    }
    
    $query = "INSERT INTO usuario SET
                nick = :nick, nombre = :nombre, email = :email, contrasena = :contrasena,
                tipo = :tipo, activo = :activo, accesoweb = :accesoweb, administrador = :administrador,
                codigo_paciente = :codigo_paciente, edad = :edad, altura = :altura,
                img_perfil = :img_perfil, fechaa = NOW(), codusuarioa = :codusuarioa";

    if (isset($columns['premium_periodo_meses'])) {
        $query .= ", premium_periodo_meses = :premium_periodo_meses";
    }
    if (isset($columns['premium_expira_fecha'])) {
        $query .= ", premium_expira_fecha = :premium_expira_fecha";
    }
    if (isset($columns['premium_desde_fecha'])) {
        $query .= ", premium_desde_fecha = :premium_desde_fecha";
    }
    if (isset($columns['premium_hasta_fecha'])) {
        $query .= ", premium_hasta_fecha = :premium_hasta_fecha";
    }
    if (isset($columns['premium_periodo_meses_solicitado'])) {
        $query .= ", premium_periodo_meses_solicitado = :premium_periodo_meses_solicitado";
    }
    if (isset($columns['premium_forma_pago_solicitada'])) {
        $query .= ", premium_forma_pago_solicitada = :premium_forma_pago_solicitada";
    }
    if (isset($columns['premium_solicitud_pendiente'])) {
        $query .= ", premium_solicitud_pendiente = :premium_solicitud_pendiente";
    }
    if (isset($columns['premium_fecha_solicitud'])) {
        $query .= ", premium_fecha_solicitud = :premium_fecha_solicitud";
    }
    
    $stmt = $db->prepare($query);
    bind_usuario_params($stmt, $data);
    bind_premium_usuario_params($stmt, $premiumPeriodoMeses, $premiumExpiraFecha, $query);
    bind_extended_premium_usuario_params(
        $stmt,
        $premiumDesdeFecha,
        $premiumHastaFecha,
        $premiumPeriodoMesesSolicitado,
        $premiumFormaPagoSolicitada,
        $premiumSolicitudPendiente,
        $premiumFechaSolicitud,
        $query
    );
    $stmt->bindParam(":contrasena", $contrasena_hash);
    $stmt->bindParam(":codusuarioa", $codusuarioa);
    
    if($stmt->execute()){
        $nuevo_codigo = $db->lastInsertId();
        
        // Si se asignó un paciente, sincronizar registros de consejos y recetas
        $sync_result = array();
        if (!empty($data->codigo_paciente)) {
            $sync_result = sync_usuario_paciente_rel(intval($nuevo_codigo), intval($data->codigo_paciente));
        }
        
        http_response_code(201);
        $response = array("message" => "Usuario creado.", "codigo" => intval($nuevo_codigo));
        if (!empty($sync_result)) {
            $response["consejos_actualizados"] = $sync_result['consejos'] ?? 0;
            $response["recetas_actualizadas"] = $sync_result['recetas'] ?? 0;
            if (($sync_result['consejos'] ?? 0) > 0 || ($sync_result['recetas'] ?? 0) > 0) {
                $msg = array();
                if (($sync_result['consejos'] ?? 0) > 0) {
                    $msg[] = $sync_result['consejos'] . " consejo" . (($sync_result['consejos'] ?? 0) > 1 ? "s" : "");
                }
                if (($sync_result['recetas'] ?? 0) > 0) {
                    $msg[] = $sync_result['recetas'] . " receta" . (($sync_result['recetas'] ?? 0) > 1 ? "s" : "");
                }
                $response["sync_message"] = "Se han actualizado con el nuevo usuario: " . implode(" y ", $msg) . ".";
            }
        }

        if ($tipoNuevo === 'premium') {
            log_usuario_premium_auditoria_usuarios(
                $db,
                intval($nuevo_codigo),
                'alta_premium_manual',
                'Alta de usuario ya marcado como Premium.',
                intval($codusuarioa),
                $premiumPeriodoMeses,
                $premiumFormaPagoSolicitada,
                $premiumDesdeFecha,
                $premiumHastaFecha
            );
        }
        echo json_encode($response);
    } else {
        http_response_code(503);
        echo json_encode(array(
            "message" => "No se pudo crear el usuario.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function update_usuario() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    $columns = get_usuario_columns_map_usuarios($db);

    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del usuario."));
        return;
    }

    $currentSelect = 'tipo, email';
    if (isset($columns['email_verificado'])) {
        $currentSelect .= ', email_verificado';
    }
    if (isset($columns['fecha_verificacion_email'])) {
        $currentSelect .= ', fecha_verificacion_email';
    }
    if (isset($columns['codigo_verificacion_email'])) {
        $currentSelect .= ', codigo_verificacion_email';
    }
    if (isset($columns['codigo_verificacion_email_expira'])) {
        $currentSelect .= ', codigo_verificacion_email_expira';
    }
    if (isset($columns['premium_periodo_meses'])) {
        $currentSelect .= ', premium_periodo_meses';
    }
    if (isset($columns['premium_expira_fecha'])) {
        $currentSelect .= ', premium_expira_fecha';
    }
    if (isset($columns['premium_desde_fecha'])) {
        $currentSelect .= ', premium_desde_fecha';
    }
    if (isset($columns['premium_hasta_fecha'])) {
        $currentSelect .= ', premium_hasta_fecha';
    }
    if (isset($columns['premium_periodo_meses_solicitado'])) {
        $currentSelect .= ', premium_periodo_meses_solicitado';
    }
    if (isset($columns['premium_forma_pago_solicitada'])) {
        $currentSelect .= ', premium_forma_pago_solicitada';
    }
    if (isset($columns['premium_solicitud_pendiente'])) {
        $currentSelect .= ', premium_solicitud_pendiente';
    }
    if (isset($columns['premium_fecha_solicitud'])) {
        $currentSelect .= ', premium_fecha_solicitud';
    }

    $notDeletedCondition = build_not_deleted_condition_usuarios($db);
    $stmtCurrent = $db->prepare("SELECT $currentSelect FROM usuario WHERE codigo = :codigo AND $notDeletedCondition LIMIT 1");
    $stmtCurrent->bindParam(':codigo', $data->codigo, PDO::PARAM_INT);
    $stmtCurrent->execute();
    $currentUserRow = $stmtCurrent->fetch(PDO::FETCH_ASSOC) ?: array();
    if (empty($currentUserRow)) {
        http_response_code(404);
        echo json_encode(array(
            "message" => "Usuario no encontrado."
        ));
        return;
    }
    
    // Verificar si el usuario está actualizando su propio perfil o el de otro
    $authenticated_user = $GLOBALS['authenticated_user'] ?? null;
    $is_updating_own_profile = false;
    $codigo_paciente_anterior = null;
    
    if ($authenticated_user) {
        // Comparar el código del usuario autenticado con el código que se está actualizando
        $user_codigo = intval($authenticated_user['codigo'] ?? 0);
        $target_codigo = intval($data->codigo);
        
        if ($user_codigo === $target_codigo) {
            $is_updating_own_profile = true;
        } else {
            // Si está intentando actualizar otro usuario, verificar permisos de administrador
            try {
                PermissionManager::checkPermission($authenticated_user, 'usuarios');
            } catch (Exception $e) {
                http_response_code(403);
                echo json_encode(array(
                    "error" => "No tienes permiso para actualizar otros usuarios",
                    "code" => "PERMISSION_DENIED"
                ));
                return;
            }
        }
    }
    
    // Si se actualiza propio perfil, mantener campos de rol/asociación protegidos
    // (tipo, administrador y paciente asociado solo los cambia nutricionista/admin).
    if ($is_updating_own_profile) {
        $codigo_paciente_anterior = $authenticated_user['codigo_paciente'] ?? null;
        $data->codigo_paciente = $codigo_paciente_anterior;
        $data->tipo = $authenticated_user['tipo'] ?? ($data->tipo ?? 'Usuario');
        $data->administrador = $authenticated_user['administrador'] ?? 'N';
        if (isset($currentUserRow['premium_periodo_meses'])) {
            $data->premium_periodo_meses = $currentUserRow['premium_periodo_meses'];
        }
    }

    $tipoActual = strtolower(trim((string)($currentUserRow['tipo'] ?? '')));
    $tipoNuevo = strtolower(trim((string)($data->tipo ?? '')));
    $emailActual = trim((string)($currentUserRow['email'] ?? ''));
    $emailNuevo = trim((string)($data->email ?? ''));
    $emailChanged = strcasecmp($emailActual, $emailNuevo) !== 0;
    $premiumPeriodoMeses = null;
    $premiumExpiraFecha = null;
    $premiumDesdeFecha = normalize_iso_date_usuarios($data->premium_desde_fecha ?? ($currentUserRow['premium_desde_fecha'] ?? null));
    $premiumHastaFecha = normalize_iso_date_usuarios($data->premium_hasta_fecha ?? ($currentUserRow['premium_hasta_fecha'] ?? null));
    $premiumPeriodoMesesSolicitado = normalize_premium_period_usuarios($data->premium_periodo_meses_solicitado ?? ($currentUserRow['premium_periodo_meses_solicitado'] ?? null));
    $premiumFormaPagoSolicitada = trim((string)($data->premium_forma_pago_solicitada ?? ($currentUserRow['premium_forma_pago_solicitada'] ?? '')));
    $premiumSolicitudPendiente = normalize_pending_flag_usuarios($data->premium_solicitud_pendiente ?? ($currentUserRow['premium_solicitud_pendiente'] ?? 'N'), 'N');
    $premiumFechaSolicitud = null;
    $premiumFechaSolicitudInput = $data->premium_fecha_solicitud ?? ($currentUserRow['premium_fecha_solicitud'] ?? null);
    if ($premiumFechaSolicitudInput !== null && trim((string)$premiumFechaSolicitudInput) !== '') {
        try {
            $premiumFechaSolicitud = (new DateTime((string)$premiumFechaSolicitudInput))->format('Y-m-d');
        } catch (Throwable $e) {
            $premiumFechaSolicitud = null;
        }
    }

    if ($emailChanged && $emailNuevo !== '') {
        $stmtEmail = $db->prepare('SELECT codigo FROM usuario WHERE LOWER(email) = LOWER(:email) AND codigo <> :codigo LIMIT 1');
        $stmtEmail->bindParam(':email', $emailNuevo, PDO::PARAM_STR);
        $stmtEmail->bindParam(':codigo', $data->codigo, PDO::PARAM_INT);
        $stmtEmail->execute();
        if ($stmtEmail->fetch(PDO::FETCH_ASSOC)) {
            http_response_code(400);
            echo json_encode(array('message' => 'No puede usar esta cuenta de email, indique otra'));
            return;
        }
    }

    if ($tipoNuevo === 'premium') {
        $periodInput = $data->premium_periodo_meses ?? ($currentUserRow['premium_periodo_meses'] ?? null);
        $premiumPeriodoMeses = normalize_premium_period_usuarios($periodInput);
        if ($premiumPeriodoMeses === null) {
            $premiumPeriodoMeses = 1;
        }

        $hasExplicitPeriod = isset($data->premium_periodo_meses);
        $isActivation = $tipoActual !== 'premium';
        $existingExpira = trim((string)($currentUserRow['premium_expira_fecha'] ?? ''));
        $expiredOrMissing = $existingExpira === '' || strtotime($existingExpira) === false || strtotime($existingExpira) < strtotime(date('Y-m-d'));

        if ($isActivation || $hasExplicitPeriod || $expiredOrMissing) {
            $premiumExpiraFecha = compute_premium_expiration_date_usuarios($premiumPeriodoMeses);
        } else {
            $premiumExpiraFecha = $existingExpira;
        }

        if ($premiumDesdeFecha === null) {
            $premiumDesdeFecha = date('Y-m-d');
        }
        if ($premiumHastaFecha === null) {
            $premiumHastaFecha = normalize_iso_date_usuarios($premiumExpiraFecha);
        }
        if ($premiumHastaFecha !== null) {
            $premiumExpiraFecha = $premiumHastaFecha;
        }
        $premiumSolicitudPendiente = 'N';
    } else {
        $premiumDesdeFecha = null;
        $premiumHastaFecha = null;
    }
    
    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;
    
    $sql_pass = "";
    // Si se envía una contraseña, se actualiza. Si no, se deja la que estaba.
    if(!empty($data->contrasena)) {
        $password_policy = get_password_policy_usuarios($db);
        $password_validation_error = validate_password_with_policy_usuarios($data->contrasena, $password_policy);
        if ($password_validation_error !== null) {
            http_response_code(400);
            echo json_encode(array("message" => $password_validation_error));
            return;
        }

        $contrasena_hash = password_hash($data->contrasena, PASSWORD_BCRYPT);
        $sql_pass = ", contrasena = :contrasena";
    }

    $query = "UPDATE usuario SET
                nick = :nick, nombre = :nombre, email = :email,
                tipo = :tipo, activo = :activo, accesoweb = :accesoweb, administrador = :administrador,
                                codigo_paciente = :codigo_paciente, edad = :edad, altura = :altura,
                                img_perfil = :img_perfil, fecham = NOW(), codusuariom = :codusuariom
                $sql_pass
              WHERE codigo = :codigo";

    if ($emailChanged && isset($columns['email_verificado'])) {
        $query = str_replace('img_perfil = :img_perfil,', "img_perfil = :img_perfil, email_verificado = 'N',", $query);
    }
    if ($emailChanged && isset($columns['fecha_verificacion_email'])) {
        $query = str_replace('img_perfil = :img_perfil,', 'img_perfil = :img_perfil, fecha_verificacion_email = NULL,', $query);
    }
    if ($emailChanged && isset($columns['codigo_verificacion_email'])) {
        $query = str_replace('img_perfil = :img_perfil,', 'img_perfil = :img_perfil, codigo_verificacion_email = NULL,', $query);
    }
    if ($emailChanged && isset($columns['codigo_verificacion_email_expira'])) {
        $query = str_replace('img_perfil = :img_perfil,', 'img_perfil = :img_perfil, codigo_verificacion_email_expira = NULL,', $query);
    }

    if (isset($columns['premium_periodo_meses'])) {
        $query = str_replace('img_perfil = :img_perfil, fecham', 'img_perfil = :img_perfil, premium_periodo_meses = :premium_periodo_meses, fecham', $query);
    }
    if (isset($columns['premium_expira_fecha'])) {
        $query = str_replace('img_perfil = :img_perfil,', 'img_perfil = :img_perfil, premium_expira_fecha = :premium_expira_fecha,', $query);
    }
    if (isset($columns['premium_desde_fecha'])) {
        $query = str_replace('img_perfil = :img_perfil,', 'img_perfil = :img_perfil, premium_desde_fecha = :premium_desde_fecha,', $query);
    }
    if (isset($columns['premium_hasta_fecha'])) {
        $query = str_replace('img_perfil = :img_perfil,', 'img_perfil = :img_perfil, premium_hasta_fecha = :premium_hasta_fecha,', $query);
    }
    if (isset($columns['premium_periodo_meses_solicitado'])) {
        $query = str_replace('img_perfil = :img_perfil,', 'img_perfil = :img_perfil, premium_periodo_meses_solicitado = :premium_periodo_meses_solicitado,', $query);
    }
    if (isset($columns['premium_forma_pago_solicitada'])) {
        $query = str_replace('img_perfil = :img_perfil,', 'img_perfil = :img_perfil, premium_forma_pago_solicitada = :premium_forma_pago_solicitada,', $query);
    }
    if (isset($columns['premium_solicitud_pendiente'])) {
        $query = str_replace('img_perfil = :img_perfil,', 'img_perfil = :img_perfil, premium_solicitud_pendiente = :premium_solicitud_pendiente,', $query);
    }
    if (isset($columns['premium_fecha_solicitud'])) {
        $query = str_replace('img_perfil = :img_perfil,', 'img_perfil = :img_perfil, premium_fecha_solicitud = :premium_fecha_solicitud,', $query);
    }

    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);
    $stmt->bindParam(":codusuariom", $codusuariom);
    bind_usuario_params($stmt, $data);
    bind_premium_usuario_params($stmt, $premiumPeriodoMeses, $premiumExpiraFecha, $query);
    bind_extended_premium_usuario_params(
        $stmt,
        $premiumDesdeFecha,
        $premiumHastaFecha,
        $premiumPeriodoMesesSolicitado,
        $premiumFormaPagoSolicitada,
        $premiumSolicitudPendiente,
        $premiumFechaSolicitud,
        $query
    );

    if(!empty($sql_pass)) {
        $stmt->bindParam(":contrasena", $contrasena_hash);
    }

    try {
        $executed = $stmt->execute();
    } catch (Throwable $e) {
        http_response_code(500);
        echo json_encode(array(
            "message" => "Error al actualizar el usuario.",
            "error" => $e->getMessage(),
        ));
        return;
    }

    if($executed){
        // Si se asignó un paciente por parte de un admin (no es actualización del propio perfil), sincronizar registros
        $sync_result = array();
        if (!$is_updating_own_profile && !empty($data->codigo_paciente)) {
            $sync_result = sync_usuario_paciente_rel(intval($data->codigo), intval($data->codigo_paciente));
        }
        
        http_response_code(200);
        $response = array("message" => "Usuario actualizado.", "codigo" => intval($data->codigo));
        if (!empty($sync_result)) {
            $response["consejos_actualizados"] = $sync_result['consejos'] ?? 0;
            $response["recetas_actualizadas"] = $sync_result['recetas'] ?? 0;
            if (($sync_result['consejos'] ?? 0) > 0 || ($sync_result['recetas'] ?? 0) > 0) {
                $msg = array();
                if (($sync_result['consejos'] ?? 0) > 0) {
                    $msg[] = $sync_result['consejos'] . " consejo" . (($sync_result['consejos'] ?? 0) > 1 ? "s" : "");
                }
                if (($sync_result['recetas'] ?? 0) > 0) {
                    $msg[] = $sync_result['recetas'] . " receta" . (($sync_result['recetas'] ?? 0) > 1 ? "s" : "");
                }
                $response["sync_message"] = "Se han actualizado con el usuario: " . implode(" y ", $msg) . ".";
            }
        }

        $is_now_premium = $tipoNuevo === 'premium';
        $was_premium = $tipoActual === 'premium';
        if ($is_now_premium && !$was_premium) {
            log_usuario_premium_auditoria_usuarios(
                $db,
                intval($data->codigo),
                'activacion_premium_manual',
                'El nutricionista/administrador activó Premium al usuario.',
                intval($codusuariom),
                $premiumPeriodoMeses,
                $premiumFormaPagoSolicitada,
                $premiumDesdeFecha,
                $premiumHastaFecha
            );
        } elseif ($is_now_premium && $was_premium) {
            log_usuario_premium_auditoria_usuarios(
                $db,
                intval($data->codigo),
                'actualizacion_periodo_premium',
                'Actualización manual del período Premium del usuario.',
                intval($codusuariom),
                $premiumPeriodoMeses,
                $premiumFormaPagoSolicitada,
                $premiumDesdeFecha,
                $premiumHastaFecha
            );
        } elseif (!$is_now_premium && $was_premium) {
            log_usuario_premium_auditoria_usuarios(
                $db,
                intval($data->codigo),
                'desactivacion_premium_manual',
                'El nutricionista/administrador desactivó Premium al usuario.',
                intval($codusuariom),
                null,
                null,
                null,
                null
            );
        }

        echo json_encode($response);
    } else {
        http_response_code(503);
        echo json_encode(array(
            "message" => "No se pudo actualizar el usuario.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function sync_usuario_paciente_rel($codigo_usuario, $codigo_paciente) {
    global $db;

    if (empty($codigo_usuario) || empty($codigo_paciente)) {
        return array();
    }

    $result = array('consejos' => 0, 'recetas' => 0);
    $tables = array(
        'nu_consejo_usuario' => 'consejos',
        'nu_receta_usuario' => 'recetas'
    );
    
    foreach ($tables as $table => $key) {
        if (!table_exists_usuarios($db, $table)) {
            continue;
        }

        $query = "UPDATE $table
                  SET codigo_usuario = :usuario
                  WHERE codigo_paciente = :paciente
                  AND (codigo_usuario IS NULL OR codigo_usuario = 0)";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':usuario', $codigo_usuario);
        $stmt->bindParam(':paciente', $codigo_paciente);
        $stmt->execute();
        
        // Capturar el número de filas afectadas
        $result[$key] = $stmt->rowCount();
    }
    
    return $result;
}

function table_exists_usuarios($db, $table_name) {
    $query = "SHOW TABLES LIKE :table";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':table', $table_name);
    $stmt->execute();
    return $stmt->rowCount() > 0;
}

function get_usuario_delete_context($codigo_usuario) {
    global $db;
    $notDeletedCondition = build_not_deleted_condition_usuarios($db);

    $stmt = $db->prepare("SELECT codigo, nick, nombre, activo, codigo_paciente FROM usuario WHERE codigo = :codigo AND $notDeletedCondition LIMIT 1");
    $stmt->bindParam(':codigo', $codigo_usuario, PDO::PARAM_INT);
    $stmt->execute();
    $usuario = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$usuario) {
        return null;
    }

    $codigo_paciente = intval($usuario['codigo_paciente'] ?? 0);
    $paciente = null;
    if ($codigo_paciente > 0 && table_exists_usuarios($db, 'nu_paciente')) {
        $pstmt = $db->prepare("SELECT codigo, nombre FROM nu_paciente WHERE codigo = :codigo LIMIT 1");
        $pstmt->bindParam(':codigo', $codigo_paciente, PDO::PARAM_INT);
        $pstmt->execute();
        $paciente = $pstmt->fetch(PDO::FETCH_ASSOC);
    }

    return array(
        'usuario' => $usuario,
        'codigo_paciente' => $codigo_paciente,
        'paciente' => $paciente,
    );
}

function count_usuario_records($sql, $params = array()) {
    global $db;
    try {
        $stmt = $db->prepare($sql);
        if (!$stmt) return 0;
        foreach ($params as $key => $value) {
            $stmt->bindValue($key, intval($value), PDO::PARAM_INT);
        }
        if (!$stmt->execute()) return 0;
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        return intval($row['count'] ?? 0);
    } catch (Throwable $e) {
        return 0;
    }
}

function build_usuario_dependencies($codigo_usuario, $codigo_paciente) {
    global $db;
    $deps = array();

    if (table_exists_usuarios($db, 'nu_adherencia_diaria')) {
        $count = count_usuario_records(
            "SELECT COUNT(*) as count FROM nu_adherencia_diaria WHERE codigo_usuario = :codigo_usuario",
            array(':codigo_usuario' => $codigo_usuario)
        );
        if ($count > 0) $deps['nu_adherencia_diaria'] = $count;
    }

    if (table_exists_usuarios($db, 'nu_consejo_usuario')) {
        $count = count_usuario_records(
            "SELECT COUNT(*) as count FROM nu_consejo_usuario WHERE codigo_usuario = :codigo_usuario",
            array(':codigo_usuario' => $codigo_usuario)
        );
        if ($count > 0) $deps['nu_consejo_usuario'] = $count;
    }

    if (table_exists_usuarios($db, 'nu_entrenamientos_actividad_custom')) {
        $count = count_usuario_records(
            "SELECT COUNT(*) as count FROM nu_entrenamientos_actividad_custom WHERE codigo_usuario = :codigo_usuario",
            array(':codigo_usuario' => $codigo_usuario)
        );
        if ($count > 0) $deps['nu_entrenamientos_actividad_custom'] = $count;
    }

    if (table_exists_usuarios($db, 'nu_lista_compra')) {
        $count = count_usuario_records(
            "SELECT COUNT(*) as count FROM nu_lista_compra WHERE codigo_usuario = :codigo_usuario",
            array(':codigo_usuario' => $codigo_usuario)
        );
        if ($count > 0) $deps['nu_lista_compra'] = $count;
    }

    if (table_exists_usuarios($db, 'sesion')) {
        $count = count_usuario_records(
            "SELECT COUNT(*) as count FROM sesion WHERE codigousuario = :codigo_usuario",
            array(':codigo_usuario' => $codigo_usuario)
        );
        if ($count > 0) $deps['sesion'] = $count;
    }

    if (table_exists_usuarios($db, 'chat_conversation')) {
        $count = count_usuario_records(
            "SELECT COUNT(*) as count FROM chat_conversation WHERE usuario_id = :codigo_usuario",
            array(':codigo_usuario' => $codigo_usuario)
        );
        if ($count > 0) $deps['chat_conversation'] = $count;
    }

    if (table_exists_usuarios($db, 'chat_message') && table_exists_usuarios($db, 'chat_conversation')) {
        $count = count_usuario_records(
            "SELECT COUNT(*) as count
             FROM chat_message m
             INNER JOIN chat_conversation c ON c.id = m.conversation_id
             WHERE c.usuario_id = :codigo_usuario",
            array(':codigo_usuario' => $codigo_usuario)
        );
        if ($count > 0) $deps['chat_message'] = $count;
    }

    if (table_exists_usuarios($db, 'nu_receta_usuario')) {
        $count = count_usuario_records(
            "SELECT COUNT(*) as count FROM nu_receta_usuario WHERE codigo_usuario = :codigo_usuario",
            array(':codigo_usuario' => $codigo_usuario)
        );
        if ($count > 0) $deps['nu_receta_usuario'] = $count;
    }

    if (table_exists_usuarios($db, 'nu_todo_list')) {
        $count = count_usuario_records(
            "SELECT COUNT(*) as count FROM nu_todo_list WHERE codigo_usuario = :codigo_usuario",
            array(':codigo_usuario' => $codigo_usuario)
        );
        if ($count > 0) $deps['nu_todo_list'] = $count;
    }

    if (table_exists_usuarios($db, 'usuario_push_dispositivo')) {
        $count = count_usuario_records(
            "SELECT COUNT(*) as count FROM usuario_push_dispositivo WHERE usuario_codigo = :codigo_usuario",
            array(':codigo_usuario' => $codigo_usuario)
        );
        if ($count > 0) $deps['usuario_push_dispositivo'] = $count;
    }

    if ($codigo_paciente > 0 && table_exists_usuarios($db, 'nu_entrenamientos')) {
        $countEntr = count_usuario_records(
            "SELECT COUNT(*) as count FROM nu_entrenamientos WHERE codigo_paciente = :codigo_paciente",
            array(':codigo_paciente' => $codigo_paciente)
        );
        if ($countEntr > 0) $deps['nu_entrenamientos'] = $countEntr;

        if (table_exists_usuarios($db, 'nu_entrenamientos_ejercicios')) {
            $countEjercicios = count_usuario_records(
                "SELECT COUNT(*) as count
                 FROM nu_entrenamientos_ejercicios ee
                 INNER JOIN nu_entrenamientos e ON e.codigo = ee.codigo_entrenamiento
                 WHERE e.codigo_paciente = :codigo_paciente",
                array(':codigo_paciente' => $codigo_paciente)
            );
            if ($countEjercicios > 0) $deps['nu_entrenamientos_ejercicios'] = $countEjercicios;
        }

        if (table_exists_usuarios($db, 'nu_entrenamientos_imagenes')) {
            $countImgs = count_usuario_records(
                "SELECT COUNT(*) as count
                 FROM nu_entrenamientos_imagenes ei
                 INNER JOIN nu_entrenamientos e ON e.codigo = ei.codigo_entrenamiento
                 WHERE e.codigo_paciente = :codigo_paciente",
                array(':codigo_paciente' => $codigo_paciente)
            );
            if ($countImgs > 0) $deps['nu_entrenamientos_imagenes'] = $countImgs;
        }
    }

    if ($codigo_paciente > 0 && table_exists_usuarios($db, 'nu_paciente_medicion')) {
        $count = count_usuario_records(
            "SELECT COUNT(*) as count FROM nu_paciente_medicion WHERE codigo_paciente = :codigo_paciente",
            array(':codigo_paciente' => $codigo_paciente)
        );
        if ($count > 0) $deps['nu_paciente_medicion'] = $count;
    }

    return $deps;
}

function get_available_transfer_users($codigo_origen) {
    global $db;
        $notDeletedCondition = build_not_deleted_condition_usuarios($db);
    $query = "SELECT codigo, nick, nombre
              FROM usuario
              WHERE codigo <> :codigo_origen
                AND activo = 'S'
                                AND $notDeletedCondition
                AND (codigo_paciente IS NULL OR codigo_paciente = 0)
              ORDER BY nombre, nick";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_origen', $codigo_origen, PDO::PARAM_INT);
    $stmt->execute();
    return $stmt->fetchAll(PDO::FETCH_ASSOC) ?: array();
}

function get_usuario_delete_flow_info($data = null) {
    if ($data === null) {
        $data = json_decode(file_get_contents("php://input"));
    }

    if (!is_object($data) || empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del usuario."));
        return;
    }

    $codigo = intval($data->codigo);
    if ($codigo === 1) {
        http_response_code(403);
        echo json_encode(array("message" => "No se puede eliminar al usuario administrador principal."));
        return;
    }

    $ctx = get_usuario_delete_context($codigo);
    if (!$ctx) {
        http_response_code(404);
        echo json_encode(array("message" => "Usuario o contraseña incorrectos."));
        return;
    }

    $deps = build_usuario_dependencies($codigo, intval($ctx['codigo_paciente'] ?? 0));
    $hasPaciente = intval($ctx['codigo_paciente'] ?? 0) > 0;

    http_response_code(200);
    echo json_encode(array(
        "usuario" => $ctx['usuario'],
        "has_paciente_asociado" => $hasPaciente,
        "paciente_asociado" => $ctx['paciente'],
        "usuarios_destino_disponibles" => $hasPaciente ? get_available_transfer_users($codigo) : array(),
        "dependencies" => $deps,
    ));
}

function transfer_paciente_asociado($data = null) {
    global $db;
    if ($data === null) {
        $data = json_decode(file_get_contents("php://input"));
    }

    if (!is_object($data) || empty($data->codigo_usuario_origen) || empty($data->codigo_usuario_destino)) {
        http_response_code(400);
        echo json_encode(array("message" => "Faltan parámetros de transferencia."));
        return;
    }

    $origen = intval($data->codigo_usuario_origen);
    $destino = intval($data->codigo_usuario_destino);

    if ($origen <= 0 || $destino <= 0 || $origen === $destino) {
        http_response_code(400);
        echo json_encode(array("message" => "Parámetros de transferencia inválidos."));
        return;
    }

    $ctx = get_usuario_delete_context($origen);
    if (!$ctx) {
        http_response_code(404);
        echo json_encode(array("message" => "Usuario origen no encontrado."));
        return;
    }

    $codigo_paciente = intval($ctx['codigo_paciente'] ?? 0);
    if ($codigo_paciente <= 0) {
        http_response_code(409);
        echo json_encode(array("message" => "El usuario origen no tiene paciente asociado."));
        return;
    }

    try {
        $db->beginTransaction();

        $stmtDest = $db->prepare("SELECT codigo, activo, codigo_paciente FROM usuario WHERE codigo = :codigo LIMIT 1 FOR UPDATE");
        $stmtDest->bindParam(':codigo', $destino, PDO::PARAM_INT);
        $stmtDest->execute();
        $usuarioDestino = $stmtDest->fetch(PDO::FETCH_ASSOC);

        if (!$usuarioDestino) {
            $db->rollBack();
            http_response_code(404);
            echo json_encode(array("message" => "Usuario destino no encontrado."));
            return;
        }

        if (($usuarioDestino['activo'] ?? 'N') !== 'S') {
            $db->rollBack();
            http_response_code(409);
            echo json_encode(array("message" => "El usuario destino debe estar activo."));
            return;
        }

        if (intval($usuarioDestino['codigo_paciente'] ?? 0) > 0) {
            $db->rollBack();
            http_response_code(409);
            echo json_encode(array("message" => "El usuario destino ya tiene un paciente asociado."));
            return;
        }

        $stmtUpdateDestino = $db->prepare("UPDATE usuario SET codigo_paciente = :codigo_paciente, fecham = NOW() WHERE codigo = :codigo");
        $stmtUpdateDestino->bindParam(':codigo_paciente', $codigo_paciente, PDO::PARAM_INT);
        $stmtUpdateDestino->bindParam(':codigo', $destino, PDO::PARAM_INT);
        $stmtUpdateDestino->execute();

        $stmtUpdateOrigen = $db->prepare("UPDATE usuario SET codigo_paciente = NULL, fecham = NOW() WHERE codigo = :codigo");
        $stmtUpdateOrigen->bindParam(':codigo', $origen, PDO::PARAM_INT);
        $stmtUpdateOrigen->execute();

        $db->commit();

        http_response_code(200);
        echo json_encode(array(
            "message" => "Paciente asociado transferido correctamente.",
            "codigo_paciente" => $codigo_paciente,
        ));
    } catch (Throwable $e) {
        if ($db->inTransaction()) {
            $db->rollBack();
        }
        http_response_code(500);
        echo json_encode(array("message" => "Error al transferir el paciente asociado."));
    }
}

function execute_usuario_delete_with_details($codigo, $allowPacienteAsociadoDelete = false) {
    global $db;

    if ($codigo === 1) {
        http_response_code(403);
        echo json_encode(array("message" => "No se puede eliminar al usuario administrador principal."));
        return;
    }

    $ctx = get_usuario_delete_context($codigo);
    if (!$ctx) {
        http_response_code(404);
        echo json_encode(array("message" => "Usuario o contraseña incorrectos."));
        return;
    }

    $codigo_paciente = intval($ctx['codigo_paciente'] ?? 0);
    if ($codigo_paciente > 0 && !$allowPacienteAsociadoDelete) {
        http_response_code(409);
        echo json_encode(array(
            "message" => "No se puede eliminar un usuario con paciente asociado. Transfiere primero el paciente.",
        ));
        return;
    }

    $deleted = array(
        'nu_adherencia_diaria' => 0,
        'sesion' => 0,
        'chat_message' => 0,
        'chat_conversation' => 0,
        'nu_consejo_usuario' => 0,
        'nu_paciente_medicion' => 0,
        'nu_entrenamientos' => 0,
        'nu_entrenamientos_ejercicios' => 0,
        'nu_entrenamientos_actividad_custom' => 0,
        'nu_entrenamientos_imagenes' => 0,
        'nu_lista_compra' => 0,
        'nu_receta_usuario' => 0,
        'nu_todo_list' => 0,
        'usuario_push_dispositivo' => 0,
        'usuario' => 0,
    );

    try {
        $db->beginTransaction();

        if (table_exists_usuarios($db, 'nu_adherencia_diaria')) {
            $stmt = $db->prepare("DELETE FROM nu_adherencia_diaria WHERE codigo_usuario = :codigo_usuario");
            $stmt->bindParam(':codigo_usuario', $codigo, PDO::PARAM_INT);
            $stmt->execute();
            $deleted['nu_adherencia_diaria'] = $stmt->rowCount();
        }

        if (table_exists_usuarios($db, 'nu_consejo_usuario')) {
            $stmt = $db->prepare("DELETE FROM nu_consejo_usuario WHERE codigo_usuario = :codigo_usuario");
            $stmt->bindParam(':codigo_usuario', $codigo, PDO::PARAM_INT);
            $stmt->execute();
            $deleted['nu_consejo_usuario'] = $stmt->rowCount();
        }

        if (table_exists_usuarios($db, 'sesion')) {
            $stmt = $db->prepare("DELETE FROM sesion WHERE codigousuario = :codigo_usuario");
            $stmt->bindParam(':codigo_usuario', $codigo, PDO::PARAM_INT);
            $stmt->execute();
            $deleted['sesion'] = $stmt->rowCount();
        }

        if (table_exists_usuarios($db, 'chat_conversation')) {
            $stmtConvs = $db->prepare("SELECT id FROM chat_conversation WHERE usuario_id = :codigo_usuario");
            $stmtConvs->bindParam(':codigo_usuario', $codigo, PDO::PARAM_INT);
            $stmtConvs->execute();
            $conversations = $stmtConvs->fetchAll(PDO::FETCH_ASSOC);
            $conversationIds = array_map('intval', array_column($conversations, 'id'));

            if (!empty($conversationIds) && table_exists_usuarios($db, 'chat_message')) {
                $placeholders = implode(',', array_fill(0, count($conversationIds), '?'));
                $stmtMsgs = $db->prepare("DELETE FROM chat_message WHERE conversation_id IN ($placeholders)");
                $stmtMsgs->execute($conversationIds);
                $deleted['chat_message'] = $stmtMsgs->rowCount();
            }

            if (!empty($conversationIds)) {
                $placeholders = implode(',', array_fill(0, count($conversationIds), '?'));
                $stmtDelConvs = $db->prepare("DELETE FROM chat_conversation WHERE id IN ($placeholders)");
                $stmtDelConvs->execute($conversationIds);
                $deleted['chat_conversation'] = $stmtDelConvs->rowCount();
            }
        }

        if (table_exists_usuarios($db, 'nu_entrenamientos_actividad_custom')) {
            $stmt = $db->prepare("DELETE FROM nu_entrenamientos_actividad_custom WHERE codigo_usuario = :codigo_usuario");
            $stmt->bindParam(':codigo_usuario', $codigo, PDO::PARAM_INT);
            $stmt->execute();
            $deleted['nu_entrenamientos_actividad_custom'] = $stmt->rowCount();
        }

        if ($codigo_paciente > 0 && table_exists_usuarios($db, 'nu_paciente_medicion')) {
            $stmt = $db->prepare("DELETE FROM nu_paciente_medicion WHERE codigo_paciente = :codigo_paciente");
            $stmt->bindParam(':codigo_paciente', $codigo_paciente, PDO::PARAM_INT);
            $stmt->execute();
            $deleted['nu_paciente_medicion'] = $stmt->rowCount();
        }

        if ($codigo_paciente > 0 && table_exists_usuarios($db, 'nu_entrenamientos')) {
            $stmtEntr = $db->prepare("SELECT codigo FROM nu_entrenamientos WHERE codigo_paciente = :codigo_paciente");
            $stmtEntr->bindParam(':codigo_paciente', $codigo_paciente, PDO::PARAM_INT);
            $stmtEntr->execute();
            $entrenamientos = $stmtEntr->fetchAll(PDO::FETCH_ASSOC);
            $entrenamientoIds = array_map('intval', array_column($entrenamientos, 'codigo'));

            if (!empty($entrenamientoIds)) {
                $placeholders = implode(',', array_fill(0, count($entrenamientoIds), '?'));

                if (table_exists_usuarios($db, 'nu_entrenamientos_ejercicios')) {
                    $stmtEjer = $db->prepare("DELETE FROM nu_entrenamientos_ejercicios WHERE codigo_entrenamiento IN ($placeholders)");
                    $stmtEjer->execute($entrenamientoIds);
                    $deleted['nu_entrenamientos_ejercicios'] = $stmtEjer->rowCount();
                }

                if (table_exists_usuarios($db, 'nu_entrenamientos_imagenes')) {
                    $stmtImg = $db->prepare("DELETE FROM nu_entrenamientos_imagenes WHERE codigo_entrenamiento IN ($placeholders)");
                    $stmtImg->execute($entrenamientoIds);
                    $deleted['nu_entrenamientos_imagenes'] = $stmtImg->rowCount();
                }
            }

            $stmtDelEntr = $db->prepare("DELETE FROM nu_entrenamientos WHERE codigo_paciente = :codigo_paciente");
            $stmtDelEntr->bindParam(':codigo_paciente', $codigo_paciente, PDO::PARAM_INT);
            $stmtDelEntr->execute();
            $deleted['nu_entrenamientos'] = $stmtDelEntr->rowCount();
        }

        if (table_exists_usuarios($db, 'nu_lista_compra')) {
            $stmt = $db->prepare("DELETE FROM nu_lista_compra WHERE codigo_usuario = :codigo_usuario");
            $stmt->bindParam(':codigo_usuario', $codigo, PDO::PARAM_INT);
            $stmt->execute();
            $deleted['nu_lista_compra'] = $stmt->rowCount();
        }

        if (table_exists_usuarios($db, 'nu_receta_usuario')) {
            $stmt = $db->prepare("DELETE FROM nu_receta_usuario WHERE codigo_usuario = :codigo_usuario");
            $stmt->bindParam(':codigo_usuario', $codigo, PDO::PARAM_INT);
            $stmt->execute();
            $deleted['nu_receta_usuario'] = $stmt->rowCount();
        }

        if (table_exists_usuarios($db, 'nu_todo_list')) {
            $stmt = $db->prepare("DELETE FROM nu_todo_list WHERE codigo_usuario = :codigo_usuario");
            $stmt->bindParam(':codigo_usuario', $codigo, PDO::PARAM_INT);
            $stmt->execute();
            $deleted['nu_todo_list'] = $stmt->rowCount();
        }

        if (table_exists_usuarios($db, 'usuario_push_dispositivo')) {
            $stmt = $db->prepare("DELETE FROM usuario_push_dispositivo WHERE usuario_codigo = :codigo_usuario");
            $stmt->bindParam(':codigo_usuario', $codigo, PDO::PARAM_INT);
            $stmt->execute();
            $deleted['usuario_push_dispositivo'] = $stmt->rowCount();
        }

        if (table_exists_usuarios($db, 'usuario')) {
            $stmt = $db->prepare("DELETE FROM usuario WHERE codigo = :codigo");
            $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);
            $stmt->execute();
            $deleted['usuario'] = $stmt->rowCount();
        }

        if (intval($deleted['usuario']) <= 0) {
            throw new Exception('No se eliminó el usuario.');
        }

        $db->commit();

        http_response_code(200);
        echo json_encode(array(
            'message' => 'Usuario eliminado correctamente.',
            'deleted_counts' => $deleted,
        ));
    } catch (Throwable $e) {
        if ($db->inTransaction()) {
            $db->rollBack();
        }
        http_response_code(500);
        echo json_encode(array('message' => 'Error al eliminar el usuario.', 'error' => $e->getMessage()));
    }
}

function delete_usuario_with_details($data = null) {
    if ($data === null) {
        $data = json_decode(file_get_contents("php://input"));
    }

    if (!is_object($data) || empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del usuario."));
        return;
    }

    $codigo = intval($data->codigo);
    execute_usuario_delete_with_details($codigo, false);
}

function delete_self_with_details($data = null) {
    $authUser = $GLOBALS['authenticated_user'] ?? null;
    $codigoAuth = intval($authUser['codigo'] ?? 0);

    if ($codigoAuth <= 0) {
        http_response_code(401);
        echo json_encode(array("message" => "Usuario o contraseña incorrectos."));
        return;
    }

    execute_usuario_soft_delete($codigoAuth);
}

function execute_usuario_soft_delete($codigo) {
    global $db;

    if ($codigo === 1) {
        http_response_code(403);
        echo json_encode(array("message" => "No se puede eliminar al usuario administrador principal."));
        return;
    }

    if (!has_soft_delete_columns_usuarios($db)) {
        http_response_code(409);
        echo json_encode(array(
            'message' => 'La base de datos no está actualizada para eliminación lógica. Faltan las columnas eliminado y/o fecha_eliminacion.',
            'code' => 'MISSING_SOFT_DELETE_COLUMNS',
        ));
        return;
    }

    $notDeletedCondition = build_not_deleted_condition_usuarios($db);
    $columns = get_usuario_columns_map_usuarios($db);

    try {
        $db->beginTransaction();

        $selectOriginal = "SELECT codigo, nick, email FROM usuario WHERE codigo = :codigo AND $notDeletedCondition LIMIT 1 FOR UPDATE";
        $stmtOriginal = $db->prepare($selectOriginal);
        $stmtOriginal->bindParam(':codigo', $codigo, PDO::PARAM_INT);
        $stmtOriginal->execute();
        $originalUser = $stmtOriginal->fetch(PDO::FETCH_ASSOC);
        if (!$originalUser) {
            throw new Exception('No se encontró el usuario o ya estaba eliminado.');
        }

        $renamedNick = build_deleted_nick_usuarios($db, (string)($originalUser['nick'] ?? ''), $codigo);
        $renamedEmail = build_deleted_email_usuarios($db, (string)($originalUser['email'] ?? ''), $codigo);

        $setParts = array(
            "eliminado = 'S'",
            "fecha_eliminacion = NOW()",
            "nick = :nick_eliminado",
        );

        if (isset($columns['email'])) {
            $setParts[] = "email = :email_eliminado";
        }

        if (isset($columns['activo'])) {
            $setParts[] = "activo = 'N'";
        }
        if (isset($columns['accesoweb'])) {
            $setParts[] = "accesoweb = 'N'";
        }
        if (isset($columns['token'])) {
            $setParts[] = "token = NULL";
        }
        if (isset($columns['token_expiracion'])) {
            $setParts[] = "token_expiracion = NULL";
        }
        if (isset($columns['codigo_recuperacion_password'])) {
            $setParts[] = "codigo_recuperacion_password = NULL";
        }
        if (isset($columns['codigo_recuperacion_password_expira'])) {
            $setParts[] = "codigo_recuperacion_password_expira = NULL";
        }
        if (isset($columns['codigo_verificacion_email'])) {
            $setParts[] = "codigo_verificacion_email = NULL";
        }
        if (isset($columns['codigo_verificacion_email_expira'])) {
            $setParts[] = "codigo_verificacion_email_expira = NULL";
        }

        $query = "UPDATE usuario SET " . implode(', ', $setParts) . " WHERE codigo = :codigo AND $notDeletedCondition";
        $stmt = $db->prepare($query);
        $stmt->bindValue(':nick_eliminado', $renamedNick, PDO::PARAM_STR);
        if (isset($columns['email'])) {
            $stmt->bindValue(':email_eliminado', $renamedEmail, PDO::PARAM_STR);
        }
        $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);
        $stmt->execute();

        if ($stmt->rowCount() <= 0) {
            throw new Exception('No se encontró el usuario o ya estaba eliminado.');
        }

        $db->commit();

        http_response_code(200);
        echo json_encode(array(
            'message' => 'Usuario eliminado correctamente.',
            'soft_deleted' => true,
        ));
    } catch (Throwable $e) {
        if ($db->inTransaction()) {
            $db->rollBack();
        }
        http_response_code(500);
        echo json_encode(array('message' => 'Error al eliminar el usuario.', 'error' => $e->getMessage()));
    }
}

function usuario_nick_exists_any_state($db, $nick) {
    $stmt = $db->prepare("SELECT COUNT(*) as count FROM usuario WHERE nick = :nick");
    $stmt->bindParam(':nick', $nick, PDO::PARAM_STR);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    return intval($row['count'] ?? 0) > 0;
}

function usuario_email_exists_any_state($db, $email) {
    if (trim((string)$email) === '') {
        return false;
    }
    $stmt = $db->prepare("SELECT COUNT(*) as count FROM usuario WHERE email = :email");
    $stmt->bindParam(':email', $email, PDO::PARAM_STR);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    return intval($row['count'] ?? 0) > 0;
}

function build_deleted_nick_usuarios($db, $originalNick, $codigo) {
    $baseNick = trim((string)$originalNick);
    if ($baseNick === '') {
        $baseNick = 'usuario_' . intval($codigo);
    }

    $candidate = $baseNick . '[[eliminado]]';
    if (!usuario_nick_exists_any_state($db, $candidate)) {
        return $candidate;
    }

    return $baseNick . '_' . intval($codigo) . '[[eliminado]]';
}

function build_deleted_email_usuarios($db, $originalEmail, $codigo) {
    $baseEmail = trim((string)$originalEmail);
    if ($baseEmail === '') {
        return 'usuario_' . intval($codigo) . '[eliminado]';
    }

    $candidate = $baseEmail . '[eliminado]';
    if (!usuario_email_exists_any_state($db, $candidate)) {
        return $candidate;
    }

    return $baseEmail . '_' . intval($codigo) . '[eliminado]';
}

function delete_usuario() {
    global $db;
    try {
        $data = json_decode(file_get_contents("php://input"));

        if(!is_object($data) || empty($data->codigo)) {
            http_response_code(400);
            echo json_encode(array("message" => "Falta el código del usuario."));
            return;
        }

        $codigo = intval($data->codigo);

        // Opcional: No permitir borrar el usuario 'admin' (código 1, por ejemplo)
        if ($codigo == 1) {
            http_response_code(403);
            echo json_encode(array("message" => "No se puede eliminar al usuario administrador principal."));
            return;
        }

        $query = "DELETE FROM usuario WHERE codigo = :codigo";
        $stmt = $db->prepare($query);
        if (!$stmt) {
            http_response_code(500);
            echo json_encode(array("message" => "Error interno preparando la eliminación del usuario."));
            return;
        }

        $stmt->bindParam(":codigo", $codigo);

        if($stmt->execute()){
            if ($stmt->rowCount() === 0) {
                http_response_code(404);
                echo json_encode(array("message" => "Usuario o contraseña incorrectos."));
                return;
            }

            http_response_code(200);
            echo json_encode(array("message" => "Usuario eliminado."));
        } else {
            $errorInfo = $stmt->errorInfo();
            $sqlState = isset($errorInfo[0]) ? $errorInfo[0] : null;
            $driverCode = isset($errorInfo[1]) ? intval($errorInfo[1]) : 0;

            // 23000/1451 = conflicto por integridad referencial (FK)
            if ($sqlState === '23000' || $driverCode === 1451) {
                http_response_code(409);
                echo json_encode(array(
                    "message" => "No se puede eliminar el usuario porque tiene registros relacionados."
                ));
                return;
            }

            http_response_code(503);
            echo json_encode(array(
                "message" => "No se pudo eliminar el usuario.",
                "errorInfo" => $errorInfo
            ));
        }
    } catch (Throwable $e) {
        error_log('usuarios.php delete_usuario error: ' . $e->getMessage());
        http_response_code(500);
        echo json_encode(array(
            "message" => "Error interno al eliminar usuario."
        ));
    }
}

// Función para verificar dependencias de un usuario antes de eliminarlo
function check_usuario_dependencies($data = null) {
    global $db;
    if ($data === null) {
        $data = json_decode(file_get_contents("php://input"));
    }
    
    if(!is_object($data) || empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del usuario."));
        return;
    }
    
    $codigo = intval($data->codigo);
    
    // No permitir verificar el usuario admin
    if ($codigo == 1) {
        http_response_code(403);
        echo json_encode(array("message" => "No se puede eliminar al usuario administrador principal."));
        return;
    }
    
    $ctx = get_usuario_delete_context($codigo);
    $codigo_paciente = intval($ctx['codigo_paciente'] ?? 0);
    $dependencies = build_usuario_dependencies($codigo, $codigo_paciente);
    
    http_response_code(200);
    echo json_encode(array("dependencies" => $dependencies));
}

// Función para eliminar usuario en cascada (elimina todos los registros relacionados)
function delete_usuario_cascade($data = null) {
    global $db;
    if ($data === null) {
        $data = json_decode(file_get_contents("php://input"));
    }
    
    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del usuario."));
        return;
    }
    
    $codigo = intval($data->codigo);
    
    // No permitir eliminar el usuario admin
    if ($codigo == 1) {
        http_response_code(403);
        echo json_encode(array("message" => "No se puede eliminar al usuario administrador principal."));
        return;
    }
    
    try {
        $db->beginTransaction();
        
        // Obtener IDs de entrenamientos de este usuario para limpiar sus registros
        $query = "SELECT codigo FROM nu_entrenamientos WHERE codigo_paciente = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":codigo", $codigo);
        $stmt->execute();
        $entrenamientos = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $entrenamiento_ids = array_column($entrenamientos, 'codigo');
        
        // Eliminar ejercicios de entrenamientos
        if (!empty($entrenamiento_ids)) {
            $placeholders = implode(',', array_fill(0, count($entrenamiento_ids), '?'));
            $query = "DELETE FROM nu_entrenamientos_ejercicios WHERE codigo_entrenamiento IN ($placeholders)";
            $stmt = $db->prepare($query);
            $stmt->execute($entrenamiento_ids);
            
            // Eliminar imágenes de entrenamientos
            $query = "DELETE FROM nu_entrenamientos_imagenes WHERE codigo_entrenamiento IN ($placeholders)";
            $stmt = $db->prepare($query);
            $stmt->execute($entrenamiento_ids);
        }
        
        // Eliminar entrenamientos
        $query = "DELETE FROM nu_entrenamientos WHERE codigo_paciente = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":codigo", $codigo);
        $stmt->execute();
        
        // Eliminar actividades custom del usuario
        $query = "DELETE FROM nu_entrenamientos_actividad_custom WHERE codigo_usuario = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":codigo", $codigo);
        $stmt->execute();
        
        // Eliminar consejos del usuario
        $query = "DELETE FROM nu_consejo_usuario WHERE codigo_usuario = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":codigo", $codigo);
        $stmt->execute();
        
        // Eliminar recetas del usuario
        $query = "DELETE FROM nu_receta_usuario WHERE codigo_usuario = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":codigo", $codigo);
        $stmt->execute();
        
        // Finalmente eliminar el usuario
        $query = "DELETE FROM usuario WHERE codigo = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":codigo", $codigo);
        $stmt->execute();
        
        $db->commit();
        
        http_response_code(200);
        echo json_encode(array("message" => "Usuario y todos sus registros eliminados correctamente."));
    } catch (Exception $e) {
        $db->rollBack();
        http_response_code(503);
        echo json_encode(array(
            "message" => "Error al eliminar el usuario.",
            "error" => $e->getMessage()
        ));
    }
}

// Función para mover todos los registros de un usuario a otro
function move_usuario_data($data = null) {
    global $db;
    if ($data === null) {
        $data = json_decode(file_get_contents("php://input"));
    }
    
    if(empty($data->codigo_usuario) || empty($data->codigo_usuario_destino)) {
        http_response_code(400);
        echo json_encode(array("message" => "Faltan parámetros: codigo_usuario y codigo_usuario_destino."));
        return;
    }
    
    $codigo_origen = intval($data->codigo_usuario);
    $codigo_destino = intval($data->codigo_usuario_destino);
    
    // No permitir mover datos del usuario admin
    if ($codigo_origen == 1) {
        http_response_code(403);
        echo json_encode(array("message" => "No se puede eliminar al usuario administrador principal."));
        return;
    }
    
    // No permitir mover a uno mismo
    if ($codigo_origen == $codigo_destino) {
        http_response_code(400);
        echo json_encode(array("message" => "No se pueden mover los datos al mismo usuario."));
        return;
    }
    
    try {
        $db->beginTransaction();
        
        // Mover registros en nu_consejo_usuario
        $query = "UPDATE nu_consejo_usuario SET codigo_usuario = :destino WHERE codigo_usuario = :origen";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":origen", $codigo_origen);
        $stmt->bindParam(":destino", $codigo_destino);
        $stmt->execute();
        
        // Mover registros en nu_receta_usuario
        $query = "UPDATE nu_receta_usuario SET codigo_usuario = :destino WHERE codigo_usuario = :origen";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":origen", $codigo_origen);
        $stmt->bindParam(":destino", $codigo_destino);
        $stmt->execute();
        
        // Mover registros en nu_entrenamientos_actividad_custom
        $query = "UPDATE nu_entrenamientos_actividad_custom SET codigo_usuario = :destino WHERE codigo_usuario = :origen";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":origen", $codigo_origen);
        $stmt->bindParam(":destino", $codigo_destino);
        $stmt->execute();
        
        // Mover registros en nu_entrenamientos (como código_paciente)
        $query = "UPDATE nu_entrenamientos SET codigo_paciente = :destino WHERE codigo_paciente = :origen";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":origen", $codigo_origen);
        $stmt->bindParam(":destino", $codigo_destino);
        $stmt->execute();
        
        // Eliminar el usuario de origen
        $query = "DELETE FROM usuario WHERE codigo = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":codigo", $codigo_origen);
        $stmt->execute();
        
        $db->commit();
        
        http_response_code(200);
        echo json_encode(array("message" => "Datos movidos correctamente y usuario eliminado."));
    } catch (Exception $e) {
        $db->rollBack();
        http_response_code(503);
        echo json_encode(array(
            "message" => "Error al mover los datos.",
            "error" => $e->getMessage()
        ));
    }
}
?>