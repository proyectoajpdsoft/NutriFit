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
            get_pacientes_by_consejo($_GET["consejo"]);
        } else if(isset($_GET["paciente"]) && isset($_GET["consejo_codigo"])) {
            get_consejo_paciente($_GET["paciente"], $_GET["consejo_codigo"]);
        } else if(isset($_GET["destacados_no_leidos"]) && isset($_GET["paciente"])) {
            get_destacados_no_leidos($_GET["paciente"]);
        } else if(isset($_GET["favoritos"]) && isset($_GET["paciente"])) {
            get_favoritos($_GET["paciente"]);
        }
        break;
    case 'POST':
        if(isset($_GET["toggle_like"])) {
            toggle_like();
        } else if(isset($_GET["marcar_leido"])) {
            marcar_leido();
        } else if(isset($_GET["toggle_favorito"])) {
            toggle_favorito();
        } else {
            assign_pacientes();
        }
        break;
    case 'DELETE':
        if(isset($_GET["consejo"]) && isset($_GET["paciente"])) {
            remove_paciente($_GET["consejo"], $_GET["paciente"]);
        }
        break;
    default:
        http_response_code(405);
        echo json_encode(array("message" => "Método no permitido."));
        break;
}

function get_pacientes_by_consejo($consejo_codigo) {
    global $db;
    
    $query = "SELECT cp.*, p.nombre
              FROM nu_consejo_usuario cp
              INNER JOIN nu_paciente p ON cp.codigo_paciente = p.codigo
              WHERE cp.codigo_consejo = :consejo
              ORDER BY p.nombre";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':consejo', $consejo_codigo);
    $stmt->execute();
    $pacientes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    ob_clean();
    echo json_encode($pacientes);
}

function get_consejo_paciente($paciente_codigo, $consejo_codigo) {
    global $db;
    
    $query = "SELECT * FROM nu_consejo_usuario 
              WHERE codigo_paciente = :paciente AND codigo_consejo = :consejo";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':paciente', $paciente_codigo);
    $stmt->bindParam(':consejo', $consejo_codigo);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    ob_clean();
    if($result) {
        echo json_encode($result);
    } else {
        echo json_encode(array("me_gusta" => "N"));
    }
}

function assign_pacientes() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    // Log para debug
    error_log("assign_pacientes - Datos recibidos: " . json_encode($data));
    
    if(empty($data->codigo_consejo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta codigo_consejo."));
        return;
    }
    
    if(!isset($data->codigos_pacientes) || !is_array($data->codigos_pacientes) || count($data->codigos_pacientes) == 0) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta codigos_pacientes o está vacío."));
        return;
    }
    
    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;
    $success_count = 0;
    $error_count = 0;
    
    // Primero eliminar asignaciones previas
    $delete_query = "DELETE FROM nu_consejo_usuario WHERE codigo_consejo = :consejo";
    $delete_stmt = $db->prepare($delete_query);
    $delete_stmt->bindParam(':consejo', $data->codigo_consejo);
    $delete_stmt->execute();
    
    error_log("Eliminadas asignaciones previas del consejo " . $data->codigo_consejo);
    
    // Insertar nuevas asignaciones
    $query = "INSERT INTO nu_consejo_usuario SET
                codigo_consejo = :codigo_consejo,
                codigo_paciente = :codigo_paciente,
                me_gusta = 'N',
                leido = 'N',
                fechaa = NOW(),
                codusuarioa = :codusuarioa";
    
    $stmt = $db->prepare($query);
    
    foreach($data->codigos_pacientes as $codigo_paciente) {
        error_log("Insertando paciente $codigo_paciente al consejo " . $data->codigo_consejo);
        $stmt->bindParam(":codigo_consejo", $data->codigo_consejo);
        $stmt->bindParam(":codigo_paciente", $codigo_paciente);
        $stmt->bindParam(":codusuarioa", $codusuarioa);
        
        if($stmt->execute()) {
            $success_count++;
            error_log("Éxito al insertar paciente $codigo_paciente");
        } else {
            $error_count++;
            error_log("Error al insertar paciente $codigo_paciente: " . json_encode($stmt->errorInfo()));
        }
    }
    
    http_response_code(200);
    ob_clean();
    echo json_encode(array(
        "message" => "Pacientes asignados.",
        "success" => $success_count,
        "errors" => $error_count
    ));
}

