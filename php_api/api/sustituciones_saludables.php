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

$validator = new AutoValidator($db);
$user = $validator->validate();

ensure_sustitucion_tables();

$request_method = $_SERVER['REQUEST_METHOD'];

function require_sustituciones_permission() {
    global $user;
    PermissionManager::checkPermission($user, 'premium_exclusive');
}

switch ($request_method) {
    case 'GET':
        if (isset($_GET['total'])) {
            get_sustituciones_total();
        } else if (isset($_GET['categorias'])) {
            require_sustituciones_permission();
            get_sustitucion_categorias();
        } else if (!empty($_GET['codigo'])) {
            get_sustitucion(intval($_GET['codigo']));
        } else if (isset($_GET['portada'])) {
            get_public_sustituciones(true);
        } else if (isset($_GET['publico'])) {
            get_public_sustituciones(false);
        } else {
            require_sustituciones_permission();
            get_sustituciones();
        }
        break;
    case 'POST':
        require_sustituciones_permission();
        if (isset($_GET['categorias'])) {
            require_manager();
            create_sustitucion_categoria();
        } else {
            require_manager();
            create_sustitucion();
        }
        break;
    case 'PUT':
        require_sustituciones_permission();
        require_manager();
        if (isset($_GET['categorias'])) {
            update_sustitucion_categoria();
        } else {
            update_sustitucion();
        }
        break;
    case 'DELETE':
        require_sustituciones_permission();
        require_manager();
        if (isset($_GET['categorias'])) {
            if (!empty($_GET['codigo'])) {
                delete_sustitucion_categoria(intval($_GET['codigo']));
            } else {
                http_response_code(400);
                echo json_encode(array('message' => 'Falta el código de la categoría.'));
            }
        } else if (!empty($_GET['codigo'])) {
            delete_sustitucion(intval($_GET['codigo']));
        } else {
            http_response_code(400);
            echo json_encode(array('message' => 'Falta el código de la sustitución.'));
        }
        break;
    default:
        http_response_code(405);
        echo json_encode(array('message' => 'Método no permitido.'));
        break;
}

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
        echo json_encode(array(
            'message' => 'Solo nutricionistas y administradores pueden gestionar sustituciones saludables.'
        ));
        exit();
    }
}

