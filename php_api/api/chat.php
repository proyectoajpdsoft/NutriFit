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
    $limit_param = isset($_GET['limit']) ? intval($_GET['limit']) : 0;
    $before_id = isset($_GET['before_id']) ? intval($_GET['before_id']) : 0;
    $is_paginated = $limit_param > 0;
    $limit = $is_paginated ? max(1, min($limit_param, 100)) : 0;

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

    $base_select = "SELECT id, conversation_id, sender_id, receiver_id, cuerpo, imagen_base64, imagen_mime,
                           leido, leido_fecha, creado_en
                    FROM chat_message
                    WHERE conversation_id = :conversation_id";

    if (is_nutri($user)) {
        $visibility_filter = " AND (borrado_por_emisor = 0 OR borrado_por_receptor = 0)";
    } else {
        $visibility_filter = " AND ((sender_id = :user_id AND borrado_por_emisor = 0)
                              OR (receiver_id = :user_id AND borrado_por_receptor = 0))";
    }

    $before_filter = $before_id > 0 ? " AND id < :before_id" : "";

    if ($is_paginated) {
        $query = $base_select . $visibility_filter . $before_filter . "
                  ORDER BY id DESC
                  LIMIT :limit_plus_one";
    } else {
        $query = $base_select . $visibility_filter . "
                  ORDER BY creado_en ASC";
    }

    $stmt = $db->prepare($query);
    $stmt->bindParam(':conversation_id', $conversation_id);
    if (!is_nutri($user)) {
        $stmt->bindParam(':user_id', $user['codigo']);
    }
    if ($before_id > 0) {
        $stmt->bindParam(':before_id', $before_id, PDO::PARAM_INT);
    }
    if ($is_paginated) {
        $limit_plus_one = $limit + 1;
        $stmt->bindParam(':limit_plus_one', $limit_plus_one, PDO::PARAM_INT);
    }

    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $has_more = false;
    $next_before_id = null;

    if ($is_paginated) {
        if (count($rows) > $limit) {
            $has_more = true;
            array_pop($rows);
        }
        $items = array_reverse($rows);
        if (!empty($items)) {
            $next_before_id = intval($items[0]['id']);
        }
    } else {
        $items = $rows;
    }

    http_response_code(200);
    echo json_encode([
        "conversation_id" => $conversation_id,
        "items" => $items ?? [],
        "has_more" => $has_more,
        "next_before_id" => $next_before_id
    ]);
}

