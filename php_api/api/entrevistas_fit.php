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

// Validar token (solo usuarios registrados con paciente)
$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'entrevistas_fit');

switch($request_method) {
    case 'GET':
        if (isset($_GET["total_entrevistas_fit"])) {
            $codigo_paciente = isset($_GET["codigo_paciente"]) ? intval($_GET["codigo_paciente"]) : null;
            get_total_entrevistas_fit($codigo_paciente);
        } elseif(!empty($_GET["codigo"])) {
            get_entrevista_fit(intval($_GET["codigo"]));
        } elseif (!empty($_GET["codigo_paciente"])) {
            get_entrevistas_fit_por_paciente(intval($_GET["codigo_paciente"]));
        } else {
            get_todas_entrevistas_fit();
        }
        break;
    case 'POST':
        create_entrevista_fit();
        break;
    case 'PUT':
        update_entrevista_fit();
        break;
    case 'DELETE':
        delete_entrevista_fit();
        break;
    default:
        header("HTTP/1.0 405 Method Not Allowed");
        break;
}

function get_total_entrevistas_fit($codigo_paciente = null) {
    global $db;
    $query = "SELECT COUNT(*) as total FROM nu_paciente_entrevista_fit";
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

function get_entrevistas_fit_por_paciente($codigo_paciente) {
    global $db;
    $query = "SELECT e.*, p.nombre as nombre_paciente, p.activo as paciente_activo
              FROM nu_paciente_entrevista_fit e
              LEFT JOIN nu_paciente p ON e.codigo_paciente = p.codigo
              WHERE e.codigo_paciente = :codigo_paciente
              ORDER BY e.fecha_prevista DESC";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items);
}

function get_todas_entrevistas_fit() {
    global $db;
    $query = "SELECT e.*, p.nombre as nombre_paciente, p.activo as paciente_activo
              FROM nu_paciente_entrevista_fit e
              LEFT JOIN nu_paciente p ON e.codigo_paciente = p.codigo
              ORDER BY e.fecha_prevista DESC";

    $stmt = $db->prepare($query);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items);
}

function get_entrevista_fit($codigo) {
    global $db;
    $query = "SELECT * FROM nu_paciente_entrevista_fit WHERE codigo = :codigo LIMIT 0,1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);
    if($item) {
        ob_clean();
        echo json_encode($item);
    } else {
        http_response_code(404);
        ob_clean();
        echo json_encode(array("message" => "Entrevista Fit no encontrada."));
    }
}

function bind_entrevista_fit_params($stmt, $data) {
    foreach ($data as $key => $value) {
        if (is_string($value)) {
            $data->$key = htmlspecialchars(strip_tags($value));
        }
    }

    $stmt->bindParam(":codigo_paciente", $data->codigo_paciente);
    $stmt->bindParam(":fecha_realizacion", $data->fecha_realizacion);
    $stmt->bindParam(":completada", $data->completada);
    $stmt->bindParam(":fecha_prevista", $data->fecha_prevista);
    $stmt->bindParam(":online", $data->online);
    $stmt->bindParam(":motivo", $data->motivo);
    $stmt->bindParam(":objetivos", $data->objetivos);
    $stmt->bindParam(":enfermedad_corazon", $data->enfermedad_corazon);
    $stmt->bindParam(":nota_dolor_practica_actividad", $data->nota_dolor_practica_actividad);
    $stmt->bindParam(":nota_dolor_reposo", $data->nota_dolor_reposo);
    $stmt->bindParam(":perdida_equilibrio", $data->perdida_equilibrio);
    $stmt->bindParam(":problema_huesos_articulaciones", $data->problema_huesos_articulaciones);
    $stmt->bindParam(":prescipcion_medicacion_arterial", $data->prescipcion_medicacion_arterial);
    $stmt->bindParam(":razon_impedimento_ejercicio", $data->razon_impedimento_ejercicio);
    $stmt->bindParam(":historial_deportivo", $data->historial_deportivo);
    $stmt->bindParam(":actividad_diaria", $data->actividad_diaria);
    $stmt->bindParam(":profesion", $data->profesion);
    $stmt->bindParam(":disponibilidad_horaria", $data->disponibilidad_horaria);
    $stmt->bindParam(":disponibilidad_instalaciones", $data->disponibilidad_instalaciones);
    $stmt->bindParam(":habitos_alimentarios", $data->habitos_alimentarios);
    $stmt->bindParam(":futuro_seguir_ritmo", $data->futuro_seguir_ritmo);
    $stmt->bindParam(":futuro_logros_proximas_semanas", $data->futuro_logros_proximas_semanas);
    $stmt->bindParam(":futuro_probar_nuevos_ejercicios", $data->futuro_probar_nuevos_ejercicios);
    $stmt->bindParam(":observacion", $data->observacion);
}