function ensure_sustitucion_tables() {
    global $db;

    $db->exec("CREATE TABLE IF NOT EXISTS nu_sustitucion_saludable (
        codigo INT AUTO_INCREMENT PRIMARY KEY,
        titulo VARCHAR(180) NOT NULL,
        subtitulo VARCHAR(255) DEFAULT NULL,
        alimento_origen VARCHAR(160) NOT NULL,
        sustituto_principal VARCHAR(160) NOT NULL,
        equivalencia_texto VARCHAR(255) DEFAULT NULL,
        objetivo_macro VARCHAR(120) DEFAULT NULL,
        texto TEXT DEFAULT NULL,
        activo VARCHAR(1) DEFAULT 'S',
        mostrar_portada VARCHAR(1) DEFAULT 'N',
        visible_para_todos VARCHAR(1) DEFAULT 'S',
        imagen_portada LONGBLOB DEFAULT NULL,
        imagen_portada_nombre VARCHAR(255) DEFAULT NULL,
        imagen_miniatura LONGBLOB DEFAULT NULL,
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        fecham DATETIME DEFAULT NULL,
        codusuariom INT DEFAULT NULL,
        KEY idx_sustitucion_activo (activo),
        KEY idx_sustitucion_portada (mostrar_portada),
        KEY idx_sustitucion_visible (visible_para_todos)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $db->exec("CREATE TABLE IF NOT EXISTS nu_sustitucion_saludable_categoria (
        codigo INT AUTO_INCREMENT PRIMARY KEY,
        nombre VARCHAR(150) NOT NULL,
        activo VARCHAR(1) DEFAULT 'S',
        imagen_portada LONGBLOB DEFAULT NULL,
        imagen_portada_nombre VARCHAR(255) DEFAULT NULL,
        imagen_miniatura LONGBLOB DEFAULT NULL,
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        fecham DATETIME DEFAULT NULL,
        codusuariom INT DEFAULT NULL,
        UNIQUE KEY unique_sustitucion_categoria_nombre (nombre)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $db->exec("CREATE TABLE IF NOT EXISTS nu_sustitucion_saludable_categoria_rel (
        codigo_sustitucion INT NOT NULL,
        codigo_categoria INT NOT NULL,
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        PRIMARY KEY (codigo_sustitucion, codigo_categoria),
        KEY idx_sustitucion_categoria_rel_cat (codigo_categoria),
        CONSTRAINT sustitucion_categoria_rel_item_fk FOREIGN KEY (codigo_sustitucion) REFERENCES nu_sustitucion_saludable(codigo) ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT sustitucion_categoria_rel_categoria_fk FOREIGN KEY (codigo_categoria) REFERENCES nu_sustitucion_saludable_categoria(codigo) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $db->exec("CREATE TABLE IF NOT EXISTS nu_sustitucion_saludable_usuario (
        codigo INT AUTO_INCREMENT PRIMARY KEY,
        codigo_sustitucion INT NOT NULL,
        codigo_usuario INT NOT NULL,
        me_gusta VARCHAR(1) DEFAULT 'N',
        favorito VARCHAR(1) DEFAULT 'N',
        fecha_me_gusta DATETIME DEFAULT NULL,
        fecha_favorito DATETIME DEFAULT NULL,
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        fecham DATETIME DEFAULT NULL,
        codusuariom INT DEFAULT NULL,
        UNIQUE KEY unique_sustitucion_usuario (codigo_sustitucion, codigo_usuario),
        KEY idx_sustitucion_usuario_favorito (codigo_usuario, favorito),
        CONSTRAINT sustitucion_usuario_item_fk FOREIGN KEY (codigo_sustitucion) REFERENCES nu_sustitucion_saludable(codigo) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

function get_sustitucion_categorias() {
    global $db;
    $include_all = isset($_GET['todos']) && strval($_GET['todos']) === '1';
    $where_clause = $include_all ? "" : "WHERE sc.activo = 'S'";

    $stmt = $db->prepare("SELECT
            sc.codigo,
            sc.nombre,
            sc.activo,
            COUNT(scr.codigo_sustitucion) AS total_sustituciones
        FROM nu_sustitucion_saludable_categoria sc
        LEFT JOIN nu_sustitucion_saludable_categoria_rel scr ON scr.codigo_categoria = sc.codigo
        $where_clause
        GROUP BY sc.codigo, sc.nombre, sc.activo
        ORDER BY sc.nombre");
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($items as &$item) {
        $item['total_sustituciones'] = intval($item['total_sustituciones'] ?? 0);
    }
    echo json_encode($items);
}

function create_sustitucion_categoria() {
    global $db;
    $data = json_decode(file_get_contents('php://input'));
    $nombre = trim($data->nombre ?? '');

    if ($nombre === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Falta el nombre de la categoría.'));
        return;
    }

    $stmt = $db->prepare("SELECT codigo, nombre FROM nu_sustitucion_saludable_categoria WHERE LOWER(nombre) = LOWER(:nombre) LIMIT 1");
    $stmt->bindParam(':nombre', $nombre);
    $stmt->execute();
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($existing) {
        echo json_encode(array(
            'codigo' => intval($existing['codigo']),
            'nombre' => $existing['nombre'],
            'existed' => true,
        ));
        return;
    }

    $codigo_usuario = current_user_code();
    $stmt = $db->prepare("INSERT INTO nu_sustitucion_saludable_categoria
        (nombre, activo, imagen_portada, imagen_portada_nombre, imagen_miniatura, fechaa, codusuarioa)
        VALUES (:nombre, :activo, :imagen_portada, :imagen_portada_nombre, :imagen_miniatura, NOW(), :codusuarioa)");
    bind_categoria_params($stmt, $data);
    $stmt->bindParam(':codusuarioa', $codigo_usuario);

    if ($stmt->execute()) {
        http_response_code(201);
        echo json_encode(array(
            'codigo' => intval($db->lastInsertId()),
            'nombre' => $nombre,
            'existed' => false,
        ));
        return;
    }

    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo crear la categoría.'));
}

function update_sustitucion_categoria() {
    global $db;
    $data = json_decode(file_get_contents('php://input'));
    $codigo = intval($data->codigo ?? 0);
    $nombre = trim($data->nombre ?? '');

    if ($codigo <= 0 || $nombre === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Faltan datos para actualizar la categoría.'));
        return;
    }

    $codigo_usuario = current_user_code();
    $stmt = $db->prepare("UPDATE nu_sustitucion_saludable_categoria SET
        nombre = :nombre,
        activo = :activo,
        imagen_portada = :imagen_portada,
        imagen_portada_nombre = :imagen_portada_nombre,
        imagen_miniatura = :imagen_miniatura,
        fecham = NOW(),
        codusuariom = :codusuariom
        WHERE codigo = :codigo");
    bind_categoria_params($stmt, $data);
    $stmt->bindParam(':codusuariom', $codigo_usuario, PDO::PARAM_INT);
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);

    if ($stmt->execute()) {
        echo json_encode(array('message' => 'Categoría actualizada.'));
        return;
    }

    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo actualizar la categoría.'));
}

function delete_sustitucion_categoria($codigo) {
    global $db;

    if ($codigo <= 0) {
        http_response_code(400);
        echo json_encode(array('message' => 'Código de categoría inválido.'));
        return;
    }

    $check = $db->prepare("SELECT COUNT(*) AS total FROM nu_sustitucion_saludable_categoria_rel WHERE codigo_categoria = :codigo");
    $check->bindParam(':codigo', $codigo, PDO::PARAM_INT);
    $check->execute();
    $total = intval($check->fetchColumn() ?: 0);

    if ($total > 0) {
        http_response_code(409);
        echo json_encode(array(
            'message' => 'No se puede eliminar la categoría porque tiene sustituciones asignadas.',
            'assigned_count' => $total,
        ));
        return;
    }

    $stmt = $db->prepare("DELETE FROM nu_sustitucion_saludable_categoria WHERE codigo = :codigo");
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);

    if ($stmt->execute()) {
        echo json_encode(array('message' => 'Categoría eliminada.'));
        return;
    }

    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo eliminar la categoría.'));
}

function parse_item_row($item, $include_portada = false) {
    if (!empty($item['imagen_miniatura'])) {
        $item['imagen_miniatura'] = base64_encode($item['imagen_miniatura']);
    }
    if ($include_portada && !empty($item['imagen_portada'])) {
        $item['imagen_portada'] = base64_encode($item['imagen_portada']);
    }
    return $item;
}

function parse_categoria_row($item) {
    if (!empty($item['imagen_miniatura'])) {
        $item['imagen_miniatura'] = base64_encode($item['imagen_miniatura']);
    }
    if (!empty($item['imagen_portada'])) {
        $item['imagen_portada'] = base64_encode($item['imagen_portada']);
    }
    return $item;
}

function resolve_limit() {
    $limit = intval($_GET['limit'] ?? 20);
    if ($limit <= 0) {
        $limit = 20;
    }
    return min($limit, 100);
}

function resolve_offset() {
    $offset = intval($_GET['offset'] ?? 0);
    return max($offset, 0);
}

function resolve_search_term() {
    return trim($_GET['q'] ?? '');
}

function resolve_yes_no_filter($key) {
    if (!isset($_GET[$key])) {
        return null;
    }

    $value = strtoupper(trim($_GET[$key] ?? ''));
    if ($value !== 'S' && $value !== 'N') {
        return null;
    }

    return $value;
}

function resolve_category_filter() {
    if (!isset($_GET['categoria'])) {
        return null;
    }

    $value = intval($_GET['categoria']);
    if ($value <= 0) {
        return null;
    }

    return $value;
}

function build_search_clause($search_like, $item_alias = 's', $param_prefix = 'search') {
    $bindings = array(
        ':' . $param_prefix . '_titulo' => $search_like,
        ':' . $param_prefix . '_subtitulo' => $search_like,
        ':' . $param_prefix . '_alimento' => $search_like,
        ':' . $param_prefix . '_sustituto' => $search_like,
        ':' . $param_prefix . '_equivalencia' => $search_like,
        ':' . $param_prefix . '_objetivo' => $search_like,
        ':' . $param_prefix . '_texto' => $search_like,
        ':' . $param_prefix . '_categoria' => $search_like,
    );

    $sql = "(COALESCE($item_alias.titulo, '') LIKE :{$param_prefix}_titulo
        OR COALESCE($item_alias.subtitulo, '') LIKE :{$param_prefix}_subtitulo
        OR COALESCE($item_alias.alimento_origen, '') LIKE :{$param_prefix}_alimento
        OR COALESCE($item_alias.sustituto_principal, '') LIKE :{$param_prefix}_sustituto
        OR COALESCE($item_alias.equivalencia_texto, '') LIKE :{$param_prefix}_equivalencia
        OR COALESCE($item_alias.objetivo_macro, '') LIKE :{$param_prefix}_objetivo
        OR COALESCE($item_alias.texto, '') LIKE :{$param_prefix}_texto
        OR EXISTS (
            SELECT 1
            FROM nu_sustitucion_saludable_categoria_rel scr
            INNER JOIN nu_sustitucion_saludable_categoria sc ON scr.codigo_categoria = sc.codigo
            WHERE scr.codigo_sustitucion = $item_alias.codigo
              AND sc.activo = 'S'
              AND COALESCE(sc.nombre, '') LIKE :{$param_prefix}_categoria
        ))";

    return array(
        'sql' => $sql,
        'bindings' => $bindings,
    );
}

function base_select_fields($include_portada = false, $include_user_state = false) {
        $fallback_imagen_portada_nombre = "(SELECT sc.imagen_portada_nombre
                        FROM nu_sustitucion_saludable_categoria_rel scr
                        INNER JOIN nu_sustitucion_saludable_categoria sc ON scr.codigo_categoria = sc.codigo
                        WHERE scr.codigo_sustitucion = s.codigo
                            AND sc.activo = 'S'
                            AND (sc.imagen_portada IS NOT NULL OR sc.imagen_miniatura IS NOT NULL)
                        ORDER BY scr.fechaa ASC, scr.codigo_categoria ASC
                        LIMIT 1)";

        $fallback_imagen_miniatura = "(SELECT COALESCE(sc.imagen_miniatura, sc.imagen_portada)
                        FROM nu_sustitucion_saludable_categoria_rel scr
                        INNER JOIN nu_sustitucion_saludable_categoria sc ON scr.codigo_categoria = sc.codigo
                        WHERE scr.codigo_sustitucion = s.codigo
                            AND sc.activo = 'S'
                            AND (sc.imagen_portada IS NOT NULL OR sc.imagen_miniatura IS NOT NULL)
                        ORDER BY scr.fechaa ASC, scr.codigo_categoria ASC
                        LIMIT 1)";

        $fallback_imagen_portada = "(SELECT sc.imagen_portada
                        FROM nu_sustitucion_saludable_categoria_rel scr
                        INNER JOIN nu_sustitucion_saludable_categoria sc ON scr.codigo_categoria = sc.codigo
                        WHERE scr.codigo_sustitucion = s.codigo
                            AND sc.activo = 'S'
                            AND sc.imagen_portada IS NOT NULL
                        ORDER BY scr.fechaa ASC, scr.codigo_categoria ASC
                        LIMIT 1)";

    $fields = "s.codigo, s.titulo, s.subtitulo, s.alimento_origen, s.sustituto_principal,
        s.equivalencia_texto, s.objetivo_macro, s.texto, s.activo, s.mostrar_portada,
                s.visible_para_todos,
                COALESCE(s.imagen_portada_nombre, $fallback_imagen_portada_nombre) as imagen_portada_nombre,
                COALESCE(s.imagen_miniatura, $fallback_imagen_miniatura) as imagen_miniatura,
        s.fechaa, s.codusuarioa, s.fecham, s.codusuariom,
        (SELECT COUNT(*) FROM nu_sustitucion_saludable_usuario su WHERE su.codigo_sustitucion = s.codigo AND su.me_gusta = 'S') as total_likes,
        (SELECT GROUP_CONCAT(DISTINCT sc.codigo ORDER BY sc.nombre SEPARATOR ',')
            FROM nu_sustitucion_saludable_categoria_rel scr
            LEFT JOIN nu_sustitucion_saludable_categoria sc ON scr.codigo_categoria = sc.codigo AND sc.activo = 'S'
            WHERE scr.codigo_sustitucion = s.codigo) as categorias_ids,
        (SELECT GROUP_CONCAT(DISTINCT sc.nombre ORDER BY sc.nombre SEPARATOR ',')
            FROM nu_sustitucion_saludable_categoria_rel scr
            LEFT JOIN nu_sustitucion_saludable_categoria sc ON scr.codigo_categoria = sc.codigo AND sc.activo = 'S'
            WHERE scr.codigo_sustitucion = s.codigo) as categorias_nombres";

    if ($include_portada) {
        $fields .= ", COALESCE(s.imagen_portada, $fallback_imagen_portada) as imagen_portada";
    }

    if ($include_user_state && current_user_code() > 0) {
        $fields .= ", COALESCE(su.me_gusta, 'N') as me_gusta, COALESCE(su.favorito, 'N') as favorito";
    } else {
        $fields .= ", 'N' as me_gusta, 'N' as favorito";
    }

    return $fields;
}

function get_sustituciones() {
    global $db;

    if (!is_manager_user()) {
        get_public_sustituciones(false);
        return;
    }

    $limit = resolve_limit();
    $offset = resolve_offset();
    $search = resolve_search_term();
    $activo = resolve_yes_no_filter('activo');
    $portada = resolve_yes_no_filter('portada');
    $categoria = resolve_category_filter();

    $where = array('1 = 1');
    $bindings = array();

    if ($search !== '') {
        $search_clause = build_search_clause('%' . $search . '%', 's', 'manager_search');
        $where[] = $search_clause['sql'];
        $bindings = array_merge($bindings, $search_clause['bindings']);
    }

    if ($activo !== null) {
        $where[] = 's.activo = :activo';
        $bindings[':activo'] = $activo;
    }

    if ($portada !== null) {
        $where[] = 's.mostrar_portada = :mostrar_portada';
        $bindings[':mostrar_portada'] = $portada;
    }

    if ($categoria !== null) {
        $where[] = 'EXISTS (
            SELECT 1
            FROM nu_sustitucion_saludable_categoria_rel scrf
            WHERE scrf.codigo_sustitucion = s.codigo
              AND scrf.codigo_categoria = :codigo_categoria
        )';
        $bindings[':codigo_categoria'] = $categoria;
    }

    $query = "SELECT " . base_select_fields(false, false) . "
        FROM nu_sustitucion_saludable s
        WHERE " . implode(' AND ', $where) . "
        ORDER BY s.fechaa DESC, s.codigo DESC
        LIMIT :limit OFFSET :offset";

    $stmt = $db->prepare($query);
    foreach ($bindings as $name => $value) {
        $stmt->bindValue($name, $value, PDO::PARAM_STR);
    }
    $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
    $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($items as &$item) {
        $item = parse_item_row($item, false);
    }

    echo json_encode($items);
}

function get_public_sustituciones($solo_portada = false) {
    global $db;

    $user_code = current_user_code();
    $limit = resolve_limit();
    $offset = resolve_offset();
    $search = resolve_search_term();
    $joins = '';
    $bindings = array();
    if ($user_code > 0) {
        $joins = 'LEFT JOIN nu_sustitucion_saludable_usuario su ON s.codigo = su.codigo_sustitucion AND su.codigo_usuario = :codigo_usuario';
    }

    $where = array("s.activo = 'S'", "s.visible_para_todos = 'S'");
    if ($solo_portada) {
        $where[] = "s.mostrar_portada = 'S'";
    }
    if ($search !== '') {
        $search_clause = build_search_clause('%' . $search . '%', 's', 'public_search');
        $where[] = $search_clause['sql'];
        $bindings = array_merge($bindings, $search_clause['bindings']);
    }

    $query = "SELECT " . base_select_fields(false, true) . "
        FROM nu_sustitucion_saludable s
        $joins
        WHERE " . implode(' AND ', $where) . "
        ORDER BY s.mostrar_portada DESC, total_likes DESC, s.fechaa DESC, s.codigo DESC
        LIMIT :limit OFFSET :offset";

    $stmt = $db->prepare($query);
    if ($user_code > 0) {
        $stmt->bindParam(':codigo_usuario', $user_code, PDO::PARAM_INT);
    }
    foreach ($bindings as $name => $value) {
        $stmt->bindValue($name, $value, PDO::PARAM_STR);
    }
    $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
    $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($items as &$item) {
        $item = parse_item_row($item, false);
    }

    echo json_encode($items);
}

function get_sustituciones_total() {
    global $db;

    if (is_manager_user()) {
        $search = resolve_search_term();
        $activo = resolve_yes_no_filter('activo');
        $portada = resolve_yes_no_filter('portada');
        $categoria = resolve_category_filter();

        $where = array('1 = 1');
        $bindings = array();

        if ($search !== '') {
            $search_clause = build_search_clause('%' . $search . '%', 's', 'manager_total_search');
            $where[] = $search_clause['sql'];
            $bindings = array_merge($bindings, $search_clause['bindings']);
        }

        if ($activo !== null) {
            $where[] = 's.activo = :activo';
            $bindings[':activo'] = $activo;
        }

        if ($portada !== null) {
            $where[] = 's.mostrar_portada = :mostrar_portada';
            $bindings[':mostrar_portada'] = $portada;
        }

        if ($categoria !== null) {
            $where[] = 'EXISTS (
                SELECT 1
                FROM nu_sustitucion_saludable_categoria_rel scrf
                WHERE scrf.codigo_sustitucion = s.codigo
                  AND scrf.codigo_categoria = :codigo_categoria
            )';
            $bindings[':codigo_categoria'] = $categoria;
        }

        $query = "SELECT COUNT(*) AS total
            FROM nu_sustitucion_saludable s
            WHERE " . implode(' AND ', $where);

        $stmt = $db->prepare($query);
        foreach ($bindings as $name => $value) {
            $stmt->bindValue($name, $value, PDO::PARAM_STR);
        }
        $stmt->execute();
        $total = intval($stmt->fetchColumn() ?: 0);

        echo json_encode(array('total' => $total));
        return;
    }

    $search = resolve_search_term();
    $solo_portada = isset($_GET['portada']) && strtoupper(trim($_GET['portada'])) === 'S';

    $where = array("s.activo = 'S'", "s.visible_para_todos = 'S'");
    $bindings = array();

    if ($solo_portada) {
        $where[] = "s.mostrar_portada = 'S'";
    }

    if ($search !== '') {
        $search_clause = build_search_clause('%' . $search . '%', 's', 'public_total_search');
        $where[] = $search_clause['sql'];
        $bindings = array_merge($bindings, $search_clause['bindings']);
    }

    $query = "SELECT COUNT(*) AS total
        FROM nu_sustitucion_saludable s
        WHERE " . implode(' AND ', $where);

    $stmt = $db->prepare($query);
    foreach ($bindings as $name => $value) {
        $stmt->bindValue($name, $value, PDO::PARAM_STR);
    }
    $stmt->execute();
    $total = intval($stmt->fetchColumn() ?: 0);

    echo json_encode(array('total' => $total));
}

