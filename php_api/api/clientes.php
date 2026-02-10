<?php
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
PermissionManager::checkPermission($user, 'clientes');

switch($request_method) {
    case 'GET':
        if(!empty($_GET["codigo"])) {
            get_cliente(intval($_GET["codigo"]));
        } else {
            get_clientes();
        }
        break;
    case 'POST':
        create_cliente();
        break;
    case 'PUT':
        update_cliente();
        break;
    case 'DELETE':
        delete_cliente();
        break;
    default:
        header("HTTP/1.0 405 Method Not Allowed");
        break;
}

function get_clientes() {
    global $db;
    $query = "SELECT * FROM tercero WHERE activo = 'S' ORDER BY nombre";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode($items);
}

function get_cliente($codigo) {
    global $db;
    $query = "SELECT * FROM tercero WHERE codigo = :codigo LIMIT 0,1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);
    if($item) {
        echo json_encode($item);
    } else {
        http_response_code(404);
        echo json_encode(array("message" => "Cliente no encontrado."));
    }
}

function bind_cliente_params($stmt, $data) {
    // Sanitizar datos
    $data->nombre = htmlspecialchars(strip_tags($data->nombre));
    $data->cif = htmlspecialchars(strip_tags($data->cif));
    $data->direccion = htmlspecialchars(strip_tags($data->direccion));
    $data->telefono = htmlspecialchars(strip_tags($data->telefono));
    $data->poblacion = htmlspecialchars(strip_tags($data->poblacion));
    $data->provincia = htmlspecialchars(strip_tags($data->provincia));
    $data->cp = htmlspecialchars(strip_tags($data->cp));
    $data->personacontacto = htmlspecialchars(strip_tags($data->personacontacto));
    $data->web = htmlspecialchars(strip_tags($data->web));
    $data->email = htmlspecialchars(strip_tags($data->email));
    $data->observacion = htmlspecialchars(strip_tags($data->observacion));
    $data->activo = htmlspecialchars(strip_tags($data->activo));

    $stmt->bindParam(":nombre", $data->nombre);
    $stmt->bindParam(":cif", $data->cif);
    $stmt->bindParam(":direccion", $data->direccion);
    $stmt->bindParam(":telefono", $data->telefono);
    $stmt->bindParam(":poblacion", $data->poblacion);
    $stmt->bindParam(":provincia", $data->provincia);
    $stmt->bindParam(":cp", $data->cp);
    $stmt->bindParam(":personacontacto", $data->personacontacto);
    $stmt->bindParam(":web", $data->web);
    $stmt->bindParam(":email", $data->email);
    $stmt->bindParam(":observacion", $data->observacion);
    $stmt->bindParam(":activo", $data->activo);
}

function create_cliente() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;
    
    $query = "INSERT INTO tercero SET
                nombre = :nombre, cif = :cif, direccion = :direccion, telefono = :telefono,
                poblacion = :poblacion, provincia = :provincia, cp = :cp,
                personacontacto = :personacontacto, web = :web, email = :email,
                observacion = :observacion, activo = :activo,
                fechaalta = NOW(), fechaa = NOW(), codusuarioa = :codusuarioa";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codusuarioa", $codusuarioa);
    bind_cliente_params($stmt, $data);
    
    if($stmt->execute()){
        http_response_code(201);
        echo json_encode(array("message" => "Cliente creado."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo crear el cliente."));
    }
}

function update_cliente() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del cliente."));
        return;
    }
    
    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;
    
    $query = "UPDATE tercero SET
                nombre = :nombre, cif = :cif, direccion = :direccion, telefono = :telefono,
                poblacion = :poblacion, provincia = :provincia, cp = :cp,
                personacontacto = :personacontacto, web = :web, email = :email,
                observacion = :observacion, activo = :activo,
                fecham = NOW(), codusuariom = :codusuariom
              WHERE codigo = :codigo";

    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);
    $stmt->bindParam(":codusuariom", $codusuariom);
    bind_cliente_params($stmt, $data);

    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Cliente actualizado."));
    } else{
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo actualizar el cliente."));
    }
}

function delete_cliente() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del cliente."));
        return;
    }

    // Usamos borrado lógico para no perder el histórico en los cobros
    $query = "UPDATE tercero SET activo = 'N' WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);

    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Cliente desactivado (borrado lógico)."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo desactivar el cliente."));
    }
}
?>