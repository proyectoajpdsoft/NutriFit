<?php
ob_start(); // Iniciar el buffer de salida como primera instrucción

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Max-Age: 3600");
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

// ⭐ VALIDAR TOKEN
$validator = new TokenValidator($db);
$user = $validator->validateToken();

// ⭐ VALIDAR PERMISOS
PermissionManager::checkPermission($user, 'citas');

$request_method = $_SERVER["REQUEST_METHOD"];

try {
    switch($request_method) {
        case 'GET':
            if (isset($_GET["total_citas"])) {
                $codigo_paciente = isset($_GET["codigo_paciente"]) ? intval($_GET["codigo_paciente"]) : null;
                get_total_citas($codigo_paciente);
            } elseif(!empty($_GET["codigo"])) {
                get_cita(intval($_GET["codigo"]));
            } else {
                // Parámetros para filtrado flexible
                $month = isset($_GET['month']) ? intval($_GET['month']) : null;
                $year = isset($_GET['year']) ? intval($_GET['year']) : null;
                $estado = isset($_GET['estado']) ? htmlspecialchars(strip_tags($_GET['estado'])) : null;
                $codigo_paciente = isset($_GET['codigo_paciente']) ? intval($_GET['codigo_paciente']) : null;
                get_citas($month, $year, $estado, $codigo_paciente);
            }
            break;
        case 'POST':
            create_cita();
            break;
        case 'PUT':
            update_cita();
            break;
        case 'DELETE':
            delete_cita();
            break;
        default:
            http_response_code(405);
            ob_clean();
            echo json_encode(array("message" => "Method Not Allowed"));
            break;
    }
} catch (Throwable $e) {
    http_response_code(500);
    ob_clean();
    echo json_encode(array(
        "message" => "Error fatal en el servidor.",
        "error_details" => $e->getMessage(),
        "file" => $e->getFile(),
        "line" => $e->getLine()
    ));
}

function get_total_citas($codigo_paciente = null) {
    global $db;
    $query = "SELECT COUNT(*) as total FROM nu_cita";
    $params = [];
    $where_clauses = [];

    if ($codigo_paciente !== null) {
        $where_clauses[] = "codigo_paciente = :codigo_paciente";
        $params[':codigo_paciente'] = $codigo_paciente;
    }

    if (!empty($where_clauses)) {
        $query .= " WHERE " . implode(" AND ", $where_clauses);
    }
    
    $stmt = $db->prepare($query);

    if ($codigo_paciente !== null) {
        $stmt->bindParam(':codigo_paciente', $params[':codigo_paciente'], PDO::PARAM_INT);
    }

    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($row);
}


function get_citas($month, $year, $estado, $codigo_paciente) {
    global $db;
    $query = "SELECT c.*, p.nombre as nombre_paciente 
              FROM nu_cita c
              LEFT JOIN nu_paciente p ON c.codigo_paciente = p.codigo";
    
    $params = [];
    $where_clauses = [];

    if ($month !== null && $year !== null) {
        $where_clauses[] = "MONTH(c.comienzo) = :month AND YEAR(c.comienzo) = :year";
        $params[':month'] = $month;
        $params[':year'] = $year;
    }

    if ($estado !== null) {
        $where_clauses[] = "c.estado = :estado";
        $params[':estado'] = $estado;
    }

    if ($codigo_paciente !== null) {
        $where_clauses[] = "c.codigo_paciente = :codigo_paciente";
        $params[':codigo_paciente'] = $codigo_paciente;
    }

    if (!empty($where_clauses)) {
        $query .= " WHERE " . implode(" AND ", $where_clauses);
    }

    $query .= " ORDER BY c.comienzo DESC"; // Ordenamos por más reciente primero para la lista
              
    $stmt = $db->prepare($query);

    // Bindeamos los parámetros dinámicamente
    if ($month !== null && $year !== null) {
        $stmt->bindParam(':month', $params[':month'], PDO::PARAM_INT);
        $stmt->bindParam(':year', $params[':year'], PDO::PARAM_INT);
    }
    if ($estado !== null) {
        $stmt->bindParam(':estado', $params[':estado'], PDO::PARAM_STR);
    }
    if ($codigo_paciente !== null) {
        $stmt->bindParam(':codigo_paciente', $params[':codigo_paciente'], PDO::PARAM_INT);
    }
    
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items);
}

function get_cita($codigo) {
    global $db;
    $query = "SELECT c.*, p.nombre as nombre_paciente 
              FROM nu_cita c
              LEFT JOIN nu_paciente p ON c.codigo_paciente = p.codigo
              WHERE c.codigo = :codigo LIMIT 0,1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    if($item) {
        echo json_encode($item);
    } else {
        http_response_code(404);
        echo json_encode(array("message" => "Cita no encontrada."));
    }
}

