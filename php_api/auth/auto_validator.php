<?php
/**
 * Auto Validator
 * Intenta validar primero como usuario regular, si falla intenta como guest
 * Simplifica la lógica en los endpoints
 */

class AutoValidator {
    private $db;
    private $token_validator;
    private $user_data = null;
    
    public function __construct($database) {
        $this->db = $database;
        $this->token_validator = new TokenValidator($database);
    }
    
    /**
     * Valida automáticamente: primero usuario, luego guest
     * @return array Datos del usuario o guest
     */
    public function validate() {
        // Obtener token del header
        $headers = getallheaders();
        $auth_header = $headers['Authorization'] ?? $headers['authorization'] ?? null;
        
        if (!$auth_header || strpos($auth_header, 'Bearer ') !== 0) {
            http_response_code(401);
            echo json_encode(array("error" => "Token no proporcionado o formato inválido", "code" => "NO_TOKEN"));
            exit();
        }
        
        $token = substr($auth_header, 7);
        
        // Log para debug
        error_log("AutoValidator - Validando token: " . substr($token, 0, 20) . "...");
        
        // Intentar validar como usuario regular primero
        if ($this->validateUserToken($token)) {
            error_log("AutoValidator - Token válido como usuario");
            return $this->user_data;
        }
        
        // Si falla, intentar como guest
        if ($this->validateGuestTokenDB($token)) {
            error_log("AutoValidator - Token válido como guest");
            return array(
                "codigo" => 0,
                "tipo" => "Guest",
                "es_guest" => true,
                "token" => $token
            );
        }
        
        // Si ambas fallan, retornar error
        error_log("AutoValidator - Token no válido en ninguna tabla");
        http_response_code(401);
        echo json_encode(array(
            "error" => "Token inválido o expirado",
            "code" => "INVALID_TOKEN"
        ));
        exit();
    }
    
    /**
     * Valida token de usuario contra tabla usuario
     */
    private function validateUserToken($token) {
        $query = "SELECT codigo, nick, tipo, administrador, codigo_paciente, token_expiracion, activo, accesoweb 
                  FROM usuario 
                  WHERE token = :token 
                  AND token_expiracion > NOW() 
                  AND activo = 'S' 
                  AND accesoweb = 'S'
                  LIMIT 1";
        
        try {
            $stmt = $this->db->prepare($query);
            $stmt->bindParam(':token', $token, PDO::PARAM_STR);
            $stmt->execute();
            
            if ($stmt->rowCount() > 0) {
                $user = $stmt->fetch(PDO::FETCH_ASSOC);
                $this->user_data = array(
                    "codigo" => $user['codigo'],
                    "nick" => $user['nick'],
                    "tipo" => $user['tipo'],
                    "administrador" => $user['administrador'],
                    "codigo_paciente" => $user['codigo_paciente'],
                    "es_guest" => false,
                    "token" => $token
                );
                
                // Registrar sesión
                $this->logSession($user['codigo'], 'OK');
                return true;
            }
        } catch (Exception $e) {
            error_log("Error validating user token: " . $e->getMessage());
        }
        
        return false;
    }
    
    /**
     * Valida token guest contra tabla guest_tokens
     */
    private function validateGuestTokenDB($token) {
        $query = "SELECT token, fecha_expiracion, ip_publica, activo 
                  FROM guest_tokens 
                  WHERE token = :token 
                  AND fecha_expiracion > NOW() 
                  AND activo = 'S'
                  LIMIT 1";
        
        try {
            $stmt = $this->db->prepare($query);
            $stmt->bindParam(':token', $token, PDO::PARAM_STR);
            $stmt->execute();
            
            if ($stmt->rowCount() > 0) {
                // Registrar sesión guest
                $this->logSession(null, 'OK_GUEST');
                return true;
            }
        } catch (Exception $e) {
            error_log("Error validating guest token: " . $e->getMessage());
        }
        
        return false;
    }
    
    /**
     * Registra la sesión en tabla sesion
     */
    private function logSession($codigo_usuario = null, $estado = 'OK') {
        try {
            $query = "INSERT INTO sesion 
                      (codigousuario, fecha, hora, estado, ip_publica) 
                      VALUES (:codigousuario, CURDATE(), CURTIME(), :estado, :ip_publica)";
            
            $stmt = $this->db->prepare($query);
            $stmt->bindParam(':codigousuario', $codigo_usuario);
            $stmt->bindParam(':estado', $estado);
            
            $ip_publica = $this->getClientIP();
            $stmt->bindParam(':ip_publica', $ip_publica);
            
            $stmt->execute();
        } catch (Exception $e) {
            error_log("Error logging session: " . $e->getMessage());
        }
    }
    
    /**
     * Obtiene la IP del cliente
     */
    private function getClientIP() {
        if (!empty($_SERVER['HTTP_CLIENT_IP'])) {
            return $_SERVER['HTTP_CLIENT_IP'];
        } elseif (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
            return explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'])[0];
        } else {
            return $_SERVER['REMOTE_ADDR'] ?? 'UNKNOWN';
        }
    }
}
?>
