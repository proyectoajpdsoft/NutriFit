<?php
/**
 * Sistema de autenticación con validación de token por tipo de usuario
 * Incluye expiración parametrizada según tipo (Nutricionista, Paciente, Usuario, Invitado)
 */

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/token_expiration_config.php';

/**
 * Obtener token del header Authorization
 */
function get_auth_token() {
    $headers = apache_request_headers();
    if (isset($headers['Authorization'])) {
        // Formato esperado: "Bearer <token>"
        if (preg_match('/Bearer\s(\S+)/', $headers['Authorization'], $matches)) {
            return $matches[1];
        }
    }
    return null;
}

/**
 * Obtener parámetro de expiración según tipo de usuario
 */
function get_token_expiration_hours($db, $tipo) {
    $tipo_normalizado = strtolower(trim((string) $tipo));

    if ($tipo_normalizado === 'invitado' || $tipo_normalizado === 'guest') {
        return get_guest_token_expiration_hours($db);
    }

    if ($tipo_normalizado === 'paciente') {
        return get_token_hours_from_param($db, 'horas_caducidad_token_paciente', 720);
    }

    if ($tipo_normalizado === 'nutricionista') {
        return get_token_hours_from_param($db, 'horas_caducidad_token_nutricionista', 504);
    }

    return get_token_hours_from_param($db, 'horas_caducidad_token_usuario', 1440);
}

/**
 * Validar token con expiración parametrizada
 */
function validate_token_with_expiration($db, $token) {
    if (!$token) {
        return [
            'valid' => false,
            'error' => 'Token no proporcionado',
            'code' => 'TOKEN_MISSING'
        ];
    }

    try {
        // Buscar sesión activa con el token
        $stmt = $db->prepare("
            SELECT s.codigo, s.codigo_usuario, s.token, s.fecha_creacion, s.tipo_usuario, s.activo,
                   u.nick, u.tipo, u.codigo_paciente, u.administrador
            FROM sesiones s
            INNER JOIN usuarios u ON s.codigo_usuario = u.codigo
            WHERE s.token = :token
            LIMIT 1
        ");
        $stmt->bindParam(':token', $token);
        $stmt->execute();
        
        if ($stmt->rowCount() === 0) {
            return [
                'valid' => false,
                'error' => 'Token no encontrado',
                'code' => 'TOKEN_NOT_FOUND'
            ];
        }
        
        $session = $stmt->fetch(PDO::FETCH_ASSOC);
        
        // Verificar que la sesión esté activa
        if ($session['activo'] !== 'S') {
            return [
                'valid' => false,
                'error' => 'Token inválido o expirado',
                'code' => 'INVALID_TOKEN'
            ];
        }
        
        // Verificar expiración según tipo de usuario
        $tipo_usuario = $session['tipo_usuario'] ?? $session['tipo'];
        $horas_validez = get_token_expiration_hours($db, $tipo_usuario);
        
        // Invitados no tienen expiración
        if ($tipo_usuario === 'Invitado' || $horas_validez === 0) {
            return [
                'valid' => true,
                'user' => [
                    'codigo' => $session['codigo_usuario'],
                    'nick' => $session['nick'],
                    'tipo' => $session['tipo'],
                    'codigo_paciente' => $session['codigo_paciente'],
                    'administrador' => $session['administrador']
                ]
            ];
        }
        
        // Calcular fecha de expiración
        $fecha_creacion = new DateTime($session['fecha_creacion']);
        $fecha_expiracion = clone $fecha_creacion;
        $fecha_expiracion->modify("+$horas_validez hours");
        $ahora = new DateTime();
        
        // Verificar si ha expirado
        if ($ahora > $fecha_expiracion) {
            // Desactivar el token expirado
            $stmtDeactivate = $db->prepare("
                UPDATE sesiones 
                SET activo = 'N', fecha_cierre = NOW() 
                WHERE token = :token
            ");
            $stmtDeactivate->bindParam(':token', $token);
            $stmtDeactivate->execute();
            
            return [
                'valid' => false,
                'error' => 'Token inválido o expirado',
                'code' => 'INVALID_TOKEN'
            ];
        }
        
        // Token válido
        return [
            'valid' => true,
            'user' => [
                'codigo' => $session['codigo_usuario'],
                'nick' => $session['nick'],
                'tipo' => $session['tipo'],
                'codigo_paciente' => $session['codigo_paciente'],
                'administrador' => $session['administrador']
            ]
        ];
        
    } catch (PDOException $e) {
        return [
            'valid' => false,
            'error' => 'Error al validar token: ' . $e->getMessage(),
            'code' => 'DB_ERROR'
        ];
    }
}

/**
 * Función principal de verificación de token
 * Retorna el usuario si el token es válido, o termina la ejecución con error 401
 */
function verificar_token() {
    $token = get_auth_token();
    $database = new Database();
    $db = $database->getConnection();
    
    $result = validate_token_with_expiration($db, $token);
    
    if (!$result['valid']) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'error' => $result['error'],
            'code' => $result['code']
        ]);
        exit();
    }
    
    return $result['user'];
}

/**
 * Obtener información del usuario autenticado sin terminar la ejecución
 */
function get_authenticated_user() {
    $token = get_auth_token();
    if (!$token) {
        return null;
    }
    
    $database = new Database();
    $db = $database->getConnection();
    
    $result = validate_token_with_expiration($db, $token);
    
    return $result['valid'] ? $result['user'] : null;
}
?>
