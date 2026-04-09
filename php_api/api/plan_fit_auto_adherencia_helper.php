<?php

function pfaa_normalize_float($value) {
    if ($value === null || $value === '') {
        return 0.0;
    }
    return floatval($value);
}

function pfaa_normalize_int($value) {
    if ($value === null || $value === '') {
        return 0;
    }
    return intval($value);
}

function pfaa_normalize_date($value) {
    $raw = trim((string)$value);
    if ($raw === '') {
        return null;
    }

    if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $raw)) {
        return $raw;
    }

    $timestamp = strtotime($raw);
    if ($timestamp === false) {
        return null;
    }

    return date('Y-m-d', $timestamp);
}

function pfaa_format_km($kilometros) {
    $formatted = number_format(pfaa_normalize_float($kilometros), 2, '.', '');
    $formatted = rtrim(rtrim($formatted, '0'), '.');
    return str_replace('.', ',', $formatted);
}

function pfaa_format_time_label($horas, $minutos) {
    $totalMinutos = (pfaa_normalize_int($horas) * 60) + pfaa_normalize_int($minutos);
    return $totalMinutos . ' min';
}

function pfaa_build_activity_title($training) {
    $titulo = trim((string)($training['titulo'] ?? ''));
    if ($titulo !== '') {
        return $titulo;
    }

    $actividad = trim((string)($training['actividad'] ?? ''));
    if ($actividad !== '') {
        return $actividad;
    }

    return 'Actividad';
}

function pfaa_build_reason($training, $metrics) {
    $parts = array(
        'Actividad realizada [' . pfaa_build_activity_title($training) . ']',
        'Tiempo: ' . pfaa_format_time_label($training['duracion_horas'] ?? 0, $training['duracion_minutos'] ?? 0),
    );

    $kilometros = pfaa_normalize_float($training['duracion_kilometros'] ?? 0);
    if ($kilometros > 0) {
        $parts[] = 'Km: ' . pfaa_format_km($kilometros);
    }

    if (($metrics['mode'] ?? '') === 'plan') {
        $parts[] = 'Ejercicios realizados: ' . intval($metrics['performed']) . ' de ' . intval($metrics['total']) . ' del plan';
    } elseif (($metrics['mode'] ?? '') === 'catalog') {
        $parts[] = 'Ejercicios realizados: ' . intval($metrics['performed']);
    }

    return implode('. ', $parts) . '.';
}

function pfaa_map_plan_ratio_to_state($ratio) {
    if ($ratio >= 0.70) {
        return 'cumplido';
    }
    if ($ratio >= 0.20) {
        return 'parcial';
    }
    return 'no';
}

function pfaa_resolve_target_user_code($db, $codigoPaciente) {
    $stmt = $db->prepare("SELECT codigo FROM usuario WHERE codigo_paciente = :codigo_paciente AND activo = 'S' ORDER BY codigo ASC LIMIT 1");
    $stmt->bindValue(':codigo_paciente', intval($codigoPaciente), PDO::PARAM_INT);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row || empty($row['codigo'])) {
        return null;
    }

    return intval($row['codigo']);
}

function pfaa_resolve_active_plan_fit_code($db, $codigoPaciente, $fecha) {
    $baseQuery = "SELECT codigo
                  FROM nu_plan_nutricional_fit
                  WHERE codigo_paciente = :codigo_paciente
                    AND (completado IS NULL OR completado <> 'S')";

    $stmt = $db->prepare(
        $baseQuery . "
                    AND (:fecha BETWEEN DATE(COALESCE(desde, :fecha)) AND DATE(COALESCE(hasta, :fecha)))
                  ORDER BY desde DESC, codigo DESC
                  LIMIT 1"
    );
    $stmt->bindValue(':codigo_paciente', intval($codigoPaciente), PDO::PARAM_INT);
    $stmt->bindValue(':fecha', $fecha);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($row && !empty($row['codigo'])) {
        return intval($row['codigo']);
    }

    $fallback = $db->prepare(
        $baseQuery . "
                  ORDER BY desde DESC, codigo DESC
                  LIMIT 1"
    );
    $fallback->bindValue(':codigo_paciente', intval($codigoPaciente), PDO::PARAM_INT);
    $fallback->execute();
    $fallbackRow = $fallback->fetch(PDO::FETCH_ASSOC);

    if ($fallbackRow && !empty($fallbackRow['codigo'])) {
        return intval($fallbackRow['codigo']);
    }

    return null;
}

