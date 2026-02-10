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

// Solo validar token para operaciones de escritura (POST, PUT, DELETE)
// GET es público para que los invitados puedan ver información de contacto
if ($request_method !== 'GET') {
    $validator = new TokenValidator($db);
    $user = $validator->validateToken();
    PermissionManager::checkPermission($user, 'parametros');
}

switch($request_method) {
    case 'GET':
        if(!empty($_GET["valor"]) && !empty($_GET["nombre"])) {
            // GET con parámetro ?nombre=X&valor=1 retorna solo el valor
            get_parametro_valor($_GET["nombre"]);
        } else if(!empty($_GET["nombre"])) {
            // GET con parámetro ?nombre=X retorna todo el parámetro
            get_parametro_by_nombre($_GET["nombre"]);
        } else if(!empty($_GET["categoria"])) {
            // GET con parámetro ?categoria=X retorna todos los parámetros de esa categoría
            get_parametros_by_categoria($_GET["categoria"]);
        } else {
            // GET sin parámetros retorna todos
            get_parametros();
        }
        break;
    case 'POST':
        create_parametro();
        break;
    case 'PUT':
        if(!empty($_GET["method"]) && $_GET["method"] === "updateValor") {
            update_parametro_valor();
        } else {
            update_parametro();
        }
        break;
    case 'DELETE':
        delete_parametro();
        break;
    default:
        header("HTTP/1.0 405 Method Not Allowed");
        break;
}

// Obtener todos los parámetros
function get_parametros() {
    global $db;
    $query = "SELECT codigo, nombre, valor, valor2, descripcion, categoria, tipo
              FROM parametro ORDER BY categoria, nombre";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode($items);
}

// Obtener un parámetro por nombre
function get_parametro_by_nombre($nombre) {
    global $db;
    $query = "SELECT codigo, nombre, valor, valor2, descripcion, categoria, tipo
              FROM parametro WHERE nombre = :nombre LIMIT 1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if($item) {
        echo json_encode($item);
    } else {
        http_response_code(404);
        echo json_encode(array("message" => "Parámetro no encontrado."));
    }
}

// Obtener solo el valor de un parámetro por nombre (método rápido)
function get_parametro_valor($nombre) {
    global $db;
    $query = "SELECT valor FROM parametro WHERE nombre = :nombre LIMIT 1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if($item) {
        echo json_encode(array("valor" => $item['valor']));
    } else {
        http_response_code(404);
        echo json_encode(array("message" => "Parámetro no encontrado."));
    }
}

// Obtener parámetros por categoría
function get_parametros_by_categoria($categoria) {
    global $db;
    $query = "SELECT codigo, nombre, valor, valor2, descripcion, categoria, tipo
              FROM parametro WHERE categoria = :categoria ORDER BY nombre";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':categoria', $categoria);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode($items);
}

