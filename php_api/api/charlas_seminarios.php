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

if (!$db) {
    http_response_code(500);
    echo json_encode(array('message' => 'No se pudo conectar con la base de datos.'));
    exit();
}

$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$validator = new AutoValidator($db);
$user = $validator->validate();
PermissionManager::checkPermission($user, 'charlas_seminarios');

ensure_charlas_tables();

$request_method = $_SERVER['REQUEST_METHOD'];

try {
    switch ($request_method) {
        case 'GET':
            if (isset($_GET['categorias'])) {
                get_charla_categorias();
            } elseif (!empty($_GET['diapositivas'])) {
                get_charla_diapositivas(intval($_GET['diapositivas']));
            } elseif (!empty($_GET['codigo'])) {
                get_charla(intval($_GET['codigo']));
            } elseif (isset($_GET['portada'])) {
                get_public_charlas(true);
            } elseif (isset($_GET['publico'])) {
                get_public_charlas(false);
            } elseif (isset($_GET['favoritos'])) {
                get_charlas_favoritas();
            } else {
                get_charlas();
            }
            break;

        case 'POST':
            if (isset($_GET['categorias'])) {
                require_manager();
                create_charla_categoria();
            } elseif (isset($_GET['toggle_like'])) {
                toggle_charla_like();
            } elseif (isset($_GET['toggle_favorito'])) {
                toggle_charla_favorito();
            } elseif (isset($_GET['progreso'])) {
                save_progreso_charla();
            } elseif (!empty($_GET['slide'])) {
                require_manager();
                create_diapositiva(intval($_GET['slide']));
            } else {
                require_manager();
                create_charla();
            }
            break;

        case 'PUT':
            if (isset($_GET['categorias']) && !empty($_GET['codigo'])) {
                require_manager();
                update_charla_categoria(intval($_GET['codigo']));
            } elseif (!empty($_GET['slide'])) {
                require_manager();
                update_diapositiva(intval($_GET['slide']));
            } else {
                require_manager();
                update_charla();
            }
            break;

        case 'DELETE':
            require_manager();
            if (isset($_GET['categorias']) && !empty($_GET['codigo'])) {
                delete_charla_categoria(intval($_GET['codigo']));
            } elseif (!empty($_GET['slide'])) {
                delete_diapositiva(intval($_GET['slide']));
            } elseif (!empty($_GET['codigo'])) {
                delete_charla(intval($_GET['codigo']));
            } else {
                http_response_code(400);
                echo json_encode(array('message' => 'Falta el código.'));
            }
            break;

        default:
            http_response_code(405);
            echo json_encode(array('message' => 'Método no permitido.'));
            break;
    }
} catch (Throwable $e) {
    error_log('charlas_seminarios.php error: ' . $e->getMessage());
    http_response_code(500);
    ob_clean();
    echo json_encode(array('message' => 'Error interno al procesar charlas/seminarios.', 'error' => $e->getMessage()));
}

// ─────────────────────────── HELPERS ───────────────────────────

function current_user_code() {
    global $user;
    return isset($user['codigo']) ? intval($user['codigo']) : 0;
}

function is_manager_user() {
    global $user;
    $user_type = PermissionManager::getUserType($user);
    return $user_type === PermissionManager::TYPE_NUTRITIONIST ||
        $user_type === PermissionManager::TYPE_ADMIN;
}

function require_manager() {
    if (!is_manager_user()) {
        http_response_code(403);
        echo json_encode(array('message' => 'Solo nutricionistas y administradores pueden gestionar charlas y seminarios.'));
        exit();
    }
}

function table_exists($table_name) {
    global $db;
    $stmt = $db->prepare("SHOW TABLES LIKE :table_name");
    $stmt->bindValue(':table_name', $table_name);
    $stmt->execute();
    return (bool)$stmt->fetchColumn();
}

function ensure_table_if_missing($table_name, $sql) {
    global $db;
    if (table_exists($table_name)) {
        return;
    }
    $db->exec($sql);
}

function column_exists($table_name, $column_name) {
    global $db;
    $stmt = $db->prepare("SHOW COLUMNS FROM `$table_name` LIKE :column_name");
    $stmt->bindValue(':column_name', $column_name);
    $stmt->execute();
    return (bool)$stmt->fetchColumn();
}

function ensure_column_if_missing($table_name, $column_name, $definition_sql) {
    global $db;
    if (column_exists($table_name, $column_name)) {
        return;
    }
    $db->exec("ALTER TABLE `$table_name` ADD COLUMN $column_name $definition_sql");
}

// ─────────────────────────── ENSURE TABLES ───────────────────────────

