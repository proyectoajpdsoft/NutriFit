<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

ini_set('display_errors', 0);
error_reporting(E_ALL);

require_once '../config/database.php';
require_once '../auth/token_validator.php';
require_once '../auth/permissions.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

if (!$db) {
    http_response_code(500);
    echo json_encode(array("error" => "Error de conexión a la base de datos"));
    exit();
}

$validator = new TokenValidator($db);
$user = $validator->validateToken();

function check_adherencia_access($user) {
    if (($user['es_guest'] ?? false) === true) {
        http_response_code(403);
        echo json_encode(array(
            'error' => 'No tienes permiso para acceder a este recurso',
            'code' => 'PERMISSION_DENIED',
        ));
        exit();
    }
}

check_adherencia_access($user);

function resolve_user_code($user) {
    if (!empty($user['codigo'])) {
        return intval($user['codigo']);
    }
    return null;
}

function can_read_other_user($user) {
    if (($user['administrador'] ?? 'N') === 'S') {
        return true;
    }
    $tipo = strtolower(trim((string)($user['tipo'] ?? '')));
    return $tipo === 'nutricionista';
}

function can_write_other_user($user) {
    if (($user['administrador'] ?? 'N') === 'S') {
        return true;
    }
    $tipo = strtolower(trim((string)($user['tipo'] ?? '')));
    return $tipo === 'nutricionista';
}

function resolve_target_usuario_from_payload($db, $user, $codigo_usuario_default, $data) {
    $target_usuario = intval($codigo_usuario_default);

    if (isset($data['codigo_usuario']) && intval($data['codigo_usuario']) > 0) {
        $requested = intval($data['codigo_usuario']);
        if ($requested !== $target_usuario && !can_write_other_user($user)) {
            return array('ok' => false, 'status' => 403, 'message' => 'No tienes permiso para guardar adherencia de otro usuario.');
        }
        $target_usuario = $requested;
        return array('ok' => true, 'codigo_usuario' => $target_usuario);
    }

    if (isset($data['codigo_paciente']) && intval($data['codigo_paciente']) > 0) {
        $codigo_paciente = intval($data['codigo_paciente']);

        if (!can_write_other_user($user)) {
            $codigo_paciente_usuario = intval($user['codigo_paciente'] ?? 0);
            if ($codigo_paciente_usuario <= 0 || $codigo_paciente_usuario !== $codigo_paciente) {
                return array('ok' => false, 'status' => 403, 'message' => 'No tienes permiso para guardar adherencia por paciente.');
            }
        }

        $stmt = $db->prepare("SELECT codigo FROM usuario WHERE codigo_paciente = :codigo_paciente AND activo = 'S' LIMIT 1");
        $stmt->bindValue(':codigo_paciente', $codigo_paciente, PDO::PARAM_INT);
        $stmt->execute();
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$row || empty($row['codigo'])) {
            return array('ok' => false, 'status' => 404, 'message' => 'No se encontró usuario para el paciente indicado.');
        }

        $target_usuario = intval($row['codigo']);
    }

    return array('ok' => true, 'codigo_usuario' => $target_usuario);
}

function normalize_tipo($value) {
    $tipo = strtolower(trim((string)$value));
    return in_array($tipo, array('nutri', 'fit'), true) ? $tipo : null;
}

function normalize_estado($value) {
    $estado = strtolower(trim((string)$value));
    return in_array($estado, array('cumplido', 'parcial', 'no'), true) ? $estado : null;
}

function normalize_fecha($value) {
    $raw = trim((string)$value);
    if ($raw === '') {
        return date('Y-m-d');
    }

    if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $raw)) {
        return $raw;
    }

    $timestamp = strtotime($raw);
    if ($timestamp === false) {
        return null;
    }

    return date('Y-m-d', $timestamp);
}

