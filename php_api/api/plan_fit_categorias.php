<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/permissions.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

// Validar token
$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'planes_fit');

$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {
    case 'GET':
        get_categorias();
        break;
    case 'POST':
        if (isset($_POST['codigo']) && intval($_POST['codigo']) > 0) {
            update_categoria();
        } else {
            create_categoria();
        }
        break;
    case 'DELETE':
        delete_categoria();
        break;
    default:
        http_response_code(405);
        echo json_encode(["message" => "Método no permitido."]);
        break;
}

function get_categorias() {
    global $db;
    $query = "SELECT codigo, nombre, descripcion, orden, activo 
              FROM nu_plan_fit_categorias 
              WHERE activo = 'S' 
              ORDER BY orden, nombre";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items ?? []);
}

function create_categoria() {
    global $db;
    $nombre = trim($_POST['nombre'] ?? '');
    $descripcion = $_POST['descripcion'] ?? null;
    $orden = isset($_POST['orden']) && $_POST['orden'] !== '' ? intval($_POST['orden']) : 0;
    $codusuario = isset($_POST['codusuarioa']) ? intval($_POST['codusuarioa']) : null;

    if ($nombre === '') {
        http_response_code(400);
        echo json_encode(["message" => "El nombre es obligatorio."]);
        return;
    }

    $query = "INSERT INTO nu_plan_fit_categorias (nombre, descripcion, orden, activo, codusuarioa, fechaa) 
              VALUES (:nombre, :descripcion, :orden, 'S', :codusuario, NOW())";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':descripcion', $descripcion);
    $stmt->bindParam(':orden', $orden);
    $stmt->bindParam(':codusuario', $codusuario);

    if ($stmt->execute()) {
        http_response_code(201);
        ob_clean();
        echo json_encode(["message" => "Categoría creada.", "codigo" => $db->lastInsertId()]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "Error al crear categoría.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function update_categoria() {
    global $db;
    $codigo = intval($_POST['codigo']);
    $nombre = trim($_POST['nombre'] ?? '');
    $descripcion = $_POST['descripcion'] ?? null;
    $orden = isset($_POST['orden']) && $_POST['orden'] !== '' ? intval($_POST['orden']) : 0;
    $codusuario = isset($_POST['codusuariom']) ? intval($_POST['codusuariom']) : null;

    if ($nombre === '') {
        http_response_code(400);
        echo json_encode(["message" => "El nombre es obligatorio."]);
        return;
    }

    $query = "UPDATE nu_plan_fit_categorias 
              SET nombre = :nombre, descripcion = :descripcion, orden = :orden, 
                  codusuariom = :codusuario, fecham = NOW()
              WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':descripcion', $descripcion);
    $stmt->bindParam(':orden', $orden);
    $stmt->bindParam(':codusuario', $codusuario);

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Categoría actualizada."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "Error al actualizar categoría.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function delete_categoria() {
    global $db;
    $data = json_decode(file_get_contents("php://input"), true);
    $codigo = isset($data['codigo']) ? intval($data['codigo']) : 0;

    if ($codigo === 0) {
        http_response_code(400);
        echo json_encode(["message" => "Código inválido."]);
        return;
    }

    // Soft delete
    $query = "UPDATE nu_plan_fit_categorias SET activo = 'N' WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Categoría eliminada."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "Error al eliminar categoría.", "errorInfo" => $stmt->errorInfo()]);
    }
}
?>
