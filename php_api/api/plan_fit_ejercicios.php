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

// Validar token
$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'planes_fit');

$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {
    case 'GET':
        if (isset($_GET['catalog'])) {
            $search = isset($_GET['search']) ? $_GET['search'] : null;
            $categoria = isset($_GET['categoria']) ? intval($_GET['categoria']) : null;
            get_catalog_ejercicios($search, $categoria);
        } elseif (isset($_GET['ejercicio_categorias'])) {
            get_ejercicio_categorias(intval($_GET['ejercicio_categorias']));
        } elseif (isset($_GET['codigo_plan_fit'])) {
            $codigoDia = isset($_GET['codigo_dia']) ? intval($_GET['codigo_dia']) : null;
            get_ejercicios_plan_fit(intval($_GET['codigo_plan_fit']), $codigoDia);
        }
        break;
    case 'POST':
        if (isset($_POST['catalog']) && $_POST['catalog'] === '1') {
            if (isset($_POST['codigo']) && intval($_POST['codigo']) > 0) {
                update_catalog_ejercicio();
            } else {
                create_catalog_ejercicio();
            }
        } else {
            if (isset($_POST['codigo']) && intval($_POST['codigo']) > 0) {
                update_ejercicio_plan_fit();
            } else {
                create_ejercicio_plan_fit();
            }
        }
        break;
    case 'DELETE':
        if (isset($_GET['catalog']) && $_GET['catalog'] === '1') {
            delete_catalog_ejercicio();
        } else {
            delete_ejercicio_plan_fit();
        }
        break;
    default:
        http_response_code(405);
        echo json_encode(["message" => "Método no permitido."]);
        break;
}

function get_ejercicios_plan_fit($codigo_plan_fit, $codigo_dia = null) {
    global $db;
    $query = "SELECT codigo, codigo_plan_fit, codigo_dia, nombre, instrucciones, url_video, foto, foto_nombre, tiempo, descanso, repeticiones, kilos, orden
              FROM nu_plan_fit_ejercicio
              WHERE codigo_plan_fit = :codigo_plan_fit";
    
    if ($codigo_dia !== null) {
        $query .= " AND codigo_dia = :codigo_dia";
    }
    
    $query .= " ORDER BY orden, codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_plan_fit', $codigo_plan_fit);
    
    if ($codigo_dia !== null) {
        $stmt->bindParam(':codigo_dia', $codigo_dia);
    }
    
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($items as &$item) {
        if (!empty($item['foto'])) {
            $item['foto'] = base64_encode($item['foto']);
        }
    }

    ob_clean();
    echo json_encode($items ?? []);
}

