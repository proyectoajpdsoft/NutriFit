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
PermissionManager::checkPermission($user, 'videos_ejercicios');

switch ($request_method) {
    case 'GET':
        if (isset($_GET["usuario"]) && isset($_GET["video_codigo"])) {
            get_video_usuario($_GET["usuario"], $_GET["video_codigo"]);
        } elseif (isset($_GET["favoritos"]) && isset($_GET["usuario"])) {
            get_favoritos($_GET["usuario"]);
        }
        break;
    case 'POST':
        if (isset($_GET["toggle_like"])) {
            toggle_like();
        } elseif (isset($_GET["toggle_favorito"])) {
            toggle_favorito();
        }
        break;
    case 'DELETE':
        if (isset($_GET["video"]) && isset($_GET["usuario"])) {
            remove_usuario($_GET["video"], $_GET["usuario"]);
        }
        break;
    default:
        http_response_code(405);
        echo json_encode(array("message" => "Método no permitido."));
        break;
}

function get_video_usuario($usuario_codigo, $video_codigo) {
    global $db;
    $query = "SELECT * FROM nu_video_ejercicio_usuario
              WHERE codigo_usuario = :usuario AND codigo_video = :video";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':usuario', $usuario_codigo);
    $stmt->bindParam(':video',   $video_codigo);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($result ?: array("me_gusta" => "N", "favorito" => "N"));
}

function toggle_like() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if (empty($data->codigo_video) || empty($data->codigo_usuario)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Faltan codigo_video o codigo_usuario."));
        return;
    }

    $check = $db->prepare(
        "SELECT codigo, me_gusta FROM nu_video_ejercicio_usuario
         WHERE codigo_video = :video AND codigo_usuario = :usuario"
    );
    $check->bindParam(':video',   $data->codigo_video);
    $check->bindParam(':usuario', $data->codigo_usuario);
    $check->execute();
    $existing = $check->fetch(PDO::FETCH_ASSOC);

    if (!$existing) {
        $ins = $db->prepare(
            "INSERT INTO nu_video_ejercicio_usuario SET
             codigo_video    = :codigo_video,
             codigo_usuario  = :codigo_usuario,
             me_gusta        = 'S',
             favorito        = 'N',
             fecha_me_gusta  = NOW(),
             fechaa          = NOW(),
             codusuarioa     = :codusuarioa"
        );
        $ins->bindParam(':codigo_video',   $data->codigo_video);
        $ins->bindParam(':codigo_usuario', $data->codigo_usuario);
        $ins->bindParam(':codusuarioa',    $data->codigo_usuario);

        if ($ins->execute()) {
            // Incrementar caché total_likes
            $db->prepare("UPDATE nu_video_ejercicio SET total_likes = total_likes + 1 WHERE codigo = :codigo")
               ->execute(array(':codigo' => $data->codigo_video));
            ob_clean();
            echo json_encode(array("message" => "Like agregado.", "me_gusta" => "S"));
        } else {
            http_response_code(503);
            ob_clean();
            echo json_encode(array("message" => "No se pudo registrar el like."));
        }
        return;
    }

    $new_value      = $existing['me_gusta'] == 'S' ? 'N' : 'S';
    $fecha_me_gusta = $new_value == 'S' ? date('Y-m-d H:i:s') : null;

    $upd = $db->prepare(
        "UPDATE nu_video_ejercicio_usuario SET
         me_gusta       = :me_gusta,
         fecha_me_gusta = " . ($fecha_me_gusta ? ":fecha_me_gusta" : "NULL") . ",
         fecham         = NOW(),
         codusuariom    = :codusuariom
         WHERE codigo = :codigo"
    );
    $upd->bindParam(':me_gusta',    $new_value);
    if ($fecha_me_gusta) $upd->bindParam(':fecha_me_gusta', $fecha_me_gusta);
    $upd->bindParam(':codusuariom', $data->codigo_usuario);
    $upd->bindParam(':codigo',      $existing['codigo']);

    if ($upd->execute()) {
        // Sincronizar caché total_likes
        $db->prepare(
            "UPDATE nu_video_ejercicio SET total_likes =
             (SELECT COUNT(*) FROM nu_video_ejercicio_usuario WHERE codigo_video = :codigo AND me_gusta = 'S')
             WHERE codigo = :codigo2"
        )->execute(array(':codigo' => $data->codigo_video, ':codigo2' => $data->codigo_video));

        ob_clean();
        echo json_encode(array("message" => "Like actualizado.", "me_gusta" => $new_value));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo actualizar el like."));
    }
}

