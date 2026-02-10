<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once '../config/database.php';
require_once '../auth/token_validator.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

$validator = new TokenValidator($db);
$user = $validator->validateToken();

$action = $_GET['action'] ?? null;

switch ($method) {
    case 'GET':
        if ($action === 'unread_count') {
            get_unread_count($db, $user);
        } elseif ($action === 'list_conversations') {
            list_conversations($db, $user);
        } elseif ($action === 'get_messages') {
            get_messages($db, $user);
        } else {
            http_response_code(400);
            echo json_encode(["message" => "Accion no reconocida."]);
        }
        break;
    case 'POST':
        if ($action === 'send_message') {
            send_message($db, $user);
        } elseif ($action === 'mark_read') {
            mark_read($db, $user);
        } elseif ($action === 'delete_message') {
            delete_message($db, $user);
        } else {
            http_response_code(400);
            echo json_encode(["message" => "Accion no reconocida."]);
        }
        break;
    default:
        http_response_code(405);
        echo json_encode(["message" => "Metodo no permitido."]);
        break;
}

function is_nutri($user) {
    return $user['tipo'] === 'Nutricionista' || $user['tipo'] === 'Administrador';
}

function get_default_nutri_id($db) {
    $query = "SELECT codigo FROM usuario WHERE tipo = 'Nutricionista' ORDER BY codigo LIMIT 1";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($row && !empty($row['codigo'])) {
        return intval($row['codigo']);
    }

    $query = "SELECT codigo FROM usuario WHERE tipo = 'Administrador' ORDER BY codigo LIMIT 1";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($row && !empty($row['codigo'])) {
        return intval($row['codigo']);
    }

    return null;
}

function get_or_create_conversation($db, $usuario_id, $nutri_id = null) {
    $query = "SELECT id, nutricionista_id FROM chat_conversation WHERE usuario_id = :usuario_id LIMIT 1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':usuario_id', $usuario_id);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($row && !empty($row['id'])) {
        return [
            'id' => intval($row['id']),
            'nutricionista_id' => intval($row['nutricionista_id'] ?? 0)
        ];
    }

    if ($nutri_id === null) {
        return null;
    }

    $insert = $db->prepare(
        "INSERT INTO chat_conversation (usuario_id, nutricionista_id, creado_en, actualizado_en)
         VALUES (:usuario_id, :nutri_id, NOW(), NOW())"
    );
    $insert->bindParam(':usuario_id', $usuario_id);
    $insert->bindParam(':nutri_id', $nutri_id);

    if ($insert->execute()) {
        return [
            'id' => intval($db->lastInsertId()),
            'nutricionista_id' => intval($nutri_id)
        ];
    }

    return null;
}

function get_unread_count($db, $user) {
    if (is_nutri($user)) {
        $query = "SELECT COUNT(*) AS total
                  FROM chat_message m
                  INNER JOIN usuario u ON u.codigo = m.sender_id
                  WHERE m.leido = 0
                    AND m.borrado_por_receptor = 0
                    AND u.tipo NOT IN ('Nutricionista', 'Administrador')";
        $stmt = $db->prepare($query);
        $stmt->execute();
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
    } else {
        $query = "SELECT COUNT(*) AS total
                  FROM chat_message
                  WHERE receiver_id = :receiver_id
                    AND leido = 0
                    AND borrado_por_receptor = 0";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':receiver_id', $user['codigo']);
        $stmt->execute();
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
    }

    http_response_code(200);
    echo json_encode(["total" => intval($row['total'] ?? 0)]);
}

function list_conversations($db, $user) {
    if (!is_nutri($user)) {
        http_response_code(403);
        echo json_encode(["message" => "No autorizado."]);
        return;
    }

    $query = "SELECT c.id,
                     u.codigo AS usuario_id,
                     u.nombre,
                     u.nick,
                     (
                        SELECT m.cuerpo
                        FROM chat_message m
                                                WHERE m.conversation_id = c.id
                                                    AND (m.borrado_por_emisor = 0 OR m.borrado_por_receptor = 0)
                        ORDER BY m.creado_en DESC
                        LIMIT 1
                     ) AS ultimo_mensaje,
                     (
                        SELECT m.imagen_base64
                        FROM chat_message m
                                                WHERE m.conversation_id = c.id
                                                    AND (m.borrado_por_emisor = 0 OR m.borrado_por_receptor = 0)
                        ORDER BY m.creado_en DESC
                        LIMIT 1
                     ) AS ultimo_imagen,
                     (
                        SELECT m.creado_en
                        FROM chat_message m
                                                WHERE m.conversation_id = c.id
                                                    AND (m.borrado_por_emisor = 0 OR m.borrado_por_receptor = 0)
                        ORDER BY m.creado_en DESC
                        LIMIT 1
                     ) AS ultimo_fecha,
                     (
                        SELECT COUNT(*)
                        FROM chat_message m
                        WHERE m.conversation_id = c.id
                                                    AND m.sender_id = u.codigo
                                                    AND m.leido = 0
                                                    AND m.borrado_por_receptor = 0
                     ) AS no_leidos
              FROM chat_conversation c
              INNER JOIN usuario u ON u.codigo = c.usuario_id
              ORDER BY ultimo_fecha DESC, c.actualizado_en DESC";

    $stmt = $db->prepare($query);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    http_response_code(200);
    echo json_encode($items ?? []);
}

