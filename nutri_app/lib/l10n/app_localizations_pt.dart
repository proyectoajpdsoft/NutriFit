// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get settingsAndPrivacyTitle => 'Definicoes e privacidade';

  @override
  String get settingsAndPrivacyMenuLabel => 'Definicoes e privacidade';

  @override
  String get configTabParameters => 'Parametros';

  @override
  String get configTabPremium => 'Premium';

  @override
  String get configTabAppMenu => 'Menu app';

  @override
  String get configTabGeneral => 'General';

  @override
  String get configTabSecurity => 'Seguranca';

  @override
  String get configTabUser => 'Usuario';

  @override
  String get configTabDisplay => 'Exibicao';

  @override
  String get configTabDefaults => 'Padrao';

  @override
  String get configTabPrivacy => 'Privacidade';

  @override
  String get securitySubtabAccess => 'Acesso';

  @override
  String get securitySubtabEmailServer => 'Servidor de email';

  @override
  String get securitySubtabCipher => 'Criptografar/Descriptografar';

  @override
  String get securitySubtabSessions => 'Sessoes';

  @override
  String get securitySubtabAccesses => 'Acessos';

  @override
  String get privacyCenterTab => 'Centro';

  @override
  String get privacyPolicyTab => 'Politica';

  @override
  String get privacySessionsTab => 'Sessoes';

  @override
  String privacyLastUpdatedLabel(Object date) {
    return 'Ultima atualizacao: $date';
  }

  @override
  String get privacyIntro =>
      'This section shows the updated NutriFitApp Privacy Policy, explains how personal data is processed under the GDPR and the Spanish LOPDGDD, and details how you can delete your account and all associated data directly from the app.';

  @override
  String get privacyPrintPdf => 'Print / save as PDF';

  @override
  String privacyPdfGenerateError(Object error) {
    return 'Error generating privacy PDF: $error';
  }

  @override
  String get privacyCannotIdentifyUser =>
      'The current user could not be identified.';

  @override
  String privacyOpenProfileError(Object error) {
    return 'Could not open Edit Profile: $error';
  }

  @override
  String get privacyDeleteDialogTitle => 'Delete all my data';

  @override
  String get privacyDeleteDialogIntro =>
      'This action deletes your account and all data associated with it under your right to erasure.';

  @override
  String get privacyDeleteDialogBody =>
      'Login history, chats, weight tracking, shopping list, activities, tasks, trainings, exercises, and images linked to your account will be deleted.';

  @override
  String get privacyDeleteDialogWarning =>
      'This action is irreversible and will sign you out.';

  @override
  String get privacyDeleteTypedTitle => 'Final confirmation';

  @override
  String privacyDeleteTypedPrompt(Object keyword) {
    return 'To confirm, type $keyword in uppercase:';
  }

  @override
  String privacyDeleteTypedHint(Object keyword) {
    return '$keyword';
  }

  @override
  String privacyDeleteTypedMismatch(Object keyword) {
    return 'You must type $keyword to confirm.';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get privacyDeleteMyData => 'Delete my data';

  @override
  String get privacyDeleteConnectionError =>
      'The process could not be completed. Please check your internet connection.';

  @override
  String get privacyDeleteAccountFailed => 'The account could not be deleted.';

  @override
  String get privacyActionPolicyTitle => 'Privacy policy';

  @override
  String get privacyActionPolicyDescription =>
      'Review the full privacy text, user rights, and data processing details under GDPR and LOPDGDD.';

  @override
  String get privacyViewPolicy => 'View policy';

  @override
  String get privacyPdfShort => 'PDF';

  @override
  String get privacyActionSecurityTitle => 'Security and access';

  @override
  String get privacyActionSecurityDescription =>
      'Open Edit Profile to manage email, two-factor authentication (2FA), trusted devices, and other access controls for your account.';

  @override
  String get privacyOpenEditProfile => 'Open Edit Profile';

  @override
  String get privacyActionSessionsTitle => 'Sign-ins';

  @override
  String get privacyActionSessionsDescription =>
      'Review successful sessions, failed attempts, and access activity linked to your account.';

  @override
  String get privacyViewSessions => 'View sessions';

  @override
  String get privacyActionDeleteTitle => 'Delete all my data';

  @override
  String get privacyActionDeleteDescription =>
      'You can request complete deletion of your account and related data directly from the app. This action is irreversible and will sign you out.';

  @override
  String get sessionsUserCodeUnavailable => 'User code is not available';

  @override
  String get sessionsAnonymousGuestInfo =>
      'Nao ha dados de sessao disponiveis para utilizadores nao registados, uma vez que o acesso e anonimo.';

  @override
  String sessionsError(Object error) {
    return 'Error: $error';
  }

  @override
  String get commonRetry => 'Retry';

  @override
  String get sessionsNoDataAvailable => 'No session data available';

  @override
  String get sessionsSuccessfulTitle => 'Latest Successful Sign-ins';

  @override
  String get sessionsCurrent => 'Current session:';

  @override
  String get sessionsPrevious => 'Previous session:';

  @override
  String get sessionsNoSuccessful => 'No successful sessions recorded';

  @override
  String get sessionsFailedTitle => 'Latest Failed Access Attempts';

  @override
  String sessionsAttemptNumber(Object count) {
    return 'Attempt $count:';
  }

  @override
  String get sessionsNoFailed => 'No failed attempts recorded.';

  @override
  String get sessionsStatsTitle => 'Session Statistics';

  @override
  String sessionsTotal(Object count) {
    return 'Total sessions: $count';
  }

  @override
  String sessionsSuccessfulCount(Object count) {
    return 'Successful attempts: $count';
  }

  @override
  String sessionsFailedCount(Object count) {
    return 'Failed attempts: $count';
  }

  @override
  String get commonNotAvailable => 'N/A';

  @override
  String sessionsDate(Object value) {
    return 'Date: $value';
  }

  @override
  String sessionsTime(Object value) {
    return 'Time: $value';
  }

  @override
  String sessionsDevice(Object value) {
    return 'Device: $value';
  }

  @override
  String get sessionsIpAddress => 'IP address:';

  @override
  String sessionsPublicIp(Object value) {
    return 'Public: $value';
  }

  @override
  String get privacyPolicyTitle => 'NutriFitApp privacy policy';

  @override
  String get privacyPolicyLastUpdated => 'April 7, 2026';

  @override
  String get privacyPolicySection1Title => '1. Data controller';

  @override
  String get privacyPolicySection1Paragraph1 =>
      'The data controller for the personal data processed through the NutriFit application is the owner or operating entity of the NutriFitApp service.';

  @override
  String get privacyPolicySection1Paragraph2 => 'Controller contact details:';

  @override
  String get privacyPolicySection1Bullet1 =>
      'Name or business name: Patricia Carmona Fernández.';

  @override
  String get privacyPolicySection1Bullet2 =>
      'Tax ID/VAT number: Provided upon request.';

  @override
  String get privacyPolicySection1Bullet3 => 'Address: Provided upon request.';

  @override
  String get privacyPolicySection1Bullet4 =>
      'Contact email: aprendeconpatrica[ — at — ]gmail[ — dot — ]com';

  @override
  String get privacyPolicySection2Title => '2. Applicable regulations';

  @override
  String get privacyPolicySection2Paragraph1 =>
      'This Privacy Policy has been drafted in accordance with the applicable personal data protection regulations, in particular:';

  @override
  String get privacyPolicySection2Bullet1 =>
      'Regulation (EU) 2016/679 of the European Parliament and of the Council of 27 April 2016, the General Data Protection Regulation (GDPR).';

  @override
  String get privacyPolicySection2Bullet2 =>
      'Spanish Organic Law 3/2018 of 5 December on Personal Data Protection and guarantee of digital rights (LOPDGDD).';

  @override
  String get privacyPolicySection2Bullet3 =>
      'Any other applicable Spanish and European regulations.';

  @override
  String get privacyPolicySection3Title => '3. What NutriFitApp is';

  @override
  String get privacyPolicySection3Paragraph1 =>
      'NutriFitApp is an application focused on nutrition, health, sports, habit tracking, and personal organization. It may include features such as a user profile, tasks, shopping list, recipes, tips, healthy substitutions, training, nutritional scanner, notifications, additives, supplements, weight control, and tracking tools between the user and the professional.';

  @override
  String get privacyPolicySection4Title => '4. What personal data we process';

  @override
  String get privacyPolicySection4Paragraph1 =>
      'Depending on how you use the app, NutriFitApp may process the following categories of data:';

  @override
  String get privacyPolicySection4Bullet1 =>
      'Identification data: name, nickname or alias, email address, profile image, and other registration data.';

  @override
  String get privacyPolicySection4Bullet2 =>
      'Access and authentication data: credentials, session identifiers, security verifications, and elements associated with secure access to the account.';

  @override
  String get privacyPolicySection4Bullet3 =>
      'App usage data: interactions, preferences, saved settings, and actions performed within the application.';

  @override
  String get privacyPolicySection4Bullet4 =>
      'Data provided by the user: tasks, notes, comments, feelings, manually entered content, and any other information voluntarily provided.';

  @override
  String get privacyPolicySection4Bullet5 =>
      'Data related to nutrition, wellness, physical activity, or personal tracking that the user chooses to add to the application.';

  @override
  String get privacyPolicySection4Bullet6 =>
      'Technical and device data: technical identifiers, app version, operating system, language settings, and the minimum data needed for operation, security, and diagnostics.';

  @override
  String get privacyPolicySection4Bullet7 =>
      'Data derived from push notifications, if the user enables them.';

  @override
  String get privacyPolicySection4Bullet8 =>
      'Camera or image data, if the user uses features such as profile image, scanner, content capture, or images in activities.';

  @override
  String get privacyPolicySection4Bullet9 =>
      'Data linked to calendar features, if the user decides to use schedule integrations.';

  @override
  String get privacyPolicySection4Bullet10 =>
      'Any other data necessary to properly provide the services offered in the app.';

  @override
  String get privacyPolicySection4Paragraph2 =>
      'If, in certain cases, data related to health or personal wellness is processed, such processing will only take place to the extent necessary to provide the functionality requested by the user and in accordance with the applicable legal basis.';

  @override
  String get privacyPolicySection5Title => '5. Purposes of processing';

  @override
  String get privacyPolicySection5Bullet1 =>
      'Create and manage the user account.';

  @override
  String get privacyPolicySection5Bullet2 =>
      'Allow sign-in and keep the session authenticated.';

  @override
  String get privacyPolicySection5Bullet3 =>
      'Provide the main NutriFitApp features.';

  @override
  String get privacyPolicySection5Bullet4 => 'Manage the user profile.';

  @override
  String get privacyPolicySection5Bullet5 =>
      'Allow tracking of habits, tasks, training, nutrition, and related content.';

  @override
  String get privacyPolicySection5Bullet6 =>
      'Facilitate interaction between the user and the professional when that functionality is enabled.';

  @override
  String get privacyPolicySection5Bullet7 =>
      'Send notifications related to account activity or features used by the user.';

  @override
  String get privacyPolicySection5Bullet8 =>
      'Improve the user experience, stability, security, and performance of the app.';

  @override
  String get privacyPolicySection5Bullet9 =>
      'Handle requests, incidents, or inquiries submitted by the user.';

  @override
  String get privacyPolicySection5Bullet10 =>
      'Comply with applicable legal obligations.';

  @override
  String get privacyPolicySection5Bullet11 =>
      'Protect the controller\'s legitimate interests regarding security, fraud prevention, service integrity, and protection against unauthorized access.';

  @override
  String get privacyPolicySection6Title => '6. Legal basis';

  @override
  String get privacyPolicySection6Paragraph1 =>
      'The legal bases that legitimize processing may be, depending on the case:';

  @override
  String get privacyPolicySection6Bullet1 =>
      'Performance of the contractual or pre-contractual relationship when the user registers for and uses NutriFitApp.';

  @override
  String get privacyPolicySection6Bullet2 =>
      'The user\'s consent for those features that require it.';

  @override
  String get privacyPolicySection6Bullet3 =>
      'Compliance with legal obligations.';

  @override
  String get privacyPolicySection6Bullet4 =>
      'The controller\'s legitimate interest in ensuring the security, continuity, and proper functioning of the application.';

  @override
  String get privacyPolicySection6Paragraph2 =>
      'When processing is based on consent, the user may withdraw it at any time, without affecting the lawfulness of processing carried out before its withdrawal.';

  @override
  String get privacyPolicySection7Title => '7. Data retention';

  @override
  String get privacyPolicySection7Paragraph1 =>
      'Personal data will be kept for as long as necessary to fulfill the purpose for which it was collected and, thereafter, for the periods legally required to address potential liabilities.';

  @override
  String get privacyPolicySection7Paragraph2 =>
      'When the user requests deletion of the account, their data will be deleted or anonymized in accordance with the internal retention policy and any applicable legal obligations.';

  @override
  String get privacyPolicySection8Title => '8. User-initiated data deletion';

  @override
  String get privacyPolicySection8Paragraph1 =>
      'NutriFitApp allows the user to delete all of their data by deleting the account directly from the application at any time.';

  @override
  String get privacyPolicySection8Paragraph2 =>
      'Steps within the app to completely delete the account and its data:';

  @override
  String get privacyPolicySection8Step1 =>
      'Sign in to NutriFitApp with your user account.';

  @override
  String get privacyPolicySection8Step2 => 'Open Edit Profile.';

  @override
  String get privacyPolicySection8Step3 =>
      'Within that screen, locate the account deletion option (the “Delete all my data” button).';

  @override
  String get privacyPolicySection8Step4 => 'Tap Delete all my data.';

  @override
  String get privacyPolicySection8Step5 => 'Confirm the deletion process.';

  @override
  String get privacyPolicySection8Paragraph3 =>
      'After confirmation, the application will execute the deletion process for the account and associated data according to the system\'s operation, and will sign the user out.';

  @override
  String get privacyPolicySection8Paragraph4 =>
      'If, for any reason, the user cannot complete the process from the app, they may also request deletion by writing to the contact email indicated above.';

  @override
  String get privacyPolicySection9Title => '9. Data recipients';

  @override
  String get privacyPolicySection9Paragraph1 =>
      'Data will NEVER be sold or disclosed to third parties.';

  @override
  String get privacyPolicySection9Paragraph2 =>
      'Only the following may have access to the data:';

  @override
  String get privacyPolicySection9Bullet1 =>
      'Qualified technical personnel solely for technological processes necessary for app operation, hosting, notifications, technical support, or related services.';

  @override
  String get privacyPolicySection9Bullet2 =>
      'Data processors contracted by the controller, under the corresponding contractual safeguards.';

  @override
  String get privacyPolicySection9Bullet3 =>
      'Public administrations, judges, courts, or competent authorities when there is a legal obligation.';

  @override
  String get privacyPolicySection9Paragraph3 =>
      'There are no international data transfers outside the European Economic Area.';

  @override
  String get privacyPolicySection10Title => '10. Device permissions';

  @override
  String get privacyPolicySection10Paragraph1 =>
      'NutriFitApp may request device permissions only when they are necessary for a specific feature. For example:';

  @override
  String get privacyPolicySection10Bullet1 =>
      'Camera: to capture images or use scanning features.';

  @override
  String get privacyPolicySection10Bullet2 =>
      'Gallery or files: to select images or documents, or to save PDF documents from the app.';

  @override
  String get privacyPolicySection10Bullet3 =>
      'Notifications: for relevant alerts within the app.';

  @override
  String get privacyPolicySection10Bullet4 =>
      'Calendar: if the user decides to export or add events.';

  @override
  String get privacyPolicySection10Bullet5 =>
      'Other permissions strictly necessary for certain application tools.';

  @override
  String get privacyPolicySection10Paragraph2 =>
      'The user may revoke these permissions at any time from the device settings, although some features may no longer be available.';

  @override
  String get privacyPolicySection11Title => '11. Information security';

  @override
  String get privacyPolicySection11Paragraph1 =>
      'NutriFitApp applies reasonable technical and organizational measures to protect personal data against loss, alteration, unauthorized access, disclosure, or destruction. Information is encrypted in transit.';

  @override
  String get privacyPolicySection11Paragraph2 =>
      'However, the user should be aware that no Internet transmission or storage system can guarantee absolute security.';

  @override
  String get privacyPolicySection12Title => '12. User rights';

  @override
  String get privacyPolicySection12Paragraph1 =>
      'The user may exercise the following rights at any time:';

  @override
  String get privacyPolicySection12Bullet1 => 'Access.';

  @override
  String get privacyPolicySection12Bullet2 => 'Rectification.';

  @override
  String get privacyPolicySection12Bullet3 => 'Erasure.';

  @override
  String get privacyPolicySection12Bullet4 => 'Objection.';

  @override
  String get privacyPolicySection12Bullet5 => 'Restriction of processing.';

  @override
  String get privacyPolicySection12Bullet6 => 'Portability.';

  @override
  String get privacyPolicySection12Bullet7 =>
      'Withdrawal of consent, when processing is based on it.';

  @override
  String get privacyPolicySection12Paragraph2 =>
      'To exercise these rights, the user may:';

  @override
  String get privacyPolicySection12Bullet8 =>
      'Use the functions available within the app, when they exist.';

  @override
  String get privacyPolicySection12Bullet9 =>
      'Contact the controller through the contact email indicated above.';

  @override
  String get privacyPolicySection12Paragraph3 =>
      'The request must allow the applicant to be reasonably identified.';

  @override
  String get privacyPolicySection12Paragraph4 =>
      'The user also has the right to lodge a complaint with the Spanish Data Protection Agency (AEPD) if they believe their rights have not been properly addressed:';

  @override
  String get privacyPolicySection12Paragraph5 => 'https://www.aepd.es/';

  @override
  String get privacyPolicySection13Title => '13. Minors';

  @override
  String get privacyPolicySection13Paragraph1 =>
      'NutriFitApp is not generally intended for minors without the intervention or authorization of their legal representatives when required. If we detect that personal data of a minor has been collected in breach of the applicable regulations, the appropriate measures will be taken for its deletion.';

  @override
  String get privacyPolicySection14Title =>
      '14. Accuracy and user responsibility';

  @override
  String get privacyPolicySection14Paragraph1 =>
      'The user guarantees that the data provided is true, accurate, and up to date, and undertakes to communicate any changes.';

  @override
  String get privacyPolicySection14Paragraph2 =>
      'The user shall be responsible for any damages or losses that may arise from providing false, inaccurate, or outdated data.';

  @override
  String get privacyPolicySection15Title => '15. Changes to this policy';

  @override
  String get privacyPolicySection15Paragraph1 =>
      'NutriFitApp may update this Privacy Policy to adapt it to legal, technical, or functional changes. When changes are relevant, the user will be informed through appropriate means.';

  @override
  String get privacyPolicySection16Title => '16. Contact';

  @override
  String get privacyPolicySection16Paragraph1 =>
      'For any matter related to privacy or data protection, you can contact:';

  @override
  String get privacyPolicySection16Paragraph2 =>
      'aprendeconpatrica[ — at — ]gmail[ — dot — ]com';

  @override
  String get commonClose => 'Close';

  @override
  String appUpdatedNotice(Object version) {
    return 'A aplicacao foi atualizada para a versao $version.';
  }

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonAgree => 'OK';

  @override
  String get commonLater => 'Later';

  @override
  String get commonValidate => 'Validar';

  @override
  String get commonToday => 'hoje';

  @override
  String get commonDebug => 'DEBUG';

  @override
  String get commonAllRightsReserved => 'Todos os direitos reservados';

  @override
  String get navHome => 'Inicio';

  @override
  String get navLogout => 'Encerrar sessao';

  @override
  String get navChat => 'Chat';

  @override
  String get navPatients => 'Patients';

  @override
  String get navAppointments => 'Appointments';

  @override
  String get navReviews => 'Reviews';

  @override
  String get navMeasurements => 'Measurements';

  @override
  String get navNutriInterviews => 'Nutri interviews';

  @override
  String get navNutriPlans => 'Nutri plans';

  @override
  String get navFitInterviews => 'Fit interviews';

  @override
  String get navFitPlans => 'Fit plans';

  @override
  String get navExercises => 'Exercises';

  @override
  String get navExerciseVideos => 'Exercise videos';

  @override
  String get navActivities => 'Activities';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navCharges => 'Charges';

  @override
  String get navClients => 'Clients';

  @override
  String get navTips => 'Tips';

  @override
  String get navRecipes => 'Recipes';

  @override
  String get navSubstitutions => 'Substitutions';

  @override
  String get navTalksAndSeminars => 'Talks and seminars';

  @override
  String get navTalks => 'Talks';

  @override
  String get navPremiumPreview => 'Go Premium (preview)';

  @override
  String get navPremium => 'Go Premium';

  @override
  String get premiumRegistrationRequiredBody =>
      'To go Premium, you must register first. Registration is free and, once you have your account, you will be able to request Premium access from the dietitian.';

  @override
  String get premiumRegisterFree => 'Register for free';

  @override
  String get premiumPaymentMethodLabel => 'Payment method';

  @override
  String get premiumVerifyEmailAction => 'Verify your email to pay';

  @override
  String get premiumContinuePayment => 'Continue to payment';

  @override
  String premiumVerifiedEmailStatus(Object email) {
    return 'Verified email: $email';
  }

  @override
  String get premiumPaymentNeedsRegistration =>
      'To make the payment, register first. It\'s free:';

  @override
  String get premiumPaymentNeedsEmailVerification =>
      'To make the payment, first verify your email in';

  @override
  String get premiumGoToRegisterLink => 'Go to user registration';

  @override
  String get premiumGuestRegistrationBody =>
      'If you do not have an account yet, you must first register for free so you can request Premium access.';

  @override
  String get premiumBenefitsSectionTitle => 'Benefits of being Premium';

  @override
  String get premiumPaymentSectionTitle => 'Premium payment and signup';

  @override
  String get premiumAfterRegistrationMessage =>
      'After registering, you will be able to use the Premium payment assistant on this same screen.';

  @override
  String get premiumFinalActivationMessage =>
      'Final activation of Premium access is carried out by the NutriFit team after validating the payment and the selected period. It will be completed within the next 24/48/72 hours depending on the chosen method.';

  @override
  String get premiumDefaultIntroTitle => 'Unlock your Premium experience';

  @override
  String get premiumDefaultIntroText =>
      'Access exclusive content, advanced resources, and enhanced follow-up to get more out of your plan.';

  @override
  String get premiumDefaultBenefit1 =>
      'Access exclusive Premium-only features, such as Exercise Videos and future improvements.';

  @override
  String get premiumDefaultBenefit2 =>
      'Healthy substitutions library: quick swaps like \"if I do not have X, use Y\" so you can stay on plan.';

  @override
  String get premiumDefaultBenefit3 =>
      'A more complete in-app experience with differentiated content and expanded access.';

  @override
  String get premiumDefaultBenefit4 =>
      'Possibility of receiving personalized proposals from your nutritionist depending on the contracted service.';

  @override
  String get premiumDefaultPaymentMethod1 =>
      'The nutritionist may offer methods such as PayPal, Bizum, bank transfer, or other personalized options.';

  @override
  String get premiumDefaultPaymentMethod2 =>
      'These details are configurable through global parameters so each professional can adapt the commercial offer.';

  @override
  String get premiumDefaultPaymentIntro =>
      'Instructions to complete the payment and activate your Premium account.';

  @override
  String get premiumDefaultActivationNotice =>
      'Once payment is received, your Premium profile will be activated within approximately 24/48/72 hours depending on the selected method.';

  @override
  String premiumDefaultPaypalSteps(
      Object boton_abrir_url_paypal, Object email_paypal, Object url_paypal) {
    return 'Open the payment gateway at: $url_paypal.\nMake the payment using the PayPal account ($email_paypal) and the indicated amount.\nIf needed, use the $boton_abrir_url_paypal button.';
  }

  @override
  String premiumDefaultBizumSteps(
      Object boton_copiar_telefono, Object telefono_nutricionista) {
    return 'Send the Bizum payment to the phone number $telefono_nutricionista.\nAdd the payment concept before confirming the payment.\nIf needed, use the $boton_copiar_telefono button.';
  }

  @override
  String get premiumDefaultTransferSteps =>
      'Make the bank transfer using the details shown on screen.\nCheck the amount and add the concept before sending.\nIf needed, copy the available bank details.';

  @override
  String get premiumPayWithPaypal => 'Pay with PayPal';

  @override
  String get premiumPayWithBizum => 'Pay with Bizum';

  @override
  String get premiumPayWithTransfer => 'Pay by bank transfer';

  @override
  String get premiumPeriodBadgeMaxDiscount => 'Maximum discount';

  @override
  String get premiumPeriodBadgeHighSaving => 'High savings';

  @override
  String get premiumPeriodBadgeMediumSaving => 'Medium savings';

  @override
  String get premiumPeriodBadgeNoDiscount => 'No discount';

  @override
  String get premiumPeriodLabel => 'Premium period';

  @override
  String premiumPeriodMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$months month$_temp0';
  }

  @override
  String premiumPriceUnavailable(Object period) {
    return 'Price not available for $period.';
  }

  @override
  String premiumPriceDisplay(Object amount, Object period) {
    return 'Price: $amount (contracted period: $period)';
  }

  @override
  String get premiumVerifyEmailBeforePayment =>
      'You must verify your email before continuing with the payment.';

  @override
  String get premiumCopyPhone => 'Copy phone';

  @override
  String get premiumOpenPayment => 'Go to payment';

  @override
  String get premiumCopyConcept => 'Copy concept';

  @override
  String get premiumVerifyEmailBeforeNotifyPayment =>
      'You must verify your email before notifying the payment.';

  @override
  String premiumNotifyPaymentError(Object error) {
    return 'The payment could not be notified: $error';
  }

  @override
  String get premiumCompletePaymentTitle => 'Complete payment';

  @override
  String get premiumPaymentConceptLabel =>
      'Concept you must include in the payment method:';

  @override
  String premiumStepsFor(Object method) {
    return 'Steps for $method';
  }

  @override
  String get premiumBizumPhoneLabel => 'Bizum phone';

  @override
  String get premiumAfterPaymentNotice =>
      'Once you have completed the payment, tap \"I have completed the payment\" to notify the NutriFit team. As soon as the payment is verified, your Premium account will be activated and you will be notified by email.';

  @override
  String get premiumSendingNotification => 'Sending notification...';

  @override
  String get premiumIHavePaid => 'I have completed the payment';

  @override
  String get premiumInvalidUrl => 'Invalid URL.';

  @override
  String premiumOpenPaymentError(Object error) {
    return 'The payment link could not be opened: $error';
  }

  @override
  String get premiumPeriodSummaryMaxDiscount =>
      '12-month subscription period (maximum discount).';

  @override
  String get premiumPeriodSummaryHighDiscount =>
      '6-month subscription period (high discount).';

  @override
  String get premiumPeriodSummaryDiscount =>
      '3-month subscription period (discount).';

  @override
  String get premiumPeriodSummarySingleMonth => '1-month subscription period.';

  @override
  String premiumPaymentConcept(Object nick) {
    return 'NutriFit Premium user $nick.';
  }

  @override
  String get navFoods => 'Foods';

  @override
  String get navSupplements => 'Supplements';

  @override
  String get navFoodAdditives => 'Food additives';

  @override
  String get navAdditives => 'Additives';

  @override
  String get navScanner => 'Scanner';

  @override
  String get navSettings => 'Settings';

  @override
  String get navUsers => 'Users';

  @override
  String get navTasks => 'Tasks';

  @override
  String get navChatWithDietitian => 'Chat com dietista';

  @override
  String get navContactDietitian => 'Contactar dietista';

  @override
  String get navEditProfile => 'Editar perfil';

  @override
  String get profileEditProfileTab => 'Perfil';

  @override
  String get profileEditSessionsTab => 'Acessos';

  @override
  String get profileEditPremiumBadgeTitle => 'Conta Premium';

  @override
  String get profileEditPremiumBadgeBody =>
      'Voce tem acesso a funcionalidades exclusivas como videos de exercicios.';

  @override
  String get profileEditNickLabel => 'Apelido / Utilizador';

  @override
  String get profileEditNickRequired => 'O apelido e obrigatorio';

  @override
  String get profileEditEmailLabel => 'Email';

  @override
  String get profileEditInvalidEmail => 'Email invalido';

  @override
  String get profileEditEmailInUse =>
      'O email introduzido nao e valido, utilize outro.';

  @override
  String get profileEditChangeEmailTooltip => 'Alterar conta de email';

  @override
  String get profileEditVerifyEmailCta => 'Verificar email';

  @override
  String get profileEditTwoFactorShortLabel => 'Dois fatores';

  @override
  String get profileEditBmiCardTitle => 'Dados de IMC';

  @override
  String get profileEditBmiInfoTooltip => 'Informacoes de IMC/MVP';

  @override
  String get profileEditBmiCardBody =>
      'Para obter IMC, MVP e recomendacoes, preencha idade e altura.';

  @override
  String get profileEditAgeLabel => 'Idade';

  @override
  String get profileEditInvalidAge => 'Idade invalida';

  @override
  String get profileEditHeightLabel => 'Altura (cm)';

  @override
  String get profileEditInvalidHeight => 'Altura invalida';

  @override
  String get profileEditPasswordCardTitle => 'Alterar palavra-passe';

  @override
  String get profileEditPasswordHint =>
      'Deixe em branco para manter a palavra-passe atual';

  @override
  String get profileEditPasswordLabel => 'Palavra-passe';

  @override
  String get profileEditPasswordConfirmLabel => 'Confirmar palavra-passe';

  @override
  String get profileEditPasswordConfirmRequired =>
      'Tem de confirmar a palavra-passe';

  @override
  String get profileEditPasswordMismatch => 'As palavras-passe nao coincidem';

  @override
  String get profileEditSaveChanges => 'Guardar alteracoes';

  @override
  String get profileEditDeleteMyData => 'Eliminar todos os meus dados';

  @override
  String get profileEditChangeEmailTitle => 'Alterar email';

  @override
  String get profileEditChangeEmailVerifiedWarning =>
      'O email atual esta verificado. Se o alterar, tera de o verificar novamente.';

  @override
  String get profileEditChangeEmailNewLabel => 'Novo email';

  @override
  String get profileEditChangeEmailRequired => 'Deves indicar um email.';

  @override
  String get profileEditChangeEmailMustDiffer =>
      'Deves indicar um email diferente do atual.';

  @override
  String get profileEditChangeEmailValidationFailed =>
      'Nao foi possivel validar o email. Tenta novamente.';

  @override
  String get profileEditChangeEmailReview => 'Revise o email indicado.';

  @override
  String get profileEditEmailRequiredForVerification =>
      'Voce deve informar primeiro uma conta de e-mail.';

  @override
  String get profileEditEmailCodeSentGeneric => 'Codigo enviado.';

  @override
  String get profileEditEmailVerifiedGeneric => 'E-mail verificado.';

  @override
  String get profileEditEmailCodeLengthError => 'O codigo deve ter 10 digitos.';

  @override
  String get profileEditEmailCodeDialogTitle => 'Validar codigo de e-mail';

  @override
  String get profileEditEmailCodeTenDigitsLabel => 'Codigo de 10 digitos';

  @override
  String get profileEditValidateEmailCodeAction => 'Validar codigo de e-mail';

  @override
  String get profileEditVerifyEmailTitle => 'Verificar e-mail';

  @override
  String get profileEditVerifyEmailIntroPrefix =>
      'Precisamos verificar se este endereco de e-mail pertence a voce:';

  @override
  String get profileEditVerifyEmailPremiumLink =>
      'Ver beneficios Premium com e-mail verificado';

  @override
  String get profileEditFollowTheseSteps => 'Siga estes passos...';

  @override
  String get profileEditYourEmail => 'Seu e-mail';

  @override
  String profileEditSendCodeInstruction(Object email) {
    return 'Toque em \"Enviar codigo\" para enviar o codigo de verificacao para $email.';
  }

  @override
  String get profileEditEmailCodeSentInfo =>
      'Um codigo foi enviado para sua conta de e-mail. Ele expirara em 15 minutos. Se nao o encontrar na Caixa de entrada, verifique a pasta Spam.';

  @override
  String get profileEditEmailSendFailed =>
      'Nao foi possivel enviar o e-mail de verificacao neste momento. Tente novamente mais tarde.';

  @override
  String get profileEditSendCodeAction => 'Enviar codigo';

  @override
  String get profileEditResendCodeAction => 'Enviar novamente';

  @override
  String get profileEditVerifyCodeInstruction =>
      'Digite o codigo de verificacao que enviamos para voce.';

  @override
  String get profileEditVerificationCodeLabel => 'Codigo de verificacao';

  @override
  String get profileEditEmailRequiredInProfile =>
      'Voce deve informar primeiro um e-mail em Editar perfil para poder verifica-lo.';

  @override
  String get profileEditTwoFactorDialogTitle =>
      'Autenticacao em dois fatores (2FA)';

  @override
  String get profileEditTwoFactorEnabledStatus => 'Status: Ativado';

  @override
  String get profileEditTwoFactorEnabledBody =>
      'A autenticacao em dois fatores ja esta ativada na sua conta. A partir daqui, voce so pode verificar se este dispositivo e confiavel e vinculá-lo ou desvincula-lo.';

  @override
  String get profileEditTrustedDeviceEnabledBody =>
      'Este dispositivo esta marcado como confiavel. O codigo 2FA nao sera solicitado nos proximos logins ate que voce remova a confianca por aqui.';

  @override
  String get profileEditTrustedDeviceDisabledBody =>
      'Este dispositivo nao esta marcado como confiavel. Voce pode marca-lo tocando em \"Definir este dispositivo como confiavel\" ou encerrando a sessao e entrando novamente, ativando a opcao \"Confiar neste dispositivo\" durante a validacao 2FA.';

  @override
  String get profileEditRemoveTrustedDeviceAction =>
      'Remover confianca deste dispositivo';

  @override
  String get profileEditSetTrustedDeviceAction =>
      'Definir este dispositivo como confiavel';

  @override
  String get profileEditCancelProcess => 'Cancelar processo';

  @override
  String get profileEditSetTrustedDeviceTitle =>
      'Definir dispositivo confiavel';

  @override
  String get profileEditSetTrustedDeviceBody =>
      'Para marcar este dispositivo como confiavel, voce deve valida-lo no login 2FA, ativando a opcao \"Confiar neste dispositivo\".\n\nDeseja encerrar a sessao agora para fazer isso?';

  @override
  String get profileEditGoToLogin => 'Ir para o login';

  @override
  String get profileEditActivateTwoFactorTitle =>
      'Ativar autenticacao em dois fatores';

  @override
  String get profileEditActivateTwoFactorIntro =>
      'A autenticacao em dois fatores (2FA) adiciona uma camada extra de seguranca: alem da sua senha, sera solicitado um codigo temporario do seu aplicativo autenticador.';

  @override
  String get profileEditTwoFactorStep1 =>
      '1. Abra seu aplicativo autenticador e adicione uma nova conta.';

  @override
  String get profileEditTwoFactorSetupKeyLabel => 'Chave de configuracao';

  @override
  String get profileEditKeyCopied =>
      'Chave copiada para a area de transferencia';

  @override
  String get profileEditHideOptions => 'Ocultar opcoes';

  @override
  String get profileEditMoreOptions => 'Mais opcoes...';

  @override
  String profileEditQrSavedDownloads(Object path) {
    return 'QR salvo em Downloads: $path';
  }

  @override
  String get profileEditQrShared =>
      'O menu para compartilhar ou salvar o QR foi aberto.';

  @override
  String get profileEditOtpUrlCopied => 'URL otpauth copiada';

  @override
  String get profileEditCopyUrl => 'Copiar URL';

  @override
  String get profileEditOtpUrlInfo =>
      'A opcao \"Copiar URL\" copia um link otpauth com toda a configuracao 2FA para importa-la em aplicativos compativeis. Se o seu aplicativo nao permitir importacao por link, use \"Copiar\" na chave.';

  @override
  String get profileEditTwoFactorConfirmCodeInstruction =>
      'Digite o codigo de 6 digitos exibido no seu aplicativo autenticador para confirmar.';

  @override
  String get profileEditActivateTwoFactorAction => 'Ativar';

  @override
  String get profileEditTwoFactorActivated =>
      'Autenticacao em dois fatores ativada com sucesso';

  @override
  String get profileEditTwoFactorActivateFailed =>
      'Nao foi possivel ativar o 2FA.';

  @override
  String get profileEditNoQrData => 'Nao ha dados para salvar o QR.';

  @override
  String profileEditQrSavedPath(Object path) {
    return 'QR salvo em: $path';
  }

  @override
  String profileEditQrSaveFailed(Object error) {
    return 'Nao foi possivel salvar o QR: $error';
  }

  @override
  String get profileEditDeactivateTwoFactorTitle =>
      'Desativar autenticacao em dois fatores (2FA)';

  @override
  String get profileEditCurrentCodeSixDigitsLabel =>
      'Codigo atual de 6 digitos';

  @override
  String get profileEditDeactivateTwoFactorAction => 'Desativar';

  @override
  String get profileEditTwoFactorDeactivated =>
      'Autenticacao em dois fatores desativada com sucesso';

  @override
  String get profileEditTwoFactorDeactivateFailed =>
      'Nao foi possivel desativar o 2FA.';

  @override
  String get profileEditRemoveTrustedDeviceTitle =>
      'Remover confianca do dispositivo';

  @override
  String get profileEditRemoveTrustedDeviceBody =>
      'Neste dispositivo o codigo 2FA sera solicitado novamente no proximo login. Deseja continuar?';

  @override
  String get profileEditRemoveTrustedDeviceActionShort => 'Remover confianca';

  @override
  String get profileEditTrustedDeviceRemoved =>
      'Confianca do dispositivo removida.';

  @override
  String profileEditTrustedDeviceRemoveFailed(Object error) {
    return 'Nao foi possivel remover a confianca do dispositivo: $error';
  }

  @override
  String get profileEditMvpDialogTitle => 'Calculo MVP e formulas';

  @override
  String get profileEditMvpWhatIsTitle => 'O que e o MVP?';

  @override
  String get profileEditMvpWhatIsBody =>
      'MVP e um conjunto minimo de indicadores antropometricos para ajudar voce a monitorar de forma simples sua evolucao de saude: IMC, cintura/altura e cintura/quadril.';

  @override
  String get profileEditMvpFormulasTitle => 'Formulas usadas e sua origem:';

  @override
  String get profileEditMvpOriginBmi =>
      'Origem: OMS (classificacao do IMC em adultos).';

  @override
  String get profileEditMvpOriginWhtr => 'Origem: indice cintura-altura.';

  @override
  String get profileEditMvpOriginWhr =>
      'Origem: relacao cintura-quadril (OMS, obesidade abdominal).';

  @override
  String get profileEditImportantNotice => 'Aviso importante';

  @override
  String get profileEditMvpImportantNoticeBody =>
      'Esses calculos e classificacoes sao orientativos. Para uma avaliacao personalizada, consulte sempre um profissional de saude, dietista-nutricionista ou personal trainer.';

  @override
  String get profileEditAccept => 'Aceitar';

  @override
  String get profileEditNotAvailable => 'N/D';

  @override
  String get profileEditSessionDate => 'Data';

  @override
  String get profileEditSessionTime => 'Hora';

  @override
  String get profileEditSessionDevice => 'Dispositivo';

  @override
  String get profileEditSessionIp => 'Endereco IP:';

  @override
  String get profileEditSessionPublicIp => 'Publico';

  @override
  String get profileEditUserCodeUnavailable =>
      'Codigo de utilizador indisponivel';

  @override
  String get profileEditGenericError => 'Erro';

  @override
  String get profileEditRetry => 'Tentar novamente';

  @override
  String get profileEditSessionDataUnavailable =>
      'Nao foi possivel aceder aos dados de inicios de sessao neste momento.';

  @override
  String get profileEditNoSessionData => 'Sem dados de acesso disponiveis';

  @override
  String get profileEditSuccessfulSessionsTitle =>
      'Ultimos acessos com sucesso';

  @override
  String get profileEditCurrentSession => 'Sessao atual:';

  @override
  String get profileEditPreviousSession => 'Sessao anterior:';

  @override
  String get profileEditNoSuccessfulSessions =>
      'Nenhum acesso com sucesso registado';

  @override
  String get profileEditFailedAttemptsTitle =>
      'Ultimas tentativas de acesso falhadas';

  @override
  String profileEditAttemptLabel(Object count) {
    return 'Tentativa $count:';
  }

  @override
  String get profileEditNoFailedAttempts =>
      'Nenhuma tentativa falhada registada.';

  @override
  String get profileEditSessionStatsTitle => 'Estatisticas de sessao';

  @override
  String profileEditTotalSessions(Object count) {
    return 'Total de acessos: $count';
  }

  @override
  String profileEditSuccessfulAttempts(Object count) {
    return 'Tentativas com sucesso: $count';
  }

  @override
  String profileEditFailedAttempts(Object count) {
    return 'Tentativas falhadas: $count';
  }

  @override
  String get navRecommendations => 'Recommendations';

  @override
  String get navExerciseCatalog => 'Exercise catalog';

  @override
  String get exerciseCatalogSearchFieldLabel => 'Search in';

  @override
  String get exerciseCatalogSearchFieldAll => 'All';

  @override
  String get exerciseCatalogSearchFieldTitle => 'Title';

  @override
  String get exerciseCatalogSearchFieldInstructions => 'Instructions';

  @override
  String get exerciseCatalogSearchFieldHashtags => 'Hashtags';

  @override
  String get exerciseCatalogSearchLabel => 'Search exercises';

  @override
  String get exerciseCatalogSearchHint =>
      'Type to search in the selected field';

  @override
  String get exerciseCatalogClearSearch => 'Clear search';

  @override
  String get exerciseCatalogHideSearch => 'Hide search';

  @override
  String get navWeightControl => 'Controlo do peso';

  @override
  String get navShoppingList => 'Shopping list';

  @override
  String get navStartRegistration => 'Start registration';

  @override
  String get navPreviewRegisteredUser => 'Preview as registered user';

  @override
  String get navPreviewGuestUser => 'Preview as unregistered user';

  @override
  String get drawerGuestUser => 'Guest user';

  @override
  String get drawerAdminUser => 'Administrator user';

  @override
  String get drawerPremiumPatientUser => 'Premium patient user';

  @override
  String get drawerPatientUser => 'Patient user';

  @override
  String get drawerPremiumRegisteredUser => 'Premium registered user';

  @override
  String get drawerRegisteredUser => 'Registered user';

  @override
  String get drawerPremiumBadge => 'PREMIUM';

  @override
  String get drawerRestrictedNutriPlansTitle => 'Nutrition plans';

  @override
  String get drawerRestrictedTrainingTitle => 'Personalized training';

  @override
  String get drawerRestrictedRecommendationsTitle => 'Recommendations';

  @override
  String get drawerRegistrationRequiredTitle => 'Registration required';

  @override
  String get drawerRegistrationRequiredChatMessage =>
      'To chat with your online dietitian, please register first. It\'s free.';

  @override
  String get homePaymentNotifiedTitle => 'Payment notified to NutriFit';

  @override
  String get homePaymentNotifiedMessage =>
      'We have received your payment notification. Your Premium account will be activated once NutriFit receives and verifies the payment. We will notify you by email and through the in-app chat. The Premium period starts from the payment verification date.';

  @override
  String get homePremiumExpiredTitle => 'Your Premium has expired';

  @override
  String get homePremiumExpiringTitle => 'Your Premium is about to expire';

  @override
  String homePremiumExpiredMessage(Object date) {
    return 'Your Premium expired on $date. You can renew it now.';
  }

  @override
  String homePremiumExpiringTodayMessage(Object date) {
    return 'Your Premium expires on $date (today). We recommend renewing it so you don\'t lose your benefits.';
  }

  @override
  String homePremiumExpiringInDaysMessage(Object date, Object days) {
    return 'Your Premium expires on $date (in $days days). We recommend renewing it so you don\'t lose your benefits.';
  }

  @override
  String get homeRenewPremium => 'Renew Premium';

  @override
  String get homeSecurityRecommendedTitle => 'Recommended security';

  @override
  String get homeSecurityRecommendedBody =>
      'You work with sensitive medical data. We recommend enabling two-factor authentication (2FA) to better protect your account.';

  @override
  String get homeGoToEditProfile => 'Go to Edit Profile';

  @override
  String get homeDoNotShowAgain => 'Do not show again';

  @override
  String get loginNetworkError =>
      'There is a problem with the internet connection or the app does not have permission to connect.';

  @override
  String get loginInvalidCredentials =>
      'Utilizador ou palavra-passe incorretos.';

  @override
  String get loginFailedGeneric =>
      'Sign-in could not be completed. Please try again.';

  @override
  String get loginGuestFailedGeneric =>
      'Guest access could not be completed. Please try again.';

  @override
  String get loginUnknownUserType => 'Tipo de utilizador desconhecido';

  @override
  String get loginTwoFactorTitle => 'Verificacao 2FA';

  @override
  String get loginTwoFactorPrompt =>
      'Introduz o codigo de 6 digitos da tua app TOTP.';

  @override
  String get loginTwoFactorCodeLabel => 'Codigo 2FA';

  @override
  String get loginTrustThisDevice => 'Confiar neste dispositivo';

  @override
  String get loginTrustThisDeviceSubtitle =>
      'A 2FA deixara de ser pedida neste dispositivo.';

  @override
  String get loginCodeMustHave6Digits => 'O codigo deve ter 6 digitos.';

  @override
  String get loginRecoveryTitle => 'Recuperar acesso';

  @override
  String get loginRecoveryIdentifierIntro =>
      'Introduz o teu utilizador (nick) ou o teu email para recuperar o acesso.';

  @override
  String get loginUserOrEmailLabel => 'Utilizador ou email';

  @override
  String get loginEnterUserOrEmail => 'Introduz um utilizador ou email.';

  @override
  String get loginNoRecoveryMethods =>
      'Este utilizador nao tem metodos de recuperacao disponiveis.';

  @override
  String get loginSelectRecoveryMethod => 'Seleciona o metodo de recuperacao';

  @override
  String get loginRecoveryByEmail => 'Usando o teu email';

  @override
  String get loginRecoveryByTwoFactor =>
      'Usando a autenticacao de dois fatores (2FA)';

  @override
  String get loginEmailRecoveryIntro =>
      'Vamos enviar-te um codigo de recuperacao por email. Introdu-lo aqui juntamente com a tua nova palavra-passe.';

  @override
  String get loginRecoveryStep1SendCode => 'Passo 1: Enviar codigo';

  @override
  String get loginRecoveryStep1SendCodeBody =>
      'Toca em \"Enviar codigo\" para receberes um codigo de recuperacao no teu email.';

  @override
  String get loginSendCode => 'Enviar codigo';

  @override
  String get loginRecoveryStep2VerifyCode => 'Passo 2: Verificar codigo';

  @override
  String get loginRecoveryStep2VerifyCodeBody =>
      'Introduz o codigo que recebeste no teu email.';

  @override
  String get loginRecoveryCodeLabel => 'Codigo de recuperacao';

  @override
  String get loginRecoveryCodeHintAlpha => 'Ex. 1a3B';

  @override
  String get loginRecoveryCodeHintNumeric => 'Ex. 1234';

  @override
  String get loginVerifyCode => 'Verificar codigo';

  @override
  String get loginRecoveryStep3NewPassword => 'Passo 3: Nova palavra-passe';

  @override
  String get loginRecoveryStep3NewPasswordBody =>
      'Introduz a tua nova palavra-passe.';

  @override
  String get loginNewPasswordLabel => 'Nova palavra-passe';

  @override
  String get loginRepeatNewPasswordLabel => 'Repetir nova palavra-passe';

  @override
  String get loginBothPasswordsRequired =>
      'Preenche ambos os campos da palavra-passe.';

  @override
  String get loginPasswordsMismatch => 'As palavras-passe nao coincidem.';

  @override
  String get loginPasswordResetSuccess =>
      'Palavra-passe reposta. Ja podes entrar.';

  @override
  String get loginTwoFactorRecoveryIntro =>
      'Para repores a palavra-passe com autenticacao de dois fatores, precisas do codigo temporario da tua app.';

  @override
  String get loginTwoFactorRecoveryStep1 =>
      'Passo 1: Abre a tua app de autenticacao';

  @override
  String get loginTwoFactorRecoveryStep1Body =>
      'Procura o codigo temporario de 6 digitos na tua app de autenticacao (Google Authenticator, Microsoft Authenticator, Authy, etc.)';

  @override
  String get loginIHaveIt => 'Ja o tenho';

  @override
  String get loginTwoFactorRecoveryStep2 =>
      'Passo 2: Verifica o teu codigo 2FA';

  @override
  String get loginTwoFactorRecoveryStep2Body =>
      'Introduz o codigo de 6 digitos no campo abaixo.';

  @override
  String get loginTwoFactorCodeSixDigitsLabel => 'Codigo 2FA (6 digitos)';

  @override
  String get loginTwoFactorCodeHint => '000000';

  @override
  String get loginVerifyTwoFactorCode => 'Verificar codigo 2FA';

  @override
  String get loginCodeMustHaveExactly6Digits =>
      'O codigo deve ter exatamente 6 digitos.';

  @override
  String get loginPasswordUpdatedSuccess =>
      'Palavra-passe atualizada. Ja podes entrar.';

  @override
  String get loginUsernameLabel => 'Utilizador';

  @override
  String get loginEnterUsername => 'Introduz o teu utilizador';

  @override
  String get loginPasswordLabel => 'Palavra-passe';

  @override
  String get loginEnterPassword => 'Introduz a tua palavra-passe';

  @override
  String get loginSignIn => 'Entrar';

  @override
  String get loginForgotPassword => 'Esqueceste-te da palavra-passe?';

  @override
  String get loginGuestInfo =>
      'Acede gratis a NutriFit para consultar conselhos de saude e nutricao, videos de exercicios, receitas, controlo de peso e muito mais.';

  @override
  String get loginGuestAccess => 'Aceder sem credenciais';

  @override
  String get loginRegisterFree => 'Regista-te gratis';

  @override
  String get registerCreateAccountTitle => 'Criar conta';

  @override
  String get registerFullNameLabel => 'Nome completo';

  @override
  String get registerEnterFullName => 'Introduz o teu nome';

  @override
  String get registerUsernameMinLength =>
      'O utilizador deve ter pelo menos 3 caracteres';

  @override
  String get registerEmailLabel => 'Email';

  @override
  String get registerInvalidEmail => 'Email invalido';

  @override
  String get registerAdditionalDataTitle => 'Dados adicionais';

  @override
  String get registerAdditionalDataCollapsedSubtitle =>
      'Idade e altura (opcionais)';

  @override
  String get registerAdditionalDataExpandedSubtitle =>
      'Idade e altura para IMC/MVP';

  @override
  String get registerAdditionalDataInfo =>
      'Para ativar o calculo do IMC, MVP e metricas de saude, indica a idade e a altura (em centimetros).';

  @override
  String get registerAgeLabel => 'Idade';

  @override
  String get registerInvalidAge => 'Idade invalida';

  @override
  String get registerHeightLabel => 'Altura (cm)';

  @override
  String get registerInvalidHeight => 'Altura invalida';

  @override
  String get registerConfirmPasswordLabel => 'Confirmar palavra-passe';

  @override
  String get registerConfirmPasswordRequired => 'Confirma a tua palavra-passe';

  @override
  String get registerCreateAccountButton => 'Criar conta';

  @override
  String get registerAlreadyHaveAccount => 'Ja tens conta? Inicia sessao';

  @override
  String get registerEmailUnavailable =>
      'Esta conta de email nao pode ser utilizada. Indica outra.';

  @override
  String get registerSuccessMessage =>
      'Utilizador registado com sucesso. Inicia sessao com os teus dados (utilizador e palavra-passe).';

  @override
  String get registerNetworkError =>
      'Nao foi possivel concluir o processo. Verifica a ligacao a Internet.';

  @override
  String get registerGenericError => 'Erro ao registar';

  @override
  String get loginResetPassword => 'Repor palavra-passe';

  @override
  String get loginEmailRecoverySendFailedGeneric =>
      'Nao foi possivel enviar o email de recuperacao neste momento. Tenta novamente mais tarde.';

  @override
  String get passwordChecklistTitle => 'Requisitos da palavra-passe:';

  @override
  String passwordChecklistMinLength(Object count) {
    return 'Minimo de $count caracteres';
  }

  @override
  String get passwordChecklistUpperLower =>
      'Pelo menos uma letra maiuscula e uma minuscula';

  @override
  String get passwordChecklistNumber => 'Pelo menos um numero (0-9)';

  @override
  String get passwordChecklistSpecial =>
      'Pelo menos um caractere especial (*,.+-#\\\$?¿!¡_()/\\%&)';

  @override
  String loginPasswordMinLengthError(Object count) {
    return 'A nova palavra-passe deve ter pelo menos $count caracteres.';
  }

  @override
  String get loginPasswordUppercaseError =>
      'A nova palavra-passe deve conter pelo menos uma letra maiuscula.';

  @override
  String get loginPasswordLowercaseError =>
      'A nova palavra-passe deve conter pelo menos uma letra minuscula.';

  @override
  String get loginPasswordNumberError =>
      'A nova palavra-passe deve conter pelo menos um numero.';

  @override
  String get loginPasswordSpecialError =>
      'A nova palavra-passe deve conter pelo menos um caractere especial (* , . + - # \\\$ ? ¿ ! ¡ _ ( ) / \\ % &).';

  @override
  String get commonOk => 'OK';

  @override
  String get commonReadMore => 'Read more';

  @override
  String get commonViewAll => 'View all';

  @override
  String get commonCouldNotOpenLink => 'The link could not be opened';

  @override
  String get commonCollapse => 'Collapse';

  @override
  String get commonExpand => 'Expand';

  @override
  String get patientSecurityRecommendedTitle => 'Improve your account security';

  @override
  String get patientSecurityRecommendedBody =>
      'We recommend enabling two-factor authentication (2FA). Add an extra layer of protection beyond your password.';

  @override
  String get patientChatLoadError =>
      'The process could not be completed. Please check your internet connection';

  @override
  String get patientAdherenceNutriPlan => 'Plano nutricional';

  @override
  String get patientAdherenceFitPlan => 'Plano Fit';

  @override
  String get patientAdherenceCompleted => 'Cumprido';

  @override
  String get patientAdherencePartial => 'Parcial';

  @override
  String get patientAdherenceNotDone => 'Nao realizado';

  @override
  String get patientAdherenceNoChanges => 'Sem alteracoes';

  @override
  String patientAdherenceTrendPoints(Object trend) {
    return '$trend pts';
  }

  @override
  String get patientAdherenceTitle => 'Cumprimento';

  @override
  String get patientAdherenceImprovementPoints => 'Pontos de melhoria';

  @override
  String get patientAdherenceImprovementNutriTarget =>
      'Nutri: tenta cumprir pelo menos 5 de 7 dias esta semana.';

  @override
  String get patientAdherenceImprovementNutriTrend =>
      'Nutri: estas a descer face a semana passada; volta a tua rotina base.';

  @override
  String get patientAdherenceImprovementFitTarget =>
      'Fit: tenta chegar a 3-4 sessoes por semana, mesmo que sejam curtas.';

  @override
  String get patientAdherenceImprovementFitTrend =>
      'Fit: a tendencia desceu; agenda hoje as proximas sessoes.';

  @override
  String get patientAdherenceImprovementKeepGoing =>
      'Bom ritmo. Mantem a consistencia para consolidar resultados.';

  @override
  String get patientAdherenceSheetTitleToday => 'Cumprimento para hoje';

  @override
  String patientAdherenceSheetTitleForDate(Object date) {
    return 'Cumprimento para $date';
  }

  @override
  String get patientAdherenceDateToday => 'hoje';

  @override
  String patientAdherenceStatusSaved(Object plan, Object status, Object date) {
    return '$plan: $status $date';
  }

  @override
  String get patientAdherenceFutureDateError =>
      'Nao e possivel registar cumprimento em datas futuras. So hoje ou dias anteriores.';

  @override
  String get patientAdherenceReasonNotDoneTitle => 'Motivo da nao realizacao';

  @override
  String get patientAdherenceReasonPartialTitle =>
      'Motivo do cumprimento parcial';

  @override
  String get patientAdherenceReasonHint =>
      'Conta-nos brevemente o que aconteceu hoje';

  @override
  String get patientAdherenceSkipReason => 'Omitir motivo';

  @override
  String get patientAdherenceSaveContinue => 'Guardar e continuar';

  @override
  String patientAdherenceSaveError(Object error) {
    return 'Nao foi possivel guardar na base de dados: $error';
  }

  @override
  String get patientAdherenceReasonLabel => 'Motivo';

  @override
  String get patientAdherenceInfoTitle =>
      'O que significa cada estado de cumprimento?';

  @override
  String get patientAdherenceNutriCompletedDescription =>
      'Seguiste o plano alimentar tal como estava previsto para este dia.';

  @override
  String get patientAdherenceNutriPartialDescription =>
      'Seguiste parte do plano, mas nao por completo: alguma refeicao foi omitida, alterada ou com quantidade diferente.';

  @override
  String get patientAdherenceNutriNotDoneDescription =>
      'Nao seguiste o plano alimentar neste dia.';

  @override
  String get patientAdherenceFitCompletedDescription =>
      'Realizaste o treino completo previsto para este dia.';

  @override
  String get patientAdherenceFitPartialDescription =>
      'Fizeste parte do treino: alguns exercicios, series ou tempo ficaram incompletos.';

  @override
  String get patientAdherenceFitNotDoneDescription =>
      'Nao realizaste o treino neste dia.';

  @override
  String get patientAdherenceAlertRecoveryTitle => 'Hora de reagir';

  @override
  String patientAdherenceAlertRecoveryBody(Object plan) {
    return 'Estas ha duas semanas seguidas abaixo dos 50% em $plan. Vamos recuperar o ritmo ja: pequenos passos diarios, mas sem falhar. Consegues, mas e hora de levar isto a serio.';
  }

  @override
  String get patientAdherenceAlertEncouragementTitle => 'Ainda vamos a tempo';

  @override
  String patientAdherenceAlertEncouragementBody(Object plan) {
    return 'Esta semana $plan esta abaixo dos 50%. A proxima pode ser muito melhor: volta a tua rotina base e soma uma vitoria por dia.';
  }

  @override
  String get patientRecommendationsForYou => 'Recommendations for you';

  @override
  String get patientWelcomeNeutral => 'Welcome';

  @override
  String get patientWelcomeFemale => 'Welcome';

  @override
  String get patientWelcomeMale => 'Welcome';

  @override
  String patientWelcomeToNutriFit(Object welcome) {
    return '$welcome to NutriFit';
  }

  @override
  String get patientWelcomeBody =>
      'From NutriFit you can review your personalized nutrition and training plans. You can chat with and contact your online dietitian and read personalized recommendations. \n\nYou also have nutrition and health tips, recipes, a shopping list, food information, measurements (weight control), blood pressure, and many other features...';

  @override
  String get patientPersonalRecommendation => 'Personal recommendation';

  @override
  String get patientNewBadge => 'NEW';

  @override
  String get patientContactDietitianPrompt => 'Contactar o dietista...';

  @override
  String get patientContactDietitianTrainer => 'Contactar Dietista/Treinador';

  @override
  String get contactDietitianMethodsTitle => 'Formas de contacto';

  @override
  String get contactDietitianEmailLabel => 'Email';

  @override
  String get contactDietitianCallLabel => 'Ligar';

  @override
  String get contactDietitianSocialTitle => 'Segue-nos nas redes sociais';

  @override
  String get contactDietitianWebsiteLabel => 'Site web';

  @override
  String get contactDietitianPhoneCopied =>
      'Telefone copiado para a area de transferencia.';

  @override
  String get contactDietitianWhatsappInvalidPhone =>
      'Nao existe um numero valido para abrir o WhatsApp.';

  @override
  String contactDietitianWhatsappOpenError(Object error) {
    return 'Nao foi possivel abrir o WhatsApp: $error';
  }

  @override
  String get contactDietitianWhatsappDialogTitle => 'Contactar por WhatsApp';

  @override
  String contactDietitianWhatsappDialogBody(Object phone) {
    return 'Podes abrir o chat do WhatsApp diretamente com o numero $phone. Tambem podes copiar o numero para a area de transferencia para o usar na tua aplicacao do WhatsApp ou guarda-lo.';
  }

  @override
  String get contactDietitianCopyPhone => 'Copiar telefone';

  @override
  String get contactDietitianOpenWhatsapp => 'Abrir WhatsApp';

  @override
  String get contactDietitianWhatsappLabel => 'WhatsApp';

  @override
  String get contactDietitianTelegramLabel => 'Telegram';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatHideSearch => 'Hide search';

  @override
  String get chatSearch => 'Search';

  @override
  String get chatSearchHint => 'Search in chat...';

  @override
  String get chatMessageHint => 'Escreve uma mensagem';

  @override
  String get profileImagePickerDialogTitle => 'Selecionar imagem de perfil';

  @override
  String get profileImagePickerTakePhoto => 'Tirar foto';

  @override
  String get profileImagePickerChooseFromGallery => 'Escolher da galeria';

  @override
  String get profileImagePickerSelectImage => 'Selecionar imagem';

  @override
  String get profileImagePickerRemovePhoto => 'Remover foto';

  @override
  String get profileImagePickerPrompt => 'Seleciona a tua imagem de perfil';

  @override
  String profileImagePickerMaxDimensions(Object width, Object height) {
    return 'Max. ${width}x${height}px';
  }

  @override
  String profileImagePickerSaved(Object sizeKb) {
    return 'Imagem guardada com sucesso (${sizeKb}KB)';
  }

  @override
  String get profileImagePickerProcessError => 'Erro ao processar a imagem';

  @override
  String get profileImagePickerTechnicalDetails => 'Detalhes tecnicos';

  @override
  String get profileImagePickerOperationFailed =>
      'Nao foi possivel concluir a operacao. Tenta novamente ou contacta o suporte.';

  @override
  String get shoppingListPremiumTitle => 'Lista de compras Premium';

  @override
  String shoppingListPremiumSubtitle(Object limit) {
    return 'You can view the last $limit items and create up to $limit records. If you want an unlimited list, ';
  }

  @override
  String get shoppingListPremiumHighlight => 'go Premium.';

  @override
  String shoppingListPremiumLimitMessage(Object limit) {
    return 'As a non-Premium user you can create up to $limit items in the shopping list. Go Premium to add unlimited items and access the full history.';
  }

  @override
  String get shoppingListTabAll => 'All';

  @override
  String get shoppingListTabPending => 'Next purchase';

  @override
  String get shoppingListTabBought => 'Bought';

  @override
  String get shoppingListTabExpiring => 'Expiring soon';

  @override
  String get shoppingListTabExpired => 'Expired';

  @override
  String get shoppingListFilterCategories => 'Filter categories';

  @override
  String shoppingListFilterCategoriesCount(Object count) {
    return 'Filter categories ($count)';
  }

  @override
  String get shoppingListMoreOptions => 'More options';

  @override
  String get shoppingListFilter => 'Filter';

  @override
  String get shoppingListRefresh => 'Refresh';

  @override
  String get shoppingListAddItem => 'Add item';

  @override
  String get shoppingListGuestMessage =>
      'To use the shopping list, you need to sign up. It\'s free.';

  @override
  String get weightControlBack => 'Voltar';

  @override
  String get weightControlChangeTarget => 'Alterar peso objetivo';

  @override
  String get weightControlHideFilter => 'Ocultar filtro';

  @override
  String get weightControlShowFilter => 'Mostrar filtro';

  @override
  String get weightControlGuestMessage =>
      'Para gerir o registo do peso, tens de te registar. E gratis.';

  @override
  String weightControlLoadError(Object error) {
    return 'Erro ao carregar medicoes: $error';
  }

  @override
  String get weightControlNoMeasurementsTitle =>
      'Ainda nao existem medicoes registadas.';

  @override
  String get weightControlNoMeasurementsBody =>
      'Comeca por adicionar a tua primeira medicao para veres o progresso.';

  @override
  String get weightControlAddMeasurement => 'Adicionar medicao';

  @override
  String weightControlNoWeightsForPeriod(Object period) {
    return 'Nao ha pesos para $period.';
  }

  @override
  String weightControlNoMeasurementsForPeriod(Object period) {
    return 'Nao ha medicoes para $period.';
  }

  @override
  String get weightControlPremiumPerimetersTitle =>
      'Evolucao Premium dos perimetros';

  @override
  String get weightControlPremiumChartBody =>
      'Este grafico esta disponivel apenas para utilizadores Premium. Ativa a tua conta para veres todo o teu progresso com indicadores visuais avancados.';

  @override
  String get weightControlCurrentMonth => 'Mes atual';

  @override
  String get weightControlPreviousMonth => 'Mes anterior';

  @override
  String get weightControlQuarter => 'Trimestre';

  @override
  String get weightControlSemester => 'Semestre';

  @override
  String get weightControlCurrentYear => 'Ano atual';

  @override
  String get weightControlPreviousYear => 'Ano anterior';

  @override
  String get weightControlAllTime => 'Todo o periodo';

  @override
  String weightControlLastDaysLabel(Object days) {
    return 'Ultimos $days dias';
  }

  @override
  String get patientMoreContactOptions => 'More contact options';

  @override
  String get patientContactEmailShort => 'Email...';

  @override
  String get patientContactWhatsAppShort => 'WhatsApp...';

  @override
  String get patientContactTelegramShort => 'Telegram...';

  @override
  String get patientContactEmailSubject =>
      'Request for Online Dietitian services';

  @override
  String get patientAddDietitianToContactsTitle => 'Add dietitian to contacts';

  @override
  String get patientAddDietitianToContactsBody =>
      'Please add the dietitian manually to your contacts with the following details:\n\nName: Online Dietitian - NutriFit';

  @override
  String patientViewAllTipsCount(Object count) {
    return 'View all tips ($count)';
  }

  @override
  String get settingsNotificationsTab => 'Notifications';

  @override
  String get settingsLegendsTab => 'Legends';

  @override
  String get settingsCalendarsTab => 'Calendars';

  @override
  String get settingsPushPreferenceSaveError =>
      'The push notification preference could not be saved.';

  @override
  String get settingsScannerFrameReset =>
      'Scanner frame reset to default values';

  @override
  String settingsCurrentView(Object mode) {
    return 'Current view: $mode';
  }

  @override
  String get settingsCalendarModeWeek => 'Week';

  @override
  String get settingsCalendarModeMonth => 'Month';

  @override
  String get settingsCalendarModeTwoWeeks => '2 weeks';

  @override
  String get settingsNutriBreachTitle => 'Nutri plan breach alerts';

  @override
  String get settingsNutriBreachSubtitle =>
      'Receive notifications when the nutrition plan is not followed.';

  @override
  String get settingsFitBreachTitle => 'Fit plan breach alerts';

  @override
  String get settingsFitBreachSubtitle =>
      'Receive notifications when the training plan is not followed.';

  @override
  String get settingsChatPushTitle => 'Enable chat push notifications';

  @override
  String get settingsChatPushSubtitle =>
      'Receive push notifications when you have unread messages from the dietitian.';

  @override
  String get settingsPerimetersLegendTitle => 'Perimeter evolution';

  @override
  String get settingsPerimetersLegendSubtitle =>
      'Show or hide the legend in the perimeter evolution chart.';

  @override
  String get settingsWeightCalendarLegendTitle => 'Weight control calendar';

  @override
  String get settingsWeightCalendarLegendSubtitle =>
      'Show or hide the legend of the weight control calendar (lost weight, gained weight, no changes, normal BMI, BMI out of range, and higher weight/lower BMI).';

  @override
  String get settingsTasksCalendarLegendTitle => 'Task calendar';

  @override
  String get settingsTasksCalendarLegendSubtitle =>
      'Future legend. This preference will be applied to the task calendar soon.';

  @override
  String get settingsTasksCalendarTitle => 'Task calendar';

  @override
  String get settingsWeightControlCalendarTitle =>
      'Measurements calendar (weight control)';

  @override
  String get settingsNutriCalendarTitle => 'Nutri plans calendar';

  @override
  String get settingsFitCalendarTitle => 'Fit plans calendar';

  @override
  String get settingsShowActivityEquivalencesTitle =>
      'Show activity equivalences';

  @override
  String get settingsShowActivityEquivalencesSubtitle =>
      'Enable or disable equivalence messages on the activities screen.';

  @override
  String get settingsScannerFrameWidthTitle => 'Scanner frame width';

  @override
  String get settingsScannerFrameWidthSubtitle =>
      'Applies when taking a photo in label scanning and in the shopping list.';

  @override
  String get settingsScannerFrameHeightTitle => 'Scanner frame height';

  @override
  String get settingsScannerFrameHeightSubtitle =>
      'Adjust the height of the barcode framing area.';

  @override
  String get settingsResetScannerFrameSize => 'Reset size';

  @override
  String get commonPremiumFeatureTitle => 'Funcionalidade Premium';

  @override
  String get commonSearch => 'Pesquisar';

  @override
  String get commonFilter => 'Filtrar';

  @override
  String get commonRefresh => 'Atualizar';

  @override
  String get commonMoreOptions => 'Mais opcoes';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonClear => 'Limpar';

  @override
  String get commonApply => 'Aplicar';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonGeneratePdf => 'Gerar PDF';

  @override
  String get commonHideSearch => 'Ocultar pesquisa';

  @override
  String get commonFilterByCategories => 'Filtrar por categorias';

  @override
  String commonFilterByCategoriesCount(Object count) {
    return 'Filtrar categorias ($count)';
  }

  @override
  String get commonMatchAll => 'Corresponder a todas';

  @override
  String get commonRequireAllSelected =>
      'Se estiver ativo, exige todas as selecionadas.';

  @override
  String commonCategoryFallback(Object id) {
    return 'Categoria $id';
  }

  @override
  String get commonSignInToLike =>
      'Voce precisa iniciar sessao para curtir isto';

  @override
  String get commonSignInToSaveFavorites =>
      'Voce precisa iniciar sessao para salvar favoritos';

  @override
  String get commonCouldNotIdentifyUser =>
      'Erro: nao foi possivel identificar o usuario';

  @override
  String commonLikeChangeError(Object error) {
    return 'Erro ao alterar a curtida. $error';
  }

  @override
  String commonFavoriteChangeError(Object error) {
    return 'Erro ao alterar o favorito. $error';
  }

  @override
  String commonGuestFavoritesRequiresRegistration(Object itemType) {
    return 'Para marcar $itemType como favorito, voce precisa se registrar (e gratis).';
  }

  @override
  String get commonRecipesAndTipsPremiumCopyPdfMessage =>
      'Para copiar e exportar receitas e dicas em PDF, voce precisa ser um usuario Premium.';

  @override
  String get commonCopiedToClipboard => 'Copiado para a area de transferencia';

  @override
  String commonCopiedToClipboardLabel(Object label) {
    return '$label copiado para a area de transferencia.';
  }

  @override
  String get commonLanguage => 'Idioma';

  @override
  String get commonUser => 'usuario';

  @override
  String get languageSpanish => 'Espanhol';

  @override
  String get languageEnglish => 'Ingles';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageGerman => 'Alemao';

  @override
  String get languageFrench => 'Frances';

  @override
  String get languagePortuguese => 'Portugues';

  @override
  String commonCopyError(Object error) {
    return 'Erro ao copiar: $error';
  }

  @override
  String commonGeneratePdfError(Object error) {
    return 'Erro ao gerar PDF: $error';
  }

  @override
  String commonOpenLinkError(Object error) {
    return 'Erro ao abrir o link: $error';
  }

  @override
  String get commonDocumentUnavailable => 'O documento nao esta disponivel';

  @override
  String commonDecodeError(Object error) {
    return 'Erro ao decodificar: $error';
  }

  @override
  String get commonSaveDocumentError =>
      'Erro: nao foi possivel salvar o documento';

  @override
  String commonOpenDocumentError(Object error) {
    return 'Erro ao abrir o documento: $error';
  }

  @override
  String get commonDownloadDocument => 'Baixar documento';

  @override
  String get commonDocumentsAndLinks => 'Documentos e links';

  @override
  String get commonYouMayAlsoLike => 'Voce tambem pode gostar...';

  @override
  String get commonSortByTitle => 'Ordenar por titulo';

  @override
  String get commonSortByRecent => 'Ordenar por recentes';

  @override
  String get commonSortByPopular => 'Ordenar por populares';

  @override
  String get commonPersonalTab => 'Pessoais';

  @override
  String get commonFeaturedTab => 'Em destaque';

  @override
  String get commonAllTab => 'Todos';

  @override
  String get commonFavoritesTab => 'Favoritos';

  @override
  String get commonFeaturedFeminineTab => 'Em destaque';

  @override
  String get commonAllFeminineTab => 'Todas';

  @override
  String get commonFavoritesFeminineTab => 'Favoritas';

  @override
  String commonLikesCount(Object count) {
    return '$count curtidas';
  }

  @override
  String get commonLink => 'Link';

  @override
  String get commonTipItem => 'dica';

  @override
  String get commonRecipeItem => 'receita';

  @override
  String get commonAdditiveItem => 'aditivo';

  @override
  String get commonSupplementItem => 'suplemento';

  @override
  String commonSeeLinkToType(Object type) {
    return 'Ver link para $type';
  }

  @override
  String get commonDocument => 'Documento';

  @override
  String get todoPriorityHigh => 'Alta';

  @override
  String get todoPriorityMedium => 'Media';

  @override
  String get todoPriorityLow => 'Baixa';

  @override
  String get todoStatusPending => 'Pendente';

  @override
  String get todoStatusResolved => 'Concluida';

  @override
  String todoCalendarPriority(Object value) {
    return 'Prioridade: $value';
  }

  @override
  String todoCalendarStatus(Object value) {
    return 'Status: $value';
  }

  @override
  String todoExportError(Object error) {
    return 'Erro ao exportar a tarefa: $error';
  }

  @override
  String get todoDateRequiredForCalendar =>
      'A tarefa precisa ter uma data para ser adicionada ao calendario';

  @override
  String todoAddToCalendarError(Object error) {
    return 'Nao foi possivel adicionar a tarefa ao calendario: $error';
  }

  @override
  String todoPremiumLimitMessage(int limit) {
    return 'Como usuario nao Premium, voce pode criar ate $limit tarefas. Torne-se Premium para adicionar tarefas ilimitadas e consultar todo o historico.';
  }

  @override
  String get todoNoDate => 'Sem data';

  @override
  String get todoPriorityHighTooltip => 'Prioridade alta';

  @override
  String get todoPriorityMediumTooltip => 'Prioridade media';

  @override
  String get todoPriorityLowTooltip => 'Prioridade baixa';

  @override
  String get todoStatusResolvedShort => 'Feita (F)';

  @override
  String get todoStatusPendingShort => 'Pendente (P)';

  @override
  String get todoMarkPending => 'Marcar como pendente';

  @override
  String get todoMarkResolved => 'Marcar como concluida';

  @override
  String get todoEditTaskTitle => 'Editar tarefa';

  @override
  String get todoNewTaskTitle => 'Nova tarefa';

  @override
  String get todoTitleLabel => 'Titulo';

  @override
  String get todoTitleRequired => 'O titulo e obrigatorio';

  @override
  String get todoDescriptionTitle => 'Descricao';

  @override
  String get todoDescriptionOptionalLabel => 'Descricao (opcional)';

  @override
  String get todoPriorityTitle => 'Prioridade';

  @override
  String get todoStatusTitle => 'Status';

  @override
  String todoTasksForDay(Object date) {
    return 'Tarefas de $date';
  }

  @override
  String get todoNewShort => 'Nova';

  @override
  String get todoNoTasksSelectedDay => 'Nao ha tarefas para o dia selecionado.';

  @override
  String get todoNoTasksToShow => 'Nenhuma tarefa para mostrar';

  @override
  String get todoPremiumTitle => 'Tarefas Premium';

  @override
  String todoPremiumPreviewSubtitle(int limit) {
    return 'Voce pode consultar os ultimos $limit registros e criar ate $limit tarefas. Se quiser tarefas ilimitadas, torne-se Premium.';
  }

  @override
  String todoPremiumPreviewHighlight(int count) {
    return 'Atualmente voce tem $count tarefas registradas.';
  }

  @override
  String get todoEmptyState => 'Voce ainda nao criou nenhuma tarefa.';

  @override
  String get todoScreenTitle => 'Tarefas';

  @override
  String get todoTabPending => 'Pendentes';

  @override
  String get todoTabResolved => 'Concluidas';

  @override
  String get todoTabAll => 'Todas';

  @override
  String get todoHideFilters => 'Ocultar filtros';

  @override
  String get todoViewList => 'Ver lista';

  @override
  String get todoViewCalendar => 'Ver calendario';

  @override
  String get todoSortByDate => 'Ordenar por data';

  @override
  String get todoSortByPriority => 'Ordenar por prioridade';

  @override
  String get todoSearchHint => 'Pesquisar tarefas';

  @override
  String get todoClearSearch => 'Limpar pesquisa';

  @override
  String get todoDeleteTitle => 'Excluir tarefa';

  @override
  String todoDeleteConfirm(Object title) {
    return 'Deseja excluir a tarefa \"$title\"?';
  }

  @override
  String get todoDeletedSuccess => 'Tarefa excluida';

  @override
  String get todoAddToDeviceCalendar =>
      'Adicionar ao calendario do dispositivo';

  @override
  String get todoEditAction => 'Editar';

  @override
  String get todoSelectDate => 'Selecionar data';

  @override
  String get todoRemoveDate => 'Remover data';

  @override
  String get todoGuestTitle => 'Tarefas para usuarios registrados';

  @override
  String get todoGuestBody =>
      'Faca login ou torne-se Premium para criar, organizar e sincronizar suas tarefas em todos os seus dispositivos.';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonSortByName => 'Ordenar por nome';

  @override
  String get commonSortByType => 'Ordenar por tipo';

  @override
  String get commonSortByDate => 'Ordenar por data';

  @override
  String get commonSortBySeverity => 'Ordenar por gravidade';

  @override
  String get commonName => 'Nome';

  @override
  String get commonTitleField => 'Titulo';

  @override
  String get commonDescriptionField => 'Descricao';

  @override
  String get commonTypeField => 'Tipo';

  @override
  String get commonSeverity => 'Gravidade';

  @override
  String commonNoResultsForQuery(Object query) {
    return 'Nenhum resultado para \"$query\"';
  }

  @override
  String get tipsPremiumToolsMessage =>
      'Pesquisa, filtros, favoritos, curtidas e acesso completo ao catalogo de dicas estao disponiveis apenas para usuarios Premium.';

  @override
  String get tipsPremiumPreviewTitle => 'Dicas Premium';

  @override
  String get tipsPremiumPreviewSubtitle =>
      'Voce pode ver uma previa das ultimas 3 dicas. Torne-se Premium para acessar o catalogo completo e todas as suas ferramentas.';

  @override
  String tipsPreviewAvailableCount(Object count) {
    return ' Atualmente ha $count dicas disponiveis.';
  }

  @override
  String get tipsSearchLabel => 'Pesquisar dicas';

  @override
  String get tipsNoPersonalizedRecommendations =>
      'Sem recomendacoes personalizadas';

  @override
  String get tipsViewGeneralTips => 'Ver dicas gerais';

  @override
  String get tipsUnreadBadge => 'Nao lida';

  @override
  String get messagesInboxTitle => 'Mensagens por ler';

  @override
  String get messagesInboxGuestBody =>
      'Para conversar online com o teu dietista, por favor regista-te (e gratis).';

  @override
  String get messagesInboxGuestAction => 'Iniciar registo';

  @override
  String get messagesInboxUnreadChats => 'Chats por ler';

  @override
  String get messagesInboxNoPendingChats => 'Nao ha chats pendentes.';

  @override
  String get messagesInboxUser => 'Utilizador';

  @override
  String get messagesInboxImage => 'Imagem';

  @override
  String get messagesInboxNoMessages => 'Sem mensagens';

  @override
  String get messagesInboxPendingExerciseFeelings =>
      'Sensacoes de exercicios pendentes';

  @override
  String get messagesInboxNoPendingExerciseFeelings =>
      'Nao ha sensacoes de exercicios pendentes.';

  @override
  String get messagesInboxViewPendingExerciseFeelings =>
      'Ver sensacoes de exercicios pendentes';

  @override
  String get messagesInboxUnreadDietitianChats => 'Chats com dietista por ler';

  @override
  String get messagesInboxOpenDietitianChat => 'Abrir chat com dietista';

  @override
  String get messagesInboxMessage => 'Mensagem';

  @override
  String get messagesInboxDietitianMessage => 'Mensagem do dietista';

  @override
  String get messagesInboxUnreadCoachComments =>
      'Comentarios do treinador por ler';

  @override
  String get messagesInboxNoUnreadCoachComments =>
      'Nao tens comentarios do treinador pessoal pendentes de ler.';

  @override
  String get messagesInboxViewPendingComments => 'Ver comentarios pendentes';

  @override
  String messagesInboxLoadError(Object error) {
    return 'Erro ao carregar mensagens: $error';
  }

  @override
  String get tipsNoFeaturedAvailable => 'Sem dicas em destaque';

  @override
  String get tipsNoTipsAvailable => 'Sem dicas disponiveis';

  @override
  String get tipsNoFavoriteTips => 'Voce nao tem dicas favoritas';

  @override
  String get tipsDetailTitle => 'Detalhes da dica';

  @override
  String get tipsPreviewBanner => 'Previa - Assim os usuarios verao a dica';

  @override
  String tipsHashtagTitle(Object hashtag) {
    return 'Dicas com $hashtag';
  }

  @override
  String tipsHashtagEmpty(Object hashtag) {
    return 'Nao ha dicas com $hashtag';
  }

  @override
  String tipsLoadErrorStatus(Object statusCode) {
    return 'Erro ao carregar as dicas: $statusCode';
  }

  @override
  String tipsLoadError(Object error) {
    return 'Erro ao carregar as dicas. $error';
  }

  @override
  String get recipesPremiumToolsMessage =>
      'Pesquisa, filtros, favoritos, curtidas e acesso completo ao catalogo de receitas estao disponiveis apenas para usuarios Premium.';

  @override
  String get recipesPremiumPreviewTitle => 'Receitas Premium';

  @override
  String get recipesPremiumPreviewSubtitle =>
      'Voce pode ver uma previa das ultimas 3 receitas. Torne-se Premium para acessar o catalogo completo e todas as suas ferramentas.';

  @override
  String recipesPreviewAvailableCount(Object count) {
    return ' Atualmente ha $count receitas disponiveis.';
  }

  @override
  String get recipesSearchLabel => 'Pesquisar receitas';

  @override
  String get recipesNoFeaturedAvailable => 'Sem receitas em destaque';

  @override
  String get recipesNoRecipesAvailable => 'Sem receitas disponiveis';

  @override
  String get recipesNoFavoriteRecipes => 'Voce nao tem receitas favoritas';

  @override
  String get recipesDetailTitle => 'Detalhes da receita';

  @override
  String get recipesPreviewBanner =>
      'Previa - Assim os usuarios verao a receita';

  @override
  String recipesHashtagTitle(Object hashtag) {
    return 'Receitas com $hashtag';
  }

  @override
  String recipesHashtagEmpty(Object hashtag) {
    return 'Nao ha receitas com $hashtag';
  }

  @override
  String get additivesPremiumCopyPdfMessage =>
      'Para copiar um aditivo e exporta-lo em PDF, voce precisa ser um usuario Premium.';

  @override
  String get additivesPremiumExploreMessage =>
      'Hashtags e recomendacoes de aditivos estao disponiveis apenas para usuarios Premium.';

  @override
  String get additivesPremiumToolsMessage =>
      'Pesquisa, filtros, atualizacao e ordenacao completa do catalogo de aditivos estao disponiveis apenas para usuarios Premium.';

  @override
  String get additivesFilterTitle => 'Filtrar aditivos';

  @override
  String get additivesNoConfiguredTypes =>
      'Nao ha tipos configurados em tipos_aditivos.';

  @override
  String get additivesTypesLabel => 'Tipos';

  @override
  String get additivesSearchHint => 'Pesquisar aditivos';

  @override
  String get additivesEmpty => 'Nenhum aditivo disponivel';

  @override
  String get additivesPremiumTitle => 'Aditivos Premium';

  @override
  String get additivesPremiumSubtitle =>
      'O catalogo completo de aditivos esta disponivel apenas para usuarios Premium.';

  @override
  String additivesCatalogHighlight(Object count) {
    return ' (com mais de $count aditivos)';
  }

  @override
  String get additivesLoadFailed => 'Nao foi possivel carregar os aditivos.';

  @override
  String get additivesCatalogUnavailable =>
      'O catalogo de aditivos esta temporariamente indisponivel. Tente novamente mais tarde.';

  @override
  String get additivesServerConnectionError =>
      'Nao foi possivel conectar ao servidor. Verifique sua conexao e tente novamente.';

  @override
  String get additivesSeveritySafe => 'Seguro';

  @override
  String get additivesSeverityAttention => 'Atencao';

  @override
  String get additivesSeverityHigh => 'Alto';

  @override
  String get additivesSeverityRestricted => 'Restrito';

  @override
  String get additivesSeverityForbidden => 'Proibido';

  @override
  String get substitutionsPremiumToolsMessage =>
      'Pesquisa, filtros, favoritos e ordenacao completa de substituicoes saudaveis estao disponiveis apenas para usuarios Premium.';

  @override
  String get substitutionsPremiumCopyPdfMessage =>
      'Para copiar uma substituicao saudavel e exporta-la em PDF, voce precisa ser um usuario Premium.';

  @override
  String get substitutionsPremiumExploreMessage =>
      'Hashtags, categorias, recomendacoes e navegacao avancada de substituicoes saudaveis estao disponiveis apenas para usuarios Premium.';

  @override
  String get substitutionsPremiumEngagementMessage =>
      'Favoritos e curtidas de substituicoes saudaveis estao disponiveis apenas para usuarios Premium.';

  @override
  String get substitutionsSearchLabel => 'Pesquisar substituicoes ou hashtags';

  @override
  String get substitutionsEmptyFeatured => 'Nenhuma substituicao em destaque.';

  @override
  String get substitutionsEmptyAll => 'Nenhuma substituicao disponivel.';

  @override
  String get substitutionsEmptyFavorites =>
      'Voce ainda nao tem substituicoes favoritas.';

  @override
  String get substitutionsPremiumTitle => 'Substituicoes Premium';

  @override
  String get substitutionsPremiumSubtitle =>
      'A biblioteca completa de substituicoes saudaveis esta disponivel apenas para usuarios Premium.';

  @override
  String substitutionsCatalogHighlight(Object count) {
    return ' (com mais de $count substituicoes)';
  }

  @override
  String get substitutionsDefaultBadge => 'Substituicao Premium';

  @override
  String get substitutionsTapForDetail => 'Toque para ver o detalhe completo';

  @override
  String get substitutionsDetailTitle => 'Substituicao saudavel';

  @override
  String get substitutionsRecommendedChange => 'Mudanca recomendada';

  @override
  String get substitutionsIfUnavailable => 'Se voce nao tiver';

  @override
  String get substitutionsUse => 'Use';

  @override
  String get substitutionsEquivalence => 'Quantidade equivalente';

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
  String get commonGallery => 'Galeria';

  @override
  String get commonUnavailable => 'Indisponivel';

  @override
  String get scannerTitle => 'Scanner de rotulos';

  @override
  String get scannerPremiumRequiredMessage =>
      'A leitura, a abertura de imagens da galeria e a pesquisa de produtos pelo scanner estao disponiveis apenas para usuarios Premium.';

  @override
  String get scannerClearTrainingTitle => 'Limpar treinamento OCR';

  @override
  String get scannerClearTrainingBody =>
      'Todas as correcoes salvas neste dispositivo serao excluidas. Deseja continuar?';

  @override
  String get scannerLocalTrainingRemoved => 'Treinamento OCR local removido';

  @override
  String get scannerExportRulesTitle => 'Exportar regras OCR';

  @override
  String get scannerImportRulesTitle => 'Importar regras OCR';

  @override
  String get scannerImportRulesHint => 'Cole aqui o JSON exportado';

  @override
  String get scannerInvalidFormat => 'Formato invalido';

  @override
  String get scannerInvalidJsonOrCanceled =>
      'JSON invalido ou importacao cancelada';

  @override
  String scannerImportedRulesCount(Object count) {
    return '$count regras de treinamento importadas';
  }

  @override
  String get scannerRulesUploaded => 'Regras OCR enviadas ao servidor';

  @override
  String scannerRulesUploadError(Object error) {
    return 'Erro ao enviar regras: $error';
  }

  @override
  String get scannerNoRemoteRules => 'Nenhuma regra remota disponivel.';

  @override
  String scannerDownloadedRulesCount(Object count) {
    return '$count regras baixadas do servidor';
  }

  @override
  String scannerRulesDownloadError(Object error) {
    return 'Erro ao baixar regras: $error';
  }

  @override
  String get scannerTrainingMarkedCorrect =>
      'Treinamento salvo: leitura marcada como correta';

  @override
  String get scannerCorrectOcrValuesTitle => 'Corrigir valores OCR';

  @override
  String get scannerSugarField => 'Sugar (g)';

  @override
  String get scannerSaltField => 'Salt (g)';

  @override
  String get scannerFatField => 'Fat (g)';

  @override
  String get scannerProteinField => 'Protein (g)';

  @override
  String get scannerPortionField => 'Porcao (g)';

  @override
  String get scannerSaveCorrection => 'Salvar correcao';

  @override
  String get scannerCorrectionSaved =>
      'Correcao salva. Ela sera aplicada a rotulos semelhantes.';

  @override
  String get scannerSourceBarcode => 'Codigo de barras';

  @override
  String get scannerSourceOcrOpenFood => 'OCR do nome + Open Food Facts';

  @override
  String get scannerSourceOcrTable => 'OCR da tabela nutricional';

  @override
  String get scannerSourceAutoBarcodeOpenFood =>
      'Deteccao automatica (codigo de barras + Open Food Facts)';

  @override
  String get scannerSourceAutoOcrOpenFood =>
      'Deteccao automatica (OCR + Open Food Facts)';

  @override
  String get scannerSourceAutoOcrTable =>
      'Deteccao automatica (OCR da tabela nutricional)';

  @override
  String get scannerNoNutritionData =>
      'Nao foi possivel obter os dados nutricionais. Tire a foto com boa iluminacao, texto nitido e enquadrando a tabela de informacoes nutricionais.';

  @override
  String scannerReadCompleted(Object source) {
    return 'Leitura concluida: $source';
  }

  @override
  String scannerAnalyzeError(Object error) {
    return 'Nao foi possivel analisar o rotulo: $error';
  }

  @override
  String get scannerHeaderTitle => 'Scanner de rotulos alimentares';

  @override
  String get scannerHeaderTooltip => 'Informacoes completas do processo';

  @override
  String get scannerHeaderBody =>
      'Tire uma foto do codigo de barras de um produto ou selecione uma imagem da galeria. Quando este modo estiver ativado, o NutriFit detectara automaticamente o codigo de barras, o nome do produto ou a tabela nutricional.';

  @override
  String get scannerPremiumBanner =>
      'Funcionalidade Premium: voce pode entrar na tela e ver as informacoes, mas Pesquisa, Foto e Galeria estao bloqueadas para usuarios nao Premium.';

  @override
  String get scannerTrainingModeTitle => 'Modo de treinamento OCR';

  @override
  String get scannerTrainingModeSubtitle =>
      'Permite corrigir leituras para melhorar as deteccoes.';

  @override
  String get scannerModeLabel => 'Modo';

  @override
  String get scannerModeAuto => 'Modo automatico';

  @override
  String get scannerModeBarcode => 'Modo codigo de barras';

  @override
  String get scannerModeOcrTable => 'Modo tabela nutricional';

  @override
  String get scannerActionSearchOpenFood => 'Pesquisar no Open Food Facts';

  @override
  String get scannerAutoHint =>
      'No modo automatico, o app primeiro tenta detectar o codigo de barras e, se nao encontrar um produto valido, tenta OCR no nome ou na tabela nutricional.';

  @override
  String get scannerBarcodeHint =>
      'No modo codigo de barras, a camera mostra uma moldura guia e o app analisa apenas essa area para melhorar a precisao.';

  @override
  String get scannerOcrHint =>
      'No modo tabela nutricional, o app prioriza a leitura OCR do nome do produto e da tabela nutricional sem depender do codigo de barras.';

  @override
  String get scannerDismissHintTooltip =>
      'Fechar (pressione e segure o botao do modo para mostrar novamente)';

  @override
  String get scannerAnalyzing => 'Analisando rotulo...';

  @override
  String get scannerResultPerServing => 'Resultado por porcao';

  @override
  String get scannerThresholdInfo => 'Threshold info';

  @override
  String get scannerMiniTrainingTitle => 'Mini OCR training';

  @override
  String get scannerMiniTrainingApplied =>
      'Previous learning was applied for this label or a similar one.';

  @override
  String get scannerMiniTrainingPrompt =>
      'Validate or correct this reading to train recognition.';

  @override
  String get scannerTrainingCorrect => 'It is correct';

  @override
  String get scannerTrainingCorrectAction => 'Correct';

  @override
  String get scannerDownloadServerRules => 'Download server rules';

  @override
  String get scannerUploadServerRules => 'Upload server rules';

  @override
  String get scannerClearLocalRules => 'Clear local';

  @override
  String get scannerZoomLabel => 'Zoom';

  @override
  String get scannerDetectedTextTitle => 'Detected text (OCR)';

  @override
  String get scannerManualSearchTitle => 'Search in Open Food Facts';

  @override
  String get scannerManualSearchHint => 'Product name';

  @override
  String get scannerNoValidProductByName =>
      'No valid product was found with that name.';

  @override
  String get scannerManualSearchSource =>
      'Manual search by name (Open Food Facts)';

  @override
  String get scannerProductFound => 'Product found in Open Food Facts';

  @override
  String scannerProductSearchError(Object error) {
    return 'Error searching product: $error';
  }

  @override
  String get scannerProductName => 'Product name';

  @override
  String get scannerBrand => 'Brand';

  @override
  String get scannerFormat => 'Format';

  @override
  String get scannerBarcodeLabel => 'Barcode';

  @override
  String get scannerActions => 'Actions';

  @override
  String get scannerAddToShoppingList => 'Add to shopping list';

  @override
  String get scannerNutriScoreNova => 'Nutri-Score   NOVA';

  @override
  String get scannerNutriScoreMeaning => 'What does Nutri-Score mean?';

  @override
  String get scannerNovaMeaning => 'What does NOVA mean?';

  @override
  String get scannerIngredients => 'Ingredients';

  @override
  String get scannerNutritionData => 'Nutrition data';

  @override
  String scannerEnergyValue(Object value) {
    return 'Energy: $value';
  }

  @override
  String scannerCarbohydratesValue(Object value) {
    return 'Carbohydrates: $value';
  }

  @override
  String scannerFiberValue(Object value) {
    return 'Fiber: $value';
  }

  @override
  String scannerSaturatedFatValue(Object value) {
    return 'Saturated fat: $value';
  }

  @override
  String scannerSodiumValue(Object value) {
    return 'Sodium: $value';
  }

  @override
  String get scannerImageTitle => 'Nutrition label';

  @override
  String scannerOpenImageError(Object error) {
    return 'Could not open the image: $error';
  }

  @override
  String get scannerInfoTitle => 'Information';

  @override
  String get scannerContactDietitianButton => 'Contactar dietista';

  @override
  String get scannerAllergensAndTraces => 'Allergens and traces';

  @override
  String scannerAllergensValue(Object value) {
    return 'Allergens: $value';
  }

  @override
  String scannerTracesValue(Object value) {
    return 'Traces: $value';
  }

  @override
  String get scannerFeaturedLabels => 'Featured labels';

  @override
  String get scannerCopiedData => 'Data copied to clipboard';

  @override
  String get scannerRegisterForShoppingList =>
      'Sign up to add products to the shopping list';

  @override
  String get scannerUnknownUser => 'User not identified';

  @override
  String get scannerExistingFoodUpdated =>
      'The food already exists and has been updated';

  @override
  String get scannerProductAddedToShoppingList =>
      'Product added to the shopping list';

  @override
  String scannerAddToShoppingListError(Object error) {
    return 'Error adding to the list: $error';
  }

  @override
  String get scannerThresholdInfoIntro =>
      'The \"Per-serving result\" table helps you see whether a value is close to (OK) or far from (Caution/High) the suggested reference range.';

  @override
  String get scannerThresholdComponent => 'Component';

  @override
  String get scannerThresholdOk => 'OK';

  @override
  String get scannerThresholdCaution => 'Caution';

  @override
  String get scannerThresholdHighLow => 'High / Low';

  @override
  String get scannerThresholdSugar => 'Sugar';

  @override
  String get scannerThresholdSalt => 'Salt';

  @override
  String get scannerThresholdFat => 'Fat';

  @override
  String get scannerThresholdProtein => 'Protein';

  @override
  String get scannerThresholdDisclaimer =>
      'The suggestions and values shown are always indicative and do not replace advice from a dietitian. In addition, the number of servings you consume directly affects the total amount of each nutrient you ingest.';

  @override
  String get scannerOcrAccuracyTitle => 'Reading accuracy (OCR)';

  @override
  String get scannerOcrAccuracyBody =>
      'The accuracy of the detected product depends directly on image quality. If the photo is blurry, reflective, or does not clearly focus the barcode or the nutrition table, the values may be incorrect. Always review the product name to make sure it matches.';

  @override
  String get scannerOcrTip1 => '• Focus only on the barcode.';

  @override
  String get scannerOcrTip2 =>
      '• If there is no barcode, focus only on the nutrition information table.';

  @override
  String get scannerOcrTip3 =>
      '• If you photograph the barcode, make sure it is fully visible and sharp.';

  @override
  String get scannerOcrTip4 =>
      '• Avoid shadows, reflections, and poor lighting.';

  @override
  String get scannerOcrTip5 =>
      '• Keep the phone steady and the text as straight as possible.';

  @override
  String get scannerOcrTip6 =>
      '• Check that numbers and units (g/ml) are readable.';

  @override
  String get scannerOcrTip7 =>
      '• Avoid photographing wrinkled or damaged labels.';

  @override
  String get scannerNutriScoreDescription =>
      'Nutri-Score is a public front-of-pack labeling system used in Europe to summarize the product\'s overall nutritional quality.';

  @override
  String get scannerNutriScoreA => 'Most nutritionally favorable';

  @override
  String get scannerNutriScoreB => 'Favorable';

  @override
  String get scannerNutriScoreC => 'Intermediate';

  @override
  String get scannerNutriScoreD => 'Less favorable';

  @override
  String get scannerNutriScoreE => 'Least healthy overall';

  @override
  String get scannerNovaDescription =>
      'NOVA classifies foods by degree of processing (public health academic system).';

  @override
  String get scannerNova1 => 'Unprocessed or minimally processed';

  @override
  String get scannerNova2 => 'Processed culinary ingredients';

  @override
  String get scannerNova3 => 'Processed foods';

  @override
  String get scannerNova4 => 'Ultra-processed foods';

  @override
  String get scannerGuestAccuracyPromptStart =>
      'If you want more accurate information ';

  @override
  String get scannerGuestAccuracyPromptLink => 'sign up (it\'s free)';

  @override
  String get scannerGuestAccuracyPromptEnd => ' and enter your age and height.';

  @override
  String get scannerCaptureTipsTitle => 'Tips for taking the photo...';

  @override
  String get scannerCaptureTipsIntro =>
      'To obtain correct values, the image must clearly focus on the barcode or the nutrition information table.';

  @override
  String get scannerCaptureTipsBody =>
      '• If you scan the barcode, center it in the frame.\n• If you scan the nutrition table, make sure the whole table is visible.\n• Avoid shaky, blurry, or reflective photos.\n• Use good lighting and get close enough to read the numbers.\n• If the result does not look right, retake the photo from another angle.';

  @override
  String get scannerImportantNotice => 'Important notice';

  @override
  String get scannerOrientativeNotice =>
      'These calculations and this information are indicative and also depend on the quality of the photo/image and on whether the product exists in the Open Food Facts database. For a personalized assessment, always consult your online dietitian.';

  @override
  String get scannerNutrientColumn => 'Nutrient';

  @override
  String scannerServingColumn(Object portion) {
    return 'Serving ($portion)';
  }

  @override
  String get scannerStatus100gColumn => 'Status (100 g)';

  @override
  String scannerCameraInitError(Object error) {
    return 'Could not start the camera: $error';
  }

  @override
  String scannerTakePhotoError(Object error) {
    return 'Could not take the photo: $error';
  }

  @override
  String get scannerFrameHint => 'Center the label/barcode inside the frame';

  @override
  String get activitiesCatalogTitle => 'Activities catalog';

  @override
  String get commonEmail => 'Email';

  @override
  String get restrictedAccessGenericMessage =>
      'Para acessar seus planos nutricionais, planos de treino e recomendacoes personalizadas, primeiro voce precisa entrar em contato com seu dietista/treinador online, que atribuira um plano especifico ajustado as suas necessidades.';

  @override
  String get restrictedAccessContactMethods => 'Formas de contato:';

  @override
  String get restrictedAccessMoreContactOptions => 'Mais formas de contato';

  @override
  String get videosPremiumToolsMessage =>
      'Pesquisa, filtros, favoritos, curtidas e ordenacao completa dos videos de exercicios estao disponiveis apenas para usuarios Premium.';

  @override
  String get videosPremiumPlaybackMessage =>
      'A reproducao completa dos videos de exercicios esta disponivel apenas para usuarios Premium.';

  @override
  String get videosPremiumTitle => 'Videos Premium';

  @override
  String get videosPremiumSubtitle =>
      'O catalogo completo de videos de exercicios esta disponivel apenas para usuarios Premium. Acesse ';

  @override
  String videosPremiumPreviewHighlight(Object count) {
    return '$count videos exclusivos.';
  }

  @override
  String get charlasPremiumToolsMessage =>
      'Pesquisa, filtros, favoritos, curtidas e ordenacao completa de palestras e seminarios estao disponiveis apenas para usuarios Premium.';

  @override
  String get charlasPremiumContentMessage =>
      'O acesso completo ao conteudo da palestra ou seminario esta disponivel apenas para usuarios Premium.';

  @override
  String get charlasPremiumTitle => 'Palestras Premium';

  @override
  String get charlasPremiumSubtitle =>
      'O catalogo completo de palestras e seminarios esta disponivel apenas para usuarios Premium. Acesse ';

  @override
  String charlasPremiumPreviewHighlight(Object count) {
    return '$count palestras exclusivas.';
  }

  @override
  String get supplementsPremiumCopyPdfMessage =>
      'Para copiar um suplemento e exporta-lo em PDF, voce precisa ser um usuario Premium.';

  @override
  String get supplementsPremiumExploreMessage =>
      'Hashtags e recomendacoes de suplementos estao disponiveis apenas para usuarios Premium.';

  @override
  String get supplementsPremiumToolsMessage =>
      'Pesquisa, atualizacao e ordenacao completa do catalogo de suplementos estao disponiveis apenas para usuarios Premium.';

  @override
  String get supplementsPremiumTitle => 'Suplementos Premium';

  @override
  String get supplementsPremiumSubtitle =>
      'O catalogo completo de suplementos esta disponivel apenas para usuarios Premium.';

  @override
  String supplementsPremiumPreviewHighlight(Object count) {
    return '(com mais de $count suplementos)';
  }

  @override
  String get exerciseCatalogPremiumToolsMessage =>
      'Pesquisa, filtros, atualizacao e ordenacao completa do catalogo de exercicios estao disponiveis apenas para usuarios Premium.';

  @override
  String get exerciseCatalogPremiumVideoMessage =>
      'O video completo do exercicio esta disponivel apenas para usuarios Premium.';

  @override
  String get exerciseCatalogPremiumTitle => 'Exercicios Premium';

  @override
  String get exerciseCatalogPremiumSubtitle =>
      'O catalogo completo de exercicios esta disponivel apenas para usuarios Premium.';

  @override
  String exerciseCatalogPremiumPreviewHighlight(Object count) {
    return '(com mais de $count exercicios)';
  }
}
