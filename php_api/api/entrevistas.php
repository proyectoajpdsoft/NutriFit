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
PermissionManager::checkPermission($user, 'entrevistas');

switch($request_method) {
    case 'GET':
        if (isset($_GET["total_entrevistas"])) {
            $codigo_paciente = isset($_GET["codigo_paciente"]) ? intval($_GET["codigo_paciente"]) : null;
            get_total_entrevistas($codigo_paciente);
        } elseif(!empty($_GET["codigo"])) {
            // Devuelve una entrevista específica
            get_entrevista(intval($_GET["codigo"]));
        } elseif (!empty($_GET["codigo_paciente"])) {
            // Devuelve todas las entrevistas de un paciente
            get_entrevistas_por_paciente(intval($_GET["codigo_paciente"]));
        }
        else {
            // Devuelve todas las entrevistas sin filtro de paciente
            get_todas_entrevistas();
        }
        break;
    case 'POST':
        create_entrevista();
        break;
    case 'PUT':
        update_entrevista();
        break;
    case 'DELETE':
        delete_entrevista();
        break;
    default:
        header("HTTP/1.0 405 Method Not Allowed");
        break;
}

function get_total_entrevistas($codigo_paciente = null) {
    global $db;
    $query = "SELECT COUNT(*) as total FROM nu_paciente_entrevista";
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

function get_entrevistas_por_paciente($codigo_paciente) {
    global $db;
    $query = "SELECT e.*, p.nombre as nombre_paciente, p.activo as paciente_activo
              FROM nu_paciente_entrevista e
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

function get_todas_entrevistas() {
    global $db;
    $query = "SELECT e.*, p.nombre as nombre_paciente, p.activo as paciente_activo
              FROM nu_paciente_entrevista e
              LEFT JOIN nu_paciente p ON e.codigo_paciente = p.codigo
              ORDER BY e.fecha_prevista DESC";
              
    $stmt = $db->prepare($query);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items);
}

function get_entrevista($codigo) {
    global $db;
    $query = "SELECT * FROM nu_paciente_entrevista WHERE codigo = :codigo LIMIT 0,1";
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
        echo json_encode(array("message" => "Entrevista no encontrada."));
    }
}

