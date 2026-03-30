<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

include_once '../config/database.php';
include_once '../auth/token_validator.php';
include_once '../auth/permissions.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

ensure_alimento_categoria_rel_table();

$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'planes_nutricionales');

$method = $_SERVER['REQUEST_METHOD'];

// Parse JSON input if Content-Type is application/json
$data = [];
if ($method === 'POST' || $method === 'DELETE') {
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    if (strpos($contentType, 'application/json') !== false) {
        $input = file_get_contents('php://input');
        $data = json_decode($input, true) ?? [];
    } else {
        $data = $_POST;
    }
}

switch ($method) {
    case 'GET':
        get_alimentos();
        break;
    case 'POST':
        if (!empty($data['codigo']) && intval($data['codigo']) > 0) {
            update_alimento($data);
        } else {
            create_alimento($data);
        }
        break;
    case 'DELETE':
        delete_alimento($data);
        break;
    default:
        http_response_code(405);
        echo json_encode(["message" => "Metodo no permitido."]);
        break;
}

function get_alimentos() {
    global $db;

    $codigo_alimento_planes = isset($_GET['codigo_alimento_planes'])
        ? intval($_GET['codigo_alimento_planes'])
        : 0;
    if ($codigo_alimento_planes > 0) {
        get_planes_for_alimento($codigo_alimento_planes);
        return;
    }

    $search = trim($_GET['search'] ?? '');
    $codigo_grupo = isset($_GET['codigo_grupo']) && $_GET['codigo_grupo'] !== '' ? intval($_GET['codigo_grupo']) : null;
    $codigo_grupos_raw = trim($_GET['codigo_grupos'] ?? '');
    $solo_activos = isset($_GET['solo_activos']) ? intval($_GET['solo_activos']) : null;

    $codigo_grupos = [];
    if ($codigo_grupos_raw !== '') {
        $codigo_grupos = array_values(array_unique(array_filter(array_map(
            'intval',
            explode(',', $codigo_grupos_raw)
        ), function($v) {
            return $v > 0;
        })));
    }
    if ($codigo_grupo !== null && $codigo_grupo > 0 && !in_array($codigo_grupo, $codigo_grupos, true)) {
        $codigo_grupos[] = $codigo_grupo;
    }

    // Detect whether Harvard table exists to avoid query errors on fresh installs
    $harvardJoin = '';
    $harvardSelect = "NULL AS harvard_categoria,
                     NULL AS harvard_nombre,
                     NULL AS harvard_color,
                     NULL AS harvard_seccion,
                     NULL AS harvard_recomendado,
                     '' AS harvard_categorias,
                     '' AS harvard_categorias_nombres";
    try {
        $chk = $db->query("SHOW TABLES LIKE 'nu_alimento_harvard_tag'");
        if ($chk && $chk->rowCount() > 0) {
            $harvardJoin = "LEFT JOIN nu_alimento_harvard_tag ht ON ht.codigo_alimento = a.codigo AND ht.es_primario = 1
              LEFT JOIN nu_harvard_categoria hc ON hc.codigo = ht.codigo_categoria
              LEFT JOIN nu_alimento_harvard_tag hta ON hta.codigo_alimento = a.codigo
              LEFT JOIN nu_harvard_categoria hca ON hca.codigo = hta.codigo_categoria";
                        $harvardSelect = "ht.codigo_categoria AS harvard_categoria,
                                         COALESCE(hc.nombre, '') AS harvard_nombre,
                                         COALESCE(hc.color_hex, '') AS harvard_color,
                                         COALESCE(hc.seccion_plato, '') AS harvard_seccion,
                                         COALESCE(hc.es_recomendado, 1) AS harvard_recomendado,
                                         COALESCE(GROUP_CONCAT(hta.codigo_categoria ORDER BY hta.es_primario DESC, hta.codigo_categoria SEPARATOR ','), '') AS harvard_categorias,
                                         COALESCE(GROUP_CONCAT(hca.nombre ORDER BY hta.es_primario DESC, hca.nombre SEPARATOR ','), '') AS harvard_categorias_nombres";
        }
    } catch (Exception $e) {}

    $query = "SELECT a.codigo,
                     a.nombre,
                     a.codigo_grupo,
                     g.nombre AS nombre_grupo,
                     GROUP_CONCAT(DISTINCT ag.codigo_grupo ORDER BY ag.codigo_grupo SEPARATOR ',') AS categorias_ids,
                     GROUP_CONCAT(DISTINCT gc.nombre ORDER BY gc.nombre SEPARATOR ',') AS categorias_nombres,
                     a.activo,
                     a.observacion,
                     a.fecha_alta,
                     a.fechaa,
                     a.codigousuarioa,
                     a.fecham,
                     a.codusuariom,
                a.opcion,
                COALESCE(ui.total_ingestas, 0) AS total_ingestas,
                $harvardSelect
              FROM nu_alimento a
              LEFT JOIN nu_alimento_grupo g ON g.codigo = a.codigo_grupo
              LEFT JOIN nu_alimento_categoria_rel ag ON ag.codigo_alimento = a.codigo
              LEFT JOIN nu_alimento_grupo gc ON gc.codigo = ag.codigo_grupo
            LEFT JOIN (
                  SELECT codigo_alimento,
                      COUNT(DISTINCT codigo_plan_nutricional_dia_ingesta) AS total_ingestas
                  FROM nu_plan_nutricional_ingesta_item
                  WHERE codigo_alimento IS NOT NULL
                  GROUP BY codigo_alimento
            ) ui ON ui.codigo_alimento = a.codigo
              $harvardJoin
              WHERE 1=1";

    $bind = [];

    if ($search !== '') {
      $query .= " AND a.nombre LIKE :search";
      $bind[':search'] = '%' . $search . '%';
    }

        if (!empty($codigo_grupos)) {
            $placeholders = [];
            foreach ($codigo_grupos as $idx => $grupo_id) {
                $ph = ':codigo_grupo_' . $idx;
                $placeholders[] = $ph;
                $bind[$ph] = $grupo_id;
            }
            $query .= " AND EXISTS (
                                        SELECT 1
                                        FROM nu_alimento_categoria_rel agf
                                        WHERE agf.codigo_alimento = a.codigo
                                            AND agf.codigo_grupo IN (" . implode(',', $placeholders) . ")
                                    )";
    }

    if ($solo_activos === 1) {
      $query .= " AND IFNULL(a.activo, 1) = 1";
    }

    $query .= " GROUP BY a.codigo ORDER BY a.nombre";

    $stmt = $db->prepare($query);
    foreach ($bind as $key => $val) {
        $stmt->bindValue($key, $val);
    }
    $stmt->execute();

    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items ?? []);
}

