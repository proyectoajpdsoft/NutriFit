<!DOCTYPE html>
<html>
<head>
    <title>Verificar y Corregir Entrevistas</title>
</head>
<body>
    <h1>Verificar Estructura de nu_paciente_entrevista</h1>
    <?php
    include_once '../config/database.php';
    
    $database = new Database();
    $db = $database->getConnection();
    
    echo "<h2>Columnas actuales:</h2>";
    $query = "SHOW COLUMNS FROM nu_paciente_entrevista";
    $stmt = $db->query($query);
    echo "<table border='1'><tr><th>Campo</th><th>Tipo</th><th>Nulo</th><th>Key</th><th>Default</th></tr>";
    while($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "<tr>";
        echo "<td>" . $row['Field'] . "</td>";
        echo "<td>" . $row['Type'] . "</td>";
        echo "<td>" . $row['Null'] . "</td>";
        echo "<td>" . $row['Key'] . "</td>";
        echo "<td>" . $row['Default'] . "</td>";
        echo "</tr>";
    }
    echo "</table>";
    
    // Verificar si faltan las columnas
    $query = "SELECT COUNT(*) as tiene_codusuariom 
              FROM INFORMATION_SCHEMA.COLUMNS 
              WHERE table_schema = DATABASE() 
              AND table_name = 'nu_paciente_entrevista' 
              AND column_name = 'codusuariom'";
    $stmt = $db->query($query);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo "<h2>Estado de las columnas:</h2>";
    echo "<p>Columna 'codusuariom': " . ($result['tiene_codusuariom'] > 0 ? "✓ Existe" : "✗ No existe") . "</p>";
    
    $query = "SELECT COUNT(*) as tiene_fecham 
              FROM INFORMATION_SCHEMA.COLUMNS 
              WHERE table_schema = DATABASE() 
              AND table_name = 'nu_paciente_entrevista' 
              AND column_name = 'fecham'";
    $stmt = $db->query($query);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo "<p>Columna 'fecham': " . ($result['tiene_fecham'] > 0 ? "✓ Existe" : "✗ No existe") . "</p>";
    
    // Intentar agregar las columnas si no existen
    echo "<h2>Intentando agregar columnas faltantes...</h2>";
    
    try {
        $query = "ALTER TABLE nu_paciente_entrevista 
                  ADD COLUMN IF NOT EXISTS codusuariom int(11) DEFAULT NULL,
                  ADD COLUMN IF NOT EXISTS fecham datetime DEFAULT NULL";
        $db->exec($query);
        echo "<p style='color: green;'>✓ Columnas agregadas exitosamente</p>";
    } catch(PDOException $e) {
        if(strpos($e->getMessage(), 'Duplicate column') !== false) {
            echo "<p style='color: orange;'>⚠ Las columnas ya existen</p>";
        } else {
            echo "<p style='color: red;'>✗ Error: " . $e->getMessage() . "</p>";
        }
    }
    
    echo "<p><a href='entrevistas.php'>Probar API de entrevistas</a></p>";
    ?>
</body>
</html>