function pfaa_fit_adherencia_exists($db, $codigoUsuario, $fecha) {
    $stmt = $db->prepare("SELECT 1 FROM nu_adherencia_diaria WHERE codigo_usuario = :codigo_usuario AND fecha = :fecha AND tipo = 'fit' LIMIT 1");
    $stmt->bindValue(':codigo_usuario', intval($codigoUsuario), PDO::PARAM_INT);
    $stmt->bindValue(':fecha', $fecha);
    $stmt->execute();
    return (bool)$stmt->fetchColumn();
}

function pfaa_fetch_training($db, $codigoEntrenamiento) {
    $stmt = $db->prepare("SELECT codigo, codigo_paciente, actividad, titulo, fecha, duracion_horas, duracion_minutos, duracion_kilometros, codigo_plan_fit, codusuario FROM nu_entrenamientos WHERE codigo = :codigo LIMIT 1");
    $stmt->bindValue(':codigo', intval($codigoEntrenamiento), PDO::PARAM_INT);
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    return $row ?: null;
}

function pfaa_fetch_training_exercises($db, $codigoEntrenamiento) {
    $stmt = $db->prepare(
        "SELECT e.codigo_plan_fit_ejercicio,
                e.codigo_ejercicio_catalogo,
                e.realizado,
                pfe.codigo_plan_fit,
                pfe.codigo_dia
           FROM nu_entrenamientos_ejercicios e
      LEFT JOIN nu_plan_fit_ejercicio pfe ON pfe.codigo = e.codigo_plan_fit_ejercicio
          WHERE e.codigo_entrenamiento = :codigo_entrenamiento"
    );
    $stmt->bindValue(':codigo_entrenamiento', intval($codigoEntrenamiento), PDO::PARAM_INT);
    $stmt->execute();

    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

function pfaa_is_exercise_done($exercise) {
    return strtoupper(trim((string)($exercise['realizado'] ?? 'N'))) === 'S';
}

function pfaa_calculate_state_and_reason($db, $training, $exercises, $activePlanFitCode) {
    $planExercises = array_values(array_filter($exercises, function ($exercise) {
        return intval($exercise['codigo_plan_fit_ejercicio'] ?? 0) > 0;
    }));

    if (!empty($planExercises)) {
        $dayIds = array();
        foreach ($planExercises as $exercise) {
            $codigoDia = intval($exercise['codigo_dia'] ?? 0);
            if ($codigoDia > 0) {
                $dayIds[$codigoDia] = true;
            }
        }

        $totalPlanExercises = count($planExercises);
        if (!empty($dayIds)) {
            $placeholders = implode(',', array_fill(0, count($dayIds), '?'));
            $stmt = $db->prepare("SELECT COUNT(DISTINCT codigo) AS total FROM nu_plan_fit_ejercicio WHERE codigo_dia IN ($placeholders)");
            $index = 1;
            foreach (array_keys($dayIds) as $codigoDia) {
                $stmt->bindValue($index++, intval($codigoDia), PDO::PARAM_INT);
            }
            $stmt->execute();
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            $totalPlanExercises = max(1, intval($row['total'] ?? 0));
        }

        $performed = 0;
        foreach ($planExercises as $exercise) {
            if (pfaa_is_exercise_done($exercise)) {
                $performed++;
            }
        }

        $ratio = $totalPlanExercises > 0 ? ($performed / $totalPlanExercises) : 0.0;
        $metrics = array(
            'mode' => 'plan',
            'performed' => $performed,
            'total' => $totalPlanExercises,
        );

        return array(
            'estado' => pfaa_map_plan_ratio_to_state($ratio),
            'observacion' => pfaa_build_reason($training, $metrics),
        );
    }

    if ($activePlanFitCode === null) {
        return null;
    }

    if (!empty($exercises)) {
        $performed = 0;
        foreach ($exercises as $exercise) {
            if (pfaa_is_exercise_done($exercise)) {
                $performed++;
            }
        }

        if ($performed > 3) {
            $estado = 'cumplido';
        } elseif ($performed === 3) {
            $estado = 'parcial';
        } else {
            $estado = 'no';
        }

        return array(
            'estado' => $estado,
            'observacion' => pfaa_build_reason($training, array(
                'mode' => 'catalog',
                'performed' => $performed,
                'total' => count($exercises),
            )),
        );
    }

    $kilometros = pfaa_normalize_float($training['duracion_kilometros'] ?? 0);
    if ($kilometros > 0) {
        if ($kilometros > 4) {
            $estado = 'cumplido';
        } elseif ($kilometros >= 2) {
            $estado = 'parcial';
        } else {
            $estado = 'no';
        }

        return array(
            'estado' => $estado,
            'observacion' => pfaa_build_reason($training, array('mode' => 'distance')),
        );
    }

    $totalMinutos = (pfaa_normalize_int($training['duracion_horas'] ?? 0) * 60) + pfaa_normalize_int($training['duracion_minutos'] ?? 0);
    if ($totalMinutos > 20) {
        $estado = 'cumplido';
    } elseif ($totalMinutos >= 10) {
        $estado = 'parcial';
    } else {
        $estado = 'no';
    }

    return array(
        'estado' => $estado,
        'observacion' => pfaa_build_reason($training, array('mode' => 'time')),
    );
}

function pfaa_generate_auto_fit_adherence_if_missing($db, $codigoEntrenamiento, $codigoUsuarioActor = null) {
    $training = pfaa_fetch_training($db, $codigoEntrenamiento);
    if (!$training) {
        return array('ok' => false, 'reason' => 'training_not_found');
    }

    $codigoPaciente = intval($training['codigo_paciente'] ?? 0);
    if ($codigoPaciente <= 0) {
        return array('ok' => false, 'reason' => 'patient_not_found');
    }

    $fecha = pfaa_normalize_date($training['fecha'] ?? null);
    if ($fecha === null) {
        return array('ok' => false, 'reason' => 'invalid_date');
    }

    $codigoUsuarioObjetivo = pfaa_resolve_target_user_code($db, $codigoPaciente);
    if ($codigoUsuarioObjetivo === null) {
        return array('ok' => false, 'reason' => 'target_user_not_found');
    }

    if (pfaa_fit_adherencia_exists($db, $codigoUsuarioObjetivo, $fecha)) {
        return array('ok' => true, 'created' => false, 'reason' => 'already_exists');
    }

    $activePlanFitCode = intval($training['codigo_plan_fit'] ?? 0);
    if ($activePlanFitCode <= 0) {
        $activePlanFitCode = pfaa_resolve_active_plan_fit_code($db, $codigoPaciente, $fecha);
    }
    if ($activePlanFitCode !== null && $activePlanFitCode <= 0) {
        $activePlanFitCode = null;
    }

    $exercises = pfaa_fetch_training_exercises($db, $codigoEntrenamiento);
    $evaluation = pfaa_calculate_state_and_reason($db, $training, $exercises, $activePlanFitCode);
    if ($evaluation === null) {
        return array('ok' => true, 'created' => false, 'reason' => 'no_plan_fit');
    }

    $codigoActor = intval($codigoUsuarioActor ?: ($training['codusuario'] ?? 0));
    if ($codigoActor <= 0) {
        $codigoActor = $codigoUsuarioObjetivo;
    }

    $insert = $db->prepare(
        "INSERT INTO nu_adherencia_diaria
            (codigo_usuario, fecha, tipo, estado, observacion, codusuarioa, fechaa)
         SELECT
            :codigo_usuario, :fecha, 'fit', :estado, :observacion, :codusuarioa, NOW()
         FROM DUAL
         WHERE NOT EXISTS (
            SELECT 1
              FROM nu_adherencia_diaria
             WHERE codigo_usuario = :codigo_usuario_check
               AND fecha = :fecha_check
               AND tipo = 'fit'
         )"
    );
    $insert->bindValue(':codigo_usuario', $codigoUsuarioObjetivo, PDO::PARAM_INT);
    $insert->bindValue(':fecha', $fecha);
    $insert->bindValue(':estado', $evaluation['estado']);
    $insert->bindValue(':observacion', $evaluation['observacion']);
    $insert->bindValue(':codusuarioa', $codigoActor, PDO::PARAM_INT);
    $insert->bindValue(':codigo_usuario_check', $codigoUsuarioObjetivo, PDO::PARAM_INT);
    $insert->bindValue(':fecha_check', $fecha);
    $insert->execute();

    return array(
        'ok' => true,
        'created' => $insert->rowCount() > 0,
        'estado' => $evaluation['estado'],
        'observacion' => $evaluation['observacion'],
    );
}