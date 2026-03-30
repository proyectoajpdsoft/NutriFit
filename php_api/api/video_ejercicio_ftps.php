<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

include_once '../config/database.php';
include_once '../auth/auto_validator.php';
include_once '../auth/permissions.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(array('message' => 'Método no permitido.'));
    exit();
}

$database = new Database();
$db = $database->getConnection();

$validator = new AutoValidator($db);
$user = $validator->validate();
PermissionManager::checkPermission($user, 'videos_ejercicios');

if (!is_manager_user_ftps($user)) {
    http_response_code(403);
    echo json_encode(array('message' => 'Solo nutricionistas/administradores pueden usar FTPS de vídeos.'));
    exit();
}

$data = json_decode(file_get_contents('php://input'));
$action = trim((string)($data->action ?? ''));

if ($action !== 'get_config') {
    http_response_code(400);
    echo json_encode(array('message' => 'Acción no válida.'));
    exit();
}

$enabled = get_parametro_valor_ftps($db, 'videos_ftps_enabled');
$host = get_parametro_valor_ftps($db, 'videos_ftps_host');
$port = get_parametro_valor_ftps($db, 'videos_ftps_port');
$security = get_parametro_valor_ftps($db, 'videos_ftps_security');
$remoteRoot = get_parametro_valor_ftps($db, 'videos_ftps_remote_root');
$userEnc = get_parametro_valor_ftps($db, 'videos_ftps_user_enc');
$passEnc = get_parametro_valor_ftps($db, 'videos_ftps_pass_enc');
$cipher = get_parametro_valor_ftps($db, 'videos_ftps_cipher_version');

http_response_code(200);
echo json_encode(array(
    'enabled' => normalize_truthy_ftps($enabled) ? 'S' : 'N',
    'host' => $host,
    'port' => $port !== '' ? intval($port) : 21,
    'security' => $security !== '' ? strtolower($security) : 'ftpes',
    'remote_root' => $remoteRoot,
    'user_enc' => $userEnc,
    'pass_enc' => $passEnc,
    'cipher_version' => $cipher !== '' ? $cipher : 'ENCFTPS1',
));

function is_manager_user_ftps($user) {
    $tipo = strtolower(trim((string)PermissionManager::getUserType($user)));
    return $tipo === PermissionManager::TYPE_NUTRITIONIST ||
           $tipo === PermissionManager::TYPE_ADMIN ||
           $tipo === 'administrador' ||
           $tipo === 'nutricionista' ||
           $tipo === 'admin';
}

function get_parametro_valor_ftps($db, $nombre) {
    $stmt = $db->prepare('SELECT valor FROM parametro WHERE nombre = :nombre LIMIT 1');
    $stmt->bindParam(':nombre', $nombre, PDO::PARAM_STR);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        return '';
    }
    return trim((string)($row['valor'] ?? ''));
}

function normalize_truthy_ftps($value) {
    $normalized = strtolower(trim((string)$value));
    return $normalized === 's' ||
           $normalized === '1' ||
           $normalized === 'si' ||
           $normalized === 'sí' ||
           $normalized === 'true' ||
           $normalized === 'yes' ||
           $normalized === 'y';
}
