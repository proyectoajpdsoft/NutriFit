<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

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

// ⭐ VALIDAR TOKEN (acepta usuario o guest)
$validator = new AutoValidator($db);
$user = $validator->validate();

// ⭐ VALIDAR PERMISOS
PermissionManager::checkPermission($user, 'entrenamientos');

// Función para obtener entrenamientos de un paciente/usuario
function get_entrenamientos($db, $codigo_paciente, $limite = null) {
    $query = "SELECT * FROM nu_entrenamientos 
              WHERE codigo_paciente = :codigo_paciente 
              ORDER BY fecha DESC";
    
    if ($limite) {
        $query .= " LIMIT " . intval($limite);
    }
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    $stmt->execute();
    
    $entrenamientos = array();
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $entrenamientos[] = $row;
    }
    
    return $entrenamientos;
}

// Función para obtener pacientes con actividades con plan fit (solo nutricionista)
function get_pacientes_con_actividades_plan_fit($db) {
        $query = "SELECT DISTINCT p.codigo, p.nombre
                            FROM usuario u
                            INNER JOIN nu_paciente p ON p.codigo = u.codigo_paciente
                            INNER JOIN nu_entrenamientos e ON e.codigo_paciente = p.codigo
                            WHERE u.codigo_paciente IS NOT NULL
                                AND e.codigo_plan_fit IS NOT NULL
                                AND e.codigo_plan_fit <> 0
                            ORDER BY p.nombre";

        $stmt = $db->prepare($query);
        $stmt->execute();

        $items = array();
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
                $items[] = $row;
        }

        return $items;
}

// Función para obtener entrenamientos con plan fit de un paciente
function get_entrenamientos_plan_fit_paciente($db, $codigo_paciente, $solo_no_validados = false) {
    $query = "SELECT e.*,
             COUNT(ee.codigo) AS ejercicios_total,
             SUM(CASE WHEN ee.realizado = 'S' THEN 1 ELSE 0 END) AS ejercicios_realizados,
             SUM(CASE WHEN ee.realizado = 'N' OR ee.realizado IS NULL OR ee.realizado = '' THEN 1 ELSE 0 END) AS ejercicios_no_realizados
            FROM nu_entrenamientos e
            LEFT JOIN nu_entrenamientos_ejercicios ee ON ee.codigo_entrenamiento = e.codigo
            WHERE e.codigo_paciente = :codigo_paciente
            AND e.codigo_plan_fit IS NOT NULL
            AND e.codigo_plan_fit <> 0";

    if ($solo_no_validados) {
        $query .= " AND (e.validado IS NULL OR e.validado = 0)";
    }

    $query .= " GROUP BY e.codigo ORDER BY e.fecha DESC";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    $stmt->execute();

    $items = array();
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $items[] = $row;
    }

    return $items;
}

// Función para obtener entrenamientos por rango de fechas
function get_entrenamientos_por_rango($db, $codigo_paciente, $fecha_inicio, $fecha_fin) {
    $query = "SELECT * FROM nu_entrenamientos 
              WHERE codigo_paciente = :codigo_paciente 
              AND DATE(fecha) >= :fecha_inicio 
              AND DATE(fecha) <= :fecha_fin 
              ORDER BY fecha DESC";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    $stmt->bindParam(':fecha_inicio', $fecha_inicio);
    $stmt->bindParam(':fecha_fin', $fecha_fin);
    $stmt->execute();
    
    $entrenamientos = array();
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $entrenamientos[] = $row;
    }
    
    return $entrenamientos;
}

// Función para obtener un entrenamiento específico
function get_entrenamiento($db, $codigo) {
    $query = "SELECT * FROM nu_entrenamientos WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->execute();
    
    return $stmt->fetch(PDO::FETCH_ASSOC);
}

