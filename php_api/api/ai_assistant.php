<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once '../config/database.php';
require_once '../auth/token_validator.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

$validator = new TokenValidator($db);
$user = $validator->validateToken();

if (!can_use_ai_assistant($user)) {
    http_response_code(403);
    echo json_encode([
        'message' => 'No autorizado para usar el asistente IA.',
    ]);
    exit();
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    get_ai_assistant_config($db);
    exit();
}

if ($method === 'POST') {
    send_ai_assistant_message($db, $user);
    exit();
}

http_response_code(405);
echo json_encode(['message' => 'Metodo no permitido.']);

function can_use_ai_assistant($user) {
    $tipo = strtolower(trim((string)($user['tipo'] ?? '')));
    return $tipo === 'nutricionista' || $tipo === 'administrador';
}

function is_truthy($value) {
    $normalized = strtolower(trim((string)$value));
    return in_array($normalized, ['1', 'true', 't', 'yes', 'y', 'si', 's', 'on'], true);
}

function get_param_value($db, $name, $default = '') {
    $stmt = $db->prepare('SELECT valor FROM parametro WHERE nombre = :nombre LIMIT 1');
    $stmt->bindParam(':nombre', $name);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    return $row && array_key_exists('valor', $row) ? (string)$row['valor'] : $default;
}

function decode_json_object($value) {
    if (!is_string($value) || trim($value) === '') {
        return [];
    }

    $decoded = json_decode($value, true);
    return is_array($decoded) ? $decoded : [];
}

function decode_json_list($value) {
    if (!is_string($value) || trim($value) === '') {
        return [];
    }

    $decoded = json_decode($value, true);
    return is_array($decoded) ? array_values($decoded) : [];
}

function sanitize_prompt_templates($templates) {
    if (!is_array($templates)) {
        return [];
    }

    $result = [];
    foreach ($templates as $item) {
        if (!is_array($item)) {
            continue;
        }

        $title = trim((string)($item['title'] ?? $item['titulo'] ?? ''));
        $prompt = trim((string)($item['prompt'] ?? $item['texto'] ?? ''));
        $module = trim((string)($item['module'] ?? $item['modulo'] ?? 'Todos'));
        $rawActive = $item['active'] ?? $item['activo'] ?? true;
        $rawDefault = $item['default'] ?? $item['defecto'] ?? false;
        $active = is_bool($rawActive)
            ? $rawActive
            : is_truthy($rawActive) || trim((string)$rawActive) === '';
        $isDefault = is_bool($rawDefault)
            ? $rawDefault
            : is_truthy($rawDefault);

        if ($title === '' || $prompt === '' || !$active) {
            continue;
        }

        $result[] = [
            'title' => $title,
            'prompt' => $prompt,
            'module' => $module === '' ? 'Todos' : $module,
            'active' => true,
            'default' => $isDefault,
        ];
    }

    return $result;
}

function default_role_prompt() {
    return 'Actúa siempre con el rol de un especialista cualificado en nutrición y dietética y el de un entrenador personal (personal training) cualificado. Responde con criterio profesional, prudencia y enfoque práctico.';
}

function get_ai_runtime_config($db) {
    $enabled = is_truthy(get_param_value($db, 'ia_habilitada', '0'));
    $provider = trim(get_param_value($db, 'ia_proveedor', 'deepseek'));
    $baseUrl = trim(get_param_value($db, 'ia_base_url', 'https://api.deepseek.com'));
    $chatPath = trim(get_param_value($db, 'ia_endpoint_chat', '/chat/completions'));
    $apiKey = trim(get_param_value($db, 'ia_api_key', ''));
    $model = trim(get_param_value($db, 'ia_modelo', 'deepseek-chat'));
    $rolePrompt = trim(get_param_value($db, 'ia_rol_sistema', default_role_prompt()));
    $systemPrompt = trim(get_param_value($db, 'ia_system_prompt', ''));
    $temperature = (float)get_param_value($db, 'ia_temperature', '0.7');
    $maxTokens = (int)get_param_value($db, 'ia_max_tokens', '1200');
    $timeoutSeconds = (int)get_param_value($db, 'ia_timeout_segundos', '60');
    $templates = sanitize_prompt_templates(
        decode_json_list(get_param_value($db, 'ia_prompt_templates_json', '[]'))
    );

    return [
        'enabled' => $enabled,
        'provider' => $provider,
        'base_url' => $baseUrl,
        'chat_path' => $chatPath,
        'api_key' => $apiKey,
        'model' => $model,
        'role_prompt' => $rolePrompt,
        'system_prompt' => $systemPrompt,
        'temperature' => $temperature,
        'max_tokens' => $maxTokens,
        'timeout_seconds' => max(5, $timeoutSeconds),
        'templates' => $templates,
    ];
}

function get_ai_assistant_config($db) {
    $config = get_ai_runtime_config($db);

    http_response_code(200);
    echo json_encode([
        'enabled' => $config['enabled'],
        'provider' => $config['provider'],
        'model' => $config['model'],
        'role_prompt' => $config['role_prompt'],
        'system_prompt' => $config['system_prompt'],
        'temperature' => $config['temperature'],
        'max_tokens' => $config['max_tokens'],
        'templates' => $config['templates'],
        'placeholders' => [
            '[título]',
            '[descripcion]',
            '[descripción]',
            '[instrucciones]',
            '[pasos]',
        ],
    ]);
}

