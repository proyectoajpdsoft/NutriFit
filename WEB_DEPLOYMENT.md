# NutriApp - Despliegue Web

La aplicación ha sido compilada exitosamente para web. Aquí se encuentran las instrucciones para ejecutarla.

## 🚀 Resumen Rápido (Producción con Nginx)

**Lo que necesitas:**
- ✅ Servidor Linux con Nginx instalado
- ✅ Archivos compilados en: `D:\Git\Flutter\Nutricion\nutri_app\build\web`
- ✅ API PHP funcionando (ya la tienes en `http://ipcasa.ajpdsoft.com:8080/apirestnu/`)
- ✅ (Opcional) Certificado SSL con Let's Encrypt para HTTPS

**Pasos básicos:**
1. Copiar contenido de `build/web` al servidor → `/var/www/html/nutriapp`
2. Configurar Nginx con el archivo de configuración (ver abajo)
3. Verificar CORS en tu API PHP (probablemente ya está configurado)
4. Activar sitio y reiniciar Nginx
5. ¡Listo! Accede desde `http://tu-dominio.com`

---

## Requisitos

- Un servidor web (Apache, Nginx, Python, Node.js, etc.)
- O utilizar el servidor de desarrollo de Flutter

## Opción 1: Servidor de Desarrollo de Flutter (Recomendado para pruebas)

```bash
cd D:\Git\Flutter\Nutricion\nutri_app
flutter run -d web
```

Esto abrirá automáticamente la aplicación en tu navegador predeterminado en `http://localhost:8080`

## Opción 2: Servidor HTTP con Python

Si tienes Python instalado, puedes ejecutar un servidor HTTP simple:

```bash
cd D:\Git\Flutter\Nutricion\nutri_app\build\web
python -m http.server 8080
```

Luego abre en tu navegador: `http://localhost:8080`

## Opción 3: Servidor HTTP con Node.js

Si tienes Node.js instalado con `http-server`:

```bash
cd D:\Git\Flutter\Nutricion\nutri_app\build\web
http-server -p 8080
```

Luego abre en tu navegador: `http://localhost:8080`

## Opción 4: Despliegue en Producción

Los archivos compilados están en:
```
D:\Git\Flutter\Nutricion\nutri_app\build\web
```

Copia toda la carpeta `web` a tu servidor web (Apache, Nginx, etc.).

### Configuración recomendada para Apache

**IMPORTANTE**: El archivo `.htaccess` está incluido en `build/web/.htaccess` - cópialo junto con los demás archivos.

1. Copia la carpeta `web` a `/var/www/html/nutri_app`:
   ```bash
   sudo cp -r build/web/* /var/www/html/nutri_app/
   ```

2. Asegúrate de que todos los archivos tengan permisos correctos:
   ```bash
   sudo chmod -R 755 /var/www/html/nutri_app
   sudo chown -R www-data:www-data /var/www/html/nutri_app
   ```

3. Verifica que Apache tenga habilitados los módulos necesarios:
   ```bash
   sudo a2enmod rewrite
   sudo a2enmod headers
   sudo a2enmod mime
   sudo systemctl restart apache2
   ```

4. Verifica la configuración Apache permita `.htaccess` (`/etc/apache2/sites-available/000-default.conf`):
   ```apache
   <Directory /var/www/html>
       AllowOverride All    # ← Debe ser "All"
       Require all granted
   </Directory>
   ```

5. Si la app está en un **subdirectorio** (no en raíz):
   - Edita `build/web/.htaccess` y cambia `RewriteBase /` por `RewriteBase /nutri_app/`
   - O recompila: `flutter build web --base-href /nutri_app/`

6. Accede a través de: `http://tu-servidor.com/nutri_app`

### Configuración para Windows + IIS

Si usas Windows Server con IIS:

1. Copia `build\web` a `C:\inetpub\wwwroot\nutriapp`

