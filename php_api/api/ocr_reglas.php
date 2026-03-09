<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With, If-None-Match");

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/permissions.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();
$request_method = $_SERVER['REQUEST_METHOD'];

if ($request_method !== 'GET') {
    $validator = new TokenValidator($db);
    $user = $validator->validateToken();
    PermissionManager::checkPermission($user, 'parametros');
}

switch ($request_method) {
    case 'GET':
        get_ocr_rules();
        break;
    case 'POST':
    case 'PUT':
        save_ocr_rules();
        break;
    default:
        http_response_code(405);
        echo json_encode(array("message" => "Method Not Allowed"));
        break;
}

function get_ocr_rules_table_name() {
    return 'ocr_regla_entrenamiento';
}

function normalize_token($token) {
    $text = mb_strtolower(trim((string)$token), 'UTF-8');
    $text = preg_replace('/\s+/', ' ', $text);
    $text = preg_replace('/[^\p{L}\p{N}\s]/u', '', $text);
    return trim($text);
}

function normalize_tokens($tokens) {
    if (!is_array($tokens)) {
        return array();
    }

    $normalized = array();
    foreach ($tokens as $token) {
        $item = normalize_token($token);
        if ($item !== '' && mb_strlen($item, 'UTF-8') >= 2) {
            $normalized[] = $item;
        }
    }

    $normalized = array_values(array_unique($normalized));
    sort($normalized, SORT_STRING);
    return $normalized;
}

function parse_nullable_decimal($value) {
    if ($value === null || $value === '') {
        return null;
    }

    if (is_string($value)) {
        $value = str_replace(',', '.', trim($value));
    }

    if (!is_numeric($value)) {
        return null;
    }

    return round((float)$value, 3);
}

function get_rules_metadata($db) {
    $table = get_ocr_rules_table_name();

    $sql = "SELECT COUNT(*) AS total, COALESCE(MAX(updated_at), '1970-01-01 00:00:00') AS max_updated_at FROM {$table}";
    $stmt = $db->prepare($sql);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    $total = isset($row['total']) ? (int)$row['total'] : 0;
    $maxUpdatedAt = $row['max_updated_at'] ?? '1970-01-01 00:00:00';
    $etag = sha1($total . '|' . $maxUpdatedAt);

    return array(
        'total' => $total,
        'max_updated_at' => $maxUpdatedAt,
        'etag' => $etag,
    );
}

function get_ocr_rules() {
    global $db;

    $metadata = get_rules_metadata($db);
    $currentEtag = $metadata['etag'];

    header('ETag: "' . $currentEtag . '"');
    header('Cache-Control: public, max-age=300');

    $ifNoneMatch = $_SERVER['HTTP_IF_NONE_MATCH'] ?? null;
    if ($ifNoneMatch !== null) {
        $clean = trim($ifNoneMatch, " \"\t\r\n");
        if ($clean === $currentEtag) {
            http_response_code(304);
            exit();
        }
    }

    $onlyMeta = isset($_GET['summary']) && $_GET['summary'] == '1';
    if ($onlyMeta) {
        echo json_encode(array(
            'version' => $currentEtag,
            'count' => $metadata['total'],
            'updatedAt' => $metadata['max_updated_at'],
        ));
        return;
    }

    $table = get_ocr_rules_table_name();
    $sql = "SELECT tokens_json, azucar_gr, sal_gr, grasas_gr, proteina_gr, porcion_gr, updated_at
            FROM {$table}
            ORDER BY updated_at DESC, id DESC";

    $stmt = $db->prepare($sql);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $rules = array();
    foreach ($rows as $row) {
        $tokens = json_decode($row['tokens_json'] ?? '[]', true);
        if (!is_array($tokens)) {
            $tokens = array();
        }

        $rules[] = array(
            'tokens' => $tokens,
            'azucarGr' => $row['azucar_gr'] !== null ? (float)$row['azucar_gr'] : null,
            'salGr' => $row['sal_gr'] !== null ? (float)$row['sal_gr'] : null,
            'grasasGr' => $row['grasas_gr'] !== null ? (float)$row['grasas_gr'] : null,
            'proteinaGr' => $row['proteina_gr'] !== null ? (float)$row['proteina_gr'] : null,
            'porcionGr' => $row['porcion_gr'] !== null ? (float)$row['porcion_gr'] : null,
            'updatedAtIso' => isset($row['updated_at']) ? date(DATE_ATOM, strtotime($row['updated_at'])) : null,
        );
    }

    echo json_encode(array(
        'version' => $currentEtag,
        'count' => $metadata['total'],
        'updatedAt' => $metadata['max_updated_at'],
        'rules' => $rules,
    ));
}