function ensure_charlas_tables() {
    global $db;

    ensure_table_if_missing('nu_charla_seminario', "CREATE TABLE IF NOT EXISTS nu_charla_seminario (
        codigo INT AUTO_INCREMENT PRIMARY KEY,
        titulo VARCHAR(220) NOT NULL,
        descripcion TEXT DEFAULT NULL,
        activo VARCHAR(1) DEFAULT 'S',
        mostrar_portada VARCHAR(1) DEFAULT 'N',
        visible_para_todos VARCHAR(1) DEFAULT 'N',
        imagen_portada LONGBLOB DEFAULT NULL,
        imagen_portada_nombre VARCHAR(255) DEFAULT NULL,
        imagen_miniatura LONGBLOB DEFAULT NULL,
        total_diapositivas INT DEFAULT 0,
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        fecham DATETIME DEFAULT NULL,
        codusuariom INT DEFAULT NULL,
        KEY idx_charla_activo (activo),
        KEY idx_charla_portada (mostrar_portada),
        KEY idx_charla_visible (visible_para_todos)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    ensure_table_if_missing('nu_charla_seminario_categoria', "CREATE TABLE IF NOT EXISTS nu_charla_seminario_categoria (
        codigo INT AUTO_INCREMENT PRIMARY KEY,
        nombre VARCHAR(150) NOT NULL,
        activo VARCHAR(1) DEFAULT 'S',
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        fecham DATETIME DEFAULT NULL,
        codusuariom INT DEFAULT NULL,
        UNIQUE KEY unique_charla_categoria_nombre (nombre)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    ensure_table_if_missing('nu_charla_seminario_categoria_rel', "CREATE TABLE IF NOT EXISTS nu_charla_seminario_categoria_rel (
        codigo_charla INT NOT NULL,
        codigo_categoria INT NOT NULL,
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        PRIMARY KEY (codigo_charla, codigo_categoria),
        KEY idx_charla_cat_rel (codigo_categoria),
        CONSTRAINT charla_cat_rel_item_fk FOREIGN KEY (codigo_charla) REFERENCES nu_charla_seminario(codigo) ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT charla_cat_rel_cat_fk FOREIGN KEY (codigo_categoria) REFERENCES nu_charla_seminario_categoria(codigo) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    ensure_table_if_missing('nu_charla_seminario_diapositiva', "CREATE TABLE IF NOT EXISTS nu_charla_seminario_diapositiva (
        codigo INT AUTO_INCREMENT PRIMARY KEY,
        codigo_charla INT NOT NULL,
        numero_diapositiva INT NOT NULL,
        imagen_diapositiva LONGBLOB DEFAULT NULL,
        imagen_diapositiva_nombre VARCHAR(255) DEFAULT NULL,
        imagen_miniatura LONGBLOB DEFAULT NULL,
        audio_diapositiva LONGBLOB DEFAULT NULL,
        audio_diapositiva_nombre VARCHAR(255) DEFAULT NULL,
        audio_diapositiva_mime VARCHAR(120) DEFAULT NULL,
        audio_duracion_ms INT DEFAULT NULL,
        ancho_px INT DEFAULT NULL,
        alto_px INT DEFAULT NULL,
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        fecham DATETIME DEFAULT NULL,
        codusuariom INT DEFAULT NULL,
        UNIQUE KEY unique_charla_slide (codigo_charla, numero_diapositiva),
        KEY idx_charla_slide_charla (codigo_charla),
        CONSTRAINT charla_slide_item_fk FOREIGN KEY (codigo_charla) REFERENCES nu_charla_seminario(codigo) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    ensure_table_if_missing('nu_charla_seminario_usuario', "CREATE TABLE IF NOT EXISTS nu_charla_seminario_usuario (
        codigo INT AUTO_INCREMENT PRIMARY KEY,
        codigo_charla INT NOT NULL,
        codigo_usuario INT NOT NULL,
        me_gusta VARCHAR(1) DEFAULT 'N',
        favorito VARCHAR(1) DEFAULT 'N',
        fecha_me_gusta DATETIME DEFAULT NULL,
        fecha_favorito DATETIME DEFAULT NULL,
        ultima_diapositiva_vista INT DEFAULT NULL,
        fecha_ultima_visualizacion DATETIME DEFAULT NULL,
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        fecham DATETIME DEFAULT NULL,
        codusuariom INT DEFAULT NULL,
        UNIQUE KEY unique_charla_usuario (codigo_charla, codigo_usuario),
        KEY idx_charla_usuario_fav (codigo_usuario, favorito),
        CONSTRAINT charla_usuario_item_fk FOREIGN KEY (codigo_charla) REFERENCES nu_charla_seminario(codigo) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    ensure_column_if_missing('nu_charla_seminario_diapositiva', 'audio_diapositiva', 'LONGBLOB DEFAULT NULL');
    ensure_column_if_missing('nu_charla_seminario_diapositiva', 'audio_diapositiva_nombre', 'VARCHAR(255) DEFAULT NULL');
    ensure_column_if_missing('nu_charla_seminario_diapositiva', 'audio_diapositiva_mime', 'VARCHAR(120) DEFAULT NULL');
    ensure_column_if_missing('nu_charla_seminario_diapositiva', 'audio_duracion_ms', 'INT DEFAULT NULL');
}

// ─────────────────────────── CAMPOS BASE SELECT ───────────────────────────

function base_charla_fields($include_portada = false, $include_user_state = false) {
    $fields = "c.codigo, c.titulo, c.descripcion, c.activo, c.mostrar_portada,
        c.visible_para_todos, c.imagen_portada_nombre, c.imagen_miniatura,
        c.total_diapositivas,
        c.fechaa, c.codusuarioa, c.fecham, c.codusuariom,
        (SELECT COUNT(*) FROM nu_charla_seminario_usuario cu WHERE cu.codigo_charla = c.codigo AND cu.me_gusta = 'S') AS total_likes,
        (SELECT GROUP_CONCAT(DISTINCT cc.codigo ORDER BY cc.nombre SEPARATOR ',')
            FROM nu_charla_seminario_categoria_rel ccr
            LEFT JOIN nu_charla_seminario_categoria cc ON ccr.codigo_categoria = cc.codigo AND cc.activo = 'S'
            WHERE ccr.codigo_charla = c.codigo) AS categorias_ids,
        (SELECT GROUP_CONCAT(DISTINCT cc.nombre ORDER BY cc.nombre SEPARATOR ',')
            FROM nu_charla_seminario_categoria_rel ccr
            LEFT JOIN nu_charla_seminario_categoria cc ON ccr.codigo_categoria = cc.codigo AND cc.activo = 'S'
            WHERE ccr.codigo_charla = c.codigo) AS categorias_nombres";

    if ($include_portada) {
        $fields .= ", c.imagen_portada";
    }

    if ($include_user_state && current_user_code() > 0) {
        $fields .= ", COALESCE(cu.me_gusta, 'N') AS me_gusta, COALESCE(cu.favorito, 'N') AS favorito,
            COALESCE(cu.ultima_diapositiva_vista, 0) AS ultima_diapositiva_vista";
    } else {
        $fields .= ", 'N' AS me_gusta, 'N' AS favorito, 0 AS ultima_diapositiva_vista";
    }

    return $fields;
}

function parse_charla_row($item, $include_portada = false) {
    if (!empty($item['imagen_miniatura'])) {
        $item['imagen_miniatura'] = base64_encode($item['imagen_miniatura']);
    }
    if ($include_portada && !empty($item['imagen_portada'])) {
        $item['imagen_portada'] = base64_encode($item['imagen_portada']);
    }
    if (isset($item['total_diapositivas'])) {
        $item['total_diapositivas'] = intval($item['total_diapositivas']);
    }
    if (isset($item['total_likes'])) {
        $item['total_likes'] = intval($item['total_likes']);
    }
    return $item;
}

// ─────────────────────────── CATEGORÍAS ───────────────────────────

function get_charla_categorias() {
    global $db;
    $stmt = $db->prepare("SELECT codigo, nombre, activo FROM nu_charla_seminario_categoria WHERE activo = 'S' ORDER BY nombre");
    $stmt->execute();
    ob_clean();
    echo json_encode($stmt->fetchAll(PDO::FETCH_ASSOC));
}

function create_charla_categoria() {
    global $db;
    $data = json_decode(file_get_contents('php://input'));
    $nombre = trim($data->nombre ?? '');

    if ($nombre === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Falta el nombre de la categoría.'));
        return;
    }

    $stmt = $db->prepare("SELECT codigo, nombre FROM nu_charla_seminario_categoria WHERE LOWER(nombre) = LOWER(:nombre) LIMIT 1");
    $stmt->bindParam(':nombre', $nombre);
    $stmt->execute();
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($existing) {
        ob_clean();
        echo json_encode(array('codigo' => intval($existing['codigo']), 'nombre' => $existing['nombre'], 'existed' => true));
        return;
    }

    $codigo_usuario = current_user_code();
    $stmt = $db->prepare("INSERT INTO nu_charla_seminario_categoria (nombre, activo, fechaa, codusuarioa) VALUES (:nombre, 'S', NOW(), :codusuarioa)");
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':codusuarioa', $codigo_usuario);

    if ($stmt->execute()) {
        http_response_code(201);
        ob_clean();
        echo json_encode(array('codigo' => intval($db->lastInsertId()), 'nombre' => $nombre, 'existed' => false));
        return;
    }

    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo crear la categoría.'));
}

function update_charla_categoria($codigo_categoria) {
    global $db;

    if ($codigo_categoria <= 0) {
        http_response_code(400);
        echo json_encode(array('message' => 'Código de categoría inválido.'));
        return;
    }

    $data = json_decode(file_get_contents('php://input'));
    $nombre = trim($data->nombre ?? '');

    if ($nombre === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Falta el nombre de la categoría.'));
        return;
    }

    $dup = $db->prepare("SELECT codigo FROM nu_charla_seminario_categoria WHERE LOWER(nombre) = LOWER(:nombre) AND codigo <> :codigo LIMIT 1");
    $dup->bindParam(':nombre', $nombre);
    $dup->bindParam(':codigo', $codigo_categoria, PDO::PARAM_INT);
    $dup->execute();
    if ($dup->fetch(PDO::FETCH_ASSOC)) {
        http_response_code(409);
        echo json_encode(array('message' => 'Ya existe otra categoría con ese nombre.'));
        return;
    }

    $codigo_usuario = current_user_code();
    $stmt = $db->prepare("UPDATE nu_charla_seminario_categoria SET nombre = :nombre, fecham = NOW(), codusuariom = :codusuariom WHERE codigo = :codigo");
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':codusuariom', $codigo_usuario, PDO::PARAM_INT);
    $stmt->bindParam(':codigo', $codigo_categoria, PDO::PARAM_INT);

    if ($stmt->execute()) {
        ob_clean();
        echo json_encode(array('message' => 'Categoría actualizada.', 'codigo' => $codigo_categoria, 'nombre' => $nombre));
        return;
    }

    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo actualizar la categoría.'));
}

function delete_charla_categoria($codigo_categoria) {
    global $db;

    if ($codigo_categoria <= 0) {
        http_response_code(400);
        echo json_encode(array('message' => 'Código de categoría inválido.'));
        return;
    }

    $stmt = $db->prepare("DELETE FROM nu_charla_seminario_categoria WHERE codigo = :codigo");
    $stmt->bindParam(':codigo', $codigo_categoria, PDO::PARAM_INT);

    if ($stmt->execute()) {
        ob_clean();
        echo json_encode(array('message' => 'Categoría eliminada.'));
        return;
    }

    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo eliminar la categoría.'));
}

function update_charla_categorias($codigo_charla, $categorias, $codigo_usuario) {
    global $db;

    $delete = $db->prepare("DELETE FROM nu_charla_seminario_categoria_rel WHERE codigo_charla = :codigo");
    $delete->bindParam(':codigo', $codigo_charla, PDO::PARAM_INT);
    $delete->execute();

    if (empty($categorias) || !is_array($categorias)) {
        return;
    }

    $insert = $db->prepare("INSERT INTO nu_charla_seminario_categoria_rel (codigo_charla, codigo_categoria, fechaa, codusuarioa) VALUES (:codigo_charla, :codigo_categoria, NOW(), :codusuarioa)");
    foreach ($categorias as $cat_id) {
        $cat_id = intval($cat_id);
        if ($cat_id <= 0) continue;
        $insert->bindParam(':codigo_charla', $codigo_charla, PDO::PARAM_INT);
        $insert->bindParam(':codigo_categoria', $cat_id, PDO::PARAM_INT);
        $insert->bindParam(':codusuarioa', $codigo_usuario, PDO::PARAM_INT);
        $insert->execute();
    }
}

// ─────────────────────────── GET CHARLAS ───────────────────────────

function get_charlas() {
    global $db;

    if (!is_manager_user()) {
        get_public_charlas(false);
        return;
    }

    $query = "SELECT " . base_charla_fields(false, false) . "
        FROM nu_charla_seminario c
        ORDER BY c.fechaa DESC, c.codigo DESC";

    $stmt = $db->prepare($query);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($items as &$item) {
        $item = parse_charla_row($item, false);
    }

    ob_clean();
    echo json_encode($items);
}

function get_public_charlas($solo_portada = false) {
    global $db;

    $user_code = current_user_code();
    $joins = '';
    if ($user_code > 0) {
        $joins = 'LEFT JOIN nu_charla_seminario_usuario cu ON c.codigo = cu.codigo_charla AND cu.codigo_usuario = :codigo_usuario';
    }

    $where = "WHERE c.activo = 'S' AND c.visible_para_todos = 'S'";
    if ($solo_portada) {
        $where .= " AND c.mostrar_portada = 'S'";
    }

    $query = "SELECT " . base_charla_fields(false, true) . "
        FROM nu_charla_seminario c
        $joins
        $where
        ORDER BY c.mostrar_portada DESC, total_likes DESC, c.fechaa DESC, c.codigo DESC";

    $stmt = $db->prepare($query);
    if ($user_code > 0) {
        $stmt->bindParam(':codigo_usuario', $user_code, PDO::PARAM_INT);
    }
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($items as &$item) {
        $item = parse_charla_row($item, false);
    }

    ob_clean();
    echo json_encode($items);
}

function get_charlas_favoritas() {
    global $db;

    $user_code = current_user_code();
    if ($user_code <= 0) {
        ob_clean();
        echo json_encode(array());
        return;
    }

    $query = "SELECT " . base_charla_fields(false, true) . "
        FROM nu_charla_seminario c
        LEFT JOIN nu_charla_seminario_usuario cu ON c.codigo = cu.codigo_charla AND cu.codigo_usuario = :codigo_usuario
        WHERE c.activo = 'S' AND cu.favorito = 'S'
        ORDER BY cu.fecha_favorito DESC, c.codigo DESC";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_usuario', $user_code, PDO::PARAM_INT);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($items as &$item) {
        $item = parse_charla_row($item, false);
    }

    ob_clean();
    echo json_encode($items);
}

function get_charla($codigo) {
    global $db;

    $user_code = current_user_code();
    $joins = '';
    if ($user_code > 0) {
        $joins = 'LEFT JOIN nu_charla_seminario_usuario cu ON c.codigo = cu.codigo_charla AND cu.codigo_usuario = :codigo_usuario';
    }

    $query = "SELECT " . base_charla_fields(true, true) . "
        FROM nu_charla_seminario c
        $joins
        WHERE c.codigo = :codigo
        LIMIT 1";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);
    if ($user_code > 0) {
        $stmt->bindParam(':codigo_usuario', $user_code, PDO::PARAM_INT);
    }
    $stmt->execute();
    $item = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$item) {
        http_response_code(404);
        echo json_encode(array('message' => 'Charla no encontrada.'));
        return;
    }

    ob_clean();
    echo json_encode(parse_charla_row($item, true));
}

function get_charla_diapositivas($codigo_charla) {
    global $db;

    $stmt = $db->prepare(
        "SELECT codigo, codigo_charla, numero_diapositiva, imagen_diapositiva, imagen_diapositiva_nombre, imagen_miniatura,
            audio_diapositiva, audio_diapositiva_nombre, audio_diapositiva_mime, audio_duracion_ms,
            ancho_px, alto_px
         FROM nu_charla_seminario_diapositiva
         WHERE codigo_charla = :codigo_charla
         ORDER BY numero_diapositiva ASC"
    );
    $stmt->bindParam(':codigo_charla', $codigo_charla, PDO::PARAM_INT);
    $stmt->execute();
    $slides = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($slides as &$slide) {
        if (!empty($slide['imagen_diapositiva'])) {
            $slide['imagen_diapositiva'] = base64_encode($slide['imagen_diapositiva']);
        }
        if (!empty($slide['imagen_miniatura'])) {
            $slide['imagen_miniatura'] = base64_encode($slide['imagen_miniatura']);
        }
        if (!empty($slide['audio_diapositiva'])) {
            $slide['audio_diapositiva'] = base64_encode($slide['audio_diapositiva']);
        }
        $slide['numero_diapositiva'] = intval($slide['numero_diapositiva']);
        $slide['ancho_px'] = $slide['ancho_px'] !== null ? intval($slide['ancho_px']) : null;
        $slide['alto_px']  = $slide['alto_px']  !== null ? intval($slide['alto_px'])  : null;
        $slide['audio_duracion_ms'] = $slide['audio_duracion_ms'] !== null ? intval($slide['audio_duracion_ms']) : null;
    }

    ob_clean();
    echo json_encode($slides);
}

// ─────────────────────────── CREATE / UPDATE CHARLA ───────────────────────────

function bind_charla_params($stmt, $data) {
    $titulo             = trim($data->titulo ?? '');
    $descripcion        = trim($data->descripcion ?? '');
    $activo             = !empty($data->activo) ? trim($data->activo) : 'S';
    $mostrar_portada    = !empty($data->mostrar_portada) ? trim($data->mostrar_portada) : 'N';
    $visible_para_todos = !empty($data->visible_para_todos) ? trim($data->visible_para_todos) : 'N';

    $imagen_portada       = null;
    $imagen_portada_nombre = null;
    if (!empty($data->imagen_portada)) {
        $imagen_portada        = base64_decode($data->imagen_portada);
        $imagen_portada_nombre = $data->imagen_portada_nombre ?? 'portada.jpg';
    }

    $imagen_miniatura = null;
    if (!empty($data->imagen_miniatura)) {
        $imagen_miniatura = base64_decode($data->imagen_miniatura);
    }

    $stmt->bindValue(':titulo', $titulo);
    $stmt->bindValue(':descripcion', $descripcion);
    $stmt->bindValue(':activo', $activo);
    $stmt->bindValue(':mostrar_portada', $mostrar_portada);
    $stmt->bindValue(':visible_para_todos', $visible_para_todos);
    $stmt->bindValue(':imagen_portada', $imagen_portada, PDO::PARAM_LOB);
    $stmt->bindValue(':imagen_portada_nombre', $imagen_portada_nombre);
    $stmt->bindValue(':imagen_miniatura', $imagen_miniatura, PDO::PARAM_LOB);
}

function create_charla() {
    global $db;
    $data = json_decode(file_get_contents('php://input'));

    if (!$data || empty(trim($data->titulo ?? ''))) {
        http_response_code(400);
        echo json_encode(array('message' => 'El título es obligatorio.'));
        return;
    }

    $codigo_usuario = current_user_code();
    $query = "INSERT INTO nu_charla_seminario SET
        titulo = :titulo,
        descripcion = :descripcion,
        activo = :activo,
        mostrar_portada = :mostrar_portada,
        visible_para_todos = :visible_para_todos,
        imagen_portada = :imagen_portada,
        imagen_portada_nombre = :imagen_portada_nombre,
        imagen_miniatura = :imagen_miniatura,
        total_diapositivas = 0,
        fechaa = NOW(),
        codusuarioa = :codusuarioa";

    $stmt = $db->prepare($query);
    bind_charla_params($stmt, $data);
    $stmt->bindParam(':codusuarioa', $codigo_usuario, PDO::PARAM_INT);

    if ($stmt->execute()) {
        $codigo = intval($db->lastInsertId());
        if (isset($data->categorias)) {
            update_charla_categorias($codigo, $data->categorias, $codigo_usuario);
        }
        http_response_code(201);
        ob_clean();
        echo json_encode(array('codigo' => $codigo, 'message' => 'Charla creada.'));
        return;
    }

    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo crear la charla.'));
}

function update_charla() {
    global $db;
    $data = json_decode(file_get_contents('php://input'));

    if (!$data || empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array('message' => 'Falta el código de la charla.'));
        return;
    }

    if (empty(trim($data->titulo ?? ''))) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array('message' => 'El título es obligatorio.'));
        return;
    }

    $codigo_usuario = current_user_code();

    // Solo actualizar imagen_portada / imagen_miniatura si se envían nuevas
    $imagen_sets = '';
    $imagen_portada = null;
    $imagen_portada_nombre = null;
    $imagen_miniatura = null;

    if (!empty($data->imagen_portada)) {
        $imagen_portada        = base64_decode($data->imagen_portada);
        $imagen_portada_nombre = $data->imagen_portada_nombre ?? 'portada.jpg';
        $imagen_sets .= ", imagen_portada = :imagen_portada, imagen_portada_nombre = :imagen_portada_nombre";
    }
    if (!empty($data->imagen_miniatura)) {
        $imagen_miniatura = base64_decode($data->imagen_miniatura);
        $imagen_sets .= ", imagen_miniatura = :imagen_miniatura";
    }

    $query = "UPDATE nu_charla_seminario SET
        titulo = :titulo,
        descripcion = :descripcion,
        activo = :activo,
        mostrar_portada = :mostrar_portada,
        visible_para_todos = :visible_para_todos
        $imagen_sets,
        fecham = NOW(),
        codusuariom = :codusuariom
        WHERE codigo = :codigo";

    $stmt = $db->prepare($query);
    $stmt->bindValue(':titulo', trim($data->titulo ?? ''));
    $stmt->bindValue(':descripcion', trim($data->descripcion ?? ''));
    $stmt->bindValue(':activo', !empty($data->activo) ? trim($data->activo) : 'S');
    $stmt->bindValue(':mostrar_portada', !empty($data->mostrar_portada) ? trim($data->mostrar_portada) : 'N');
    $stmt->bindValue(':visible_para_todos', !empty($data->visible_para_todos) ? trim($data->visible_para_todos) : 'N');
    if ($imagen_portada !== null) {
        $stmt->bindValue(':imagen_portada', $imagen_portada, PDO::PARAM_LOB);
        $stmt->bindValue(':imagen_portada_nombre', $imagen_portada_nombre);
    }
    if ($imagen_miniatura !== null) {
        $stmt->bindValue(':imagen_miniatura', $imagen_miniatura, PDO::PARAM_LOB);
    }
    $stmt->bindParam(':codusuariom', $codigo_usuario, PDO::PARAM_INT);
    $codigo = intval($data->codigo);
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);

    if ($stmt->execute()) {
        if (isset($data->categorias)) {
            update_charla_categorias($codigo, $data->categorias, $codigo_usuario);
        }
        ob_clean();
        echo json_encode(array('message' => 'Charla actualizada.'));
        return;
    }

    http_response_code(503);
    ob_clean();
    echo json_encode(array('message' => 'No se pudo actualizar la charla.'));
}