function ensure_catalog_table() {
    global $db;
    $db->exec("CREATE TABLE IF NOT EXISTS nu_plan_fit_ejercicios_catalogo (
        codigo INT AUTO_INCREMENT PRIMARY KEY,
        nombre VARCHAR(255) UNIQUE NOT NULL COLLATE utf8mb4_unicode_ci,
        instrucciones TEXT NULL,
        url_video VARCHAR(500) NULL,
        foto LONGBLOB NULL,
        foto_nombre VARCHAR(255) NULL,
        tiempo INT NULL,
        descanso INT NULL,
        repeticiones INT NULL,
        kilos INT NULL,
        codusuarioa INT NULL,
        codusuariom INT NULL,
        fechaa DATETIME NULL,
        fecham DATETIME NULL,
        INDEX idx_nombre (nombre)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

function get_catalog_ejercicios($search = null, $codigo_categoria = null) {
    global $db;
    ensure_catalog_table();

    if ($codigo_categoria !== null) {
        // Filtrar por categoría
        $query = "SELECT DISTINCT e.codigo, 0 as codigo_plan_fit, NULL as codigo_dia, e.nombre, e.instrucciones, e.url_video, e.foto, e.foto_nombre, e.tiempo, e.descanso, e.repeticiones, e.kilos, 0 as orden
                  FROM nu_plan_fit_ejercicios_catalogo e
                  INNER JOIN nu_plan_fit_ejercicios_categorias ec ON e.codigo = ec.codigo_ejercicio
                  WHERE ec.codigo_categoria = :codigo_categoria";
        $bind = [':codigo_categoria' => $codigo_categoria];
        
        if (!empty($search)) {
            $query .= " AND e.nombre LIKE :search";
            $bind[':search'] = '%' . $search . '%';
        }
        
        $query .= " ORDER BY e.nombre";
    } else {
        $query = "SELECT codigo, 0 as codigo_plan_fit, NULL as codigo_dia, nombre, instrucciones, url_video, foto, foto_nombre, tiempo, descanso, repeticiones, kilos, 0 as orden
                  FROM nu_plan_fit_ejercicios_catalogo";
        $bind = [];
        if (!empty($search)) {
            $query .= " WHERE nombre LIKE :search";
            $bind[':search'] = '%' . $search . '%';
        }
        $query .= " ORDER BY nombre";
    }

    $stmt = $db->prepare($query);
    foreach ($bind as $key => $val) {
        $stmt->bindValue($key, $val);
    }
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($items as &$item) {
        if (!empty($item['foto'])) {
            $item['foto'] = base64_encode($item['foto']);
        }
    }

    ob_clean();
    echo json_encode($items ?? []);
}

function upsert_catalog_ejercicio($data) {
    global $db;
    ensure_catalog_table();

    $nombre = trim($data['nombre'] ?? '');
    if ($nombre === '') {
        return;
    }

    $stmt = $db->prepare("SELECT codigo, nombre, instrucciones, url_video, foto, foto_nombre, tiempo, descanso, repeticiones, kilos
                          FROM nu_plan_fit_ejercicios_catalogo WHERE LOWER(nombre) = LOWER(:nombre) LIMIT 1");
    $stmt->bindParam(':nombre', $nombre);
    $stmt->execute();
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);

    $instrucciones = $data['instrucciones'] ?? null;
    $url_video = $data['url_video'] ?? null;
    $tiempo = array_key_exists('tiempo', $data) ? $data['tiempo'] : null;
    $descanso = array_key_exists('descanso', $data) ? $data['descanso'] : null;
    $repeticiones = array_key_exists('repeticiones', $data) ? $data['repeticiones'] : null;
    $kilos = array_key_exists('kilos', $data) ? $data['kilos'] : null;
    $foto_blob = $data['foto_blob'] ?? null;
    $foto_nombre = $data['foto_nombre'] ?? null;
    $clear_foto = isset($data['clear_foto']) && $data['clear_foto'] === true;
    $codusuario = $data['codusuario'] ?? null;

    if ($existing) {
        $set = [];
        $bind = [':codigo' => $existing['codigo']];

        if ((string)($existing['nombre'] ?? '') !== $nombre) {
            $set[] = "nombre = :nombre";
            $bind[':nombre'] = $nombre;
        }
        if ((string)($existing['instrucciones'] ?? '') !== (string)($instrucciones ?? '')) {
            $set[] = "instrucciones = :instrucciones";
            $bind[':instrucciones'] = $instrucciones;
        }
        if ((string)($existing['url_video'] ?? '') !== (string)($url_video ?? '')) {
            $set[] = "url_video = :url_video";
            $bind[':url_video'] = $url_video;
        }

        $existing_tiempo = $existing['tiempo'] !== null ? intval($existing['tiempo']) : null;
        if ($existing_tiempo !== $tiempo) {
            $set[] = "tiempo = :tiempo";
            $bind[':tiempo'] = $tiempo;
        }
        $existing_descanso = $existing['descanso'] !== null ? intval($existing['descanso']) : null;
        if ($existing_descanso !== $descanso) {
            $set[] = "descanso = :descanso";
            $bind[':descanso'] = $descanso;
        }
        $existing_repeticiones = $existing['repeticiones'] !== null ? intval($existing['repeticiones']) : null;
        if ($existing_repeticiones !== $repeticiones) {
            $set[] = "repeticiones = :repeticiones";
            $bind[':repeticiones'] = $repeticiones;
        }
        $existing_kilos = $existing['kilos'] !== null ? intval($existing['kilos']) : null;
        if ($existing_kilos !== $kilos) {
            $set[] = "kilos = :kilos";
            $bind[':kilos'] = $kilos;
        }

        if ($clear_foto) {
            if (!empty($existing['foto']) || !empty($existing['foto_nombre'])) {
                $set[] = "foto = NULL";
                $set[] = "foto_nombre = NULL";
            }
        } elseif ($foto_blob !== null) {
            $set[] = "foto = :foto";
            $set[] = "foto_nombre = :foto_nombre";
            $bind[':foto'] = $foto_blob;
            $bind[':foto_nombre'] = $foto_nombre;
        }

        if (!empty($set)) {
            $set[] = "fecham = NOW()";
            if ($codusuario !== null) {
                $set[] = "codusuariom = :codusuariom";
                $bind[':codusuariom'] = $codusuario;
            }
            $query = "UPDATE nu_plan_fit_ejercicios_catalogo SET " . implode(", ", $set) . " WHERE codigo = :codigo";
            $stmt = $db->prepare($query);
            foreach ($bind as $key => &$val) {
                if ($key === ':foto') {
                    $stmt->bindParam($key, $val, PDO::PARAM_LOB);
                } else {
                    $stmt->bindParam($key, $val);
                }
            }
            $stmt->execute();
        }
        return;
    }

    $query = "INSERT INTO nu_plan_fit_ejercicios_catalogo
              (nombre, instrucciones, url_video, foto, foto_nombre, tiempo, descanso, repeticiones, kilos, codusuarioa, fechaa)
              VALUES (:nombre, :instrucciones, :url_video, :foto, :foto_nombre, :tiempo, :descanso, :repeticiones, :kilos, :codusuarioa, NOW())";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':instrucciones', $instrucciones);
    $stmt->bindParam(':url_video', $url_video);
    $stmt->bindParam(':foto', $foto_blob, PDO::PARAM_LOB);
    $stmt->bindParam(':foto_nombre', $foto_nombre);
    $stmt->bindParam(':tiempo', $tiempo);
    $stmt->bindParam(':descanso', $descanso);
    $stmt->bindParam(':repeticiones', $repeticiones);
    $stmt->bindParam(':kilos', $kilos);
    $stmt->bindParam(':codusuarioa', $codusuario);
    $stmt->execute();
}

function create_catalog_ejercicio() {
    global $db;
    ensure_catalog_table();

    $nombre = trim($_POST['nombre'] ?? '');
    if ($nombre === '') {
        http_response_code(400);
        echo json_encode(["message" => "El nombre es obligatorio."]);
        return;
    }

    $stmt = $db->prepare("SELECT codigo FROM nu_plan_fit_ejercicios_catalogo WHERE LOWER(nombre) = LOWER(:nombre) LIMIT 1");
    $stmt->bindParam(':nombre', $nombre);
    $stmt->execute();
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($existing) {
        http_response_code(409);
        ob_clean();
        echo json_encode(["message" => "Ya existe un ejercicio con ese nombre."]);
        return;
    }

    $instrucciones = $_POST['instrucciones'] ?? null;
    $url_video = $_POST['url_video'] ?? null;
    $tiempo = isset($_POST['tiempo']) && $_POST['tiempo'] !== '' ? intval($_POST['tiempo']) : null;
    $descanso = isset($_POST['descanso']) && $_POST['descanso'] !== '' ? intval($_POST['descanso']) : null;
    $repeticiones = isset($_POST['repeticiones']) && $_POST['repeticiones'] !== '' ? intval($_POST['repeticiones']) : null;
    $kilos = isset($_POST['kilos']) && $_POST['kilos'] !== '' ? intval($_POST['kilos']) : null;
    $codusuarioa = isset($_POST['codusuarioa']) ? intval($_POST['codusuarioa']) : null;

    $foto_blob = null;
    $foto_nombre = $_POST['foto_nombre'] ?? null;
    if (isset($_FILES['foto']) && $_FILES['foto']['error'] === UPLOAD_ERR_OK) {
        $foto_blob = file_get_contents($_FILES['foto']['tmp_name']);
        if (!$foto_nombre) {
            $foto_nombre = $_FILES['foto']['name'];
        }
    }

    $query = "INSERT INTO nu_plan_fit_ejercicios_catalogo
              (nombre, instrucciones, url_video, foto, foto_nombre, tiempo, descanso, repeticiones, kilos, codusuarioa, fechaa)
              VALUES (:nombre, :instrucciones, :url_video, :foto, :foto_nombre, :tiempo, :descanso, :repeticiones, :kilos, :codusuarioa, NOW())";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':instrucciones', $instrucciones);
    $stmt->bindParam(':url_video', $url_video);
    $stmt->bindParam(':foto', $foto_blob, PDO::PARAM_LOB);
    $stmt->bindParam(':foto_nombre', $foto_nombre);
    $stmt->bindParam(':tiempo', $tiempo);
    $stmt->bindParam(':descanso', $descanso);
    $stmt->bindParam(':repeticiones', $repeticiones);
    $stmt->bindParam(':kilos', $kilos);
    $stmt->bindParam(':codusuarioa', $codusuarioa);

    if ($stmt->execute()) {
        http_response_code(201);
        ob_clean();
        echo json_encode(["message" => "Ejercicio del catalogo creado.", "codigo" => $db->lastInsertId()]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "No se pudo crear el ejercicio del catalogo.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function update_catalog_ejercicio() {
    global $db;
    ensure_catalog_table();

    $codigo = isset($_POST['codigo']) ? intval($_POST['codigo']) : 0;
    if ($codigo === 0) {
        http_response_code(400);
        echo json_encode(["message" => "Falta el codigo del ejercicio."]);
        return;
    }

    $set = [];
    $bind = [':codigo' => $codigo];

    if (isset($_POST['nombre'])) {
        $nombre = trim($_POST['nombre']);
        $stmt = $db->prepare("SELECT codigo FROM nu_plan_fit_ejercicios_catalogo WHERE LOWER(nombre) = LOWER(:nombre) AND codigo <> :codigo LIMIT 1");
        $stmt->bindParam(':nombre', $nombre);
        $stmt->bindParam(':codigo', $codigo);
        $stmt->execute();
        $existing = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($existing) {
            http_response_code(409);
            ob_clean();
            echo json_encode(["message" => "Ya existe un ejercicio con ese nombre."]);
            return;
        }
        $set[] = "nombre = :nombre";
        $bind[':nombre'] = $nombre;
    }
    if (isset($_POST['instrucciones'])) {
        $set[] = "instrucciones = :instrucciones";
        $bind[':instrucciones'] = $_POST['instrucciones'];
    }
    if (isset($_POST['url_video'])) {
        $set[] = "url_video = :url_video";
        $bind[':url_video'] = $_POST['url_video'];
    }
    if (isset($_POST['tiempo'])) {
        $set[] = "tiempo = :tiempo";
        $bind[':tiempo'] = $_POST['tiempo'] !== '' ? intval($_POST['tiempo']) : null;
    }
    if (isset($_POST['descanso'])) {
        $set[] = "descanso = :descanso";
        $bind[':descanso'] = $_POST['descanso'] !== '' ? intval($_POST['descanso']) : null;
    }
    if (isset($_POST['repeticiones'])) {
        $set[] = "repeticiones = :repeticiones";
        $bind[':repeticiones'] = $_POST['repeticiones'] !== '' ? intval($_POST['repeticiones']) : null;
    }
    if (isset($_POST['kilos'])) {
        $set[] = "kilos = :kilos";
        $bind[':kilos'] = $_POST['kilos'] !== '' ? intval($_POST['kilos']) : null;
    }
    if (isset($_POST['codusuariom'])) {
        $set[] = "codusuariom = :codusuariom";
        $bind[':codusuariom'] = intval($_POST['codusuariom']);
    }

    if (isset($_POST['eliminar_foto']) && $_POST['eliminar_foto'] == '1') {
        $set[] = "foto = NULL";
        $set[] = "foto_nombre = NULL";
    }

    $foto_blob = null;
    $foto_nombre = null;
    if (isset($_FILES['foto']) && $_FILES['foto']['error'] === UPLOAD_ERR_OK) {
        $foto_blob = file_get_contents($_FILES['foto']['tmp_name']);
        $set[] = "foto = :foto";
        $bind[':foto'] = $foto_blob;
        if (isset($_POST['foto_nombre'])) {
            $set[] = "foto_nombre = :foto_nombre";
            $bind[':foto_nombre'] = $_POST['foto_nombre'];
        } else {
            $set[] = "foto_nombre = :foto_nombre";
            $bind[':foto_nombre'] = $_FILES['foto']['name'];
        }
    }

    $set[] = "fecham = NOW()";

    if (empty($set)) {
        http_response_code(400);
        echo json_encode(["message" => "No hay datos para actualizar."]);
        return;
    }

    $query = "UPDATE nu_plan_fit_ejercicios_catalogo SET " . implode(", ", $set) . " WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    foreach ($bind as $key => &$val) {
        if ($key === ':foto') {
            $stmt->bindParam($key, $val, PDO::PARAM_LOB);
        } else {
            $stmt->bindParam($key, $val);
        }
    }

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Ejercicio del catalogo actualizado."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "No se pudo actualizar el ejercicio del catalogo.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function delete_catalog_ejercicio() {
    global $db;
    $data = json_decode(file_get_contents("php://input"), true);
    $codigo = isset($data['codigo']) ? intval($data['codigo']) : 0;
    if ($codigo === 0 && isset($_GET['codigo'])) {
        $codigo = intval($_GET['codigo']);
    }

    if ($codigo === 0) {
        http_response_code(400);
        echo json_encode(["message" => "Falta el codigo del ejercicio."]);
        return;
    }

    // Eliminar relaciones de categorias antes de borrar el catalogo
    try {
        $stmtRel = $db->prepare("DELETE FROM nu_plan_fit_ejercicios_categorias WHERE codigo_ejercicio = :codigo");
        $stmtRel->bindParam(':codigo', $codigo);
        $stmtRel->execute();
    } catch (Exception $e) {
        // Si falla la limpieza de categorias, continuar para reportar el error del delete principal
    }

    $query = "DELETE FROM nu_plan_fit_ejercicios_catalogo WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Ejercicio del catalogo eliminado."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "No se pudo eliminar el ejercicio del catalogo.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function create_ejercicio_plan_fit() {
    global $db;

    $codigo_plan_fit = isset($_POST['codigo_plan_fit']) ? intval($_POST['codigo_plan_fit']) : null;
    if (!$codigo_plan_fit) {
        http_response_code(400);
        echo json_encode(["message" => "Falta codigo_plan_fit."]);
        return;
    }

    $codigo_dia = isset($_POST['codigo_dia']) && $_POST['codigo_dia'] !== '' ? intval($_POST['codigo_dia']) : null;
    $nombre = $_POST['nombre'] ?? '';
    $instrucciones = $_POST['instrucciones'] ?? null;
    $url_video = $_POST['url_video'] ?? null;
    $tiempo = isset($_POST['tiempo']) && $_POST['tiempo'] !== '' ? intval($_POST['tiempo']) : null;
    $descanso = isset($_POST['descanso']) && $_POST['descanso'] !== '' ? intval($_POST['descanso']) : null;
    $repeticiones = isset($_POST['repeticiones']) && $_POST['repeticiones'] !== '' ? intval($_POST['repeticiones']) : null;
    $kilos = isset($_POST['kilos']) && $_POST['kilos'] !== '' ? intval($_POST['kilos']) : null;
    $orden = isset($_POST['orden']) && $_POST['orden'] !== '' ? intval($_POST['orden']) : 0;
    $codusuarioa = isset($_POST['codusuarioa']) ? intval($_POST['codusuarioa']) : 1;

    $foto_blob = null;
    $foto_nombre = $_POST['foto_nombre'] ?? null;
    if (isset($_FILES['foto']) && $_FILES['foto']['error'] === UPLOAD_ERR_OK) {
        $foto_blob = file_get_contents($_FILES['foto']['tmp_name']);
        if (!$foto_nombre) {
            $foto_nombre = $_FILES['foto']['name'];
        }
    }

    $query = "INSERT INTO nu_plan_fit_ejercicio (codigo_plan_fit, codigo_dia, nombre, instrucciones, url_video, foto, foto_nombre, tiempo, descanso, repeticiones, kilos, orden, codusuarioa, fechaa)
              VALUES (:codigo_plan_fit, :codigo_dia, :nombre, :instrucciones, :url_video, :foto, :foto_nombre, :tiempo, :descanso, :repeticiones, :kilos, :orden, :codusuarioa, NOW())";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_plan_fit', $codigo_plan_fit);
    $stmt->bindParam(':codigo_dia', $codigo_dia);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':instrucciones', $instrucciones);
    $stmt->bindParam(':url_video', $url_video);
    $stmt->bindParam(':foto', $foto_blob, PDO::PARAM_LOB);
    $stmt->bindParam(':foto_nombre', $foto_nombre);
    $stmt->bindParam(':tiempo', $tiempo);
    $stmt->bindParam(':descanso', $descanso);
    $stmt->bindParam(':repeticiones', $repeticiones);
    $stmt->bindParam(':kilos', $kilos);
    $stmt->bindParam(':orden', $orden);
    $stmt->bindParam(':codusuarioa', $codusuarioa);

    if ($stmt->execute()) {
        http_response_code(201);
        ob_clean();
        echo json_encode(["message" => "Ejercicio creado.", "codigo" => $db->lastInsertId()]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "No se pudo crear el ejercicio.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function update_ejercicio_plan_fit() {
    global $db;

    $codigo = isset($_POST['codigo']) ? intval($_POST['codigo']) : null;
    if (!$codigo) {
        http_response_code(400);
        echo json_encode(["message" => "Falta el código del ejercicio."]);
        return;
    }

    $set = [];
    $bind = [':codigo' => $codigo];

    if (isset($_POST['codigo_plan_fit'])) {
        $set[] = "codigo_plan_fit = :codigo_plan_fit";
        $bind[':codigo_plan_fit'] = intval($_POST['codigo_plan_fit']);
    }
    if (isset($_POST['codigo_dia'])) {
        $set[] = "codigo_dia = :codigo_dia";
        $bind[':codigo_dia'] = $_POST['codigo_dia'] !== '' ? intval($_POST['codigo_dia']) : null;
    }
    if (isset($_POST['nombre'])) {
        $set[] = "nombre = :nombre";
        $bind[':nombre'] = $_POST['nombre'];
    }
    if (isset($_POST['instrucciones'])) {
        $set[] = "instrucciones = :instrucciones";
        $bind[':instrucciones'] = $_POST['instrucciones'];
    }
    if (isset($_POST['url_video'])) {
        $set[] = "url_video = :url_video";
        $bind[':url_video'] = $_POST['url_video'];
    }
    if (isset($_POST['tiempo'])) {
        $set[] = "tiempo = :tiempo";
        $bind[':tiempo'] = $_POST['tiempo'] !== '' ? intval($_POST['tiempo']) : null;
    }
    if (isset($_POST['descanso'])) {
        $set[] = "descanso = :descanso";
        $bind[':descanso'] = $_POST['descanso'] !== '' ? intval($_POST['descanso']) : null;
    }
    if (isset($_POST['repeticiones'])) {
        $set[] = "repeticiones = :repeticiones";
        $bind[':repeticiones'] = $_POST['repeticiones'] !== '' ? intval($_POST['repeticiones']) : null;
    }
    if (isset($_POST['kilos'])) {
        $set[] = "kilos = :kilos";
        $bind[':kilos'] = $_POST['kilos'] !== '' ? intval($_POST['kilos']) : null;
    }
    if (isset($_POST['orden'])) {
        $set[] = "orden = :orden";
        $bind[':orden'] = $_POST['orden'] !== '' ? intval($_POST['orden']) : 0;
    }
    if (isset($_POST['codusuariom'])) {
        $set[] = "codusuariom = :codusuariom";
        $bind[':codusuariom'] = intval($_POST['codusuariom']);
    }

    if (isset($_POST['eliminar_foto']) && $_POST['eliminar_foto'] == '1') {
        $set[] = "foto = NULL";
        $set[] = "foto_nombre = NULL";
    }

    $foto_blob = null;
    $foto_nombre = null;
    if (isset($_FILES['foto']) && $_FILES['foto']['error'] === UPLOAD_ERR_OK) {
        $foto_blob = file_get_contents($_FILES['foto']['tmp_name']);
        $set[] = "foto = :foto";
        $bind[':foto'] = $foto_blob;
        if (isset($_POST['foto_nombre'])) {
            $set[] = "foto_nombre = :foto_nombre";
            $bind[':foto_nombre'] = $_POST['foto_nombre'];
            $foto_nombre = $_POST['foto_nombre'];
        } else {
            $set[] = "foto_nombre = :foto_nombre";
            $bind[':foto_nombre'] = $_FILES['foto']['name'];
            $foto_nombre = $_FILES['foto']['name'];
        }
    }

    $set[] = "fecham = NOW()";

    if (empty($set)) {
        http_response_code(400);
        echo json_encode(["message" => "No hay datos para actualizar."]);
        return;
    }

    $query = "UPDATE nu_plan_fit_ejercicio SET " . implode(", ", $set) . " WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    foreach ($bind as $key => &$val) {
        if ($key === ':foto') {
            $stmt->bindParam($key, $val, PDO::PARAM_LOB);
        } else {
            $stmt->bindParam($key, $val);
        }
    }

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Ejercicio actualizado."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "No se pudo actualizar el ejercicio.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function delete_ejercicio_plan_fit() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    if (empty($data->codigo)) {
        http_response_code(400);
        echo json_encode(["message" => "Falta el código del ejercicio."]);
        return;
    }

    $query = "DELETE FROM nu_plan_fit_ejercicio WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $data->codigo);

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Ejercicio eliminado."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "No se pudo eliminar el ejercicio.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function get_ejercicio_categorias($codigo_ejercicio) {
    global $db;
    $query = "SELECT c.codigo, c.nombre, c.descripcion, c.orden
              FROM nu_plan_fit_categorias c
              INNER JOIN nu_plan_fit_ejercicios_categorias ec ON c.codigo = ec.codigo_categoria
              WHERE ec.codigo_ejercicio = :codigo_ejercicio AND c.activo = 'S'
              ORDER BY c.orden, c.nombre";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_ejercicio', $codigo_ejercicio);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items ?? []);
}
?>
