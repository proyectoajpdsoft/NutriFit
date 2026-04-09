<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/auto_validator.php';
include_once '../auth/permissions.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

if (!$db) {
    http_response_code(500);
    echo json_encode(array('message' => 'No se pudo conectar con la base de datos.'));
    exit();
}

$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$validator = new AutoValidator($db);
$user = $validator->validate();

$request_method = $_SERVER['REQUEST_METHOD'];

function require_aditivos_permission() {
    global $user;
    PermissionManager::checkPermission($user, 'suplementos');
}

function require_manager() {
    if (!is_manager_user()) {
        http_response_code(403);
        ob_clean();
        echo json_encode(array('message' => 'No tienes permisos para realizar esta operaciÃ³n.'));
        exit();
    }
}

function is_manager_user() {
    global $user;

    if (($user['administrador'] ?? 'N') === 'S') {
        return true;
    }

    $raw_types = array(
        strtolower(trim((string)($user['tipo'] ?? ''))),
        strtolower(trim((string)($user['tipo_usuario'] ?? ''))),
        strtolower(trim((string)($user['role'] ?? ''))),
        strtolower(trim((string)($user['rol'] ?? ''))),
    );

    foreach ($raw_types as $tipo) {
        if (in_array($tipo, array('nutricionista', 'nutritionist', 'administrador', 'admin'), true)) {
            return true;
        }
    }

    $user_type = PermissionManager::getUserType($user);
    return $user_type === PermissionManager::TYPE_NUTRITIONIST ||
        $user_type === PermissionManager::TYPE_ADMIN;
}

function current_user_code_nullable() {
    global $user;

    $candidates = array(
        $user['codigo'] ?? null,
        $user['codusuario'] ?? null,
        $user['id'] ?? null,
    );

    foreach ($candidates as $raw) {
        $value = intval($raw ?? 0);
        if ($value > 0) {
            return $value;
        }
    }

    return null;
}

function parse_peligrosidad_nullable($raw, &$isValid = true) {
    if ($raw === null) {
        $isValid = true;
        return null;
    }

    $value = trim((string)$raw);
    if ($value === '') {
        $isValid = true;
        return null;
    }

    if (!preg_match('/^-?\d+$/', $value)) {
        $isValid = false;
        return null;
    }

    $intValue = intval($value);
    if ($intValue < 1 || $intValue > 5) {
        $isValid = false;
        return null;
    }

    $isValid = true;
    return $intValue;
}

try {
    switch ($request_method) {
        case 'GET':
            if (!empty($_GET['total_aditivos'])) {
                require_aditivos_permission();
                require_manager();
                get_total_aditivos();
            } elseif (!empty($_GET['codigo'])) {
                get_aditivo(intval($_GET['codigo']));
            } elseif (isset($_GET['activos'])) {
                get_aditivos_activos();
            } else {
                require_aditivos_permission();
                get_aditivos();
            }
            break;

        case 'POST':
            require_aditivos_permission();
            require_manager();
            create_aditivo();
            break;

        case 'PUT':
            require_aditivos_permission();
            require_manager();
            update_aditivo();
            break;

        case 'DELETE':
            require_aditivos_permission();
            require_manager();
            if (!empty($_GET['codigo'])) {
                delete_aditivo(intval($_GET['codigo']));
            } else {
                http_response_code(400);
                ob_clean();
                echo json_encode(array('message' => 'Falta el código del aditivo.'));
            }
            break;

        default:
            http_response_code(405);
            ob_clean();
            echo json_encode(array('message' => 'Método no permitido.'));
            break;
    }
} catch (Exception $e) {
    http_response_code(500);
    ob_clean();
    echo json_encode(array('message' => 'Error interno del servidor: ' . $e->getMessage()));
}

// â”€â”€â”€ GET TOTAL (para dashboard nutricionista) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function get_total_aditivos() {
    global $db;
    $stmt = $db->prepare("SELECT COUNT(*) AS total FROM nu_aditivos");
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode(['total' => intval($row['total'])]);
}

// â”€â”€â”€ GET ALL (nutricionista: todos; premium: solo activos) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function get_aditivos() {
    global $db;
    $soloActivos = !is_manager_user();

    $where = $soloActivos ? "WHERE s.activo = 'S'" : '';
    $query = "SELECT s.codigo, s.titulo, s.descripcion, s.tipo, s.activo,
                s.peligrosidad, s.fechaa, s.codusuarioa, s.fecham, s.codusuariom
              FROM nu_aditivos s
              $where
              ORDER BY s.fechaa DESC";

    $stmt = $db->prepare($query);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    ob_clean();
    echo json_encode($rows);
}

// â”€â”€â”€ GET ACTIVE ONLY (para paciente premium) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function get_aditivos_activos() {
    global $db;
    $query = "SELECT s.codigo, s.titulo, s.descripcion, s.tipo, s.activo,
                s.peligrosidad, s.fechaa, s.codusuarioa, s.fecham, s.codusuariom
              FROM nu_aditivos s
              WHERE s.activo = 'S'
              ORDER BY s.fechaa DESC";

    $stmt = $db->prepare($query);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    ob_clean();
    echo json_encode($rows);
}

// â”€â”€â”€ GET ONE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function get_aditivo($codigo) {
    global $db;
    $soloActivos = !is_manager_user();

    $query = "SELECT codigo, titulo, descripcion, tipo, activo,
                peligrosidad, fechaa, codusuarioa, fecham, codusuariom
              FROM nu_aditivos
              WHERE codigo = :codigo" . ($soloActivos ? " AND activo = 'S'" : '');

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        http_response_code(404);
        ob_clean();
        echo json_encode(array('message' => 'Aditivo no encontrado.'));
        return;
    }

    ob_clean();
    echo json_encode($row);
}

