import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';
import 'app_localizations_om.dart';
import 'app_localizations_ti.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('am'),
    Locale('en'),
    Locale('om'),
    Locale('ti')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ZEGA-ALERT'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your safety companion'**
  String get appSubtitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get news;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @sosEmergency.
  ///
  /// In en, this message translates to:
  /// **'SOS EMERGENCY'**
  String get sosEmergency;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'SENDING…'**
  String get sending;

  /// No description provided for @sosDispatched.
  ///
  /// In en, this message translates to:
  /// **'🚨 SOS Dispatched'**
  String get sosDispatched;

  /// No description provided for @unitsOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'{count} unit(s) are on the way.'**
  String unitsOnTheWay(Object count);

  /// No description provided for @announcements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcements;

  /// No description provided for @missingPersons.
  ///
  /// In en, this message translates to:
  /// **'Missing persons'**
  String get missingPersons;

  /// No description provided for @wantedPersons.
  ///
  /// In en, this message translates to:
  /// **'Wanted persons'**
  String get wantedPersons;

  /// No description provided for @reportMissing.
  ///
  /// In en, this message translates to:
  /// **'Report missing'**
  String get reportMissing;

  /// No description provided for @reportACrime.
  ///
  /// In en, this message translates to:
  /// **'Report a crime'**
  String get reportACrime;

  /// No description provided for @yourReportGoesTo.
  ///
  /// In en, this message translates to:
  /// **'Your report goes to the regional police.'**
  String get yourReportGoesTo;

  /// No description provided for @newCrimeReport.
  ///
  /// In en, this message translates to:
  /// **'New crime report'**
  String get newCrimeReport;

  /// No description provided for @myReports.
  ///
  /// In en, this message translates to:
  /// **'My reports'**
  String get myReports;

  /// No description provided for @noReportsYet.
  ///
  /// In en, this message translates to:
  /// **'You have not submitted any reports yet.'**
  String get noReportsYet;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @severity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get severity;

  /// No description provided for @reportAnonymously.
  ///
  /// In en, this message translates to:
  /// **'Report anonymously'**
  String get reportAnonymously;

  /// No description provided for @evidenceOptional.
  ///
  /// In en, this message translates to:
  /// **'Evidence (optional)'**
  String get evidenceOptional;

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get submitReport;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get submitting;

  /// No description provided for @newsAndInformation.
  ///
  /// In en, this message translates to:
  /// **'News & Information'**
  String get newsAndInformation;

  /// No description provided for @announcementsTab.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcementsTab;

  /// No description provided for @legalTab.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legalTab;

  /// No description provided for @missingTab.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get missingTab;

  /// No description provided for @sightingsTab.
  ///
  /// In en, this message translates to:
  /// **'Sightings'**
  String get sightingsTab;

  /// No description provided for @reportAMissingPerson.
  ///
  /// In en, this message translates to:
  /// **'Report a missing person'**
  String get reportAMissingPerson;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your account, language, zones and accessibility'**
  String get settingsSubtitle;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// No description provided for @regionLabel.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get regionLabel;

  /// No description provided for @subCity.
  ///
  /// In en, this message translates to:
  /// **'Sub-city / Woreda'**
  String get subCity;

  /// No description provided for @subCityLabel.
  ///
  /// In en, this message translates to:
  /// **'Sub-city / Woreda'**
  String get subCityLabel;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @preferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred language'**
  String get preferredLanguage;

  /// No description provided for @safetyZones.
  ///
  /// In en, this message translates to:
  /// **'Safety zones (geofences)'**
  String get safetyZones;

  /// No description provided for @addSafetyZone.
  ///
  /// In en, this message translates to:
  /// **'Add safety zone'**
  String get addSafetyZone;

  /// No description provided for @legalInformation.
  ///
  /// In en, this message translates to:
  /// **'Legal information'**
  String get legalInformation;

  /// No description provided for @accessibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Accessibility (People of Determination)'**
  String get accessibilityTitle;

  /// No description provided for @accessibilitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Larger text, high contrast, voice-assisted actions'**
  String get accessibilitySubtitle;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @darkModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use dark theme across the app'**
  String get darkModeSubtitle;

  /// No description provided for @callbackRequests.
  ///
  /// In en, this message translates to:
  /// **'Callback requests'**
  String get callbackRequests;

  /// No description provided for @callbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Respond to police follow-up calls on your reports'**
  String get callbackSubtitle;

  /// No description provided for @requestDirectCall.
  ///
  /// In en, this message translates to:
  /// **'Request direct call'**
  String get requestDirectCall;

  /// No description provided for @recordSignLanguage.
  ///
  /// In en, this message translates to:
  /// **'Record sign language video'**
  String get recordSignLanguage;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get saveSettings;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutLabel;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signingIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @emergencyAndCrime.
  ///
  /// In en, this message translates to:
  /// **'ZEGA-ALERT · Emergency & crime reporting'**
  String get emergencyAndCrime;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No description provided for @newHere.
  ///
  /// In en, this message translates to:
  /// **'New here? Create account'**
  String get newHere;

  /// No description provided for @callbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Callback requests'**
  String get callbackTitle;

  /// No description provided for @callbackDescription.
  ///
  /// In en, this message translates to:
  /// **'Police request callbacks to follow up on your reports.'**
  String get callbackDescription;

  /// No description provided for @noCallbacksYet.
  ///
  /// In en, this message translates to:
  /// **'No callback requests yet.'**
  String get noCallbacksYet;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode — showing cached data'**
  String get offlineMode;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @sosSent.
  ///
  /// In en, this message translates to:
  /// **'SOS sent. Units dispatched. Stay where you are.'**
  String get sosSent;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Share announcement: {title}'**
  String shareAnnouncement(Object title);

  /// No description provided for @missing.
  ///
  /// In en, this message translates to:
  /// **'MISSING'**
  String get missing;

  /// No description provided for @wanted.
  ///
  /// In en, this message translates to:
  /// **'WANTED'**
  String get wanted;

  /// No description provided for @reportSighting.
  ///
  /// In en, this message translates to:
  /// **'Report a sighting'**
  String get reportSighting;

  /// No description provided for @shareMissingPerson.
  ///
  /// In en, this message translates to:
  /// **'Share missing person: {name}'**
  String shareMissingPerson(Object name);

  /// No description provided for @shareWantedPerson.
  ///
  /// In en, this message translates to:
  /// **'Share wanted person: {name}'**
  String shareWantedPerson(Object name);

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen: {location}'**
  String lastSeen(Object location);

  /// No description provided for @nothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get nothingHereYet;

  /// No description provided for @citizenSightingsInfo.
  ///
  /// In en, this message translates to:
  /// **'Citizen sightings are shown to police in real time.'**
  String get citizenSightingsInfo;

  /// No description provided for @unknownLocation.
  ///
  /// In en, this message translates to:
  /// **'Unknown location'**
  String get unknownLocation;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get pleaseWait;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// No description provided for @checkOtpHint.
  ///
  /// In en, this message translates to:
  /// **'Check server console for dev OTP'**
  String get checkOtpHint;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @rateResponse.
  ///
  /// In en, this message translates to:
  /// **'Rate the response'**
  String get rateResponse;

  /// No description provided for @commentOptional.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get commentOptional;

  /// No description provided for @thanksFeedback.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your feedback!'**
  String get thanksFeedback;

  /// No description provided for @rateThisResponse.
  ///
  /// In en, this message translates to:
  /// **'Rate this response'**
  String get rateThisResponse;

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. Thank you.'**
  String get reportSubmitted;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String uploadFailed(Object error);

  /// No description provided for @addType.
  ///
  /// In en, this message translates to:
  /// **'Add {type}'**
  String addType(Object type);

  /// No description provided for @url.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get url;

  /// No description provided for @filePathNote.
  ///
  /// In en, this message translates to:
  /// **'File path / note'**
  String get filePathNote;

  /// No description provided for @noScheduledSlot.
  ///
  /// In en, this message translates to:
  /// **'No scheduled slot'**
  String get noScheduledSlot;

  /// No description provided for @reportFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Report follow-up'**
  String get reportFollowUp;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @contactStaff.
  ///
  /// In en, this message translates to:
  /// **'Contact a staff member'**
  String get contactStaff;

  /// No description provided for @staffPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Staff phone, e.g. 0911000003'**
  String get staffPhoneHint;

  /// No description provided for @startChat.
  ///
  /// In en, this message translates to:
  /// **'Start chat'**
  String get startChat;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get userNotFound;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations'**
  String get noConversations;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get typeMessage;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @missingPersonReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Missing person report submitted.'**
  String get missingPersonReportSubmitted;

  /// No description provided for @fullNameMissingPerson.
  ///
  /// In en, this message translates to:
  /// **'Full name of missing person'**
  String get fullNameMissingPerson;

  /// No description provided for @ageOptional.
  ///
  /// In en, this message translates to:
  /// **'Age (optional)'**
  String get ageOptional;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @lastSeenLocation.
  ///
  /// In en, this message translates to:
  /// **'Last seen location (address)'**
  String get lastSeenLocation;

  /// No description provided for @lastSeenDateTime.
  ///
  /// In en, this message translates to:
  /// **'Last seen date & time (optional)'**
  String get lastSeenDateTime;

  /// No description provided for @lastSeenPrefix.
  ///
  /// In en, this message translates to:
  /// **'Last seen: {datetime}'**
  String lastSeenPrefix(Object datetime);

  /// No description provided for @descriptionIdentifying.
  ///
  /// In en, this message translates to:
  /// **'Description / identifying details'**
  String get descriptionIdentifying;

  /// No description provided for @sightingReported.
  ///
  /// In en, this message translates to:
  /// **'Sighting reported. Thank you for helping.'**
  String get sightingReported;

  /// No description provided for @whereSeen.
  ///
  /// In en, this message translates to:
  /// **'Where did you see them?'**
  String get whereSeen;

  /// No description provided for @whenOptional.
  ///
  /// In en, this message translates to:
  /// **'When? (optional)'**
  String get whenOptional;

  /// No description provided for @seenAt.
  ///
  /// In en, this message translates to:
  /// **'Seen at: {datetime}'**
  String seenAt(Object datetime);

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @submitSighting.
  ///
  /// In en, this message translates to:
  /// **'Submit sighting'**
  String get submitSighting;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @idNumberPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your ID number and take a photo of your ID card.'**
  String get idNumberPhotoRequired;

  /// No description provided for @verificationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Verification submitted.'**
  String get verificationSubmitted;

  /// No description provided for @faydaIdVerification.
  ///
  /// In en, this message translates to:
  /// **'Fayda National ID Verification'**
  String get faydaIdVerification;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @notVerified.
  ///
  /// In en, this message translates to:
  /// **'Not Verified'**
  String get notVerified;

  /// No description provided for @identityVerifiedDesc.
  ///
  /// In en, this message translates to:
  /// **'Your identity has been verified via Fayda National ID.'**
  String get identityVerifiedDesc;

  /// No description provided for @verifyIdentityDesc.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to build trust and enable all features.'**
  String get verifyIdentityDesc;

  /// No description provided for @scanFaydaId.
  ///
  /// In en, this message translates to:
  /// **'Scan your Fayda National ID card'**
  String get scanFaydaId;

  /// No description provided for @scanIdInstruction.
  ///
  /// In en, this message translates to:
  /// **'Take a clear photo of the front of your ID card. Your information will be verified against the Fayda database.'**
  String get scanIdInstruction;

  /// No description provided for @tapToScanId.
  ///
  /// In en, this message translates to:
  /// **'Tap to scan ID card'**
  String get tapToScanId;

  /// No description provided for @faydaIdNumber.
  ///
  /// In en, this message translates to:
  /// **'Fayda ID Number'**
  String get faydaIdNumber;

  /// No description provided for @faydaIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1234567890123'**
  String get faydaIdHint;

  /// No description provided for @fullNameAsOnId.
  ///
  /// In en, this message translates to:
  /// **'Full name (as on ID)'**
  String get fullNameAsOnId;

  /// No description provided for @verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get verifying;

  /// No description provided for @submitForVerification.
  ///
  /// In en, this message translates to:
  /// **'Submit for Verification'**
  String get submitForVerification;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @ringing.
  ///
  /// In en, this message translates to:
  /// **'Ringing...'**
  String get ringing;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploading;

  /// No description provided for @newSafetyZone.
  ///
  /// In en, this message translates to:
  /// **'New safety zone'**
  String get newSafetyZone;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @centerLatitude.
  ///
  /// In en, this message translates to:
  /// **'Center latitude'**
  String get centerLatitude;

  /// No description provided for @centerLongitude.
  ///
  /// In en, this message translates to:
  /// **'Center longitude'**
  String get centerLongitude;

  /// No description provided for @radiusMeters.
  ///
  /// In en, this message translates to:
  /// **'Radius (meters)'**
  String get radiusMeters;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @safetyZoneCreated.
  ///
  /// In en, this message translates to:
  /// **'Safety zone created.'**
  String get safetyZoneCreated;

  /// No description provided for @safetyZoneDeleted.
  ///
  /// In en, this message translates to:
  /// **'Safety zone deleted.'**
  String get safetyZoneDeleted;

  /// No description provided for @noLegalContent.
  ///
  /// In en, this message translates to:
  /// **'No legal content available.'**
  String get noLegalContent;

  /// No description provided for @identityVerification.
  ///
  /// In en, this message translates to:
  /// **'Identity Verification'**
  String get identityVerification;

  /// No description provided for @faydaVerificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity with your national ID card'**
  String get faydaVerificationSubtitle;

  /// No description provided for @accessibilityModePoD.
  ///
  /// In en, this message translates to:
  /// **'Accessibility mode (PoD)'**
  String get accessibilityModePoD;

  /// No description provided for @callingNumber.
  ///
  /// In en, this message translates to:
  /// **'Calling {number}…'**
  String callingNumber(Object number);

  /// No description provided for @couldNotStartCall.
  ///
  /// In en, this message translates to:
  /// **'Could not start the call: {error}'**
  String couldNotStartCall(Object error);

  /// No description provided for @recordingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Recording cancelled.'**
  String get recordingCancelled;

  /// No description provided for @signLanguageUploaded.
  ///
  /// In en, this message translates to:
  /// **'Sign language video uploaded ({name}).'**
  String signLanguageUploaded(Object name);

  /// No description provided for @signLanguageRecorded.
  ///
  /// In en, this message translates to:
  /// **'Sign language video recorded & uploaded.'**
  String get signLanguageRecorded;

  /// No description provided for @couldNotRecordVideo.
  ///
  /// In en, this message translates to:
  /// **'Could not record/upload video: {error}'**
  String couldNotRecordVideo(Object error);

  /// No description provided for @incomingCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming Call'**
  String get incomingCall;

  /// No description provided for @callerIsCalling.
  ///
  /// In en, this message translates to:
  /// **'{name} is calling you'**
  String callerIsCalling(Object name);

  /// No description provided for @photoOfPerson.
  ///
  /// In en, this message translates to:
  /// **'Photo of the person (optional)'**
  String get photoOfPerson;

  /// No description provided for @photoOfSighting.
  ///
  /// In en, this message translates to:
  /// **'Photo of sighting (optional)'**
  String get photoOfSighting;

  /// No description provided for @newCallbackRequest.
  ///
  /// In en, this message translates to:
  /// **'New callback request for \"{title}\"'**
  String newCallbackRequest(Object title);

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @sosUpdated.
  ///
  /// In en, this message translates to:
  /// **'Your SOS is now {status}'**
  String sosUpdated(Object status);
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
      <String>['am', 'en', 'om', 'ti'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
    case 'om':
      return AppLocalizationsOm();
    case 'ti':
      return AppLocalizationsTi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
