<?php
ob_start(); // Start output buffering as the very first thing

// Headers for CORS
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Include database connection
include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/permissions.php';

// Handle OPTIONS request for CORS preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

// ⭐ VALIDAR TOKEN (solo usuarios registrados)
$validator = new TokenValidator($db);
$user = $validator->validateToken();

// ⭐ VALIDAR PERMISOS - Solo nutricionistas pueden listar pacientes
PermissionManager::checkPermission($user, 'pacientes');

$request_method = $_SERVER["REQUEST_METHOD"];

try {
    switch ($request_method) {
        case 'GET':
            if (isset($_GET["total_pacientes"])) {
                get_total_pacientes();
            } elseif (!empty($_GET["codigo"])) {
                get_paciente(intval($_GET["codigo"]));
            } else {
                $activo = isset($_GET['activo']) ? $_GET['activo'] : null;
                get_pacientes($activo);
            }
            break;
        case 'POST':
            handle_post_request();
            break;
        case 'PUT':
            update_paciente();
            break;
        case 'DELETE':
            delete_paciente();
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

function get_pacientes($activo = null) {
    global $db;
    $query = "SELECT * FROM nu_paciente";
    $params = [];

    if ($activo === 'S') {
        $query .= " WHERE activo = :activo";
        $params[':activo'] = $activo;
    }
    
    $query .= " ORDER BY nombre";
    $stmt = $db->prepare($query);

    foreach ($params as $key => &$val) {
        $stmt->bindParam($key, $val);
    }

    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items);
}

function bind_paciente_params($stmt, &$data) {
    // Sanitizar todos los campos de texto del objeto $data
    foreach ($data as $key => $value) {
        if (is_string($value)) {
            $data->$key = htmlspecialchars(strip_tags($value));
        }
    }

    $stmt->bindParam(":nombre", $data->nombre);

    // Campos que pueden ser NULL
    $stmt->bindValue(":dni", isset($data->dni) && $data->dni !== '' ? $data->dni : null, PDO::PARAM_STR);
    $stmt->bindValue(":fecha_nacimiento", isset($data->fecha_nacimiento) && $data->fecha_nacimiento !== '' ? $data->fecha_nacimiento : null, PDO::PARAM_STR);
    $stmt->bindValue(":sexo", isset($data->sexo) && $data->sexo !== '' ? $data->sexo : null, PDO::PARAM_STR);
    $stmt->bindValue(":altura", isset($data->altura) && $data->altura !== '' ? $data->altura : null, PDO::PARAM_INT);
    $stmt->bindValue(":observacion", isset($data->observacion) && $data->observacion !== '' ? $data->observacion : null, PDO::PARAM_STR);
    $stmt->bindValue(":calle", isset($data->calle) && $data->calle !== '' ? $data->calle : null, PDO::PARAM_STR);
    $stmt->bindValue(":codigo_postal", isset($data->codigo_postal) && $data->codigo_postal !== '' ? $data->codigo_postal : null, PDO::PARAM_STR);
    $stmt->bindValue(":provincia", isset($data->provincia) && $data->provincia !== '' ? $data->provincia : null, PDO::PARAM_STR);
    $stmt->bindValue(":pais", isset($data->pais) && $data->pais !== '' ? $data->pais : null, PDO::PARAM_STR);
    $stmt->bindValue(":online", isset($data->online) && $data->online !== '' ? $data->online : null, PDO::PARAM_STR);
    $stmt->bindValue(":telefono", isset($data->telefono) && $data->telefono !== '' ? $data->telefono : null, PDO::PARAM_STR);
    $stmt->bindValue(":email1", isset($data->email1) && $data->email1 !== '' ? $data->email1 : null, PDO::PARAM_STR);
    $stmt->bindValue(":email2", isset($data->email2) && $data->email2 !== '' ? $data->email2 : null, PDO::PARAM_STR);
    $stmt->bindValue(":peso", isset($data->peso) && $data->peso !== '' ? $data->peso : null, PDO::PARAM_STR); // Usar STR para DECIMAL/FLOAT
    $stmt->bindValue(":edad", isset($data->edad) && $data->edad !== '' ? $data->edad : null, PDO::PARAM_INT);
    $stmt->bindValue(":activo", isset($data->activo) && $data->activo !== '' ? $data->activo : 'N', PDO::PARAM_STR); // Nuevo campo activo
}

function get_total_pacientes() {
    global $db;
    $query = "SELECT COUNT(*) as total FROM nu_paciente";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($row);
}

function get_paciente($codigo) {
    global $db;
    $query = "SELECT * FROM nu_paciente WHERE codigo = :codigo LIMIT 0,1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($item) {
        ob_clean();
        echo json_encode($item);
    } else {
        http_response_code(404);
        ob_clean();
        echo json_encode(array("message" => "Paciente no encontrado."));
    }
}