function toggle_like() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if(empty($data->codigo_consejo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta codigo_consejo."));
        return;
    }
    
    // codigo_paciente puede ser null para usuarios sin paciente
    $codigo_paciente = $data->codigo_paciente ?? null;
    
    // Verificar si existe el registro
    $check_query = "SELECT codigo, me_gusta FROM nu_consejo_usuario 
                    WHERE codigo_consejo = :consejo AND codigo_paciente <=> :paciente";
    $check_stmt = $db->prepare($check_query);
    $check_stmt->bindParam(':consejo', $data->codigo_consejo);
    $check_stmt->bindParam(':paciente', $codigo_paciente);
    $check_stmt->execute();
    $existing = $check_stmt->fetch(PDO::FETCH_ASSOC);
    
    if(!$existing) {
        // Si no existe, crear el registro
        $insert_query = "INSERT INTO nu_consejo_usuario SET
                        codigo_consejo = :codigo_consejo,
                        codigo_paciente = :codigo_paciente,
                        me_gusta = 'S',
                        favorito = 'N',
                        leido = 'N',
                        fecha_me_gusta = NOW(),
                        fechaa = NOW(),
                        codusuarioa = 1";
        
        $insert_stmt = $db->prepare($insert_query);
        $insert_stmt->bindParam(':codigo_consejo', $data->codigo_consejo);
        $insert_stmt->bindParam(':codigo_paciente', $codigo_paciente);
        
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
                    fecham = NOW()
                    WHERE codigo = :codigo";
    
    $update_stmt = $db->prepare($update_query);
    $update_stmt->bindParam(':me_gusta', $new_value);
    if ($fecha_me_gusta) {
        $update_stmt->bindParam(':fecha_me_gusta', $fecha_me_gusta);
    }
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

function remove_paciente($consejo_codigo, $paciente_codigo) {
    global $db;
    
    $query = "DELETE FROM nu_consejo_usuario WHERE codigo_consejo = :consejo AND codigo_paciente = :paciente";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':consejo', $consejo_codigo);
    $stmt->bindParam(':paciente', $paciente_codigo);
    
    if($stmt->execute()){
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Paciente desasignado."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo desasignar el paciente."));
    }
}

function marcar_leido() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if(empty($data->codigo_consejo) || empty($data->codigo_paciente)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Faltan datos requeridos."));
        return;
    }
    
    // Verificar si existe el registro
    $check_query = "SELECT codigo, leido FROM nu_consejo_usuario 
                    WHERE codigo_consejo = :consejo AND codigo_paciente = :paciente";
    $check_stmt = $db->prepare($check_query);
    $check_stmt->bindParam(':consejo', $data->codigo_consejo);
    $check_stmt->bindParam(':paciente', $data->codigo_paciente);
    $check_stmt->execute();
    $existing = $check_stmt->fetch(PDO::FETCH_ASSOC);
    
    if($existing) {
        // Marcar como leído
        $update_query = "UPDATE nu_consejo_usuario SET 
                        leido = 'S',
                        fecham = NOW()
                        WHERE codigo = :codigo";
        
        $update_stmt = $db->prepare($update_query);
        $update_stmt->bindParam(':codigo', $existing['codigo']);
        
        if($update_stmt->execute()) {
            http_response_code(200);
            ob_clean();
            echo json_encode(array(
                "message" => "Consejo marcado como leído.",
                "leido" => "S"
            ));
        } else {
            http_response_code(503);
            ob_clean();
            echo json_encode(array("message" => "No se pudo marcar como leído."));
        }
    } else {
        http_response_code(404);
        ob_clean();
        echo json_encode(array("message" => "El consejo no está asignado a este paciente."));
    }
}

function get_destacados_no_leidos($paciente_codigo) {
    global $db;
    
    try {
        if (!table_exists($db, 'nu_consejo')) {
            ob_clean();
            echo json_encode([]);
            return;
        }
        
        $has_consejo_paciente = table_exists($db, 'nu_consejo_usuario');
    
        // Si paciente_codigo es 0 o está vacío, mostrar solo consejos visible_para_todos
        if($paciente_codigo == '0' || empty($paciente_codigo)) {
            $likes_select = $has_consejo_paciente
                ? "(SELECT COUNT(*) FROM nu_consejo_usuario WHERE codigo_consejo = c.codigo AND me_gusta = 'S')"
                : "0";
            
            $query = "SELECT c.*, 'N' as me_gusta, 'N' as leido,
                      $likes_select as totalLikes
                      FROM nu_consejo c
                      WHERE c.activo = 'S'
                      AND c.mostrar_portada = 'S'
                      AND c.visible_para_todos = 'S'
                      AND (c.fecha_inicio IS NULL OR c.fecha_inicio <= CURDATE())
                      AND (c.fecha_fin IS NULL OR c.fecha_fin >= CURDATE())
                      ORDER BY c.fechaa DESC";
            
            $stmt = $db->prepare($query);
            $stmt->execute();
        } else {
            // Para pacientes con código asignado, buscar en nu_consejo_usuario
            if (!$has_consejo_paciente) {
                ob_clean();
                echo json_encode([]);
                return;
            }
            
            $query = "SELECT c.*, cp.me_gusta, cp.leido,
                      (SELECT COUNT(*) FROM nu_consejo_usuario WHERE codigo_consejo = c.codigo AND me_gusta = 'S') as totalLikes
                      FROM nu_consejo c
                      INNER JOIN nu_consejo_usuario cp ON c.codigo = cp.codigo_consejo
                      WHERE cp.codigo_paciente = :paciente
                      AND c.activo = 'S'
                      AND c.mostrar_portada = 'S'
                      AND cp.leido = 'N'
                      AND (c.fecha_inicio IS NULL OR c.fecha_inicio <= CURDATE())
                      AND (c.fecha_fin IS NULL OR c.fecha_fin >= CURDATE())
                      ORDER BY c.fechaa DESC";
            
            $stmt = $db->prepare($query);
            $stmt->bindParam(':paciente', $paciente_codigo);
            $stmt->execute();
        }
        
        $consejos = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Convertir imágenes a base64
        foreach($consejos as &$consejo) {
            if($consejo['imagen_portada']) {
                $consejo['imagen_portada'] = base64_encode($consejo['imagen_portada']);
            }
        }
        
        ob_clean();
        echo json_encode($consejos);
    } catch (PDOException $e) {
        ob_clean();
        echo json_encode([]);
    }
}