function get_planes_for_alimento($codigo_alimento) {
    global $db;

    $query = "SELECT p.codigo,
                     p.codigo_paciente,
                     p.titulo_plan,
                     p.objetivo_plan,
                     p.desde,
                     p.hasta,
                     p.semanas,
                     p.total_semanas,
                     p.usa_estructura_detallada,
                     p.completado,
                     p.codigo_entrevista,
                     p.plan_documento_nombre,
                     p.plan_indicaciones,
                     p.plan_indicaciones_visible_usuario,
                     p.url,
                     p.fechaa,
                     pa.nombre AS nombre_paciente
              FROM nu_plan_nutricional p
              LEFT JOIN nu_paciente pa ON pa.codigo = p.codigo_paciente
              WHERE EXISTS (
                  SELECT 1
                  FROM nu_plan_nutricional_semana s
                  INNER JOIN nu_plan_nutricional_semana_dia d
                          ON d.codigo_plan_nutricional_semana = s.codigo
                  INNER JOIN nu_plan_nutricional_dia_ingesta i
                          ON i.codigo_plan_nutricional_semana_dia = d.codigo
                  INNER JOIN nu_plan_nutricional_ingesta_item ii
                          ON ii.codigo_plan_nutricional_dia_ingesta = i.codigo
                  WHERE s.codigo_plan_nutricional = p.codigo
                    AND ii.codigo_alimento = :codigo_alimento
              )
              ORDER BY p.desde DESC, p.codigo DESC";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_alimento', $codigo_alimento, PDO::PARAM_INT);
    $stmt->execute();

    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    ob_clean();
    echo json_encode($items ?? []);
}

