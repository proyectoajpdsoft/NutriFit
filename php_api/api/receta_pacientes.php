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
PermissionManager::checkPermission($user, 'recetas');

switch($request_method) {
    case 'GET':
        if(isset($_GET["receta"])) {
            get_pacientes_by_receta($_GET["receta"]);
        } else if(isset($_GET["paciente"]) && isset($_GET["receta_codigo"])) {
            get_receta_paciente($_GET["paciente"], $_GET["receta_codigo"]);
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
        if(isset($_GET["receta"]) && isset($_GET["paciente"])) {
            remove_paciente($_GET["receta"], $_GET["paciente"]);
        }
        break;
    default:
        http_response_code(405);
        echo json_encode(array("message" => "Método no permitido."));
        break;
}

function get_pacientes_by_receta($receta_codigo) {
    global $db;

    $query = "SELECT rp.*, p.nombre
              FROM nu_receta_paciente rp
              INNER JOIN nu_paciente p ON rp.codigo_paciente = p.codigo
              WHERE rp.codigo_receta = :receta
              ORDER BY p.nombre";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':receta', $receta_codigo);
    $stmt->execute();
    $pacientes = $stmt->fetchAll(PDO::FETCH_ASSOC);

    ob_clean();
    echo json_encode($pacientes);
}

function get_receta_paciente($paciente_codigo, $receta_codigo) {
    global $db;

    $query = "SELECT * FROM nu_receta_paciente 
              WHERE codigo_paciente = :paciente AND codigo_receta = :receta";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':paciente', $paciente_codigo);
    $stmt->bindParam(':receta', $receta_codigo);
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

    if(empty($data->codigo_receta)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta codigo_receta."));
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

    $delete_query = "DELETE FROM nu_receta_paciente WHERE codigo_receta = :receta";
    $delete_stmt = $db->prepare($delete_query);
    $delete_stmt->bindParam(':receta', $data->codigo_receta);
    $delete_stmt->execute();

    $query = "INSERT INTO nu_receta_paciente SET
                codigo_receta = :codigo_receta,
                codigo_paciente = :codigo_paciente,
                me_gusta = 'N',
                favorito = 'N',
                leido = 'N',
                fechaa = NOW(),
                codusuarioa = :codusuarioa";

    $stmt = $db->prepare($query);

    foreach($data->codigos_pacientes as $codigo_paciente) {
        $stmt->bindParam(":codigo_receta", $data->codigo_receta);
        $stmt->bindParam(":codigo_paciente", $codigo_paciente);
        $stmt->bindParam(":codusuarioa", $codusuarioa);

        if($stmt->execute()) {
            $success_count++;
        } else {
            $error_count++;
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

    if(empty($data->codigo_receta) || empty($data->codigo_paciente)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Faltan datos requeridos."));
        return;
    }

    $check_query = "SELECT codigo, me_gusta FROM nu_receta_paciente 
                    WHERE codigo_receta = :receta AND codigo_paciente = :paciente";
    $check_stmt = $db->prepare($check_query);
    $check_stmt->bindParam(':receta', $data->codigo_receta);
    $check_stmt->bindParam(':paciente', $data->codigo_paciente);
    $check_stmt->execute();
    $existing = $check_stmt->fetch(PDO::FETCH_ASSOC);

    if(!$existing) {
        $insert_query = "INSERT INTO nu_receta_paciente SET
                        codigo_receta = :codigo_receta,
                        codigo_paciente = :codigo_paciente,
                        me_gusta = 'S',
                        favorito = 'N',
                        leido = 'N',
                        fecha_me_gusta = NOW(),
                        fechaa = NOW(),
                        codusuarioa = 1";

        $insert_stmt = $db->prepare($insert_query);
        $insert_stmt->bindParam(':codigo_receta', $data->codigo_receta);
        $insert_stmt->bindParam(':codigo_paciente', $data->codigo_paciente);

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

    $new_value = $existing['me_gusta'] == 'S' ? 'N' : 'S';
    $fecha_me_gusta = $new_value == 'S' ? date('Y-m-d H:i:s') : null;

    $update_query = "UPDATE nu_receta_paciente SET 
                    me_gusta = :me_gusta,
                    fecha_me_gusta = :fecha_me_gusta,
                    fecham = NOW()
                    WHERE codigo = :codigo";

    $update_stmt = $db->prepare($update_query);
    $update_stmt->bindParam(':me_gusta', $new_value);
    $update_stmt->bindParam(':fecha_me_gusta', $fecha_me_gusta);
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

function remove_paciente($receta_codigo, $paciente_codigo) {
    global $db;

    $query = "DELETE FROM nu_receta_paciente WHERE codigo_receta = :receta AND codigo_paciente = :paciente";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':receta', $receta_codigo);
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

    if(empty($data->codigo_receta) || empty($data->codigo_paciente)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Faltan datos requeridos."));
        return;
    }

    $check_query = "SELECT codigo, leido FROM nu_receta_paciente 
                    WHERE codigo_receta = :receta AND codigo_paciente = :paciente";
    $check_stmt = $db->prepare($check_query);
    $check_stmt->bindParam(':receta', $data->codigo_receta);
    $check_stmt->bindParam(':paciente', $data->codigo_paciente);
    $check_stmt->execute();
    $existing = $check_stmt->fetch(PDO::FETCH_ASSOC);

    if(!$existing) {
        $insert_query = "INSERT INTO nu_receta_paciente SET
                        codigo_receta = :codigo_receta,
                        codigo_paciente = :codigo_paciente,
                        me_gusta = 'N',
                        favorito = 'N',
                        leido = 'S',
                        fechaa = NOW(),
                        codusuarioa = 1";

        $insert_stmt = $db->prepare($insert_query);
        $insert_stmt->bindParam(':codigo_receta', $data->codigo_receta);
        $insert_stmt->bindParam(':codigo_paciente', $data->codigo_paciente);

        if($insert_stmt->execute()) {
            http_response_code(200);
            ob_clean();
            echo json_encode(array(
                "message" => "Receta marcada como leída.",
                "leido" => "S"
            ));
        } else {
            http_response_code(503);
            ob_clean();
            echo json_encode(array("message" => "No se pudo crear el registro para marcar leído."));
        }
        return;
    }

    $update_query = "UPDATE nu_receta_paciente SET 
                    leido = 'S',
                    fecham = NOW()
                    WHERE codigo = :codigo";

    $update_stmt = $db->prepare($update_query);
    $update_stmt->bindParam(':codigo', $existing['codigo']);

    if($update_stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(array(
            "message" => "Receta marcada como leída.",
            "leido" => "S"
        ));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo marcar como leída."));
    }
}

function get_destacados_no_leidos($paciente_codigo) {
    global $db;

    $query = "SELECT r.*, rp.me_gusta, rp.leido,
              (SELECT COUNT(*) FROM nu_receta_paciente rp2 WHERE rp2.codigo_receta = r.codigo AND rp2.me_gusta = 'S') as total_likes
              FROM nu_receta r
              INNER JOIN nu_receta_paciente rp ON r.codigo = rp.codigo_receta
              WHERE rp.codigo_paciente = :paciente
              AND r.mostrar_portada = 'S'
              AND rp.leido = 'N'
              ORDER BY r.fechaa DESC";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':paciente', $paciente_codigo);
    $stmt->execute();
    $recetas = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($recetas as &$receta) {
        if ($receta['imagen_portada']) {
            $receta['imagen_portada'] = base64_encode($receta['imagen_portada']);
        }
    }

    ob_clean();
    echo json_encode($recetas);
}

function get_favoritos($paciente_codigo) {
    global $db;

    $query = "SELECT r.*, rp.me_gusta, rp.leido, rp.favorito,
              (SELECT COUNT(*) FROM nu_receta_paciente rp2 WHERE rp2.codigo_receta = r.codigo AND rp2.me_gusta = 'S') as total_likes
              FROM nu_receta r
              INNER JOIN nu_receta_paciente rp ON r.codigo = rp.codigo_receta
              WHERE rp.codigo_paciente <=> :paciente
              AND rp.favorito = 'S'
              ORDER BY r.fechaa DESC";

    $stmt = $db->prepare($query);
    // Convertir 'null' string a null real
    $paciente_real = ($paciente_codigo === 'null' || $paciente_codigo === null) ? null : $paciente_codigo;
    $stmt->bindParam(':paciente', $paciente_real);
    $stmt->execute();
    $recetas = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($recetas as &$receta) {
        if ($receta['imagen_portada']) {
            $receta['imagen_portada'] = base64_encode($receta['imagen_portada']);
        }
    }

    ob_clean();
    echo json_encode($recetas);
}

function toggle_favorito() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo_receta)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta codigo_receta."));
        return;
    }

    // codigo_paciente puede ser null para usuarios sin paciente
    $codigo_paciente = isset($data->codigo_paciente) ? $data->codigo_paciente : null;

    // Usar operador NULL-safe para comparar
    $check_query = "SELECT codigo, favorito FROM nu_receta_paciente 
                    WHERE codigo_receta = :receta AND codigo_paciente <=> :paciente";
    $check_stmt = $db->prepare($check_query);
    $check_stmt->bindParam(':receta', $data->codigo_receta);
    $check_stmt->bindParam(':paciente', $codigo_paciente);
    $check_stmt->execute();
    $existing = $check_stmt->fetch(PDO::FETCH_ASSOC);

    if(!$existing) {
        $insert_query = "INSERT INTO nu_receta_paciente SET
                        codigo_receta = :codigo_receta,
                        codigo_paciente = :codigo_paciente,
                        me_gusta = 'N',
                        favorito = 'S',
                        fecha_favorito = NOW(),
                        leido = 'N',
                        fechaa = NOW(),
                        codusuarioa = 1";

        $insert_stmt = $db->prepare($insert_query);
        $insert_stmt->bindParam(':codigo_receta', $data->codigo_receta);
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

    $new_value = ($existing['favorito'] == 'S') ? 'N' : 'S';
    $fecha_favorito = $new_value == 'S' ? date('Y-m-d H:i:s') : null;

    // Construir query con NULL directo si es necesario
    $update_query = "UPDATE nu_receta_paciente SET 
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
?>
