<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once '../config/database.php';
require_once '../auth/token_validator.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

$validator = new TokenValidator($db);
$user = $validator->validateToken();

$action = $_GET['action'] ?? null;

ensure_push_table($db);

if ($method === 'GET' && $action === 'get_preferences') {
    get_preferences($db, $user);
    exit();
}

if ($method === 'POST' && $action === 'update_preferences') {
    update_preferences($db, $user);
    exit();
}

if ($method === 'POST' && $action === 'register_device') {
    register_device($db, $user);
    exit();
}

if ($method === 'POST' && $action === 'unregister_device') {
    unregister_device($db, $user);
    exit();
}

http_response_code(400);
echo json_encode(["message" => "Acción no reconocida."]);

function ensure_push_table($db) {
    $db->exec(
        "CREATE TABLE IF NOT EXISTS usuario_push_dispositivo (
            id INT AUTO_INCREMENT PRIMARY KEY,
            usuario_codigo INT NOT NULL,
            token VARCHAR(255) NOT NULL,
            plataforma VARCHAR(20) NOT NULL,
            device_id VARCHAR(128) NULL,
            chat_unread_enabled TINYINT(1) NOT NULL DEFAULT 1,
            activo TINYINT(1) NOT NULL DEFAULT 1,
            creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            ultimo_seen DATETIME NULL,
            UNIQUE KEY uk_push_token (token),
            INDEX idx_usuario_activo (usuario_codigo, activo),
            INDEX idx_usuario_plataforma (usuario_codigo, plataforma)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    );
}

function can_manage_own_push($user) {
    return isset($user['codigo']) && intval($user['codigo']) > 0;
}

function to_bool_int($value, $default = 1) {
    if ($value === null) {
        return $default;
    }

    $normalized = strtolower(trim((string)$value));
    if ($normalized === '1' || $normalized === 'true' || $normalized === 's' || $normalized === 'si' || $normalized === 'sí') {
        return 1;
    }
    if ($normalized === '0' || $normalized === 'false' || $normalized === 'n' || $normalized === 'no') {
        return 0;
    }

    return $default;
}

function get_preferences($db, $user) {
    if (!can_manage_own_push($user)) {
        http_response_code(403);
        echo json_encode(["message" => "No autorizado."]);
        return;
    }

    $usuario_codigo = intval($user['codigo']);

    $stmt = $db->prepare(
        "SELECT chat_unread_enabled
         FROM usuario_push_dispositivo
         WHERE usuario_codigo = :usuario_codigo
           AND activo = 1
         ORDER BY actualizado_en DESC
         LIMIT 1"
    );
    $stmt->bindParam(':usuario_codigo', $usuario_codigo);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    $enabled = isset($row['chat_unread_enabled']) ? intval($row['chat_unread_enabled']) : 1;

    http_response_code(200);
    echo json_encode([
        "chat_unread_enabled" => $enabled,
    ]);
}

function update_preferences($db, $user) {
    if (!can_manage_own_push($user)) {
        http_response_code(403);
        echo json_encode(["message" => "No autorizado."]);
        return;
    }

    $data = json_decode(file_get_contents("php://input"), true);
    $chat_enabled = to_bool_int($data['chat_unread_enabled'] ?? null, 1);
    $usuario_codigo = intval($user['codigo']);

    $update = $db->prepare(
        "UPDATE usuario_push_dispositivo
         SET chat_unread_enabled = :chat_enabled,
             actualizado_en = NOW()
         WHERE usuario_codigo = :usuario_codigo"
    );
    $update->bindParam(':chat_enabled', $chat_enabled, PDO::PARAM_INT);
    $update->bindParam(':usuario_codigo', $usuario_codigo, PDO::PARAM_INT);
    $update->execute();

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "chat_unread_enabled" => $chat_enabled,
    ]);
}

function register_device($db, $user) {
    if (!can_manage_own_push($user)) {
        http_response_code(403);
        echo json_encode(["message" => "No autorizado."]);
        return;
    }

    $data = json_decode(file_get_contents("php://input"), true);
    $token = trim((string)($data['token'] ?? ''));
    $platform = trim((string)($data['platform'] ?? 'android'));
    $device_id = trim((string)($data['device_id'] ?? ''));
    $chat_enabled = to_bool_int($data['chat_unread_enabled'] ?? null, 1);

    if ($token === '') {
        http_response_code(400);
        echo json_encode(["message" => "Token requerido."]);
        return;
    }

    $usuario_codigo = intval($user['codigo']);

    $stmt = $db->prepare(
        "INSERT INTO usuario_push_dispositivo
            (usuario_codigo, token, plataforma, device_id, chat_unread_enabled, activo, creado_en, actualizado_en, ultimo_seen)
         VALUES
            (:usuario_codigo, :token, :plataforma, :device_id, :chat_enabled, 1, NOW(), NOW(), NOW())
         ON DUPLICATE KEY UPDATE
            usuario_codigo = VALUES(usuario_codigo),
            plataforma = VALUES(plataforma),
            device_id = VALUES(device_id),
            chat_unread_enabled = VALUES(chat_unread_enabled),
            activo = 1,
            actualizado_en = NOW(),
            ultimo_seen = NOW()"
    );

    $device_id_param = $device_id !== '' ? $device_id : null;

    $stmt->bindParam(':usuario_codigo', $usuario_codigo, PDO::PARAM_INT);
    $stmt->bindParam(':token', $token);
    $stmt->bindParam(':plataforma', $platform);
    $stmt->bindParam(':device_id', $device_id_param);
    $stmt->bindParam(':chat_enabled', $chat_enabled, PDO::PARAM_INT);

    if ($stmt->execute()) {
        http_response_code(201);
        echo json_encode(["success" => true]);
        return;
    }

    http_response_code(500);
    echo json_encode(["message" => "No se pudo registrar el dispositivo."]);
}

function unregister_device($db, $user) {
    if (!can_manage_own_push($user)) {
        http_response_code(403);
        echo json_encode(["message" => "No autorizado."]);
        return;
    }

    $data = json_decode(file_get_contents("php://input"), true);
    $token = trim((string)($data['token'] ?? ''));

    if ($token === '') {
        http_response_code(400);
        echo json_encode(["message" => "Token requerido."]);
        return;
    }

    $usuario_codigo = intval($user['codigo']);

    $stmt = $db->prepare(
        "UPDATE usuario_push_dispositivo
         SET activo = 0,
             actualizado_en = NOW()
         WHERE usuario_codigo = :usuario_codigo
           AND token = :token"
    );
    $stmt->bindParam(':usuario_codigo', $usuario_codigo, PDO::PARAM_INT);
    $stmt->bindParam(':token', $token);

    if ($stmt->execute()) {
        http_response_code(200);
        echo json_encode(["success" => true]);
        return;
    }

    http_response_code(500);
    echo json_encode(["message" => "No se pudo desactivar el dispositivo."]);
}
