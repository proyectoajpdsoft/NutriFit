<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS");
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

$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'entrenamientos');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? null;

switch ($method) {
    case 'GET':
        if ($action === 'unread_comments') {
            get_unread_comments();
        } elseif ($action === 'unread_sensaciones_nutri') {
            get_unread_sensaciones_nutri();
        } elseif (isset($_GET['codigo_entrenamiento'])) {
            get_ejercicios_entrenamiento(intval($_GET['codigo_entrenamiento']));
        } else {
            http_response_code(400);
            echo json_encode(["message" => "Parametros insuficientes."]);
        }
        break;
    case 'POST':
        if ($action === 'mark_read') {
            mark_comment_read();
        } elseif ($action === 'mark_sensaciones_read') {
            mark_sensaciones_read();
        } else {
            save_ejercicios_entrenamiento();
        }
        break;
    case 'PUT':
        if ($action === 'update_comment') {
            update_comment();
        } else {
            http_response_code(400);
            echo json_encode(["message" => "Accion no reconocida."]);
        }
        break;
    default:
        http_response_code(405);
        echo json_encode(["message" => "Método no permitido."]);
        break;
}

function get_ejercicios_entrenamiento($codigo_entrenamiento) {
    global $db;
    $query = "SELECT e.codigo, e.codigo_entrenamiento, e.codigo_plan_fit_ejercicio, e.nombre, e.instrucciones, e.url_video,
               pfe.codigo_ejercicio_catalogo,
               NULL AS foto,
               COALESCE(c.foto_miniatura, pfe.foto_miniatura) AS foto_miniatura,
                     e.tiempo_plan, e.descanso_plan, e.repeticiones_plan, e.kilos_plan, e.esfuerzo_percibido, e.tiempo_realizado, e.repeticiones_realizadas,
                     e.sensaciones, e.comentario_nutricionista, e.comentario_leido, e.comentario_leido_fecha,
                     e.sensaciones_leido_nutri, e.sensaciones_leido_nutri_fecha, e.realizado, e.orden
              FROM nu_entrenamientos_ejercicios e
              LEFT JOIN nu_plan_fit_ejercicio pfe ON e.codigo_plan_fit_ejercicio = pfe.codigo
          LEFT JOIN nu_plan_fit_ejercicios_catalogo c ON c.codigo = pfe.codigo_ejercicio_catalogo
              WHERE e.codigo_entrenamiento = :codigo_entrenamiento
              ORDER BY e.orden DESC, e.codigo DESC";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_entrenamiento', $codigo_entrenamiento, PDO::PARAM_INT);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($items as &$item) {
        if (!empty($item['foto_miniatura'])) {
            $item['foto_miniatura'] = base64_encode($item['foto_miniatura']);
        }
    }

    ob_clean();
    echo json_encode($items ?? []);
}

function get_unread_comments() {
    global $db, $user;

    $codigo_paciente = $user['codigo_paciente'] ?? null;
    if (!$codigo_paciente) {
        http_response_code(200);
        echo json_encode([]);
        return;
    }

        $query = "SELECT e.codigo AS codigo_ejercicio,
                         e.codigo_entrenamiento,
                         e.codigo_plan_fit_ejercicio,
                         e.nombre AS nombre_ejercicio,
                         e.comentario_nutricionista,
                         e.sensaciones,
                         e.tiempo_realizado,
                         e.repeticiones_realizadas,
                         e.tiempo_plan,
                         e.repeticiones_plan,
                         e.kilos_plan,
                         pfe.foto,
                         pfe.foto_miniatura,
                         en.actividad,
                         en.fecha,
                         en.duracion_horas,
                         en.duracion_minutos,
                         en.nivel_esfuerzo
                            FROM nu_entrenamientos_ejercicios e
                            INNER JOIN nu_entrenamientos en ON en.codigo = e.codigo_entrenamiento
                            LEFT JOIN nu_plan_fit_ejercicio pfe ON e.codigo_plan_fit_ejercicio = pfe.codigo
                            WHERE en.codigo_paciente = :codigo_paciente
                                AND e.comentario_nutricionista IS NOT NULL
                                AND e.comentario_nutricionista <> ''
                                AND (e.comentario_leido IS NULL OR e.comentario_leido = 0)
                            ORDER BY en.fecha DESC";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($items as &$item) {
        if (!empty($item['foto'])) {
            $item['foto'] = base64_encode($item['foto']);
        }
        if (!empty($item['foto_miniatura'])) {
            $item['foto_miniatura'] = base64_encode($item['foto_miniatura']);
        }
    }

    ob_clean();
    echo json_encode($items ?? []);
}

