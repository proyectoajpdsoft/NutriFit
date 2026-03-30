<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, OPTIONS");
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

$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'planes_nutricionales');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(["message" => "Metodo no permitido."]);
    exit();
}

// Check that the tables exist before querying
$checkTable = $db->query("SHOW TABLES LIKE 'nu_harvard_categoria'");
if (!$checkTable || $checkTable->rowCount() === 0) {
    http_response_code(503);
    echo json_encode(["message" => "La tabla nu_harvard_categoria no existe aún. Ejecuta el SQL de creación primero."]);
    exit();
}

$stmt = $db->query(
    "SELECT codigo, nombre, descripcion, seccion_plato, es_recomendado,
            COALESCE(color_hex, '#9E9E9E') AS color_hex,
            COALESCE(icono_emoji, '') AS icono_emoji,
            orden_display
     FROM nu_harvard_categoria
     ORDER BY orden_display, codigo"
);

$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
ob_clean();
echo json_encode($rows ?? []);
?>