function send_message($db, $user) {
    $data = json_decode(file_get_contents("php://input"), true);
    $cuerpo = trim($data['cuerpo'] ?? '');
    $imagen_base64 = trim($data['imagen_base64'] ?? '');
    $imagen_mime = trim($data['imagen_mime'] ?? '');

    if ($imagen_base64 !== '') {
        $chat_image_limits = get_chat_image_limits($db);
        $processed_image = process_chat_image_for_storage(
            $imagen_base64,
            $imagen_mime,
            $chat_image_limits['width'],
            $chat_image_limits['height']
        );

        if (!$processed_image['ok']) {
            http_response_code(400);
            echo json_encode(["message" => $processed_image['message']]);
            return;
        }

        $imagen_base64 = $processed_image['base64'];
        $imagen_mime = $processed_image['mime'];
    }

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

        $sender_display_name = trim((string)($user['nombre'] ?? ''));
        if ($sender_display_name === '') {
            $sender_display_name = trim((string)($user['nick'] ?? 'Usuario'));
        }
        dispatch_unread_chat_push(
            $db,
            intval($receiver_id),
            $sender_display_name,
            $cuerpo,
            $conversation_id,
            $sender_id
        );

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

function dispatch_unread_chat_push($db, $receiver_id, $sender_name, $message_text, $conversation_id, $sender_id) {
    $tokens = get_push_tokens_for_receiver($db, $receiver_id);
    if (empty($tokens)) {
        return;
    }

    $title = 'Nuevo mensaje de ' . $sender_name;
    $body = trim((string)$message_text);
    if ($body === '') {
        $body = 'Te ha enviado una imagen';
    }

    $data = [
        'type' => 'chat_unread',
        'conversation_id' => (string)$conversation_id,
        'sender_id' => (string)$sender_id,
    ];

    $sent = send_fcm_v1_multicast($db, $tokens, $title, $body, $data);
    if ($sent) {
        return;
    }

    $server_key = get_fcm_server_key($db);
    if ($server_key) {
        send_fcm_legacy_multicast($server_key, $tokens, $title, $body, $data);
    }
}

function get_push_tokens_for_receiver($db, $receiver_id) {
    try {
        $stmt = $db->prepare(
            "SELECT token
             FROM usuario_push_dispositivo
             WHERE usuario_codigo = :receiver_id
               AND activo = 1
               AND chat_unread_enabled = 1
               AND token IS NOT NULL
               AND token <> ''"
        );
        $stmt->bindParam(':receiver_id', $receiver_id, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $tokens = [];
        foreach ($rows as $row) {
            $token = trim((string)($row['token'] ?? ''));
            if ($token !== '') {
                $tokens[] = $token;
            }
        }

        return array_values(array_unique($tokens));
    } catch (Throwable $e) {
        return [];
    }
}

function get_fcm_server_key($db) {
    $envKey = trim((string)(getenv('FCM_SERVER_KEY') ?: ''));
    if ($envKey !== '') {
        return $envKey;
    }

    return get_param_value($db, 'fcm_server_key', 'TU_FCM_SERVER_KEY');
}

function get_chat_image_limits($db) {
    $defaults = [
        'width' => 1280,
        'height' => 1280,
    ];

    $param = get_param_with_dimensions($db, 'tamaño_imagen_maximo_chat');
    if ($param) {
        $width = parse_positive_int($param['valor'] ?? null);
        $height = parse_positive_int($param['valor2'] ?? null);

        if ($width !== null && $height !== null) {
            return [
                'width' => $width,
                'height' => $height,
            ];
        }
    }

    return $defaults;
}

function get_param_with_dimensions($db, $name) {
    $queries = [
        "SELECT valor, valor2 FROM parametro WHERE nombre = :nombre LIMIT 1",
        "SELECT valor1 AS valor, valor2 FROM parametro WHERE nombre = :nombre LIMIT 1",
    ];

    foreach ($queries as $query) {
        try {
            $stmt = $db->prepare($query);
            $stmt->bindParam(':nombre', $name);
            $stmt->execute();
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($row) {
                return $row;
            }
        } catch (Throwable $e) {
            continue;
        }
    }

    return null;
}

function parse_positive_int($value) {
    if ($value === null) {
        return null;
    }

    $parsed = intval(trim((string)$value));
    return $parsed > 0 ? $parsed : null;
}

function normalize_base64_data($raw) {
    $value = trim((string)$raw);
    if ($value === '') {
        return '';
    }

    if (strpos($value, ',') !== false && stripos($value, 'base64,') !== false) {
        $parts = explode(',', $value, 2);
        $value = trim((string)($parts[1] ?? ''));
    }

    return str_replace(' ', '+', $value);
}

function process_chat_image_for_storage($base64, $mime, $max_width, $max_height) {
    $normalized = normalize_base64_data($base64);
    if ($normalized === '') {
        return [
            'ok' => false,
            'message' => 'Imagen no valida.',
        ];
    }

    $binary = base64_decode($normalized, true);
    if ($binary === false) {
        return [
            'ok' => false,
            'message' => 'Imagen base64 no valida.',
        ];
    }

    $image_info = @getimagesizefromstring($binary);
    if (!$image_info || empty($image_info[0]) || empty($image_info[1])) {
        return [
            'ok' => false,
            'message' => 'Formato de imagen no soportado.',
        ];
    }

    $source_width = intval($image_info[0]);
    $source_height = intval($image_info[1]);
    $detected_mime = strtolower(trim((string)($image_info['mime'] ?? '')));
    $requested_mime = strtolower(trim((string)$mime));

    $target_mime = 'image/jpeg';
    if ($requested_mime === 'image/png' || $detected_mime === 'image/png') {
        $target_mime = 'image/png';
    } elseif ($requested_mime === 'image/webp' || $detected_mime === 'image/webp') {
        $target_mime = function_exists('imagewebp') ? 'image/webp' : 'image/jpeg';
    }

    $max_width = max(1, intval($max_width));
    $max_height = max(1, intval($max_height));

    if ($source_width <= $max_width && $source_height <= $max_height) {
        return [
            'ok' => true,
            'base64' => base64_encode($binary),
            'mime' => $target_mime,
        ];
    }

    if (!function_exists('imagecreatefromstring') ||
        !function_exists('imagecreatetruecolor') ||
        !function_exists('imagecopyresampled')) {
        return [
            'ok' => true,
            'base64' => base64_encode($binary),
            'mime' => $target_mime,
        ];
    }

    $scale = min($max_width / $source_width, $max_height / $source_height);
    $new_width = max(1, intval(round($source_width * $scale)));
    $new_height = max(1, intval(round($source_height * $scale)));

    $source_image = @imagecreatefromstring($binary);
    if (!$source_image) {
        return [
            'ok' => true,
            'base64' => base64_encode($binary),
            'mime' => $target_mime,
        ];
    }

    $resized_image = imagecreatetruecolor($new_width, $new_height);
    if (!$resized_image) {
        imagedestroy($source_image);
        return [
            'ok' => true,
            'base64' => base64_encode($binary),
            'mime' => $target_mime,
        ];
    }

    if ($target_mime === 'image/png' || $target_mime === 'image/webp') {
        imagealphablending($resized_image, false);
        imagesavealpha($resized_image, true);
        $transparent = imagecolorallocatealpha($resized_image, 0, 0, 0, 127);
        imagefilledrectangle($resized_image, 0, 0, $new_width, $new_height, $transparent);
    }

    imagecopyresampled(
        $resized_image,
        $source_image,
        0,
        0,
        0,
        0,
        $new_width,
        $new_height,
        $source_width,
        $source_height
    );

    ob_start();
    $encoded_ok = false;
    if ($target_mime === 'image/png') {
        $encoded_ok = imagepng($resized_image, null, 6);
    } elseif ($target_mime === 'image/webp' && function_exists('imagewebp')) {
        $encoded_ok = imagewebp($resized_image, null, 82);
    } else {
        $target_mime = 'image/jpeg';
        $encoded_ok = imagejpeg($resized_image, null, 85);
    }
    $output = ob_get_clean();

    imagedestroy($source_image);
    imagedestroy($resized_image);

    if (!$encoded_ok || $output === false || $output === '') {
        return [
            'ok' => true,
            'base64' => base64_encode($binary),
            'mime' => $target_mime,
        ];
    }

    return [
        'ok' => true,
        'base64' => base64_encode($output),
        'mime' => $target_mime,
    ];
}

function get_param_value($db, $name, $placeholder = null) {
    $queries = [
        "SELECT valor, valor2 FROM parametro WHERE nombre = :nombre LIMIT 1",
        "SELECT valor1 AS valor, valor2 FROM parametro WHERE nombre = :nombre LIMIT 1",
    ];

    foreach ($queries as $query) {
        try {
            $stmt = $db->prepare($query);
            $stmt->bindParam(':nombre', $name);
            $stmt->execute();
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$row) {
                return null;
            }

            $candidates = [
                trim((string)($row['valor'] ?? '')),
                trim((string)($row['valor2'] ?? '')),
            ];

            foreach ($candidates as $candidate) {
                if ($candidate === '') {
                    continue;
                }
                if ($placeholder !== null && strtoupper($candidate) === strtoupper($placeholder)) {
                    continue;
                }
                return $candidate;
            }

            return null;
        } catch (Throwable $e) {
            continue;
        }
    }

    return null;
}

function get_fcm_v1_credentials($db) {
    $projectId = trim((string)(getenv('FCM_V1_PROJECT_ID') ?: ''));
    $clientEmail = trim((string)(getenv('FCM_V1_CLIENT_EMAIL') ?: ''));
    $privateKey = (string)(getenv('FCM_V1_PRIVATE_KEY') ?: '');

    if ($projectId === '') {
        $projectId = (string)(get_param_value($db, 'fcm_v1_project_id', 'TU_PROJECT_ID') ?? '');
    }
    if ($clientEmail === '') {
        $clientEmail = (string)(get_param_value($db, 'fcm_v1_client_email', 'TU_CLIENT_EMAIL') ?? '');
    }
    if (trim($privateKey) === '') {
        $privateKey = (string)(get_param_value($db, 'fcm_v1_private_key', 'TU_PRIVATE_KEY') ?? '');
    }

    $privateKey = trim(str_replace("\\n", "\n", $privateKey));

    if ($projectId === '' || $clientEmail === '' || $privateKey === '') {
        return null;
    }

    return [
        'project_id' => $projectId,
        'client_email' => $clientEmail,
        'private_key' => $privateKey,
        'token_uri' => 'https://oauth2.googleapis.com/token',
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
    ];
}

function create_service_account_jwt($clientEmail, $privateKey, $scope, $tokenUri) {
    $now = time();
    $header = [
        'alg' => 'RS256',
        'typ' => 'JWT',
    ];
    $claims = [
        'iss' => $clientEmail,
        'scope' => $scope,
        'aud' => $tokenUri,
        'iat' => $now,
        'exp' => $now + 3600,
    ];

    $encodedHeader = rtrim(strtr(base64_encode(json_encode($header)), '+/', '-_'), '=');
    $encodedClaims = rtrim(strtr(base64_encode(json_encode($claims)), '+/', '-_'), '=');
    $unsignedToken = $encodedHeader . '.' . $encodedClaims;

    $signature = '';
    $signOk = openssl_sign($unsignedToken, $signature, $privateKey, OPENSSL_ALGO_SHA256);
    if (!$signOk) {
        return null;
    }

    $encodedSignature = rtrim(strtr(base64_encode($signature), '+/', '-_'), '=');
    return $unsignedToken . '.' . $encodedSignature;
}

function fetch_google_oauth_access_token($credentials) {
    $jwt = create_service_account_jwt(
        $credentials['client_email'],
        $credentials['private_key'],
        $credentials['scope'],
        $credentials['token_uri']
    );

    if (!$jwt) {
        return null;
    }

    $postFields = http_build_query([
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion' => $jwt,
    ]);

    $ch = curl_init($credentials['token_uri']);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 8);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $postFields);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);

    if ($response === false || $httpCode < 200 || $httpCode >= 300) {
        error_log('FCM v1 OAuth token error. HTTP=' . $httpCode . ' curl=' . $curlError . ' response=' . (string)$response);
        return null;
    }

    $json = json_decode($response, true);
    $token = trim((string)($json['access_token'] ?? ''));
    if ($token === '') {
        error_log('FCM v1 OAuth token missing in response: ' . $response);
        return null;
    }

    return $token;
}