2. Crea un archivo `web.config` en ese directorio:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <system.webServer>
        <rewrite>
            <rules>
                <rule name="Flutter Web Routes" stopProcessing="true">
                    <match url=".*" />
                    <conditions logicalGrouping="MatchAll">
                        <add input="{REQUEST_FILENAME}" matchType="IsFile" negate="true" />
                        <add input="{REQUEST_FILENAME}" matchType="IsDirectory" negate="true" />
                    </conditions>
                    <action type="Rewrite" url="/index.html" />
                </rule>
            </rules>
        </rewrite>
        <staticContent>
            <mimeMap fileExtension=".json" mimeType="application/json" />
            <mimeMap fileExtension=".wasm" mimeType="application/wasm" />
        </staticContent>
        <httpProtocol>
            <customHeaders>
                <add name="Cache-Control" value="no-cache, no-store, must-revalidate" />
            </customHeaders>
        </httpProtocol>
    </system.webServer>
</configuration>
```

3. Habilitar la extensión "URL Rewrite" en IIS
4. Accede a través de: `http://tu-servidor.com/nutriapp`

### Configuración recomendada para Nginx

**Paso 1: Instalar Nginx (si no lo tienes)**

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nginx

# CentOS/RHEL
sudo yum install nginx

# Windows (usar instalador o ejecutar con Docker)
```

**Paso 2: Copiar archivos de la aplicación**

```bash
# Crear directorio para la aplicación
sudo mkdir -p /var/www/html/nutriapp