function get_registros($db, $codigo_usuario, $fecha_desde = null, $fecha_hasta = null) {
    $query = "SELECT codigo, codigo_usuario, fecha, tipo, estado, observacion, fechaa, fecham
              FROM nu_adherencia_diaria
              WHERE codigo_usuario = :codigo_usuario";

    $params = array(':codigo_usuario' => intval($codigo_usuario));

    if (!empty($fecha_desde)) {
        $query .= " AND fecha >= :fecha_desde";
        $params[':fecha_desde'] = $fecha_desde;
    }

    if (!empty($fecha_hasta)) {
        $query .= " AND fecha <= :fecha_hasta";
        $params[':fecha_hasta'] = $fecha_hasta;
    }

    $query .= " ORDER BY fecha DESC, tipo ASC";

    $stmt = $db->prepare($query);
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->execute();

    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

function upsert_registro($db, $codigo_usuario_objetivo, $codigo_usuario_actor, $data) {
    $tipo = normalize_tipo($data['tipo'] ?? null);
    $estado = normalize_estado($data['estado'] ?? null);
    $fecha = normalize_fecha($data['fecha'] ?? null);
    $observacion = isset($data['observacion']) ? trim((string)$data['observacion']) : null;

    if (empty($tipo)) {
        http_response_code(400);
        echo json_encode(array('message' => 'Tipo no válido (nutri|fit).'));
        return;
    }

    if (empty($estado)) {
        http_response_code(400);
        echo json_encode(array('message' => 'Estado no válido (cumplido|parcial|no).'));
        return;
    }

    if (empty($fecha)) {
        http_response_code(400);
        echo json_encode(array('message' => 'Fecha no válida.'));
        return;
    }

    $query = "INSERT INTO nu_adherencia_diaria
                (codigo_usuario, fecha, tipo, estado, observacion, codusuarioa, fechaa)
              VALUES
                (:codigo_usuario, :fecha, :tipo, :estado, :observacion, :codusuarioa, NOW())
              ON DUPLICATE KEY UPDATE
                estado = VALUES(estado),
                observacion = VALUES(observacion),
                codusuariom = VALUES(codusuarioa),
                fecham = NOW()";

    $stmt = $db->prepare($query);
    $stmt->bindValue(':codigo_usuario', intval($codigo_usuario_objetivo), PDO::PARAM_INT);
    $stmt->bindValue(':fecha', $fecha);
    $stmt->bindValue(':tipo', $tipo);
    $stmt->bindValue(':estado', $estado);
    $stmt->bindValue(':observacion', $observacion);
    $stmt->bindValue(':codusuarioa', intval($codigo_usuario_actor), PDO::PARAM_INT);

    if (!$stmt->execute()) {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo guardar el registro de adherencia.'));
        return;
    }

    $result = get_registros($db, $codigo_usuario_objetivo, $fecha, $fecha);

    http_response_code(200);
    echo json_encode(array(
        'message' => 'Registro de adherencia guardado correctamente.',
        'items' => $result,
    ));
}

function delete_registro($db, $codigo_usuario, $data) {
    $codigo = intval($data['codigo'] ?? 0);

    if ($codigo > 0) {
        $stmt = $db->prepare("DELETE FROM nu_adherencia_diaria WHERE codigo = :codigo AND codigo_usuario = :codigo_usuario");
        $stmt->bindValue(':codigo', $codigo, PDO::PARAM_INT);
        $stmt->bindValue(':codigo_usuario', intval($codigo_usuario), PDO::PARAM_INT);

        if (!$stmt->execute()) {
            http_response_code(500);
            echo json_encode(array('message' => 'No se pudo eliminar el registro.'));
            return;
        }

        http_response_code(200);
        echo json_encode(array('message' => 'Registro eliminado.'));
        return;
    }

    $tipo = normalize_tipo($data['tipo'] ?? null);
    $fecha = normalize_fecha($data['fecha'] ?? null);

    if (empty($tipo) || empty($fecha)) {
        http_response_code(400);
        echo json_encode(array('message' => 'Para borrar por fecha/tipo, ambos son obligatorios.'));
        return;
    }

    $stmt = $db->prepare("DELETE FROM nu_adherencia_diaria WHERE codigo_usuario = :codigo_usuario AND fecha = :fecha AND tipo = :tipo");
    $stmt->bindValue(':codigo_usuario', intval($codigo_usuario), PDO::PARAM_INT);
    $stmt->bindValue(':fecha', $fecha);
    $stmt->bindValue(':tipo', $tipo);

    if (!$stmt->execute()) {
        http_response_code(500);
        echo json_encode(array('message' => 'No se pudo eliminar el registro.'));
        return;
    }

    http_response_code(200);
    echo json_encode(array('message' => 'Registro eliminado.'));
}

try {
    $codigo_usuario = resolve_user_code($user);
    if (empty($codigo_usuario)) {
        http_response_code(401);
        echo json_encode(array('message' => 'Usuario inválido.'));
        exit();
    }

    switch ($method) {
        case 'GET':
            $target_usuario = $codigo_usuario;
            if (isset($_GET['codigo_usuario']) && $_GET['codigo_usuario'] !== '') {
                $requested_usuario = intval($_GET['codigo_usuario']);
                if ($requested_usuario > 0) {
                    if (!can_read_other_user($user) && $requested_usuario !== $codigo_usuario) {
                        http_response_code(403);
                        echo json_encode(array('message' => 'No tienes permiso para consultar adherencia de otro usuario.'));
                        exit();
                    }
                    $target_usuario = $requested_usuario;
                }
            }

            $fecha_desde = normalize_fecha($_GET['fecha_desde'] ?? null);
            $fecha_hasta = normalize_fecha($_GET['fecha_hasta'] ?? null);

            if (isset($_GET['fecha_desde']) && $fecha_desde === null) {
                http_response_code(400);
                echo json_encode(array('message' => 'fecha_desde no válida.'));
                exit();
            }
            if (isset($_GET['fecha_hasta']) && $fecha_hasta === null) {
                http_response_code(400);
                echo json_encode(array('message' => 'fecha_hasta no válida.'));
                exit();
            }

            $items = get_registros($db, $target_usuario, $fecha_desde, $fecha_hasta);
            http_response_code(200);
            echo json_encode(array('items' => $items));
            break;

        case 'POST':
        case 'PUT':
            $data = json_decode(file_get_contents('php://input'), true);
            if (!is_array($data)) {
                http_response_code(400);
                echo json_encode(array('message' => 'Payload inválido.'));
                exit();
            }
            $resolved = resolve_target_usuario_from_payload($db, $user, $codigo_usuario, $data);
            if (!$resolved['ok']) {
                http_response_code(intval($resolved['status']));
                echo json_encode(array('message' => $resolved['message']));
                exit();
            }
            upsert_registro($db, intval($resolved['codigo_usuario']), $codigo_usuario, $data);
            break;

        case 'DELETE':
            $data = json_decode(file_get_contents('php://input'), true);
            if (!is_array($data)) {
                http_response_code(400);
                echo json_encode(array('message' => 'Payload inválido.'));
                exit();
            }
            delete_registro($db, $codigo_usuario, $data);
            break;

        default:
            http_response_code(405);
            echo json_encode(array('message' => 'Método no permitido.'));
            break;
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(array('message' => 'Error interno.', 'error' => $e->getMessage()));
}
