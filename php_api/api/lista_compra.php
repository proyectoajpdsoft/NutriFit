<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

ini_set('display_errors', 0);
error_reporting(E_ALL);

require_once '../config/database.php';
require_once '../auth/token_validator.php';
require_once '../auth/auto_validator.php';
require_once '../auth/permissions.php';

$method = $_SERVER['REQUEST_METHOD'];

// Manejar solicitud OPTIONS para CORS
if ($method == "OPTIONS") {
    http_response_code(200);
    exit();
}

// Obtener la conexión
$database = new Database();
$db = $database->getConnection();

if (!$db) {
    http_response_code(500);
    echo json_encode(array("error" => "Error de conexión a la base de datos"));
    exit();
}

// Validar token (acepta usuario o guest)
$validator = new AutoValidator($db);
$user = $validator->validate();
PermissionManager::checkPermission($user, 'lista_compra');

// Función para obtener todos los items de un usuario
function get_items_usuario($db, $codigo_usuario, $filtro = null) {
    try {
        $query = "SELECT * FROM nu_lista_compra WHERE codigo_usuario = :codigo_usuario";
        
        // Aplicar filtros
        if ($filtro == 'pendientes') {
            $query .= " AND comprado = 'N'";
        } elseif ($filtro == 'comprados') {
            $query .= " AND comprado = 'S'";
        } elseif ($filtro == 'por_caducar') {
            $query .= " AND fecha_caducidad IS NOT NULL AND fecha_caducidad >= CURDATE() AND fecha_caducidad <= DATE_ADD(CURDATE(), INTERVAL 3 DAY) AND comprado = 'N'";
        } elseif ($filtro == 'caducados') {
            $query .= " AND fecha_caducidad IS NOT NULL AND fecha_caducidad < CURDATE() AND comprado = 'N'";
        }
        
        $query .= " ORDER BY comprado ASC, fecha_caducidad ASC, categoria ASC, nombre ASC";
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigo_usuario', $codigo_usuario);
        $stmt->execute();
        
        $items = array();
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $items[] = $row;
        }
        
        return $items;
    } catch (PDOException $e) {
        throw new Exception("Error al obtener items: " . $e->getMessage());
    }
}

// Función para obtener items por categoría
function get_items_por_categoria($db, $codigo_usuario, $categoria) {
    try {
        $query = "SELECT * FROM nu_lista_compra WHERE codigo_usuario = :codigo_usuario AND categoria = :categoria ORDER BY comprado ASC, nombre ASC";
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigo_usuario', $codigo_usuario);
        $stmt->bindParam(':categoria', $categoria);
        $stmt->execute();
        
        $items = array();
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $items[] = $row;
        }
        
        return $items;
    } catch (PDOException $e) {
        throw new Exception("Error al obtener items por categoría: " . $e->getMessage());
    }
}

// Función para obtener un item específico
function get_item($db, $codigo) {
    try {
        $query = "SELECT * FROM nu_lista_compra WHERE codigo = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigo', $codigo);
        $stmt->execute();
        
        return $stmt->fetch(PDO::FETCH_ASSOC);
    } catch (PDOException $e) {
        throw new Exception("Error al obtener item: " . $e->getMessage());
    }
}

