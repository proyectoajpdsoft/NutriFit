<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once '../config/database.php';
require_once '../auth/token_validator.php';
require_once '../auth/permissions.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();
$request_method = $_SERVER["REQUEST_METHOD"];

// Permitir registro público (POST con action=register) sin autenticación
// Permitir GET del propio usuario sin permisos especiales
// Permitir PUT del propio usuario sin permisos especiales
// Para otras operaciones, validar token
$requiresAuth = true;
$requiresPermission = true;

if ($request_method === 'POST') {
    $data = json_decode(file_get_contents("php://input"));
    $action = isset($data->action) ? $data->action : 'create';
    
    // Permitir registro sin autenticación
    if ($action === 'register' || $action === 'check_nick') {
        $requiresAuth = false;
        $requiresPermission = false;
    }
}

if ($request_method === 'GET' && !empty($_GET["codigo"])) {
    // Si está solicitando un usuario específico, validar token pero no permisos especiales
    // Cualquier usuario autenticado puede ver su propia información
    $requiresPermission = false;
}

if ($request_method === 'PUT') {
    // Para actualización, validar token pero verificar permisos después
    // Si está actualizando su propio perfil, no requiere permisos especiales
    $requiresPermission = false;
}

if ($requiresAuth) {
    // Validar token (solo usuarios registrados)
    $validator = new TokenValidator($db);
    $user = $validator->validateToken();
    
    // Solo verificar permisos si es necesario
    if ($requiresPermission) {
        PermissionManager::checkPermission($user, 'usuarios');
    }
    
    // Guardar el usuario validado para usar en update_usuario()
    $GLOBALS['authenticated_user'] = $user;
}

switch($request_method) {
    case 'GET':
        if (isset($_GET["total_usuarios"])) {
            get_total_usuarios();
        } elseif(!empty($_GET["codigo"])) {
            get_usuario(intval($_GET["codigo"]));
        } else {
            get_usuarios();
        }
        break;
    case 'POST':
        handle_post_request();
        break;
    case 'PUT':
        update_usuario();
        break;
    case 'DELETE':
        delete_usuario();
        break;
    default:
        header("HTTP/1.0 405 Method Not Allowed");
        break;
}

function handle_post_request() {
    $data = json_decode(file_get_contents("php://input"));
    $action = isset($data->action) ? $data->action : 'create';
    
    if ($action === 'check_nick') {
        check_nick_exists($data);
    } elseif ($action === 'register') {
        register_usuario($data);
    } else {
        create_usuario($data);
    }
}

function get_usuarios() {
    global $db;
    // Incluir img_perfil para que se muestre en el listado
    $query = "SELECT codigo, nick, nombre, email, tipo, activo, accesoweb, administrador, codigo_paciente, img_perfil
              FROM usuario ORDER BY nombre";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Convertir img_perfil de BLOB a base64
    foreach ($items as &$item) {
        if ($item['img_perfil'] !== null) {
            $item['img_perfil'] = base64_encode($item['img_perfil']);
        }
    }
    
    echo json_encode($items);
}

function get_total_usuarios() {
    global $db;
    $query = "SELECT COUNT(*) as total FROM usuario";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($row);
}

function get_usuario($codigo) {
    global $db;
    $query = "SELECT codigo, nick, nombre, email, tipo, activo, administrador, codigo_paciente, accesoweb, img_perfil
              FROM usuario WHERE codigo = :codigo LIMIT 0,1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);
    if($item) {
        // Convertir img_perfil de BLOB a base64 usando PHP
        if ($item['img_perfil'] !== null) {
            $item['img_perfil'] = base64_encode($item['img_perfil']);
        }
        echo json_encode($item);
    } else {
        http_response_code(404);
        echo json_encode(array("message" => "Usuario no encontrado."));
    }
}

