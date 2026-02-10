# NutriApp - Aplicación de Gestión para Nutricionistas

NutriApp es una completa aplicación multiplataforma (Android e iOS) desarrollada con Flutter, diseñada para facilitar la gestión diaria de dietistas y nutricionistas. La aplicación se conecta a un backend PHP con una base de datos MySQL/MariaDB para gestionar toda la información de forma segura y centralizada.

## Características Principales

-   **Gestión de Pacientes**: Completo CRUD (Crear, Leer, Actualizar, Borrar) para la información de los pacientes.
-   **Calendario de Citas**: Visualización y gestión de citas en una interfaz de calendario intuitiva.
-   **Entrevistas Detalladas**: Formularios complejos con secciones desplegables (acordes) para recoger toda la información necesaria del paciente.
-   **Revisiones y Mediciones**: Seguimiento del progreso del paciente en formato maestro-detalle.
-   **Planes Nutricionales**: Asignación de planes (documentos PDF) a los pacientes.
-   **Gestión de Cobros y Clientes**: Seguimiento de los pagos y gestión de clientes externos (para charlas, etc.).
-   **API REST Segura**: Toda la comunicación se realiza a través de un API REST en PHP con planes para implementar autenticación por token.
-   **Roles de Usuario**: Perfiles diferenciados para `Nutricionista` (acceso completo) y `Paciente` (acceso de solo lectura a sus planes).

## Estructura del Proyecto

El repositorio está organizado en dos partes principales:

1.  `nutri_app/`: Contiene todo el código fuente de la aplicación Flutter.
    -   `lib/`: El corazón de la aplicación.
        -   `main.dart`: Punto de entrada de la aplicación.
        -   `models/`: Clases de modelo que representan los datos (Paciente, Cita, etc.).
        -   `screens/`: Las diferentes pantallas de la aplicación, organizadas por módulo.
        -   `services/`: Lógica de negocio, principalmente el `api_service.dart` que maneja la comunicación con el backend.
        -   `widgets/`: Widgets reutilizables que se pueden usar en varias pantallas.
    -   `pubspec.yaml`: Fichero de configuración del proyecto Flutter, donde se gestionan las dependencias.
2.  `php_api/`: Contiene el código fuente del API REST en PHP.
    -   `config/`: Ficheros de configuración, como la conexión a la base de datos (`database.php`).
    -   `api/`: Los diferentes *endpoints* del API, uno por cada recurso (pacientes, citas, etc.).
3.  `database.sql`: Script SQL para crear toda la estructura de la base de datos necesaria para el proyecto.

## Puesta en Marcha

### Prerrequisitos

-   Tener un entorno de desarrollo PHP/MySQL (como XAMPP, WAMP, MAMP o un servidor web).
-   Tener el [SDK de Flutter](https://flutter.dev/docs/get-started/install) instalado y configurado correctamente.
-   Un editor de código como Visual Studio Code.

### Pasos para la Instalación

#### 1. Backend (PHP API)

1.  **Importar la Base de Datos**:
    -   Crea una nueva base de datos en tu servidor MySQL/MariaDB (por ejemplo, `nutriapp_db`).
    -   Importa el fichero `database.sql` en esa base de datos. Esto creará todas las tablas necesarias.
2.  **Configurar el API**:
    -   Copia la carpeta `php_api` a la raíz de tu servidor web (e.g., `htdocs` en XAMPP).
    -   Edita el fichero `php_api/config/database.php` y actualiza las credenciales (`$host`, `$db_name`, `$username`, `$password`) para que coincidan con tu configuración de base de datos.
3.  **Probar el API**:
    -   Inicia tu servidor web.
    -   Abre un navegador y navega a `http://localhost/php_api/api/pacientes.php`. Deberías ver una respuesta JSON (probablemente `[]` si la base de datos está vacía).

#### 2. Frontend (Flutter App)

1.  **Abrir el Proyecto**:
    -   Abre la carpeta `nutri_app` con VS Code.
2.  **Instalar Dependencias**:
    -   Abre una terminal en VS Code y ejecuta el comando:
        ```sh
        flutter pub get
        ```
3.  **Configurar la Conexión al API**:
    -   Abre el fichero `lib/services/api_service.dart`.
    -   Localiza la variable `_baseUrl` y **cámbiala por la URL de tu API**.
        -   **Importante**: Si estás probando en un emulador de Android, `localhost` no funcionará. Debes usar la dirección IP de tu máquina en la red local (e.g., `http://192.168.1.100/php_api/api`).
4.  **Ejecutar la Aplicación**:
    -   Selecciona un dispositivo (emulador o físico).
    -   Presiona `F5` o ejecuta desde la terminal:
        ```sh
        flutter run
        ```

---
*Este proyecto está siendo desarrollado con la ayuda de un asistente de IA para agilizar la creación del código base y la estructura inicial.*
