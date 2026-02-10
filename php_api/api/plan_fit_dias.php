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
        if (isset($_GET['codigo_plan_fit'])) {
            get_dias_plan_fit(intval($_GET['codigo_plan_fit']));
        } elseif (isset($_GET['codigo_dia'])) {
            get_dia_by_id(intval($_GET['codigo_dia']));
        }
        break;
    case 'POST':
        if (isset($_POST['codigo']) && intval($_POST['codigo']) > 0) {
            update_dia();
        } else {
            create_dia();
        }
        break;
    case 'DELETE':
        delete_dia();
        break;
    default:
        http_response_code(405);
        echo json_encode(["message" => "Método no permitido."]);
        break;
}

function get_dias_plan_fit($codigo_plan_fit) {
    global $db;
    $query = "SELECT d.codigo, d.codigo_plan_fit, d.numero_dia, d.titulo, d.descripcion, d.orden,
                     COUNT(e.codigo) as total_ejercicios
              FROM nu_plan_fit_dias d
              LEFT JOIN nu_plan_fit_ejercicio e ON e.codigo_dia = d.codigo
              WHERE d.codigo_plan_fit = :codigo_plan_fit
              GROUP BY d.codigo
              ORDER BY d.orden, d.numero_dia";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_plan_fit', $codigo_plan_fit);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items ?? []);
}

function get_dia_by_id($codigo_dia) {
    global $db;
    $query = "SELECT codigo, codigo_plan_fit, numero_dia, titulo, descripcion, orden
              FROM nu_plan_fit_dias
              WHERE codigo = :codigo_dia
              LIMIT 1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_dia', $codigo_dia);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($item ?: null);
}

function create_dia() {
    global $db;
    $codigo_plan_fit = isset($_POST['codigo_plan_fit']) ? intval($_POST['codigo_plan_fit']) : 0;
    $numero_dia = isset($_POST['numero_dia']) ? intval($_POST['numero_dia']) : 0;
    $titulo = $_POST['titulo'] ?? null;
    $descripcion = $_POST['descripcion'] ?? null;
    $orden = isset($_POST['orden']) && $_POST['orden'] !== '' ? intval($_POST['orden']) : 0;
    $codusuario = isset($_POST['codusuarioa']) ? intval($_POST['codusuarioa']) : null;

    if ($codigo_plan_fit === 0 || $numero_dia === 0) {
        http_response_code(400);
        echo json_encode(["message" => "codigo_plan_fit y numero_dia son obligatorios."]);
        return;
    }

    $query = "INSERT INTO nu_plan_fit_dias (codigo_plan_fit, numero_dia, titulo, descripcion, orden, codusuarioa, fechaa) 
              VALUES (:codigo_plan_fit, :numero_dia, :titulo, :descripcion, :orden, :codusuario, NOW())";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_plan_fit', $codigo_plan_fit);
    $stmt->bindParam(':numero_dia', $numero_dia);
    $stmt->bindParam(':titulo', $titulo);
    $stmt->bindParam(':descripcion', $descripcion);
    $stmt->bindParam(':orden', $orden);
    $stmt->bindParam(':codusuario', $codusuario);

    if ($stmt->execute()) {
        http_response_code(201);
        ob_clean();
        echo json_encode(["message" => "Día creado.", "codigo" => $db->lastInsertId()]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "Error al crear día.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function update_dia() {
    global $db;
    $codigo = intval($_POST['codigo']);
    $numero_dia = isset($_POST['numero_dia']) ? intval($_POST['numero_dia']) : null;
    $titulo = $_POST['titulo'] ?? null;
    $descripcion = $_POST['descripcion'] ?? null;
    $orden = isset($_POST['orden']) && $_POST['orden'] !== '' ? intval($_POST['orden']) : 0;
    $codusuario = isset($_POST['codusuariom']) ? intval($_POST['codusuariom']) : null;

    $query = "UPDATE nu_plan_fit_dias 
              SET numero_dia = :numero_dia, titulo = :titulo, descripcion = :descripcion, orden = :orden,
                  codusuariom = :codusuario, fecham = NOW()
              WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->bindParam(':numero_dia', $numero_dia);
    $stmt->bindParam(':titulo', $titulo);
    $stmt->bindParam(':descripcion', $descripcion);
    $stmt->bindParam(':orden', $orden);
    $stmt->bindParam(':codusuario', $codusuario);

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Día actualizado."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "Error al actualizar día.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function delete_dia() {
    global $db;
    $data = json_decode(file_get_contents("php://input"), true);
    $codigo = isset($data['codigo']) ? intval($data['codigo']) : 0;

    if ($codigo === 0) {
        http_response_code(400);
        echo json_encode(["message" => "Código inválido."]);
        return;
    }

    // Los ejercicios se eliminan en cascada
    $query = "DELETE FROM nu_plan_fit_dias WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Día eliminado."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "Error al eliminar día.", "errorInfo" => $stmt->errorInfo()]);
    }
}
?>
