<?php
// --- SCRIPT DE USO ÚNICO PARA ACTUALIZAR CONTRASEÑAS ---
// ADVERTENCIA: Haz una copia de seguridad de tu tabla 'usuario' antes de ejecutar.

// --------------------------------------------------------------------------
// --- CONFIGURACIÓN: Introduce aquí la contraseña que quieres hashear ---
$contrasena_a_hashear = '1234'; 
// --------------------------------------------------------------------------


if (empty($contrasena_a_hashear)) {
    die("Error: Debes especificar una contraseña en la variable \$contrasena_a_hashear.");
}

// Generar el hash seguro usando el algoritmo por defecto de PHP (BCRYPT)
$hash_seguro = password_hash($contrasena_a_hashear, PASSWORD_DEFAULT);

echo "<h1>Generador de Hash de Contraseña</h1>";
echo "<p><strong>Contraseña en texto plano:</strong> " . htmlspecialchars($contrasena_a_hashear) . "</p>";
echo "<p><strong>Hash seguro generado (BCRYPT):</strong></p>";
echo "<textarea rows='3' cols='80' readonly>" . htmlspecialchars($hash_seguro) . "</textarea>";
echo "<hr>";
echo "<h2>Instrucciones:</h2>";
echo "<ol>";
echo "<li>Modifica la variable \$contrasena_a_hashear en este script con la contraseña que quieras usar.</li>";
echo "<li>Abre este script en tu navegador (ej: http://localhost/api/hasher.php).</li>";
echo "<li>Copia el hash generado de la caja de texto.</li>";
echo "<li>Abre tu gestor de base de datos (phpMyAdmin, DBeaver, etc.).</li>";
echo "<li>Ejecuta una consulta SQL para actualizar la contraseña del usuario que desees. Ejemplo:</li>";
echo "</ol>";
echo "<pre>UPDATE usuario SET contrasena = 'COPIA_AQUI_EL_HASH_GENERADO' WHERE nick = 'tu_usuario';</pre>";
echo "<p><strong>IMPORTANTE:</strong> Después de actualizar las contraseñas, puedes borrar este fichero ('hasher.php') del servidor.</p>";

?>