// Crear un parámetro
function create_parametro() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->nombre)) {
        http_response_code(400);
        echo json_encode(array("message" => "El nombre del parámetro es obligatorio."));
        return;
    }

    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;

    $query = "INSERT INTO parametro SET
                nombre = :nombre,
                valor = :valor,
                valor2 = :valor2,
                descripcion = :descripcion,
                categoria = :categoria,
                tipo = :tipo,
                codusuarioa = :codusuarioa,
                fechaa = NOW()";

    $stmt = $db->prepare($query);
    
    $nombre = $data->nombre;
    $valor = $data->valor ?? null;
    $valor2 = $data->valor2 ?? null;
    $descripcion = $data->descripcion ?? null;
    $categoria = $data->categoria ?? null;
    $tipo = $data->tipo ?? null;

    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':valor', $valor);
    $stmt->bindParam(':valor2', $valor2);
    $stmt->bindParam(':descripcion', $descripcion);
    $stmt->bindParam(':categoria', $categoria);
    $stmt->bindParam(':tipo', $tipo);
    $stmt->bindParam(':codusuarioa', $codusuarioa);

    if($stmt->execute()){
        http_response_code(201);
        echo json_encode(array("message" => "Parámetro creado.", "codigo" => $db->lastInsertId()));
    } else {
        http_response_code(503);
        echo json_encode(array(
            "message" => "No se pudo crear el parámetro.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

// Actualizar un parámetro por nombre
function update_parametro() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->nombre)) {
        http_response_code(400);
        echo json_encode(array("message" => "El nombre del parámetro es obligatorio."));
        return;
    }

    // Verificar si el parámetro ya existe
    $checkQuery = "SELECT codigo FROM parametro WHERE nombre = :nombre LIMIT 1";
    $checkStmt = $db->prepare($checkQuery);
    $checkStmt->bindParam(':nombre', $data->nombre);
    $checkStmt->execute();
    $exists = $checkStmt->fetch(PDO::FETCH_ASSOC);

    if($exists) {
        // El parámetro existe, actualizar SOLO valor, fecham y codusuariom
        $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;
        
        $query = "UPDATE parametro SET
                    valor = :valor,
                    codusuariom = :codusuariom,
                    fecham = NOW()
                  WHERE nombre = :nombre";

        $stmt = $db->prepare($query);

        $nombre = $data->nombre;
        $valor = $data->valor ?? null;

        $stmt->bindParam(':nombre', $nombre);
        $stmt->bindParam(':valor', $valor);
        $stmt->bindParam(':codusuariom', $codusuariom);

        if($stmt->execute()){
            http_response_code(200);
            echo json_encode(array("message" => "Parámetro actualizado."));
        } else {
            http_response_code(503);
            echo json_encode(array(
                "message" => "No se pudo actualizar el parámetro.",
                "errorInfo" => $stmt->errorInfo()
            ));
        }
    } else {
        // El parámetro NO existe, crear uno nuevo CON descripción, categoria y tipo
        $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;
        
        $query = "INSERT INTO parametro SET
                    nombre = :nombre,
                    valor = :valor,
                    valor2 = :valor2,
                    descripcion = :descripcion,
                    categoria = :categoria,
                    tipo = :tipo,
                    codusuarioa = :codusuarioa,
                    fechaa = NOW()";

        $stmt = $db->prepare($query);
        
        $nombre = $data->nombre;
        $valor = $data->valor ?? null;
        $valor2 = $data->valor2 ?? null;
        $descripcion = $data->descripcion ?? null;
        $categoria = $data->categoria ?? null;
        $tipo = $data->tipo ?? null;

        $stmt->bindParam(':nombre', $nombre);
        $stmt->bindParam(':valor', $valor);
        $stmt->bindParam(':valor2', $valor2);
        $stmt->bindParam(':descripcion', $descripcion);
        $stmt->bindParam(':categoria', $categoria);
        $stmt->bindParam(':tipo', $tipo);
        $stmt->bindParam(':codusuarioa', $codusuarioa);

        if($stmt->execute()){
            http_response_code(201);
            echo json_encode(array("message" => "Parámetro creado.", "codigo" => $db->lastInsertId()));
        } else {
            http_response_code(503);
            echo json_encode(array(
                "message" => "No se pudo crear el parámetro.",
                "errorInfo" => $stmt->errorInfo()
            ));
        }
    }
}

// Actualizar SOLO el valor de un parámetro (método rápido)
function update_parametro_valor() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->nombre) || !isset($data->valor)) {
        http_response_code(400);
        echo json_encode(array("message" => "El nombre y el valor del parámetro son obligatorios."));
        return;
    }

    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;

    $query = "UPDATE parametro SET
                valor = :valor,
                codusuariom = :codusuariom,
                fecham = NOW()
              WHERE nombre = :nombre";

    $stmt = $db->prepare($query);
    
    $nombre = $data->nombre;
    $valor = $data->valor;

    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':valor', $valor);
    $stmt->bindParam(':codusuariom', $codusuariom);

    if($stmt->execute()){
        if($stmt->rowCount() > 0) {
            http_response_code(200);
            echo json_encode(array("message" => "Valor del parámetro actualizado."));
        } else {
            http_response_code(404);
            echo json_encode(array("message" => "Parámetro no encontrado."));
        }
    } else {
        http_response_code(503);
        echo json_encode(array(
            "message" => "No se pudo actualizar el valor del parámetro.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

// Eliminar un parámetro
function delete_parametro() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del parámetro."));
        return;
    }

    $query = "DELETE FROM parametro WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    
    $codigo = intval($data->codigo);
    $stmt->bindParam(':codigo', $codigo);

    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Parámetro eliminado."));
    } else {
        http_response_code(503);
        echo json_encode(array(
            "message" => "No se pudo eliminar el parámetro.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}
?>
