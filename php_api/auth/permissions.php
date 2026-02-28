<?php
/**
 * Permission Manager
 * Gestiona los permisos según el tipo de usuario
 */

class PermissionManager {
    const TYPE_GUEST = 'Guest';
    const TYPE_USER_NO_PATIENT = 'Usuario';
    const TYPE_USER_WITH_PATIENT = 'Paciente';
    const TYPE_NUTRITIONIST = 'Nutricionista';
    const TYPE_ADMIN = 'Administrador';
    
    /**
     * Define qué puede hacer cada tipo de usuario
     */
    private static $permissions = array(
        self::TYPE_GUEST => array(
            'consejos' => true,
            'contacto' => true,
            'recetas' => true,
            'pacientes' => false,
            'planes_nutricionales' => false,
            'planes_fit' => false,
            'lista_compra' => false,
            'entrenamientos' => false,
            'mediciones' => false,
            'citas' => false,
            'revisiones' => false,
            'entrevistas' => false,
            'entrevistas_fit' => false,
            'sesiones' => false,
            'cobros' => false,
            'usuarios' => false,
            'clientes' => false,
            'parametros' => false,
            'totales' => false,
        ),
        self::TYPE_USER_NO_PATIENT => array(
            'consejos' => true,
            'contacto' => true,
            'recetas' => true,
            'pacientes' => false,
            'planes_nutricionales' => false,
            'planes_fit' => false,
            'lista_compra' => true,
            'entrenamientos' => true,
            'mediciones' => true,
            'citas' => false,
            'revisiones' => false,
            'entrevistas' => false,
            'entrevistas_fit' => false,
            'sesiones' => true,
            'cobros' => false,
            'usuarios' => false,
            'clientes' => false,
            'parametros' => false,
            'totales' => false,
        ),
        self::TYPE_USER_WITH_PATIENT => array(
            'consejos' => true,
            'contacto' => true,
            'recetas' => true,
            'pacientes' => false,
            'planes_nutricionales' => true,
            'planes_fit' => true,
            'lista_compra' => true,
            'entrenamientos' => true,
            'mediciones' => true,
            'citas' => true,
            'revisiones' => true,
            'entrevistas' => true,
            'entrevistas_fit' => true,
            'sesiones' => true,
            'cobros' => true,
            'usuarios' => false,
            'clientes' => false,
            'parametros' => false,
            'totales' => false,
        ),
        self::TYPE_NUTRITIONIST => array(
            'consejos' => true,
            'contacto' => true,
            'recetas' => true,
            'pacientes' => true,
            'planes_nutricionales' => true,
            'planes_fit' => true,
            'lista_compra' => true,
            'entrenamientos' => true,
            'mediciones' => true,
            'citas' => true,
            'revisiones' => true,
            'entrevistas' => true,
            'entrevistas_fit' => true,
            'sesiones' => true,
            'cobros' => true,
            'usuarios' => true,
            'clientes' => true,
            'parametros' => true,
            'totales' => true,
        ),
        self::TYPE_ADMIN => array(
            'consejos' => true,
            'contacto' => true,
            'recetas' => true,
            'pacientes' => true,
            'planes_nutricionales' => true,
            'planes_fit' => true,
            'lista_compra' => true,
            'entrenamientos' => true,
            'mediciones' => true,
            'citas' => true,
            'revisiones' => true,
            'entrevistas' => true,
            'entrevistas_fit' => true,
            'sesiones' => true,
            'cobros' => true,
            'usuarios' => true,
            'clientes' => true,
            'parametros' => true,
            'totales' => true,
        ),
    );
    
    /**
     * Valida si un usuario tiene permiso para acceder a un recurso
     */
    public static function checkPermission($user, $resource) {
        if ($user['es_guest'] ?? false) {
            $tipo = self::TYPE_GUEST;
        } elseif ($user['administrador'] == 'S') {
            $tipo = self::TYPE_ADMIN;
        } elseif (!empty($user['codigo_paciente'])) {
            $tipo = self::TYPE_USER_WITH_PATIENT;
        } else {
            $tipo = self::TYPE_USER_NO_PATIENT;
        }
        
        if (!isset(self::$permissions[$tipo][$resource])) {
            http_response_code(403);
            echo json_encode(array(
                "error" => "Recurso no reconocido",
                "code" => "UNKNOWN_RESOURCE"
            ));
            exit();
        }
        
        if (!self::$permissions[$tipo][$resource]) {
            http_response_code(403);
            echo json_encode(array(
                "error" => "No tienes permiso para acceder a este recurso",
                "code" => "PERMISSION_DENIED",
                "user_type" => $tipo,
                "required_type" => "Nutricionista o administrador"
            ));
            exit();
        }
        
        return true;
    }
    
    /**
     * Obtiene el tipo de usuario basado en su información
     */
    public static function getUserType($user) {
        if ($user['es_guest'] ?? false) {
            return self::TYPE_GUEST;
        } elseif ($user['administrador'] == 'S') {
            return self::TYPE_ADMIN;
        } elseif (!empty($user['codigo_paciente'])) {
            return self::TYPE_USER_WITH_PATIENT;
        } else {
            return self::TYPE_USER_NO_PATIENT;
        }
    }
    
    /**
     * Verifica si es administrador/nutricionista
     */
    public static function isAdmin($user) {
        return ($user['administrador'] ?? 'N') == 'S';
    }
    
    /**
     * Verifica si es usuario guest
     */
    public static function isGuest($user) {
        return $user['es_guest'] ?? false;
    }
    
    /**
     * Verifica si tiene paciente asociado
     */
    public static function hasPatient($user) {
        return !empty($user['codigo_paciente']);
    }
}
?>
