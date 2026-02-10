<?php
error_reporting(E_ALL); 
ini_set('display_errors', 1); 
ob_start(); // Iniciar el buffer de salida

// Headers para permitir el acceso desde cualquier origen (CORS)
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

// Validar token (solo usuarios registrados con paciente)
$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'planes_nutricionales');

// --- BLOQUE TRY-CATCH PARA CAPTURAR ERRORES FATALES ---
try {
    switch ($request_method) {
        case 'GET':
            if (isset($_GET["total_planes"])) {
                $codigo_paciente = isset($_GET["codigo_paciente"]) ? intval($_GET["codigo_paciente"]) : null;
                get_total_planes($codigo_paciente);
            } elseif (!empty($_GET["codigo_paciente"])) {
                get_planes_por_paciente(intval($_GET["codigo_paciente"]));
            } elseif (!empty($_GET["codigo_descarga"])) {
                download_plan(intval($_GET["codigo_descarga"]));
            } else {
                // Si no hay parámetros específicos, obtener todos los planes
                get_todos_planes();
            }
            break;
        case 'POST':
            if (isset($_POST['codigo'])) {
                update_plan();
            } else {
                create_plan();
            }
            break;
        case 'PUT':
            // PUT requests cannot handle file uploads directly with $_FILES.
            // The update_plan function is currently designed to handle both JSON data and file uploads from POST requests.
            // For PUT, if file upload is needed, it would require a different approach (e.g., base64 encoding file in JSON body, or separate upload endpoint).
            // As per current implementation, update_plan only uses $_POST and $_FILES, so it cannot be directly called for a PUT request with file.
            // Assuming PUT is for non-file updates or will be handled differently.
            http_response_code(405);
            echo json_encode(array("message" => "Method Not Allowed for direct file uploads via PUT. Use POST for updates with files."));
            break;
        case 'DELETE':
            delete_plan();
            break;
        default:
            header("HTTP/1.0 405 Method Not Allowed");
            break;
    }
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(array(
        "message" => "Error fatal en el servidor.",
        "error_details" => $e->getMessage(),
        "file" => $e->getFile(),
        "line" => $e->getLine()
    ));
}