function create_entrevista_fit() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;

    $query = "INSERT INTO nu_paciente_entrevista_fit SET
                codigo_paciente = :codigo_paciente, fecha_realizacion = :fecha_realizacion, completada = :completada,
                fecha_prevista = :fecha_prevista, online = :online, motivo = :motivo,
                objetivos = :objetivos, enfermedad_corazon = :enfermedad_corazon, nota_dolor_practica_actividad = :nota_dolor_practica_actividad,
                nota_dolor_reposo = :nota_dolor_reposo, perdida_equilibrio = :perdida_equilibrio,
                problema_huesos_articulaciones = :problema_huesos_articulaciones, prescipcion_medicacion_arterial = :prescipcion_medicacion_arterial,
                razon_impedimento_ejercicio = :razon_impedimento_ejercicio, historial_deportivo = :historial_deportivo,
                actividad_diaria = :actividad_diaria, profesion = :profesion, disponibilidad_horaria = :disponibilidad_horaria,
                disponibilidad_instalaciones = :disponibilidad_instalaciones, habitos_alimentarios = :habitos_alimentarios,
                futuro_seguir_ritmo = :futuro_seguir_ritmo, futuro_logros_proximas_semanas = :futuro_logros_proximas_semanas,
                futuro_probar_nuevos_ejercicios = :futuro_probar_nuevos_ejercicios, observacion = :observacion,
                fechaa = NOW(), codusuarioa = :codusuarioa";

    $stmt = $db->prepare($query);
    bind_entrevista_fit_params($stmt, $data);
    $stmt->bindParam(":codusuarioa", $codusuarioa);

    if($stmt->execute()) {
        http_response_code(201);
        ob_clean();
        echo json_encode(array("message" => "Entrevista Fit creada."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo crear la entrevista Fit."));
    }
}

function update_entrevista_fit() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;

    $query = "UPDATE nu_paciente_entrevista_fit SET
                codigo_paciente = :codigo_paciente, fecha_realizacion = :fecha_realizacion, completada = :completada,
                fecha_prevista = :fecha_prevista, online = :online, motivo = :motivo,
                objetivos = :objetivos, enfermedad_corazon = :enfermedad_corazon, nota_dolor_practica_actividad = :nota_dolor_practica_actividad,
                nota_dolor_reposo = :nota_dolor_reposo, perdida_equilibrio = :perdida_equilibrio,
                problema_huesos_articulaciones = :problema_huesos_articulaciones, prescipcion_medicacion_arterial = :prescipcion_medicacion_arterial,
                razon_impedimento_ejercicio = :razon_impedimento_ejercicio, historial_deportivo = :historial_deportivo,
                actividad_diaria = :actividad_diaria, profesion = :profesion, disponibilidad_horaria = :disponibilidad_horaria,
                disponibilidad_instalaciones = :disponibilidad_instalaciones, habitos_alimentarios = :habitos_alimentarios,
                futuro_seguir_ritmo = :futuro_seguir_ritmo, futuro_logros_proximas_semanas = :futuro_logros_proximas_semanas,
                futuro_probar_nuevos_ejercicios = :futuro_probar_nuevos_ejercicios, observacion = :observacion,
                fecham = NOW(), codusuariom = :codusuariom
              WHERE codigo = :codigo";

    $stmt = $db->prepare($query);
    bind_entrevista_fit_params($stmt, $data);
    $stmt->bindParam(":codusuariom", $codusuariom);
    $stmt->bindParam(":codigo", $data->codigo);

    if($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Entrevista Fit actualizada."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo actualizar la entrevista Fit."));
    }
}

function delete_entrevista_fit() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if (!isset($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(["message" => "Código requerido."]);
        return;
    }

    $query = "DELETE FROM nu_paciente_entrevista_fit WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $data->codigo);

    if($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Entrevista Fit eliminada."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo eliminar la entrevista Fit."));
    }
}
?>