// â”€â”€â”€ CREATE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function create_aditivo() {
    global $db;

    $data = json_decode(file_get_contents('php://input'));

    if (!$data || !is_object($data)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array('message' => 'Payload JSON inválido.'));
        return;
    }

    if (empty($data->titulo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array('message' => 'El título es obligatorio.'));
        return;
    }

    if (empty($data->tipo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array('message' => 'El tipo es obligatorio.'));
        return;
    }

    $titulo      = substr(trim($data->titulo), 0, 200);
    $descripcion = isset($data->descripcion) ? trim($data->descripcion) : '';
    $tipo        = substr(trim($data->tipo), 0, 150);
    $activo      = (!empty($data->activo) && $data->activo === 'N') ? 'N' : 'S';
    $isPeligrosidadValid = true;
    $peligrosidad = parse_peligrosidad_nullable($data->peligrosidad ?? null, $isPeligrosidadValid);
    if (!$isPeligrosidadValid) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array('message' => 'El campo peligrosidad debe ser un número entre 1 y 5.'));
        return;
    }
    $codusuarioa = current_user_code_nullable();

    $stmt = $db->prepare(
        "INSERT INTO nu_aditivos (titulo, descripcion, tipo, activo, peligrosidad, fechaa, codusuarioa)
         VALUES (:titulo, :descripcion, :tipo, :activo, :peligrosidad, NOW(), :codusuarioa)"
    );
    $stmt->bindParam(':titulo',      $titulo);
    $stmt->bindParam(':descripcion', $descripcion);
    $stmt->bindParam(':tipo',        $tipo);
    $stmt->bindParam(':activo',      $activo);
    if ($peligrosidad === null) {
        $stmt->bindValue(':peligrosidad', null, PDO::PARAM_NULL);
    } else {
        $stmt->bindValue(':peligrosidad', $peligrosidad, PDO::PARAM_INT);
    }
    if ($codusuarioa === null) {
        $stmt->bindValue(':codusuarioa', null, PDO::PARAM_NULL);
    } else {
        $stmt->bindValue(':codusuarioa', $codusuarioa, PDO::PARAM_INT);
    }

    if ($stmt->execute()) {
        $codigo = (int)$db->lastInsertId();
        http_response_code(201);
        ob_clean();
        echo json_encode(array('message' => 'Aditivo creado.', 'codigo' => $codigo));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array('message' => 'No se pudo crear el aditivo.'));
    }
}

// â”€â”€â”€ UPDATE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function update_aditivo() {
    global $db;

    $data = json_decode(file_get_contents('php://input'));

    if (!$data || !is_object($data)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array('message' => 'Payload JSON inválido.'));
        return;
    }

    if (empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array('message' => 'Falta el código del aditivo.'));
        return;
    }
    if (empty($data->titulo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array('message' => 'El título es obligatorio.'));
        return;
    }
    if (empty($data->tipo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array('message' => 'El tipo es obligatorio.'));
        return;
    }

    $codigo      = intval($data->codigo);
    $titulo      = substr(trim($data->titulo), 0, 200);
    $descripcion = isset($data->descripcion) ? trim($data->descripcion) : '';
    $tipo        = substr(trim($data->tipo), 0, 150);
    $activo      = (!empty($data->activo) && $data->activo === 'N') ? 'N' : 'S';
    $isPeligrosidadValid = true;
    $peligrosidad = parse_peligrosidad_nullable($data->peligrosidad ?? null, $isPeligrosidadValid);
    if (!$isPeligrosidadValid) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array('message' => 'El campo peligrosidad debe ser un número entre 1 y 5.'));
        return;
    }
    $codusuariom = current_user_code_nullable();

    $stmt = $db->prepare(
        "UPDATE nu_aditivos
         SET titulo = :titulo, descripcion = :descripcion, tipo = :tipo, activo = :activo,
             peligrosidad = :peligrosidad,
             fecham = NOW(), codusuariom = :codusuariom
         WHERE codigo = :codigo"
    );
    $stmt->bindParam(':titulo',      $titulo);
    $stmt->bindParam(':descripcion', $descripcion);
    $stmt->bindParam(':tipo',        $tipo);
    $stmt->bindParam(':activo',      $activo);
    if ($peligrosidad === null) {
        $stmt->bindValue(':peligrosidad', null, PDO::PARAM_NULL);
    } else {
        $stmt->bindValue(':peligrosidad', $peligrosidad, PDO::PARAM_INT);
    }
    if ($codusuariom === null) {
        $stmt->bindValue(':codusuariom', null, PDO::PARAM_NULL);
    } else {
        $stmt->bindValue(':codusuariom', $codusuariom, PDO::PARAM_INT);
    }
    $stmt->bindParam(':codigo',      $codigo, PDO::PARAM_INT);

    if ($stmt->execute()) {
        ob_clean();
        echo json_encode(array('message' => 'Aditivo actualizado.'));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array('message' => 'No se pudo actualizar el aditivo.'));
    }
}

// â”€â”€â”€ DELETE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function delete_aditivo($codigo) {
    global $db;

    $stmt = $db->prepare('DELETE FROM nu_aditivos WHERE codigo = :codigo');
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);

    if ($stmt->execute()) {
        ob_clean();
        echo json_encode(array('message' => 'Aditivo eliminado.'));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array('message' => 'No se pudo eliminar el Aditivo.'));
    }
}

