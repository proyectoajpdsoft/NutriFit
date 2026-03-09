<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/permissions.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

// Validar token (solo usuarios registrados)
$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'sesiones');

// GET: Obtener sesiones del usuario
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $codigo_usuario = isset($_GET['codigo_usuario']) ? $_GET['codigo_usuario'] : null;
    $codigo_usuario_auth = intval($user['codigo'] ?? 0);
    $is_admin = (($user['administrador'] ?? 'N') === 'S');
    $is_nutri = strtolower(trim((string)($user['tipo'] ?? ''))) === 'nutricionista';

    if (empty($codigo_usuario)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta codigo_usuario."));
        exit();
    }

    $codigo_usuario = intval($codigo_usuario);

    if ($codigo_usuario_auth <= 0) {
        http_response_code(401);
        echo json_encode(array("message" => "Usuario inválido."));
        exit();
    }

    // LOPDGDD/RGPD: usuario normal solo puede consultar sus propias sesiones.
    if (!$is_admin && !$is_nutri && $codigo_usuario !== $codigo_usuario_auth) {
        http_response_code(403);
        echo json_encode(array("message" => "No tienes permiso para consultar sesiones de otro usuario."));
        exit();
    }

    // Obtener todas las sesiones del usuario ordenadas por fecha y hora descendente
    $query = "SELECT id, codigousuario, fecha, hora, estado, ip_local, ip_publica, tipo
              FROM sesion 
              WHERE codigousuario = :codigo_usuario 
              ORDER BY fecha DESC, hora DESC";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_usuario', $codigo_usuario);
    $stmt->execute();

    if ($stmt->rowCount() > 0) {
        $sesiones = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Separar sesiones exitosas y fallidas
        $sesiones_exitosas = array();
        $sesiones_fallidas = array();
        $total_exitosas = 0;
        $total_fallidas = 0;

        foreach ($sesiones as $sesion) {
            if ($sesion['estado'] === 'OK') {
                $sesiones_exitosas[] = $sesion;
                $total_exitosas++;
            } else {
                $sesiones_fallidas[] = $sesion;
                $total_fallidas++;
            }
        }

        // Obtener las 2 últimas sesiones exitosas
        $ultimas_sesiones_exitosas = array_slice($sesiones_exitosas, 0, 2);
        
        // Obtener los 2 últimos intentos fallidos
        $ultimos_intentos_fallidos = array_slice($sesiones_fallidas, 0, 2);

        http_response_code(200);
        echo json_encode(array(
            "ultimas_sesiones_exitosas" => $ultimas_sesiones_exitosas,
            "ultimos_intentos_fallidos" => $ultimos_intentos_fallidos,
            "total_sesiones" => count($sesiones),
            "total_exitosas" => $total_exitosas,
            "total_fallidas" => $total_fallidas,
            "todas_sesiones" => $sesiones
        ));
    } else {
        http_response_code(404);
        echo json_encode(array("message" => "No hay sesiones registradas para este usuario."));
    }
} else {
    http_response_code(405);
    echo json_encode(array("message" => "Método no permitido."));
}
?>