function get_sustitucion($codigo) {
    global $db;

    $user_code = current_user_code();
    $joins = '';
    $where = array('s.codigo = :codigo');
    if ($user_code > 0) {
        $joins = 'LEFT JOIN nu_sustitucion_saludable_usuario su ON s.codigo = su.codigo_sustitucion AND su.codigo_usuario = :codigo_usuario';
    }

    if (!is_manager_user()) {
        $where[] = "s.activo = 'S'";
        $where[] = "s.visible_para_todos = 'S'";
    }

    $query = "SELECT " . base_select_fields(true, true) . "
        FROM nu_sustitucion_saludable s
        $joins
        WHERE " . implode(' AND ', $where) . "
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
        echo json_encode(array('message' => 'Sustitución no encontrada.'));
        return;
    }

    echo json_encode(parse_item_row($item, true));
}

function bind_sustitucion_params($stmt, $data) {
    $titulo = trim($data->titulo ?? '');
    $subtitulo = trim($data->subtitulo ?? '');
    $alimento_origen = trim($data->alimento_origen ?? '');
    $sustituto_principal = trim($data->sustituto_principal ?? '');
    $equivalencia_texto = trim($data->equivalencia_texto ?? '');
    $objetivo_macro = trim($data->objetivo_macro ?? '');
    $texto = trim($data->texto ?? '');
    $activo = !empty($data->activo) ? trim($data->activo) : 'S';
    $mostrar_portada = !empty($data->mostrar_portada) ? trim($data->mostrar_portada) : 'N';
    $visible_para_todos = !empty($data->visible_para_todos) ? trim($data->visible_para_todos) : 'S';

    $imagen_portada = null;
    $imagen_portada_nombre = null;
    if (!empty($data->imagen_portada)) {
        $imagen_portada = base64_decode($data->imagen_portada);
        $imagen_portada_nombre = $data->imagen_portada_nombre ?? 'sustitucion.jpg';
    }

    $imagen_miniatura = null;
    if (!empty($data->imagen_miniatura)) {
        $imagen_miniatura = base64_decode($data->imagen_miniatura);
    }

    $stmt->bindParam(':titulo', $titulo);
    $stmt->bindParam(':subtitulo', $subtitulo);
    $stmt->bindParam(':alimento_origen', $alimento_origen);
    $stmt->bindParam(':sustituto_principal', $sustituto_principal);
    $stmt->bindParam(':equivalencia_texto', $equivalencia_texto);
    $stmt->bindParam(':objetivo_macro', $objetivo_macro);
    $stmt->bindParam(':texto', $texto);
    $stmt->bindParam(':activo', $activo);
    $stmt->bindParam(':mostrar_portada', $mostrar_portada);
    $stmt->bindParam(':visible_para_todos', $visible_para_todos);
    $stmt->bindParam(':imagen_portada', $imagen_portada, PDO::PARAM_LOB);
    $stmt->bindParam(':imagen_portada_nombre', $imagen_portada_nombre);
    $stmt->bindParam(':imagen_miniatura', $imagen_miniatura, PDO::PARAM_LOB);
}