function delete_charla($codigo) {
    global $db;

    $stmt = $db->prepare("DELETE FROM nu_charla_seminario WHERE codigo = :codigo");
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);

    if ($stmt->execute() && $stmt->rowCount() > 0) {
        ob_clean();
        echo json_encode(array('message' => 'Charla eliminada.'));
        return;
    }

    http_response_code(404);
    echo json_encode(array('message' => 'Charla no encontrada.'));
}

// ─────────────────────────── DIAPOSITIVAS ───────────────────────────

function create_diapositiva($codigo_charla) {
    global $db;
    $data = json_decode(file_get_contents('php://input'));

    if (!$data || empty($data->imagen_diapositiva)) {
        http_response_code(400);
        echo json_encode(array('message' => 'Falta la imagen de la diapositiva.'));
        return;
    }

    // Determinar número de diapositiva (próximo disponible)
    $numero = isset($data->numero_diapositiva) ? intval($data->numero_diapositiva) : null;
    if (!$numero || $numero <= 0) {
        $max_stmt = $db->prepare("SELECT COALESCE(MAX(numero_diapositiva), 0) + 1 AS next_num FROM nu_charla_seminario_diapositiva WHERE codigo_charla = :codigo_charla");
        $max_stmt->bindParam(':codigo_charla', $codigo_charla, PDO::PARAM_INT);
        $max_stmt->execute();
        $numero = intval($max_stmt->fetch(PDO::FETCH_ASSOC)['next_num']);
    }

    $imagen        = base64_decode($data->imagen_diapositiva);
    $nombre        = $data->imagen_diapositiva_nombre ?? "slide_{$numero}.jpg";
    $miniatura     = !empty($data->imagen_miniatura) ? base64_decode($data->imagen_miniatura) : null;
    $ancho_px      = isset($data->ancho_px)  ? intval($data->ancho_px)  : null;
    $alto_px       = isset($data->alto_px)   ? intval($data->alto_px)   : null;
    $audio_diapositiva       = !empty($data->audio_diapositiva) ? base64_decode($data->audio_diapositiva) : null;
    $audio_diapositiva_nombre = !empty($data->audio_diapositiva_nombre) ? $data->audio_diapositiva_nombre : null;
    $audio_diapositiva_mime   = !empty($data->audio_diapositiva_mime) ? $data->audio_diapositiva_mime : null;
    $audio_duracion_ms        = isset($data->audio_duracion_ms) ? intval($data->audio_duracion_ms) : null;
    $codigo_usuario = current_user_code();

    $stmt = $db->prepare(
        "INSERT INTO nu_charla_seminario_diapositiva
            (codigo_charla, numero_diapositiva, imagen_diapositiva, imagen_diapositiva_nombre, imagen_miniatura,
             audio_diapositiva, audio_diapositiva_nombre, audio_diapositiva_mime, audio_duracion_ms,
             ancho_px, alto_px, fechaa, codusuarioa)
         VALUES (:codigo_charla, :numero, :imagen, :nombre, :miniatura,
                 :audio, :audio_nombre, :audio_mime, :audio_duracion_ms,
                 :ancho, :alto, NOW(), :codusuarioa)"
    );
    $stmt->bindParam(':codigo_charla', $codigo_charla, PDO::PARAM_INT);
    $stmt->bindParam(':numero', $numero, PDO::PARAM_INT);
    $stmt->bindParam(':imagen', $imagen, PDO::PARAM_LOB);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':miniatura', $miniatura, PDO::PARAM_LOB);
    $stmt->bindParam(':audio', $audio_diapositiva, PDO::PARAM_LOB);
    $stmt->bindParam(':audio_nombre', $audio_diapositiva_nombre);
    $stmt->bindParam(':audio_mime', $audio_diapositiva_mime);
    $stmt->bindParam(':audio_duracion_ms', $audio_duracion_ms);
    $stmt->bindParam(':ancho', $ancho_px);
    $stmt->bindParam(':alto', $alto_px);
    $stmt->bindParam(':codusuarioa', $codigo_usuario, PDO::PARAM_INT);

    if ($stmt->execute()) {
        // Actualizar total_diapositivas en la charla
        $db->prepare("UPDATE nu_charla_seminario SET total_diapositivas = (SELECT COUNT(*) FROM nu_charla_seminario_diapositiva WHERE codigo_charla = :c) WHERE codigo = :c2")
           ->execute(array(':c' => $codigo_charla, ':c2' => $codigo_charla));

        http_response_code(201);
        ob_clean();
        echo json_encode(array('codigo' => intval($db->lastInsertId()), 'numero_diapositiva' => $numero, 'message' => 'Diapositiva creada.'));
        return;
    }

    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo crear la diapositiva.'));
}