function get_unread_sensaciones_nutri() {
        global $db, $user;

        if ($user['tipo'] !== 'Nutricionista' && $user['tipo'] !== 'Administrador') {
                http_response_code(403);
                echo json_encode(["message" => "No autorizado."]);
                return;
        }

        $query = "SELECT e.codigo AS codigo_ejercicio,
                         e.codigo_entrenamiento,
                         e.codigo_plan_fit_ejercicio,
                         e.nombre AS nombre_ejercicio,
                         e.sensaciones,
                         e.tiempo_realizado,
                         e.repeticiones_realizadas,
                         e.tiempo_plan,
                         e.repeticiones_plan,
                         e.kilos_plan,
                         pfe.foto,
                         pfe.foto_miniatura,
                         en.actividad,
                         en.fecha,
                         en.duracion_horas,
                         en.duracion_minutos,
                         en.nivel_esfuerzo,
                         p.codigo AS codigo_paciente,
                         p.nombre AS nombre_paciente,
                                                 (
                                                     SELECT u.img_perfil
                                                     FROM usuario u
                                                     WHERE u.codigo_paciente = p.codigo
                                                         AND u.img_perfil IS NOT NULL
                                                     LIMIT 1
                                                 ) AS usuario_img_perfil
                            FROM nu_entrenamientos_ejercicios e
                            INNER JOIN nu_entrenamientos en ON en.codigo = e.codigo_entrenamiento
                            LEFT JOIN nu_paciente p ON p.codigo = en.codigo_paciente
                            LEFT JOIN nu_plan_fit_ejercicio pfe ON e.codigo_plan_fit_ejercicio = pfe.codigo
                            WHERE e.sensaciones IS NOT NULL
                                AND e.sensaciones <> ''
                                AND (e.sensaciones_leido_nutri IS NULL OR e.sensaciones_leido_nutri = 0)
                            ORDER BY en.fecha DESC";

        $stmt = $db->prepare($query);
        $stmt->execute();
        $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Codificar imágenes en base64
        foreach ($items as &$item) {
            if (!empty($item['foto_miniatura'])) {
                $item['foto_miniatura'] = base64_encode($item['foto_miniatura']);
            }
            if (!empty($item['foto'])) {
                $item['foto'] = base64_encode($item['foto']);
            }
            if (!empty($item['usuario_img_perfil'])) {
                $item['usuario_img_perfil'] = base64_encode($item['usuario_img_perfil']);
            }
        }

        ob_clean();
        echo json_encode($items ?? []);
}

function update_comment() {
    global $db, $user;

    if ($user['tipo'] !== 'Nutricionista' && $user['tipo'] !== 'Administrador') {
        http_response_code(403);
        echo json_encode(["message" => "No autorizado."]);
        return;
    }

    $codigo = $_GET['codigo'] ?? null;
    $data = json_decode(file_get_contents("php://input"), true);
    $comentario = trim($data['comentario_nutricionista'] ?? '');

    if (!$codigo) {
        http_response_code(400);
        echo json_encode(["message" => "Codigo requerido."]);
        return;
    }

    $query = "UPDATE nu_entrenamientos_ejercicios
              SET comentario_nutricionista = :comentario,
                  comentario_leido = 0,
                  comentario_leido_fecha = NULL
              WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':comentario', $comentario);
    $stmt->bindParam(':codigo', $codigo);

    if ($stmt->execute()) {
        http_response_code(200);
        echo json_encode(["success" => true]);
        return;
    }

    http_response_code(500);
    echo json_encode(["message" => "Error al actualizar comentario."]);
}

