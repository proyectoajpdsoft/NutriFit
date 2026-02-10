<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/auto_validator.php';
include_once '../auth/permissions.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

$request_method = $_SERVER["REQUEST_METHOD"];

// Validar token (acepta usuario o guest)
$validator = new AutoValidator($db);
$user = $validator->validate();
PermissionManager::checkPermission($user, 'consejos');

switch($request_method) {
    case 'GET':
        if(isset($_GET["consejo"])) {
            get_usuarios_by_consejo($_GET["consejo"]);
        } else if(isset($_GET["usuario"]) && isset($_GET["consejo_codigo"])) {
            get_consejo_usuario($_GET["usuario"], $_GET["consejo_codigo"]);
        } else if(isset($_GET["favoritos"]) && isset($_GET["usuario"])) {
            get_favoritos($_GET["usuario"]);
        }
        break;
    case 'POST':
        if(isset($_GET["toggle_like"])) {
            toggle_like();
        } else if(isset($_GET["toggle_favorito"])) {
            toggle_favorito();
        }
        break;
    case 'DELETE':
        if(isset($_GET["consejo"]) && isset($_GET["usuario"])) {
            remove_usuario($_GET["consejo"], $_GET["usuario"]);
        }
        break;
    default:
        http_response_code(405);
        echo json_encode(array("message" => "Método no permitido."));
        break;
}

function get_usuarios_by_consejo($consejo_codigo) {
    global $db;
    
    $query = "SELECT cu.*, u.nombre
              FROM nu_consejo_usuario cu
              INNER JOIN usuario u ON cu.codigo_usuario = u.codigo
              WHERE cu.codigo_consejo = :consejo
              ORDER BY u.nombre";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':consejo', $consejo_codigo);
    $stmt->execute();
    $usuarios = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    ob_clean();
    echo json_encode($usuarios);
}

function get_consejo_usuario($usuario_codigo, $consejo_codigo) {
    global $db;
    
    $query = "SELECT * FROM nu_consejo_usuario 
              WHERE codigo_usuario = :usuario AND codigo_consejo = :consejo";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':usuario', $usuario_codigo);
    $stmt->bindParam(':consejo', $consejo_codigo);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    ob_clean();
    if($result) {
        echo json_encode($result);
    } else {
        echo json_encode(array("me_gusta" => "N", "favorito" => "N"));
    }
}

function toggle_like() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if(empty($data->codigo_consejo) || empty($data->codigo_usuario)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Faltan codigo_consejo o codigo_usuario."));
        return;
    }
    
    // Verificar si existe el registro
    $check_query = "SELECT codigo, me_gusta FROM nu_consejo_usuario 
                    WHERE codigo_consejo = :consejo AND codigo_usuario = :usuario";
    $check_stmt = $db->prepare($check_query);
    $check_stmt->bindParam(':consejo', $data->codigo_consejo);
    $check_stmt->bindParam(':usuario', $data->codigo_usuario);
    $check_stmt->execute();
    $existing = $check_stmt->fetch(PDO::FETCH_ASSOC);
    
    if(!$existing) {
        // Si no existe, crear el registro
        $insert_query = "INSERT INTO nu_consejo_usuario SET
                        codigo_consejo = :codigo_consejo,
                        codigo_usuario = :codigo_usuario,
                        me_gusta = 'S',
                        favorito = 'N',
                        leido = 'N',
                        fecha_me_gusta = NOW(),
                        fechaa = NOW(),
                        codusuarioa = :codusuarioa";
        
        $insert_stmt = $db->prepare($insert_query);
        $insert_stmt->bindParam(':codigo_consejo', $data->codigo_consejo);
        $insert_stmt->bindParam(':codigo_usuario', $data->codigo_usuario);
        $insert_stmt->bindParam(':codusuarioa', $data->codigo_usuario);
        
        if($insert_stmt->execute()) {
            http_response_code(200);
            ob_clean();
            echo json_encode(array(
                "message" => "Like agregado.",
                "me_gusta" => 'S'
            ));
        } else {
            http_response_code(503);
            ob_clean();
            echo json_encode(array("message" => "No se pudo crear el registro para agregar like."));
        }
        return;
    }
    
    // Toggle el me_gusta
    $new_value = $existing['me_gusta'] == 'S' ? 'N' : 'S';
    $fecha_me_gusta = $new_value == 'S' ? date('Y-m-d H:i:s') : null;
    
    $update_query = "UPDATE nu_consejo_usuario SET 
                    me_gusta = :me_gusta,
                    fecha_me_gusta = " . ($fecha_me_gusta ? ":fecha_me_gusta" : "NULL") . ",
                    fecham = NOW(),
                    codusuariom = :codusuariom
                    WHERE codigo = :codigo";
    
    $update_stmt = $db->prepare($update_query);
    $update_stmt->bindParam(':me_gusta', $new_value);
    if ($fecha_me_gusta) {
        $update_stmt->bindParam(':fecha_me_gusta', $fecha_me_gusta);
    }
    $update_stmt->bindParam(':codusuariom', $data->codigo_usuario);
    $update_stmt->bindParam(':codigo', $existing['codigo']);
    
    if($update_stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(array(
            "message" => "Like actualizado.",
            "me_gusta" => $new_value
        ));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo actualizar el like."));
    }
}

