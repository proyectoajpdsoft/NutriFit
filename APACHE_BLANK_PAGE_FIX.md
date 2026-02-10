# 🔧 Solución: Página en Blanco en Apache

## Problema
La aplicación Flutter Web muestra solo una página vacía/blanca cuando se despliega en Apache.

## ✅ Solución Rápida (3 pasos)

### 1. Copia el archivo `.htaccess` al servidor

El archivo `.htaccess` ya está incluido en `build/web/.htaccess`. Asegúrate de copiarlo junto con los demás archivos.

**Ubicación local**: `D:\Git\Flutter\Nutricion\nutri_app\build\web\.htaccess`

**Ubicación servidor**: Debe estar en el mismo directorio que `index.html`

### 2. Verifica módulos Apache habilitados

En el servidor, ejecuta:
```bash
sudo a2enmod rewrite
sudo a2enmod headers
sudo a2enmod mime
sudo systemctl restart apache2
```

### 3. Configura `AllowOverride All` en Apache

Edita la configuración de Apache (usualmente `/etc/apache2/sites-available/000-default.conf`):

```apache
<Directory /var/www/html>
    AllowOverride All    # ← Cambiar de "None" a "All"
    Require all granted
</Directory>
```

Luego reinicia Apache:
```bash
sudo systemctl restart apache2
```

---

## 📋 Checklist de Verificación

- [ ] Archivo `.htaccess` existe en el directorio de la app
- [ ] Módulo `mod_rewrite` habilitado
- [ ] Módulo `mod_headers` habilitado  
- [ ] Módulo `mod_mime` habilitado
- [ ] `AllowOverride All` en configuración Apache
- [ ] Permisos correctos: `chmod -R 755` en el directorio
- [ ] Propietario correcto: `chown -R www-data:www-data`

---

## 🔍 Diagnóstico

### En el navegador (Developer Tools - F12):

1. **Pestaña "Network"**:
   - Recarga la página
   - Busca `flutter_bootstrap.js` → debe devolver código **200** (not 404 or 403)
   - Busca `main.dart.js` → debe devolver código **200**

2. **Pestaña "Console"**:
   - No debe haber errores en rojo
   - Si dice "Failed to load resource" → problema de rutas o permisos

### En el servidor:

1. **Verificar que `.htaccess` existe**:
   ```bash
   ls -la /var/www/html/nutriapp/.htaccess
   ```

2. **Verificar módulos Apache**:
   ```bash
   apache2ctl -M | grep rewrite
   apache2ctl -M | grep headers
   ```

3. **Verificar permisos**:
   ```bash
   ls -la /var/www/html/nutriapp/
   # Todos los archivos deben ser legibles (r--) y directorios ejecutables (x)
   ```

4. **Ver logs de Apache**:
   ```bash
   sudo tail -f /var/log/apache2/error.log
   # Recarga la página en el navegador y observa errores
   ```

---

## 🚨 Caso Especial: App en Subdirectorio

Si tu app NO está en la raíz (ejemplo: `http://servidor.com/nutriapp/` en lugar de `http://servidor.com/`):

### Opción A: Modificar `.htaccess`
Edita el archivo `.htaccess` y cambia:
```apache
RewriteBase /
```
Por:
```apache
RewriteBase /nutriapp/
```

### Opción B: Recompilar (RECOMENDADO)
Recompila la app con el base-href correcto:
```bash
flutter build web --release --base-href /nutriapp/
```

Luego copia nuevamente todos los archivos al servidor.

---

## 📞 ¿Sigue sin funcionar?

### Prueba con servidor Python (diagnóstico)

Para descartar problemas de Apache, prueba la app localmente con Python:

```bash
cd D:\Git\Flutter\Nutricion\nutri_app\build\web
python -m http.server 8080
```

Abre `http://localhost:8080` en el navegador:
- ✅ **Si funciona**: El problema es configuración de Apache
- ❌ **Si no funciona**: El problema es la compilación

### Contenido correcto del `.htaccess`

Verifica que el contenido de `.htaccess` sea exactamente:

```apache
# Configuración para Flutter Web en Apache

RewriteEngine On
RewriteBase /

RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)$ index.html [QSA,L]

<IfModule mod_mime.c>
    AddType application/javascript .js
    AddType application/json .json
    AddType text/css .css
    AddType image/x-icon .ico
    AddType image/png .png
</IfModule>

<IfModule mod_headers.c>
    Header set Access-Control-Allow-Origin "*"
</IfModule>
```

---

## ✅ Resultado Esperado

Después de aplicar estos pasos, la aplicación debe cargar completamente mostrando la pantalla de login.

Si sigues teniendo problemas, revisa los logs de Apache y la consola del navegador para obtener más detalles del error específico.
