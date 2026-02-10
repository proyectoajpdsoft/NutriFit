<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

session_start();

$api_base_url = "http://ipcasa.ajpdsoft.com:8080/apirestnu/api";
$api_result = null;

// Función para realizar llamadas cURL a la API
function call_api($method, $url, $token = null, $data = false) {
    $curl = curl_init();

    switch ($method) {
        case "POST":
            curl_setopt($curl, CURLOPT_POST, 1);
            if ($data)
                curl_setopt($curl, CURLOPT_POSTFIELDS, $data);
            break;
        case "PUT":
            curl_setopt($curl, CURLOPT_CUSTOMREQUEST, "PUT");
            if ($data)
                curl_setopt($curl, CURLOPT_POSTFIELDS, $data);
            break;
        default: // GET
            if ($data)
                $url = sprintf("%s?%s", $url, http_build_query($data));
    }

    // Opciones de cURL
    curl_setopt($curl, CURLOPT_URL, $url);
    curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($curl, CURLOPT_VERBOSE, 1); // Verbose para depuración
    curl_setopt($curl, CURLOPT_HEADER, 1); // Incluir cabeceras en la salida

    $headers = ['Content-Type: application/json'];
    if ($token) {
        $headers[] = "Authorization: Bearer " . $token;
    }
    curl_setopt($curl, CURLOPT_HTTPHEADER, $headers);

    // Ejecutar cURL
    $response = curl_exec($curl);
    $curl_error = curl_error($curl);
    
    if ($curl_error) {
        return ['error' => 'cURL Error: ' . $curl_error];
    }

    $header_size = curl_getinfo($curl, CURLINFO_HEADER_SIZE);
    $http_code = curl_getinfo($curl, CURLINFO_HTTP_CODE);
    curl_close($curl);
    
    $header_str = substr($response, 0, $header_size);
    $body_str = substr($response, $header_size);

    return [
        'http_code' => $http_code,
        'headers' => $header_str,
        'body' => $body_str
    ];
}

// --- LÓGICA DE LA PÁGINA ---

// Manejar Logout
if (isset($_GET['action']) && $_GET['action'] === 'logout') {
    session_destroy();
    header("Location: debug_tool.php");
    exit();
}

// Manejar Login
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['nick'])) {
    $login_data = json_encode([
        'nick' => $_POST['nick'],
        'contrasena' => $_POST['password']
    ]);
    $api_result = call_api('POST', "$api_base_url/login.php", null, $login_data);
    
    if (isset($api_result['body'])) {
        $login_response = json_decode($api_result['body'], true);
        if (isset($login_response['token'])) {
            $_SESSION['api_token'] = $login_response['token'];
            $_SESSION['user_info'] = $login_response['usuario'];
        }
    }
}

// Manejar otras acciones (ej. get_pacientes)
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['action'])) {
    if (isset($_SESSION['api_token'])) {
        $token = $_SESSION['api_token'];
        switch ($_GET['action']) {
            case 'get_pacientes':
                $api_result = call_api('GET', "$api_base_url/pacientes.php", $token);
                break;
            // Aquí se podrían añadir más casos para otros endpoints
        }
    } else {
        $api_result = ['error' => 'No estás autenticado. Por favor, inicia sesión.'];
    }
}

?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Herramienta de Depuración de API</title>
    <style>
        body { font-family: sans-serif; line-height: 1.6; padding: 20px; }
        .container { max-width: 800px; margin: auto; }
        .card { border: 1px solid #ccc; padding: 20px; margin-bottom: 20px; border-radius: 5px; }
        .card h2 { margin-top: 0; }
        pre { background-color: #f4f4f4; padding: 15px; border-radius: 5px; white-space: pre-wrap; word-wrap: break-word; }
        .error { color: red; }
        .success { color: green; }
        input[type="text"], input[type="password"] { width: 100%; padding: 8px; margin-bottom: 10px; }
        button { padding: 10px 15px; cursor: pointer; }
        .actions a { display: inline-block; margin-right: 15px; padding: 10px; background-color: #007bff; color: white; text-decoration: none; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Herramienta de Depuración de API</h1>

        <?php if (!isset($_SESSION['api_token'])): ?>
            <div class="card">
                <h2>Iniciar Sesión</h2>
                <form action="debug_tool.php" method="POST">
                    <label for="nick">Nick:</label>
                    <input type="text" id="nick" name="nick" required>
                    <label for="password">Contraseña:</label>
                    <input type="password" id="password" name="password" required>
                    <button type="submit">Login</button>
                </form>
            </div>
        <?php else: ?>
            <div class="card">
                <h2>Panel de Acciones</h2>
                <p class="success">
                    Autenticado correctamente. <br>
                    <strong>Tipo de usuario:</strong> <?php echo htmlspecialchars($_SESSION['user_info']['tipo'] ?? 'No especificado'); ?>
                </p>
                <div class="actions">
                    <a href="?action=get_pacientes">Consultar Pacientes</a>
                    <!-- Añadir más enlaces para otras acciones aquí -->
                </div>
                <br>
                <a href="?action=logout">Cerrar Sesión</a>
            </div>
        <?php endif; ?>

        <?php if ($api_result): ?>
            <div class="card">
                <h2>Resultado de la API</h2>
                <?php if (isset($api_result['error'])): ?>
                    <pre class="error"><?php echo htmlspecialchars($api_result['error']); ?></pre>
                <?php else: ?>
                    <h3>Código de Estado HTTP</h3>
                    <pre><?php echo htmlspecialchars($api_result['http_code']); ?></pre>
                    
                    <h3>Cabeceras de la Respuesta</h3>
                    <pre><?php echo htmlspecialchars($api_result['headers']); ?></pre>

                    <h3>Cuerpo de la Respuesta (JSON)</h3>
                    <pre><?php 
                        $json_body = json_decode($api_result['body']);
                        echo json_encode($json_body, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE); 
                    ?></pre>
                <?php endif; ?>
            </div>
        <?php endif; ?>

    </div>
</body>
</html>
