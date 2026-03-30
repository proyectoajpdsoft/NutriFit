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
PermissionManager::checkPermission($user, 'suplementos');

$request_method = $_SERVER['REQUEST_METHOD'];

function require_manager() {
    if (!is_manager_user()) {
        http_response_code(403);
        ob_clean();
        echo json_encode(array('message' => 'No tienes permisos para realizar esta operación.'));
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

try {
    switch ($request_method) {
        case 'GET':
            if (!empty($_GET['total_suplementos'])) {
                require_manager();
                get_total_suplementos();
            } elseif (!empty($_GET['codigo'])) {
                get_suplemento(intval($_GET['codigo']));
            } elseif (isset($_GET['activos'])) {
                get_suplementos_activos();
            } else {
                get_suplementos();
            }
            break;

        case 'POST':
            require_manager();
            create_suplemento();
            break;

        case 'PUT':
            require_manager();
            update_suplemento();
            break;

        case 'DELETE':
            require_manager();
            if (!empty($_GET['codigo'])) {
                delete_suplemento(intval($_GET['codigo']));
            } else {
                http_response_code(400);
                ob_clean();
                echo json_encode(array('message' => 'Falta el código del suplemento.'));
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

// ─── GET TOTAL (para dashboard nutricionista) ───────────────────────────────

function get_total_suplementos() {
    global $db;
    $stmt = $db->prepare("SELECT COUNT(*) AS total FROM nu_suplementos");
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode(['total' => intval($row['total'])]);
}

// ─── GET ALL (nutricionista: todos; premium: solo activos) ────────────────────

function get_suplementos() {
    global $db;
    $soloActivos = !is_manager_user();

    $where = $soloActivos ? "WHERE s.activo = 'S'" : '';
    $query = "SELECT s.codigo, s.titulo, s.descripcion, s.activo,
                     s.fechaa, s.codusuarioa, s.fecham, s.codusuariom
              FROM nu_suplementos s
              $where
              ORDER BY s.fechaa DESC";

    $stmt = $db->prepare($query);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    ob_clean();
    echo json_encode($rows);
}

// ─── GET ACTIVE ONLY (para paciente premium) ─────────────────────────────────

function get_suplementos_activos() {
    global $db;
    $query = "SELECT s.codigo, s.titulo, s.descripcion, s.activo,
                     s.fechaa, s.codusuarioa, s.fecham, s.codusuariom
              FROM nu_suplementos s
              WHERE s.activo = 'S'
              ORDER BY s.fechaa DESC";

    $stmt = $db->prepare($query);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    ob_clean();
    echo json_encode($rows);
}

// ─── GET ONE ─────────────────────────────────────────────────────────────────

function get_suplemento($codigo) {
    global $db;
    $soloActivos = !is_manager_user();

    $query = "SELECT codigo, titulo, descripcion, activo,
                     fechaa, codusuarioa, fecham, codusuariom
              FROM nu_suplementos
              WHERE codigo = :codigo" . ($soloActivos ? " AND activo = 'S'" : '');

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        http_response_code(404);
        ob_clean();
        echo json_encode(array('message' => 'Suplemento no encontrado.'));
        return;
    }

    ob_clean();
    echo json_encode($row);
}

// ─── CREATE ───────────────────────────────────────────────────────────────────

function create_suplemento() {
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

    $titulo      = substr(trim($data->titulo), 0, 200);
    $descripcion = isset($data->descripcion) ? trim($data->descripcion) : '';
    $activo      = (!empty($data->activo) && $data->activo === 'N') ? 'N' : 'S';
    $codusuarioa = current_user_code_nullable();

    $stmt = $db->prepare(
        "INSERT INTO nu_suplementos (titulo, descripcion, activo, fechaa, codusuarioa)
         VALUES (:titulo, :descripcion, :activo, NOW(), :codusuarioa)"
    );
    $stmt->bindParam(':titulo',      $titulo);
    $stmt->bindParam(':descripcion', $descripcion);
    $stmt->bindParam(':activo',      $activo);
    if ($codusuarioa === null) {
        $stmt->bindValue(':codusuarioa', null, PDO::PARAM_NULL);
    } else {
        $stmt->bindValue(':codusuarioa', $codusuarioa, PDO::PARAM_INT);
    }

    if ($stmt->execute()) {
        $codigo = (int)$db->lastInsertId();
        http_response_code(201);
        ob_clean();
        echo json_encode(array('message' => 'Suplemento creado.', 'codigo' => $codigo));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array('message' => 'No se pudo crear el suplemento.'));
    }
}

// ─── UPDATE ───────────────────────────────────────────────────────────────────

function update_suplemento() {
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
        echo json_encode(array('message' => 'Falta el código del suplemento.'));
        return;
    }
    if (empty($data->titulo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array('message' => 'El título es obligatorio.'));
        return;
    }

    $codigo      = intval($data->codigo);
    $titulo      = substr(trim($data->titulo), 0, 200);
    $descripcion = isset($data->descripcion) ? trim($data->descripcion) : '';
    $activo      = (!empty($data->activo) && $data->activo === 'N') ? 'N' : 'S';
    $codusuariom = current_user_code_nullable();

    $stmt = $db->prepare(
        "UPDATE nu_suplementos
         SET titulo = :titulo, descripcion = :descripcion, activo = :activo,
             fecham = NOW(), codusuariom = :codusuariom
         WHERE codigo = :codigo"
    );
    $stmt->bindParam(':titulo',      $titulo);
    $stmt->bindParam(':descripcion', $descripcion);
    $stmt->bindParam(':activo',      $activo);
    if ($codusuariom === null) {
        $stmt->bindValue(':codusuariom', null, PDO::PARAM_NULL);
    } else {
        $stmt->bindValue(':codusuariom', $codusuariom, PDO::PARAM_INT);
    }
    $stmt->bindParam(':codigo',      $codigo, PDO::PARAM_INT);

    if ($stmt->execute()) {
        ob_clean();
        echo json_encode(array('message' => 'Suplemento actualizado.'));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array('message' => 'No se pudo actualizar el suplemento.'));
    }
}

// ─── DELETE ───────────────────────────────────────────────────────────────────

function delete_suplemento($codigo) {
    global $db;

    $stmt = $db->prepare('DELETE FROM nu_suplementos WHERE codigo = :codigo');
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);

    if ($stmt->execute()) {
        ob_clean();
        echo json_encode(array('message' => 'Suplemento eliminado.'));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array('message' => 'No se pudo eliminar el suplemento.'));
    }
}