// Función para crear un item
function create_item($db, $data) {
    try {
        $query = "INSERT INTO nu_lista_compra (codigo_usuario, nombre, descripcion, categoria, cantidad, unidad, comprado, fecha_caducidad, fecha_compra, notas, codusuarioa, fechaa) VALUES (:codigo_usuario, :nombre, :descripcion, :categoria, :cantidad, :unidad, :comprado, :fecha_caducidad, :fecha_compra, :notas, :codusuarioa, NOW())";
        
        $stmt = $db->prepare($query);
        
        // Preparar variables con valores por defecto
        $codigo_usuario = isset($data['codigo_usuario']) ? $data['codigo_usuario'] : null;
        $nombre = isset($data['nombre']) ? $data['nombre'] : null;
        $descripcion = isset($data['descripcion']) ? $data['descripcion'] : null;
        $categoria = isset($data['categoria']) ? $data['categoria'] : null;
        $cantidad = isset($data['cantidad']) ? $data['cantidad'] : null;
        $unidad = isset($data['unidad']) ? $data['unidad'] : null;
        $comprado = isset($data['comprado']) ? $data['comprado'] : 'N';
        $fecha_caducidad = isset($data['fecha_caducidad']) ? $data['fecha_caducidad'] : null;
        $fecha_compra = isset($data['fecha_compra']) ? $data['fecha_compra'] : null;
        $notas = isset($data['notas']) ? $data['notas'] : null;
        $codusuarioa = isset($data['codusuarioa']) ? $data['codusuarioa'] : null;
        
        $stmt->bindParam(':codigo_usuario', $codigo_usuario);
        $stmt->bindParam(':nombre', $nombre);
        $stmt->bindParam(':descripcion', $descripcion);
        $stmt->bindParam(':categoria', $categoria);
        $stmt->bindParam(':cantidad', $cantidad);
        $stmt->bindParam(':unidad', $unidad);
        $stmt->bindParam(':comprado', $comprado);
        $stmt->bindParam(':fecha_caducidad', $fecha_caducidad);
        $stmt->bindParam(':fecha_compra', $fecha_compra);
        $stmt->bindParam(':notas', $notas);
        $stmt->bindParam(':codusuarioa', $codusuarioa);
        
        if ($stmt->execute()) {
            return $db->lastInsertId();
        }
        return false;
    } catch (PDOException $e) {
        throw new Exception("Error al crear item: " . $e->getMessage());
    }
}

// Función para actualizar un item
function update_item($db, $data) {
    try {
        $query = "UPDATE nu_lista_compra SET nombre = :nombre, descripcion = :descripcion, categoria = :categoria, cantidad = :cantidad, unidad = :unidad, comprado = :comprado, fecha_caducidad = :fecha_caducidad, fecha_compra = :fecha_compra, notas = :notas WHERE codigo = :codigo";
        
        $stmt = $db->prepare($query);
        
        // Preparar variables
        $codigo = isset($data['codigo']) ? $data['codigo'] : null;
        $nombre = isset($data['nombre']) ? $data['nombre'] : null;
        $descripcion = isset($data['descripcion']) ? $data['descripcion'] : null;
        $categoria = isset($data['categoria']) ? $data['categoria'] : null;
        $cantidad = isset($data['cantidad']) ? $data['cantidad'] : null;
        $unidad = isset($data['unidad']) ? $data['unidad'] : null;
        $comprado = isset($data['comprado']) ? $data['comprado'] : 'N';
        $fecha_caducidad = isset($data['fecha_caducidad']) ? $data['fecha_caducidad'] : null;
        $fecha_compra = isset($data['fecha_compra']) ? $data['fecha_compra'] : null;
        $notas = isset($data['notas']) ? $data['notas'] : null;
        
        $stmt->bindParam(':codigo', $codigo);
        $stmt->bindParam(':nombre', $nombre);
        $stmt->bindParam(':descripcion', $descripcion);
        $stmt->bindParam(':categoria', $categoria);
        $stmt->bindParam(':cantidad', $cantidad);
        $stmt->bindParam(':unidad', $unidad);
        $stmt->bindParam(':comprado', $comprado);
        $stmt->bindParam(':fecha_caducidad', $fecha_caducidad);
        $stmt->bindParam(':fecha_compra', $fecha_compra);
        $stmt->bindParam(':notas', $notas);
        
        return $stmt->execute();
    } catch (PDOException $e) {
        throw new Exception("Error al actualizar item: " . $e->getMessage());
    }
}

// Función para marcar como comprado/pendiente
function toggle_comprado($db, $codigo) {
    try {
        $item = get_item($db, $codigo);
        
        if (!$item) {
            return false;
        }
        
        $nuevo_estado = ($item['comprado'] == 'S') ? 'N' : 'S';
        $fecha_compra = $nuevo_estado == 'S' ? date('Y-m-d H:i:s') : null;
        
        $query = "UPDATE nu_lista_compra SET comprado = :comprado, fecha_compra = :fecha_compra WHERE codigo = :codigo";
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigo', $codigo);
        $stmt->bindParam(':comprado', $nuevo_estado);
        $stmt->bindParam(':fecha_compra', $fecha_compra);
        
        return $stmt->execute();
    } catch (PDOException $e) {
        throw new Exception("Error al cambiar estado de compra: " . $e->getMessage());
    }
}