function bind_usuario_params($stmt, $data) {
    $data->nick = htmlspecialchars(strip_tags($data->nick));
    $data->nombre = htmlspecialchars(strip_tags($data->nombre ?? ''));
    $data->email = htmlspecialchars(strip_tags($data->email ?? ''));
    
    // Asegurar que activo, accesoweb y administrador sean 'S' o 'N'
    // Maneja: boolean true/false, string 'S'/'N', string 'true'/'false', etc
    $convertToSN = function($value) {
        if ($value === true || $value === 'S' || $value === 'true' || $value === '1' || $value === 1) {
            return 'S';
        }
        return 'N';
    };
    
    $data->activo = $convertToSN($data->activo ?? 'S');
    $data->accesoweb = $convertToSN($data->accesoweb ?? 'S');
    $data->administrador = $convertToSN($data->administrador ?? 'N');
    
    $stmt->bindParam(":nick", $data->nick);
    $stmt->bindParam(":nombre", $data->nombre);
    $stmt->bindParam(":email", $data->email);
    $stmt->bindParam(":tipo", $data->tipo);
    $stmt->bindParam(":activo", $data->activo);
    $stmt->bindParam(":accesoweb", $data->accesoweb);
    $stmt->bindParam(":administrador", $data->administrador);

    $data->codigo_paciente = !empty($data->codigo_paciente) ? $data->codigo_paciente : null;
    $stmt->bindParam(":codigo_paciente", $data->codigo_paciente);
    
    // Manejar imagen de perfil (base64)
    $img_perfil = null;
    if (!empty($data->img_perfil)) {
        // Decodificar base64 a binario
        $img_perfil = base64_decode($data->img_perfil);
    }
    $stmt->bindParam(":img_perfil", $img_perfil, PDO::PARAM_LOB);
}

/// Verifica si un nick ya existe en la base de datos
function check_nick_exists($data) {
    global $db;
    
    if(empty($data->nick)) {
        http_response_code(400);
        echo json_encode(array("message" => "El nick es obligatorio.", "exists" => false));
        return;
    }
    
    $query = "SELECT COUNT(*) as count FROM usuario WHERE nick = :nick";
    $stmt = $db->prepare($query);
    $nick = htmlspecialchars(strip_tags($data->nick));
    $stmt->bindParam(':nick', $nick);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    http_response_code(200);
    echo json_encode(array("exists" => $result['count'] > 0));
}

/// Registra un nuevo usuario (guest registration)
function register_usuario($data) {
    global $db;

    // Validar campos obligatorios
    if(empty($data->nick)) {
        http_response_code(400);
        echo json_encode(array("success" => false, "message" => "El nick es obligatorio."));
        return;
    }
    
    if(empty($data->contrasena)) {
        http_response_code(400);
        echo json_encode(array("success" => false, "message" => "La contraseña es obligatoria."));
        return;
    }
    
    if(empty($data->tipo)) {
        http_response_code(400);
        echo json_encode(array("success" => false, "message" => "El tipo de usuario es obligatorio."));
        return;
    }
    
    // Verificar si el nick ya existe
    $check_query = "SELECT COUNT(*) as count FROM usuario WHERE nick = :nick";
    $check_stmt = $db->prepare($check_query);
    $nick = htmlspecialchars(strip_tags($data->nick));
    $check_stmt->bindParam(':nick', $nick);
    $check_stmt->execute();
    $check_result = $check_stmt->fetch(PDO::FETCH_ASSOC);
    
    if($check_result['count'] > 0) {
        http_response_code(400);
        echo json_encode(array("success" => false, "message" => "El nick ya existe."));
        return;
    }
    
    // Hashear la contraseña
    $contrasena_hash = password_hash($data->contrasena, PASSWORD_BCRYPT);
    $tipo = htmlspecialchars(strip_tags($data->tipo));
    $nombre = htmlspecialchars(strip_tags($data->nombre ?? ''));
    $codigo_paciente = null;
    
    // Insertar usuario
    $insert_query = "INSERT INTO usuario SET
                nick = :nick,
                nombre = :nombre,
                email = '',
                contrasena = :contrasena,
                tipo = :tipo,
                activo = 'S',
                accesoweb = 'S',
                administrador = 'N',
                codigo_paciente = :codigo_paciente,
                img_perfil = NULL,
                fechaa = NOW(),
                codusuarioa = 1";
    
    $insert_stmt = $db->prepare($insert_query);
    $insert_stmt->bindParam(':nick', $nick);
    $insert_stmt->bindParam(':contrasena', $contrasena_hash);
    $insert_stmt->bindParam(':tipo', $tipo);
    $insert_stmt->bindParam(':nombre', $nombre);
    $insert_stmt->bindParam(':codigo_paciente', $codigo_paciente);
    
    if($insert_stmt->execute()) {
        http_response_code(201);
        echo json_encode(array(
            "success" => true,
            "message" => "Usuario registrado correctamente."
        ));
    } else {
        http_response_code(503);
        echo json_encode(array(
            "success" => false,
            "message" => "No se pudo registrar el usuario.",
            "errorInfo" => $insert_stmt->errorInfo()
        ));
    }
}

