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
PermissionManager::checkPermission($user, 'consejos');

switch($request_method) {
    case 'GET':
        if(isset($_GET["total_consejos"])) {
            get_total_consejos();
        } else if(isset($_GET["categorias"])) {
            get_consejo_categorias();
        } else if(!empty($_GET["codigo"])) {
            get_consejo($_GET["codigo"]);
        } else if(isset($_GET["paciente"])) {
            $usuario = isset($_GET["codigo_usuario"]) ? $_GET["codigo_usuario"] : null;
            get_consejos_paciente($_GET["paciente"], $usuario);
        } else if(isset($_GET["portada"]) && isset($_GET["paciente_codigo"])) {
            $usuario = isset($_GET["codigo_usuario"]) ? $_GET["codigo_usuario"] : null;
            get_consejos_portada_paciente($_GET["paciente_codigo"], $usuario);
        } else if(isset($_GET["total_likes"]) && isset($_GET["consejo"])) {
            get_total_likes($_GET["consejo"]);
        } else {
            get_consejos();
        }
        break;
    case 'POST':
        if(isset($_GET["categorias"])) {
            create_consejo_categoria();
        } else {
            create_consejo();
        }
        break;
    case 'PUT':
        update_consejo();
        break;
    case 'DELETE':
        if(!empty($_GET["codigo"])) {
            delete_consejo($_GET["codigo"]);
        }
        break;
    default:
        http_response_code(405);
        echo json_encode(array("message" => "Método no permitido."));
        break;
}