function mark_comment_read() {
    global $db, $user;

    $codigo = $_GET['codigo'] ?? null;
    if (!$codigo) {
        http_response_code(400);
        echo json_encode(["message" => "Codigo requerido."]);
        return;
    }

    $codigo_paciente = $user['codigo_paciente'] ?? null;
    if (!$codigo_paciente) {
        http_response_code(403);
        echo json_encode(["message" => "No autorizado."]);
        return;
    }

    $query = "UPDATE nu_entrenamientos_ejercicios e
              INNER JOIN nu_entrenamientos en ON en.codigo = e.codigo_entrenamiento
              SET e.comentario_leido = 1,
                  e.comentario_leido_fecha = NOW()
              WHERE e.codigo = :codigo
                AND en.codigo_paciente = :codigo_paciente";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->bindParam(':codigo_paciente', $codigo_paciente);

    if ($stmt->execute()) {
        http_response_code(200);
        echo json_encode(["success" => true]);
        return;
    }

    http_response_code(500);
    echo json_encode(["message" => "Error al marcar como leido."]);
}

function mark_sensaciones_read() {
    global $db, $user;

    if ($user['tipo'] !== 'Nutricionista' && $user['tipo'] !== 'Administrador') {
        http_response_code(403);
        echo json_encode(["message" => "No autorizado."]);
        return;
    }

    $codigo = $_GET['codigo'] ?? null;
    if (!$codigo) {
        http_response_code(400);
        echo json_encode(["message" => "Codigo requerido."]);
        return;
    }

    $query = "UPDATE nu_entrenamientos_ejercicios
              SET sensaciones_leido_nutri = 1,
                  sensaciones_leido_nutri_fecha = NOW()
              WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);

    if ($stmt->execute()) {
        http_response_code(200);
        echo json_encode(["success" => true]);
        return;
    }

    http_response_code(500);
    echo json_encode(["message" => "Error al marcar sensaciones como leidas."]);
}