// Función para bindear todos los parámetros. Evita repetir código.
function bind_entrevista_params($stmt, $data) {
    // Sanitizar todos los campos de texto
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
    $stmt->bindParam(":peso", $data->peso);
    $stmt->bindParam(":motivo", $data->motivo);
    $stmt->bindParam(":objetivos", $data->objetivos);
    $stmt->bindParam(":dietas_anteriores", $data->dietas_anteriores);
    $stmt->bindParam(":ocupacion_horario", $data->ocupacion_horario);
    $stmt->bindParam(":deporte_frecuencia", $data->deporte_frecuencia);
    $stmt->bindParam(":actividad_fisica", $data->actividad_fisica);
    $stmt->bindParam(":fumador", $data->fumador);
    $stmt->bindParam(":alcohol", $data->alcohol);
    $stmt->bindParam(":sueno", $data->sueno);
    $stmt->bindParam(":horario_laboral_comidas", $data->horario_laboral_comidas);
    $stmt->bindParam(":comidas_dia", $data->comidas_dia);
    $stmt->bindParam(":horario_comidas_regular", $data->horario_comidas_regular);
    $stmt->bindParam(":lugar_comidas", $data->lugar_comidas);
    $stmt->bindParam(":quien_compra_casa", $data->quien_compra_casa);
    $stmt->bindParam(":bebida_comida", $data->bebida_comida);
    $stmt->bindParam(":preferencias_alimentarias", $data->preferencias_alimentarias);
    $stmt->bindParam(":alimentos_rechazo", $data->alimentos_rechazo);
    $stmt->bindParam(":tipo_dieta_preferencia", $data->tipo_dieta_preferencia);
    $stmt->bindParam(":cantidad_agua_diaria", $data->cantidad_agua_diaria);
    $stmt->bindParam(":picar_entre_horas", $data->picar_entre_horas);
    $stmt->bindParam(":hora_dia_mas_apetito", $data->hora_dia_mas_apetito);
    $stmt->bindParam(":antojo_dulce_salado", $data->antojo_dulce_salado);
    $stmt->bindParam(":patologia", $data->patologia);
    $stmt->bindParam(":antecedentes_enfermedades", $data->antecedentes_enfermedades);
    $stmt->bindParam(":tipo_medicacion", $data->tipo_medicacion);
    $stmt->bindParam(":tipo_suplemento", $data->tipo_suplemento);
    $stmt->bindParam(":intolerancia_alergia", $data->intolerancia_alergia);
    $stmt->bindParam(":hambre_emocional", $data->hambre_emocional);
    $stmt->bindParam(":estres_ansiedad", $data->estres_ansiedad);
    $stmt->bindParam(":relacion_comida", $data->relacion_comida);
    $stmt->bindParam(":ciclo_menstrual", $data->ciclo_menstrual);
    $stmt->bindParam(":lactancia", $data->lactancia);
    $stmt->bindParam(":24_horas_desayuno", $data->{'24_horas_desayuno'});
    $stmt->bindParam(":24_horas_almuerzo", $data->{'24_horas_almuerzo'});
    $stmt->bindParam(":24_horas_comida", $data->{'24_horas_comida'});
    $stmt->bindParam(":24_horas_merienda", $data->{'24_horas_merienda'});
    $stmt->bindParam(":24_horas_cena", $data->{'24_horas_cena'});
    $stmt->bindParam(":24_horas_recena", $data->{'24_horas_recena'});
    $stmt->bindParam(":pesar_alimentos", $data->pesar_alimentos);
    $stmt->bindParam(":resultados_bascula", $data->resultados_bascula);
    $stmt->bindParam(":gusta_cocinar", $data->gusta_cocinar);
    $stmt->bindParam(":establecimiento_compra", $data->establecimiento_compra);
}

