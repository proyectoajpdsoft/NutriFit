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

// Validar token (acepta usuario o guest)
$validator = new AutoValidator($db);
$user = $validator->validate();
PermissionManager::checkPermission($user, 'recetas');

switch($request_method) {
    case 'GET':
        if(isset($_GET["total_recetas"])) {
            get_total_recetas();
        } else if(isset($_GET["categorias"])) {
            get_receta_categorias();
        } else if(!empty($_GET["codigo"])) {
            get_receta($_GET["codigo"]);
        } else if(isset($_GET["paciente"]) || isset($_GET["get_recetas_paciente"])) {
            $paciente = isset($_GET["paciente"]) ? $_GET["paciente"] : '0';
            $usuario = isset($_GET["codigo_usuario"]) ? $_GET["codigo_usuario"] : null;
            get_recetas_paciente($paciente, $usuario);
        } else if(isset($_GET["portada"]) && isset($_GET["paciente_codigo"])) {
            $usuario = isset($_GET["codigo_usuario"]) ? $_GET["codigo_usuario"] : null;
            get_recetas_portada_paciente($_GET["paciente_codigo"], $usuario);
        } else if(isset($_GET["total_likes"]) && isset($_GET["receta"])) {
            get_total_likes($_GET["receta"]);
        } else {
            get_recetas();
        }
        break;
    case 'POST':
        if(isset($_GET["categorias"])) {
            create_receta_categoria();
        } else {
            create_receta();
        }
        break;
    case 'PUT':
        update_receta();
        break;
    case 'DELETE':
        if(!empty($_GET["codigo"])) {
            delete_receta($_GET["codigo"]);
        }
        break;
    default:
        http_response_code(405);
        echo json_encode(array("message" => "Método no permitido."));
        break;
}

