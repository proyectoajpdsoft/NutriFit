<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
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
PermissionManager::checkPermission($user, 'premium_exclusive');

ensure_sustitucion_usuario_tables();

switch ($_SERVER['REQUEST_METHOD']) {
    case 'GET':
        if (isset($_GET['favoritos'])) {
            $codigo_usuario = resolve_user_code($_GET['usuario'] ?? null);
            if (isset($_GET['total'])) {
                get_favoritos_total($codigo_usuario);
            } else {
                get_favoritos($codigo_usuario);
            }
        } else if (isset($_GET['usuario']) && isset($_GET['codigo_sustitucion'])) {
            get_estado_usuario(resolve_user_code($_GET['usuario']), intval($_GET['codigo_sustitucion']));
        } else {
            http_response_code(400);
            echo json_encode(array('message' => 'Consulta no válida.'));
        }
        break;
    case 'POST':
        if (isset($_GET['toggle_like'])) {
            toggle_like();
        } else if (isset($_GET['toggle_favorito'])) {
            toggle_favorito();
        } else {
            http_response_code(400);
            echo json_encode(array('message' => 'Acción no válida.'));
        }
        break;
    default:
        http_response_code(405);
        echo json_encode(array('message' => 'Método no permitido.'));
        break;
}

function ensure_sustitucion_usuario_tables() {
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
        codusuariom INT DEFAULT NULL
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
        CONSTRAINT sustitucion_usuario_item_fk_rel FOREIGN KEY (codigo_sustitucion) REFERENCES nu_sustitucion_saludable(codigo) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

function current_user_code_rel() {
    global $user;
    return isset($user['codigo']) ? intval($user['codigo']) : 0;
}

function is_manager_rel() {
    global $user;
    $user_type = PermissionManager::getUserType($user);
    return $user_type === PermissionManager::TYPE_NUTRITIONIST ||
        $user_type === PermissionManager::TYPE_ADMIN;
}

function resolve_user_code($requested) {
    $current = current_user_code_rel();
    if ($current <= 0) {
        http_response_code(403);
        echo json_encode(array('message' => 'Usuario no identificado.'));
        exit();
    }

    $requested_code = intval($requested ?? 0);
    if ($requested_code <= 0) {
        return $current;
    }
    if ($requested_code !== $current && !is_manager_rel()) {
        http_response_code(403);
        echo json_encode(array('message' => 'No puedes consultar datos de otro usuario.'));
        exit();
    }
    return $requested_code;
}

function parse_item_row_rel($item) {
    if (!empty($item['imagen_portada'])) {
        $item['imagen_portada'] = base64_encode($item['imagen_portada']);
    }
    if (!empty($item['imagen_miniatura'])) {
        $item['imagen_miniatura'] = base64_encode($item['imagen_miniatura']);
    }
    return $item;
}

function resolve_limit_rel() {
    $limit = intval($_GET['limit'] ?? 20);
    if ($limit <= 0) {
        $limit = 20;
    }
    return min($limit, 100);
}

function resolve_offset_rel() {
    $offset = intval($_GET['offset'] ?? 0);
    return max($offset, 0);
}

function resolve_search_term_rel() {
    return trim($_GET['q'] ?? '');
}

function build_search_clause_rel($search_like, $item_alias = 's', $param_prefix = 'search_rel') {
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

function get_estado_usuario($codigo_usuario, $codigo_sustitucion) {
    global $db;
    $stmt = $db->prepare("SELECT me_gusta, favorito FROM nu_sustitucion_saludable_usuario WHERE codigo_usuario = :usuario AND codigo_sustitucion = :codigo LIMIT 1");
    $stmt->bindParam(':usuario', $codigo_usuario, PDO::PARAM_INT);
    $stmt->bindParam(':codigo', $codigo_sustitucion, PDO::PARAM_INT);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    echo json_encode($result ? $result : array('me_gusta' => 'N', 'favorito' => 'N'));
}

function toggle_like() {
    global $db;
    $data = json_decode(file_get_contents('php://input'));
    $codigo_sustitucion = intval($data->codigo_sustitucion ?? 0);
    $codigo_usuario = resolve_user_code($data->codigo_usuario ?? null);

    if ($codigo_sustitucion <= 0) {
        http_response_code(400);
        echo json_encode(array('message' => 'Falta el código de la sustitución.'));
        return;
    }

    $stmt = $db->prepare("SELECT codigo, me_gusta FROM nu_sustitucion_saludable_usuario WHERE codigo_sustitucion = :codigo_sustitucion AND codigo_usuario = :codigo_usuario LIMIT 1");
    $stmt->bindParam(':codigo_sustitucion', $codigo_sustitucion, PDO::PARAM_INT);
    $stmt->bindParam(':codigo_usuario', $codigo_usuario, PDO::PARAM_INT);
    $stmt->execute();
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$existing) {
        $insert = $db->prepare("INSERT INTO nu_sustitucion_saludable_usuario SET codigo_sustitucion = :codigo_sustitucion, codigo_usuario = :codigo_usuario, me_gusta = 'S', favorito = 'N', fecha_me_gusta = NOW(), fechaa = NOW(), codusuarioa = :codusuarioa");
        $insert->bindParam(':codigo_sustitucion', $codigo_sustitucion, PDO::PARAM_INT);
        $insert->bindParam(':codigo_usuario', $codigo_usuario, PDO::PARAM_INT);
        $insert->bindParam(':codusuarioa', $codigo_usuario, PDO::PARAM_INT);
        if ($insert->execute()) {
            echo json_encode(array('me_gusta' => 'S', 'message' => 'Me gusta agregado.'));
            return;
        }
        http_response_code(503);
        echo json_encode(array('message' => 'No se pudo registrar el me gusta.'));
        return;
    }

    $new_value = $existing['me_gusta'] === 'S' ? 'N' : 'S';
    $fecha = $new_value === 'S' ? date('Y-m-d H:i:s') : null;
    $query = "UPDATE nu_sustitucion_saludable_usuario SET me_gusta = :me_gusta, fecha_me_gusta = " . ($fecha ? ':fecha_me_gusta' : 'NULL') . ", fecham = NOW(), codusuariom = :codusuariom WHERE codigo = :codigo";
    $update = $db->prepare($query);
    $update->bindParam(':me_gusta', $new_value);
    if ($fecha) {
        $update->bindParam(':fecha_me_gusta', $fecha);
    }
    $update->bindParam(':codusuariom', $codigo_usuario, PDO::PARAM_INT);
    $update->bindParam(':codigo', $existing['codigo'], PDO::PARAM_INT);
    if ($update->execute()) {
        echo json_encode(array('me_gusta' => $new_value, 'message' => 'Me gusta actualizado.'));
        return;
    }
    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo actualizar el me gusta.'));
}

function toggle_favorito() {
    global $db;
    $data = json_decode(file_get_contents('php://input'));
    $codigo_sustitucion = intval($data->codigo_sustitucion ?? 0);
    $codigo_usuario = resolve_user_code($data->codigo_usuario ?? null);

    if ($codigo_sustitucion <= 0) {
        http_response_code(400);
        echo json_encode(array('message' => 'Falta el código de la sustitución.'));
        return;
    }

    $stmt = $db->prepare("SELECT codigo, favorito FROM nu_sustitucion_saludable_usuario WHERE codigo_sustitucion = :codigo_sustitucion AND codigo_usuario = :codigo_usuario LIMIT 1");
    $stmt->bindParam(':codigo_sustitucion', $codigo_sustitucion, PDO::PARAM_INT);
    $stmt->bindParam(':codigo_usuario', $codigo_usuario, PDO::PARAM_INT);
    $stmt->execute();
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$existing) {
        $insert = $db->prepare("INSERT INTO nu_sustitucion_saludable_usuario SET codigo_sustitucion = :codigo_sustitucion, codigo_usuario = :codigo_usuario, me_gusta = 'N', favorito = 'S', fecha_favorito = NOW(), fechaa = NOW(), codusuarioa = :codusuarioa");
        $insert->bindParam(':codigo_sustitucion', $codigo_sustitucion, PDO::PARAM_INT);
        $insert->bindParam(':codigo_usuario', $codigo_usuario, PDO::PARAM_INT);
        $insert->bindParam(':codusuarioa', $codigo_usuario, PDO::PARAM_INT);
        if ($insert->execute()) {
            echo json_encode(array('favorito' => 'S', 'message' => 'Favorito agregado.'));
            return;
        }
        http_response_code(503);
        echo json_encode(array('message' => 'No se pudo registrar el favorito.'));
        return;
    }

    $new_value = $existing['favorito'] === 'S' ? 'N' : 'S';
    $fecha = $new_value === 'S' ? date('Y-m-d H:i:s') : null;
    $query = "UPDATE nu_sustitucion_saludable_usuario SET favorito = :favorito, fecha_favorito = " . ($fecha ? ':fecha_favorito' : 'NULL') . ", fecham = NOW(), codusuariom = :codusuariom WHERE codigo = :codigo";
    $update = $db->prepare($query);
    $update->bindParam(':favorito', $new_value);
    if ($fecha) {
        $update->bindParam(':fecha_favorito', $fecha);
    }
    $update->bindParam(':codusuariom', $codigo_usuario, PDO::PARAM_INT);
    $update->bindParam(':codigo', $existing['codigo'], PDO::PARAM_INT);
    if ($update->execute()) {
        echo json_encode(array('favorito' => $new_value, 'message' => 'Favorito actualizado.'));
        return;
    }
    http_response_code(503);
    echo json_encode(array('message' => 'No se pudo actualizar el favorito.'));
}

