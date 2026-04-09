<?php
// Este fichero se incluirá en cada endpoint que requiera autenticación.

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

function get_usuario_columns_map_auth($db) {
    $columns = array();
    try {
        $stmt = $db->query("SHOW COLUMNS FROM usuario");
        $rows = $stmt ? $stmt->fetchAll(PDO::FETCH_ASSOC) : array();
        foreach ($rows as $row) {
            $field = strtolower(trim((string)($row['Field'] ?? '')));
            if ($field !== '') {
                $columns[$field] = true;
            }
        }
    } catch (Throwable $e) {
        $columns = array();
    }
    return $columns;
}

function validate_token($db, $token) {
    if (!$token) {
        return false;
    }

    $columns = get_usuario_columns_map_auth($db);
    $query = "SELECT codigo, tipo, codigo_paciente FROM usuario WHERE token = :token AND (token_expiracion IS NULL OR token_expiracion > NOW())";
    if (isset($columns['activo'])) {
        $query .= " AND activo = 'S'";
    }
    if (isset($columns['accesoweb'])) {
        $query .= " AND accesoweb = 'S'";
    }
    if (isset($columns['eliminado'])) {
        $query .= " AND COALESCE(eliminado, 'N') <> 'S'";
    }
    $stmt = $db->prepare($query);
    $stmt->bindParam(':token', $token);
    $stmt->execute();

    if ($stmt->rowCount() > 0) {
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    return false;
}

// Lógica principal de autenticación
$token = get_auth_token();
$database_auth = new Database();
$db_auth = $database_auth->getConnection();

$logged_in_user = validate_token($db_auth, $token);

if (!$logged_in_user) {
    http_response_code(401); // Unauthorized
    echo json_encode(array("message" => "Acceso denegado. Token no válido o expirado."));
    // Es importante terminar el script para que no continúe la ejecución del endpoint
    exit();
}
?>