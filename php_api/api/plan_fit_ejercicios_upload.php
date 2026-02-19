<?php
/**
 * Endpoint especifico para carga de fotos del catalogo de ejercicios (multipart).
 * Separado para evitar restricciones de Apache en multipart.
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);
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

// Validar token
$validator = new AutoValidator($db);
$user = $validator->validate();
PermissionManager::checkPermission($user, 'planes_fit');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(array("error" => "Solo POST permitido"));
    exit();
}

try {
    if (!isset($_FILES['foto']) || $_FILES['foto']['error'] !== UPLOAD_ERR_OK) {
        http_response_code(400);
        echo json_encode(array("error" => "No se proporciono foto valida"));
        exit();
    }

    $foto_blob = file_get_contents($_FILES['foto']['tmp_name']);
    $foto_nombre = !empty($_POST['foto_nombre'])
        ? $_POST['foto_nombre']
        : $_FILES['foto']['name'];

    $codigo = isset($_POST['codigo']) ? intval($_POST['codigo']) : 0;
    $nombre = trim($_POST['nombre'] ?? '');
    if ($nombre === '') {
        http_response_code(400);
        echo json_encode(array("error" => "El nombre es obligatorio."));
        exit();
    }

    $instrucciones = $_POST['instrucciones'] ?? null;
    $url_video = $_POST['url_video'] ?? null;
    $tiempo = isset($_POST['tiempo']) && $_POST['tiempo'] !== '' ? intval($_POST['tiempo']) : null;
    $descanso = isset($_POST['descanso']) && $_POST['descanso'] !== '' ? intval($_POST['descanso']) : null;
    $repeticiones = isset($_POST['repeticiones']) && $_POST['repeticiones'] !== '' ? intval($_POST['repeticiones']) : null;
    $kilos = isset($_POST['kilos']) && $_POST['kilos'] !== '' ? intval($_POST['kilos']) : null;

    if ($codigo > 0) {
        $stmt = $db->prepare("SELECT codigo FROM nu_plan_fit_ejercicios_catalogo WHERE LOWER(nombre) = LOWER(:nombre) AND codigo <> :codigo LIMIT 1");
        $stmt->bindParam(':nombre', $nombre);
        $stmt->bindParam(':codigo', $codigo);
        $stmt->execute();
        if ($stmt->fetch(PDO::FETCH_ASSOC)) {
            http_response_code(409);
            ob_clean();
            echo json_encode(array("message" => "Ya existe un ejercicio con ese nombre."));
            exit();
        }

        $codusuariom = isset($_POST['codusuariom']) ? intval($_POST['codusuariom']) : 1;
        $query = "UPDATE nu_plan_fit_ejercicios_catalogo
                  SET nombre = :nombre,
                      instrucciones = :instrucciones,
                      url_video = :url_video,
                      tiempo = :tiempo,
                      descanso = :descanso,
                      repeticiones = :repeticiones,
                      kilos = :kilos,
                      foto = :foto,
                      foto_nombre = :foto_nombre,
                      codusuariom = :codusuariom,
                      fecham = NOW()
                  WHERE codigo = :codigo";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':nombre', $nombre);
        $stmt->bindParam(':instrucciones', $instrucciones);
        $stmt->bindParam(':url_video', $url_video);
        $stmt->bindParam(':tiempo', $tiempo);
        $stmt->bindParam(':descanso', $descanso);
        $stmt->bindParam(':repeticiones', $repeticiones);
        $stmt->bindParam(':kilos', $kilos);
        $stmt->bindParam(':foto', $foto_blob, PDO::PARAM_LOB);
        $stmt->bindParam(':foto_nombre', $foto_nombre);
        $stmt->bindParam(':codusuariom', $codusuariom, PDO::PARAM_INT);
        $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);

        if ($stmt->execute()) {
            if (isset($_POST['categorias'])) {
                $stmtDel = $db->prepare("DELETE FROM nu_plan_fit_ejercicios_categorias WHERE codigo_ejercicio = :codigo");
                $stmtDel->bindParam(':codigo', $codigo);
                $stmtDel->execute();

                $categorias = json_decode($_POST['categorias'], true);
                if (is_array($categorias) && !empty($categorias)) {
                    $stmtCat = $db->prepare("INSERT INTO nu_plan_fit_ejercicios_categorias (codigo_ejercicio, codigo_categoria) VALUES (:codigo_ejercicio, :codigo_categoria)");
                    foreach ($categorias as $codigo_categoria) {
                        $codigo_categoria_int = intval($codigo_categoria);
                        $stmtCat->bindParam(':codigo_ejercicio', $codigo, PDO::PARAM_INT);
                        $stmtCat->bindValue(':codigo_categoria', $codigo_categoria_int, PDO::PARAM_INT);
                        $stmtCat->execute();
                    }
                }
            }

            http_response_code(200);
            ob_clean();
            echo json_encode(array("message" => "Ejercicio del catalogo actualizado."));
        } else {
            http_response_code(503);
            ob_clean();
            echo json_encode(array("error" => "No se pudo actualizar el ejercicio del catalogo."));
        }
        exit();
    }

    $stmt = $db->prepare("SELECT codigo FROM nu_plan_fit_ejercicios_catalogo WHERE LOWER(nombre) = LOWER(:nombre) LIMIT 1");
    $stmt->bindParam(':nombre', $nombre);
    $stmt->execute();
    if ($stmt->fetch(PDO::FETCH_ASSOC)) {
        http_response_code(409);
        ob_clean();
        echo json_encode(array("message" => "Ya existe un ejercicio con ese nombre."));
        exit();
    }

    $codusuarioa = isset($_POST['codusuarioa']) ? intval($_POST['codusuarioa']) : 1;
    $query = "INSERT INTO nu_plan_fit_ejercicios_catalogo
              (nombre, instrucciones, url_video, foto, foto_nombre, tiempo, descanso, repeticiones, kilos, codusuarioa, fechaa)
              VALUES (:nombre, :instrucciones, :url_video, :foto, :foto_nombre, :tiempo, :descanso, :repeticiones, :kilos, :codusuarioa, NOW())";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':instrucciones', $instrucciones);
    $stmt->bindParam(':url_video', $url_video);
    $stmt->bindParam(':foto', $foto_blob, PDO::PARAM_LOB);
    $stmt->bindParam(':foto_nombre', $foto_nombre);
    $stmt->bindParam(':tiempo', $tiempo);
    $stmt->bindParam(':descanso', $descanso);
    $stmt->bindParam(':repeticiones', $repeticiones);
    $stmt->bindParam(':kilos', $kilos);
    $stmt->bindParam(':codusuarioa', $codusuarioa, PDO::PARAM_INT);

    if ($stmt->execute()) {
        $codigo_ejercicio = $db->lastInsertId();

        if (isset($_POST['categorias'])) {
            $categorias = json_decode($_POST['categorias'], true);
            if (is_array($categorias) && !empty($categorias)) {
                $stmtCat = $db->prepare("INSERT INTO nu_plan_fit_ejercicios_categorias (codigo_ejercicio, codigo_categoria) VALUES (:codigo_ejercicio, :codigo_categoria)");
                foreach ($categorias as $codigo_categoria) {
                    $codigo_categoria_int = intval($codigo_categoria);
                    $stmtCat->bindParam(':codigo_ejercicio', $codigo_ejercicio, PDO::PARAM_INT);
                    $stmtCat->bindValue(':codigo_categoria', $codigo_categoria_int, PDO::PARAM_INT);
                    $stmtCat->execute();
                }
            }
        }

        http_response_code(201);
        ob_clean();
        echo json_encode(array("message" => "Ejercicio del catalogo creado.", "codigo" => $codigo_ejercicio));
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(array("error" => "No se pudo crear el ejercicio del catalogo."));
    }
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(array(
        "error" => "Error interno del servidor",
        "details" => $e->getMessage()
    ));
}

?>