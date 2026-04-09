// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get settingsAndPrivacyTitle => 'Parametres et confidentialite';

  @override
  String get settingsAndPrivacyMenuLabel => 'Parametres et confidentialite';

  @override
  String get configTabParameters => 'Parametres';

  @override
  String get configTabPremium => 'Premium';

  @override
  String get configTabAppMenu => 'Menu app';

  @override
  String get configTabGeneral => 'General';

  @override
  String get configTabSecurity => 'Securite';

  @override
  String get configTabUser => 'Utilisateur';

  @override
  String get configTabDisplay => 'Affichage';

  @override
  String get configTabDefaults => 'Defaut';

  @override
  String get configTabPrivacy => 'Confidentialite';

  @override
  String get securitySubtabAccess => 'Acces';

  @override
  String get securitySubtabEmailServer => 'Serveur email';

  @override
  String get securitySubtabCipher => 'Chiffrer/Dechiffrer';

  @override
  String get securitySubtabSessions => 'Sessions';

  @override
  String get securitySubtabAccesses => 'Acces';

  @override
  String get privacyCenterTab => 'Centre';

  @override
  String get privacyPolicyTab => 'Politique';

  @override
  String get privacySessionsTab => 'Sessions';

  @override
  String privacyLastUpdatedLabel(Object date) {
    return 'Derniere mise a jour : $date';
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
      'Aucune donnee de session n\'est disponible pour les utilisateurs non inscrits, car l\'acces est anonyme.';

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
    return 'L\'application a ete mise a jour vers la version $version.';
  }

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonAgree => 'OK';

  @override
  String get commonLater => 'Later';

  @override
  String get commonValidate => 'Valider';

  @override
  String get commonToday => 'aujourd\'hui';

  @override
  String get commonDebug => 'DEBUG';

  @override
  String get commonAllRightsReserved => 'Tous droits reserves';

  @override
  String get navHome => 'Accueil';

  @override
  String get navLogout => 'Se deconnecter';

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
  String get navChatWithDietitian => 'Chat avec le dieteticien';

  @override
  String get navContactDietitian => 'Contacter le dieteticien';

  @override
  String get navEditProfile => 'Modifier le profil';

  @override
  String get profileEditProfileTab => 'Profil';

  @override
  String get profileEditSessionsTab => 'Connexions';

  @override
  String get profileEditPremiumBadgeTitle => 'Compte Premium';

  @override
  String get profileEditPremiumBadgeBody =>
      'Vous avez acces a des fonctionnalites exclusives comme les videos d\'exercices.';

  @override
  String get profileEditNickLabel => 'Pseudo / Utilisateur';

  @override
  String get profileEditNickRequired => 'Le pseudo est obligatoire';

  @override
  String get profileEditEmailLabel => 'Email';

  @override
  String get profileEditInvalidEmail => 'Email invalide';

  @override
  String get profileEditEmailInUse =>
      'L\'email saisi n\'est pas valide, utilisez-en un autre.';

  @override
  String get profileEditChangeEmailTooltip => 'Changer de compte email';

  @override
  String get profileEditVerifyEmailCta => 'Verifier l\'email';

  @override
  String get profileEditTwoFactorShortLabel => 'Double facteur';

  @override
  String get profileEditBmiCardTitle => 'Donnees IMC';

  @override
  String get profileEditBmiInfoTooltip => 'Informations IMC/MVP';

  @override
  String get profileEditBmiCardBody =>
      'Pour obtenir l\'IMC, le MVP et des recommandations, renseignez l\'age et la taille.';

  @override
  String get profileEditAgeLabel => 'Age';

  @override
  String get profileEditInvalidAge => 'Age invalide';

  @override
  String get profileEditHeightLabel => 'Taille (cm)';

  @override
  String get profileEditInvalidHeight => 'Taille invalide';

  @override
  String get profileEditPasswordCardTitle => 'Changer le mot de passe';

  @override
  String get profileEditPasswordHint =>
      'Laissez vide pour conserver le mot de passe actuel';

  @override
  String get profileEditPasswordLabel => 'Mot de passe';

  @override
  String get profileEditPasswordConfirmLabel => 'Confirmer le mot de passe';

  @override
  String get profileEditPasswordConfirmRequired =>
      'Vous devez confirmer le mot de passe';

  @override
  String get profileEditPasswordMismatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get profileEditSaveChanges => 'Enregistrer les modifications';

  @override
  String get profileEditDeleteMyData => 'Supprimer toutes mes donnees';

  @override
  String get profileEditChangeEmailTitle => 'Changer l\'email';

  @override
  String get profileEditChangeEmailVerifiedWarning =>
      'L\'email actuel est verifie. Si vous le changez, vous devrez le verifier a nouveau.';

  @override
  String get profileEditChangeEmailNewLabel => 'Nouvel email';

  @override
  String get profileEditChangeEmailRequired => 'Vous devez indiquer un email.';

  @override
  String get profileEditChangeEmailMustDiffer =>
      'Vous devez indiquer un email different de l\'actuel.';

  @override
  String get profileEditChangeEmailValidationFailed =>
      'Impossible de valider l\'email. Reessayez.';

  @override
  String get profileEditChangeEmailReview => 'Verifiez l\'email indique.';

  @override
  String get profileEditEmailRequiredForVerification =>
      'Vous devez d\'abord saisir une adresse e-mail.';

  @override
  String get profileEditEmailCodeSentGeneric => 'Code envoye.';

  @override
  String get profileEditEmailVerifiedGeneric => 'E-mail verifie.';

  @override
  String get profileEditEmailCodeLengthError =>
      'Le code doit contenir 10 chiffres.';

  @override
  String get profileEditEmailCodeDialogTitle => 'Valider le code e-mail';

  @override
  String get profileEditEmailCodeTenDigitsLabel => 'Code a 10 chiffres';

  @override
  String get profileEditValidateEmailCodeAction => 'Valider le code e-mail';

  @override
  String get profileEditVerifyEmailTitle => 'Verifier l\'e-mail';

  @override
  String get profileEditVerifyEmailIntroPrefix =>
      'Nous devons verifier que cette adresse e-mail vous appartient :';

  @override
  String get profileEditVerifyEmailPremiumLink =>
      'Voir les avantages Premium avec un e-mail verifie';

  @override
  String get profileEditFollowTheseSteps => 'Suivez ces etapes...';

  @override
  String get profileEditYourEmail => 'Votre e-mail';

  @override
  String profileEditSendCodeInstruction(Object email) {
    return 'Appuyez sur \"Envoyer le code\" pour envoyer le code de verification a $email.';
  }

  @override
  String get profileEditEmailCodeSentInfo =>
      'Un code a ete envoye a votre adresse e-mail. Il expirera dans 15 minutes. Si vous ne le voyez pas dans la boite de reception, verifiez le dossier Spam.';

  @override
  String get profileEditEmailSendFailed =>
      'L\'e-mail de verification n\'a pas pu etre envoye pour le moment. Veuillez reessayer plus tard.';

  @override
  String get profileEditSendCodeAction => 'Envoyer le code';

  @override
  String get profileEditResendCodeAction => 'Renvoyer';

  @override
  String get profileEditVerifyCodeInstruction =>
      'Saisissez le code de verification que nous vous avons envoye.';

  @override
  String get profileEditVerificationCodeLabel => 'Code de verification';

  @override
  String get profileEditEmailRequiredInProfile =>
      'Vous devez d\'abord saisir une adresse e-mail dans Modifier le profil pour pouvoir la verifier.';

  @override
  String get profileEditTwoFactorDialogTitle =>
      'Authentification a deux facteurs (2FA)';

  @override
  String get profileEditTwoFactorEnabledStatus => 'Statut : Activee';

  @override
  String get profileEditTwoFactorEnabledBody =>
      'L\'authentification a deux facteurs est deja activee sur votre compte. Depuis ici, vous pouvez seulement verifier si cet appareil est fiable et le lier ou le dissocier.';

  @override
  String get profileEditTrustedDeviceEnabledBody =>
      'Cet appareil est marque comme fiable. Le code 2FA ne sera pas demande lors des prochaines connexions tant que vous ne retirez pas cette confiance depuis ici.';

  @override
  String get profileEditTrustedDeviceDisabledBody =>
      'Cet appareil n\'est pas marque comme fiable. Vous pouvez le marquer en appuyant sur \"Definir cet appareil comme fiable\" ou en vous deconnectant puis en vous reconnectant en activant la case \"Faire confiance a cet appareil\" lors de la validation 2FA.';

  @override
  String get profileEditRemoveTrustedDeviceAction =>
      'Retirer la confiance de cet appareil';

  @override
  String get profileEditSetTrustedDeviceAction =>
      'Definir cet appareil comme fiable';

  @override
  String get profileEditCancelProcess => 'Annuler le processus';

  @override
  String get profileEditSetTrustedDeviceTitle =>
      'Definir un appareil de confiance';

  @override
  String get profileEditSetTrustedDeviceBody =>
      'Pour marquer cet appareil comme fiable, vous devez le valider lors de la connexion 2FA en activant la case \"Faire confiance a cet appareil\".\n\nVoulez-vous vous deconnecter maintenant pour le faire ?';

  @override
  String get profileEditGoToLogin => 'Aller a la connexion';

  @override
  String get profileEditActivateTwoFactorTitle =>
      'Activer l\'authentification a deux facteurs';

  @override
  String get profileEditActivateTwoFactorIntro =>
      'L\'authentification a deux facteurs (2FA) ajoute une couche de securite supplementaire : en plus de votre mot de passe, un code temporaire de votre application d\'authentification est demande.';

  @override
  String get profileEditTwoFactorStep1 =>
      '1. Ouvrez votre application d\'authentification et ajoutez un nouveau compte.';

  @override
  String get profileEditTwoFactorSetupKeyLabel => 'Cle de configuration';

  @override
  String get profileEditKeyCopied => 'Cle copiee dans le presse-papiers';

  @override
  String get profileEditHideOptions => 'Masquer les options';

  @override
  String get profileEditMoreOptions => 'Plus d\'options...';

  @override
  String profileEditQrSavedDownloads(Object path) {
    return 'QR enregistre dans Telechargements : $path';
  }

  @override
  String get profileEditQrShared =>
      'Le menu pour partager ou enregistrer le QR a ete ouvert.';

  @override
  String get profileEditOtpUrlCopied => 'URL otpauth copiee';

  @override
  String get profileEditCopyUrl => 'Copier l\'URL';

  @override
  String get profileEditOtpUrlInfo =>
      'L\'option \"Copier l\'URL\" copie un lien otpauth avec toute la configuration 2FA afin de l\'importer dans des applications compatibles. Si votre application ne permet pas l\'importation par lien, utilisez \"Copier\" sur la cle.';

  @override
  String get profileEditTwoFactorConfirmCodeInstruction =>
      'Saisissez le code a 6 chiffres affiche par votre application d\'authentification pour confirmer.';

  @override
  String get profileEditActivateTwoFactorAction => 'Activer';

  @override
  String get profileEditTwoFactorActivated =>
      'Authentification a deux facteurs activee avec succes';

  @override
  String get profileEditTwoFactorActivateFailed =>
      'Impossible d\'activer la 2FA.';

  @override
  String get profileEditNoQrData =>
      'Il n\'y a aucune donnee a enregistrer pour le QR.';

  @override
  String profileEditQrSavedPath(Object path) {
    return 'QR enregistre dans : $path';
  }

  @override
  String profileEditQrSaveFailed(Object error) {
    return 'Impossible d\'enregistrer le QR : $error';
  }

  @override
  String get profileEditDeactivateTwoFactorTitle =>
      'Desactiver l\'authentification a deux facteurs (2FA)';

  @override
  String get profileEditCurrentCodeSixDigitsLabel => 'Code actuel a 6 chiffres';

  @override
  String get profileEditDeactivateTwoFactorAction => 'Desactiver';

  @override
  String get profileEditTwoFactorDeactivated =>
      'Authentification a deux facteurs desactivee avec succes';

  @override
  String get profileEditTwoFactorDeactivateFailed =>
      'Impossible de desactiver la 2FA.';

  @override
  String get profileEditRemoveTrustedDeviceTitle =>
      'Retirer la confiance de l\'appareil';

  @override
  String get profileEditRemoveTrustedDeviceBody =>
      'Sur cet appareil, le code 2FA sera de nouveau demande lors de la prochaine connexion. Voulez-vous continuer ?';

  @override
  String get profileEditRemoveTrustedDeviceActionShort =>
      'Retirer la confiance';

  @override
  String get profileEditTrustedDeviceRemoved =>
      'Confiance de l\'appareil retiree.';

  @override
  String profileEditTrustedDeviceRemoveFailed(Object error) {
    return 'Impossible de retirer la confiance de l\'appareil : $error';
  }

  @override
  String get profileEditMvpDialogTitle => 'Calcul MVP et formules';

  @override
  String get profileEditMvpWhatIsTitle => 'Qu\'est-ce que le MVP ?';

  @override
  String get profileEditMvpWhatIsBody =>
      'MVP est un ensemble minimal d\'indicateurs anthropometriques pour vous aider a suivre facilement l\'evolution de votre sante : IMC, taille/taille et taille/hanches.';

  @override
  String get profileEditMvpFormulasTitle =>
      'Formules utilisees et leur origine :';

  @override
  String get profileEditMvpOriginBmi =>
      'Source : OMS (classification de l\'IMC chez l\'adulte).';

  @override
  String get profileEditMvpOriginWhtr => 'Source : indice taille-taille.';

  @override
  String get profileEditMvpOriginWhr =>
      'Source : rapport taille-hanches (OMS, obesite abdominale).';

  @override
  String get profileEditImportantNotice => 'Avis important';

  @override
  String get profileEditMvpImportantNoticeBody =>
      'Ces calculs et classifications sont indicatifs. Pour une evaluation personnalisee, consultez toujours un professionnel de sante, un dieteticien-nutritionniste ou un coach sportif.';

  @override
  String get profileEditAccept => 'Accepter';

  @override
  String get profileEditNotAvailable => 'N/D';

  @override
  String get profileEditSessionDate => 'Date';

  @override
  String get profileEditSessionTime => 'Heure';

  @override
  String get profileEditSessionDevice => 'Appareil';

  @override
  String get profileEditSessionIp => 'Adresse IP :';

  @override
  String get profileEditSessionPublicIp => 'Publique';

  @override
  String get profileEditUserCodeUnavailable => 'Code utilisateur indisponible';

  @override
  String get profileEditGenericError => 'Erreur';

  @override
  String get profileEditRetry => 'Reessayer';

  @override
  String get profileEditSessionDataUnavailable =>
      'Les donnees de connexion ne sont pas accessibles pour le moment.';

  @override
  String get profileEditNoSessionData =>
      'Aucune donnee de connexion disponible';

  @override
  String get profileEditSuccessfulSessionsTitle =>
      'Dernieres connexions reussies';

  @override
  String get profileEditCurrentSession => 'Session actuelle :';

  @override
  String get profileEditPreviousSession => 'Session precedente :';

  @override
  String get profileEditNoSuccessfulSessions =>
      'Aucune connexion reussie enregistree';

  @override
  String get profileEditFailedAttemptsTitle =>
      'Dernieres tentatives de connexion echouees';

  @override
  String profileEditAttemptLabel(Object count) {
    return 'Tentative $count :';
  }

  @override
  String get profileEditNoFailedAttempts =>
      'Aucune tentative echouee enregistree.';

  @override
  String get profileEditSessionStatsTitle => 'Statistiques de session';

  @override
  String profileEditTotalSessions(Object count) {
    return 'Connexions totales : $count';
  }

  @override
  String profileEditSuccessfulAttempts(Object count) {
    return 'Tentatives reussies : $count';
  }

  @override
  String profileEditFailedAttempts(Object count) {
    return 'Tentatives echouees : $count';
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
  String get navWeightControl => 'Controle du poids';

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
      'Nom d\'utilisateur ou mot de passe incorrect.';

  @override
  String get loginFailedGeneric =>
      'Sign-in could not be completed. Please try again.';

  @override
  String get loginGuestFailedGeneric =>
      'Guest access could not be completed. Please try again.';

  @override
  String get loginUnknownUserType => 'Type d\'utilisateur inconnu';

  @override
  String get loginTwoFactorTitle => 'Verification 2FA';

  @override
  String get loginTwoFactorPrompt =>
      'Saisissez le code a 6 chiffres de votre application TOTP.';

  @override
  String get loginTwoFactorCodeLabel => 'Code 2FA';

  @override
  String get loginTrustThisDevice => 'Faire confiance a cet appareil';

  @override
  String get loginTrustThisDeviceSubtitle =>
      'La 2FA ne sera plus demandee sur cet appareil.';

  @override
  String get loginCodeMustHave6Digits => 'Le code doit contenir 6 chiffres.';

  @override
  String get loginRecoveryTitle => 'Recuperer l\'acces';

  @override
  String get loginRecoveryIdentifierIntro =>
      'Saisissez votre nom d\'utilisateur (nick) ou votre email pour recuperer l\'acces.';

  @override
  String get loginUserOrEmailLabel => 'Nom d\'utilisateur ou email';

  @override
  String get loginEnterUserOrEmail =>
      'Saisissez un nom d\'utilisateur ou un email.';

  @override
  String get loginNoRecoveryMethods =>
      'Cet utilisateur n\'a aucune methode de recuperation disponible.';

  @override
  String get loginSelectRecoveryMethod =>
      'Selectionnez une methode de recuperation';

  @override
  String get loginRecoveryByEmail => 'Avec votre email';

  @override
  String get loginRecoveryByTwoFactor =>
      'Avec l\'authentification a deux facteurs (2FA)';

  @override
  String get loginEmailRecoveryIntro =>
      'Nous vous enverrons un code de recuperation par email. Saisissez-le ici avec votre nouveau mot de passe.';

  @override
  String get loginRecoveryStep1SendCode => 'Etape 1 : Envoyer le code';

  @override
  String get loginRecoveryStep1SendCodeBody =>
      'Appuyez sur \"Envoyer le code\" pour recevoir un code de recuperation par email.';

  @override
  String get loginSendCode => 'Envoyer le code';

  @override
  String get loginRecoveryStep2VerifyCode => 'Etape 2 : Verifier le code';

  @override
  String get loginRecoveryStep2VerifyCodeBody =>
      'Saisissez le code recu par email.';

  @override
  String get loginRecoveryCodeLabel => 'Code de recuperation';

  @override
  String get loginRecoveryCodeHintAlpha => 'Ex. 1a3B';

  @override
  String get loginRecoveryCodeHintNumeric => 'Ex. 1234';

  @override
  String get loginVerifyCode => 'Verifier le code';

  @override
  String get loginRecoveryStep3NewPassword => 'Etape 3 : Nouveau mot de passe';

  @override
  String get loginRecoveryStep3NewPasswordBody =>
      'Saisissez votre nouveau mot de passe.';

  @override
  String get loginNewPasswordLabel => 'Nouveau mot de passe';

  @override
  String get loginRepeatNewPasswordLabel => 'Repetez le nouveau mot de passe';

  @override
  String get loginBothPasswordsRequired =>
      'Remplissez les deux champs du mot de passe.';

  @override
  String get loginPasswordsMismatch =>
      'Les mots de passe ne correspondent pas.';

  @override
  String get loginPasswordResetSuccess =>
      'Mot de passe reinitialise. Vous pouvez maintenant vous connecter.';

  @override
  String get loginTwoFactorRecoveryIntro =>
      'Pour reinitialiser votre mot de passe avec l\'authentification a deux facteurs, vous avez besoin du code temporaire de votre application.';

  @override
  String get loginTwoFactorRecoveryStep1 =>
      'Etape 1 : Ouvrez votre application d\'authentification';

  @override
  String get loginTwoFactorRecoveryStep1Body =>
      'Cherchez le code temporaire a 6 chiffres dans votre application d\'authentification (Google Authenticator, Microsoft Authenticator, Authy, etc.)';

  @override
  String get loginIHaveIt => 'Je l\'ai';

  @override
  String get loginTwoFactorRecoveryStep2 => 'Etape 2 : Verifiez votre code 2FA';

  @override
  String get loginTwoFactorRecoveryStep2Body =>
      'Saisissez le code a 6 chiffres dans le champ ci-dessous.';

  @override
  String get loginTwoFactorCodeSixDigitsLabel => 'Code 2FA (6 chiffres)';

  @override
  String get loginTwoFactorCodeHint => '000000';

  @override
  String get loginVerifyTwoFactorCode => 'Verifier le code 2FA';

  @override
  String get loginCodeMustHaveExactly6Digits =>
      'Le code doit contenir exactement 6 chiffres.';

  @override
  String get loginPasswordUpdatedSuccess =>
      'Mot de passe mis a jour. Vous pouvez maintenant vous connecter.';

  @override
  String get loginUsernameLabel => 'Nom d\'utilisateur';

  @override
  String get loginEnterUsername => 'Saisissez votre nom d\'utilisateur';

  @override
  String get loginPasswordLabel => 'Mot de passe';

  @override
  String get loginEnterPassword => 'Saisissez votre mot de passe';

  @override
  String get loginSignIn => 'Se connecter';

  @override
  String get loginForgotPassword => 'Mot de passe oublie ?';

  @override
  String get loginGuestInfo =>
      'Accedez gratuitement a NutriFit pour consulter des conseils de sante et de nutrition, des videos d\'exercices, des recettes, le controle du poids et bien plus encore.';

  @override
  String get loginGuestAccess => 'Acceder sans identifiants';

  @override
  String get loginRegisterFree => 'Inscrivez-vous gratuitement';

  @override
  String get registerCreateAccountTitle => 'Creer un compte';

  @override
  String get registerFullNameLabel => 'Nom complet';

  @override
  String get registerEnterFullName => 'Saisissez votre nom';

  @override
  String get registerUsernameMinLength =>
      'Le nom d\'utilisateur doit comporter au moins 3 caracteres';

  @override
  String get registerEmailLabel => 'Email';

  @override
  String get registerInvalidEmail => 'Email non valide';

  @override
  String get registerAdditionalDataTitle => 'Donnees supplementaires';

  @override
  String get registerAdditionalDataCollapsedSubtitle =>
      'Age et taille (facultatifs)';

  @override
  String get registerAdditionalDataExpandedSubtitle =>
      'Age et taille pour IMC/MVP';

  @override
  String get registerAdditionalDataInfo =>
      'Pour activer le calcul de l\'IMC, du MVP et des metriques de sante, indiquez votre age et votre taille (en centimetres).';

  @override
  String get registerAgeLabel => 'Age';

  @override
  String get registerInvalidAge => 'Age non valide';

  @override
  String get registerHeightLabel => 'Taille (cm)';

  @override
  String get registerInvalidHeight => 'Taille non valide';

  @override
  String get registerConfirmPasswordLabel => 'Confirmer le mot de passe';

  @override
  String get registerConfirmPasswordRequired => 'Confirmez votre mot de passe';

  @override
  String get registerCreateAccountButton => 'Creer un compte';

  @override
  String get registerAlreadyHaveAccount =>
      'Vous avez deja un compte ? Connectez-vous';

  @override
  String get registerEmailUnavailable =>
      'Cette adresse e-mail ne peut pas etre utilisee. Veuillez en indiquer une autre.';

  @override
  String get registerSuccessMessage =>
      'Utilisateur inscrit avec succes. Connectez-vous avec vos identifiants (nom d\'utilisateur et mot de passe).';

  @override
  String get registerNetworkError =>
      'Le processus n\'a pas pu etre finalise. Verifiez la connexion Internet.';

  @override
  String get registerGenericError => 'Erreur lors de l\'inscription';

  @override
  String get loginResetPassword => 'Reinitialiser le mot de passe';

  @override
  String get loginEmailRecoverySendFailedGeneric =>
      'L\'email de recuperation n\'a pas pu etre envoye pour le moment. Veuillez reessayer plus tard.';

  @override
  String get passwordChecklistTitle => 'Exigences du mot de passe :';

  @override
  String passwordChecklistMinLength(Object count) {
    return 'Minimum $count caracteres';
  }

  @override
  String get passwordChecklistUpperLower =>
      'Au moins une lettre majuscule et une minuscule';

  @override
  String get passwordChecklistNumber => 'Au moins un chiffre (0-9)';

  @override
  String get passwordChecklistSpecial =>
      'Au moins un caractere special (*,.+-#\\\$?¿!¡_()/\\%&)';

  @override
  String loginPasswordMinLengthError(Object count) {
    return 'Le nouveau mot de passe doit contenir au moins $count caracteres.';
  }

  @override
  String get loginPasswordUppercaseError =>
      'Le nouveau mot de passe doit contenir au moins une lettre majuscule.';

  @override
  String get loginPasswordLowercaseError =>
      'Le nouveau mot de passe doit contenir au moins une lettre minuscule.';

  @override
  String get loginPasswordNumberError =>
      'Le nouveau mot de passe doit contenir au moins un chiffre.';

  @override
  String get loginPasswordSpecialError =>
      'Le nouveau mot de passe doit contenir au moins un caractere special (* , . + - # \\\$ ? ¿ ! ¡ _ ( ) / \\ % &).';

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
  String get patientAdherenceNutriPlan => 'Plan nutritionnel';

  @override
  String get patientAdherenceFitPlan => 'Plan Fit';

  @override
  String get patientAdherenceCompleted => 'Respecte';

  @override
  String get patientAdherencePartial => 'Partiel';

  @override
  String get patientAdherenceNotDone => 'Non realise';

  @override
  String get patientAdherenceNoChanges => 'Sans changement';

  @override
  String patientAdherenceTrendPoints(Object trend) {
    return '$trend pts';
  }

  @override
  String get patientAdherenceTitle => 'Respect du plan';

  @override
  String get patientAdherenceImprovementPoints => 'Points d\'amelioration';

  @override
  String get patientAdherenceImprovementNutriTarget =>
      'Nutri : essayez de respecter au moins 5 jours sur 7 cette semaine.';

  @override
  String get patientAdherenceImprovementNutriTrend =>
      'Nutri : la tendance baisse par rapport a la semaine derniere ; revenez a votre routine de base.';

  @override
  String get patientAdherenceImprovementFitTarget =>
      'Fit : essayez d\'atteindre 3 a 4 seances par semaine, meme si elles sont courtes.';

  @override
  String get patientAdherenceImprovementFitTrend =>
      'Fit : la tendance a baisse ; planifiez vos prochaines seances aujourd\'hui.';

  @override
  String get patientAdherenceImprovementKeepGoing =>
      'Bon rythme. Gardez de la constance pour consolider les resultats.';

  @override
  String get patientAdherenceSheetTitleToday =>
      'Respect du plan pour aujourd\'hui';

  @override
  String patientAdherenceSheetTitleForDate(Object date) {
    return 'Respect du plan pour $date';
  }

  @override
  String get patientAdherenceDateToday => 'aujourd\'hui';

  @override
  String patientAdherenceStatusSaved(Object plan, Object status, Object date) {
    return '$plan : $status $date';
  }

  @override
  String get patientAdherenceFutureDateError =>
      'Il n\'est pas possible d\'enregistrer le respect du plan pour des dates futures. Seulement aujourd\'hui ou des jours precedents.';

  @override
  String get patientAdherenceReasonNotDoneTitle =>
      'Raison de la non-realisation';

  @override
  String get patientAdherenceReasonPartialTitle => 'Raison du respect partiel';

  @override
  String get patientAdherenceReasonHint =>
      'Dites-nous brievement ce qui s\'est passe aujourd\'hui';

  @override
  String get patientAdherenceSkipReason => 'Ignorer la raison';

  @override
  String get patientAdherenceSaveContinue => 'Enregistrer et continuer';

  @override
  String patientAdherenceSaveError(Object error) {
    return 'Impossible d\'enregistrer dans la base de donnees : $error';
  }

  @override
  String get patientAdherenceReasonLabel => 'Raison';

  @override
  String get patientAdherenceInfoTitle =>
      'Que signifie chaque etat de respect du plan ?';

  @override
  String get patientAdherenceNutriCompletedDescription =>
      'Vous avez suivi le plan alimentaire exactement comme prevu pour cette journee.';

  @override
  String get patientAdherenceNutriPartialDescription =>
      'Vous avez suivi une partie du plan, mais pas completement : un repas a ete saute, modifie ou avec une quantite differente.';

  @override
  String get patientAdherenceNutriNotDoneDescription =>
      'Vous n\'avez pas suivi le plan alimentaire ce jour-la.';

  @override
  String get patientAdherenceFitCompletedDescription =>
      'Vous avez realise l\'entrainement complet prevu pour cette journee.';

  @override
  String get patientAdherenceFitPartialDescription =>
      'Vous avez realise une partie de l\'entrainement : certains exercices, series ou la duree sont restes incomplets.';

  @override
  String get patientAdherenceFitNotDoneDescription =>
      'Vous n\'avez pas realise l\'entrainement ce jour-la.';

  @override
  String get patientAdherenceAlertRecoveryTitle => 'Il faut reagir';

  @override
  String patientAdherenceAlertRecoveryBody(Object plan) {
    return 'Vous etes sous les 50 % depuis deux semaines d\'affilee en $plan. Il faut reprendre le rythme des maintenant : de petits pas chaque jour, mais sans manquer. Vous pouvez le faire, mais il faut s\'y remettre serieusement.';
  }

  @override
  String get patientAdherenceAlertEncouragementTitle => 'Il est encore temps';

  @override
  String patientAdherenceAlertEncouragementBody(Object plan) {
    return 'Cette semaine, $plan est sous les 50 %. La prochaine peut etre bien meilleure : revenez a votre routine de base et ajoutez une victoire chaque jour.';
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
  String get patientContactDietitianPrompt => 'Contacter la dieteticienne...';

  @override
  String get patientContactDietitianTrainer => 'Contacter Dieteticien/Coach';

  @override
  String get contactDietitianMethodsTitle => 'Moyens de contact';

  @override
  String get contactDietitianEmailLabel => 'Email';

  @override
  String get contactDietitianCallLabel => 'Appeler';

  @override
  String get contactDietitianSocialTitle =>
      'Suivez-nous sur les reseaux sociaux';

  @override
  String get contactDietitianWebsiteLabel => 'Site web';

  @override
  String get contactDietitianPhoneCopied =>
      'Numero de telephone copie dans le presse-papiers.';

  @override
  String get contactDietitianWhatsappInvalidPhone =>
      'Aucun numero valide pour ouvrir WhatsApp.';

  @override
  String contactDietitianWhatsappOpenError(Object error) {
    return 'Impossible d\'ouvrir WhatsApp : $error';
  }

  @override
  String get contactDietitianWhatsappDialogTitle => 'Contacter via WhatsApp';

  @override
  String contactDietitianWhatsappDialogBody(Object phone) {
    return 'Vous pouvez ouvrir directement le chat WhatsApp avec le numero $phone. Vous pouvez aussi copier le numero dans le presse-papiers pour l\'utiliser dans votre application WhatsApp ou l\'enregistrer.';
  }

  @override
  String get contactDietitianCopyPhone => 'Copier le telephone';

  @override
  String get contactDietitianOpenWhatsapp => 'Ouvrir WhatsApp';

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
  String get chatMessageHint => 'Ecrivez un message';

  @override
  String get profileImagePickerDialogTitle => 'Selectionner l\'image de profil';

  @override
  String get profileImagePickerTakePhoto => 'Prendre une photo';

  @override
  String get profileImagePickerChooseFromGallery => 'Choisir depuis la galerie';

  @override
  String get profileImagePickerSelectImage => 'Selectionner une image';

  @override
  String get profileImagePickerRemovePhoto => 'Supprimer la photo';

  @override
  String get profileImagePickerPrompt => 'Selectionnez votre image de profil';

  @override
  String profileImagePickerMaxDimensions(Object width, Object height) {
    return 'Max. ${width}x${height}px';
  }

  @override
  String profileImagePickerSaved(Object sizeKb) {
    return 'Image enregistree avec succes (${sizeKb}KB)';
  }

  @override
  String get profileImagePickerProcessError =>
      'Erreur lors du traitement de l\'image';

  @override
  String get profileImagePickerTechnicalDetails => 'Details techniques';

  @override
  String get profileImagePickerOperationFailed =>
      'L\'operation n\'a pas pu etre terminee. Reessayez ou contactez le support.';

  @override
  String get shoppingListPremiumTitle => 'Liste de courses Premium';

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
  String get weightControlBack => 'Retour';

  @override
  String get weightControlChangeTarget => 'Changer le poids objectif';

  @override
  String get weightControlHideFilter => 'Masquer le filtre';

  @override
  String get weightControlShowFilter => 'Afficher le filtre';

  @override
  String get weightControlGuestMessage =>
      'Pour gerer votre suivi du poids, vous devez vous inscrire. C\'est gratuit.';

  @override
  String weightControlLoadError(Object error) {
    return 'Erreur lors du chargement des mesures : $error';
  }

  @override
  String get weightControlNoMeasurementsTitle =>
      'Aucune mesure n\'a encore ete enregistree.';

  @override
  String get weightControlNoMeasurementsBody =>
      'Commencez par ajouter votre premiere mesure pour voir vos progres.';

  @override
  String get weightControlAddMeasurement => 'Ajouter une mesure';

  @override
  String weightControlNoWeightsForPeriod(Object period) {
    return 'Il n\'y a pas de poids pour $period.';
  }

  @override
  String weightControlNoMeasurementsForPeriod(Object period) {
    return 'Il n\'y a pas de mesures pour $period.';
  }

  @override
  String get weightControlPremiumPerimetersTitle =>
      'Evolution Premium des perimetres';

  @override
  String get weightControlPremiumChartBody =>
      'Ce graphique est disponible uniquement pour les utilisateurs Premium. Activez votre compte pour voir toute votre progression avec des indicateurs visuels avances.';

  @override
  String get weightControlCurrentMonth => 'Mois en cours';

  @override
  String get weightControlPreviousMonth => 'Mois precedent';

  @override
  String get weightControlQuarter => 'Trimestre';

  @override
  String get weightControlSemester => 'Semestre';

  @override
  String get weightControlCurrentYear => 'Annee en cours';

  @override
  String get weightControlPreviousYear => 'Annee precedente';

  @override
  String get weightControlAllTime => 'Depuis le debut';

  @override
  String weightControlLastDaysLabel(Object days) {
    return 'Derniers $days jours';
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
  String get commonPremiumFeatureTitle => 'Fonction Premium';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonFilter => 'Filtrer';

  @override
  String get commonRefresh => 'Actualiser';

  @override
  String get commonMoreOptions => 'Plus d\'options';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonClear => 'Effacer';

  @override
  String get commonApply => 'Appliquer';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonGeneratePdf => 'Generer un PDF';

  @override
  String get commonHideSearch => 'Masquer la recherche';

  @override
  String get commonFilterByCategories => 'Filtrer par categories';

  @override
  String commonFilterByCategoriesCount(Object count) {
    return 'Filtrer les categories ($count)';
  }

  @override
  String get commonMatchAll => 'Faire correspondre toutes';

  @override
  String get commonRequireAllSelected =>
      'Si active, toutes les selections sont requises.';

  @override
  String commonCategoryFallback(Object id) {
    return 'Categorie $id';
  }

  @override
  String get commonSignInToLike => 'Vous devez vous connecter pour aimer ceci';

  @override
  String get commonSignInToSaveFavorites =>
      'Vous devez vous connecter pour enregistrer des favoris';

  @override
  String get commonCouldNotIdentifyUser =>
      'Erreur : impossible d\'identifier l\'utilisateur';

  @override
  String commonLikeChangeError(Object error) {
    return 'Erreur lors du changement du statut J\'aime. $error';
  }

  @override
  String commonFavoriteChangeError(Object error) {
    return 'Erreur lors du changement du favori. $error';
  }

  @override
  String commonGuestFavoritesRequiresRegistration(Object itemType) {
    return 'Pour ajouter $itemType aux favoris, vous devez vous inscrire (c\'est gratuit).';
  }

  @override
  String get commonRecipesAndTipsPremiumCopyPdfMessage =>
      'Pour copier et exporter en PDF les recettes et conseils, vous devez etre utilisateur Premium.';

  @override
  String get commonCopiedToClipboard => 'Copie dans le presse-papiers';

  @override
  String commonCopiedToClipboardLabel(Object label) {
    return '$label copie dans le presse-papiers.';
  }

  @override
  String get commonLanguage => 'Langue';

  @override
  String get commonUser => 'utilisateur';

  @override
  String get languageSpanish => 'Espagnol';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageItalian => 'Italien';

  @override
  String get languageGerman => 'Allemand';

  @override
  String get languageFrench => 'Francais';

  @override
  String get languagePortuguese => 'Portugais';

  @override
  String commonCopyError(Object error) {
    return 'Erreur lors de la copie : $error';
  }

  @override
  String commonGeneratePdfError(Object error) {
    return 'Erreur lors de la generation du PDF : $error';
  }

  @override
  String commonOpenLinkError(Object error) {
    return 'Erreur lors de l\'ouverture du lien : $error';
  }

  @override
  String get commonDocumentUnavailable => 'Le document n\'est pas disponible';

  @override
  String commonDecodeError(Object error) {
    return 'Erreur de decodage : $error';
  }

  @override
  String get commonSaveDocumentError =>
      'Erreur : le document n\'a pas pu etre enregistre';

  @override
  String commonOpenDocumentError(Object error) {
    return 'Erreur lors de l\'ouverture du document : $error';
  }

  @override
  String get commonDownloadDocument => 'Telecharger le document';

  @override
  String get commonDocumentsAndLinks => 'Documents et liens';

  @override
  String get commonYouMayAlsoLike => 'Cela pourrait aussi vous interesser...';

  @override
  String get commonSortByTitle => 'Trier par titre';

  @override
  String get commonSortByRecent => 'Trier par recent';

  @override
  String get commonSortByPopular => 'Trier par popularite';

  @override
  String get commonPersonalTab => 'Personnels';

  @override
  String get commonFeaturedTab => 'Mis en avant';

  @override
  String get commonAllTab => 'Tous';

  @override
  String get commonFavoritesTab => 'Favoris';

  @override
  String get commonFeaturedFeminineTab => 'Mises en avant';

  @override
  String get commonAllFeminineTab => 'Toutes';

  @override
  String get commonFavoritesFeminineTab => 'Favorites';

  @override
  String commonLikesCount(Object count) {
    return '$count mentions J\'aime';
  }

  @override
  String get commonLink => 'Lien';

  @override
  String get commonTipItem => 'conseil';

  @override
  String get commonRecipeItem => 'recette';

  @override
  String get commonAdditiveItem => 'additif';

  @override
  String get commonSupplementItem => 'complement';

  @override
  String commonSeeLinkToType(Object type) {
    return 'Voir le lien vers $type';
  }

  @override
  String get commonDocument => 'Document';

  @override
  String get todoPriorityHigh => 'Haute';

  @override
  String get todoPriorityMedium => 'Moyenne';

  @override
  String get todoPriorityLow => 'Basse';

  @override
  String get todoStatusPending => 'En attente';

  @override
  String get todoStatusResolved => 'Resolue';

  @override
  String todoCalendarPriority(Object value) {
    return 'Priorite : $value';
  }

  @override
  String todoCalendarStatus(Object value) {
    return 'Statut : $value';
  }

  @override
  String todoExportError(Object error) {
    return 'Erreur lors de l\'exportation de la tache : $error';
  }

  @override
  String get todoDateRequiredForCalendar =>
      'La tache doit avoir une date pour etre ajoutee au calendrier';

  @override
  String todoAddToCalendarError(Object error) {
    return 'Impossible d\'ajouter la tache au calendrier : $error';
  }

  @override
  String todoPremiumLimitMessage(int limit) {
    return 'En tant qu\'utilisateur non Premium, vous pouvez creer jusqu\'a $limit taches. Passez a Premium pour ajouter des taches illimitees et consulter tout l\'historique.';
  }

  @override
  String get todoNoDate => 'Sans date';

  @override
  String get todoPriorityHighTooltip => 'Priorite haute';

  @override
  String get todoPriorityMediumTooltip => 'Priorite moyenne';

  @override
  String get todoPriorityLowTooltip => 'Priorite basse';

  @override
  String get todoStatusResolvedShort => 'Faite (F)';

  @override
  String get todoStatusPendingShort => 'En attente (E)';

  @override
  String get todoMarkPending => 'Marquer comme en attente';

  @override
  String get todoMarkResolved => 'Marquer comme resolue';

  @override
  String get todoEditTaskTitle => 'Modifier la tache';

  @override
  String get todoNewTaskTitle => 'Nouvelle tache';

  @override
  String get todoTitleLabel => 'Titre';

  @override
  String get todoTitleRequired => 'Le titre est obligatoire';

  @override
  String get todoDescriptionTitle => 'Description';

  @override
  String get todoDescriptionOptionalLabel => 'Description (facultative)';

  @override
  String get todoPriorityTitle => 'Priorite';

  @override
  String get todoStatusTitle => 'Statut';

  @override
  String todoTasksForDay(Object date) {
    return 'Taches du $date';
  }

  @override
  String get todoNewShort => 'Nouvelle';

  @override
  String get todoNoTasksSelectedDay => 'Aucune tache pour le jour selectionne.';

  @override
  String get todoNoTasksToShow => 'Aucune tache a afficher';

  @override
  String get todoPremiumTitle => 'Taches Premium';

  @override
  String todoPremiumPreviewSubtitle(int limit) {
    return 'Vous pouvez consulter les $limit derniers enregistrements et creer jusqu\'a $limit taches. Si vous voulez des taches illimitees, passez a Premium.';
  }

  @override
  String todoPremiumPreviewHighlight(int count) {
    return 'Vous avez actuellement $count taches enregistrees.';
  }

  @override
  String get todoEmptyState => 'Vous n\'avez encore cree aucune tache.';

  @override
  String get todoScreenTitle => 'Taches';

  @override
  String get todoTabPending => 'En attente';

  @override
  String get todoTabResolved => 'Resolues';

  @override
  String get todoTabAll => 'Toutes';

  @override
  String get todoHideFilters => 'Masquer les filtres';

  @override
  String get todoViewList => 'Voir la liste';

  @override
  String get todoViewCalendar => 'Voir le calendrier';

  @override
  String get todoSortByDate => 'Trier par date';

  @override
  String get todoSortByPriority => 'Trier par priorite';

  @override
  String get todoSearchHint => 'Rechercher des taches';

  @override
  String get todoClearSearch => 'Effacer la recherche';

  @override
  String get todoDeleteTitle => 'Supprimer la tache';

  @override
  String todoDeleteConfirm(Object title) {
    return 'Voulez-vous supprimer la tache \"$title\" ?';
  }

  @override
  String get todoDeletedSuccess => 'Tache supprimee';

  @override
  String get todoAddToDeviceCalendar => 'Ajouter au calendrier de l\'appareil';

  @override
  String get todoEditAction => 'Modifier';

  @override
  String get todoSelectDate => 'Selectionner une date';

  @override
  String get todoRemoveDate => 'Supprimer la date';

  @override
  String get todoGuestTitle => 'Taches pour utilisateurs enregistres';

  @override
  String get todoGuestBody =>
      'Connectez-vous ou passez Premium pour creer, organiser et synchroniser vos taches sur tous vos appareils.';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonSortByName => 'Trier par nom';

  @override
  String get commonSortByType => 'Trier par type';

  @override
  String get commonSortByDate => 'Trier par date';

  @override
  String get commonSortBySeverity => 'Trier par gravite';

  @override
  String get commonName => 'Nom';

  @override
  String get commonTitleField => 'Titre';

  @override
  String get commonDescriptionField => 'Description';

  @override
  String get commonTypeField => 'Type';

  @override
  String get commonSeverity => 'Gravite';

  @override
  String commonNoResultsForQuery(Object query) {
    return 'Aucun resultat pour \"$query\"';
  }

  @override
  String get tipsPremiumToolsMessage =>
      'La recherche, les filtres, les favoris, les mentions J\'aime et l\'acces complet au catalogue des conseils sont reserves aux utilisateurs Premium.';

  @override
  String get tipsPremiumPreviewTitle => 'Conseils Premium';

  @override
  String get tipsPremiumPreviewSubtitle =>
      'Vous pouvez voir un apercu des 3 derniers conseils. Passez a Premium pour acceder au catalogue complet et a tous ses outils.';

  @override
  String tipsPreviewAvailableCount(Object count) {
    return ' Il y a actuellement $count conseils disponibles.';
  }

  @override
  String get tipsSearchLabel => 'Rechercher des conseils';

  @override
  String get tipsNoPersonalizedRecommendations =>
      'Aucune recommandation personnalisee';

  @override
  String get tipsViewGeneralTips => 'Voir les conseils generaux';

  @override
  String get tipsUnreadBadge => 'Non lu';

  @override
  String get messagesInboxTitle => 'Messages non lus';

  @override
  String get messagesInboxGuestBody =>
      'Pour discuter en ligne avec votre dieteticien, veuillez vous inscrire (c\'est gratuit).';

  @override
  String get messagesInboxGuestAction => 'Commencer l\'inscription';

  @override
  String get messagesInboxUnreadChats => 'Chats non lus';

  @override
  String get messagesInboxNoPendingChats =>
      'Il n\'y a pas de chats en attente.';

  @override
  String get messagesInboxUser => 'Utilisateur';

  @override
  String get messagesInboxImage => 'Image';

  @override
  String get messagesInboxNoMessages => 'Aucun message';

  @override
  String get messagesInboxPendingExerciseFeelings =>
      'Ressentis d\'exercices en attente';

  @override
  String get messagesInboxNoPendingExerciseFeelings =>
      'Il n\'y a pas de ressentis d\'exercices en attente.';

  @override
  String get messagesInboxViewPendingExerciseFeelings =>
      'Voir les ressentis d\'exercices en attente';

  @override
  String get messagesInboxUnreadDietitianChats =>
      'Chats avec le dieteticien non lus';

  @override
  String get messagesInboxOpenDietitianChat =>
      'Ouvrir le chat avec le dieteticien';

  @override
  String get messagesInboxMessage => 'Message';

  @override
  String get messagesInboxDietitianMessage => 'Message du dieteticien';

  @override
  String get messagesInboxUnreadCoachComments =>
      'Commentaires du coach non lus';

  @override
  String get messagesInboxNoUnreadCoachComments =>
      'Vous n\'avez pas de commentaires du coach sportif en attente de lecture.';

  @override
  String get messagesInboxViewPendingComments =>
      'Voir les commentaires en attente';

  @override
  String messagesInboxLoadError(Object error) {
    return 'Erreur lors du chargement des messages : $error';
  }

  @override
  String get tipsNoFeaturedAvailable => 'Aucun conseil mis en avant';

  @override
  String get tipsNoTipsAvailable => 'Aucun conseil disponible';

  @override
  String get tipsNoFavoriteTips => 'Vous n\'avez aucun conseil favori';

  @override
  String get tipsDetailTitle => 'Details du conseil';

  @override
  String get tipsPreviewBanner =>
      'Apercu - Voici comment les utilisateurs verront le conseil';

  @override
  String tipsHashtagTitle(Object hashtag) {
    return 'Conseils avec $hashtag';
  }

  @override
  String tipsHashtagEmpty(Object hashtag) {
    return 'Il n\'y a pas de conseils avec $hashtag';
  }

  @override
  String tipsLoadErrorStatus(Object statusCode) {
    return 'Erreur lors du chargement des conseils : $statusCode';
  }

  @override
  String tipsLoadError(Object error) {
    return 'Erreur lors du chargement des conseils. $error';
  }

  @override
  String get recipesPremiumToolsMessage =>
      'La recherche, les filtres, les favoris, les mentions J\'aime et l\'acces complet au catalogue des recettes sont reserves aux utilisateurs Premium.';

  @override
  String get recipesPremiumPreviewTitle => 'Recettes Premium';

  @override
  String get recipesPremiumPreviewSubtitle =>
      'Vous pouvez voir un apercu des 3 dernieres recettes. Passez a Premium pour acceder au catalogue complet et a tous ses outils.';

  @override
  String recipesPreviewAvailableCount(Object count) {
    return ' Il y a actuellement $count recettes disponibles.';
  }

  @override
  String get recipesSearchLabel => 'Rechercher des recettes';

  @override
  String get recipesNoFeaturedAvailable => 'Aucune recette mise en avant';

  @override
  String get recipesNoRecipesAvailable => 'Aucune recette disponible';

  @override
  String get recipesNoFavoriteRecipes => 'Vous n\'avez aucune recette favorite';

  @override
  String get recipesDetailTitle => 'Details de la recette';

  @override
  String get recipesPreviewBanner =>
      'Apercu - Voici comment les utilisateurs verront la recette';

  @override
  String recipesHashtagTitle(Object hashtag) {
    return 'Recettes avec $hashtag';
  }

  @override
  String recipesHashtagEmpty(Object hashtag) {
    return 'Il n\'y a pas de recettes avec $hashtag';
  }

  @override
  String get additivesPremiumCopyPdfMessage =>
      'Pour copier un additif et l\'exporter en PDF, vous devez etre utilisateur Premium.';

  @override
  String get additivesPremiumExploreMessage =>
      'Les hashtags et recommandations d\'additifs sont reserves aux utilisateurs Premium.';

  @override
  String get additivesPremiumToolsMessage =>
      'La recherche, les filtres, l\'actualisation et le tri complet du catalogue des additifs sont reserves aux utilisateurs Premium.';

  @override
  String get additivesFilterTitle => 'Filtrer les additifs';

  @override
  String get additivesNoConfiguredTypes =>
      'Aucun type n\'est configure dans tipos_aditivos.';

  @override
  String get additivesTypesLabel => 'Types';

  @override
  String get additivesSearchHint => 'Rechercher des additifs';

  @override
  String get additivesEmpty => 'Aucun additif disponible';

  @override
  String get additivesPremiumTitle => 'Additifs Premium';

  @override
  String get additivesPremiumSubtitle =>
      'Le catalogue complet des additifs est reserve aux utilisateurs Premium.';

  @override
  String additivesCatalogHighlight(Object count) {
    return ' (avec plus de $count additifs)';
  }

  @override
  String get additivesLoadFailed => 'Impossible de charger les additifs.';

  @override
  String get additivesCatalogUnavailable =>
      'Le catalogue des additifs est temporairement indisponible. Reessayez plus tard.';

  @override
  String get additivesServerConnectionError =>
      'Impossible de se connecter au serveur. Verifiez votre connexion et reessayez.';

  @override
  String get additivesSeveritySafe => 'Sain';

  @override
  String get additivesSeverityAttention => 'Attention';

  @override
  String get additivesSeverityHigh => 'Eleve';

  @override
  String get additivesSeverityRestricted => 'Restreint';

  @override
  String get additivesSeverityForbidden => 'Interdit';

  @override
  String get substitutionsPremiumToolsMessage =>
      'La recherche, les filtres, les favoris et le tri complet des substitutions saines sont reserves aux utilisateurs Premium.';

  @override
  String get substitutionsPremiumCopyPdfMessage =>
      'Pour copier une substitution saine et l\'exporter en PDF, vous devez etre utilisateur Premium.';

  @override
  String get substitutionsPremiumExploreMessage =>
      'Les hashtags, categories, recommandations et la navigation avancee des substitutions saines sont reserves aux utilisateurs Premium.';

  @override
  String get substitutionsPremiumEngagementMessage =>
      'Les favoris et mentions J\'aime des substitutions saines sont reserves aux utilisateurs Premium.';

  @override
  String get substitutionsSearchLabel =>
      'Rechercher des substitutions ou hashtags';

  @override
  String get substitutionsEmptyFeatured => 'Aucune substitution mise en avant.';

  @override
  String get substitutionsEmptyAll => 'Aucune substitution disponible.';

  @override
  String get substitutionsEmptyFavorites =>
      'Vous n\'avez pas encore de substitutions favorites.';

  @override
  String get substitutionsPremiumTitle => 'Substitutions Premium';

  @override
  String get substitutionsPremiumSubtitle =>
      'La bibliotheque complete des substitutions saines est reservee aux utilisateurs Premium.';

  @override
  String substitutionsCatalogHighlight(Object count) {
    return ' (avec plus de $count substitutions)';
  }

  @override
  String get substitutionsDefaultBadge => 'Substitution Premium';

  @override
  String get substitutionsTapForDetail => 'Touchez pour voir le detail complet';

  @override
  String get substitutionsDetailTitle => 'Substitution saine';

  @override
  String get substitutionsRecommendedChange => 'Changement recommande';

  @override
  String get substitutionsIfUnavailable => 'Si vous n\'avez pas';

  @override
  String get substitutionsUse => 'Utilisez';

  @override
  String get substitutionsEquivalence => 'Quantite equivalente';

  @override
  String get substitutionsGoal => 'Objectif';

  @override
  String get substitutionsNotesContext => 'Sustitución saludable';

  @override
  String get commonExport => 'Exporter';

  @override
  String get commonImport => 'Importer';

  @override
  String get commonPhoto => 'Photo';

  @override
  String get commonGallery => 'Galerie';

  @override
  String get commonUnavailable => 'Indisponible';

  @override
  String get scannerTitle => 'Scanner d\'etiquettes';

  @override
  String get scannerPremiumRequiredMessage =>
      'La lecture, l\'ouverture d\'images depuis la galerie et la recherche de produits depuis le scanner sont reservees aux utilisateurs Premium.';

  @override
  String get scannerClearTrainingTitle => 'Effacer l\'entrainement OCR';

  @override
  String get scannerClearTrainingBody =>
      'Toutes les corrections enregistrees sur cet appareil seront supprimees. Voulez-vous continuer ?';

  @override
  String get scannerLocalTrainingRemoved => 'Entrainement OCR local supprime';

  @override
  String get scannerExportRulesTitle => 'Exporter les regles OCR';

  @override
  String get scannerImportRulesTitle => 'Importer les regles OCR';

  @override
  String get scannerImportRulesHint => 'Collez ici le JSON exporte';

  @override
  String get scannerInvalidFormat => 'Format invalide';

  @override
  String get scannerInvalidJsonOrCanceled =>
      'JSON invalide ou importation annulee';

  @override
  String scannerImportedRulesCount(Object count) {
    return '$count regles d\'entrainement importees';
  }

  @override
  String get scannerRulesUploaded => 'Regles OCR envoyees au serveur';

  @override
  String scannerRulesUploadError(Object error) {
    return 'Erreur lors de l\'envoi des regles : $error';
  }

  @override
  String get scannerNoRemoteRules => 'Aucune regle distante disponible.';

  @override
  String scannerDownloadedRulesCount(Object count) {
    return '$count regles telechargees depuis le serveur';
  }

  @override
  String scannerRulesDownloadError(Object error) {
    return 'Erreur lors du telechargement des regles : $error';
  }

  @override
  String get scannerTrainingMarkedCorrect =>
      'Entrainement enregistre : lecture marquee comme correcte';

  @override
  String get scannerCorrectOcrValuesTitle => 'Corriger les valeurs OCR';

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
  String get scannerSaveCorrection => 'Enregistrer la correction';

  @override
  String get scannerCorrectionSaved =>
      'Correction enregistree. Elle sera appliquee a des etiquettes similaires.';

  @override
  String get scannerSourceBarcode => 'Code-barres';

  @override
  String get scannerSourceOcrOpenFood => 'OCR du nom + Open Food Facts';

  @override
  String get scannerSourceOcrTable => 'OCR du tableau nutritionnel';

  @override
  String get scannerSourceAutoBarcodeOpenFood =>
      'Detection automatique (code-barres + Open Food Facts)';

  @override
  String get scannerSourceAutoOcrOpenFood =>
      'Detection automatique (OCR + Open Food Facts)';

  @override
  String get scannerSourceAutoOcrTable =>
      'Detection automatique (OCR du tableau nutritionnel)';

  @override
  String get scannerNoNutritionData =>
      'Les donnees nutritionnelles n\'ont pas pu etre obtenues. Prenez la photo avec une bonne lumiere, un texte net et en cadrant le tableau d\'informations nutritionnelles.';

  @override
  String scannerReadCompleted(Object source) {
    return 'Lecture terminee : $source';
  }

  @override
  String scannerAnalyzeError(Object error) {
    return 'Impossible d\'analyser l\'etiquette : $error';
  }

  @override
  String get scannerHeaderTitle => 'Scanner d\'etiquettes alimentaires';

  @override
  String get scannerHeaderTooltip => 'Informations completes sur le processus';

  @override
  String get scannerHeaderBody =>
      'Prenez une photo du code-barres d\'un produit ou selectionnez une image dans la galerie. Lorsque ce mode est active, NutriFit detecte automatiquement le code-barres, le nom du produit ou le tableau nutritionnel.';

  @override
  String get scannerPremiumBanner =>
      'Fonction Premium : vous pouvez entrer dans l\'ecran et voir les informations, mais Recherche, Photo et Galerie sont bloquees pour les utilisateurs non Premium.';

  @override
  String get scannerTrainingModeTitle => 'Mode d\'entrainement OCR';

  @override
  String get scannerTrainingModeSubtitle =>
      'Vous permet de corriger les lectures pour ameliorer les detections.';

  @override
  String get scannerModeLabel => 'Mode';

  @override
  String get scannerModeAuto => 'Mode automatique';

  @override
  String get scannerModeBarcode => 'Mode code-barres';

  @override
  String get scannerModeOcrTable => 'Mode tableau nutritionnel';

  @override
  String get scannerActionSearchOpenFood => 'Rechercher dans Open Food Facts';

  @override
  String get scannerAutoHint =>
      'En mode automatique, l\'application essaie d\'abord de detecter le code-barres et, si aucun produit valide n\'est trouve, elle essaie l\'OCR sur le nom ou le tableau nutritionnel.';

  @override
  String get scannerBarcodeHint =>
      'En mode code-barres, la camera affiche un cadre guide et l\'application analyse uniquement cette zone pour ameliorer la precision.';

  @override
  String get scannerOcrHint =>
      'En mode tableau nutritionnel, l\'application privilegie la lecture OCR du nom du produit et du tableau nutritionnel sans dependre du code-barres.';

  @override
  String get scannerDismissHintTooltip =>
      'Fermer (appuyez longuement sur le bouton du mode pour l\'afficher de nouveau)';

  @override
  String get scannerAnalyzing => 'Analyse de l\'etiquette...';

  @override
  String get scannerResultPerServing => 'Resultat par portion';

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
  String get scannerContactDietitianButton => 'Contacter le dieteticien';

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
      'Pour accéder à vos plans nutritionnels, vos plans d\'entraînement et vos recommandations personnalisées, vous devez d\'abord contacter votre diététicien/coach en ligne, qui vous attribuera un plan spécifique adapté à vos besoins.';

  @override
  String get restrictedAccessContactMethods => 'Moyens de contact :';

  @override
  String get restrictedAccessMoreContactOptions => 'Plus de moyens de contact';

  @override
  String get videosPremiumToolsMessage =>
      'La recherche, les filtres, les favoris, les mentions J\'aime et le tri complet des vidéos d\'exercices sont réservés aux utilisateurs Premium.';

  @override
  String get videosPremiumPlaybackMessage =>
      'La lecture complète des vidéos d\'exercices est réservée aux utilisateurs Premium.';

  @override
  String get videosPremiumTitle => 'Vidéos Premium';

  @override
  String get videosPremiumSubtitle =>
      'Le catalogue complet des vidéos d\'exercices est réservé aux utilisateurs Premium. Accédez à ';

  @override
  String videosPremiumPreviewHighlight(Object count) {
    return '$count vidéos exclusives.';
  }

  @override
  String get charlasPremiumToolsMessage =>
      'La recherche, les filtres, les favoris, les mentions J\'aime et le tri complet des conférences et séminaires sont réservés aux utilisateurs Premium.';

  @override
  String get charlasPremiumContentMessage =>
      'L\'accès complet au contenu de la conférence ou du séminaire est réservé aux utilisateurs Premium.';

  @override
  String get charlasPremiumTitle => 'Conférences Premium';

  @override
  String get charlasPremiumSubtitle =>
      'Le catalogue complet des conférences et séminaires est réservé aux utilisateurs Premium. Accédez à ';

  @override
  String charlasPremiumPreviewHighlight(Object count) {
    return '$count conférences exclusives.';
  }

  @override
  String get supplementsPremiumCopyPdfMessage =>
      'Pour copier un supplément et l\'exporter en PDF, vous devez être utilisateur Premium.';

  @override
  String get supplementsPremiumExploreMessage =>
      'Les hashtags et recommandations de suppléments sont réservés aux utilisateurs Premium.';

  @override
  String get supplementsPremiumToolsMessage =>
      'La recherche, l\'actualisation et le tri complet du catalogue des suppléments sont réservés aux utilisateurs Premium.';

  @override
  String get supplementsPremiumTitle => 'Suppléments Premium';

  @override
  String get supplementsPremiumSubtitle =>
      'Le catalogue complet des suppléments est réservé aux utilisateurs Premium.';

  @override
  String supplementsPremiumPreviewHighlight(Object count) {
    return '(avec plus de $count suppléments)';
  }

  @override
  String get exerciseCatalogPremiumToolsMessage =>
      'La recherche, les filtres, l\'actualisation et le tri complet du catalogue des exercices sont réservés aux utilisateurs Premium.';

  @override
  String get exerciseCatalogPremiumVideoMessage =>
      'La vidéo complète de l\'exercice est réservée aux utilisateurs Premium.';

  @override
  String get exerciseCatalogPremiumTitle => 'Exercices Premium';

  @override
  String get exerciseCatalogPremiumSubtitle =>
      'Le catalogue complet des exercices est réservé aux utilisateurs Premium.';

  @override
  String exerciseCatalogPremiumPreviewHighlight(Object count) {
    return '(avec plus de $count exercices)';
  }
}