function get_messages($db, $user) {
    $nutri_id = null;
    $usuario_id = null;
    $other_user_id = $_GET['user_id'] ?? null;

    if (is_nutri($user)) {
        if (!$other_user_id) {
            http_response_code(400);
            echo json_encode(["message" => "Parametro user_id requerido."]);
            return;
        }
        $usuario_id = intval($other_user_id);
    } else {
        $usuario_id = $user['codigo'];
        $nutri_id = get_default_nutri_id($db);
        if (!$nutri_id) {
            http_response_code(404);
            echo json_encode(["message" => "Nutricionista no encontrado."]);
            return;
        }
    }

    $conversation = get_or_create_conversation($db, $usuario_id, $nutri_id);
    if (!$conversation || empty($conversation['id'])) {
        http_response_code(500);
        echo json_encode(["message" => "No se pudo crear la conversacion."]);
        return;
    }

    $conversation_id = intval($conversation['id']);

        if (is_nutri($user)) {
                $query = "SELECT id, conversation_id, sender_id, receiver_id, cuerpo, imagen_base64, imagen_mime,
                                                 leido, leido_fecha, creado_en
                                    FROM chat_message
                                    WHERE conversation_id = :conversation_id
                                        AND (borrado_por_emisor = 0 OR borrado_por_receptor = 0)
                                    ORDER BY creado_en ASC";
                $stmt = $db->prepare($query);
                $stmt->bindParam(':conversation_id', $conversation_id);
        } else {
                $query = "SELECT id, conversation_id, sender_id, receiver_id, cuerpo, imagen_base64, imagen_mime,
                                                 leido, leido_fecha, creado_en
                                    FROM chat_message
                                    WHERE conversation_id = :conversation_id
                                        AND ((sender_id = :user_id AND borrado_por_emisor = 0)
                                            OR (receiver_id = :user_id AND borrado_por_receptor = 0))
                                    ORDER BY creado_en ASC";
                $stmt = $db->prepare($query);
                $stmt->bindParam(':conversation_id', $conversation_id);
                $stmt->bindParam(':user_id', $user['codigo']);
        }
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    http_response_code(200);
    echo json_encode([
        "conversation_id" => $conversation_id,
        "items" => $items ?? []
    ]);
}

function send_message($db, $user) {
    $data = json_decode(file_get_contents("php://input"), true);
    $cuerpo = trim($data['cuerpo'] ?? '');
    $imagen_base64 = trim($data['imagen_base64'] ?? '');
    $imagen_mime = trim($data['imagen_mime'] ?? '');

    if ($cuerpo === '' && $imagen_base64 === '') {
        http_response_code(400);
        echo json_encode(["message" => "Mensaje vacio."]);
        return;
    }

    $sender_id = intval($user['codigo']);
    $receiver_id = null;
    $nutri_id = null;
    $usuario_id = null;

    if (is_nutri($user)) {
        $receiver_id = intval($data['receiver_id'] ?? 0);
        if ($receiver_id <= 0) {
            http_response_code(400);
            echo json_encode(["message" => "Receiver requerido."]);
            return;
        }
        $nutri_id = $sender_id;
        $usuario_id = $receiver_id;
    } else {
        $conversation = get_or_create_conversation($db, $sender_id, null);
        $existing_nutri_id = $conversation['nutricionista_id'] ?? null;
        $nutri_id = $existing_nutri_id ?: get_default_nutri_id($db);
        if (!$nutri_id) {
            http_response_code(404);
            echo json_encode(["message" => "Nutricionista no encontrado."]);
            return;
        }
        $receiver_id = $nutri_id;
        $usuario_id = $sender_id;
    }

    $conversation = get_or_create_conversation($db, $usuario_id, $nutri_id);
    if (!$conversation || empty($conversation['id'])) {
        http_response_code(500);
        echo json_encode(["message" => "No se pudo crear la conversacion."]);
        return;
    }

    $conversation_id = intval($conversation['id']);

    $insert = $db->prepare(
        "INSERT INTO chat_message
            (conversation_id, sender_id, receiver_id, cuerpo, imagen_base64, imagen_mime, leido, creado_en)
         VALUES
            (:conversation_id, :sender_id, :receiver_id, :cuerpo, :imagen_base64, :imagen_mime, 0, NOW())"
    );

    $cuerpo_param = $cuerpo !== '' ? $cuerpo : null;
    $imagen_param = $imagen_base64 !== '' ? $imagen_base64 : null;
    $mime_param = $imagen_mime !== '' ? $imagen_mime : null;

    $insert->bindParam(':conversation_id', $conversation_id);
    $insert->bindParam(':sender_id', $sender_id);
    $insert->bindParam(':receiver_id', $receiver_id);
    $insert->bindParam(':cuerpo', $cuerpo_param);
    $insert->bindParam(':imagen_base64', $imagen_param);
    $insert->bindParam(':imagen_mime', $mime_param);

    if ($insert->execute()) {
        $update = $db->prepare(
            "UPDATE chat_conversation SET actualizado_en = NOW() WHERE id = :id"
        );
        $update->bindParam(':id', $conversation_id);
        $update->execute();

        http_response_code(201);
        echo json_encode(["success" => true, "message_id" => $db->lastInsertId()]);
        return;
    }

    http_response_code(500);
    echo json_encode(["message" => "Error al enviar mensaje."]);
}

