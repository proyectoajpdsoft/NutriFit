// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get settingsAndPrivacyTitle => 'Ajustes y privacidad';

  @override
  String get settingsAndPrivacyMenuLabel => 'Ajustes y privacidad';

  @override
  String get configTabParameters => 'Parámetros';

  @override
  String get configTabPremium => 'Premium';

  @override
  String get configTabAppMenu => 'Menú app';

  @override
  String get configTabGeneral => 'General';

  @override
  String get configTabSecurity => 'Seguridad';

  @override
  String get configTabUser => 'Usuario';

  @override
  String get configTabDisplay => 'Mostrar';

  @override
  String get configTabDefaults => 'Defecto';

  @override
  String get configTabPrivacy => 'Privacidad';

  @override
  String get securitySubtabAccess => 'Acceso';

  @override
  String get securitySubtabEmailServer => 'Servidor Email';

  @override
  String get securitySubtabCipher => 'Cifrado/Descifrado';

  @override
  String get securitySubtabSessions => 'Sesiones';

  @override
  String get securitySubtabAccesses => 'Accesos';

  @override
  String get privacyCenterTab => 'Centro';

  @override
  String get privacyPolicyTab => 'Política';

  @override
  String get privacySessionsTab => 'Sesiones';

  @override
  String privacyLastUpdatedLabel(Object date) {
    return 'Última actualización: $date';
  }

  @override
  String get privacyIntro =>
      'Esta sección muestra la Política de Privacidad actualizada de NutriFitApp, explica cómo se tratan los datos personales conforme al RGPD y la LOPDGDD y detalla cómo eliminar la cuenta y todos los datos desde la propia app.';

  @override
  String get privacyPrintPdf => 'Imprimir / guardar en PDF';

  @override
  String privacyPdfGenerateError(Object error) {
    return 'Error al generar el PDF de privacidad: $error';
  }

  @override
  String get privacyCannotIdentifyUser =>
      'No se pudo identificar al usuario actual.';

  @override
  String privacyOpenProfileError(Object error) {
    return 'No se pudo abrir Editar Perfil: $error';
  }

  @override
  String get privacyDeleteDialogTitle => 'Eliminar todos mis datos';

  @override
  String get privacyDeleteDialogIntro =>
      'Esta acción elimina tu cuenta y los datos asociados a ella conforme al derecho de supresión.';

  @override
  String get privacyDeleteDialogBody =>
      'Se eliminarán los inicios de sesión, chats, control de peso, lista de la compra, actividades, tareas, entrenamientos, ejercicios e imágenes vinculadas a tu usuario.';

  @override
  String get privacyDeleteDialogWarning =>
      'La acción es irreversible y cerrará tu sesión.';

  @override
  String get privacyDeleteTypedTitle => 'Confirmación final';

  @override
  String privacyDeleteTypedPrompt(Object keyword) {
    return 'Para confirmar, escribe $keyword en mayúsculas:';
  }

  @override
  String privacyDeleteTypedHint(Object keyword) {
    return '$keyword';
  }

  @override
  String privacyDeleteTypedMismatch(Object keyword) {
    return 'Debes escribir $keyword para confirmar.';
  }

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get privacyDeleteMyData => 'Eliminar mis datos';

  @override
  String get privacyDeleteConnectionError =>
      'No se ha podido realizar el proceso. Revise la conexión a Internet.';

  @override
  String get privacyDeleteAccountFailed => 'No se pudo eliminar la cuenta.';

  @override
  String get privacyActionPolicyTitle => 'Política de privacidad';

  @override
  String get privacyActionPolicyDescription =>
      'Consulta el texto completo de privacidad, derechos del usuario y tratamiento de datos según RGPD y LOPDGDD.';

  @override
  String get privacyViewPolicy => 'Ver política';

  @override
  String get privacyPdfShort => 'PDF';

  @override
  String get privacyActionSecurityTitle => 'Seguridad y acceso';

  @override
  String get privacyActionSecurityDescription =>
      'Accede a Editar Perfil para gestionar el correo, el doble factor (2FA), dispositivos de confianza y otros controles de acceso a tu cuenta.';

  @override
  String get privacyOpenEditProfile => 'Abrir Editar Perfil';

  @override
  String get privacyActionSessionsTitle => 'Inicios de sesión';

  @override
  String get privacyActionSessionsDescription =>
      'Consulta las últimas sesiones exitosas, intentos fallidos y la actividad de acceso asociada a tu cuenta.';

  @override
  String get privacyViewSessions => 'Ver sesiones';

  @override
  String get privacyActionDeleteTitle => 'Eliminar todos mis datos';

  @override
  String get privacyActionDeleteDescription =>
      'Puedes solicitar la eliminación completa de tu cuenta y de los datos asociados directamente desde la app. La acción es irreversible y cerrará tu sesión.';

  @override
  String get sessionsUserCodeUnavailable => 'Código de usuario no disponible';

  @override
  String get sessionsAnonymousGuestInfo =>
      'No hay datos de sesión disponibles para usuarios sin registrar, ya que el acceso se realiza de forma anónima.';

  @override
  String sessionsError(Object error) {
    return 'Error: $error';
  }

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get sessionsNoDataAvailable => 'No hay datos de sesión disponibles';

  @override
  String get sessionsSuccessfulTitle => 'Últimos Inicios de Sesión Exitosos';

  @override
  String get sessionsCurrent => 'Sesión actual:';

  @override
  String get sessionsPrevious => 'Sesión anterior:';

  @override
  String get sessionsNoSuccessful => 'No hay sesiones exitosas registradas';

  @override
  String get sessionsFailedTitle => 'Últimos Intentos de Acceso Fallidos';

  @override
  String sessionsAttemptNumber(Object count) {
    return 'Intento $count:';
  }

  @override
  String get sessionsNoFailed => 'No hay intentos fallidos registrados.';

  @override
  String get sessionsStatsTitle => 'Estadísticas de Sesiones';

  @override
  String sessionsTotal(Object count) {
    return 'Total de sesiones: $count';
  }

  @override
  String sessionsSuccessfulCount(Object count) {
    return 'Intentos exitosos: $count';
  }

  @override
  String sessionsFailedCount(Object count) {
    return 'Intentos fallidos: $count';
  }

  @override
  String get commonNotAvailable => 'N/D';

  @override
  String sessionsDate(Object value) {
    return 'Fecha: $value';
  }

  @override
  String sessionsTime(Object value) {
    return 'Hora: $value';
  }

  @override
  String sessionsDevice(Object value) {
    return 'Dispositivo: $value';
  }

  @override
  String get sessionsIpAddress => 'Dirección IP:';

  @override
  String sessionsPublicIp(Object value) {
    return 'Pública: $value';
  }

  @override
  String get privacyPolicyTitle => 'Política de privacidad de NutriFitApp';

  @override
  String get privacyPolicyLastUpdated => '7 de abril de 2026';

  @override
  String get privacyPolicySection1Title => '1. Responsable del tratamiento';

  @override
  String get privacyPolicySection1Paragraph1 =>
      'El responsable del tratamiento de los datos personales tratados a través de la aplicación NutriFit es el titular o entidad explotadora del servicio NutriFitApp.';

  @override
  String get privacyPolicySection1Paragraph2 =>
      'Datos de contacto del responsable:';

  @override
  String get privacyPolicySection1Bullet1 =>
      'Nombre o razón social: Patricia Carmona Fernández.';

  @override
  String get privacyPolicySection1Bullet2 =>
      'NIF/CIF: Se enviará previa solicitud.';

  @override
  String get privacyPolicySection1Bullet3 =>
      'Domicilio: Se enviará previa solicitud.';

  @override
  String get privacyPolicySection1Bullet4 =>
      'Correo electrónico de contacto: aprendeconpatrica[ — arroba — ]gmail[ — punto — ]com';

  @override
  String get privacyPolicySection2Title => '2. Normativa aplicable';

  @override
  String get privacyPolicySection2Paragraph1 =>
      'Esta Política de Privacidad se ha redactado de conformidad con la normativa aplicable en materia de protección de datos personales, en particular:';

  @override
  String get privacyPolicySection2Bullet1 =>
      'Reglamento (UE) 2016/679 del Parlamento Europeo y del Consejo, de 27 de abril de 2016, Reglamento General de Protección de Datos (RGPD).';

  @override
  String get privacyPolicySection2Bullet2 =>
      'Ley Orgánica 3/2018, de 5 de diciembre, de Protección de Datos Personales y garantía de los derechos digitales (LOPDGDD).';

  @override
  String get privacyPolicySection2Bullet3 =>
      'Resto de normativa española y europea que resulte aplicable.';

  @override
  String get privacyPolicySection3Title => '3. Qué es NutriFitApp';

  @override
  String get privacyPolicySection3Paragraph1 =>
      'NutriFitApp es una aplicación orientada a nutrición, salud, deporte, seguimiento de hábitos y organización personal, que puede incluir funciones como perfil de usuario, tareas, lista de la compra, recetas, consejos, sustituciones saludables, entrenamiento, escáner nutricional, notificaciones, aditivos, suplementos, control de peso y herramientas de seguimiento entre usuario y profesional.';

  @override
  String get privacyPolicySection4Title => '4. Qué datos personales tratamos';

  @override
  String get privacyPolicySection4Paragraph1 =>
      'En función del uso que realices de la app, NutriFitApp puede tratar las siguientes categorías de datos:';

  @override
  String get privacyPolicySection4Bullet1 =>
      'Datos identificativos: nombre, nick o alias, correo electrónico, imagen de perfil y otros datos de registro.';

  @override
  String get privacyPolicySection4Bullet2 =>
      'Datos de acceso y autenticación: credenciales, identificadores de sesión, verificaciones de seguridad y elementos asociados al acceso seguro a la cuenta.';

  @override
  String get privacyPolicySection4Bullet3 =>
      'Datos de uso de la app: interacciones, preferencias, configuraciones guardadas y acciones realizadas dentro de la aplicación.';

  @override
  String get privacyPolicySection4Bullet4 =>
      'Datos aportados por el usuario: tareas, notas, comentarios, sensaciones, contenidos introducidos manualmente y otra información facilitada voluntariamente.';

  @override
  String get privacyPolicySection4Bullet5 =>
      'Datos relacionados con nutrición, bienestar, actividad física o seguimiento personal que el usuario decida incorporar a la aplicación.';

  @override
  String get privacyPolicySection4Bullet6 =>
      'Datos técnicos y del dispositivo: identificadores técnicos, versión de la app, sistema operativo, configuración de idioma, datos mínimos necesarios para funcionamiento, seguridad y diagnóstico.';

  @override
  String get privacyPolicySection4Bullet7 =>
      'Datos derivados de notificaciones push, en caso de que el usuario las active.';

  @override
  String get privacyPolicySection4Bullet8 =>
      'Datos de cámara o imágenes, si el usuario utiliza funciones como imagen de perfil, escáner o captura de contenido, imágenes en actividades.';

  @override
  String get privacyPolicySection4Bullet9 =>
      'Datos vinculados a funciones de calendario, si el usuario decide usar integraciones de agenda.';

  @override
  String get privacyPolicySection4Bullet10 =>
      'Otros datos necesarios para prestar correctamente los servicios ofrecidos en la app.';

  @override
  String get privacyPolicySection4Paragraph2 =>
      'Si en determinados casos se tratan datos relacionados con salud o bienestar personal, dicho tratamiento se realizará únicamente en la medida necesaria para prestar la funcionalidad solicitada por el usuario y conforme a la base jurídica aplicable.';

  @override
  String get privacyPolicySection5Title => '5. Finalidades del tratamiento';

  @override
  String get privacyPolicySection5Bullet1 =>
      'Crear y gestionar la cuenta de usuario.';

  @override
  String get privacyPolicySection5Bullet2 =>
      'Permitir el inicio de sesión y mantener la sesión autenticada.';

  @override
  String get privacyPolicySection5Bullet3 =>
      'Prestar las funcionalidades principales de NutriFitApp.';

  @override
  String get privacyPolicySection5Bullet4 => 'Gestionar el perfil del usuario.';

  @override
  String get privacyPolicySection5Bullet5 =>
      'Permitir el seguimiento de hábitos, tareas, entrenamiento, nutrición y contenidos relacionados.';

  @override
  String get privacyPolicySection5Bullet6 =>
      'Facilitar la interacción entre usuario y profesional cuando esa funcionalidad esté habilitada.';

  @override
  String get privacyPolicySection5Bullet7 =>
      'Enviar notificaciones relacionadas con la actividad de la cuenta o con funciones utilizadas por el usuario.';

  @override
  String get privacyPolicySection5Bullet8 =>
      'Mejorar la experiencia de uso, estabilidad, seguridad y rendimiento de la app.';

  @override
  String get privacyPolicySection5Bullet9 =>
      'Atender solicitudes, incidencias o consultas remitidas por el usuario.';

  @override
  String get privacyPolicySection5Bullet10 =>
      'Cumplir obligaciones legales aplicables.';

  @override
  String get privacyPolicySection5Bullet11 =>
      'Defender los intereses legítimos del responsable en materia de seguridad, prevención del fraude, integridad del servicio y protección frente a accesos no autorizados.';

  @override
  String get privacyPolicySection6Title => '6. Base jurídica';

  @override
  String get privacyPolicySection6Paragraph1 =>
      'Las bases jurídicas que legitiman el tratamiento pueden ser, según el caso:';

  @override
  String get privacyPolicySection6Bullet1 =>
      'La ejecución de la relación contractual o precontractual cuando el usuario se registra y utiliza NutriFitApp.';

  @override
  String get privacyPolicySection6Bullet2 =>
      'El consentimiento del usuario para aquellas funcionalidades que lo requieran.';

  @override
  String get privacyPolicySection6Bullet3 =>
      'El cumplimiento de obligaciones legales.';

  @override
  String get privacyPolicySection6Bullet4 =>
      'El interés legítimo del responsable en garantizar la seguridad, continuidad y correcto funcionamiento de la aplicación.';

  @override
  String get privacyPolicySection6Paragraph2 =>
      'Cuando el tratamiento se base en el consentimiento, el usuario podrá retirarlo en cualquier momento, sin que ello afecte a la licitud del tratamiento previo a su retirada.';

  @override
  String get privacyPolicySection7Title => '7. Conservación de los datos';

  @override
  String get privacyPolicySection7Paragraph1 =>
      'Los datos personales se conservarán durante el tiempo necesario para cumplir con la finalidad para la que fueron recogidos y, posteriormente, durante los plazos legalmente exigibles para atender posibles responsabilidades.';

  @override
  String get privacyPolicySection7Paragraph2 =>
      'Cuando el usuario solicite la eliminación de su cuenta, sus datos serán suprimidos o anonimizados conforme a la política interna de retención y a las obligaciones legales que pudieran resultar aplicables.';

  @override
  String get privacyPolicySection8Title =>
      '8. Eliminación de datos por parte del usuario';

  @override
  String get privacyPolicySection8Paragraph1 =>
      'NutriFitApp permite al usuario eliminar todos sus datos, suprimiendo su cuenta directamente desde la propia aplicación en cualquier momento.';

  @override
  String get privacyPolicySection8Paragraph2 =>
      'Pasos dentro de la app para eliminar la cuenta y sus datos por completo:';

  @override
  String get privacyPolicySection8Step1 =>
      'Accede a NutriFitApp con tu usuario.';

  @override
  String get privacyPolicySection8Step2 => 'Entra en Editar Perfil.';

  @override
  String get privacyPolicySection8Step3 =>
      'Dentro de esa pantalla, localiza la opción de eliminación de cuenta (botón «Eliminar todos mis datos»).';

  @override
  String get privacyPolicySection8Step4 => 'Pulsa en Eliminar todos mis datos.';

  @override
  String get privacyPolicySection8Step5 =>
      'Confirma el proceso de eliminación.';

  @override
  String get privacyPolicySection8Paragraph3 =>
      'Tras la confirmación, la aplicación ejecutará el proceso de borrado de la cuenta y de los datos asociados conforme al funcionamiento del sistema, y cerrará la sesión del usuario.';

  @override
  String get privacyPolicySection8Paragraph4 =>
      'Si por cualquier motivo el usuario no pudiera completar el proceso desde la app, también podrá solicitar la eliminación escribiendo al correo electrónico de contacto arriba indicado.';

  @override
  String get privacyPolicySection9Title => '9. Destinatarios de los datos';

  @override
  String get privacyPolicySection9Paragraph1 =>
      'NUNCA se venderán ni cederán los datos a terceros.';

  @override
  String get privacyPolicySection9Paragraph2 =>
      'Sólo tendrán acceso a los datos:';

  @override
  String get privacyPolicySection9Bullet1 =>
      'Personal técnico cualificado únicamente para procesos tecnológicos necesarios para el funcionamiento de la app, el alojamiento, las notificaciones, el soporte técnico o servicios asociados.';

  @override
  String get privacyPolicySection9Bullet2 =>
      'Encargados del tratamiento contratados por el responsable, bajo las correspondientes garantías contractuales.';

  @override
  String get privacyPolicySection9Bullet3 =>
      'Administraciones públicas, jueces, tribunales o autoridades competentes cuando exista obligación legal.';

  @override
  String get privacyPolicySection9Paragraph3 =>
      'No hay transferencias internacionales de datos fuera del Espacio Económico Europeo.';

  @override
  String get privacyPolicySection10Title => '10. Permisos del dispositivo';

  @override
  String get privacyPolicySection10Paragraph1 =>
      'NutriFitApp puede solicitar permisos del dispositivo únicamente cuando sean necesarios para una funcionalidad concreta. Por ejemplo:';

  @override
  String get privacyPolicySection10Bullet1 =>
      'Cámara: para capturar imágenes o usar funciones de escaneo.';

  @override
  String get privacyPolicySection10Bullet2 =>
      'Galería o archivos: para seleccionar imágenes o documentos, para guardar documentos PDF de la App.';

  @override
  String get privacyPolicySection10Bullet3 =>
      'Notificaciones: para avisos relevantes dentro de la app.';

  @override
  String get privacyPolicySection10Bullet4 =>
      'Calendario: si el usuario decide exportar o añadir eventos.';

  @override
  String get privacyPolicySection10Bullet5 =>
      'Otros permisos estrictamente necesarios para determinadas herramientas de la aplicación.';

  @override
  String get privacyPolicySection10Paragraph2 =>
      'El usuario puede revocar estos permisos en cualquier momento desde la configuración del dispositivo, aunque algunas funciones podrían dejar de estar disponibles.';

  @override
  String get privacyPolicySection11Title => '11. Seguridad de la información';

  @override
  String get privacyPolicySection11Paragraph1 =>
      'NutriFitApp aplica medidas técnicas y organizativas razonables para proteger los datos personales frente a pérdida, alteración, acceso no autorizado, divulgación o destrucción. La información se cifra en tránsito.';

  @override
  String get privacyPolicySection11Paragraph2 =>
      'No obstante, el usuario debe saber que ninguna transmisión por Internet ni ningún sistema de almacenamiento puede garantizar seguridad absoluta.';

  @override
  String get privacyPolicySection12Title => '12. Derechos del usuario';

  @override
  String get privacyPolicySection12Paragraph1 =>
      'El usuario puede ejercer en cualquier momento los siguientes derechos:';

  @override
  String get privacyPolicySection12Bullet1 => 'Acceso.';

  @override
  String get privacyPolicySection12Bullet2 => 'Rectificación.';

  @override
  String get privacyPolicySection12Bullet3 => 'Supresión.';

  @override
  String get privacyPolicySection12Bullet4 => 'Oposición.';

  @override
  String get privacyPolicySection12Bullet5 => 'Limitación del tratamiento.';

  @override
  String get privacyPolicySection12Bullet6 => 'Portabilidad.';

  @override
  String get privacyPolicySection12Bullet7 =>
      'Retirada del consentimiento, cuando el tratamiento se base en este.';

  @override
  String get privacyPolicySection12Paragraph2 =>
      'Para ejercer estos derechos, el usuario puede:';

  @override
  String get privacyPolicySection12Bullet8 =>
      'Utilizar las funciones disponibles dentro de la propia app, cuando existan.';

  @override
  String get privacyPolicySection12Bullet9 =>
      'Contactar con el responsable a través del email de contacto arriba indicado.';

  @override
  String get privacyPolicySection12Paragraph3 =>
      'La solicitud deberá permitir identificar razonablemente al solicitante.';

  @override
  String get privacyPolicySection12Paragraph4 =>
      'Asimismo, el usuario tiene derecho a presentar una reclamación ante la Agencia Española de Protección de Datos (AEPD) si considera que sus derechos no han sido debidamente atendidos:';

  @override
  String get privacyPolicySection12Paragraph5 => 'https://www.aepd.es/';

  @override
  String get privacyPolicySection13Title => '13. Menores de edad';

  @override
  String get privacyPolicySection13Paragraph1 =>
      'NutriFitApp no está dirigida de forma general a menores de edad sin la intervención o autorización de sus representantes legales cuando esta sea exigible. Si detectamos que se han recopilado datos personales de un menor de forma contraria a la normativa aplicable, se adoptarán las medidas oportunas para su supresión.';

  @override
  String get privacyPolicySection14Title =>
      '14. Exactitud y responsabilidad del usuario';

  @override
  String get privacyPolicySection14Paragraph1 =>
      'El usuario garantiza que los datos facilitados son verdaderos, exactos y actualizados, y se compromete a comunicar cualquier modificación.';

  @override
  String get privacyPolicySection14Paragraph2 =>
      'El usuario será responsable de los daños o perjuicios que pudieran derivarse de la aportación de datos falsos, inexactos o desactualizados.';

  @override
  String get privacyPolicySection15Title => '15. Cambios en esta política';

  @override
  String get privacyPolicySection15Paragraph1 =>
      'NutriFitApp podrá actualizar esta Política de Privacidad para adaptarla a cambios legales, técnicos o funcionales. Cuando los cambios sean relevantes, se informará al usuario por medios adecuados.';

  @override
  String get privacyPolicySection16Title => '16. Contacto';

  @override
  String get privacyPolicySection16Paragraph1 =>
      'Para cualquier cuestión relacionada con privacidad o protección de datos, puedes contactar en:';

  @override
  String get privacyPolicySection16Paragraph2 =>
      'aprendeconpatrica[ — arroba — ]gmail[ — punto — ]com';

  @override
  String get commonClose => 'Cerrar';

  @override
  String appUpdatedNotice(Object version) {
    return 'La app se ha actualizado a la versión $version.';
  }

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonAgree => 'De acuerdo';

  @override
  String get commonLater => 'Más tarde';

  @override
  String get commonValidate => 'Validar';

  @override
  String get commonToday => 'hoy';

  @override
  String get commonDebug => 'DEBUG';

  @override
  String get commonAllRightsReserved => 'Todos los derechos reservados';

  @override
  String get navHome => 'Inicio';

  @override
  String get navLogout => 'Cerrar sesión';

  @override
  String get navChat => 'Chat';

  @override
  String get navPatients => 'Pacientes';

  @override
  String get navAppointments => 'Citas';

  @override
  String get navReviews => 'Revisiones';

  @override
  String get navMeasurements => 'Mediciones';

  @override
  String get navNutriInterviews => 'Entrevistas Nutri';

  @override
  String get navNutriPlans => 'Planes Nutri';

  @override
  String get navFitInterviews => 'Entrevistas Fit';

  @override
  String get navFitPlans => 'Planes Fit';

  @override
  String get navExercises => 'Ejercicios';

  @override
  String get navExerciseVideos => 'Vídeos Ejercicios';

  @override
  String get navActivities => 'Actividades';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navCharges => 'Cobros';

  @override
  String get navClients => 'Clientes';

  @override
  String get navTips => 'Consejos';

  @override
  String get navRecipes => 'Recetas';

  @override
  String get navSubstitutions => 'Sustituciones';

  @override
  String get navTalksAndSeminars => 'Charlas y Seminarios';

  @override
  String get navTalks => 'Charlas';

  @override
  String get navPremiumPreview => 'Hazte Premium (vista)';

  @override
  String get navPremium => 'Hazte Premium';

  @override
  String get premiumRegistrationRequiredBody =>
      'Para hacerte Premium primero tienes que registrarte. El registro es gratis y, una vez tengas tu cuenta, ya podrás solicitar el acceso Premium al dietista.';

  @override
  String get premiumRegisterFree => 'Registrarme gratis';

  @override
  String get premiumPaymentMethodLabel => 'Método de pago';

  @override
  String get premiumVerifyEmailAction =>
      'Verifica tu email para realizar el pago';

  @override
  String get premiumContinuePayment => 'Continuar con el pago';

  @override
  String premiumVerifiedEmailStatus(Object email) {
    return 'Email verificado: $email';
  }

  @override
  String get premiumPaymentNeedsRegistration =>
      'Para realizar el pago, primero regístrate, es gratis:';

  @override
  String get premiumPaymentNeedsEmailVerification =>
      'Para realizar el pago, primero verifica tu email en';

  @override
  String get premiumGoToRegisterLink => 'Ir al registro de usuario';

  @override
  String get premiumGuestRegistrationBody =>
      'Si todavía no tienes cuenta, primero debes registrarte gratis para poder solicitar el acceso Premium.';

  @override
  String get premiumBenefitsSectionTitle => 'Ventajas de ser Premium';

  @override
  String get premiumPaymentSectionTitle => 'Pago y contratación Premium';

  @override
  String get premiumAfterRegistrationMessage =>
      'Después del registro podrás usar el asistente de pago Premium en esta misma pantalla.';

  @override
  String get premiumFinalActivationMessage =>
      'La activación final del acceso Premium la realiza el equipo de NutriFit tras validar el pago y el período elegido. Se realizará en las próximas 24/48/72 horas, en función del método elegido.';

  @override
  String get premiumDefaultIntroTitle => 'Desbloquea tu experiencia Premium';

  @override
  String get premiumDefaultIntroText =>
      'Accede a contenidos exclusivos, recursos avanzados y seguimiento reforzado para sacar más partido a tu plan.';

  @override
  String get premiumDefaultBenefit1 =>
      'Acceso a funcionalidades exclusivas para usuarios Premium, como Vídeos Ejercicios y futuras mejoras.';

  @override
  String get premiumDefaultBenefit2 =>
      'Biblioteca de sustituciones saludables: equivalencias rápidas del tipo \"si no tengo X, usa Y\" para no romper el plan.';

  @override
  String get premiumDefaultBenefit3 =>
      'Experiencia más completa dentro de la app con contenido diferencial y acceso ampliado.';

  @override
  String get premiumDefaultBenefit4 =>
      'Posibilidad de recibir propuestas personalizadas del nutricionista según el servicio contratado.';

  @override
  String get premiumDefaultPaymentMethod1 =>
      'El nutricionista puede ofrecer métodos como PayPal, Bizum, transferencia bancaria u otras opciones personalizadas.';

  @override
  String get premiumDefaultPaymentMethod2 =>
      'Estos datos son configurables desde parámetros globales para adaptar la propuesta comercial a cada profesional.';

  @override
  String get premiumDefaultPaymentIntro =>
      'Instrucciones para realizar el pago y activar tu cuenta Premium.';

  @override
  String get premiumDefaultActivationNotice =>
      'Una vez recibido el pago, tu perfil Premium se activará en un plazo aproximado de 24/48/72 horas, en función del método elegido.';

  @override
  String premiumDefaultPaypalSteps(
      Object boton_abrir_url_paypal, Object email_paypal, Object url_paypal) {
    return 'Abre la pasarela de pago en: $url_paypal.\nRealiza el pago con la cuenta PayPal ($email_paypal) e importe indicado.\nSi lo necesitas, usa el botón $boton_abrir_url_paypal.';
  }

  @override
  String premiumDefaultBizumSteps(
      Object boton_copiar_telefono, Object telefono_nutricionista) {
    return 'Realiza el Bizum al teléfono $telefono_nutricionista.\nAñade el concepto antes de confirmar el pago.\nSi lo necesitas, usa el botón $boton_copiar_telefono.';
  }

  @override
  String get premiumDefaultTransferSteps =>
      'Realiza la transferencia con los datos mostrados en pantalla.\nComprueba el importe y añade el concepto antes de enviar.\nSi lo necesitas, copia los datos bancarios disponibles.';

  @override
  String get premiumPayWithPaypal => 'Pagar por PayPal';

  @override
  String get premiumPayWithBizum => 'Pagar por Bizum';

  @override
  String get premiumPayWithTransfer => 'Pagar por transferencia';

  @override
  String get premiumPeriodBadgeMaxDiscount => 'Máximo descuento';

  @override
  String get premiumPeriodBadgeHighSaving => 'Ahorro alto';

  @override
  String get premiumPeriodBadgeMediumSaving => 'Ahorro medio';

  @override
  String get premiumPeriodBadgeNoDiscount => 'Sin descuento';

  @override
  String get premiumPeriodLabel => 'Período Premium';

  @override
  String premiumPeriodMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'es',
      one: '',
    );
    return '$months mes$_temp0';
  }

  @override
  String premiumPriceUnavailable(Object period) {
    return 'Precio no disponible para $period.';
  }

  @override
  String premiumPriceDisplay(Object amount, Object period) {
    return 'Precio: $amount (período contratado de $period)';
  }

  @override
  String get premiumVerifyEmailBeforePayment =>
      'Debes verificar tu email antes de continuar con el pago.';

  @override
  String get premiumCopyPhone => 'Copiar teléfono';

  @override
  String get premiumOpenPayment => 'Acceder al pago';

  @override
  String get premiumCopyConcept => 'Copiar concepto';

  @override
  String get premiumVerifyEmailBeforeNotifyPayment =>
      'Debes verificar tu email antes de notificar el pago.';

  @override
  String premiumNotifyPaymentError(Object error) {
    return 'No se pudo notificar el pago: $error';
  }

  @override
  String get premiumCompletePaymentTitle => 'Completar el pago';

  @override
  String get premiumPaymentConceptLabel =>
      'Concepto que debes indicar en el método de pago:';

  @override
  String premiumStepsFor(Object method) {
    return 'Pasos para $method';
  }

  @override
  String get premiumBizumPhoneLabel => 'Teléfono Bizum';

  @override
  String get premiumAfterPaymentNotice =>
      'Cuando hayas realizado el pago, pulsa en \"He realizado el pago\" para enviar notificación al equipo de NutriFit. En cuanto se verifique el pago, se activará tu cuenta Premium y se te notificará por email.';

  @override
  String get premiumSendingNotification => 'Enviando notificación...';

  @override
  String get premiumIHavePaid => 'He realizado el pago';

  @override
  String get premiumInvalidUrl => 'URL no válida.';

  @override
  String premiumOpenPaymentError(Object error) {
    return 'No se pudo abrir el enlace de pago: $error';
  }

  @override
  String get premiumPeriodSummaryMaxDiscount =>
      'Período a contratar de 12 meses (con descuento máximo).';

  @override
  String get premiumPeriodSummaryHighDiscount =>
      'Período a contratar de 6 meses (con descuento alto).';

  @override
  String get premiumPeriodSummaryDiscount =>
      'Período a contratar de 3 meses (con descuento).';

  @override
  String get premiumPeriodSummarySingleMonth => 'Período a contratar de 1 mes.';

  @override
  String premiumPaymentConcept(Object nick) {
    return 'NutriFit Premium usuario $nick.';
  }

  @override
  String get navFoods => 'Alimentos';

  @override
  String get navSupplements => 'Suplementos';

  @override
  String get navFoodAdditives => 'Aditivos alimentarios';

  @override
  String get navAdditives => 'Aditivos';

  @override
  String get navScanner => 'Escáner';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get navUsers => 'Usuarios';

  @override
  String get navTasks => 'Tareas';

  @override
  String get navChatWithDietitian => 'Chat con dietista';

  @override
  String get navContactDietitian => 'Contactar con dietista';

  @override
  String get navEditProfile => 'Editar Perfil';

  @override
  String get profileEditProfileTab => 'Perfil';

  @override
  String get profileEditSessionsTab => 'Inicios de sesión';

  @override
  String get profileEditPremiumBadgeTitle => 'Cuenta Premium';

  @override
  String get profileEditPremiumBadgeBody =>
      'Tienes acceso a funciones exclusivas como Vídeos Ejercicios.';

  @override
  String get profileEditNickLabel => 'Nick / Usuario';

  @override
  String get profileEditNickRequired => 'El nick es obligatorio';

  @override
  String get profileEditEmailLabel => 'Email';

  @override
  String get profileEditInvalidEmail => 'Email no válido';

  @override
  String get profileEditEmailInUse =>
      'El email introducido no es válido, indique otro';

  @override
  String get profileEditChangeEmailTooltip =>
      'Cambiar cuenta de correo electrónico';

  @override
  String get profileEditVerifyEmailCta => 'Verificar email';

  @override
  String get profileEditTwoFactorShortLabel => 'Doble factor';

  @override
  String get profileEditBmiCardTitle => 'Datos para IMC';

  @override
  String get profileEditBmiInfoTooltip => 'Información MVP/IMC';

  @override
  String get profileEditBmiCardBody =>
      'Para obtener el IMC, MVP y recomendaciones, completa Edad y Altura.';

  @override
  String get profileEditAgeLabel => 'Edad';

  @override
  String get profileEditInvalidAge => 'Edad no válida';

  @override
  String get profileEditHeightLabel => 'Altura (cm)';

  @override
  String get profileEditInvalidHeight => 'Altura no válida';

  @override
  String get profileEditPasswordCardTitle => 'Cambio de contraseña';

  @override
  String get profileEditPasswordHint => 'Dejar en blanco para no cambiar';

  @override
  String get profileEditPasswordLabel => 'Contraseña';

  @override
  String get profileEditPasswordConfirmLabel => 'Confirmar Contraseña';

  @override
  String get profileEditPasswordConfirmRequired =>
      'Debes confirmar la contraseña';

  @override
  String get profileEditPasswordMismatch => 'Las contraseñas no coinciden';

  @override
  String get profileEditSaveChanges => 'Guardar Cambios';

  @override
  String get profileEditDeleteMyData => 'Eliminar todos mis datos';

  @override
  String get profileEditChangeEmailTitle => 'Cambiar email';

  @override
  String get profileEditChangeEmailVerifiedWarning =>
      'El email actual está verificado, si lo cambias, tendrás que volver a verificarlo.';

  @override
  String get profileEditChangeEmailNewLabel => 'Nuevo email';

  @override
  String get profileEditChangeEmailRequired => 'Debes indicar un email.';

  @override
  String get profileEditChangeEmailMustDiffer =>
      'Debes indicar un email distinto al actual.';

  @override
  String get profileEditChangeEmailValidationFailed =>
      'No se pudo validar el email. Inténtalo de nuevo.';

  @override
  String get profileEditChangeEmailReview => 'Revisa el email indicado.';

  @override
  String get profileEditEmailRequiredForVerification =>
      'Debes indicar primero una cuenta de email.';

  @override
  String get profileEditEmailCodeSentGeneric => 'Código enviado.';

  @override
  String get profileEditEmailVerifiedGeneric => 'Email verificado.';

  @override
  String get profileEditEmailCodeLengthError =>
      'El código debe tener 10 dígitos.';

  @override
  String get profileEditEmailCodeDialogTitle => 'Validar código de email';

  @override
  String get profileEditEmailCodeTenDigitsLabel => 'Código de 10 dígitos';

  @override
  String get profileEditValidateEmailCodeAction => 'Validar código';

  @override
  String get profileEditVerifyEmailTitle => 'Verificar email';

  @override
  String get profileEditVerifyEmailIntroPrefix =>
      'Verificar tu email te permitirá recuperar el acceso por correo si olvidas la contraseña y también solicitar ';

  @override
  String get profileEditVerifyEmailPremiumLink => 'suscribirte a Premium';

  @override
  String get profileEditFollowTheseSteps => 'Sigue estos pasos...';

  @override
  String get profileEditYourEmail => 'tu email';

  @override
  String profileEditSendCodeInstruction(Object email) {
    return 'Pulsa en \"Enviar código\" para enviarte el código de verificación a $email.';
  }

  @override
  String get profileEditEmailCodeSentInfo =>
      'Código enviado a tu cuenta de correo electrónico. Caducará en 15 minutos. Si no lo ves en Bandeja de entrada, revisa la carpeta Spam.';

  @override
  String get profileEditEmailSendFailed =>
      'No se ha podido enviar el email de verificación en este momento, inténtelo más tarde.';

  @override
  String get profileEditSendCodeAction => 'Enviar código';

  @override
  String get profileEditResendCodeAction => 'Volver a enviar';

  @override
  String get profileEditVerifyCodeInstruction =>
      'Revisa tu correo electrónico, habrás recibido un email con un código, cópialo y pégalo aquí, y pulsa en \"Verificar\".';

  @override
  String get profileEditVerificationCodeLabel => 'Código de verificación';

  @override
  String get profileEditEmailRequiredInProfile =>
      'Debes indicar primero un email en Editar Perfil para poder verificarlo.';

  @override
  String get profileEditTwoFactorDialogTitle => 'Doble factor (2FA)';

  @override
  String get profileEditTwoFactorEnabledStatus => 'Estado: Activado';

  @override
  String get profileEditTwoFactorEnabledBody =>
      'El doble factor ya está activado en tu cuenta. Desde aquí solo puedes consultar si este dispositivo es de confianza y vincularlo o desvincularlo.';

  @override
  String get profileEditTrustedDeviceEnabledBody =>
      'Este dispositivo está marcado como de confianza. No se solicitará el código 2FA en próximos inicios de sesión hasta que quites la confianza desde aquí.';

  @override
  String get profileEditTrustedDeviceDisabledBody =>
      'Este dispositivo no está marcado como de confianza. Puedes marcarlo pulsando en \"Establecer este dispositivo como de confianza\" o cerrando sesión y volviendo a acceder, activando la casilla \"Confiar en este dispositivo\" durante la validación 2FA.';

  @override
  String get profileEditRemoveTrustedDeviceAction =>
      'Quitar confianza en este dispositivo';

  @override
  String get profileEditSetTrustedDeviceAction =>
      'Establecer este dispositivo como de confianza';

  @override
  String get profileEditCancelProcess => 'Cancelar proceso';

  @override
  String get profileEditSetTrustedDeviceTitle =>
      'Establecer dispositivo de confianza';

  @override
  String get profileEditSetTrustedDeviceBody =>
      'Para marcar este dispositivo como de confianza debes validarlo en el inicio de sesión 2FA, activando la casilla \"Confiar en este dispositivo\".\n\n¿Quieres cerrar sesión ahora para hacerlo?';

  @override
  String get profileEditGoToLogin => 'Ir al login';

  @override
  String get profileEditActivateTwoFactorTitle => 'Activar doble factor';

  @override
  String get profileEditActivateTwoFactorIntro =>
      'El doble factor (2FA) añade una capa extra de seguridad: además de tu contraseña, se solicita un código temporal de tu app de autenticación.';

  @override
  String get profileEditTwoFactorStep1 =>
      'Abre tu app de autenticación (Google Authenticator, Microsoft Authenticator, Authy, etc.) y añade una cuenta.';

  @override
  String get profileEditTwoFactorSetupKeyLabel => 'Clave para configurar 2FA:';

  @override
  String get profileEditKeyCopied => 'Clave copiada al portapapeles';

  @override
  String get profileEditHideOptions => 'Ocultar opciones';

  @override
  String get profileEditMoreOptions => 'Más opciones...';

  @override
  String profileEditQrSavedDownloads(Object path) {
    return 'QR guardado en Descargas: $path';
  }

  @override
  String get profileEditQrShared =>
      'Se abrió el menú para compartir o guardar el QR.';

  @override
  String get profileEditOtpUrlCopied => 'URL otpauth copiada';

  @override
  String get profileEditCopyUrl => 'Copiar URL';

  @override
  String get profileEditOtpUrlInfo =>
      'La opción \"Copiar URL\" copia un enlace otpauth con toda la configuración 2FA para importarla en apps compatibles. Si tu app no permite importación por enlace, usa \"Copiar\" en la clave.';

  @override
  String get profileEditTwoFactorConfirmCodeInstruction =>
      'Introduce el código de 6 dígitos que te aparecerá en la app de autenticación para confirmar.';

  @override
  String get profileEditActivateTwoFactorAction => 'Activar';

  @override
  String get profileEditTwoFactorActivated =>
      'Doble factor activado correctamente';

  @override
  String get profileEditTwoFactorActivateFailed => 'No se pudo activar 2FA.';

  @override
  String get profileEditNoQrData => 'No hay datos para guardar el QR.';

  @override
  String profileEditQrSavedPath(Object path) {
    return 'QR guardado en: $path';
  }

  @override
  String profileEditQrSaveFailed(Object error) {
    return 'No se pudo guardar el QR: $error';
  }

  @override
  String get profileEditDeactivateTwoFactorTitle =>
      'Desactivar doble factor (2FA)';

  @override
  String get profileEditCurrentCodeSixDigitsLabel =>
      'Código actual de 6 dígitos';

  @override
  String get profileEditDeactivateTwoFactorAction => 'Desactivar';

  @override
  String get profileEditTwoFactorDeactivated =>
      'Doble factor desactivado correctamente';

  @override
  String get profileEditTwoFactorDeactivateFailed =>
      'No se pudo desactivar 2FA.';

  @override
  String get profileEditRemoveTrustedDeviceTitle =>
      'Quitar confianza del dispositivo';

  @override
  String get profileEditRemoveTrustedDeviceBody =>
      'En este dispositivo se volverá a solicitar el código 2FA en el próximo inicio de sesión. ¿Deseas continuar?';

  @override
  String get profileEditRemoveTrustedDeviceActionShort => 'Quitar confianza';

  @override
  String get profileEditTrustedDeviceRemoved =>
      'Confianza del dispositivo eliminada.';

  @override
  String profileEditTrustedDeviceRemoveFailed(Object error) {
    return 'No se pudo quitar la confianza del dispositivo: $error';
  }

  @override
  String get profileEditMvpDialogTitle => 'Cálculo MVP y fórmulas';

  @override
  String get profileEditMvpWhatIsTitle => '¿Qué es el MVP?';

  @override
  String get profileEditMvpWhatIsBody =>
      'MVP es un conjunto mínimo de indicadores antropométricos para ayudarte a monitorizar de forma sencilla tu evolución de salud: IMC, cintura/altura y cintura/cadera.';

  @override
  String get profileEditMvpFormulasTitle => 'Fórmulas utilizadas y su origen:';

  @override
  String get profileEditMvpOriginBmi =>
      'Origen: OMS (clasificación IMC en adultos).';

  @override
  String get profileEditMvpOriginWhtr =>
      'Origen: índice Waist-to-Height Ratio.';

  @override
  String get profileEditMvpOriginWhr =>
      'Origen: Waist-Hip Ratio (OMS, obesidad abdominal).';

  @override
  String get profileEditImportantNotice => 'Aviso importante';

  @override
  String get profileEditMvpImportantNoticeBody =>
      'Estos cálculos y clasificaciones son orientativos. Para una valoración personalizada, consulta siempre con un profesional médico, dietista-nutricionista o entrenador personal.';

  @override
  String get profileEditAccept => 'Aceptar';

  @override
  String get profileEditNotAvailable => 'N/D';

  @override
  String get profileEditSessionDate => 'Fecha';

  @override
  String get profileEditSessionTime => 'Hora';

  @override
  String get profileEditSessionDevice => 'Dispositivo';

  @override
  String get profileEditSessionIp => 'Dirección IP:';

  @override
  String get profileEditSessionPublicIp => 'Pública';

  @override
  String get profileEditUserCodeUnavailable =>
      'Código de usuario no disponible';

  @override
  String get profileEditGenericError => 'Error';

  @override
  String get profileEditRetry => 'Reintentar';

  @override
  String get profileEditSessionDataUnavailable =>
      'No se ha podido acceder a los datos de inicios de sesión en este momento.';

  @override
  String get profileEditNoSessionData => 'No hay datos de sesión disponibles';

  @override
  String get profileEditSuccessfulSessionsTitle =>
      'Últimos Inicios de Sesión Exitosos';

  @override
  String get profileEditCurrentSession => 'Sesión actual:';

  @override
  String get profileEditPreviousSession => 'Sesión anterior:';

  @override
  String get profileEditNoSuccessfulSessions =>
      'No hay sesiones exitosas registradas';

  @override
  String get profileEditFailedAttemptsTitle =>
      'Últimos Intentos de Acceso Fallidos';

  @override
  String profileEditAttemptLabel(Object count) {
    return 'Intento $count:';
  }

  @override
  String get profileEditNoFailedAttempts =>
      'No hay intentos fallidos registrados.';

  @override
  String get profileEditSessionStatsTitle => 'Estadísticas de Sesiones';

  @override
  String profileEditTotalSessions(Object count) {
    return 'Total de sesiones: $count';
  }

  @override
  String profileEditSuccessfulAttempts(Object count) {
    return 'Intentos exitosos: $count';
  }

  @override
  String profileEditFailedAttempts(Object count) {
    return 'Intentos fallidos: $count';
  }

  @override
  String get navRecommendations => 'Recomendaciones';

  @override
  String get navExerciseCatalog => 'Catálogo ejercicios';

  @override
  String get exerciseCatalogSearchFieldLabel => 'Buscar en';

  @override
  String get exerciseCatalogSearchFieldAll => 'Todos';

  @override
  String get exerciseCatalogSearchFieldTitle => 'Título';

  @override
  String get exerciseCatalogSearchFieldInstructions => 'Instrucciones';

  @override
  String get exerciseCatalogSearchFieldHashtags => 'Hashtags';

  @override
  String get exerciseCatalogSearchLabel => 'Buscar ejercicios';

  @override
  String get exerciseCatalogSearchHint =>
      'Escribe para buscar en el campo seleccionado';

  @override
  String get exerciseCatalogClearSearch => 'Borrar búsqueda';

  @override
  String get exerciseCatalogHideSearch => 'Ocultar búsqueda';

  @override
  String get navWeightControl => 'Control de peso';

  @override
  String get navShoppingList => 'Lista de la compra';

  @override
  String get navStartRegistration => 'Iniciar registro';

  @override
  String get navPreviewRegisteredUser => 'Ver como usuario registrado';

  @override
  String get navPreviewGuestUser => 'Ver como usuario no registrado';

  @override
  String get drawerGuestUser => 'Usuario invitado';

  @override
  String get drawerAdminUser => 'Usuario administrador';

  @override
  String get drawerPremiumPatientUser => 'Usuario paciente Premium';

  @override
  String get drawerPatientUser => 'Usuario paciente';

  @override
  String get drawerPremiumRegisteredUser => 'Usuario registrado Premium';

  @override
  String get drawerRegisteredUser => 'Usuario registrado';

  @override
  String get drawerPremiumBadge => 'PREMIUM';

  @override
  String get drawerRestrictedNutriPlansTitle => 'Planes nutricionales';

  @override
  String get drawerRestrictedTrainingTitle => 'Entrenamientos personalizados';

  @override
  String get drawerRestrictedRecommendationsTitle => 'Recomendaciones';

  @override
  String get drawerRegistrationRequiredTitle => 'Registro requerido';

  @override
  String get drawerRegistrationRequiredChatMessage =>
      'Para chatear con tu dietista online, por favor, regístrate (es gratis).';

  @override
  String get homePaymentNotifiedTitle => 'Pago notificado a NutriFit';

  @override
  String get homePaymentNotifiedMessage =>
      'Hemos recibido tu aviso de pago. Tu cuenta Premium se activará cuando NutriFit reciba y verifique el pago. Te avisaremos por email y por el chat de la app. El periodo Premium empezará a contar desde la fecha de verificación del pago.';

  @override
  String get homePremiumExpiredTitle => 'Tu Premium ha caducado';

  @override
  String get homePremiumExpiringTitle => 'Tu Premium está próximo a caducar';

  @override
  String homePremiumExpiredMessage(Object date) {
    return 'Tu Premium caducó el $date. Puedes renovarlo ahora.';
  }

  @override
  String homePremiumExpiringTodayMessage(Object date) {
    return 'Tu Premium vence el $date (hoy). Te recomendamos renovarlo para no perder ventajas.';
  }

  @override
  String homePremiumExpiringInDaysMessage(Object date, Object days) {
    return 'Tu Premium vence el $date (en $days días). Te recomendamos renovarlo para no perder ventajas.';
  }

  @override
  String get homeRenewPremium => 'Renovar Premium';

  @override
  String get homeSecurityRecommendedTitle => 'Seguridad recomendada';

  @override
  String get homeSecurityRecommendedBody =>
      'Trabajas con datos médicos sensibles. Te recomendamos activar el doble factor (2FA) para proteger mejor tu cuenta.';

  @override
  String get homeGoToEditProfile => 'Ir a editar perfil';

  @override
  String get homeDoNotShowAgain => 'No volver a mostrar';

  @override
  String get loginNetworkError =>
      'Hay algún problema con la conexión a Internet o la app no tiene permisos para conectarse.';

  @override
  String get loginInvalidCredentials => 'Usuario o contraseña incorrectos.';

  @override
  String get loginFailedGeneric =>
      'No se pudo completar el inicio de sesión. Inténtalo de nuevo.';

  @override
  String get loginGuestFailedGeneric =>
      'No se pudo acceder como invitado. Inténtalo de nuevo.';

  @override
  String get loginUnknownUserType => 'Tipo de usuario no reconocido';

  @override
  String get loginTwoFactorTitle => 'Verificación 2FA';

  @override
  String get loginTwoFactorPrompt =>
      'Introduce el código de 6 dígitos de tu aplicación TOTP.';

  @override
  String get loginTwoFactorCodeLabel => 'Código 2FA';

  @override
  String get loginTrustThisDevice => 'Confiar en este dispositivo';

  @override
  String get loginTrustThisDeviceSubtitle =>
      'No se volverá a solicitar 2FA en este dispositivo.';

  @override
  String get loginCodeMustHave6Digits => 'El código debe tener 6 dígitos.';

  @override
  String get loginRecoveryTitle => 'Recuperar acceso';

  @override
  String get loginRecoveryIdentifierIntro =>
      'Introduce tu usuario (nick) o tu cuenta de email para recuperar el acceso.';

  @override
  String get loginUserOrEmailLabel => 'Usuario o email';

  @override
  String get loginEnterUserOrEmail => 'Introduce usuario o email.';

  @override
  String get loginNoRecoveryMethods =>
      'Este usuario no tiene métodos de recuperación disponibles.';

  @override
  String get loginSelectRecoveryMethod => 'Selecciona método de recuperación';

  @override
  String get loginRecoveryByEmail => 'Mediante tu email';

  @override
  String get loginRecoveryByTwoFactor => 'Mediante doble factor (2FA)';

  @override
  String get loginEmailRecoveryIntro =>
      'Te enviaremos un código de recuperación por email. Introdúzcalo aquí junto con tu nueva contraseña.';

  @override
  String get loginRecoveryStep1SendCode => 'Paso 1: Enviar código';

  @override
  String get loginRecoveryStep1SendCodeBody =>
      'Pulsa en \"Enviar código\" para recibir un código de recuperación en tu email.';

  @override
  String get loginSendCode => 'Enviar código';

  @override
  String get loginRecoveryStep2VerifyCode => 'Paso 2: Verificar código';

  @override
  String get loginRecoveryStep2VerifyCodeBody =>
      'Introduce el código que recibiste en tu email.';

  @override
  String get loginRecoveryCodeLabel => 'Código de recuperación';

  @override
  String get loginRecoveryCodeHintAlpha => 'Ej. 1a3B';

  @override
  String get loginRecoveryCodeHintNumeric => 'Ej. 1234';

  @override
  String get loginVerifyCode => 'Verificar código';

  @override
  String get loginRecoveryStep3NewPassword => 'Paso 3: Nueva contraseña';

  @override
  String get loginRecoveryStep3NewPasswordBody =>
      'Introduce tu nueva contraseña.';

  @override
  String get loginNewPasswordLabel => 'Nueva contraseña';

  @override
  String get loginRepeatNewPasswordLabel => 'Repetir nueva contraseña';

  @override
  String get loginBothPasswordsRequired =>
      'Completa ambos campos de contraseña.';

  @override
  String get loginPasswordsMismatch => 'Las contraseñas no coinciden.';

  @override
  String get loginPasswordResetSuccess =>
      'Contraseña restablecida. Ya puedes iniciar sesión.';

  @override
  String get loginTwoFactorRecoveryIntro =>
      'Para restablecer tu contraseña con doble factor de autenticación, necesitas el código temporal de tu app.';

  @override
  String get loginTwoFactorRecoveryStep1 =>
      'Paso 1: Abre tu app de autenticación';

  @override
  String get loginTwoFactorRecoveryStep1Body =>
      'Busca el código temporal de 6 dígitos en tu app de autenticación (Google Authenticator, Microsoft Authenticator, Authy, etc.)';

  @override
  String get loginIHaveIt => 'Ya lo tengo';

  @override
  String get loginTwoFactorRecoveryStep2 => 'Paso 2: Verifica tu código 2FA';

  @override
  String get loginTwoFactorRecoveryStep2Body =>
      'Introduce el código de 6 dígitos en el campo de abajo.';

  @override
  String get loginTwoFactorCodeSixDigitsLabel => 'Código 2FA (6 dígitos)';

  @override
  String get loginTwoFactorCodeHint => '000000';

  @override
  String get loginVerifyTwoFactorCode => 'Verificar código 2FA';

  @override
  String get loginCodeMustHaveExactly6Digits =>
      'El código debe tener exactamente 6 dígitos.';

  @override
  String get loginPasswordUpdatedSuccess =>
      'Contraseña actualizada. Ya puedes iniciar sesión.';

  @override
  String get loginUsernameLabel => 'Usuario';

  @override
  String get loginEnterUsername => 'Introduce tu usuario';

  @override
  String get loginPasswordLabel => 'Contraseña';

  @override
  String get loginEnterPassword => 'Introduce tu contraseña';

  @override
  String get loginSignIn => 'Iniciar Sesión';

  @override
  String get loginForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get loginGuestInfo =>
      'Accede a NutriFit gratis para consultar consejos de salud, de nutrición, vídeos de ejercicios, recetas de cocina, control de peso y mucho más.';

  @override
  String get loginGuestAccess => 'Acceder sin credenciales';

  @override
  String get loginRegisterFree => 'Regístrate gratis';

  @override
  String get registerCreateAccountTitle => 'Crear cuenta';

  @override
  String get registerFullNameLabel => 'Nombre completo';

  @override
  String get registerEnterFullName => 'Introduce tu nombre';

  @override
  String get registerUsernameMinLength =>
      'El usuario debe tener al menos 3 caracteres';

  @override
  String get registerEmailLabel => 'Email';

  @override
  String get registerInvalidEmail => 'Email no válido';

  @override
  String get registerAdditionalDataTitle => 'Datos adicionales';

  @override
  String get registerAdditionalDataCollapsedSubtitle =>
      'Edad y altura (no obligatorios)';

  @override
  String get registerAdditionalDataExpandedSubtitle =>
      'Edad y altura para IMC/MVP';

  @override
  String get registerAdditionalDataInfo =>
      'Para habilitar el cálculo de IMC, MVP y métricas de salud, indica edad y altura (en centímetros).';

  @override
  String get registerAgeLabel => 'Edad';

  @override
  String get registerInvalidAge => 'Edad no válida';

  @override
  String get registerHeightLabel => 'Altura (cm)';

  @override
  String get registerInvalidHeight => 'Altura no válida';

  @override
  String get registerConfirmPasswordLabel => 'Confirmar contraseña';

  @override
  String get registerConfirmPasswordRequired => 'Confirma tu contraseña';

  @override
  String get registerCreateAccountButton => 'Crear cuenta';

  @override
  String get registerAlreadyHaveAccount => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get registerEmailUnavailable =>
      'Esta cuenta de email no puede usarse, indica otra.';

  @override
  String get registerSuccessMessage =>
      'Usuario registrado correctamente. Por favor, inicia sesión con tus datos (usuario y contraseña).';

  @override
  String get registerNetworkError =>
      'No se ha podido realizar el proceso. Revisa la conexión a Internet.';

  @override
  String get registerGenericError => 'Error al registrarse';

  @override
  String get loginResetPassword => 'Restablecer contraseña';

  @override
  String get loginEmailRecoverySendFailedGeneric =>
      'No se ha podido enviar el email de recuperación en este momento, inténtelo más tarde.';

  @override
  String get passwordChecklistTitle => 'Requisitos de contraseña:';

  @override
  String passwordChecklistMinLength(Object count) {
    return 'Mínimo $count caracteres';
  }

  @override
  String get passwordChecklistUpperLower =>
      'Al menos una mayúscula y una minúscula';

  @override
  String get passwordChecklistNumber => 'Al menos un número (0-9)';

  @override
  String get passwordChecklistSpecial =>
      'Al menos un carácter especial (*,.+-#\\\$?¿!¡_()/\\%&)';

  @override
  String loginPasswordMinLengthError(Object count) {
    return 'La nueva contraseña debe tener al menos $count caracteres.';
  }

  @override
  String get loginPasswordUppercaseError =>
      'La nueva contraseña debe contener al menos una letra mayúscula.';

  @override
  String get loginPasswordLowercaseError =>
      'La nueva contraseña debe contener al menos una letra minúscula.';

  @override
  String get loginPasswordNumberError =>
      'La nueva contraseña debe contener al menos un número.';

  @override
  String get loginPasswordSpecialError =>
      'La nueva contraseña debe contener al menos un carácter especial (* , . + - # \\\$ ? ¿ ! ¡ _ ( ) / \\ % &).';

  @override
  String get commonOk => 'OK';

  @override
  String get commonReadMore => 'Leer más';

  @override
  String get commonViewAll => 'Ver todos';

  @override
  String get commonCouldNotOpenLink => 'No se pudo abrir el enlace';

  @override
  String get commonCollapse => 'Plegar';

  @override
  String get commonExpand => 'Desplegar';

  @override
  String get patientSecurityRecommendedTitle =>
      'Mejora la seguridad de tu cuenta';

  @override
  String get patientSecurityRecommendedBody =>
      'Te recomendamos activar el doble factor (2FA). Añade una capa extra de protección además de tu contraseña.';

  @override
  String get patientChatLoadError =>
      'No se ha podido realizar el proceso. Revise la conexión a Internet';

  @override
  String get patientAdherenceNutriPlan => 'Plan nutricional';

  @override
  String get patientAdherenceFitPlan => 'Plan Fit';

  @override
  String get patientAdherenceCompleted => 'Cumplido';

  @override
  String get patientAdherencePartial => 'Parcial';

  @override
  String get patientAdherenceNotDone => 'No realizado';

  @override
  String get patientAdherenceNoChanges => 'Sin cambios';

  @override
  String patientAdherenceTrendPoints(Object trend) {
    return '$trend pts';
  }

  @override
  String get patientAdherenceTitle => 'Cumplimiento';

  @override
  String get patientAdherenceImprovementPoints => 'Puntos de mejora';

  @override
  String get patientAdherenceImprovementNutriTarget =>
      'Nutri: intenta cumplir al menos 5 de 7 días esta semana.';

  @override
  String get patientAdherenceImprovementNutriTrend =>
      'Nutri: vas a la baja frente a la semana pasada; vuelve a tu rutina base.';

  @override
  String get patientAdherenceImprovementFitTarget =>
      'Fit: intenta llegar a 3-4 sesiones semanales, aunque sean cortas.';

  @override
  String get patientAdherenceImprovementFitTrend =>
      'Fit: la tendencia ha bajado; agenda tus próximas sesiones hoy.';

  @override
  String get patientAdherenceImprovementKeepGoing =>
      'Buen ritmo. Mantén la constancia para consolidar resultados.';

  @override
  String get patientAdherenceSheetTitleToday => 'Cumplimiento para hoy';

  @override
  String patientAdherenceSheetTitleForDate(Object date) {
    return 'Cumplimiento para $date';
  }

  @override
  String get patientAdherenceDateToday => 'hoy';

  @override
  String patientAdherenceStatusSaved(Object plan, Object status, Object date) {
    return '$plan: $status $date';
  }

  @override
  String get patientAdherenceFutureDateError =>
      'No se puede registrar cumplimiento en fechas futuras. Solo hoy o días anteriores.';

  @override
  String get patientAdherenceReasonNotDoneTitle => 'Motivo de no realización';

  @override
  String get patientAdherenceReasonPartialTitle =>
      'Motivo de cumplimiento parcial';

  @override
  String get patientAdherenceReasonHint => 'Cuéntanos brevemente qué pasó hoy';

  @override
  String get patientAdherenceSkipReason => 'Omitir motivo';

  @override
  String get patientAdherenceSaveContinue => 'Guardar y continuar';

  @override
  String patientAdherenceSaveError(Object error) {
    return 'No se pudo guardar en la base de datos: $error';
  }

  @override
  String get patientAdherenceReasonLabel => 'Motivo';

  @override
  String get patientAdherenceInfoTitle =>
      '¿Qué significa cada estado de cumplimiento?';

  @override
  String get patientAdherenceNutriCompletedDescription =>
      'Seguiste el plan de alimentación tal como estaba previsto para este día.';

  @override
  String get patientAdherenceNutriPartialDescription =>
      'Seguiste parte del plan pero no completamente: alguna comida omitida, cambiada o con cantidad distinta.';

  @override
  String get patientAdherenceNutriNotDoneDescription =>
      'No seguiste el plan de alimentación en este día.';

  @override
  String get patientAdherenceFitCompletedDescription =>
      'Realizaste el entrenamiento completo previsto para este día.';

  @override
  String get patientAdherenceFitPartialDescription =>
      'Hiciste parte del entrenamiento: algunos ejercicios, series o tiempo incompleto.';

  @override
  String get patientAdherenceFitNotDoneDescription =>
      'No realizaste el entrenamiento en este día.';

  @override
  String get patientAdherenceAlertRecoveryTitle => 'Vamos a reaccionar';

  @override
  String patientAdherenceAlertRecoveryBody(Object plan) {
    return 'Llevas dos semanas seguidas por debajo del 50% en $plan. Vamos a recuperar el ritmo ya: pequeños pasos diarios, pero sin fallar. Tú puedes, pero toca ponerse serio.';
  }

  @override
  String get patientAdherenceAlertEncouragementTitle => 'Aún estamos a tiempo';

  @override
  String patientAdherenceAlertEncouragementBody(Object plan) {
    return 'Esta semana $plan va por debajo del 50%. La próxima puede ser mucho mejor: vuelve a tu rutina base y suma una victoria cada día.';
  }

  @override
  String get patientRecommendationsForYou => 'Recomendaciones para ti';

  @override
  String get patientWelcomeNeutral => 'Bienvenid@';

  @override
  String get patientWelcomeFemale => 'Bienvenida';

  @override
  String get patientWelcomeMale => 'Bienvenido';

  @override
  String patientWelcomeToNutriFit(Object welcome) {
    return '$welcome a NutriFit';
  }

  @override
  String get patientWelcomeBody =>
      'Desde NutriFit podrás consultar tus planes nutricionales y de entrenamiento personalizados. Podrás chatear y contactar con tu dietista online y leer recomendaciones personalizadas. \n\nDispones de Consejos de nutrición y salud, Recetas de cocina, lista de la compra, información de alimentos, mediciones (control de peso), presión arterial y muchas otras cosas...';

  @override
  String get patientPersonalRecommendation => 'Recomendación personal';

  @override
  String get patientNewBadge => 'NUEVO';

  @override
  String get patientContactDietitianPrompt => 'Contactar con el dietista...';

  @override
  String get patientContactDietitianTrainer =>
      'Contactar con Dietista/Entrenador';

  @override
  String get contactDietitianMethodsTitle => 'Formas de contacto';

  @override
  String get contactDietitianEmailLabel => 'Email';

  @override
  String get contactDietitianCallLabel => 'Llamar';

  @override
  String get contactDietitianSocialTitle => 'Síguenos en redes sociales';

  @override
  String get contactDietitianWebsiteLabel => 'Sitio web';

  @override
  String get contactDietitianPhoneCopied => 'Teléfono copiado al portapapeles.';

  @override
  String get contactDietitianWhatsappInvalidPhone =>
      'No hay un teléfono válido para abrir WhatsApp.';

  @override
  String contactDietitianWhatsappOpenError(Object error) {
    return 'No se pudo abrir WhatsApp: $error';
  }

  @override
  String get contactDietitianWhatsappDialogTitle => 'Contactar por WhatsApp';

  @override
  String contactDietitianWhatsappDialogBody(Object phone) {
    return 'Puedes abrir el chat de WhatsApp directamente con el número $phone. También puedes copiar el número al portapapeles para usarlo en tu aplicación de WhatsApp o para guardarlo.';
  }

  @override
  String get contactDietitianCopyPhone => 'Copiar teléfono';

  @override
  String get contactDietitianOpenWhatsapp => 'Abrir WhatsApp';

  @override
  String get contactDietitianWhatsappLabel => 'WhatsApp';

  @override
  String get contactDietitianTelegramLabel => 'Telegram';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatHideSearch => 'Ocultar búsqueda';

  @override
  String get chatSearch => 'Buscar';

  @override
  String get chatSearchHint => 'Buscar en el chat...';

  @override
  String get chatMessageHint => 'Escribe un mensaje';

  @override
  String get profileImagePickerDialogTitle => 'Seleccionar imagen de perfil';

  @override
  String get profileImagePickerTakePhoto => 'Tomar foto';

  @override
  String get profileImagePickerChooseFromGallery => 'Elegir de galería';

  @override
  String get profileImagePickerSelectImage => 'Seleccionar imagen';

  @override
  String get profileImagePickerRemovePhoto => 'Eliminar foto';

  @override
  String get profileImagePickerPrompt => 'Selecciona tu imagen de perfil';

  @override
  String profileImagePickerMaxDimensions(Object width, Object height) {
    return 'Máx. ${width}x${height}px';
  }

  @override
  String profileImagePickerSaved(Object sizeKb) {
    return 'Imagen guardada correctamente (${sizeKb}KB)';
  }

  @override
  String get profileImagePickerProcessError => 'Error al procesar la imagen';

  @override
  String get profileImagePickerTechnicalDetails => 'Detalles técnicos';

  @override
  String get profileImagePickerOperationFailed =>
      'No se ha podido completar la operación. Por favor, inténtalo de nuevo o contacta con soporte.';

  @override
  String get shoppingListPremiumTitle => 'Lista de la compra Premium';

  @override
  String shoppingListPremiumSubtitle(Object limit) {
    return 'Puedes consultar los $limit últimos items y crear hasta $limit registros. Si quieres una lista ilimitada, ';
  }

  @override
  String get shoppingListPremiumHighlight => 'hazte Premium.';

  @override
  String shoppingListPremiumLimitMessage(Object limit) {
    return 'Como usuario no Premium puedes crear hasta $limit items en la lista de la compra. Hazte Premium para añadir items ilimitados y consultar todo el histórico.';
  }

  @override
  String get shoppingListTabAll => 'Todos';

  @override
  String get shoppingListTabPending => 'Próxima compra';

  @override
  String get shoppingListTabBought => 'Comprados';

  @override
  String get shoppingListTabExpiring => 'Por caducar';

  @override
  String get shoppingListTabExpired => 'Caducados';

  @override
  String get shoppingListFilterCategories => 'Filtrar categorías';

  @override
  String shoppingListFilterCategoriesCount(Object count) {
    return 'Filtrar categorías ($count)';
  }

  @override
  String get shoppingListMoreOptions => 'Más opciones';

  @override
  String get shoppingListFilter => 'Filtrar';

  @override
  String get shoppingListRefresh => 'Actualizar';

  @override
  String get shoppingListAddItem => 'Añadir item';

  @override
  String get shoppingListGuestMessage =>
      'Para poder usar la Lista de la compra, debes registrarte (es gratis).';

  @override
  String get weightControlBack => 'Volver';

  @override
  String get weightControlChangeTarget => 'Cambiar peso objetivo';

  @override
  String get weightControlHideFilter => 'Ocultar filtro';

  @override
  String get weightControlShowFilter => 'Mostrar filtro';

  @override
  String get weightControlGuestMessage =>
      'Para poder gestionar tu control de pesos debes registrarte (es gratis).';

  @override
  String weightControlLoadError(Object error) {
    return 'Error cargando mediciones: $error';
  }

  @override
  String get weightControlNoMeasurementsTitle =>
      'Todavía no hay mediciones registradas.';

  @override
  String get weightControlNoMeasurementsBody =>
      'Empieza añadiendo tu primera medición para ver tu evolución.';

  @override
  String get weightControlAddMeasurement => 'Añadir medición';

  @override
  String weightControlNoWeightsForPeriod(Object period) {
    return 'No hay pesos para $period.';
  }

  @override
  String weightControlNoMeasurementsForPeriod(Object period) {
    return 'No hay mediciones para $period.';
  }

  @override
  String get weightControlPremiumPerimetersTitle =>
      'Evolución de perímetros Premium';

  @override
  String get weightControlPremiumChartBody =>
      'Esta gráfica está disponible solo para usuarios Premium. Activa tu cuenta para ver tu evolución completa con indicadores visuales avanzados.';

  @override
  String get weightControlCurrentMonth => 'Mes actual';

  @override
  String get weightControlPreviousMonth => 'Mes anterior';

  @override
  String get weightControlQuarter => 'Trimestre';

  @override
  String get weightControlSemester => 'Semestre';

  @override
  String get weightControlCurrentYear => 'Año';

  @override
  String get weightControlPreviousYear => 'Año anterior';

  @override
  String get weightControlAllTime => 'Siempre';

  @override
  String weightControlLastDaysLabel(Object days) {
    return 'Últimos $days días';
  }

  @override
  String get patientMoreContactOptions => 'Más formas de contacto';

  @override
  String get patientContactEmailShort => 'Email...';

  @override
  String get patientContactWhatsAppShort => 'WhatsApp...';

  @override
  String get patientContactTelegramShort => 'Telegram...';

  @override
  String get patientContactEmailSubject =>
      'Solicitud de servicios de Nutricionista Online';

  @override
  String get patientAddDietitianToContactsTitle =>
      'Agregar dietista a contactos';

  @override
  String get patientAddDietitianToContactsBody =>
      'Por favor, agrega al dietista manualmente a tus contactos con los siguientes datos:\n\nNombre: Dietista Online - NutriFit';

  @override
  String patientViewAllTipsCount(Object count) {
    return 'Ver todos los consejos ($count)';
  }

  @override
  String get settingsNotificationsTab => 'Notificaciones';

  @override
  String get settingsLegendsTab => 'Leyendas';

  @override
  String get settingsCalendarsTab => 'Calendarios';

  @override
  String get settingsPushPreferenceSaveError =>
      'No se pudo guardar la preferencia de notificaciones push.';

  @override
  String get settingsScannerFrameReset =>
      'Recuadro de escaneo restablecido a valores por defecto';

  @override
  String settingsCurrentView(Object mode) {
    return 'Vista actual: $mode';
  }

  @override
  String get settingsCalendarModeWeek => 'Semana';

  @override
  String get settingsCalendarModeMonth => 'Mes';

  @override
  String get settingsCalendarModeTwoWeeks => '2 semanas';

  @override
  String get settingsNutriBreachTitle => 'Avisos de incumplimiento Plan Nutri';

  @override
  String get settingsNutriBreachSubtitle =>
      'Recibir notificaciones cuando no se cumpla el plan nutricional.';

  @override
  String get settingsFitBreachTitle => 'Avisos de incumplimiento Plan Fit';

  @override
  String get settingsFitBreachSubtitle =>
      'Recibir notificaciones cuando no se cumpla el plan de entrenamiento.';

  @override
  String get settingsChatPushTitle => 'Activar notificaciones push de chat';

  @override
  String get settingsChatPushSubtitle =>
      'Recibir notificaciones push cuando tengas mensajes sin leer del dietista.';

  @override
  String get settingsPerimetersLegendTitle => 'Evolución de perímetros';

  @override
  String get settingsPerimetersLegendSubtitle =>
      'Muestra u oculta la leyenda en la gráfica de evolución de perímetros.';

  @override
  String get settingsWeightCalendarLegendTitle =>
      'Calendario de control de pesos';

  @override
  String get settingsWeightCalendarLegendSubtitle =>
      'Muestra u oculta la leyenda del calendario de control de pesos (adelgazó, engordó, sin cambios, IMC normal, IMC fuera de rango y superior peso/inferior IMC).';

  @override
  String get settingsTasksCalendarLegendTitle => 'Calendario de tareas';

  @override
  String get settingsTasksCalendarLegendSubtitle =>
      'Leyenda futura. Próximamente se aplicará esta preferencia al calendario de tareas.';

  @override
  String get settingsTasksCalendarTitle => 'Calendario de tareas';

  @override
  String get settingsWeightControlCalendarTitle =>
      'Calendario de mediciones (control de peso)';

  @override
  String get settingsNutriCalendarTitle => 'Calendario Planes Nutri';

  @override
  String get settingsFitCalendarTitle => 'Calendario Planes Fit';

  @override
  String get settingsShowActivityEquivalencesTitle =>
      'Mostrar equivalencias en actividades';

  @override
  String get settingsShowActivityEquivalencesSubtitle =>
      'Activa o desactiva los mensajes de equivalencias en la pantalla de actividades.';

  @override
  String get settingsScannerFrameWidthTitle => 'Ancho del recuadro de escaneo';

  @override
  String get settingsScannerFrameWidthSubtitle =>
      'Se aplica al hacer foto en escanear etiquetas y en lista de la compra.';

  @override
  String get settingsScannerFrameHeightTitle => 'Alto del recuadro de escaneo';

  @override
  String get settingsScannerFrameHeightSubtitle =>
      'Ajusta la altura del area a encuadrar para el codigo de barras.';

  @override
  String get settingsResetScannerFrameSize => 'Restablecer tamaño';

  @override
  String get commonPremiumFeatureTitle => 'Función Premium';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonFilter => 'Filtrar';

  @override
  String get commonRefresh => 'Actualizar';

  @override
  String get commonMoreOptions => 'Más opciones';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonClear => 'Limpiar';

  @override
  String get commonApply => 'Aplicar';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonGeneratePdf => 'Generar PDF';

  @override
  String get commonHideSearch => 'Ocultar búsqueda';

  @override
  String get commonFilterByCategories => 'Filtrar por categorías';

  @override
  String commonFilterByCategoriesCount(Object count) {
    return 'Filtrar categorías ($count)';
  }

  @override
  String get commonMatchAll => 'Coincidir todas';

  @override
  String get commonRequireAllSelected => 'Si está activo, requiere todas.';

  @override
  String commonCategoryFallback(Object id) {
    return 'Categoría $id';
  }

  @override
  String get commonSignInToLike => 'Debes iniciar sesión para dar me gusta';

  @override
  String get commonSignInToSaveFavorites =>
      'Debes iniciar sesión para guardar favoritos';

  @override
  String get commonCouldNotIdentifyUser =>
      'Error: No se pudo identificar el usuario';

  @override
  String commonLikeChangeError(Object error) {
    return 'Error al cambiar me gusta. $error';
  }

  @override
  String commonFavoriteChangeError(Object error) {
    return 'Error al cambiar favorito. $error';
  }

  @override
  String commonGuestFavoritesRequiresRegistration(Object itemType) {
    return 'Para poder marcar $itemType como favoritos, debes registrarte (es gratis).';
  }

  @override
  String get commonRecipesAndTipsPremiumCopyPdfMessage =>
      'Para poder copiar y pasar a PDF las recetas y consejos, debes ser usuario Premium.';

  @override
  String get commonCopiedToClipboard => 'Copiado al portapapeles';

  @override
  String commonCopiedToClipboardLabel(Object label) {
    return '$label copiado al portapapeles.';
  }

  @override
  String get commonLanguage => 'Idioma';

  @override
  String get commonUser => 'usuario';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageGerman => 'Alemán';

  @override
  String get languageFrench => 'Francés';

  @override
  String get languagePortuguese => 'Portugués';

  @override
  String commonCopyError(Object error) {
    return 'Error al copiar: $error';
  }

  @override
  String commonGeneratePdfError(Object error) {
    return 'Error al generar PDF: $error';
  }

  @override
  String commonOpenLinkError(Object error) {
    return 'Error al abrir enlace: $error';
  }

  @override
  String get commonDocumentUnavailable => 'El documento no está disponible';

  @override
  String commonDecodeError(Object error) {
    return 'Error al decodificar: $error';
  }

  @override
  String get commonSaveDocumentError =>
      'Error: No se pudo guardar el documento';

  @override
  String commonOpenDocumentError(Object error) {
    return 'Error al abrir documento: $error';
  }

  @override
  String get commonDownloadDocument => 'Descargar documento';

  @override
  String get commonDocumentsAndLinks => 'Documentos y enlaces';

  @override
  String get commonYouMayAlsoLike => 'También te puede interesar...';

  @override
  String get commonSortByTitle => 'Ordenar Título';

  @override
  String get commonSortByRecent => 'Ordenar Recientes';

  @override
  String get commonSortByPopular => 'Ordenar Populares';

  @override
  String get commonPersonalTab => 'Personales';

  @override
  String get commonFeaturedTab => 'Destacados';

  @override
  String get commonAllTab => 'Todos';

  @override
  String get commonFavoritesTab => 'Favoritos';

  @override
  String get commonFeaturedFeminineTab => 'Destacadas';

  @override
  String get commonAllFeminineTab => 'Todas';

  @override
  String get commonFavoritesFeminineTab => 'Favoritas';

  @override
  String commonLikesCount(Object count) {
    return '$count me gusta';
  }

  @override
  String get commonLink => 'Enlace';

  @override
  String get commonTipItem => 'consejo';

  @override
  String get commonRecipeItem => 'receta';

  @override
  String get commonAdditiveItem => 'aditivo';

  @override
  String get commonSupplementItem => 'suplemento';

  @override
  String commonSeeLinkToType(Object type) {
    return 'Véase enlace a $type';
  }

  @override
  String get commonDocument => 'Documento';

  @override
  String get todoPriorityHigh => 'Alta';

  @override
  String get todoPriorityMedium => 'Media';

  @override
  String get todoPriorityLow => 'Baja';

  @override
  String get todoStatusPending => 'Pendiente';

  @override
  String get todoStatusResolved => 'Resuelta';

  @override
  String todoCalendarPriority(Object value) {
    return 'Prioridad: $value';
  }

  @override
  String todoCalendarStatus(Object value) {
    return 'Estado: $value';
  }

  @override
  String todoExportError(Object error) {
    return 'Error al exportar la tarea: $error';
  }

  @override
  String get todoDateRequiredForCalendar =>
      'La tarea debe tener fecha para añadirla al calendario';

  @override
  String todoAddToCalendarError(Object error) {
    return 'No se pudo añadir la tarea al calendario: $error';
  }

  @override
  String todoPremiumLimitMessage(int limit) {
    return 'Como usuario no Premium puedes crear hasta $limit tareas. Hazte Premium para añadir tareas ilimitadas y consultar todo el histórico.';
  }

  @override
  String get todoNoDate => 'Sin fecha';

  @override
  String get todoPriorityHighTooltip => 'Prioridad alta';

  @override
  String get todoPriorityMediumTooltip => 'Prioridad media';

  @override
  String get todoPriorityLowTooltip => 'Prioridad baja';

  @override
  String get todoStatusResolvedShort => 'Realizada (R)';

  @override
  String get todoStatusPendingShort => 'Pendiente (P)';

  @override
  String get todoMarkPending => 'Marcar pendiente';

  @override
  String get todoMarkResolved => 'Marcar resuelta';

  @override
  String get todoEditTaskTitle => 'Editar tarea';

  @override
  String get todoNewTaskTitle => 'Nueva tarea';

  @override
  String get todoTitleLabel => 'Título';

  @override
  String get todoTitleRequired => 'El título es obligatorio';

  @override
  String get todoDescriptionTitle => 'Descripción';

  @override
  String get todoDescriptionOptionalLabel => 'Descripción (opcional)';

  @override
  String get todoPriorityTitle => 'Prioridad';

  @override
  String get todoStatusTitle => 'Estado';

  @override
  String todoTasksForDay(Object date) {
    return 'Tareas del $date';
  }

  @override
  String get todoNewShort => 'Nueva';

  @override
  String get todoNoTasksSelectedDay =>
      'No hay tareas para el día seleccionado.';

  @override
  String get todoNoTasksToShow => 'No hay tareas para mostrar.';

  @override
  String get todoPremiumTitle => 'Tareas Premium';

  @override
  String todoPremiumPreviewSubtitle(int limit) {
    return 'Puedes consultar los $limit últimos registros y crear hasta $limit tareas. Si quieres tareas ilimitadas hazte Premium.';
  }

  @override
  String todoPremiumPreviewHighlight(int count) {
    return ' Actualmente tienes $count tareas registradas.';
  }

  @override
  String get todoEmptyState => 'Todavía no tienes tareas registradas.';

  @override
  String get todoScreenTitle => 'Tareas';

  @override
  String get todoTabPending => 'Pendientes';

  @override
  String get todoTabResolved => 'Resueltas';

  @override
  String get todoTabAll => 'Todas';

  @override
  String get todoHideFilters => 'Ocultar filtros';

  @override
  String get todoViewList => 'Ver lista';

  @override
  String get todoViewCalendar => 'Ver calendario';

  @override
  String get todoSortByDate => 'Ordenar Fecha';

  @override
  String get todoSortByPriority => 'Ordenar Prioridad';

  @override
  String get todoSearchHint => 'Buscar por título o descripción';

  @override
  String get todoClearSearch => 'Limpiar búsqueda';

  @override
  String get todoDeleteTitle => 'Eliminar tarea';

  @override
  String todoDeleteConfirm(Object title) {
    return '¿Deseas eliminar la tarea \"$title\"?';
  }

  @override
  String get todoDeletedSuccess => 'Tarea eliminada correctamente';

  @override
  String get todoAddToDeviceCalendar => 'Añadir al calendario del dispositivo';

  @override
  String get todoEditAction => 'Editar';

  @override
  String get todoSelectDate => 'Seleccionar fecha';

  @override
  String get todoRemoveDate => 'Quitar fecha';

  @override
  String get todoGuestTitle => 'Registro requerido';

  @override
  String get todoGuestBody =>
      'Para poder usar Tareas, debes registrarte (es gratis).';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonSortByName => 'Ordenar Nombre';

  @override
  String get commonSortByType => 'Ordenar Tipo';

  @override
  String get commonSortByDate => 'Ordenar Fecha';

  @override
  String get commonSortBySeverity => 'Ordenar Peligrosidad';

  @override
  String get commonName => 'Nombre';

  @override
  String get commonTitleField => 'Título';

  @override
  String get commonDescriptionField => 'Descripción';

  @override
  String get commonTypeField => 'Tipo';

  @override
  String get commonSeverity => 'Peligrosidad';

  @override
  String commonNoResultsForQuery(Object query) {
    return 'Sin resultados para \"$query\"';
  }

  @override
  String get tipsPremiumToolsMessage =>
      'La búsqueda, filtros, favoritos, me gusta y el acceso completo al catálogo de consejos están disponibles solo para usuarios Premium.';

  @override
  String get tipsPremiumPreviewTitle => 'Consejos Premium';

  @override
  String get tipsPremiumPreviewSubtitle =>
      'Puedes ver una vista previa con los 3 últimos consejos. Hazte Premium para acceder al catálogo completo y a todas sus herramientas.';

  @override
  String tipsPreviewAvailableCount(Object count) {
    return ' Actualmente hay $count consejos disponibles.';
  }

  @override
  String get tipsSearchLabel => 'Buscar consejos';

  @override
  String get tipsNoPersonalizedRecommendations =>
      'No tiene recomendaciones personalizadas';

  @override
  String get tipsViewGeneralTips => 'Ver consejos generales';

  @override
  String get tipsUnreadBadge => 'No leído';

  @override
  String get messagesInboxTitle => 'Mensajes sin leer';

  @override
  String get messagesInboxGuestBody =>
      'Para chatear con tu dietista online, por favor, regístrate (es gratis).';

  @override
  String get messagesInboxGuestAction => 'Iniciar registro';

  @override
  String get messagesInboxUnreadChats => 'Chats sin leer';

  @override
  String get messagesInboxNoPendingChats => 'No hay chats pendientes.';

  @override
  String get messagesInboxUser => 'Usuario';

  @override
  String get messagesInboxImage => 'Imagen';

  @override
  String get messagesInboxNoMessages => 'Sin mensajes';

  @override
  String get messagesInboxPendingExerciseFeelings =>
      'Sensaciones de ejercicios pendientes';

  @override
  String get messagesInboxNoPendingExerciseFeelings =>
      'No hay sensaciones de ejercicios pendientes.';

  @override
  String get messagesInboxViewPendingExerciseFeelings =>
      'Ver sensaciones de ejercicios pendientes';

  @override
  String get messagesInboxUnreadDietitianChats => 'Chats con dietista sin leer';

  @override
  String get messagesInboxOpenDietitianChat => 'Abrir chat con dietista';

  @override
  String get messagesInboxMessage => 'Mensaje';

  @override
  String get messagesInboxDietitianMessage => 'Mensaje de dietista';

  @override
  String get messagesInboxUnreadCoachComments =>
      'Comentarios de entrenador sin leer';

  @override
  String get messagesInboxNoUnreadCoachComments =>
      'No tienes comentarios de entrenador personal pendientes de leer.';

  @override
  String get messagesInboxViewPendingComments => 'Ver comentarios pendientes';

  @override
  String messagesInboxLoadError(Object error) {
    return 'Error al cargar mensajes: $error';
  }

  @override
  String get tipsNoFeaturedAvailable => 'No hay consejos destacados';

  @override
  String get tipsNoTipsAvailable => 'No hay consejos disponibles';

  @override
  String get tipsNoFavoriteTips => 'No tienes consejos favoritos';

  @override
  String get tipsDetailTitle => 'Detalle del Consejo';

  @override
  String get tipsPreviewBanner =>
      'Vista Previa - Así verán el consejo los usuarios';

  @override
  String tipsHashtagTitle(Object hashtag) {
    return 'Consejos con $hashtag';
  }

  @override
  String tipsHashtagEmpty(Object hashtag) {
    return 'No hay consejos con $hashtag';
  }

  @override
  String tipsLoadErrorStatus(Object statusCode) {
    return 'Error al cargar consejos: $statusCode';
  }

  @override
  String tipsLoadError(Object error) {
    return 'Error al cargar consejos. $error';
  }

  @override
  String get recipesPremiumToolsMessage =>
      'La búsqueda, filtros, favoritos, me gusta y el acceso completo al catálogo de recetas están disponibles solo para usuarios Premium.';

  @override
  String get recipesPremiumPreviewTitle => 'Recetas Premium';

  @override
  String get recipesPremiumPreviewSubtitle =>
      'Puedes ver una vista previa con las 3 últimas recetas. Hazte Premium para acceder al catálogo completo y a todas sus herramientas.';

  @override
  String recipesPreviewAvailableCount(Object count) {
    return ' Actualmente hay $count recetas disponibles.';
  }

  @override
  String get recipesSearchLabel => 'Buscar recetas';

  @override
  String get recipesNoFeaturedAvailable => 'No hay recetas destacadas';

  @override
  String get recipesNoRecipesAvailable => 'No hay recetas disponibles';

  @override
  String get recipesNoFavoriteRecipes => 'No tienes recetas favoritas';

  @override
  String get recipesDetailTitle => 'Detalle de la Receta';

  @override
  String get recipesPreviewBanner =>
      'Vista Previa - Así verán la receta los usuarios';

  @override
  String recipesHashtagTitle(Object hashtag) {
    return 'Recetas con $hashtag';
  }

  @override
  String recipesHashtagEmpty(Object hashtag) {
    return 'No hay recetas con $hashtag';
  }

  @override
  String get additivesPremiumCopyPdfMessage =>
      'Para poder copiar y pasar a PDF un aditivo, debes ser usuario Premium.';

  @override
  String get additivesPremiumExploreMessage =>
      'Los hashtags y las recomendaciones de aditivos están disponibles solo para usuarios Premium.';

  @override
  String get additivesPremiumToolsMessage =>
      'La búsqueda, filtros, actualización y ordenación completa del catálogo de aditivos están disponibles solo para usuarios Premium.';

  @override
  String get additivesFilterTitle => 'Filtrar aditivos';

  @override
  String get additivesNoConfiguredTypes =>
      'No hay tipos configurados en tipos_aditivos.';

  @override
  String get additivesTypesLabel => 'Tipos';

  @override
  String get additivesSearchHint => 'Buscar aditivos';

  @override
  String get additivesEmpty => 'No hay aditivos disponibles';

  @override
  String get additivesPremiumTitle => 'Aditivos Premium';

  @override
  String get additivesPremiumSubtitle =>
      'El catálogo completo de aditivos está disponible solo para usuarios Premium.';

  @override
  String additivesCatalogHighlight(Object count) {
    return ' (con más de $count aditivos)';
  }

  @override
  String get additivesLoadFailed => 'No se pudieron cargar los aditivos.';

  @override
  String get additivesCatalogUnavailable =>
      'El catálogo de aditivos no está disponible temporalmente. Inténtalo más tarde.';

  @override
  String get additivesServerConnectionError =>
      'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get additivesSeveritySafe => 'Seguro';

  @override
  String get additivesSeverityAttention => 'Atención';

  @override
  String get additivesSeverityHigh => 'Alto';

  @override
  String get additivesSeverityRestricted => 'Restringido';

  @override
  String get additivesSeverityForbidden => 'Prohibido';

  @override
  String get substitutionsPremiumToolsMessage =>
      'La búsqueda, filtros, favoritos y ordenación completa de sustituciones saludables están disponibles solo para usuarios Premium.';

  @override
  String get substitutionsPremiumCopyPdfMessage =>
      'Para poder copiar y pasar a PDF una sustitución saludable, debes ser usuario Premium.';

  @override
  String get substitutionsPremiumExploreMessage =>
      'Los hashtags, categorías, recomendaciones y navegación avanzada de sustituciones saludables están disponibles solo para usuarios Premium.';

  @override
  String get substitutionsPremiumEngagementMessage =>
      'Los favoritos y los me gusta de sustituciones saludables están disponibles solo para usuarios Premium.';

  @override
  String get substitutionsSearchLabel => 'Buscar sustituciones o hashtags';

  @override
  String get substitutionsEmptyFeatured => 'No hay sustituciones destacadas.';

  @override
  String get substitutionsEmptyAll => 'No hay sustituciones disponibles.';

  @override
  String get substitutionsEmptyFavorites =>
      'No tienes sustituciones favoritas todavía.';

  @override
  String get substitutionsPremiumTitle => 'Sustituciones Premium';

  @override
  String get substitutionsPremiumSubtitle =>
      'La biblioteca completa de sustituciones saludables está disponible solo para usuarios Premium.';

  @override
  String substitutionsCatalogHighlight(Object count) {
    return ' (con más de $count sustituciones)';
  }

  @override
  String get substitutionsDefaultBadge => 'Sustitución premium';

  @override
  String get substitutionsTapForDetail => 'Toca para ver el detalle completo';

  @override
  String get substitutionsDetailTitle => 'Sustitución saludable';

  @override
  String get substitutionsRecommendedChange => 'Cambio recomendado';

  @override
  String get substitutionsIfUnavailable => 'Si no tienes';

  @override
  String get substitutionsUse => 'Usa';

  @override
  String get substitutionsEquivalence => 'Equivalencia';

  @override
  String get substitutionsGoal => 'Objetivo';

  @override
  String get substitutionsNotesContext => 'Sustitución saludable';

  @override
  String get commonExport => 'Exportar';

  @override
  String get commonImport => 'Importar';

  @override
  String get commonPhoto => 'Foto';

  @override
  String get commonGallery => 'Galería';

  @override
  String get commonUnavailable => 'No disponible';

  @override
  String get scannerTitle => 'Escáner de etiquetas';

  @override
  String get scannerPremiumRequiredMessage =>
      'Escanear, abrir imágenes de la galería y buscar productos desde el escáner está disponible solo para usuarios Premium.';

  @override
  String get scannerClearTrainingTitle => 'Limpiar entrenamiento OCR';

  @override
  String get scannerClearTrainingBody =>
      'Se eliminarán todas las correcciones guardadas en este dispositivo. ¿Deseas continuar?';

  @override
  String get scannerLocalTrainingRemoved => 'Entrenamiento OCR local eliminado';

  @override
  String get scannerExportRulesTitle => 'Exportar reglas OCR';

  @override
  String get scannerImportRulesTitle => 'Importar reglas OCR';

  @override
  String get scannerImportRulesHint => 'Pega aquí el JSON exportado';

  @override
  String get scannerInvalidFormat => 'Formato inválido';

  @override
  String get scannerInvalidJsonOrCanceled =>
      'JSON inválido o importación cancelada';

  @override
  String scannerImportedRulesCount(Object count) {
    return 'Importadas $count reglas de entrenamiento';
  }

  @override
  String get scannerRulesUploaded => 'Reglas OCR subidas al servidor';

  @override
  String scannerRulesUploadError(Object error) {
    return 'Error al subir reglas: $error';
  }

  @override
  String get scannerNoRemoteRules => 'No hay reglas remotas disponibles.';

  @override
  String scannerDownloadedRulesCount(Object count) {
    return 'Descargadas $count reglas desde servidor';
  }

  @override
  String scannerRulesDownloadError(Object error) {
    return 'Error al descargar reglas: $error';
  }

  @override
  String get scannerTrainingMarkedCorrect =>
      'Entrenamiento guardado: lectura marcada como correcta';

  @override
  String get scannerCorrectOcrValuesTitle => 'Corregir valores OCR';

  @override
  String get scannerSugarField => 'Azúcar (g)';

  @override
  String get scannerSaltField => 'Sal (g)';

  @override
  String get scannerFatField => 'Grasas (g)';

  @override
  String get scannerProteinField => 'Proteína (g)';

  @override
  String get scannerPortionField => 'Porción (g)';

  @override
  String get scannerSaveCorrection => 'Guardar corrección';

  @override
  String get scannerCorrectionSaved =>
      'Corrección guardada. Se aplicará a etiquetas similares.';

  @override
  String get scannerSourceBarcode => 'Código de barras';

  @override
  String get scannerSourceOcrOpenFood => 'OCR de nombre + Open Food Facts';

  @override
  String get scannerSourceOcrTable => 'OCR de tabla nutricional';

  @override
  String get scannerSourceAutoBarcodeOpenFood =>
      'Detección automática (código de barras + Open Food Facts)';

  @override
  String get scannerSourceAutoOcrOpenFood =>
      'Detección automática (OCR + Open Food Facts)';

  @override
  String get scannerSourceAutoOcrTable =>
      'Detección automática (OCR de tabla nutricional)';

  @override
  String get scannerNoNutritionData =>
      'No se pudieron obtener los datos nutricionales. Haz la foto con buena luminosidad, texto nítido y enfocado, y encuadrando la tabla de información nutricional.';

  @override
  String scannerReadCompleted(Object source) {
    return 'Lectura completada: $source';
  }

  @override
  String scannerAnalyzeError(Object error) {
    return 'No se pudo analizar la etiqueta: $error';
  }

  @override
  String get scannerHeaderTitle => 'Escáner de etiquetas de alimentos';

  @override
  String get scannerHeaderTooltip => 'Información completa del proceso';

  @override
  String get scannerHeaderBody =>
      'Haz una foto del código de barras de un producto (alimento) o bien selecciona una imagen de la galería. La app NutriFit detectará automáticamente, si se activa este modo, el código de barras, nombre de producto o tabla nutricional.';

  @override
  String get scannerPremiumBanner =>
      'Función Premium: puedes entrar en la pantalla y ver la información, pero Buscar, Foto y Galería están bloqueados para usuarios no Premium.';

  @override
  String get scannerTrainingModeTitle => 'Modo entrenamiento OCR';

  @override
  String get scannerTrainingModeSubtitle =>
      'Permite corregir lecturas para mejorar detecciones.';

  @override
  String get scannerModeLabel => 'Modo';

  @override
  String get scannerModeAuto => 'Modo automático';

  @override
  String get scannerModeBarcode => 'Modo código de barras';

  @override
  String get scannerModeOcrTable => 'Modo tabla nutricional';

  @override
  String get scannerActionSearchOpenFood => 'Buscar en Open Food Facts';

  @override
  String get scannerAutoHint =>
      'En modo automático, la app intenta detectar primero el código de barras y, si no encuentra un producto válido, prueba con OCR sobre el nombre o la tabla nutricional.';

  @override
  String get scannerBarcodeHint =>
      'En modo código de barras, la cámara muestra un recuadro guía y la app analiza sólo esa zona para mejorar la precisión.';

  @override
  String get scannerOcrHint =>
      'En modo tabla nutricional, la app prioriza la lectura OCR del nombre y de la tabla nutricional, sin depender del código de barras.';

  @override
  String get scannerDismissHintTooltip =>
      'Cerrar (mant. pulsado el botón de modo para volver a mostrarlo)';

  @override
  String get scannerAnalyzing => 'Analizando etiqueta...';

  @override
  String get scannerResultPerServing => 'Resultado por porción';

  @override
  String get scannerThresholdInfo => 'Info de umbrales';

  @override
  String get scannerMiniTrainingTitle => 'Mini-entrenamiento OCR';

  @override
  String get scannerMiniTrainingApplied =>
      'Se aplicó aprendizaje previo para esta etiqueta o una similar.';

  @override
  String get scannerMiniTrainingPrompt =>
      'Valida o corrige esta lectura para entrenar el reconocimiento.';

  @override
  String get scannerTrainingCorrect => 'Es correcto';

  @override
  String get scannerTrainingCorrectAction => 'Corregir';

  @override
  String get scannerDownloadServerRules => 'Bajar reglas servidor';

  @override
  String get scannerUploadServerRules => 'Subir reglas servidor';

  @override
  String get scannerClearLocalRules => 'Limpiar local';

  @override
  String get scannerZoomLabel => 'Ampliar';

  @override
  String get scannerDetectedTextTitle => 'Texto detectado (OCR)';

  @override
  String get scannerManualSearchTitle => 'Buscar en Open Food Facts';

  @override
  String get scannerManualSearchHint => 'Nombre del producto';

  @override
  String get scannerNoValidProductByName =>
      'No se encontró un producto válido con ese nombre.';

  @override
  String get scannerManualSearchSource =>
      'Búsqueda manual por nombre (Open Food Facts)';

  @override
  String get scannerProductFound => 'Producto encontrado en Open Food Facts';

  @override
  String scannerProductSearchError(Object error) {
    return 'Error al buscar producto: $error';
  }

  @override
  String get scannerProductName => 'Nombre del producto';

  @override
  String get scannerBrand => 'Marca';

  @override
  String get scannerFormat => 'Formato';

  @override
  String get scannerBarcodeLabel => 'Código de barras';

  @override
  String get scannerActions => 'Acciones';

  @override
  String get scannerAddToShoppingList => 'Añadir a compra';

  @override
  String get scannerNutriScoreNova => 'Nutri score   Nova';

  @override
  String get scannerNutriScoreMeaning => '¿Qué significa Nutri-Score?';

  @override
  String get scannerNovaMeaning => '¿Qué significa NOVA?';

  @override
  String get scannerIngredients => 'Ingredientes';

  @override
  String get scannerNutritionData => 'Datos nutricionales';

  @override
  String scannerEnergyValue(Object value) {
    return 'Energía: $value';
  }

  @override
  String scannerCarbohydratesValue(Object value) {
    return 'Carbohidratos: $value';
  }

  @override
  String scannerFiberValue(Object value) {
    return 'Fibra: $value';
  }

  @override
  String scannerSaturatedFatValue(Object value) {
    return 'Grasas saturadas: $value';
  }

  @override
  String scannerSodiumValue(Object value) {
    return 'Sodio: $value';
  }

  @override
  String get scannerImageTitle => 'Etiqueta nutricional';

  @override
  String scannerOpenImageError(Object error) {
    return 'No se pudo abrir la imagen: $error';
  }

  @override
  String get scannerInfoTitle => 'Información';

  @override
  String get scannerContactDietitianButton => 'Contactar con dietista';

  @override
  String get scannerAllergensAndTraces => 'Alérgenos y trazas';

  @override
  String scannerAllergensValue(Object value) {
    return 'Alérgenos: $value';
  }

  @override
  String scannerTracesValue(Object value) {
    return 'Trazas: $value';
  }

  @override
  String get scannerFeaturedLabels => 'Etiquetas destacadas';

  @override
  String get scannerCopiedData => 'Datos copiados al portapapeles';

  @override
  String get scannerRegisterForShoppingList =>
      'Regístrate para añadir productos a la lista de compra';

  @override
  String get scannerUnknownUser => 'Usuario no identificado';

  @override
  String get scannerExistingFoodUpdated =>
      'El alimento ya existe, se ha actualizado';

  @override
  String get scannerProductAddedToShoppingList =>
      'Producto añadido a la lista de compra';

  @override
  String scannerAddToShoppingListError(Object error) {
    return 'Error al añadir a la lista: $error';
  }

  @override
  String get scannerThresholdInfoIntro =>
      'La tabla de \"Resultado por porción\" te ayuda a comprobar si un valor está cerca (OK) o lejos (Precaución/Alto) del rango recomendado orientativo.';

  @override
  String get scannerThresholdComponent => 'Componente';

  @override
  String get scannerThresholdOk => 'OK';

  @override
  String get scannerThresholdCaution => 'Precaución';

  @override
  String get scannerThresholdHighLow => 'Alto / Bajo';

  @override
  String get scannerThresholdSugar => 'Azúcar';

  @override
  String get scannerThresholdSalt => 'Sal';

  @override
  String get scannerThresholdFat => 'Grasas';

  @override
  String get scannerThresholdProtein => 'Proteína';

  @override
  String get scannerThresholdDisclaimer =>
      'Las sugerencias y valores mostrados son siempre orientativos: no sustituyen la recomendación de un profesional dietético. Además, la cantidad de porciones que consumes afecta directamente a la cantidad total de cada nutriente que ingieres.';

  @override
  String get scannerOcrAccuracyTitle => 'Precisión de lectura (OCR)';

  @override
  String get scannerOcrAccuracyBody =>
      'La exactitud del producto (alimento) detectado depende directamente de la calidad de la imagen. Si la foto es borrosa, con reflejos o sin enfocar el código de barras o la tabla nutricional, los valores pueden mostrarse incorrectos. Revisa siempre el nombre del producto para asegurarte de que coincide.';

  @override
  String get scannerOcrTip1 => '• Enfoca solo el código de barras.';

  @override
  String get scannerOcrTip2 =>
      '• Si no tiene código de barras, enfoca únicamente la tabla de información nutricional.';

  @override
  String get scannerOcrTip3 =>
      '• Si fotografías el código de barras, que se vea completo y nítido.';

  @override
  String get scannerOcrTip4 => '• Evita sombras, reflejos y baja iluminación.';

  @override
  String get scannerOcrTip5 =>
      '• Mantén el móvil estable y el texto lo más recto posible.';

  @override
  String get scannerOcrTip6 =>
      '• Comprueba que números y unidades (g/ml) se lean nítidos.';

  @override
  String get scannerOcrTip7 =>
      '• Evita fotografiar etiquetas arrugadas o dañadas.';

  @override
  String get scannerNutriScoreDescription =>
      'Nutri-Score es un sistema público de etiquetado frontal usado en Europa para resumir la calidad nutricional global del producto.';

  @override
  String get scannerNutriScoreA => 'Más favorable nutricionalmente';

  @override
  String get scannerNutriScoreB => 'Favorable';

  @override
  String get scannerNutriScoreC => 'Intermedio';

  @override
  String get scannerNutriScoreD => 'Menos favorable';

  @override
  String get scannerNutriScoreE => 'Menos saludable en conjunto';

  @override
  String get scannerNovaDescription =>
      'NOVA clasifica alimentos por grado de procesamiento (sistema académico de salud pública).';

  @override
  String get scannerNova1 => 'Sin procesar o mínimamente procesado';

  @override
  String get scannerNova2 => 'Ingredientes culinarios procesados';

  @override
  String get scannerNova3 => 'Alimentos procesados';

  @override
  String get scannerNova4 => 'Ultraprocesados';

  @override
  String get scannerGuestAccuracyPromptStart =>
      'Si quieres información más exacta ';

  @override
  String get scannerGuestAccuracyPromptLink => 'regístrate (es gratis)';

  @override
  String get scannerGuestAccuracyPromptEnd => ' e indica tu edad y altura.';

  @override
  String get scannerCaptureTipsTitle => 'Consejos para hacer foto...';

  @override
  String get scannerCaptureTipsIntro =>
      'Para obtener valores correctos, la imagen debe enfocarse bien sobre el código de barras o sobre la tabla de información nutricional.';

  @override
  String get scannerCaptureTipsBody =>
      '• Si escaneas el código de barras, céntralo en el recuadro.\n• Si escaneas la tabla nutricional, asegúrate de que toda la tabla esté visible.\n• Evita fotos movidas, borrosas o con reflejos.\n• Usa buena luz y acércate lo suficiente para leer números.\n• Si el resultado no cuadra, repite la foto desde otro ángulo.';

  @override
  String get scannerImportantNotice => 'Aviso importante';

  @override
  String get scannerOrientativeNotice =>
      'Estos cálculos e información son orientativos y dependen, además, de la calidad de la foto/imagen y de si el producto existe en la base de datos Open Food Facts. Para una valoración personalizada, consulta siempre tu dietista online.';

  @override
  String get scannerNutrientColumn => 'Nutriente';

  @override
  String scannerServingColumn(Object portion) {
    return 'Porción ($portion)';
  }

  @override
  String get scannerStatus100gColumn => 'Estado (100 g)';

  @override
  String scannerCameraInitError(Object error) {
    return 'No se pudo iniciar la cámara: $error';
  }

  @override
  String scannerTakePhotoError(Object error) {
    return 'No se pudo tomar la foto: $error';
  }

  @override
  String get scannerFrameHint =>
      'Centra la etiqueta/código de barras dentro del recuadro';

  @override
  String get activitiesCatalogTitle => 'Catálogo de actividades';

  @override
  String get commonEmail => 'Email';

  @override
  String get restrictedAccessGenericMessage =>
      'Para acceder a tus planes nutricionales, planes de entrenamiento y recomendaciones personalizadas, primero necesitas contactar con tu dietista/entrenador online, que te asignará un plan específico, ajustado a tus necesidades.';

  @override
  String get restrictedAccessContactMethods => 'Formas de contacto:';

  @override
  String get restrictedAccessMoreContactOptions => 'Más formas de contacto';

  @override
  String get videosPremiumToolsMessage =>
      'La búsqueda, filtros, favoritos, likes y ordenación completa de los vídeos de ejercicios están disponibles solo para usuarios Premium.';

  @override
  String get videosPremiumPlaybackMessage =>
      'La reproducción completa de los vídeos de ejercicios está disponible solo para usuarios Premium.';

  @override
  String get videosPremiumTitle => 'Vídeos Premium';

  @override
  String get videosPremiumSubtitle =>
      'El catálogo completo de vídeos de ejercicios está disponible solo para usuarios Premium. Accede a ';

  @override
  String videosPremiumPreviewHighlight(Object count) {
    return '$count vídeos exclusivos.';
  }

  @override
  String get charlasPremiumToolsMessage =>
      'La búsqueda, filtros, favoritos, likes y ordenación completa de las charlas y seminarios están disponibles solo para usuarios Premium.';

  @override
  String get charlasPremiumContentMessage =>
      'El acceso completo al contenido de la charla o seminario está disponible solo para usuarios Premium.';

  @override
  String get charlasPremiumTitle => 'Charlas Premium';

  @override
  String get charlasPremiumSubtitle =>
      'El catálogo completo de charlas y seminarios está disponible solo para usuarios Premium. Accede a ';

  @override
  String charlasPremiumPreviewHighlight(Object count) {
    return '$count charlas exclusivas.';
  }

  @override
  String get supplementsPremiumCopyPdfMessage =>
      'Para poder copiar y pasar a PDF un suplemento, debes ser usuario Premium.';

  @override
  String get supplementsPremiumExploreMessage =>
      'Los hashtags y las recomendaciones de suplementos están disponibles solo para usuarios Premium.';

  @override
  String get supplementsPremiumToolsMessage =>
      'La búsqueda, actualización y ordenación completa del catálogo de suplementos están disponibles solo para usuarios Premium.';

  @override
  String get supplementsPremiumTitle => 'Suplementos Premium';

  @override
  String get supplementsPremiumSubtitle =>
      'El catálogo completo de suplementos está disponible solo para usuarios Premium.';

  @override
  String supplementsPremiumPreviewHighlight(Object count) {
    return '(con más de $count suplementos)';
  }

  @override
  String get exerciseCatalogPremiumToolsMessage =>
      'La búsqueda, filtros, actualización y ordenación completa del catálogo de ejercicios están disponibles solo para usuarios Premium.';

  @override
  String get exerciseCatalogPremiumVideoMessage =>
      'El vídeo completo del ejercicio está disponible solo para usuarios Premium.';

  @override
  String get exerciseCatalogPremiumTitle => 'Ejercicios Premium';

  @override
  String get exerciseCatalogPremiumSubtitle =>
      'El catálogo completo de ejercicios está disponible solo para usuarios Premium.';

  @override
  String exerciseCatalogPremiumPreviewHighlight(Object count) {
    return '(con más de $count ejercicios)';
  }
}