function get_favoritos($codigo_usuario) {
    global $db;
    $limit = resolve_limit_rel();
    $offset = resolve_offset_rel();
    $search = resolve_search_term_rel();
    $bindings = array();
    $where = array(
        'su.codigo_usuario = :codigo_usuario',
        "su.favorito = 'S'",
        "s.activo = 'S'",
        "s.visible_para_todos = 'S'",
    );
    if ($search !== '') {
        $search_clause = build_search_clause_rel('%' . $search . '%', 's', 'favoritos_search');
        $where[] = $search_clause['sql'];
        $bindings = array_merge($bindings, $search_clause['bindings']);
    }
    $query = "SELECT s.codigo, s.titulo, s.subtitulo, s.alimento_origen, s.sustituto_principal,
        s.equivalencia_texto, s.objetivo_macro, s.texto, s.activo, s.mostrar_portada,
        s.visible_para_todos, s.imagen_portada, s.imagen_portada_nombre, s.imagen_miniatura,
        s.fechaa, s.codusuarioa, s.fecham, s.codusuariom,
        su.me_gusta, su.favorito,
        (SELECT COUNT(*) FROM nu_sustitucion_saludable_usuario WHERE codigo_sustitucion = s.codigo AND me_gusta = 'S') as total_likes,
        (SELECT GROUP_CONCAT(DISTINCT sc.codigo ORDER BY sc.nombre SEPARATOR ',')
            FROM nu_sustitucion_saludable_categoria_rel scr
            LEFT JOIN nu_sustitucion_saludable_categoria sc ON scr.codigo_categoria = sc.codigo AND sc.activo = 'S'
            WHERE scr.codigo_sustitucion = s.codigo) as categorias_ids,
        (SELECT GROUP_CONCAT(DISTINCT sc.nombre ORDER BY sc.nombre SEPARATOR ',')
            FROM nu_sustitucion_saludable_categoria_rel scr
            LEFT JOIN nu_sustitucion_saludable_categoria sc ON scr.codigo_categoria = sc.codigo AND sc.activo = 'S'
            WHERE scr.codigo_sustitucion = s.codigo) as categorias_nombres
        FROM nu_sustitucion_saludable s
        INNER JOIN nu_sustitucion_saludable_usuario su ON s.codigo = su.codigo_sustitucion
        WHERE " . implode(' AND ', $where) . "
        ORDER BY su.fecha_favorito DESC, s.codigo DESC
        LIMIT :limit OFFSET :offset";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_usuario', $codigo_usuario, PDO::PARAM_INT);
    foreach ($bindings as $name => $value) {
        $stmt->bindValue($name, $value, PDO::PARAM_STR);
    }
    $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
    $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($items as &$item) {
        $item = parse_item_row_rel($item);
    }
    echo json_encode($items);
}

function get_favoritos_total($codigo_usuario) {
    global $db;

    $search = resolve_search_term_rel();
    $bindings = array();
    $where = array(
        'su.codigo_usuario = :codigo_usuario',
        "su.favorito = 'S'",
        "s.activo = 'S'",
        "s.visible_para_todos = 'S'",
    );

    if ($search !== '') {
        $search_clause = build_search_clause_rel('%' . $search . '%', 's', 'favoritos_total_search');
        $where[] = $search_clause['sql'];
        $bindings = array_merge($bindings, $search_clause['bindings']);
    }

    $query = "SELECT COUNT(*) AS total
        FROM nu_sustitucion_saludable s
        INNER JOIN nu_sustitucion_saludable_usuario su ON s.codigo = su.codigo_sustitucion
        WHERE " . implode(' AND ', $where);

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_usuario', $codigo_usuario, PDO::PARAM_INT);
    foreach ($bindings as $name => $value) {
        $stmt->bindValue($name, $value, PDO::PARAM_STR);
    }
    $stmt->execute();
    $total = intval($stmt->fetchColumn() ?: 0);

    echo json_encode(array('total' => $total));
}
?>