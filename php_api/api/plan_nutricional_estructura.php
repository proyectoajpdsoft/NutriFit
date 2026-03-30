<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

register_shutdown_function(function () {
    $error = error_get_last();
    if (!$error) {
        return;
    }

    $fatal_types = array(E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR, E_USER_ERROR);
    if (!in_array($error['type'], $fatal_types, true)) {
        return;
    }

    if (!headers_sent()) {
        http_response_code(500);
        header("Content-Type: application/json; charset=UTF-8");
    }

    if (function_exists('ob_get_level')) {
        while (ob_get_level() > 0) {
            ob_end_clean();
        }
    }

    echo json_encode(array(
        'message' => 'Error fatal en plan_nutricional_estructura.php',
        'error' => $error['message'],
        'file' => basename($error['file']),
        'line' => intval($error['line'])
    ));
});

include_once '../config/database.php';
include_once '../auth/auto_validator.php';
include_once '../auth/permissions.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

$validator = new AutoValidator($db);
$user = $validator->validate();
PermissionManager::checkPermission($user, 'planes_nutricionales');

$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {
    case 'GET':
        get_estructura();
        break;
    case 'POST':
        save_estructura();
        break;
    default:
        http_response_code(405);
        echo json_encode(["message" => "Metodo no permitido."]);
        break;
}

function is_profesional($user) {
    return (($user['administrador'] ?? 'N') === 'S') || empty($user['codigo_paciente']);
}

function validar_plan_visible_usuario($plan, $user) {
    if (($user['administrador'] ?? 'N') === 'S') {
        return true;
    }

    $codigoPacienteUsuario = intval($user['codigo_paciente'] ?? 0);
    $codigoPacientePlan = intval($plan['codigo_paciente'] ?? 0);

    if ($codigoPacienteUsuario > 0 && $codigoPacienteUsuario === $codigoPacientePlan) {
        return true;
    }

    if (empty($user['codigo_paciente'])) {
        return true;
    }

    return false;
}

