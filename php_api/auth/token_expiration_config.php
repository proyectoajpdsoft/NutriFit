<?php
/**
 * Configuración centralizada de caducidad de tokens.
 *
 * Reglas:
 * - Invitado: parametro horas_caducidad_token_invitado (default 0 = no caduca)
 * - Usuario sin paciente: parametro horas_caducidad_token_usuario (default 1440)
 * - Usuario con paciente: parametro horas_caducidad_token_paciente (default 720)
 * - Nutricionista: parametro horas_caducidad_token_nutricionista (default 504)
 */

function get_token_hours_from_param($db, $param_name, $default_hours) {
    $queries = [
        "SELECT valor1 AS valor_horas FROM parametro WHERE nombre = :nombre LIMIT 1",
        "SELECT valor AS valor_horas FROM parametro WHERE nombre = :nombre LIMIT 1",
    ];

    foreach ($queries as $query) {
        try {
            $stmt = $db->prepare($query);
            $stmt->bindParam(':nombre', $param_name, PDO::PARAM_STR);
            $stmt->execute();
            $row = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$row || !isset($row['valor_horas']) || $row['valor_horas'] === null || $row['valor_horas'] === '') {
                continue;
            }

            $horas = (int) floor((float) $row['valor_horas']);
            return max(0, $horas);
        } catch (Exception $e) {
            // Intentar siguiente variante (valor1 -> valor)
            continue;
        }
    }

    return (int) $default_hours;
}

function get_guest_token_expiration_hours($db) {
    return get_token_hours_from_param($db, 'horas_caducidad_token_invitado', 0);
}

function get_registered_user_token_expiration_hours($db, $tipo, $codigo_paciente = null) {
    $tipo_normalizado = strtolower(trim((string) $tipo));

    if ($tipo_normalizado === 'nutricionista') {
        return get_token_hours_from_param($db, 'horas_caducidad_token_nutricionista', 504);
    }

    $has_paciente = !empty($codigo_paciente) && (int) $codigo_paciente > 0;
    if ($has_paciente) {
        return get_token_hours_from_param($db, 'horas_caducidad_token_paciente', 720);
    }

    return get_token_hours_from_param($db, 'horas_caducidad_token_usuario', 1440);
}

function build_token_expiration_datetime_or_null($hours) {
    $hours_int = max(0, (int) $hours);
    if ($hours_int === 0) {
        return '9999-12-31 23:59:59';
    }
    return date('Y-m-d H:i:s', strtotime('+' . $hours_int . ' hours'));
}
