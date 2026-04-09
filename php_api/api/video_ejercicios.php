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

$validator = new AutoValidator($db);
$user = $validator->validate();

function is_safe_video_preview_read_request() {
    return $_SERVER['REQUEST_METHOD'] === 'GET'
        && (
            isset($_GET['categorias'])
            || isset($_GET['usuario'])
            || !empty($_GET['codigo'])
        );
}

function can_read_video_preview($user) {
    $user_type = PermissionManager::getUserType($user);

    return in_array($user_type, array(
        PermissionManager::TYPE_USER_NO_PATIENT,
        PermissionManager::TYPE_USER_WITH_PATIENT,
        PermissionManager::TYPE_PREMIUM,
        PermissionManager::TYPE_NUTRITIONIST,
        PermissionManager::TYPE_ADMIN,
    ), true);
}

function can_manage_video_catalog($user) {
    $user_type = PermissionManager::getUserType($user);

    return in_array($user_type, array(
        PermissionManager::TYPE_NUTRITIONIST,
        PermissionManager::TYPE_ADMIN,
    ), true);
}

if (is_safe_video_preview_read_request()) {
    if (!can_read_video_preview($user)) {
        PermissionManager::checkPermission($user, 'videos_ejercicios');
    }
} else {
    PermissionManager::checkPermission($user, 'videos_ejercicios');
}

$is_admin = PermissionManager::isAdmin($user);

switch ($request_method) {
    case 'GET':
        if (isset($_GET["categorias"])) {
            get_video_categorias();
        } elseif (!empty($_GET["codigo"])) {
            get_video_ejercicio((int)$_GET["codigo"]);
        } elseif (isset($_GET["usuario"])) {
            $codigo_usuario = isset($_GET["codigo_usuario"])
                ? $_GET["codigo_usuario"]
                : $_GET["usuario"];
            get_videos_ejercicio_usuario($codigo_usuario);
        } elseif (isset($_GET["favoritos"]) && isset($_GET["usuario"])) {
            get_videos_favoritos_usuario($_GET["usuario"]);
        } else {
            // Lista admin (solo nutricionista/admin ven todos)
            get_videos_ejercicios();
        }
        break;
    case 'POST':
        if (isset($_GET["categorias"])) {
            create_video_categoria();
        } else {
            create_video_ejercicio();
        }
        break;
    case 'PUT':
        if (isset($_GET["categorias"])) {
            update_video_categoria();
        } else {
            update_video_ejercicio();
        }
        break;
    case 'DELETE':
        if (!empty($_GET["codigo"])) {
            if (isset($_GET["categorias"])) {
                delete_video_categoria((int)$_GET["codigo"]);
            } else {
                delete_video_ejercicio((int)$_GET["codigo"]);
            }
        }
        break;
    default:
        http_response_code(405);
        echo json_encode(array("message" => "Método no permitido."));
        break;
}

// ─────────────────────────── CATEGORÍAS ───────────────────────────

function get_video_categorias() {
    global $db;
    $stmt = $db->prepare(
        "SELECT codigo, nombre, activo FROM nu_video_ejercicio_categoria WHERE activo = 'S' ORDER BY nombre"
    );
    $stmt->execute();
    ob_clean();
    echo json_encode($stmt->fetchAll(PDO::FETCH_ASSOC));
}

function create_video_categoria() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if (empty($data->nombre)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el nombre de la categoría."));
        return;
    }

    $nombre      = trim($data->nombre);
    $codusuarioa = isset($data->codusuarioa) ? (int)$data->codusuarioa : 1;

    $stmt = $db->prepare(
        "SELECT codigo, nombre FROM nu_video_ejercicio_categoria WHERE LOWER(nombre) = LOWER(:nombre) LIMIT 1"
    );
    $stmt->bindParam(':nombre', $nombre);
    $stmt->execute();
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($existing) {
        ob_clean();
        echo json_encode(array("codigo" => (int)$existing['codigo'], "nombre" => $existing['nombre'], "existed" => true));
        return;
    }

    $stmt = $db->prepare(
        "INSERT INTO nu_video_ejercicio_categoria (nombre, activo, fechaa, codusuarioa) VALUES (:nombre, 'S', NOW(), :codusuarioa)"
    );
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':codusuarioa', $codusuarioa);

    if ($stmt->execute()) {
        http_response_code(201);
        ob_clean();
        echo json_encode(array("codigo" => (int)$db->lastInsertId(), "nombre" => $nombre, "existed" => false));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo crear la categoría."));
    }
}

