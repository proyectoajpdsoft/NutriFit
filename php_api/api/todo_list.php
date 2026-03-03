<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

ini_set('display_errors', 0);
error_reporting(E_ALL);

require_once '../config/database.php';
require_once '../auth/token_validator.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

if (!$db) {
    http_response_code(500);
    echo json_encode(array("message" => "Error de conexión a la base de datos"));
    exit();
}

$validator = new TokenValidator($db);
$user = $validator->validateToken();
$codigo_usuario_auth = intval($user['codigo'] ?? 0);

if ($codigo_usuario_auth <= 0) {
    http_response_code(401);
    echo json_encode(array("message" => "Usuario inválido"));
    exit();
}

$method = $_SERVER['REQUEST_METHOD'];

function normalize_estado($value) {
    $estado = strtoupper(trim((string)$value));
    return $estado === 'R' ? 'R' : 'P';
}

function normalize_prioridad($value) {
    $prioridad = strtoupper(trim((string)$value));
    if ($prioridad === 'A' || $prioridad === 'B') {
        return $prioridad;
    }
    return 'M';
}

function normalize_fecha_tarea($value) {
    $raw = trim((string)$value);
    if ($raw === '') {
        return null;
    }

    if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $raw)) {
        return $raw;
    }

    $ts = strtotime($raw);
    if ($ts === false) {
        return null;
    }

    return date('Y-m-d', $ts);
}

function get_tareas($db, $codigo_usuario, $estado = null, $year = null, $month = null) {
    $query = "SELECT codigo, codigo_usuario, titulo, descripcion, fecha_tarea, estado, prioridad, fecha_resuelta, fechaa, fecham
              FROM nu_todo_list
              WHERE codigo_usuario = :codigo_usuario";

    $params = array(':codigo_usuario' => $codigo_usuario);

    if (!empty($estado) && ($estado === 'P' || $estado === 'R')) {
        $query .= " AND estado = :estado";
        $params[':estado'] = $estado;
    }

    if (!empty($year) && !empty($month)) {
        $query .= " AND fecha_tarea IS NOT NULL AND YEAR(fecha_tarea) = :year AND MONTH(fecha_tarea) = :month";
        $params[':year'] = intval($year);
        $params[':month'] = intval($month);
    }

    $query .= " ORDER BY
                CASE WHEN estado = 'P' THEN 0 ELSE 1 END,
                CASE prioridad WHEN 'A' THEN 0 WHEN 'M' THEN 1 ELSE 2 END,
                fecha_tarea IS NULL,
                fecha_tarea ASC,
                codigo DESC";

    $stmt = $db->prepare($query);
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }

    $stmt->execute();
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

function get_tarea($db, $codigo_usuario, $codigo) {
    $query = "SELECT codigo, codigo_usuario, titulo, descripcion, fecha_tarea, estado, prioridad, fecha_resuelta, fechaa, fecham
              FROM nu_todo_list
              WHERE codigo = :codigo AND codigo_usuario = :codigo_usuario
              LIMIT 1";

    $stmt = $db->prepare($query);
    $stmt->bindValue(':codigo', intval($codigo), PDO::PARAM_INT);
    $stmt->bindValue(':codigo_usuario', intval($codigo_usuario), PDO::PARAM_INT);
    $stmt->execute();

    return $stmt->fetch(PDO::FETCH_ASSOC);
}

function create_tarea($db, $codigo_usuario, $data) {
    $titulo = trim((string)($data['titulo'] ?? ''));
    if ($titulo === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'El título es obligatorio.'));
        return;
    }

    $descripcion = isset($data['descripcion']) ? trim((string)$data['descripcion']) : null;
    if ($descripcion === '') {
        $descripcion = null;
    }

    $fecha_tarea = normalize_fecha_tarea($data['fecha_tarea'] ?? null);
    $estado = normalize_estado($data['estado'] ?? 'P');
    $prioridad = normalize_prioridad($data['prioridad'] ?? 'M');
    $codusuarioa = intval($codigo_usuario);

    $query = "INSERT INTO nu_todo_list
              (codigo_usuario, titulo, descripcion, fecha_tarea, estado, prioridad, fecha_resuelta, codusuarioa, fechaa)
              VALUES
              (:codigo_usuario, :titulo, :descripcion, :fecha_tarea, :estado, :prioridad,
               CASE WHEN :estado = 'R' THEN NOW() ELSE NULL END,
               :codusuarioa, NOW())";

    $stmt = $db->prepare($query);
    $stmt->bindValue(':codigo_usuario', intval($codigo_usuario), PDO::PARAM_INT);
    $stmt->bindValue(':titulo', $titulo);
    $stmt->bindValue(':descripcion', $descripcion);
    $stmt->bindValue(':fecha_tarea', $fecha_tarea);
    $stmt->bindValue(':estado', $estado);
    $stmt->bindValue(':prioridad', $prioridad);
    $stmt->bindValue(':codusuarioa', $codusuarioa, PDO::PARAM_INT);

    if (!$stmt->execute()) {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo crear la tarea.'));
        return;
    }

    $codigo = intval($db->lastInsertId());
    $creada = get_tarea($db, $codigo_usuario, $codigo);

    http_response_code(201);
    echo json_encode(array(
        'message' => 'Tarea creada correctamente.',
        'item' => $creada
    ));
}

