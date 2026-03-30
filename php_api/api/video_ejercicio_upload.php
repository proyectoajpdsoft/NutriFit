<?php
/**
 * Endpoint para subida de ficheros de vídeo al sistema de ficheros del servidor.
 * Usa el parámetro ruta_fs_videos_ejercicios (ruta del sistema de ficheros).
 * Si dicho parámetro no está configurado, intenta derivar la ruta a partir de
 * ruta_base_videos_ejercicios combinada con DOCUMENT_ROOT.
 *
 * POST multipart/form-data
 *   video       : archivo binario (obligatorio)
 *   subcarpeta  : subdirectorio relativo dentro de la base (opcional)
 *
 * Respuesta 200:
 *   { "ruta_video": "subcarpeta/nombre_fichero.mp4" }   // relativa a ruta_base
 *   { "ruta_video": "nombre_fichero.mp4" }              // si sin subcarpeta
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);
ob_start();

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/auto_validator.php';
include_once '../auth/permissions.php';

$database = new Database();
$db = $database->getConnection();

$validator = new AutoValidator($db);
$user = $validator->validate();
PermissionManager::checkPermission($user, 'videos_ejercicios');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    ob_clean();
    echo json_encode(["error" => "Solo POST permitido"]);
    exit();
}

// ── Leer parámetros de configuración desde BD ──────────────────────────────

function get_parametro(PDO $db, string $nombre): string {
    $stmt = $db->prepare("SELECT valor FROM parametro WHERE nombre = :nombre LIMIT 1");
    $stmt->bindParam(':nombre', $nombre);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    return $row ? trim($row['valor']) : '';
}

$ruta_fs  = get_parametro($db, 'ruta_fs_videos_ejercicios');
$ruta_url = get_parametro($db, 'ruta_base_videos_ejercicios');

// Si la ruta de sistema de ficheros no está configurada, derivarla desde la URL
if ($ruta_fs === '') {
    if ($ruta_url !== '') {
        $parsed = parse_url($ruta_url);
        $path   = isset($parsed['path']) ? $parsed['path'] : '';
        if ($path !== '') {
            $doc_root = rtrim($_SERVER['DOCUMENT_ROOT'], '/\\');
            $ruta_fs  = $doc_root . '/' . ltrim($path, '/');
        }
    }
}

if ($ruta_fs === '') {
    http_response_code(500);
    ob_clean();
    echo json_encode([
        "error" => "No está configurada la ruta de subida de vídeos. " .
                   "Define el parámetro 'ruta_fs_videos_ejercicios' con la ruta " .
                   "absoluta del sistema de ficheros en el servidor."
    ]);
    exit();
}

// Normalizar separadores y asegurar barra final
$ruta_fs = rtrim(str_replace('\\', '/', $ruta_fs), '/') . '/';

// ── Validar fichero subido ─────────────────────────────────────────────────

if (empty($_FILES['video'])) {
    http_response_code(400);
    ob_clean();
    echo json_encode(["error" => "No se proporcionó ningún archivo (campo 'video')"]);
    exit();
}

$file = $_FILES['video'];

if ($file['error'] !== UPLOAD_ERR_OK) {
    $upload_errors = [
        UPLOAD_ERR_INI_SIZE   => 'El fichero supera upload_max_filesize de php.ini',
        UPLOAD_ERR_FORM_SIZE  => 'El fichero supera MAX_FILE_SIZE del formulario',
        UPLOAD_ERR_PARTIAL    => 'El fichero se subió solo parcialmente',
        UPLOAD_ERR_NO_FILE    => 'No se subió ningún fichero',
        UPLOAD_ERR_NO_TMP_DIR => 'Falta la carpeta temporal',
        UPLOAD_ERR_CANT_WRITE => 'Error al escribir el fichero en disco',
        UPLOAD_ERR_EXTENSION  => 'Una extensión PHP detuvo la subida',
    ];
    $msg = $upload_errors[$file['error']] ?? 'Error desconocido (' . $file['error'] . ')';
    http_response_code(400);
    ob_clean();
    echo json_encode(["error" => "Error en la subida: $msg"]);
    exit();
}

// ── Sanitizar nombre del fichero ──────────────────────────────────────────

function sanitize_filename(string $name): string {
    $name = basename($name);                              // sin rutas
    $name = mb_convert_encoding($name, 'UTF-8', 'auto'); // normalizar encoding
    $name = preg_replace('/\s+/', '_', $name);           // espacios → _
    $name = preg_replace('/[^A-Za-z0-9._\-]/', '', $name); // solo caracteres seguros
    $name = preg_replace('/\.{2,}/', '.', $name);        // evitar ..
    $name = trim($name, '.-_');
    return $name !== '' ? $name : 'video_' . time();
}

$original_name = sanitize_filename($file['name']);

// Comprobar extensión permitida
$allowed_extensions = ['mp4', 'webm', 'mov', 'avi', 'mkv', 'gif'];
$dot_pos  = strrpos($original_name, '.');
$ext      = $dot_pos !== false ? strtolower(substr($original_name, $dot_pos + 1)) : '';
if (!in_array($ext, $allowed_extensions)) {
    http_response_code(400);
    ob_clean();
    echo json_encode(["error" => "Extensión no permitida: '$ext'. Permitidas: " . implode(', ', $allowed_extensions)]);
    exit();
}

// ── Preparar carpeta de destino ───────────────────────────────────────────

$subcarpeta = trim($_POST['subcarpeta'] ?? '');

// Sanitizar subcarpeta: solo letras, números, guiones, barras y puntos
$subcarpeta = preg_replace('/[^A-Za-z0-9._\-\/]/', '', $subcarpeta);
$subcarpeta = trim($subcarpeta, '/');

if ($subcarpeta !== '') {
    $destino_dir = $ruta_fs . $subcarpeta . '/';
} else {
    $destino_dir = $ruta_fs;
}

// Crear directorio si no existe
if (!is_dir($destino_dir)) {
    if (!mkdir($destino_dir, 0775, true)) {
        http_response_code(500);
        ob_clean();
        echo json_encode(["error" => "No se pudo crear la carpeta: $destino_dir"]);
        exit();
    }
}

// ── Mover el fichero ──────────────────────────────────────────────────────

// Si ya existe un fichero con ese nombre, añadir sufijo numérico
$destino_fichero = $destino_dir . $original_name;
if (file_exists($destino_fichero)) {
    $base = $dot_pos !== false ? substr($original_name, 0, $dot_pos) : $original_name;
    $i    = 1;
    do {
        $destino_fichero = $destino_dir . $base . '_' . $i . ($ext !== '' ? ".$ext" : '');
        $i++;
    } while (file_exists($destino_fichero) && $i < 1000);
    $original_name = basename($destino_fichero);
}

if (!move_uploaded_file($file['tmp_name'], $destino_fichero)) {
    http_response_code(500);
    ob_clean();
    echo json_encode(["error" => "No se pudo mover el fichero al destino: $destino_fichero"]);
    exit();
}

// ── Responder con la ruta relativa para guardar en BD ────────────────────

$ruta_video = $subcarpeta !== ''
    ? $subcarpeta . '/' . $original_name
    : $original_name;

ob_clean();
echo json_encode([
    "ruta_video"      => $ruta_video,
    "nombre_fichero"  => $original_name,
    "subcarpeta"      => $subcarpeta,
    "mensaje"         => "Vídeo subido correctamente"
]);
