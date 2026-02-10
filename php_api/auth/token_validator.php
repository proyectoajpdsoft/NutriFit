<?php
/**
 * Token Validator
 * Valida y decodifica tokens JWT/Bearer en todas las peticiones
 * Registra la sesión en la tabla sesion
 */

class TokenValidator {
    private $db;
    private $current_user = null;
    private $token = null;
    
    public function __construct($database) {
        $this->db = $database;
    }
    
    /**
     * Valida el token desde el header Authorization
     * @return array|false Usuario si es válido, false si no lo es
     */
    public function validateToken() {
        // Obtener token del header Authorization
        $headers = getallheaders();
        
        if (!isset($headers['Authorization']) && !isset($headers['authorization'])) {
            http_response_code(401);
            echo json_encode(array("error" => "Token no proporcionado", "code" => "NO_TOKEN"));
            exit();
        }
        
        $auth_header = $headers['Authorization'] ?? $headers['authorization'];
        
        // Esperar formato: Bearer {token}
        if (strpos($auth_header, 'Bearer ') !== 0) {
            http_response_code(401);
            echo json_encode(array("error" => "Formato de token inválido. Use: Authorization: Bearer {token}", "code" => "INVALID_FORMAT"));
            exit();
        }
        
        $this->token = substr($auth_header, 7); // Eliminar "Bearer "
        
        // Validar token en base de datos
        return $this->validateTokenInDatabase();
    }
    
    /**
     * Valida un token guest (sin usuario registrado)
     * Busca el token en la tabla guest_tokens
     */
    public function validateGuestToken() {
        $headers = getallheaders();
        
        if (!isset($headers['Authorization']) && !isset($headers['authorization'])) {
            http_response_code(401);
            echo json_encode(array("error" => "Token no proporcionado", "code" => "NO_TOKEN"));
            exit();
        }
        
        $auth_header = $headers['Authorization'] ?? $headers['authorization'];
        
        if (strpos($auth_header, 'Bearer ') !== 0) {
            http_response_code(401);
            echo json_encode(array("error" => "Formato de token inválido", "code" => "INVALID_FORMAT"));
            exit();
        }
        
        $this->token = substr($auth_header, 7);
        
        // Validar que el token existe en guest_tokens y no está expirado
        return $this->validateGuestTokenInDatabase();
    }
    
    /**
     * Valida el token guest contra la tabla guest_tokens
     */
    private function validateGuestTokenInDatabase() {
        $query = "SELECT token, fecha_expiracion, ip_publica, activo 
                  FROM guest_tokens 
                  WHERE token = :token 
                  AND fecha_expiracion > NOW() 
                  AND activo = 'S'
                  LIMIT 1";
        
        try {
            $stmt = $this->db->prepare($query);
            $stmt->bindParam(':token', $this->token);
            $stmt->execute();
            
            if ($stmt->rowCount() > 0) {
                $guest = $stmt->fetch(PDO::FETCH_ASSOC);
                
                // Registrar sesión guest
                $this->logSession(null, 'OK_GUEST');
                
                return array(
                    "codigo" => 0,
                    "tipo" => "Guest",
                    "es_guest" => true,
                    "token" => $this->token
                );
            } else {
                // Token no válido o expirado
                http_response_code(401);
                echo json_encode(array(
                    "error" => "Token guest inválido o expirado",
                    "code" => "INVALID_GUEST_TOKEN"
                ));
                exit();
            }
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(array("error" => "Error validando token guest", "details" => $e->getMessage()));
            exit();
        }
    }
    
    /**
     * Valida el token contra la base de datos
     */
    private function validateTokenInDatabase() {
        $query = "SELECT codigo, nick, tipo, administrador, codigo_paciente, token_expiracion, activo, accesoweb 
                  FROM usuario 
                  WHERE token = :token 
                  AND token_expiracion > NOW() 
                  AND activo = 'S' 
                  AND accesoweb = 'S'
                  LIMIT 1";
        
        try {
            $stmt = $this->db->prepare($query);
            $stmt->bindParam(':token', $this->token);
            $stmt->execute();
            
            if ($stmt->rowCount() > 0) {
                $user = $stmt->fetch(PDO::FETCH_ASSOC);
                $this->current_user = $user;
                
                // Registrar sesión exitosa
                $this->logSession($user['codigo'], 'OK');
                
                return array(
                    "codigo" => $user['codigo'],
                    "nick" => $user['nick'],
                    "tipo" => $user['tipo'],
                    "administrador" => $user['administrador'],
                    "codigo_paciente" => $user['codigo_paciente'],
                    "es_guest" => false,
                    "token" => $this->token
                );
            } else {
                // Token no válido o expirado
                http_response_code(401);
                echo json_encode(array(
                    "error" => "Token inválido o expirado",
                    "code" => "INVALID_TOKEN"
                ));
                exit();
            }
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(array("error" => "Error validando token", "details" => $e->getMessage()));
            exit();
        }
    }
    
    /**
     * Registra la sesión en la tabla sesion
     */
    private function logSession($codigo_usuario = null, $estado = 'OK', $codigo_ejercicio = null) {
        try {
            $query = "INSERT INTO sesion 
                      (codigousuario, fecha, hora, estado, codigoejercicio, ip_publica) 
                      VALUES (:codigousuario, CURDATE(), CURTIME(), :estado, :codigoejercicio, :ip_publica)";
            
            $stmt = $this->db->prepare($query);
            $stmt->bindParam(':codigousuario', $codigo_usuario);
            $stmt->bindParam(':estado', $estado);
            $stmt->bindParam(':codigoejercicio', $codigo_ejercicio);
            
            // Obtener IP pública
            $ip_publica = $this->getClientIP();
            $stmt->bindParam(':ip_publica', $ip_publica);
            
            $stmt->execute();
        } catch (Exception $e) {
            // No abortar si falla el logging
            error_log("Error logging session: " . $e->getMessage());
        }
    }
    
    /**
     * Obtiene la IP del cliente (pública)
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
    
    /**
     * Obtiene el usuario validado
     */
    public function getUser() {
        return $this->current_user;
    }
    
    /**
     * Obtiene el token
     */
    public function getToken() {
        return $this->token;
    }
}
?>