// Función para crear un entrenamiento
function create_entrenamiento($db, $data) {
    $query = "INSERT INTO nu_entrenamientos 
              (codigo_paciente, actividad, descripcion_actividad, fecha, 
               duracion_horas, duracion_minutos, duracion_kilometros, nivel_esfuerzo, notas, vueltas, codigo_plan_fit, codusuario, validado, validado_fecha, validado_usuario, fechaa) 
              VALUES 
              (:codigo_paciente, :actividad, :descripcion_actividad, :fecha, 
               :duracion_horas, :duracion_minutos, :duracion_kilometros, :nivel_esfuerzo, :notas, :vueltas, :codigo_plan_fit, :codusuario, 0, NULL, NULL, NOW())";
    
    $stmt = $db->prepare($query);
    
    $stmt->bindParam(':codigo_paciente', $data['codigo_paciente']);
    $stmt->bindParam(':actividad', $data['actividad']);
    $stmt->bindParam(':descripcion_actividad', $data['descripcion_actividad']);
    $stmt->bindParam(':fecha', $data['fecha']);
    $stmt->bindParam(':duracion_horas', $data['duracion_horas']);
    $stmt->bindParam(':duracion_minutos', $data['duracion_minutos']);
    $stmt->bindParam(':duracion_kilometros', $data['duracion_kilometros']);
    $stmt->bindParam(':nivel_esfuerzo', $data['nivel_esfuerzo']);
    $stmt->bindParam(':notas', $data['notas']);
    $stmt->bindParam(':vueltas', $data['vueltas']);
    $stmt->bindParam(':codigo_plan_fit', $data['codigo_plan_fit']);
    $stmt->bindParam(':codusuario', $data['codusuario']);
    
    if ($stmt->execute()) {
        return array('success' => true, 'codigo' => $db->lastInsertId());
    }
    
    return array('success' => false, 'message' => 'Error al crear el entrenamiento: ' . implode(', ', $stmt->errorInfo()));
}

// Función para guardar imágenes de un entrenamiento
function save_entrenamiento_images($db, $codigo_entrenamiento, $fotos) {
    if (!is_array($fotos) || empty($fotos)) {
        return array('success' => true, 'message' => 'Sin imágenes para guardar');
    }

    try {
        $query = "INSERT INTO nu_entrenamientos_imagenes (codigo_entrenamiento, imagen, tipo_imagen) 
                  VALUES (:codigo_entrenamiento, :imagen, :tipo_imagen)";
        
        $stmt = $db->prepare($query);
        
        foreach ($fotos as $foto) {
            if (!isset($foto['imagen']) || !isset($foto['tipo'])) {
                continue;
            }
            
            // Decodificar base64
            $imageData = base64_decode($foto['imagen'], true);
            if ($imageData === false) {
                continue;
            }
            
            $stmt->bindParam(':codigo_entrenamiento', $codigo_entrenamiento);
            $stmt->bindParam(':imagen', $imageData, PDO::PARAM_LOB);
            $stmt->bindParam(':tipo_imagen', $foto['tipo']);
            
            $stmt->execute();
        }
        
        return array('success' => true, 'message' => 'Imágenes guardadas correctamente');
    } catch (Exception $e) {
        return array('success' => false, 'message' => 'Error al guardar imágenes: ' . $e->getMessage());
    }
}

// Función para obtener imágenes de un entrenamiento
function get_entrenamiento_images($db, $codigo_entrenamiento) {
    $query = "SELECT id, codigo_entrenamiento, tipo_imagen, fecha_creacion FROM nu_entrenamientos_imagenes 
              WHERE codigo_entrenamiento = :codigo_entrenamiento 
              ORDER BY fecha_creacion DESC";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_entrenamiento', $codigo_entrenamiento);
    $stmt->execute();
    
    $imagenes = array();
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $imagenes[] = $row;
    }
    
    return $imagenes;
}

// Función para obtener imagen de un entrenamiento (para mostrar)
function get_entrenamiento_image($db, $id_imagen) {
    $query = "SELECT imagen, tipo_imagen FROM nu_entrenamientos_imagenes WHERE id = :id";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':id', $id_imagen);
    $stmt->execute();
    
    return $stmt->fetch(PDO::FETCH_ASSOC);
}

// Función para eliminar imagen de un entrenamiento
function delete_entrenamiento_image($db, $id_imagen) {
    $query = "DELETE FROM nu_entrenamientos_imagenes WHERE id = :id";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':id', $id_imagen);
    
    if ($stmt->execute()) {
        return array('success' => true);
    }
    
    return array('success' => false, 'message' => 'Error al eliminar la imagen');
}


function update_entrenamiento($db, $codigo, $data) {
    $query = "UPDATE nu_entrenamientos SET 
              actividad = :actividad,
              descripcion_actividad = :descripcion_actividad,
              fecha = :fecha,
              duracion_horas = :duracion_horas,
              duracion_minutos = :duracion_minutos,
              duracion_kilometros = :duracion_kilometros,
              nivel_esfuerzo = :nivel_esfuerzo,
              notas = :notas,
              vueltas = :vueltas,
              codigo_plan_fit = :codigo_plan_fit
              WHERE codigo = :codigo";
    
    $stmt = $db->prepare($query);
    
    $stmt->bindParam(':codigo', $codigo);
    $stmt->bindParam(':actividad', $data['actividad']);
    $stmt->bindParam(':descripcion_actividad', $data['descripcion_actividad']);
    $stmt->bindParam(':fecha', $data['fecha']);
    $stmt->bindParam(':duracion_horas', $data['duracion_horas']);
    $stmt->bindParam(':duracion_minutos', $data['duracion_minutos']);
    $stmt->bindParam(':duracion_kilometros', $data['duracion_kilometros']);
    $stmt->bindParam(':nivel_esfuerzo', $data['nivel_esfuerzo']);
    $stmt->bindParam(':notas', $data['notas']);
    $stmt->bindParam(':vueltas', $data['vueltas']);
    $stmt->bindParam(':codigo_plan_fit', $data['codigo_plan_fit']);
    
    if ($stmt->execute()) {
        return array('success' => true);
    }
    
    return array('success' => false, 'message' => 'Error al actualizar el entrenamiento: ' . implode(', ', $stmt->errorInfo()));
}

