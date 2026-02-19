<?php
/**
 * Endpoint específico para carga de documentos en planes fit
 * Separado del CRUD principal para evitar restricciones de Apache en multipart
 */

error_reporting(E_ALL); 
ini_set('display_errors', 1); 
ob_start();

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/auto_validator.php';
include_once '../auth/permissions.php';

$database = new Database();
$db = $database->getConnection();

// Validar token
$validator = new AutoValidator($db);
$user = $validator->validate();
PermissionManager::checkPermission($user, 'planes_fit');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(array("error" => "Solo POST permitido"));
    exit();
}

try {
    error_log("PLAN_FIT_UPLOAD: Iniciando carga de archivo. FILES=" . json_encode($_FILES));
    
    $codigo = !empty($_POST['codigo']) ? intval($_POST['codigo']) : null;
    $tipo_operacion = !empty($_POST['tipo']) ? $_POST['tipo'] : 'update'; // 'create' o 'update'
    
    if (empty($_FILES['archivo'])) {
        http_response_code(400);
        echo json_encode(array("error" => "No se proporcionó archivo"));
        exit();
    }

    if ($_FILES['archivo']['error'] !== UPLOAD_ERR_OK) {
        http_response_code(400);
        echo json_encode(array(
            "error" => "Error en la carga del archivo",
            "details" => $_FILES['archivo']['error']
        ));
        exit();
    }

    $plan_documento = file_get_contents($_FILES['archivo']['tmp_name']);
    $plan_documento_nombre = basename($_FILES['archivo']['name']);
    $tamaño = strlen($plan_documento);
    
    error_log("PLAN_FIT_UPLOAD: Archivo recibido: $plan_documento_nombre, tamaño=$tamaño bytes");

    if ($tipo_operacion === 'create') {
        // INSERT (crear plan con documento)
        if (is_null($codigo)) {
            // codigo_paciente es requerido para crear
            $codigo_paciente = !empty($_POST['codigo_paciente']) ? intval($_POST['codigo_paciente']) : null;
            
            if (is_null($codigo_paciente)) {
                http_response_code(400);
                echo json_encode(array("error" => "codigo_paciente requerido para crear"));
                exit();
            }

            $desde = !empty($_POST['fecha_inicio']) ? $_POST['fecha_inicio'] : null;
            $hasta = !empty($_POST['fecha_fin']) ? $_POST['fecha_fin'] : null;
            $semanas = !empty($_POST['semanas']) ? $_POST['semanas'] : null;
            $completado = !empty($_POST['completado']) ? $_POST['completado'] : 'N';
            $codigo_entrevista = !empty($_POST['codigo_entrevista']) ? intval($_POST['codigo_entrevista']) : null;
            $descripcion = !empty($_POST['descripcion']) ? $_POST['descripcion'] : null;
            $plan_indicaciones_visible_usuario = !empty($_POST['plan_indicaciones_visible_usuario']) ? $_POST['plan_indicaciones_visible_usuario'] : null;
            $url = !empty($_POST['url']) ? $_POST['url'] : null;
            $rondas = !empty($_POST['rondas']) ? intval($_POST['rondas']) : null;
            $consejos = !empty($_POST['consejos']) ? $_POST['consejos'] : null;
            $recomendaciones = !empty($_POST['recomendaciones']) ? $_POST['recomendaciones'] : null;
            $codusuarioa = !empty($_POST['codusuarioa']) ? intval($_POST['codusuarioa']) : 1;

            $query = "INSERT INTO nu_plan_nutricional_fit 
                      (codigo_paciente, desde, hasta, semanas, completado, codigo_entrevista, 
                       plan_documento, plan_documento_nombre, descripcion, 
                       plan_indicaciones_visible_usuario, url, rondas, consejos, recomendaciones, fechaa, codusuarioa) 
                      VALUES 
                      (:codigo_paciente, :desde, :hasta, :semanas, :completado, :codigo_entrevista, 
                       :plan_documento, :plan_documento_nombre, :descripcion, 
                       :plan_indicaciones_visible_usuario, :url, :rondas, :consejos, :recomendaciones, NOW(), :codusuarioa)";
            
            $stmt = $db->prepare($query);
            $stmt->bindParam(":codigo_paciente", $codigo_paciente, PDO::PARAM_INT);
            $stmt->bindParam(":desde", $desde);
            $stmt->bindParam(":hasta", $hasta);
            $stmt->bindParam(":semanas", $semanas);
            $stmt->bindParam(":completado", $completado);
            $stmt->bindParam(":codigo_entrevista", $codigo_entrevista, PDO::PARAM_INT);
            $stmt->bindParam(":plan_documento", $plan_documento, PDO::PARAM_LOB);
            $stmt->bindParam(":plan_documento_nombre", $plan_documento_nombre);
            $stmt->bindParam(":descripcion", $descripcion);
            $stmt->bindParam(":plan_indicaciones_visible_usuario", $plan_indicaciones_visible_usuario);
            $stmt->bindParam(":url", $url);
            $stmt->bindParam(":rondas", $rondas, PDO::PARAM_INT);
            $stmt->bindParam(":consejos", $consejos);
            $stmt->bindParam(":recomendaciones", $recomendaciones);
            $stmt->bindParam(":codusuarioa", $codusuarioa, PDO::PARAM_INT);

            if ($stmt->execute()) {
                http_response_code(201);
                echo json_encode(array("message" => "Plan fit creado con documento"));
            } else {
                http_response_code(503);
                echo json_encode(array("error" => "No se pudo insertar el plan fit"));
            }
        } else {
            http_response_code(400);
            echo json_encode(array("error" => "Para crear use tipo=create sin codigo"));
        }
    } else {
        // UPDATE (actualizar documento de plan existente)
        if (is_null($codigo)) {
            http_response_code(400);
            echo json_encode(array("error" => "codigo requerido para actualizar"));
            exit();
        }

        $codusuariom = !empty($_POST['codusuariom']) ? intval($_POST['codusuariom']) : 1;
        
        $query = "UPDATE nu_plan_nutricional_fit 
                  SET plan_documento = :plan_documento, 
                      plan_documento_nombre = :plan_documento_nombre,
                      fecham = NOW(),
                      codusuariom = :codusuariom
                  WHERE codigo = :codigo";
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(":plan_documento", $plan_documento, PDO::PARAM_LOB);
        $stmt->bindParam(":plan_documento_nombre", $plan_documento_nombre);
        $stmt->bindParam(":codusuariom", $codusuariom, PDO::PARAM_INT);
        $stmt->bindParam(":codigo", $codigo, PDO::PARAM_INT);

        if ($stmt->execute()) {
            http_response_code(200);
            echo json_encode(array("message" => "Documento plan fit actualizado"));
        } else {
            http_response_code(503);
            echo json_encode(array("error" => "No se pudo actualizar el documento plan fit"));
        }
    }

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(array(
        "error" => "Error interno del servidor",
        "details" => $e->getMessage()
    ));
}

?>