function bind_categoria_params($stmt, $data) {
    $nombre = trim($data->nombre ?? '');
    $activo = !empty($data->activo) ? trim($data->activo) : 'S';

    $imagen_portada = null;
    $imagen_portada_nombre = null;
    if (property_exists($data, 'imagen_portada') && !empty($data->imagen_portada)) {
        $imagen_portada = base64_decode($data->imagen_portada);
        $imagen_portada_nombre = $data->imagen_portada_nombre ?? 'categoria.jpg';
    } else if (!property_exists($data, 'imagen_portada')) {
        $imagen_portada = null;
        $imagen_portada_nombre = null;
    }

    $imagen_miniatura = null;
    if (property_exists($data, 'imagen_miniatura') && !empty($data->imagen_miniatura)) {
        $imagen_miniatura = base64_decode($data->imagen_miniatura);
    }

    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':activo', $activo);
    $stmt->bindParam(':imagen_portada', $imagen_portada, PDO::PARAM_LOB);
    $stmt->bindParam(':imagen_portada_nombre', $imagen_portada_nombre);
    $stmt->bindParam(':imagen_miniatura', $imagen_miniatura, PDO::PARAM_LOB);
}

function validate_sustitucion_data($data) {
    $alimento_origen = trim($data->alimento_origen ?? '');
    $sustituto_principal = trim($data->sustituto_principal ?? '');
    $titulo = trim($data->titulo ?? '');

    if ($alimento_origen === '' || $sustituto_principal === '') {
        http_response_code(400);
        echo json_encode(array('message' => 'Los campos alimento origen y sustituto principal son obligatorios.'));
        return false;
    }

    if ($titulo === '') {
        $data->titulo = 'Si no tienes ' . $alimento_origen . ', usa ' . $sustituto_principal;
    }

    return true;
}