function create_paciente() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;
    
    $query = "INSERT INTO nu_paciente (nombre, dni, fecha_nacimiento, sexo, altura, observacion, calle, codigo_postal, provincia, pais, online, telefono, email1, email2, peso, edad, activo, fechaa, codusuarioa) VALUES (:nombre, :dni, :fecha_nacimiento, :sexo, :altura, :observacion, :calle, :codigo_postal, :provincia, :pais, :online, :telefono, :email1, :email2, :peso, :edad, :activo, NOW(), :codusuarioa)";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codusuarioa", $codusuarioa);
    bind_paciente_params($stmt, $data);
    
    if ($stmt->execute()) {
        http_response_code(201);
        ob_clean();
        echo json_encode(array("message" => "Paciente creado."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array(
            "message" => "No se pudo crear el paciente.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function update_paciente() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if (empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el código del paciente."));
        return;
    }
    
    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;
    
    $query = "UPDATE nu_paciente SET nombre = :nombre, dni = :dni, fecha_nacimiento = :fecha_nacimiento, sexo = :sexo, altura = :altura, observacion = :observacion, calle = :calle, codigo_postal = :codigo_postal, provincia = :provincia, pais = :pais, online = :online, telefono = :telefono, email1 = :email1, email2 = :email2, peso = :peso, edad = :edad, activo = :activo, fecham = NOW(), codusuariom = :codusuariom WHERE codigo = :codigo";
    
    $stmt = $db->prepare($query);

    $codigo = intval($data->codigo);
    $stmt->bindParam(":codigo", $codigo);
    $stmt->bindParam(":codusuariom", $codusuariom);
    
    bind_paciente_params($stmt, $data);

    if ($stmt->execute()) {
        if (!empty($data->codigo_usuario)) {
            $codigo_usuario = intval($data->codigo_usuario);
            $codigo_paciente = intval($data->codigo);

            $update_user = $db->prepare("UPDATE usuario SET codigo_paciente = :paciente WHERE codigo = :usuario");
            $update_user->bindParam(':paciente', $codigo_paciente);
            $update_user->bindParam(':usuario', $codigo_usuario);
            $update_user->execute();

            sync_usuario_paciente_rel($codigo_usuario, $codigo_paciente);
        }
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Paciente actualizado."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array(
            "message" => "No se pudo actualizar el paciente.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function sync_usuario_paciente_rel($codigo_usuario, $codigo_paciente) {
    global $db;

    if (empty($codigo_usuario) || empty($codigo_paciente)) {
        return;
    }

    $tables = array('nu_consejo_usuario', 'nu_receta_usuario');
    foreach ($tables as $table) {
        if (!table_exists_pacientes($db, $table)) {
            continue;
        }

        $query = "UPDATE $table
                  SET codigo_usuario = :usuario
                  WHERE codigo_paciente = :paciente
                  AND (codigo_usuario IS NULL OR codigo_usuario = 0)";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':usuario', $codigo_usuario);
        $stmt->bindParam(':paciente', $codigo_paciente);
        $stmt->execute();
    }
}

function table_exists_pacientes($db, $table_name) {
    $query = "SHOW TABLES LIKE :table";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':table', $table_name);
    $stmt->execute();
    return $stmt->rowCount() > 0;
}

function delete_paciente() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if (empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el código del paciente."));
        return;
    }

    $query = "DELETE FROM nu_paciente WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    
    $codigo = intval($data->codigo);
    $stmt->bindParam(":codigo", $codigo);

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Paciente eliminado."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo eliminar el paciente."));
    }
}

function handle_post_request() {
    $data = json_decode(file_get_contents("php://input"));
    $action = isset($data->action) ? $data->action : 'create';
    
    if ($action === 'check_dependencies') {
        check_paciente_dependencies($data);
    } elseif ($action === 'delete_cascade') {
        delete_paciente_cascade($data);
    } else {
        create_paciente();
    }
}