function update_video_categoria() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    $codigo = isset($data->codigo) ? (int)$data->codigo : 0;
    $nombre = isset($data->nombre) ? trim($data->nombre) : '';

    if ($codigo <= 0 || $nombre === '') {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Faltan datos para actualizar la categoría."));
        return;
    }

    $stmt = $db->prepare(
        "SELECT codigo FROM nu_video_ejercicio_categoria WHERE LOWER(nombre) = LOWER(:nombre) AND codigo <> :codigo LIMIT 1"
    );
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    if ($stmt->fetch(PDO::FETCH_ASSOC)) {
        http_response_code(409);
        ob_clean();
        echo json_encode(array("message" => "Ya existe una categoría con ese nombre."));
        return;
    }

    $stmt = $db->prepare(
        "UPDATE nu_video_ejercicio_categoria SET nombre = :nombre WHERE codigo = :codigo"
    );
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':codigo', $codigo);

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Categoría actualizada."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo actualizar la categoría."));
    }
}

function delete_video_categoria($codigo) {
    global $db;

    $stmt = $db->prepare(
        "UPDATE nu_video_ejercicio_categoria SET activo = 'N' WHERE codigo = :codigo"
    );
    $stmt->bindParam(':codigo', $codigo);

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Categoría eliminada."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo eliminar la categoría."));
    }
}

function update_video_categorias($codigo_video, $categorias, $codusuarioa = 1) {
    global $db;
    $db->prepare("DELETE FROM nu_video_ejercicio_categoria_rel WHERE codigo_video = :codigo")
       ->execute(array(':codigo' => $codigo_video));

    if (empty($categorias) || !is_array($categorias)) return;

    $stmt = $db->prepare(
        "INSERT INTO nu_video_ejercicio_categoria_rel (codigo_video, codigo_categoria, fechaa, codusuarioa)
         VALUES (:codigo_video, :codigo_categoria, NOW(), :codusuarioa)"
    );
    foreach ($categorias as $cat_id) {
        $cat_id = intval($cat_id);
        if ($cat_id <= 0) continue;
        $stmt->bindParam(':codigo_video',     $codigo_video);
        $stmt->bindParam(':codigo_categoria', $cat_id);
        $stmt->bindParam(':codusuarioa',      $codusuarioa);
        $stmt->execute();
    }
}

// ─────────────────────────── HELPERS ───────────────────────────

function encode_miniatura(&$video) {
    if (!empty($video['imagen_miniatura'])) {
        $video['imagen_miniatura'] = base64_encode($video['imagen_miniatura']);
    }
}

function encode_imagen(&$video) {
    if (!empty($video['imagen'])) {
        $video['imagen'] = base64_encode($video['imagen']);
    }
}

function video_select_base($include_full_image = false) {
    $full_image_sql = $include_full_image
        ? "v.imagen, v.imagen_nombre,"
        : "v.imagen_nombre,";

    return "v.codigo, v.titulo, v.descripcion, v.tipo_media, v.ruta_video, v.formato,
            $full_image_sql
            v.imagen_miniatura, v.imagen_miniatura_nombre,
            v.visible, v.total_likes,
            v.fechaa, v.codusuarioa, v.fecham, v.codusuariom,
            (SELECT GROUP_CONCAT(DISTINCT vc.codigo ORDER BY vc.nombre SEPARATOR ',')
             FROM nu_video_ejercicio_categoria_rel vcr
             LEFT JOIN nu_video_ejercicio_categoria vc ON vcr.codigo_categoria = vc.codigo AND vc.activo = 'S'
             WHERE vcr.codigo_video = v.codigo) AS categorias_ids,
            (SELECT GROUP_CONCAT(DISTINCT vc.nombre ORDER BY vc.nombre SEPARATOR ',')
             FROM nu_video_ejercicio_categoria_rel vcr
             LEFT JOIN nu_video_ejercicio_categoria vc ON vcr.codigo_categoria = vc.codigo AND vc.activo = 'S'
             WHERE vcr.codigo_video = v.codigo) AS categorias_nombres";
}

// ─────────────────────────── VÍDEOS ───────────────────────────

// Lista completa para administrador / nutricionista
function get_videos_ejercicios() {
    global $db;
    $query = "SELECT " . video_select_base() . ",
              'N' AS me_gusta,
              'N' AS favorito
              FROM nu_video_ejercicio v
              ORDER BY v.fechaa DESC";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $videos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($videos as &$v) encode_miniatura($v);
    ob_clean();
    echo json_encode($videos);
}