function update_diapositiva($codigo_slide) {
    global $db;
    $data = json_decode(file_get_contents('php://input'));

    if (!$data) {
        http_response_code(400);
        echo json_encode(array('message' => 'Cuerpo de la petición inválido.'));
        return;
    }

    $imagen        = !empty($data->imagen_diapositiva) ? base64_decode($data->imagen_diapositiva) : null;
    $nombre        = !empty($data->imagen_diapositiva_nombre) ? $data->imagen_diapositiva_nombre : null;
    $miniatura     = !empty($data->imagen_miniatura) ? base64_decode($data->imagen_miniatura) : null;
    $ancho_px      = isset($data->ancho_px) ? intval($data->ancho_px) : null;
    $alto_px       = isset($data->alto_px)  ? intval($data->alto_px)  : null;
    $numero        = isset($data->numero_diapositiva) ? intval($data->numero_diapositiva) : null;
    $audio         = !empty($data->audio_diapositiva) ? base64_decode($data->audio_diapositiva) : null;
    $audio_nombre  = !empty($data->audio_diapositiva_nombre) ? $data->audio_diapositiva_nombre : null;
    $audio_mime    = !empty($data->audio_diapositiva_mime) ? $data->audio_diapositiva_mime : null;
    $audio_duracion_ms = isset($data->audio_duracion_ms) ? intval($data->audio_duracion_ms) : null;
    $clear_audio   = !empty($data->clear_audio);
    $codigo_usuario = current_user_code();

    $parts  = array('fecham = NOW()', 'codusuariom = :codusuariom');
    $params = array(':codusuariom' => $codigo_usuario, ':codigo' => $codigo_slide);

    if ($imagen !== null)    { $parts[] = 'imagen_diapositiva = :imagen'; }
    if ($nombre !== null)    { $parts[] = 'imagen_diapositiva_nombre = :nombre'; }
    if ($miniatura !== null) { $parts[] = 'imagen_miniatura = :miniatura'; }
    if ($ancho_px !== null)  { $parts[] = 'ancho_px = :ancho'; }
    if ($alto_px !== null)   { $parts[] = 'alto_px = :alto'; }
    if ($numero !== null)    { $parts[] = 'numero_diapositiva = :numero'; }
    if ($audio !== null)     { $parts[] = 'audio_diapositiva = :audio'; }
    if ($audio_nombre !== null) { $parts[] = 'audio_diapositiva_nombre = :audio_nombre'; }
    if ($audio_mime !== null) { $parts[] = 'audio_diapositiva_mime = :audio_mime'; }
    if ($audio_duracion_ms !== null) { $parts[] = 'audio_duracion_ms = :audio_duracion_ms'; }
    if ($clear_audio) {
        $parts[] = 'audio_diapositiva = NULL';
        $parts[] = 'audio_diapositiva_nombre = NULL';
        $parts[] = 'audio_diapositiva_mime = NULL';
        $parts[] = 'audio_duracion_ms = NULL';
    }

    $stmt = $db->prepare("UPDATE nu_charla_seminario_diapositiva SET " . implode(', ', $parts) . " WHERE codigo = :codigo");
    foreach ($params as $k => $v) { $stmt->bindValue($k, $v); }
    if ($imagen !== null)    { $stmt->bindParam(':imagen', $imagen, PDO::PARAM_LOB); }
    if ($nombre !== null)    { $stmt->bindValue(':nombre', $nombre); }
    if ($miniatura !== null) { $stmt->bindParam(':miniatura', $miniatura, PDO::PARAM_LOB); }
    if ($ancho_px !== null)  { $stmt->bindValue(':ancho', $ancho_px, PDO::PARAM_INT); }
    if ($alto_px !== null)   { $stmt->bindValue(':alto', $alto_px, PDO::PARAM_INT); }
    if ($numero !== null)    { $stmt->bindValue(':numero', $numero, PDO::PARAM_INT); }
    if ($audio !== null)     { $stmt->bindParam(':audio', $audio, PDO::PARAM_LOB); }
    if ($audio_nombre !== null) { $stmt->bindValue(':audio_nombre', $audio_nombre); }
    if ($audio_mime !== null) { $stmt->bindValue(':audio_mime', $audio_mime); }
    if ($audio_duracion_ms !== null) { $stmt->bindValue(':audio_duracion_ms', $audio_duracion_ms, PDO::PARAM_INT); }

    if ($stmt->execute()) {
        ob_clean();
        echo json_encode(array('message' => 'Diapositiva actualizada.'));
        return;
    }

    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo actualizar la diapositiva.'));
}

