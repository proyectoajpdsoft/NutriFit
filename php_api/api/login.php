<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/permissions.php';
include_once '../auth/token_expiration_config.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

if (empty($data->nick) || empty($data->contrasena)) {
    http_response_code(400);
    echo json_encode(array("message" => "Faltan el usuario o la contraseña."));
    exit();
}

$query = "SELECT codigo, nick, contrasena, administrador, tipo, activo, accesoweb, codigo_paciente FROM usuario WHERE nick = :nick LIMIT 0,1";
$stmt = $db->prepare($query);
$stmt->bindParam(':nick', $data->nick);
$stmt->execute();

$num = $stmt->rowCount();

if ($num > 0) {
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    $codigo = $row['codigo'];
    $nick = $row['nick'];
    $contrasena_hash = $row['contrasena'];
    $administrador = $row['administrador'];
    $tipo = $row['tipo'];
    $activo = $row['activo'];
    $accesoweb = $row['accesoweb'];
    $codigo_paciente = $row['codigo_paciente'];

    // Verificar contraseña (¡IMPORTANTE! Deberías usar password_hash() y password_verify())
    // Por simplicidad en este ejemplo, se compara texto plano. ¡CAMBIAR EN PRODUCCIÓN!
    if (password_verify($data->contrasena, $contrasena_hash)) {

        if ($activo != 'S' || $accesoweb != 'S') {
            http_response_code(403); // Forbidden
            echo json_encode(array("message" => "Acceso denegado. El usuario no está activo."));
            log_session($db, $codigo, 'Error_Inactivo');
            exit();
        }

        // Generar un token seguro
        $token = bin2hex(random_bytes(32));
        $hours_to_expire = get_registered_user_token_expiration_hours(
            $db,
            $tipo,
            $codigo_paciente
        );
        $token_expiracion = build_token_expiration_datetime_or_null($hours_to_expire);

        // Guardar el token en la base de datos
        $update_query = "UPDATE usuario SET token = :token, token_expiracion = :token_expiracion WHERE codigo = :codigo";
        $update_stmt = $db->prepare($update_query);
        $update_stmt->bindParam(':token', $token);
        $update_stmt->bindParam(':token_expiracion', $token_expiracion);
        $update_stmt->bindParam(':codigo', $codigo);

        if ($update_stmt->execute()) {
            log_session($db, $codigo, 'OK', $data->dispositivo_tipo ?? null);
            http_response_code(200);
            echo json_encode(array(
                "message" => "Inicio de sesión correcto.",
                "token" => $token,
                "token_expira_horas" => $hours_to_expire,
                "usuario" => array(
                    "codigo" => $codigo,
                    "nick" => $nick,
                    "administrador" => $administrador,
                    "tipo" => $tipo,
                    "codigo_paciente" => $codigo_paciente
                )
            ));
        } else {
            http_response_code(503);
            echo json_encode(array("message" => "No se pudo actualizar el token."));
        }
    } else {
        http_response_code(401); // Unauthorized
        echo json_encode(array(
            "message" => "Contraseña incorrecta.",
            "code" => "INVALID_PASSWORD"
        ));
        log_session($db, $codigo, 'Error_Pass', $data->dispositivo_tipo ?? null);
    }
} else {
    http_response_code(404);
    echo json_encode(array("message" => "Usuario no encontrado."));
    // Registrar intento con usuario inválido - usar código 0 o especial para usuario no encontrado
    log_session($db, 0, 'Error_Usuario_NoExiste', $data->dispositivo_tipo ?? null);
}

function log_session($db, $codigo_usuario, $estado, $tipo_dispositivo = null) {
    // Capturar IP pública percibida por el servidor
    $ip_publica = $_SERVER['REMOTE_ADDR'] ?? null;
    
    // Capturar IP local (si está disponible) - se obtiene del cliente si es enviada
    // En entornos LAN, esto puede venir del header X-Forwarded-For u otro método
    $ip_local = null;
    
    // Obtener fecha y hora actuales
    $fecha = date('Y-m-d');
    $hora = date('H:i:s');

    // Insertar en la tabla sesion con fecha, hora, IPs y tipo de dispositivo
    $query = "INSERT INTO sesion (codigousuario, fecha, hora, estado, ip_local, ip_publica, tipo)
              VALUES (:codigousuario, :fecha, :hora, :estado, :ip_local, :ip_publica, :tipo)";
    try {
        $stmt = $db->prepare($query);
        $stmt->bindParam(':codigousuario', $codigo_usuario);
        $stmt->bindParam(':fecha', $fecha);
        $stmt->bindParam(':hora', $hora);
        $stmt->bindParam(':estado', $estado);
        $stmt->bindParam(':ip_local', $ip_local);
        $stmt->bindParam(':ip_publica', $ip_publica);
        $stmt->bindParam(':tipo', $tipo_dispositivo);
        $stmt->execute();
    } catch (Exception $e) {
        // Manejo de errores silencioso para no interrumpir el login
        error_log("Error al registrar sesión: " . $e->getMessage());
    }
}
?>