function remove_usuario($consejo_codigo, $usuario_codigo) {
    global $db;
    
    $query = "DELETE FROM nu_consejo_usuario WHERE codigo_consejo = :consejo AND codigo_usuario = :usuario";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':consejo', $consejo_codigo);
    $stmt->bindParam(':usuario', $usuario_codigo);
    
    if($stmt->execute()){
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Usuario desvinculado."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo desvincular el usuario."));
    }
}

function toggle_favorito() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if(empty($data->codigo_consejo) || empty($data->codigo_usuario)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Faltan codigo_consejo o codigo_usuario."));
        return;
    }
    
    // Verificar si existe el registro
    $check_query = "SELECT codigo, favorito FROM nu_consejo_usuario 
                    WHERE codigo_consejo = :consejo AND codigo_usuario = :usuario";
    $check_stmt = $db->prepare($check_query);
    $check_stmt->bindParam(':consejo', $data->codigo_consejo);
    $check_stmt->bindParam(':usuario', $data->codigo_usuario);
    $check_stmt->execute();
    $existing = $check_stmt->fetch(PDO::FETCH_ASSOC);
    
    if(!$existing) {
        // Si no existe, crear el registro
        $insert_query = "INSERT INTO nu_consejo_usuario SET
                        codigo_consejo = :codigo_consejo,
                        codigo_usuario = :codigo_usuario,
                        me_gusta = 'N',
                        favorito = 'S',
                        leido = 'N',
                        fecha_favorito = NOW(),
                        fechaa = NOW(),
                        codusuarioa = :codusuarioa";
        
        $insert_stmt = $db->prepare($insert_query);
        $insert_stmt->bindParam(':codigo_consejo', $data->codigo_consejo);
        $insert_stmt->bindParam(':codigo_usuario', $data->codigo_usuario);
        $insert_stmt->bindParam(':codusuarioa', $data->codigo_usuario);
        
        if($insert_stmt->execute()) {
            http_response_code(200);
            ob_clean();
            echo json_encode(array(
                "message" => "Favorito agregado.",
                "favorito" => 'S'
            ));
        } else {
            http_response_code(503);
            ob_clean();
            echo json_encode(array("message" => "No se pudo crear el registro para agregar favorito."));
        }
        return;
    }
    
    // Toggle el favorito
    $new_value = ($existing['favorito'] == 'S') ? 'N' : 'S';
    $fecha_favorito = $new_value == 'S' ? date('Y-m-d H:i:s') : null;
    
    $update_query = "UPDATE nu_consejo_usuario SET 
                    favorito = :favorito,
                    fecha_favorito = " . ($fecha_favorito ? ":fecha_favorito" : "NULL") . ",
                    fecham = NOW(),
                    codusuariom = :codusuariom
                    WHERE codigo = :codigo";
    
    $update_stmt = $db->prepare($update_query);
    $update_stmt->bindParam(':favorito', $new_value);
    if ($fecha_favorito) {
        $update_stmt->bindParam(':fecha_favorito', $fecha_favorito);
    }
    $update_stmt->bindParam(':codusuariom', $data->codigo_usuario);
    $update_stmt->bindParam(':codigo', $existing['codigo']);
    
    if($update_stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(array(
            "message" => "Favorito actualizado.",
            "favorito" => $new_value
        ));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo actualizar el favorito."));
    }
}

function get_favoritos($usuario_codigo) {
    global $db;
    
    $query = "SELECT c.*, cu.me_gusta, cu.favorito,
              (SELECT COUNT(*) FROM nu_consejo_usuario WHERE codigo_consejo = c.codigo AND me_gusta = 'S') as total_likes
              FROM nu_consejo c
              INNER JOIN nu_consejo_usuario cu ON c.codigo = cu.codigo_consejo
              WHERE cu.codigo_usuario = :usuario
              AND c.activo = 'S'
              AND cu.favorito = 'S'
              AND (c.fecha_inicio IS NULL OR c.fecha_inicio <= CURDATE())
              AND (c.fecha_fin IS NULL OR c.fecha_fin >= CURDATE())
              ORDER BY cu.fecha_favorito DESC";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':usuario', $usuario_codigo);
    $stmt->execute();
    $consejos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Convertir imágenes a base64
    foreach($consejos as &$consejo) {
        if($consejo['imagen_portada']) {
            $consejo['imagen_portada'] = base64_encode($consejo['imagen_portada']);
        }
    }
    
    ob_clean();
    echo json_encode($consejos);
}
?>