function toggle_favorito() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if (empty($data->codigo_video) || empty($data->codigo_usuario)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Faltan codigo_video o codigo_usuario."));
        return;
    }

    $check = $db->prepare(
        "SELECT codigo, favorito FROM nu_video_ejercicio_usuario
         WHERE codigo_video = :video AND codigo_usuario = :usuario"
    );
    $check->bindParam(':video',   $data->codigo_video);
    $check->bindParam(':usuario', $data->codigo_usuario);
    $check->execute();
    $existing = $check->fetch(PDO::FETCH_ASSOC);

    if (!$existing) {
        $ins = $db->prepare(
            "INSERT INTO nu_video_ejercicio_usuario SET
             codigo_video   = :codigo_video,
             codigo_usuario = :codigo_usuario,
             me_gusta       = 'N',
             favorito       = 'S',
             fecha_favorito = NOW(),
             fechaa         = NOW(),
             codusuarioa    = :codusuarioa"
        );
        $ins->bindParam(':codigo_video',   $data->codigo_video);
        $ins->bindParam(':codigo_usuario', $data->codigo_usuario);
        $ins->bindParam(':codusuarioa',    $data->codigo_usuario);

        if ($ins->execute()) {
            ob_clean();
            echo json_encode(array("message" => "Favorito agregado.", "favorito" => "S"));
        } else {
            http_response_code(503);
            ob_clean();
            echo json_encode(array("message" => "No se pudo registrar el favorito."));
        }
        return;
    }

    $new_value     = $existing['favorito'] == 'S' ? 'N' : 'S';
    $fecha_favorito = $new_value == 'S' ? date('Y-m-d H:i:s') : null;

    $upd = $db->prepare(
        "UPDATE nu_video_ejercicio_usuario SET
         favorito       = :favorito,
         fecha_favorito = " . ($fecha_favorito ? ":fecha_favorito" : "NULL") . ",
         fecham         = NOW(),
         codusuariom    = :codusuariom
         WHERE codigo = :codigo"
    );
    $upd->bindParam(':favorito',      $new_value);
    if ($fecha_favorito) $upd->bindParam(':fecha_favorito', $fecha_favorito);
    $upd->bindParam(':codusuariom',   $data->codigo_usuario);
    $upd->bindParam(':codigo',        $existing['codigo']);

    if ($upd->execute()) {
        ob_clean();
        echo json_encode(array("message" => "Favorito actualizado.", "favorito" => $new_value));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo actualizar el favorito."));
    }
}

function get_favoritos($usuario_codigo) {
    global $db;
    $query = "SELECT v.codigo, v.titulo, v.descripcion, v.tipo_media, v.ruta_video, v.formato,
              v.imagen_miniatura, v.imagen_miniatura_nombre, v.visible, v.total_likes,
              v.fechaa, v.codusuarioa, v.fecham, v.codusuariom,
              COALESCE(vu.me_gusta, 'N') AS me_gusta,
              'S' AS favorito,
              (SELECT GROUP_CONCAT(DISTINCT vc.codigo ORDER BY vc.nombre SEPARATOR ',')
               FROM nu_video_ejercicio_categoria_rel vcr
               LEFT JOIN nu_video_ejercicio_categoria vc ON vcr.codigo_categoria = vc.codigo AND vc.activo = 'S'
               WHERE vcr.codigo_video = v.codigo) AS categorias_ids,
              (SELECT GROUP_CONCAT(DISTINCT vc.nombre ORDER BY vc.nombre SEPARATOR ',')
               FROM nu_video_ejercicio_categoria_rel vcr
               LEFT JOIN nu_video_ejercicio_categoria vc ON vcr.codigo_categoria = vc.codigo AND vc.activo = 'S'
               WHERE vcr.codigo_video = v.codigo) AS categorias_nombres
              FROM nu_video_ejercicio v
              INNER JOIN nu_video_ejercicio_usuario vu
                ON vu.codigo_video = v.codigo AND vu.codigo_usuario = :usuario
              WHERE v.visible = 'S'
              AND vu.favorito = 'S'
              ORDER BY vu.fecha_favorito DESC";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':usuario', $usuario_codigo);
    $stmt->execute();
    $videos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($videos as &$v) {
        if (!empty($v['imagen_miniatura'])) {
            $v['imagen_miniatura'] = base64_encode($v['imagen_miniatura']);
        }
    }
    ob_clean();
    echo json_encode($videos);
}

function remove_usuario($video_codigo, $usuario_codigo) {
    global $db;
    $stmt = $db->prepare(
        "DELETE FROM nu_video_ejercicio_usuario WHERE codigo_video = :video AND codigo_usuario = :usuario"
    );
    $stmt->bindParam(':video',   $video_codigo);
    $stmt->bindParam(':usuario', $usuario_codigo);
    if ($stmt->execute()) {
        ob_clean();
        echo json_encode(array("message" => "Registro eliminado."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo eliminar el registro."));
    }
}
?>