function send_fcm_v1_message($accessToken, $projectId, $token, $title, $body, $data = []) {
    $endpoint = 'https://fcm.googleapis.com/v1/projects/' . rawurlencode($projectId) . '/messages:send';

    $payload = [
        'message' => [
            'token' => $token,
            'notification' => [
                'title' => $title,
                'body' => $body,
            ],
            'data' => $data,
            'android' => [
                'priority' => 'HIGH',
                'notification' => [
                    'sound' => 'default',
                    'channel_id' => 'nutrifit_chat_messages',
                ],
            ],
        ],
    ];

    $ch = curl_init($endpoint);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $accessToken,
        'Content-Type: application/json; charset=UTF-8',
    ]);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 8);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);

    if ($response === false) {
        return [
            'ok' => false,
            'http_code' => $httpCode,
            'error_status' => null,
            'response' => null,
            'curl_error' => $curlError,
        ];
    }

    $json = json_decode($response, true);
    $errorStatus = null;
    if (is_array($json) && isset($json['error']['status'])) {
        $errorStatus = (string)$json['error']['status'];
    }

    return [
        'ok' => $httpCode >= 200 && $httpCode < 300,
        'http_code' => $httpCode,
        'error_status' => $errorStatus,
        'response' => $response,
        'curl_error' => $curlError,
    ];
}

