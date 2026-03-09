<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/permissions.php';
include_once '../auth/totp.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

$validator = new TokenValidator($db);
$user = $validator->validateToken();

$codigoUsuario = (int) ($user['codigo'] ?? 0);
if ($codigoUsuario <= 0) {
    http_response_code(401);
    echo json_encode(array('message' => 'Usuario no autenticado.'));
    exit();
}

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? 'status';

if ($method === 'GET') {
    two_factor_status($db, $codigoUsuario);
    exit();
}

$data = json_decode(file_get_contents('php://input'));
if (!is_object($data)) {
    $data = (object) [];
}

switch ($action) {
    case 'setup':
        two_factor_setup($db, $codigoUsuario, $user);
        break;
    case 'enable':
        two_factor_enable($db, $codigoUsuario, $user, $data);
        break;
    case 'disable':
        two_factor_disable($db, $codigoUsuario, $data);
        break;
    case 'admin_disable':
        two_factor_admin_disable($db, $user, $data);
        break;
    default:
        http_response_code(400);
        echo json_encode(array('message' => 'Acción no válida.'));
        break;
}

function two_factor_status($db, $codigoUsuario) {
    $query = "SELECT two_factor_enabled FROM usuario WHERE codigo = :codigo LIMIT 1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigoUsuario, PDO::PARAM_INT);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        http_response_code(404);
        echo json_encode(array('message' => 'Usuario o contraseña incorrectos.'));
        return;
    }

    echo json_encode(array(
        'enabled' => strtoupper((string) ($row['two_factor_enabled'] ?? 'N')) === 'S'
    ));
}

function two_factor_setup($db, $codigoUsuario, $user) {
    $secret = totp_generate_secret(20);
    $issuer = 'NutriFit';
    $accountName = $user['nick'] ?? ('user_' . $codigoUsuario);
    $otpauthUrl = totp_build_otpauth_url($issuer, $accountName, $secret);

    echo json_encode(array(
        'secret' => $secret,
        'manual_key' => trim(chunk_split($secret, 4, ' ')),
        'issuer' => $issuer,
        'account_name' => $accountName,
        'otpauth_url' => $otpauthUrl,
        'digits' => 6,
        'period' => 30,
    ));
}

function two_factor_enable($db, $codigoUsuario, $user, $data) {
    $secret = strtoupper(trim((string) ($data->secret ?? '')));
    $code = trim((string) ($data->codigo_2fa ?? ''));

    if ($secret === '' || $code === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Secret y código son obligatorios.'));
        return;
    }

    $matchedCounter = null;
    if (!totp_verify_code($secret, $code, 1, $matchedCounter)) {
        http_response_code(401);
        echo json_encode(array(
            'message' => 'Código 2FA inválido.',
            'code' => 'INVALID_2FA_CODE'
        ));
        return;
    }

    $counterValue = $matchedCounter !== null ? (int) $matchedCounter : null;
    $query = "UPDATE usuario
              SET two_factor_enabled = 'S',
                  two_factor_secret = :secret,
                  two_factor_last_counter = :counter
              WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':secret', $secret, PDO::PARAM_STR);
    if ($counterValue === null) {
        $stmt->bindValue(':counter', null, PDO::PARAM_NULL);
    } else {
        $stmt->bindValue(':counter', (int) $counterValue, PDO::PARAM_INT);
    }
    $stmt->bindParam(':codigo', $codigoUsuario, PDO::PARAM_INT);

    if ($stmt->execute()) {
        echo json_encode(array('message' => '2FA activado correctamente.', 'enabled' => true));
    } else {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo activar 2FA.'));
    }
}

function two_factor_disable($db, $codigoUsuario, $data) {
    $queryUser = "SELECT two_factor_enabled, two_factor_secret FROM usuario WHERE codigo = :codigo LIMIT 1";
    $stmtUser = $db->prepare($queryUser);
    $stmtUser->bindParam(':codigo', $codigoUsuario, PDO::PARAM_INT);
    $stmtUser->execute();
    $row = $stmtUser->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        http_response_code(404);
        echo json_encode(array('message' => 'Usuario o contraseña incorrectos.'));
        return;
    }

    $isEnabled = strtoupper((string) ($row['two_factor_enabled'] ?? 'N')) === 'S';
    if ($isEnabled) {
        $code = trim((string) ($data->codigo_2fa ?? ''));
        if ($code === '') {
            http_response_code(400);
            echo json_encode(array('message' => 'Debe indicar el código 2FA para desactivar.'));
            return;
        }

        $matchedCounter = null;
        if (!totp_verify_code((string) ($row['two_factor_secret'] ?? ''), $code, 1, $matchedCounter)) {
            http_response_code(401);
            echo json_encode(array(
                'message' => 'Código 2FA inválido.',
                'code' => 'INVALID_2FA_CODE'
            ));
            return;
        }
    }

    $query = "UPDATE usuario
              SET two_factor_enabled = 'N',
                  two_factor_secret = NULL,
                  two_factor_last_counter = NULL
              WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigoUsuario, PDO::PARAM_INT);

    if ($stmt->execute()) {
        echo json_encode(array('message' => '2FA desactivado correctamente.', 'enabled' => false));
    } else {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo desactivar 2FA.'));
    }
}

function two_factor_admin_disable($db, $authUser, $data) {
    try {
        PermissionManager::checkPermission($authUser, 'usuarios');
    } catch (Exception $e) {
        http_response_code(403);
        echo json_encode(array(
            'message' => 'No tienes permisos para desactivar 2FA de otros usuarios.',
            'code' => 'PERMISSION_DENIED'
        ));
        return;
    }

    $targetCodigo = isset($data->codigo_usuario) ? (int)$data->codigo_usuario : 0;
    if ($targetCodigo <= 0) {
        http_response_code(400);
        echo json_encode(array('message' => 'codigo_usuario es obligatorio.'));
        return;
    }

    $queryUser = "SELECT codigo, nick, two_factor_enabled FROM usuario WHERE codigo = :codigo LIMIT 1";
    $stmtUser = $db->prepare($queryUser);
    $stmtUser->bindParam(':codigo', $targetCodigo, PDO::PARAM_INT);
    $stmtUser->execute();
    $row = $stmtUser->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        http_response_code(404);
        echo json_encode(array('message' => 'Usuario objetivo no encontrado.'));
        return;
    }

    $query = "UPDATE usuario
              SET two_factor_enabled = 'N',
                  two_factor_secret = NULL,
                  two_factor_last_counter = NULL
              WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $targetCodigo, PDO::PARAM_INT);

    if ($stmt->execute()) {
        echo json_encode(array(
            'message' => '2FA desactivado por administrador.',
            'enabled' => false,
            'codigo_usuario' => $targetCodigo,
            'nick' => $row['nick'] ?? null
        ));
    } else {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo desactivar 2FA del usuario.'));
    }
}