function save_ocr_rules() {
    global $db;

    $payload = json_decode(file_get_contents('php://input'), true);
    if (!is_array($payload)) {
        http_response_code(400);
        echo json_encode(array('message' => 'JSON inválido'));
        return;
    }

    $rules = $payload['rules'] ?? $payload['entries'] ?? null;
    if (!is_array($rules)) {
        http_response_code(400);
        echo json_encode(array('message' => 'El campo rules/entries es obligatorio y debe ser un array'));
        return;
    }

    $replace = !empty($payload['replace']);
    $userCode = isset($payload['codusuariom']) && is_numeric($payload['codusuariom'])
        ? (int)$payload['codusuariom']
        : null;

    $table = get_ocr_rules_table_name();

    try {
        $db->beginTransaction();

        if ($replace) {
            $db->exec("DELETE FROM {$table}");
        }

        $sql = "INSERT INTO {$table}
                (signature_key, tokens_json, azucar_gr, sal_gr, grasas_gr, proteina_gr, porcion_gr, created_by, updated_by)
                VALUES
                (:signature_key, :tokens_json, :azucar_gr, :sal_gr, :grasas_gr, :proteina_gr, :porcion_gr, :created_by, :updated_by)
                ON DUPLICATE KEY UPDATE
                    tokens_json = VALUES(tokens_json),
                    azucar_gr = VALUES(azucar_gr),
                    sal_gr = VALUES(sal_gr),
                    grasas_gr = VALUES(grasas_gr),
                    proteina_gr = VALUES(proteina_gr),
                    porcion_gr = VALUES(porcion_gr),
                    updated_by = VALUES(updated_by),
                    updated_at = CURRENT_TIMESTAMP";

        $stmt = $db->prepare($sql);
        $processed = 0;

        foreach ($rules as $rule) {
            if (!is_array($rule)) {
                continue;
            }

            $tokens = normalize_tokens($rule['tokens'] ?? array());
            if (empty($tokens)) {
                continue;
            }

            $signatureString = implode('|', $tokens);
            $signatureKey = sha1($signatureString);
            $tokensJson = json_encode($tokens, JSON_UNESCAPED_UNICODE);

            $azucarGr = parse_nullable_decimal($rule['azucarGr'] ?? null);
            $salGr = parse_nullable_decimal($rule['salGr'] ?? null);
            $grasasGr = parse_nullable_decimal($rule['grasasGr'] ?? null);
            $proteinaGr = parse_nullable_decimal($rule['proteinaGr'] ?? null);
            $porcionGr = parse_nullable_decimal($rule['porcionGr'] ?? null);

            $stmt->bindParam(':signature_key', $signatureKey);
            $stmt->bindParam(':tokens_json', $tokensJson);
            $stmt->bindParam(':azucar_gr', $azucarGr);
            $stmt->bindParam(':sal_gr', $salGr);
            $stmt->bindParam(':grasas_gr', $grasasGr);
            $stmt->bindParam(':proteina_gr', $proteinaGr);
            $stmt->bindParam(':porcion_gr', $porcionGr);
            $stmt->bindParam(':created_by', $userCode);
            $stmt->bindParam(':updated_by', $userCode);
            $stmt->execute();

            $processed++;
        }

        $db->commit();

        $metadata = get_rules_metadata($db);

        echo json_encode(array(
            'message' => 'Reglas OCR guardadas',
            'processed' => $processed,
            'version' => $metadata['etag'],
            'count' => $metadata['total'],
            'updatedAt' => $metadata['max_updated_at'],
        ));
    } catch (Exception $e) {
        if ($db->inTransaction()) {
            $db->rollBack();
        }

        http_response_code(500);
        echo json_encode(array(
            'message' => 'Error guardando reglas OCR',
            'details' => $e->getMessage(),
        ));
    }
}
?>