function ensure_consejo_categoria_tables() {
    global $db;

    $db->exec("CREATE TABLE IF NOT EXISTS nu_consejo_categoria (
        codigo INT AUTO_INCREMENT PRIMARY KEY,
        nombre VARCHAR(150) NOT NULL,
        activo VARCHAR(1) DEFAULT 'S',
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        fecham DATETIME DEFAULT NULL,
        codusuariom INT DEFAULT NULL,
        UNIQUE KEY unique_consejo_categoria_nombre (nombre)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $db->exec("CREATE TABLE IF NOT EXISTS nu_consejo_categoria_rel (
        codigo_consejo INT NOT NULL,
        codigo_categoria INT NOT NULL,
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        PRIMARY KEY (codigo_consejo, codigo_categoria),
        KEY idx_consejo_categoria_rel_cat (codigo_categoria),
        CONSTRAINT consejo_categoria_rel_consejo_fk FOREIGN KEY (codigo_consejo) REFERENCES nu_consejo(codigo) ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT consejo_categoria_rel_categoria_fk FOREIGN KEY (codigo_categoria) REFERENCES nu_consejo_categoria(codigo) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

function get_consejo_categorias() {
    global $db;
    ensure_consejo_categoria_tables();

    $query = "SELECT codigo, nombre, activo FROM nu_consejo_categoria WHERE activo = 'S' ORDER BY nombre";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $categorias = $stmt->fetchAll(PDO::FETCH_ASSOC);

    ob_clean();
    echo json_encode($categorias);
}

function create_consejo_categoria() {
    global $db;
    ensure_consejo_categoria_tables();
    $data = json_decode(file_get_contents("php://input"));

    if (empty($data->nombre)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el nombre de la categoria."));
        return;
    }

    $nombre = trim($data->nombre);
    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;

    $stmt = $db->prepare("SELECT codigo, nombre FROM nu_consejo_categoria WHERE LOWER(nombre) = LOWER(:nombre) LIMIT 1");
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

    $stmt = $db->prepare("INSERT INTO nu_consejo_categoria (nombre, activo, fechaa, codusuarioa) VALUES (:nombre, 'S', NOW(), :codusuarioa)");
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

function update_consejo_categorias($codigo_consejo, $categorias, $codusuarioa = 1) {
    global $db;
    ensure_consejo_categoria_tables();

    $db->prepare("DELETE FROM nu_consejo_categoria_rel WHERE codigo_consejo = :codigo")
        ->execute(array(':codigo' => $codigo_consejo));

    if (empty($categorias) || !is_array($categorias)) {
        return;
    }

    $stmt = $db->prepare("INSERT INTO nu_consejo_categoria_rel (codigo_consejo, codigo_categoria, fechaa, codusuarioa) VALUES (:codigo_consejo, :codigo_categoria, NOW(), :codusuarioa)");
    foreach ($categorias as $categoria_id) {
        $categoria_id = intval($categoria_id);
        if ($categoria_id <= 0) continue;
        $stmt->bindParam(':codigo_consejo', $codigo_consejo);
        $stmt->bindParam(':codigo_categoria', $categoria_id);
        $stmt->bindParam(':codusuarioa', $codusuarioa);
        $stmt->execute();
    }
}

function bind_consejo_params($stmt, $data) {
    $stmt->bindParam(":titulo", $data->titulo);
    $stmt->bindParam(":texto", $data->texto);
    $stmt->bindParam(":activo", $data->activo);
    
    $fecha_inicio = !empty($data->fecha_inicio) ? $data->fecha_inicio : null;
    $stmt->bindParam(":fecha_inicio", $fecha_inicio);
    
    $fecha_fin = !empty($data->fecha_fin) ? $data->fecha_fin : null;
    $stmt->bindParam(":fecha_fin", $fecha_fin);
    
    $stmt->bindParam(":mostrar_portada", $data->mostrar_portada);
    
    $visible_para_todos = !empty($data->visible_para_todos) ? $data->visible_para_todos : 'N';
    $stmt->bindParam(":visible_para_todos", $visible_para_todos);
    
    // Imagen de portada
    $imagen_portada = null;
    $imagen_portada_nombre = null;
    if (!empty($data->imagen_portada)) {
        $imagen_portada = base64_decode($data->imagen_portada);
        $imagen_portada_nombre = $data->imagen_portada_nombre ?? 'portada.jpg';
    }
    $stmt->bindParam(":imagen_portada", $imagen_portada, PDO::PARAM_LOB);
    $stmt->bindParam(":imagen_portada_nombre", $imagen_portada_nombre);
}

function get_consejos() {
    global $db;
    ensure_consejo_categoria_tables();
    
    $query = "SELECT c.*, 
              (SELECT COUNT(*) FROM nu_consejo_usuario cu WHERE cu.codigo_consejo = c.codigo AND cu.me_gusta = 'S') as total_likes,
              (SELECT COUNT(*) FROM nu_consejo_usuario cu WHERE cu.codigo_consejo = c.codigo) as total_usuarios,
              GROUP_CONCAT(DISTINCT cc.codigo ORDER BY cc.nombre SEPARATOR ',') as categorias_ids,
              GROUP_CONCAT(DISTINCT cc.nombre ORDER BY cc.nombre SEPARATOR ',') as categorias_nombres
              FROM nu_consejo c 
              LEFT JOIN nu_consejo_categoria_rel ccr ON c.codigo = ccr.codigo_consejo
              LEFT JOIN nu_consejo_categoria cc ON ccr.codigo_categoria = cc.codigo AND cc.activo = 'S'
              GROUP BY c.codigo
              ORDER BY c.fechaa DESC";
    
    $stmt = $db->prepare($query);
    $stmt->execute();
    $consejos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Convertir imagen de portada a base64
    foreach ($consejos as &$consejo) {
        if ($consejo['imagen_portada']) {
            $consejo['imagen_portada'] = base64_encode($consejo['imagen_portada']);
        }
    }
    
    ob_clean();
    echo json_encode($consejos);
}

function get_total_consejos() {
    global $db;
    $query = "SELECT COUNT(*) as total FROM nu_consejo";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($row);
}

function get_consejo($codigo) {
    global $db;
    ensure_consejo_categoria_tables();
    
    $query = "SELECT c.*,
              (SELECT COUNT(*) FROM nu_consejo_usuario cu WHERE cu.codigo_consejo = c.codigo AND cu.me_gusta = 'S') as total_likes,
              (SELECT COUNT(*) FROM nu_consejo_usuario cu WHERE cu.codigo_consejo = c.codigo) as total_usuarios,
              GROUP_CONCAT(DISTINCT cc.codigo ORDER BY cc.nombre SEPARATOR ',') as categorias_ids,
              GROUP_CONCAT(DISTINCT cc.nombre ORDER BY cc.nombre SEPARATOR ',') as categorias_nombres
              FROM nu_consejo c 
              LEFT JOIN nu_consejo_categoria_rel ccr ON c.codigo = ccr.codigo_consejo
              LEFT JOIN nu_consejo_categoria cc ON ccr.codigo_categoria = cc.codigo AND cc.activo = 'S'
              WHERE c.codigo = :codigo
              GROUP BY c.codigo";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    $consejo = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($consejo) {
        if ($consejo['imagen_portada']) {
            $consejo['imagen_portada'] = base64_encode($consejo['imagen_portada']);
        }
        ob_clean();
        echo json_encode($consejo);
    } else {
        http_response_code(404);
        ob_clean();
        echo json_encode(array("message" => "Consejo no encontrado."));
    }
}

function get_consejos_paciente($paciente_codigo, $codigo_usuario = null) {
    global $db;
    ensure_consejo_categoria_tables();
    
    // Si se proporciona codigo_usuario, hacer JOIN para obtener estado de favorito y me_gusta
    if ($codigo_usuario !== null) {
        $query = "SELECT c.*, 
              MAX(COALESCE(cu.me_gusta, 'N')) as me_gusta, 
              MAX(COALESCE(cu.favorito, 'N')) as favorito,
              (SELECT COUNT(*) FROM nu_consejo_usuario cu2 WHERE cu2.codigo_consejo = c.codigo AND cu2.me_gusta = 'S') as total_likes,
              GROUP_CONCAT(DISTINCT cc.codigo ORDER BY cc.nombre SEPARATOR ',') as categorias_ids,
              GROUP_CONCAT(DISTINCT cc.nombre ORDER BY cc.nombre SEPARATOR ',') as categorias_nombres
              FROM nu_consejo c
              LEFT JOIN nu_consejo_usuario cu ON c.codigo = cu.codigo_consejo AND cu.codigo_usuario = :codigo_usuario
              LEFT JOIN nu_consejo_categoria_rel ccr ON c.codigo = ccr.codigo_consejo
              LEFT JOIN nu_consejo_categoria cc ON ccr.codigo_categoria = cc.codigo AND cc.activo = 'S'
              WHERE c.activo = 'S'
              AND c.visible_para_todos = 'S'
              GROUP BY c.codigo
              ORDER BY c.fechaa DESC";
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigo_usuario', $codigo_usuario);
    } else {
        // Sin codigo_usuario, devolver valores por defecto
        $query = "SELECT c.*, 
              'N' as me_gusta, 
              'N' as favorito,
              (SELECT COUNT(*) FROM nu_consejo_usuario cu2 WHERE cu2.codigo_consejo = c.codigo AND cu2.me_gusta = 'S') as total_likes,
              GROUP_CONCAT(DISTINCT cc.codigo ORDER BY cc.nombre SEPARATOR ',') as categorias_ids,
              GROUP_CONCAT(DISTINCT cc.nombre ORDER BY cc.nombre SEPARATOR ',') as categorias_nombres
              FROM nu_consejo c
              LEFT JOIN nu_consejo_categoria_rel ccr ON c.codigo = ccr.codigo_consejo
              LEFT JOIN nu_consejo_categoria cc ON ccr.codigo_categoria = cc.codigo AND cc.activo = 'S'
              WHERE c.activo = 'S'
              AND c.visible_para_todos = 'S'
              GROUP BY c.codigo
              ORDER BY c.fechaa DESC";
        
        $stmt = $db->prepare($query);
    }
    
    $stmt->execute();
    $consejos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($consejos as &$consejo) {
        if ($consejo['imagen_portada']) {
            $consejo['imagen_portada'] = base64_encode($consejo['imagen_portada']);
        }
    }
    
    ob_clean();
    echo json_encode($consejos);
}

function get_consejos_portada_paciente($paciente_codigo, $codigo_usuario = null) {
    global $db;
    ensure_consejo_categoria_tables();
    
    $hoy = date('Y-m-d');
    
    // Si se proporciona codigo_usuario, hacer JOIN para obtener estado de favorito y me_gusta
    if ($codigo_usuario !== null) {
        $query = "SELECT c.*, 
              MAX(COALESCE(cu.me_gusta, 'N')) as me_gusta, 
              MAX(COALESCE(cu.favorito, 'N')) as favorito,
              (SELECT COUNT(*) FROM nu_consejo_usuario cu2 WHERE cu2.codigo_consejo = c.codigo AND cu2.me_gusta = 'S') as total_likes,
              GROUP_CONCAT(DISTINCT cc.codigo ORDER BY cc.nombre SEPARATOR ',') as categorias_ids,
              GROUP_CONCAT(DISTINCT cc.nombre ORDER BY cc.nombre SEPARATOR ',') as categorias_nombres
              FROM nu_consejo c
              LEFT JOIN nu_consejo_usuario cu ON c.codigo = cu.codigo_consejo AND cu.codigo_usuario = :codigo_usuario
              LEFT JOIN nu_consejo_categoria_rel ccr ON c.codigo = ccr.codigo_consejo
              LEFT JOIN nu_consejo_categoria cc ON ccr.codigo_categoria = cc.codigo AND cc.activo = 'S'
              WHERE c.activo = 'S'
              AND c.mostrar_portada = 'S'
              AND c.visible_para_todos = 'S'
              AND (c.fecha_inicio IS NULL OR c.fecha_inicio <= :hoy)
              AND (c.fecha_fin IS NULL OR c.fecha_fin >= :hoy)
              GROUP BY c.codigo
              ORDER BY c.fechaa DESC";
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigo_usuario', $codigo_usuario);
        $stmt->bindParam(':hoy', $hoy);
    } else {
        // Sin codigo_usuario, devolver valores por defecto
        $query = "SELECT c.*, 
              'N' as me_gusta, 
              'N' as favorito,
              (SELECT COUNT(*) FROM nu_consejo_usuario cu2 WHERE cu2.codigo_consejo = c.codigo AND cu2.me_gusta = 'S') as total_likes,
              GROUP_CONCAT(DISTINCT cc.codigo ORDER BY cc.nombre SEPARATOR ',') as categorias_ids,
              GROUP_CONCAT(DISTINCT cc.nombre ORDER BY cc.nombre SEPARATOR ',') as categorias_nombres
              FROM nu_consejo c
              LEFT JOIN nu_consejo_categoria_rel ccr ON c.codigo = ccr.codigo_consejo
              LEFT JOIN nu_consejo_categoria cc ON ccr.codigo_categoria = cc.codigo AND cc.activo = 'S'
              WHERE c.activo = 'S'
              AND c.mostrar_portada = 'S'
              AND c.visible_para_todos = 'S'
              AND (c.fecha_inicio IS NULL OR c.fecha_inicio <= :hoy)
              AND (c.fecha_fin IS NULL OR c.fecha_fin >= :hoy)
              GROUP BY c.codigo
              ORDER BY c.fechaa DESC";
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(':hoy', $hoy);
    }
    
    $stmt->execute();
    $consejos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($consejos as &$consejo) {
        if ($consejo['imagen_portada']) {
            $consejo['imagen_portada'] = base64_encode($consejo['imagen_portada']);
        }
    }
    
    ob_clean();
    echo json_encode($consejos);
}

function get_total_likes($codigo_consejo) {
    global $db;
    
    $query = "SELECT COUNT(*) as total FROM nu_consejo_usuario WHERE codigo_consejo = :codigo AND me_gusta = 'S'";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo_consejo);
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    ob_clean();
    echo json_encode($result);
}

function create_consejo() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    $codusuarioa = isset($data->codusuarioa) ? $data->codusuarioa : 1;
    
    $query = "INSERT INTO nu_consejo SET
                titulo = :titulo,
                texto = :texto,
                activo = :activo,
                fecha_inicio = :fecha_inicio,
                fecha_fin = :fecha_fin,
                mostrar_portada = :mostrar_portada,
                visible_para_todos = :visible_para_todos,
                imagen_portada = :imagen_portada,
                imagen_portada_nombre = :imagen_portada_nombre,
                fechaa = NOW(),
                codusuarioa = :codusuarioa";
    
    $stmt = $db->prepare($query);
    bind_consejo_params($stmt, $data);
    $stmt->bindParam(":codusuarioa", $codusuarioa);
    
    if($stmt->execute()) {
        $consejo_id = $db->lastInsertId();
        if (isset($data->categorias)) {
            update_consejo_categorias($consejo_id, $data->categorias, $codusuarioa);
        }
        http_response_code(201);
        ob_clean();
        echo json_encode(array("message" => "Consejo creado.", "codigo" => $consejo_id));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array(
            "message" => "No se pudo crear el consejo.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function update_consejo() {
    global $db;
    $data = json_decode(file_get_contents("php://input"));
    
    if(empty($data->codigo)) {
        http_response_code(400);
        ob_clean();
        echo json_encode(array("message" => "Falta el código del consejo."));
        return;
    }
    
    $codusuariom = isset($data->codusuariom) ? $data->codusuariom : 1;
    
    $query = "UPDATE nu_consejo SET
                titulo = :titulo,
                texto = :texto,
                activo = :activo,
                fecha_inicio = :fecha_inicio,
                fecha_fin = :fecha_fin,
                mostrar_portada = :mostrar_portada,
                visible_para_todos = :visible_para_todos,
                imagen_portada = :imagen_portada,
                imagen_portada_nombre = :imagen_portada_nombre,
                fecham = NOW(),
                codusuariom = :codusuariom
              WHERE codigo = :codigo";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(":codigo", $data->codigo);
    $stmt->bindParam(":codusuariom", $codusuariom);
    bind_consejo_params($stmt, $data);
    
    if($stmt->execute()){
        if (isset($data->categorias)) {
            update_consejo_categorias($data->codigo, $data->categorias, $codusuariom);
        }
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Consejo actualizado."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array(
            "message" => "No se pudo actualizar el consejo.",
            "errorInfo" => $stmt->errorInfo()
        ));
    }
}

function delete_consejo($codigo) {
    global $db;
    
    $query = "DELETE FROM nu_consejo WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    
    if($stmt->execute()){
        http_response_code(200);
        ob_clean();
        echo json_encode(array("message" => "Consejo eliminado."));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("message" => "No se pudo eliminar el consejo."));
    }
}
?>