function delete_diapositiva($codigo_slide) {
    global $db;

    // Obtener el codigo_charla antes de borrar
    $row = $db->prepare("SELECT codigo_charla FROM nu_charla_seminario_diapositiva WHERE codigo = :c");
    $row->bindParam(':c', $codigo_slide, PDO::PARAM_INT);
    $row->execute();
    $slide = $row->fetch(PDO::FETCH_ASSOC);

    if (!$slide) {
        http_response_code(404);
        echo json_encode(array('message' => 'Diapositiva no encontrada.'));
        return;
    }

    $codigo_charla = intval($slide['codigo_charla']);

    $stmt = $db->prepare("DELETE FROM nu_charla_seminario_diapositiva WHERE codigo = :codigo");
    $stmt->bindParam(':codigo', $codigo_slide, PDO::PARAM_INT);

    if ($stmt->execute() && $stmt->rowCount() > 0) {
        // Renumerar diapositivas y actualizar total
        renumerate_slides($codigo_charla);
        ob_clean();
        echo json_encode(array('message' => 'Diapositiva eliminada.'));
        return;
    }

    http_response_code(404);
    echo json_encode(array('message' => 'Diapositiva no encontrada.'));
}

function renumerate_slides($codigo_charla) {
    global $db;

    // Obtener slides ordenadas
    $stmt = $db->prepare("SELECT codigo FROM nu_charla_seminario_diapositiva WHERE codigo_charla = :c ORDER BY numero_diapositiva ASC, codigo ASC");
    $stmt->bindParam(':c', $codigo_charla, PDO::PARAM_INT);
    $stmt->execute();
    $slides = $stmt->fetchAll(PDO::FETCH_COLUMN);

    $upd = $db->prepare("UPDATE nu_charla_seminario_diapositiva SET numero_diapositiva = :n WHERE codigo = :c");
    foreach ($slides as $i => $slide_codigo) {
        $n = $i + 1;
        $upd->bindParam(':n', $n, PDO::PARAM_INT);
        $upd->bindParam(':c', $slide_codigo, PDO::PARAM_INT);
        $upd->execute();
    }

    $total = count($slides);
    $upd2 = $db->prepare("UPDATE nu_charla_seminario SET total_diapositivas = :total WHERE codigo = :c");
    $upd2->bindParam(':total', $total, PDO::PARAM_INT);
    $upd2->bindParam(':c', $codigo_charla, PDO::PARAM_INT);
    $upd2->execute();
}

