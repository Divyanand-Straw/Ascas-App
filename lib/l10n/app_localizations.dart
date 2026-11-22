import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ta.dart';

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
    Locale('en'),
    Locale('ta'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Thaai Seyali'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcome;

  /// No description provided for @upcomingAppointments.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Appointments'**
  String get upcomingAppointments;

  /// No description provided for @treatmentOverview.
  ///
  /// In en, this message translates to:
  /// **'Treatment Overview'**
  String get treatmentOverview;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPassword;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Preferred Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @tamil.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get tamil;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @clinicianSupported.
  ///
  /// In en, this message translates to:
  /// **'Clinician-supported'**
  String get clinicianSupported;

  /// No description provided for @yourFertilityJourney.
  ///
  /// In en, this message translates to:
  /// **'Your fertility\njourney,\nour care.'**
  String get yourFertilityJourney;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Expert guidance, thoughtful support, and every step of your care in one private place.'**
  String get welcomeDescription;

  /// No description provided for @privateConnectedCare.
  ///
  /// In en, this message translates to:
  /// **'Private, connected care from Thaai Seyali Fertility and Women’s Centre.'**
  String get privateConnectedCare;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @newPatientRegistration.
  ///
  /// In en, this message translates to:
  /// **'NEW PATIENT REGISTRATION'**
  String get newPatientRegistration;

  /// No description provided for @letsBegin.
  ///
  /// In en, this message translates to:
  /// **'Let\'s begin with you'**
  String get letsBegin;

  /// No description provided for @encryptedPrivate.
  ///
  /// In en, this message translates to:
  /// **'Your details stay encrypted and private.'**
  String get encryptedPrivate;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @enterFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterFullName;

  /// No description provided for @pleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get pleaseEnterName;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @enterMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter mobile number'**
  String get enterMobileNumber;

  /// No description provided for @validMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number'**
  String get validMobileNumber;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @enterEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get enterEmailAddress;

  /// No description provided for @validEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get validEmailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @forgotPasswordQuestion.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordQuestion;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get noAccount;

  /// No description provided for @patientType.
  ///
  /// In en, this message translates to:
  /// **'Patient type'**
  String get patientType;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @secureRegistration.
  ///
  /// In en, this message translates to:
  /// **'SECURE REGISTRATION'**
  String get secureRegistration;

  /// No description provided for @howJoining.
  ///
  /// In en, this message translates to:
  /// **'How are you joining\nThaai Seyali?'**
  String get howJoining;

  /// No description provided for @relationshipClinic.
  ///
  /// In en, this message translates to:
  /// **'Choose the option that matches your relationship with the clinic.'**
  String get relationshipClinic;

  /// No description provided for @newPatient.
  ///
  /// In en, this message translates to:
  /// **'New Patient'**
  String get newPatient;

  /// No description provided for @newPatientDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a new Thaai Seyali patient account.'**
  String get newPatientDescription;

  /// No description provided for @existingPatient.
  ///
  /// In en, this message translates to:
  /// **'Existing Thaai Seyali Patient'**
  String get existingPatient;

  /// No description provided for @existingPatientDescription.
  ///
  /// In en, this message translates to:
  /// **'Securely link an existing clinic record.'**
  String get existingPatientDescription;

  /// No description provided for @linkedMember.
  ///
  /// In en, this message translates to:
  /// **'Partner / Linked Member'**
  String get linkedMember;

  /// No description provided for @linkedMemberDescription.
  ///
  /// In en, this message translates to:
  /// **'Use a patient-authorized invitation.'**
  String get linkedMemberDescription;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @myJourney.
  ///
  /// In en, this message translates to:
  /// **'My Journey'**
  String get myJourney;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// No description provided for @healthRecords.
  ///
  /// In en, this message translates to:
  /// **'Health Records'**
  String get healthRecords;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// No description provided for @treatmentCare.
  ///
  /// In en, this message translates to:
  /// **'Treatment & care'**
  String get treatmentCare;

  /// No description provided for @planningSupport.
  ///
  /// In en, this message translates to:
  /// **'Planning & support'**
  String get planningSupport;

  /// No description provided for @learnSupported.
  ///
  /// In en, this message translates to:
  /// **'Learn & feel supported'**
  String get learnSupported;

  /// No description provided for @accountClinic.
  ///
  /// In en, this message translates to:
  /// **'Account & clinic'**
  String get accountClinic;

  /// No description provided for @medicationInjections.
  ///
  /// In en, this message translates to:
  /// **'Medication & Injections'**
  String get medicationInjections;

  /// No description provided for @educationCentre.
  ///
  /// In en, this message translates to:
  /// **'Education Centre'**
  String get educationCentre;

  /// No description provided for @clinicCommunication.
  ///
  /// In en, this message translates to:
  /// **'Clinic Communication'**
  String get clinicCommunication;

  /// No description provided for @patientServices.
  ///
  /// In en, this message translates to:
  /// **'More / Patient Services'**
  String get patientServices;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get languageChanged;

  /// No description provided for @journeySupportedCare.
  ///
  /// In en, this message translates to:
  /// **'Your journey, supported with care'**
  String get journeySupportedCare;

  /// No description provided for @tapToContinue.
  ///
  /// In en, this message translates to:
  /// **'TAP TO CONTINUE'**
  String get tapToContinue;

  /// No description provided for @mobileRegistration.
  ///
  /// In en, this message translates to:
  /// **'Mobile registration'**
  String get mobileRegistration;

  /// No description provided for @existingPatientMobile.
  ///
  /// In en, this message translates to:
  /// **'Existing patient mobile'**
  String get existingPatientMobile;

  /// No description provided for @verifyMobile.
  ///
  /// In en, this message translates to:
  /// **'Verify your mobile number'**
  String get verifyMobile;

  /// No description provided for @registeredMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered mobile number'**
  String get registeredMobile;

  /// No description provided for @sendOneTimeCode.
  ///
  /// In en, this message translates to:
  /// **'We will send a one-time code to your Indian mobile number.'**
  String get sendOneTimeCode;

  /// No description provided for @registeredMobileHint.
  ///
  /// In en, this message translates to:
  /// **'Use the mobile number registered with your hospital record.'**
  String get registeredMobileHint;

  /// No description provided for @otpVerification.
  ///
  /// In en, this message translates to:
  /// **'OTP verification'**
  String get otpVerification;

  /// No description provided for @pleaseEnterOtp.
  ///
  /// In en, this message translates to:
  /// **'Please enter the 6-digit OTP.'**
  String get pleaseEnterOtp;

  /// No description provided for @incorrectOtp.
  ///
  /// In en, this message translates to:
  /// **'Incorrect OTP. Please try again.'**
  String get incorrectOtp;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordTitle;

  /// No description provided for @resetPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the email address registered to your account. If eligible, we will send a verification code to continue with password recovery.'**
  String get resetPasswordDescription;

  /// No description provided for @registeredMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Registered mobile number'**
  String get registeredMobileNumber;

  /// No description provided for @registeredEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Registered email address'**
  String get registeredEmailAddress;

  /// No description provided for @enterTenDigitMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter 10-digit mobile number'**
  String get enterTenDigitMobile;

  /// No description provided for @enterRegisteredEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter registered email address'**
  String get enterRegisteredEmail;

  /// No description provided for @partnerAccess.
  ///
  /// In en, this message translates to:
  /// **'Partner Access'**
  String get partnerAccess;

  /// No description provided for @connectedPartner.
  ///
  /// In en, this message translates to:
  /// **'Connected partner'**
  String get connectedPartner;

  /// No description provided for @partnerDetails.
  ///
  /// In en, this message translates to:
  /// **'Partner details'**
  String get partnerDetails;

  /// No description provided for @sharingSettings.
  ///
  /// In en, this message translates to:
  /// **'Sharing settings'**
  String get sharingSettings;

  /// No description provided for @shareMedicationSchedule.
  ///
  /// In en, this message translates to:
  /// **'Share Medication Schedule'**
  String get shareMedicationSchedule;

  /// No description provided for @shareAppointments.
  ///
  /// In en, this message translates to:
  /// **'Share Appointments'**
  String get shareAppointments;

  /// No description provided for @shareMedicalReports.
  ///
  /// In en, this message translates to:
  /// **'Share Medical Reports'**
  String get shareMedicalReports;

  /// No description provided for @generateInvitation.
  ///
  /// In en, this message translates to:
  /// **'Generate invitation'**
  String get generateInvitation;

  /// No description provided for @invitationCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Invitation code copied.'**
  String get invitationCodeCopied;

  /// No description provided for @securityPin.
  ///
  /// In en, this message translates to:
  /// **'Security PIN'**
  String get securityPin;

  /// No description provided for @enableAppLock.
  ///
  /// In en, this message translates to:
  /// **'Enable App Lock'**
  String get enableAppLock;

  /// No description provided for @changeSecurityPin.
  ///
  /// In en, this message translates to:
  /// **'Change Security PIN'**
  String get changeSecurityPin;

  /// No description provided for @resetSecurityPin.
  ///
  /// In en, this message translates to:
  /// **'Reset Security PIN'**
  String get resetSecurityPin;

  /// No description provided for @timelineInitialConsultationAssessment.
  ///
  /// In en, this message translates to:
  /// **'Initial consultation & assessment'**
  String get timelineInitialConsultationAssessment;

  /// No description provided for @timelineBaselineScanBloodTests.
  ///
  /// In en, this message translates to:
  /// **'Baseline scan & blood tests'**
  String get timelineBaselineScanBloodTests;

  /// No description provided for @timelineCyclePreparationSuppression.
  ///
  /// In en, this message translates to:
  /// **'Cycle preparation / suppression'**
  String get timelineCyclePreparationSuppression;

  /// No description provided for @timelineSpermCollectionPreparation.
  ///
  /// In en, this message translates to:
  /// **'Sperm collection & preparation'**
  String get timelineSpermCollectionPreparation;

  /// No description provided for @timelineEmbryoAssessmentSelection.
  ///
  /// In en, this message translates to:
  /// **'Embryo assessment & selection'**
  String get timelineEmbryoAssessmentSelection;

  /// No description provided for @timelineLutealSupport.
  ///
  /// In en, this message translates to:
  /// **'Luteal phase support, if prescribed'**
  String get timelineLutealSupport;

  /// No description provided for @timelinePregnancyConfirmationScan.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy confirmation scan, if positive'**
  String get timelinePregnancyConfirmationScan;

  /// No description provided for @timelineIuiInitialConsultation.
  ///
  /// In en, this message translates to:
  /// **'IUI initial consultation'**
  String get timelineIuiInitialConsultation;

  /// No description provided for @timelinePreTreatmentFertilityTests.
  ///
  /// In en, this message translates to:
  /// **'Pre-treatment fertility tests'**
  String get timelinePreTreatmentFertilityTests;

  /// No description provided for @timelineMenstrualCycleDayOne.
  ///
  /// In en, this message translates to:
  /// **'Menstrual cycle – Day 1'**
  String get timelineMenstrualCycleDayOne;

  /// No description provided for @timelineOvulationInduction.
  ///
  /// In en, this message translates to:
  /// **'Ovulation induction, if required'**
  String get timelineOvulationInduction;

  /// No description provided for @timelineOvulationDetectionTrigger.
  ///
  /// In en, this message translates to:
  /// **'Ovulation detection / trigger injection'**
  String get timelineOvulationDetectionTrigger;

  /// No description provided for @timelineIuiInsemination.
  ///
  /// In en, this message translates to:
  /// **'Insemination (IUI procedure)'**
  String get timelineIuiInsemination;

  /// No description provided for @timelineTwoWeekWait.
  ///
  /// In en, this message translates to:
  /// **'Two-week wait'**
  String get timelineTwoWeekWait;

  /// No description provided for @timelinePregnancyFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy follow-up, if positive'**
  String get timelinePregnancyFollowUp;

  /// No description provided for @timelineCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get timelineCompleted;

  /// No description provided for @timelineInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get timelineInProgress;

  /// No description provided for @timelineUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get timelineUpcoming;

  /// No description provided for @timelineRescheduled.
  ///
  /// In en, this message translates to:
  /// **'Rescheduled'**
  String get timelineRescheduled;

  /// No description provided for @timelineCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get timelineCancelled;

  /// No description provided for @timelineAwaitingClinicUpdate.
  ///
  /// In en, this message translates to:
  /// **'Awaiting clinic update'**
  String get timelineAwaitingClinicUpdate;

  /// No description provided for @timelineAboutThisStage.
  ///
  /// In en, this message translates to:
  /// **'About This Stage'**
  String get timelineAboutThisStage;

  /// No description provided for @timelineWhatHappens.
  ///
  /// In en, this message translates to:
  /// **'What Happens'**
  String get timelineWhatHappens;

  /// No description provided for @timelineTreatmentInformation.
  ///
  /// In en, this message translates to:
  /// **'Treatment Information'**
  String get timelineTreatmentInformation;

  /// No description provided for @timelineAppointmentsReports.
  ///
  /// In en, this message translates to:
  /// **'Appointments & Reports'**
  String get timelineAppointmentsReports;

  /// No description provided for @timelineClinicInstructions.
  ///
  /// In en, this message translates to:
  /// **'Clinic Instructions'**
  String get timelineClinicInstructions;

  /// No description provided for @timelineOpenAppointment.
  ///
  /// In en, this message translates to:
  /// **'Open appointment'**
  String get timelineOpenAppointment;

  /// No description provided for @timelinePreviousStage.
  ///
  /// In en, this message translates to:
  /// **'Previous Stage'**
  String get timelinePreviousStage;

  /// No description provided for @timelineNextStage.
  ///
  /// In en, this message translates to:
  /// **'Next Stage'**
  String get timelineNextStage;

  /// No description provided for @timelineBackToTimeline.
  ///
  /// In en, this message translates to:
  /// **'Back to Timeline'**
  String get timelineBackToTimeline;

  /// No description provided for @timelineGuideOnly.
  ///
  /// In en, this message translates to:
  /// **'Guide only. This stage is not confirmed as part of your personal treatment plan.'**
  String get timelineGuideOnly;

  /// No description provided for @timelineDevelopmentSample.
  ///
  /// In en, this message translates to:
  /// **'Development-only sample: clinic timeline data has not been connected.'**
  String get timelineDevelopmentSample;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
