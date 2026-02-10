<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS");
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
    case 'POST':
        assign_categoria_to_ejercicio();
        break;
    case 'DELETE':
        remove_categoria_from_ejercicio();
        break;
    default:
        http_response_code(405);
        echo json_encode(["message" => "Método no permitido."]);
        break;
}

function assign_categoria_to_ejercicio() {
    global $db;
    $codigo_ejercicio = isset($_POST['codigo_ejercicio']) ? intval($_POST['codigo_ejercicio']) : 0;
    $codigo_categoria = isset($_POST['codigo_categoria']) ? intval($_POST['codigo_categoria']) : 0;

    if ($codigo_ejercicio === 0 || $codigo_categoria === 0) {
        http_response_code(400);
        echo json_encode(["message" => "codigo_ejercicio y codigo_categoria son obligatorios."]);
        return;
    }

    $query = "INSERT IGNORE INTO nu_plan_fit_ejercicios_categorias (codigo_ejercicio, codigo_categoria) 
              VALUES (:codigo_ejercicio, :codigo_categoria)";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_ejercicio', $codigo_ejercicio);
    $stmt->bindParam(':codigo_categoria', $codigo_categoria);

    if ($stmt->execute()) {
        http_response_code(201);
        ob_clean();
        echo json_encode(["message" => "Categoría asignada al ejercicio."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "Error al asignar categoría.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function remove_categoria_from_ejercicio() {
    global $db;
    $data = json_decode(file_get_contents("php://input"), true);
    $codigo_ejercicio = isset($data['codigo_ejercicio']) ? intval($data['codigo_ejercicio']) : 0;
    $codigo_categoria = isset($data['codigo_categoria']) ? intval($data['codigo_categoria']) : 0;

    if ($codigo_ejercicio === 0 || $codigo_categoria === 0) {
        http_response_code(400);
        echo json_encode(["message" => "codigo_ejercicio y codigo_categoria son obligatorios."]);
        return;
    }

    $query = "DELETE FROM nu_plan_fit_ejercicios_categorias 
              WHERE codigo_ejercicio = :codigo_ejercicio AND codigo_categoria = :codigo_categoria";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_ejercicio', $codigo_ejercicio);
    $stmt->bindParam(':codigo_categoria', $codigo_categoria);

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Categoría eliminada del ejercicio."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "Error al eliminar categoría.", "errorInfo" => $stmt->errorInfo()]);
    }
}
?>