// Lista para usuario Premium (solo visible='S', con estado like/fav)
function get_videos_ejercicio_usuario($codigo_usuario) {
    global $db;
    $query = "SELECT " . video_select_base() . ",
              COALESCE(vu.me_gusta, 'N') AS me_gusta,
              COALESCE(vu.favorito, 'N') AS favorito
              FROM nu_video_ejercicio v
              LEFT JOIN nu_video_ejercicio_usuario vu
                ON vu.codigo_video = v.codigo AND vu.codigo_usuario = :codigo_usuario
              WHERE v.visible = 'S'
              ORDER BY v.fechaa DESC";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_usuario', $codigo_usuario);
    $stmt->execute();
    $videos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($videos as &$v) encode_miniatura($v);
    ob_clean();
    echo json_encode($videos);
}

// Favoritos de un usuario
function get_videos_favoritos_usuario($codigo_usuario) {
    global $db;
    $query = "SELECT " . video_select_base() . ",
              COALESCE(vu.me_gusta, 'N') AS me_gusta,
              COALESCE(vu.favorito, 'N') AS favorito
              FROM nu_video_ejercicio v
              INNER JOIN nu_video_ejercicio_usuario vu
                ON vu.codigo_video = v.codigo AND vu.codigo_usuario = :codigo_usuario
              WHERE v.visible = 'S'
              AND vu.favorito = 'S'
              ORDER BY vu.fecha_favorito DESC";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_usuario', $codigo_usuario);
    $stmt->execute();
    $videos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($videos as &$v) encode_miniatura($v);
    ob_clean();
    echo json_encode($videos);
}

// Detalle de un vídeo
function get_video_ejercicio($codigo) {
    global $db, $user;
    $query = "SELECT " . video_select_base(true) . ",
              'N' AS me_gusta,
              'N' AS favorito
              FROM nu_video_ejercicio v
              WHERE v.codigo = :codigo";

    if (!can_manage_video_catalog($user)) {
        $query .= " AND v.visible = 'S'";
    }

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $video = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($video) {
        encode_imagen($video);
        encode_miniatura($video);
        ob_clean();
        echo json_encode($video);
    } else {
        http_response_code(404);
        ob_clean();
        echo json_encode(array("message" => "Vídeo no encontrado."));
    }
}

function create_video_ejercicio() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if (empty($data->titulo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el título del vídeo."));
        return;
    }

    $codusuarioa            = isset($data->codusuarioa)    ? (int)$data->codusuarioa : 1;
    $visible                = isset($data->visible)        ? $data->visible           : 'S';
    $tipo_media             = isset($data->tipo_media)     ? $data->tipo_media        : 'local';
    $ruta_video             = isset($data->ruta_video)     ? trim($data->ruta_video)  : null;
    $formato                = isset($data->formato)        ? $data->formato           : null;
    $descripcion            = isset($data->descripcion)    ? $data->descripcion       : null;
    $imagen                 = null;
    $imagen_nombre          = null;
    $imagen_miniatura       = null;
    $imagen_miniatura_nombre = null;

    if (!empty($data->imagen)) {
        $imagen = base64_decode($data->imagen);
        $imagen_nombre = $data->imagen_nombre ?? 'imagen.jpg';
    }

    if (!empty($data->imagen_miniatura)) {
        $imagen_miniatura        = base64_decode($data->imagen_miniatura);
        $imagen_miniatura_nombre = $data->imagen_miniatura_nombre ?? 'miniatura.jpg';
    }

    $query = "INSERT INTO nu_video_ejercicio SET
                titulo                  = :titulo,
                descripcion             = :descripcion,
                tipo_media              = :tipo_media,
                ruta_video              = :ruta_video,
                formato                 = :formato,
                imagen                  = :imagen,
                imagen_nombre           = :imagen_nombre,
                imagen_miniatura        = :imagen_miniatura,
                imagen_miniatura_nombre = :imagen_miniatura_nombre,
                visible                 = :visible,
                total_likes             = 0,
                fechaa                  = NOW(),
                codusuarioa             = :codusuarioa";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':titulo',                  $data->titulo);
    $stmt->bindParam(':descripcion',             $descripcion);
    $stmt->bindParam(':tipo_media',              $tipo_media);
    $stmt->bindParam(':ruta_video',              $ruta_video);
    $stmt->bindParam(':formato',                 $formato);
    $stmt->bindParam(':imagen',                  $imagen, PDO::PARAM_LOB);
    $stmt->bindParam(':imagen_nombre',           $imagen_nombre);
    $stmt->bindParam(':imagen_miniatura',        $imagen_miniatura, PDO::PARAM_LOB);
    $stmt->bindParam(':imagen_miniatura_nombre', $imagen_miniatura_nombre);
    $stmt->bindParam(':visible',                 $visible);
    $stmt->bindParam(':codusuarioa',             $codusuarioa);

    if ($stmt->execute()) {
        $video_id = (int)$db->lastInsertId();
        if (isset($data->categorias)) {
            update_video_categorias($video_id, $data->categorias, $codusuarioa);
        }
        http_response_code(201);
        ob_clean();
        echo json_encode(array("message" => "Vídeo creado.", "codigo" => $video_id));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo crear el vídeo.", "errorInfo" => $stmt->errorInfo()));
    }
}