function create_cita() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    // Validaciones básicas
    if (empty($data->codigo_paciente) || empty($data->asunto) || empty($data->comienzo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Faltan datos requeridos (paciente, asunto, comienzo)."));
        return;
    }

    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;

    $query = "INSERT INTO nu_cita (codigo_paciente, comienzo, fin, tipo, online, estado, asunto, descripcion, ubicacion, fechaa, codusuarioa) 
              VALUES (:codigo_paciente, :comienzo, :fin, :tipo, :online, :estado, :asunto, :descripcion, :ubicacion, NOW(), :codusuarioa)";
    
    $stmt = $db->prepare($query);

    // Asignación y sanitización
    $codigo_paciente = filter_var($data->codigo_paciente, FILTER_VALIDATE_INT);
    $comienzo = htmlspecialchars(strip_tags($data->comienzo));
    $fin = htmlspecialchars(strip_tags($data->fin));
    $tipo = htmlspecialchars(strip_tags($data->tipo));
    $online = htmlspecialchars(strip_tags($data->online));
    $estado = htmlspecialchars(strip_tags($data->estado));
    $asunto = htmlspecialchars(strip_tags($data->asunto));
    $descripcion = htmlspecialchars(strip_tags($data->descripcion));
    $ubicacion = htmlspecialchars(strip_tags($data->ubicacion));

    $stmt->bindParam(":codigo_paciente", $codigo_paciente);
    $stmt->bindParam(":comienzo", $comienzo);
    $stmt->bindParam(":fin", $fin);
    $stmt->bindParam(":tipo", $tipo);
    $stmt->bindParam(":online", $online);
    $stmt->bindParam(":estado", $estado);
    $stmt->bindParam(":asunto", $asunto);
    $stmt->bindParam(":descripcion", $descripcion);
    $stmt->bindParam(":ubicacion", $ubicacion);
    $stmt->bindParam(":codusuarioa", $codusuarioa);
    
    ob_clean();
    if($stmt->execute()){
        http_response_code(201);
        echo json_encode(array("message" => "Cita creada."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo crear la cita.", "errorInfo" => $stmt->errorInfo()));
    }
}

function update_cita() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el código de la cita."));
        return;
    }
    
    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;
    
    $query = "UPDATE nu_cita SET 
                codigo_paciente = :codigo_paciente, 
                comienzo = :comienzo, 
                fin = :fin, 
                tipo = :tipo, 
                online = :online, 
                estado = :estado, 
                asunto = :asunto, 
                descripcion = :descripcion, 
                ubicacion = :ubicacion, 
                fecham = NOW(), 
                codusuariom = :codusuariom 
              WHERE codigo = :codigo";
    
    $stmt = $db->prepare($query);

    $codigo = filter_var($data->codigo, FILTER_VALIDATE_INT);
    $codigo_paciente = filter_var($data->codigo_paciente, FILTER_VALIDATE_INT);
    $comienzo = htmlspecialchars(strip_tags($data->comienzo));
    $fin = htmlspecialchars(strip_tags($data->fin));
    $tipo = htmlspecialchars(strip_tags($data->tipo));
    $online = htmlspecialchars(strip_tags($data->online));
    $estado = htmlspecialchars(strip_tags($data->estado));
    $asunto = htmlspecialchars(strip_tags($data->asunto));
    $descripcion = htmlspecialchars(strip_tags($data->descripcion));
    $ubicacion = htmlspecialchars(strip_tags($data->ubicacion));

    $stmt->bindParam(":codigo", $codigo);
    $stmt->bindParam(":codigo_paciente", $codigo_paciente);
    $stmt->bindParam(":comienzo", $comienzo);
    $stmt->bindParam(":fin", $fin);
    $stmt->bindParam(":tipo", $tipo);
    $stmt->bindParam(":online", $online);
    $stmt->bindParam(":estado", $estado);
    $stmt->bindParam(":asunto", $asunto);
    $stmt->bindParam(":descripcion", $descripcion);
    $stmt->bindParam(":ubicacion", $ubicacion);
    $stmt->bindParam(":codusuariom", $codusuariom);

    ob_clean();
    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Cita actualizada."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo actualizar la cita.", "errorInfo" => $stmt->errorInfo()));
    }
}

function delete_cita() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if(empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el código de la cita."));
        return;
    }

    $query = "DELETE FROM nu_cita WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    
    $codigo = filter_var($data->codigo, FILTER_VALIDATE_INT);
    $stmt->bindParam(":codigo", $codigo);

    ob_clean();
    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Cita eliminada."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo eliminar la cita.", "errorInfo" => $stmt->errorInfo()));
    }
}
?>