// Función para eliminar un entrenamiento
function delete_entrenamiento($db, $codigo) {
    $query = "DELETE FROM nu_entrenamientos WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    
    if ($stmt->execute()) {
        return array('success' => true);
    }
    
    return array('success' => false, 'message' => 'Error al eliminar el entrenamiento');
}

// Función para obtener estadísticas semanales
function get_estadisticas_semanales($db, $codigo_paciente) {
    $query = "SELECT 
              DATE(fecha) as fecha,
              COUNT(*) as total_entrenamientos,
              SUM(duracion_horas * 60 + duracion_minutos) as minutos_totales,
              AVG(nivel_esfuerzo) as esfuerzo_promedio
              FROM nu_entrenamientos
              WHERE codigo_paciente = :codigo_paciente
              AND DATE(fecha) >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
              GROUP BY DATE(fecha)
              ORDER BY fecha DESC";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    $stmt->execute();
    
    $estadisticas = array();
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $estadisticas[] = $row;
    }
    
    return $estadisticas;
}

// Función para obtener estadísticas por actividad
function get_estadisticas_por_actividad($db, $codigo_paciente, $semanas = 4) {
    $query = "SELECT 
              actividad,
              COUNT(*) as cantidad,
              SUM(duracion_horas * 60 + duracion_minutos) as minutos_totales,
              AVG(nivel_esfuerzo) as esfuerzo_promedio
              FROM nu_entrenamientos
              WHERE codigo_paciente = :codigo_paciente
              AND DATE(fecha) >= DATE_SUB(CURDATE(), INTERVAL " . intval($semanas) . " WEEK)
              GROUP BY actividad
              ORDER BY cantidad DESC";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_paciente', $codigo_paciente);
    $stmt->execute();
    
    $estadisticas = array();
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $estadisticas[] = $row;
    }
    
    return $estadisticas;
}

// Función para obtener el total de actividades con paciente y plan
function get_total_actividades_con_plan($db) {
    $query = "SELECT COUNT(*) as total 
              FROM nu_entrenamientos e
              INNER JOIN usuario u ON e.codusuario = u.codigo
              WHERE u.codigo_paciente IS NOT NULL
              AND e.codigo_plan_fit IS NOT NULL
              AND e.codigo_plan_fit <> 0";
    
    $stmt = $db->prepare($query);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    
    return array('total' => intval($row['total']));
}

// Función para obtener listado de actividades con paciente y plan
function get_actividades_con_plan($db) {
    $query = "SELECT 
              e.*,
              p.nombre as nombre_paciente
              FROM nu_entrenamientos e
              INNER JOIN usuario u ON e.codusuario = u.codigo
              INNER JOIN nu_paciente p ON u.codigo_paciente = p.codigo
              WHERE u.codigo_paciente IS NOT NULL
              AND e.codigo_plan_fit IS NOT NULL
              AND e.codigo_plan_fit <> 0
              ORDER BY e.fecha DESC";
    
    $stmt = $db->prepare($query);
    $stmt->execute();
    
    $actividades = array();
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $actividades[] = $row;
    }
    
    return $actividades;
}

// Procesar la solicitud
$action = $_GET['action'] ?? null;
$paciente = $_GET['paciente'] ?? null;