function create_usuario($data = null) {
    global $db;
    if ($data === null) {
        $data = json_decode(file_get_contents("php://input"));
    }

    if(empty($data->contrasena)) {
        http_response_code(400);
        echo json_encode(array("message" => "La contraseña es obligatoria."));
        return;
    }
    
    // ¡¡¡IMPORTANTE: Hashear la contraseña!!!
    $contrasena_hash = password_hash($data->contrasena, PASSWORD_BCRYPT);
    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;
    
    $data->codigo_paciente = null;
    $query = "INSERT INTO usuario SET
                nick = :nick, nombre = :nombre, email = :email, contrasena = :contrasena,
                tipo = :tipo, activo = :activo, accesoweb = :accesoweb, administrador = :administrador,
                codigo_paciente = :codigo_paciente, img_perfil = :img_perfil, fechaa = NOW(), codusuarioa = :codusuarioa";
    
    $stmt = $db->prepare($query);
    bind_usuario_params($stmt, $data);
    $stmt->bindParam(":contrasena", $contrasena_hash);
    $stmt->bindParam(":codusuarioa", $codusuarioa);
    
    if($stmt->execute()){
        http_response_code(201);
        echo json_encode(array("message" => "Usuario creado."));
    } else {
        http_response_code(503);
        echo json_encode(array(
            "message" => "No se pudo crear el usuario.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function update_usuario() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del usuario."));
        return;
    }
    
    // Verificar si el usuario está actualizando su propio perfil o el de otro
    $authenticated_user = $GLOBALS['authenticated_user'] ?? null;
    $is_updating_own_profile = false;
    
    if ($authenticated_user) {
        // Comparar el código del usuario autenticado con el código que se está actualizando
        $user_codigo = intval($authenticated_user['codigo'] ?? 0);
        $target_codigo = intval($data->codigo);
        
        if ($user_codigo === $target_codigo) {
            $is_updating_own_profile = true;
        } else {
            // Si está intentando actualizar otro usuario, verificar permisos de administrador
            try {
                PermissionManager::checkPermission($authenticated_user, 'usuarios');
            } catch (Exception $e) {
                http_response_code(403);
                echo json_encode(array(
                    "error" => "No tienes permiso para actualizar otros usuarios",
                    "code" => "PERMISSION_DENIED"
                ));
                return;
            }
        }
    }
    
    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;
    if ($is_updating_own_profile) {
        $data->codigo_paciente = $authenticated_user['codigo_paciente'] ?? null;
    }
    
    $sql_pass = "";
    // Si se envía una contraseña, se actualiza. Si no, se deja la que estaba.
    if(!empty($data->contrasena)) {
        $contrasena_hash = password_hash($data->contrasena, PASSWORD_BCRYPT);
        $sql_pass = ", contrasena = :contrasena";
    }

    $query = "UPDATE usuario SET
                nick = :nick, nombre = :nombre, email = :email,
                tipo = :tipo, activo = :activo, accesoweb = :accesoweb, administrador = :administrador,
                codigo_paciente = :codigo_paciente, img_perfil = :img_perfil, fecham = NOW(), codusuariom = :codusuariom
                $sql_pass
              WHERE codigo = :codigo";

    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);
    $stmt->bindParam(":codusuariom", $codusuariom);
    bind_usuario_params($stmt, $data);

    if(!empty($sql_pass)) {
        $stmt->bindParam(":contrasena", $contrasena_hash);
    }

    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Usuario actualizado."));
    } else {
        http_response_code(503);
        echo json_encode(array(
            "message" => "No se pudo actualizar el usuario.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function delete_usuario() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del usuario."));
        return;
    }

    // Opcional: No permitir borrar el usuario 'admin' (código 1, por ejemplo)
    if (intval($data->codigo) == 1) {
        http_response_code(403);
        echo json_encode(array("message" => "No se puede eliminar al usuario administrador principal."));
        return;
    }

    $query = "DELETE FROM usuario WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    
    $codigo = intval($data->codigo);
    $stmt->bindParam(":codigo", $codigo);

    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Usuario eliminado."));
    } else {
        http_response_code(503);
        echo json_encode(array(
            "message" => "No se pudo eliminar el usuario.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}
?>