function create_entrevista() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;
    
    $query = "INSERT INTO nu_paciente_entrevista SET
                codigo_paciente = :codigo_paciente, fecha_realizacion = :fecha_realizacion, completada = :completada, 
                fecha_prevista = :fecha_prevista, online = :online, peso = :peso, motivo = :motivo, 
                objetivos = :objetivos, dietas_anteriores = :dietas_anteriores, ocupacion_horario = :ocupacion_horario, 
                deporte_frecuencia = :deporte_frecuencia, actividad_fisica = :actividad_fisica, fumador = :fumador, 
                alcohol = :alcohol, sueno = :sueno, horario_laboral_comidas = :horario_laboral_comidas, 
                comidas_dia = :comidas_dia, horario_comidas_regular = :horario_comidas_regular, lugar_comidas = :lugar_comidas, 
                quien_compra_casa = :quien_compra_casa, bebida_comida = :bebida_comida, 
                preferencias_alimentarias = :preferencias_alimentarias, alimentos_rechazo = :alimentos_rechazo, 
                tipo_dieta_preferencia = :tipo_dieta_preferencia, cantidad_agua_diaria = :cantidad_agua_diaria, 
                picar_entre_horas = :picar_entre_horas, hora_dia_mas_apetito = :hora_dia_mas_apetito, 
                antojo_dulce_salado = :antojo_dulce_salado, patologia = :patologia, 
                antecedentes_enfermedades = :antecedentes_enfermedades, tipo_medicacion = :tipo_medicacion, 
                tipo_suplemento = :tipo_suplemento, intolerancia_alergia = :intolerancia_alergia, 
                hambre_emocional = :hambre_emocional, estres_ansiedad = :estres_ansiedad, relacion_comida = :relacion_comida, 
                ciclo_menstrual = :ciclo_menstrual, lactancia = :lactancia, `24_horas_desayuno` = :24_horas_desayuno, 
                `24_horas_almuerzo` = :24_horas_almuerzo, `24_horas_comida` = :24_horas_comida, 
                `24_horas_merienda` = :24_horas_merienda, `24_horas_cena` = :24_horas_cena, `24_horas_recena` = :24_horas_recena, 
                pesar_alimentos = :pesar_alimentos, resultados_bascula = :resultados_bascula, gusta_cocinar = :gusta_cocinar, 
                establecimiento_compra = :establecimiento_compra, fechaa = NOW(), codusuarioa = :codusuarioa";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codusuarioa", $codusuarioa);
    bind_entrevista_params($stmt, $data);
    
    if($stmt->execute()){
        http_response_code(201);
        echo json_encode(array("message" => "Entrevista creada."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo crear la entrevista.", "errorInfo" => $stmt->errorInfo()));
    }
}

function update_entrevista() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código de la entrevista."));
        return;
    }
    
    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;
    
    $query = "UPDATE nu_paciente_entrevista SET
                codigo_paciente = :codigo_paciente, fecha_realizacion = :fecha_realizacion, completada = :completada, 
                fecha_prevista = :fecha_prevista, online = :online, peso = :peso, motivo = :motivo, 
                objetivos = :objetivos, dietas_anteriores = :dietas_anteriores, ocupacion_horario = :ocupacion_horario, 
                deporte_frecuencia = :deporte_frecuencia, actividad_fisica = :actividad_fisica, fumador = :fumador, 
                alcohol = :alcohol, sueno = :sueno, horario_laboral_comidas = :horario_laboral_comidas, 
                comidas_dia = :comidas_dia, horario_comidas_regular = :horario_comidas_regular, lugar_comidas = :lugar_comidas, 
                quien_compra_casa = :quien_compra_casa, bebida_comida = :bebida_comida, 
                preferencias_alimentarias = :preferencias_alimentarias, alimentos_rechazo = :alimentos_rechazo, 
                tipo_dieta_preferencia = :tipo_dieta_preferencia, cantidad_agua_diaria = :cantidad_agua_diaria, 
                picar_entre_horas = :picar_entre_horas, hora_dia_mas_apetito = :hora_dia_mas_apetito, 
                antojo_dulce_salado = :antojo_dulce_salado, patologia = :patologia, 
                antecedentes_enfermedades = :antecedentes_enfermedades, tipo_medicacion = :tipo_medicacion, 
                tipo_suplemento = :tipo_suplemento, intolerancia_alergia = :intolerancia_alergia, 
                hambre_emocional = :hambre_emocional, estres_ansiedad = :estres_ansiedad, relacion_comida = :relacion_comida, 
                ciclo_menstrual = :ciclo_menstrual, lactancia = :lactancia, `24_horas_desayuno` = :24_horas_desayuno, 
                `24_horas_almuerzo` = :24_horas_almuerzo, `24_horas_comida` = :24_horas_comida, 
                `24_horas_merienda` = :24_horas_merienda, `24_horas_cena` = :24_horas_cena, `24_horas_recena` = :24_horas_recena, 
                pesar_alimentos = :pesar_alimentos, resultados_bascula = :resultados_bascula, gusta_cocinar = :gusta_cocinar, 
                establecimiento_compra = :establecimiento_compra, fecham = NOW(), codusuariom = :codusuariom
              WHERE codigo = :codigo";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);
    $stmt->bindParam(":codusuariom", $codusuariom);
    bind_entrevista_params($stmt, $data);

    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Entrevista actualizada."));
    } else{
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo actualizar la entrevista.", "errorInfo" => $stmt->errorInfo()));
    }
}

function delete_entrevista() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if(empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta el código de la entrevista."));
        return;
    }

    $query = "DELETE FROM nu_paciente_entrevista WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    
    $stmt->bindParam(":codigo", $data->codigo);

    if($stmt->execute()){
        http_response_code(200);
        echo json_encode(array("message" => "Entrevista eliminada."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "No se pudo eliminar la entrevista."));
    }
}
?>