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

// Validar token de usuario o invitado según corresponda.
$validator = new AutoValidator($db);
$user = $validator->validate();

$method = $_SERVER['REQUEST_METHOD'];

function is_premium_catalog_read_request() {
    return $_SERVER['REQUEST_METHOD'] === 'GET'
        && isset($_GET['catalog'])
        && isset($_GET['premium_visible'])
        && $_GET['premium_visible'] == '1';
}

function is_catalog_detail_read_request() {
    return $_SERVER['REQUEST_METHOD'] === 'GET'
        && isset($_GET['catalog_ejercicio'])
        && intval($_GET['catalog_ejercicio']) > 0;
}

function is_catalog_total_read_request() {
    return $_SERVER['REQUEST_METHOD'] === 'GET'
        && isset($_GET['total_catalog']);
}

function can_read_premium_catalog_preview($user) {
    $user_type = PermissionManager::getUserType($user);

    return in_array($user_type, array(
        PermissionManager::TYPE_GUEST,
        PermissionManager::TYPE_USER_NO_PATIENT,
        PermissionManager::TYPE_USER_WITH_PATIENT,
        PermissionManager::TYPE_PREMIUM,
        PermissionManager::TYPE_NUTRITIONIST,
        PermissionManager::TYPE_ADMIN,
    ), true);
}

function user_can_manage_plan_fit_catalog($user) {
    $user_type = PermissionManager::getUserType($user);

    return in_array($user_type, array(
        PermissionManager::TYPE_NUTRITIONIST,
        PermissionManager::TYPE_ADMIN,
    ), true);
}

if (is_premium_catalog_read_request() || is_catalog_detail_read_request() || is_catalog_total_read_request()) {
    if (!can_read_premium_catalog_preview($user)) {
        PermissionManager::checkPermission($user, 'planes_fit');
    }
} else {
    PermissionManager::checkPermission($user, 'planes_fit');
}

