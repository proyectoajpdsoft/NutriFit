# Preparación de la App para Google Play Store

## ✅ PASO 1: Generar la clave de firma (EJECUTAR PRIMERO)

Abre PowerShell en `D:\Git\Flutter\Nutricion\nutri_app` y ejecuta:

```powershell
keytool -genkey -v -keystore android\app\nutricion_release_key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nutricion_app
```

**Te pedirá completar estos campos:**
- **Contraseña de la clave del repositorio:** `TuContraseñaSegura123` (o la que prefieras)
- **Nombre y Apellidos:** Patricia Nutrición
- **Nombre de la organización:** Aprendé con Patricia  
- **Ciudad:** (tu ciudad)
- **Provincia:** (tu provincia)
- **País:** ES
- **¿Es correcto?** yes
- **Contraseña del alias:** (la misma que arriba)

**Resultado:** Se creará `android/app/nutricion_release_key.jks`

---

## ✅ PASO 2: Actualizar la configuración de Gradle

**YA HECHO** - El archivo `android/app/build.gradle.kts` ha sido actualizado con:
- ✅ Package ID: `com.aprendeconcatricia.nutricion`
- ✅ Clave de firma configurada
- ✅ Firma automática para release builds

---

## ✅ PASO 3: Generar el App Bundle (AAB)

Ejecuta este comando en PowerShell desde `D:\Git\Flutter\Nutricion\nutri_app`:

```powershell
flutter build appbundle --release
```

**Espera a que se complete** (puede tardar 5-10 minutos)

**Resultado:** Se generará: `build/app/outputs/bundle/release/app-release.aab`

---

## ✅ PASO 4: Crear cuenta en Google Play Console

1. Ve a https://play.google.com/console
2. Haz clic en **"Create app"**
3. Rellena:
   - **App name:** NutriFit
   - **Default language:** Spanish (Español)
   - **App or game:** App
   - **Free or paid:** Free
   - **Aceptar las políticas**

---

## ✅ PASO 5: Completar información de la app

En Google Play Console, rellena:

### **1. App details**
- **App name:** NutriFit
- **Short description:** Gestión de nutrición y ejercicio
- **Full description:** Una aplicación completa para nutricionistas y entrenadores personales. Gestiona citas, pacientes, entrenamientos, mediciones y planes nutricionales.
- **Icon:** Usa tu logo (512x512 PNG)
- **Feature graphic:** 1024x500 PNG (opcional)
- **Screenshots:** Al menos 2 de móvil

### **2. Category & contact details**
- **App category:** Health & Fitness o Lifestyle
- **Contact email:** tu@email.com

### **3. Pricing & distribution**
- **Countries:** Selecciona donde quieres distribuir
- **Content rating:** Completa el cuestionario

---

## ✅ PASO 6: Crear un release

En Google Play Console:

1. **Vete a:** Releases → Production → Create new release
2. **Sube el APK/AAB:**
   - Click en **"Upload"**
   - Selecciona: `build/app/outputs/bundle/release/app-release.aab`
3. **Rellena:**
   - **Release name:** v1.0.0 (o tu versión)
   - **Release notes:** First release of NutriFit

---

## ✅ PASO 7: Información de privacidad

En Google Play Console:

1. **Policy & Programs → App policies**
2. **Content rating questionnaire:** Completa
3. **Privacy policy URL:** Pon tu URL de privacidad (o crea una temporal)
4. **Permissions:** Revisa los permisos solicitados

---

## ✅ PASO 8: Enviar para revisión

1. En "Releases" → Production → Review
2. Lee y acepta todos los requisitos
3. **Click en "Submit for Review"**

**Google Play Store revisará tu app (24-48 horas usualmente)**

---

## 📋 Información de tu App

| Campo | Valor |
|-------|-------|
| **Package Name** | com.aprendeconcatricia.nutricion |
| **App Name** | NutriFit |
| **Version** | 1.0.0+1 |
| **Min SDK** | 21 |
| **Target SDK** | 34 |
| **Signing Key** | nutricion_release_key.jks |
| **Key Alias** | nutricion_app |

---

## ⚠️ IMPORTANTE

1. **Guarda las contraseñas en un lugar seguro:**
   - Contraseña del keystore
   - Contraseña del alias
   - Son necesarias para TODOS los updates futuros

2. **Nunca publiques el keystore:**
   ```
   android/app/nutricion_release_key.jks
   ```
   Está en .gitignore pero verifica

3. **Para updates futuros:**
   - Aumenta `versionCode` y `versionName` en `pubspec.yaml`
   - Ejecuta `flutter build appbundle --release`
   - Crea un nuevo release en Google Play Console

---

## 🚀 Comandos útiles

**Generar AAB completo:**
```bash
flutter pub get
flutter analyze
flutter build appbundle --release
```

**Ver información del APK:**
```bash
bundletool dump manifest --bundle=app-release.aab
```

**Instalar en dispositivo local para pruebas:**
```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

**¿Necesitas ayuda en algún paso?**
