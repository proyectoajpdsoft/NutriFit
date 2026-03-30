<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS");
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

ensure_alimento_categoria_rel_table();

$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'planes_nutricionales');

$method = $_SERVER['REQUEST_METHOD'];

// Parse JSON input if Content-Type is application/json
$data = [];
if ($method === 'POST' || $method === 'DELETE') {
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    if (strpos($contentType, 'application/json') !== false) {
        $input = file_get_contents('php://input');
        $data = json_decode($input, true) ?? [];
    } else {
        $data = $_POST;
    }
}

switch ($method) {
    case 'GET':
        get_grupos();
        break;
    case 'POST':
        if (!empty($data['codigo']) && intval($data['codigo']) > 0) {
            update_grupo($data);
        } else {
            create_grupo($data);
        }
        break;
    case 'DELETE':
        delete_grupo($data);
        break;
    default:
        http_response_code(405);
        echo json_encode(["message" => "Metodo no permitido."]);
        break;
}

function get_grupos() {
    global $db;
    $query = "SELECT codigo, nombre, fechaa, codigousuarioa, fecham, codusuariom
              FROM nu_alimento_grupo
              ORDER BY nombre";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items ?? []);
}

function create_grupo($data) {
    global $db, $user;

    $nombre = trim($data['nombre'] ?? '');
    $codusuarioa = isset($data['codusuarioa']) ? intval($data['codusuarioa']) : intval($user['codigo'] ?? 0);

    if ($nombre === '') {
        http_response_code(400);
        echo json_encode(["message" => "El nombre es obligatorio."]);
        return;
    }

    $query = "INSERT INTO nu_alimento_grupo (nombre, codigousuarioa, fechaa)
              VALUES (:nombre, :codigousuarioa, NOW())";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':codigousuarioa', $codusuarioa);

    if ($stmt->execute()) {
        http_response_code(201);
        ob_clean();
        echo json_encode(["message" => "Grupo creado.", "codigo" => $db->lastInsertId()]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "No se pudo crear el grupo.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function update_grupo($data) {
    global $db, $user;

    $codigo = intval($data['codigo'] ?? 0);
    $nombre = trim($data['nombre'] ?? '');
    $codusuariom = isset($data['codusuariom']) ? intval($data['codusuariom']) : intval($user['codigo'] ?? 0);

    if ($codigo === 0 || $nombre === '') {
        http_response_code(400);
        echo json_encode(["message" => "Codigo y nombre son obligatorios."]);
        return;
    }

    $query = "UPDATE nu_alimento_grupo
              SET nombre = :nombre,
                  codusuariom = :codusuariom,
                  fecham = NOW()
              WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':codusuariom', $codusuariom);

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Grupo actualizado."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "No se pudo actualizar el grupo.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function delete_grupo($data) {
    global $db;

    $codigo = isset($data['codigo']) ? intval($data['codigo']) : 0;
    if ($codigo === 0) {
        http_response_code(400);
        echo json_encode(["message" => "Codigo invalido."]);
        return;
    }

    // Bloquear si el grupo tiene alimentos asignados (N:N + legacy)
    $stmtUso = $db->prepare("SELECT (
                                (SELECT COUNT(*) FROM nu_alimento_categoria_rel WHERE codigo_grupo = :codigo1)
                                +
                                (SELECT COUNT(*) FROM nu_alimento WHERE codigo_grupo = :codigo2)
                             ) AS total");
    $stmtUso->bindParam(':codigo1', $codigo, PDO::PARAM_INT);
    $stmtUso->bindParam(':codigo2', $codigo, PDO::PARAM_INT);
    $stmtUso->execute();
    $uso = $stmtUso->fetch(PDO::FETCH_ASSOC);
    if (intval($uso['total'] ?? 0) > 0) {
        http_response_code(409);
        ob_clean();
        echo json_encode(["message" => "No se puede eliminar el grupo porque tiene alimentos asignados. Reasigna o elimina los alimentos primero."]);
        return;
    }

    $query = "DELETE FROM nu_alimento_grupo WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Grupo eliminado."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "No se pudo eliminar el grupo.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function ensure_alimento_categoria_rel_table() {
    global $db;
    $db->exec("CREATE TABLE IF NOT EXISTS nu_alimento_categoria_rel (
        codigo_alimento INT NOT NULL,
        codigo_grupo INT NOT NULL,
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        PRIMARY KEY (codigo_alimento, codigo_grupo),
        KEY idx_alimento_categoria_rel_grupo (codigo_grupo),
        CONSTRAINT alimento_categoria_rel_alimento_fk
            FOREIGN KEY (codigo_alimento) REFERENCES nu_alimento(codigo)
            ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT alimento_categoria_rel_grupo_fk
            FOREIGN KEY (codigo_grupo) REFERENCES nu_alimento_grupo(codigo)
            ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}
?>