// Función para verificar dependencias de un paciente antes de eliminarlo
function check_paciente_dependencies($data) {
    global $db;
    
    if(empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el código del paciente."));
        return;
    }
    
    $codigo = intval($data->codigo);
    $dependencies = array();
    
    // Contar registros en nu_consejo_usuario
    $query = "SELECT COUNT(*) as count FROM nu_consejo_usuario WHERE codigo_paciente = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $codigo);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($result['count'] > 0) {
        $dependencies['nu_consejo_usuario'] = intval($result['count']);
    }
    
    // Contar registros en nu_receta_usuario
    $query = "SELECT COUNT(*) as count FROM nu_receta_usuario WHERE codigo_paciente = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $codigo);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($result['count'] > 0) {
        $dependencies['nu_receta_usuario'] = intval($result['count']);
    }
    
    // Contar registros en nu_entrenamientos (por codigo_paciente)
    $query = "SELECT COUNT(*) as count FROM nu_entrenamientos WHERE codigo_paciente = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $codigo);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($result['count'] > 0) {
        $dependencies['nu_entrenamientos'] = intval($result['count']);
    }
    
    // Contar registros en nu_entrenamientos_ejercicios para entrenamientos de este paciente
    $query = "SELECT COUNT(DISTINCT eej.codigo) as count 
              FROM nu_entrenamientos_ejercicios eej
              JOIN nu_entrenamientos e ON eej.codigo_entrenamiento = e.codigo
              WHERE e.codigo_paciente = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $codigo);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($result['count'] > 0) {
        $dependencies['nu_entrenamientos_ejercicios'] = intval($result['count']);
    }
    
    // Contar registros en nu_entrenamientos_imagenes para entrenamientos de este paciente
    $query = "SELECT COUNT(DISTINCT eei.codigo) as count 
              FROM nu_entrenamientos_imagenes eei
              JOIN nu_entrenamientos e ON eei.codigo_entrenamiento = e.codigo
              WHERE e.codigo_paciente = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $codigo);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($result['count'] > 0) {
        $dependencies['nu_entrenamientos_imagenes'] = intval($result['count']);
    }
    
    http_response_code(200);
    ob_clean();
    echo json_encode(array("dependencies" => $dependencies));
}

// Función para eliminar paciente en cascada (elimina todos los registros relacionados)
function delete_paciente_cascade() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if(empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el código del paciente."));
        return;
    }
    
    $codigo = intval($data->codigo);
    
    try {
        $db->beginTransaction();
        
        // Obtener IDs de entrenamientos de este paciente
        $query = "SELECT codigo FROM nu_entrenamientos WHERE codigo_paciente = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":codigo", $codigo);
        $stmt->execute();
        $entrenamientos = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $entrenamiento_ids = array_column($entrenamientos, 'codigo');
        
        // Eliminar ejercicios de entrenamientos
        if (!empty($entrenamiento_ids)) {
            $placeholders = implode(',', array_fill(0, count($entrenamiento_ids), '?'));
            $query = "DELETE FROM nu_entrenamientos_ejercicios WHERE codigo_entrenamiento IN ($placeholders)";
            $stmt = $db->prepare($query);
            $stmt->execute($entrenamiento_ids);
            
            // Eliminar imágenes de entrenamientos
            $query = "DELETE FROM nu_entrenamientos_imagenes WHERE codigo_entrenamiento IN ($placeholders)";
            $stmt = $db->prepare($query);
            $stmt->execute($entrenamiento_ids);
        }
        
        // Eliminar entrenamientos
        $query = "DELETE FROM nu_entrenamientos WHERE codigo_paciente = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":codigo", $codigo);
        $stmt->execute();
        
        // Eliminar consejos del paciente
        $query = "DELETE FROM nu_consejo_usuario WHERE codigo_paciente = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":codigo", $codigo);
        $stmt->execute();
        
        // Eliminar recetas del paciente
        $query = "DELETE FROM nu_receta_usuario WHERE codigo_paciente = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":codigo", $codigo);
        $stmt->execute();
        
        // Finalmente eliminar el paciente
        $query = "DELETE FROM nu_paciente WHERE codigo = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":codigo", $codigo);
        $stmt->execute();
        
        $db->commit();
        
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Paciente y todos sus registros eliminados correctamente."));
    } catch (Exception $e) {
        $db->rollBack();
        http_response_code(503);
        ob_clean();
        echo json_encode(array(
            "message" => "Error al eliminar el paciente.",
            "error" => $e->getMessage()
        ));
    }
}
?>
