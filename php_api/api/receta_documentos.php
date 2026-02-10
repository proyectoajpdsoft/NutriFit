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

$request_method = $_SERVER["REQUEST_METHOD"];

// Validar token
$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'recetas');

switch($request_method) {
    case 'GET':
        if(!empty($_GET["codigo"])) {
            get_documento($_GET["codigo"]);
        } else if(isset($_GET["receta"])) {
            get_documentos_by_receta($_GET["receta"]);
        }
        break;
    case 'POST':
        create_documento();
        break;
    case 'PUT':
        update_documento();
        break;
    case 'DELETE':
        if(!empty($_GET["codigo"])) {
            delete_documento($_GET["codigo"]);
        }
        break;
    default:
        http_response_code(405);
        echo json_encode(array("message" => "Método no permitido."));
        break;
}

function get_documentos_by_receta($receta_codigo) {
    global $db;

    $query = "SELECT codigo, codigo_receta, tipo, nombre, url, orden
              FROM nu_receta_documento
              WHERE codigo_receta = :receta
              ORDER BY orden ASC";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':receta', $receta_codigo);
    $stmt->execute();
    $documentos = $stmt->fetchAll(PDO::FETCH_ASSOC);

    ob_clean();
    echo json_encode($documentos);
}

function get_documento($codigo) {
    global $db;

    $query = "SELECT codigo, codigo_receta, tipo, nombre, 
              CASE 
                WHEN tipo = 'documento' AND documento IS NOT NULL 
                THEN documento 
                ELSE NULL 
              END as documento,
              url, orden
              FROM nu_receta_documento 
              WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $documento = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($documento) {
        if ($documento['tipo'] == 'documento' && $documento['documento'] !== null) {
            if (!mb_check_encoding($documento['documento'], 'UTF-8')) {
                $documento['documento'] = base64_encode($documento['documento']);
            }
        }
        ob_clean();
        echo json_encode($documento);
    } else {
        http_response_code(404);
        ob_clean();
        echo json_encode(array("message" => "Documento no encontrado."));
    }
}

function create_documento() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo_receta) || empty($data->tipo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Faltan datos requeridos."));
        return;
    }

    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;

    $query = "INSERT INTO nu_receta_documento SET
                codigo_receta = :codigo_receta,
                tipo = :tipo,
                nombre = :nombre,
                documento = :documento,
                url = :url,
                orden = :orden,
                fechaa = NOW(),
                codusuarioa = :codusuarioa";

    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo_receta", $data->codigo_receta);
    $stmt->bindParam(":tipo", $data->tipo);

    $nombre = isset($data->nombre) ? $data->nombre : null;
    $stmt->bindParam(":nombre", $nombre);

    $documento = null;
    $url = null;

    if ($data->tipo == 'documento' && !empty($data->documento)) {
        $documento = base64_decode($data->documento);
    } else if ($data->tipo == 'url' && !empty($data->url)) {
        $url = $data->url;
    }

    $stmt->bindParam(":documento", $documento, PDO::PARAM_LOB);
    $stmt->bindParam(":url", $url);

    $orden = isset($data->orden) ? $data->orden : 0;
    $stmt->bindParam(":orden", $orden);
    $stmt->bindParam(":codusuarioa", $codusuarioa);

    if($stmt->execute()) {
        $documento_id = $db->lastInsertId();
        http_response_code(201);
        ob_clean();
        echo json_encode(array(
            "message" => "Documento creado.",
            "codigo" => $documento_id
        ));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array(
            "message" => "No se pudo crear el documento.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function update_documento() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el código del documento."));
        return;
    }

    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;

    $query = "UPDATE nu_receta_documento SET
                tipo = :tipo,
                nombre = :nombre,
                documento = :documento,
                url = :url,
                orden = :orden,
                fecham = NOW(),
                codusuariom = :codusuariom
              WHERE codigo = :codigo";

    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);
    $stmt->bindParam(":tipo", $data->tipo);

    $nombre = isset($data->nombre) ? $data->nombre : null;
    $stmt->bindParam(":nombre", $nombre);

    $documento = null;
    $url = null;

    if ($data->tipo == 'documento' && !empty($data->documento)) {
        $documento = base64_decode($data->documento);
    } else if ($data->tipo == 'url' && !empty($data->url)) {
        $url = $data->url;
    }

    $stmt->bindParam(":documento", $documento, PDO::PARAM_LOB);
    $stmt->bindParam(":url", $url);

    $orden = isset($data->orden) ? $data->orden : 0;
    $stmt->bindParam(":orden", $orden);
    $stmt->bindParam(":codusuariom", $codusuariom);

    if($stmt->execute()){
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Documento actualizado."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array(
            "message" => "No se pudo actualizar el documento.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function delete_documento($codigo) {
    global $db;

    $query = "DELETE FROM nu_receta_documento WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);

    if($stmt->execute()){
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Documento eliminado."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo eliminar el documento."));
    }
}
?>