# Copiar los archivos compilados
sudo cp -r D:\Git\Flutter\Nutricion\nutri_app\build\web/* /var/www/html/nutriapp/

# Asignar permisos correctos
sudo chown -R www-data:www-data /var/www/html/nutriapp
sudo chmod -R 755 /var/www/html/nutriapp
```

**Paso 3: Configurar Nginx**

Crea el archivo `/etc/nginx/sites-available/nutriapp`:

```nginx
server {
    listen 80;
    server_name tu-dominio.com;  # Cambia esto por tu dominio o IP
    
    root /var/www/html/nutriapp;
    index index.html;

    # Logs
    access_log /var/log/nginx/nutriapp-access.log;
    error_log /var/log/nginx/nutriapp-error.log;

    # Soporte para Flutter Web
    location / {
        try_files $uri $uri/ /index.html;
        
        # Headers para Flutter Web
        add_header Cache-Control "public, max-age=3600";
    }

    # Assets con cache largo (optimización)
    location /assets/ {
        try_files $uri =404;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    # CanvasKit
    location /canvaskit/ {
        try_files $uri =404;
        add_header Cache-Control "public, max-age=31536000";
    }

    # Archivos JavaScript
    location ~* \.(js|json)$ {
        try_files $uri =404;
        add_header Cache-Control "public, max-age=86400";
    }

    # Deshabilitar cache para index.html y service worker
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    location = /flutter_service_worker.js {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # Compresión GZIP
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript 
               application/x-javascript application/xml+rss 
               application/javascript application/json;
}
```

**Paso 4: Activar el sitio**

```bash
# Crear enlace simbólico
sudo ln -s /etc/nginx/sites-available/nutriapp /etc/nginx/sites-enabled/

# Verificar configuración
sudo nginx -t

# Si todo está OK, reiniciar Nginx
sudo systemctl restart nginx
```

**Paso 5: (Opcional) Configurar HTTPS con Let's Encrypt**

```bash
# Instalar certbot
sudo apt install certbot python3-certbot-nginx

# Obtener certificado SSL
sudo certbot --nginx -d tu-dominio.com

# Certbot modificará automáticamente tu configuración de Nginx
```

## Nota Importante sobre CORS

**Si accedes a la API desde un dominio diferente** (por ejemplo, la app en `https://nutriapp.com` y la API en `http://ipcasa.ajpdsoft.com:8080`), necesitas configurar CORS.

### Opción 1: CORS en PHP (Ya configurado en tu API)

Verifica que todos tus archivos PHP en `php_api/api/` tengan estas cabeceras al inicio:

```php
<?php
// Permitir acceso desde cualquier origen
header("Access-Control-Allow-Origin: *");

// O especificar dominios específicos (más seguro)
// header("Access-Control-Allow-Origin: https://nutriapp.com");

header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Max-Age: 3600");
header("Content-Type: application/json; charset=UTF-8");

// Responder a preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}
```

### Opción 2: CORS en Nginx (proxy inverso)

Si tu API PHP también está en Nginx, agrega esta configuración:

```nginx
server {
    listen 8080;
    server_name api.tu-dominio.com;
    
    root /var/www/php_api;
    index index.php;

    # Configuración PHP-FPM
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;  # Ajusta la versión de PHP
        
        # CORS Headers
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization' always;
        add_header 'Access-Control-Max-Age' 3600 always;
        
        # Manejar preflight
        if ($request_method = 'OPTIONS') {
            return 204;
        }
    }
}
```

### Opción 3: CORS en Apache (.htaccess)

Si usas Apache, crea un archivo `.htaccess` en `php_api/`:

```apache
# Habilitar CORS
Header always set Access-Control-Allow-Origin "*"
Header always set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
Header always set Access-Control-Allow-Headers "Content-Type, Authorization"
Header always set Access-Control-Max-Age "3600"

# Responder a OPTIONS con 200
RewriteEngine On
RewriteCond %{REQUEST_METHOD} OPTIONS
RewriteRule ^(.*)$ $1 [R=200,L]
```

## Navegadores Soportados

- Chrome/Chromium (recomendado)
- Firefox
- Safari
- Edge

## Problemas Comunes

### ⚠️ La página aparece vacía/blanca (PROBLEMA MÁS COMÚN)

**Síntoma**: El HTML se carga pero la aplicación no aparece, solo página en blanco.

**Causa**: Los archivos JavaScript (flutter_bootstrap.js, main.dart.js) no se cargan correctamente.

**Solución para Apache:**

1. **Crear archivo `.htaccess`** en el directorio donde está desplegada la app:
   ```bash
   cd /var/www/html/nutriapp  # o donde esté tu carpeta web
   nano .htaccess
   ```

2. **Contenido del `.htaccess`** (YA INCLUIDO en `build/web/.htaccess`):
   ```apache
   RewriteEngine On
   RewriteBase /
   
   # Permitir archivos estáticos
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule ^(.*)$ index.html [QSA,L]
   
   # MIME types correctos
   <IfModule mod_mime.c>
       AddType application/javascript .js
       AddType application/json .json
   </IfModule>
   ```

3. **Si la app NO está en la raíz** del servidor (ej: `http://servidor.com/nutriapp/`):
   - Cambia `RewriteBase /` por `RewriteBase /nutriapp/`
   - O recompila con: `flutter build web --base-href /nutriapp/`

4. **Verificar módulos Apache habilitados**:
   ```bash
   sudo a2enmod rewrite
   sudo a2enmod headers
   sudo a2enmod mime
   sudo systemctl restart apache2
   ```

5. **Verificar permisos**:
   ```bash
   sudo chmod -R 755 /var/www/html/nutriapp
   sudo chown -R www-data:www-data /var/www/html/nutriapp
   ```

6. **Verificar configuración Apache** (`/etc/apache2/sites-available/000-default.conf`):
   ```apache
   <Directory /var/www/html>
       AllowOverride All    # ← DEBE estar en "All" para que .htaccess funcione
       Require all granted
   </Directory>
   ```

**Verificar en el navegador:**
- Abre Developer Tools (F12) → Pestaña "Network"
- Recarga la página
- Verifica que `flutter_bootstrap.js` y `main.dart.js` se cargan con código 200 (no 404 o 403)
- Pestaña "Console" → verifica que no haya errores en rojo

### La aplicación no carga
- Verifica que el servidor web está ejecutándose
- Comprueba que la URL es correcta
- Abre la consola del navegador (F12) para ver errores

### API no responde
- Verifica que la configuración de API en la aplicación es correcta
- Comprueba que el servidor PHP está ejecutándose
- Verifica la configuración de CORS

### Recursos no cargan
- Asegúrate de que los archivos se copiaron completamente
- Verifica los permisos de lectura en el servidor
- Revisa el archivo `.htaccess` y MIME types

## Información Técnica

- **Framework**: Flutter 3.x
- **Tipo de compilación**: Web (JavaScript)
- **Tamaño aproximado**: 50-100 MB (sin comprimir)
- **Plataformas soportadas**: Todos los navegadores modernos