// Función para eliminar un item
function delete_item($db, $codigo) {
    try {
        $query = "DELETE FROM nu_lista_compra WHERE codigo = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigo', $codigo);
        
        return $stmt->execute();
    } catch (PDOException $e) {
        throw new Exception("Error al eliminar item: " . $e->getMessage());
    }
}

// Función para eliminar todos los items comprados de un usuario
function delete_comprados($db, $codigo_usuario) {
    try {
        $query = "DELETE FROM nu_lista_compra WHERE codigo_usuario = :codigo_usuario AND comprado = 'S'";
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigo_usuario', $codigo_usuario);
        
        return $stmt->execute();
    } catch (PDOException $e) {
        throw new Exception("Error al eliminar items comprados: " . $e->getMessage());
    }
}

// Manejar solicitudes
if ($method == 'GET') {
    try {
        if (isset($_GET['codigo'])) {
            // Obtener un item específico
            $item = get_item($db, $_GET['codigo']);
            if ($item) {
                http_response_code(200);
                echo json_encode($item);
            } else {
                http_response_code(404);
                echo json_encode(array("message" => "Item no encontrado"));
            }
        } elseif (isset($_GET['usuario']) || isset($_GET['usuario_id'])) {
            // Obtener items de un usuario
            $codigo_usuario = isset($_GET['usuario']) ? $_GET['usuario'] : $_GET['usuario_id'];
            $filtro = isset($_GET['filtro']) ? $_GET['filtro'] : null;
            $items = get_items_usuario($db, $codigo_usuario, $filtro);
            http_response_code(200);
            echo json_encode($items);
        } elseif (isset($_GET['usuario_categoria']) && isset($_GET['categoria'])) {
            // Obtener items por categoría
            $items = get_items_por_categoria($db, $_GET['usuario_categoria'], $_GET['categoria']);
            http_response_code(200);
            echo json_encode($items);
        } else {
            http_response_code(400);
            echo json_encode(array("message" => "Parámetros inválidos"));
        }
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(array("error" => $e->getMessage()));
    }
    
} elseif ($method == 'POST') {
    try {
        $data = json_decode(file_get_contents("php://input"), true);
        
        if (isset($_GET['toggle_comprado'])) {
            if (toggle_comprado($db, $data['codigo'])) {
                http_response_code(200);
                echo json_encode(array("message" => "Estado actualizado"));
            } else {
                http_response_code(500);
                echo json_encode(array("message" => "Error al actualizar estado"));
            }
        } elseif (isset($_GET['delete_comprados'])) {
            if (delete_comprados($db, $data['codigo_usuario'])) {
                http_response_code(200);
                echo json_encode(array("message" => "Items comprados eliminados"));
            } else {
                http_response_code(500);
                echo json_encode(array("message" => "Error al eliminar items"));
            }
        } else {
            $item_id = create_item($db, $data);
            if ($item_id) {
                http_response_code(201);
                echo json_encode(array("message" => "Item creado", "codigo" => $item_id));
            } else {
                http_response_code(500);
                echo json_encode(array("message" => "Error al crear item"));
            }
        }
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(array("error" => $e->getMessage()));
    }
    
} elseif ($method == 'PUT') {
    try {
        $data = json_decode(file_get_contents("php://input"), true);
        
        if (update_item($db, $data)) {
            http_response_code(200);
            echo json_encode(array("message" => "Item actualizado"));
        } else {
            http_response_code(500);
            echo json_encode(array("message" => "Error al actualizar item"));
        }
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(array("error" => $e->getMessage()));
    }
    
} elseif ($method == 'DELETE') {
    try {
        if (isset($_GET['codigo'])) {
            if (delete_item($db, $_GET['codigo'])) {
                http_response_code(200);
                echo json_encode(array("message" => "Item eliminado"));
            } else {
                http_response_code(500);
                echo json_encode(array("message" => "Error al eliminar item"));
            }
        } else {
            http_response_code(400);
            echo json_encode(array("message" => "Código de item no proporcionado"));
        }
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(array("error" => $e->getMessage()));
    }
}
?>