function ensure_receta_categoria_tables() {
    global $db;

    $db->exec("CREATE TABLE IF NOT EXISTS nu_receta_categoria (
        codigo INT AUTO_INCREMENT PRIMARY KEY,
        nombre VARCHAR(150) NOT NULL,
        activo VARCHAR(1) DEFAULT 'S',
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        fecham DATETIME DEFAULT NULL,
        codusuariom INT DEFAULT NULL,
        UNIQUE KEY unique_receta_categoria_nombre (nombre)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $db->exec("CREATE TABLE IF NOT EXISTS nu_receta_categoria_rel (
        codigo_receta INT NOT NULL,
        codigo_categoria INT NOT NULL,
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        PRIMARY KEY (codigo_receta, codigo_categoria),
        KEY idx_receta_categoria_rel_cat (codigo_categoria),
        CONSTRAINT receta_categoria_rel_receta_fk FOREIGN KEY (codigo_receta) REFERENCES nu_receta(codigo) ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT receta_categoria_rel_categoria_fk FOREIGN KEY (codigo_categoria) REFERENCES nu_receta_categoria(codigo) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

function get_receta_categorias() {
    global $db;
    ensure_receta_categoria_tables();

    $query = "SELECT codigo, nombre, activo FROM nu_receta_categoria WHERE activo = 'S' ORDER BY nombre";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $categorias = $stmt->fetchAll(PDO::FETCH_ASSOC);

    ob_clean();
    echo json_encode($categorias);
}

function create_receta_categoria() {
    global $db;
    ensure_receta_categoria_tables();
    $data = json_decode(file_get_contents("php://input"));

    if (empty($data->nombre)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el nombre de la categoria."));
        return;
    }

    $nombre = trim($data->nombre);
    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;

    $stmt = $db->prepare("SELECT codigo, nombre FROM nu_receta_categoria WHERE LOWER(nombre) = LOWER(:nombre) LIMIT 1");
    $stmt->bindParam(':nombre', $nombre);
    $stmt->execute();
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($existing) {
        ob_clean();
        echo json_encode(array(
            "codigo" => (int)$existing['codigo'],
            "nombre" => $existing['nombre'],
            "existed" => true
        ));
        return;
    }

    $stmt = $db->prepare("INSERT INTO nu_receta_categoria (nombre, activo, fechaa, codusuarioa) VALUES (:nombre, 'S', NOW(), :codusuarioa)");
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':codusuarioa', $codusuarioa);

    if ($stmt->execute()) {
        $codigo = $db->lastInsertId();
        http_response_code(201);
        ob_clean();
        echo json_encode(array(
            "codigo" => (int)$codigo,
            "nombre" => $nombre,
            "existed" => false
        ));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo crear la categoria."));
    }
}

function update_receta_categorias($codigo_receta, $categorias, $codusuarioa = 1) {
    global $db;
    ensure_receta_categoria_tables();

    $db->prepare("DELETE FROM nu_receta_categoria_rel WHERE codigo_receta = :codigo")
        ->execute(array(':codigo' => $codigo_receta));

    if (empty($categorias) || !is_array($categorias)) {
        return;
    }

    $stmt = $db->prepare("INSERT INTO nu_receta_categoria_rel (codigo_receta, codigo_categoria, fechaa, codusuarioa) VALUES (:codigo_receta, :codigo_categoria, NOW(), :codusuarioa)");
    foreach ($categorias as $categoria_id) {
        $categoria_id = intval($categoria_id);
        if ($categoria_id <= 0) continue;
        $stmt->bindParam(':codigo_receta', $codigo_receta);
        $stmt->bindParam(':codigo_categoria', $categoria_id);
        $stmt->bindParam(':codusuarioa', $codusuarioa);
        $stmt->execute();
    }
}

function bind_receta_params($stmt, $data) {
    $stmt->bindParam(":titulo", $data->titulo);
    $stmt->bindParam(":texto", $data->texto);
    $stmt->bindParam(":activo", $data->activo);

    $fecha_inicio = !empty($data->fecha_inicio) ? $data->fecha_inicio : null;
    $stmt->bindParam(":fecha_inicio", $fecha_inicio);

    $fecha_fin = !empty($data->fecha_fin) ? $data->fecha_fin : null;
    $stmt->bindParam(":fecha_fin", $fecha_fin);

    $stmt->bindParam(":mostrar_portada", $data->mostrar_portada);

    $visible_para_todos = !empty($data->visible_para_todos) ? $data->visible_para_todos : 'S';
    $stmt->bindParam(":visible_para_todos", $visible_para_todos);

    $imagen_portada = null;
    $imagen_portada_nombre = null;
    if (!empty($data->imagen_portada)) {
        $imagen_portada = base64_decode($data->imagen_portada);
        $imagen_portada_nombre = $data->imagen_portada_nombre ?? 'portada.jpg';
    }
    $stmt->bindParam(":imagen_portada", $imagen_portada, PDO::PARAM_LOB);
    $stmt->bindParam(":imagen_portada_nombre", $imagen_portada_nombre);

    // Handle thumbnail
    $imagen_miniatura = null;
    if (!empty($data->imagen_miniatura)) {
        $imagen_miniatura = base64_decode($data->imagen_miniatura);
    }
    $stmt->bindParam(":imagen_miniatura", $imagen_miniatura, PDO::PARAM_LOB);
}

function get_recetas() {
    global $db;
    ensure_receta_categoria_tables();

    $query = "SELECT r.codigo, r.titulo, r.texto, r.activo, r.fecha_inicio, r.fecha_fin, 
              r.mostrar_portada, r.visible_para_todos, r.imagen_portada_nombre, r.imagen_miniatura,
              r.fechaa, r.codusuarioa, r.fecham, r.codusuariom,
              (SELECT COUNT(*) FROM nu_receta_usuario ru WHERE ru.codigo_receta = r.codigo AND ru.me_gusta = 'S') as total_likes,
              (SELECT COUNT(DISTINCT CASE WHEN ru.codigo_paciente IS NOT NULL THEN ru.codigo_paciente END) FROM nu_receta_usuario ru WHERE ru.codigo_receta = r.codigo) as total_pacientes,
              GROUP_CONCAT(DISTINCT rc.codigo ORDER BY rc.nombre SEPARATOR ',') as categorias_ids,
              GROUP_CONCAT(DISTINCT rc.nombre ORDER BY rc.nombre SEPARATOR ',') as categorias_nombres
              FROM nu_receta r 
              LEFT JOIN nu_receta_categoria_rel rcr ON r.codigo = rcr.codigo_receta
              LEFT JOIN nu_receta_categoria rc ON rcr.codigo_categoria = rc.codigo AND rc.activo = 'S'
              GROUP BY r.codigo
              ORDER BY r.fechaa DESC";

    $stmt = $db->prepare($query);
    $stmt->execute();
    $recetas = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($recetas as &$receta) {
        // Solo codificar miniatura (imagen_portada no está en el SELECT)
        if ($receta['imagen_miniatura']) {
            $receta['imagen_miniatura'] = base64_encode($receta['imagen_miniatura']);
        }
    }

    ob_clean();
    echo json_encode($recetas);
}

function get_total_recetas() {
    global $db;
    $query = "SELECT COUNT(*) as total FROM nu_receta";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($row);
}

function get_receta($codigo) {
    global $db;
    ensure_receta_categoria_tables();

    $query = "SELECT r.*,
              (SELECT COUNT(*) FROM nu_receta_usuario ru WHERE ru.codigo_receta = r.codigo AND ru.me_gusta = 'S') as total_likes,
              (SELECT COUNT(DISTINCT CASE WHEN ru.codigo_paciente IS NOT NULL THEN ru.codigo_paciente END) FROM nu_receta_usuario ru WHERE ru.codigo_receta = r.codigo) as total_pacientes,
              GROUP_CONCAT(DISTINCT rc.codigo ORDER BY rc.nombre SEPARATOR ',') as categorias_ids,
              GROUP_CONCAT(DISTINCT rc.nombre ORDER BY rc.nombre SEPARATOR ',') as categorias_nombres
              FROM nu_receta r 
              LEFT JOIN nu_receta_categoria_rel rcr ON r.codigo = rcr.codigo_receta
              LEFT JOIN nu_receta_categoria rc ON rcr.codigo_categoria = rc.codigo AND rc.activo = 'S'
              WHERE r.codigo = :codigo
              GROUP BY r.codigo";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $receta = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($receta) {
        if ($receta['imagen_portada']) {
            $receta['imagen_portada'] = base64_encode($receta['imagen_portada']);
        }
        if ($receta['imagen_miniatura']) {
            $receta['imagen_miniatura'] = base64_encode($receta['imagen_miniatura']);
        }
        ob_clean();
        echo json_encode($receta);
    } else {
        http_response_code(404);
        ob_clean();
        echo json_encode(array("message" => "Receta no encontrada."));
    }
}

function get_recetas_paciente($paciente_codigo, $codigo_usuario = null) {
    global $db;
    ensure_receta_categoria_tables();

    // Si se proporciona codigo_usuario, hacer JOIN para obtener estado de favorito y me_gusta
    if ($codigo_usuario !== null) {
          $query = "SELECT r.codigo, r.titulo, r.texto, r.activo, r.fecha_inicio, r.fecha_fin,
              r.mostrar_portada, r.visible_para_todos, r.imagen_portada, r.imagen_portada_nombre, r.imagen_miniatura,
              r.fechaa, r.codusuarioa, r.fecham, r.codusuariom,
              MAX(COALESCE(ru.me_gusta, 'N')) as me_gusta, 
              MAX(COALESCE(ru.favorito, 'N')) as favorito,
              (SELECT COUNT(*) FROM nu_receta_usuario ru2 WHERE ru2.codigo_receta = r.codigo AND ru2.me_gusta = 'S') as total_likes,
              GROUP_CONCAT(DISTINCT rc.codigo ORDER BY rc.nombre SEPARATOR ',') as categorias_ids,
              GROUP_CONCAT(DISTINCT rc.nombre ORDER BY rc.nombre SEPARATOR ',') as categorias_nombres
              FROM nu_receta r
              LEFT JOIN nu_receta_usuario ru ON r.codigo = ru.codigo_receta AND ru.codigo_usuario = :codigo_usuario
              LEFT JOIN nu_receta_categoria_rel rcr ON r.codigo = rcr.codigo_receta
              LEFT JOIN nu_receta_categoria rc ON rcr.codigo_categoria = rc.codigo AND rc.activo = 'S'
              WHERE r.activo = 'S'
              AND r.visible_para_todos = 'S'
              GROUP BY r.codigo
              ORDER BY r.fechaa DESC";
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigo_usuario', $codigo_usuario);
    } else {
        // Sin codigo_usuario, devolver valores por defecto
          $query = "SELECT r.codigo, r.titulo, r.texto, r.activo, r.fecha_inicio, r.fecha_fin,
              r.mostrar_portada, r.visible_para_todos, r.imagen_portada, r.imagen_portada_nombre, r.imagen_miniatura,
              r.fechaa, r.codusuarioa, r.fecham, r.codusuariom,
              'N' as me_gusta, 
              'N' as favorito,
              (SELECT COUNT(*) FROM nu_receta_usuario ru2 WHERE ru2.codigo_receta = r.codigo AND ru2.me_gusta = 'S') as total_likes,
              GROUP_CONCAT(DISTINCT rc.codigo ORDER BY rc.nombre SEPARATOR ',') as categorias_ids,
              GROUP_CONCAT(DISTINCT rc.nombre ORDER BY rc.nombre SEPARATOR ',') as categorias_nombres
              FROM nu_receta r
              LEFT JOIN nu_receta_categoria_rel rcr ON r.codigo = rcr.codigo_receta
              LEFT JOIN nu_receta_categoria rc ON rcr.codigo_categoria = rc.codigo AND rc.activo = 'S'
              WHERE r.activo = 'S'
              AND r.visible_para_todos = 'S'
              GROUP BY r.codigo
              ORDER BY r.fechaa DESC";
        
        $stmt = $db->prepare($query);
    }

    $stmt->execute();
    $recetas = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($recetas as &$receta) {
        if ($receta['imagen_portada']) {
            $receta['imagen_portada'] = base64_encode($receta['imagen_portada']);
        }
        if ($receta['imagen_miniatura']) {
            $receta['imagen_miniatura'] = base64_encode($receta['imagen_miniatura']);
        }
    }

    ob_clean();
    echo json_encode($recetas);
}

function get_recetas_portada_paciente($paciente_codigo, $codigo_usuario = null) {
    global $db;
    ensure_receta_categoria_tables();

    $hoy = date('Y-m-d');

    // Si se proporciona codigo_usuario, hacer JOIN para obtener estado de favorito y me_gusta
    // El parámetro $paciente_codigo aquí representa el codigo_paciente del paciente
    // El parámetro $codigo_usuario (si existe) representa el codigo_usuario autenticado
    
    // Obtener codigo_paciente del usuario (si $codigo_usuario no es null, usarlo para obtener el paciente)
    $codigo_paciente = null;
    if ($codigo_usuario !== null) {
        $query_usuario = "SELECT codigo_paciente FROM usuario WHERE codigo = :codigo_usuario";
        $stmt_usuario = $db->prepare($query_usuario);
        $stmt_usuario->bindParam(':codigo_usuario', $codigo_usuario);
        $stmt_usuario->execute();
        $usuario_data = $stmt_usuario->fetch(PDO::FETCH_ASSOC);
        $codigo_paciente = $usuario_data ? $usuario_data['codigo_paciente'] : null;
    }
    
    // Si se proporciona codigo_usuario y se obtiene codigo_paciente, hacer JOIN para obtener estado personalizados
    if ($codigo_usuario !== null && $codigo_paciente !== null) {
        $query = "SELECT r.codigo, r.titulo, r.texto, r.activo, r.fecha_inicio, r.fecha_fin,
              r.mostrar_portada, r.visible_para_todos, r.imagen_portada, r.imagen_portada_nombre, r.imagen_miniatura,
              r.fechaa, r.codusuarioa, r.fecham, r.codusuariom,
              MAX(COALESCE(ru.me_gusta, 'N')) as me_gusta, 
              MAX(COALESCE(ru.favorito, 'N')) as favorito,
              (SELECT COUNT(*) FROM nu_receta_usuario ru2 WHERE ru2.codigo_receta = r.codigo AND ru2.me_gusta = 'S') as total_likes,
              GROUP_CONCAT(DISTINCT rc.codigo ORDER BY rc.nombre SEPARATOR ',') as categorias_ids,
              GROUP_CONCAT(DISTINCT rc.nombre ORDER BY rc.nombre SEPARATOR ',') as categorias_nombres
              FROM nu_receta r
              LEFT JOIN nu_receta_usuario ru ON r.codigo = ru.codigo_receta 
                  AND (ru.codigo_usuario = :codigo_usuario OR ru.codigo_paciente = :codigo_paciente)
              LEFT JOIN nu_receta_categoria_rel rcr ON r.codigo = rcr.codigo_receta
              LEFT JOIN nu_receta_categoria rc ON rcr.codigo_categoria = rc.codigo AND rc.activo = 'S'
              WHERE r.activo = 'S'
              AND r.mostrar_portada = 'S'
              AND (r.visible_para_todos = 'S' OR ru.codigo_usuario = :codigo_usuario OR ru.codigo_paciente = :codigo_paciente)
              AND (r.fecha_inicio IS NULL OR r.fecha_inicio <= :hoy)
              AND (r.fecha_fin IS NULL OR r.fecha_fin >= :hoy)
              GROUP BY r.codigo
              ORDER BY r.fechaa DESC";
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigo_usuario', $codigo_usuario);
        $stmt->bindParam(':codigo_paciente', $codigo_paciente);
        $stmt->bindParam(':hoy', $hoy);
    } else {
        // Sin codigo_usuario, devolver solo visible_para_todos
        $query = "SELECT r.codigo, r.titulo, r.texto, r.activo, r.fecha_inicio, r.fecha_fin,
              r.mostrar_portada, r.visible_para_todos, r.imagen_portada, r.imagen_portada_nombre, r.imagen_miniatura,
              r.fechaa, r.codusuarioa, r.fecham, r.codusuariom,
              'N' as me_gusta, 
              'N' as favorito,
              (SELECT COUNT(*) FROM nu_receta_usuario ru2 WHERE ru2.codigo_receta = r.codigo AND ru2.me_gusta = 'S') as total_likes,
              GROUP_CONCAT(DISTINCT rc.codigo ORDER BY rc.nombre SEPARATOR ',') as categorias_ids,
              GROUP_CONCAT(DISTINCT rc.nombre ORDER BY rc.nombre SEPARATOR ',') as categorias_nombres
              FROM nu_receta r
              LEFT JOIN nu_receta_categoria_rel rcr ON r.codigo = rcr.codigo_receta
              LEFT JOIN nu_receta_categoria rc ON rcr.codigo_categoria = rc.codigo AND rc.activo = 'S'
              WHERE r.activo = 'S'
              AND r.mostrar_portada = 'S'
              AND r.visible_para_todos = 'S'
              AND (r.fecha_inicio IS NULL OR r.fecha_inicio <= :hoy)
              AND (r.fecha_fin IS NULL OR r.fecha_fin >= :hoy)
              GROUP BY r.codigo
              ORDER BY r.fechaa DESC";
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(':hoy', $hoy);
    }

    $stmt->execute();
    $recetas = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($recetas as &$receta) {
        if ($receta['imagen_portada']) {
            $receta['imagen_portada'] = base64_encode($receta['imagen_portada']);
        }
        if ($receta['imagen_miniatura']) {
            $receta['imagen_miniatura'] = base64_encode($receta['imagen_miniatura']);
        }
    }

    ob_clean();
    echo json_encode($recetas);
}

function get_total_likes($codigo_receta) {
    global $db;

    $query = "SELECT COUNT(*) as total FROM nu_receta_usuario WHERE codigo_receta = :codigo AND me_gusta = 'S'";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo_receta);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);

    ob_clean();
    echo json_encode($result);
}

