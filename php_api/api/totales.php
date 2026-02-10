<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/permissions.php';

$database = new Database();
$db = $database->getConnection();

// Validar token (solo usuarios registrados)
$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'totales');

try {
    // Obtener totales de todos los pacientes
    $query = "
        SELECT 
            p.codigo,
            p.nombre,
            COALESCE(COUNT(DISTINCT pn.codigo), 0) as total_planes,
            COALESCE(COUNT(DISTINCT pe.codigo), 0) as total_entrevistas,
            COALESCE(COUNT(DISTINCT pef.codigo), 0) as total_entrevistas_fit,
            COALESCE(COUNT(DISTINCT pnf.codigo), 0) as total_planes_fit,
            COALESCE(COUNT(DISTINCT pr.codigo), 0) as total_revisiones,
            COALESCE(COUNT(DISTINCT m.codigo), 0) as total_mediciones
        FROM nu_paciente p
        LEFT JOIN nu_plan_nutricional pn ON p.codigo = pn.codigo_paciente
        LEFT JOIN nu_paciente_entrevista pe ON p.codigo = pe.codigo_paciente
        LEFT JOIN nu_paciente_entrevista_fit pef ON p.codigo = pef.codigo_paciente
        LEFT JOIN nu_plan_nutricional_fit pnf ON p.codigo = pnf.codigo_paciente
        LEFT JOIN nu_paciente_revision pr ON p.codigo = pr.codigo_paciente
        LEFT JOIN nu_paciente_medicion m ON p.codigo = m.codigo_paciente
        GROUP BY p.codigo, p.nombre
        ORDER BY p.nombre
    ";
    
    $stmt = $db->prepare($query);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    ob_clean();
    http_response_code(200);
    echo json_encode($items);
} catch (Throwable $e) {
    http_response_code(500);
    ob_clean();
    echo json_encode([
        "message" => "Error fatal en el servidor.",
        "error_details" => $e->getMessage(),
        "file" => $e->getFile(),
        "line" => $e->getLine()
    ]);
}
?>