function sanitize_messages($messages) {
    if (!is_array($messages)) {
        return [];
    }

    $result = [];
    foreach ($messages as $message) {
        if (!is_array($message)) {
            continue;
        }

        $role = trim((string)($message['role'] ?? ''));
        $content = trim((string)($message['content'] ?? ''));
        if ($role === '' || $content === '') {
            continue;
        }

        if (!in_array($role, ['system', 'user', 'assistant'], true)) {
            continue;
        }

        $result[] = [
            'role' => $role,
            'content' => $content,
        ];
    }

    return $result;
}

function extract_assistant_text($decoded) {
    if (!is_array($decoded)) {
        return '';
    }

    $choices = $decoded['choices'] ?? null;
    if (!is_array($choices) || empty($choices[0])) {
        return '';
    }

    $first = $choices[0];
    $message = $first['message'] ?? null;
    if (is_array($message)) {
        $content = $message['content'] ?? '';
        if (is_string($content)) {
            return trim($content);
        }
        if (is_array($content)) {
            $parts = [];
            foreach ($content as $item) {
                if (is_array($item) && isset($item['text']) && is_string($item['text'])) {
                    $parts[] = trim($item['text']);
                }
            }
            return trim(implode("\n", array_filter($parts)));
        }
    }

    $text = $first['text'] ?? '';
    return is_string($text) ? trim($text) : '';
}

function send_ai_assistant_message($db, $user) {
    $config = get_ai_runtime_config($db);
    if (!$config['enabled']) {
        http_response_code(403);
        echo json_encode(['message' => 'El asistente IA no esta habilitado.']);
        return;
    }

    if ($config['api_key'] === '' || $config['base_url'] === '' || $config['model'] === '') {
        http_response_code(500);
        echo json_encode(['message' => 'La configuracion del asistente IA es incompleta.']);
        return;
    }

    $input = json_decode(file_get_contents('php://input'), true);
    if (!is_array($input)) {
        http_response_code(400);
        echo json_encode(['message' => 'JSON invalido.']);
        return;
    }

    $messages = sanitize_messages($input['messages'] ?? []);
    $userPrompt = trim((string)($input['prompt'] ?? ''));
    if ($userPrompt !== '') {
        $messages[] = ['role' => 'user', 'content' => $userPrompt];
    }

    if (empty($messages)) {
        http_response_code(400);
        echo json_encode(['message' => 'No hay mensajes para enviar a la IA.']);
        return;
    }

    $requestSystemPrompt = trim((string)($input['system_prompt'] ?? ''));
    $systemParts = [];
    if ($config['role_prompt'] !== '') {
        $systemParts[] = $config['role_prompt'];
    }
    if ($requestSystemPrompt !== '') {
        $systemParts[] = $requestSystemPrompt;
    } elseif ($config['system_prompt'] !== '') {
        $systemParts[] = $config['system_prompt'];
    }

    if (!empty($systemParts)) {
        array_unshift($messages, [
            'role' => 'system',
            'content' => implode("\n\n", $systemParts),
        ]);
    }

    $temperature = isset($input['temperature']) ? (float)$input['temperature'] : $config['temperature'];
    $maxTokens = isset($input['max_tokens']) ? (int)$input['max_tokens'] : $config['max_tokens'];

    $payload = [
        'model' => $config['model'],
        'messages' => $messages,
        'temperature' => $temperature,
    ];

    if ($maxTokens > 0) {
        $payload['max_tokens'] = $maxTokens;
    }

    $endpoint = rtrim($config['base_url'], '/') . '/' . ltrim($config['chat_path'], '/');
    $headers = [
        'Authorization: Bearer ' . $config['api_key'],
        'Content-Type: application/json; charset=UTF-8',
    ];

    $ch = curl_init($endpoint);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, $config['timeout_seconds']);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload, JSON_UNESCAPED_UNICODE));

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);

    if ($response === false) {
        http_response_code(502);
        echo json_encode([
            'message' => 'Error de red conectando con el proveedor IA.',
            'details' => $curlError,
        ]);
        return;
    }

    $decoded = json_decode($response, true);
    $assistantText = extract_assistant_text($decoded);

    if ($httpCode < 200 || $httpCode >= 300 || $assistantText === '') {
        http_response_code($httpCode >= 400 ? $httpCode : 502);
        echo json_encode([
            'message' => 'Respuesta invalida del proveedor IA.',
            'provider' => $config['provider'],
            'details' => $decoded ?: $response,
        ]);
        return;
    }

    http_response_code(200);
    echo json_encode([
        'provider' => $config['provider'],
        'model' => $config['model'],
        'reply' => $assistantText,
        'usage' => is_array($decoded['usage'] ?? null) ? $decoded['usage'] : null,
        'origin' => $input['origin'] ?? null,
        'requested_by' => [
            'codigo' => $user['codigo'] ?? null,
            'tipo' => $user['tipo'] ?? null,
        ],
    ]);
}