switch ($method) {
    case 'GET':
        if (isset($_GET['total_catalog'])) {
            get_total_catalog_ejercicios();
        } elseif (isset($_GET['catalog_ejercicio'])) {
            get_catalog_ejercicio_with_foto(intval($_GET['catalog_ejercicio']));
        } elseif (isset($_GET['catalog']) && isset($_GET['check_nombre'])) {
            check_catalog_ejercicio_by_nombre($_GET['check_nombre']);
        } elseif (isset($_GET['catalog'])) {
            $search = isset($_GET['search']) ? $_GET['search'] : null;
            $categoria = isset($_GET['categoria']) ? intval($_GET['categoria']) : null;
            $categorias = [];
            if (isset($_GET['categorias'])) {
                $categorias_raw = explode(',', $_GET['categorias']);
                foreach ($categorias_raw as $cat) {
                    $cat_int = intval(trim($cat));
                    if ($cat_int > 0) {
                        $categorias[] = $cat_int;
                    }
                }
                $categorias = array_values(array_unique($categorias));
            }
            $premium_visible = isset($_GET['premium_visible']) && $_GET['premium_visible'] == '1';
            get_catalog_ejercicios($search, $categoria, $premium_visible, $categorias);
        } elseif (isset($_GET['planes_ejercicio'])) {
            get_planes_for_ejercicio(intval($_GET['planes_ejercicio']));
        } elseif (isset($_GET['ejercicio_categorias'])) {
            get_ejercicio_categorias(intval($_GET['ejercicio_categorias']));
        } elseif (isset($_GET['codigo_plan_fit'])) {
            $codigoDia = isset($_GET['codigo_dia']) ? intval($_GET['codigo_dia']) : null;
            get_ejercicios_plan_fit(intval($_GET['codigo_plan_fit']), $codigoDia);
        }
        break;
    case 'POST':
        // Check for multipart form data catalog operations
        if (isset($_POST['catalog_update_image'])) {
            update_catalog_ejercicio_image();
        } elseif (isset($_POST['catalog_create'])) {
            create_catalog_ejercicio_multipart();
        } elseif (isset($_POST['codigo']) && intval($_POST['codigo']) > 0) {
            update_ejercicio_plan_fit();
        } else {
            // Try JSON input for legacy catalog operations
            $input = file_get_contents("php://input");
            $data = json_decode($input);
            
            if ($data && isset($data->catalog) && $data->catalog === '1') {
                if (isset($data->codigo) && intval($data->codigo) > 0) {
                    update_catalog_ejercicio();
                } else {
                    create_catalog_ejercicio();
                }
            } else {
                create_ejercicio_plan_fit();
            }
        }
        break;
    case 'PUT':
        if (isset($_POST['catalog_update_image'])) {
            update_catalog_ejercicio_image();
        } else {
            update_catalog_ejercicio();
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
    $query = "SELECT e.codigo,
                     e.codigo_plan_fit,
                     e.codigo_dia,
                     e.codigo_ejercicio_catalogo,
                     e.nombre,
                     e.instrucciones,
                     c.instrucciones_detalladas,
                     COALESCE(NULLIF(e.url_video, ''), c.url_video) AS url_video,
                     c.foto_miniatura AS foto_miniatura,
                     c.foto_nombre AS foto_nombre,
                     e.tiempo,
                     e.descanso,
                     e.repeticiones,
                     e.kilos,
                     e.orden
              FROM nu_plan_fit_ejercicio e
              LEFT JOIN nu_plan_fit_ejercicios_catalogo c ON c.codigo = e.codigo_ejercicio_catalogo
              WHERE e.codigo_plan_fit = :codigo_plan_fit";
    
    if ($codigo_dia !== null) {
        $query .= " AND e.codigo_dia = :codigo_dia";
    }
    
    $query .= " ORDER BY e.orden, e.codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_plan_fit', $codigo_plan_fit);
    
    if ($codigo_dia !== null) {
        $stmt->bindParam(':codigo_dia', $codigo_dia);
    }
    
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

function ensure_catalog_table() {
    global $db;
    $db->exec("CREATE TABLE IF NOT EXISTS nu_plan_fit_ejercicios_catalogo (
        codigo INT AUTO_INCREMENT PRIMARY KEY,
        nombre VARCHAR(255) UNIQUE NOT NULL COLLATE utf8mb4_unicode_ci,
        instrucciones TEXT NULL,
        instrucciones_detalladas LONGBLOB NULL,
        url_video VARCHAR(500) NULL,
        foto LONGBLOB NULL,
        foto_nombre VARCHAR(255) NULL,
        visible_premium CHAR(1) DEFAULT 'N',
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
    try {
        $db->exec("ALTER TABLE nu_plan_fit_ejercicios_catalogo ADD COLUMN IF NOT EXISTS visible_premium CHAR(1) DEFAULT 'N' AFTER foto_nombre");
    } catch (Exception $e) {
        // ignore
    }
    try {
        $db->exec("ALTER TABLE nu_plan_fit_ejercicios_catalogo ADD COLUMN IF NOT EXISTS instrucciones_detalladas LONGBLOB NULL AFTER instrucciones");
    } catch (Exception $e) {
        // ignore
    }
    try {
        $db->exec("ALTER TABLE nu_plan_fit_ejercicios_catalogo ADD COLUMN IF NOT EXISTS hashtag VARCHAR(255) NULL AFTER kilos");
    } catch (Exception $e) {
        // ignore
    }
}

function get_catalog_ejercicios($search = null, $codigo_categoria = null, $premium_visible = false, $codigos_categorias = []) {
    global $db;
    ensure_catalog_table();

    $usos_subquery = "(SELECT codigo_ejercicio_catalogo, COUNT(*) AS total_usos FROM nu_plan_fit_ejercicio WHERE codigo_ejercicio_catalogo IS NOT NULL GROUP BY codigo_ejercicio_catalogo) uu";

    $has_multi_categorias = is_array($codigos_categorias) && count($codigos_categorias) > 0;

    if ($has_multi_categorias || $codigo_categoria !== null) {
        // Filtrar por categoría - NO incluir foto completa (solo miniatura)
        $query = "SELECT DISTINCT e.codigo, 0 as codigo_plan_fit, NULL as codigo_dia, e.nombre, e.instrucciones, e.instrucciones_detalladas, e.url_video, e.foto_miniatura, e.foto_nombre, e.visible_premium, e.tiempo, e.descanso, e.repeticiones, e.kilos, e.hashtag, 0 as orden, COALESCE(uu.total_usos, 0) AS total_usos
                  FROM nu_plan_fit_ejercicios_catalogo e
                  INNER JOIN nu_plan_fit_ejercicios_categorias ec ON e.codigo = ec.codigo_ejercicio
                  LEFT JOIN $usos_subquery ON uu.codigo_ejercicio_catalogo = e.codigo";
        $bind = [];

        if ($has_multi_categorias) {
            $placeholders = [];
            foreach ($codigos_categorias as $idx => $codigo_cat) {
                $placeholder = ':codigo_categoria_' . $idx;
                $placeholders[] = $placeholder;
                $bind[$placeholder] = intval($codigo_cat);
            }
            $query .= " WHERE ec.codigo_categoria IN (" . implode(', ', $placeholders) . ")";
        } else {
            $query .= " WHERE ec.codigo_categoria = :codigo_categoria";
            $bind[':codigo_categoria'] = $codigo_categoria;
        }

        if ($premium_visible) {
            $query .= " AND e.visible_premium = 'S'";
        }
        
        if (!empty($search)) {
            $query .= " AND e.nombre LIKE :search";
            $bind[':search'] = '%' . $search . '%';
        }
        
        $query .= " ORDER BY e.nombre";
    } else {
        // NO incluir foto completa (solo miniatura)
        $query = "SELECT e.codigo, 0 as codigo_plan_fit, NULL as codigo_dia, e.nombre, e.instrucciones, e.instrucciones_detalladas, e.url_video, e.foto_miniatura, e.foto_nombre, e.visible_premium, e.tiempo, e.descanso, e.repeticiones, e.kilos, e.hashtag, 0 as orden, COALESCE(uu.total_usos, 0) AS total_usos
                  FROM nu_plan_fit_ejercicios_catalogo e
                  LEFT JOIN $usos_subquery ON uu.codigo_ejercicio_catalogo = e.codigo";
        $bind = [];
        if (!empty($search)) {
            $query .= " WHERE e.nombre LIKE :search";
            $bind[':search'] = '%' . $search . '%';
            if ($premium_visible) {
                $query .= " AND e.visible_premium = 'S'";
            }
        } elseif ($premium_visible) {
            $query .= " WHERE e.visible_premium = 'S'";
        }
        $query .= " ORDER BY e.nombre";
    }

    $stmt = $db->prepare($query);
    foreach ($bind as $key => $val) {
        $stmt->bindValue($key, $val);
    }
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

function get_catalog_ejercicio_with_foto($codigo) {
    global $db, $user;
    ensure_catalog_table();

    $query = "SELECT codigo, 0 as codigo_plan_fit, NULL as codigo_dia, nombre, instrucciones, instrucciones_detalladas, url_video, foto, foto_miniatura, foto_nombre, visible_premium, tiempo, descanso, repeticiones, kilos, hashtag, 0 as orden
              FROM nu_plan_fit_ejercicios_catalogo
              WHERE codigo = :codigo";

    if (!user_can_manage_plan_fit_catalog($user)) {
        $query .= " AND visible_premium = 'S'";
    }

    $query .= " LIMIT 1";
    
    $stmt = $db->prepare($query);
    $stmt->bindValue(':codigo', $codigo, PDO::PARAM_INT);
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($item) {
        if (!empty($item['foto'])) {
            $item['foto'] = base64_encode($item['foto']);
        }
        if (!empty($item['foto_miniatura'])) {
            $item['foto_miniatura'] = base64_encode($item['foto_miniatura']);
        }
    }

    ob_clean();
    echo json_encode($item ?? null);
}

function get_total_catalog_ejercicios() {
    global $db;
    ensure_catalog_table();

    $stmt = $db->prepare("SELECT COUNT(*) as total FROM nu_plan_fit_ejercicios_catalogo");
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode(["total" => (int)($row['total'] ?? 0)]);
}

function get_planes_for_ejercicio($codigo_ejercicio) {
    global $db;
    $query = "SELECT p.codigo, p.codigo_paciente, p.desde, p.hasta, p.semanas, p.completado,
                     p.codigo_entrevista, p.plan_documento_nombre, p.plan_indicaciones,
                     p.plan_indicaciones_visible_usuario, p.url, p.rondas, p.fechaa,
                     pa.nombre AS nombre_paciente
              FROM nu_plan_nutricional_fit p
              LEFT JOIN nu_paciente pa ON pa.codigo = p.codigo_paciente
              WHERE EXISTS (
                  SELECT 1
                  FROM nu_plan_fit_ejercicio e
                  WHERE e.codigo_plan_fit = p.codigo
                    AND e.codigo_ejercicio_catalogo = :codigo_ejercicio
              )
              ORDER BY p.desde DESC, p.codigo DESC";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_ejercicio', $codigo_ejercicio, PDO::PARAM_INT);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items ?? []);
}

function check_catalog_ejercicio_by_nombre($nombre) {
    global $db;
    ensure_catalog_table();

    $query = "SELECT codigo, 0 as codigo_plan_fit, NULL as codigo_dia, nombre, instrucciones, instrucciones_detalladas, url_video, foto_miniatura, foto_nombre, visible_premium, tiempo, descanso, repeticiones, kilos, hashtag, 0 as orden
              FROM nu_plan_fit_ejercicios_catalogo
              WHERE LOWER(nombre) = LOWER(:nombre) LIMIT 1";
    
    $stmt = $db->prepare($query);
    $stmt->bindValue(':nombre', trim($nombre));
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($item && !empty($item['foto_miniatura'])) {
        $item['foto_miniatura'] = base64_encode($item['foto_miniatura']);
    }

    ob_clean();
    echo json_encode($item ?? null);
}

function create_catalog_ejercicio_multipart() {
    global $db, $user;
    ensure_catalog_table();

    $nombre = trim($_POST['nombre'] ?? '');
    if ($nombre === '') {
        http_response_code(400);
        echo json_encode(["message" => "Nombre es requerido"]);
        return;
    }

    // Check if already exists
    $stmt = $db->prepare("SELECT codigo FROM nu_plan_fit_ejercicios_catalogo WHERE LOWER(nombre) = LOWER(:nombre) LIMIT 1");
    $stmt->bindParam(':nombre', $nombre);
    $stmt->execute();
    if ($stmt->fetch()) {
        http_response_code(409);
        echo json_encode(["message" => "El ejercicio ya existe en el catálogo"]);
        return;
    }

    $instrucciones = $_POST['descripcion'] ?? null;
    $instrucciones_detalladas = $_POST['instrucciones_detalladas'] ?? null;
    $url_video = $_POST['url_video'] ?? null;
    $visible_premium = ($_POST['visible_premium'] ?? 'N') === 'S' ? 'S' : 'N';
    $hashtag_mp = isset($_POST['hashtag']) ? trim($_POST['hashtag']) : null;
    if ($hashtag_mp === '') $hashtag_mp = null;
    $codigo_categoria = !empty($_POST['codigo_categoria']) ? intval($_POST['codigo_categoria']) : null;
    $codusuariom = intval($_POST['codusuariom'] ?? $user['codigo']);

    // Handle image upload
    $foto_blob = null;
    $foto_miniatura_blob = null;
    $foto_nombre = null;

    if (isset($_FILES['foto']) && $_FILES['foto']['error'] === UPLOAD_ERR_OK) {
        $foto_blob = file_get_contents($_FILES['foto']['tmp_name']);
        $foto_nombre = $_POST['foto_nombre'] ?? $_FILES['foto']['name'];
    }
    if (isset($_FILES['foto_miniatura']) && $_FILES['foto_miniatura']['error'] === UPLOAD_ERR_OK) {
        $foto_miniatura_blob = file_get_contents($_FILES['foto_miniatura']['tmp_name']);
    }

    $query = "INSERT INTO nu_plan_fit_ejercicios_catalogo 
              (nombre, instrucciones, instrucciones_detalladas, url_video, foto, foto_miniatura, foto_nombre, visible_premium, hashtag, codusuarioa, fechaa) 
              VALUES (:nombre, :instrucciones, :instrucciones_detalladas, :url_video, :foto, :foto_miniatura, :foto_nombre, :visible_premium, :hashtag, :codusuarioa, NOW())";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':instrucciones', $instrucciones);
    $stmt->bindParam(':instrucciones_detalladas', $instrucciones_detalladas, PDO::PARAM_LOB);
    $stmt->bindParam(':url_video', $url_video);
    $stmt->bindParam(':foto', $foto_blob, PDO::PARAM_LOB);
    $stmt->bindParam(':foto_miniatura', $foto_miniatura_blob, PDO::PARAM_LOB);
    $stmt->bindParam(':foto_nombre', $foto_nombre);
    $stmt->bindParam(':visible_premium', $visible_premium);
    $stmt->bindParam(':hashtag', $hashtag_mp);
    $stmt->bindParam(':codusuarioa', $codusuariom);
    $stmt->execute();

    $codigo = $db->lastInsertId();

    // Link to category if provided
    if ($codigo_categoria !== null) {
        $stmt = $db->prepare("INSERT IGNORE INTO nu_plan_fit_ejercicios_categorias (codigo_ejercicio, codigo_categoria) VALUES (:codigo_ejercicio, :codigo_categoria)");
        $stmt->bindParam(':codigo_ejercicio', $codigo);
        $stmt->bindParam(':codigo_categoria', $codigo_categoria);
        $stmt->execute();
    }

    ob_clean();
    echo json_encode(["message" => "Ejercicio creado en catálogo", "codigo" => $codigo]);
}

function update_catalog_ejercicio_image() {
    global $db, $user;
    ensure_catalog_table();

    $codigo = intval($_POST['codigo'] ?? 0);
    if ($codigo === 0) {
        http_response_code(400);
        echo json_encode(["message" => "Código es requerido"]);
        return;
    }

    $codusuariom = intval($_POST['codusuariom'] ?? $user['codigo']);

    // Handle image upload
    $foto_blob = null;
    $foto_miniatura_blob = null;
    $foto_nombre = null;

    if (isset($_FILES['foto']) && $_FILES['foto']['error'] === UPLOAD_ERR_OK) {
        $foto_blob = file_get_contents($_FILES['foto']['tmp_name']);
        $foto_nombre = $_POST['foto_nombre'] ?? $_FILES['foto']['name'];
    }
    if (isset($_FILES['foto_miniatura']) && $_FILES['foto_miniatura']['error'] === UPLOAD_ERR_OK) {
        $foto_miniatura_blob = file_get_contents($_FILES['foto_miniatura']['tmp_name']);
    }

    if ($foto_blob === null) {
        http_response_code(400);
        echo json_encode(["message" => "Imagen es requerida"]);
        return;
    }

    $query = "UPDATE nu_plan_fit_ejercicios_catalogo 
              SET foto = :foto, foto_miniatura = :foto_miniatura, foto_nombre = :foto_nombre, 
                  codusuariom = :codusuariom, fecham = NOW()
              WHERE codigo = :codigo";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':foto', $foto_blob, PDO::PARAM_LOB);
    $stmt->bindParam(':foto_miniatura', $foto_miniatura_blob, PDO::PARAM_LOB);
    $stmt->bindParam(':foto_nombre', $foto_nombre);
    $stmt->bindParam(':codusuariom', $codusuariom);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();

    ob_clean();
    echo json_encode(["message" => "Imagen del catálogo actualizada"]);
}


function upsert_catalog_ejercicio($data) {
    global $db;
    ensure_catalog_table();

    $nombre = trim($data['nombre'] ?? '');
    if ($nombre === '') {
        return;
    }

    $stmt = $db->prepare("SELECT codigo, nombre, instrucciones, instrucciones_detalladas, url_video, foto, foto_nombre, tiempo, descanso, repeticiones, kilos
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

    $data = json_decode(file_get_contents("php://input"));

    $nombre = trim($data->nombre ?? '');
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

    $instrucciones = null;
    if (isset($data->instrucciones)) {
        $instrucciones_trim = trim($data->instrucciones);
        $instrucciones = $instrucciones_trim !== '' ? $instrucciones_trim : null;
    }
    $instrucciones_detalladas = null;
    if (isset($data->instrucciones_detalladas)) {
        $instrucciones_detalladas_trim = trim($data->instrucciones_detalladas);
        $instrucciones_detalladas = $instrucciones_detalladas_trim !== '' ? $instrucciones_detalladas_trim : null;
    }
    $url_video = $data->url_video ?? null;
    $tiempo = isset($data->tiempo) && $data->tiempo !== '' ? intval($data->tiempo) : null;
    $descanso = isset($data->descanso) && $data->descanso !== '' ? intval($data->descanso) : null;
    $repeticiones = isset($data->repeticiones) && $data->repeticiones !== '' ? intval($data->repeticiones) : null;
    $kilos = isset($data->kilos) && $data->kilos !== '' ? intval($data->kilos) : null;
    $visible_premium = isset($data->visible_premium) && $data->visible_premium === 'S' ? 'S' : 'N';
    $codusuarioa = isset($data->codusuarioa) ? intval($data->codusuarioa) : null;
    $hashtag = isset($data->hashtag) ? trim($data->hashtag) : null;
    if ($hashtag === '') $hashtag = null;

    $foto_blob = null;
    $foto_nombre = null;
    $foto_miniatura_blob = null;
    
    if (!empty($data->foto)) {
        $foto_blob = base64_decode($data->foto);
        $foto_nombre = $data->foto_nombre ?? 'foto.jpg';
    }
    
    if (!empty($data->foto_miniatura)) {
        $foto_miniatura_blob = base64_decode($data->foto_miniatura);
    }

    $query = "INSERT INTO nu_plan_fit_ejercicios_catalogo
              (nombre, instrucciones, instrucciones_detalladas, url_video, foto, foto_nombre, foto_miniatura, visible_premium, tiempo, descanso, repeticiones, kilos, hashtag, codusuarioa, fechaa)
              VALUES (:nombre, :instrucciones, :instrucciones_detalladas, :url_video, :foto, :foto_nombre, :foto_miniatura, :visible_premium, :tiempo, :descanso, :repeticiones, :kilos, :hashtag, :codusuarioa, NOW())";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':instrucciones', $instrucciones);
    $stmt->bindParam(':instrucciones_detalladas', $instrucciones_detalladas, PDO::PARAM_LOB);
    $stmt->bindParam(':url_video', $url_video);
    $stmt->bindParam(':foto', $foto_blob, PDO::PARAM_LOB);
    $stmt->bindParam(':foto_nombre', $foto_nombre);
    $stmt->bindParam(':foto_miniatura', $foto_miniatura_blob, PDO::PARAM_LOB);
    $stmt->bindParam(':visible_premium', $visible_premium);
    $stmt->bindParam(':tiempo', $tiempo);
    $stmt->bindParam(':descanso', $descanso);
    $stmt->bindParam(':repeticiones', $repeticiones);
    $stmt->bindParam(':kilos', $kilos);
    $stmt->bindParam(':hashtag', $hashtag);
    $stmt->bindParam(':codusuarioa', $codusuarioa);

    if ($stmt->execute()) {
        $codigo_ejercicio = $db->lastInsertId();
        
        // Guardar categorías si se proporcionan
        if (isset($data->categorias)) {
            $categorias = $data->categorias;
            if (is_array($categorias) && !empty($categorias)) {
                $stmtCat = $db->prepare("INSERT INTO nu_plan_fit_ejercicios_categorias (codigo_ejercicio, codigo_categoria) VALUES (:codigo_ejercicio, :codigo_categoria)");
                foreach ($categorias as $codigo_categoria) {
                    $codigo_categoria_int = intval($codigo_categoria);
                    $stmtCat->bindParam(':codigo_ejercicio', $codigo_ejercicio, PDO::PARAM_INT);
                    $stmtCat->bindValue(':codigo_categoria', $codigo_categoria_int, PDO::PARAM_INT);
                    $stmtCat->execute();
                }
            }
        }
        
        http_response_code(201);
        ob_clean();
        echo json_encode(["message" => "Ejercicio del catalogo creado.", "codigo" => $codigo_ejercicio]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "No se pudo crear el ejercicio del catalogo.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function update_catalog_ejercicio() {
    global $db;
    ensure_catalog_table();

    $data = json_decode(file_get_contents("php://input"));

    $codigo = isset($data->codigo) ? intval($data->codigo) : 0;
    if ($codigo === 0) {
        http_response_code(400);
        echo json_encode(["message" => "Falta el codigo del ejercicio."]);
        return;
    }

    $set = [];
    $bind = [':codigo' => $codigo];

    if (isset($data->nombre)) {
        $nombre = trim($data->nombre);
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
    if (isset($data->clear_instrucciones) && $data->clear_instrucciones == '1') {
        $set[] = "instrucciones = :instrucciones";
        $bind[':instrucciones'] = null;
    } elseif (isset($data->instrucciones)) {
        $instrucciones_trim = trim($data->instrucciones);
        $set[] = "instrucciones = :instrucciones";
        $bind[':instrucciones'] = $instrucciones_trim !== ''
            ? $instrucciones_trim
            : null;
    }
    if (isset($data->clear_instrucciones_detalladas) && $data->clear_instrucciones_detalladas == '1') {
        $set[] = "instrucciones_detalladas = :instrucciones_detalladas";
        $bind[':instrucciones_detalladas'] = null;
    } elseif (isset($data->instrucciones_detalladas)) {
        $instrucciones_detalladas_trim = trim($data->instrucciones_detalladas);
        $set[] = "instrucciones_detalladas = :instrucciones_detalladas";
        $bind[':instrucciones_detalladas'] = $instrucciones_detalladas_trim !== ''
            ? $instrucciones_detalladas_trim
            : null;
    }
    if (isset($data->url_video)) {
        $set[] = "url_video = :url_video";
        $bind[':url_video'] = $data->url_video;
    }
    if (isset($data->tiempo)) {
        $set[] = "tiempo = :tiempo";
        $bind[':tiempo'] = $data->tiempo !== '' ? intval($data->tiempo) : null;
    }
    if (isset($data->descanso)) {
        $set[] = "descanso = :descanso";
        $bind[':descanso'] = $data->descanso !== '' ? intval($data->descanso) : null;
    }
    if (isset($data->repeticiones)) {
        $set[] = "repeticiones = :repeticiones";
        $bind[':repeticiones'] = $data->repeticiones !== '' ? intval($data->repeticiones) : null;
    }
    if (isset($data->kilos)) {
        $set[] = "kilos = :kilos";
        $bind[':kilos'] = $data->kilos !== '' ? intval($data->kilos) : null;
    }
    if (isset($data->visible_premium)) {
        $set[] = "visible_premium = :visible_premium";
        $bind[':visible_premium'] = $data->visible_premium === 'S' ? 'S' : 'N';
    }
    if (isset($data->hashtag)) {
        $hashtag_trim = trim($data->hashtag);
        $set[] = "hashtag = :hashtag";
        $bind[':hashtag'] = $hashtag_trim !== '' ? $hashtag_trim : null;
    }
    if (isset($data->codusuariom)) {
        $set[] = "codusuariom = :codusuariom";
        $bind[':codusuariom'] = intval($data->codusuariom);
    }

    if (isset($data->eliminar_foto) && $data->eliminar_foto == '1') {
        $set[] = "foto = NULL";
        $set[] = "foto_nombre = NULL";
        $set[] = "foto_miniatura = NULL";
    }

    if (isset($data->foto) && $data->foto !== '') {
        $decoded = base64_decode($data->foto);
        $set[] = "foto = :foto";
        $bind[':foto'] = $decoded;
        $set[] = "foto_nombre = :foto_nombre";
        $bind[':foto_nombre'] = $data->foto_nombre ?? 'foto.jpg';
    }
    
    // Procesar miniatura independientemente (puede llegar sola cuando se regenera)
    if (isset($data->foto_miniatura) && $data->foto_miniatura !== '') {
        $decoded_miniatura = base64_decode($data->foto_miniatura);
        $set[] = "foto_miniatura = :foto_miniatura";
        $bind[':foto_miniatura'] = $decoded_miniatura;
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
        if ($key === ':foto' || $key === ':foto_miniatura' || $key === ':instrucciones_detalladas') {
            $stmt->bindParam($key, $val, PDO::PARAM_LOB);
        } else {
            $stmt->bindParam($key, $val);
        }
    }

    if ($stmt->execute()) {
        if (isset($data->categorias)) {
            $stmtDel = $db->prepare("DELETE FROM nu_plan_fit_ejercicios_categorias WHERE codigo_ejercicio = :codigo");
            $stmtDel->bindParam(':codigo', $codigo);
            $stmtDel->execute();
            
            $categorias = is_array($data->categorias) ? $data->categorias : json_decode($data->categorias, true);
            if (is_array($categorias) && !empty($categorias)) {
                $stmtCat = $db->prepare("INSERT INTO nu_plan_fit_ejercicios_categorias (codigo_ejercicio, codigo_categoria) VALUES (:codigo_ejercicio, :codigo_categoria)");
                foreach ($categorias as $codigo_categoria) {
                    $codigo_categoria_int = intval($codigo_categoria);
                    $stmtCat->bindParam(':codigo_ejercicio', $codigo, PDO::PARAM_INT);
                    $stmtCat->bindValue(':codigo_categoria', $codigo_categoria_int, PDO::PARAM_INT);
                    $stmtCat->execute();
                }
            }
        }
        
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

    // No permitir borrar si hay ejercicios de plan fit asociados a este catálogo
    $stmtUso = $db->prepare("SELECT COUNT(*) AS total FROM nu_plan_fit_ejercicio WHERE codigo_ejercicio_catalogo = :codigo");
    $stmtUso->bindParam(':codigo', $codigo, PDO::PARAM_INT);
    $stmtUso->execute();
    $uso = $stmtUso->fetch(PDO::FETCH_ASSOC);
    $totalUso = isset($uso['total']) ? intval($uso['total']) : 0;

    if ($totalUso > 0) {
        http_response_code(409);
        ob_clean();
        echo json_encode([
            "message" => "No se puede eliminar el ejercicio porque hay planes fit que lo usan."
        ]);
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
    $codigo_ejercicio_catalogo = isset($_POST['codigo_ejercicio_catalogo']) && $_POST['codigo_ejercicio_catalogo'] !== '' ? intval($_POST['codigo_ejercicio_catalogo']) : null;
    $nombre = $_POST['nombre'] ?? '';
    $instrucciones = null;
    if (isset($_POST['instrucciones'])) {
        $instrucciones_trim = trim($_POST['instrucciones']);
        $instrucciones = $instrucciones_trim !== '' ? $instrucciones_trim : null;
    }
    $url_video = null;
    if (isset($_POST['url_video'])) {
        $url_video_trim = trim($_POST['url_video']);
        $url_video = $url_video_trim !== '' ? $url_video_trim : null;
    }
    $tiempo = isset($_POST['tiempo']) && $_POST['tiempo'] !== '' ? intval($_POST['tiempo']) : null;
    $descanso = isset($_POST['descanso']) && $_POST['descanso'] !== '' ? intval($_POST['descanso']) : null;
    $repeticiones = isset($_POST['repeticiones']) && $_POST['repeticiones'] !== '' ? intval($_POST['repeticiones']) : null;
    $kilos = isset($_POST['kilos']) && $_POST['kilos'] !== '' ? intval($_POST['kilos']) : null;
    $orden = isset($_POST['orden']) && $_POST['orden'] !== '' ? intval($_POST['orden']) : 0;
    $codusuarioa = isset($_POST['codusuarioa']) ? intval($_POST['codusuarioa']) : 1;

    $query = "INSERT INTO nu_plan_fit_ejercicio (codigo_plan_fit, codigo_dia, codigo_ejercicio_catalogo, nombre, instrucciones, url_video, tiempo, descanso, repeticiones, kilos, orden, codusuarioa, fechaa)
              VALUES (:codigo_plan_fit, :codigo_dia, :codigo_ejercicio_catalogo, :nombre, :instrucciones, :url_video, :tiempo, :descanso, :repeticiones, :kilos, :orden, :codusuarioa, NOW())";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_plan_fit', $codigo_plan_fit);
    $stmt->bindParam(':codigo_dia', $codigo_dia);
    $stmt->bindParam(':codigo_ejercicio_catalogo', $codigo_ejercicio_catalogo);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':instrucciones', $instrucciones);
    $stmt->bindParam(':url_video', $url_video);
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
    if (isset($_POST['codigo_ejercicio_catalogo'])) {
        $set[] = "codigo_ejercicio_catalogo = :codigo_ejercicio_catalogo";
        $bind[':codigo_ejercicio_catalogo'] = $_POST['codigo_ejercicio_catalogo'] !== '' ? intval($_POST['codigo_ejercicio_catalogo']) : null;
    }
    if (isset($_POST['nombre'])) {
        $set[] = "nombre = :nombre";
        $bind[':nombre'] = $_POST['nombre'];
    }
    if (isset($_POST['clear_instrucciones']) && $_POST['clear_instrucciones'] == '1') {
        $set[] = "instrucciones = :instrucciones";
        $bind[':instrucciones'] = null;
    } elseif (isset($_POST['instrucciones'])) {
        $instrucciones_trim = trim($_POST['instrucciones']);
        $set[] = "instrucciones = :instrucciones";
        $bind[':instrucciones'] = $instrucciones_trim !== '' ? $instrucciones_trim : null;
    }
    if (isset($_POST['clear_url_video']) && $_POST['clear_url_video'] == '1') {
        $set[] = "url_video = :url_video";
        $bind[':url_video'] = null;
    } elseif (isset($_POST['url_video'])) {
        $url_video_trim = trim($_POST['url_video']);
        $set[] = "url_video = :url_video";
        $bind[':url_video'] = $url_video_trim !== '' ? $url_video_trim : null;
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

    $set[] = "fecham = NOW()";

    if (empty($set)) {
        http_response_code(400);
        echo json_encode(["message" => "No hay datos para actualizar."]);
        return;
    }

    $query = "UPDATE nu_plan_fit_ejercicio SET " . implode(", ", $set) . " WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    foreach ($bind as $key => &$val) {
        $stmt->bindParam($key, $val);
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
