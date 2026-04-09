<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
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

// Validar token (solo usuarios registrados)
$validator = new TokenValidator($db);
$user = $validator->validateToken();
PermissionManager::checkPermission($user, 'sesiones');

// GET: Obtener sesiones del usuario
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $ultimos_accesos = isset($_GET['ultimos_accesos']) ? intval($_GET['ultimos_accesos']) : 0;
    $all_sesiones = isset($_GET['all_sesiones']) ? intval($_GET['all_sesiones']) : 0;
    $codigo_usuario = isset($_GET['codigo_usuario']) ? $_GET['codigo_usuario'] : null;
    $codigo_usuario_auth = intval($user['codigo'] ?? 0);
    $is_admin = (($user['administrador'] ?? 'N') === 'S');
    $is_nutri = strtolower(trim((string)($user['tipo'] ?? ''))) === 'nutricionista';

    if ($ultimos_accesos === 1) {
        if (!$is_admin && !$is_nutri) {
            http_response_code(403);
            echo json_encode(array("message" => "No tienes permiso para consultar accesos globales."));
            exit();
        }

        // Registrados: un único registro por usuario con su último acceso exitoso.
        $query_registered = "SELECT s.id, s.codigousuario, s.fecha, s.hora, s.estado, s.ip_local, s.ip_publica, s.tipo,
                                    u.nick AS usuario_nick, u.nombre AS usuario_nombre
                             FROM sesion s
                             INNER JOIN (
                                SELECT codigousuario,
                                       MAX(CONCAT(COALESCE(fecha, '0000-00-00'), ' ', COALESCE(hora, '00:00:00'))) AS max_dt
                                FROM sesion
                                WHERE codigousuario IS NOT NULL
                                  AND estado IN ('OK', 'OK_GUEST_LOGIN')
                                GROUP BY codigousuario
                             ) last_s ON last_s.codigousuario = s.codigousuario
                                     AND CONCAT(COALESCE(s.fecha, '0000-00-00'), ' ', COALESCE(s.hora, '00:00:00')) = last_s.max_dt
                             LEFT JOIN usuario u ON u.codigo = s.codigousuario
                             ORDER BY s.fecha DESC, s.hora DESC";
        $stmt_registered = $db->prepare($query_registered);
        $stmt_registered->execute();
        $registered_rows = $stmt_registered->fetchAll(PDO::FETCH_ASSOC);

        // Invitados no registrados: un único registro por IP pública con su último acceso.
        $query_guest = "SELECT s.id, s.codigousuario, s.fecha, s.hora, s.estado, s.ip_local, s.ip_publica, s.tipo,
                               NULL AS usuario_nick, NULL AS usuario_nombre
                        FROM sesion s
                        INNER JOIN (
                            SELECT ip_publica,
                                   MAX(CONCAT(COALESCE(fecha, '0000-00-00'), ' ', COALESCE(hora, '00:00:00'))) AS max_dt
                            FROM sesion
                            WHERE (codigousuario IS NULL OR codigousuario = 0)
                              AND ip_publica IS NOT NULL
                              AND TRIM(ip_publica) <> ''
                              AND estado IN ('OK_GUEST_LOGIN', 'OK')
                            GROUP BY ip_publica
                        ) last_g ON last_g.ip_publica = s.ip_publica
                                AND CONCAT(COALESCE(s.fecha, '0000-00-00'), ' ', COALESCE(s.hora, '00:00:00')) = last_g.max_dt
                        WHERE (s.codigousuario IS NULL OR s.codigousuario = 0)
                        ORDER BY s.fecha DESC, s.hora DESC";
        $stmt_guest = $db->prepare($query_guest);
        $stmt_guest->execute();
        $guest_rows = $stmt_guest->fetchAll(PDO::FETCH_ASSOC);

        $accesos = array_merge($registered_rows, $guest_rows);

        usort($accesos, function ($a, $b) {
            $ad = ($a['fecha'] ?? '') . ' ' . ($a['hora'] ?? '00:00:00');
            $bd = ($b['fecha'] ?? '') . ' ' . ($b['hora'] ?? '00:00:00');
            if ($ad === $bd) return 0;
            return ($ad < $bd) ? 1 : -1;
        });

        http_response_code(200);
        echo json_encode(array(
            "total_accesos" => count($accesos),
            "ultimos_accesos" => $accesos
        ));
        exit();
    }

    if ($all_sesiones === 1) {
        if (!$is_admin && !$is_nutri) {
            http_response_code(403);
            echo json_encode(array("message" => "No tienes permiso para consultar sesiones globales."));
            exit();
        }

        $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 20;
        $offset = isset($_GET['offset']) ? intval($_GET['offset']) : 0;
        if ($limit <= 0) $limit = 20;
        if ($limit > 200) $limit = 200;
        if ($offset < 0) $offset = 0;

        $codigo_usuario_filter = isset($_GET['codigo_usuario_filter']) ? intval($_GET['codigo_usuario_filter']) : 0;
        $fecha_hora_q = isset($_GET['fecha_hora_q']) ? trim((string)$_GET['fecha_hora_q']) : '';
        $desde_raw = isset($_GET['desde']) ? trim((string)$_GET['desde']) : '';
        $hasta_raw = isset($_GET['hasta']) ? trim((string)$_GET['hasta']) : '';

        $where = array();
        $params = array();

        if ($codigo_usuario_filter > 0) {
            $where[] = "s.codigousuario = :codigo_usuario_filter";
            $params[':codigo_usuario_filter'] = $codigo_usuario_filter;
        }

        if ($fecha_hora_q !== '') {
            $where[] = "CONCAT(COALESCE(s.fecha, ''), ' ', COALESCE(s.hora, '')) LIKE :fecha_hora_q";
            $params[':fecha_hora_q'] = '%' . $fecha_hora_q . '%';
        }

        $desde_dt = null;
        if ($desde_raw !== '') {
            try {
                $desde_dt = new DateTime($desde_raw);
                $where[] = "STR_TO_DATE(CONCAT(COALESCE(s.fecha, ''), ' ', COALESCE(s.hora, '00:00:00')), '%Y-%m-%d %H:%i:%s') >= :desde_dt";
                $params[':desde_dt'] = $desde_dt->format('Y-m-d H:i:s');
            } catch (Exception $e) {
                // Ignorar filtro inválido
            }
        }

        $hasta_dt = null;
        if ($hasta_raw !== '') {
            try {
                $hasta_dt = new DateTime($hasta_raw);
                $where[] = "STR_TO_DATE(CONCAT(COALESCE(s.fecha, ''), ' ', COALESCE(s.hora, '00:00:00')), '%Y-%m-%d %H:%i:%s') <= :hasta_dt";
                $params[':hasta_dt'] = $hasta_dt->format('Y-m-d H:i:s');
            } catch (Exception $e) {
                // Ignorar filtro inválido
            }
        }

        $where_sql = '';
        if (!empty($where)) {
            $where_sql = ' WHERE ' . implode(' AND ', $where);
        }

        $count_sql = "SELECT COUNT(*) AS total
                      FROM sesion s
                      LEFT JOIN usuario u ON u.codigo = s.codigousuario" . $where_sql;
        $count_stmt = $db->prepare($count_sql);
        foreach ($params as $key => $value) {
            $count_stmt->bindValue($key, $value);
        }
        $count_stmt->execute();
        $total_row = $count_stmt->fetch(PDO::FETCH_ASSOC);
        $total_filtrado = intval($total_row['total'] ?? 0);

        if ($total_filtrado <= 0) {
            http_response_code(404);
            echo json_encode(array("message" => "No hay sesiones registradas.", "total_sesiones" => 0, "todas_sesiones" => array(), "limit" => $limit, "offset" => $offset, "has_more" => false));
            exit();
        }

        $query_all = "SELECT s.id, s.codigousuario, s.fecha, s.hora, s.estado, s.ip_local, s.ip_publica, s.tipo,
                             u.nick AS usuario_nick, u.nombre AS usuario_nombre
                      FROM sesion s
                      LEFT JOIN usuario u ON u.codigo = s.codigousuario"
                      . $where_sql .
                      " ORDER BY s.fecha DESC, s.hora DESC
                        LIMIT :limit OFFSET :offset";

        $stmt_all = $db->prepare($query_all);
        foreach ($params as $key => $value) {
            $stmt_all->bindValue($key, $value);
        }
        $stmt_all->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt_all->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt_all->execute();
        $sesiones_all = $stmt_all->fetchAll(PDO::FETCH_ASSOC);

        http_response_code(200);
        echo json_encode(array(
            "total_sesiones" => $total_filtrado,
            "todas_sesiones" => $sesiones_all,
            "limit" => $limit,
            "offset" => $offset,
            "has_more" => ($offset + count($sesiones_all)) < $total_filtrado
        ));
        exit();
    }

    if (empty($codigo_usuario)) {
        http_response_code(400);
        echo json_encode(array("message" => "Falta codigo_usuario."));
        exit();
    }

    $codigo_usuario = intval($codigo_usuario);

    if ($codigo_usuario_auth <= 0) {
        http_response_code(401);
        echo json_encode(array("message" => "Usuario inválido."));
        exit();
    }

    // LOPDGDD/RGPD: usuario normal solo puede consultar sus propias sesiones.
    if (!$is_admin && !$is_nutri && $codigo_usuario !== $codigo_usuario_auth) {
        http_response_code(403);
        echo json_encode(array("message" => "No tienes permiso para consultar sesiones de otro usuario."));
        exit();
    }

    // Obtener todas las sesiones del usuario ordenadas por fecha y hora descendente
    $query = "SELECT id, codigousuario, fecha, hora, estado, ip_local, ip_publica, tipo
              FROM sesion 
              WHERE codigousuario = :codigo_usuario 
              ORDER BY fecha DESC, hora DESC";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':codigo_usuario', $codigo_usuario);
    $stmt->execute();

    if ($stmt->rowCount() > 0) {
        $sesiones = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Separar sesiones exitosas y fallidas
        $sesiones_exitosas = array();
        $sesiones_fallidas = array();
        $total_exitosas = 0;
        $total_fallidas = 0;

        foreach ($sesiones as $sesion) {
            if ($sesion['estado'] === 'OK') {
                $sesiones_exitosas[] = $sesion;
                $total_exitosas++;
            } else {
                $sesiones_fallidas[] = $sesion;
                $total_fallidas++;
            }
        }

        // Obtener las 2 últimas sesiones exitosas
        $ultimas_sesiones_exitosas = array_slice($sesiones_exitosas, 0, 2);
        
        // Obtener los 2 últimos intentos fallidos
        $ultimos_intentos_fallidos = array_slice($sesiones_fallidas, 0, 2);

        http_response_code(200);
        echo json_encode(array(
            "ultimas_sesiones_exitosas" => $ultimas_sesiones_exitosas,
            "ultimos_intentos_fallidos" => $ultimos_intentos_fallidos,
            "total_sesiones" => count($sesiones),
            "total_exitosas" => $total_exitosas,
            "total_fallidas" => $total_fallidas,
            "todas_sesiones" => $sesiones
        ));
    } else {
        http_response_code(404);
        echo json_encode(array("message" => "No hay sesiones registradas para este usuario."));
    }
} else {
    http_response_code(405);
    echo json_encode(array("message" => "Método no permitido."));
}
?>
