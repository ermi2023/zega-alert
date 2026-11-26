// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Zega-alert';

  @override
  String get appSubtitle => 'Your safety companion';

  @override
  String get home => 'Home';

  @override
  String get report => 'Report';

  @override
  String get news => 'News';

  @override
  String get messages => 'Messages';

  @override
  String get settings => 'Settings';

  @override
  String get sosEmergency => 'SOS EMERGENCY';

  @override
  String get sending => 'SENDING…';

  @override
  String get sosDispatched => '🚨 SOS Dispatched';

  @override
  String unitsOnTheWay(Object count) {
    return '$count unit(s) are on the way.';
  }

  @override
  String get announcements => 'Announcements';

  @override
  String get missingPersons => 'Missing persons';

  @override
  String get wantedPersons => 'Wanted persons';

  @override
  String get reportMissing => 'Report missing';

  @override
  String get reportACrime => 'Report a crime';

  @override
  String get yourReportGoesTo => 'Your report goes to the regional police.';

  @override
  String get newCrimeReport => 'New crime report';

  @override
  String get myReports => 'My reports';

  @override
  String get noReportsYet => 'You have not submitted any reports yet.';

  @override
  String get title => 'Title';

  @override
  String get description => 'Description';

  @override
  String get category => 'Category';

  @override
  String get severity => 'Severity';

  @override
  String get reportAnonymously => 'Report anonymously';

  @override
  String get evidenceOptional => 'Evidence (optional)';

  @override
  String get submitReport => 'Submit report';

  @override
  String get submitting => 'Submitting…';

  @override
  String get newsAndInformation => 'News & Information';

  @override
  String get announcementsTab => 'Announcements';

  @override
  String get legalTab => 'Legal';

  @override
  String get missingTab => 'Missing';

  @override
  String get sightingsTab => 'Sightings';

  @override
  String get reportAMissingPerson => 'Report a missing person';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle =>
      'Manage your account, language, zones and accessibility';

  @override
  String get account => 'Account';

  @override
  String get fullName => 'Full name';

  @override
  String get location => 'Location';

  @override
  String get locationLabel => 'Location';

  @override
  String get region => 'Region';

  @override
  String get regionLabel => 'Region';

  @override
  String get subCity => 'Sub-city / Woreda';

  @override
  String get subCityLabel => 'Sub-city / Woreda';

  @override
  String get languageLabel => 'Language';

  @override
  String get preferredLanguage => 'Preferred language';

  @override
  String get safetyZones => 'Safety zones (geofences)';

  @override
  String get safetyZonesTab => 'Zones';

  @override
  String get safetyZonesHomeDescription =>
      'Safety-zone updates and emergency incidents inside a zone are added to your notification inbox and sent as push alerts when notifications are enabled. Select an area below to see its map and boundary. Follow local instructions; a zone does not guarantee safety.';

  @override
  String get noSafetyZonesAvailable =>
      'No official safety zones are currently published for your region.';

  @override
  String get safetyZonesLoadFailed =>
      'Safety-zone information could not be loaded. Try again.';

  @override
  String get addSafetyZone => 'Add safety zone';

  @override
  String get legalInformation => 'Legal information';

  @override
  String get accessibilityTitle => 'Accessibility (People of Determination)';

  @override
  String get accessibilitySubtitle =>
      'Larger text, high contrast, voice-assisted actions';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get darkModeSubtitle => 'Use dark theme across the app';

  @override
  String get callbackRequests => 'Callback requests';

  @override
  String get callbackSubtitle =>
      'Respond to police follow-up calls on your reports';

  @override
  String get requestDirectCall => 'Request direct call';

  @override
  String get recordSignLanguage => 'Record sign language video';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get logout => 'Logout';

  @override
  String get logoutLabel => 'Logout';

  @override
  String get signingIn => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get emergencyAndCrime => 'Zega-alert · Emergency & crime reporting';

  @override
  String get phone => 'Phone';

  @override
  String get password => 'Password';

  @override
  String get register => 'Register';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get newHere => 'New here? Create account';

  @override
  String get callbackTitle => 'Callback requests';

  @override
  String get callbackDescription =>
      'Police request callbacks to follow up on your reports.';

  @override
  String get noCallbacksYet => 'No callback requests yet.';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get offlineMode => 'Offline mode — showing cached data';

  @override
  String get ok => 'OK';

  @override
  String get sosSent => 'SOS sent. Units dispatched. Stay where you are.';

  @override
  String get share => 'Share';

  @override
  String shareAnnouncement(Object title) {
    return 'Share announcement: $title';
  }

  @override
  String get missing => 'MISSING';

  @override
  String get wanted => 'WANTED';

  @override
  String get reportSighting => 'Report a sighting';

  @override
  String shareMissingPerson(Object name) {
    return 'Share missing person: $name';
  }

  @override
  String shareWantedPerson(Object name) {
    return 'Share wanted person: $name';
  }

  @override
  String lastSeen(Object location) {
    return 'Last seen: $location';
  }

  @override
  String get nothingHereYet => 'Nothing here yet.';

  @override
  String get citizenSightingsInfo =>
      'Citizen sightings are shown to police in real time.';

  @override
  String get unknownLocation => 'Unknown location';

  @override
  String get pleaseWait => 'Please wait…';

  @override
  String get enterOtp => 'Enter OTP';

  @override
  String get checkOtpHint => 'Check server console for dev OTP';

  @override
  String get verify => 'Verify';

  @override
  String get required => 'Required';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get rateResponse => 'Rate the response';

  @override
  String get commentOptional => 'Comment (optional)';

  @override
  String get thanksFeedback => 'Thanks for your feedback!';

  @override
  String get rateThisResponse => 'Rate this response';

  @override
  String get reportSubmitted => 'Report submitted. Thank you.';

  @override
  String uploadFailed(Object error) {
    return 'Upload failed: $error';
  }

  @override
  String get translate => 'Translate';

  @override
  String get showOriginal => 'Show original';

  @override
  String addType(Object type) {
    return 'Add $type';
  }

  @override
  String get url => 'URL';

  @override
  String get filePathNote => 'File path / note';

  @override
  String get noScheduledSlot => 'No scheduled slot';

  @override
  String get reportFollowUp => 'Report follow-up';

  @override
  String get mode => 'Mode';

  @override
  String get contactStaff => 'Contact a staff member';

  @override
  String get staffPhoneHint => 'Staff phone, e.g. 0911000003';

  @override
  String get startChat => 'Start chat';

  @override
  String get userNotFound => 'User not found';

  @override
  String get noConversations => 'No conversations';

  @override
  String get newChat => 'New chat';

  @override
  String get typeMessage => 'Type a message…';

  @override
  String get send => 'Send';

  @override
  String get missingPersonReportSubmitted => 'Missing person report submitted.';

  @override
  String get fullNameMissingPerson => 'Full name of missing person';

  @override
  String get ageOptional => 'Age (optional)';

  @override
  String get gender => 'Gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get unknown => 'Unknown';

  @override
  String get lastSeenLocation => 'Last seen location (address)';

  @override
  String get lastSeenDateTime => 'Last seen date & time (optional)';

  @override
  String lastSeenPrefix(Object datetime) {
    return 'Last seen: $datetime';
  }

  @override
  String get descriptionIdentifying => 'Description / identifying details';

  @override
  String get sightingReported => 'Sighting reported. Thank you for helping.';

  @override
  String get whereSeen => 'Where did you see them?';

  @override
  String get whenOptional => 'When? (optional)';

  @override
  String seenAt(Object datetime) {
    return 'Seen at: $datetime';
  }

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get submitSighting => 'Submit sighting';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get idNumberPhotoRequired =>
      'Please enter your ID number and take a photo of your ID card.';

  @override
  String get verificationSubmitted => 'Verification submitted.';

  @override
  String get faydaIdVerification => 'Fayda National ID Verification';

  @override
  String get verified => 'Verified';

  @override
  String get notVerified => 'Not Verified';

  @override
  String get identityVerifiedDesc =>
      'Your identity has been verified via Fayda National ID.';

  @override
  String get verifyIdentityDesc =>
      'Verify your identity to build trust and enable all features.';

  @override
  String get scanFaydaId => 'Scan your Fayda National ID card';

  @override
  String get scanIdInstruction =>
      'Take a clear photo of the front of your ID card. Your information will be verified against the Fayda database.';

  @override
  String get tapToScanId => 'Tap to scan ID card';

  @override
  String get faydaIdNumber => 'Fayda ID Number';

  @override
  String get faydaIdHint => 'e.g. 1234567890123';

  @override
  String get fullNameAsOnId => 'Full name (as on ID)';

  @override
  String get verifying => 'Verifying...';

  @override
  String get submitForVerification => 'Submit for Verification';

  @override
  String get connecting => 'Connecting...';

  @override
  String get ringing => 'Ringing...';

  @override
  String get uploading => 'Uploading…';

  @override
  String get newSafetyZone => 'New safety zone';

  @override
  String get name => 'Name';

  @override
  String get type => 'Type';

  @override
  String get centerLatitude => 'Center latitude';

  @override
  String get centerLongitude => 'Center longitude';

  @override
  String get radiusMeters => 'Radius (meters)';

  @override
  String get create => 'Create';

  @override
  String get safetyZoneCreated => 'Safety zone created.';

  @override
  String get safetyZoneDeleted => 'Safety zone deleted.';

  @override
  String get noLegalContent => 'No legal content available.';

  @override
  String get identityVerification => 'Identity Verification';

  @override
  String get faydaVerificationSubtitle =>
      'Verify your identity with your national ID card';

  @override
  String get accessibilityModePoD => 'Accessibility mode (PoD)';

  @override
  String callingNumber(Object number) {
    return 'Calling $number…';
  }

  @override
  String couldNotStartCall(Object error) {
    return 'Could not start the call: $error';
  }

  @override
  String get recordingCancelled => 'Recording cancelled.';

  @override
  String signLanguageUploaded(Object name) {
    return 'Sign language video uploaded ($name).';
  }

  @override
  String get signLanguageRecorded => 'Sign language video recorded & uploaded.';

  @override
  String couldNotRecordVideo(Object error) {
    return 'Could not record/upload video: $error';
  }

  @override
  String get incomingCall => 'Incoming Call';

  @override
  String callerIsCalling(Object name) {
    return '$name is calling you';
  }

  @override
  String get photoOfPerson => 'Photo of the person (optional)';

  @override
  String get photoOfSighting => 'Photo of sighting (optional)';

  @override
  String newCallbackRequest(Object title) {
    return 'New callback request for \"$title\"';
  }

  @override
  String get open => 'Open';

  @override
  String sosUpdated(Object status) {
    return 'Your SOS is now $status';
  }

  @override
  String get searchMissingWantedPeople => 'Search missing or wanted people';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get closeSearch => 'Close search';

  @override
  String get searchPeople => 'Search people';

  @override
  String get notifications => 'Notifications';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get markRead => 'Mark read';

  @override
  String get noNotificationsYet => 'No notifications yet.';

  @override
  String get retry => 'Retry';

  @override
  String get safetyZoneNoLongerActive =>
      'This area is no longer active. Check Safety Zones for current information.';

  @override
  String get couldNotOpenSafetyZone => 'Could not open this safety-zone map.';

  @override
  String get helpAndAccessibility => 'Help & accessibility';

  @override
  String get policeRescueContacts => 'Police and rescue contacts';

  @override
  String get personalInformation => 'Personal information';

  @override
  String get emailAddress => 'Email address';

  @override
  String get safetyZoneEntryAlerts => 'Safety Zone entry alerts';

  @override
  String get safetyZoneEntryAlertsDescription =>
      'When enabled, ZEGA Alert checks your location in the background and alerts you when you enter an active published Safety Zone. Available on Android.';

  @override
  String get safetyZoneLocationPrivacy =>
      'Precise location for these alerts stays on this device and is not uploaded. Android shows an ongoing notification while monitoring; this can use more battery. SOS and report actions may use location separately. Your saved Region/Sub-city fields remain the manual fallback and still control area-based information.';

  @override
  String get allowBackgroundLocation => 'Allow background location';

  @override
  String get allowBackgroundLocationDescription =>
      'To check for Safety Zone entry while ZEGA Alert is closed, Android must allow location access all the time. In app permissions, choose “Allow all the time”.';

  @override
  String get openAppSettings => 'Open app settings';

  @override
  String get notNow => 'Not now';

  @override
  String get safetyZoneAlertsOn => 'Safety Zone entry alerts are on.';

  @override
  String get safetyZoneAlertsOff => 'Safety Zone location alerts are off.';

  @override
  String get safetyZoneAlertsOnNoZones =>
      'Location alerts are on. No published Safety Zones are available yet.';

  @override
  String get security => 'Security';

  @override
  String get preferences => 'Preferences';

  @override
  String get offlineData => 'Offline data';

  @override
  String get savePersonPhotos => 'Save wanted and missing-person photos';

  @override
  String get savePersonPhotosDescription =>
      'Photos you view are stored on this device for offline access. This is off by default.';

  @override
  String get clearSavedPhotos => 'Clear saved person photos';

  @override
  String get clearSavedPhotosConfirmation => 'Clear saved person photos?';

  @override
  String get clearSavedPhotosDescription =>
      'This removes wanted and missing-person photos saved on this device. They can be saved again while photo storage is enabled.';

  @override
  String photosCountAndStorage(Object count, Object size) {
    return '$count photos · $size used';
  }

  @override
  String get officialSafetyAreasDescription =>
      'View official safety areas published by local authorities. New or changed areas and emergency incidents inside a zone appear in Notifications; push alerts require device notifications to be enabled. This information does not guarantee safety.';

  @override
  String get noOfficialSafetyAreas =>
      'No official safety areas are available for this region yet.';

  @override
  String officialSafetyArea(Object name, Object type) {
    return 'Official safety area: $name. Type: $type.';
  }

  @override
  String get mappedBoundary => 'Mapped boundary';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get currentPasswordRequired => 'Enter your current password.';

  @override
  String get passwordMinimumLength => 'Use at least 8 characters.';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match.';

  @override
  String get updatePassword => 'Update password';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get welcomeSafetyMessage =>
      'Thank you for helping keep our community safe.';

  @override
  String get phoneNumberOrEmail => 'Phone number or email';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get logIn => 'Log in';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get signInBiometrics => 'Sign in with biometrics';

  @override
  String get continueAsGuest => 'Continue as guest';

  @override
  String get signUp => 'Sign up';

  @override
  String get validEmailRequired => 'Enter a valid email address.';

  @override
  String get validPhoneOrEmailRequired =>
      'Enter a valid phone number or email.';

  @override
  String get invalidCredentials =>
      'Invalid phone/email or password. Please try again.';

  @override
  String get accountNotFound => 'No account found with this phone/email.';

  @override
  String get signInFailed =>
      'Sign in could not be completed. Please try again.';
}