// ─────────────────────────── TOGGLE LIKE / FAVORITO ───────────────────────────

function toggle_charla_like() {
    global $db;
    $data = json_decode(file_get_contents('php://input'));

    $codigo_charla  = isset($data->codigo_charla)  ? intval($data->codigo_charla)  : 0;
    $codigo_usuario = isset($data->codigo_usuario) ? intval($data->codigo_usuario) : current_user_code();

    if ($codigo_charla <= 0 || $codigo_usuario <= 0) {
        http_response_code(400);
        echo json_encode(array('message' => 'Datos insuficientes.'));
        return;
    }

    // Upsert
    $stmt = $db->prepare(
        "INSERT INTO nu_charla_seminario_usuario (codigo_charla, codigo_usuario, me_gusta, fecha_me_gusta, fechaa, codusuarioa)
         VALUES (:charla, :usuario, 'S', NOW(), NOW(), :ua)
         ON DUPLICATE KEY UPDATE
           me_gusta = IF(me_gusta = 'S', 'N', 'S'),
           fecha_me_gusta = IF(me_gusta = 'S', fecha_me_gusta, NOW())"
    );
    $stmt->bindParam(':charla', $codigo_charla, PDO::PARAM_INT);
    $stmt->bindParam(':usuario', $codigo_usuario, PDO::PARAM_INT);
    $stmt->bindParam(':ua', $codigo_usuario, PDO::PARAM_INT);
    $stmt->execute();

    $row = $db->prepare("SELECT me_gusta FROM nu_charla_seminario_usuario WHERE codigo_charla = :charla AND codigo_usuario = :usuario");
    $row->bindParam(':charla', $codigo_charla, PDO::PARAM_INT);
    $row->bindParam(':usuario', $codigo_usuario, PDO::PARAM_INT);
    $row->execute();
    $result = $row->fetch(PDO::FETCH_ASSOC);

    ob_clean();
    echo json_encode(array('me_gusta' => $result ? $result['me_gusta'] : 'N'));
}

