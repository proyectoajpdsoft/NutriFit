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
PermissionManager::checkPermission($user, 'revisiones');

try {
    switch($request_method) {
        case 'GET':
            if (isset($_GET["total_revisiones"])) {
                $codigo_paciente = isset($_GET["codigo_paciente"]) ? intval($_GET["codigo_paciente"]) : null;
                get_total_revisiones($codigo_paciente);
            } elseif(!empty($_GET["codigo"])) {
                get_revision(intval($_GET["codigo"]));
            } elseif (!empty($_GET["codigo_paciente"])) {
                $codigo_paciente = intval($_GET["codigo_paciente"]);
                $completada = isset($_GET['completada']) ? htmlspecialchars(strip_tags($_GET['completada'])) : null;
                get_revisiones_por_paciente($codigo_paciente, $completada);
            } else {
                $completada = isset($_GET['completada']) ? htmlspecialchars(strip_tags($_GET['completada'])) : null;
                get_todas_revisiones($completada);
            }
            break;
        case 'POST':
            create_revision();
            break;
        case 'PUT':
            update_revision();
            break;
        case 'DELETE':
            delete_revision();
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

function get_revisiones_por_paciente($codigo_paciente, $completada) {
    global $db;
    $query = "SELECT r.*, p.nombre as nombre_paciente, p.activo as paciente_activo
              FROM nu_paciente_revision r
              LEFT JOIN nu_paciente p ON r.codigo_paciente = p.codigo
              WHERE r.codigo_paciente = :codigo_paciente";

    if ($completada !== null) {
        $query .= " AND r.completada = :completada";
    }
              
    $query .= " ORDER BY r.fecha_prevista DESC";
              
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    if ($completada !== null) {
        $stmt->bindParam(':completada', $completada);
    }
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean(); // <-- ARREGLO: Añadido ob_clean() para evitar errores de formato
    echo json_encode($items);
}

function get_todas_revisiones($completada) {
    global $db;
    $query = "SELECT r.*, p.nombre as nombre_paciente, p.activo as paciente_activo
              FROM nu_paciente_revision r
              LEFT JOIN nu_paciente p ON r.codigo_paciente = p.codigo";

    if ($completada !== null) {
        $query .= " WHERE r.completada = :completada";
    }
              
    $query .= " ORDER BY r.fecha_prevista DESC";
              
    $stmt = $db->prepare($query);
    if ($completada !== null) {
        $stmt->bindParam(':completada', $completada);
    }
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items);
}

function get_total_revisiones($codigo_paciente = null) {
    global $db;
    $query = "SELECT COUNT(*) as total FROM nu_paciente_revision";
    if ($codigo_paciente !== null) {
        $query .= " WHERE codigo_paciente = :codigo_paciente";
    }
    $stmt = $db->prepare($query);
    if ($codigo_paciente !== null) {
        $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    }
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($row);
}

function get_revision($codigo) {
// ...
// ...
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    if($item) {
        echo json_encode($item);
    } else {
        http_response_code(404);
        echo json_encode(array("message" => "Revisión no encontrada."));
    }
}

function bind_revision_params($stmt, &$data) {
    foreach ($data as $key => $value) {
        if (is_string($value)) {
            $data->$key = htmlspecialchars(strip_tags($value));
        }
    }

    // Explicitly handle nullable fields with bindValue
    if (isset($data->codigo_paciente) && $data->codigo_paciente !== null) {
        $stmt->bindParam(":codigo_paciente", $data->codigo_paciente, PDO::PARAM_INT);
    } else {
        $stmt->bindValue(":codigo_paciente", null, PDO::PARAM_NULL);
    }

    $stmt->bindParam(":asunto", $data->asunto);

    if (isset($data->fecha_prevista) && $data->fecha_prevista !== null && $data->fecha_prevista !== '') {
        $stmt->bindParam(":fecha_prevista", $data->fecha_prevista);
    } else {
        $stmt->bindValue(":fecha_prevista", null, PDO::PARAM_NULL);
    }

    if (isset($data->fecha_realizacion) && $data->fecha_realizacion !== null && $data->fecha_realizacion !== '') {
        $stmt->bindParam(":fecha_realizacion", $data->fecha_realizacion);
    } else {
        $stmt->bindValue(":fecha_realizacion", null, PDO::PARAM_NULL);
    }

    $stmt->bindParam(":semanas", $data->semanas);

    if (isset($data->modificacion_dieta) && $data->modificacion_dieta !== null && $data->modificacion_dieta !== '') {
        $stmt->bindParam(":modificacion_dieta", $data->modificacion_dieta);
    } else {
        $stmt->bindValue(":modificacion_dieta", null, PDO::PARAM_NULL);
    }

    $stmt->bindParam(":completada", $data->completada);
    $stmt->bindParam(":online", $data->online);

    if (isset($data->peso) && $data->peso !== null && $data->peso !== '') {
        // PDO::PARAM_STR is generally safe for decimal, it will be converted by the DB
        $stmt->bindParam(":peso", $data->peso);
    } else {
        $stmt->bindValue(":peso", null, PDO::PARAM_NULL);
    }
}

function create_revision() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;

    $query = "INSERT INTO nu_paciente_revision (
                codigo_paciente, asunto, fecha_prevista, fecha_realizacion, 
                semanas, modificacion_dieta, completada, online, peso, 
                fechaa, codusuarioa
              ) VALUES (
                :codigo_paciente, :asunto, :fecha_prevista, :fecha_realizacion, 
                :semanas, :modificacion_dieta, :completada, :online, :peso, 
                NOW(), :codusuarioa
              )";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codusuarioa", $codusuarioa);
    bind_revision_params($stmt, $data);

    ob_clean();
    if($stmt->execute()){
        http_response_code(201);
        echo json_encode(array("message" => "Revisión creada."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo crear la revisión.", "errorInfo" => $stmt->errorInfo()));
    }
}

function update_revision() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el código de la revisión."));
        return;
    }

    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;

    $query = "UPDATE nu_paciente_revision SET
                codigo_paciente = :codigo_paciente, asunto = :asunto, fecha_prevista = :fecha_prevista,
                fecha_realizacion = :fecha_realizacion, semanas = :semanas, modificacion_dieta = :modificacion_dieta,
                completada = :completada, online = :online, peso = :peso,
                fecham = NOW(), codusuariom = :codusuariom
              WHERE codigo = :codigo";

    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);
    $stmt->bindParam(":codusuariom", $codusuariom);
    bind_revision_params($stmt, $data);

    ob_clean();
    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Revisión actualizada."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo actualizar la revisión.", "errorInfo" => $stmt->errorInfo()));
    }
}

function delete_revision() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el código de la revisión."));
        return;
    }

    $query = "DELETE FROM nu_paciente_revision WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);

    ob_clean();
    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Revisión eliminada."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo eliminar la revisión.", "errorInfo" => $stmt->errorInfo()));
    }
}
?>