<?php
error_reporting(E_ALL); 
ini_set('display_errors', 1); 
ob_start();

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
PermissionManager::checkPermission($user, 'planes_fit');

try {
    switch ($request_method) {
        case 'GET':
            if (isset($_GET["total_planes_fit"])) {
                $codigo_paciente = isset($_GET["codigo_paciente"]) ? intval($_GET["codigo_paciente"]) : null;
                get_total_planes_fit($codigo_paciente);
            } elseif (!empty($_GET["codigo_paciente"])) {
                get_planes_fit_por_paciente(intval($_GET["codigo_paciente"]));
            } elseif (!empty($_GET["codigo_descarga"])) {
                download_plan_fit(intval($_GET["codigo_descarga"]));
            } else {
                get_todos_planes_fit();
            }
            break;
        case 'POST':
            if (isset($_POST['codigo'])) {
                update_plan_fit();
            } else {
                create_plan_fit();
            }
            break;
        case 'PUT':
            http_response_code(405);
            echo json_encode(array("message" => "Method Not Allowed for direct file uploads via PUT. Use POST for updates with files."));
            break;
        case 'DELETE':
            delete_plan_fit();
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

function get_total_planes_fit($codigo_paciente = null) {
    global $db;
    $query = "SELECT COUNT(*) as total FROM nu_plan_nutricional_fit";
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

function get_planes_fit_por_paciente($codigo_paciente) {
    global $db;
    $query = "SELECT p.codigo, p.codigo_paciente, p.desde, p.hasta, p.semanas, p.completado, p.codigo_entrevista, p.plan_documento_nombre, p.plan_indicaciones, p.plan_indicaciones_visible_usuario, p.url, p.rondas, p.consejos, p.recomendaciones, p.fechaa, pa.nombre as nombre_paciente FROM nu_plan_nutricional_fit p LEFT JOIN nu_paciente pa ON p.codigo_paciente = pa.codigo WHERE p.codigo_paciente = :codigo_paciente ORDER BY p.desde DESC";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    
    if ($stmt->execute()) {
        $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
        ob_clean();
        echo json_encode($items ?? []); 
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array(
            "message" => "No se pudo obtener los planes fit del paciente.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function get_todos_planes_fit() {
    global $db;
    $query = "SELECT p.codigo, p.codigo_paciente, p.desde, p.hasta, p.semanas, p.completado, p.codigo_entrevista, p.plan_documento_nombre, p.plan_indicaciones, p.plan_indicaciones_visible_usuario, p.url, p.rondas, p.consejos, p.recomendaciones, p.fechaa, pa.nombre as nombre_paciente FROM nu_plan_nutricional_fit p LEFT JOIN nu_paciente pa ON p.codigo_paciente = pa.codigo ORDER BY p.desde DESC";
    
    $stmt = $db->prepare($query);
    
    if ($stmt->execute()) {
        $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
        ob_clean();
        echo json_encode($items ?? []); 
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array(
            "message" => "No se pudo obtener los planes fit.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function download_plan_fit($codigo) {
    global $db;
    $query = "SELECT plan_documento, plan_documento_nombre FROM nu_plan_nutricional_fit WHERE codigo = :codigo LIMIT 0,1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);

    if($item && !empty($item['plan_documento'])) {
        $nombreFichero = $item['plan_documento_nombre'] ?? 'plan_fit.pdf';
        header("Content-Type: application/pdf");
        header("Content-Disposition: attachment; filename=\"$nombreFichero\"");
        header("Content-Length: " . strlen($item['plan_documento']));
        echo $item['plan_documento'];
        exit();
    } else {
        http_response_code(404);
        echo json_encode(array("message" => "Plan fit no encontrado o sin documento."));
    }
}

function create_plan_fit() {
    global $db;
    
    $codigo_paciente = isset($_POST['codigo_paciente']) ? intval($_POST['codigo_paciente']) : null;
    $fecha_inicio = $_POST['fecha_inicio'] ?? null;
    $fecha_fin = $_POST['fecha_fin'] ?? null;
    $semanas = $_POST['semanas'] ?? null;
    $completado = $_POST['completado'] ?? 'N';
    $codigo_entrevista = isset($_POST['codigo_entrevista']) && $_POST['codigo_entrevista'] !== '' ? intval($_POST['codigo_entrevista']) : null;
    $descripcion = $_POST['descripcion'] ?? null;
    $plan_indicaciones_visible_usuario = $_POST['plan_indicaciones_visible_usuario'] ?? null;
    $url = $_POST['url'] ?? null;
    $rondas = isset($_POST['rondas']) && $_POST['rondas'] !== '' ? intval($_POST['rondas']) : null;
    $consejos = $_POST['consejos'] ?? null;
    $recomendaciones = $_POST['recomendaciones'] ?? null;
    $plan_documento_nombre = $_POST['plan_documento_nombre'] ?? null;
    $codusuarioa = isset($_POST['codusuarioa']) ? intval($_POST['codusuarioa']) : 1;

    $plan_documento_blob = null;
    if (isset($_FILES['archivo']) && $_FILES['archivo']['error'] === UPLOAD_ERR_OK) {
        $plan_documento_blob = file_get_contents($_FILES['archivo']['tmp_name']);
        if (!$plan_documento_nombre) {
            $plan_documento_nombre = $_FILES['archivo']['name'];
        }
    }

    $query = "INSERT INTO nu_plan_nutricional_fit (codigo_paciente, desde, hasta, semanas, completado, codigo_entrevista, plan_indicaciones, plan_indicaciones_visible_usuario, url, rondas, consejos, recomendaciones, plan_documento, plan_documento_nombre, codusuarioa, fechaa) VALUES (:codigo_paciente, :desde, :hasta, :semanas, :completado, :codigo_entrevista, :plan_indicaciones, :plan_indicaciones_visible_usuario, :url, :rondas, :consejos, :recomendaciones, :plan_documento, :plan_documento_nombre, :codusuarioa, NOW())";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    $stmt->bindParam(':desde', $fecha_inicio);
    $stmt->bindParam(':hasta', $fecha_fin);
    $stmt->bindParam(':semanas', $semanas);
    $stmt->bindParam(':completado', $completado);
    $stmt->bindParam(':codigo_entrevista', $codigo_entrevista);
    $stmt->bindParam(':plan_indicaciones', $descripcion);
    $stmt->bindParam(':plan_indicaciones_visible_usuario', $plan_indicaciones_visible_usuario);
    $stmt->bindParam(':url', $url);
    $stmt->bindParam(':rondas', $rondas);
    $stmt->bindParam(':consejos', $consejos);
    $stmt->bindParam(':recomendaciones', $recomendaciones);
    $stmt->bindParam(':plan_documento', $plan_documento_blob, PDO::PARAM_LOB);
    $stmt->bindParam(':plan_documento_nombre', $plan_documento_nombre);
    $stmt->bindParam(':codusuarioa', $codusuarioa);

    if ($stmt->execute()) {
        http_response_code(201);
        ob_clean();
        echo json_encode(array("message" => "Plan fit creado.", "codigo" => $db->lastInsertId()));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array(
            "message" => "No se pudo crear el plan fit.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function update_plan_fit() {
    global $db;

    $codigo = isset($_POST['codigo']) ? intval($_POST['codigo']) : null;
    if (!$codigo) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del plan fit."));
        return;
    }

    $set_clauses = [];
    $bind_params = [':codigo' => $codigo];

    if (isset($_POST['codigo_paciente'])) {
        $set_clauses[] = "codigo_paciente = :codigo_paciente";
        $bind_params[':codigo_paciente'] = intval($_POST['codigo_paciente']);
    }
    if (isset($_POST['fecha_inicio'])) {
        $set_clauses[] = "desde = :desde";
        $bind_params[':desde'] = $_POST['fecha_inicio'];
    }
    if (isset($_POST['fecha_fin'])) {
        $set_clauses[] = "hasta = :hasta";
        $bind_params[':hasta'] = $_POST['fecha_fin'];
    }
    if (isset($_POST['semanas'])) {
        $set_clauses[] = "semanas = :semanas";
        $bind_params[':semanas'] = $_POST['semanas'];
    }
    if (isset($_POST['completado'])) {
        $set_clauses[] = "completado = :completado";
        $bind_params[':completado'] = $_POST['completado'];
    }
    if (isset($_POST['codigo_entrevista'])) {
        $set_clauses[] = "codigo_entrevista = :codigo_entrevista";
        $bind_params[':codigo_entrevista'] = $_POST['codigo_entrevista'] !== '' ? intval($_POST['codigo_entrevista']) : null;
    }
    if (isset($_POST['descripcion'])) {
        $set_clauses[] = "plan_indicaciones = :plan_indicaciones";
        $bind_params[':plan_indicaciones'] = $_POST['descripcion'];
    }
    if (isset($_POST['plan_indicaciones_visible_usuario'])) {
        $set_clauses[] = "plan_indicaciones_visible_usuario = :plan_indicaciones_visible_usuario";
        $bind_params[':plan_indicaciones_visible_usuario'] = $_POST['plan_indicaciones_visible_usuario'];
    }
    if (isset($_POST['url'])) {
        $set_clauses[] = "url = :url";
        $bind_params[':url'] = $_POST['url'];
    }
    if (isset($_POST['rondas'])) {
        $set_clauses[] = "rondas = :rondas";
        $bind_params[':rondas'] = $_POST['rondas'] !== '' ? intval($_POST['rondas']) : null;
    }
    if (isset($_POST['consejos'])) {
        $set_clauses[] = "consejos = :consejos";
        $bind_params[':consejos'] = $_POST['consejos'];
    }
    if (isset($_POST['recomendaciones'])) {
        $set_clauses[] = "recomendaciones = :recomendaciones";
        $bind_params[':recomendaciones'] = $_POST['recomendaciones'];
    }
    if (isset($_POST['plan_documento_nombre'])) {
        $set_clauses[] = "plan_documento_nombre = :plan_documento_nombre";
        $bind_params[':plan_documento_nombre'] = $_POST['plan_documento_nombre'];
    }
    if (isset($_POST['codusuariom'])) {
        $set_clauses[] = "codusuariom = :codusuariom";
        $bind_params[':codusuariom'] = intval($_POST['codusuariom']);
    }

    $set_clauses[] = "fecham = NOW()";

    if (isset($_FILES['archivo']) && $_FILES['archivo']['error'] === UPLOAD_ERR_OK) {
        $plan_documento_blob = file_get_contents($_FILES['archivo']['tmp_name']);
        $set_clauses[] = "plan_documento = :plan_documento";
        $bind_params[':plan_documento'] = $plan_documento_blob;
    }

    if (empty($set_clauses)) {
        http_response_code(400);
        echo json_encode(array("message" => "No hay datos para actualizar."));
        return;
    }

    $query = "UPDATE nu_plan_nutricional_fit SET " . implode(", ", $set_clauses) . " WHERE codigo = :codigo";
    $stmt = $db->prepare($query);

    foreach ($bind_params as $key => &$val) {
        if ($key === ':plan_documento') {
            $stmt->bindParam($key, $val, PDO::PARAM_LOB);
        } else {
            $stmt->bindParam($key, $val);
        }
    }

    if ($stmt->execute()) {
        http_response_code(200);
        echo json_encode(array("message" => "Plan fit actualizado."));
    } else {
        http_response_code(503);
        echo json_encode(array(
            "message" => "No se pudo actualizar el plan fit.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function delete_plan_fit() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código del plan fit."));
        return;
    }

    $query = "DELETE FROM nu_plan_nutricional_fit WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);

    if($stmt->execute()){
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Plan fit eliminado."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo eliminar el plan fit."));
    }
}
?>
