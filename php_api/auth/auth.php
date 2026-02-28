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

function validate_token($db, $token) {
    if (!$token) {
        return false;
    }

    $query = "SELECT codigo, tipo, codigo_paciente FROM usuario WHERE token = :token AND (token_expiracion IS NULL OR token_expiracion > NOW())";
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