function mark_read($db, $user) {
    $data = json_decode(file_get_contents("php://input"), true);
    $other_user_id = $data['user_id'] ?? null;

    $nutri_id = null;
    $usuario_id = null;

    if (is_nutri($user)) {
        if (!$other_user_id) {
            http_response_code(400);
            echo json_encode(["message" => "Parametro user_id requerido."]);
            return;
        }
        $usuario_id = intval($other_user_id);
    } else {
        $usuario_id = $user['codigo'];
        $nutri_id = get_default_nutri_id($db);
        if (!$nutri_id) {
            http_response_code(404);
            echo json_encode(["message" => "Nutricionista no encontrado."]);
            return;
        }
    }

    $conversation = get_or_create_conversation($db, $usuario_id, $nutri_id);
    if (!$conversation || empty($conversation['id'])) {
        http_response_code(500);
        echo json_encode(["message" => "No se pudo crear la conversacion."]);
        return;
    }

    $conversation_id = intval($conversation['id']);

    if (is_nutri($user)) {
        $query = "UPDATE chat_message
                  SET leido = 1, leido_fecha = NOW()
                  WHERE conversation_id = :conversation_id
                    AND sender_id = :sender_id
                    AND leido = 0";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':conversation_id', $conversation_id);
        $stmt->bindParam(':sender_id', $usuario_id);
    } else {
        $query = "UPDATE chat_message
                  SET leido = 1, leido_fecha = NOW()
                  WHERE conversation_id = :conversation_id
                    AND receiver_id = :receiver_id
                    AND leido = 0";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':conversation_id', $conversation_id);
        $stmt->bindParam(':receiver_id', $user['codigo']);
    }

    if ($stmt->execute()) {
        http_response_code(200);
        echo json_encode(["success" => true]);
        return;
    }

    http_response_code(500);
    echo json_encode(["message" => "Error al marcar leidos."]);
}

function delete_message($db, $user) {
    $data = json_decode(file_get_contents("php://input"), true);
    $message_id = intval($data['message_id'] ?? 0);
    $delete_for_all = ($data['delete_for_all'] ?? false) === true;

    if ($message_id <= 0) {
        http_response_code(400);
        echo json_encode(["message" => "Parametro message_id requerido."]);
        return;
    }

    $query = "SELECT id, sender_id, receiver_id FROM chat_message WHERE id = :id LIMIT 1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':id', $message_id);
    $stmt->execute();
    $msg = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$msg) {
        http_response_code(404);
        echo json_encode(["message" => "Mensaje no encontrado."]);
        return;
    }

    $user_id = intval($user['codigo']);
    if ($msg['sender_id'] != $user_id && $msg['receiver_id'] != $user_id) {
        http_response_code(403);
        echo json_encode(["message" => "No autorizado."]);
        return;
    }

    if ($delete_for_all && $msg['sender_id'] == $user_id) {
        $update = $db->prepare(
            "UPDATE chat_message
             SET borrado_por_emisor = 1, borrado_por_receptor = 1
             WHERE id = :id"
        );
        $update->bindParam(':id', $message_id);
    } else if ($msg['sender_id'] == $user_id) {
        $update = $db->prepare(
            "UPDATE chat_message SET borrado_por_emisor = 1 WHERE id = :id"
        );
        $update->bindParam(':id', $message_id);
    } else {
        $update = $db->prepare(
            "UPDATE chat_message SET borrado_por_receptor = 1 WHERE id = :id"
        );
        $update->bindParam(':id', $message_id);
    }

    if ($update->execute()) {
        http_response_code(200);
        echo json_encode(["success" => true]);
        return;
    }

    http_response_code(500);
    echo json_encode(["message" => "Error al borrar mensaje."]);
}
?>