function create_receta() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;

    $query = "INSERT INTO nu_receta SET
                titulo = :titulo,
                texto = :texto,
                activo = :activo,
                fecha_inicio = :fecha_inicio,
                fecha_fin = :fecha_fin,
                mostrar_portada = :mostrar_portada,
                visible_para_todos = :visible_para_todos,
                imagen_portada = :imagen_portada,
                imagen_portada_nombre = :imagen_portada_nombre,
                imagen_miniatura = :imagen_miniatura,
                fechaa = NOW(),
                codusuarioa = :codusuarioa";

    $stmt = $db->prepare($query);
    bind_receta_params($stmt, $data);
    $stmt->bindParam(":codusuarioa", $codusuarioa);

    if($stmt->execute()) {
        $receta_id = $db->lastInsertId();
        if (isset($data->categorias)) {
            update_receta_categorias($receta_id, $data->categorias, $codusuarioa);
        }
        http_response_code(201);
        ob_clean();
        echo json_encode(array("message" => "Receta creada.", "codigo" => $receta_id));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array(
            "message" => "No se pudo crear la receta.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function update_receta() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));

    if(empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el código de la receta."));
        return;
    }

    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;

    $query = "UPDATE nu_receta SET
                titulo = :titulo,
                texto = :texto,
                activo = :activo,
                fecha_inicio = :fecha_inicio,
                fecha_fin = :fecha_fin,
                mostrar_portada = :mostrar_portada,
                visible_para_todos = :visible_para_todos,
                imagen_portada = :imagen_portada,
                imagen_portada_nombre = :imagen_portada_nombre,
                imagen_miniatura = :imagen_miniatura,
                fecham = NOW(),
                codusuariom = :codusuariom
              WHERE codigo = :codigo";

    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);
    $stmt->bindParam(":codusuariom", $codusuariom);
    bind_receta_params($stmt, $data);

    if($stmt->execute()){
        if (isset($data->categorias)) {
            update_receta_categorias($data->codigo, $data->categorias, $codusuariom);
        }
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Receta actualizada."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array(
            "message" => "No se pudo actualizar la receta.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function delete_receta($codigo) {
    global $db;

    $query = "DELETE FROM nu_receta WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);

    if($stmt->execute()){
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Receta eliminada."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo eliminar la receta."));
    }
}
?>
