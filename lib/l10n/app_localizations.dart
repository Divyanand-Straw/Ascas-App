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

  /// No description provided for @orLoginWith.
  ///
  /// In en, this message translates to:
  /// **'OR LOGIN WITH'**
  String get orLoginWith;

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
  /// **'Enter your registered mobile number and email address. We will help you verify your identity and reset your password.'**
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
