<?php
ob_start(); // Iniciar el buffer de salida
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
$request_method = $_SERVER["REQUEST_METHOD"];

// Validar token (solo usuarios registrados con paciente)
$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'mediciones');

switch($request_method) {
    case 'GET':
        if (isset($_GET["total_mediciones"])) {
            $codigo_paciente = isset($_GET["codigo_paciente"]) ? intval($_GET["codigo_paciente"]) : null;
            get_total_mediciones($codigo_paciente);
        } elseif(!empty($_GET["codigo"])) {
            get_medicion(intval($_GET["codigo"]));
        } elseif (!empty($_GET["codigo_paciente"])) {
            get_mediciones_por_paciente(intval($_GET["codigo_paciente"]));
        } else {
            get_todas_mediciones();
        }
        break;
    case 'POST':
        create_medicion();
        break;
    case 'PUT':
        update_medicion();
        break;
    case 'DELETE':
        delete_medicion();
        break;
    default:
        header("HTTP/1.0 405 Method Not Allowed");
        break;
}

function get_mediciones_por_paciente($codigo_paciente) {
    global $db;
    $query = "SELECT m.*, p.nombre as nombre_paciente, p.activo as paciente_activo
              FROM nu_paciente_medicion m
              LEFT JOIN nu_paciente p ON m.codigo_paciente = p.codigo
              WHERE m.codigo_paciente = :codigo_paciente
              ORDER BY m.fecha DESC";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode($items);
}

function get_todas_mediciones() {
    global $db;
    $query = "SELECT m.*, p.nombre as nombre_paciente, p.activo as paciente_activo
              FROM nu_paciente_medicion m
              LEFT JOIN nu_paciente p ON m.codigo_paciente = p.codigo
              ORDER BY m.fecha DESC";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode($items);
}

function get_medicion($codigo) {
    global $db;
    $query = "SELECT * FROM nu_paciente_medicion WHERE codigo = :codigo LIMIT 0,1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);
    if($item) {
        echo json_encode($item);
    } else {
        http_response_code(404);
        echo json_encode(array("message" => "Medición no encontrada."));
    }
}

function bind_medicion_params($stmt, $data) {
    // Convertir strings vacíos a null y strings numéricos a números
    $data->peso = ($data->peso === '' || $data->peso === null) ? null : floatval($data->peso);
    $data->pliegue_abdominal = ($data->pliegue_abdominal === '' || $data->pliegue_abdominal === null) ? null : floatval($data->pliegue_abdominal);
    $data->pliegue_cuadricipital = ($data->pliegue_cuadricipital === '' || $data->pliegue_cuadricipital === null) ? null : floatval($data->pliegue_cuadricipital);
    $data->pliegue_peroneal = ($data->pliegue_peroneal === '' || $data->pliegue_peroneal === null) ? null : floatval($data->pliegue_peroneal);
    $data->pliegue_subescapular = ($data->pliegue_subescapular === '' || $data->pliegue_subescapular === null) ? null : floatval($data->pliegue_subescapular);
    $data->pligue_tricipital = ($data->pligue_tricipital === '' || $data->pligue_tricipital === null) ? null : floatval($data->pligue_tricipital);
    $data->pliegue_suprailiaco = ($data->pliegue_suprailiaco === '' || $data->pliegue_suprailiaco === null) ? null : floatval($data->pliegue_suprailiaco);

    $stmt->bindParam(":codigo_paciente", $data->codigo_paciente);
    $stmt->bindParam(":fecha", $data->fecha);
    $stmt->bindParam(":peso", $data->peso);
    $stmt->bindParam(":actividad_fisica", $data->actividad_fisica);
    $stmt->bindParam(":pliegue_abdominal", $data->pliegue_abdominal);
    $stmt->bindParam(":pliegue_cuadricipital", $data->pliegue_cuadricipital);
    $stmt->bindParam(":pliegue_peroneal", $data->pliegue_peroneal);
    $stmt->bindParam(":pliegue_subescapular", $data->pliegue_subescapular);
    $stmt->bindParam(":pligue_tricipital", $data->pligue_tricipital);
    $stmt->bindParam(":pliegue_suprailiaco", $data->pliegue_suprailiaco);
    $stmt->bindParam(":observacion", $data->observacion);
}


function create_medicion() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;

    $query = "INSERT INTO nu_paciente_medicion SET
                codigo_paciente = :codigo_paciente, fecha = :fecha, peso = :peso,
                actividad_fisica = :actividad_fisica, pliegue_abdominal = :pliegue_abdominal,
                pliegue_cuadricipital = :pliegue_cuadricipital, pliegue_peroneal = :pliegue_peroneal,
                pliegue_subescapular = :pliegue_subescapular, pligue_tricipital = :pligue_tricipital,
                pliegue_suprailiaco = :pliegue_suprailiaco, observacion = :observacion,
                fechaa = NOW(), codusuarioa = :codusuarioa";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codusuarioa", $codusuarioa);
    bind_medicion_params($stmt, $data);

    if($stmt->execute()){
        http_response_code(201);
        echo json_encode(array("message" => "Medición creada."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo crear la medición."));
    }
}

function update_medicion() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código de la medición."));
        return;
    }

    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;

    $query = "UPDATE nu_paciente_medicion SET
                codigo_paciente = :codigo_paciente, fecha = :fecha, peso = :peso,
                actividad_fisica = :actividad_fisica, pliegue_abdominal = :pliegue_abdominal,
                pliegue_cuadricipital = :pliegue_cuadricipital, pliegue_peroneal = :pliegue_peroneal,
                pliegue_subescapular = :pliegue_subescapular, pligue_tricipital = :pligue_tricipital,
                pliegue_suprailiaco = :pliegue_suprailiaco, observacion = :observacion,
                fecham = NOW(), codusuariom = :codusuariom
              WHERE codigo = :codigo";

    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);
    $stmt->bindParam(":codusuariom", $codusuariom);
    bind_medicion_params($stmt, $data);

    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Medición actualizada."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo actualizar la medición."));
    }
}

function delete_medicion() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código de la medición."));
        return;
    }

    $query = "DELETE FROM nu_paciente_medicion WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);

    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Medición eliminada."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo eliminar la medición."));
    }
}

function get_total_mediciones($codigo_paciente = null) {
    global $db;

    $query = "SELECT COUNT(*) as total FROM nu_paciente_medicion";
    if ($codigo_paciente !== null) {
        $query .= " WHERE codigo_paciente = :codigo_paciente";
    }

    $stmt = $db->prepare($query);
    if ($codigo_paciente !== null) {
        $stmt->bindParam(':codigo_paciente', $codigo_paciente, PDO::PARAM_INT);
    }

    if ($stmt->execute()) {
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        ob_clean();
        echo json_encode(array("total_mediciones" => (int)$row['total']));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo obtener el total de mediciones.", "errorInfo" => $stmt->errorInfo()));
    }
}
?>