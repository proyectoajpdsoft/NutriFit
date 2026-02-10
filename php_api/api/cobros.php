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

// Validar token
$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'cobros');

switch($request_method) {
    case 'GET':
        if (isset($_GET["total_cobros"])) {
            $codigo_paciente = isset($_GET["codigo_paciente"]) ? intval($_GET["codigo_paciente"]) : null;
            get_total_cobros($codigo_paciente);
        } elseif (isset($_GET["sum_importe_cobros"])) {
            $codigo_paciente = isset($_GET["codigo_paciente"]) ? intval($_GET["codigo_paciente"]) : null;
            get_sum_importe_cobros($codigo_paciente);
        } elseif(!empty($_GET["codigo"])) {
            get_cobro(intval($_GET["codigo"]));
        } elseif (isset($_GET["codigo_paciente"])) {
            get_cobros(intval($_GET["codigo_paciente"]));
        } else {
            get_cobros(null);
        }
        break;
    case 'POST':
        create_cobro();
        break;
    case 'PUT':
        update_cobro();
        break;
    case 'DELETE':
        delete_cobro();
        break;
    default:
        header("HTTP/1.0 405 Method Not Allowed");
        break;
}

function get_sum_importe_cobros($codigo_paciente = null) {
    global $db;
    $query = "SELECT SUM(importe) as total_importe FROM cobro";
     if ($codigo_paciente !== null) {
        $query .= " WHERE codigo_paciente = :codigo_paciente";
    }
    $stmt = $db->prepare($query);
    if ($codigo_paciente !== null) {
        $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    }
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    // Si la suma es NULL (ningún registro), devuelve 0.
    $row['total_importe'] = $row['total_importe'] ?? "0";
    ob_clean();
    echo json_encode($row);
}

function get_cobros($codigo_paciente = null) {
    global $db;
    $query = "SELECT 
                c.codigo, c.fecha, c.importe, c.descripcion, 
                c.codigo_paciente, p.nombre as nombre_paciente,
                c.codigocliente, t.nombre as nombre_cliente
              FROM cobro c
              LEFT JOIN nu_paciente p ON c.codigo_paciente = p.codigo
              LEFT JOIN tercero t ON c.codigocliente = t.codigo";

    $params = [];
    if ($codigo_paciente !== null) {
        $query .= " WHERE c.codigo_paciente = :codigo_paciente";
        $params[':codigo_paciente'] = $codigo_paciente;
    }

    $query .= " ORDER BY c.fecha DESC";
              
    $stmt = $db->prepare($query);

    if ($codigo_paciente !== null) {
        $stmt->bindParam(':codigo_paciente', $params[':codigo_paciente'], PDO::PARAM_INT);
    }

    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items);
}

function get_cobro($codigo) {
    global $db;
    $query = "SELECT * FROM cobro WHERE codigo = :codigo LIMIT 0,1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);
    if($item) {
        ob_clean(); // Limpiar antes de enviar el JSON
        echo json_encode($item);
    } else {
        http_response_code(404);
        ob_clean(); // Limpiar antes de enviar el JSON de error
        echo json_encode(array("message" => "Cobro no encontrado."));
    }
}

function bind_cobro_params($stmt, &$data) {
    // Sanitizar todos los campos de texto del objeto $data
    foreach ($data as $key => $value) {
        if (is_string($value)) {
            $data->$key = htmlspecialchars(strip_tags($value));
        }
    }

    // bindParam para campos que pueden ser NULL
    if (isset($data->fecha) && $data->fecha !== null && $data->fecha !== '') {
        // Formatear la fecha a 'YYYY-MM-DD' para el campo DATE de la BD
        $formatted_date = date('Y-m-d', strtotime($data->fecha));
        $stmt->bindParam(":fecha", $formatted_date);
    } else {
        $stmt->bindValue(":fecha", null, PDO::PARAM_NULL);
    }

    if (isset($data->importe) && $data->importe !== null && $data->importe !== '') {
        $stmt->bindParam(":importe", $data->importe);
    } else {
        $stmt->bindValue(":importe", null, PDO::PARAM_NULL);
    }
    
    // Descripcion puede ser nula
    if (isset($data->descripcion) && $data->descripcion !== null && $data->descripcion !== '') {
        $stmt->bindParam(":descripcion", $data->descripcion);
    } else {
        $stmt->bindValue(":descripcion", null, PDO::PARAM_NULL);
    }

    // codigo_paciente y codigocliente: sólo uno puede tener valor, el otro es NULL
    if (isset($data->codigo_paciente) && $data->codigo_paciente !== null) {
        $stmt->bindParam(":codigo_paciente", $data->codigo_paciente, PDO::PARAM_INT);
    } else {
        $stmt->bindValue(":codigo_paciente", null, PDO::PARAM_NULL);
    }

    if (isset($data->codigocliente) && $data->codigocliente !== null) {
        $stmt->bindParam(":codigocliente", $data->codigocliente, PDO::PARAM_INT);
    } else {
        $stmt->bindValue(":codigocliente", null, PDO::PARAM_NULL);
    }
}

function create_cobro() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;

    $query = "INSERT INTO cobro SET
                fecha = :fecha, importe = :importe, descripcion = :descripcion,
                codigo_paciente = :codigo_paciente, codigocliente = :codigocliente,
                fechaa = NOW(), codusuarioa = :codusuarioa";

    $stmt = $db->prepare($query);
    $stmt->bindParam(":codusuarioa", $codusuarioa);
    bind_cobro_params($stmt, $data);

    if($stmt->execute()){
        http_response_code(201);
        echo json_encode(array("message" => "Cobro creado."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo crear el cobro.", "errorInfo" => $stmt->errorInfo()));
    }
}

function update_cobro() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del cobro."));
        return;
    }

    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;

    $query = "UPDATE cobro SET
                fecha = :fecha, importe = :importe, descripcion = :descripcion,
                codigo_paciente = :codigo_paciente, codigocliente = :codigocliente,
                fecham = NOW(), codusuariom = :codusuariom
              WHERE codigo = :codigo";

    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);
    $stmt->bindParam(":codusuariom", $codusuariom);
    bind_cobro_params($stmt, $data);

    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Cobro actualizado."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo actualizar el cobro.", "errorInfo" => $stmt->errorInfo()));
    }
}

function delete_cobro() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del cobro."));
        return;
    }

    $query = "DELETE FROM cobro WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);

    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Cobro eliminado."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo eliminar el cobro."));
    }
}

function get_total_cobros($codigo_paciente = null) {
    global $db;

    $query = "SELECT COUNT(*) as total FROM cobro";
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
        echo json_encode(array("total_cobros" => (int)$row['total']));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo obtener el total de cobros.", "errorInfo" => $stmt->errorInfo()));
    }
}
?>