function update_tarea($db, $codigo_usuario, $data) {
    $codigo = intval($data['codigo'] ?? 0);
    if ($codigo <= 0) {
        http_response_code(400);
        echo json_encode(array('message' => 'Falta el código de la tarea.'));
        return;
    }

    $actual = get_tarea($db, $codigo_usuario, $codigo);
    if (!$actual) {
        http_response_code(404);
        echo json_encode(array('message' => 'Tarea no encontrada.'));
        return;
    }

    $titulo = array_key_exists('titulo', $data)
        ? trim((string)$data['titulo'])
        : $actual['titulo'];

    if ($titulo === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'El título es obligatorio.'));
        return;
    }

    $descripcion = array_key_exists('descripcion', $data)
        ? trim((string)$data['descripcion'])
        : $actual['descripcion'];

    if ($descripcion === '') {
        $descripcion = null;
    }

    $fecha_tarea = array_key_exists('fecha_tarea', $data)
        ? normalize_fecha_tarea($data['fecha_tarea'])
        : $actual['fecha_tarea'];

    $estado = array_key_exists('estado', $data)
        ? normalize_estado($data['estado'])
        : normalize_estado($actual['estado']);

    $prioridad = array_key_exists('prioridad', $data)
        ? normalize_prioridad($data['prioridad'])
        : normalize_prioridad($actual['prioridad']);

    $codusuariom = intval($codigo_usuario);

    $query = "UPDATE nu_todo_list
              SET titulo = :titulo,
                  descripcion = :descripcion,
                  fecha_tarea = :fecha_tarea,
                  estado = :estado,
                  prioridad = :prioridad,
                  fecha_resuelta = CASE WHEN :estado = 'R' THEN COALESCE(fecha_resuelta, NOW()) ELSE NULL END,
                  fecham = NOW(),
                  codusuariom = :codusuariom
              WHERE codigo = :codigo AND codigo_usuario = :codigo_usuario";

    $stmt = $db->prepare($query);
    $stmt->bindValue(':titulo', $titulo);
    $stmt->bindValue(':descripcion', $descripcion);
    $stmt->bindValue(':fecha_tarea', $fecha_tarea);
    $stmt->bindValue(':estado', $estado);
    $stmt->bindValue(':prioridad', $prioridad);
    $stmt->bindValue(':codusuariom', $codusuariom, PDO::PARAM_INT);
    $stmt->bindValue(':codigo', $codigo, PDO::PARAM_INT);
    $stmt->bindValue(':codigo_usuario', $codigo_usuario, PDO::PARAM_INT);

    if (!$stmt->execute()) {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo actualizar la tarea.'));
        return;
    }

    $actualizada = get_tarea($db, $codigo_usuario, $codigo);

    http_response_code(200);
    echo json_encode(array(
        'message' => 'Tarea actualizada correctamente.',
        'item' => $actualizada
    ));
}

function delete_tarea($db, $codigo_usuario, $data) {
    $codigo = intval($data['codigo'] ?? 0);
    if ($codigo <= 0) {
        http_response_code(400);
        echo json_encode(array('message' => 'Falta el código de la tarea.'));
        return;
    }

    $query = "DELETE FROM nu_todo_list WHERE codigo = :codigo AND codigo_usuario = :codigo_usuario";
    $stmt = $db->prepare($query);
    $stmt->bindValue(':codigo', $codigo, PDO::PARAM_INT);
    $stmt->bindValue(':codigo_usuario', $codigo_usuario, PDO::PARAM_INT);

    if (!$stmt->execute()) {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo eliminar la tarea.'));
        return;
    }

    if ($stmt->rowCount() === 0) {
        http_response_code(404);
        echo json_encode(array('message' => 'Tarea no encontrada.'));
        return;
    }

    http_response_code(200);
    echo json_encode(array('message' => 'Tarea eliminada correctamente.'));
}

try {
    if ($method === 'GET') {
        if (!empty($_GET['codigo'])) {
            $item = get_tarea($db, $codigo_usuario_auth, intval($_GET['codigo']));
            if (!$item) {
                http_response_code(404);
                echo json_encode(array('message' => 'Tarea no encontrada.'));
            } else {
                http_response_code(200);
                echo json_encode($item);
            }
            exit();
        }

        $estado = isset($_GET['estado']) ? strtoupper(trim((string)$_GET['estado'])) : null;
        if ($estado === 'T') {
            $estado = null;
        }

        $year = isset($_GET['year']) ? intval($_GET['year']) : null;
        $month = isset($_GET['month']) ? intval($_GET['month']) : null;

        $items = get_tareas($db, $codigo_usuario_auth, $estado, $year, $month);
        http_response_code(200);
        echo json_encode($items);
        exit();
    }

    $raw = file_get_contents("php://input");
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = array();
    }

    if ($method === 'POST') {
        create_tarea($db, $codigo_usuario_auth, $data);
        exit();
    }

    if ($method === 'PUT') {
        update_tarea($db, $codigo_usuario_auth, $data);
        exit();
    }

    if ($method === 'DELETE') {
        delete_tarea($db, $codigo_usuario_auth, $data);
        exit();
    }

    http_response_code(405);
    echo json_encode(array('message' => 'Método no permitido.'));
} catch (Throwable $e) {
    error_log('todo_list.php error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(array('message' => 'Error interno del servidor.'));
}
