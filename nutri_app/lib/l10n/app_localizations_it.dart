// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get settingsAndPrivacyTitle => 'Impostazioni e privacy';

  @override
  String get settingsAndPrivacyMenuLabel => 'Impostazioni e privacy';

  @override
  String get configTabParameters => 'Parametri';

  @override
  String get configTabPremium => 'Premium';

  @override
  String get configTabAppMenu => 'Menu app';

  @override
  String get configTabGeneral => 'General';

  @override
  String get configTabSecurity => 'Sicurezza';

  @override
  String get configTabUser => 'Utente';

  @override
  String get configTabDisplay => 'Visualizzazione';

  @override
  String get configTabDefaults => 'Predefiniti';

  @override
  String get configTabPrivacy => 'Privacy';

  @override
  String get securitySubtabAccess => 'Accesso';

  @override
  String get securitySubtabEmailServer => 'Server email';

  @override
  String get securitySubtabCipher => 'Cifra/Decifra';

  @override
  String get securitySubtabSessions => 'Sessioni';

  @override
  String get securitySubtabAccesses => 'Accessi';

  @override
  String get privacyCenterTab => 'Centro';

  @override
  String get privacyPolicyTab => 'Politica';

  @override
  String get privacySessionsTab => 'Sessioni';

  @override
  String privacyLastUpdatedLabel(Object date) {
    return 'Ultimo aggiornamento: $date';
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
      'Non sono disponibili dati di sessione per gli utenti non registrati, poiche l\'accesso avviene in forma anonima.';

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
    return 'L\'app e stata aggiornata alla versione $version.';
  }

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonAgree => 'OK';

  @override
  String get commonLater => 'Later';

  @override
  String get commonValidate => 'Convalida';

  @override
  String get commonToday => 'oggi';

  @override
  String get commonDebug => 'DEBUG';

  @override
  String get commonAllRightsReserved => 'Tutti i diritti riservati';

  @override
  String get navHome => 'Home';

  @override
  String get navLogout => 'Disconnetti';

  @override
  String get navChat => 'Chat';

  @override
  String get navPatients => 'Pazienti';

  @override
  String get navAppointments => 'Appuntamenti';

  @override
  String get navReviews => 'Revisioni';

  @override
  String get navMeasurements => 'Misurazioni';

  @override
  String get navNutriInterviews => 'Interviste Nutri';

  @override
  String get navNutriPlans => 'Piani Nutri';

  @override
  String get navFitInterviews => 'Interviste Fit';

  @override
  String get navFitPlans => 'Piani Fit';

  @override
  String get navExercises => 'Esercizi';

  @override
  String get navExerciseVideos => 'Video esercizi';

  @override
  String get navActivities => 'Attivita';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navCharges => 'Pagamenti';

  @override
  String get navClients => 'Clienti';

  @override
  String get navTips => 'Tips';

  @override
  String get navRecipes => 'Recipes';

  @override
  String get navSubstitutions => 'Substitutions';

  @override
  String get navTalksAndSeminars => 'Talk e seminari';

  @override
  String get navTalks => 'Talk';

  @override
  String get navPremiumPreview => 'Passa a Premium (anteprima)';

  @override
  String get navPremium => 'Passa a Premium';

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
  String get navChatWithDietitian => 'Chat con il dietista';

  @override
  String get navContactDietitian => 'Contatta il dietista';

  @override
  String get navEditProfile => 'Modifica profilo';

  @override
  String get profileEditProfileTab => 'Profilo';

  @override
  String get profileEditSessionsTab => 'Accessi';

  @override
  String get profileEditPremiumBadgeTitle => 'Account Premium';

  @override
  String get profileEditPremiumBadgeBody =>
      'Hai accesso a funzionalita esclusive come i video di esercizi.';

  @override
  String get profileEditNickLabel => 'Nick / Utente';

  @override
  String get profileEditNickRequired => 'Il nickname e obbligatorio';

  @override
  String get profileEditEmailLabel => 'Email';

  @override
  String get profileEditInvalidEmail => 'Email non valida';

  @override
  String get profileEditEmailInUse =>
      'L\'email inserita non e valida, usa un\'altra email';

  @override
  String get profileEditChangeEmailTooltip => 'Cambia account email';

  @override
  String get profileEditVerifyEmailCta => 'Verifica email';

  @override
  String get profileEditTwoFactorShortLabel => 'Due fattori';

  @override
  String get profileEditBmiCardTitle => 'Dati BMI';

  @override
  String get profileEditBmiInfoTooltip => 'Informazioni BMI/MVP';

  @override
  String get profileEditBmiCardBody =>
      'Per ottenere BMI, MVP e raccomandazioni, completa eta e altezza.';

  @override
  String get profileEditAgeLabel => 'Eta';

  @override
  String get profileEditInvalidAge => 'Eta non valida';

  @override
  String get profileEditHeightLabel => 'Altezza (cm)';

  @override
  String get profileEditInvalidHeight => 'Altezza non valida';

  @override
  String get profileEditPasswordCardTitle => 'Cambia password';

  @override
  String get profileEditPasswordHint =>
      'Lascia vuoto per mantenere la password attuale';

  @override
  String get profileEditPasswordLabel => 'Parola d\'accesso';

  @override
  String get profileEditPasswordConfirmLabel => 'Conferma password';

  @override
  String get profileEditPasswordConfirmRequired =>
      'Devi confermare la password';

  @override
  String get profileEditPasswordMismatch => 'Le password non coincidono';

  @override
  String get profileEditSaveChanges => 'Salva modifiche';

  @override
  String get profileEditDeleteMyData => 'Elimina tutti i miei dati';

  @override
  String get profileEditChangeEmailTitle => 'Cambia email';

  @override
  String get profileEditChangeEmailVerifiedWarning =>
      'L\'email attuale e verificata. Se la cambi, dovrai verificarla di nuovo.';

  @override
  String get profileEditChangeEmailNewLabel => 'Nuova email';

  @override
  String get profileEditChangeEmailRequired => 'Devi indicare un\'email.';

  @override
  String get profileEditChangeEmailMustDiffer =>
      'Devi indicare un\'email diversa da quella attuale.';

  @override
  String get profileEditChangeEmailValidationFailed =>
      'Non e stato possibile convalidare l\'email. Riprova.';

  @override
  String get profileEditChangeEmailReview => 'Controlla l\'email indicata.';

  @override
  String get profileEditEmailRequiredForVerification =>
      'Devi prima inserire un indirizzo e-mail.';

  @override
  String get profileEditEmailCodeSentGeneric => 'Codice inviato.';

  @override
  String get profileEditEmailVerifiedGeneric => 'E-mail verificata.';

  @override
  String get profileEditEmailCodeLengthError =>
      'Il codice deve avere 10 cifre.';

  @override
  String get profileEditEmailCodeDialogTitle => 'Convalida codice e-mail';

  @override
  String get profileEditEmailCodeTenDigitsLabel => 'Codice di 10 cifre';

  @override
  String get profileEditValidateEmailCodeAction => 'Convalida codice e-mail';

  @override
  String get profileEditVerifyEmailTitle => 'Verifica e-mail';

  @override
  String get profileEditVerifyEmailIntroPrefix =>
      'Dobbiamo verificare che questo indirizzo e-mail sia tuo:';

  @override
  String get profileEditVerifyEmailPremiumLink =>
      'Vedi i vantaggi Premium con e-mail verificata';

  @override
  String get profileEditFollowTheseSteps => 'Segui questi passaggi...';

  @override
  String get profileEditYourEmail => 'La tua e-mail';

  @override
  String profileEditSendCodeInstruction(Object email) {
    return 'Tocca \"Invia codice\" per inviare il codice di verifica a $email.';
  }

  @override
  String get profileEditEmailCodeSentInfo =>
      'E stato inviato un codice al tuo indirizzo e-mail. Scadra tra 15 minuti. Se non lo vedi nella posta in arrivo, controlla la cartella Spam.';

  @override
  String get profileEditEmailSendFailed =>
      'L\'e-mail di verifica non puo essere inviata in questo momento. Riprova piu tardi.';

  @override
  String get profileEditSendCodeAction => 'Invia codice';

  @override
  String get profileEditResendCodeAction => 'Invia di nuovo';

  @override
  String get profileEditVerifyCodeInstruction =>
      'Inserisci il codice di verifica che ti abbiamo inviato.';

  @override
  String get profileEditVerificationCodeLabel => 'Codice di verifica';

  @override
  String get profileEditEmailRequiredInProfile =>
      'Devi prima inserire un\'e-mail in Modifica profilo per poterla verificare.';

  @override
  String get profileEditTwoFactorDialogTitle =>
      'Autenticazione a due fattori (2FA)';

  @override
  String get profileEditTwoFactorEnabledStatus => 'Stato: Attiva';

  @override
  String get profileEditTwoFactorEnabledBody =>
      'L\'autenticazione a due fattori e gia attiva sul tuo account. Da qui puoi solo verificare se questo dispositivo e affidabile e collegarlo o scollegarlo.';

  @override
  String get profileEditTrustedDeviceEnabledBody =>
      'Questo dispositivo e contrassegnato come affidabile. Il codice 2FA non verra richiesto ai prossimi accessi finche non rimuoverai la fiducia da qui.';

  @override
  String get profileEditTrustedDeviceDisabledBody =>
      'Questo dispositivo non e contrassegnato come affidabile. Puoi contrassegnarlo toccando \"Imposta questo dispositivo come affidabile\" oppure disconnettendoti e accedendo di nuovo, attivando la casella \"Fidati di questo dispositivo\" durante la convalida 2FA.';

  @override
  String get profileEditRemoveTrustedDeviceAction =>
      'Rimuovi fiducia da questo dispositivo';

  @override
  String get profileEditSetTrustedDeviceAction =>
      'Imposta questo dispositivo come affidabile';

  @override
  String get profileEditCancelProcess => 'Annulla processo';

  @override
  String get profileEditSetTrustedDeviceTitle =>
      'Imposta dispositivo affidabile';

  @override
  String get profileEditSetTrustedDeviceBody =>
      'Per contrassegnare questo dispositivo come affidabile devi convalidarlo durante l\'accesso 2FA, attivando la casella \"Fidati di questo dispositivo\".\n\nVuoi disconnetterti ora per farlo?';

  @override
  String get profileEditGoToLogin => 'Vai al login';

  @override
  String get profileEditActivateTwoFactorTitle =>
      'Attiva l\'autenticazione a due fattori';

  @override
  String get profileEditActivateTwoFactorIntro =>
      'L\'autenticazione a due fattori (2FA) aggiunge un ulteriore livello di sicurezza: oltre alla password, verra richiesto un codice temporaneo dalla tua app di autenticazione.';

  @override
  String get profileEditTwoFactorStep1 =>
      '1. Apri la tua app di autenticazione e aggiungi un nuovo account.';

  @override
  String get profileEditTwoFactorSetupKeyLabel => 'Chiave di configurazione';

  @override
  String get profileEditKeyCopied => 'Chiave copiata negli appunti';

  @override
  String get profileEditHideOptions => 'Nascondi opzioni';

  @override
  String get profileEditMoreOptions => 'Altre opzioni...';

  @override
  String profileEditQrSavedDownloads(Object path) {
    return 'QR salvato in Download: $path';
  }

  @override
  String get profileEditQrShared =>
      'E stato aperto il menu per condividere o salvare il QR.';

  @override
  String get profileEditOtpUrlCopied => 'URL otpauth copiato';

  @override
  String get profileEditCopyUrl => 'Copia URL';

  @override
  String get profileEditOtpUrlInfo =>
      'L\'opzione \"Copia URL\" copia un link otpauth con tutta la configurazione 2FA per importarla nelle app compatibili. Se la tua app non consente l\'importazione tramite link, usa \"Copia\" sulla chiave.';

  @override
  String get profileEditTwoFactorConfirmCodeInstruction =>
      'Inserisci il codice di 6 cifre mostrato dalla tua app di autenticazione per confermare.';

  @override
  String get profileEditActivateTwoFactorAction => 'Attiva';

  @override
  String get profileEditTwoFactorActivated =>
      'Autenticazione a due fattori attivata correttamente';

  @override
  String get profileEditTwoFactorActivateFailed =>
      'Impossibile attivare la 2FA.';

  @override
  String get profileEditNoQrData => 'Non ci sono dati da salvare nel QR.';

  @override
  String profileEditQrSavedPath(Object path) {
    return 'QR salvato in: $path';
  }

  @override
  String profileEditQrSaveFailed(Object error) {
    return 'Impossibile salvare il QR: $error';
  }

  @override
  String get profileEditDeactivateTwoFactorTitle =>
      'Disattiva l\'autenticazione a due fattori (2FA)';

  @override
  String get profileEditCurrentCodeSixDigitsLabel =>
      'Codice attuale di 6 cifre';

  @override
  String get profileEditDeactivateTwoFactorAction => 'Disattiva';

  @override
  String get profileEditTwoFactorDeactivated =>
      'Autenticazione a due fattori disattivata correttamente';

  @override
  String get profileEditTwoFactorDeactivateFailed =>
      'Impossibile disattivare la 2FA.';

  @override
  String get profileEditRemoveTrustedDeviceTitle =>
      'Rimuovi fiducia dal dispositivo';

  @override
  String get profileEditRemoveTrustedDeviceBody =>
      'Su questo dispositivo il codice 2FA verra richiesto nuovamente al prossimo accesso. Vuoi continuare?';

  @override
  String get profileEditRemoveTrustedDeviceActionShort => 'Rimuovi fiducia';

  @override
  String get profileEditTrustedDeviceRemoved =>
      'Fiducia del dispositivo rimossa.';

  @override
  String profileEditTrustedDeviceRemoveFailed(Object error) {
    return 'Impossibile rimuovere la fiducia dal dispositivo: $error';
  }

  @override
  String get profileEditMvpDialogTitle => 'Calcolo MVP e formule';

  @override
  String get profileEditMvpWhatIsTitle => 'Che cos\'e il MVP?';

  @override
  String get profileEditMvpWhatIsBody =>
      'MVP e un insieme minimo di indicatori antropometrici per aiutarti a monitorare in modo semplice la tua evoluzione di salute: BMI, vita/altezza e vita/fianchi.';

  @override
  String get profileEditMvpFormulasTitle =>
      'Formule utilizzate e loro origine:';

  @override
  String get profileEditMvpOriginBmi =>
      'Fonte: OMS (classificazione BMI negli adulti).';

  @override
  String get profileEditMvpOriginWhtr => 'Fonte: indice vita-altezza.';

  @override
  String get profileEditMvpOriginWhr =>
      'Fonte: rapporto vita-fianchi (OMS, obesita addominale).';

  @override
  String get profileEditImportantNotice => 'Avviso importante';

  @override
  String get profileEditMvpImportantNoticeBody =>
      'Questi calcoli e classificazioni sono indicativi. Per una valutazione personalizzata, consulta sempre un professionista sanitario, un dietista-nutrizionista o un personal trainer.';

  @override
  String get profileEditAccept => 'Accetta';

  @override
  String get profileEditNotAvailable => 'N/D';

  @override
  String get profileEditSessionDate => 'Data';

  @override
  String get profileEditSessionTime => 'Ora';

  @override
  String get profileEditSessionDevice => 'Dispositivo';

  @override
  String get profileEditSessionIp => 'Indirizzo IP:';

  @override
  String get profileEditSessionPublicIp => 'Pubblico';

  @override
  String get profileEditUserCodeUnavailable => 'Codice utente non disponibile';

  @override
  String get profileEditGenericError => 'Errore';

  @override
  String get profileEditRetry => 'Riprova';

  @override
  String get profileEditSessionDataUnavailable =>
      'Impossibile accedere ai dati di accesso in questo momento.';

  @override
  String get profileEditNoSessionData => 'Nessun dato di accesso disponibile';

  @override
  String get profileEditSuccessfulSessionsTitle => 'Ultimi accessi riusciti';

  @override
  String get profileEditCurrentSession => 'Sessione corrente:';

  @override
  String get profileEditPreviousSession => 'Sessione precedente:';

  @override
  String get profileEditNoSuccessfulSessions =>
      'Nessun accesso riuscito registrato';

  @override
  String get profileEditFailedAttemptsTitle =>
      'Ultimi tentativi di accesso falliti';

  @override
  String profileEditAttemptLabel(Object count) {
    return 'Tentativo $count:';
  }

  @override
  String get profileEditNoFailedAttempts =>
      'Nessun tentativo fallito registrato.';

  @override
  String get profileEditSessionStatsTitle => 'Statistiche sessioni';

  @override
  String profileEditTotalSessions(Object count) {
    return 'Accessi totali: $count';
  }

  @override
  String profileEditSuccessfulAttempts(Object count) {
    return 'Tentativi riusciti: $count';
  }

  @override
  String profileEditFailedAttempts(Object count) {
    return 'Tentativi falliti: $count';
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
  String get navWeightControl => 'Controllo peso';

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
  String get loginInvalidCredentials => 'Nome utente o password non corretti.';

  @override
  String get loginFailedGeneric =>
      'Sign-in could not be completed. Please try again.';

  @override
  String get loginGuestFailedGeneric =>
      'Guest access could not be completed. Please try again.';

  @override
  String get loginUnknownUserType => 'Tipo di utente sconosciuto';

  @override
  String get loginTwoFactorTitle => 'Verifica 2FA';

  @override
  String get loginTwoFactorPrompt =>
      'Inserisci il codice di 6 cifre della tua app TOTP.';

  @override
  String get loginTwoFactorCodeLabel => 'Codice 2FA';

  @override
  String get loginTrustThisDevice => 'Considera attendibile questo dispositivo';

  @override
  String get loginTrustThisDeviceSubtitle =>
      'La 2FA non verra piu richiesta su questo dispositivo.';

  @override
  String get loginCodeMustHave6Digits => 'Il codice deve avere 6 cifre.';

  @override
  String get loginRecoveryTitle => 'Recupera accesso';

  @override
  String get loginRecoveryIdentifierIntro =>
      'Inserisci il tuo nome utente (nick) o la tua email per recuperare l\'accesso.';

  @override
  String get loginUserOrEmailLabel => 'Nome utente o email';

  @override
  String get loginEnterUserOrEmail => 'Inserisci un nome utente o una email.';

  @override
  String get loginNoRecoveryMethods =>
      'Questo utente non ha metodi di recupero disponibili.';

  @override
  String get loginSelectRecoveryMethod => 'Seleziona il metodo di recupero';

  @override
  String get loginRecoveryByEmail => 'Usando la tua email';

  @override
  String get loginRecoveryByTwoFactor =>
      'Usando l\'autenticazione a due fattori (2FA)';

  @override
  String get loginEmailRecoveryIntro =>
      'Ti invieremo un codice di recupero via email. Inseriscilo qui insieme alla tua nuova password.';

  @override
  String get loginRecoveryStep1SendCode => 'Passo 1: Invia codice';

  @override
  String get loginRecoveryStep1SendCodeBody =>
      'Tocca \"Invia codice\" per ricevere un codice di recupero via email.';

  @override
  String get loginSendCode => 'Invia codice';

  @override
  String get loginRecoveryStep2VerifyCode => 'Passo 2: Verifica codice';

  @override
  String get loginRecoveryStep2VerifyCodeBody =>
      'Inserisci il codice che hai ricevuto via email.';

  @override
  String get loginRecoveryCodeLabel => 'Codice di recupero';

  @override
  String get loginRecoveryCodeHintAlpha => 'Ex. 1a3B';

  @override
  String get loginRecoveryCodeHintNumeric => 'Ex. 1234';

  @override
  String get loginVerifyCode => 'Verifica codice';

  @override
  String get loginRecoveryStep3NewPassword => 'Passo 3: Nuova password';

  @override
  String get loginRecoveryStep3NewPasswordBody =>
      'Inserisci la tua nuova password.';

  @override
  String get loginNewPasswordLabel => 'Nuova password';

  @override
  String get loginRepeatNewPasswordLabel => 'Ripeti la nuova password';

  @override
  String get loginBothPasswordsRequired =>
      'Compila entrambi i campi della password.';

  @override
  String get loginPasswordsMismatch => 'Le password non coincidono.';

  @override
  String get loginPasswordResetSuccess =>
      'Password reimpostata. Ora puoi accedere.';

  @override
  String get loginTwoFactorRecoveryIntro =>
      'Per reimpostare la password usando l\'autenticazione a due fattori, ti serve il codice temporaneo della tua app.';

  @override
  String get loginTwoFactorRecoveryStep1 =>
      'Passo 1: Apri la tua app di autenticazione';

  @override
  String get loginTwoFactorRecoveryStep1Body =>
      'Cerca il codice temporaneo di 6 cifre nella tua app di autenticazione (Google Authenticator, Microsoft Authenticator, Authy, ecc.)';

  @override
  String get loginIHaveIt => 'Ce l\'ho';

  @override
  String get loginTwoFactorRecoveryStep2 =>
      'Passo 2: Verifica il tuo codice 2FA';

  @override
  String get loginTwoFactorRecoveryStep2Body =>
      'Inserisci il codice di 6 cifre nel campo qui sotto.';

  @override
  String get loginTwoFactorCodeSixDigitsLabel => 'Codice 2FA (6 cifre)';

  @override
  String get loginTwoFactorCodeHint => '000000';

  @override
  String get loginVerifyTwoFactorCode => 'Verifica codice 2FA';

  @override
  String get loginCodeMustHaveExactly6Digits =>
      'Il codice deve avere esattamente 6 cifre.';

  @override
  String get loginPasswordUpdatedSuccess =>
      'Password aggiornata. Ora puoi accedere.';

  @override
  String get loginUsernameLabel => 'Nome utente';

  @override
  String get loginEnterUsername => 'Inserisci il tuo nome utente';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginEnterPassword => 'Inserisci la tua password';

  @override
  String get loginSignIn => 'Accedi';

  @override
  String get loginForgotPassword => 'Hai dimenticato la password?';

  @override
  String get loginGuestInfo =>
      'Accedi gratis a NutriFit per consultare consigli di salute e nutrizione, video di esercizi, ricette, controllo del peso e molto altro.';

  @override
  String get loginGuestAccess => 'Accedi senza credenziali';

  @override
  String get loginRegisterFree => 'Registrati gratis';

  @override
  String get registerCreateAccountTitle => 'Crea account';

  @override
  String get registerFullNameLabel => 'Nome completo';

  @override
  String get registerEnterFullName => 'Inserisci il tuo nome';

  @override
  String get registerUsernameMinLength =>
      'Il nome utente deve contenere almeno 3 caratteri';

  @override
  String get registerEmailLabel => 'Email';

  @override
  String get registerInvalidEmail => 'Email non valida';

  @override
  String get registerAdditionalDataTitle => 'Dati aggiuntivi';

  @override
  String get registerAdditionalDataCollapsedSubtitle =>
      'Eta e altezza (facoltative)';

  @override
  String get registerAdditionalDataExpandedSubtitle =>
      'Eta e altezza per IMC/MVP';

  @override
  String get registerAdditionalDataInfo =>
      'Per abilitare il calcolo di IMC, MVP e delle metriche di salute, inserisci eta e altezza (in centimetri).';

  @override
  String get registerAgeLabel => 'Eta';

  @override
  String get registerInvalidAge => 'Eta non valida';

  @override
  String get registerHeightLabel => 'Altezza (cm)';

  @override
  String get registerInvalidHeight => 'Altezza non valida';

  @override
  String get registerConfirmPasswordLabel => 'Conferma password';

  @override
  String get registerConfirmPasswordRequired => 'Conferma la password';

  @override
  String get registerCreateAccountButton => 'Crea account';

  @override
  String get registerAlreadyHaveAccount => 'Hai gia un account? Accedi';

  @override
  String get registerEmailUnavailable =>
      'Questo indirizzo email non puo essere utilizzato. Inseriscine un altro.';

  @override
  String get registerSuccessMessage =>
      'Utente registrato correttamente. Accedi con i tuoi dati (nome utente e password).';

  @override
  String get registerNetworkError =>
      'Impossibile completare il processo. Controlla la connessione a Internet.';

  @override
  String get registerGenericError => 'Errore durante la registrazione';

  @override
  String get loginResetPassword => 'Reimposta la password';

  @override
  String get loginEmailRecoverySendFailedGeneric =>
      'Non e stato possibile inviare l\'email di recupero in questo momento. Riprova piu tardi.';

  @override
  String get passwordChecklistTitle => 'Requisiti della password:';

  @override
  String passwordChecklistMinLength(Object count) {
    return 'Minimo $count caratteri';
  }

  @override
  String get passwordChecklistUpperLower =>
      'Almeno una lettera maiuscola e una minuscola';

  @override
  String get passwordChecklistNumber => 'Almeno un numero (0-9)';

  @override
  String get passwordChecklistSpecial =>
      'Almeno un carattere speciale (*,.+-#\\\$?¿!¡_()/\\%&)';

  @override
  String loginPasswordMinLengthError(Object count) {
    return 'La nuova password deve contenere almeno $count caratteri.';
  }

  @override
  String get loginPasswordUppercaseError =>
      'La nuova password deve contenere almeno una lettera maiuscola.';

  @override
  String get loginPasswordLowercaseError =>
      'La nuova password deve contenere almeno una lettera minuscola.';

  @override
  String get loginPasswordNumberError =>
      'La nuova password deve contenere almeno un numero.';

  @override
  String get loginPasswordSpecialError =>
      'La nuova password deve contenere almeno un carattere speciale (* , . + - # \\\$ ? ¿ ! ¡ _ ( ) / \\ % &).';

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
  String get patientAdherenceNutriPlan => 'Piano nutrizionale';

  @override
  String get patientAdherenceFitPlan => 'Piano Fit';

  @override
  String get patientAdherenceCompleted => 'Completato';

  @override
  String get patientAdherencePartial => 'Parziale';

  @override
  String get patientAdherenceNotDone => 'Non eseguito';

  @override
  String get patientAdherenceNoChanges => 'Nessun cambiamento';

  @override
  String patientAdherenceTrendPoints(Object trend) {
    return '$trend pts';
  }

  @override
  String get patientAdherenceTitle => 'Aderenza';

  @override
  String get patientAdherenceImprovementPoints => 'Punti di miglioramento';

  @override
  String get patientAdherenceImprovementNutriTarget =>
      'Nutri: prova a rispettare il piano almeno 5 giorni su 7 questa settimana.';

  @override
  String get patientAdherenceImprovementNutriTrend =>
      'Nutri: la tendenza e in calo rispetto alla settimana scorsa; torna alla tua routine base.';

  @override
  String get patientAdherenceImprovementFitTarget =>
      'Fit: prova a raggiungere 3-4 sessioni a settimana, anche se brevi.';

  @override
  String get patientAdherenceImprovementFitTrend =>
      'Fit: la tendenza e diminuita; programma oggi le prossime sessioni.';

  @override
  String get patientAdherenceImprovementKeepGoing =>
      'Buon ritmo. Mantieni la costanza per consolidare i risultati.';

  @override
  String get patientAdherenceSheetTitleToday => 'Aderenza per oggi';

  @override
  String patientAdherenceSheetTitleForDate(Object date) {
    return 'Aderenza per $date';
  }

  @override
  String get patientAdherenceDateToday => 'oggi';

  @override
  String patientAdherenceStatusSaved(Object plan, Object status, Object date) {
    return '$plan: $status $date';
  }

  @override
  String get patientAdherenceFutureDateError =>
      'Non e possibile registrare l\'aderenza in date future. Solo oggi o giorni precedenti.';

  @override
  String get patientAdherenceReasonNotDoneTitle =>
      'Motivo della mancata esecuzione';

  @override
  String get patientAdherenceReasonPartialTitle =>
      'Motivo dell\'esecuzione parziale';

  @override
  String get patientAdherenceReasonHint =>
      'Raccontaci brevemente cosa e successo oggi';

  @override
  String get patientAdherenceSkipReason => 'Salta il motivo';

  @override
  String get patientAdherenceSaveContinue => 'Salva e continua';

  @override
  String patientAdherenceSaveError(Object error) {
    return 'Impossibile salvare nel database: $error';
  }

  @override
  String get patientAdherenceReasonLabel => 'Motivo';

  @override
  String get patientAdherenceInfoTitle =>
      'Che cosa significa ogni stato di aderenza?';

  @override
  String get patientAdherenceNutriCompletedDescription =>
      'Hai seguito il piano alimentare esattamente come previsto per questa giornata.';

  @override
  String get patientAdherenceNutriPartialDescription =>
      'Hai seguito una parte del piano ma non completamente: un pasto e stato saltato, modificato o con una quantita diversa.';

  @override
  String get patientAdherenceNutriNotDoneDescription =>
      'Non hai seguito il piano alimentare in questa giornata.';

  @override
  String get patientAdherenceFitCompletedDescription =>
      'Hai completato l\'allenamento previsto per questa giornata.';

  @override
  String get patientAdherenceFitPartialDescription =>
      'Hai svolto solo una parte dell\'allenamento: alcuni esercizi, serie o la durata sono rimasti incompleti.';

  @override
  String get patientAdherenceFitNotDoneDescription =>
      'Non hai svolto l\'allenamento in questa giornata.';

  @override
  String get patientAdherenceAlertRecoveryTitle => 'E ora di reagire';

  @override
  String patientAdherenceAlertRecoveryBody(Object plan) {
    return 'Sei sotto il 50% da due settimane di fila in $plan. Riprendiamo subito il ritmo: piccoli passi ogni giorno, ma senza saltare. Puoi farcela, ma ora bisogna fare sul serio.';
  }

  @override
  String get patientAdherenceAlertEncouragementTitle => 'C\'e ancora tempo';

  @override
  String patientAdherenceAlertEncouragementBody(Object plan) {
    return 'Questa settimana $plan e sotto il 50%. La prossima puo andare molto meglio: torna alla tua routine base e aggiungi una piccola vittoria ogni giorno.';
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
  String get patientContactDietitianPrompt => 'Contatta il dietista...';

  @override
  String get patientContactDietitianTrainer => 'Contatta Dietista/Allenatore';

  @override
  String get contactDietitianMethodsTitle => 'Modalita di contatto';

  @override
  String get contactDietitianEmailLabel => 'Email';

  @override
  String get contactDietitianCallLabel => 'Chiama';

  @override
  String get contactDietitianSocialTitle => 'Seguici sui social';

  @override
  String get contactDietitianWebsiteLabel => 'Sito web';

  @override
  String get contactDietitianPhoneCopied =>
      'Numero di telefono copiato negli appunti.';

  @override
  String get contactDietitianWhatsappInvalidPhone =>
      'Non esiste un numero valido per aprire WhatsApp.';

  @override
  String contactDietitianWhatsappOpenError(Object error) {
    return 'Impossibile aprire WhatsApp: $error';
  }

  @override
  String get contactDietitianWhatsappDialogTitle => 'Contatta tramite WhatsApp';

  @override
  String contactDietitianWhatsappDialogBody(Object phone) {
    return 'Puoi aprire direttamente la chat di WhatsApp con il numero $phone. Puoi anche copiare il numero negli appunti per usarlo nella tua applicazione WhatsApp o salvarlo.';
  }

  @override
  String get contactDietitianCopyPhone => 'Copia telefono';

  @override
  String get contactDietitianOpenWhatsapp => 'Apri WhatsApp';

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
  String get chatMessageHint => 'Scrivi un messaggio';

  @override
  String get profileImagePickerDialogTitle => 'Seleziona immagine profilo';

  @override
  String get profileImagePickerTakePhoto => 'Scatta foto';

  @override
  String get profileImagePickerChooseFromGallery => 'Scegli dalla galleria';

  @override
  String get profileImagePickerSelectImage => 'Seleziona immagine';

  @override
  String get profileImagePickerRemovePhoto => 'Rimuovi foto';

  @override
  String get profileImagePickerPrompt => 'Seleziona la tua immagine profilo';

  @override
  String profileImagePickerMaxDimensions(Object width, Object height) {
    return 'Max. ${width}x${height}px';
  }

  @override
  String profileImagePickerSaved(Object sizeKb) {
    return 'Immagine salvata correttamente (${sizeKb}KB)';
  }

  @override
  String get profileImagePickerProcessError =>
      'Errore durante l\'elaborazione dell\'immagine';

  @override
  String get profileImagePickerTechnicalDetails => 'Dettagli tecnici';

  @override
  String get profileImagePickerOperationFailed =>
      'Impossibile completare l\'operazione. Riprova o contatta il supporto.';

  @override
  String get shoppingListPremiumTitle => 'Lista della spesa Premium';

  @override
  String shoppingListPremiumSubtitle(Object limit) {
    return 'Puoi vedere gli ultimi $limit elementi e creare fino a $limit record. Se vuoi una lista illimitata, ';
  }

  @override
  String get shoppingListPremiumHighlight => 'passa a Premium.';

  @override
  String shoppingListPremiumLimitMessage(Object limit) {
    return 'Come utente non Premium puoi creare fino a $limit elementi nella lista della spesa. Passa a Premium per aggiungere elementi illimitati e accedere a tutto lo storico.';
  }

  @override
  String get shoppingListTabAll => 'Tutti';

  @override
  String get shoppingListTabPending => 'Prossimo acquisto';

  @override
  String get shoppingListTabBought => 'Acquistati';

  @override
  String get shoppingListTabExpiring => 'In scadenza';

  @override
  String get shoppingListTabExpired => 'Scaduti';

  @override
  String get shoppingListFilterCategories => 'Filtra categorie';

  @override
  String shoppingListFilterCategoriesCount(Object count) {
    return 'Filtra categorie ($count)';
  }

  @override
  String get shoppingListMoreOptions => 'Altre opzioni';

  @override
  String get shoppingListFilter => 'Filtra';

  @override
  String get shoppingListRefresh => 'Aggiorna';

  @override
  String get shoppingListAddItem => 'Aggiungi elemento';

  @override
  String get shoppingListGuestMessage =>
      'Per usare la lista della spesa devi registrarti. E gratis.';

  @override
  String get weightControlBack => 'Indietro';

  @override
  String get weightControlChangeTarget => 'Cambia peso obiettivo';

  @override
  String get weightControlHideFilter => 'Nascondi filtro';

  @override
  String get weightControlShowFilter => 'Mostra filtro';

  @override
  String get weightControlGuestMessage =>
      'Per gestire il monitoraggio del peso devi registrarti. E gratis.';

  @override
  String weightControlLoadError(Object error) {
    return 'Errore nel caricamento delle misurazioni: $error';
  }

  @override
  String get weightControlNoMeasurementsTitle =>
      'Non ci sono ancora misurazioni registrate.';

  @override
  String get weightControlNoMeasurementsBody =>
      'Inizia aggiungendo la tua prima misurazione per vedere i progressi.';

  @override
  String get weightControlAddMeasurement => 'Aggiungi misurazione';

  @override
  String weightControlNoWeightsForPeriod(Object period) {
    return 'Non ci sono pesi per $period.';
  }

  @override
  String weightControlNoMeasurementsForPeriod(Object period) {
    return 'Non ci sono misurazioni per $period.';
  }

  @override
  String get weightControlPremiumPerimetersTitle =>
      'Evoluzione Premium dei perimetri';

  @override
  String get weightControlPremiumChartBody =>
      'Questo grafico e disponibile solo per gli utenti Premium. Attiva il tuo account per vedere tutti i progressi con indicatori visivi avanzati.';

  @override
  String get weightControlCurrentMonth => 'Mese corrente';

  @override
  String get weightControlPreviousMonth => 'Mese precedente';

  @override
  String get weightControlQuarter => 'Trimestre';

  @override
  String get weightControlSemester => 'Semestre';

  @override
  String get weightControlCurrentYear => 'Anno corrente';

  @override
  String get weightControlPreviousYear => 'Anno precedente';

  @override
  String get weightControlAllTime => 'Sempre';

  @override
  String weightControlLastDaysLabel(Object days) {
    return 'Ultimi $days giorni';
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
  String get commonPremiumFeatureTitle => 'Funzione Premium';

  @override
  String get commonSearch => 'Cerca';

  @override
  String get commonFilter => 'Filtra';

  @override
  String get commonRefresh => 'Aggiorna';

  @override
  String get commonMoreOptions => 'Altre opzioni';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonClear => 'Cancella';

  @override
  String get commonApply => 'Applica';

  @override
  String get commonCopy => 'Copia';

  @override
  String get commonGeneratePdf => 'Genera PDF';

  @override
  String get commonHideSearch => 'Nascondi ricerca';

  @override
  String get commonFilterByCategories => 'Filtra per categorie';

  @override
  String commonFilterByCategoriesCount(Object count) {
    return 'Filtra categorie ($count)';
  }

  @override
  String get commonMatchAll => 'Corrispondi a tutte';

  @override
  String get commonRequireAllSelected =>
      'Se attivo, richiede tutte quelle selezionate.';

  @override
  String commonCategoryFallback(Object id) {
    return 'Categoria $id';
  }

  @override
  String get commonSignInToLike => 'Devi accedere per mettere mi piace';

  @override
  String get commonSignInToSaveFavorites =>
      'Devi accedere per salvare i preferiti';

  @override
  String get commonCouldNotIdentifyUser =>
      'Errore: impossibile identificare l\'utente';

  @override
  String commonLikeChangeError(Object error) {
    return 'Errore nel modificare il mi piace. $error';
  }

  @override
  String commonFavoriteChangeError(Object error) {
    return 'Errore nel modificare il preferito. $error';
  }

  @override
  String commonGuestFavoritesRequiresRegistration(Object itemType) {
    return 'Per aggiungere $itemType ai preferiti, devi registrarti (e gratis).';
  }

  @override
  String get commonRecipesAndTipsPremiumCopyPdfMessage =>
      'Per copiare ed esportare in PDF ricette e consigli, devi essere un utente Premium.';

  @override
  String get commonCopiedToClipboard => 'Copiato negli appunti';

  @override
  String commonCopiedToClipboardLabel(Object label) {
    return '$label copiato negli appunti.';
  }

  @override
  String get commonLanguage => 'Lingua';

  @override
  String get commonUser => 'utente';

  @override
  String get languageSpanish => 'Spagnolo';

  @override
  String get languageEnglish => 'Inglese';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageGerman => 'Tedesco';

  @override
  String get languageFrench => 'Francese';

  @override
  String get languagePortuguese => 'Portoghese';

  @override
  String commonCopyError(Object error) {
    return 'Errore durante la copia: $error';
  }

  @override
  String commonGeneratePdfError(Object error) {
    return 'Errore durante la generazione del PDF: $error';
  }

  @override
  String commonOpenLinkError(Object error) {
    return 'Errore nell\'aprire il link: $error';
  }

  @override
  String get commonDocumentUnavailable => 'Il documento non e disponibile';

  @override
  String commonDecodeError(Object error) {
    return 'Errore di decodifica: $error';
  }

  @override
  String get commonSaveDocumentError =>
      'Errore: impossibile salvare il documento';

  @override
  String commonOpenDocumentError(Object error) {
    return 'Errore nell\'aprire il documento: $error';
  }

  @override
  String get commonDownloadDocument => 'Scarica documento';

  @override
  String get commonDocumentsAndLinks => 'Documenti e link';

  @override
  String get commonYouMayAlsoLike => 'Potrebbe interessarti anche...';

  @override
  String get commonSortByTitle => 'Ordina per titolo';

  @override
  String get commonSortByRecent => 'Ordina per recenti';

  @override
  String get commonSortByPopular => 'Ordina per popolari';

  @override
  String get commonPersonalTab => 'Personali';

  @override
  String get commonFeaturedTab => 'In evidenza';

  @override
  String get commonAllTab => 'Tutti';

  @override
  String get commonFavoritesTab => 'Preferiti';

  @override
  String get commonFeaturedFeminineTab => 'In evidenza';

  @override
  String get commonAllFeminineTab => 'Tutte';

  @override
  String get commonFavoritesFeminineTab => 'Preferite';

  @override
  String commonLikesCount(Object count) {
    return '$count mi piace';
  }

  @override
  String get commonLink => 'Link';

  @override
  String get commonTipItem => 'consiglio';

  @override
  String get commonRecipeItem => 'ricetta';

  @override
  String get commonAdditiveItem => 'additivo';

  @override
  String get commonSupplementItem => 'integratore';

  @override
  String commonSeeLinkToType(Object type) {
    return 'Vedi il link a $type';
  }

  @override
  String get commonDocument => 'Documento';

  @override
  String get todoPriorityHigh => 'Alta';

  @override
  String get todoPriorityMedium => 'Media';

  @override
  String get todoPriorityLow => 'Bassa';

  @override
  String get todoStatusPending => 'In sospeso';

  @override
  String get todoStatusResolved => 'Completata';

  @override
  String todoCalendarPriority(Object value) {
    return 'Priorita: $value';
  }

  @override
  String todoCalendarStatus(Object value) {
    return 'Stato: $value';
  }

  @override
  String todoExportError(Object error) {
    return 'Errore durante l\'esportazione dell\'attivita: $error';
  }

  @override
  String get todoDateRequiredForCalendar =>
      'L\'attivita deve avere una data per poter essere aggiunta al calendario';

  @override
  String todoAddToCalendarError(Object error) {
    return 'Impossibile aggiungere l\'attivita al calendario: $error';
  }

  @override
  String todoPremiumLimitMessage(int limit) {
    return 'Come utente non Premium puoi creare fino a $limit attivita. Passa a Premium per aggiungere attivita illimitate e consultare tutto lo storico.';
  }

  @override
  String get todoNoDate => 'Senza data';

  @override
  String get todoPriorityHighTooltip => 'Priorita alta';

  @override
  String get todoPriorityMediumTooltip => 'Priorita media';

  @override
  String get todoPriorityLowTooltip => 'Priorita bassa';

  @override
  String get todoStatusResolvedShort => 'Completata (C)';

  @override
  String get todoStatusPendingShort => 'In sospeso (S)';

  @override
  String get todoMarkPending => 'Segna come in sospeso';

  @override
  String get todoMarkResolved => 'Segna come completata';

  @override
  String get todoEditTaskTitle => 'Modifica attivita';

  @override
  String get todoNewTaskTitle => 'Nuova attivita';

  @override
  String get todoTitleLabel => 'Titolo';

  @override
  String get todoTitleRequired => 'Il titolo e obbligatorio';

  @override
  String get todoDescriptionTitle => 'Descrizione';

  @override
  String get todoDescriptionOptionalLabel => 'Descrizione (opzionale)';

  @override
  String get todoPriorityTitle => 'Priorita';

  @override
  String get todoStatusTitle => 'Stato';

  @override
  String todoTasksForDay(Object date) {
    return 'Attivita del $date';
  }

  @override
  String get todoNewShort => 'Nuova';

  @override
  String get todoNoTasksSelectedDay =>
      'Non ci sono attivita per il giorno selezionato.';

  @override
  String get todoNoTasksToShow => 'Nessuna attivita da mostrare';

  @override
  String get todoPremiumTitle => 'Attivita Premium';

  @override
  String todoPremiumPreviewSubtitle(int limit) {
    return 'Puoi consultare gli ultimi $limit registri e creare fino a $limit attivita. Se vuoi attivita illimitate, passa a Premium.';
  }

  @override
  String todoPremiumPreviewHighlight(int count) {
    return 'Attualmente hai $count attivita registrate.';
  }

  @override
  String get todoEmptyState => 'Non hai ancora creato nessuna attivita.';

  @override
  String get todoScreenTitle => 'Attivita';

  @override
  String get todoTabPending => 'In sospeso';

  @override
  String get todoTabResolved => 'Completate';

  @override
  String get todoTabAll => 'Tutte';

  @override
  String get todoHideFilters => 'Nascondi filtri';

  @override
  String get todoViewList => 'Vedi elenco';

  @override
  String get todoViewCalendar => 'Vedi calendario';

  @override
  String get todoSortByDate => 'Ordina per data';

  @override
  String get todoSortByPriority => 'Ordina per priorita';

  @override
  String get todoSearchHint => 'Cerca attivita';

  @override
  String get todoClearSearch => 'Cancella ricerca';

  @override
  String get todoDeleteTitle => 'Elimina attivita';

  @override
  String todoDeleteConfirm(Object title) {
    return 'Vuoi eliminare l\'attivita \"$title\"?';
  }

  @override
  String get todoDeletedSuccess => 'Attivita eliminata';

  @override
  String get todoAddToDeviceCalendar =>
      'Aggiungi al calendario del dispositivo';

  @override
  String get todoEditAction => 'Modifica';

  @override
  String get todoSelectDate => 'Seleziona data';

  @override
  String get todoRemoveDate => 'Rimuovi data';

  @override
  String get todoGuestTitle => 'Attivita per utenti registrati';

  @override
  String get todoGuestBody =>
      'Accedi o passa a Premium per creare, organizzare e sincronizzare le tue attivita su tutti i tuoi dispositivi.';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonSortByName => 'Ordina per nome';

  @override
  String get commonSortByType => 'Ordina per tipo';

  @override
  String get commonSortByDate => 'Ordina per data';

  @override
  String get commonSortBySeverity => 'Ordina per gravita';

  @override
  String get commonName => 'Nome';

  @override
  String get commonTitleField => 'Titolo';

  @override
  String get commonDescriptionField => 'Descrizione';

  @override
  String get commonTypeField => 'Tipo';

  @override
  String get commonSeverity => 'Gravita';

  @override
  String commonNoResultsForQuery(Object query) {
    return 'Nessun risultato per \"$query\"';
  }

  @override
  String get tipsPremiumToolsMessage =>
      'Ricerca, filtri, preferiti, mi piace e accesso completo al catalogo dei consigli sono disponibili solo per gli utenti Premium.';

  @override
  String get tipsPremiumPreviewTitle => 'Consigli Premium';

  @override
  String get tipsPremiumPreviewSubtitle =>
      'Puoi vedere un\'anteprima degli ultimi 3 consigli. Passa a Premium per accedere al catalogo completo e a tutti i suoi strumenti.';

  @override
  String tipsPreviewAvailableCount(Object count) {
    return ' Attualmente sono disponibili $count consigli.';
  }

  @override
  String get tipsSearchLabel => 'Cerca consigli';

  @override
  String get tipsNoPersonalizedRecommendations =>
      'Nessun consiglio personalizzato';

  @override
  String get tipsViewGeneralTips => 'Vedi consigli generali';

  @override
  String get tipsUnreadBadge => 'Non letto';

  @override
  String get messagesInboxTitle => 'Messaggi non letti';

  @override
  String get messagesInboxGuestBody =>
      'Per chattare online con il tuo dietista, registrati per favore (e gratis).';

  @override
  String get messagesInboxGuestAction => 'Avvia registrazione';

  @override
  String get messagesInboxUnreadChats => 'Chat non lette';

  @override
  String get messagesInboxNoPendingChats => 'Non ci sono chat in sospeso.';

  @override
  String get messagesInboxUser => 'Utente';

  @override
  String get messagesInboxImage => 'Immagine';

  @override
  String get messagesInboxNoMessages => 'Nessun messaggio';

  @override
  String get messagesInboxPendingExerciseFeelings =>
      'Feedback sugli esercizi in sospeso';

  @override
  String get messagesInboxNoPendingExerciseFeelings =>
      'Non ci sono feedback sugli esercizi in sospeso.';

  @override
  String get messagesInboxViewPendingExerciseFeelings =>
      'Vedi feedback sugli esercizi in sospeso';

  @override
  String get messagesInboxUnreadDietitianChats =>
      'Chat con il dietista non lette';

  @override
  String get messagesInboxOpenDietitianChat => 'Apri chat con il dietista';

  @override
  String get messagesInboxMessage => 'Messaggio';

  @override
  String get messagesInboxDietitianMessage => 'Messaggio del dietista';

  @override
  String get messagesInboxUnreadCoachComments =>
      'Commenti dell\'allenatore non letti';

  @override
  String get messagesInboxNoUnreadCoachComments =>
      'Non hai commenti del personal trainer in attesa di lettura.';

  @override
  String get messagesInboxViewPendingComments => 'Vedi commenti in sospeso';

  @override
  String messagesInboxLoadError(Object error) {
    return 'Errore durante il caricamento dei messaggi: $error';
  }

  @override
  String get tipsNoFeaturedAvailable => 'Nessun consiglio in evidenza';

  @override
  String get tipsNoTipsAvailable => 'Nessun consiglio disponibile';

  @override
  String get tipsNoFavoriteTips => 'Non hai consigli preferiti';

  @override
  String get tipsDetailTitle => 'Dettagli del consiglio';

  @override
  String get tipsPreviewBanner =>
      'Anteprima - Questo e il modo in cui gli utenti vedranno il consiglio';

  @override
  String tipsHashtagTitle(Object hashtag) {
    return 'Consigli con $hashtag';
  }

  @override
  String tipsHashtagEmpty(Object hashtag) {
    return 'Non ci sono consigli con $hashtag';
  }

  @override
  String tipsLoadErrorStatus(Object statusCode) {
    return 'Errore durante il caricamento dei consigli: $statusCode';
  }

  @override
  String tipsLoadError(Object error) {
    return 'Errore durante il caricamento dei consigli. $error';
  }

  @override
  String get recipesPremiumToolsMessage =>
      'Ricerca, filtri, preferiti, mi piace e accesso completo al catalogo delle ricette sono disponibili solo per gli utenti Premium.';

  @override
  String get recipesPremiumPreviewTitle => 'Ricette Premium';

  @override
  String get recipesPremiumPreviewSubtitle =>
      'Puoi vedere un\'anteprima delle ultime 3 ricette. Passa a Premium per accedere al catalogo completo e a tutti i suoi strumenti.';

  @override
  String recipesPreviewAvailableCount(Object count) {
    return ' Attualmente sono disponibili $count ricette.';
  }

  @override
  String get recipesSearchLabel => 'Cerca ricette';

  @override
  String get recipesNoFeaturedAvailable => 'Nessuna ricetta in evidenza';

  @override
  String get recipesNoRecipesAvailable => 'Nessuna ricetta disponibile';

  @override
  String get recipesNoFavoriteRecipes => 'Non hai ricette preferite';

  @override
  String get recipesDetailTitle => 'Dettagli della ricetta';

  @override
  String get recipesPreviewBanner =>
      'Anteprima - Questo e il modo in cui gli utenti vedranno la ricetta';

  @override
  String recipesHashtagTitle(Object hashtag) {
    return 'Ricette con $hashtag';
  }

  @override
  String recipesHashtagEmpty(Object hashtag) {
    return 'Non ci sono ricette con $hashtag';
  }

  @override
  String get additivesPremiumCopyPdfMessage =>
      'Per copiare un additivo ed esportarlo in PDF, devi essere un utente Premium.';

  @override
  String get additivesPremiumExploreMessage =>
      'Hashtag e consigli sugli additivi sono disponibili solo per gli utenti Premium.';

  @override
  String get additivesPremiumToolsMessage =>
      'Ricerca, filtri, aggiornamento e ordinamento completo del catalogo degli additivi sono disponibili solo per gli utenti Premium.';

  @override
  String get additivesFilterTitle => 'Filtra additivi';

  @override
  String get additivesNoConfiguredTypes =>
      'Non ci sono tipi configurati in tipos_aditivos.';

  @override
  String get additivesTypesLabel => 'Tipi';

  @override
  String get additivesSearchHint => 'Cerca additivi';

  @override
  String get additivesEmpty => 'Nessun additivo disponibile';

  @override
  String get additivesPremiumTitle => 'Additivi Premium';

  @override
  String get additivesPremiumSubtitle =>
      'Il catalogo completo degli additivi e disponibile solo per gli utenti Premium.';

  @override
  String additivesCatalogHighlight(Object count) {
    return ' (con piu di $count additivi)';
  }

  @override
  String get additivesLoadFailed => 'Impossibile caricare gli additivi.';

  @override
  String get additivesCatalogUnavailable =>
      'Il catalogo degli additivi non e temporaneamente disponibile. Riprova piu tardi.';

  @override
  String get additivesServerConnectionError =>
      'Impossibile connettersi al server. Controlla la connessione e riprova.';

  @override
  String get additivesSeveritySafe => 'Sicuro';

  @override
  String get additivesSeverityAttention => 'Attenzione';

  @override
  String get additivesSeverityHigh => 'Alto';

  @override
  String get additivesSeverityRestricted => 'Limitato';

  @override
  String get additivesSeverityForbidden => 'Vietato';

  @override
  String get substitutionsPremiumToolsMessage =>
      'Ricerca, filtri, preferiti e ordinamento completo delle sostituzioni salutari sono disponibili solo per gli utenti Premium.';

  @override
  String get substitutionsPremiumCopyPdfMessage =>
      'Per copiare una sostituzione salutare ed esportarla in PDF, devi essere un utente Premium.';

  @override
  String get substitutionsPremiumExploreMessage =>
      'Hashtag, categorie, consigli e navigazione avanzata delle sostituzioni salutari sono disponibili solo per gli utenti Premium.';

  @override
  String get substitutionsPremiumEngagementMessage =>
      'Preferiti e mi piace delle sostituzioni salutari sono disponibili solo per gli utenti Premium.';

  @override
  String get substitutionsSearchLabel => 'Cerca sostituzioni o hashtag';

  @override
  String get substitutionsEmptyFeatured => 'Nessuna sostituzione in evidenza.';

  @override
  String get substitutionsEmptyAll => 'Nessuna sostituzione disponibile.';

  @override
  String get substitutionsEmptyFavorites =>
      'Non hai ancora sostituzioni preferite.';

  @override
  String get substitutionsPremiumTitle => 'Sostituzioni Premium';

  @override
  String get substitutionsPremiumSubtitle =>
      'La libreria completa delle sostituzioni salutari e disponibile solo per gli utenti Premium.';

  @override
  String substitutionsCatalogHighlight(Object count) {
    return ' (con piu di $count sostituzioni)';
  }

  @override
  String get substitutionsDefaultBadge => 'Sostituzione Premium';

  @override
  String get substitutionsTapForDetail =>
      'Tocca per vedere il dettaglio completo';

  @override
  String get substitutionsDetailTitle => 'Sostituzione salutare';

  @override
  String get substitutionsRecommendedChange => 'Cambio consigliato';

  @override
  String get substitutionsIfUnavailable => 'Se non hai';

  @override
  String get substitutionsUse => 'Usa';

  @override
  String get substitutionsEquivalence => 'Quantita equivalente';

  @override
  String get substitutionsGoal => 'Obiettivo';

  @override
  String get substitutionsNotesContext => 'Sustitución saludable';

  @override
  String get commonExport => 'Esporta';

  @override
  String get commonImport => 'Importa';

  @override
  String get commonPhoto => 'Foto';

  @override
  String get commonGallery => 'Galleria';

  @override
  String get commonUnavailable => 'Non disponibile';

  @override
  String get scannerTitle => 'Scanner etichette';

  @override
  String get scannerPremiumRequiredMessage =>
      'La scansione, l\'apertura di immagini dalla galleria e la ricerca di prodotti dallo scanner sono disponibili solo per gli utenti Premium.';

  @override
  String get scannerClearTrainingTitle => 'Cancella addestramento OCR';

  @override
  String get scannerClearTrainingBody =>
      'Tutte le correzioni salvate su questo dispositivo verranno eliminate. Vuoi continuare?';

  @override
  String get scannerLocalTrainingRemoved => 'Addestramento OCR locale rimosso';

  @override
  String get scannerExportRulesTitle => 'Esporta regole OCR';

  @override
  String get scannerImportRulesTitle => 'Importa regole OCR';

  @override
  String get scannerImportRulesHint => 'Incolla qui il JSON esportato';

  @override
  String get scannerInvalidFormat => 'Formato non valido';

  @override
  String get scannerInvalidJsonOrCanceled =>
      'JSON non valido o importazione annullata';

  @override
  String scannerImportedRulesCount(Object count) {
    return 'Importate $count regole di addestramento';
  }

  @override
  String get scannerRulesUploaded => 'Regole OCR caricate sul server';

  @override
  String scannerRulesUploadError(Object error) {
    return 'Errore nel caricamento delle regole: $error';
  }

  @override
  String get scannerNoRemoteRules => 'Nessuna regola remota disponibile.';

  @override
  String scannerDownloadedRulesCount(Object count) {
    return 'Scaricate $count regole dal server';
  }

  @override
  String scannerRulesDownloadError(Object error) {
    return 'Errore nel download delle regole: $error';
  }

  @override
  String get scannerTrainingMarkedCorrect =>
      'Addestramento salvato: lettura segnata come corretta';

  @override
  String get scannerCorrectOcrValuesTitle => 'Correggi valori OCR';

  @override
  String get scannerSugarField => 'Sugar (g)';

  @override
  String get scannerSaltField => 'Salt (g)';

  @override
  String get scannerFatField => 'Fat (g)';

  @override
  String get scannerProteinField => 'Protein (g)';

  @override
  String get scannerPortionField => 'Porzione (g)';

  @override
  String get scannerSaveCorrection => 'Salva correzione';

  @override
  String get scannerCorrectionSaved =>
      'Correzione salvata. Sara applicata a etichette simili.';

  @override
  String get scannerSourceBarcode => 'Codice a barre';

  @override
  String get scannerSourceOcrOpenFood => 'OCR nome + Open Food Facts';

  @override
  String get scannerSourceOcrTable => 'OCR tabella nutrizionale';

  @override
  String get scannerSourceAutoBarcodeOpenFood =>
      'Rilevamento automatico (codice a barre + Open Food Facts)';

  @override
  String get scannerSourceAutoOcrOpenFood =>
      'Rilevamento automatico (OCR + Open Food Facts)';

  @override
  String get scannerSourceAutoOcrTable =>
      'Rilevamento automatico (OCR tabella nutrizionale)';

  @override
  String get scannerNoNutritionData =>
      'Non e stato possibile ottenere i dati nutrizionali. Scatta la foto con buona illuminazione, testo nitido e inquadrando la tabella nutrizionale.';

  @override
  String scannerReadCompleted(Object source) {
    return 'Lettura completata: $source';
  }

  @override
  String scannerAnalyzeError(Object error) {
    return 'Impossibile analizzare l\'etichetta: $error';
  }

  @override
  String get scannerHeaderTitle => 'Scanner etichette alimentari';

  @override
  String get scannerHeaderTooltip => 'Informazioni complete sul processo';

  @override
  String get scannerHeaderBody =>
      'Scatta una foto del codice a barre di un prodotto o seleziona un\'immagine dalla galleria. Quando questa modalita e attiva, NutriFit rilevera automaticamente il codice a barre, il nome del prodotto o la tabella nutrizionale.';

  @override
  String get scannerPremiumBanner =>
      'Funzione Premium: puoi entrare nella schermata e vedere le informazioni, ma Ricerca, Foto e Galleria sono bloccate per gli utenti non Premium.';

  @override
  String get scannerTrainingModeTitle => 'Modalita di addestramento OCR';

  @override
  String get scannerTrainingModeSubtitle =>
      'Ti permette di correggere le letture per migliorare i rilevamenti.';

  @override
  String get scannerModeLabel => 'Modalita';

  @override
  String get scannerModeAuto => 'Modalita automatica';

  @override
  String get scannerModeBarcode => 'Modalita codice a barre';

  @override
  String get scannerModeOcrTable => 'Modalita tabella nutrizionale';

  @override
  String get scannerActionSearchOpenFood => 'Cerca in Open Food Facts';

  @override
  String get scannerAutoHint =>
      'In modalita automatica, l\'app prova prima a rilevare il codice a barre e, se non trova un prodotto valido, prova l\'OCR sul nome o sulla tabella nutrizionale.';

  @override
  String get scannerBarcodeHint =>
      'In modalita codice a barre, la fotocamera mostra una guida e l\'app analizza solo quell\'area per migliorare la precisione.';

  @override
  String get scannerOcrHint =>
      'In modalita tabella nutrizionale, l\'app da priorita alla lettura OCR del nome del prodotto e della tabella nutrizionale senza dipendere dal codice a barre.';

  @override
  String get scannerDismissHintTooltip =>
      'Chiudi (premi a lungo il pulsante modalita per mostrarlo di nuovo)';

  @override
  String get scannerAnalyzing => 'Analisi etichetta...';

  @override
  String get scannerResultPerServing => 'Risultato per porzione';

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
  String get scannerContactDietitianButton => 'Contatta il dietista';

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
      'Per accedere ai tuoi piani nutrizionali, ai piani di allenamento e alle raccomandazioni personalizzate, devi prima contattare il tuo dietista/allenatore online, che ti assegnerà un piano specifico adatto alle tue esigenze.';

  @override
  String get restrictedAccessContactMethods => 'Modalità di contatto:';

  @override
  String get restrictedAccessMoreContactOptions => 'Altre modalità di contatto';

  @override
  String get videosPremiumToolsMessage =>
      'Ricerca, filtri, preferiti, mi piace e ordinamento completo dei video di esercizi sono disponibili solo per gli utenti Premium.';

  @override
  String get videosPremiumPlaybackMessage =>
      'La riproduzione completa dei video di esercizi è disponibile solo per gli utenti Premium.';

  @override
  String get videosPremiumTitle => 'Video Premium';

  @override
  String get videosPremiumSubtitle =>
      'L\'intero catalogo dei video di esercizi è disponibile solo per gli utenti Premium. Accedi a ';

  @override
  String videosPremiumPreviewHighlight(Object count) {
    return '$count video esclusivi.';
  }

  @override
  String get charlasPremiumToolsMessage =>
      'Ricerca, filtri, preferiti, mi piace e ordinamento completo di conferenze e seminari sono disponibili solo per gli utenti Premium.';

  @override
  String get charlasPremiumContentMessage =>
      'L\'accesso completo al contenuto della conferenza o del seminario è disponibile solo per gli utenti Premium.';

  @override
  String get charlasPremiumTitle => 'Conferenze Premium';

  @override
  String get charlasPremiumSubtitle =>
      'L\'intero catalogo di conferenze e seminari è disponibile solo per gli utenti Premium. Accedi a ';

  @override
  String charlasPremiumPreviewHighlight(Object count) {
    return '$count conferenze esclusive.';
  }

  @override
  String get supplementsPremiumCopyPdfMessage =>
      'Per copiare un integratore ed esportarlo in PDF, devi essere un utente Premium.';

  @override
  String get supplementsPremiumExploreMessage =>
      'Hashtag e raccomandazioni sugli integratori sono disponibili solo per gli utenti Premium.';

  @override
  String get supplementsPremiumToolsMessage =>
      'Ricerca, aggiornamento e ordinamento completo del catalogo degli integratori sono disponibili solo per gli utenti Premium.';

  @override
  String get supplementsPremiumTitle => 'Integratori Premium';

  @override
  String get supplementsPremiumSubtitle =>
      'L\'intero catalogo degli integratori è disponibile solo per gli utenti Premium.';

  @override
  String supplementsPremiumPreviewHighlight(Object count) {
    return '(con più di $count integratori)';
  }

  @override
  String get exerciseCatalogPremiumToolsMessage =>
      'Ricerca, filtri, aggiornamento e ordinamento completo del catalogo degli esercizi sono disponibili solo per gli utenti Premium.';

  @override
  String get exerciseCatalogPremiumVideoMessage =>
      'Il video completo dell\'esercizio è disponibile solo per gli utenti Premium.';

  @override
  String get exerciseCatalogPremiumTitle => 'Esercizi Premium';

  @override
  String get exerciseCatalogPremiumSubtitle =>
      'L\'intero catalogo degli esercizi è disponibile solo per gli utenti Premium.';

  @override
  String exerciseCatalogPremiumPreviewHighlight(Object count) {
    return '(con più di $count esercizi)';
  }
}