switch ($action) {
    case 'get_entrenamientos':
        if (!$paciente) {
            http_response_code(400);
            echo json_encode(array('message' => 'Parámetro paciente requerido'));
            exit();
        }
        
        $entrenamientos = get_entrenamientos($db, $paciente);
        http_response_code(200);
        echo json_encode($entrenamientos);
        break;
    case 'get_pacientes_plan_fit_actividades':
        if ($user['tipo'] !== 'Nutricionista' && $user['tipo'] !== 'Administrador') {
            http_response_code(403);
            echo json_encode(array('message' => 'No autorizado'));
            exit();
        }

        $items = get_pacientes_con_actividades_plan_fit($db);
        http_response_code(200);
        echo json_encode($items);
        break;

    case 'get_entrenamientos_plan_fit_paciente':
        if ($user['tipo'] !== 'Nutricionista' && $user['tipo'] !== 'Administrador') {
            http_response_code(403);
            echo json_encode(array('message' => 'No autorizado'));
            exit();
        }

        $codigo_paciente = $_GET['paciente'] ?? null;
        $validado_param = $_GET['validado'] ?? null;
        $solo_no_validados = $validado_param !== null && $validado_param === '0';
        if (!$codigo_paciente) {
            http_response_code(400);
            echo json_encode(array('message' => 'Parámetro paciente requerido'));
            exit();
        }

        $items = get_entrenamientos_plan_fit_paciente($db, $codigo_paciente, $solo_no_validados);
        http_response_code(200);
        echo json_encode($items);
        break;
    case 'validate_entrenamiento':
        if ($method != 'POST') {
            http_response_code(405);
            echo json_encode(array('message' => 'Método POST requerido'));
            exit();
        }

        if ($user['tipo'] !== 'Nutricionista' && $user['tipo'] !== 'Administrador') {
            http_response_code(403);
            echo json_encode(array('message' => 'No autorizado'));
            exit();
        }

        $codigo = $_GET['codigo'] ?? null;
        if (!$codigo) {
            http_response_code(400);
            echo json_encode(array('message' => 'Parámetro codigo requerido'));
            exit();
        }

        $query = "UPDATE nu_entrenamientos
                  SET validado = 1,
                      validado_fecha = NOW(),
                      validado_usuario = :validado_usuario
                  WHERE codigo = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigo', $codigo);
        $stmt->bindParam(':validado_usuario', $user['codigo']);

        if ($stmt->execute()) {
            http_response_code(200);
            echo json_encode(array('success' => true));
        } else {
            http_response_code(500);
            echo json_encode(array('message' => 'Error al validar entrenamiento'));
        }
        break;
        
    case 'get_entrenamientos_rango':
        if (!$paciente) {
            http_response_code(400);
            echo json_encode(array('message' => 'Parámetro paciente requerido'));
            exit();
        }
        
        $fecha_inicio = $_GET['fecha_inicio'] ?? null;
        $fecha_fin = $_GET['fecha_fin'] ?? null;
        
        if (!$fecha_inicio || !$fecha_fin) {
            http_response_code(400);
            echo json_encode(array('message' => 'Parámetros fecha_inicio y fecha_fin requeridos'));
            exit();
        }
        
        $entrenamientos = get_entrenamientos_por_rango($db, $paciente, $fecha_inicio, $fecha_fin);
        http_response_code(200);
        echo json_encode($entrenamientos);
        break;
        
    case 'get_entrenamiento':
        $codigo = $_GET['codigo'] ?? null;
        
        if (!$codigo) {
            http_response_code(400);
            echo json_encode(array('message' => 'Parámetro codigo requerido'));
            exit();
        }
        
        $entrenamiento = get_entrenamiento($db, $codigo);
        
        if ($entrenamiento) {
            http_response_code(200);
            echo json_encode($entrenamiento);
        } else {
            http_response_code(404);
            echo json_encode(array('message' => 'Entrenamiento no encontrado'));
        }
        break;
        
    case 'create_entrenamiento':
        if ($method != 'POST') {
            http_response_code(405);
            echo json_encode(array('message' => 'Método POST requerido'));
            exit();
        }
        
        $data = json_decode(file_get_contents("php://input"), true);
        
        if (!$data['codigo_paciente'] || !$data['actividad'] || !$data['fecha']) {
            http_response_code(400);
            echo json_encode(array('message' => 'Campos requeridos: codigo_paciente, actividad, fecha'));
            exit();
        }
        
        // Extraer fotos del data antes de crear el entrenamiento
        $fotos = $data['fotos'] ?? null;
        unset($data['fotos']);
        
        $result = create_entrenamiento($db, $data);
        
        if ($result['success']) {
            // Guardar imágenes si existen
            if (!empty($fotos)) {
                save_entrenamiento_images($db, $result['codigo'], $fotos);
            }
            http_response_code(201);
            echo json_encode($result);
        } else {
            http_response_code(500);
            echo json_encode($result);
        }
        break;
        
    case 'update_entrenamiento':
        if ($method != 'PUT') {
            http_response_code(405);
            echo json_encode(array('message' => 'Método PUT requerido'));
            exit();
        }
        
        $codigo = $_GET['codigo'] ?? null;
        $data = json_decode(file_get_contents("php://input"), true);
        
        if (!$codigo) {
            http_response_code(400);
            echo json_encode(array('message' => 'Parámetro codigo requerido'));
            exit();
        }
        
        // Extraer fotos del data antes de actualizar el entrenamiento
        $fotos = $data['fotos'] ?? null;
        unset($data['fotos']);
        
        $result = update_entrenamiento($db, $codigo, $data);
        
        if ($result['success']) {
            // Guardar nuevas imágenes si existen
            if (!empty($fotos)) {
                save_entrenamiento_images($db, $codigo, $fotos);
            }
            http_response_code(200);
            echo json_encode($result);
        } else {
            http_response_code(500);
            echo json_encode($result);
        }
        break;
        
    case 'delete_entrenamiento':
        if ($method != 'DELETE') {
            http_response_code(405);
            echo json_encode(array('message' => 'Método DELETE requerido'));
            exit();
        }
        
        $codigo = $_GET['codigo'] ?? null;
        
        if (!$codigo) {
            http_response_code(400);
            echo json_encode(array('message' => 'Parámetro codigo requerido'));
            exit();
        }
        
        $result = delete_entrenamiento($db, $codigo);
        
        if ($result['success']) {
            http_response_code(200);
            echo json_encode($result);
        } else {
            http_response_code(500);
            echo json_encode($result);
        }
        break;
        
    case 'get_estadisticas_semanales':
        if (!$paciente) {
            http_response_code(400);
            echo json_encode(array('message' => 'Parámetro paciente requerido'));
            exit();
        }
        
        $estadisticas = get_estadisticas_semanales($db, $paciente);
        http_response_code(200);
        echo json_encode($estadisticas);
        break;
        
    case 'get_estadisticas_por_actividad':
        if (!$paciente) {
            http_response_code(400);
            echo json_encode(array('message' => 'Parámetro paciente requerido'));
            exit();
        }
        
        $semanas = $_GET['semanas'] ?? 4;
        $estadisticas = get_estadisticas_por_actividad($db, $paciente, $semanas);
        http_response_code(200);
        echo json_encode($estadisticas);
        break;
        
    case 'get_imagenes_entrenamiento':
        $codigo = $_GET['codigo'] ?? null;
        
        if (!$codigo) {
            http_response_code(400);
            echo json_encode(array('message' => 'Parámetro codigo requerido'));
            exit();
        }
        
        // Obtener IDs de imágenes
        $imagenes = get_entrenamiento_images($db, $codigo);
        $imagenesConBase64 = array();
        
        foreach ($imagenes as $imagen) {
            $imagenData = get_entrenamiento_image($db, $imagen['id']);
            if ($imagenData) {
                $imagenesConBase64[] = array(
                    'id' => $imagen['id'],
                    'imagen' => base64_encode($imagenData['imagen']),
                    'tipo' => $imagenData['tipo_imagen'],
                    'fecha' => $imagen['fecha_creacion']
                );
            }
        }
        
        http_response_code(200);
        echo json_encode($imagenesConBase64);
        break;
        
    case 'delete_imagen_entrenamiento':
        if ($method != 'DELETE') {
            http_response_code(405);
            echo json_encode(array('message' => 'Método DELETE requerido'));
            exit();
        }
        
        $id_imagen = $_GET['id_imagen'] ?? null;
        
        if (!$id_imagen) {
            http_response_code(400);
            echo json_encode(array('message' => 'Parámetro id_imagen requerido'));
            exit();
        }
        
        $result = delete_entrenamiento_image($db, $id_imagen);
        
        if ($result['success']) {
            http_response_code(200);
            echo json_encode($result);
        } else {
            http_response_code(500);
            echo json_encode($result);
        }
        break;

    case 'total_actividades_con_plan':
        if ($user['tipo'] !== 'Nutricionista' && $user['tipo'] !== 'Administrador') {
            http_response_code(403);
            echo json_encode(array('message' => 'No autorizado'));
            exit();
        }

        $total = get_total_actividades_con_plan($db);
        http_response_code(200);
        echo json_encode($total);
        break;

    case 'get_actividades_con_plan':
        if ($user['tipo'] !== 'Nutricionista' && $user['tipo'] !== 'Administrador') {
            http_response_code(403);
            echo json_encode(array('message' => 'No autorizado'));
            exit();
        }

        $actividades = get_actividades_con_plan($db);
        http_response_code(200);
        echo json_encode($actividades);
        break;
        
    default:
        http_response_code(400);
        echo json_encode(array('message' => 'Acción no reconocida'));
        break;
}
?>