function get_plan_basico($codigo_plan_nutricional) {
    global $db;
    $stmt = $db->prepare("SELECT codigo, codigo_paciente, plan_indicaciones, plan_indicaciones_visible_usuario, titulo_plan, objetivo_plan
                          FROM nu_plan_nutricional
                          WHERE codigo = :codigo
                          LIMIT 1");
    $stmt->bindParam(':codigo', $codigo_plan_nutricional, PDO::PARAM_INT);
    $stmt->execute();
    return $stmt->fetch(PDO::FETCH_ASSOC);
}

function assert_table_exists($table_name) {
    global $db;

    $stmt = $db->prepare("SELECT COUNT(*)
                          FROM information_schema.TABLES
                          WHERE TABLE_SCHEMA = DATABASE()
                            AND TABLE_NAME = :table_name");
    $stmt->bindParam(':table_name', $table_name);
    $stmt->execute();
    $exists = intval($stmt->fetchColumn() ?? 0) > 0;

    if (!$exists) {
        throw new Exception("Falta la tabla requerida: $table_name");
    }
}

function assert_columns_exist($table_name, $columns) {
    global $db;

    foreach ($columns as $column_name) {
        $stmt = $db->prepare("SELECT COUNT(*)
                              FROM information_schema.COLUMNS
                              WHERE TABLE_SCHEMA = DATABASE()
                                AND TABLE_NAME = :table_name
                                AND COLUMN_NAME = :column_name");
        $stmt->bindParam(':table_name', $table_name);
        $stmt->bindParam(':column_name', $column_name);
        $stmt->execute();
        $exists = intval($stmt->fetchColumn() ?? 0) > 0;

        if (!$exists) {
            throw new Exception("Falta la columna $table_name.$column_name");
        }
    }
}

function validate_estructura_schema() {
    assert_table_exists('nu_plan_nutricional');
    assert_columns_exist('nu_plan_nutricional', [
        'titulo_plan',
        'objetivo_plan',
        'total_semanas',
        'usa_estructura_detallada',
        'plan_indicaciones',
        'plan_indicaciones_visible_usuario'
    ]);

    assert_table_exists('nu_plan_nutricional_semana');
    assert_columns_exist('nu_plan_nutricional_semana', ['completada']);
    assert_table_exists('nu_plan_nutricional_semana_dia');
    assert_table_exists('nu_plan_nutricional_dia_ingesta');
    assert_table_exists('nu_plan_nutricional_ingesta_item');
    assert_table_exists('nu_plan_nutricional_receta');
}

function get_estructura() {
    global $db, $user;

    $codigo_plan_nutricional = isset($_GET['codigo_plan_nutricional']) ? intval($_GET['codigo_plan_nutricional']) : 0;
    if ($codigo_plan_nutricional === 0) {
        http_response_code(400);
        echo json_encode(["message" => "codigo_plan_nutricional es obligatorio."]);
        return;
    }

    $plan = get_plan_basico($codigo_plan_nutricional);
    if (!$plan) {
        http_response_code(404);
        echo json_encode(["message" => "Plan no encontrado."]);
        return;
    }

    if (!validar_plan_visible_usuario($plan, $user)) {
        http_response_code(403);
        echo json_encode(["message" => "No tienes permiso para ver este plan."]);
        return;
    }

    $stmtRecetas = $db->prepare("SELECT pr.codigo_receta,
                                        r.titulo AS receta_titulo,
                                        pr.orden
                                 FROM nu_plan_nutricional_receta pr
                                 INNER JOIN nu_receta r ON r.codigo = pr.codigo_receta
                                 WHERE pr.codigo_plan_nutricional = :codigo_plan
                                 ORDER BY pr.orden, pr.codigo");
    $stmtRecetas->bindParam(':codigo_plan', $codigo_plan_nutricional, PDO::PARAM_INT);
    $stmtRecetas->execute();
    $recetas = $stmtRecetas->fetchAll(PDO::FETCH_ASSOC);

    $stmtSemanas = $db->prepare("SELECT codigo, numero_semana, titulo, completada, orden
                                 FROM nu_plan_nutricional_semana
                                 WHERE codigo_plan_nutricional = :codigo_plan
                                 ORDER BY orden, numero_semana");
    $stmtSemanas->bindParam(':codigo_plan', $codigo_plan_nutricional, PDO::PARAM_INT);
    $stmtSemanas->execute();
    $semanasRows = $stmtSemanas->fetchAll(PDO::FETCH_ASSOC);

    $semanas = [];
    foreach ($semanasRows as $semana) {
        $codigo_semana = intval($semana['codigo']);

        $stmtDias = $db->prepare("SELECT codigo, dia_semana, nombre_dia, observaciones
                                  FROM nu_plan_nutricional_semana_dia
                                  WHERE codigo_plan_nutricional_semana = :codigo_semana
                                  ORDER BY dia_semana");
        $stmtDias->bindParam(':codigo_semana', $codigo_semana, PDO::PARAM_INT);
        $stmtDias->execute();
        $diasRows = $stmtDias->fetchAll(PDO::FETCH_ASSOC);

        $dias = [];
        foreach ($diasRows as $dia) {
            $codigo_dia = intval($dia['codigo']);
            $stmtIngestas = $db->prepare("SELECT codigo, tipo_ingesta, orden, observaciones
                                          FROM nu_plan_nutricional_dia_ingesta
                                          WHERE codigo_plan_nutricional_semana_dia = :codigo_dia
                                          ORDER BY orden, codigo");
            $stmtIngestas->bindParam(':codigo_dia', $codigo_dia, PDO::PARAM_INT);
            $stmtIngestas->execute();
            $ingestasRows = $stmtIngestas->fetchAll(PDO::FETCH_ASSOC);

            $ingestas = [];
            foreach ($ingestasRows as $ingesta) {
                $codigo_ingesta = intval($ingesta['codigo']);

                // Check whether Harvard tables exist (graceful fallback)
                static $harvardAvailable = null;
                if ($harvardAvailable === null) {
                    try {
                        $chk = $db->query("SHOW TABLES LIKE 'nu_alimento_harvard_tag'");
                        $harvardAvailable = ($chk && $chk->rowCount() > 0);
                    } catch (Exception $e) { $harvardAvailable = false; }
                }

                if ($harvardAvailable) {
                    $stmtItems = $db->prepare("SELECT i.codigo,
                                                      i.codigo_alimento,
                                                      a.nombre AS alimento_nombre,
                                                      i.descripcion_manual,
                                                      i.cantidad,
                                                      i.unidad,
                                                      i.orden,
                                                      i.notas,
                                                      i.opcion,
                                                      ht.codigo_categoria AS harvard_categoria,
                                                      COALESCE(hc.color_hex, '') AS harvard_color,
                                                      COALESCE(hc.seccion_plato, '') AS harvard_seccion
                                               FROM nu_plan_nutricional_ingesta_item i
                                               LEFT JOIN nu_alimento a ON a.codigo = i.codigo_alimento
                                               LEFT JOIN nu_alimento_harvard_tag ht
                                                         ON ht.codigo_alimento = i.codigo_alimento AND ht.es_primario = 1
                                               LEFT JOIN nu_harvard_categoria hc ON hc.codigo = ht.codigo_categoria
                                               WHERE i.codigo_plan_nutricional_dia_ingesta = :codigo_ingesta
                                               ORDER BY i.orden, i.codigo");
                } else {
                    $stmtItems = $db->prepare("SELECT i.codigo,
                                                      i.codigo_alimento,
                                                      a.nombre AS alimento_nombre,
                                                      i.descripcion_manual,
                                                      i.cantidad,
                                                      i.unidad,
                                                      i.orden,
                                                      i.notas,
                                                      i.opcion,
                                                      NULL AS harvard_categoria,
                                                      '' AS harvard_color,
                                                      '' AS harvard_seccion
                                               FROM nu_plan_nutricional_ingesta_item i
                                               LEFT JOIN nu_alimento a ON a.codigo = i.codigo_alimento
                                               WHERE i.codigo_plan_nutricional_dia_ingesta = :codigo_ingesta
                                               ORDER BY i.orden, i.codigo");
                }
                $stmtItems->bindParam(':codigo_ingesta', $codigo_ingesta, PDO::PARAM_INT);
                $stmtItems->execute();
                $items = $stmtItems->fetchAll(PDO::FETCH_ASSOC);

                $ingestas[] = [
                    'codigo' => intval($ingesta['codigo']),
                    'tipo_ingesta' => $ingesta['tipo_ingesta'],
                    'orden' => intval($ingesta['orden'] ?? 0),
                    'observaciones' => $ingesta['observaciones'],
                    'items' => $items ?? []
                ];
            }

            $dias[] = [
                'codigo' => intval($dia['codigo']),
                'dia_semana' => intval($dia['dia_semana']),
                'nombre_dia' => $dia['nombre_dia'],
                'observaciones' => $dia['observaciones'],
                'ingestas' => $ingestas
            ];
        }

        $semanas[] = [
            'codigo' => intval($semana['codigo']),
            'numero_semana' => intval($semana['numero_semana']),
            'orden' => intval($semana['orden'] ?? $semana['numero_semana']),
            'titulo' => $semana['titulo'],
            'completada' => $semana['completada'] ?? 'N',
            'dias' => $dias
        ];
    }

    ob_clean();
    echo json_encode([
        'codigo_plan_nutricional' => intval($plan['codigo']),
        'titulo_plan' => $plan['titulo_plan'],
        'objetivo_plan' => $plan['objetivo_plan'],
        'plan_indicaciones' => $plan['plan_indicaciones'],
        'plan_indicaciones_visible_usuario' => $plan['plan_indicaciones_visible_usuario'],
        'recomendaciones' => $plan['plan_indicaciones_visible_usuario'],
        'recetas' => $recetas ?? [],
        'semanas' => $semanas
    ], JSON_UNESCAPED_UNICODE);
}

function save_estructura() {
    global $db, $user;

    if (!is_profesional($user)) {
        http_response_code(403);
        echo json_encode(["message" => "Solo nutricionistas o administradores pueden editar la estructura del plan."]);
        return;
    }

    $data = json_decode(file_get_contents("php://input"), true);
    $codigo_plan_nutricional = intval($data['codigo_plan_nutricional'] ?? 0);
    if ($codigo_plan_nutricional === 0) {
        http_response_code(400);
        echo json_encode(["message" => "codigo_plan_nutricional es obligatorio."]);
        return;
    }

    $plan = get_plan_basico($codigo_plan_nutricional);
    if (!$plan) {
        http_response_code(404);
        echo json_encode(["message" => "Plan no encontrado."]);
        return;
    }

    $titulo_plan = trim($data['titulo_plan'] ?? '');
    $objetivo_plan = trim($data['objetivo_plan'] ?? '');
    $plan_indicaciones_visible_usuario = trim(
        $data['plan_indicaciones_visible_usuario'] ?? ($data['recomendaciones'] ?? '')
    );
    $recetas = is_array($data['recetas']) ? $data['recetas'] : [];
    $semanas = is_array($data['semanas']) ? $data['semanas'] : [];

    $codusuario = intval($user['codigo'] ?? 0);

    try {
        $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        validate_estructura_schema();

        $db->beginTransaction();

        $stmtPlan = $db->prepare("UPDATE nu_plan_nutricional
                                  SET titulo_plan = :titulo_plan,
                                      objetivo_plan = :objetivo_plan,
                                      plan_indicaciones_visible_usuario = :plan_indicaciones_visible_usuario,
                                      usa_estructura_detallada = 'S',
                                      total_semanas = :total_semanas,
                                      codusuariom = :codusuariom,
                                      fecham = NOW()
                                  WHERE codigo = :codigo");
        $total_semanas = count($semanas);
        $stmtPlan->bindParam(':titulo_plan', $titulo_plan);
        $stmtPlan->bindParam(':objetivo_plan', $objetivo_plan);
        $stmtPlan->bindParam(':plan_indicaciones_visible_usuario', $plan_indicaciones_visible_usuario);
        $stmtPlan->bindParam(':total_semanas', $total_semanas, PDO::PARAM_INT);
        $stmtPlan->bindParam(':codusuariom', $codusuario, PDO::PARAM_INT);
        $stmtPlan->bindParam(':codigo', $codigo_plan_nutricional, PDO::PARAM_INT);
        $stmtPlan->execute();

        $stmtDeleteSemanas = $db->prepare("DELETE FROM nu_plan_nutricional_semana WHERE codigo_plan_nutricional = :codigo_plan");
        $stmtDeleteSemanas->bindParam(':codigo_plan', $codigo_plan_nutricional, PDO::PARAM_INT);
        $stmtDeleteSemanas->execute();

        $stmtDeleteRecetas = $db->prepare("DELETE FROM nu_plan_nutricional_receta WHERE codigo_plan_nutricional = :codigo_plan");
        $stmtDeleteRecetas->bindParam(':codigo_plan', $codigo_plan_nutricional, PDO::PARAM_INT);
        $stmtDeleteRecetas->execute();

        $stmtInsSemana = $db->prepare("INSERT INTO nu_plan_nutricional_semana
          (codigo_plan_nutricional, numero_semana, titulo, completada, orden, codusuarioa, fechaa)
          VALUES (:codigo_plan_nutricional, :numero_semana, :titulo, :completada, :orden, :codusuarioa, NOW())");

        $stmtInsDia = $db->prepare("INSERT INTO nu_plan_nutricional_semana_dia
          (codigo_plan_nutricional_semana, dia_semana, nombre_dia, observaciones, codusuarioa, fechaa)
          VALUES (:codigo_plan_nutricional_semana, :dia_semana, :nombre_dia, :observaciones, :codusuarioa, NOW())");

        $stmtInsIngesta = $db->prepare("INSERT INTO nu_plan_nutricional_dia_ingesta
          (codigo_plan_nutricional_semana_dia, tipo_ingesta, orden, observaciones, codusuarioa, fechaa)
          VALUES (:codigo_plan_nutricional_semana_dia, :tipo_ingesta, :orden, :observaciones, :codusuarioa, NOW())");

        $stmtInsItem = $db->prepare("INSERT INTO nu_plan_nutricional_ingesta_item
          (codigo_plan_nutricional_dia_ingesta, codigo_alimento, descripcion_manual, cantidad, unidad, orden, notas, opcion, codusuarioa, fechaa)
          VALUES (:codigo_plan_nutricional_dia_ingesta, :codigo_alimento, :descripcion_manual, :cantidad, :unidad, :orden, :notas, :opcion, :codusuarioa, NOW())");

        foreach ($semanas as $weekIndex => $semana) {
            $numero_semana = intval($semana['numero_semana'] ?? ($weekIndex + 1));
            $orden_semana = intval($semana['orden'] ?? ($weekIndex + 1));
            $titulo = trim($semana['titulo'] ?? ('Semana ' . $numero_semana));
            $completada = in_array(strtoupper(trim($semana['completada'] ?? 'N')), ['S', 'N'], true)
                ? strtoupper(trim($semana['completada']))
                : 'N';
            $stmtInsSemana->bindParam(':codigo_plan_nutricional', $codigo_plan_nutricional, PDO::PARAM_INT);
            $stmtInsSemana->bindParam(':numero_semana', $numero_semana, PDO::PARAM_INT);
            $stmtInsSemana->bindParam(':titulo', $titulo);
            $stmtInsSemana->bindParam(':completada', $completada);
            $stmtInsSemana->bindParam(':orden', $orden_semana, PDO::PARAM_INT);
            $stmtInsSemana->bindParam(':codusuarioa', $codusuario, PDO::PARAM_INT);
            $stmtInsSemana->execute();
            $codigo_semana = intval($db->lastInsertId());

            $dias = is_array($semana['dias']) ? $semana['dias'] : [];
            foreach ($dias as $dia) {
                $dia_semana = intval($dia['dia_semana'] ?? 0);
                $nombre_dia = trim($dia['nombre_dia'] ?? '');
                $obs_dia = trim($dia['observaciones'] ?? '');

                $stmtInsDia->bindParam(':codigo_plan_nutricional_semana', $codigo_semana, PDO::PARAM_INT);
                $stmtInsDia->bindParam(':dia_semana', $dia_semana, PDO::PARAM_INT);
                $stmtInsDia->bindParam(':nombre_dia', $nombre_dia);
                $stmtInsDia->bindParam(':observaciones', $obs_dia);
                $stmtInsDia->bindParam(':codusuarioa', $codusuario, PDO::PARAM_INT);
                $stmtInsDia->execute();
                $codigo_dia = intval($db->lastInsertId());

                $ingestas = is_array($dia['ingestas']) ? $dia['ingestas'] : [];
                foreach ($ingestas as $ingIndex => $ingesta) {
                    $tipo_ingesta = trim($ingesta['tipo_ingesta'] ?? '');
                    $orden_ingesta = intval($ingesta['orden'] ?? ($ingIndex + 1));
                    $obs_ingesta = trim($ingesta['observaciones'] ?? '');

                    $stmtInsIngesta->bindParam(':codigo_plan_nutricional_semana_dia', $codigo_dia, PDO::PARAM_INT);
                    $stmtInsIngesta->bindParam(':tipo_ingesta', $tipo_ingesta);
                    $stmtInsIngesta->bindParam(':orden', $orden_ingesta, PDO::PARAM_INT);
                    $stmtInsIngesta->bindParam(':observaciones', $obs_ingesta);
                    $stmtInsIngesta->bindParam(':codusuarioa', $codusuario, PDO::PARAM_INT);
                    $stmtInsIngesta->execute();
                    $codigo_ingesta = intval($db->lastInsertId());

                    $items = is_array($ingesta['items']) ? $ingesta['items'] : [];
                    foreach ($items as $itemIndex => $item) {
                        $codigo_alimento = isset($item['codigo_alimento']) && $item['codigo_alimento'] !== ''
                            ? intval($item['codigo_alimento'])
                            : null;
                        $descripcion_manual = trim($item['descripcion_manual'] ?? '');
                        $cantidad = trim($item['cantidad'] ?? '');
                        $unidad = trim($item['unidad'] ?? '');
                        $orden_item = intval($item['orden'] ?? ($itemIndex + 1));
                        $notas = trim($item['notas'] ?? '');
                        $opcion = in_array(strtoupper(trim($item['opcion'] ?? '')), ['S', 'N']) ? strtoupper(trim($item['opcion'])) : null;

                        $stmtInsItem->bindParam(':codigo_plan_nutricional_dia_ingesta', $codigo_ingesta, PDO::PARAM_INT);
                        $stmtInsItem->bindParam(':codigo_alimento', $codigo_alimento);
                        $stmtInsItem->bindParam(':descripcion_manual', $descripcion_manual);
                        $stmtInsItem->bindParam(':cantidad', $cantidad);
                        $stmtInsItem->bindParam(':unidad', $unidad);
                        $stmtInsItem->bindParam(':orden', $orden_item, PDO::PARAM_INT);
                        $stmtInsItem->bindParam(':notas', $notas);
                        $stmtInsItem->bindParam(':opcion', $opcion);
                        $stmtInsItem->bindParam(':codusuarioa', $codusuario, PDO::PARAM_INT);
                        $stmtInsItem->execute();
                    }
                }
            }
        }

        $stmtInsReceta = $db->prepare("INSERT INTO nu_plan_nutricional_receta
            (codigo_plan_nutricional, codigo_receta, orden, codusuarioa, fechaa)
            VALUES (:codigo_plan_nutricional, :codigo_receta, :orden, :codusuarioa, NOW())");

        foreach ($recetas as $recIndex => $receta) {
            $codigo_receta = intval(is_array($receta) ? ($receta['codigo_receta'] ?? 0) : $receta);
            if ($codigo_receta <= 0) continue;
            $orden = $recIndex + 1;

            $stmtInsReceta->bindParam(':codigo_plan_nutricional', $codigo_plan_nutricional, PDO::PARAM_INT);
            $stmtInsReceta->bindParam(':codigo_receta', $codigo_receta, PDO::PARAM_INT);
            $stmtInsReceta->bindParam(':orden', $orden, PDO::PARAM_INT);
            $stmtInsReceta->bindParam(':codusuarioa', $codusuario, PDO::PARAM_INT);
            $stmtInsReceta->execute();
        }

        $db->commit();

        ob_clean();
        echo json_encode(["message" => "Estructura guardada correctamente."]);
    } catch (Throwable $e) {
        error_log('plan_nutricional_estructura save error: ' . $e->getMessage());
        if ($db->inTransaction()) {
            $db->rollBack();
        }
        http_response_code(500);
        ob_clean();
        echo json_encode([
            "message" => "No se pudo guardar la estructura del plan.",
            "error" => $e->getMessage()
        ]);
    }
}
?>
