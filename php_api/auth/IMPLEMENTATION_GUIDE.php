<?php
/**
 * EJEMPLO DE CÓMO IMPLEMENTAR VALIDACIÓN DE TOKENS EN ENDPOINTS
 * 
 * Instrucciones para aplicar a todos los endpoints:
 * 
 * 1. Agregar al inicio de cada archivo PHP que requiera autenticación:
 */

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Incluir las clases necesarias
include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/permissions.php';

$database = new Database();
$db = $database->getConnection();

// 2. VALIDAR TOKEN Y OBTENER USUARIO
$validator = new TokenValidator($db);
$user = $validator->validateToken();

// 3. VALIDAR PERMISOS PARA ESTE RECURSO (ejemplo: pacientes)
PermissionManager::checkPermission($user, 'pacientes');

// 4. A PARTIR DE AQUÍ, PUEDES USAR $user CON SEGURIDAD
// $user contiene:
// - codigo: ID del usuario
// - tipo: Tipo de usuario
// - administrador: 'S' o 'N'
// - codigo_paciente: ID del paciente (si existe)
// - es_guest: true/false

/*
EJEMPLO COMPLETO PARA pacientes.php:

<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
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

// Validar token
$validator = new TokenValidator($db);
$user = $validator->validateToken();

// Validar permisos - Solo nutricionistas pueden listar pacientes
PermissionManager::checkPermission($user, 'pacientes');

// Ahora proceder con la lógica del endpoint
$query = "SELECT codigo, nombre, apellidos, cedula, email FROM paciente";

if (!PermissionManager::isAdmin($user)) {
    // Si no es admin, solo puede ver sus propios datos si es paciente
    if (PermissionManager::hasPatient($user)) {
        $query .= " WHERE codigo = :codigo_paciente";
    } else {
        // No tiene permisos suficientes
        http_response_code(403);
        echo json_encode(array("error" => "No autorizado"));
        exit();
    }
}

try {
    $stmt = $db->prepare($query);
    
    if (!PermissionManager::isAdmin($user) && PermissionManager::hasPatient($user)) {
        $stmt->bindParam(':codigo_paciente', $user['codigo_paciente']);
    }
    
    $stmt->execute();
    $pacientes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    http_response_code(200);
    echo json_encode($pacientes);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(array("error" => "Error obteniendo pacientes", "details" => $e->getMessage()));
}
?>

*/
?>
