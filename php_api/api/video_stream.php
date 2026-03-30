<?php
/**
 * video_stream.php — Proxy de streaming para archivos de vídeo locales.
 *
 * Sirve vídeos desde php_api/med/ con soporte completo de Range requests
 * (HTTP 206 Partial Content), necesario para que ExoPlayer (Android) y
 * otros reproductores nativos puedan hacer seek y reproducir correctamente.
 *
 * El WAF/ModSecurity del servidor bloquea Range directamente sobre los
 * archivos estáticos (.mp4), pero permite peticiones PHP normales.
 * Este script lee el archivo en disco y sirve los rangos él mismo,
 * evitando el bloqueo del WAF por completo.
 *
 * Uso:
 *   GET /php_api/api/video_stream.php?file=nombre_video.mp4
 *   GET /php_api/api/video_stream.php?file=subcarpeta/nombre_video.mp4
 */

// ── Cabeceras de seguridad básicas ──────────────────────────────────────────
header('X-Content-Type-Options: nosniff');

// ── CORS (necesario para WebView / Flutter web) ──────────────────────────────
$origin = $_SERVER['HTTP_ORIGIN'] ?? '*';
header("Access-Control-Allow-Origin: $origin");
header('Access-Control-Allow-Methods: GET, HEAD, OPTIONS');
header('Access-Control-Allow-Headers: Range, Content-Type, Authorization');
header('Access-Control-Expose-Headers: Content-Range, Content-Length, Accept-Ranges');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit();
}

// ── Solo GET y HEAD ──────────────────────────────────────────────────────────
if (!in_array($_SERVER['REQUEST_METHOD'], ['GET', 'HEAD'], true)) {
    http_response_code(405);
    header('Allow: GET, HEAD, OPTIONS');
    exit();
}

// ── Validar parámetro 'file' ─────────────────────────────────────────────────
$file = $_GET['file'] ?? '';
if ($file === '') {
    http_response_code(400);
    echo json_encode(['error' => 'Parámetro "file" requerido']);
    exit();
}

// Sanitizar: solo se permiten caracteres seguros para nombres de archivo/ruta.
// No se permite ningún componente '..' (prevención de path traversal).
$file = ltrim(str_replace('\\', '/', $file), '/');
$parts = explode('/', $file);
foreach ($parts as $p) {
    if ($p === '' || $p === '.' || $p === '..') {
        http_response_code(400);
        echo json_encode(['error' => 'Ruta de archivo no válida']);
        exit();
    }
}
if (!preg_match('/^[a-zA-Z0-9_\-\.\/]+$/', $file)) {
    http_response_code(400);
    echo json_encode(['error' => 'Nombre de archivo contiene caracteres no permitidos']);
    exit();
}

// Solo extensiones de vídeo permitidas
$ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
$allowedExt = ['mp4', 'm4v', 'webm', 'ogv', 'ogg', 'mov', 'avi', 'mkv'];
if (!in_array($ext, $allowedExt, true)) {
    http_response_code(400);
    echo json_encode(['error' => 'Tipo de archivo no permitido']);
    exit();
}

// ── Resolver ruta absoluta del archivo ───────────────────────────────────────
// Este script está en php_api/api/; los vídeos están en php_api/med/
$medDir = realpath(__DIR__ . '/../med');
if ($medDir === false) {
    http_response_code(500);
    echo json_encode(['error' => 'Directorio de vídeos no encontrado']);
    exit();
}

$filePath = realpath($medDir . '/' . $file);
if ($filePath === false || !file_exists($filePath)) {
    http_response_code(404);
    echo json_encode(['error' => 'Vídeo no encontrado']);
    exit();
}

// Verificar que la ruta resuelta está dentro de $medDir (double-check path traversal)
if (strpos($filePath, $medDir) !== 0) {
    http_response_code(403);
    echo json_encode(['error' => 'Acceso denegado']);
    exit();
}

if (!is_readable($filePath)) {
    http_response_code(403);
    echo json_encode(['error' => 'Archivo no legible']);
    exit();
}

// ── Tipo MIME ────────────────────────────────────────────────────────────────
$mimeMap = [
    'mp4'  => 'video/mp4',
    'm4v'  => 'video/mp4',
    'webm' => 'video/webm',
    'ogv'  => 'video/ogg',
    'ogg'  => 'video/ogg',
    'mov'  => 'video/quicktime',
    'avi'  => 'video/x-msvideo',
    'mkv'  => 'video/x-matroska',
];
$mimeType = $mimeMap[$ext] ?? 'application/octet-stream';

// ── Tamaño del archivo ───────────────────────────────────────────────────────
$fileSize = filesize($filePath);

// ── Procesar cabecera Range ──────────────────────────────────────────────────
$rangeHeader = $_SERVER['HTTP_RANGE'] ?? null;
$start = 0;
$end   = $fileSize - 1;
$isRange = false;

if ($rangeHeader !== null) {
    if (!preg_match('/^bytes=(\d*)-(\d*)$/', trim($rangeHeader), $m)) {
        header('Content-Range: bytes */' . $fileSize);
        http_response_code(416); // Range Not Satisfiable
        exit();
    }

    $reqStart = $m[1] !== '' ? (int)$m[1] : null;
    $reqEnd   = $m[2] !== '' ? (int)$m[2] : null;

    if ($reqStart === null && $reqEnd !== null) {
        // Sufijo: bytes=-500  →  últimos 500 bytes
        $start = max(0, $fileSize - $reqEnd);
        $end   = $fileSize - 1;
    } else {
        $start = $reqStart ?? 0;
        $end   = $reqEnd  ?? ($fileSize - 1);
    }

    // Validar rangos
    if ($start > $end || $start >= $fileSize) {
        header('Content-Range: bytes */' . $fileSize);
        http_response_code(416);
        exit();
    }
    $end   = min($end, $fileSize - 1);
    $isRange = true;
}

$length = $end - $start + 1;

// ── Enviar cabeceras ──────────────────────────────────────────────────────────
if ($isRange) {
    http_response_code(206);
    header("Content-Range: bytes $start-$end/$fileSize");
} else {
    http_response_code(200);
}

header('Content-Type: ' . $mimeType);
header('Content-Length: ' . $length);
header('Accept-Ranges: bytes');
header('Cache-Control: public, max-age=86400');

// Evitar compresión (el vídeo ya está comprimido, gzip lo corrompería)
header('Content-Encoding: identity');

// ── Enviar cuerpo ─────────────────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'HEAD') {
    exit();
}

$fp = @fopen($filePath, 'rb');
if ($fp === false) {
    http_response_code(500);
    echo json_encode(['error' => 'No se pudo abrir el archivo']);
    exit();
}

if ($start > 0) {
    fseek($fp, $start);
}

$bufferSize  = 8192; // 8 KB por chunk
$bytesLeft   = $length;

while ($bytesLeft > 0 && !feof($fp)) {
    $chunk = min($bufferSize, $bytesLeft);
    $data  = fread($fp, $chunk);
    if ($data === false) break;
    echo $data;
    $bytesLeft -= strlen($data);
    flush();
}

fclose($fp);
