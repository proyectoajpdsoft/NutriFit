// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get settingsAndPrivacyTitle => 'Einstellungen und Datenschutz';

  @override
  String get settingsAndPrivacyMenuLabel => 'Einstellungen und Datenschutz';

  @override
  String get configTabParameters => 'Parameter';

  @override
  String get configTabPremium => 'Premium';

  @override
  String get configTabAppMenu => 'App-Menue';

  @override
  String get configTabGeneral => 'General';

  @override
  String get configTabSecurity => 'Sicherheit';

  @override
  String get configTabUser => 'Benutzer';

  @override
  String get configTabDisplay => 'Anzeige';

  @override
  String get configTabDefaults => 'Standard';

  @override
  String get configTabPrivacy => 'Datenschutz';

  @override
  String get securitySubtabAccess => 'Zugang';

  @override
  String get securitySubtabEmailServer => 'E-Mail-Server';

  @override
  String get securitySubtabCipher => 'Verschluesseln/Entschluesseln';

  @override
  String get securitySubtabSessions => 'Sitzungen';

  @override
  String get securitySubtabAccesses => 'Zugriffe';

  @override
  String get privacyCenterTab => 'Zentrum';

  @override
  String get privacyPolicyTab => 'Richtlinie';

  @override
  String get privacySessionsTab => 'Sitzungen';

  @override
  String privacyLastUpdatedLabel(Object date) {
    return 'Letzte Aktualisierung: $date';
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
      'Fuer nicht registrierte Benutzer sind keine Sitzungsdaten verfuegbar, da der Zugriff anonym erfolgt.';

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
    return 'Die App wurde auf Version $version aktualisiert.';
  }

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonAgree => 'OK';

  @override
  String get commonLater => 'Later';

  @override
  String get commonValidate => 'Bestaetigen';

  @override
  String get commonToday => 'heute';

  @override
  String get commonDebug => 'DEBUG';

  @override
  String get commonAllRightsReserved => 'Alle Rechte vorbehalten';

  @override
  String get navHome => 'Start';

  @override
  String get navLogout => 'Abmelden';

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
  String get navChatWithDietitian => 'Chat mit Ernaehrungsberater';

  @override
  String get navContactDietitian => 'Ernaehrungsberater kontaktieren';

  @override
  String get navEditProfile => 'Profil bearbeiten';

  @override
  String get profileEditProfileTab => 'Profil';

  @override
  String get profileEditSessionsTab => 'Anmeldungen';

  @override
  String get profileEditPremiumBadgeTitle => 'Premium-Konto';

  @override
  String get profileEditPremiumBadgeBody =>
      'Du hast Zugriff auf exklusive Funktionen wie Trainingsvideos.';

  @override
  String get profileEditNickLabel => 'Spitzname / Benutzer';

  @override
  String get profileEditNickRequired => 'Der Spitzname ist erforderlich';

  @override
  String get profileEditEmailLabel => 'Email';

  @override
  String get profileEditInvalidEmail => 'Ungueltige E-Mail';

  @override
  String get profileEditEmailInUse =>
      'Die eingegebene E-Mail ist nicht gueltig, bitte verwende eine andere.';

  @override
  String get profileEditChangeEmailTooltip => 'E-Mail-Konto aendern';

  @override
  String get profileEditVerifyEmailCta => 'E-Mail bestaetigen';

  @override
  String get profileEditTwoFactorShortLabel => 'Zwei-Faktor';

  @override
  String get profileEditBmiCardTitle => 'BMI-Daten';

  @override
  String get profileEditBmiInfoTooltip => 'BMI/MVP-Informationen';

  @override
  String get profileEditBmiCardBody =>
      'Um BMI, MVP und Empfehlungen zu erhalten, vervollstaendige Alter und Groesse.';

  @override
  String get profileEditAgeLabel => 'Alter';

  @override
  String get profileEditInvalidAge => 'Ungueltiges Alter';

  @override
  String get profileEditHeightLabel => 'Groesse (cm)';

  @override
  String get profileEditInvalidHeight => 'Ungueltige Groesse';

  @override
  String get profileEditPasswordCardTitle => 'Passwort aendern';

  @override
  String get profileEditPasswordHint =>
      'Leer lassen, um das aktuelle Passwort beizubehalten';

  @override
  String get profileEditPasswordLabel => 'Passwort';

  @override
  String get profileEditPasswordConfirmLabel => 'Passwort bestaetigen';

  @override
  String get profileEditPasswordConfirmRequired =>
      'Du musst das Passwort bestaetigen';

  @override
  String get profileEditPasswordMismatch =>
      'Die Passwoerter stimmen nicht ueberein';

  @override
  String get profileEditSaveChanges => 'Aenderungen speichern';

  @override
  String get profileEditDeleteMyData => 'Alle meine Daten loeschen';

  @override
  String get profileEditChangeEmailTitle => 'E-Mail aendern';

  @override
  String get profileEditChangeEmailVerifiedWarning =>
      'Die aktuelle E-Mail ist bestaetigt. Wenn du sie aenderst, musst du sie erneut bestaetigen.';

  @override
  String get profileEditChangeEmailNewLabel => 'Neue E-Mail';

  @override
  String get profileEditChangeEmailRequired => 'Du musst eine E-Mail angeben.';

  @override
  String get profileEditChangeEmailMustDiffer =>
      'Du musst eine andere E-Mail als die aktuelle angeben.';

  @override
  String get profileEditChangeEmailValidationFailed =>
      'Die E-Mail konnte nicht geprueft werden. Bitte versuche es erneut.';

  @override
  String get profileEditChangeEmailReview =>
      'Bitte pruefe die eingegebene E-Mail.';

  @override
  String get profileEditEmailRequiredForVerification =>
      'Du musst zuerst eine E-Mail-Adresse angeben.';

  @override
  String get profileEditEmailCodeSentGeneric => 'Code gesendet.';

  @override
  String get profileEditEmailVerifiedGeneric => 'E-Mail bestaetigt.';

  @override
  String get profileEditEmailCodeLengthError =>
      'Der Code muss 10 Ziffern haben.';

  @override
  String get profileEditEmailCodeDialogTitle => 'E-Mail-Code bestaetigen';

  @override
  String get profileEditEmailCodeTenDigitsLabel => '10-stelliger Code';

  @override
  String get profileEditValidateEmailCodeAction => 'E-Mail-Code bestaetigen';

  @override
  String get profileEditVerifyEmailTitle => 'E-Mail bestaetigen';

  @override
  String get profileEditVerifyEmailIntroPrefix =>
      'Wir muessen bestaetigen, dass diese E-Mail-Adresse dir gehoert:';

  @override
  String get profileEditVerifyEmailPremiumLink =>
      'Premium-Vorteile mit bestaetigter E-Mail ansehen';

  @override
  String get profileEditFollowTheseSteps => 'Folge diesen Schritten...';

  @override
  String get profileEditYourEmail => 'Deine E-Mail';

  @override
  String profileEditSendCodeInstruction(Object email) {
    return 'Tippe auf \"Code senden\", um den Bestaetigungscode an $email zu senden.';
  }

  @override
  String get profileEditEmailCodeSentInfo =>
      'Ein Code wurde an dein E-Mail-Konto gesendet. Er laeuft in 15 Minuten ab. Wenn du ihn nicht im Posteingang siehst, pruefe den Spam-Ordner.';

  @override
  String get profileEditEmailSendFailed =>
      'Die Bestaetigungs-E-Mail konnte derzeit nicht gesendet werden. Bitte spaeter erneut versuchen.';

  @override
  String get profileEditSendCodeAction => 'Code senden';

  @override
  String get profileEditResendCodeAction => 'Erneut senden';

  @override
  String get profileEditVerifyCodeInstruction =>
      'Gib den Bestaetigungscode ein, den wir dir gesendet haben.';

  @override
  String get profileEditVerificationCodeLabel => 'Bestaetigungscode';

  @override
  String get profileEditEmailRequiredInProfile =>
      'Du musst zuerst in Profil bearbeiten eine E-Mail-Adresse angeben, um sie bestaetigen zu koennen.';

  @override
  String get profileEditTwoFactorDialogTitle =>
      'Zwei-Faktor-Authentifizierung (2FA)';

  @override
  String get profileEditTwoFactorEnabledStatus => 'Status: Aktiviert';

  @override
  String get profileEditTwoFactorEnabledBody =>
      'Die Zwei-Faktor-Authentifizierung ist fuer dein Konto bereits aktiviert. Von hier aus kannst du nur pruefen, ob dieses Geraet vertrauenswuerdig ist, und es verknuepfen oder entkoppeln.';

  @override
  String get profileEditTrustedDeviceEnabledBody =>
      'Dieses Geraet ist als vertrauenswuerdig markiert. Der 2FA-Code wird bei kuenftigen Anmeldungen nicht abgefragt, bis du das Vertrauen hier entfernst.';

  @override
  String get profileEditTrustedDeviceDisabledBody =>
      'Dieses Geraet ist nicht als vertrauenswuerdig markiert. Du kannst es markieren, indem du auf \"Dieses Geraet als vertrauenswuerdig festlegen\" tippst oder dich abmeldest und erneut anmeldest und dabei waehrend der 2FA-Bestaetigung die Option \"Diesem Geraet vertrauen\" aktivierst.';

  @override
  String get profileEditRemoveTrustedDeviceAction =>
      'Vertrauen fuer dieses Geraet entfernen';

  @override
  String get profileEditSetTrustedDeviceAction =>
      'Dieses Geraet als vertrauenswuerdig festlegen';

  @override
  String get profileEditCancelProcess => 'Vorgang abbrechen';

  @override
  String get profileEditSetTrustedDeviceTitle =>
      'Vertrauenswuerdiges Geraet festlegen';

  @override
  String get profileEditSetTrustedDeviceBody =>
      'Um dieses Geraet als vertrauenswuerdig zu markieren, musst du es beim 2FA-Login bestaetigen und die Option \"Diesem Geraet vertrauen\" aktivieren.\n\nMoechtest du dich jetzt abmelden, um das zu tun?';

  @override
  String get profileEditGoToLogin => 'Zum Login';

  @override
  String get profileEditActivateTwoFactorTitle =>
      'Zwei-Faktor-Authentifizierung aktivieren';

  @override
  String get profileEditActivateTwoFactorIntro =>
      'Die Zwei-Faktor-Authentifizierung (2FA) fuegt eine zusaetzliche Sicherheitsebene hinzu: Neben deinem Passwort wird ein temporaerer Code aus deiner Authenticator-App abgefragt.';

  @override
  String get profileEditTwoFactorStep1 =>
      '1. Oeffne deine Authenticator-App und fuege ein neues Konto hinzu.';

  @override
  String get profileEditTwoFactorSetupKeyLabel => 'Einrichtungsschluessel';

  @override
  String get profileEditKeyCopied => 'Schluessel in die Zwischenablage kopiert';

  @override
  String get profileEditHideOptions => 'Optionen ausblenden';

  @override
  String get profileEditMoreOptions => 'Weitere Optionen...';

  @override
  String profileEditQrSavedDownloads(Object path) {
    return 'QR in Downloads gespeichert: $path';
  }

  @override
  String get profileEditQrShared =>
      'Das Menue zum Teilen oder Speichern des QR-Codes wurde geoeffnet.';

  @override
  String get profileEditOtpUrlCopied => 'otpauth-URL kopiert';

  @override
  String get profileEditCopyUrl => 'URL kopieren';

  @override
  String get profileEditOtpUrlInfo =>
      'Die Option \"URL kopieren\" kopiert einen otpauth-Link mit der vollstaendigen 2FA-Konfiguration zum Import in kompatible Apps. Wenn deine App keinen Link-Import unterstuetzt, nutze \"Kopieren\" beim Schluessel.';

  @override
  String get profileEditTwoFactorConfirmCodeInstruction =>
      'Gib zur Bestaetigung den 6-stelligen Code aus deiner Authenticator-App ein.';

  @override
  String get profileEditActivateTwoFactorAction => 'Aktivieren';

  @override
  String get profileEditTwoFactorActivated =>
      'Zwei-Faktor-Authentifizierung erfolgreich aktiviert';

  @override
  String get profileEditTwoFactorActivateFailed =>
      '2FA konnte nicht aktiviert werden.';

  @override
  String get profileEditNoQrData =>
      'Es sind keine Daten zum Speichern des QR-Codes vorhanden.';

  @override
  String profileEditQrSavedPath(Object path) {
    return 'QR gespeichert unter: $path';
  }

  @override
  String profileEditQrSaveFailed(Object error) {
    return 'QR konnte nicht gespeichert werden: $error';
  }

  @override
  String get profileEditDeactivateTwoFactorTitle =>
      'Zwei-Faktor-Authentifizierung (2FA) deaktivieren';

  @override
  String get profileEditCurrentCodeSixDigitsLabel =>
      'Aktueller 6-stelliger Code';

  @override
  String get profileEditDeactivateTwoFactorAction => 'Deaktivieren';

  @override
  String get profileEditTwoFactorDeactivated =>
      'Zwei-Faktor-Authentifizierung erfolgreich deaktiviert';

  @override
  String get profileEditTwoFactorDeactivateFailed =>
      '2FA konnte nicht deaktiviert werden.';

  @override
  String get profileEditRemoveTrustedDeviceTitle =>
      'Geraetevertrauen entfernen';

  @override
  String get profileEditRemoveTrustedDeviceBody =>
      'Auf diesem Geraet wird beim naechsten Login erneut der 2FA-Code abgefragt. Moechtest du fortfahren?';

  @override
  String get profileEditRemoveTrustedDeviceActionShort => 'Vertrauen entfernen';

  @override
  String get profileEditTrustedDeviceRemoved => 'Geraetevertrauen entfernt.';

  @override
  String profileEditTrustedDeviceRemoveFailed(Object error) {
    return 'Das Vertrauen fuer das Geraet konnte nicht entfernt werden: $error';
  }

  @override
  String get profileEditMvpDialogTitle => 'MVP-Berechnung und Formeln';

  @override
  String get profileEditMvpWhatIsTitle => 'Was ist MVP?';

  @override
  String get profileEditMvpWhatIsBody =>
      'MVP ist ein Mindestpaket anthropometrischer Indikatoren, mit dem du deine gesundheitliche Entwicklung einfach verfolgen kannst: BMI, Taille/Groesse und Taille/Huefte.';

  @override
  String get profileEditMvpFormulasTitle =>
      'Verwendete Formeln und ihre Herkunft:';

  @override
  String get profileEditMvpOriginBmi =>
      'Quelle: WHO (BMI-Klassifikation fuer Erwachsene).';

  @override
  String get profileEditMvpOriginWhtr => 'Quelle: Taille-Groesse-Verhaeltnis.';

  @override
  String get profileEditMvpOriginWhr =>
      'Quelle: Taille-Huefte-Verhaeltnis (WHO, abdominale Adipositas).';

  @override
  String get profileEditImportantNotice => 'Wichtiger Hinweis';

  @override
  String get profileEditMvpImportantNoticeBody =>
      'Diese Berechnungen und Einstufungen dienen nur zur Orientierung. Fuer eine persoenliche Bewertung konsultiere immer medizinisches Fachpersonal, eine Ernaehrungsfachkraft oder einen Personal Trainer.';

  @override
  String get profileEditAccept => 'Akzeptieren';

  @override
  String get profileEditNotAvailable => 'k. A.';

  @override
  String get profileEditSessionDate => 'Datum';

  @override
  String get profileEditSessionTime => 'Uhrzeit';

  @override
  String get profileEditSessionDevice => 'Geraet';

  @override
  String get profileEditSessionIp => 'IP-Adresse:';

  @override
  String get profileEditSessionPublicIp => 'Oeffentlich';

  @override
  String get profileEditUserCodeUnavailable => 'Benutzercode nicht verfuegbar';

  @override
  String get profileEditGenericError => 'Fehler';

  @override
  String get profileEditRetry => 'Erneut versuchen';

  @override
  String get profileEditSessionDataUnavailable =>
      'Auf die Anmeldedaten konnte im Moment nicht zugegriffen werden.';

  @override
  String get profileEditNoSessionData => 'Keine Anmeldedaten verfuegbar';

  @override
  String get profileEditSuccessfulSessionsTitle =>
      'Letzte erfolgreichen Anmeldungen';

  @override
  String get profileEditCurrentSession => 'Aktuelle Sitzung:';

  @override
  String get profileEditPreviousSession => 'Vorherige Sitzung:';

  @override
  String get profileEditNoSuccessfulSessions =>
      'Keine erfolgreichen Anmeldungen registriert';

  @override
  String get profileEditFailedAttemptsTitle =>
      'Letzte fehlgeschlagene Anmeldeversuche';

  @override
  String profileEditAttemptLabel(Object count) {
    return 'Versuch $count:';
  }

  @override
  String get profileEditNoFailedAttempts =>
      'Keine fehlgeschlagenen Versuche registriert.';

  @override
  String get profileEditSessionStatsTitle => 'Sitzungsstatistiken';

  @override
  String profileEditTotalSessions(Object count) {
    return 'Anmeldungen gesamt: $count';
  }

  @override
  String profileEditSuccessfulAttempts(Object count) {
    return 'Erfolgreiche Versuche: $count';
  }

  @override
  String profileEditFailedAttempts(Object count) {
    return 'Fehlgeschlagene Versuche: $count';
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
  String get navWeightControl => 'Gewichtskontrolle';

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
      'Falscher Benutzername oder falsches Passwort.';

  @override
  String get loginFailedGeneric =>
      'Sign-in could not be completed. Please try again.';

  @override
  String get loginGuestFailedGeneric =>
      'Guest access could not be completed. Please try again.';

  @override
  String get loginUnknownUserType => 'Unbekannter Benutzertyp';

  @override
  String get loginTwoFactorTitle => '2FA-Verifizierung';

  @override
  String get loginTwoFactorPrompt =>
      'Gib den 6-stelligen Code aus deiner TOTP-App ein.';

  @override
  String get loginTwoFactorCodeLabel => '2FA-Code';

  @override
  String get loginTrustThisDevice => 'Diesem Geraet vertrauen';

  @override
  String get loginTrustThisDeviceSubtitle =>
      'Die 2FA wird auf diesem Geraet nicht mehr abgefragt.';

  @override
  String get loginCodeMustHave6Digits => 'Der Code muss 6 Ziffern haben.';

  @override
  String get loginRecoveryTitle => 'Zugang wiederherstellen';

  @override
  String get loginRecoveryIdentifierIntro =>
      'Gib deinen Benutzernamen (Nick) oder deine E-Mail-Adresse ein, um den Zugang wiederherzustellen.';

  @override
  String get loginUserOrEmailLabel => 'Benutzername oder E-Mail';

  @override
  String get loginEnterUserOrEmail =>
      'Gib einen Benutzernamen oder eine E-Mail ein.';

  @override
  String get loginNoRecoveryMethods =>
      'Fuer diesen Benutzer sind keine Wiederherstellungsmethoden verfuegbar.';

  @override
  String get loginSelectRecoveryMethod =>
      'Wiederherstellungsmethode auswaehlen';

  @override
  String get loginRecoveryByEmail => 'Mit deiner E-Mail';

  @override
  String get loginRecoveryByTwoFactor =>
      'Mit Zwei-Faktor-Authentifizierung (2FA)';

  @override
  String get loginEmailRecoveryIntro =>
      'Wir senden dir einen Wiederherstellungscode per E-Mail. Gib ihn hier zusammen mit deinem neuen Passwort ein.';

  @override
  String get loginRecoveryStep1SendCode => 'Schritt 1: Code senden';

  @override
  String get loginRecoveryStep1SendCodeBody =>
      'Tippe auf \"Code senden\", um einen Wiederherstellungscode per E-Mail zu erhalten.';

  @override
  String get loginSendCode => 'Code senden';

  @override
  String get loginRecoveryStep2VerifyCode => 'Schritt 2: Code bestaetigen';

  @override
  String get loginRecoveryStep2VerifyCodeBody =>
      'Gib den Code ein, den du per E-Mail erhalten hast.';

  @override
  String get loginRecoveryCodeLabel => 'Wiederherstellungscode';

  @override
  String get loginRecoveryCodeHintAlpha => 'Ex. 1a3B';

  @override
  String get loginRecoveryCodeHintNumeric => 'Ex. 1234';

  @override
  String get loginVerifyCode => 'Code bestaetigen';

  @override
  String get loginRecoveryStep3NewPassword => 'Schritt 3: Neues Passwort';

  @override
  String get loginRecoveryStep3NewPasswordBody =>
      'Gib dein neues Passwort ein.';

  @override
  String get loginNewPasswordLabel => 'Neues Passwort';

  @override
  String get loginRepeatNewPasswordLabel => 'Neues Passwort wiederholen';

  @override
  String get loginBothPasswordsRequired =>
      'Fuellen Sie beide Passwortfelder aus.';

  @override
  String get loginPasswordsMismatch =>
      'Die Passwoerter stimmen nicht ueberein.';

  @override
  String get loginPasswordResetSuccess =>
      'Passwort zurueckgesetzt. Du kannst dich jetzt anmelden.';

  @override
  String get loginTwoFactorRecoveryIntro =>
      'Um dein Passwort mit Zwei-Faktor-Authentifizierung zurueckzusetzen, brauchst du den temporaeren Code aus deiner App.';

  @override
  String get loginTwoFactorRecoveryStep1 =>
      'Schritt 1: Oeffne deine Authentifizierungs-App';

  @override
  String get loginTwoFactorRecoveryStep1Body =>
      'Suche den temporaeren 6-stelligen Code in deiner Authentifizierungs-App (Google Authenticator, Microsoft Authenticator, Authy usw.)';

  @override
  String get loginIHaveIt => 'Ich habe ihn';

  @override
  String get loginTwoFactorRecoveryStep2 =>
      'Schritt 2: Bestaetige deinen 2FA-Code';

  @override
  String get loginTwoFactorRecoveryStep2Body =>
      'Gib den 6-stelligen Code in das Feld unten ein.';

  @override
  String get loginTwoFactorCodeSixDigitsLabel => '2FA-Code (6 Ziffern)';

  @override
  String get loginTwoFactorCodeHint => '000000';

  @override
  String get loginVerifyTwoFactorCode => '2FA-Code bestaetigen';

  @override
  String get loginCodeMustHaveExactly6Digits =>
      'Der Code muss genau 6 Ziffern haben.';

  @override
  String get loginPasswordUpdatedSuccess =>
      'Passwort aktualisiert. Du kannst dich jetzt anmelden.';

  @override
  String get loginUsernameLabel => 'Benutzername';

  @override
  String get loginEnterUsername => 'Benutzername eingeben';

  @override
  String get loginPasswordLabel => 'Passwort';

  @override
  String get loginEnterPassword => 'Passwort eingeben';

  @override
  String get loginSignIn => 'Anmelden';

  @override
  String get loginForgotPassword => 'Passwort vergessen?';

  @override
  String get loginGuestInfo =>
      'Greife kostenlos auf NutriFit zu, um Gesundheits- und Ernahrungstipps, Trainingsvideos, Rezepte, Gewichtskontrolle und vieles mehr zu sehen.';

  @override
  String get loginGuestAccess => 'Ohne Zugangsdaten zugreifen';

  @override
  String get loginRegisterFree => 'Kostenlos registrieren';

  @override
  String get registerCreateAccountTitle => 'Konto erstellen';

  @override
  String get registerFullNameLabel => 'Vollstaendiger Name';

  @override
  String get registerEnterFullName => 'Gib deinen Namen ein';

  @override
  String get registerUsernameMinLength =>
      'Der Benutzername muss mindestens 3 Zeichen lang sein';

  @override
  String get registerEmailLabel => 'E-Mail';

  @override
  String get registerInvalidEmail => 'Ungueltige E-Mail-Adresse';

  @override
  String get registerAdditionalDataTitle => 'Zusaetzliche Daten';

  @override
  String get registerAdditionalDataCollapsedSubtitle =>
      'Alter und Groesse (optional)';

  @override
  String get registerAdditionalDataExpandedSubtitle =>
      'Alter und Groesse fuer BMI/MVP';

  @override
  String get registerAdditionalDataInfo =>
      'Um die Berechnung von BMI, MVP und Gesundheitsmetriken zu aktivieren, gib Alter und Groesse (in Zentimetern) an.';

  @override
  String get registerAgeLabel => 'Alter';

  @override
  String get registerInvalidAge => 'Ungueltiges Alter';

  @override
  String get registerHeightLabel => 'Groesse (cm)';

  @override
  String get registerInvalidHeight => 'Ungueltige Groesse';

  @override
  String get registerConfirmPasswordLabel => 'Passwort bestaetigen';

  @override
  String get registerConfirmPasswordRequired => 'Bestaetige dein Passwort';

  @override
  String get registerCreateAccountButton => 'Konto erstellen';

  @override
  String get registerAlreadyHaveAccount =>
      'Hast du bereits ein Konto? Melde dich an';

  @override
  String get registerEmailUnavailable =>
      'Diese E-Mail-Adresse kann nicht verwendet werden. Bitte gib eine andere an.';

  @override
  String get registerSuccessMessage =>
      'Benutzer erfolgreich registriert. Bitte melde dich mit deinem Benutzernamen und Passwort an.';

  @override
  String get registerNetworkError =>
      'Der Vorgang konnte nicht abgeschlossen werden. Bitte pruefe die Internetverbindung.';

  @override
  String get registerGenericError => 'Fehler bei der Registrierung';

  @override
  String get loginResetPassword => 'Passwort zuruecksetzen';

  @override
  String get loginEmailRecoverySendFailedGeneric =>
      'Die Wiederherstellungs-E-Mail konnte im Moment nicht gesendet werden. Bitte spaeter erneut versuchen.';

  @override
  String get passwordChecklistTitle => 'Passwortanforderungen:';

  @override
  String passwordChecklistMinLength(Object count) {
    return 'Mindestens $count Zeichen';
  }

  @override
  String get passwordChecklistUpperLower =>
      'Mindestens ein Gross- und ein Kleinbuchstabe';

  @override
  String get passwordChecklistNumber => 'Mindestens eine Zahl (0-9)';

  @override
  String get passwordChecklistSpecial =>
      'Mindestens ein Sonderzeichen (*,.+-#\\\$?¿!¡_()/\\%&)';

  @override
  String loginPasswordMinLengthError(Object count) {
    return 'Das neue Passwort muss mindestens $count Zeichen lang sein.';
  }

  @override
  String get loginPasswordUppercaseError =>
      'Das neue Passwort muss mindestens einen Grossbuchstaben enthalten.';

  @override
  String get loginPasswordLowercaseError =>
      'Das neue Passwort muss mindestens einen Kleinbuchstaben enthalten.';

  @override
  String get loginPasswordNumberError =>
      'Das neue Passwort muss mindestens eine Zahl enthalten.';

  @override
  String get loginPasswordSpecialError =>
      'Das neue Passwort muss mindestens ein Sonderzeichen enthalten (* , . + - # \\\$ ? ¿ ! ¡ _ ( ) / \\ % &).';

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
  String get patientAdherenceNutriPlan => 'Ernaehrungsplan';

  @override
  String get patientAdherenceFitPlan => 'Fit-Plan';

  @override
  String get patientAdherenceCompleted => 'Erfuellt';

  @override
  String get patientAdherencePartial => 'Teilweise';

  @override
  String get patientAdherenceNotDone => 'Nicht erledigt';

  @override
  String get patientAdherenceNoChanges => 'Keine Aenderungen';

  @override
  String patientAdherenceTrendPoints(Object trend) {
    return '$trend pts';
  }

  @override
  String get patientAdherenceTitle => 'Einhaltung';

  @override
  String get patientAdherenceImprovementPoints => 'Verbesserungspunkte';

  @override
  String get patientAdherenceImprovementNutriTarget =>
      'Ernaehrung: Versuche diese Woche den Plan an mindestens 5 von 7 Tagen einzuhalten.';

  @override
  String get patientAdherenceImprovementNutriTrend =>
      'Ernaehrung: Im Vergleich zur letzten Woche geht der Trend nach unten; kehre zu deiner Grundroutine zurueck.';

  @override
  String get patientAdherenceImprovementFitTarget =>
      'Fit: Versuche 3-4 Einheiten pro Woche zu erreichen, auch wenn sie kurz sind.';

  @override
  String get patientAdherenceImprovementFitTrend =>
      'Fit: Der Trend ist gesunken; plane deine naechsten Einheiten noch heute.';

  @override
  String get patientAdherenceImprovementKeepGoing =>
      'Gutes Tempo. Bleib konsequent, um die Ergebnisse zu festigen.';

  @override
  String get patientAdherenceSheetTitleToday => 'Einhaltung fuer heute';

  @override
  String patientAdherenceSheetTitleForDate(Object date) {
    return 'Einhaltung fuer $date';
  }

  @override
  String get patientAdherenceDateToday => 'heute';

  @override
  String patientAdherenceStatusSaved(Object plan, Object status, Object date) {
    return '$plan: $status $date';
  }

  @override
  String get patientAdherenceFutureDateError =>
      'Die Einhaltung kann nicht fuer zukuenftige Daten erfasst werden. Nur fuer heute oder fruehere Tage.';

  @override
  String get patientAdherenceReasonNotDoneTitle =>
      'Grund fuer die Nichtdurchfuehrung';

  @override
  String get patientAdherenceReasonPartialTitle =>
      'Grund fuer die teilweise Erfuellung';

  @override
  String get patientAdherenceReasonHint =>
      'Erzaehle uns kurz, was heute passiert ist';

  @override
  String get patientAdherenceSkipReason => 'Grund ueberspringen';

  @override
  String get patientAdherenceSaveContinue => 'Speichern und fortfahren';

  @override
  String patientAdherenceSaveError(Object error) {
    return 'Konnte nicht in der Datenbank gespeichert werden: $error';
  }

  @override
  String get patientAdherenceReasonLabel => 'Grund';

  @override
  String get patientAdherenceInfoTitle =>
      'Was bedeutet jeder Einhaltungsstatus?';

  @override
  String get patientAdherenceNutriCompletedDescription =>
      'Du hast den Ernaehrungsplan fuer diesen Tag genau wie vorgesehen eingehalten.';

  @override
  String get patientAdherenceNutriPartialDescription =>
      'Du hast einen Teil des Plans eingehalten, aber nicht komplett: eine Mahlzeit wurde ausgelassen, geaendert oder in anderer Menge gegessen.';

  @override
  String get patientAdherenceNutriNotDoneDescription =>
      'Du hast den Ernaehrungsplan an diesem Tag nicht eingehalten.';

  @override
  String get patientAdherenceFitCompletedDescription =>
      'Du hast das fuer diesen Tag geplante Training vollstaendig absolviert.';

  @override
  String get patientAdherenceFitPartialDescription =>
      'Du hast einen Teil des Trainings geschafft: einige Uebungen, Saetze oder die Dauer waren unvollstaendig.';

  @override
  String get patientAdherenceFitNotDoneDescription =>
      'Du hast das Training an diesem Tag nicht absolviert.';

  @override
  String get patientAdherenceAlertRecoveryTitle => 'Jetzt reagieren';

  @override
  String patientAdherenceAlertRecoveryBody(Object plan) {
    return 'Du liegst in $plan seit zwei Wochen in Folge unter 50 %. Lass uns den Rhythmus jetzt wieder aufnehmen: kleine taegliche Schritte, aber ohne auszulassen. Du schaffst das, aber jetzt wird es ernst.';
  }

  @override
  String get patientAdherenceAlertEncouragementTitle => 'Es ist noch Zeit';

  @override
  String patientAdherenceAlertEncouragementBody(Object plan) {
    return 'Diese Woche liegt $plan unter 50 %. Die naechste kann deutlich besser werden: Kehre zu deiner Grundroutine zurueck und sammle jeden Tag einen kleinen Erfolg.';
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
  String get patientContactDietitianPrompt =>
      'Ernaehrungsberater kontaktieren...';

  @override
  String get patientContactDietitianTrainer =>
      'Ernaehrungsberater/Trainer kontaktieren';

  @override
  String get contactDietitianMethodsTitle => 'Kontaktmoeglichkeiten';

  @override
  String get contactDietitianEmailLabel => 'Email';

  @override
  String get contactDietitianCallLabel => 'Anrufen';

  @override
  String get contactDietitianSocialTitle =>
      'Folge uns in den sozialen Netzwerken';

  @override
  String get contactDietitianWebsiteLabel => 'Webseite';

  @override
  String get contactDietitianPhoneCopied =>
      'Telefonnummer in die Zwischenablage kopiert.';

  @override
  String get contactDietitianWhatsappInvalidPhone =>
      'Es gibt keine gueltige Telefonnummer, um WhatsApp zu oeffnen.';

  @override
  String contactDietitianWhatsappOpenError(Object error) {
    return 'WhatsApp konnte nicht geoeffnet werden: $error';
  }

  @override
  String get contactDietitianWhatsappDialogTitle => 'Per WhatsApp kontaktieren';

  @override
  String contactDietitianWhatsappDialogBody(Object phone) {
    return 'Du kannst den WhatsApp-Chat direkt mit der Nummer $phone oeffnen. Du kannst die Nummer auch in die Zwischenablage kopieren, um sie in WhatsApp zu verwenden oder zu speichern.';
  }

  @override
  String get contactDietitianCopyPhone => 'Telefon kopieren';

  @override
  String get contactDietitianOpenWhatsapp => 'WhatsApp oeffnen';

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
  String get chatMessageHint => 'Schreibe eine Nachricht';

  @override
  String get profileImagePickerDialogTitle => 'Profilbild auswaehlen';

  @override
  String get profileImagePickerTakePhoto => 'Foto aufnehmen';

  @override
  String get profileImagePickerChooseFromGallery => 'Aus Galerie waehlen';

  @override
  String get profileImagePickerSelectImage => 'Bild auswaehlen';

  @override
  String get profileImagePickerRemovePhoto => 'Foto entfernen';

  @override
  String get profileImagePickerPrompt => 'Waehle dein Profilbild aus';

  @override
  String profileImagePickerMaxDimensions(Object width, Object height) {
    return 'Max. ${width}x${height}px';
  }

  @override
  String profileImagePickerSaved(Object sizeKb) {
    return 'Bild erfolgreich gespeichert (${sizeKb}KB)';
  }

  @override
  String get profileImagePickerProcessError =>
      'Fehler bei der Bildverarbeitung';

  @override
  String get profileImagePickerTechnicalDetails => 'Technische Details';

  @override
  String get profileImagePickerOperationFailed =>
      'Der Vorgang konnte nicht abgeschlossen werden. Bitte versuche es erneut oder kontaktiere den Support.';

  @override
  String get shoppingListPremiumTitle => 'Premium-Einkaufsliste';

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
  String get weightControlBack => 'Zurueck';

  @override
  String get weightControlChangeTarget => 'Zielgewicht aendern';

  @override
  String get weightControlHideFilter => 'Filter ausblenden';

  @override
  String get weightControlShowFilter => 'Filter anzeigen';

  @override
  String get weightControlGuestMessage =>
      'Um deine Gewichtskontrolle zu verwalten, musst du dich registrieren. Es ist kostenlos.';

  @override
  String weightControlLoadError(Object error) {
    return 'Fehler beim Laden der Messungen: $error';
  }

  @override
  String get weightControlNoMeasurementsTitle =>
      'Es sind noch keine Messungen vorhanden.';

  @override
  String get weightControlNoMeasurementsBody =>
      'Beginne mit deiner ersten Messung, um deinen Fortschritt zu sehen.';

  @override
  String get weightControlAddMeasurement => 'Messung hinzufuegen';

  @override
  String weightControlNoWeightsForPeriod(Object period) {
    return 'Es gibt keine Gewichte fuer $period.';
  }

  @override
  String weightControlNoMeasurementsForPeriod(Object period) {
    return 'Es gibt keine Messungen fuer $period.';
  }

  @override
  String get weightControlPremiumPerimetersTitle =>
      'Premium-Umfangsentwicklung';

  @override
  String get weightControlPremiumChartBody =>
      'Dieses Diagramm ist nur fuer Premium-Nutzer verfuegbar. Aktiviere dein Konto, um deinen vollstaendigen Fortschritt mit erweiterten visuellen Indikatoren zu sehen.';

  @override
  String get weightControlCurrentMonth => 'Aktueller Monat';

  @override
  String get weightControlPreviousMonth => 'Vorheriger Monat';

  @override
  String get weightControlQuarter => 'Quartal';

  @override
  String get weightControlSemester => 'Halbjahr';

  @override
  String get weightControlCurrentYear => 'Aktuelles Jahr';

  @override
  String get weightControlPreviousYear => 'Vorheriges Jahr';

  @override
  String get weightControlAllTime => 'Gesamter Zeitraum';

  @override
  String weightControlLastDaysLabel(Object days) {
    return 'Letzte $days Tage';
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
  String get commonPremiumFeatureTitle => 'Premium-Funktion';

  @override
  String get commonSearch => 'Suchen';

  @override
  String get commonFilter => 'Filtern';

  @override
  String get commonRefresh => 'Aktualisieren';

  @override
  String get commonMoreOptions => 'Weitere Optionen';

  @override
  String get commonDelete => 'Loschen';

  @override
  String get commonClear => 'Leeren';

  @override
  String get commonApply => 'Anwenden';

  @override
  String get commonCopy => 'Kopieren';

  @override
  String get commonGeneratePdf => 'PDF erstellen';

  @override
  String get commonHideSearch => 'Suche ausblenden';

  @override
  String get commonFilterByCategories => 'Nach Kategorien filtern';

  @override
  String commonFilterByCategoriesCount(Object count) {
    return 'Kategorien filtern ($count)';
  }

  @override
  String get commonMatchAll => 'Alle mussen passen';

  @override
  String get commonRequireAllSelected =>
      'Wenn aktiviert, mussen alle ausgewahlten Elemente zutreffen.';

  @override
  String commonCategoryFallback(Object id) {
    return 'Kategorie $id';
  }

  @override
  String get commonSignInToLike => 'Du musst dich anmelden, um dies zu liken';

  @override
  String get commonSignInToSaveFavorites =>
      'Du musst dich anmelden, um Favoriten zu speichern';

  @override
  String get commonCouldNotIdentifyUser =>
      'Fehler: Der Benutzer konnte nicht identifiziert werden';

  @override
  String commonLikeChangeError(Object error) {
    return 'Fehler beim Andern des Like-Status. $error';
  }

  @override
  String commonFavoriteChangeError(Object error) {
    return 'Fehler beim Andern des Favoritenstatus. $error';
  }

  @override
  String commonGuestFavoritesRequiresRegistration(Object itemType) {
    return 'Um $itemType als Favorit zu markieren, musst du dich registrieren (das ist kostenlos).';
  }

  @override
  String get commonRecipesAndTipsPremiumCopyPdfMessage =>
      'Um Rezepte und Tipps zu kopieren und als PDF zu exportieren, musst du Premium-Nutzer sein.';

  @override
  String get commonCopiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String commonCopiedToClipboardLabel(Object label) {
    return '$label wurde in die Zwischenablage kopiert.';
  }

  @override
  String get commonLanguage => 'Sprache';

  @override
  String get commonUser => 'Benutzer';

  @override
  String get languageSpanish => 'Spanisch';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageItalian => 'Italienisch';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageFrench => 'Franzosisch';

  @override
  String get languagePortuguese => 'Portugiesisch';

  @override
  String commonCopyError(Object error) {
    return 'Fehler beim Kopieren: $error';
  }

  @override
  String commonGeneratePdfError(Object error) {
    return 'Fehler beim Erstellen des PDF: $error';
  }

  @override
  String commonOpenLinkError(Object error) {
    return 'Fehler beim Offnen des Links: $error';
  }

  @override
  String get commonDocumentUnavailable => 'Das Dokument ist nicht verfugbar';

  @override
  String commonDecodeError(Object error) {
    return 'Fehler beim Dekodieren: $error';
  }

  @override
  String get commonSaveDocumentError =>
      'Fehler: Das Dokument konnte nicht gespeichert werden';

  @override
  String commonOpenDocumentError(Object error) {
    return 'Fehler beim Offnen des Dokuments: $error';
  }

  @override
  String get commonDownloadDocument => 'Dokument herunterladen';

  @override
  String get commonDocumentsAndLinks => 'Dokumente und Links';

  @override
  String get commonYouMayAlsoLike => 'Das konnte dich auch interessieren...';

  @override
  String get commonSortByTitle => 'Nach Titel sortieren';

  @override
  String get commonSortByRecent => 'Nach Neuheit sortieren';

  @override
  String get commonSortByPopular => 'Nach Beliebtheit sortieren';

  @override
  String get commonPersonalTab => 'Personlich';

  @override
  String get commonFeaturedTab => 'Empfohlen';

  @override
  String get commonAllTab => 'Alle';

  @override
  String get commonFavoritesTab => 'Favoriten';

  @override
  String get commonFeaturedFeminineTab => 'Empfohlen';

  @override
  String get commonAllFeminineTab => 'Alle';

  @override
  String get commonFavoritesFeminineTab => 'Favoriten';

  @override
  String commonLikesCount(Object count) {
    return '$count Likes';
  }

  @override
  String get commonLink => 'Link';

  @override
  String get commonTipItem => 'Tipp';

  @override
  String get commonRecipeItem => 'Rezept';

  @override
  String get commonAdditiveItem => 'Zusatzstoff';

  @override
  String get commonSupplementItem => 'Nahrungserganzungsmittel';

  @override
  String commonSeeLinkToType(Object type) {
    return 'Siehe Link zu $type';
  }

  @override
  String get commonDocument => 'Dokument';

  @override
  String get todoPriorityHigh => 'Hoch';

  @override
  String get todoPriorityMedium => 'Mittel';

  @override
  String get todoPriorityLow => 'Niedrig';

  @override
  String get todoStatusPending => 'Ausstehend';

  @override
  String get todoStatusResolved => 'Erledigt';

  @override
  String todoCalendarPriority(Object value) {
    return 'Prioritat: $value';
  }

  @override
  String todoCalendarStatus(Object value) {
    return 'Status: $value';
  }

  @override
  String todoExportError(Object error) {
    return 'Fehler beim Exportieren der Aufgabe: $error';
  }

  @override
  String get todoDateRequiredForCalendar =>
      'Die Aufgabe muss ein Datum haben, um zum Kalender hinzugefugt zu werden';

  @override
  String todoAddToCalendarError(Object error) {
    return 'Die Aufgabe konnte nicht zum Kalender hinzugefugt werden: $error';
  }

  @override
  String todoPremiumLimitMessage(int limit) {
    return 'Als Nicht-Premium-Nutzer kannst du bis zu $limit Aufgaben erstellen. Werde Premium, um unbegrenzt Aufgaben hinzuzufugen und den gesamten Verlauf einzusehen.';
  }

  @override
  String get todoNoDate => 'Ohne Datum';

  @override
  String get todoPriorityHighTooltip => 'Hohe Prioritat';

  @override
  String get todoPriorityMediumTooltip => 'Mittlere Prioritat';

  @override
  String get todoPriorityLowTooltip => 'Niedrige Prioritat';

  @override
  String get todoStatusResolvedShort => 'Erledigt (E)';

  @override
  String get todoStatusPendingShort => 'Ausstehend (A)';

  @override
  String get todoMarkPending => 'Als ausstehend markieren';

  @override
  String get todoMarkResolved => 'Als erledigt markieren';

  @override
  String get todoEditTaskTitle => 'Aufgabe bearbeiten';

  @override
  String get todoNewTaskTitle => 'Neue Aufgabe';

  @override
  String get todoTitleLabel => 'Titel';

  @override
  String get todoTitleRequired => 'Der Titel ist erforderlich';

  @override
  String get todoDescriptionTitle => 'Beschreibung';

  @override
  String get todoDescriptionOptionalLabel => 'Beschreibung (optional)';

  @override
  String get todoPriorityTitle => 'Prioritat';

  @override
  String get todoStatusTitle => 'Status';

  @override
  String todoTasksForDay(Object date) {
    return 'Aufgaben fur den $date';
  }

  @override
  String get todoNewShort => 'Neu';

  @override
  String get todoNoTasksSelectedDay =>
      'Es gibt keine Aufgaben fur den ausgewahlten Tag.';

  @override
  String get todoNoTasksToShow => 'Keine Aufgaben zum Anzeigen';

  @override
  String get todoPremiumTitle => 'Premium-Aufgaben';

  @override
  String todoPremiumPreviewSubtitle(int limit) {
    return 'Du kannst die letzten $limit Eintraege ansehen und bis zu $limit Aufgaben erstellen. Wenn du unbegrenzte Aufgaben moechtest, werde Premium.';
  }

  @override
  String todoPremiumPreviewHighlight(int count) {
    return 'Aktuell hast du $count Aufgaben gespeichert.';
  }

  @override
  String get todoEmptyState => 'Du hast noch keine Aufgaben erstellt.';

  @override
  String get todoScreenTitle => 'Aufgaben';

  @override
  String get todoTabPending => 'Ausstehend';

  @override
  String get todoTabResolved => 'Erledigt';

  @override
  String get todoTabAll => 'Alle';

  @override
  String get todoHideFilters => 'Filter ausblenden';

  @override
  String get todoViewList => 'Liste ansehen';

  @override
  String get todoViewCalendar => 'Kalender ansehen';

  @override
  String get todoSortByDate => 'Nach Datum sortieren';

  @override
  String get todoSortByPriority => 'Nach Prioritaet sortieren';

  @override
  String get todoSearchHint => 'Aufgaben suchen';

  @override
  String get todoClearSearch => 'Suche loeschen';

  @override
  String get todoDeleteTitle => 'Aufgabe loeschen';

  @override
  String todoDeleteConfirm(Object title) {
    return 'Moechtest du die Aufgabe \"$title\" loeschen?';
  }

  @override
  String get todoDeletedSuccess => 'Aufgabe geloescht';

  @override
  String get todoAddToDeviceCalendar => 'Zum Geraetekalender hinzufuegen';

  @override
  String get todoEditAction => 'Bearbeiten';

  @override
  String get todoSelectDate => 'Datum auswaehlen';

  @override
  String get todoRemoveDate => 'Datum entfernen';

  @override
  String get todoGuestTitle => 'Aufgaben fuer registrierte Nutzer';

  @override
  String get todoGuestBody =>
      'Melde dich an oder werde Premium, um Aufgaben zu erstellen, zu organisieren und auf allen deinen Geraeten zu synchronisieren.';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonSortByName => 'Nach Name sortieren';

  @override
  String get commonSortByType => 'Nach Typ sortieren';

  @override
  String get commonSortByDate => 'Nach Datum sortieren';

  @override
  String get commonSortBySeverity => 'Nach Schweregrad sortieren';

  @override
  String get commonName => 'Name';

  @override
  String get commonTitleField => 'Titel';

  @override
  String get commonDescriptionField => 'Beschreibung';

  @override
  String get commonTypeField => 'Typ';

  @override
  String get commonSeverity => 'Schweregrad';

  @override
  String commonNoResultsForQuery(Object query) {
    return 'Keine Ergebnisse fur \"$query\"';
  }

  @override
  String get tipsPremiumToolsMessage =>
      'Suche, Filter, Favoriten, Likes und voller Zugriff auf den Tipp-Katalog sind nur fur Premium-Nutzer verfugbar.';

  @override
  String get tipsPremiumPreviewTitle => 'Premium-Tipps';

  @override
  String get tipsPremiumPreviewSubtitle =>
      'Du kannst eine Vorschau der letzten 3 Tipps sehen. Werde Premium, um auf den vollstandigen Katalog und alle Funktionen zuzugreifen.';

  @override
  String tipsPreviewAvailableCount(Object count) {
    return ' Derzeit sind $count Tipps verfugbar.';
  }

  @override
  String get tipsSearchLabel => 'Tipps suchen';

  @override
  String get tipsNoPersonalizedRecommendations =>
      'Keine personalisierten Empfehlungen';

  @override
  String get tipsViewGeneralTips => 'Allgemeine Tipps anzeigen';

  @override
  String get tipsUnreadBadge => 'Ungelesen';

  @override
  String get messagesInboxTitle => 'Ungelesene Nachrichten';

  @override
  String get messagesInboxGuestBody =>
      'Um online mit deinem Ernaehrungsberater zu chatten, registriere dich bitte zuerst (es ist kostenlos).';

  @override
  String get messagesInboxGuestAction => 'Registrierung starten';

  @override
  String get messagesInboxUnreadChats => 'Ungelesene Chats';

  @override
  String get messagesInboxNoPendingChats => 'Es gibt keine offenen Chats.';

  @override
  String get messagesInboxUser => 'Benutzer';

  @override
  String get messagesInboxImage => 'Bild';

  @override
  String get messagesInboxNoMessages => 'Keine Nachrichten';

  @override
  String get messagesInboxPendingExerciseFeelings =>
      'Ausstehende Trainingsrueckmeldungen';

  @override
  String get messagesInboxNoPendingExerciseFeelings =>
      'Es gibt keine ausstehenden Trainingsrueckmeldungen.';

  @override
  String get messagesInboxViewPendingExerciseFeelings =>
      'Ausstehende Trainingsrueckmeldungen anzeigen';

  @override
  String get messagesInboxUnreadDietitianChats =>
      'Ungelesene Chats mit dem Ernaehrungsberater';

  @override
  String get messagesInboxOpenDietitianChat =>
      'Chat mit dem Ernaehrungsberater oeffnen';

  @override
  String get messagesInboxMessage => 'Nachricht';

  @override
  String get messagesInboxDietitianMessage =>
      'Nachricht vom Ernaehrungsberater';

  @override
  String get messagesInboxUnreadCoachComments => 'Ungelesene Trainerkommentare';

  @override
  String get messagesInboxNoUnreadCoachComments =>
      'Du hast keine ungelesenen Kommentare deines Personal Trainers.';

  @override
  String get messagesInboxViewPendingComments =>
      'Ausstehende Kommentare anzeigen';

  @override
  String messagesInboxLoadError(Object error) {
    return 'Fehler beim Laden der Nachrichten: $error';
  }

  @override
  String get tipsNoFeaturedAvailable => 'Keine empfohlenen Tipps';

  @override
  String get tipsNoTipsAvailable => 'Keine Tipps verfugbar';

  @override
  String get tipsNoFavoriteTips => 'Du hast keine Lieblings-Tipps';

  @override
  String get tipsDetailTitle => 'Tipp-Details';

  @override
  String get tipsPreviewBanner => 'Vorschau - So sehen Nutzer den Tipp';

  @override
  String tipsHashtagTitle(Object hashtag) {
    return 'Tipps mit $hashtag';
  }

  @override
  String tipsHashtagEmpty(Object hashtag) {
    return 'Es gibt keine Tipps mit $hashtag';
  }

  @override
  String tipsLoadErrorStatus(Object statusCode) {
    return 'Fehler beim Laden der Tipps: $statusCode';
  }

  @override
  String tipsLoadError(Object error) {
    return 'Fehler beim Laden der Tipps. $error';
  }

  @override
  String get recipesPremiumToolsMessage =>
      'Suche, Filter, Favoriten, Likes und voller Zugriff auf den Rezeptkatalog sind nur fur Premium-Nutzer verfugbar.';

  @override
  String get recipesPremiumPreviewTitle => 'Premium-Rezepte';

  @override
  String get recipesPremiumPreviewSubtitle =>
      'Du kannst eine Vorschau der letzten 3 Rezepte sehen. Werde Premium, um auf den vollstandigen Katalog und alle Funktionen zuzugreifen.';

  @override
  String recipesPreviewAvailableCount(Object count) {
    return ' Derzeit sind $count Rezepte verfugbar.';
  }

  @override
  String get recipesSearchLabel => 'Rezepte suchen';

  @override
  String get recipesNoFeaturedAvailable => 'Keine empfohlenen Rezepte';

  @override
  String get recipesNoRecipesAvailable => 'Keine Rezepte verfugbar';

  @override
  String get recipesNoFavoriteRecipes => 'Du hast keine Lieblingsrezepte';

  @override
  String get recipesDetailTitle => 'Rezeptdetails';

  @override
  String get recipesPreviewBanner => 'Vorschau - So sehen Nutzer das Rezept';

  @override
  String recipesHashtagTitle(Object hashtag) {
    return 'Rezepte mit $hashtag';
  }

  @override
  String recipesHashtagEmpty(Object hashtag) {
    return 'Es gibt keine Rezepte mit $hashtag';
  }

  @override
  String get additivesPremiumCopyPdfMessage =>
      'Um einen Zusatzstoff zu kopieren und als PDF zu exportieren, musst du Premium-Nutzer sein.';

  @override
  String get additivesPremiumExploreMessage =>
      'Hashtags und Zusatzstoff-Empfehlungen sind nur fuer Premium-Nutzer verfuegbar.';

  @override
  String get additivesPremiumToolsMessage =>
      'Suche, Filter, Aktualisierung und vollstaendige Sortierung des Zusatzstoff-Katalogs sind nur fuer Premium-Nutzer verfuegbar.';

  @override
  String get additivesFilterTitle => 'Zusatzstoffe filtern';

  @override
  String get additivesNoConfiguredTypes =>
      'In tipos_aditivos sind keine Typen konfiguriert.';

  @override
  String get additivesTypesLabel => 'Typen';

  @override
  String get additivesSearchHint => 'Zusatzstoffe suchen';

  @override
  String get additivesEmpty => 'Keine Zusatzstoffe verfuegbar';

  @override
  String get additivesPremiumTitle => 'Premium-Zusatzstoffe';

  @override
  String get additivesPremiumSubtitle =>
      'Der vollstaendige Zusatzstoff-Katalog ist nur fuer Premium-Nutzer verfuegbar.';

  @override
  String additivesCatalogHighlight(Object count) {
    return ' (mit mehr als $count Zusatzstoffen)';
  }

  @override
  String get additivesLoadFailed =>
      'Zusatzstoffe konnten nicht geladen werden.';

  @override
  String get additivesCatalogUnavailable =>
      'Der Zusatzstoff-Katalog ist voruebergehend nicht verfuegbar. Bitte versuche es spaeter erneut.';

  @override
  String get additivesServerConnectionError =>
      'Verbindung zum Server fehlgeschlagen. Pruefe deine Verbindung und versuche es erneut.';

  @override
  String get additivesSeveritySafe => 'Sicher';

  @override
  String get additivesSeverityAttention => 'Achtung';

  @override
  String get additivesSeverityHigh => 'Hoch';

  @override
  String get additivesSeverityRestricted => 'Eingeschraenkt';

  @override
  String get additivesSeverityForbidden => 'Verboten';

  @override
  String get substitutionsPremiumToolsMessage =>
      'Suche, Filter, Favoriten und vollstaendige Sortierung gesunder Alternativen sind nur fuer Premium-Nutzer verfuegbar.';

  @override
  String get substitutionsPremiumCopyPdfMessage =>
      'Um eine gesunde Alternative zu kopieren und als PDF zu exportieren, musst du Premium-Nutzer sein.';

  @override
  String get substitutionsPremiumExploreMessage =>
      'Hashtags, Kategorien, Empfehlungen und erweiterte Navigation fuer gesunde Alternativen sind nur fuer Premium-Nutzer verfuegbar.';

  @override
  String get substitutionsPremiumEngagementMessage =>
      'Favoriten und Likes fuer gesunde Alternativen sind nur fuer Premium-Nutzer verfuegbar.';

  @override
  String get substitutionsSearchLabel => 'Alternativen oder Hashtags suchen';

  @override
  String get substitutionsEmptyFeatured =>
      'Keine hervorgehobenen Alternativen.';

  @override
  String get substitutionsEmptyAll => 'Keine Alternativen verfuegbar.';

  @override
  String get substitutionsEmptyFavorites =>
      'Du hast noch keine Lieblings-Alternativen.';

  @override
  String get substitutionsPremiumTitle => 'Premium-Alternativen';

  @override
  String get substitutionsPremiumSubtitle =>
      'Die vollstaendige Bibliothek gesunder Alternativen ist nur fuer Premium-Nutzer verfuegbar.';

  @override
  String substitutionsCatalogHighlight(Object count) {
    return ' (mit mehr als $count Alternativen)';
  }

  @override
  String get substitutionsDefaultBadge => 'Premium-Alternative';

  @override
  String get substitutionsTapForDetail =>
      'Tippe, um das komplette Detail zu sehen';

  @override
  String get substitutionsDetailTitle => 'Gesunde Alternative';

  @override
  String get substitutionsRecommendedChange => 'Empfohlene Aenderung';

  @override
  String get substitutionsIfUnavailable => 'Wenn du nicht hast';

  @override
  String get substitutionsUse => 'Verwende';

  @override
  String get substitutionsEquivalence => 'Entsprechende Menge';

  @override
  String get substitutionsGoal => 'Ziel';

  @override
  String get substitutionsNotesContext => 'Sustitución saludable';

  @override
  String get commonExport => 'Exportieren';

  @override
  String get commonImport => 'Importieren';

  @override
  String get commonPhoto => 'Foto';

  @override
  String get commonGallery => 'Galerie';

  @override
  String get commonUnavailable => 'Nicht verfuegbar';

  @override
  String get scannerTitle => 'Etiketten-Scanner';

  @override
  String get scannerPremiumRequiredMessage =>
      'Scannen, Oeffnen von Bildern aus der Galerie und Produktsuche aus dem Scanner sind nur fuer Premium-Nutzer verfuegbar.';

  @override
  String get scannerClearTrainingTitle => 'OCR-Training loeschen';

  @override
  String get scannerClearTrainingBody =>
      'Alle auf diesem Geraet gespeicherten Korrekturen werden geloescht. Moechtest du fortfahren?';

  @override
  String get scannerLocalTrainingRemoved => 'Lokales OCR-Training entfernt';

  @override
  String get scannerExportRulesTitle => 'OCR-Regeln exportieren';

  @override
  String get scannerImportRulesTitle => 'OCR-Regeln importieren';

  @override
  String get scannerImportRulesHint => 'Fuege hier das exportierte JSON ein';

  @override
  String get scannerInvalidFormat => 'Ungueltiges Format';

  @override
  String get scannerInvalidJsonOrCanceled =>
      'Ungueltiges JSON oder Import abgebrochen';

  @override
  String scannerImportedRulesCount(Object count) {
    return '$count Trainingsregeln importiert';
  }

  @override
  String get scannerRulesUploaded => 'OCR-Regeln auf den Server hochgeladen';

  @override
  String scannerRulesUploadError(Object error) {
    return 'Fehler beim Hochladen der Regeln: $error';
  }

  @override
  String get scannerNoRemoteRules => 'Keine entfernten Regeln verfuegbar.';

  @override
  String scannerDownloadedRulesCount(Object count) {
    return '$count Regeln vom Server heruntergeladen';
  }

  @override
  String scannerRulesDownloadError(Object error) {
    return 'Fehler beim Herunterladen der Regeln: $error';
  }

  @override
  String get scannerTrainingMarkedCorrect =>
      'Training gespeichert: Erkennung als korrekt markiert';

  @override
  String get scannerCorrectOcrValuesTitle => 'OCR-Werte korrigieren';

  @override
  String get scannerSugarField => 'Sugar (g)';

  @override
  String get scannerSaltField => 'Salt (g)';

  @override
  String get scannerFatField => 'Fat (g)';

  @override
  String get scannerProteinField => 'Protein (g)';

  @override
  String get scannerPortionField => 'Portion (g)';

  @override
  String get scannerSaveCorrection => 'Korrektur speichern';

  @override
  String get scannerCorrectionSaved =>
      'Korrektur gespeichert. Sie wird auf aehnliche Etiketten angewendet.';

  @override
  String get scannerSourceBarcode => 'Barcode';

  @override
  String get scannerSourceOcrOpenFood => 'OCR-Name + Open Food Facts';

  @override
  String get scannerSourceOcrTable => 'OCR-Naehrwerttabelle';

  @override
  String get scannerSourceAutoBarcodeOpenFood =>
      'Automatische Erkennung (Barcode + Open Food Facts)';

  @override
  String get scannerSourceAutoOcrOpenFood =>
      'Automatische Erkennung (OCR + Open Food Facts)';

  @override
  String get scannerSourceAutoOcrTable =>
      'Automatische Erkennung (OCR-Naehrwerttabelle)';

  @override
  String get scannerNoNutritionData =>
      'Naehrwertdaten konnten nicht ermittelt werden. Fotografiere mit guter Beleuchtung, scharfem Text und so, dass die Naehrwerttabelle vollstaendig im Bild ist.';

  @override
  String scannerReadCompleted(Object source) {
    return 'Lesung abgeschlossen: $source';
  }

  @override
  String scannerAnalyzeError(Object error) {
    return 'Etikett konnte nicht analysiert werden: $error';
  }

  @override
  String get scannerHeaderTitle => 'Lebensmitteletiketten-Scanner';

  @override
  String get scannerHeaderTooltip => 'Vollstaendige Prozessinformationen';

  @override
  String get scannerHeaderBody =>
      'Mache ein Foto vom Barcode eines Produkts oder waehle ein Bild aus der Galerie. Wenn dieser Modus aktiviert ist, erkennt NutriFit automatisch den Barcode, den Produktnamen oder die Naehrwerttabelle.';

  @override
  String get scannerPremiumBanner =>
      'Premium-Funktion: Du kannst den Bildschirm oeffnen und Informationen sehen, aber Suche, Foto und Galerie sind fuer Nicht-Premium-Nutzer gesperrt.';

  @override
  String get scannerTrainingModeTitle => 'OCR-Trainingsmodus';

  @override
  String get scannerTrainingModeSubtitle =>
      'Ermoeglicht das Korrigieren von Erkennungen, um die Erkennung zu verbessern.';

  @override
  String get scannerModeLabel => 'Modus';

  @override
  String get scannerModeAuto => 'Automatischer Modus';

  @override
  String get scannerModeBarcode => 'Barcode-Modus';

  @override
  String get scannerModeOcrTable => 'Naehrwerttabellen-Modus';

  @override
  String get scannerActionSearchOpenFood => 'In Open Food Facts suchen';

  @override
  String get scannerAutoHint =>
      'Im automatischen Modus versucht die App zuerst den Barcode zu erkennen und, falls kein gueltiges Produkt gefunden wird, OCR auf Namen oder Naehrwerttabelle.';

  @override
  String get scannerBarcodeHint =>
      'Im Barcode-Modus zeigt die Kamera einen Rahmen an und die App analysiert nur diesen Bereich fuer bessere Genauigkeit.';

  @override
  String get scannerOcrHint =>
      'Im Naehrwerttabellen-Modus priorisiert die App das OCR-Lesen des Produktnamens und der Naehrwerttabelle, ohne sich auf den Barcode zu stuetzen.';

  @override
  String get scannerDismissHintTooltip =>
      'Schliessen (halte die Modus-Taste gedrueckt, um es erneut anzuzeigen)';

  @override
  String get scannerAnalyzing => 'Etikett wird analysiert...';

  @override
  String get scannerResultPerServing => 'Ergebnis pro Portion';

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
  String get scannerContactDietitianButton => 'Ernaehrungsberater kontaktieren';

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
  String get commonEmail => 'E-Mail';

  @override
  String get restrictedAccessGenericMessage =>
      'Um auf deine Ernährungspläne, Trainingspläne und personalisierten Empfehlungen zuzugreifen, musst du zuerst deinen Online-Diätassistenten/Trainer kontaktieren, der dir einen auf deine Bedürfnisse zugeschnittenen Plan zuweist.';

  @override
  String get restrictedAccessContactMethods => 'Kontaktmöglichkeiten:';

  @override
  String get restrictedAccessMoreContactOptions =>
      'Weitere Kontaktmöglichkeiten';

  @override
  String get videosPremiumToolsMessage =>
      'Suche, Filter, Favoriten, Likes und vollständige Sortierung der Trainingsvideos sind nur für Premium-Nutzer verfügbar.';

  @override
  String get videosPremiumPlaybackMessage =>
      'Die vollständige Wiedergabe der Trainingsvideos ist nur für Premium-Nutzer verfügbar.';

  @override
  String get videosPremiumTitle => 'Premium-Videos';

  @override
  String get videosPremiumSubtitle =>
      'Der vollständige Katalog der Trainingsvideos ist nur für Premium-Nutzer verfügbar. Zugriff auf ';

  @override
  String videosPremiumPreviewHighlight(Object count) {
    return '$count exklusive Videos.';
  }

  @override
  String get charlasPremiumToolsMessage =>
      'Suche, Filter, Favoriten, Likes und vollständige Sortierung von Vorträgen und Seminaren sind nur für Premium-Nutzer verfügbar.';

  @override
  String get charlasPremiumContentMessage =>
      'Der vollständige Zugriff auf den Inhalt des Vortrags oder Seminars ist nur für Premium-Nutzer verfügbar.';

  @override
  String get charlasPremiumTitle => 'Premium-Vorträge';

  @override
  String get charlasPremiumSubtitle =>
      'Der vollständige Katalog von Vorträgen und Seminaren ist nur für Premium-Nutzer verfügbar. Zugriff auf ';

  @override
  String charlasPremiumPreviewHighlight(Object count) {
    return '$count exklusive Vorträge.';
  }

  @override
  String get supplementsPremiumCopyPdfMessage =>
      'Um ein Nahrungsergänzungsmittel zu kopieren und als PDF zu exportieren, musst du Premium-Nutzer sein.';

  @override
  String get supplementsPremiumExploreMessage =>
      'Hashtags und Empfehlungen zu Nahrungsergänzungsmitteln sind nur für Premium-Nutzer verfügbar.';

  @override
  String get supplementsPremiumToolsMessage =>
      'Suche, Aktualisierung und vollständige Sortierung des Nahrungsergänzungsmittel-Katalogs sind nur für Premium-Nutzer verfügbar.';

  @override
  String get supplementsPremiumTitle => 'Premium-Nahrungsergänzungsmittel';

  @override
  String get supplementsPremiumSubtitle =>
      'Der vollständige Nahrungsergänzungsmittel-Katalog ist nur für Premium-Nutzer verfügbar.';

  @override
  String supplementsPremiumPreviewHighlight(Object count) {
    return '(mit mehr als $count Nahrungsergänzungsmitteln)';
  }

  @override
  String get exerciseCatalogPremiumToolsMessage =>
      'Suche, Filter, Aktualisierung und vollständige Sortierung des Übungskatalogs sind nur für Premium-Nutzer verfügbar.';

  @override
  String get exerciseCatalogPremiumVideoMessage =>
      'Das vollständige Video der Übung ist nur für Premium-Nutzer verfügbar.';

  @override
  String get exerciseCatalogPremiumTitle => 'Premium-Übungen';

  @override
  String get exerciseCatalogPremiumSubtitle =>
      'Der vollständige Übungskatalog ist nur für Premium-Nutzer verfügbar.';

  @override
  String exerciseCatalogPremiumPreviewHighlight(Object count) {
    return '(mit mehr als $count Übungen)';
  }
}