function get_total_planes($codigo_paciente = null) {
    global $db;
    $query = "SELECT COUNT(*) as total FROM nu_plan_nutricional";
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


function get_planes_por_paciente($codigo_paciente) {
    global $db;
    $query = "SELECT p.codigo, p.codigo_paciente, p.desde, p.hasta, p.semanas, p.completado, p.codigo_entrevista, p.plan_documento_nombre, p.plan_indicaciones, p.plan_indicaciones_visible_usuario, p.url, p.fechaa, pa.nombre as nombre_paciente FROM nu_plan_nutricional p LEFT JOIN nu_paciente pa ON p.codigo_paciente = pa.codigo WHERE p.codigo_paciente = :codigo_paciente ORDER BY p.desde DESC";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    
    if ($stmt->execute()) {
        $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
        ob_clean(); // Limpiar cualquier salida previa antes de enviar el JSON
        // Asegurarse de que siempre se devuelve un array JSON, incluso si está vacío.
        echo json_encode($items ?? []); 
    } else {
        http_response_code(503);
        ob_clean(); // Limpiar antes de enviar el JSON de error
        echo json_encode(array(
            "message" => "No se pudo obtener los planes del paciente.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function get_todos_planes() {
    global $db;
    $query = "SELECT p.codigo, p.codigo_paciente, p.desde, p.hasta, p.semanas, p.completado, p.codigo_entrevista, p.plan_documento_nombre, p.plan_indicaciones, p.plan_indicaciones_visible_usuario, p.url, p.fechaa, pa.nombre as nombre_paciente FROM nu_plan_nutricional p LEFT JOIN nu_paciente pa ON p.codigo_paciente = pa.codigo ORDER BY p.desde DESC";
    
    $stmt = $db->prepare($query);
    
    if ($stmt->execute()) {
        $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
        ob_clean(); // Limpiar cualquier salida previa antes de enviar el JSON
        // Asegurarse de que siempre se devuelve un array JSON, incluso si está vacío.
        echo json_encode($items ?? []); 
    } else {
        http_response_code(503);
        ob_clean(); // Limpiar antes de enviar el JSON de error
        echo json_encode(array(
            "message" => "No se pudo obtener los planes.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function download_plan($codigo) {
    global $db;
    $query = "SELECT plan_documento, plan_documento_nombre FROM nu_plan_nutricional WHERE codigo = :codigo LIMIT 0,1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);

    if($item && !empty($item['plan_documento'])) {
        $nombreFichero = $item['plan_documento_nombre'] ?? 'plan.pdf';
        header("Content-Type: application/pdf");
        header("Content-Disposition: attachment; filename=\"$nombreFichero\"");
        header("Content-Length: " . strlen($item['plan_documento']));
        echo $item['plan_documento'];
        exit();
    } else {
        http_response_code(404);
        // Devolvemos JSON para que la app pueda interpretar el error
        header("Content-Type: application/json; charset=UTF-8");
        echo json_encode(array("message" => "Documento no encontrado."));
    }
}

function create_plan() {
    global $db;
    
    $codigo_paciente = !empty($_POST['codigo_paciente']) ? intval($_POST['codigo_paciente']) : null;
    $desde = !empty($_POST['fecha_inicio']) ? $_POST['fecha_inicio'] : null;
    $hasta = !empty($_POST['fecha_fin']) ? $_POST['fecha_fin'] : null;
    $semanas = !empty($_POST['semanas']) ? $_POST['semanas'] : null;
    $completado = !empty($_POST['completado']) ? $_POST['completado'] : null;
    $codigo_entrevista = !empty($_POST['codigo_entrevista']) ? intval($_POST['codigo_entrevista']) : null;
    $plan_indicaciones = !empty($_POST['descripcion']) ? $_POST['descripcion'] : null;
    $plan_indicaciones_visible_usuario = !empty($_POST['plan_indicaciones_visible_usuario']) ? $_POST['plan_indicaciones_visible_usuario'] : null;
    $url = !empty($_POST['url']) ? $_POST['url'] : null;
    $codusuarioa = !empty($_POST['codusuarioa']) ? intval($_POST['codusuarioa']) : 1;
    
    $plan_documento = null;
    $plan_documento_nombre = null;

    if (isset($_FILES['archivo']) && $_FILES['archivo']['error'] == UPLOAD_ERR_OK) {
        $plan_documento = file_get_contents($_FILES['archivo']['tmp_name']);
        $plan_documento_nombre = basename($_FILES['archivo']['name']);
    }

    $query = "INSERT INTO nu_plan_nutricional (codigo_paciente, desde, hasta, semanas, completado, codigo_entrevista, plan_documento, plan_documento_nombre, plan_indicaciones, plan_indicaciones_visible_usuario, url, fechaa, codusuarioa) VALUES (:codigo_paciente, :desde, :hasta, :semanas, :completado, :codigo_entrevista, :plan_documento, :plan_documento_nombre, :plan_indicaciones, :plan_indicaciones_visible_usuario, :url, NOW(), :codusuarioa)";
    
    $stmt = $db->prepare($query);

    $stmt->bindParam(":codigo_paciente", $codigo_paciente, PDO::PARAM_INT);
    $stmt->bindParam(":desde", $desde);
    $stmt->bindParam(":hasta", $hasta);
    $stmt->bindParam(":semanas", $semanas);
    $stmt->bindParam(":completado", $completado);
    $stmt->bindParam(":codigo_entrevista", $codigo_entrevista, PDO::PARAM_INT);
    $stmt->bindParam(":plan_documento", $plan_documento, PDO::PARAM_LOB);
    $stmt->bindParam(":plan_documento_nombre", $plan_documento_nombre);
    $stmt->bindParam(":plan_indicaciones", $plan_indicaciones);
    $stmt->bindParam(":plan_indicaciones_visible_usuario", $plan_indicaciones_visible_usuario);
    $stmt->bindParam(":url", $url);
    $stmt->bindParam(":codusuarioa", $codusuarioa);

    if ($stmt->execute()) {
        http_response_code(201);
        echo json_encode(array("message" => "Plan creado."));
    } else {
        http_response_code(503);
        echo json_encode(array(
            "message" => "No se pudo crear el plan.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function update_plan() {
    global $db;
    
    $codigo = !empty($_POST['codigo']) ? intval($_POST['codigo']) : null;
    if (is_null($codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del plan para actualizar."));
        return;
    }

    $codigo_paciente = !empty($_POST['codigo_paciente']) ? intval($_POST['codigo_paciente']) : null;
    $desde = !empty($_POST['fecha_inicio']) ? $_POST['fecha_inicio'] : null;
    $hasta = !empty($_POST['fecha_fin']) ? $_POST['fecha_fin'] : null;
    $semanas = !empty($_POST['semanas']) ? $_POST['semanas'] : null;
    $completado = !empty($_POST['completado']) ? $_POST['completado'] : null;
    $codigo_entrevista = !empty($_POST['codigo_entrevista']) ? intval($_POST['codigo_entrevista']) : null;
    $plan_indicaciones = !empty($_POST['descripcion']) ? $_POST['descripcion'] : null;
    $plan_indicaciones_visible_usuario = !empty($_POST['plan_indicaciones_visible_usuario']) ? $_POST['plan_indicaciones_visible_usuario'] : null;
    $url = !empty($_POST['url']) ? $_POST['url'] : null;
    $codusuariom = !empty($_POST['codusuariom']) ? intval($_POST['codusuariom']) : 1;

    $set_clauses = [
        "codigo_paciente = :codigo_paciente",
        "desde = :desde",
        "hasta = :hasta",
        "semanas = :semanas",
        "completado = :completado",
        "codigo_entrevista = :codigo_entrevista",
        "plan_indicaciones = :plan_indicaciones",
        "plan_indicaciones_visible_usuario = :plan_indicaciones_visible_usuario",
        "url = :url",
        "fecham = NOW()",
        "codusuariom = :codusuariom"
    ];
    $bind_params = [
        ':codigo_paciente' => $codigo_paciente,
        ':desde' => $desde,
        ':hasta' => $hasta,
        ':semanas' => $semanas,
        ':completado' => $completado,
        ':codigo_entrevista' => $codigo_entrevista,
        ':plan_indicaciones' => $plan_indicaciones,
        ':plan_indicaciones_visible_usuario' => $plan_indicaciones_visible_usuario,
        ':url' => $url,
        ':codusuariom' => $codusuariom,
        ':codigo' => $codigo
    ];

    // Si se sube un nuevo documento, se añade a la consulta
    if (isset($_FILES['archivo']) && $_FILES['archivo']['error'] == UPLOAD_ERR_OK) {
        $plan_documento = file_get_contents($_FILES['archivo']['tmp_name']);
        $plan_documento_nombre = basename($_FILES['archivo']['name']);
        $set_clauses[] = "plan_documento = :plan_documento";
        $set_clauses[] = "plan_documento_nombre = :plan_documento_nombre";
        $bind_params[':plan_documento'] = $plan_documento;
        $bind_params[':plan_documento_nombre'] = $plan_documento_nombre;
    }

    $query = "UPDATE nu_plan_nutricional SET " . implode(", ", $set_clauses) . " WHERE codigo = :codigo";
    $stmt = $db->prepare($query);

    // Bindeo de parámetros
    foreach ($bind_params as $key => &$val) {
        if ($key === ':plan_documento') {
            $stmt->bindParam($key, $val, PDO::PARAM_LOB);
        } else {
            $stmt->bindParam($key, $val);
        }
    }

    if ($stmt->execute()) {
        http_response_code(200);
        echo json_encode(array("message" => "Plan actualizado."));
    } else {
        http_response_code(503);
        echo json_encode(array(
            "message" => "No se pudo actualizar el plan.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function delete_plan() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del plan."));
        return;
    }

    $query = "DELETE FROM nu_plan_nutricional WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);

    if($stmt->execute()){
        http_response_code(200);
        ob_clean(); // Limpiar antes de enviar el JSON
        echo json_encode(array("message" => "Plan eliminado."));
    } else {
        http_response_code(503);
        ob_clean(); // Limpiar antes de enviar el JSON de error
        echo json_encode(array("message" => "No se pudo eliminar el plan."));
    }
}
?>