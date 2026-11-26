import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';
import 'app_localizations_om.dart';
import 'app_localizations_so.dart';
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
    Locale('so'),
    Locale('ti'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Zega-alert'**
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

  /// No description provided for @safetyZonesTab.
  ///
  /// In en, this message translates to:
  /// **'Zones'**
  String get safetyZonesTab;

  /// No description provided for @safetyZonesHomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Safety-zone updates and emergency incidents inside a zone are added to your notification inbox and sent as push alerts when notifications are enabled. Select an area below to see its map and boundary. Follow local instructions; a zone does not guarantee safety.'**
  String get safetyZonesHomeDescription;

  /// No description provided for @noSafetyZonesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No official safety zones are currently published for your region.'**
  String get noSafetyZonesAvailable;

  /// No description provided for @safetyZonesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Safety-zone information could not be loaded. Try again.'**
  String get safetyZonesLoadFailed;

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
  /// **'Zega-alert · Emergency & crime reporting'**
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

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @showOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show original'**
  String get showOriginal;

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
  /// **'No scheduled time'**
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

  /// No description provided for @searchMissingWantedPeople.
  ///
  /// In en, this message translates to:
  /// **'Search missing or wanted people'**
  String get searchMissingWantedPeople;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @searchPeople.
  ///
  /// In en, this message translates to:
  /// **'Search people'**
  String get searchPeople;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @markRead.
  ///
  /// In en, this message translates to:
  /// **'Mark read'**
  String get markRead;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get noNotificationsYet;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @safetyZoneNoLongerActive.
  ///
  /// In en, this message translates to:
  /// **'This area is no longer active. Check Safety Zones for current information.'**
  String get safetyZoneNoLongerActive;

  /// No description provided for @couldNotOpenSafetyZone.
  ///
  /// In en, this message translates to:
  /// **'Could not open this safety-zone map.'**
  String get couldNotOpenSafetyZone;

  /// No description provided for @helpAndAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Help & accessibility'**
  String get helpAndAccessibility;

  /// No description provided for @policeRescueContacts.
  ///
  /// In en, this message translates to:
  /// **'Police and rescue contacts'**
  String get policeRescueContacts;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get personalInformation;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @safetyZoneEntryAlerts.
  ///
  /// In en, this message translates to:
  /// **'Safety Zone entry alerts'**
  String get safetyZoneEntryAlerts;

  /// No description provided for @safetyZoneEntryAlertsDescription.
  ///
  /// In en, this message translates to:
  /// **'When enabled, ZEGA Alert checks your location in the background and alerts you when you enter an active published Safety Zone. Available on Android.'**
  String get safetyZoneEntryAlertsDescription;

  /// No description provided for @safetyZoneLocationPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Precise location for these alerts stays on this device and is not uploaded. Android shows an ongoing notification while monitoring; this can use more battery. SOS and report actions may use location separately. Your saved Region/Sub-city fields remain the manual fallback and still control area-based information.'**
  String get safetyZoneLocationPrivacy;

  /// No description provided for @allowBackgroundLocation.
  ///
  /// In en, this message translates to:
  /// **'Allow background location'**
  String get allowBackgroundLocation;

  /// No description provided for @allowBackgroundLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'To check for Safety Zone entry while ZEGA Alert is closed, Android must allow location access all the time. In app permissions, choose “Allow all the time”.'**
  String get allowBackgroundLocationDescription;

  /// No description provided for @openAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get openAppSettings;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @safetyZoneAlertsOn.
  ///
  /// In en, this message translates to:
  /// **'Safety Zone entry alerts are on.'**
  String get safetyZoneAlertsOn;

  /// No description provided for @safetyZoneAlertsOff.
  ///
  /// In en, this message translates to:
  /// **'Safety Zone location alerts are off.'**
  String get safetyZoneAlertsOff;

  /// No description provided for @safetyZoneAlertsOnNoZones.
  ///
  /// In en, this message translates to:
  /// **'Location alerts are on. No published Safety Zones are available yet.'**
  String get safetyZoneAlertsOnNoZones;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @offlineData.
  ///
  /// In en, this message translates to:
  /// **'Offline data'**
  String get offlineData;

  /// No description provided for @savePersonPhotos.
  ///
  /// In en, this message translates to:
  /// **'Save wanted and missing-person photos'**
  String get savePersonPhotos;

  /// No description provided for @savePersonPhotosDescription.
  ///
  /// In en, this message translates to:
  /// **'Photos you view are stored on this device for offline access. This is off by default.'**
  String get savePersonPhotosDescription;

  /// No description provided for @clearSavedPhotos.
  ///
  /// In en, this message translates to:
  /// **'Clear saved person photos'**
  String get clearSavedPhotos;

  /// No description provided for @clearSavedPhotosConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Clear saved person photos?'**
  String get clearSavedPhotosConfirmation;

  /// No description provided for @clearSavedPhotosDescription.
  ///
  /// In en, this message translates to:
  /// **'This removes wanted and missing-person photos saved on this device. They can be saved again while photo storage is enabled.'**
  String get clearSavedPhotosDescription;

  /// No description provided for @photosCountAndStorage.
  ///
  /// In en, this message translates to:
  /// **'{count} photos · {size} used'**
  String photosCountAndStorage(Object count, Object size);

  /// No description provided for @officialSafetyAreasDescription.
  ///
  /// In en, this message translates to:
  /// **'View official safety areas published by local authorities. New or changed areas and emergency incidents inside a zone appear in Notifications; push alerts require device notifications to be enabled. This information does not guarantee safety.'**
  String get officialSafetyAreasDescription;

  /// No description provided for @noOfficialSafetyAreas.
  ///
  /// In en, this message translates to:
  /// **'No official safety areas are available for this region yet.'**
  String get noOfficialSafetyAreas;

  /// No description provided for @officialSafetyArea.
  ///
  /// In en, this message translates to:
  /// **'Official safety area: {name}. Type: {type}.'**
  String officialSafetyArea(Object name, Object type);

  /// No description provided for @mappedBoundary.
  ///
  /// In en, this message translates to:
  /// **'Mapped boundary'**
  String get mappedBoundary;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @currentPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password.'**
  String get currentPasswordRequired;

  /// No description provided for @passwordMinimumLength.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get passwordMinimumLength;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePassword;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @welcomeSafetyMessage.
  ///
  /// In en, this message translates to:
  /// **'Thank you for helping keep our community safe.'**
  String get welcomeSafetyMessage;

  /// No description provided for @phoneNumberOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Phone number or email'**
  String get phoneNumberOrEmail;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPassword;

  /// No description provided for @signInBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Sign in with biometrics'**
  String get signInBiometrics;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get continueAsGuest;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @validEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get validEmailRequired;

  /// No description provided for @validPhoneOrEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number or email.'**
  String get validPhoneOrEmailRequired;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone/email or password. Please try again.'**
  String get invalidCredentials;

  /// No description provided for @accountNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this phone/email.'**
  String get accountNotFound;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in could not be completed. Please try again.'**
  String get signInFailed;

  /// No description provided for @police.
  ///
  /// In en, this message translates to:
  /// **'Police'**
  String get police;

  /// No description provided for @ambulanceRescue.
  ///
  /// In en, this message translates to:
  /// **'Ambulance / rescue'**
  String get ambulanceRescue;

  /// No description provided for @regionSelectedSemantics.
  ///
  /// In en, this message translates to:
  /// **'Region dropdown. Currently set to {region}.'**
  String regionSelectedSemantics(Object region);

  /// No description provided for @subCitySelectedSemantics.
  ///
  /// In en, this message translates to:
  /// **'Sub-city dropdown. Currently set to {subCity}.'**
  String subCitySelectedSemantics(Object subCity);

  /// No description provided for @languageSelectedSemantics.
  ///
  /// In en, this message translates to:
  /// **'Preferred language dropdown. Currently set to {language}.'**
  String languageSelectedSemantics(Object language);

  /// No description provided for @citizenProfile.
  ///
  /// In en, this message translates to:
  /// **'Citizen profile'**
  String get citizenProfile;

  /// No description provided for @verifiedAccount.
  ///
  /// In en, this message translates to:
  /// **'Verified account'**
  String get verifiedAccount;

  /// No description provided for @unverifiedAccount.
  ///
  /// In en, this message translates to:
  /// **'Unverified account'**
  String get unverifiedAccount;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get memberSince;

  /// No description provided for @verificationStatus.
  ///
  /// In en, this message translates to:
  /// **'Verification status'**
  String get verificationStatus;

  /// No description provided for @guestBrowsing.
  ///
  /// In en, this message translates to:
  /// **'Browsing as guest'**
  String get guestBrowsing;

  /// No description provided for @guestFeaturesInfo.
  ///
  /// In en, this message translates to:
  /// **'Sign in to file reports, send SOS, message officers and verify your ID.'**
  String get guestFeaturesInfo;

  /// No description provided for @signInCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in / Create account'**
  String get signInCreateAccount;

  /// No description provided for @fanIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'FAN identity verification'**
  String get fanIdentityTitle;

  /// No description provided for @fanIdentityDescription.
  ///
  /// In en, this message translates to:
  /// **'Scan your original ID QR or enter its 16-digit FAN to check the administrator’s mock record.'**
  String get fanIdentityDescription;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile and settings saved.'**
  String get settingsSaved;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your profile.'**
  String get settingsSaveFailed;

  /// No description provided for @notificationLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load notifications right now.'**
  String get notificationLoadFailed;

  /// No description provided for @backgroundLocationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose “Allow all the time” in app permissions, then turn on Safety Zone alerts again.'**
  String get backgroundLocationPermissionRequired;

  /// No description provided for @backgroundLocationAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'Background Safety Zone alerts are currently available on Android.'**
  String get backgroundLocationAndroidOnly;

  /// No description provided for @turnOnDeviceLocation.
  ///
  /// In en, this message translates to:
  /// **'Turn on device Location to enable Safety Zone alerts.'**
  String get turnOnDeviceLocation;

  /// No description provided for @alwaysLocationPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow ZEGA Alert to access location all the time in app permissions, then turn Safety Zone alerts on again.'**
  String get alwaysLocationPermission;

  /// No description provided for @safetyNotificationsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Safety Zone notifications are not available on this device.'**
  String get safetyNotificationsUnavailable;

  /// No description provided for @allowSafetyNotifications.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications for ZEGA Alert to receive Safety Zone entry alerts.'**
  String get allowSafetyNotifications;

  /// No description provided for @couldNotEnableSafetyZoneAlerts.
  ///
  /// In en, this message translates to:
  /// **'Could not enable Safety Zone alerts. Check your connection, location permission, and notification settings.'**
  String get couldNotEnableSafetyZoneAlerts;

  /// No description provided for @couldNotStartLocationMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Could not start Safety Zone location monitoring.'**
  String get couldNotStartLocationMonitoring;

  /// No description provided for @couldNotRestartLocationMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Could not restart Safety Zone location monitoring.'**
  String get couldNotRestartLocationMonitoring;

  /// No description provided for @locationMonitoringStopped.
  ///
  /// In en, this message translates to:
  /// **'Location monitoring stopped. Check device Location and permissions.'**
  String get locationMonitoringStopped;

  /// No description provided for @couldNotCheckZoneBoundaries.
  ///
  /// In en, this message translates to:
  /// **'Could not check the current Safety Zone boundaries.'**
  String get couldNotCheckZoneBoundaries;

  /// No description provided for @biometricCancelled.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication was cancelled.'**
  String get biometricCancelled;

  /// No description provided for @settingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load settings right now.'**
  String get settingsLoadFailed;

  /// No description provided for @savedPhotoStorageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read saved photo storage.'**
  String get savedPhotoStorageFailed;

  /// No description provided for @photoStorageUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update photo storage settings.'**
  String get photoStorageUpdateFailed;

  /// No description provided for @photoStorageClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear saved photos.'**
  String get photoStorageClearFailed;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully.'**
  String get passwordChanged;

  /// No description provided for @passwordChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change your password.'**
  String get passwordChangeFailed;

  /// No description provided for @clearPhotos.
  ///
  /// In en, this message translates to:
  /// **'Clear photos'**
  String get clearPhotos;

  /// No description provided for @clearSavedPersonPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear saved person photos?'**
  String get clearSavedPersonPhotosTitle;

  /// No description provided for @clearSavedPersonPhotosBody.
  ///
  /// In en, this message translates to:
  /// **'This removes wanted and missing-person photos saved on this device. They can be saved again while photo storage is enabled.'**
  String get clearSavedPersonPhotosBody;

  /// No description provided for @aboutSupport.
  ///
  /// In en, this message translates to:
  /// **'About & support'**
  String get aboutSupport;

  /// No description provided for @aboutZegaAlert.
  ///
  /// In en, this message translates to:
  /// **'About ZEGA-ALERT'**
  String get aboutZegaAlert;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @termsConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsConditions;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @rateZegaAlert.
  ///
  /// In en, this message translates to:
  /// **'Rate ZEGA-ALERT'**
  String get rateZegaAlert;

  /// No description provided for @chatWithAdmin.
  ///
  /// In en, this message translates to:
  /// **'Chat with Admin'**
  String get chatWithAdmin;

  /// No description provided for @followUpOnReports.
  ///
  /// In en, this message translates to:
  /// **'Follow up on reports'**
  String get followUpOnReports;

  /// No description provided for @leaveFeedback.
  ///
  /// In en, this message translates to:
  /// **'Leave Feedback'**
  String get leaveFeedback;

  /// No description provided for @feedbackHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us how we can improve...'**
  String get feedbackHint;

  /// No description provided for @feedbackSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Feedback submitted. Thank you!'**
  String get feedbackSubmitted;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactUs;

  /// No description provided for @policeEmergency.
  ///
  /// In en, this message translates to:
  /// **'Police emergency'**
  String get policeEmergency;

  /// No description provided for @emailSupport.
  ///
  /// In en, this message translates to:
  /// **'Email support'**
  String get emailSupport;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @searchAppStoreToRate.
  ///
  /// In en, this message translates to:
  /// **'Search for ZEGA-ALERT in your app store to rate us.'**
  String get searchAppStoreToRate;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'ZEGA-ALERT is the Ethiopian Federal Police citizen safety app. It connects you to emergency dispatch, crime reporting, missing and wanted persons, official announcements and two-way communication with officers — in English, Amharic, Oromifa, Tigrinya and Ethio Somali.\n\nVersion {version}'**
  String aboutBody(Object version);

  /// No description provided for @termsBody.
  ///
  /// In en, this message translates to:
  /// **'1. Use ZEGA-ALERT only for genuine emergencies, crime reports and public-safety information.\n\n2. Knowingly sending false reports is an offence and may lead to account suspension and legal action.\n\n3. Emergency features depend on network coverage and location services. Always call 991 if the app cannot connect.\n\n4. Reports you submit are shared with the responsible police station and regional administrators for investigation.\n\n5. Keep your account credentials private. You are responsible for activity on your account.'**
  String get termsBody;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'ZEGA-ALERT collects only the information needed to keep you safe: your name, phone number, region and the content of reports you choose to submit.\n\nLocation is used for SOS alerts, nearest-station lookup, safety zones and incident mapping. It is transmitted only while you use these features.\n\nContact details on missing-person notices are encrypted at rest. Sensitive information is visible only to authorised police staff.\n\nYou can browse news, wanted and missing persons as a guest. You can delete your account by contacting support.'**
  String get privacyBody;

  /// No description provided for @onboardingEmergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency SOS'**
  String get onboardingEmergencyTitle;

  /// No description provided for @onboardingEmergencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Press SOS to alert nearby police and share your location. If the app cannot connect, call 991.'**
  String get onboardingEmergencySubtitle;

  /// No description provided for @onboardingReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Crime Safely'**
  String get onboardingReportTitle;

  /// No description provided for @onboardingReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send a crime report with details and photos. You can choose whether to include your identity.'**
  String get onboardingReportSubtitle;

  /// No description provided for @onboardingMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Find Missing Persons'**
  String get onboardingMissingTitle;

  /// No description provided for @onboardingMissingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View missing-person and wanted alerts. Report a sighting to help police and families.'**
  String get onboardingMissingSubtitle;

  /// No description provided for @onboardingRegionTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Your Region'**
  String get onboardingRegionTitle;

  /// No description provided for @onboardingRegionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your region in Settings to see local alerts and receive Safety Zone notifications.'**
  String get onboardingRegionSubtitle;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @callbacksLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load callback requests right now.'**
  String get callbacksLoadFailed;

  /// No description provided for @callbackUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the callback request.'**
  String get callbackUpdateFailed;

  /// No description provided for @chooseFutureTime.
  ///
  /// In en, this message translates to:
  /// **'Choose a future time.'**
  String get chooseFutureTime;

  /// No description provided for @alternativeTimeSent.
  ///
  /// In en, this message translates to:
  /// **'Alternative time sent to the officer.'**
  String get alternativeTimeSent;

  /// No description provided for @callbackSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the callback update.'**
  String get callbackSendFailed;

  /// No description provided for @callbackSessionStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the session.'**
  String get callbackSessionStartFailed;

  /// No description provided for @youProposedSlot.
  ///
  /// In en, this message translates to:
  /// **'You proposed: {slot}'**
  String youProposedSlot(Object slot);

  /// No description provided for @waitingForOfficer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for officer'**
  String get waitingForOfficer;

  /// No description provided for @inAppSessionStarted.
  ///
  /// In en, this message translates to:
  /// **'In-app session started'**
  String get inAppSessionStarted;

  /// No description provided for @proposeAnotherTime.
  ///
  /// In en, this message translates to:
  /// **'Propose another time'**
  String get proposeAnotherTime;

  /// No description provided for @rejoinSession.
  ///
  /// In en, this message translates to:
  /// **'Rejoin session'**
  String get rejoinSession;

  /// No description provided for @startInAppSession.
  ///
  /// In en, this message translates to:
  /// **'Start in-app session'**
  String get startInAppSession;

  /// No description provided for @callbackStatusPending.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get callbackStatusPending;

  /// No description provided for @callbackStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'ACCEPTED'**
  String get callbackStatusAccepted;

  /// No description provided for @callbackStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'DECLINED'**
  String get callbackStatusDeclined;

  /// No description provided for @callbackStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get callbackStatusCompleted;

  /// No description provided for @callbackStatusRescheduled.
  ///
  /// In en, this message translates to:
  /// **'RESCHEDULED'**
  String get callbackStatusRescheduled;

  /// No description provided for @callbackModeVoice.
  ///
  /// In en, this message translates to:
  /// **'voice'**
  String get callbackModeVoice;

  /// No description provided for @callbackModeVideo.
  ///
  /// In en, this message translates to:
  /// **'video'**
  String get callbackModeVideo;

  /// No description provided for @callbackModeChat.
  ///
  /// In en, this message translates to:
  /// **'chat'**
  String get callbackModeChat;
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
      <String>['am', 'en', 'om', 'so', 'ti'].contains(locale.languageCode);

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
    case 'so':
      return AppLocalizationsSo();
    case 'ti':
      return AppLocalizationsTi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
