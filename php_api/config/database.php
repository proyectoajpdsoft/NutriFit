<?php
ob_start(); // Iniciar el buffer de salida
// Configuración de la base de datos
class Database {
    private $host = "ajpdsoft.com";
    private $db_name = "patri_dietista"; // Cambia esto por el nombre de tu BD
    private $username = "car_pat_nutri"; // Cambia esto por tu usuario de BD
    private $password = "XPqbf94&.8]5"; // Cambia esto por tu contraseña de BD
    public $conn;


    // Obtener la conexión a la base de datos
    public function getConnection() {
        $this->conn = null;
        try {
            $this->conn = new PDO("mysql:host=" . $this->host . ";dbname=" . $this->db_name . ";charset=utf8mb4", $this->username, $this->password);
            $this->conn->exec("set names utf8mb4");
        } catch(PDOException $exception) {
            echo "Error de conexión: " . $exception->getMessage();
        }
        return $this->conn;
    }
}