function update_video_ejercicio() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if (empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el código del vídeo."));
        return;
    }

    $codusuariom = isset($data->codusuariom) ? (int)$data->codusuariom : 1;
    $tipo_media  = isset($data->tipo_media)  ? $data->tipo_media        : 'local';
    $ruta_video  = isset($data->ruta_video)  ? trim($data->ruta_video)  : null;
    $formato     = isset($data->formato)     ? $data->formato           : null;
    $visible     = isset($data->visible)     ? $data->visible           : 'S';
    $descripcion = isset($data->descripcion) ? $data->descripcion       : null;
    $clear_imagen = !empty($data->clear_imagen);

    $has_new_imagen = !empty($data->imagen);
    if ($has_new_imagen) {
        $imagen = base64_decode($data->imagen);
        $imagen_nombre = $data->imagen_nombre ?? 'imagen.jpg';
        $imagen_sql = ", imagen = :imagen, imagen_nombre = :imagen_nombre";
    } elseif ($clear_imagen) {
        $imagen_sql = ", imagen = NULL, imagen_nombre = NULL, imagen_miniatura = NULL, imagen_miniatura_nombre = NULL";
    } else {
        $imagen_sql = "";
    }

    $has_new_miniatura = !empty($data->imagen_miniatura);
    if ($has_new_miniatura && !$clear_imagen) {
        $imagen_miniatura        = base64_decode($data->imagen_miniatura);
        $imagen_miniatura_nombre = $data->imagen_miniatura_nombre ?? 'miniatura.jpg';
        $miniatura_sql = ", imagen_miniatura = :imagen_miniatura, imagen_miniatura_nombre = :imagen_miniatura_nombre";
    } else {
        $miniatura_sql = "";
    }

    $query = "UPDATE nu_video_ejercicio SET
                titulo       = :titulo,
                descripcion  = :descripcion,
                tipo_media   = :tipo_media,
                ruta_video   = :ruta_video,
                formato      = :formato,
                visible      = :visible,
                fecham       = NOW(),
                codusuariom  = :codusuariom
                                $imagen_sql
                $miniatura_sql
              WHERE codigo = :codigo";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo',      $data->codigo);
    $stmt->bindParam(':titulo',      $data->titulo);
    $stmt->bindParam(':descripcion', $descripcion);
    $stmt->bindParam(':tipo_media',  $tipo_media);
    $stmt->bindParam(':ruta_video',  $ruta_video);
    $stmt->bindParam(':formato',     $formato);
    $stmt->bindParam(':visible',     $visible);
    $stmt->bindParam(':codusuariom', $codusuariom);

    if ($has_new_imagen) {
        $stmt->bindParam(':imagen', $imagen, PDO::PARAM_LOB);
        $stmt->bindParam(':imagen_nombre', $imagen_nombre);
    }

    if ($has_new_miniatura && !$clear_imagen) {
        $stmt->bindParam(':imagen_miniatura',        $imagen_miniatura, PDO::PARAM_LOB);
        $stmt->bindParam(':imagen_miniatura_nombre', $imagen_miniatura_nombre);
    }

    if ($stmt->execute()) {
        if (isset($data->categorias)) {
            update_video_categorias($data->codigo, $data->categorias, $codusuariom);
        }
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Vídeo actualizado."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo actualizar el vídeo.", "errorInfo" => $stmt->errorInfo()));
    }
}

function delete_video_ejercicio($codigo) {
    global $db;
    $stmt = $db->prepare("DELETE FROM nu_video_ejercicio WHERE codigo = :codigo");
    $stmt->bindParam(':codigo', $codigo);
    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Vídeo eliminado."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo eliminar el vídeo."));
    }
}
?>