function create_alimento($data) {
    global $db, $user;

    $nombre = trim($data['nombre'] ?? '');
    $codigo_grupo = isset($data['codigo_grupo']) && $data['codigo_grupo'] !== '' ? intval($data['codigo_grupo']) : null;
    $codigo_grupos = parse_codigo_grupos($data, $codigo_grupo);
    $codigo_grupo = !empty($codigo_grupos) ? intval($codigo_grupos[0]) : null;
    $activo = isset($data['activo']) ? intval($data['activo']) : 1;
    $observacion = trim($data['observacion'] ?? '');
    $opcion = in_array(strtoupper(trim($data['opcion'] ?? '')), ['S', 'N']) ? strtoupper(trim($data['opcion'])) : null;
    $codusuarioa = isset($data['codigousuarioa']) ? intval($data['codigousuarioa']) : intval($user['codigo'] ?? 0);

    if ($nombre === '') {
        http_response_code(400);
        echo json_encode(["message" => "El nombre es obligatorio."]);
        return;
    }

    if (alimento_nombre_exists($nombre)) {
        http_response_code(409);
        ob_clean();
        echo json_encode(["message" => "Ya existe un alimento con ese nombre."]);
        return;
    }

    $query = "INSERT INTO nu_alimento (nombre, codigo_grupo, activo, observacion, opcion, fecha_alta, codigousuarioa, fechaa)
              VALUES (:nombre, :codigo_grupo, :activo, :observacion, :opcion, NOW(), :codigousuarioa, NOW())";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':codigo_grupo', $codigo_grupo);
    $stmt->bindParam(':activo', $activo);
    $stmt->bindParam(':observacion', $observacion);
    $stmt->bindParam(':opcion', $opcion);
    $stmt->bindParam(':codigousuarioa', $codusuarioa);

    if ($stmt->execute()) {
        $codigo_alimento = intval($db->lastInsertId());
        sync_alimento_grupos($codigo_alimento, $codigo_grupos, $codusuarioa);
        $harvard_categoria = trim($data['harvard_categoria'] ?? '');
        $harvard_categorias = parse_harvard_categorias($data, $harvard_categoria);
        sync_harvard_tags($codigo_alimento, $harvard_categorias, $codusuarioa);
        http_response_code(201);
        ob_clean();
        echo json_encode(["message" => "Alimento creado.", "codigo" => $codigo_alimento]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "No se pudo crear el alimento.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function update_alimento($data) {
    global $db, $user;

    $codigo = intval($data['codigo'] ?? 0);
    $nombre = trim($data['nombre'] ?? '');
    $codigo_grupo = isset($data['codigo_grupo']) && $data['codigo_grupo'] !== '' ? intval($data['codigo_grupo']) : null;
    $codigo_grupos = parse_codigo_grupos($data, $codigo_grupo);
    $codigo_grupo = !empty($codigo_grupos) ? intval($codigo_grupos[0]) : null;
    $activo = isset($data['activo']) ? intval($data['activo']) : 1;
    $observacion = trim($data['observacion'] ?? '');
    $opcion = in_array(strtoupper(trim($data['opcion'] ?? '')), ['S', 'N']) ? strtoupper(trim($data['opcion'])) : null;
    $codusuariom = isset($data['codusuariom']) ? intval($data['codusuariom']) : intval($user['codigo'] ?? 0);

    if ($codigo === 0 || $nombre === '') {
        http_response_code(400);
        echo json_encode(["message" => "Codigo y nombre son obligatorios."]);
        return;
    }

    if (alimento_nombre_exists($nombre, $codigo)) {
        http_response_code(409);
        ob_clean();
        echo json_encode(["message" => "No se puede modificar el nombre del alimento porque ya existe."]);
        return;
    }

    $query = "UPDATE nu_alimento
              SET nombre = :nombre,
                  codigo_grupo = :codigo_grupo,
                  activo = :activo,
                  observacion = :observacion,
                  opcion = :opcion,
                  codusuariom = :codusuariom,
                  fecham = NOW()
              WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);
    $stmt->bindParam(':nombre', $nombre);
    $stmt->bindParam(':codigo_grupo', $codigo_grupo);
    $stmt->bindParam(':activo', $activo);
    $stmt->bindParam(':observacion', $observacion);
    $stmt->bindParam(':opcion', $opcion);
    $stmt->bindParam(':codusuariom', $codusuariom);

    if ($stmt->execute()) {
        sync_alimento_grupos($codigo, $codigo_grupos, $codusuariom);
        $harvard_categoria = trim($data['harvard_categoria'] ?? '');
        $harvard_categorias = parse_harvard_categorias($data, $harvard_categoria);
        sync_harvard_tags($codigo, $harvard_categorias, $codusuariom);
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Alimento actualizado."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "No se pudo actualizar el alimento.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function delete_alimento($data) {
    global $db;

    $codigo = isset($data['codigo']) ? intval($data['codigo']) : 0;
    if ($codigo === 0) {
        http_response_code(400);
        echo json_encode(["message" => "Codigo invalido."]);
        return;
    }

    // Bloquear si el alimento está en algún plan nutricional
    $stmtUso = $db->prepare("SELECT COUNT(*) AS total FROM nu_plan_nutricional_ingesta_item WHERE codigo_alimento = :codigo");
    $stmtUso->bindParam(':codigo', $codigo, PDO::PARAM_INT);
    $stmtUso->execute();
    $uso = $stmtUso->fetch(PDO::FETCH_ASSOC);
    if (intval($uso['total'] ?? 0) > 0) {
        http_response_code(409);
        ob_clean();
        echo json_encode(["message" => "No se puede eliminar el alimento porque está incluido en uno o más planes nutricionales."]);
        return;
    }

    $query = "DELETE FROM nu_alimento WHERE codigo = :codigo";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo', $codigo);

    if ($stmt->execute()) {
        http_response_code(200);
        ob_clean();
        echo json_encode(["message" => "Alimento eliminado."]);
    } else {
        http_response_code(503);
        ob_clean();
        echo json_encode(["message" => "No se pudo eliminar el alimento.", "errorInfo" => $stmt->errorInfo()]);
    }
}

function ensure_alimento_categoria_rel_table() {
    global $db;
    $db->exec("CREATE TABLE IF NOT EXISTS nu_alimento_categoria_rel (
        codigo_alimento INT NOT NULL,
        codigo_grupo INT NOT NULL,
        fechaa DATETIME DEFAULT NULL,
        codusuarioa INT DEFAULT NULL,
        PRIMARY KEY (codigo_alimento, codigo_grupo),
        KEY idx_alimento_categoria_rel_grupo (codigo_grupo),
        CONSTRAINT alimento_categoria_rel_alimento_fk
            FOREIGN KEY (codigo_alimento) REFERENCES nu_alimento(codigo)
            ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT alimento_categoria_rel_grupo_fk
            FOREIGN KEY (codigo_grupo) REFERENCES nu_alimento_grupo(codigo)
            ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    // Backfill idempotente desde columna legacy
    $db->exec("INSERT INTO nu_alimento_categoria_rel (codigo_alimento, codigo_grupo, fechaa, codusuarioa)
               SELECT a.codigo, a.codigo_grupo, NOW(), COALESCE(a.codigousuarioa, 1)
               FROM nu_alimento a
               WHERE a.codigo_grupo IS NOT NULL
               ON DUPLICATE KEY UPDATE
                 fechaa = VALUES(fechaa),
                 codusuarioa = VALUES(codusuarioa)");
}

function parse_codigo_grupos($data, $fallback_codigo_grupo = null) {
    $codigo_grupos = [];

    if (isset($data['codigo_grupos'])) {
        $raw = $data['codigo_grupos'];
        if (is_array($raw)) {
            $codigo_grupos = $raw;
        } else {
            $raw_text = trim((string)$raw);
            if ($raw_text !== '') {
                $codigo_grupos = explode(',', $raw_text);
            }
        }
    }

    $codigo_grupos = array_values(array_unique(array_filter(array_map('intval', $codigo_grupos), function($value) {
        return $value > 0;
    })));

    $fallback = intval($fallback_codigo_grupo ?? 0);
    if ($fallback > 0 && !in_array($fallback, $codigo_grupos, true)) {
        $codigo_grupos[] = $fallback;
    }

    return $codigo_grupos;
}

function parse_harvard_categorias($data, $fallback_categoria = null) {
    $categorias = [];

    if (isset($data['harvard_categorias'])) {
        $raw = $data['harvard_categorias'];
        if (is_array($raw)) {
            $categorias = $raw;
        } else {
            $raw_text = trim((string)$raw);
            if ($raw_text !== '') {
                $categorias = explode(',', $raw_text);
            }
        }
    }

    $categorias = array_values(array_unique(array_filter(array_map(function($v) {
        return trim((string)$v);
    }, $categorias), function($v) {
        return $v !== '';
    })));

    $fallback = trim((string)($fallback_categoria ?? ''));
    if ($fallback !== '' && !in_array($fallback, $categorias, true)) {
        array_unshift($categorias, $fallback);
    }

    return $categorias;
}

function sync_alimento_grupos($codigo_alimento, $codigo_grupos, $codusuarioa) {
    global $db;

    $delete = $db->prepare("DELETE FROM nu_alimento_categoria_rel WHERE codigo_alimento = :codigo_alimento");
    $delete->bindParam(':codigo_alimento', $codigo_alimento, PDO::PARAM_INT);
    $delete->execute();

    if (empty($codigo_grupos)) {
        return;
    }

    $insert = $db->prepare("INSERT INTO nu_alimento_categoria_rel (codigo_alimento, codigo_grupo, fechaa, codusuarioa)
                            VALUES (:codigo_alimento, :codigo_grupo, NOW(), :codusuarioa)");
    foreach ($codigo_grupos as $codigo_grupo) {
        $codigo_grupo = intval($codigo_grupo);
        if ($codigo_grupo <= 0) continue;
        $insert->bindParam(':codigo_alimento', $codigo_alimento, PDO::PARAM_INT);
        $insert->bindParam(':codigo_grupo', $codigo_grupo, PDO::PARAM_INT);
        $insert->bindParam(':codusuarioa', $codusuarioa, PDO::PARAM_INT);
        $insert->execute();
    }
}

function sync_harvard_tags($codigo_alimento, $codigo_categorias, $codusuarioa) {
    global $db;

    // Silently skip if the Harvard table doesn't exist yet
    try {
        $chk = $db->query("SHOW TABLES LIKE 'nu_alimento_harvard_tag'");
        if (!$chk || $chk->rowCount() === 0) return;
    } catch (Exception $e) { return; }

    // Remove existing tags
    $del = $db->prepare("DELETE FROM nu_alimento_harvard_tag WHERE codigo_alimento = :codigo");
    $del->bindParam(':codigo', $codigo_alimento, PDO::PARAM_INT);
    $del->execute();

    if (!is_array($codigo_categorias) || empty($codigo_categorias)) return;

    $chkCat = $db->prepare("SELECT COUNT(*) FROM nu_harvard_categoria WHERE codigo = :cat");
    $ins = $db->prepare(
        "INSERT INTO nu_alimento_harvard_tag (codigo_alimento, codigo_categoria, es_primario, fechaa, codusuarioa)
         VALUES (:codigo, :categoria, :primario, NOW(), :usuario)
         ON DUPLICATE KEY UPDATE es_primario = VALUES(es_primario), fechaa = NOW(), codusuarioa = VALUES(codusuarioa)"
    );

    $isFirst = true;
    foreach ($codigo_categorias as $codigo_categoria) {
        $codigo_categoria = trim((string)$codigo_categoria);
        if ($codigo_categoria === '') continue;

        $chkCat->bindParam(':cat', $codigo_categoria);
        $chkCat->execute();
        if (intval($chkCat->fetchColumn()) === 0) continue;

        $primario = $isFirst ? 1 : 0;
        $ins->bindParam(':codigo', $codigo_alimento, PDO::PARAM_INT);
        $ins->bindParam(':categoria', $codigo_categoria);
        $ins->bindParam(':primario', $primario, PDO::PARAM_INT);
        $ins->bindParam(':usuario', $codusuarioa, PDO::PARAM_INT);
        $ins->execute();
        $isFirst = false;
    }
}

function alimento_nombre_exists($nombre, $exclude_codigo = null) {
    global $db;

    $query = "SELECT COUNT(*) FROM nu_alimento WHERE LOWER(TRIM(nombre)) = LOWER(TRIM(:nombre))";
    $exclude_codigo = intval($exclude_codigo ?? 0);
    if ($exclude_codigo > 0) {
        $query .= " AND codigo <> :codigo";
    }

    $stmt = $db->prepare($query);
    $stmt->bindParam(':nombre', $nombre);
    if ($exclude_codigo > 0) {
        $stmt->bindParam(':codigo', $exclude_codigo, PDO::PARAM_INT);
    }
    $stmt->execute();

    return intval($stmt->fetchColumn()) > 0;
}
?>