function save_ejercicios_entrenamiento() {
    global $db;
    $data = json_decode(file_get_contents("php://input"), true);

    $codigo_entrenamiento = $data['codigo_entrenamiento'] ?? null;
    $ejercicios = $data['ejercicios'] ?? [];

    if (!$codigo_entrenamiento) {
        http_response_code(400);
        echo json_encode(["message" => "Falta codigo_entrenamiento."]);
        return;
    }

    // Limpiar existentes
    $delete = $db->prepare("DELETE FROM nu_entrenamientos_ejercicios WHERE codigo_entrenamiento = :codigo_entrenamiento");
    $delete->bindParam(':codigo_entrenamiento', $codigo_entrenamiento);
    if (!$delete->execute()) {
        http_response_code(500);
        echo json_encode(["message" => "Error al limpiar ejercicios anteriores.", "error" => $delete->errorInfo()]);
        return;
    }

    if (!is_array($ejercicios) || empty($ejercicios)) {
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Ejercicios guardados."]);
        return;
    }

    $insert = $db->prepare(
        "INSERT INTO nu_entrenamientos_ejercicios (codigo_entrenamiento, codigo_plan_fit_ejercicio, nombre, instrucciones, url_video,
            tiempo_plan, descanso_plan, repeticiones_plan, kilos_plan, esfuerzo_percibido, tiempo_realizado, repeticiones_realizadas, sensaciones,
            comentario_nutricionista, comentario_leido, comentario_leido_fecha, sensaciones_leido_nutri, sensaciones_leido_nutri_fecha,
            realizado, orden)
        VALUES (:codigo_entrenamiento, :codigo_plan_fit_ejercicio, :nombre, :instrucciones, :url_video,
            :tiempo_plan, :descanso_plan, :repeticiones_plan, :kilos_plan, :esfuerzo_percibido, :tiempo_realizado, :repeticiones_realizadas, :sensaciones,
            :comentario_nutricionista, :comentario_leido, :comentario_leido_fecha, :sensaciones_leido_nutri, :sensaciones_leido_nutri_fecha,
            :realizado, :orden)"
    );

    $totalInsertados = 0;
    $errores = [];
    foreach ($ejercicios as $index => $e) {
        $insert->bindValue(':codigo_entrenamiento', $codigo_entrenamiento, PDO::PARAM_INT);
        $insert->bindValue(':codigo_plan_fit_ejercicio', $e['codigo_plan_fit_ejercicio'] ?? null, $e['codigo_plan_fit_ejercicio'] ? PDO::PARAM_INT : PDO::PARAM_NULL);
        $insert->bindValue(':nombre', $e['nombre'] ?? '', PDO::PARAM_STR);
        $insert->bindValue(':instrucciones', $e['instrucciones'] ?? null, PDO::PARAM_STR);
        $insert->bindValue(':url_video', $e['url_video'] ?? null, PDO::PARAM_STR);
        $insert->bindValue(':tiempo_plan', $e['tiempo_plan'] ?? null, $e['tiempo_plan'] ? PDO::PARAM_INT : PDO::PARAM_NULL);
        $insert->bindValue(':descanso_plan', $e['descanso_plan'] ?? null, $e['descanso_plan'] ? PDO::PARAM_INT : PDO::PARAM_NULL);
        $insert->bindValue(':repeticiones_plan', $e['repeticiones_plan'] ?? null, $e['repeticiones_plan'] ? PDO::PARAM_INT : PDO::PARAM_NULL);
        $insert->bindValue(':kilos_plan', $e['kilos_plan'] ?? null, $e['kilos_plan'] ? PDO::PARAM_INT : PDO::PARAM_NULL);
        $insert->bindValue(':esfuerzo_percibido', $e['esfuerzo_percibido'] ?? null, $e['esfuerzo_percibido'] ? PDO::PARAM_INT : PDO::PARAM_NULL);
        $insert->bindValue(':tiempo_realizado', $e['tiempo_realizado'] ?? null, $e['tiempo_realizado'] ? PDO::PARAM_INT : PDO::PARAM_NULL);
        $insert->bindValue(':repeticiones_realizadas', $e['repeticiones_realizadas'] ?? null, $e['repeticiones_realizadas'] ? PDO::PARAM_INT : PDO::PARAM_NULL);
        $sensaciones = trim($e['sensaciones'] ?? '');
        $insert->bindValue(':sensaciones', $sensaciones !== '' ? $sensaciones : null, PDO::PARAM_STR);
        $insert->bindValue(':comentario_nutricionista', $e['comentario_nutricionista'] ?? null, PDO::PARAM_STR);
        $insert->bindValue(':comentario_leido', $e['comentario_leido'] ?? 0, PDO::PARAM_INT);
        $insert->bindValue(':comentario_leido_fecha', $e['comentario_leido_fecha'] ?? null, PDO::PARAM_STR);
        $insert->bindValue(':sensaciones_leido_nutri', $sensaciones !== '' ? 0 : null, $sensaciones !== '' ? PDO::PARAM_INT : PDO::PARAM_NULL);
        $insert->bindValue(':sensaciones_leido_nutri_fecha', null, PDO::PARAM_STR);
        $insert->bindValue(':realizado', $e['realizado'] ?? 'N', PDO::PARAM_STR);
        $insert->bindValue(':orden', $e['orden'] ?? 0, PDO::PARAM_INT);

        if ($insert->execute()) {
            $totalInsertados++;
        } else {
            $errores[] = [
                "index" => $index,
                "nombre" => $e['nombre'] ?? 'sin nombre',
                "error" => $insert->errorInfo()
            ];
        }
    }

    if (!empty($errores)) {
        http_response_code(500);
        echo json_encode(["message" => "Error al guardar ejercicios", "errores" => $errores, "insertados" => $totalInsertados]);
        return;
    }

    http_response_code(200);
    ob_clean();
    echo json_encode(["message" => "Ejercicios guardados.", "total" => $totalInsertados]);
}
?>