function deactivate_push_token($db, $token) {
    try {
        $stmt = $db->prepare(
            "UPDATE usuario_push_dispositivo
             SET activo = 0,
                 actualizado_en = NOW()
             WHERE token = :token"
        );
        $stmt->bindParam(':token', $token);
        $stmt->execute();
    } catch (Throwable $e) {
        error_log('FCM deactivate token failed: ' . $e->getMessage());
    }
}

function send_fcm_v1_multicast($db, $tokens, $title, $body, $data = []) {
    if (empty($tokens)) {
        return false;
    }

    $credentials = get_fcm_v1_credentials($db);
    if (!$credentials) {
        error_log('FCM v1 credentials missing or invalid. Check fcm_v1_project_id, fcm_v1_client_email, fcm_v1_private_key.');
        return false;
    }

    $accessToken = fetch_google_oauth_access_token($credentials);
    if (!$accessToken) {
        error_log('FCM v1 access token could not be obtained.');
        return false;
    }

    $sentAtLeastOne = false;
    foreach ($tokens as $token) {
        $trimmed = trim((string)$token);
        if ($trimmed === '') {
            continue;
        }

        $result = send_fcm_v1_message(
            $accessToken,
            $credentials['project_id'],
            $trimmed,
            $title,
            $body,
            $data
        );

        if (($result['ok'] ?? false) == true) {
            $sentAtLeastOne = true;
            continue;
        }

        $errorStatus = strtoupper((string)($result['error_status'] ?? ''));
        if ($errorStatus === 'UNREGISTERED' || $errorStatus === 'NOT_FOUND') {
            deactivate_push_token($db, $trimmed);
        }

        error_log(
            'FCM v1 send failed. token=' . substr($trimmed, 0, 20) . '... ' .
            'http=' . (string)($result['http_code'] ?? 0) . ' ' .
            'status=' . (string)($result['error_status'] ?? '') . ' ' .
            'curl=' . (string)($result['curl_error'] ?? '') . ' ' .
            'response=' . (string)($result['response'] ?? '')
        );
    }

    return $sentAtLeastOne;
}

function send_fcm_legacy_multicast($server_key, $tokens, $title, $body, $data = []) {
    if (empty($tokens)) {
        return;
    }

    $payload = [
        'registration_ids' => array_values($tokens),
        'priority' => 'high',
        'notification' => [
            'title' => $title,
            'body' => $body,
            'sound' => 'default',
        ],
        'data' => $data,
    ];

    $ch = curl_init('https://fcm.googleapis.com/fcm/send');
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: key=' . $server_key,
        'Content-Type: application/json',
    ]);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
    curl_exec($ch);
    curl_close($ch);
}
?>
