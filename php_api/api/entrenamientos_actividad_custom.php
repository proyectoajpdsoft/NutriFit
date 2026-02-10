<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once '../config/database.php';
require_once '../auth/token_validator.php';
require_once '../auth/auto_validator.php';
require_once '../auth/permissions.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method == "OPTIONS") {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

$validator = new AutoValidator($db);
$user = $validator->validate();

PermissionManager::checkPermission($user, 'entrenamientos');

function list_custom_activities($db, $codigo_usuario) {
    $query = "SELECT codigo, nombre, icono, fechaa, fecham
              FROM nu_entrenamientos_actividad_custom
              WHERE codigo_usuario = :codigo_usuario
              ORDER BY nombre ASC";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_usuario', $codigo_usuario);
    $stmt->execute();

    $items = array();
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $items[] = $row;
    }

    return $items;
}

function create_custom_activity($db, $codigo_usuario, $nombre, $icono, $codusuarioa) {
    $query = "INSERT INTO nu_entrenamientos_actividad_custom
              (codigo_usuario, nombre, icono, codusuarioa, fechaa)
              VALUES
              (:codigo_usuario, :nombre, :icono, :codusuarioa, NOW())";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_usuario', $codigo_usuario);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':icono', $icono);
    $stmt->bindParam(':codusuarioa', $codusuarioa);

    if ($stmt->execute()) {
        return array('success' => true, 'codigo' => $db->lastInsertId());
    }

    return array('success' => false, 'message' => 'Error al crear la actividad');
}

function update_custom_activity($db, $codigo_usuario, $codigo, $nombre, $icono, $codusuariom) {
    $query = "UPDATE nu_entrenamientos_actividad_custom
              SET nombre = :nombre,
                  icono = :icono,
                  fecham = NOW(),
                  codusuariom = :codusuariom
              WHERE codigo = :codigo
              AND codigo_usuario = :codigo_usuario";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':icono', $icono);
    $stmt->bindParam(':codusuariom', $codusuariom);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->bindParam(':codigo_usuario', $codigo_usuario);

    if ($stmt->execute()) {
        return array('success' => true);
    }

    return array('success' => false, 'message' => 'Error al actualizar la actividad');
}

function delete_custom_activity($db, $codigo_usuario, $codigo) {
    $query = "DELETE FROM nu_entrenamientos_actividad_custom
              WHERE codigo = :codigo
              AND codigo_usuario = :codigo_usuario";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->bindParam(':codigo_usuario', $codigo_usuario);

    if ($stmt->execute()) {
        return array('success' => true);
    }

    return array('success' => false, 'message' => 'Error al eliminar la actividad');
}

$action = $_GET['action'] ?? 'list';
$codigo_usuario = $user['codigo'] ?? 0;

if (!empty($user['es_guest'])) {
    if ($action === 'list') {
        http_response_code(200);
        echo json_encode(array());
        exit();
    }
    http_response_code(403);
    echo json_encode(array('message' => 'No permitido para usuarios invitados'));
    exit();
}

switch ($action) {
    case 'list':
        $items = list_custom_activities($db, $codigo_usuario);
        http_response_code(200);
        echo json_encode($items);
        break;

    case 'create':
        if ($method != 'POST') {
            http_response_code(405);
            echo json_encode(array('message' => 'Metodo POST requerido'));
            exit();
        }

        $data = json_decode(file_get_contents("php://input"), true);
        $nombre = trim($data['nombre'] ?? '');
        $icono = trim($data['icono'] ?? '💪');

        if ($nombre === '') {
            http_response_code(400);
            echo json_encode(array('message' => 'Nombre requerido'));
            exit();
        }

        $result = create_custom_activity($db, $codigo_usuario, $nombre, $icono, (string)$codigo_usuario);
        if ($result['success']) {
            http_response_code(201);
            echo json_encode(array(
                'success' => true,
                'codigo' => $result['codigo'],
                'nombre' => $nombre,
                'icono' => $icono
            ));
        } else {
            http_response_code(500);
            echo json_encode($result);
        }
        break;

    case 'update':
        if ($method != 'PUT') {
            http_response_code(405);
            echo json_encode(array('message' => 'Metodo PUT requerido'));
            exit();
        }

        $codigo = $_GET['codigo'] ?? null;
        $data = json_decode(file_get_contents("php://input"), true);
        $nombre = trim($data['nombre'] ?? '');
        $icono = trim($data['icono'] ?? '💪');

        if (!$codigo || $nombre === '') {
            http_response_code(400);
            echo json_encode(array('message' => 'Codigo y nombre requeridos'));
            exit();
        }

        $result = update_custom_activity($db, $codigo_usuario, $codigo, $nombre, $icono, $codigo_usuario);
        if ($result['success']) {
            http_response_code(200);
            echo json_encode(array('success' => true));
        } else {
            http_response_code(500);
            echo json_encode($result);
        }
        break;

    case 'delete':
        if ($method != 'DELETE') {
            http_response_code(405);
            echo json_encode(array('message' => 'Metodo DELETE requerido'));
            exit();
        }

        $codigo = $_GET['codigo'] ?? null;
        if (!$codigo) {
            http_response_code(400);
            echo json_encode(array('message' => 'Codigo requerido'));
            exit();
        }

        $result = delete_custom_activity($db, $codigo_usuario, $codigo);
        if ($result['success']) {
            http_response_code(200);
            echo json_encode($result);
        } else {
            http_response_code(500);
            echo json_encode($result);
        }
        break;

    default:
        http_response_code(400);
        echo json_encode(array('message' => 'Accion no reconocida'));
        break;
}
?>
