// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsAndPrivacyTitle => 'Settings and privacy';

  @override
  String get settingsAndPrivacyMenuLabel => 'Settings and privacy';

  @override
  String get configTabParameters => 'Parameters';

  @override
  String get configTabPremium => 'Premium';

  @override
  String get configTabAppMenu => 'App menu';

  @override
  String get configTabGeneral => 'General';

  @override
  String get configTabSecurity => 'Security';

  @override
  String get configTabUser => 'User';

  @override
  String get configTabDisplay => 'Display';

  @override
  String get configTabDefaults => 'Defaults';

  @override
  String get configTabPrivacy => 'Privacy';

  @override
  String get securitySubtabAccess => 'Access';

  @override
  String get securitySubtabEmailServer => 'Email server';

  @override
  String get securitySubtabCipher => 'Encrypt/Decrypt';

  @override
  String get securitySubtabSessions => 'Sessions';

  @override
  String get securitySubtabAccesses => 'Access logs';

  @override
  String get privacyCenterTab => 'Center';

  @override
  String get privacyPolicyTab => 'Policy';

  @override
  String get privacySessionsTab => 'Sessions';

  @override
  String privacyLastUpdatedLabel(Object date) {
    return 'Last updated: $date';
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
      'No session data is available for unregistered users, since access is anonymous.';

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
    return 'The app has been updated to version $version.';
  }

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonAgree => 'OK';

  @override
  String get commonLater => 'Later';

  @override
  String get commonValidate => 'Validate';

  @override
  String get commonToday => 'today';

  @override
  String get commonDebug => 'DEBUG';

  @override
  String get commonAllRightsReserved => 'All rights reserved';

  @override
  String get navHome => 'Home';

  @override
  String get navLogout => 'Sign out';

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
  String get navChatWithDietitian => 'Chat with dietitian';

  @override
  String get navContactDietitian => 'Contact dietitian';

  @override
  String get navEditProfile => 'Edit profile';

  @override
  String get profileEditProfileTab => 'Profile';

  @override
  String get profileEditSessionsTab => 'Sign-ins';

  @override
  String get profileEditPremiumBadgeTitle => 'Premium account';

  @override
  String get profileEditPremiumBadgeBody =>
      'You have access to exclusive features such as Exercise Videos.';

  @override
  String get profileEditNickLabel => 'Nickname / User';

  @override
  String get profileEditNickRequired => 'Nickname is required';

  @override
  String get profileEditEmailLabel => 'Email';

  @override
  String get profileEditInvalidEmail => 'Invalid email';

  @override
  String get profileEditEmailInUse =>
      'The email entered is not valid, please use another one';

  @override
  String get profileEditChangeEmailTooltip => 'Change email account';

  @override
  String get profileEditVerifyEmailCta => 'Verify email';

  @override
  String get profileEditTwoFactorShortLabel => 'Two-factor';

  @override
  String get profileEditBmiCardTitle => 'BMI data';

  @override
  String get profileEditBmiInfoTooltip => 'BMI/MVP information';

  @override
  String get profileEditBmiCardBody =>
      'To get BMI, MVP, and recommendations, complete Age and Height.';

  @override
  String get profileEditAgeLabel => 'Age';

  @override
  String get profileEditInvalidAge => 'Invalid age';

  @override
  String get profileEditHeightLabel => 'Height (cm)';

  @override
  String get profileEditInvalidHeight => 'Invalid height';

  @override
  String get profileEditPasswordCardTitle => 'Change password';

  @override
  String get profileEditPasswordHint =>
      'Leave blank to keep the current password';

  @override
  String get profileEditPasswordLabel => 'Password';

  @override
  String get profileEditPasswordConfirmLabel => 'Confirm password';

  @override
  String get profileEditPasswordConfirmRequired =>
      'You must confirm the password';

  @override
  String get profileEditPasswordMismatch => 'Passwords do not match';

  @override
  String get profileEditSaveChanges => 'Save changes';

  @override
  String get profileEditDeleteMyData => 'Delete all my data';

  @override
  String get profileEditChangeEmailTitle => 'Change email';

  @override
  String get profileEditChangeEmailVerifiedWarning =>
      'The current email is verified. If you change it, you will need to verify it again.';

  @override
  String get profileEditChangeEmailNewLabel => 'New email';

  @override
  String get profileEditChangeEmailRequired => 'You must enter an email.';

  @override
  String get profileEditChangeEmailMustDiffer =>
      'You must enter an email different from the current one.';

  @override
  String get profileEditChangeEmailValidationFailed =>
      'The email could not be validated. Please try again.';

  @override
  String get profileEditChangeEmailReview => 'Review the email entered.';

  @override
  String get profileEditEmailRequiredForVerification =>
      'You must enter an email account first.';

  @override
  String get profileEditEmailCodeSentGeneric => 'Code sent.';

  @override
  String get profileEditEmailVerifiedGeneric => 'Email verified.';

  @override
  String get profileEditEmailCodeLengthError => 'The code must have 10 digits.';

  @override
  String get profileEditEmailCodeDialogTitle => 'Validate email code';

  @override
  String get profileEditEmailCodeTenDigitsLabel => '10-digit code';

  @override
  String get profileEditValidateEmailCodeAction => 'Validate code';

  @override
  String get profileEditVerifyEmailTitle => 'Verify email';

  @override
  String get profileEditVerifyEmailIntroPrefix =>
      'Verifying your email will let you recover access by email if you forget your password and also ';

  @override
  String get profileEditVerifyEmailPremiumLink => 'subscribe to Premium';

  @override
  String get profileEditFollowTheseSteps => 'Follow these steps...';

  @override
  String get profileEditYourEmail => 'your email';

  @override
  String profileEditSendCodeInstruction(Object email) {
    return 'Tap \"Send code\" to send the verification code to $email.';
  }

  @override
  String get profileEditEmailCodeSentInfo =>
      'A code was sent to your email account. It will expire in 15 minutes. If you do not see it in Inbox, check the Spam folder.';

  @override
  String get profileEditEmailSendFailed =>
      'The verification email could not be sent at this time. Please try again later.';

  @override
  String get profileEditSendCodeAction => 'Send code';

  @override
  String get profileEditResendCodeAction => 'Send again';

  @override
  String get profileEditVerifyCodeInstruction =>
      'Check your email. You will have received an email with a code. Copy it, paste it here, and tap \"Verify\".';

  @override
  String get profileEditVerificationCodeLabel => 'Verification code';

  @override
  String get profileEditEmailRequiredInProfile =>
      'You must first enter an email in Edit Profile in order to verify it.';

  @override
  String get profileEditTwoFactorDialogTitle =>
      'Two-factor authentication (2FA)';

  @override
  String get profileEditTwoFactorEnabledStatus => 'Status: Enabled';

  @override
  String get profileEditTwoFactorEnabledBody =>
      'Two-factor authentication is already enabled on your account. From here you can only check whether this device is trusted and link or unlink it.';

  @override
  String get profileEditTrustedDeviceEnabledBody =>
      'This device is marked as trusted. The 2FA code will not be requested on future sign-ins until you remove the trust from here.';

  @override
  String get profileEditTrustedDeviceDisabledBody =>
      'This device is not marked as trusted. You can mark it by tapping \"Set this device as trusted\" or by signing out and signing in again, enabling the \"Trust this device\" checkbox during 2FA validation.';

  @override
  String get profileEditRemoveTrustedDeviceAction =>
      'Remove trust from this device';

  @override
  String get profileEditSetTrustedDeviceAction => 'Set this device as trusted';

  @override
  String get profileEditCancelProcess => 'Cancel process';

  @override
  String get profileEditSetTrustedDeviceTitle => 'Set trusted device';

  @override
  String get profileEditSetTrustedDeviceBody =>
      'To mark this device as trusted, you must validate it during 2FA sign-in by enabling the \"Trust this device\" checkbox.\n\nDo you want to sign out now to do that?';

  @override
  String get profileEditGoToLogin => 'Go to login';

  @override
  String get profileEditActivateTwoFactorTitle =>
      'Enable two-factor authentication';

  @override
  String get profileEditActivateTwoFactorIntro =>
      'Two-factor authentication (2FA) adds an extra layer of security: in addition to your password, a temporary code from your authenticator app is requested.';

  @override
  String get profileEditTwoFactorStep1 =>
      'Open your authenticator app (Google Authenticator, Microsoft Authenticator, Authy, etc.) and add an account.';

  @override
  String get profileEditTwoFactorSetupKeyLabel => 'Key to configure 2FA:';

  @override
  String get profileEditKeyCopied => 'Key copied to clipboard';

  @override
  String get profileEditHideOptions => 'Hide options';

  @override
  String get profileEditMoreOptions => 'More options...';

  @override
  String profileEditQrSavedDownloads(Object path) {
    return 'QR saved to Downloads: $path';
  }

  @override
  String get profileEditQrShared =>
      'The menu to share or save the QR code was opened.';

  @override
  String get profileEditOtpUrlCopied => 'otpauth URL copied';

  @override
  String get profileEditCopyUrl => 'Copy URL';

  @override
  String get profileEditOtpUrlInfo =>
      'The \"Copy URL\" option copies an otpauth link with the full 2FA configuration for importing into compatible apps. If your app does not allow link import, use \"Copy\" on the key.';

  @override
  String get profileEditTwoFactorConfirmCodeInstruction =>
      'Enter the 6-digit code shown by your authenticator app to confirm.';

  @override
  String get profileEditActivateTwoFactorAction => 'Enable';

  @override
  String get profileEditTwoFactorActivated =>
      'Two-factor authentication enabled successfully';

  @override
  String get profileEditTwoFactorActivateFailed => '2FA could not be enabled.';

  @override
  String get profileEditNoQrData => 'There is no data to save the QR code.';

  @override
  String profileEditQrSavedPath(Object path) {
    return 'QR saved to: $path';
  }

  @override
  String profileEditQrSaveFailed(Object error) {
    return 'The QR code could not be saved: $error';
  }

  @override
  String get profileEditDeactivateTwoFactorTitle =>
      'Disable two-factor authentication (2FA)';

  @override
  String get profileEditCurrentCodeSixDigitsLabel => 'Current 6-digit code';

  @override
  String get profileEditDeactivateTwoFactorAction => 'Disable';

  @override
  String get profileEditTwoFactorDeactivated =>
      'Two-factor authentication disabled successfully';

  @override
  String get profileEditTwoFactorDeactivateFailed =>
      '2FA could not be disabled.';

  @override
  String get profileEditRemoveTrustedDeviceTitle => 'Remove device trust';

  @override
  String get profileEditRemoveTrustedDeviceBody =>
      'On this device, the 2FA code will be requested again on the next sign-in. Do you want to continue?';

  @override
  String get profileEditRemoveTrustedDeviceActionShort => 'Remove trust';

  @override
  String get profileEditTrustedDeviceRemoved => 'Device trust removed.';

  @override
  String profileEditTrustedDeviceRemoveFailed(Object error) {
    return 'Could not remove device trust: $error';
  }

  @override
  String get profileEditMvpDialogTitle => 'MVP calculation and formulas';

  @override
  String get profileEditMvpWhatIsTitle => 'What is MVP?';

  @override
  String get profileEditMvpWhatIsBody =>
      'MVP is a minimum set of anthropometric indicators to help you easily monitor your health progress: BMI, waist-to-height, and waist-to-hip.';

  @override
  String get profileEditMvpFormulasTitle => 'Formulas used and their origin:';

  @override
  String get profileEditMvpOriginBmi =>
      'Source: WHO (adult BMI classification).';

  @override
  String get profileEditMvpOriginWhtr => 'Source: Waist-to-Height Ratio index.';

  @override
  String get profileEditMvpOriginWhr =>
      'Source: Waist-Hip Ratio (WHO, abdominal obesity).';

  @override
  String get profileEditImportantNotice => 'Important notice';

  @override
  String get profileEditMvpImportantNoticeBody =>
      'These calculations and classifications are indicative. For a personalized assessment, always consult a medical professional, dietitian-nutritionist, or personal trainer.';

  @override
  String get profileEditAccept => 'Accept';

  @override
  String get profileEditNotAvailable => 'N/A';

  @override
  String get profileEditSessionDate => 'Date';

  @override
  String get profileEditSessionTime => 'Time';

  @override
  String get profileEditSessionDevice => 'Device';

  @override
  String get profileEditSessionIp => 'IP address:';

  @override
  String get profileEditSessionPublicIp => 'Public';

  @override
  String get profileEditUserCodeUnavailable => 'User code not available';

  @override
  String get profileEditGenericError => 'Error';

  @override
  String get profileEditRetry => 'Retry';

  @override
  String get profileEditSessionDataUnavailable =>
      'Sign-in data could not be accessed at this time.';

  @override
  String get profileEditNoSessionData => 'No session data available';

  @override
  String get profileEditSuccessfulSessionsTitle => 'Latest successful sign-ins';

  @override
  String get profileEditCurrentSession => 'Current session:';

  @override
  String get profileEditPreviousSession => 'Previous session:';

  @override
  String get profileEditNoSuccessfulSessions =>
      'No successful sessions recorded';

  @override
  String get profileEditFailedAttemptsTitle => 'Latest failed sign-in attempts';

  @override
  String profileEditAttemptLabel(Object count) {
    return 'Attempt $count:';
  }

  @override
  String get profileEditNoFailedAttempts => 'No failed attempts recorded.';

  @override
  String get profileEditSessionStatsTitle => 'Session statistics';

  @override
  String profileEditTotalSessions(Object count) {
    return 'Total sessions: $count';
  }

  @override
  String profileEditSuccessfulAttempts(Object count) {
    return 'Successful attempts: $count';
  }

  @override
  String profileEditFailedAttempts(Object count) {
    return 'Failed attempts: $count';
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
  String get navWeightControl => 'Weight control';

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
  String get loginInvalidCredentials => 'Incorrect username or password.';

  @override
  String get loginFailedGeneric =>
      'Sign-in could not be completed. Please try again.';

  @override
  String get loginGuestFailedGeneric =>
      'Guest access could not be completed. Please try again.';

  @override
  String get loginUnknownUserType => 'Unknown user type';

  @override
  String get loginTwoFactorTitle => '2FA verification';

  @override
  String get loginTwoFactorPrompt =>
      'Enter the 6-digit code from your TOTP app.';

  @override
  String get loginTwoFactorCodeLabel => '2FA code';

  @override
  String get loginTrustThisDevice => 'Trust this device';

  @override
  String get loginTrustThisDeviceSubtitle =>
      '2FA will no longer be requested on this device.';

  @override
  String get loginCodeMustHave6Digits => 'The code must have 6 digits.';

  @override
  String get loginRecoveryTitle => 'Recover access';

  @override
  String get loginRecoveryIdentifierIntro =>
      'Enter your username (nick) or your email account to recover access.';

  @override
  String get loginUserOrEmailLabel => 'Username or email';

  @override
  String get loginEnterUserOrEmail => 'Enter a username or email.';

  @override
  String get loginNoRecoveryMethods =>
      'This user has no recovery methods available.';

  @override
  String get loginSelectRecoveryMethod => 'Select recovery method';

  @override
  String get loginRecoveryByEmail => 'Using your email';

  @override
  String get loginRecoveryByTwoFactor =>
      'Using two-factor authentication (2FA)';

  @override
  String get loginEmailRecoveryIntro =>
      'We will send you a recovery code by email. Enter it here along with your new password.';

  @override
  String get loginRecoveryStep1SendCode => 'Step 1: Send code';

  @override
  String get loginRecoveryStep1SendCodeBody =>
      'Tap \"Send code\" to receive a recovery code in your email.';

  @override
  String get loginSendCode => 'Send code';

  @override
  String get loginRecoveryStep2VerifyCode => 'Step 2: Verify code';

  @override
  String get loginRecoveryStep2VerifyCodeBody =>
      'Enter the code you received in your email.';

  @override
  String get loginRecoveryCodeLabel => 'Recovery code';

  @override
  String get loginRecoveryCodeHintAlpha => 'Ex. 1a3B';

  @override
  String get loginRecoveryCodeHintNumeric => 'Ex. 1234';

  @override
  String get loginVerifyCode => 'Verify code';

  @override
  String get loginRecoveryStep3NewPassword => 'Step 3: New password';

  @override
  String get loginRecoveryStep3NewPasswordBody => 'Enter your new password.';

  @override
  String get loginNewPasswordLabel => 'New password';

  @override
  String get loginRepeatNewPasswordLabel => 'Repeat new password';

  @override
  String get loginBothPasswordsRequired => 'Complete both password fields.';

  @override
  String get loginPasswordsMismatch => 'Passwords do not match.';

  @override
  String get loginPasswordResetSuccess =>
      'Password reset. You can sign in now.';

  @override
  String get loginTwoFactorRecoveryIntro =>
      'To reset your password using two-factor authentication, you need the temporary code from your app.';

  @override
  String get loginTwoFactorRecoveryStep1 =>
      'Step 1: Open your authenticator app';

  @override
  String get loginTwoFactorRecoveryStep1Body =>
      'Find the 6-digit temporary code in your authenticator app (Google Authenticator, Microsoft Authenticator, Authy, etc.)';

  @override
  String get loginIHaveIt => 'I have it';

  @override
  String get loginTwoFactorRecoveryStep2 => 'Step 2: Verify your 2FA code';

  @override
  String get loginTwoFactorRecoveryStep2Body =>
      'Enter the 6-digit code in the field below.';

  @override
  String get loginTwoFactorCodeSixDigitsLabel => '2FA code (6 digits)';

  @override
  String get loginTwoFactorCodeHint => '000000';

  @override
  String get loginVerifyTwoFactorCode => 'Verify 2FA code';

  @override
  String get loginCodeMustHaveExactly6Digits =>
      'The code must have exactly 6 digits.';

  @override
  String get loginPasswordUpdatedSuccess =>
      'Password updated. You can sign in now.';

  @override
  String get loginUsernameLabel => 'Username';

  @override
  String get loginEnterUsername => 'Enter your username';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginEnterPassword => 'Enter your password';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get loginForgotPassword => 'Forgot your password?';

  @override
  String get loginGuestInfo =>
      'Access NutriFit for free to browse health and nutrition tips, exercise videos, recipes, weight control, and much more.';

  @override
  String get loginGuestAccess => 'Access without credentials';

  @override
  String get loginRegisterFree => 'Register for free';

  @override
  String get registerCreateAccountTitle => 'Create account';

  @override
  String get registerFullNameLabel => 'Full name';

  @override
  String get registerEnterFullName => 'Enter your name';

  @override
  String get registerUsernameMinLength =>
      'The username must be at least 3 characters long';

  @override
  String get registerEmailLabel => 'Email';

  @override
  String get registerInvalidEmail => 'Invalid email address';

  @override
  String get registerAdditionalDataTitle => 'Additional data';

  @override
  String get registerAdditionalDataCollapsedSubtitle =>
      'Age and height (optional)';

  @override
  String get registerAdditionalDataExpandedSubtitle =>
      'Age and height for BMI/MVP';

  @override
  String get registerAdditionalDataInfo =>
      'To enable BMI, MVP, and health metrics calculations, enter your age and height in centimeters.';

  @override
  String get registerAgeLabel => 'Age';

  @override
  String get registerInvalidAge => 'Invalid age';

  @override
  String get registerHeightLabel => 'Height (cm)';

  @override
  String get registerInvalidHeight => 'Invalid height';

  @override
  String get registerConfirmPasswordLabel => 'Confirm password';

  @override
  String get registerConfirmPasswordRequired => 'Confirm your password';

  @override
  String get registerCreateAccountButton => 'Create account';

  @override
  String get registerAlreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get registerEmailUnavailable =>
      'This email account cannot be used. Please enter a different one.';

  @override
  String get registerSuccessMessage =>
      'User registered successfully. Please sign in with your username and password.';

  @override
  String get registerNetworkError =>
      'The process could not be completed. Please check your internet connection.';

  @override
  String get registerGenericError => 'Registration could not be completed';

  @override
  String get loginResetPassword => 'Reset password';

  @override
  String get loginEmailRecoverySendFailedGeneric =>
      'The recovery email could not be sent right now. Please try again later.';

  @override
  String get passwordChecklistTitle => 'Password requirements:';

  @override
  String passwordChecklistMinLength(Object count) {
    return 'Minimum $count characters';
  }

  @override
  String get passwordChecklistUpperLower =>
      'At least one uppercase and one lowercase letter';

  @override
  String get passwordChecklistNumber => 'At least one number (0-9)';

  @override
  String get passwordChecklistSpecial =>
      'At least one special character (*,.+-#\\\$?¿!¡_()/\\%&)';

  @override
  String loginPasswordMinLengthError(Object count) {
    return 'The new password must be at least $count characters long.';
  }

  @override
  String get loginPasswordUppercaseError =>
      'The new password must contain at least one uppercase letter.';

  @override
  String get loginPasswordLowercaseError =>
      'The new password must contain at least one lowercase letter.';

  @override
  String get loginPasswordNumberError =>
      'The new password must contain at least one number.';

  @override
  String get loginPasswordSpecialError =>
      'The new password must contain at least one special character (* , . + - # \\\$ ? ¿ ! ¡ _ ( ) / \\ % &).';

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
  String get patientAdherenceNutriPlan => 'Nutrition plan';

  @override
  String get patientAdherenceFitPlan => 'Fit plan';

  @override
  String get patientAdherenceCompleted => 'Completed';

  @override
  String get patientAdherencePartial => 'Partial';

  @override
  String get patientAdherenceNotDone => 'Not completed';

  @override
  String get patientAdherenceNoChanges => 'No changes';

  @override
  String patientAdherenceTrendPoints(Object trend) {
    return '$trend pts';
  }

  @override
  String get patientAdherenceTitle => 'Adherence';

  @override
  String get patientAdherenceImprovementPoints => 'Improvement points';

  @override
  String get patientAdherenceImprovementNutriTarget =>
      'Nutrition: try to meet the plan at least 5 out of 7 days this week.';

  @override
  String get patientAdherenceImprovementNutriTrend =>
      'Nutrition: you are trending down compared with last week; return to your base routine.';

  @override
  String get patientAdherenceImprovementFitTarget =>
      'Fit: try to reach 3-4 sessions this week, even if they are short.';

  @override
  String get patientAdherenceImprovementFitTrend =>
      'Fit: the trend has dropped; schedule your next sessions today.';

  @override
  String get patientAdherenceImprovementKeepGoing =>
      'Good pace. Stay consistent to consolidate results.';

  @override
  String get patientAdherenceSheetTitleToday => 'Adherence for today';

  @override
  String patientAdherenceSheetTitleForDate(Object date) {
    return 'Adherence for $date';
  }

  @override
  String get patientAdherenceDateToday => 'today';

  @override
  String patientAdherenceStatusSaved(Object plan, Object status, Object date) {
    return '$plan: $status $date';
  }

  @override
  String get patientAdherenceFutureDateError =>
      'Adherence cannot be recorded for future dates. Only today or previous days are allowed.';

  @override
  String get patientAdherenceReasonNotDoneTitle =>
      'Reason for not completing it';

  @override
  String get patientAdherenceReasonPartialTitle =>
      'Reason for partial completion';

  @override
  String get patientAdherenceReasonHint =>
      'Briefly tell us what happened today';

  @override
  String get patientAdherenceSkipReason => 'Skip reason';

  @override
  String get patientAdherenceSaveContinue => 'Save and continue';

  @override
  String patientAdherenceSaveError(Object error) {
    return 'Could not save to the database: $error';
  }

  @override
  String get patientAdherenceReasonLabel => 'Reason';

  @override
  String get patientAdherenceInfoTitle =>
      'What does each adherence status mean?';

  @override
  String get patientAdherenceNutriCompletedDescription =>
      'You followed the nutrition plan exactly as planned for this day.';

  @override
  String get patientAdherenceNutriPartialDescription =>
      'You followed part of the plan but not completely: a meal was skipped, changed, or had a different quantity.';

  @override
  String get patientAdherenceNutriNotDoneDescription =>
      'You did not follow the nutrition plan on this day.';

  @override
  String get patientAdherenceFitCompletedDescription =>
      'You completed the full workout planned for this day.';

  @override
  String get patientAdherenceFitPartialDescription =>
      'You completed part of the workout: some exercises, sets, or duration were incomplete.';

  @override
  String get patientAdherenceFitNotDoneDescription =>
      'You did not complete the workout on this day.';

  @override
  String get patientAdherenceAlertRecoveryTitle => 'Time to react';

  @override
  String patientAdherenceAlertRecoveryBody(Object plan) {
    return 'You have been below 50% for two weeks in a row in $plan. Let\'s recover the rhythm now: small daily steps, but without missing. You can do it, but it is time to get serious.';
  }

  @override
  String get patientAdherenceAlertEncouragementTitle => 'There is still time';

  @override
  String patientAdherenceAlertEncouragementBody(Object plan) {
    return 'This week $plan is below 50%. Next week can be much better: return to your base routine and add one win each day.';
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
  String get patientContactDietitianPrompt => 'Contact the dietitian...';

  @override
  String get patientContactDietitianTrainer => 'Contact Dietitian/Trainer';

  @override
  String get contactDietitianMethodsTitle => 'Contact methods';

  @override
  String get contactDietitianEmailLabel => 'Email';

  @override
  String get contactDietitianCallLabel => 'Call';

  @override
  String get contactDietitianSocialTitle => 'Follow us on social media';

  @override
  String get contactDietitianWebsiteLabel => 'Website';

  @override
  String get contactDietitianPhoneCopied => 'Phone number copied to clipboard.';

  @override
  String get contactDietitianWhatsappInvalidPhone =>
      'There is no valid phone number to open WhatsApp.';

  @override
  String contactDietitianWhatsappOpenError(Object error) {
    return 'Could not open WhatsApp: $error';
  }

  @override
  String get contactDietitianWhatsappDialogTitle => 'Contact via WhatsApp';

  @override
  String contactDietitianWhatsappDialogBody(Object phone) {
    return 'You can open the WhatsApp chat directly with the number $phone. You can also copy the number to the clipboard to use it in your WhatsApp application or save it.';
  }

  @override
  String get contactDietitianCopyPhone => 'Copy phone';

  @override
  String get contactDietitianOpenWhatsapp => 'Open WhatsApp';

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
  String get chatMessageHint => 'Write a message';

  @override
  String get profileImagePickerDialogTitle => 'Select profile image';

  @override
  String get profileImagePickerTakePhoto => 'Take photo';

  @override
  String get profileImagePickerChooseFromGallery => 'Choose from gallery';

  @override
  String get profileImagePickerSelectImage => 'Select image';

  @override
  String get profileImagePickerRemovePhoto => 'Remove photo';

  @override
  String get profileImagePickerPrompt => 'Select your profile image';

  @override
  String profileImagePickerMaxDimensions(Object width, Object height) {
    return 'Max. ${width}x${height}px';
  }

  @override
  String profileImagePickerSaved(Object sizeKb) {
    return 'Image saved successfully (${sizeKb}KB)';
  }

  @override
  String get profileImagePickerProcessError => 'Error processing image';

  @override
  String get profileImagePickerTechnicalDetails => 'Technical details';

  @override
  String get profileImagePickerOperationFailed =>
      'The operation could not be completed. Please try again or contact support.';

  @override
  String get shoppingListPremiumTitle => 'Premium shopping list';

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
  String get weightControlBack => 'Back';

  @override
  String get weightControlChangeTarget => 'Change target weight';

  @override
  String get weightControlHideFilter => 'Hide filter';

  @override
  String get weightControlShowFilter => 'Show filter';

  @override
  String get weightControlGuestMessage =>
      'To manage your weight tracking, you need to sign up. It\'s free.';

  @override
  String weightControlLoadError(Object error) {
    return 'Error loading measurements: $error';
  }

  @override
  String get weightControlNoMeasurementsTitle =>
      'There are no measurements recorded yet.';

  @override
  String get weightControlNoMeasurementsBody =>
      'Start by adding your first measurement to see your progress.';

  @override
  String get weightControlAddMeasurement => 'Add measurement';

  @override
  String weightControlNoWeightsForPeriod(Object period) {
    return 'There are no weights for $period.';
  }

  @override
  String weightControlNoMeasurementsForPeriod(Object period) {
    return 'There are no measurements for $period.';
  }

  @override
  String get weightControlPremiumPerimetersTitle =>
      'Premium perimeter evolution';

  @override
  String get weightControlPremiumChartBody =>
      'This chart is available only for Premium users. Activate your account to see your full progress with advanced visual indicators.';

  @override
  String get weightControlCurrentMonth => 'Current month';

  @override
  String get weightControlPreviousMonth => 'Previous month';

  @override
  String get weightControlQuarter => 'Quarter';

  @override
  String get weightControlSemester => 'Semester';

  @override
  String get weightControlCurrentYear => 'Year';

  @override
  String get weightControlPreviousYear => 'Previous year';

  @override
  String get weightControlAllTime => 'All time';

  @override
  String weightControlLastDaysLabel(Object days) {
    return 'Last $days days';
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
  String get commonPremiumFeatureTitle => 'Premium feature';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonMoreOptions => 'More options';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonGeneratePdf => 'Generate PDF';

  @override
  String get commonHideSearch => 'Hide search';

  @override
  String get commonFilterByCategories => 'Filter by categories';

  @override
  String commonFilterByCategoriesCount(Object count) {
    return 'Filter categories ($count)';
  }

  @override
  String get commonMatchAll => 'Match all';

  @override
  String get commonRequireAllSelected =>
      'If enabled, all selected items are required.';

  @override
  String commonCategoryFallback(Object id) {
    return 'Category $id';
  }

  @override
  String get commonSignInToLike => 'You must sign in to like this';

  @override
  String get commonSignInToSaveFavorites =>
      'You must sign in to save favorites';

  @override
  String get commonCouldNotIdentifyUser =>
      'Error: The user could not be identified';

  @override
  String commonLikeChangeError(Object error) {
    return 'Error changing like status. $error';
  }

  @override
  String commonFavoriteChangeError(Object error) {
    return 'Error changing favorite status. $error';
  }

  @override
  String commonGuestFavoritesRequiresRegistration(Object itemType) {
    return 'To mark $itemType as favorites, you must register first. It\'s free.';
  }

  @override
  String get commonRecipesAndTipsPremiumCopyPdfMessage =>
      'To copy recipes and tips and export them as PDF, you must be a Premium user.';

  @override
  String get commonCopiedToClipboard => 'Copied to clipboard';

  @override
  String commonCopiedToClipboardLabel(Object label) {
    return '$label copied to the clipboard.';
  }

  @override
  String get commonLanguage => 'Language';

  @override
  String get commonUser => 'user';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageItalian => 'Italian';

  @override
  String get languageGerman => 'German';

  @override
  String get languageFrench => 'French';

  @override
  String get languagePortuguese => 'Portuguese';

  @override
  String commonCopyError(Object error) {
    return 'Error copying: $error';
  }

  @override
  String commonGeneratePdfError(Object error) {
    return 'Error generating PDF: $error';
  }

  @override
  String commonOpenLinkError(Object error) {
    return 'Error opening link: $error';
  }

  @override
  String get commonDocumentUnavailable => 'The document is not available';

  @override
  String commonDecodeError(Object error) {
    return 'Decoding error: $error';
  }

  @override
  String get commonSaveDocumentError =>
      'Error: The document could not be saved';

  @override
  String commonOpenDocumentError(Object error) {
    return 'Error opening document: $error';
  }

  @override
  String get commonDownloadDocument => 'Download document';

  @override
  String get commonDocumentsAndLinks => 'Documents and links';

  @override
  String get commonYouMayAlsoLike => 'You may also like...';

  @override
  String get commonSortByTitle => 'Sort by title';

  @override
  String get commonSortByRecent => 'Sort by recent';

  @override
  String get commonSortByPopular => 'Sort by popular';

  @override
  String get commonPersonalTab => 'Personal';

  @override
  String get commonFeaturedTab => 'Featured';

  @override
  String get commonAllTab => 'All';

  @override
  String get commonFavoritesTab => 'Favorites';

  @override
  String get commonFeaturedFeminineTab => 'Featured';

  @override
  String get commonAllFeminineTab => 'All';

  @override
  String get commonFavoritesFeminineTab => 'Favorites';

  @override
  String commonLikesCount(Object count) {
    return '$count likes';
  }

  @override
  String get commonLink => 'Link';

  @override
  String get commonTipItem => 'tip';

  @override
  String get commonRecipeItem => 'recipe';

  @override
  String get commonAdditiveItem => 'additive';

  @override
  String get commonSupplementItem => 'supplement';

  @override
  String commonSeeLinkToType(Object type) {
    return 'See link to $type';
  }

  @override
  String get commonDocument => 'Document';

  @override
  String get todoPriorityHigh => 'High';

  @override
  String get todoPriorityMedium => 'Medium';

  @override
  String get todoPriorityLow => 'Low';

  @override
  String get todoStatusPending => 'Pending';

  @override
  String get todoStatusResolved => 'Resolved';

  @override
  String todoCalendarPriority(Object value) {
    return 'Priority: $value';
  }

  @override
  String todoCalendarStatus(Object value) {
    return 'Status: $value';
  }

  @override
  String todoExportError(Object error) {
    return 'Error exporting task: $error';
  }

  @override
  String get todoDateRequiredForCalendar =>
      'The task must have a date to add it to the calendar';

  @override
  String todoAddToCalendarError(Object error) {
    return 'The task could not be added to the calendar: $error';
  }

  @override
  String todoPremiumLimitMessage(int limit) {
    return 'As a non-Premium user, you can create up to $limit tasks. Go Premium to add unlimited tasks and view your full history.';
  }

  @override
  String get todoNoDate => 'No date';

  @override
  String get todoPriorityHighTooltip => 'High priority';

  @override
  String get todoPriorityMediumTooltip => 'Medium priority';

  @override
  String get todoPriorityLowTooltip => 'Low priority';

  @override
  String get todoStatusResolvedShort => 'Completed (R)';

  @override
  String get todoStatusPendingShort => 'Pending (P)';

  @override
  String get todoMarkPending => 'Mark as pending';

  @override
  String get todoMarkResolved => 'Mark as resolved';

  @override
  String get todoEditTaskTitle => 'Edit task';

  @override
  String get todoNewTaskTitle => 'New task';

  @override
  String get todoTitleLabel => 'Title';

  @override
  String get todoTitleRequired => 'Title is required';

  @override
  String get todoDescriptionTitle => 'Description';

  @override
  String get todoDescriptionOptionalLabel => 'Description (optional)';

  @override
  String get todoPriorityTitle => 'Priority';

  @override
  String get todoStatusTitle => 'Status';

  @override
  String todoTasksForDay(Object date) {
    return 'Tasks for $date';
  }

  @override
  String get todoNewShort => 'New';

  @override
  String get todoNoTasksSelectedDay =>
      'There are no tasks for the selected day.';

  @override
  String get todoNoTasksToShow => 'There are no tasks to show.';

  @override
  String get todoPremiumTitle => 'Premium tasks';

  @override
  String todoPremiumPreviewSubtitle(int limit) {
    return 'You can review the latest $limit entries and create up to $limit tasks. If you want unlimited tasks, go Premium.';
  }

  @override
  String todoPremiumPreviewHighlight(int count) {
    return ' You currently have $count registered tasks.';
  }

  @override
  String get todoEmptyState => 'You do not have any tasks yet.';

  @override
  String get todoScreenTitle => 'Tasks';

  @override
  String get todoTabPending => 'Pending';

  @override
  String get todoTabResolved => 'Resolved';

  @override
  String get todoTabAll => 'All';

  @override
  String get todoHideFilters => 'Hide filters';

  @override
  String get todoViewList => 'View list';

  @override
  String get todoViewCalendar => 'View calendar';

  @override
  String get todoSortByDate => 'Sort by date';

  @override
  String get todoSortByPriority => 'Sort by priority';

  @override
  String get todoSearchHint => 'Search by title or description';

  @override
  String get todoClearSearch => 'Clear search';

  @override
  String get todoDeleteTitle => 'Delete task';

  @override
  String todoDeleteConfirm(Object title) {
    return 'Do you want to delete the task \"$title\"?';
  }

  @override
  String get todoDeletedSuccess => 'Task deleted successfully';

  @override
  String get todoAddToDeviceCalendar => 'Add to device calendar';

  @override
  String get todoEditAction => 'Edit';

  @override
  String get todoSelectDate => 'Select date';

  @override
  String get todoRemoveDate => 'Remove date';

  @override
  String get todoGuestTitle => 'Registration required';

  @override
  String get todoGuestBody =>
      'To use Tasks, you must register first. It\'s free.';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSortByName => 'Sort by name';

  @override
  String get commonSortByType => 'Sort by type';

  @override
  String get commonSortByDate => 'Sort by date';

  @override
  String get commonSortBySeverity => 'Sort by severity';

  @override
  String get commonName => 'Name';

  @override
  String get commonTitleField => 'Title';

  @override
  String get commonDescriptionField => 'Description';

  @override
  String get commonTypeField => 'Type';

  @override
  String get commonSeverity => 'Severity';

  @override
  String commonNoResultsForQuery(Object query) {
    return 'No results for \"$query\"';
  }

  @override
  String get tipsPremiumToolsMessage =>
      'Search, filters, favorites, likes, and full access to the tips catalog are available only for Premium users.';

  @override
  String get tipsPremiumPreviewTitle => 'Premium tips';

  @override
  String get tipsPremiumPreviewSubtitle =>
      'You can see a preview of the latest 3 tips. Go Premium to access the full catalog and all its tools.';

  @override
  String tipsPreviewAvailableCount(Object count) {
    return ' There are currently $count tips available.';
  }

  @override
  String get tipsSearchLabel => 'Search tips';

  @override
  String get tipsNoPersonalizedRecommendations =>
      'No personalized recommendations';

  @override
  String get tipsViewGeneralTips => 'View general tips';

  @override
  String get tipsUnreadBadge => 'Unread';

  @override
  String get messagesInboxTitle => 'Unread messages';

  @override
  String get messagesInboxGuestBody =>
      'To chat online with your dietitian, please register first. It\'s free.';

  @override
  String get messagesInboxGuestAction => 'Start registration';

  @override
  String get messagesInboxUnreadChats => 'Unread chats';

  @override
  String get messagesInboxNoPendingChats => 'There are no pending chats.';

  @override
  String get messagesInboxUser => 'User';

  @override
  String get messagesInboxImage => 'Image';

  @override
  String get messagesInboxNoMessages => 'No messages';

  @override
  String get messagesInboxPendingExerciseFeelings =>
      'Pending exercise feedback';

  @override
  String get messagesInboxNoPendingExerciseFeelings =>
      'There is no pending exercise feedback.';

  @override
  String get messagesInboxViewPendingExerciseFeelings =>
      'View pending exercise feedback';

  @override
  String get messagesInboxUnreadDietitianChats => 'Unread dietitian chats';

  @override
  String get messagesInboxOpenDietitianChat => 'Open chat with dietitian';

  @override
  String get messagesInboxMessage => 'Message';

  @override
  String get messagesInboxDietitianMessage => 'Message from dietitian';

  @override
  String get messagesInboxUnreadCoachComments => 'Unread coach comments';

  @override
  String get messagesInboxNoUnreadCoachComments =>
      'You have no personal trainer comments pending to read.';

  @override
  String get messagesInboxViewPendingComments => 'View pending comments';

  @override
  String messagesInboxLoadError(Object error) {
    return 'Error loading messages: $error';
  }

  @override
  String get tipsNoFeaturedAvailable => 'No featured tips';

  @override
  String get tipsNoTipsAvailable => 'No tips available';

  @override
  String get tipsNoFavoriteTips => 'You have no favorite tips';

  @override
  String get tipsDetailTitle => 'Tip details';

  @override
  String get tipsPreviewBanner =>
      'Preview - This is how users will see the tip';

  @override
  String tipsHashtagTitle(Object hashtag) {
    return 'Tips with $hashtag';
  }

  @override
  String tipsHashtagEmpty(Object hashtag) {
    return 'There are no tips with $hashtag';
  }

  @override
  String tipsLoadErrorStatus(Object statusCode) {
    return 'Error loading tips: $statusCode';
  }

  @override
  String tipsLoadError(Object error) {
    return 'Error loading tips. $error';
  }

  @override
  String get recipesPremiumToolsMessage =>
      'Search, filters, favorites, likes, and full access to the recipes catalog are available only for Premium users.';

  @override
  String get recipesPremiumPreviewTitle => 'Premium recipes';

  @override
  String get recipesPremiumPreviewSubtitle =>
      'You can see a preview of the latest 3 recipes. Go Premium to access the full catalog and all its tools.';

  @override
  String recipesPreviewAvailableCount(Object count) {
    return ' There are currently $count recipes available.';
  }

  @override
  String get recipesSearchLabel => 'Search recipes';

  @override
  String get recipesNoFeaturedAvailable => 'No featured recipes';

  @override
  String get recipesNoRecipesAvailable => 'No recipes available';

  @override
  String get recipesNoFavoriteRecipes => 'You have no favorite recipes';

  @override
  String get recipesDetailTitle => 'Recipe details';

  @override
  String get recipesPreviewBanner =>
      'Preview - This is how users will see the recipe';

  @override
  String recipesHashtagTitle(Object hashtag) {
    return 'Recipes with $hashtag';
  }

  @override
  String recipesHashtagEmpty(Object hashtag) {
    return 'There are no recipes with $hashtag';
  }

  @override
  String get additivesPremiumCopyPdfMessage =>
      'To copy an additive and export it to PDF, you must be a Premium user.';

  @override
  String get additivesPremiumExploreMessage =>
      'Hashtags and additive recommendations are available only for Premium users.';

  @override
  String get additivesPremiumToolsMessage =>
      'Search, filters, refresh, and full sorting of the additives catalog are available only for Premium users.';

  @override
  String get additivesFilterTitle => 'Filter additives';

  @override
  String get additivesNoConfiguredTypes =>
      'There are no types configured in tipos_aditivos.';

  @override
  String get additivesTypesLabel => 'Types';

  @override
  String get additivesSearchHint => 'Search additives';

  @override
  String get additivesEmpty => 'No additives available';

  @override
  String get additivesPremiumTitle => 'Premium additives';

  @override
  String get additivesPremiumSubtitle =>
      'The full additives catalog is available only for Premium users.';

  @override
  String additivesCatalogHighlight(Object count) {
    return ' (with more than $count additives)';
  }

  @override
  String get additivesLoadFailed => 'Additives could not be loaded.';

  @override
  String get additivesCatalogUnavailable =>
      'The additives catalog is temporarily unavailable. Please try again later.';

  @override
  String get additivesServerConnectionError =>
      'Could not connect to the server. Check your connection and try again.';

  @override
  String get additivesSeveritySafe => 'Safe';

  @override
  String get additivesSeverityAttention => 'Caution';

  @override
  String get additivesSeverityHigh => 'High';

  @override
  String get additivesSeverityRestricted => 'Restricted';

  @override
  String get additivesSeverityForbidden => 'Forbidden';

  @override
  String get substitutionsPremiumToolsMessage =>
      'Search, filters, favorites, and full sorting of healthy substitutions are available only for Premium users.';

  @override
  String get substitutionsPremiumCopyPdfMessage =>
      'To copy a healthy substitution and export it to PDF, you must be a Premium user.';

  @override
  String get substitutionsPremiumExploreMessage =>
      'Hashtags, categories, recommendations, and advanced navigation for healthy substitutions are available only for Premium users.';

  @override
  String get substitutionsPremiumEngagementMessage =>
      'Favorites and likes for healthy substitutions are available only for Premium users.';

  @override
  String get substitutionsSearchLabel => 'Search substitutions or hashtags';

  @override
  String get substitutionsEmptyFeatured => 'No featured substitutions.';

  @override
  String get substitutionsEmptyAll => 'No substitutions available.';

  @override
  String get substitutionsEmptyFavorites =>
      'You do not have favorite substitutions yet.';

  @override
  String get substitutionsPremiumTitle => 'Premium substitutions';

  @override
  String get substitutionsPremiumSubtitle =>
      'The full healthy substitutions library is available only for Premium users.';

  @override
  String substitutionsCatalogHighlight(Object count) {
    return ' (with more than $count substitutions)';
  }

  @override
  String get substitutionsDefaultBadge => 'Premium substitution';

  @override
  String get substitutionsTapForDetail => 'Tap to view the full detail';

  @override
  String get substitutionsDetailTitle => 'Healthy substitution';

  @override
  String get substitutionsRecommendedChange => 'Recommended change';

  @override
  String get substitutionsIfUnavailable => 'If you do not have';

  @override
  String get substitutionsUse => 'Use';

  @override
  String get substitutionsEquivalence => 'Equivalent amount';

  @override
  String get substitutionsGoal => 'Goal';

  @override
  String get substitutionsNotesContext => 'Sustitución saludable';

  @override
  String get commonExport => 'Export';

  @override
  String get commonImport => 'Import';

  @override
  String get commonPhoto => 'Photo';

  @override
  String get commonGallery => 'Gallery';

  @override
  String get commonUnavailable => 'Unavailable';

  @override
  String get scannerTitle => 'Label scanner';

  @override
  String get scannerPremiumRequiredMessage =>
      'Scanning, opening gallery images, and searching products from the scanner are available only for Premium users.';

  @override
  String get scannerClearTrainingTitle => 'Clear OCR training';

  @override
  String get scannerClearTrainingBody =>
      'All corrections saved on this device will be deleted. Do you want to continue?';

  @override
  String get scannerLocalTrainingRemoved => 'Local OCR training removed';

  @override
  String get scannerExportRulesTitle => 'Export OCR rules';

  @override
  String get scannerImportRulesTitle => 'Import OCR rules';

  @override
  String get scannerImportRulesHint => 'Paste the exported JSON here';

  @override
  String get scannerInvalidFormat => 'Invalid format';

  @override
  String get scannerInvalidJsonOrCanceled => 'Invalid JSON or import canceled';

  @override
  String scannerImportedRulesCount(Object count) {
    return 'Imported $count training rules';
  }

  @override
  String get scannerRulesUploaded => 'OCR rules uploaded to the server';

  @override
  String scannerRulesUploadError(Object error) {
    return 'Error uploading rules: $error';
  }

  @override
  String get scannerNoRemoteRules => 'No remote rules available.';

  @override
  String scannerDownloadedRulesCount(Object count) {
    return 'Downloaded $count rules from the server';
  }

  @override
  String scannerRulesDownloadError(Object error) {
    return 'Error downloading rules: $error';
  }

  @override
  String get scannerTrainingMarkedCorrect =>
      'Training saved: reading marked as correct';

  @override
  String get scannerCorrectOcrValuesTitle => 'Correct OCR values';

  @override
  String get scannerSugarField => 'Sugar (g)';

  @override
  String get scannerSaltField => 'Salt (g)';

  @override
  String get scannerFatField => 'Fat (g)';

  @override
  String get scannerProteinField => 'Protein (g)';

  @override
  String get scannerPortionField => 'Serving (g)';

  @override
  String get scannerSaveCorrection => 'Save correction';

  @override
  String get scannerCorrectionSaved =>
      'Correction saved. It will be applied to similar labels.';

  @override
  String get scannerSourceBarcode => 'Barcode';

  @override
  String get scannerSourceOcrOpenFood => 'Name OCR + Open Food Facts';

  @override
  String get scannerSourceOcrTable => 'Nutrition table OCR';

  @override
  String get scannerSourceAutoBarcodeOpenFood =>
      'Automatic detection (barcode + Open Food Facts)';

  @override
  String get scannerSourceAutoOcrOpenFood =>
      'Automatic detection (OCR + Open Food Facts)';

  @override
  String get scannerSourceAutoOcrTable =>
      'Automatic detection (nutrition table OCR)';

  @override
  String get scannerNoNutritionData =>
      'Nutrition data could not be obtained. Take the photo in good lighting, with sharp focused text, and framing the nutrition information table.';

  @override
  String scannerReadCompleted(Object source) {
    return 'Reading completed: $source';
  }

  @override
  String scannerAnalyzeError(Object error) {
    return 'Could not analyze the label: $error';
  }

  @override
  String get scannerHeaderTitle => 'Food label scanner';

  @override
  String get scannerHeaderTooltip => 'Full process information';

  @override
  String get scannerHeaderBody =>
      'Take a photo of a product barcode or select an image from the gallery. When this mode is enabled, NutriFit will automatically detect the barcode, product name, or nutrition table.';

  @override
  String get scannerPremiumBanner =>
      'Premium feature: you can enter the screen and view the information, but Search, Photo, and Gallery are blocked for non-Premium users.';

  @override
  String get scannerTrainingModeTitle => 'OCR training mode';

  @override
  String get scannerTrainingModeSubtitle =>
      'Lets you correct readings to improve detections.';

  @override
  String get scannerModeLabel => 'Mode';

  @override
  String get scannerModeAuto => 'Automatic mode';

  @override
  String get scannerModeBarcode => 'Barcode mode';

  @override
  String get scannerModeOcrTable => 'Nutrition table mode';

  @override
  String get scannerActionSearchOpenFood => 'Search in Open Food Facts';

  @override
  String get scannerAutoHint =>
      'In automatic mode, the app first tries to detect the barcode and, if it cannot find a valid product, it tries OCR on the name or the nutrition table.';

  @override
  String get scannerBarcodeHint =>
      'In barcode mode, the camera shows a guide frame and the app analyzes only that area to improve accuracy.';

  @override
  String get scannerOcrHint =>
      'In nutrition table mode, the app prioritizes OCR reading of the product name and nutrition table without relying on the barcode.';

  @override
  String get scannerDismissHintTooltip =>
      'Close (long press the mode button to show it again)';

  @override
  String get scannerAnalyzing => 'Analyzing label...';

  @override
  String get scannerResultPerServing => 'Per-serving result';

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
  String get scannerContactDietitianButton => 'Contact dietitian';

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
      'To access your nutrition plans, training plans, and personalized recommendations, you first need to contact your online dietitian/coach, who will assign you a specific plan tailored to your needs.';

  @override
  String get restrictedAccessContactMethods => 'Contact methods:';

  @override
  String get restrictedAccessMoreContactOptions => 'More contact options';

  @override
  String get videosPremiumToolsMessage =>
      'Search, filters, favorites, likes, and full sorting of exercise videos are available only for Premium users.';

  @override
  String get videosPremiumPlaybackMessage =>
      'Full playback of exercise videos is available only for Premium users.';

  @override
  String get videosPremiumTitle => 'Premium videos';

  @override
  String get videosPremiumSubtitle =>
      'The full exercise videos catalog is available only for Premium users. Access ';

  @override
  String videosPremiumPreviewHighlight(Object count) {
    return '$count exclusive videos.';
  }

  @override
  String get charlasPremiumToolsMessage =>
      'Search, filters, favorites, likes, and full sorting of talks and seminars are available only for Premium users.';

  @override
  String get charlasPremiumContentMessage =>
      'Full access to the talk or seminar content is available only for Premium users.';

  @override
  String get charlasPremiumTitle => 'Premium talks';

  @override
  String get charlasPremiumSubtitle =>
      'The full talks and seminars catalog is available only for Premium users. Access ';

  @override
  String charlasPremiumPreviewHighlight(Object count) {
    return '$count exclusive talks.';
  }

  @override
  String get supplementsPremiumCopyPdfMessage =>
      'To copy a supplement and export it to PDF, you must be a Premium user.';

  @override
  String get supplementsPremiumExploreMessage =>
      'Hashtags and supplement recommendations are available only for Premium users.';

  @override
  String get supplementsPremiumToolsMessage =>
      'Search, refresh, and full sorting of the supplements catalog are available only for Premium users.';

  @override
  String get supplementsPremiumTitle => 'Premium supplements';

  @override
  String get supplementsPremiumSubtitle =>
      'The full supplements catalog is available only for Premium users.';

  @override
  String supplementsPremiumPreviewHighlight(Object count) {
    return '(with more than $count supplements)';
  }

  @override
  String get exerciseCatalogPremiumToolsMessage =>
      'Search, filters, refresh, and full sorting of the exercise catalog are available only for Premium users.';

  @override
  String get exerciseCatalogPremiumVideoMessage =>
      'The full exercise video is available only for Premium users.';

  @override
  String get exerciseCatalogPremiumTitle => 'Premium exercises';

  @override
  String get exerciseCatalogPremiumSubtitle =>
      'The full exercise catalog is available only for Premium users.';

  @override
  String exerciseCatalogPremiumPreviewHighlight(Object count) {
    return '(with more than $count exercises)';
  }
}