function toggle_favorito() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if(empty($data->codigo_consejo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta codigo_consejo."));
        return;
    }
    
    // codigo_paciente puede ser null para usuarios sin paciente
    $codigo_paciente = $data->codigo_paciente ?? null;
    
    // Verificar si existe el registro
    $check_query = "SELECT codigo, favorito FROM nu_consejo_usuario 
                    WHERE codigo_consejo = :consejo AND codigo_paciente <=> :paciente";
    $check_stmt = $db->prepare($check_query);
    $check_stmt->bindParam(':consejo', $data->codigo_consejo);
    $check_stmt->bindParam(':paciente', $codigo_paciente);
    $check_stmt->execute();
    $existing = $check_stmt->fetch(PDO::FETCH_ASSOC);
    
    if(!$existing) {
        // Si no existe, crear el registro
        $insert_query = "INSERT INTO nu_consejo_usuario SET
                        codigo_consejo = :codigo_consejo,
                        codigo_paciente = :codigo_paciente,
                        me_gusta = 'N',
                        favorito = 'S',
                        leido = 'N',
                        fecha_favorito = NOW(),
                        fechaa = NOW(),
                        codusuarioa = 1";
        
        $insert_stmt = $db->prepare($insert_query);
        $insert_stmt->bindParam(':codigo_consejo', $data->codigo_consejo);
        $insert_stmt->bindParam(':codigo_paciente', $codigo_paciente);
        
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
                    fecham = NOW()
                    WHERE codigo = :codigo";
    
    $update_stmt = $db->prepare($update_query);
    $update_stmt->bindParam(':favorito', $new_value);
    if ($fecha_favorito) {
        $update_stmt->bindParam(':fecha_favorito', $fecha_favorito);
    }
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

function get_favoritos($paciente_codigo) {
    global $db;
    
    try {
        // Si paciente_codigo es 0, retornar array vacío (usuarios sin paciente no pueden tener favoritos)
        if($paciente_codigo == '0' || empty($paciente_codigo)) {
            ob_clean();
            echo json_encode([]);
            return;
        }
        
        if (!table_exists($db, 'nu_consejo') || !table_exists($db, 'nu_consejo_usuario')) {
            ob_clean();
            echo json_encode([]);
            return;
        }
        
        // Si paciente_codigo es NULL o 'null', usar operador NULL-safe
        $query = "SELECT c.*, cp.me_gusta, cp.leido, cp.favorito,
              (SELECT COUNT(*) FROM nu_consejo_usuario WHERE codigo_consejo = c.codigo AND me_gusta = 'S') as total_likes
              FROM nu_consejo c
              INNER JOIN nu_consejo_usuario cp ON c.codigo = cp.codigo_consejo
                  WHERE cp.codigo_paciente <=> :paciente
                  AND c.activo = 'S'
                  AND cp.favorito = 'S'
                  AND (c.fecha_inicio IS NULL OR c.fecha_inicio <= CURDATE())
                  AND (c.fecha_fin IS NULL OR c.fecha_fin >= CURDATE())
                  ORDER BY cp.fecha_favorito DESC";
        
        $stmt = $db->prepare($query);
        // Convertir 'null' string a null real
        $paciente_real = ($paciente_codigo === 'null' || $paciente_codigo === null) ? null : $paciente_codigo;
        $stmt->bindParam(':paciente', $paciente_real);
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
    } catch (PDOException $e) {
        ob_clean();
        echo json_encode([]);
    }
}

function table_exists($db, $table_name) {
    $query = "SHOW TABLES LIKE :table";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':table', $table_name);
    $stmt->execute();
    return $stmt->rowCount() > 0;
}
?>
