<?php
/**
 * Extensiones para el endpoint de usuarios
 * Endpoints adicionales: revocar token, desactivar usuario
 */

require_once '../config/database.php';
require_once '../auth/token_validator.php';

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Manejar preflight OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Obtener datos JSON del cuerpo de la solicitud
$data = json_decode(file_get_contents('php://input'), true);
$method = $_SERVER['REQUEST_METHOD'];

// Inicializar conexion
$database = new Database();
$db = $database->getConnection();

// Verificar autenticación
$tokenValidator = new TokenValidator($db);
$user = $tokenValidator->validateToken();

// Verificar que sea administrador (Nutricionista o Administrador)
$isAdminFlag = isset($user['administrador']) && ($user['administrador'] === 'S' || $user['administrador'] === 1 || $user['administrador'] === '1');
if ($user['tipo'] !== 'Nutricionista' && $user['tipo'] !== 'Administrador' && !$isAdminFlag) {
    http_response_code(403);
    echo json_encode([
        'success' => false,
        'error' => 'No tienes permisos para realizar esta acción',
        'code' => 'FORBIDDEN'
    ]);
    exit();
}

// Manejar acciones específicas
$action = $data['action'] ?? null;

switch ($action) {
    case 'revoke_token':
        revokeUserToken($data, $db);
        break;
    
    case 'deactivate':
        deactivateUser($data, $db);
        break;
    
    default:
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error' => 'Acción no válida',
            'code' => 'INVALID_ACTION'
        ]);
        break;
}

/**
 * Revocar token de un usuario (forzar desconexión)
 */
function revokeUserToken($data, $db) {
    $codigoUsuario = $data['codigo_usuario'] ?? null;
    
    if (!$codigoUsuario) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error' => 'Falta el código de usuario'
        ]);
        return;
    }
    
    try {
        // Revocar token en la tabla usuario
        $stmt = $db->prepare("
            UPDATE usuario 
            SET token = NULL,
                token_expiracion = NULL
            WHERE codigo = :codigo_usuario
        ");
        $stmt->bindParam(':codigo_usuario', $codigoUsuario);
        $stmt->execute();
        
        http_response_code(200);
        echo json_encode([
            'success' => true,
            'message' => 'Token revocado exitosamente'
        ]);
        
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'error' => 'Error al revocar token: ' . $e->getMessage()
        ]);
    }
}

/**
 * Desactivar usuario (activo = N, accesoweb = N)
 */
function deactivateUser($data, $db) {
    $codigoUsuario = $data['codigo_usuario'] ?? null;
    
    if (!$codigoUsuario) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error' => 'Falta el código de usuario'
        ]);
        return;
    }
    
    try {
        // Desactivar usuario y revocar token
        $stmt = $db->prepare("
            UPDATE usuario 
            SET activo = 'N', 
                accesoweb = 'N',
                token = NULL,
                token_expiracion = NULL
            WHERE codigo = :codigo_usuario
        ");
        $stmt->bindParam(':codigo_usuario', $codigoUsuario);
        $stmt->execute();
        
        http_response_code(200);
        echo json_encode([
            'success' => true,
            'message' => 'Usuario desactivado exitosamente'
        ]);
        
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'error' => 'Error al desactivar usuario: ' . $e->getMessage()
        ]);
    }
}
?>