function toggle_charla_favorito() {
    global $db;
    $data = json_decode(file_get_contents('php://input'));

    $codigo_charla  = isset($data->codigo_charla)  ? intval($data->codigo_charla)  : 0;
    $codigo_usuario = isset($data->codigo_usuario) ? intval($data->codigo_usuario) : current_user_code();

    if ($codigo_charla <= 0 || $codigo_usuario <= 0) {
        http_response_code(400);
        echo json_encode(array('message' => 'Datos insuficientes.'));
        return;
    }

    $stmt = $db->prepare(
        "INSERT INTO nu_charla_seminario_usuario (codigo_charla, codigo_usuario, favorito, fecha_favorito, fechaa, codusuarioa)
         VALUES (:charla, :usuario, 'S', NOW(), NOW(), :ua)
         ON DUPLICATE KEY UPDATE
           favorito = IF(favorito = 'S', 'N', 'S'),
           fecha_favorito = IF(favorito = 'S', fecha_favorito, NOW())"
    );
    $stmt->bindParam(':charla', $codigo_charla, PDO::PARAM_INT);
    $stmt->bindParam(':usuario', $codigo_usuario, PDO::PARAM_INT);
    $stmt->bindParam(':ua', $codigo_usuario, PDO::PARAM_INT);
    $stmt->execute();

    $row = $db->prepare("SELECT favorito FROM nu_charla_seminario_usuario WHERE codigo_charla = :charla AND codigo_usuario = :usuario");
    $row->bindParam(':charla', $codigo_charla, PDO::PARAM_INT);
    $row->bindParam(':usuario', $codigo_usuario, PDO::PARAM_INT);
    $row->execute();
    $result = $row->fetch(PDO::FETCH_ASSOC);

    ob_clean();
    echo json_encode(array('favorito' => $result ? $result['favorito'] : 'N'));
}