function update_sustitucion_categorias($codigo_sustitucion, $categorias, $codigo_usuario) {
    global $db;

    $delete = $db->prepare("DELETE FROM nu_sustitucion_saludable_categoria_rel WHERE codigo_sustitucion = :codigo");
    $delete->bindParam(':codigo', $codigo_sustitucion, PDO::PARAM_INT);
    $delete->execute();

    if (empty($categorias) || !is_array($categorias)) {
        return;
    }

    $insert = $db->prepare("INSERT INTO nu_sustitucion_saludable_categoria_rel (codigo_sustitucion, codigo_categoria, fechaa, codusuarioa) VALUES (:codigo_sustitucion, :codigo_categoria, NOW(), :codusuarioa)");
    foreach ($categorias as $categoria_id) {
        $categoria_id = intval($categoria_id);
        if ($categoria_id <= 0) {
            continue;
        }
        $insert->bindParam(':codigo_sustitucion', $codigo_sustitucion, PDO::PARAM_INT);
        $insert->bindParam(':codigo_categoria', $categoria_id, PDO::PARAM_INT);
        $insert->bindParam(':codusuarioa', $codigo_usuario, PDO::PARAM_INT);
        $insert->execute();
    }
}

function create_sustitucion() {
    global $db;
    $data = json_decode(file_get_contents('php://input'));
    if (!$data || !validate_sustitucion_data($data)) {
        return;
    }

    $codigo_usuario = current_user_code();
    $query = "INSERT INTO nu_sustitucion_saludable SET
        titulo = :titulo,
        subtitulo = :subtitulo,
        alimento_origen = :alimento_origen,
        sustituto_principal = :sustituto_principal,
        equivalencia_texto = :equivalencia_texto,
        objetivo_macro = :objetivo_macro,
        texto = :texto,
        activo = :activo,
        mostrar_portada = :mostrar_portada,
        visible_para_todos = :visible_para_todos,
        imagen_portada = :imagen_portada,
        imagen_portada_nombre = :imagen_portada_nombre,
        imagen_miniatura = :imagen_miniatura,
        fechaa = NOW(),
        codusuarioa = :codusuarioa";
    $stmt = $db->prepare($query);
    bind_sustitucion_params($stmt, $data);
    $stmt->bindParam(':codusuarioa', $codigo_usuario, PDO::PARAM_INT);

    if ($stmt->execute()) {
        $codigo = intval($db->lastInsertId());
        if (isset($data->categorias)) {
            update_sustitucion_categorias($codigo, $data->categorias, $codigo_usuario);
        }
        http_response_code(201);
        echo json_encode(array('codigo' => $codigo, 'message' => 'Sustitución creada.'));
        return;
    }

    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo crear la sustitución.'));
}

