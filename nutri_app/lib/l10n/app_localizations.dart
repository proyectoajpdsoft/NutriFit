import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pt')
  ];

  /// No description provided for @settingsAndPrivacyTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes y privacidad'**
  String get settingsAndPrivacyTitle;

  /// No description provided for @settingsAndPrivacyMenuLabel.
  ///
  /// In es, this message translates to:
  /// **'Ajustes y privacidad'**
  String get settingsAndPrivacyMenuLabel;

  /// No description provided for @configTabParameters.
  ///
  /// In es, this message translates to:
  /// **'Parámetros'**
  String get configTabParameters;

  /// No description provided for @configTabPremium.
  ///
  /// In es, this message translates to:
  /// **'Premium'**
  String get configTabPremium;

  /// No description provided for @configTabAppMenu.
  ///
  /// In es, this message translates to:
  /// **'Menú app'**
  String get configTabAppMenu;

  /// No description provided for @configTabGeneral.
  ///
  /// In es, this message translates to:
  /// **'General'**
  String get configTabGeneral;

  /// No description provided for @configTabSecurity.
  ///
  /// In es, this message translates to:
  /// **'Seguridad'**
  String get configTabSecurity;

  /// No description provided for @configTabUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get configTabUser;

  /// No description provided for @configTabDisplay.
  ///
  /// In es, this message translates to:
  /// **'Mostrar'**
  String get configTabDisplay;

  /// No description provided for @configTabDefaults.
  ///
  /// In es, this message translates to:
  /// **'Defecto'**
  String get configTabDefaults;

  /// No description provided for @configTabPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Privacidad'**
  String get configTabPrivacy;

  /// No description provided for @securitySubtabAccess.
  ///
  /// In es, this message translates to:
  /// **'Acceso'**
  String get securitySubtabAccess;

  /// No description provided for @securitySubtabEmailServer.
  ///
  /// In es, this message translates to:
  /// **'Servidor Email'**
  String get securitySubtabEmailServer;

  /// No description provided for @securitySubtabCipher.
  ///
  /// In es, this message translates to:
  /// **'Cifrado/Descifrado'**
  String get securitySubtabCipher;

  /// No description provided for @securitySubtabSessions.
  ///
  /// In es, this message translates to:
  /// **'Sesiones'**
  String get securitySubtabSessions;

  /// No description provided for @securitySubtabAccesses.
  ///
  /// In es, this message translates to:
  /// **'Accesos'**
  String get securitySubtabAccesses;

  /// No description provided for @privacyCenterTab.
  ///
  /// In es, this message translates to:
  /// **'Centro'**
  String get privacyCenterTab;

  /// No description provided for @privacyPolicyTab.
  ///
  /// In es, this message translates to:
  /// **'Política'**
  String get privacyPolicyTab;

  /// No description provided for @privacySessionsTab.
  ///
  /// In es, this message translates to:
  /// **'Sesiones'**
  String get privacySessionsTab;

  /// No description provided for @privacyLastUpdatedLabel.
  ///
  /// In es, this message translates to:
  /// **'Última actualización: {date}'**
  String privacyLastUpdatedLabel(Object date);

  /// No description provided for @privacyIntro.
  ///
  /// In es, this message translates to:
  /// **'Esta sección muestra la Política de Privacidad actualizada de NutriFitApp, explica cómo se tratan los datos personales conforme al RGPD y la LOPDGDD y detalla cómo eliminar la cuenta y todos los datos desde la propia app.'**
  String get privacyIntro;

  /// No description provided for @privacyPrintPdf.
  ///
  /// In es, this message translates to:
  /// **'Imprimir / guardar en PDF'**
  String get privacyPrintPdf;

  /// No description provided for @privacyPdfGenerateError.
  ///
  /// In es, this message translates to:
  /// **'Error al generar el PDF de privacidad: {error}'**
  String privacyPdfGenerateError(Object error);

  /// No description provided for @privacyCannotIdentifyUser.
  ///
  /// In es, this message translates to:
  /// **'No se pudo identificar al usuario actual.'**
  String get privacyCannotIdentifyUser;

  /// No description provided for @privacyOpenProfileError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir Editar Perfil: {error}'**
  String privacyOpenProfileError(Object error);

  /// No description provided for @privacyDeleteDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar todos mis datos'**
  String get privacyDeleteDialogTitle;

  /// No description provided for @privacyDeleteDialogIntro.
  ///
  /// In es, this message translates to:
  /// **'Esta acción elimina tu cuenta y los datos asociados a ella conforme al derecho de supresión.'**
  String get privacyDeleteDialogIntro;

  /// No description provided for @privacyDeleteDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminarán los inicios de sesión, chats, control de peso, lista de la compra, actividades, tareas, entrenamientos, ejercicios e imágenes vinculadas a tu usuario.'**
  String get privacyDeleteDialogBody;

  /// No description provided for @privacyDeleteDialogWarning.
  ///
  /// In es, this message translates to:
  /// **'La acción es irreversible y cerrará tu sesión.'**
  String get privacyDeleteDialogWarning;

  /// No description provided for @privacyDeleteTypedTitle.
  ///
  /// In es, this message translates to:
  /// **'Confirmación final'**
  String get privacyDeleteTypedTitle;

  /// No description provided for @privacyDeleteTypedPrompt.
  ///
  /// In es, this message translates to:
  /// **'Para confirmar, escribe {keyword} en mayúsculas:'**
  String privacyDeleteTypedPrompt(Object keyword);

  /// No description provided for @privacyDeleteTypedHint.
  ///
  /// In es, this message translates to:
  /// **'{keyword}'**
  String privacyDeleteTypedHint(Object keyword);

  /// No description provided for @privacyDeleteTypedMismatch.
  ///
  /// In es, this message translates to:
  /// **'Debes escribir {keyword} para confirmar.'**
  String privacyDeleteTypedMismatch(Object keyword);

  /// No description provided for @commonCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @privacyDeleteMyData.
  ///
  /// In es, this message translates to:
  /// **'Eliminar mis datos'**
  String get privacyDeleteMyData;

  /// No description provided for @privacyDeleteConnectionError.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido realizar el proceso. Revise la conexión a Internet.'**
  String get privacyDeleteConnectionError;

  /// No description provided for @privacyDeleteAccountFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar la cuenta.'**
  String get privacyDeleteAccountFailed;

  /// No description provided for @privacyActionPolicyTitle.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get privacyActionPolicyTitle;

  /// No description provided for @privacyActionPolicyDescription.
  ///
  /// In es, this message translates to:
  /// **'Consulta el texto completo de privacidad, derechos del usuario y tratamiento de datos según RGPD y LOPDGDD.'**
  String get privacyActionPolicyDescription;

  /// No description provided for @privacyViewPolicy.
  ///
  /// In es, this message translates to:
  /// **'Ver política'**
  String get privacyViewPolicy;

  /// No description provided for @privacyPdfShort.
  ///
  /// In es, this message translates to:
  /// **'PDF'**
  String get privacyPdfShort;

  /// No description provided for @privacyActionSecurityTitle.
  ///
  /// In es, this message translates to:
  /// **'Seguridad y acceso'**
  String get privacyActionSecurityTitle;

  /// No description provided for @privacyActionSecurityDescription.
  ///
  /// In es, this message translates to:
  /// **'Accede a Editar Perfil para gestionar el correo, el doble factor (2FA), dispositivos de confianza y otros controles de acceso a tu cuenta.'**
  String get privacyActionSecurityDescription;

  /// No description provided for @privacyOpenEditProfile.
  ///
  /// In es, this message translates to:
  /// **'Abrir Editar Perfil'**
  String get privacyOpenEditProfile;

  /// No description provided for @privacyActionSessionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Inicios de sesión'**
  String get privacyActionSessionsTitle;

  /// No description provided for @privacyActionSessionsDescription.
  ///
  /// In es, this message translates to:
  /// **'Consulta las últimas sesiones exitosas, intentos fallidos y la actividad de acceso asociada a tu cuenta.'**
  String get privacyActionSessionsDescription;

  /// No description provided for @privacyViewSessions.
  ///
  /// In es, this message translates to:
  /// **'Ver sesiones'**
  String get privacyViewSessions;

  /// No description provided for @privacyActionDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar todos mis datos'**
  String get privacyActionDeleteTitle;

  /// No description provided for @privacyActionDeleteDescription.
  ///
  /// In es, this message translates to:
  /// **'Puedes solicitar la eliminación completa de tu cuenta y de los datos asociados directamente desde la app. La acción es irreversible y cerrará tu sesión.'**
  String get privacyActionDeleteDescription;

  /// No description provided for @sessionsUserCodeUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Código de usuario no disponible'**
  String get sessionsUserCodeUnavailable;

  /// No description provided for @sessionsAnonymousGuestInfo.
  ///
  /// In es, this message translates to:
  /// **'No hay datos de sesión disponibles para usuarios sin registrar, ya que el acceso se realiza de forma anónima.'**
  String get sessionsAnonymousGuestInfo;

  /// No description provided for @sessionsError.
  ///
  /// In es, this message translates to:
  /// **'Error: {error}'**
  String sessionsError(Object error);

  /// No description provided for @commonRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get commonRetry;

  /// No description provided for @sessionsNoDataAvailable.
  ///
  /// In es, this message translates to:
  /// **'No hay datos de sesión disponibles'**
  String get sessionsNoDataAvailable;

  /// No description provided for @sessionsSuccessfulTitle.
  ///
  /// In es, this message translates to:
  /// **'Últimos Inicios de Sesión Exitosos'**
  String get sessionsSuccessfulTitle;

  /// No description provided for @sessionsCurrent.
  ///
  /// In es, this message translates to:
  /// **'Sesión actual:'**
  String get sessionsCurrent;

  /// No description provided for @sessionsPrevious.
  ///
  /// In es, this message translates to:
  /// **'Sesión anterior:'**
  String get sessionsPrevious;

  /// No description provided for @sessionsNoSuccessful.
  ///
  /// In es, this message translates to:
  /// **'No hay sesiones exitosas registradas'**
  String get sessionsNoSuccessful;

  /// No description provided for @sessionsFailedTitle.
  ///
  /// In es, this message translates to:
  /// **'Últimos Intentos de Acceso Fallidos'**
  String get sessionsFailedTitle;

  /// No description provided for @sessionsAttemptNumber.
  ///
  /// In es, this message translates to:
  /// **'Intento {count}:'**
  String sessionsAttemptNumber(Object count);

  /// No description provided for @sessionsNoFailed.
  ///
  /// In es, this message translates to:
  /// **'No hay intentos fallidos registrados.'**
  String get sessionsNoFailed;

  /// No description provided for @sessionsStatsTitle.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas de Sesiones'**
  String get sessionsStatsTitle;

  /// No description provided for @sessionsTotal.
  ///
  /// In es, this message translates to:
  /// **'Total de sesiones: {count}'**
  String sessionsTotal(Object count);

  /// No description provided for @sessionsSuccessfulCount.
  ///
  /// In es, this message translates to:
  /// **'Intentos exitosos: {count}'**
  String sessionsSuccessfulCount(Object count);

  /// No description provided for @sessionsFailedCount.
  ///
  /// In es, this message translates to:
  /// **'Intentos fallidos: {count}'**
  String sessionsFailedCount(Object count);

  /// No description provided for @commonNotAvailable.
  ///
  /// In es, this message translates to:
  /// **'N/D'**
  String get commonNotAvailable;

  /// No description provided for @sessionsDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha: {value}'**
  String sessionsDate(Object value);

  /// No description provided for @sessionsTime.
  ///
  /// In es, this message translates to:
  /// **'Hora: {value}'**
  String sessionsTime(Object value);

  /// No description provided for @sessionsDevice.
  ///
  /// In es, this message translates to:
  /// **'Dispositivo: {value}'**
  String sessionsDevice(Object value);

  /// No description provided for @sessionsIpAddress.
  ///
  /// In es, this message translates to:
  /// **'Dirección IP:'**
  String get sessionsIpAddress;

  /// No description provided for @sessionsPublicIp.
  ///
  /// In es, this message translates to:
  /// **'Pública: {value}'**
  String sessionsPublicIp(Object value);

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad de NutriFitApp'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicyLastUpdated.
  ///
  /// In es, this message translates to:
  /// **'7 de abril de 2026'**
  String get privacyPolicyLastUpdated;

  /// No description provided for @privacyPolicySection1Title.
  ///
  /// In es, this message translates to:
  /// **'1. Responsable del tratamiento'**
  String get privacyPolicySection1Title;

  /// No description provided for @privacyPolicySection1Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'El responsable del tratamiento de los datos personales tratados a través de la aplicación NutriFit es el titular o entidad explotadora del servicio NutriFitApp.'**
  String get privacyPolicySection1Paragraph1;

  /// No description provided for @privacyPolicySection1Paragraph2.
  ///
  /// In es, this message translates to:
  /// **'Datos de contacto del responsable:'**
  String get privacyPolicySection1Paragraph2;

  /// No description provided for @privacyPolicySection1Bullet1.
  ///
  /// In es, this message translates to:
  /// **'Nombre o razón social: Patricia Carmona Fernández.'**
  String get privacyPolicySection1Bullet1;

  /// No description provided for @privacyPolicySection1Bullet2.
  ///
  /// In es, this message translates to:
  /// **'NIF/CIF: Se enviará previa solicitud.'**
  String get privacyPolicySection1Bullet2;

  /// No description provided for @privacyPolicySection1Bullet3.
  ///
  /// In es, this message translates to:
  /// **'Domicilio: Se enviará previa solicitud.'**
  String get privacyPolicySection1Bullet3;

  /// No description provided for @privacyPolicySection1Bullet4.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico de contacto: aprendeconpatrica[ — arroba — ]gmail[ — punto — ]com'**
  String get privacyPolicySection1Bullet4;

  /// No description provided for @privacyPolicySection2Title.
  ///
  /// In es, this message translates to:
  /// **'2. Normativa aplicable'**
  String get privacyPolicySection2Title;

  /// No description provided for @privacyPolicySection2Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'Esta Política de Privacidad se ha redactado de conformidad con la normativa aplicable en materia de protección de datos personales, en particular:'**
  String get privacyPolicySection2Paragraph1;

  /// No description provided for @privacyPolicySection2Bullet1.
  ///
  /// In es, this message translates to:
  /// **'Reglamento (UE) 2016/679 del Parlamento Europeo y del Consejo, de 27 de abril de 2016, Reglamento General de Protección de Datos (RGPD).'**
  String get privacyPolicySection2Bullet1;

  /// No description provided for @privacyPolicySection2Bullet2.
  ///
  /// In es, this message translates to:
  /// **'Ley Orgánica 3/2018, de 5 de diciembre, de Protección de Datos Personales y garantía de los derechos digitales (LOPDGDD).'**
  String get privacyPolicySection2Bullet2;

  /// No description provided for @privacyPolicySection2Bullet3.
  ///
  /// In es, this message translates to:
  /// **'Resto de normativa española y europea que resulte aplicable.'**
  String get privacyPolicySection2Bullet3;

  /// No description provided for @privacyPolicySection3Title.
  ///
  /// In es, this message translates to:
  /// **'3. Qué es NutriFitApp'**
  String get privacyPolicySection3Title;

  /// No description provided for @privacyPolicySection3Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'NutriFitApp es una aplicación orientada a nutrición, salud, deporte, seguimiento de hábitos y organización personal, que puede incluir funciones como perfil de usuario, tareas, lista de la compra, recetas, consejos, sustituciones saludables, entrenamiento, escáner nutricional, notificaciones, aditivos, suplementos, control de peso y herramientas de seguimiento entre usuario y profesional.'**
  String get privacyPolicySection3Paragraph1;

  /// No description provided for @privacyPolicySection4Title.
  ///
  /// In es, this message translates to:
  /// **'4. Qué datos personales tratamos'**
  String get privacyPolicySection4Title;

  /// No description provided for @privacyPolicySection4Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'En función del uso que realices de la app, NutriFitApp puede tratar las siguientes categorías de datos:'**
  String get privacyPolicySection4Paragraph1;

  /// No description provided for @privacyPolicySection4Bullet1.
  ///
  /// In es, this message translates to:
  /// **'Datos identificativos: nombre, nick o alias, correo electrónico, imagen de perfil y otros datos de registro.'**
  String get privacyPolicySection4Bullet1;

  /// No description provided for @privacyPolicySection4Bullet2.
  ///
  /// In es, this message translates to:
  /// **'Datos de acceso y autenticación: credenciales, identificadores de sesión, verificaciones de seguridad y elementos asociados al acceso seguro a la cuenta.'**
  String get privacyPolicySection4Bullet2;

  /// No description provided for @privacyPolicySection4Bullet3.
  ///
  /// In es, this message translates to:
  /// **'Datos de uso de la app: interacciones, preferencias, configuraciones guardadas y acciones realizadas dentro de la aplicación.'**
  String get privacyPolicySection4Bullet3;

  /// No description provided for @privacyPolicySection4Bullet4.
  ///
  /// In es, this message translates to:
  /// **'Datos aportados por el usuario: tareas, notas, comentarios, sensaciones, contenidos introducidos manualmente y otra información facilitada voluntariamente.'**
  String get privacyPolicySection4Bullet4;

  /// No description provided for @privacyPolicySection4Bullet5.
  ///
  /// In es, this message translates to:
  /// **'Datos relacionados con nutrición, bienestar, actividad física o seguimiento personal que el usuario decida incorporar a la aplicación.'**
  String get privacyPolicySection4Bullet5;

  /// No description provided for @privacyPolicySection4Bullet6.
  ///
  /// In es, this message translates to:
  /// **'Datos técnicos y del dispositivo: identificadores técnicos, versión de la app, sistema operativo, configuración de idioma, datos mínimos necesarios para funcionamiento, seguridad y diagnóstico.'**
  String get privacyPolicySection4Bullet6;

  /// No description provided for @privacyPolicySection4Bullet7.
  ///
  /// In es, this message translates to:
  /// **'Datos derivados de notificaciones push, en caso de que el usuario las active.'**
  String get privacyPolicySection4Bullet7;

  /// No description provided for @privacyPolicySection4Bullet8.
  ///
  /// In es, this message translates to:
  /// **'Datos de cámara o imágenes, si el usuario utiliza funciones como imagen de perfil, escáner o captura de contenido, imágenes en actividades.'**
  String get privacyPolicySection4Bullet8;

  /// No description provided for @privacyPolicySection4Bullet9.
  ///
  /// In es, this message translates to:
  /// **'Datos vinculados a funciones de calendario, si el usuario decide usar integraciones de agenda.'**
  String get privacyPolicySection4Bullet9;

  /// No description provided for @privacyPolicySection4Bullet10.
  ///
  /// In es, this message translates to:
  /// **'Otros datos necesarios para prestar correctamente los servicios ofrecidos en la app.'**
  String get privacyPolicySection4Bullet10;

  /// No description provided for @privacyPolicySection4Paragraph2.
  ///
  /// In es, this message translates to:
  /// **'Si en determinados casos se tratan datos relacionados con salud o bienestar personal, dicho tratamiento se realizará únicamente en la medida necesaria para prestar la funcionalidad solicitada por el usuario y conforme a la base jurídica aplicable.'**
  String get privacyPolicySection4Paragraph2;

  /// No description provided for @privacyPolicySection5Title.
  ///
  /// In es, this message translates to:
  /// **'5. Finalidades del tratamiento'**
  String get privacyPolicySection5Title;

  /// No description provided for @privacyPolicySection5Bullet1.
  ///
  /// In es, this message translates to:
  /// **'Crear y gestionar la cuenta de usuario.'**
  String get privacyPolicySection5Bullet1;

  /// No description provided for @privacyPolicySection5Bullet2.
  ///
  /// In es, this message translates to:
  /// **'Permitir el inicio de sesión y mantener la sesión autenticada.'**
  String get privacyPolicySection5Bullet2;

  /// No description provided for @privacyPolicySection5Bullet3.
  ///
  /// In es, this message translates to:
  /// **'Prestar las funcionalidades principales de NutriFitApp.'**
  String get privacyPolicySection5Bullet3;

  /// No description provided for @privacyPolicySection5Bullet4.
  ///
  /// In es, this message translates to:
  /// **'Gestionar el perfil del usuario.'**
  String get privacyPolicySection5Bullet4;

  /// No description provided for @privacyPolicySection5Bullet5.
  ///
  /// In es, this message translates to:
  /// **'Permitir el seguimiento de hábitos, tareas, entrenamiento, nutrición y contenidos relacionados.'**
  String get privacyPolicySection5Bullet5;

  /// No description provided for @privacyPolicySection5Bullet6.
  ///
  /// In es, this message translates to:
  /// **'Facilitar la interacción entre usuario y profesional cuando esa funcionalidad esté habilitada.'**
  String get privacyPolicySection5Bullet6;

  /// No description provided for @privacyPolicySection5Bullet7.
  ///
  /// In es, this message translates to:
  /// **'Enviar notificaciones relacionadas con la actividad de la cuenta o con funciones utilizadas por el usuario.'**
  String get privacyPolicySection5Bullet7;

  /// No description provided for @privacyPolicySection5Bullet8.
  ///
  /// In es, this message translates to:
  /// **'Mejorar la experiencia de uso, estabilidad, seguridad y rendimiento de la app.'**
  String get privacyPolicySection5Bullet8;

  /// No description provided for @privacyPolicySection5Bullet9.
  ///
  /// In es, this message translates to:
  /// **'Atender solicitudes, incidencias o consultas remitidas por el usuario.'**
  String get privacyPolicySection5Bullet9;

  /// No description provided for @privacyPolicySection5Bullet10.
  ///
  /// In es, this message translates to:
  /// **'Cumplir obligaciones legales aplicables.'**
  String get privacyPolicySection5Bullet10;

  /// No description provided for @privacyPolicySection5Bullet11.
  ///
  /// In es, this message translates to:
  /// **'Defender los intereses legítimos del responsable en materia de seguridad, prevención del fraude, integridad del servicio y protección frente a accesos no autorizados.'**
  String get privacyPolicySection5Bullet11;

  /// No description provided for @privacyPolicySection6Title.
  ///
  /// In es, this message translates to:
  /// **'6. Base jurídica'**
  String get privacyPolicySection6Title;

  /// No description provided for @privacyPolicySection6Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'Las bases jurídicas que legitiman el tratamiento pueden ser, según el caso:'**
  String get privacyPolicySection6Paragraph1;

  /// No description provided for @privacyPolicySection6Bullet1.
  ///
  /// In es, this message translates to:
  /// **'La ejecución de la relación contractual o precontractual cuando el usuario se registra y utiliza NutriFitApp.'**
  String get privacyPolicySection6Bullet1;

  /// No description provided for @privacyPolicySection6Bullet2.
  ///
  /// In es, this message translates to:
  /// **'El consentimiento del usuario para aquellas funcionalidades que lo requieran.'**
  String get privacyPolicySection6Bullet2;

  /// No description provided for @privacyPolicySection6Bullet3.
  ///
  /// In es, this message translates to:
  /// **'El cumplimiento de obligaciones legales.'**
  String get privacyPolicySection6Bullet3;

  /// No description provided for @privacyPolicySection6Bullet4.
  ///
  /// In es, this message translates to:
  /// **'El interés legítimo del responsable en garantizar la seguridad, continuidad y correcto funcionamiento de la aplicación.'**
  String get privacyPolicySection6Bullet4;

  /// No description provided for @privacyPolicySection6Paragraph2.
  ///
  /// In es, this message translates to:
  /// **'Cuando el tratamiento se base en el consentimiento, el usuario podrá retirarlo en cualquier momento, sin que ello afecte a la licitud del tratamiento previo a su retirada.'**
  String get privacyPolicySection6Paragraph2;

  /// No description provided for @privacyPolicySection7Title.
  ///
  /// In es, this message translates to:
  /// **'7. Conservación de los datos'**
  String get privacyPolicySection7Title;

  /// No description provided for @privacyPolicySection7Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'Los datos personales se conservarán durante el tiempo necesario para cumplir con la finalidad para la que fueron recogidos y, posteriormente, durante los plazos legalmente exigibles para atender posibles responsabilidades.'**
  String get privacyPolicySection7Paragraph1;

  /// No description provided for @privacyPolicySection7Paragraph2.
  ///
  /// In es, this message translates to:
  /// **'Cuando el usuario solicite la eliminación de su cuenta, sus datos serán suprimidos o anonimizados conforme a la política interna de retención y a las obligaciones legales que pudieran resultar aplicables.'**
  String get privacyPolicySection7Paragraph2;

  /// No description provided for @privacyPolicySection8Title.
  ///
  /// In es, this message translates to:
  /// **'8. Eliminación de datos por parte del usuario'**
  String get privacyPolicySection8Title;

  /// No description provided for @privacyPolicySection8Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'NutriFitApp permite al usuario eliminar todos sus datos, suprimiendo su cuenta directamente desde la propia aplicación en cualquier momento.'**
  String get privacyPolicySection8Paragraph1;

  /// No description provided for @privacyPolicySection8Paragraph2.
  ///
  /// In es, this message translates to:
  /// **'Pasos dentro de la app para eliminar la cuenta y sus datos por completo:'**
  String get privacyPolicySection8Paragraph2;

  /// No description provided for @privacyPolicySection8Step1.
  ///
  /// In es, this message translates to:
  /// **'Accede a NutriFitApp con tu usuario.'**
  String get privacyPolicySection8Step1;

  /// No description provided for @privacyPolicySection8Step2.
  ///
  /// In es, this message translates to:
  /// **'Entra en Editar Perfil.'**
  String get privacyPolicySection8Step2;

  /// No description provided for @privacyPolicySection8Step3.
  ///
  /// In es, this message translates to:
  /// **'Dentro de esa pantalla, localiza la opción de eliminación de cuenta (botón «Eliminar todos mis datos»).'**
  String get privacyPolicySection8Step3;

  /// No description provided for @privacyPolicySection8Step4.
  ///
  /// In es, this message translates to:
  /// **'Pulsa en Eliminar todos mis datos.'**
  String get privacyPolicySection8Step4;

  /// No description provided for @privacyPolicySection8Step5.
  ///
  /// In es, this message translates to:
  /// **'Confirma el proceso de eliminación.'**
  String get privacyPolicySection8Step5;

  /// No description provided for @privacyPolicySection8Paragraph3.
  ///
  /// In es, this message translates to:
  /// **'Tras la confirmación, la aplicación ejecutará el proceso de borrado de la cuenta y de los datos asociados conforme al funcionamiento del sistema, y cerrará la sesión del usuario.'**
  String get privacyPolicySection8Paragraph3;

  /// No description provided for @privacyPolicySection8Paragraph4.
  ///
  /// In es, this message translates to:
  /// **'Si por cualquier motivo el usuario no pudiera completar el proceso desde la app, también podrá solicitar la eliminación escribiendo al correo electrónico de contacto arriba indicado.'**
  String get privacyPolicySection8Paragraph4;

  /// No description provided for @privacyPolicySection9Title.
  ///
  /// In es, this message translates to:
  /// **'9. Destinatarios de los datos'**
  String get privacyPolicySection9Title;

  /// No description provided for @privacyPolicySection9Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'NUNCA se venderán ni cederán los datos a terceros.'**
  String get privacyPolicySection9Paragraph1;

  /// No description provided for @privacyPolicySection9Paragraph2.
  ///
  /// In es, this message translates to:
  /// **'Sólo tendrán acceso a los datos:'**
  String get privacyPolicySection9Paragraph2;

  /// No description provided for @privacyPolicySection9Bullet1.
  ///
  /// In es, this message translates to:
  /// **'Personal técnico cualificado únicamente para procesos tecnológicos necesarios para el funcionamiento de la app, el alojamiento, las notificaciones, el soporte técnico o servicios asociados.'**
  String get privacyPolicySection9Bullet1;

  /// No description provided for @privacyPolicySection9Bullet2.
  ///
  /// In es, this message translates to:
  /// **'Encargados del tratamiento contratados por el responsable, bajo las correspondientes garantías contractuales.'**
  String get privacyPolicySection9Bullet2;

  /// No description provided for @privacyPolicySection9Bullet3.
  ///
  /// In es, this message translates to:
  /// **'Administraciones públicas, jueces, tribunales o autoridades competentes cuando exista obligación legal.'**
  String get privacyPolicySection9Bullet3;

  /// No description provided for @privacyPolicySection9Paragraph3.
  ///
  /// In es, this message translates to:
  /// **'No hay transferencias internacionales de datos fuera del Espacio Económico Europeo.'**
  String get privacyPolicySection9Paragraph3;

  /// No description provided for @privacyPolicySection10Title.
  ///
  /// In es, this message translates to:
  /// **'10. Permisos del dispositivo'**
  String get privacyPolicySection10Title;

  /// No description provided for @privacyPolicySection10Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'NutriFitApp puede solicitar permisos del dispositivo únicamente cuando sean necesarios para una funcionalidad concreta. Por ejemplo:'**
  String get privacyPolicySection10Paragraph1;

  /// No description provided for @privacyPolicySection10Bullet1.
  ///
  /// In es, this message translates to:
  /// **'Cámara: para capturar imágenes o usar funciones de escaneo.'**
  String get privacyPolicySection10Bullet1;

  /// No description provided for @privacyPolicySection10Bullet2.
  ///
  /// In es, this message translates to:
  /// **'Galería o archivos: para seleccionar imágenes o documentos, para guardar documentos PDF de la App.'**
  String get privacyPolicySection10Bullet2;

  /// No description provided for @privacyPolicySection10Bullet3.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones: para avisos relevantes dentro de la app.'**
  String get privacyPolicySection10Bullet3;

  /// No description provided for @privacyPolicySection10Bullet4.
  ///
  /// In es, this message translates to:
  /// **'Calendario: si el usuario decide exportar o añadir eventos.'**
  String get privacyPolicySection10Bullet4;

  /// No description provided for @privacyPolicySection10Bullet5.
  ///
  /// In es, this message translates to:
  /// **'Otros permisos estrictamente necesarios para determinadas herramientas de la aplicación.'**
  String get privacyPolicySection10Bullet5;

  /// No description provided for @privacyPolicySection10Paragraph2.
  ///
  /// In es, this message translates to:
  /// **'El usuario puede revocar estos permisos en cualquier momento desde la configuración del dispositivo, aunque algunas funciones podrían dejar de estar disponibles.'**
  String get privacyPolicySection10Paragraph2;

  /// No description provided for @privacyPolicySection11Title.
  ///
  /// In es, this message translates to:
  /// **'11. Seguridad de la información'**
  String get privacyPolicySection11Title;

  /// No description provided for @privacyPolicySection11Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'NutriFitApp aplica medidas técnicas y organizativas razonables para proteger los datos personales frente a pérdida, alteración, acceso no autorizado, divulgación o destrucción. La información se cifra en tránsito.'**
  String get privacyPolicySection11Paragraph1;

  /// No description provided for @privacyPolicySection11Paragraph2.
  ///
  /// In es, this message translates to:
  /// **'No obstante, el usuario debe saber que ninguna transmisión por Internet ni ningún sistema de almacenamiento puede garantizar seguridad absoluta.'**
  String get privacyPolicySection11Paragraph2;

  /// No description provided for @privacyPolicySection12Title.
  ///
  /// In es, this message translates to:
  /// **'12. Derechos del usuario'**
  String get privacyPolicySection12Title;

  /// No description provided for @privacyPolicySection12Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'El usuario puede ejercer en cualquier momento los siguientes derechos:'**
  String get privacyPolicySection12Paragraph1;

  /// No description provided for @privacyPolicySection12Bullet1.
  ///
  /// In es, this message translates to:
  /// **'Acceso.'**
  String get privacyPolicySection12Bullet1;

  /// No description provided for @privacyPolicySection12Bullet2.
  ///
  /// In es, this message translates to:
  /// **'Rectificación.'**
  String get privacyPolicySection12Bullet2;

  /// No description provided for @privacyPolicySection12Bullet3.
  ///
  /// In es, this message translates to:
  /// **'Supresión.'**
  String get privacyPolicySection12Bullet3;

  /// No description provided for @privacyPolicySection12Bullet4.
  ///
  /// In es, this message translates to:
  /// **'Oposición.'**
  String get privacyPolicySection12Bullet4;

  /// No description provided for @privacyPolicySection12Bullet5.
  ///
  /// In es, this message translates to:
  /// **'Limitación del tratamiento.'**
  String get privacyPolicySection12Bullet5;

  /// No description provided for @privacyPolicySection12Bullet6.
  ///
  /// In es, this message translates to:
  /// **'Portabilidad.'**
  String get privacyPolicySection12Bullet6;

  /// No description provided for @privacyPolicySection12Bullet7.
  ///
  /// In es, this message translates to:
  /// **'Retirada del consentimiento, cuando el tratamiento se base en este.'**
  String get privacyPolicySection12Bullet7;

  /// No description provided for @privacyPolicySection12Paragraph2.
  ///
  /// In es, this message translates to:
  /// **'Para ejercer estos derechos, el usuario puede:'**
  String get privacyPolicySection12Paragraph2;

  /// No description provided for @privacyPolicySection12Bullet8.
  ///
  /// In es, this message translates to:
  /// **'Utilizar las funciones disponibles dentro de la propia app, cuando existan.'**
  String get privacyPolicySection12Bullet8;

  /// No description provided for @privacyPolicySection12Bullet9.
  ///
  /// In es, this message translates to:
  /// **'Contactar con el responsable a través del email de contacto arriba indicado.'**
  String get privacyPolicySection12Bullet9;

  /// No description provided for @privacyPolicySection12Paragraph3.
  ///
  /// In es, this message translates to:
  /// **'La solicitud deberá permitir identificar razonablemente al solicitante.'**
  String get privacyPolicySection12Paragraph3;

  /// No description provided for @privacyPolicySection12Paragraph4.
  ///
  /// In es, this message translates to:
  /// **'Asimismo, el usuario tiene derecho a presentar una reclamación ante la Agencia Española de Protección de Datos (AEPD) si considera que sus derechos no han sido debidamente atendidos:'**
  String get privacyPolicySection12Paragraph4;

  /// No description provided for @privacyPolicySection12Paragraph5.
  ///
  /// In es, this message translates to:
  /// **'https://www.aepd.es/'**
  String get privacyPolicySection12Paragraph5;

  /// No description provided for @privacyPolicySection13Title.
  ///
  /// In es, this message translates to:
  /// **'13. Menores de edad'**
  String get privacyPolicySection13Title;

  /// No description provided for @privacyPolicySection13Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'NutriFitApp no está dirigida de forma general a menores de edad sin la intervención o autorización de sus representantes legales cuando esta sea exigible. Si detectamos que se han recopilado datos personales de un menor de forma contraria a la normativa aplicable, se adoptarán las medidas oportunas para su supresión.'**
  String get privacyPolicySection13Paragraph1;

  /// No description provided for @privacyPolicySection14Title.
  ///
  /// In es, this message translates to:
  /// **'14. Exactitud y responsabilidad del usuario'**
  String get privacyPolicySection14Title;

  /// No description provided for @privacyPolicySection14Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'El usuario garantiza que los datos facilitados son verdaderos, exactos y actualizados, y se compromete a comunicar cualquier modificación.'**
  String get privacyPolicySection14Paragraph1;

  /// No description provided for @privacyPolicySection14Paragraph2.
  ///
  /// In es, this message translates to:
  /// **'El usuario será responsable de los daños o perjuicios que pudieran derivarse de la aportación de datos falsos, inexactos o desactualizados.'**
  String get privacyPolicySection14Paragraph2;

  /// No description provided for @privacyPolicySection15Title.
  ///
  /// In es, this message translates to:
  /// **'15. Cambios en esta política'**
  String get privacyPolicySection15Title;

  /// No description provided for @privacyPolicySection15Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'NutriFitApp podrá actualizar esta Política de Privacidad para adaptarla a cambios legales, técnicos o funcionales. Cuando los cambios sean relevantes, se informará al usuario por medios adecuados.'**
  String get privacyPolicySection15Paragraph1;

  /// No description provided for @privacyPolicySection16Title.
  ///
  /// In es, this message translates to:
  /// **'16. Contacto'**
  String get privacyPolicySection16Title;

  /// No description provided for @privacyPolicySection16Paragraph1.
  ///
  /// In es, this message translates to:
  /// **'Para cualquier cuestión relacionada con privacidad o protección de datos, puedes contactar en:'**
  String get privacyPolicySection16Paragraph1;

  /// No description provided for @privacyPolicySection16Paragraph2.
  ///
  /// In es, this message translates to:
  /// **'aprendeconpatrica[ — arroba — ]gmail[ — punto — ]com'**
  String get privacyPolicySection16Paragraph2;

  /// No description provided for @commonClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get commonClose;

  /// No description provided for @appUpdatedNotice.
  ///
  /// In es, this message translates to:
  /// **'La app se ha actualizado a la versión {version}.'**
  String appUpdatedNotice(Object version);

  /// No description provided for @commonContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get commonContinue;

  /// No description provided for @commonAgree.
  ///
  /// In es, this message translates to:
  /// **'De acuerdo'**
  String get commonAgree;

  /// No description provided for @commonLater.
  ///
  /// In es, this message translates to:
  /// **'Más tarde'**
  String get commonLater;

  /// No description provided for @commonValidate.
  ///
  /// In es, this message translates to:
  /// **'Validar'**
  String get commonValidate;

  /// No description provided for @commonToday.
  ///
  /// In es, this message translates to:
  /// **'hoy'**
  String get commonToday;

  /// No description provided for @commonDebug.
  ///
  /// In es, this message translates to:
  /// **'DEBUG'**
  String get commonDebug;

  /// No description provided for @commonAllRightsReserved.
  ///
  /// In es, this message translates to:
  /// **'Todos los derechos reservados'**
  String get commonAllRightsReserved;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navLogout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get navLogout;

  /// No description provided for @navChat.
  ///
  /// In es, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navPatients.
  ///
  /// In es, this message translates to:
  /// **'Pacientes'**
  String get navPatients;

  /// No description provided for @navAppointments.
  ///
  /// In es, this message translates to:
  /// **'Citas'**
  String get navAppointments;

  /// No description provided for @navReviews.
  ///
  /// In es, this message translates to:
  /// **'Revisiones'**
  String get navReviews;

  /// No description provided for @navMeasurements.
  ///
  /// In es, this message translates to:
  /// **'Mediciones'**
  String get navMeasurements;

  /// No description provided for @navNutriInterviews.
  ///
  /// In es, this message translates to:
  /// **'Entrevistas Nutri'**
  String get navNutriInterviews;

  /// No description provided for @navNutriPlans.
  ///
  /// In es, this message translates to:
  /// **'Planes Nutri'**
  String get navNutriPlans;

  /// No description provided for @navFitInterviews.
  ///
  /// In es, this message translates to:
  /// **'Entrevistas Fit'**
  String get navFitInterviews;

  /// No description provided for @navFitPlans.
  ///
  /// In es, this message translates to:
  /// **'Planes Fit'**
  String get navFitPlans;

  /// No description provided for @navExercises.
  ///
  /// In es, this message translates to:
  /// **'Ejercicios'**
  String get navExercises;

  /// No description provided for @navExerciseVideos.
  ///
  /// In es, this message translates to:
  /// **'Vídeos Ejercicios'**
  String get navExerciseVideos;

  /// No description provided for @navActivities.
  ///
  /// In es, this message translates to:
  /// **'Actividades'**
  String get navActivities;

  /// No description provided for @navDashboard.
  ///
  /// In es, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navCharges.
  ///
  /// In es, this message translates to:
  /// **'Cobros'**
  String get navCharges;

  /// No description provided for @navClients.
  ///
  /// In es, this message translates to:
  /// **'Clientes'**
  String get navClients;

  /// No description provided for @navTips.
  ///
  /// In es, this message translates to:
  /// **'Consejos'**
  String get navTips;

  /// No description provided for @navRecipes.
  ///
  /// In es, this message translates to:
  /// **'Recetas'**
  String get navRecipes;

  /// No description provided for @navSubstitutions.
  ///
  /// In es, this message translates to:
  /// **'Sustituciones'**
  String get navSubstitutions;

  /// No description provided for @navTalksAndSeminars.
  ///
  /// In es, this message translates to:
  /// **'Charlas y Seminarios'**
  String get navTalksAndSeminars;

  /// No description provided for @navTalks.
  ///
  /// In es, this message translates to:
  /// **'Charlas'**
  String get navTalks;

  /// No description provided for @navPremiumPreview.
  ///
  /// In es, this message translates to:
  /// **'Hazte Premium (vista)'**
  String get navPremiumPreview;

  /// No description provided for @navPremium.
  ///
  /// In es, this message translates to:
  /// **'Hazte Premium'**
  String get navPremium;

  /// No description provided for @premiumRegistrationRequiredBody.
  ///
  /// In es, this message translates to:
  /// **'Para hacerte Premium primero tienes que registrarte. El registro es gratis y, una vez tengas tu cuenta, ya podrás solicitar el acceso Premium al dietista.'**
  String get premiumRegistrationRequiredBody;

  /// No description provided for @premiumRegisterFree.
  ///
  /// In es, this message translates to:
  /// **'Registrarme gratis'**
  String get premiumRegisterFree;

  /// No description provided for @premiumPaymentMethodLabel.
  ///
  /// In es, this message translates to:
  /// **'Método de pago'**
  String get premiumPaymentMethodLabel;

  /// No description provided for @premiumVerifyEmailAction.
  ///
  /// In es, this message translates to:
  /// **'Verifica tu email para realizar el pago'**
  String get premiumVerifyEmailAction;

  /// No description provided for @premiumContinuePayment.
  ///
  /// In es, this message translates to:
  /// **'Continuar con el pago'**
  String get premiumContinuePayment;

  /// No description provided for @premiumVerifiedEmailStatus.
  ///
  /// In es, this message translates to:
  /// **'Email verificado: {email}'**
  String premiumVerifiedEmailStatus(Object email);

  /// No description provided for @premiumPaymentNeedsRegistration.
  ///
  /// In es, this message translates to:
  /// **'Para realizar el pago, primero regístrate, es gratis:'**
  String get premiumPaymentNeedsRegistration;

  /// No description provided for @premiumPaymentNeedsEmailVerification.
  ///
  /// In es, this message translates to:
  /// **'Para realizar el pago, primero verifica tu email en'**
  String get premiumPaymentNeedsEmailVerification;

  /// No description provided for @premiumGoToRegisterLink.
  ///
  /// In es, this message translates to:
  /// **'Ir al registro de usuario'**
  String get premiumGoToRegisterLink;

  /// No description provided for @premiumGuestRegistrationBody.
  ///
  /// In es, this message translates to:
  /// **'Si todavía no tienes cuenta, primero debes registrarte gratis para poder solicitar el acceso Premium.'**
  String get premiumGuestRegistrationBody;

  /// No description provided for @premiumBenefitsSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Ventajas de ser Premium'**
  String get premiumBenefitsSectionTitle;

  /// No description provided for @premiumPaymentSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Pago y contratación Premium'**
  String get premiumPaymentSectionTitle;

  /// No description provided for @premiumAfterRegistrationMessage.
  ///
  /// In es, this message translates to:
  /// **'Después del registro podrás usar el asistente de pago Premium en esta misma pantalla.'**
  String get premiumAfterRegistrationMessage;

  /// No description provided for @premiumFinalActivationMessage.
  ///
  /// In es, this message translates to:
  /// **'La activación final del acceso Premium la realiza el equipo de NutriFit tras validar el pago y el período elegido. Se realizará en las próximas 24/48/72 horas, en función del método elegido.'**
  String get premiumFinalActivationMessage;

  /// No description provided for @premiumDefaultIntroTitle.
  ///
  /// In es, this message translates to:
  /// **'Desbloquea tu experiencia Premium'**
  String get premiumDefaultIntroTitle;

  /// No description provided for @premiumDefaultIntroText.
  ///
  /// In es, this message translates to:
  /// **'Accede a contenidos exclusivos, recursos avanzados y seguimiento reforzado para sacar más partido a tu plan.'**
  String get premiumDefaultIntroText;

  /// No description provided for @premiumDefaultBenefit1.
  ///
  /// In es, this message translates to:
  /// **'Acceso a funcionalidades exclusivas para usuarios Premium, como Vídeos Ejercicios y futuras mejoras.'**
  String get premiumDefaultBenefit1;

  /// No description provided for @premiumDefaultBenefit2.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca de sustituciones saludables: equivalencias rápidas del tipo \"si no tengo X, usa Y\" para no romper el plan.'**
  String get premiumDefaultBenefit2;

  /// No description provided for @premiumDefaultBenefit3.
  ///
  /// In es, this message translates to:
  /// **'Experiencia más completa dentro de la app con contenido diferencial y acceso ampliado.'**
  String get premiumDefaultBenefit3;

  /// No description provided for @premiumDefaultBenefit4.
  ///
  /// In es, this message translates to:
  /// **'Posibilidad de recibir propuestas personalizadas del nutricionista según el servicio contratado.'**
  String get premiumDefaultBenefit4;

  /// No description provided for @premiumDefaultPaymentMethod1.
  ///
  /// In es, this message translates to:
  /// **'El nutricionista puede ofrecer métodos como PayPal, Bizum, transferencia bancaria u otras opciones personalizadas.'**
  String get premiumDefaultPaymentMethod1;

  /// No description provided for @premiumDefaultPaymentMethod2.
  ///
  /// In es, this message translates to:
  /// **'Estos datos son configurables desde parámetros globales para adaptar la propuesta comercial a cada profesional.'**
  String get premiumDefaultPaymentMethod2;

  /// No description provided for @premiumDefaultPaymentIntro.
  ///
  /// In es, this message translates to:
  /// **'Instrucciones para realizar el pago y activar tu cuenta Premium.'**
  String get premiumDefaultPaymentIntro;

  /// No description provided for @premiumDefaultActivationNotice.
  ///
  /// In es, this message translates to:
  /// **'Una vez recibido el pago, tu perfil Premium se activará en un plazo aproximado de 24/48/72 horas, en función del método elegido.'**
  String get premiumDefaultActivationNotice;

  /// No description provided for @premiumDefaultPaypalSteps.
  ///
  /// In es, this message translates to:
  /// **'Abre la pasarela de pago en: {url_paypal}.\nRealiza el pago con la cuenta PayPal ({email_paypal}) e importe indicado.\nSi lo necesitas, usa el botón {boton_abrir_url_paypal}.'**
  String premiumDefaultPaypalSteps(
      Object boton_abrir_url_paypal, Object email_paypal, Object url_paypal);

  /// No description provided for @premiumDefaultBizumSteps.
  ///
  /// In es, this message translates to:
  /// **'Realiza el Bizum al teléfono {telefono_nutricionista}.\nAñade el concepto antes de confirmar el pago.\nSi lo necesitas, usa el botón {boton_copiar_telefono}.'**
  String premiumDefaultBizumSteps(
      Object boton_copiar_telefono, Object telefono_nutricionista);

  /// No description provided for @premiumDefaultTransferSteps.
  ///
  /// In es, this message translates to:
  /// **'Realiza la transferencia con los datos mostrados en pantalla.\nComprueba el importe y añade el concepto antes de enviar.\nSi lo necesitas, copia los datos bancarios disponibles.'**
  String get premiumDefaultTransferSteps;

  /// No description provided for @premiumPayWithPaypal.
  ///
  /// In es, this message translates to:
  /// **'Pagar por PayPal'**
  String get premiumPayWithPaypal;

  /// No description provided for @premiumPayWithBizum.
  ///
  /// In es, this message translates to:
  /// **'Pagar por Bizum'**
  String get premiumPayWithBizum;

  /// No description provided for @premiumPayWithTransfer.
  ///
  /// In es, this message translates to:
  /// **'Pagar por transferencia'**
  String get premiumPayWithTransfer;

  /// No description provided for @premiumPeriodBadgeMaxDiscount.
  ///
  /// In es, this message translates to:
  /// **'Máximo descuento'**
  String get premiumPeriodBadgeMaxDiscount;

  /// No description provided for @premiumPeriodBadgeHighSaving.
  ///
  /// In es, this message translates to:
  /// **'Ahorro alto'**
  String get premiumPeriodBadgeHighSaving;

  /// No description provided for @premiumPeriodBadgeMediumSaving.
  ///
  /// In es, this message translates to:
  /// **'Ahorro medio'**
  String get premiumPeriodBadgeMediumSaving;

  /// No description provided for @premiumPeriodBadgeNoDiscount.
  ///
  /// In es, this message translates to:
  /// **'Sin descuento'**
  String get premiumPeriodBadgeNoDiscount;

  /// No description provided for @premiumPeriodLabel.
  ///
  /// In es, this message translates to:
  /// **'Período Premium'**
  String get premiumPeriodLabel;

  /// No description provided for @premiumPeriodMonths.
  ///
  /// In es, this message translates to:
  /// **'{months} mes{months, plural, one {} other {es}}'**
  String premiumPeriodMonths(int months);

  /// No description provided for @premiumPriceUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Precio no disponible para {period}.'**
  String premiumPriceUnavailable(Object period);

  /// No description provided for @premiumPriceDisplay.
  ///
  /// In es, this message translates to:
  /// **'Precio: {amount} (período contratado de {period})'**
  String premiumPriceDisplay(Object amount, Object period);

  /// No description provided for @premiumVerifyEmailBeforePayment.
  ///
  /// In es, this message translates to:
  /// **'Debes verificar tu email antes de continuar con el pago.'**
  String get premiumVerifyEmailBeforePayment;

  /// No description provided for @premiumCopyPhone.
  ///
  /// In es, this message translates to:
  /// **'Copiar teléfono'**
  String get premiumCopyPhone;

  /// No description provided for @premiumOpenPayment.
  ///
  /// In es, this message translates to:
  /// **'Acceder al pago'**
  String get premiumOpenPayment;

  /// No description provided for @premiumCopyConcept.
  ///
  /// In es, this message translates to:
  /// **'Copiar concepto'**
  String get premiumCopyConcept;

  /// No description provided for @premiumVerifyEmailBeforeNotifyPayment.
  ///
  /// In es, this message translates to:
  /// **'Debes verificar tu email antes de notificar el pago.'**
  String get premiumVerifyEmailBeforeNotifyPayment;

  /// No description provided for @premiumNotifyPaymentError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo notificar el pago: {error}'**
  String premiumNotifyPaymentError(Object error);

  /// No description provided for @premiumCompletePaymentTitle.
  ///
  /// In es, this message translates to:
  /// **'Completar el pago'**
  String get premiumCompletePaymentTitle;

  /// No description provided for @premiumPaymentConceptLabel.
  ///
  /// In es, this message translates to:
  /// **'Concepto que debes indicar en el método de pago:'**
  String get premiumPaymentConceptLabel;

  /// No description provided for @premiumStepsFor.
  ///
  /// In es, this message translates to:
  /// **'Pasos para {method}'**
  String premiumStepsFor(Object method);

  /// No description provided for @premiumBizumPhoneLabel.
  ///
  /// In es, this message translates to:
  /// **'Teléfono Bizum'**
  String get premiumBizumPhoneLabel;

  /// No description provided for @premiumAfterPaymentNotice.
  ///
  /// In es, this message translates to:
  /// **'Cuando hayas realizado el pago, pulsa en \"He realizado el pago\" para enviar notificación al equipo de NutriFit. En cuanto se verifique el pago, se activará tu cuenta Premium y se te notificará por email.'**
  String get premiumAfterPaymentNotice;

  /// No description provided for @premiumSendingNotification.
  ///
  /// In es, this message translates to:
  /// **'Enviando notificación...'**
  String get premiumSendingNotification;

  /// No description provided for @premiumIHavePaid.
  ///
  /// In es, this message translates to:
  /// **'He realizado el pago'**
  String get premiumIHavePaid;

  /// No description provided for @premiumInvalidUrl.
  ///
  /// In es, this message translates to:
  /// **'URL no válida.'**
  String get premiumInvalidUrl;

  /// No description provided for @premiumOpenPaymentError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el enlace de pago: {error}'**
  String premiumOpenPaymentError(Object error);

  /// No description provided for @premiumPeriodSummaryMaxDiscount.
  ///
  /// In es, this message translates to:
  /// **'Período a contratar de 12 meses (con descuento máximo).'**
  String get premiumPeriodSummaryMaxDiscount;

  /// No description provided for @premiumPeriodSummaryHighDiscount.
  ///
  /// In es, this message translates to:
  /// **'Período a contratar de 6 meses (con descuento alto).'**
  String get premiumPeriodSummaryHighDiscount;

  /// No description provided for @premiumPeriodSummaryDiscount.
  ///
  /// In es, this message translates to:
  /// **'Período a contratar de 3 meses (con descuento).'**
  String get premiumPeriodSummaryDiscount;

  /// No description provided for @premiumPeriodSummarySingleMonth.
  ///
  /// In es, this message translates to:
  /// **'Período a contratar de 1 mes.'**
  String get premiumPeriodSummarySingleMonth;

  /// No description provided for @premiumPaymentConcept.
  ///
  /// In es, this message translates to:
  /// **'NutriFit Premium usuario {nick}.'**
  String premiumPaymentConcept(Object nick);

  /// No description provided for @navFoods.
  ///
  /// In es, this message translates to:
  /// **'Alimentos'**
  String get navFoods;

  /// No description provided for @navSupplements.
  ///
  /// In es, this message translates to:
  /// **'Suplementos'**
  String get navSupplements;

  /// No description provided for @navFoodAdditives.
  ///
  /// In es, this message translates to:
  /// **'Aditivos alimentarios'**
  String get navFoodAdditives;

  /// No description provided for @navAdditives.
  ///
  /// In es, this message translates to:
  /// **'Aditivos'**
  String get navAdditives;

  /// No description provided for @navScanner.
  ///
  /// In es, this message translates to:
  /// **'Escáner'**
  String get navScanner;

  /// No description provided for @navSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get navSettings;

  /// No description provided for @navUsers.
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get navUsers;

  /// No description provided for @navTasks.
  ///
  /// In es, this message translates to:
  /// **'Tareas'**
  String get navTasks;

  /// No description provided for @navChatWithDietitian.
  ///
  /// In es, this message translates to:
  /// **'Chat con dietista'**
  String get navChatWithDietitian;

  /// No description provided for @navContactDietitian.
  ///
  /// In es, this message translates to:
  /// **'Contactar con dietista'**
  String get navContactDietitian;

  /// No description provided for @navEditProfile.
  ///
  /// In es, this message translates to:
  /// **'Editar Perfil'**
  String get navEditProfile;

  /// No description provided for @profileEditProfileTab.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profileEditProfileTab;

  /// No description provided for @profileEditSessionsTab.
  ///
  /// In es, this message translates to:
  /// **'Inicios de sesión'**
  String get profileEditSessionsTab;

  /// No description provided for @profileEditPremiumBadgeTitle.
  ///
  /// In es, this message translates to:
  /// **'Cuenta Premium'**
  String get profileEditPremiumBadgeTitle;

  /// No description provided for @profileEditPremiumBadgeBody.
  ///
  /// In es, this message translates to:
  /// **'Tienes acceso a funciones exclusivas como Vídeos Ejercicios.'**
  String get profileEditPremiumBadgeBody;

  /// No description provided for @profileEditNickLabel.
  ///
  /// In es, this message translates to:
  /// **'Nick / Usuario'**
  String get profileEditNickLabel;

  /// No description provided for @profileEditNickRequired.
  ///
  /// In es, this message translates to:
  /// **'El nick es obligatorio'**
  String get profileEditNickRequired;

  /// No description provided for @profileEditEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get profileEditEmailLabel;

  /// No description provided for @profileEditInvalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Email no válido'**
  String get profileEditInvalidEmail;

  /// No description provided for @profileEditEmailInUse.
  ///
  /// In es, this message translates to:
  /// **'El email introducido no es válido, indique otro'**
  String get profileEditEmailInUse;

  /// No description provided for @profileEditChangeEmailTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cambiar cuenta de correo electrónico'**
  String get profileEditChangeEmailTooltip;

  /// No description provided for @profileEditVerifyEmailCta.
  ///
  /// In es, this message translates to:
  /// **'Verificar email'**
  String get profileEditVerifyEmailCta;

  /// No description provided for @profileEditTwoFactorShortLabel.
  ///
  /// In es, this message translates to:
  /// **'Doble factor'**
  String get profileEditTwoFactorShortLabel;

  /// No description provided for @profileEditBmiCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Datos para IMC'**
  String get profileEditBmiCardTitle;

  /// No description provided for @profileEditBmiInfoTooltip.
  ///
  /// In es, this message translates to:
  /// **'Información MVP/IMC'**
  String get profileEditBmiInfoTooltip;

  /// No description provided for @profileEditBmiCardBody.
  ///
  /// In es, this message translates to:
  /// **'Para obtener el IMC, MVP y recomendaciones, completa Edad y Altura.'**
  String get profileEditBmiCardBody;

  /// No description provided for @profileEditAgeLabel.
  ///
  /// In es, this message translates to:
  /// **'Edad'**
  String get profileEditAgeLabel;

  /// No description provided for @profileEditInvalidAge.
  ///
  /// In es, this message translates to:
  /// **'Edad no válida'**
  String get profileEditInvalidAge;

  /// No description provided for @profileEditHeightLabel.
  ///
  /// In es, this message translates to:
  /// **'Altura (cm)'**
  String get profileEditHeightLabel;

  /// No description provided for @profileEditInvalidHeight.
  ///
  /// In es, this message translates to:
  /// **'Altura no válida'**
  String get profileEditInvalidHeight;

  /// No description provided for @profileEditPasswordCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambio de contraseña'**
  String get profileEditPasswordCardTitle;

  /// No description provided for @profileEditPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Dejar en blanco para no cambiar'**
  String get profileEditPasswordHint;

  /// No description provided for @profileEditPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get profileEditPasswordLabel;

  /// No description provided for @profileEditPasswordConfirmLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar Contraseña'**
  String get profileEditPasswordConfirmLabel;

  /// No description provided for @profileEditPasswordConfirmRequired.
  ///
  /// In es, this message translates to:
  /// **'Debes confirmar la contraseña'**
  String get profileEditPasswordConfirmRequired;

  /// No description provided for @profileEditPasswordMismatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden'**
  String get profileEditPasswordMismatch;

  /// No description provided for @profileEditSaveChanges.
  ///
  /// In es, this message translates to:
  /// **'Guardar Cambios'**
  String get profileEditSaveChanges;

  /// No description provided for @profileEditDeleteMyData.
  ///
  /// In es, this message translates to:
  /// **'Eliminar todos mis datos'**
  String get profileEditDeleteMyData;

  /// No description provided for @profileEditChangeEmailTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambiar email'**
  String get profileEditChangeEmailTitle;

  /// No description provided for @profileEditChangeEmailVerifiedWarning.
  ///
  /// In es, this message translates to:
  /// **'El email actual está verificado, si lo cambias, tendrás que volver a verificarlo.'**
  String get profileEditChangeEmailVerifiedWarning;

  /// No description provided for @profileEditChangeEmailNewLabel.
  ///
  /// In es, this message translates to:
  /// **'Nuevo email'**
  String get profileEditChangeEmailNewLabel;

  /// No description provided for @profileEditChangeEmailRequired.
  ///
  /// In es, this message translates to:
  /// **'Debes indicar un email.'**
  String get profileEditChangeEmailRequired;

  /// No description provided for @profileEditChangeEmailMustDiffer.
  ///
  /// In es, this message translates to:
  /// **'Debes indicar un email distinto al actual.'**
  String get profileEditChangeEmailMustDiffer;

  /// No description provided for @profileEditChangeEmailValidationFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo validar el email. Inténtalo de nuevo.'**
  String get profileEditChangeEmailValidationFailed;

  /// No description provided for @profileEditChangeEmailReview.
  ///
  /// In es, this message translates to:
  /// **'Revisa el email indicado.'**
  String get profileEditChangeEmailReview;

  /// No description provided for @profileEditEmailRequiredForVerification.
  ///
  /// In es, this message translates to:
  /// **'Debes indicar primero una cuenta de email.'**
  String get profileEditEmailRequiredForVerification;

  /// No description provided for @profileEditEmailCodeSentGeneric.
  ///
  /// In es, this message translates to:
  /// **'Código enviado.'**
  String get profileEditEmailCodeSentGeneric;

  /// No description provided for @profileEditEmailVerifiedGeneric.
  ///
  /// In es, this message translates to:
  /// **'Email verificado.'**
  String get profileEditEmailVerifiedGeneric;

  /// No description provided for @profileEditEmailCodeLengthError.
  ///
  /// In es, this message translates to:
  /// **'El código debe tener 10 dígitos.'**
  String get profileEditEmailCodeLengthError;

  /// No description provided for @profileEditEmailCodeDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Validar código de email'**
  String get profileEditEmailCodeDialogTitle;

  /// No description provided for @profileEditEmailCodeTenDigitsLabel.
  ///
  /// In es, this message translates to:
  /// **'Código de 10 dígitos'**
  String get profileEditEmailCodeTenDigitsLabel;

  /// No description provided for @profileEditValidateEmailCodeAction.
  ///
  /// In es, this message translates to:
  /// **'Validar código'**
  String get profileEditValidateEmailCodeAction;

  /// No description provided for @profileEditVerifyEmailTitle.
  ///
  /// In es, this message translates to:
  /// **'Verificar email'**
  String get profileEditVerifyEmailTitle;

  /// No description provided for @profileEditVerifyEmailIntroPrefix.
  ///
  /// In es, this message translates to:
  /// **'Verificar tu email te permitirá recuperar el acceso por correo si olvidas la contraseña y también solicitar '**
  String get profileEditVerifyEmailIntroPrefix;

  /// No description provided for @profileEditVerifyEmailPremiumLink.
  ///
  /// In es, this message translates to:
  /// **'suscribirte a Premium'**
  String get profileEditVerifyEmailPremiumLink;

  /// No description provided for @profileEditFollowTheseSteps.
  ///
  /// In es, this message translates to:
  /// **'Sigue estos pasos...'**
  String get profileEditFollowTheseSteps;

  /// No description provided for @profileEditYourEmail.
  ///
  /// In es, this message translates to:
  /// **'tu email'**
  String get profileEditYourEmail;

  /// No description provided for @profileEditSendCodeInstruction.
  ///
  /// In es, this message translates to:
  /// **'Pulsa en \"Enviar código\" para enviarte el código de verificación a {email}.'**
  String profileEditSendCodeInstruction(Object email);

  /// No description provided for @profileEditEmailCodeSentInfo.
  ///
  /// In es, this message translates to:
  /// **'Código enviado a tu cuenta de correo electrónico. Caducará en 15 minutos. Si no lo ves en Bandeja de entrada, revisa la carpeta Spam.'**
  String get profileEditEmailCodeSentInfo;

  /// No description provided for @profileEditEmailSendFailed.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido enviar el email de verificación en este momento, inténtelo más tarde.'**
  String get profileEditEmailSendFailed;

  /// No description provided for @profileEditSendCodeAction.
  ///
  /// In es, this message translates to:
  /// **'Enviar código'**
  String get profileEditSendCodeAction;

  /// No description provided for @profileEditResendCodeAction.
  ///
  /// In es, this message translates to:
  /// **'Volver a enviar'**
  String get profileEditResendCodeAction;

  /// No description provided for @profileEditVerifyCodeInstruction.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu correo electrónico, habrás recibido un email con un código, cópialo y pégalo aquí, y pulsa en \"Verificar\".'**
  String get profileEditVerifyCodeInstruction;

  /// No description provided for @profileEditVerificationCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código de verificación'**
  String get profileEditVerificationCodeLabel;

  /// No description provided for @profileEditEmailRequiredInProfile.
  ///
  /// In es, this message translates to:
  /// **'Debes indicar primero un email en Editar Perfil para poder verificarlo.'**
  String get profileEditEmailRequiredInProfile;

  /// No description provided for @profileEditTwoFactorDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Doble factor (2FA)'**
  String get profileEditTwoFactorDialogTitle;

  /// No description provided for @profileEditTwoFactorEnabledStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado: Activado'**
  String get profileEditTwoFactorEnabledStatus;

  /// No description provided for @profileEditTwoFactorEnabledBody.
  ///
  /// In es, this message translates to:
  /// **'El doble factor ya está activado en tu cuenta. Desde aquí solo puedes consultar si este dispositivo es de confianza y vincularlo o desvincularlo.'**
  String get profileEditTwoFactorEnabledBody;

  /// No description provided for @profileEditTrustedDeviceEnabledBody.
  ///
  /// In es, this message translates to:
  /// **'Este dispositivo está marcado como de confianza. No se solicitará el código 2FA en próximos inicios de sesión hasta que quites la confianza desde aquí.'**
  String get profileEditTrustedDeviceEnabledBody;

  /// No description provided for @profileEditTrustedDeviceDisabledBody.
  ///
  /// In es, this message translates to:
  /// **'Este dispositivo no está marcado como de confianza. Puedes marcarlo pulsando en \"Establecer este dispositivo como de confianza\" o cerrando sesión y volviendo a acceder, activando la casilla \"Confiar en este dispositivo\" durante la validación 2FA.'**
  String get profileEditTrustedDeviceDisabledBody;

  /// No description provided for @profileEditRemoveTrustedDeviceAction.
  ///
  /// In es, this message translates to:
  /// **'Quitar confianza en este dispositivo'**
  String get profileEditRemoveTrustedDeviceAction;

  /// No description provided for @profileEditSetTrustedDeviceAction.
  ///
  /// In es, this message translates to:
  /// **'Establecer este dispositivo como de confianza'**
  String get profileEditSetTrustedDeviceAction;

  /// No description provided for @profileEditCancelProcess.
  ///
  /// In es, this message translates to:
  /// **'Cancelar proceso'**
  String get profileEditCancelProcess;

  /// No description provided for @profileEditSetTrustedDeviceTitle.
  ///
  /// In es, this message translates to:
  /// **'Establecer dispositivo de confianza'**
  String get profileEditSetTrustedDeviceTitle;

  /// No description provided for @profileEditSetTrustedDeviceBody.
  ///
  /// In es, this message translates to:
  /// **'Para marcar este dispositivo como de confianza debes validarlo en el inicio de sesión 2FA, activando la casilla \"Confiar en este dispositivo\".\n\n¿Quieres cerrar sesión ahora para hacerlo?'**
  String get profileEditSetTrustedDeviceBody;

  /// No description provided for @profileEditGoToLogin.
  ///
  /// In es, this message translates to:
  /// **'Ir al login'**
  String get profileEditGoToLogin;

  /// No description provided for @profileEditActivateTwoFactorTitle.
  ///
  /// In es, this message translates to:
  /// **'Activar doble factor'**
  String get profileEditActivateTwoFactorTitle;

  /// No description provided for @profileEditActivateTwoFactorIntro.
  ///
  /// In es, this message translates to:
  /// **'El doble factor (2FA) añade una capa extra de seguridad: además de tu contraseña, se solicita un código temporal de tu app de autenticación.'**
  String get profileEditActivateTwoFactorIntro;

  /// No description provided for @profileEditTwoFactorStep1.
  ///
  /// In es, this message translates to:
  /// **'Abre tu app de autenticación (Google Authenticator, Microsoft Authenticator, Authy, etc.) y añade una cuenta.'**
  String get profileEditTwoFactorStep1;

  /// No description provided for @profileEditTwoFactorSetupKeyLabel.
  ///
  /// In es, this message translates to:
  /// **'Clave para configurar 2FA:'**
  String get profileEditTwoFactorSetupKeyLabel;

  /// No description provided for @profileEditKeyCopied.
  ///
  /// In es, this message translates to:
  /// **'Clave copiada al portapapeles'**
  String get profileEditKeyCopied;

  /// No description provided for @profileEditHideOptions.
  ///
  /// In es, this message translates to:
  /// **'Ocultar opciones'**
  String get profileEditHideOptions;

  /// No description provided for @profileEditMoreOptions.
  ///
  /// In es, this message translates to:
  /// **'Más opciones...'**
  String get profileEditMoreOptions;

  /// No description provided for @profileEditQrSavedDownloads.
  ///
  /// In es, this message translates to:
  /// **'QR guardado en Descargas: {path}'**
  String profileEditQrSavedDownloads(Object path);

  /// No description provided for @profileEditQrShared.
  ///
  /// In es, this message translates to:
  /// **'Se abrió el menú para compartir o guardar el QR.'**
  String get profileEditQrShared;

  /// No description provided for @profileEditOtpUrlCopied.
  ///
  /// In es, this message translates to:
  /// **'URL otpauth copiada'**
  String get profileEditOtpUrlCopied;

  /// No description provided for @profileEditCopyUrl.
  ///
  /// In es, this message translates to:
  /// **'Copiar URL'**
  String get profileEditCopyUrl;

  /// No description provided for @profileEditOtpUrlInfo.
  ///
  /// In es, this message translates to:
  /// **'La opción \"Copiar URL\" copia un enlace otpauth con toda la configuración 2FA para importarla en apps compatibles. Si tu app no permite importación por enlace, usa \"Copiar\" en la clave.'**
  String get profileEditOtpUrlInfo;

  /// No description provided for @profileEditTwoFactorConfirmCodeInstruction.
  ///
  /// In es, this message translates to:
  /// **'Introduce el código de 6 dígitos que te aparecerá en la app de autenticación para confirmar.'**
  String get profileEditTwoFactorConfirmCodeInstruction;

  /// No description provided for @profileEditActivateTwoFactorAction.
  ///
  /// In es, this message translates to:
  /// **'Activar'**
  String get profileEditActivateTwoFactorAction;

  /// No description provided for @profileEditTwoFactorActivated.
  ///
  /// In es, this message translates to:
  /// **'Doble factor activado correctamente'**
  String get profileEditTwoFactorActivated;

  /// No description provided for @profileEditTwoFactorActivateFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo activar 2FA.'**
  String get profileEditTwoFactorActivateFailed;

  /// No description provided for @profileEditNoQrData.
  ///
  /// In es, this message translates to:
  /// **'No hay datos para guardar el QR.'**
  String get profileEditNoQrData;

  /// No description provided for @profileEditQrSavedPath.
  ///
  /// In es, this message translates to:
  /// **'QR guardado en: {path}'**
  String profileEditQrSavedPath(Object path);

  /// No description provided for @profileEditQrSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el QR: {error}'**
  String profileEditQrSaveFailed(Object error);

  /// No description provided for @profileEditDeactivateTwoFactorTitle.
  ///
  /// In es, this message translates to:
  /// **'Desactivar doble factor (2FA)'**
  String get profileEditDeactivateTwoFactorTitle;

  /// No description provided for @profileEditCurrentCodeSixDigitsLabel.
  ///
  /// In es, this message translates to:
  /// **'Código actual de 6 dígitos'**
  String get profileEditCurrentCodeSixDigitsLabel;

  /// No description provided for @profileEditDeactivateTwoFactorAction.
  ///
  /// In es, this message translates to:
  /// **'Desactivar'**
  String get profileEditDeactivateTwoFactorAction;

  /// No description provided for @profileEditTwoFactorDeactivated.
  ///
  /// In es, this message translates to:
  /// **'Doble factor desactivado correctamente'**
  String get profileEditTwoFactorDeactivated;

  /// No description provided for @profileEditTwoFactorDeactivateFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo desactivar 2FA.'**
  String get profileEditTwoFactorDeactivateFailed;

  /// No description provided for @profileEditRemoveTrustedDeviceTitle.
  ///
  /// In es, this message translates to:
  /// **'Quitar confianza del dispositivo'**
  String get profileEditRemoveTrustedDeviceTitle;

  /// No description provided for @profileEditRemoveTrustedDeviceBody.
  ///
  /// In es, this message translates to:
  /// **'En este dispositivo se volverá a solicitar el código 2FA en el próximo inicio de sesión. ¿Deseas continuar?'**
  String get profileEditRemoveTrustedDeviceBody;

  /// No description provided for @profileEditRemoveTrustedDeviceActionShort.
  ///
  /// In es, this message translates to:
  /// **'Quitar confianza'**
  String get profileEditRemoveTrustedDeviceActionShort;

  /// No description provided for @profileEditTrustedDeviceRemoved.
  ///
  /// In es, this message translates to:
  /// **'Confianza del dispositivo eliminada.'**
  String get profileEditTrustedDeviceRemoved;

  /// No description provided for @profileEditTrustedDeviceRemoveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo quitar la confianza del dispositivo: {error}'**
  String profileEditTrustedDeviceRemoveFailed(Object error);

  /// No description provided for @profileEditMvpDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Cálculo MVP y fórmulas'**
  String get profileEditMvpDialogTitle;

  /// No description provided for @profileEditMvpWhatIsTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué es el MVP?'**
  String get profileEditMvpWhatIsTitle;

  /// No description provided for @profileEditMvpWhatIsBody.
  ///
  /// In es, this message translates to:
  /// **'MVP es un conjunto mínimo de indicadores antropométricos para ayudarte a monitorizar de forma sencilla tu evolución de salud: IMC, cintura/altura y cintura/cadera.'**
  String get profileEditMvpWhatIsBody;

  /// No description provided for @profileEditMvpFormulasTitle.
  ///
  /// In es, this message translates to:
  /// **'Fórmulas utilizadas y su origen:'**
  String get profileEditMvpFormulasTitle;

  /// No description provided for @profileEditMvpOriginBmi.
  ///
  /// In es, this message translates to:
  /// **'Origen: OMS (clasificación IMC en adultos).'**
  String get profileEditMvpOriginBmi;

  /// No description provided for @profileEditMvpOriginWhtr.
  ///
  /// In es, this message translates to:
  /// **'Origen: índice Waist-to-Height Ratio.'**
  String get profileEditMvpOriginWhtr;

  /// No description provided for @profileEditMvpOriginWhr.
  ///
  /// In es, this message translates to:
  /// **'Origen: Waist-Hip Ratio (OMS, obesidad abdominal).'**
  String get profileEditMvpOriginWhr;

  /// No description provided for @profileEditImportantNotice.
  ///
  /// In es, this message translates to:
  /// **'Aviso importante'**
  String get profileEditImportantNotice;

  /// No description provided for @profileEditMvpImportantNoticeBody.
  ///
  /// In es, this message translates to:
  /// **'Estos cálculos y clasificaciones son orientativos. Para una valoración personalizada, consulta siempre con un profesional médico, dietista-nutricionista o entrenador personal.'**
  String get profileEditMvpImportantNoticeBody;

  /// No description provided for @profileEditAccept.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get profileEditAccept;

  /// No description provided for @profileEditNotAvailable.
  ///
  /// In es, this message translates to:
  /// **'N/D'**
  String get profileEditNotAvailable;

  /// No description provided for @profileEditSessionDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get profileEditSessionDate;

  /// No description provided for @profileEditSessionTime.
  ///
  /// In es, this message translates to:
  /// **'Hora'**
  String get profileEditSessionTime;

  /// No description provided for @profileEditSessionDevice.
  ///
  /// In es, this message translates to:
  /// **'Dispositivo'**
  String get profileEditSessionDevice;

  /// No description provided for @profileEditSessionIp.
  ///
  /// In es, this message translates to:
  /// **'Dirección IP:'**
  String get profileEditSessionIp;

  /// No description provided for @profileEditSessionPublicIp.
  ///
  /// In es, this message translates to:
  /// **'Pública'**
  String get profileEditSessionPublicIp;

  /// No description provided for @profileEditUserCodeUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Código de usuario no disponible'**
  String get profileEditUserCodeUnavailable;

  /// No description provided for @profileEditGenericError.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get profileEditGenericError;

  /// No description provided for @profileEditRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get profileEditRetry;

  /// No description provided for @profileEditSessionDataUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido acceder a los datos de inicios de sesión en este momento.'**
  String get profileEditSessionDataUnavailable;

  /// No description provided for @profileEditNoSessionData.
  ///
  /// In es, this message translates to:
  /// **'No hay datos de sesión disponibles'**
  String get profileEditNoSessionData;

  /// No description provided for @profileEditSuccessfulSessionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Últimos Inicios de Sesión Exitosos'**
  String get profileEditSuccessfulSessionsTitle;

  /// No description provided for @profileEditCurrentSession.
  ///
  /// In es, this message translates to:
  /// **'Sesión actual:'**
  String get profileEditCurrentSession;

  /// No description provided for @profileEditPreviousSession.
  ///
  /// In es, this message translates to:
  /// **'Sesión anterior:'**
  String get profileEditPreviousSession;

  /// No description provided for @profileEditNoSuccessfulSessions.
  ///
  /// In es, this message translates to:
  /// **'No hay sesiones exitosas registradas'**
  String get profileEditNoSuccessfulSessions;

  /// No description provided for @profileEditFailedAttemptsTitle.
  ///
  /// In es, this message translates to:
  /// **'Últimos Intentos de Acceso Fallidos'**
  String get profileEditFailedAttemptsTitle;

  /// No description provided for @profileEditAttemptLabel.
  ///
  /// In es, this message translates to:
  /// **'Intento {count}:'**
  String profileEditAttemptLabel(Object count);

  /// No description provided for @profileEditNoFailedAttempts.
  ///
  /// In es, this message translates to:
  /// **'No hay intentos fallidos registrados.'**
  String get profileEditNoFailedAttempts;

  /// No description provided for @profileEditSessionStatsTitle.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas de Sesiones'**
  String get profileEditSessionStatsTitle;

  /// No description provided for @profileEditTotalSessions.
  ///
  /// In es, this message translates to:
  /// **'Total de sesiones: {count}'**
  String profileEditTotalSessions(Object count);

  /// No description provided for @profileEditSuccessfulAttempts.
  ///
  /// In es, this message translates to:
  /// **'Intentos exitosos: {count}'**
  String profileEditSuccessfulAttempts(Object count);

  /// No description provided for @profileEditFailedAttempts.
  ///
  /// In es, this message translates to:
  /// **'Intentos fallidos: {count}'**
  String profileEditFailedAttempts(Object count);

  /// No description provided for @navRecommendations.
  ///
  /// In es, this message translates to:
  /// **'Recomendaciones'**
  String get navRecommendations;

  /// No description provided for @navExerciseCatalog.
  ///
  /// In es, this message translates to:
  /// **'Catálogo ejercicios'**
  String get navExerciseCatalog;

  /// No description provided for @exerciseCatalogSearchFieldLabel.
  ///
  /// In es, this message translates to:
  /// **'Buscar en'**
  String get exerciseCatalogSearchFieldLabel;

  /// No description provided for @exerciseCatalogSearchFieldAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get exerciseCatalogSearchFieldAll;

  /// No description provided for @exerciseCatalogSearchFieldTitle.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get exerciseCatalogSearchFieldTitle;

  /// No description provided for @exerciseCatalogSearchFieldInstructions.
  ///
  /// In es, this message translates to:
  /// **'Instrucciones'**
  String get exerciseCatalogSearchFieldInstructions;

  /// No description provided for @exerciseCatalogSearchFieldHashtags.
  ///
  /// In es, this message translates to:
  /// **'Hashtags'**
  String get exerciseCatalogSearchFieldHashtags;

  /// No description provided for @exerciseCatalogSearchLabel.
  ///
  /// In es, this message translates to:
  /// **'Buscar ejercicios'**
  String get exerciseCatalogSearchLabel;

  /// No description provided for @exerciseCatalogSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe para buscar en el campo seleccionado'**
  String get exerciseCatalogSearchHint;

  /// No description provided for @exerciseCatalogClearSearch.
  ///
  /// In es, this message translates to:
  /// **'Borrar búsqueda'**
  String get exerciseCatalogClearSearch;

  /// No description provided for @exerciseCatalogHideSearch.
  ///
  /// In es, this message translates to:
  /// **'Ocultar búsqueda'**
  String get exerciseCatalogHideSearch;

  /// No description provided for @navWeightControl.
  ///
  /// In es, this message translates to:
  /// **'Control de peso'**
  String get navWeightControl;

  /// No description provided for @navShoppingList.
  ///
  /// In es, this message translates to:
  /// **'Lista de la compra'**
  String get navShoppingList;

  /// No description provided for @navStartRegistration.
  ///
  /// In es, this message translates to:
  /// **'Iniciar registro'**
  String get navStartRegistration;

  /// No description provided for @navPreviewRegisteredUser.
  ///
  /// In es, this message translates to:
  /// **'Ver como usuario registrado'**
  String get navPreviewRegisteredUser;

  /// No description provided for @navPreviewGuestUser.
  ///
  /// In es, this message translates to:
  /// **'Ver como usuario no registrado'**
  String get navPreviewGuestUser;

  /// No description provided for @drawerGuestUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario invitado'**
  String get drawerGuestUser;

  /// No description provided for @drawerAdminUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario administrador'**
  String get drawerAdminUser;

  /// No description provided for @drawerPremiumPatientUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario paciente Premium'**
  String get drawerPremiumPatientUser;

  /// No description provided for @drawerPatientUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario paciente'**
  String get drawerPatientUser;

  /// No description provided for @drawerPremiumRegisteredUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario registrado Premium'**
  String get drawerPremiumRegisteredUser;

  /// No description provided for @drawerRegisteredUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario registrado'**
  String get drawerRegisteredUser;

  /// No description provided for @drawerPremiumBadge.
  ///
  /// In es, this message translates to:
  /// **'PREMIUM'**
  String get drawerPremiumBadge;

  /// No description provided for @drawerRestrictedNutriPlansTitle.
  ///
  /// In es, this message translates to:
  /// **'Planes nutricionales'**
  String get drawerRestrictedNutriPlansTitle;

  /// No description provided for @drawerRestrictedTrainingTitle.
  ///
  /// In es, this message translates to:
  /// **'Entrenamientos personalizados'**
  String get drawerRestrictedTrainingTitle;

  /// No description provided for @drawerRestrictedRecommendationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Recomendaciones'**
  String get drawerRestrictedRecommendationsTitle;

  /// No description provided for @drawerRegistrationRequiredTitle.
  ///
  /// In es, this message translates to:
  /// **'Registro requerido'**
  String get drawerRegistrationRequiredTitle;

  /// No description provided for @drawerRegistrationRequiredChatMessage.
  ///
  /// In es, this message translates to:
  /// **'Para chatear con tu dietista online, por favor, regístrate (es gratis).'**
  String get drawerRegistrationRequiredChatMessage;

  /// No description provided for @homePaymentNotifiedTitle.
  ///
  /// In es, this message translates to:
  /// **'Pago notificado a NutriFit'**
  String get homePaymentNotifiedTitle;

  /// No description provided for @homePaymentNotifiedMessage.
  ///
  /// In es, this message translates to:
  /// **'Hemos recibido tu aviso de pago. Tu cuenta Premium se activará cuando NutriFit reciba y verifique el pago. Te avisaremos por email y por el chat de la app. El periodo Premium empezará a contar desde la fecha de verificación del pago.'**
  String get homePaymentNotifiedMessage;

  /// No description provided for @homePremiumExpiredTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu Premium ha caducado'**
  String get homePremiumExpiredTitle;

  /// No description provided for @homePremiumExpiringTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu Premium está próximo a caducar'**
  String get homePremiumExpiringTitle;

  /// No description provided for @homePremiumExpiredMessage.
  ///
  /// In es, this message translates to:
  /// **'Tu Premium caducó el {date}. Puedes renovarlo ahora.'**
  String homePremiumExpiredMessage(Object date);

  /// No description provided for @homePremiumExpiringTodayMessage.
  ///
  /// In es, this message translates to:
  /// **'Tu Premium vence el {date} (hoy). Te recomendamos renovarlo para no perder ventajas.'**
  String homePremiumExpiringTodayMessage(Object date);

  /// No description provided for @homePremiumExpiringInDaysMessage.
  ///
  /// In es, this message translates to:
  /// **'Tu Premium vence el {date} (en {days} días). Te recomendamos renovarlo para no perder ventajas.'**
  String homePremiumExpiringInDaysMessage(Object date, Object days);

  /// No description provided for @homeRenewPremium.
  ///
  /// In es, this message translates to:
  /// **'Renovar Premium'**
  String get homeRenewPremium;

  /// No description provided for @homeSecurityRecommendedTitle.
  ///
  /// In es, this message translates to:
  /// **'Seguridad recomendada'**
  String get homeSecurityRecommendedTitle;

  /// No description provided for @homeSecurityRecommendedBody.
  ///
  /// In es, this message translates to:
  /// **'Trabajas con datos médicos sensibles. Te recomendamos activar el doble factor (2FA) para proteger mejor tu cuenta.'**
  String get homeSecurityRecommendedBody;

  /// No description provided for @homeGoToEditProfile.
  ///
  /// In es, this message translates to:
  /// **'Ir a editar perfil'**
  String get homeGoToEditProfile;

  /// No description provided for @homeDoNotShowAgain.
  ///
  /// In es, this message translates to:
  /// **'No volver a mostrar'**
  String get homeDoNotShowAgain;

  /// No description provided for @loginNetworkError.
  ///
  /// In es, this message translates to:
  /// **'Hay algún problema con la conexión a Internet o la app no tiene permisos para conectarse.'**
  String get loginNetworkError;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In es, this message translates to:
  /// **'Usuario o contraseña incorrectos.'**
  String get loginInvalidCredentials;

  /// No description provided for @loginFailedGeneric.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar el inicio de sesión. Inténtalo de nuevo.'**
  String get loginFailedGeneric;

  /// No description provided for @loginGuestFailedGeneric.
  ///
  /// In es, this message translates to:
  /// **'No se pudo acceder como invitado. Inténtalo de nuevo.'**
  String get loginGuestFailedGeneric;

  /// No description provided for @loginUnknownUserType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de usuario no reconocido'**
  String get loginUnknownUserType;

  /// No description provided for @loginTwoFactorTitle.
  ///
  /// In es, this message translates to:
  /// **'Verificación 2FA'**
  String get loginTwoFactorTitle;

  /// No description provided for @loginTwoFactorPrompt.
  ///
  /// In es, this message translates to:
  /// **'Introduce el código de 6 dígitos de tu aplicación TOTP.'**
  String get loginTwoFactorPrompt;

  /// No description provided for @loginTwoFactorCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código 2FA'**
  String get loginTwoFactorCodeLabel;

  /// No description provided for @loginTrustThisDevice.
  ///
  /// In es, this message translates to:
  /// **'Confiar en este dispositivo'**
  String get loginTrustThisDevice;

  /// No description provided for @loginTrustThisDeviceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'No se volverá a solicitar 2FA en este dispositivo.'**
  String get loginTrustThisDeviceSubtitle;

  /// No description provided for @loginCodeMustHave6Digits.
  ///
  /// In es, this message translates to:
  /// **'El código debe tener 6 dígitos.'**
  String get loginCodeMustHave6Digits;

  /// No description provided for @loginRecoveryTitle.
  ///
  /// In es, this message translates to:
  /// **'Recuperar acceso'**
  String get loginRecoveryTitle;

  /// No description provided for @loginRecoveryIdentifierIntro.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu usuario (nick) o tu cuenta de email para recuperar el acceso.'**
  String get loginRecoveryIdentifierIntro;

  /// No description provided for @loginUserOrEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Usuario o email'**
  String get loginUserOrEmailLabel;

  /// No description provided for @loginEnterUserOrEmail.
  ///
  /// In es, this message translates to:
  /// **'Introduce usuario o email.'**
  String get loginEnterUserOrEmail;

  /// No description provided for @loginNoRecoveryMethods.
  ///
  /// In es, this message translates to:
  /// **'Este usuario no tiene métodos de recuperación disponibles.'**
  String get loginNoRecoveryMethods;

  /// No description provided for @loginSelectRecoveryMethod.
  ///
  /// In es, this message translates to:
  /// **'Selecciona método de recuperación'**
  String get loginSelectRecoveryMethod;

  /// No description provided for @loginRecoveryByEmail.
  ///
  /// In es, this message translates to:
  /// **'Mediante tu email'**
  String get loginRecoveryByEmail;

  /// No description provided for @loginRecoveryByTwoFactor.
  ///
  /// In es, this message translates to:
  /// **'Mediante doble factor (2FA)'**
  String get loginRecoveryByTwoFactor;

  /// No description provided for @loginEmailRecoveryIntro.
  ///
  /// In es, this message translates to:
  /// **'Te enviaremos un código de recuperación por email. Introdúzcalo aquí junto con tu nueva contraseña.'**
  String get loginEmailRecoveryIntro;

  /// No description provided for @loginRecoveryStep1SendCode.
  ///
  /// In es, this message translates to:
  /// **'Paso 1: Enviar código'**
  String get loginRecoveryStep1SendCode;

  /// No description provided for @loginRecoveryStep1SendCodeBody.
  ///
  /// In es, this message translates to:
  /// **'Pulsa en \"Enviar código\" para recibir un código de recuperación en tu email.'**
  String get loginRecoveryStep1SendCodeBody;

  /// No description provided for @loginSendCode.
  ///
  /// In es, this message translates to:
  /// **'Enviar código'**
  String get loginSendCode;

  /// No description provided for @loginRecoveryStep2VerifyCode.
  ///
  /// In es, this message translates to:
  /// **'Paso 2: Verificar código'**
  String get loginRecoveryStep2VerifyCode;

  /// No description provided for @loginRecoveryStep2VerifyCodeBody.
  ///
  /// In es, this message translates to:
  /// **'Introduce el código que recibiste en tu email.'**
  String get loginRecoveryStep2VerifyCodeBody;

  /// No description provided for @loginRecoveryCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código de recuperación'**
  String get loginRecoveryCodeLabel;

  /// No description provided for @loginRecoveryCodeHintAlpha.
  ///
  /// In es, this message translates to:
  /// **'Ej. 1a3B'**
  String get loginRecoveryCodeHintAlpha;

  /// No description provided for @loginRecoveryCodeHintNumeric.
  ///
  /// In es, this message translates to:
  /// **'Ej. 1234'**
  String get loginRecoveryCodeHintNumeric;

  /// No description provided for @loginVerifyCode.
  ///
  /// In es, this message translates to:
  /// **'Verificar código'**
  String get loginVerifyCode;

  /// No description provided for @loginRecoveryStep3NewPassword.
  ///
  /// In es, this message translates to:
  /// **'Paso 3: Nueva contraseña'**
  String get loginRecoveryStep3NewPassword;

  /// No description provided for @loginRecoveryStep3NewPasswordBody.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu nueva contraseña.'**
  String get loginRecoveryStep3NewPasswordBody;

  /// No description provided for @loginNewPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Nueva contraseña'**
  String get loginNewPasswordLabel;

  /// No description provided for @loginRepeatNewPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Repetir nueva contraseña'**
  String get loginRepeatNewPasswordLabel;

  /// No description provided for @loginBothPasswordsRequired.
  ///
  /// In es, this message translates to:
  /// **'Completa ambos campos de contraseña.'**
  String get loginBothPasswordsRequired;

  /// No description provided for @loginPasswordsMismatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden.'**
  String get loginPasswordsMismatch;

  /// No description provided for @loginPasswordResetSuccess.
  ///
  /// In es, this message translates to:
  /// **'Contraseña restablecida. Ya puedes iniciar sesión.'**
  String get loginPasswordResetSuccess;

  /// No description provided for @loginTwoFactorRecoveryIntro.
  ///
  /// In es, this message translates to:
  /// **'Para restablecer tu contraseña con doble factor de autenticación, necesitas el código temporal de tu app.'**
  String get loginTwoFactorRecoveryIntro;

  /// No description provided for @loginTwoFactorRecoveryStep1.
  ///
  /// In es, this message translates to:
  /// **'Paso 1: Abre tu app de autenticación'**
  String get loginTwoFactorRecoveryStep1;

  /// No description provided for @loginTwoFactorRecoveryStep1Body.
  ///
  /// In es, this message translates to:
  /// **'Busca el código temporal de 6 dígitos en tu app de autenticación (Google Authenticator, Microsoft Authenticator, Authy, etc.)'**
  String get loginTwoFactorRecoveryStep1Body;

  /// No description provided for @loginIHaveIt.
  ///
  /// In es, this message translates to:
  /// **'Ya lo tengo'**
  String get loginIHaveIt;

  /// No description provided for @loginTwoFactorRecoveryStep2.
  ///
  /// In es, this message translates to:
  /// **'Paso 2: Verifica tu código 2FA'**
  String get loginTwoFactorRecoveryStep2;

  /// No description provided for @loginTwoFactorRecoveryStep2Body.
  ///
  /// In es, this message translates to:
  /// **'Introduce el código de 6 dígitos en el campo de abajo.'**
  String get loginTwoFactorRecoveryStep2Body;

  /// No description provided for @loginTwoFactorCodeSixDigitsLabel.
  ///
  /// In es, this message translates to:
  /// **'Código 2FA (6 dígitos)'**
  String get loginTwoFactorCodeSixDigitsLabel;

  /// No description provided for @loginTwoFactorCodeHint.
  ///
  /// In es, this message translates to:
  /// **'000000'**
  String get loginTwoFactorCodeHint;

  /// No description provided for @loginVerifyTwoFactorCode.
  ///
  /// In es, this message translates to:
  /// **'Verificar código 2FA'**
  String get loginVerifyTwoFactorCode;

  /// No description provided for @loginCodeMustHaveExactly6Digits.
  ///
  /// In es, this message translates to:
  /// **'El código debe tener exactamente 6 dígitos.'**
  String get loginCodeMustHaveExactly6Digits;

  /// No description provided for @loginPasswordUpdatedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Contraseña actualizada. Ya puedes iniciar sesión.'**
  String get loginPasswordUpdatedSuccess;

  /// No description provided for @loginUsernameLabel.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get loginUsernameLabel;

  /// No description provided for @loginEnterUsername.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu usuario'**
  String get loginEnterUsername;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get loginPasswordLabel;

  /// No description provided for @loginEnterPassword.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu contraseña'**
  String get loginEnterPassword;

  /// No description provided for @loginSignIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Sesión'**
  String get loginSignIn;

  /// No description provided for @loginForgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get loginForgotPassword;

  /// No description provided for @loginGuestInfo.
  ///
  /// In es, this message translates to:
  /// **'Accede a NutriFit gratis para consultar consejos de salud, de nutrición, vídeos de ejercicios, recetas de cocina, control de peso y mucho más.'**
  String get loginGuestInfo;

  /// No description provided for @loginGuestAccess.
  ///
  /// In es, this message translates to:
  /// **'Acceder sin credenciales'**
  String get loginGuestAccess;

  /// No description provided for @loginRegisterFree.
  ///
  /// In es, this message translates to:
  /// **'Regístrate gratis'**
  String get loginRegisterFree;

  /// No description provided for @registerCreateAccountTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get registerCreateAccountTitle;

  /// No description provided for @registerFullNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre completo'**
  String get registerFullNameLabel;

  /// No description provided for @registerEnterFullName.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu nombre'**
  String get registerEnterFullName;

  /// No description provided for @registerUsernameMinLength.
  ///
  /// In es, this message translates to:
  /// **'El usuario debe tener al menos 3 caracteres'**
  String get registerUsernameMinLength;

  /// No description provided for @registerEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get registerEmailLabel;

  /// No description provided for @registerInvalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Email no válido'**
  String get registerInvalidEmail;

  /// No description provided for @registerAdditionalDataTitle.
  ///
  /// In es, this message translates to:
  /// **'Datos adicionales'**
  String get registerAdditionalDataTitle;

  /// No description provided for @registerAdditionalDataCollapsedSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Edad y altura (no obligatorios)'**
  String get registerAdditionalDataCollapsedSubtitle;

  /// No description provided for @registerAdditionalDataExpandedSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Edad y altura para IMC/MVP'**
  String get registerAdditionalDataExpandedSubtitle;

  /// No description provided for @registerAdditionalDataInfo.
  ///
  /// In es, this message translates to:
  /// **'Para habilitar el cálculo de IMC, MVP y métricas de salud, indica edad y altura (en centímetros).'**
  String get registerAdditionalDataInfo;

  /// No description provided for @registerAgeLabel.
  ///
  /// In es, this message translates to:
  /// **'Edad'**
  String get registerAgeLabel;

  /// No description provided for @registerInvalidAge.
  ///
  /// In es, this message translates to:
  /// **'Edad no válida'**
  String get registerInvalidAge;

  /// No description provided for @registerHeightLabel.
  ///
  /// In es, this message translates to:
  /// **'Altura (cm)'**
  String get registerHeightLabel;

  /// No description provided for @registerInvalidHeight.
  ///
  /// In es, this message translates to:
  /// **'Altura no válida'**
  String get registerInvalidHeight;

  /// No description provided for @registerConfirmPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get registerConfirmPasswordLabel;

  /// No description provided for @registerConfirmPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Confirma tu contraseña'**
  String get registerConfirmPasswordRequired;

  /// No description provided for @registerCreateAccountButton.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get registerCreateAccountButton;

  /// No description provided for @registerAlreadyHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta? Inicia sesión'**
  String get registerAlreadyHaveAccount;

  /// No description provided for @registerEmailUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Esta cuenta de email no puede usarse, indica otra.'**
  String get registerEmailUnavailable;

  /// No description provided for @registerSuccessMessage.
  ///
  /// In es, this message translates to:
  /// **'Usuario registrado correctamente. Por favor, inicia sesión con tus datos (usuario y contraseña).'**
  String get registerSuccessMessage;

  /// No description provided for @registerNetworkError.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido realizar el proceso. Revisa la conexión a Internet.'**
  String get registerNetworkError;

  /// No description provided for @registerGenericError.
  ///
  /// In es, this message translates to:
  /// **'Error al registrarse'**
  String get registerGenericError;

  /// No description provided for @loginResetPassword.
  ///
  /// In es, this message translates to:
  /// **'Restablecer contraseña'**
  String get loginResetPassword;

  /// No description provided for @loginEmailRecoverySendFailedGeneric.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido enviar el email de recuperación en este momento, inténtelo más tarde.'**
  String get loginEmailRecoverySendFailedGeneric;

  /// No description provided for @passwordChecklistTitle.
  ///
  /// In es, this message translates to:
  /// **'Requisitos de contraseña:'**
  String get passwordChecklistTitle;

  /// No description provided for @passwordChecklistMinLength.
  ///
  /// In es, this message translates to:
  /// **'Mínimo {count} caracteres'**
  String passwordChecklistMinLength(Object count);

  /// No description provided for @passwordChecklistUpperLower.
  ///
  /// In es, this message translates to:
  /// **'Al menos una mayúscula y una minúscula'**
  String get passwordChecklistUpperLower;

  /// No description provided for @passwordChecklistNumber.
  ///
  /// In es, this message translates to:
  /// **'Al menos un número (0-9)'**
  String get passwordChecklistNumber;

  /// No description provided for @passwordChecklistSpecial.
  ///
  /// In es, this message translates to:
  /// **'Al menos un carácter especial (*,.+-#\\\$?¿!¡_()/\\%&)'**
  String get passwordChecklistSpecial;

  /// No description provided for @loginPasswordMinLengthError.
  ///
  /// In es, this message translates to:
  /// **'La nueva contraseña debe tener al menos {count} caracteres.'**
  String loginPasswordMinLengthError(Object count);

  /// No description provided for @loginPasswordUppercaseError.
  ///
  /// In es, this message translates to:
  /// **'La nueva contraseña debe contener al menos una letra mayúscula.'**
  String get loginPasswordUppercaseError;

  /// No description provided for @loginPasswordLowercaseError.
  ///
  /// In es, this message translates to:
  /// **'La nueva contraseña debe contener al menos una letra minúscula.'**
  String get loginPasswordLowercaseError;

  /// No description provided for @loginPasswordNumberError.
  ///
  /// In es, this message translates to:
  /// **'La nueva contraseña debe contener al menos un número.'**
  String get loginPasswordNumberError;

  /// No description provided for @loginPasswordSpecialError.
  ///
  /// In es, this message translates to:
  /// **'La nueva contraseña debe contener al menos un carácter especial (* , . + - # \\\$ ? ¿ ! ¡ _ ( ) / \\ % &).'**
  String get loginPasswordSpecialError;

  /// No description provided for @commonOk.
  ///
  /// In es, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonReadMore.
  ///
  /// In es, this message translates to:
  /// **'Leer más'**
  String get commonReadMore;

  /// No description provided for @commonViewAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todos'**
  String get commonViewAll;

  /// No description provided for @commonCouldNotOpenLink.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el enlace'**
  String get commonCouldNotOpenLink;

  /// No description provided for @commonCollapse.
  ///
  /// In es, this message translates to:
  /// **'Plegar'**
  String get commonCollapse;

  /// No description provided for @commonExpand.
  ///
  /// In es, this message translates to:
  /// **'Desplegar'**
  String get commonExpand;

  /// No description provided for @patientSecurityRecommendedTitle.
  ///
  /// In es, this message translates to:
  /// **'Mejora la seguridad de tu cuenta'**
  String get patientSecurityRecommendedTitle;

  /// No description provided for @patientSecurityRecommendedBody.
  ///
  /// In es, this message translates to:
  /// **'Te recomendamos activar el doble factor (2FA). Añade una capa extra de protección además de tu contraseña.'**
  String get patientSecurityRecommendedBody;

  /// No description provided for @patientChatLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido realizar el proceso. Revise la conexión a Internet'**
  String get patientChatLoadError;

  /// No description provided for @patientAdherenceNutriPlan.
  ///
  /// In es, this message translates to:
  /// **'Plan nutricional'**
  String get patientAdherenceNutriPlan;

  /// No description provided for @patientAdherenceFitPlan.
  ///
  /// In es, this message translates to:
  /// **'Plan Fit'**
  String get patientAdherenceFitPlan;

  /// No description provided for @patientAdherenceCompleted.
  ///
  /// In es, this message translates to:
  /// **'Cumplido'**
  String get patientAdherenceCompleted;

  /// No description provided for @patientAdherencePartial.
  ///
  /// In es, this message translates to:
  /// **'Parcial'**
  String get patientAdherencePartial;

  /// No description provided for @patientAdherenceNotDone.
  ///
  /// In es, this message translates to:
  /// **'No realizado'**
  String get patientAdherenceNotDone;

  /// No description provided for @patientAdherenceNoChanges.
  ///
  /// In es, this message translates to:
  /// **'Sin cambios'**
  String get patientAdherenceNoChanges;

  /// No description provided for @patientAdherenceTrendPoints.
  ///
  /// In es, this message translates to:
  /// **'{trend} pts'**
  String patientAdherenceTrendPoints(Object trend);

  /// No description provided for @patientAdherenceTitle.
  ///
  /// In es, this message translates to:
  /// **'Cumplimiento'**
  String get patientAdherenceTitle;

  /// No description provided for @patientAdherenceImprovementPoints.
  ///
  /// In es, this message translates to:
  /// **'Puntos de mejora'**
  String get patientAdherenceImprovementPoints;

  /// No description provided for @patientAdherenceImprovementNutriTarget.
  ///
  /// In es, this message translates to:
  /// **'Nutri: intenta cumplir al menos 5 de 7 días esta semana.'**
  String get patientAdherenceImprovementNutriTarget;

  /// No description provided for @patientAdherenceImprovementNutriTrend.
  ///
  /// In es, this message translates to:
  /// **'Nutri: vas a la baja frente a la semana pasada; vuelve a tu rutina base.'**
  String get patientAdherenceImprovementNutriTrend;

  /// No description provided for @patientAdherenceImprovementFitTarget.
  ///
  /// In es, this message translates to:
  /// **'Fit: intenta llegar a 3-4 sesiones semanales, aunque sean cortas.'**
  String get patientAdherenceImprovementFitTarget;

  /// No description provided for @patientAdherenceImprovementFitTrend.
  ///
  /// In es, this message translates to:
  /// **'Fit: la tendencia ha bajado; agenda tus próximas sesiones hoy.'**
  String get patientAdherenceImprovementFitTrend;

  /// No description provided for @patientAdherenceImprovementKeepGoing.
  ///
  /// In es, this message translates to:
  /// **'Buen ritmo. Mantén la constancia para consolidar resultados.'**
  String get patientAdherenceImprovementKeepGoing;

  /// No description provided for @patientAdherenceSheetTitleToday.
  ///
  /// In es, this message translates to:
  /// **'Cumplimiento para hoy'**
  String get patientAdherenceSheetTitleToday;

  /// No description provided for @patientAdherenceSheetTitleForDate.
  ///
  /// In es, this message translates to:
  /// **'Cumplimiento para {date}'**
  String patientAdherenceSheetTitleForDate(Object date);

  /// No description provided for @patientAdherenceDateToday.
  ///
  /// In es, this message translates to:
  /// **'hoy'**
  String get patientAdherenceDateToday;

  /// No description provided for @patientAdherenceStatusSaved.
  ///
  /// In es, this message translates to:
  /// **'{plan}: {status} {date}'**
  String patientAdherenceStatusSaved(Object plan, Object status, Object date);

  /// No description provided for @patientAdherenceFutureDateError.
  ///
  /// In es, this message translates to:
  /// **'No se puede registrar cumplimiento en fechas futuras. Solo hoy o días anteriores.'**
  String get patientAdherenceFutureDateError;

  /// No description provided for @patientAdherenceReasonNotDoneTitle.
  ///
  /// In es, this message translates to:
  /// **'Motivo de no realización'**
  String get patientAdherenceReasonNotDoneTitle;

  /// No description provided for @patientAdherenceReasonPartialTitle.
  ///
  /// In es, this message translates to:
  /// **'Motivo de cumplimiento parcial'**
  String get patientAdherenceReasonPartialTitle;

  /// No description provided for @patientAdherenceReasonHint.
  ///
  /// In es, this message translates to:
  /// **'Cuéntanos brevemente qué pasó hoy'**
  String get patientAdherenceReasonHint;

  /// No description provided for @patientAdherenceSkipReason.
  ///
  /// In es, this message translates to:
  /// **'Omitir motivo'**
  String get patientAdherenceSkipReason;

  /// No description provided for @patientAdherenceSaveContinue.
  ///
  /// In es, this message translates to:
  /// **'Guardar y continuar'**
  String get patientAdherenceSaveContinue;

  /// No description provided for @patientAdherenceSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar en la base de datos: {error}'**
  String patientAdherenceSaveError(Object error);

  /// No description provided for @patientAdherenceReasonLabel.
  ///
  /// In es, this message translates to:
  /// **'Motivo'**
  String get patientAdherenceReasonLabel;

  /// No description provided for @patientAdherenceInfoTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué significa cada estado de cumplimiento?'**
  String get patientAdherenceInfoTitle;

  /// No description provided for @patientAdherenceNutriCompletedDescription.
  ///
  /// In es, this message translates to:
  /// **'Seguiste el plan de alimentación tal como estaba previsto para este día.'**
  String get patientAdherenceNutriCompletedDescription;

  /// No description provided for @patientAdherenceNutriPartialDescription.
  ///
  /// In es, this message translates to:
  /// **'Seguiste parte del plan pero no completamente: alguna comida omitida, cambiada o con cantidad distinta.'**
  String get patientAdherenceNutriPartialDescription;

  /// No description provided for @patientAdherenceNutriNotDoneDescription.
  ///
  /// In es, this message translates to:
  /// **'No seguiste el plan de alimentación en este día.'**
  String get patientAdherenceNutriNotDoneDescription;

  /// No description provided for @patientAdherenceFitCompletedDescription.
  ///
  /// In es, this message translates to:
  /// **'Realizaste el entrenamiento completo previsto para este día.'**
  String get patientAdherenceFitCompletedDescription;

  /// No description provided for @patientAdherenceFitPartialDescription.
  ///
  /// In es, this message translates to:
  /// **'Hiciste parte del entrenamiento: algunos ejercicios, series o tiempo incompleto.'**
  String get patientAdherenceFitPartialDescription;

  /// No description provided for @patientAdherenceFitNotDoneDescription.
  ///
  /// In es, this message translates to:
  /// **'No realizaste el entrenamiento en este día.'**
  String get patientAdherenceFitNotDoneDescription;

  /// No description provided for @patientAdherenceAlertRecoveryTitle.
  ///
  /// In es, this message translates to:
  /// **'Vamos a reaccionar'**
  String get patientAdherenceAlertRecoveryTitle;

  /// No description provided for @patientAdherenceAlertRecoveryBody.
  ///
  /// In es, this message translates to:
  /// **'Llevas dos semanas seguidas por debajo del 50% en {plan}. Vamos a recuperar el ritmo ya: pequeños pasos diarios, pero sin fallar. Tú puedes, pero toca ponerse serio.'**
  String patientAdherenceAlertRecoveryBody(Object plan);

  /// No description provided for @patientAdherenceAlertEncouragementTitle.
  ///
  /// In es, this message translates to:
  /// **'Aún estamos a tiempo'**
  String get patientAdherenceAlertEncouragementTitle;

  /// No description provided for @patientAdherenceAlertEncouragementBody.
  ///
  /// In es, this message translates to:
  /// **'Esta semana {plan} va por debajo del 50%. La próxima puede ser mucho mejor: vuelve a tu rutina base y suma una victoria cada día.'**
  String patientAdherenceAlertEncouragementBody(Object plan);

  /// No description provided for @patientRecommendationsForYou.
  ///
  /// In es, this message translates to:
  /// **'Recomendaciones para ti'**
  String get patientRecommendationsForYou;

  /// No description provided for @patientWelcomeNeutral.
  ///
  /// In es, this message translates to:
  /// **'Bienvenid@'**
  String get patientWelcomeNeutral;

  /// No description provided for @patientWelcomeFemale.
  ///
  /// In es, this message translates to:
  /// **'Bienvenida'**
  String get patientWelcomeFemale;

  /// No description provided for @patientWelcomeMale.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido'**
  String get patientWelcomeMale;

  /// No description provided for @patientWelcomeToNutriFit.
  ///
  /// In es, this message translates to:
  /// **'{welcome} a NutriFit'**
  String patientWelcomeToNutriFit(Object welcome);

  /// No description provided for @patientWelcomeBody.
  ///
  /// In es, this message translates to:
  /// **'Desde NutriFit podrás consultar tus planes nutricionales y de entrenamiento personalizados. Podrás chatear y contactar con tu dietista online y leer recomendaciones personalizadas. \n\nDispones de Consejos de nutrición y salud, Recetas de cocina, lista de la compra, información de alimentos, mediciones (control de peso), presión arterial y muchas otras cosas...'**
  String get patientWelcomeBody;

  /// No description provided for @patientPersonalRecommendation.
  ///
  /// In es, this message translates to:
  /// **'Recomendación personal'**
  String get patientPersonalRecommendation;

  /// No description provided for @patientNewBadge.
  ///
  /// In es, this message translates to:
  /// **'NUEVO'**
  String get patientNewBadge;

  /// No description provided for @patientContactDietitianPrompt.
  ///
  /// In es, this message translates to:
  /// **'Contactar con el dietista...'**
  String get patientContactDietitianPrompt;

  /// No description provided for @patientContactDietitianTrainer.
  ///
  /// In es, this message translates to:
  /// **'Contactar con Dietista/Entrenador'**
  String get patientContactDietitianTrainer;

  /// No description provided for @contactDietitianMethodsTitle.
  ///
  /// In es, this message translates to:
  /// **'Formas de contacto'**
  String get contactDietitianMethodsTitle;

  /// No description provided for @contactDietitianEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get contactDietitianEmailLabel;

  /// No description provided for @contactDietitianCallLabel.
  ///
  /// In es, this message translates to:
  /// **'Llamar'**
  String get contactDietitianCallLabel;

  /// No description provided for @contactDietitianSocialTitle.
  ///
  /// In es, this message translates to:
  /// **'Síguenos en redes sociales'**
  String get contactDietitianSocialTitle;

  /// No description provided for @contactDietitianWebsiteLabel.
  ///
  /// In es, this message translates to:
  /// **'Sitio web'**
  String get contactDietitianWebsiteLabel;

  /// No description provided for @contactDietitianPhoneCopied.
  ///
  /// In es, this message translates to:
  /// **'Teléfono copiado al portapapeles.'**
  String get contactDietitianPhoneCopied;

  /// No description provided for @contactDietitianWhatsappInvalidPhone.
  ///
  /// In es, this message translates to:
  /// **'No hay un teléfono válido para abrir WhatsApp.'**
  String get contactDietitianWhatsappInvalidPhone;

  /// No description provided for @contactDietitianWhatsappOpenError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir WhatsApp: {error}'**
  String contactDietitianWhatsappOpenError(Object error);

  /// No description provided for @contactDietitianWhatsappDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Contactar por WhatsApp'**
  String get contactDietitianWhatsappDialogTitle;

  /// No description provided for @contactDietitianWhatsappDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Puedes abrir el chat de WhatsApp directamente con el número {phone}. También puedes copiar el número al portapapeles para usarlo en tu aplicación de WhatsApp o para guardarlo.'**
  String contactDietitianWhatsappDialogBody(Object phone);

  /// No description provided for @contactDietitianCopyPhone.
  ///
  /// In es, this message translates to:
  /// **'Copiar teléfono'**
  String get contactDietitianCopyPhone;

  /// No description provided for @contactDietitianOpenWhatsapp.
  ///
  /// In es, this message translates to:
  /// **'Abrir WhatsApp'**
  String get contactDietitianOpenWhatsapp;

  /// No description provided for @contactDietitianWhatsappLabel.
  ///
  /// In es, this message translates to:
  /// **'WhatsApp'**
  String get contactDietitianWhatsappLabel;

  /// No description provided for @contactDietitianTelegramLabel.
  ///
  /// In es, this message translates to:
  /// **'Telegram'**
  String get contactDietitianTelegramLabel;

  /// No description provided for @chatTitle.
  ///
  /// In es, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @chatHideSearch.
  ///
  /// In es, this message translates to:
  /// **'Ocultar búsqueda'**
  String get chatHideSearch;

  /// No description provided for @chatSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get chatSearch;

  /// No description provided for @chatSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar en el chat...'**
  String get chatSearchHint;

  /// No description provided for @chatMessageHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe un mensaje'**
  String get chatMessageHint;

  /// No description provided for @profileImagePickerDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar imagen de perfil'**
  String get profileImagePickerDialogTitle;

  /// No description provided for @profileImagePickerTakePhoto.
  ///
  /// In es, this message translates to:
  /// **'Tomar foto'**
  String get profileImagePickerTakePhoto;

  /// No description provided for @profileImagePickerChooseFromGallery.
  ///
  /// In es, this message translates to:
  /// **'Elegir de galería'**
  String get profileImagePickerChooseFromGallery;

  /// No description provided for @profileImagePickerSelectImage.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar imagen'**
  String get profileImagePickerSelectImage;

  /// No description provided for @profileImagePickerRemovePhoto.
  ///
  /// In es, this message translates to:
  /// **'Eliminar foto'**
  String get profileImagePickerRemovePhoto;

  /// No description provided for @profileImagePickerPrompt.
  ///
  /// In es, this message translates to:
  /// **'Selecciona tu imagen de perfil'**
  String get profileImagePickerPrompt;

  /// No description provided for @profileImagePickerMaxDimensions.
  ///
  /// In es, this message translates to:
  /// **'Máx. {width}x{height}px'**
  String profileImagePickerMaxDimensions(Object width, Object height);

  /// No description provided for @profileImagePickerSaved.
  ///
  /// In es, this message translates to:
  /// **'Imagen guardada correctamente ({sizeKb}KB)'**
  String profileImagePickerSaved(Object sizeKb);

  /// No description provided for @profileImagePickerProcessError.
  ///
  /// In es, this message translates to:
  /// **'Error al procesar la imagen'**
  String get profileImagePickerProcessError;

  /// No description provided for @profileImagePickerTechnicalDetails.
  ///
  /// In es, this message translates to:
  /// **'Detalles técnicos'**
  String get profileImagePickerTechnicalDetails;

  /// No description provided for @profileImagePickerOperationFailed.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido completar la operación. Por favor, inténtalo de nuevo o contacta con soporte.'**
  String get profileImagePickerOperationFailed;

  /// No description provided for @shoppingListPremiumTitle.
  ///
  /// In es, this message translates to:
  /// **'Lista de la compra Premium'**
  String get shoppingListPremiumTitle;

  /// No description provided for @shoppingListPremiumSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Puedes consultar los {limit} últimos items y crear hasta {limit} registros. Si quieres una lista ilimitada, '**
  String shoppingListPremiumSubtitle(Object limit);

  /// No description provided for @shoppingListPremiumHighlight.
  ///
  /// In es, this message translates to:
  /// **'hazte Premium.'**
  String get shoppingListPremiumHighlight;

  /// No description provided for @shoppingListPremiumLimitMessage.
  ///
  /// In es, this message translates to:
  /// **'Como usuario no Premium puedes crear hasta {limit} items en la lista de la compra. Hazte Premium para añadir items ilimitados y consultar todo el histórico.'**
  String shoppingListPremiumLimitMessage(Object limit);

  /// No description provided for @shoppingListTabAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get shoppingListTabAll;

  /// No description provided for @shoppingListTabPending.
  ///
  /// In es, this message translates to:
  /// **'Próxima compra'**
  String get shoppingListTabPending;

  /// No description provided for @shoppingListTabBought.
  ///
  /// In es, this message translates to:
  /// **'Comprados'**
  String get shoppingListTabBought;

  /// No description provided for @shoppingListTabExpiring.
  ///
  /// In es, this message translates to:
  /// **'Por caducar'**
  String get shoppingListTabExpiring;

  /// No description provided for @shoppingListTabExpired.
  ///
  /// In es, this message translates to:
  /// **'Caducados'**
  String get shoppingListTabExpired;

  /// No description provided for @shoppingListFilterCategories.
  ///
  /// In es, this message translates to:
  /// **'Filtrar categorías'**
  String get shoppingListFilterCategories;

  /// No description provided for @shoppingListFilterCategoriesCount.
  ///
  /// In es, this message translates to:
  /// **'Filtrar categorías ({count})'**
  String shoppingListFilterCategoriesCount(Object count);

  /// No description provided for @shoppingListMoreOptions.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get shoppingListMoreOptions;

  /// No description provided for @shoppingListFilter.
  ///
  /// In es, this message translates to:
  /// **'Filtrar'**
  String get shoppingListFilter;

  /// No description provided for @shoppingListRefresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get shoppingListRefresh;

  /// No description provided for @shoppingListAddItem.
  ///
  /// In es, this message translates to:
  /// **'Añadir item'**
  String get shoppingListAddItem;

  /// No description provided for @shoppingListGuestMessage.
  ///
  /// In es, this message translates to:
  /// **'Para poder usar la Lista de la compra, debes registrarte (es gratis).'**
  String get shoppingListGuestMessage;

  /// No description provided for @weightControlBack.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get weightControlBack;

  /// No description provided for @weightControlChangeTarget.
  ///
  /// In es, this message translates to:
  /// **'Cambiar peso objetivo'**
  String get weightControlChangeTarget;

  /// No description provided for @weightControlHideFilter.
  ///
  /// In es, this message translates to:
  /// **'Ocultar filtro'**
  String get weightControlHideFilter;

  /// No description provided for @weightControlShowFilter.
  ///
  /// In es, this message translates to:
  /// **'Mostrar filtro'**
  String get weightControlShowFilter;

  /// No description provided for @weightControlGuestMessage.
  ///
  /// In es, this message translates to:
  /// **'Para poder gestionar tu control de pesos debes registrarte (es gratis).'**
  String get weightControlGuestMessage;

  /// No description provided for @weightControlLoadError.
  ///
  /// In es, this message translates to:
  /// **'Error cargando mediciones: {error}'**
  String weightControlLoadError(Object error);

  /// No description provided for @weightControlNoMeasurementsTitle.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay mediciones registradas.'**
  String get weightControlNoMeasurementsTitle;

  /// No description provided for @weightControlNoMeasurementsBody.
  ///
  /// In es, this message translates to:
  /// **'Empieza añadiendo tu primera medición para ver tu evolución.'**
  String get weightControlNoMeasurementsBody;

  /// No description provided for @weightControlAddMeasurement.
  ///
  /// In es, this message translates to:
  /// **'Añadir medición'**
  String get weightControlAddMeasurement;

  /// No description provided for @weightControlNoWeightsForPeriod.
  ///
  /// In es, this message translates to:
  /// **'No hay pesos para {period}.'**
  String weightControlNoWeightsForPeriod(Object period);

  /// No description provided for @weightControlNoMeasurementsForPeriod.
  ///
  /// In es, this message translates to:
  /// **'No hay mediciones para {period}.'**
  String weightControlNoMeasurementsForPeriod(Object period);

  /// No description provided for @weightControlPremiumPerimetersTitle.
  ///
  /// In es, this message translates to:
  /// **'Evolución de perímetros Premium'**
  String get weightControlPremiumPerimetersTitle;

  /// No description provided for @weightControlPremiumChartBody.
  ///
  /// In es, this message translates to:
  /// **'Esta gráfica está disponible solo para usuarios Premium. Activa tu cuenta para ver tu evolución completa con indicadores visuales avanzados.'**
  String get weightControlPremiumChartBody;

  /// No description provided for @weightControlCurrentMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes actual'**
  String get weightControlCurrentMonth;

  /// No description provided for @weightControlPreviousMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes anterior'**
  String get weightControlPreviousMonth;

  /// No description provided for @weightControlQuarter.
  ///
  /// In es, this message translates to:
  /// **'Trimestre'**
  String get weightControlQuarter;

  /// No description provided for @weightControlSemester.
  ///
  /// In es, this message translates to:
  /// **'Semestre'**
  String get weightControlSemester;

  /// No description provided for @weightControlCurrentYear.
  ///
  /// In es, this message translates to:
  /// **'Año'**
  String get weightControlCurrentYear;

  /// No description provided for @weightControlPreviousYear.
  ///
  /// In es, this message translates to:
  /// **'Año anterior'**
  String get weightControlPreviousYear;

  /// No description provided for @weightControlAllTime.
  ///
  /// In es, this message translates to:
  /// **'Siempre'**
  String get weightControlAllTime;

  /// No description provided for @weightControlLastDaysLabel.
  ///
  /// In es, this message translates to:
  /// **'Últimos {days} días'**
  String weightControlLastDaysLabel(Object days);

  /// No description provided for @patientMoreContactOptions.
  ///
  /// In es, this message translates to:
  /// **'Más formas de contacto'**
  String get patientMoreContactOptions;

  /// No description provided for @patientContactEmailShort.
  ///
  /// In es, this message translates to:
  /// **'Email...'**
  String get patientContactEmailShort;

  /// No description provided for @patientContactWhatsAppShort.
  ///
  /// In es, this message translates to:
  /// **'WhatsApp...'**
  String get patientContactWhatsAppShort;

  /// No description provided for @patientContactTelegramShort.
  ///
  /// In es, this message translates to:
  /// **'Telegram...'**
  String get patientContactTelegramShort;

  /// No description provided for @patientContactEmailSubject.
  ///
  /// In es, this message translates to:
  /// **'Solicitud de servicios de Nutricionista Online'**
  String get patientContactEmailSubject;

  /// No description provided for @patientAddDietitianToContactsTitle.
  ///
  /// In es, this message translates to:
  /// **'Agregar dietista a contactos'**
  String get patientAddDietitianToContactsTitle;

  /// No description provided for @patientAddDietitianToContactsBody.
  ///
  /// In es, this message translates to:
  /// **'Por favor, agrega al dietista manualmente a tus contactos con los siguientes datos:\n\nNombre: Dietista Online - NutriFit'**
  String get patientAddDietitianToContactsBody;

  /// No description provided for @patientViewAllTipsCount.
  ///
  /// In es, this message translates to:
  /// **'Ver todos los consejos ({count})'**
  String patientViewAllTipsCount(Object count);

  /// No description provided for @settingsNotificationsTab.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get settingsNotificationsTab;

  /// No description provided for @settingsLegendsTab.
  ///
  /// In es, this message translates to:
  /// **'Leyendas'**
  String get settingsLegendsTab;

  /// No description provided for @settingsCalendarsTab.
  ///
  /// In es, this message translates to:
  /// **'Calendarios'**
  String get settingsCalendarsTab;

  /// No description provided for @settingsPushPreferenceSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la preferencia de notificaciones push.'**
  String get settingsPushPreferenceSaveError;

  /// No description provided for @settingsScannerFrameReset.
  ///
  /// In es, this message translates to:
  /// **'Recuadro de escaneo restablecido a valores por defecto'**
  String get settingsScannerFrameReset;

  /// No description provided for @settingsCurrentView.
  ///
  /// In es, this message translates to:
  /// **'Vista actual: {mode}'**
  String settingsCurrentView(Object mode);

  /// No description provided for @settingsCalendarModeWeek.
  ///
  /// In es, this message translates to:
  /// **'Semana'**
  String get settingsCalendarModeWeek;

  /// No description provided for @settingsCalendarModeMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get settingsCalendarModeMonth;

  /// No description provided for @settingsCalendarModeTwoWeeks.
  ///
  /// In es, this message translates to:
  /// **'2 semanas'**
  String get settingsCalendarModeTwoWeeks;

  /// No description provided for @settingsNutriBreachTitle.
  ///
  /// In es, this message translates to:
  /// **'Avisos de incumplimiento Plan Nutri'**
  String get settingsNutriBreachTitle;

  /// No description provided for @settingsNutriBreachSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Recibir notificaciones cuando no se cumpla el plan nutricional.'**
  String get settingsNutriBreachSubtitle;

  /// No description provided for @settingsFitBreachTitle.
  ///
  /// In es, this message translates to:
  /// **'Avisos de incumplimiento Plan Fit'**
  String get settingsFitBreachTitle;

  /// No description provided for @settingsFitBreachSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Recibir notificaciones cuando no se cumpla el plan de entrenamiento.'**
  String get settingsFitBreachSubtitle;

  /// No description provided for @settingsChatPushTitle.
  ///
  /// In es, this message translates to:
  /// **'Activar notificaciones push de chat'**
  String get settingsChatPushTitle;

  /// No description provided for @settingsChatPushSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Recibir notificaciones push cuando tengas mensajes sin leer del dietista.'**
  String get settingsChatPushSubtitle;

  /// No description provided for @settingsPerimetersLegendTitle.
  ///
  /// In es, this message translates to:
  /// **'Evolución de perímetros'**
  String get settingsPerimetersLegendTitle;

  /// No description provided for @settingsPerimetersLegendSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Muestra u oculta la leyenda en la gráfica de evolución de perímetros.'**
  String get settingsPerimetersLegendSubtitle;

  /// No description provided for @settingsWeightCalendarLegendTitle.
  ///
  /// In es, this message translates to:
  /// **'Calendario de control de pesos'**
  String get settingsWeightCalendarLegendTitle;

  /// No description provided for @settingsWeightCalendarLegendSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Muestra u oculta la leyenda del calendario de control de pesos (adelgazó, engordó, sin cambios, IMC normal, IMC fuera de rango y superior peso/inferior IMC).'**
  String get settingsWeightCalendarLegendSubtitle;

  /// No description provided for @settingsTasksCalendarLegendTitle.
  ///
  /// In es, this message translates to:
  /// **'Calendario de tareas'**
  String get settingsTasksCalendarLegendTitle;

  /// No description provided for @settingsTasksCalendarLegendSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Leyenda futura. Próximamente se aplicará esta preferencia al calendario de tareas.'**
  String get settingsTasksCalendarLegendSubtitle;

  /// No description provided for @settingsTasksCalendarTitle.
  ///
  /// In es, this message translates to:
  /// **'Calendario de tareas'**
  String get settingsTasksCalendarTitle;

  /// No description provided for @settingsWeightControlCalendarTitle.
  ///
  /// In es, this message translates to:
  /// **'Calendario de mediciones (control de peso)'**
  String get settingsWeightControlCalendarTitle;

  /// No description provided for @settingsNutriCalendarTitle.
  ///
  /// In es, this message translates to:
  /// **'Calendario Planes Nutri'**
  String get settingsNutriCalendarTitle;

  /// No description provided for @settingsFitCalendarTitle.
  ///
  /// In es, this message translates to:
  /// **'Calendario Planes Fit'**
  String get settingsFitCalendarTitle;

  /// No description provided for @settingsShowActivityEquivalencesTitle.
  ///
  /// In es, this message translates to:
  /// **'Mostrar equivalencias en actividades'**
  String get settingsShowActivityEquivalencesTitle;

  /// No description provided for @settingsShowActivityEquivalencesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Activa o desactiva los mensajes de equivalencias en la pantalla de actividades.'**
  String get settingsShowActivityEquivalencesSubtitle;

  /// No description provided for @settingsScannerFrameWidthTitle.
  ///
  /// In es, this message translates to:
  /// **'Ancho del recuadro de escaneo'**
  String get settingsScannerFrameWidthTitle;

  /// No description provided for @settingsScannerFrameWidthSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Se aplica al hacer foto en escanear etiquetas y en lista de la compra.'**
  String get settingsScannerFrameWidthSubtitle;

  /// No description provided for @settingsScannerFrameHeightTitle.
  ///
  /// In es, this message translates to:
  /// **'Alto del recuadro de escaneo'**
  String get settingsScannerFrameHeightTitle;

  /// No description provided for @settingsScannerFrameHeightSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ajusta la altura del area a encuadrar para el codigo de barras.'**
  String get settingsScannerFrameHeightSubtitle;

  /// No description provided for @settingsResetScannerFrameSize.
  ///
  /// In es, this message translates to:
  /// **'Restablecer tamaño'**
  String get settingsResetScannerFrameSize;

  /// No description provided for @commonPremiumFeatureTitle.
  ///
  /// In es, this message translates to:
  /// **'Función Premium'**
  String get commonPremiumFeatureTitle;

  /// No description provided for @commonSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get commonSearch;

  /// No description provided for @commonFilter.
  ///
  /// In es, this message translates to:
  /// **'Filtrar'**
  String get commonFilter;

  /// No description provided for @commonRefresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get commonRefresh;

  /// No description provided for @commonMoreOptions.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get commonMoreOptions;

  /// No description provided for @commonDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get commonDelete;

  /// No description provided for @commonClear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get commonClear;

  /// No description provided for @commonApply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get commonApply;

  /// No description provided for @commonCopy.
  ///
  /// In es, this message translates to:
  /// **'Copiar'**
  String get commonCopy;

  /// No description provided for @commonGeneratePdf.
  ///
  /// In es, this message translates to:
  /// **'Generar PDF'**
  String get commonGeneratePdf;

  /// No description provided for @commonHideSearch.
  ///
  /// In es, this message translates to:
  /// **'Ocultar búsqueda'**
  String get commonHideSearch;

  /// No description provided for @commonFilterByCategories.
  ///
  /// In es, this message translates to:
  /// **'Filtrar por categorías'**
  String get commonFilterByCategories;

  /// No description provided for @commonFilterByCategoriesCount.
  ///
  /// In es, this message translates to:
  /// **'Filtrar categorías ({count})'**
  String commonFilterByCategoriesCount(Object count);

  /// No description provided for @commonMatchAll.
  ///
  /// In es, this message translates to:
  /// **'Coincidir todas'**
  String get commonMatchAll;

  /// No description provided for @commonRequireAllSelected.
  ///
  /// In es, this message translates to:
  /// **'Si está activo, requiere todas.'**
  String get commonRequireAllSelected;

  /// No description provided for @commonCategoryFallback.
  ///
  /// In es, this message translates to:
  /// **'Categoría {id}'**
  String commonCategoryFallback(Object id);

  /// No description provided for @commonSignInToLike.
  ///
  /// In es, this message translates to:
  /// **'Debes iniciar sesión para dar me gusta'**
  String get commonSignInToLike;

  /// No description provided for @commonSignInToSaveFavorites.
  ///
  /// In es, this message translates to:
  /// **'Debes iniciar sesión para guardar favoritos'**
  String get commonSignInToSaveFavorites;

  /// No description provided for @commonCouldNotIdentifyUser.
  ///
  /// In es, this message translates to:
  /// **'Error: No se pudo identificar el usuario'**
  String get commonCouldNotIdentifyUser;

  /// No description provided for @commonLikeChangeError.
  ///
  /// In es, this message translates to:
  /// **'Error al cambiar me gusta. {error}'**
  String commonLikeChangeError(Object error);

  /// No description provided for @commonFavoriteChangeError.
  ///
  /// In es, this message translates to:
  /// **'Error al cambiar favorito. {error}'**
  String commonFavoriteChangeError(Object error);

  /// No description provided for @commonGuestFavoritesRequiresRegistration.
  ///
  /// In es, this message translates to:
  /// **'Para poder marcar {itemType} como favoritos, debes registrarte (es gratis).'**
  String commonGuestFavoritesRequiresRegistration(Object itemType);

  /// No description provided for @commonRecipesAndTipsPremiumCopyPdfMessage.
  ///
  /// In es, this message translates to:
  /// **'Para poder copiar y pasar a PDF las recetas y consejos, debes ser usuario Premium.'**
  String get commonRecipesAndTipsPremiumCopyPdfMessage;

  /// No description provided for @commonCopiedToClipboard.
  ///
  /// In es, this message translates to:
  /// **'Copiado al portapapeles'**
  String get commonCopiedToClipboard;

  /// No description provided for @commonCopiedToClipboardLabel.
  ///
  /// In es, this message translates to:
  /// **'{label} copiado al portapapeles.'**
  String commonCopiedToClipboardLabel(Object label);

  /// No description provided for @commonLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get commonLanguage;

  /// No description provided for @commonUser.
  ///
  /// In es, this message translates to:
  /// **'usuario'**
  String get commonUser;

  /// No description provided for @languageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageEnglish.
  ///
  /// In es, this message translates to:
  /// **'Inglés'**
  String get languageEnglish;

  /// No description provided for @languageItalian.
  ///
  /// In es, this message translates to:
  /// **'Italiano'**
  String get languageItalian;

  /// No description provided for @languageGerman.
  ///
  /// In es, this message translates to:
  /// **'Alemán'**
  String get languageGerman;

  /// No description provided for @languageFrench.
  ///
  /// In es, this message translates to:
  /// **'Francés'**
  String get languageFrench;

  /// No description provided for @languagePortuguese.
  ///
  /// In es, this message translates to:
  /// **'Portugués'**
  String get languagePortuguese;

  /// No description provided for @commonCopyError.
  ///
  /// In es, this message translates to:
  /// **'Error al copiar: {error}'**
  String commonCopyError(Object error);

  /// No description provided for @commonGeneratePdfError.
  ///
  /// In es, this message translates to:
  /// **'Error al generar PDF: {error}'**
  String commonGeneratePdfError(Object error);

  /// No description provided for @commonOpenLinkError.
  ///
  /// In es, this message translates to:
  /// **'Error al abrir enlace: {error}'**
  String commonOpenLinkError(Object error);

  /// No description provided for @commonDocumentUnavailable.
  ///
  /// In es, this message translates to:
  /// **'El documento no está disponible'**
  String get commonDocumentUnavailable;

  /// No description provided for @commonDecodeError.
  ///
  /// In es, this message translates to:
  /// **'Error al decodificar: {error}'**
  String commonDecodeError(Object error);

  /// No description provided for @commonSaveDocumentError.
  ///
  /// In es, this message translates to:
  /// **'Error: No se pudo guardar el documento'**
  String get commonSaveDocumentError;

  /// No description provided for @commonOpenDocumentError.
  ///
  /// In es, this message translates to:
  /// **'Error al abrir documento: {error}'**
  String commonOpenDocumentError(Object error);

  /// No description provided for @commonDownloadDocument.
  ///
  /// In es, this message translates to:
  /// **'Descargar documento'**
  String get commonDownloadDocument;

  /// No description provided for @commonDocumentsAndLinks.
  ///
  /// In es, this message translates to:
  /// **'Documentos y enlaces'**
  String get commonDocumentsAndLinks;

  /// No description provided for @commonYouMayAlsoLike.
  ///
  /// In es, this message translates to:
  /// **'También te puede interesar...'**
  String get commonYouMayAlsoLike;

  /// No description provided for @commonSortByTitle.
  ///
  /// In es, this message translates to:
  /// **'Ordenar Título'**
  String get commonSortByTitle;

  /// No description provided for @commonSortByRecent.
  ///
  /// In es, this message translates to:
  /// **'Ordenar Recientes'**
  String get commonSortByRecent;

  /// No description provided for @commonSortByPopular.
  ///
  /// In es, this message translates to:
  /// **'Ordenar Populares'**
  String get commonSortByPopular;

  /// No description provided for @commonPersonalTab.
  ///
  /// In es, this message translates to:
  /// **'Personales'**
  String get commonPersonalTab;

  /// No description provided for @commonFeaturedTab.
  ///
  /// In es, this message translates to:
  /// **'Destacados'**
  String get commonFeaturedTab;

  /// No description provided for @commonAllTab.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get commonAllTab;

  /// No description provided for @commonFavoritesTab.
  ///
  /// In es, this message translates to:
  /// **'Favoritos'**
  String get commonFavoritesTab;

  /// No description provided for @commonFeaturedFeminineTab.
  ///
  /// In es, this message translates to:
  /// **'Destacadas'**
  String get commonFeaturedFeminineTab;

  /// No description provided for @commonAllFeminineTab.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get commonAllFeminineTab;

  /// No description provided for @commonFavoritesFeminineTab.
  ///
  /// In es, this message translates to:
  /// **'Favoritas'**
  String get commonFavoritesFeminineTab;

  /// No description provided for @commonLikesCount.
  ///
  /// In es, this message translates to:
  /// **'{count} me gusta'**
  String commonLikesCount(Object count);

  /// No description provided for @commonLink.
  ///
  /// In es, this message translates to:
  /// **'Enlace'**
  String get commonLink;

  /// No description provided for @commonTipItem.
  ///
  /// In es, this message translates to:
  /// **'consejo'**
  String get commonTipItem;

  /// No description provided for @commonRecipeItem.
  ///
  /// In es, this message translates to:
  /// **'receta'**
  String get commonRecipeItem;

  /// No description provided for @commonAdditiveItem.
  ///
  /// In es, this message translates to:
  /// **'aditivo'**
  String get commonAdditiveItem;

  /// No description provided for @commonSupplementItem.
  ///
  /// In es, this message translates to:
  /// **'suplemento'**
  String get commonSupplementItem;

  /// No description provided for @commonSeeLinkToType.
  ///
  /// In es, this message translates to:
  /// **'Véase enlace a {type}'**
  String commonSeeLinkToType(Object type);

  /// No description provided for @commonDocument.
  ///
  /// In es, this message translates to:
  /// **'Documento'**
  String get commonDocument;

  /// No description provided for @todoPriorityHigh.
  ///
  /// In es, this message translates to:
  /// **'Alta'**
  String get todoPriorityHigh;

  /// No description provided for @todoPriorityMedium.
  ///
  /// In es, this message translates to:
  /// **'Media'**
  String get todoPriorityMedium;

  /// No description provided for @todoPriorityLow.
  ///
  /// In es, this message translates to:
  /// **'Baja'**
  String get todoPriorityLow;

  /// No description provided for @todoStatusPending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get todoStatusPending;

  /// No description provided for @todoStatusResolved.
  ///
  /// In es, this message translates to:
  /// **'Resuelta'**
  String get todoStatusResolved;

  /// No description provided for @todoCalendarPriority.
  ///
  /// In es, this message translates to:
  /// **'Prioridad: {value}'**
  String todoCalendarPriority(Object value);

  /// No description provided for @todoCalendarStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado: {value}'**
  String todoCalendarStatus(Object value);

  /// No description provided for @todoExportError.
  ///
  /// In es, this message translates to:
  /// **'Error al exportar la tarea: {error}'**
  String todoExportError(Object error);

  /// No description provided for @todoDateRequiredForCalendar.
  ///
  /// In es, this message translates to:
  /// **'La tarea debe tener fecha para añadirla al calendario'**
  String get todoDateRequiredForCalendar;

  /// No description provided for @todoAddToCalendarError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo añadir la tarea al calendario: {error}'**
  String todoAddToCalendarError(Object error);

  /// No description provided for @todoPremiumLimitMessage.
  ///
  /// In es, this message translates to:
  /// **'Como usuario no Premium puedes crear hasta {limit} tareas. Hazte Premium para añadir tareas ilimitadas y consultar todo el histórico.'**
  String todoPremiumLimitMessage(int limit);

  /// No description provided for @todoNoDate.
  ///
  /// In es, this message translates to:
  /// **'Sin fecha'**
  String get todoNoDate;

  /// No description provided for @todoPriorityHighTooltip.
  ///
  /// In es, this message translates to:
  /// **'Prioridad alta'**
  String get todoPriorityHighTooltip;

  /// No description provided for @todoPriorityMediumTooltip.
  ///
  /// In es, this message translates to:
  /// **'Prioridad media'**
  String get todoPriorityMediumTooltip;

  /// No description provided for @todoPriorityLowTooltip.
  ///
  /// In es, this message translates to:
  /// **'Prioridad baja'**
  String get todoPriorityLowTooltip;

  /// No description provided for @todoStatusResolvedShort.
  ///
  /// In es, this message translates to:
  /// **'Realizada (R)'**
  String get todoStatusResolvedShort;

  /// No description provided for @todoStatusPendingShort.
  ///
  /// In es, this message translates to:
  /// **'Pendiente (P)'**
  String get todoStatusPendingShort;

  /// No description provided for @todoMarkPending.
  ///
  /// In es, this message translates to:
  /// **'Marcar pendiente'**
  String get todoMarkPending;

  /// No description provided for @todoMarkResolved.
  ///
  /// In es, this message translates to:
  /// **'Marcar resuelta'**
  String get todoMarkResolved;

  /// No description provided for @todoEditTaskTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar tarea'**
  String get todoEditTaskTitle;

  /// No description provided for @todoNewTaskTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva tarea'**
  String get todoNewTaskTitle;

  /// No description provided for @todoTitleLabel.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get todoTitleLabel;

  /// No description provided for @todoTitleRequired.
  ///
  /// In es, this message translates to:
  /// **'El título es obligatorio'**
  String get todoTitleRequired;

  /// No description provided for @todoDescriptionTitle.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get todoDescriptionTitle;

  /// No description provided for @todoDescriptionOptionalLabel.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get todoDescriptionOptionalLabel;

  /// No description provided for @todoPriorityTitle.
  ///
  /// In es, this message translates to:
  /// **'Prioridad'**
  String get todoPriorityTitle;

  /// No description provided for @todoStatusTitle.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get todoStatusTitle;

  /// No description provided for @todoTasksForDay.
  ///
  /// In es, this message translates to:
  /// **'Tareas del {date}'**
  String todoTasksForDay(Object date);

  /// No description provided for @todoNewShort.
  ///
  /// In es, this message translates to:
  /// **'Nueva'**
  String get todoNewShort;

  /// No description provided for @todoNoTasksSelectedDay.
  ///
  /// In es, this message translates to:
  /// **'No hay tareas para el día seleccionado.'**
  String get todoNoTasksSelectedDay;

  /// No description provided for @todoNoTasksToShow.
  ///
  /// In es, this message translates to:
  /// **'No hay tareas para mostrar.'**
  String get todoNoTasksToShow;

  /// No description provided for @todoPremiumTitle.
  ///
  /// In es, this message translates to:
  /// **'Tareas Premium'**
  String get todoPremiumTitle;

  /// No description provided for @todoPremiumPreviewSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Puedes consultar los {limit} últimos registros y crear hasta {limit} tareas. Si quieres tareas ilimitadas hazte Premium.'**
  String todoPremiumPreviewSubtitle(int limit);

  /// No description provided for @todoPremiumPreviewHighlight.
  ///
  /// In es, this message translates to:
  /// **' Actualmente tienes {count} tareas registradas.'**
  String todoPremiumPreviewHighlight(int count);

  /// No description provided for @todoEmptyState.
  ///
  /// In es, this message translates to:
  /// **'Todavía no tienes tareas registradas.'**
  String get todoEmptyState;

  /// No description provided for @todoScreenTitle.
  ///
  /// In es, this message translates to:
  /// **'Tareas'**
  String get todoScreenTitle;

  /// No description provided for @todoTabPending.
  ///
  /// In es, this message translates to:
  /// **'Pendientes'**
  String get todoTabPending;

  /// No description provided for @todoTabResolved.
  ///
  /// In es, this message translates to:
  /// **'Resueltas'**
  String get todoTabResolved;

  /// No description provided for @todoTabAll.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get todoTabAll;

  /// No description provided for @todoHideFilters.
  ///
  /// In es, this message translates to:
  /// **'Ocultar filtros'**
  String get todoHideFilters;

  /// No description provided for @todoViewList.
  ///
  /// In es, this message translates to:
  /// **'Ver lista'**
  String get todoViewList;

  /// No description provided for @todoViewCalendar.
  ///
  /// In es, this message translates to:
  /// **'Ver calendario'**
  String get todoViewCalendar;

  /// No description provided for @todoSortByDate.
  ///
  /// In es, this message translates to:
  /// **'Ordenar Fecha'**
  String get todoSortByDate;

  /// No description provided for @todoSortByPriority.
  ///
  /// In es, this message translates to:
  /// **'Ordenar Prioridad'**
  String get todoSortByPriority;

  /// No description provided for @todoSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar por título o descripción'**
  String get todoSearchHint;

  /// No description provided for @todoClearSearch.
  ///
  /// In es, this message translates to:
  /// **'Limpiar búsqueda'**
  String get todoClearSearch;

  /// No description provided for @todoDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar tarea'**
  String get todoDeleteTitle;

  /// No description provided for @todoDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Deseas eliminar la tarea \"{title}\"?'**
  String todoDeleteConfirm(Object title);

  /// No description provided for @todoDeletedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Tarea eliminada correctamente'**
  String get todoDeletedSuccess;

  /// No description provided for @todoAddToDeviceCalendar.
  ///
  /// In es, this message translates to:
  /// **'Añadir al calendario del dispositivo'**
  String get todoAddToDeviceCalendar;

  /// No description provided for @todoEditAction.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get todoEditAction;

  /// No description provided for @todoSelectDate.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar fecha'**
  String get todoSelectDate;

  /// No description provided for @todoRemoveDate.
  ///
  /// In es, this message translates to:
  /// **'Quitar fecha'**
  String get todoRemoveDate;

  /// No description provided for @todoGuestTitle.
  ///
  /// In es, this message translates to:
  /// **'Registro requerido'**
  String get todoGuestTitle;

  /// No description provided for @todoGuestBody.
  ///
  /// In es, this message translates to:
  /// **'Para poder usar Tareas, debes registrarte (es gratis).'**
  String get todoGuestBody;

  /// No description provided for @commonSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get commonSave;

  /// No description provided for @commonSortByName.
  ///
  /// In es, this message translates to:
  /// **'Ordenar Nombre'**
  String get commonSortByName;

  /// No description provided for @commonSortByType.
  ///
  /// In es, this message translates to:
  /// **'Ordenar Tipo'**
  String get commonSortByType;

  /// No description provided for @commonSortByDate.
  ///
  /// In es, this message translates to:
  /// **'Ordenar Fecha'**
  String get commonSortByDate;

  /// No description provided for @commonSortBySeverity.
  ///
  /// In es, this message translates to:
  /// **'Ordenar Peligrosidad'**
  String get commonSortBySeverity;

  /// No description provided for @commonName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get commonName;

  /// No description provided for @commonTitleField.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get commonTitleField;

  /// No description provided for @commonDescriptionField.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get commonDescriptionField;

  /// No description provided for @commonTypeField.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get commonTypeField;

  /// No description provided for @commonSeverity.
  ///
  /// In es, this message translates to:
  /// **'Peligrosidad'**
  String get commonSeverity;

  /// No description provided for @commonNoResultsForQuery.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados para \"{query}\"'**
  String commonNoResultsForQuery(Object query);

  /// No description provided for @tipsPremiumToolsMessage.
  ///
  /// In es, this message translates to:
  /// **'La búsqueda, filtros, favoritos, me gusta y el acceso completo al catálogo de consejos están disponibles solo para usuarios Premium.'**
  String get tipsPremiumToolsMessage;

  /// No description provided for @tipsPremiumPreviewTitle.
  ///
  /// In es, this message translates to:
  /// **'Consejos Premium'**
  String get tipsPremiumPreviewTitle;

  /// No description provided for @tipsPremiumPreviewSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Puedes ver una vista previa con los 3 últimos consejos. Hazte Premium para acceder al catálogo completo y a todas sus herramientas.'**
  String get tipsPremiumPreviewSubtitle;

  /// No description provided for @tipsPreviewAvailableCount.
  ///
  /// In es, this message translates to:
  /// **' Actualmente hay {count} consejos disponibles.'**
  String tipsPreviewAvailableCount(Object count);

  /// No description provided for @tipsSearchLabel.
  ///
  /// In es, this message translates to:
  /// **'Buscar consejos'**
  String get tipsSearchLabel;

  /// No description provided for @tipsNoPersonalizedRecommendations.
  ///
  /// In es, this message translates to:
  /// **'No tiene recomendaciones personalizadas'**
  String get tipsNoPersonalizedRecommendations;

  /// No description provided for @tipsViewGeneralTips.
  ///
  /// In es, this message translates to:
  /// **'Ver consejos generales'**
  String get tipsViewGeneralTips;

  /// No description provided for @tipsUnreadBadge.
  ///
  /// In es, this message translates to:
  /// **'No leído'**
  String get tipsUnreadBadge;

  /// No description provided for @messagesInboxTitle.
  ///
  /// In es, this message translates to:
  /// **'Mensajes sin leer'**
  String get messagesInboxTitle;

  /// No description provided for @messagesInboxGuestBody.
  ///
  /// In es, this message translates to:
  /// **'Para chatear con tu dietista online, por favor, regístrate (es gratis).'**
  String get messagesInboxGuestBody;

  /// No description provided for @messagesInboxGuestAction.
  ///
  /// In es, this message translates to:
  /// **'Iniciar registro'**
  String get messagesInboxGuestAction;

  /// No description provided for @messagesInboxUnreadChats.
  ///
  /// In es, this message translates to:
  /// **'Chats sin leer'**
  String get messagesInboxUnreadChats;

  /// No description provided for @messagesInboxNoPendingChats.
  ///
  /// In es, this message translates to:
  /// **'No hay chats pendientes.'**
  String get messagesInboxNoPendingChats;

  /// No description provided for @messagesInboxUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get messagesInboxUser;

  /// No description provided for @messagesInboxImage.
  ///
  /// In es, this message translates to:
  /// **'Imagen'**
  String get messagesInboxImage;

  /// No description provided for @messagesInboxNoMessages.
  ///
  /// In es, this message translates to:
  /// **'Sin mensajes'**
  String get messagesInboxNoMessages;

  /// No description provided for @messagesInboxPendingExerciseFeelings.
  ///
  /// In es, this message translates to:
  /// **'Sensaciones de ejercicios pendientes'**
  String get messagesInboxPendingExerciseFeelings;

  /// No description provided for @messagesInboxNoPendingExerciseFeelings.
  ///
  /// In es, this message translates to:
  /// **'No hay sensaciones de ejercicios pendientes.'**
  String get messagesInboxNoPendingExerciseFeelings;

  /// No description provided for @messagesInboxViewPendingExerciseFeelings.
  ///
  /// In es, this message translates to:
  /// **'Ver sensaciones de ejercicios pendientes'**
  String get messagesInboxViewPendingExerciseFeelings;

  /// No description provided for @messagesInboxUnreadDietitianChats.
  ///
  /// In es, this message translates to:
  /// **'Chats con dietista sin leer'**
  String get messagesInboxUnreadDietitianChats;

  /// No description provided for @messagesInboxOpenDietitianChat.
  ///
  /// In es, this message translates to:
  /// **'Abrir chat con dietista'**
  String get messagesInboxOpenDietitianChat;

  /// No description provided for @messagesInboxMessage.
  ///
  /// In es, this message translates to:
  /// **'Mensaje'**
  String get messagesInboxMessage;

  /// No description provided for @messagesInboxDietitianMessage.
  ///
  /// In es, this message translates to:
  /// **'Mensaje de dietista'**
  String get messagesInboxDietitianMessage;

  /// No description provided for @messagesInboxUnreadCoachComments.
  ///
  /// In es, this message translates to:
  /// **'Comentarios de entrenador sin leer'**
  String get messagesInboxUnreadCoachComments;

  /// No description provided for @messagesInboxNoUnreadCoachComments.
  ///
  /// In es, this message translates to:
  /// **'No tienes comentarios de entrenador personal pendientes de leer.'**
  String get messagesInboxNoUnreadCoachComments;

  /// No description provided for @messagesInboxViewPendingComments.
  ///
  /// In es, this message translates to:
  /// **'Ver comentarios pendientes'**
  String get messagesInboxViewPendingComments;

  /// No description provided for @messagesInboxLoadError.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar mensajes: {error}'**
  String messagesInboxLoadError(Object error);

  /// No description provided for @tipsNoFeaturedAvailable.
  ///
  /// In es, this message translates to:
  /// **'No hay consejos destacados'**
  String get tipsNoFeaturedAvailable;

  /// No description provided for @tipsNoTipsAvailable.
  ///
  /// In es, this message translates to:
  /// **'No hay consejos disponibles'**
  String get tipsNoTipsAvailable;

  /// No description provided for @tipsNoFavoriteTips.
  ///
  /// In es, this message translates to:
  /// **'No tienes consejos favoritos'**
  String get tipsNoFavoriteTips;

  /// No description provided for @tipsDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Detalle del Consejo'**
  String get tipsDetailTitle;

  /// No description provided for @tipsPreviewBanner.
  ///
  /// In es, this message translates to:
  /// **'Vista Previa - Así verán el consejo los usuarios'**
  String get tipsPreviewBanner;

  /// No description provided for @tipsHashtagTitle.
  ///
  /// In es, this message translates to:
  /// **'Consejos con {hashtag}'**
  String tipsHashtagTitle(Object hashtag);

  /// No description provided for @tipsHashtagEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay consejos con {hashtag}'**
  String tipsHashtagEmpty(Object hashtag);

  /// No description provided for @tipsLoadErrorStatus.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar consejos: {statusCode}'**
  String tipsLoadErrorStatus(Object statusCode);

  /// No description provided for @tipsLoadError.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar consejos. {error}'**
  String tipsLoadError(Object error);

  /// No description provided for @recipesPremiumToolsMessage.
  ///
  /// In es, this message translates to:
  /// **'La búsqueda, filtros, favoritos, me gusta y el acceso completo al catálogo de recetas están disponibles solo para usuarios Premium.'**
  String get recipesPremiumToolsMessage;

  /// No description provided for @recipesPremiumPreviewTitle.
  ///
  /// In es, this message translates to:
  /// **'Recetas Premium'**
  String get recipesPremiumPreviewTitle;

  /// No description provided for @recipesPremiumPreviewSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Puedes ver una vista previa con las 3 últimas recetas. Hazte Premium para acceder al catálogo completo y a todas sus herramientas.'**
  String get recipesPremiumPreviewSubtitle;

  /// No description provided for @recipesPreviewAvailableCount.
  ///
  /// In es, this message translates to:
  /// **' Actualmente hay {count} recetas disponibles.'**
  String recipesPreviewAvailableCount(Object count);

  /// No description provided for @recipesSearchLabel.
  ///
  /// In es, this message translates to:
  /// **'Buscar recetas'**
  String get recipesSearchLabel;

  /// No description provided for @recipesNoFeaturedAvailable.
  ///
  /// In es, this message translates to:
  /// **'No hay recetas destacadas'**
  String get recipesNoFeaturedAvailable;

  /// No description provided for @recipesNoRecipesAvailable.
  ///
  /// In es, this message translates to:
  /// **'No hay recetas disponibles'**
  String get recipesNoRecipesAvailable;

  /// No description provided for @recipesNoFavoriteRecipes.
  ///
  /// In es, this message translates to:
  /// **'No tienes recetas favoritas'**
  String get recipesNoFavoriteRecipes;

  /// No description provided for @recipesDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Detalle de la Receta'**
  String get recipesDetailTitle;

  /// No description provided for @recipesPreviewBanner.
  ///
  /// In es, this message translates to:
  /// **'Vista Previa - Así verán la receta los usuarios'**
  String get recipesPreviewBanner;

  /// No description provided for @recipesHashtagTitle.
  ///
  /// In es, this message translates to:
  /// **'Recetas con {hashtag}'**
  String recipesHashtagTitle(Object hashtag);

  /// No description provided for @recipesHashtagEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay recetas con {hashtag}'**
  String recipesHashtagEmpty(Object hashtag);

  /// No description provided for @additivesPremiumCopyPdfMessage.
  ///
  /// In es, this message translates to:
  /// **'Para poder copiar y pasar a PDF un aditivo, debes ser usuario Premium.'**
  String get additivesPremiumCopyPdfMessage;

  /// No description provided for @additivesPremiumExploreMessage.
  ///
  /// In es, this message translates to:
  /// **'Los hashtags y las recomendaciones de aditivos están disponibles solo para usuarios Premium.'**
  String get additivesPremiumExploreMessage;

  /// No description provided for @additivesPremiumToolsMessage.
  ///
  /// In es, this message translates to:
  /// **'La búsqueda, filtros, actualización y ordenación completa del catálogo de aditivos están disponibles solo para usuarios Premium.'**
  String get additivesPremiumToolsMessage;

  /// No description provided for @additivesFilterTitle.
  ///
  /// In es, this message translates to:
  /// **'Filtrar aditivos'**
  String get additivesFilterTitle;

  /// No description provided for @additivesNoConfiguredTypes.
  ///
  /// In es, this message translates to:
  /// **'No hay tipos configurados en tipos_aditivos.'**
  String get additivesNoConfiguredTypes;

  /// No description provided for @additivesTypesLabel.
  ///
  /// In es, this message translates to:
  /// **'Tipos'**
  String get additivesTypesLabel;

  /// No description provided for @additivesSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar aditivos'**
  String get additivesSearchHint;

  /// No description provided for @additivesEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay aditivos disponibles'**
  String get additivesEmpty;

  /// No description provided for @additivesPremiumTitle.
  ///
  /// In es, this message translates to:
  /// **'Aditivos Premium'**
  String get additivesPremiumTitle;

  /// No description provided for @additivesPremiumSubtitle.
  ///
  /// In es, this message translates to:
  /// **'El catálogo completo de aditivos está disponible solo para usuarios Premium.'**
  String get additivesPremiumSubtitle;

  /// No description provided for @additivesCatalogHighlight.
  ///
  /// In es, this message translates to:
  /// **' (con más de {count} aditivos)'**
  String additivesCatalogHighlight(Object count);

  /// No description provided for @additivesLoadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los aditivos.'**
  String get additivesLoadFailed;

  /// No description provided for @additivesCatalogUnavailable.
  ///
  /// In es, this message translates to:
  /// **'El catálogo de aditivos no está disponible temporalmente. Inténtalo más tarde.'**
  String get additivesCatalogUnavailable;

  /// No description provided for @additivesServerConnectionError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.'**
  String get additivesServerConnectionError;

  /// No description provided for @additivesSeveritySafe.
  ///
  /// In es, this message translates to:
  /// **'Seguro'**
  String get additivesSeveritySafe;

  /// No description provided for @additivesSeverityAttention.
  ///
  /// In es, this message translates to:
  /// **'Atención'**
  String get additivesSeverityAttention;

  /// No description provided for @additivesSeverityHigh.
  ///
  /// In es, this message translates to:
  /// **'Alto'**
  String get additivesSeverityHigh;

  /// No description provided for @additivesSeverityRestricted.
  ///
  /// In es, this message translates to:
  /// **'Restringido'**
  String get additivesSeverityRestricted;

  /// No description provided for @additivesSeverityForbidden.
  ///
  /// In es, this message translates to:
  /// **'Prohibido'**
  String get additivesSeverityForbidden;

  /// No description provided for @substitutionsPremiumToolsMessage.
  ///
  /// In es, this message translates to:
  /// **'La búsqueda, filtros, favoritos y ordenación completa de sustituciones saludables están disponibles solo para usuarios Premium.'**
  String get substitutionsPremiumToolsMessage;

  /// No description provided for @substitutionsPremiumCopyPdfMessage.
  ///
  /// In es, this message translates to:
  /// **'Para poder copiar y pasar a PDF una sustitución saludable, debes ser usuario Premium.'**
  String get substitutionsPremiumCopyPdfMessage;

  /// No description provided for @substitutionsPremiumExploreMessage.
  ///
  /// In es, this message translates to:
  /// **'Los hashtags, categorías, recomendaciones y navegación avanzada de sustituciones saludables están disponibles solo para usuarios Premium.'**
  String get substitutionsPremiumExploreMessage;

  /// No description provided for @substitutionsPremiumEngagementMessage.
  ///
  /// In es, this message translates to:
  /// **'Los favoritos y los me gusta de sustituciones saludables están disponibles solo para usuarios Premium.'**
  String get substitutionsPremiumEngagementMessage;

  /// No description provided for @substitutionsSearchLabel.
  ///
  /// In es, this message translates to:
  /// **'Buscar sustituciones o hashtags'**
  String get substitutionsSearchLabel;

  /// No description provided for @substitutionsEmptyFeatured.
  ///
  /// In es, this message translates to:
  /// **'No hay sustituciones destacadas.'**
  String get substitutionsEmptyFeatured;

  /// No description provided for @substitutionsEmptyAll.
  ///
  /// In es, this message translates to:
  /// **'No hay sustituciones disponibles.'**
  String get substitutionsEmptyAll;

  /// No description provided for @substitutionsEmptyFavorites.
  ///
  /// In es, this message translates to:
  /// **'No tienes sustituciones favoritas todavía.'**
  String get substitutionsEmptyFavorites;

  /// No description provided for @substitutionsPremiumTitle.
  ///
  /// In es, this message translates to:
  /// **'Sustituciones Premium'**
  String get substitutionsPremiumTitle;

  /// No description provided for @substitutionsPremiumSubtitle.
  ///
  /// In es, this message translates to:
  /// **'La biblioteca completa de sustituciones saludables está disponible solo para usuarios Premium.'**
  String get substitutionsPremiumSubtitle;

  /// No description provided for @substitutionsCatalogHighlight.
  ///
  /// In es, this message translates to:
  /// **' (con más de {count} sustituciones)'**
  String substitutionsCatalogHighlight(Object count);

  /// No description provided for @substitutionsDefaultBadge.
  ///
  /// In es, this message translates to:
  /// **'Sustitución premium'**
  String get substitutionsDefaultBadge;

  /// No description provided for @substitutionsTapForDetail.
  ///
  /// In es, this message translates to:
  /// **'Toca para ver el detalle completo'**
  String get substitutionsTapForDetail;

  /// No description provided for @substitutionsDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Sustitución saludable'**
  String get substitutionsDetailTitle;

  /// No description provided for @substitutionsRecommendedChange.
  ///
  /// In es, this message translates to:
  /// **'Cambio recomendado'**
  String get substitutionsRecommendedChange;

  /// No description provided for @substitutionsIfUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Si no tienes'**
  String get substitutionsIfUnavailable;

  /// No description provided for @substitutionsUse.
  ///
  /// In es, this message translates to:
  /// **'Usa'**
  String get substitutionsUse;

  /// No description provided for @substitutionsEquivalence.
  ///
  /// In es, this message translates to:
  /// **'Equivalencia'**
  String get substitutionsEquivalence;

  /// No description provided for @substitutionsGoal.
  ///
  /// In es, this message translates to:
  /// **'Objetivo'**
  String get substitutionsGoal;

  /// No description provided for @substitutionsNotesContext.
  ///
  /// In es, this message translates to:
  /// **'Sustitución saludable'**
  String get substitutionsNotesContext;

  /// No description provided for @commonExport.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get commonExport;

  /// No description provided for @commonImport.
  ///
  /// In es, this message translates to:
  /// **'Importar'**
  String get commonImport;

  /// No description provided for @commonPhoto.
  ///
  /// In es, this message translates to:
  /// **'Foto'**
  String get commonPhoto;

  /// No description provided for @commonGallery.
  ///
  /// In es, this message translates to:
  /// **'Galería'**
  String get commonGallery;

  /// No description provided for @commonUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No disponible'**
  String get commonUnavailable;

  /// No description provided for @scannerTitle.
  ///
  /// In es, this message translates to:
  /// **'Escáner de etiquetas'**
  String get scannerTitle;

  /// No description provided for @scannerPremiumRequiredMessage.
  ///
  /// In es, this message translates to:
  /// **'Escanear, abrir imágenes de la galería y buscar productos desde el escáner está disponible solo para usuarios Premium.'**
  String get scannerPremiumRequiredMessage;

  /// No description provided for @scannerClearTrainingTitle.
  ///
  /// In es, this message translates to:
  /// **'Limpiar entrenamiento OCR'**
  String get scannerClearTrainingTitle;

  /// No description provided for @scannerClearTrainingBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminarán todas las correcciones guardadas en este dispositivo. ¿Deseas continuar?'**
  String get scannerClearTrainingBody;

  /// No description provided for @scannerLocalTrainingRemoved.
  ///
  /// In es, this message translates to:
  /// **'Entrenamiento OCR local eliminado'**
  String get scannerLocalTrainingRemoved;

  /// No description provided for @scannerExportRulesTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar reglas OCR'**
  String get scannerExportRulesTitle;

  /// No description provided for @scannerImportRulesTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar reglas OCR'**
  String get scannerImportRulesTitle;

  /// No description provided for @scannerImportRulesHint.
  ///
  /// In es, this message translates to:
  /// **'Pega aquí el JSON exportado'**
  String get scannerImportRulesHint;

  /// No description provided for @scannerInvalidFormat.
  ///
  /// In es, this message translates to:
  /// **'Formato inválido'**
  String get scannerInvalidFormat;

  /// No description provided for @scannerInvalidJsonOrCanceled.
  ///
  /// In es, this message translates to:
  /// **'JSON inválido o importación cancelada'**
  String get scannerInvalidJsonOrCanceled;

  /// No description provided for @scannerImportedRulesCount.
  ///
  /// In es, this message translates to:
  /// **'Importadas {count} reglas de entrenamiento'**
  String scannerImportedRulesCount(Object count);

  /// No description provided for @scannerRulesUploaded.
  ///
  /// In es, this message translates to:
  /// **'Reglas OCR subidas al servidor'**
  String get scannerRulesUploaded;

  /// No description provided for @scannerRulesUploadError.
  ///
  /// In es, this message translates to:
  /// **'Error al subir reglas: {error}'**
  String scannerRulesUploadError(Object error);

  /// No description provided for @scannerNoRemoteRules.
  ///
  /// In es, this message translates to:
  /// **'No hay reglas remotas disponibles.'**
  String get scannerNoRemoteRules;

  /// No description provided for @scannerDownloadedRulesCount.
  ///
  /// In es, this message translates to:
  /// **'Descargadas {count} reglas desde servidor'**
  String scannerDownloadedRulesCount(Object count);

  /// No description provided for @scannerRulesDownloadError.
  ///
  /// In es, this message translates to:
  /// **'Error al descargar reglas: {error}'**
  String scannerRulesDownloadError(Object error);

  /// No description provided for @scannerTrainingMarkedCorrect.
  ///
  /// In es, this message translates to:
  /// **'Entrenamiento guardado: lectura marcada como correcta'**
  String get scannerTrainingMarkedCorrect;

  /// No description provided for @scannerCorrectOcrValuesTitle.
  ///
  /// In es, this message translates to:
  /// **'Corregir valores OCR'**
  String get scannerCorrectOcrValuesTitle;

  /// No description provided for @scannerSugarField.
  ///
  /// In es, this message translates to:
  /// **'Azúcar (g)'**
  String get scannerSugarField;

  /// No description provided for @scannerSaltField.
  ///
  /// In es, this message translates to:
  /// **'Sal (g)'**
  String get scannerSaltField;

  /// No description provided for @scannerFatField.
  ///
  /// In es, this message translates to:
  /// **'Grasas (g)'**
  String get scannerFatField;

  /// No description provided for @scannerProteinField.
  ///
  /// In es, this message translates to:
  /// **'Proteína (g)'**
  String get scannerProteinField;

  /// No description provided for @scannerPortionField.
  ///
  /// In es, this message translates to:
  /// **'Porción (g)'**
  String get scannerPortionField;

  /// No description provided for @scannerSaveCorrection.
  ///
  /// In es, this message translates to:
  /// **'Guardar corrección'**
  String get scannerSaveCorrection;

  /// No description provided for @scannerCorrectionSaved.
  ///
  /// In es, this message translates to:
  /// **'Corrección guardada. Se aplicará a etiquetas similares.'**
  String get scannerCorrectionSaved;

  /// No description provided for @scannerSourceBarcode.
  ///
  /// In es, this message translates to:
  /// **'Código de barras'**
  String get scannerSourceBarcode;

  /// No description provided for @scannerSourceOcrOpenFood.
  ///
  /// In es, this message translates to:
  /// **'OCR de nombre + Open Food Facts'**
  String get scannerSourceOcrOpenFood;

  /// No description provided for @scannerSourceOcrTable.
  ///
  /// In es, this message translates to:
  /// **'OCR de tabla nutricional'**
  String get scannerSourceOcrTable;

  /// No description provided for @scannerSourceAutoBarcodeOpenFood.
  ///
  /// In es, this message translates to:
  /// **'Detección automática (código de barras + Open Food Facts)'**
  String get scannerSourceAutoBarcodeOpenFood;

  /// No description provided for @scannerSourceAutoOcrOpenFood.
  ///
  /// In es, this message translates to:
  /// **'Detección automática (OCR + Open Food Facts)'**
  String get scannerSourceAutoOcrOpenFood;

  /// No description provided for @scannerSourceAutoOcrTable.
  ///
  /// In es, this message translates to:
  /// **'Detección automática (OCR de tabla nutricional)'**
  String get scannerSourceAutoOcrTable;

  /// No description provided for @scannerNoNutritionData.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron obtener los datos nutricionales. Haz la foto con buena luminosidad, texto nítido y enfocado, y encuadrando la tabla de información nutricional.'**
  String get scannerNoNutritionData;

  /// No description provided for @scannerReadCompleted.
  ///
  /// In es, this message translates to:
  /// **'Lectura completada: {source}'**
  String scannerReadCompleted(Object source);

  /// No description provided for @scannerAnalyzeError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo analizar la etiqueta: {error}'**
  String scannerAnalyzeError(Object error);

  /// No description provided for @scannerHeaderTitle.
  ///
  /// In es, this message translates to:
  /// **'Escáner de etiquetas de alimentos'**
  String get scannerHeaderTitle;

  /// No description provided for @scannerHeaderTooltip.
  ///
  /// In es, this message translates to:
  /// **'Información completa del proceso'**
  String get scannerHeaderTooltip;

  /// No description provided for @scannerHeaderBody.
  ///
  /// In es, this message translates to:
  /// **'Haz una foto del código de barras de un producto (alimento) o bien selecciona una imagen de la galería. La app NutriFit detectará automáticamente, si se activa este modo, el código de barras, nombre de producto o tabla nutricional.'**
  String get scannerHeaderBody;

  /// No description provided for @scannerPremiumBanner.
  ///
  /// In es, this message translates to:
  /// **'Función Premium: puedes entrar en la pantalla y ver la información, pero Buscar, Foto y Galería están bloqueados para usuarios no Premium.'**
  String get scannerPremiumBanner;

  /// No description provided for @scannerTrainingModeTitle.
  ///
  /// In es, this message translates to:
  /// **'Modo entrenamiento OCR'**
  String get scannerTrainingModeTitle;

  /// No description provided for @scannerTrainingModeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Permite corregir lecturas para mejorar detecciones.'**
  String get scannerTrainingModeSubtitle;

  /// No description provided for @scannerModeLabel.
  ///
  /// In es, this message translates to:
  /// **'Modo'**
  String get scannerModeLabel;

  /// No description provided for @scannerModeAuto.
  ///
  /// In es, this message translates to:
  /// **'Modo automático'**
  String get scannerModeAuto;

  /// No description provided for @scannerModeBarcode.
  ///
  /// In es, this message translates to:
  /// **'Modo código de barras'**
  String get scannerModeBarcode;

  /// No description provided for @scannerModeOcrTable.
  ///
  /// In es, this message translates to:
  /// **'Modo tabla nutricional'**
  String get scannerModeOcrTable;

  /// No description provided for @scannerActionSearchOpenFood.
  ///
  /// In es, this message translates to:
  /// **'Buscar en Open Food Facts'**
  String get scannerActionSearchOpenFood;

  /// No description provided for @scannerAutoHint.
  ///
  /// In es, this message translates to:
  /// **'En modo automático, la app intenta detectar primero el código de barras y, si no encuentra un producto válido, prueba con OCR sobre el nombre o la tabla nutricional.'**
  String get scannerAutoHint;

  /// No description provided for @scannerBarcodeHint.
  ///
  /// In es, this message translates to:
  /// **'En modo código de barras, la cámara muestra un recuadro guía y la app analiza sólo esa zona para mejorar la precisión.'**
  String get scannerBarcodeHint;

  /// No description provided for @scannerOcrHint.
  ///
  /// In es, this message translates to:
  /// **'En modo tabla nutricional, la app prioriza la lectura OCR del nombre y de la tabla nutricional, sin depender del código de barras.'**
  String get scannerOcrHint;

  /// No description provided for @scannerDismissHintTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cerrar (mant. pulsado el botón de modo para volver a mostrarlo)'**
  String get scannerDismissHintTooltip;

  /// No description provided for @scannerAnalyzing.
  ///
  /// In es, this message translates to:
  /// **'Analizando etiqueta...'**
  String get scannerAnalyzing;

  /// No description provided for @scannerResultPerServing.
  ///
  /// In es, this message translates to:
  /// **'Resultado por porción'**
  String get scannerResultPerServing;

  /// No description provided for @scannerThresholdInfo.
  ///
  /// In es, this message translates to:
  /// **'Info de umbrales'**
  String get scannerThresholdInfo;

  /// No description provided for @scannerMiniTrainingTitle.
  ///
  /// In es, this message translates to:
  /// **'Mini-entrenamiento OCR'**
  String get scannerMiniTrainingTitle;

  /// No description provided for @scannerMiniTrainingApplied.
  ///
  /// In es, this message translates to:
  /// **'Se aplicó aprendizaje previo para esta etiqueta o una similar.'**
  String get scannerMiniTrainingApplied;

  /// No description provided for @scannerMiniTrainingPrompt.
  ///
  /// In es, this message translates to:
  /// **'Valida o corrige esta lectura para entrenar el reconocimiento.'**
  String get scannerMiniTrainingPrompt;

  /// No description provided for @scannerTrainingCorrect.
  ///
  /// In es, this message translates to:
  /// **'Es correcto'**
  String get scannerTrainingCorrect;

  /// No description provided for @scannerTrainingCorrectAction.
  ///
  /// In es, this message translates to:
  /// **'Corregir'**
  String get scannerTrainingCorrectAction;

  /// No description provided for @scannerDownloadServerRules.
  ///
  /// In es, this message translates to:
  /// **'Bajar reglas servidor'**
  String get scannerDownloadServerRules;

  /// No description provided for @scannerUploadServerRules.
  ///
  /// In es, this message translates to:
  /// **'Subir reglas servidor'**
  String get scannerUploadServerRules;

  /// No description provided for @scannerClearLocalRules.
  ///
  /// In es, this message translates to:
  /// **'Limpiar local'**
  String get scannerClearLocalRules;

  /// No description provided for @scannerZoomLabel.
  ///
  /// In es, this message translates to:
  /// **'Ampliar'**
  String get scannerZoomLabel;

  /// No description provided for @scannerDetectedTextTitle.
  ///
  /// In es, this message translates to:
  /// **'Texto detectado (OCR)'**
  String get scannerDetectedTextTitle;

  /// No description provided for @scannerManualSearchTitle.
  ///
  /// In es, this message translates to:
  /// **'Buscar en Open Food Facts'**
  String get scannerManualSearchTitle;

  /// No description provided for @scannerManualSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Nombre del producto'**
  String get scannerManualSearchHint;

  /// No description provided for @scannerNoValidProductByName.
  ///
  /// In es, this message translates to:
  /// **'No se encontró un producto válido con ese nombre.'**
  String get scannerNoValidProductByName;

  /// No description provided for @scannerManualSearchSource.
  ///
  /// In es, this message translates to:
  /// **'Búsqueda manual por nombre (Open Food Facts)'**
  String get scannerManualSearchSource;

  /// No description provided for @scannerProductFound.
  ///
  /// In es, this message translates to:
  /// **'Producto encontrado en Open Food Facts'**
  String get scannerProductFound;

  /// No description provided for @scannerProductSearchError.
  ///
  /// In es, this message translates to:
  /// **'Error al buscar producto: {error}'**
  String scannerProductSearchError(Object error);

  /// No description provided for @scannerProductName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del producto'**
  String get scannerProductName;

  /// No description provided for @scannerBrand.
  ///
  /// In es, this message translates to:
  /// **'Marca'**
  String get scannerBrand;

  /// No description provided for @scannerFormat.
  ///
  /// In es, this message translates to:
  /// **'Formato'**
  String get scannerFormat;

  /// No description provided for @scannerBarcodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código de barras'**
  String get scannerBarcodeLabel;

  /// No description provided for @scannerActions.
  ///
  /// In es, this message translates to:
  /// **'Acciones'**
  String get scannerActions;

  /// No description provided for @scannerAddToShoppingList.
  ///
  /// In es, this message translates to:
  /// **'Añadir a compra'**
  String get scannerAddToShoppingList;

  /// No description provided for @scannerNutriScoreNova.
  ///
  /// In es, this message translates to:
  /// **'Nutri score   Nova'**
  String get scannerNutriScoreNova;

  /// No description provided for @scannerNutriScoreMeaning.
  ///
  /// In es, this message translates to:
  /// **'¿Qué significa Nutri-Score?'**
  String get scannerNutriScoreMeaning;

  /// No description provided for @scannerNovaMeaning.
  ///
  /// In es, this message translates to:
  /// **'¿Qué significa NOVA?'**
  String get scannerNovaMeaning;

  /// No description provided for @scannerIngredients.
  ///
  /// In es, this message translates to:
  /// **'Ingredientes'**
  String get scannerIngredients;

  /// No description provided for @scannerNutritionData.
  ///
  /// In es, this message translates to:
  /// **'Datos nutricionales'**
  String get scannerNutritionData;

  /// No description provided for @scannerEnergyValue.
  ///
  /// In es, this message translates to:
  /// **'Energía: {value}'**
  String scannerEnergyValue(Object value);

  /// No description provided for @scannerCarbohydratesValue.
  ///
  /// In es, this message translates to:
  /// **'Carbohidratos: {value}'**
  String scannerCarbohydratesValue(Object value);

  /// No description provided for @scannerFiberValue.
  ///
  /// In es, this message translates to:
  /// **'Fibra: {value}'**
  String scannerFiberValue(Object value);

  /// No description provided for @scannerSaturatedFatValue.
  ///
  /// In es, this message translates to:
  /// **'Grasas saturadas: {value}'**
  String scannerSaturatedFatValue(Object value);

  /// No description provided for @scannerSodiumValue.
  ///
  /// In es, this message translates to:
  /// **'Sodio: {value}'**
  String scannerSodiumValue(Object value);

  /// No description provided for @scannerImageTitle.
  ///
  /// In es, this message translates to:
  /// **'Etiqueta nutricional'**
  String get scannerImageTitle;

  /// No description provided for @scannerOpenImageError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la imagen: {error}'**
  String scannerOpenImageError(Object error);

  /// No description provided for @scannerInfoTitle.
  ///
  /// In es, this message translates to:
  /// **'Información'**
  String get scannerInfoTitle;

  /// No description provided for @scannerContactDietitianButton.
  ///
  /// In es, this message translates to:
  /// **'Contactar con dietista'**
  String get scannerContactDietitianButton;

  /// No description provided for @scannerAllergensAndTraces.
  ///
  /// In es, this message translates to:
  /// **'Alérgenos y trazas'**
  String get scannerAllergensAndTraces;

  /// No description provided for @scannerAllergensValue.
  ///
  /// In es, this message translates to:
  /// **'Alérgenos: {value}'**
  String scannerAllergensValue(Object value);

  /// No description provided for @scannerTracesValue.
  ///
  /// In es, this message translates to:
  /// **'Trazas: {value}'**
  String scannerTracesValue(Object value);

  /// No description provided for @scannerFeaturedLabels.
  ///
  /// In es, this message translates to:
  /// **'Etiquetas destacadas'**
  String get scannerFeaturedLabels;

  /// No description provided for @scannerCopiedData.
  ///
  /// In es, this message translates to:
  /// **'Datos copiados al portapapeles'**
  String get scannerCopiedData;

  /// No description provided for @scannerRegisterForShoppingList.
  ///
  /// In es, this message translates to:
  /// **'Regístrate para añadir productos a la lista de compra'**
  String get scannerRegisterForShoppingList;

  /// No description provided for @scannerUnknownUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario no identificado'**
  String get scannerUnknownUser;

  /// No description provided for @scannerExistingFoodUpdated.
  ///
  /// In es, this message translates to:
  /// **'El alimento ya existe, se ha actualizado'**
  String get scannerExistingFoodUpdated;

  /// No description provided for @scannerProductAddedToShoppingList.
  ///
  /// In es, this message translates to:
  /// **'Producto añadido a la lista de compra'**
  String get scannerProductAddedToShoppingList;

  /// No description provided for @scannerAddToShoppingListError.
  ///
  /// In es, this message translates to:
  /// **'Error al añadir a la lista: {error}'**
  String scannerAddToShoppingListError(Object error);

  /// No description provided for @scannerThresholdInfoIntro.
  ///
  /// In es, this message translates to:
  /// **'La tabla de \"Resultado por porción\" te ayuda a comprobar si un valor está cerca (OK) o lejos (Precaución/Alto) del rango recomendado orientativo.'**
  String get scannerThresholdInfoIntro;

  /// No description provided for @scannerThresholdComponent.
  ///
  /// In es, this message translates to:
  /// **'Componente'**
  String get scannerThresholdComponent;

  /// No description provided for @scannerThresholdOk.
  ///
  /// In es, this message translates to:
  /// **'OK'**
  String get scannerThresholdOk;

  /// No description provided for @scannerThresholdCaution.
  ///
  /// In es, this message translates to:
  /// **'Precaución'**
  String get scannerThresholdCaution;

  /// No description provided for @scannerThresholdHighLow.
  ///
  /// In es, this message translates to:
  /// **'Alto / Bajo'**
  String get scannerThresholdHighLow;

  /// No description provided for @scannerThresholdSugar.
  ///
  /// In es, this message translates to:
  /// **'Azúcar'**
  String get scannerThresholdSugar;

  /// No description provided for @scannerThresholdSalt.
  ///
  /// In es, this message translates to:
  /// **'Sal'**
  String get scannerThresholdSalt;

  /// No description provided for @scannerThresholdFat.
  ///
  /// In es, this message translates to:
  /// **'Grasas'**
  String get scannerThresholdFat;

  /// No description provided for @scannerThresholdProtein.
  ///
  /// In es, this message translates to:
  /// **'Proteína'**
  String get scannerThresholdProtein;

  /// No description provided for @scannerThresholdDisclaimer.
  ///
  /// In es, this message translates to:
  /// **'Las sugerencias y valores mostrados son siempre orientativos: no sustituyen la recomendación de un profesional dietético. Además, la cantidad de porciones que consumes afecta directamente a la cantidad total de cada nutriente que ingieres.'**
  String get scannerThresholdDisclaimer;

  /// No description provided for @scannerOcrAccuracyTitle.
  ///
  /// In es, this message translates to:
  /// **'Precisión de lectura (OCR)'**
  String get scannerOcrAccuracyTitle;

  /// No description provided for @scannerOcrAccuracyBody.
  ///
  /// In es, this message translates to:
  /// **'La exactitud del producto (alimento) detectado depende directamente de la calidad de la imagen. Si la foto es borrosa, con reflejos o sin enfocar el código de barras o la tabla nutricional, los valores pueden mostrarse incorrectos. Revisa siempre el nombre del producto para asegurarte de que coincide.'**
  String get scannerOcrAccuracyBody;

  /// No description provided for @scannerOcrTip1.
  ///
  /// In es, this message translates to:
  /// **'• Enfoca solo el código de barras.'**
  String get scannerOcrTip1;

  /// No description provided for @scannerOcrTip2.
  ///
  /// In es, this message translates to:
  /// **'• Si no tiene código de barras, enfoca únicamente la tabla de información nutricional.'**
  String get scannerOcrTip2;

  /// No description provided for @scannerOcrTip3.
  ///
  /// In es, this message translates to:
  /// **'• Si fotografías el código de barras, que se vea completo y nítido.'**
  String get scannerOcrTip3;

  /// No description provided for @scannerOcrTip4.
  ///
  /// In es, this message translates to:
  /// **'• Evita sombras, reflejos y baja iluminación.'**
  String get scannerOcrTip4;

  /// No description provided for @scannerOcrTip5.
  ///
  /// In es, this message translates to:
  /// **'• Mantén el móvil estable y el texto lo más recto posible.'**
  String get scannerOcrTip5;

  /// No description provided for @scannerOcrTip6.
  ///
  /// In es, this message translates to:
  /// **'• Comprueba que números y unidades (g/ml) se lean nítidos.'**
  String get scannerOcrTip6;

  /// No description provided for @scannerOcrTip7.
  ///
  /// In es, this message translates to:
  /// **'• Evita fotografiar etiquetas arrugadas o dañadas.'**
  String get scannerOcrTip7;

  /// No description provided for @scannerNutriScoreDescription.
  ///
  /// In es, this message translates to:
  /// **'Nutri-Score es un sistema público de etiquetado frontal usado en Europa para resumir la calidad nutricional global del producto.'**
  String get scannerNutriScoreDescription;

  /// No description provided for @scannerNutriScoreA.
  ///
  /// In es, this message translates to:
  /// **'Más favorable nutricionalmente'**
  String get scannerNutriScoreA;

  /// No description provided for @scannerNutriScoreB.
  ///
  /// In es, this message translates to:
  /// **'Favorable'**
  String get scannerNutriScoreB;

  /// No description provided for @scannerNutriScoreC.
  ///
  /// In es, this message translates to:
  /// **'Intermedio'**
  String get scannerNutriScoreC;

  /// No description provided for @scannerNutriScoreD.
  ///
  /// In es, this message translates to:
  /// **'Menos favorable'**
  String get scannerNutriScoreD;

  /// No description provided for @scannerNutriScoreE.
  ///
  /// In es, this message translates to:
  /// **'Menos saludable en conjunto'**
  String get scannerNutriScoreE;

  /// No description provided for @scannerNovaDescription.
  ///
  /// In es, this message translates to:
  /// **'NOVA clasifica alimentos por grado de procesamiento (sistema académico de salud pública).'**
  String get scannerNovaDescription;

  /// No description provided for @scannerNova1.
  ///
  /// In es, this message translates to:
  /// **'Sin procesar o mínimamente procesado'**
  String get scannerNova1;

  /// No description provided for @scannerNova2.
  ///
  /// In es, this message translates to:
  /// **'Ingredientes culinarios procesados'**
  String get scannerNova2;

  /// No description provided for @scannerNova3.
  ///
  /// In es, this message translates to:
  /// **'Alimentos procesados'**
  String get scannerNova3;

  /// No description provided for @scannerNova4.
  ///
  /// In es, this message translates to:
  /// **'Ultraprocesados'**
  String get scannerNova4;

  /// No description provided for @scannerGuestAccuracyPromptStart.
  ///
  /// In es, this message translates to:
  /// **'Si quieres información más exacta '**
  String get scannerGuestAccuracyPromptStart;

  /// No description provided for @scannerGuestAccuracyPromptLink.
  ///
  /// In es, this message translates to:
  /// **'regístrate (es gratis)'**
  String get scannerGuestAccuracyPromptLink;

  /// No description provided for @scannerGuestAccuracyPromptEnd.
  ///
  /// In es, this message translates to:
  /// **' e indica tu edad y altura.'**
  String get scannerGuestAccuracyPromptEnd;

  /// No description provided for @scannerCaptureTipsTitle.
  ///
  /// In es, this message translates to:
  /// **'Consejos para hacer foto...'**
  String get scannerCaptureTipsTitle;

  /// No description provided for @scannerCaptureTipsIntro.
  ///
  /// In es, this message translates to:
  /// **'Para obtener valores correctos, la imagen debe enfocarse bien sobre el código de barras o sobre la tabla de información nutricional.'**
  String get scannerCaptureTipsIntro;

  /// No description provided for @scannerCaptureTipsBody.
  ///
  /// In es, this message translates to:
  /// **'• Si escaneas el código de barras, céntralo en el recuadro.\n• Si escaneas la tabla nutricional, asegúrate de que toda la tabla esté visible.\n• Evita fotos movidas, borrosas o con reflejos.\n• Usa buena luz y acércate lo suficiente para leer números.\n• Si el resultado no cuadra, repite la foto desde otro ángulo.'**
  String get scannerCaptureTipsBody;

  /// No description provided for @scannerImportantNotice.
  ///
  /// In es, this message translates to:
  /// **'Aviso importante'**
  String get scannerImportantNotice;

  /// No description provided for @scannerOrientativeNotice.
  ///
  /// In es, this message translates to:
  /// **'Estos cálculos e información son orientativos y dependen, además, de la calidad de la foto/imagen y de si el producto existe en la base de datos Open Food Facts. Para una valoración personalizada, consulta siempre tu dietista online.'**
  String get scannerOrientativeNotice;

  /// No description provided for @scannerNutrientColumn.
  ///
  /// In es, this message translates to:
  /// **'Nutriente'**
  String get scannerNutrientColumn;

  /// No description provided for @scannerServingColumn.
  ///
  /// In es, this message translates to:
  /// **'Porción ({portion})'**
  String scannerServingColumn(Object portion);

  /// No description provided for @scannerStatus100gColumn.
  ///
  /// In es, this message translates to:
  /// **'Estado (100 g)'**
  String get scannerStatus100gColumn;

  /// No description provided for @scannerCameraInitError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar la cámara: {error}'**
  String scannerCameraInitError(Object error);

  /// No description provided for @scannerTakePhotoError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo tomar la foto: {error}'**
  String scannerTakePhotoError(Object error);

  /// No description provided for @scannerFrameHint.
  ///
  /// In es, this message translates to:
  /// **'Centra la etiqueta/código de barras dentro del recuadro'**
  String get scannerFrameHint;

  /// No description provided for @activitiesCatalogTitle.
  ///
  /// In es, this message translates to:
  /// **'Catálogo de actividades'**
  String get activitiesCatalogTitle;

  /// No description provided for @commonEmail.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get commonEmail;

  /// No description provided for @restrictedAccessGenericMessage.
  ///
  /// In es, this message translates to:
  /// **'Para acceder a tus planes nutricionales, planes de entrenamiento y recomendaciones personalizadas, primero necesitas contactar con tu dietista/entrenador online, que te asignará un plan específico, ajustado a tus necesidades.'**
  String get restrictedAccessGenericMessage;

  /// No description provided for @restrictedAccessContactMethods.
  ///
  /// In es, this message translates to:
  /// **'Formas de contacto:'**
  String get restrictedAccessContactMethods;

  /// No description provided for @restrictedAccessMoreContactOptions.
  ///
  /// In es, this message translates to:
  /// **'Más formas de contacto'**
  String get restrictedAccessMoreContactOptions;

  /// No description provided for @videosPremiumToolsMessage.
  ///
  /// In es, this message translates to:
  /// **'La búsqueda, filtros, favoritos, likes y ordenación completa de los vídeos de ejercicios están disponibles solo para usuarios Premium.'**
  String get videosPremiumToolsMessage;

  /// No description provided for @videosPremiumPlaybackMessage.
  ///
  /// In es, this message translates to:
  /// **'La reproducción completa de los vídeos de ejercicios está disponible solo para usuarios Premium.'**
  String get videosPremiumPlaybackMessage;

  /// No description provided for @videosPremiumTitle.
  ///
  /// In es, this message translates to:
  /// **'Vídeos Premium'**
  String get videosPremiumTitle;

  /// No description provided for @videosPremiumSubtitle.
  ///
  /// In es, this message translates to:
  /// **'El catálogo completo de vídeos de ejercicios está disponible solo para usuarios Premium. Accede a '**
  String get videosPremiumSubtitle;

  /// No description provided for @videosPremiumPreviewHighlight.
  ///
  /// In es, this message translates to:
  /// **'{count} vídeos exclusivos.'**
  String videosPremiumPreviewHighlight(Object count);

  /// No description provided for @charlasPremiumToolsMessage.
  ///
  /// In es, this message translates to:
  /// **'La búsqueda, filtros, favoritos, likes y ordenación completa de las charlas y seminarios están disponibles solo para usuarios Premium.'**
  String get charlasPremiumToolsMessage;

  /// No description provided for @charlasPremiumContentMessage.
  ///
  /// In es, this message translates to:
  /// **'El acceso completo al contenido de la charla o seminario está disponible solo para usuarios Premium.'**
  String get charlasPremiumContentMessage;

  /// No description provided for @charlasPremiumTitle.
  ///
  /// In es, this message translates to:
  /// **'Charlas Premium'**
  String get charlasPremiumTitle;

  /// No description provided for @charlasPremiumSubtitle.
  ///
  /// In es, this message translates to:
  /// **'El catálogo completo de charlas y seminarios está disponible solo para usuarios Premium. Accede a '**
  String get charlasPremiumSubtitle;

  /// No description provided for @charlasPremiumPreviewHighlight.
  ///
  /// In es, this message translates to:
  /// **'{count} charlas exclusivas.'**
  String charlasPremiumPreviewHighlight(Object count);

  /// No description provided for @supplementsPremiumCopyPdfMessage.
  ///
  /// In es, this message translates to:
  /// **'Para poder copiar y pasar a PDF un suplemento, debes ser usuario Premium.'**
  String get supplementsPremiumCopyPdfMessage;

  /// No description provided for @supplementsPremiumExploreMessage.
  ///
  /// In es, this message translates to:
  /// **'Los hashtags y las recomendaciones de suplementos están disponibles solo para usuarios Premium.'**
  String get supplementsPremiumExploreMessage;

  /// No description provided for @supplementsPremiumToolsMessage.
  ///
  /// In es, this message translates to:
  /// **'La búsqueda, actualización y ordenación completa del catálogo de suplementos están disponibles solo para usuarios Premium.'**
  String get supplementsPremiumToolsMessage;

  /// No description provided for @supplementsPremiumTitle.
  ///
  /// In es, this message translates to:
  /// **'Suplementos Premium'**
  String get supplementsPremiumTitle;

  /// No description provided for @supplementsPremiumSubtitle.
  ///
  /// In es, this message translates to:
  /// **'El catálogo completo de suplementos está disponible solo para usuarios Premium.'**
  String get supplementsPremiumSubtitle;

  /// No description provided for @supplementsPremiumPreviewHighlight.
  ///
  /// In es, this message translates to:
  /// **'(con más de {count} suplementos)'**
  String supplementsPremiumPreviewHighlight(Object count);

  /// No description provided for @exerciseCatalogPremiumToolsMessage.
  ///
  /// In es, this message translates to:
  /// **'La búsqueda, filtros, actualización y ordenación completa del catálogo de ejercicios están disponibles solo para usuarios Premium.'**
  String get exerciseCatalogPremiumToolsMessage;

  /// No description provided for @exerciseCatalogPremiumVideoMessage.
  ///
  /// In es, this message translates to:
  /// **'El vídeo completo del ejercicio está disponible solo para usuarios Premium.'**
  String get exerciseCatalogPremiumVideoMessage;

  /// No description provided for @exerciseCatalogPremiumTitle.
  ///
  /// In es, this message translates to:
  /// **'Ejercicios Premium'**
  String get exerciseCatalogPremiumTitle;

  /// No description provided for @exerciseCatalogPremiumSubtitle.
  ///
  /// In es, this message translates to:
  /// **'El catálogo completo de ejercicios está disponible solo para usuarios Premium.'**
  String get exerciseCatalogPremiumSubtitle;

  /// No description provided for @exerciseCatalogPremiumPreviewHighlight.
  ///
  /// In es, this message translates to:
  /// **'(con más de {count} ejercicios)'**
  String exerciseCatalogPremiumPreviewHighlight(Object count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'de',
        'en',
        'es',
        'fr',
        'it',
        'pt'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