function save_progreso_charla() {
    global $db;
    $data = json_decode(file_get_contents('php://input'));

    $codigo_charla           = isset($data->codigo_charla)              ? intval($data->codigo_charla)              : 0;
    $codigo_usuario          = isset($data->codigo_usuario)             ? intval($data->codigo_usuario)             : current_user_code();
    $ultima_diapositiva_vista = isset($data->ultima_diapositiva_vista) ? intval($data->ultima_diapositiva_vista) : 1;

    if ($codigo_charla <= 0 || $codigo_usuario <= 0) {
        http_response_code(400);
        echo json_encode(array('message' => 'Datos insuficientes.'));
        return;
    }

    $stmt = $db->prepare(
        "INSERT INTO nu_charla_seminario_usuario (codigo_charla, codigo_usuario, ultima_diapositiva_vista, fecha_ultima_visualizacion, fechaa, codusuarioa)
         VALUES (:charla, :usuario, :slide, NOW(), NOW(), :ua)
         ON DUPLICATE KEY UPDATE
           ultima_diapositiva_vista = :slide2,
           fecha_ultima_visualizacion = NOW()"
    );
    $stmt->bindParam(':charla', $codigo_charla, PDO::PARAM_INT);
    $stmt->bindParam(':usuario', $codigo_usuario, PDO::PARAM_INT);
    $stmt->bindParam(':slide', $ultima_diapositiva_vista, PDO::PARAM_INT);
    $stmt->bindParam(':slide2', $ultima_diapositiva_vista, PDO::PARAM_INT);
    $stmt->bindParam(':ua', $codigo_usuario, PDO::PARAM_INT);
    $stmt->execute();

    ob_clean();
    echo json_encode(array('message' => 'Progreso guardado.'));
}