function update_sustitucion() {
    global $db;
    $data = json_decode(file_get_contents('php://input'));
    if (!$data || empty($data->codigo) || !validate_sustitucion_data($data)) {
        if (empty($data->codigo)) {
            http_response_code(400);
            echo json_encode(array('message' => 'Falta el código de la sustitución.'));
        }
        return;
    }

    $codigo_usuario = current_user_code();
    $query = "UPDATE nu_sustitucion_saludable SET
        titulo = :titulo,
        subtitulo = :subtitulo,
        alimento_origen = :alimento_origen,
        sustituto_principal = :sustituto_principal,
        equivalencia_texto = :equivalencia_texto,
        objetivo_macro = :objetivo_macro,
        texto = :texto,
        activo = :activo,
        mostrar_portada = :mostrar_portada,
        visible_para_todos = :visible_para_todos,
        imagen_portada = :imagen_portada,
        imagen_portada_nombre = :imagen_portada_nombre,
        imagen_miniatura = :imagen_miniatura,
        fecham = NOW(),
        codusuariom = :codusuariom
        WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    bind_sustitucion_params($stmt, $data);
    $stmt->bindParam(':codusuariom', $codigo_usuario, PDO::PARAM_INT);
    $codigo = intval($data->codigo);
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);

    if ($stmt->execute()) {
        if (isset($data->categorias)) {
            update_sustitucion_categorias($codigo, $data->categorias, $codigo_usuario);
        }
        echo json_encode(array('message' => 'Sustitución actualizada.'));
        return;
    }

    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo actualizar la sustitución.'));
}

function delete_sustitucion($codigo) {
    global $db;
    $stmt = $db->prepare("DELETE FROM nu_sustitucion_saludable WHERE codigo = :codigo");
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);
    if ($stmt->execute()) {
        echo json_encode(array('message' => 'Sustitución eliminada.'));
        return;
    }
    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo eliminar la sustitución.'));
}
?>