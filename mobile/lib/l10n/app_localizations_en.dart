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
  String get sosDispatched => 'DISPATCHED';

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
  String get noScheduledSlot => 'No scheduled time';

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

  @override
  String get police => 'Police';

  @override
  String get ambulanceRescue => 'Ambulance / rescue';

  @override
  String regionSelectedSemantics(Object region) {
    return 'Region dropdown. Currently set to $region.';
  }

  @override
  String subCitySelectedSemantics(Object subCity) {
    return 'Sub-city dropdown. Currently set to $subCity.';
  }

  @override
  String languageSelectedSemantics(Object language) {
    return 'Preferred language dropdown. Currently set to $language.';
  }

  @override
  String get citizenProfile => 'Citizen profile';

  @override
  String get verifiedAccount => 'Verified account';

  @override
  String get unverifiedAccount => 'Unverified account';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get notAvailable => 'Not available';

  @override
  String get memberSince => 'Member since';

  @override
  String get verificationStatus => 'Verification status';

  @override
  String get guestBrowsing => 'Browsing as guest';

  @override
  String get guestFeaturesInfo =>
      'Sign in to file reports, send SOS, message officers and verify your ID.';

  @override
  String get signInCreateAccount => 'Sign in / Create account';

  @override
  String get fanIdentityTitle => 'FAN identity verification';

  @override
  String get fanIdentityDescription =>
      'Scan your original ID QR or enter its 16-digit FAN to check the administrator’s mock record.';

  @override
  String get settingsSaved => 'Profile and settings saved.';

  @override
  String get settingsSaveFailed => 'Could not save your profile.';

  @override
  String get notificationLoadFailed =>
      'Could not load notifications right now.';

  @override
  String get backgroundLocationPermissionRequired =>
      'Choose “Allow all the time” in app permissions, then turn on Safety Zone alerts again.';

  @override
  String get backgroundLocationAndroidOnly =>
      'Background Safety Zone alerts are currently available on Android.';

  @override
  String get turnOnDeviceLocation =>
      'Turn on device Location to enable Safety Zone alerts.';

  @override
  String get alwaysLocationPermission =>
      'Allow ZEGA Alert to access location all the time in app permissions, then turn Safety Zone alerts on again.';

  @override
  String get safetyNotificationsUnavailable =>
      'Safety Zone notifications are not available on this device.';

  @override
  String get allowSafetyNotifications =>
      'Allow notifications for ZEGA Alert to receive Safety Zone entry alerts.';

  @override
  String get couldNotEnableSafetyZoneAlerts =>
      'Could not enable Safety Zone alerts. Check your connection, location permission, and notification settings.';

  @override
  String get couldNotStartLocationMonitoring =>
      'Could not start Safety Zone location monitoring.';

  @override
  String get couldNotRestartLocationMonitoring =>
      'Could not restart Safety Zone location monitoring.';

  @override
  String get locationMonitoringStopped =>
      'Location monitoring stopped. Check device Location and permissions.';

  @override
  String get couldNotCheckZoneBoundaries =>
      'Could not check the current Safety Zone boundaries.';

  @override
  String get biometricCancelled => 'Biometric authentication was cancelled.';

  @override
  String get settingsLoadFailed => 'Could not load settings right now.';

  @override
  String get savedPhotoStorageFailed => 'Could not read saved photo storage.';

  @override
  String get photoStorageUpdateFailed =>
      'Could not update photo storage settings.';

  @override
  String get photoStorageClearFailed => 'Could not clear saved photos.';

  @override
  String get passwordChanged => 'Password changed successfully.';

  @override
  String get passwordChangeFailed => 'Could not change your password.';

  @override
  String get clearPhotos => 'Clear photos';

  @override
  String get clearSavedPersonPhotosTitle => 'Clear saved person photos?';

  @override
  String get clearSavedPersonPhotosBody =>
      'This removes wanted and missing-person photos saved on this device. They can be saved again while photo storage is enabled.';

  @override
  String get aboutSupport => 'About & support';

  @override
  String get aboutZegaAlert => 'About ZEGA-ALERT';

  @override
  String get version => 'Version';

  @override
  String get termsConditions => 'Terms & Conditions';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get rateZegaAlert => 'Rate ZEGA-ALERT';

  @override
  String get chatWithAdmin => 'Chat with Admin';

  @override
  String get followUpOnReports => 'Follow up on reports';

  @override
  String get leaveFeedback => 'Leave Feedback';

  @override
  String get feedbackHint => 'Tell us how we can improve...';

  @override
  String get feedbackSubmitted => 'Feedback submitted. Thank you!';

  @override
  String get contactUs => 'Contact us';

  @override
  String get policeEmergency => 'Police emergency';

  @override
  String get emailSupport => 'Email support';

  @override
  String get close => 'Close';

  @override
  String get searchAppStoreToRate =>
      'Search for ZEGA-ALERT in your app store to rate us.';

  @override
  String aboutBody(Object version) {
    return 'ZEGA-ALERT is the Ethiopian Federal Police citizen safety app. It connects you to emergency dispatch, crime reporting, missing and wanted persons, official announcements and two-way communication with officers — in English, Amharic, Oromifa, Tigrinya and Ethio Somali.\n\nVersion $version';
  }

  @override
  String get termsBody =>
      '1. Use ZEGA-ALERT only for genuine emergencies, crime reports and public-safety information.\n\n2. Knowingly sending false reports is an offence and may lead to account suspension and legal action.\n\n3. Emergency features depend on network coverage and location services. Always call 991 if the app cannot connect.\n\n4. Reports you submit are shared with the responsible police station and regional administrators for investigation.\n\n5. Keep your account credentials private. You are responsible for activity on your account.';

  @override
  String get privacyBody =>
      'ZEGA-ALERT collects only the information needed to keep you safe: your name, phone number, region and the content of reports you choose to submit.\n\nLocation is used for SOS alerts, nearest-station lookup, safety zones and incident mapping. It is transmitted only while you use these features.\n\nContact details on missing-person notices are encrypted at rest. Sensitive information is visible only to authorised police staff.\n\nYou can browse news, wanted and missing persons as a guest. You can delete your account by contacting support.';

  @override
  String get onboardingEmergencyTitle => 'Emergency SOS';

  @override
  String get onboardingEmergencySubtitle =>
      'Press SOS to alert nearby police and share your location. If the app cannot connect, call 991.';

  @override
  String get onboardingReportTitle => 'Report Crime Safely';

  @override
  String get onboardingReportSubtitle =>
      'Send a crime report with details and photos. You can choose whether to include your identity.';

  @override
  String get onboardingMissingTitle => 'Find Missing Persons';

  @override
  String get onboardingMissingSubtitle =>
      'View missing-person and wanted alerts. Report a sighting to help police and families.';

  @override
  String get onboardingRegionTitle => 'Set Your Region';

  @override
  String get onboardingRegionSubtitle =>
      'Choose your region in Settings to see local alerts and receive Safety Zone notifications.';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get callbacksLoadFailed =>
      'Could not load callback requests right now.';

  @override
  String get callbackUpdateFailed => 'Could not update the callback request.';

  @override
  String get chooseFutureTime => 'Choose a future time.';

  @override
  String get alternativeTimeSent => 'Alternative time sent to the officer.';

  @override
  String get callbackSendFailed => 'Could not send the callback update.';

  @override
  String get callbackSessionStartFailed => 'Could not start the session.';

  @override
  String youProposedSlot(Object slot) {
    return 'You proposed: $slot';
  }

  @override
  String get waitingForOfficer => 'Waiting for officer';

  @override
  String get inAppSessionStarted => 'In-app session started';

  @override
  String get proposeAnotherTime => 'Propose another time';

  @override
  String get rejoinSession => 'Rejoin session';

  @override
  String get startInAppSession => 'Start in-app session';

  @override
  String get callbackStatusPending => 'PENDING';

  @override
  String get callbackStatusAccepted => 'ACCEPTED';

  @override
  String get callbackStatusDeclined => 'DECLINED';

  @override
  String get callbackStatusCompleted => 'COMPLETED';

  @override
  String get callbackStatusRescheduled => 'RESCHEDULED';

  @override
  String get callbackModeVoice => 'voice';

  @override
  String get callbackModeVideo => 'video';

  @override
  String get callbackModeChat => 'chat';

  @override
  String get accessibilityActionsDescription =>
      'Request a direct call or record a sign-language video.';

  @override
  String get switchToStreetMap => 'Switch to street map';

  @override
  String get switchToSatelliteImagery => 'Switch to satellite imagery';

  @override
  String get areaBoundaryNotAvailable =>
      'The area boundary is not available yet.';

  @override
  String get safetyArea => 'Safety area';

  @override
  String get officialMappedBoundary =>
      'Official mapped boundary. SOS reports inside it are highlighted for emergency staff.';

  @override
  String officialRadiusBoundary(Object radius) {
    return 'Official area · $radius m radius. SOS reports inside it are highlighted for emergency staff.';
  }

  @override
  String get safetyZoneSavedBoundaryWarning =>
      'On-device entry alerts are using saved zone boundaries. Reconnect and refresh Safety Zones to update them.';

  @override
  String get loadingSafetyZones => 'Loading safety zones';

  @override
  String get retryLoadingSafetyZones => 'Retry loading safety zones';

  @override
  String get openMapAndBoundary => 'Open map and boundary.';

  @override
  String get conversationsLoadFailed =>
      'Could not load conversations right now.';

  @override
  String get fileUploadFailed => 'Could not upload the file.';

  @override
  String newMessageLabel(Object message) {
    return 'New message: $message';
  }

  @override
  String get enableLocationForNearestPolice =>
      'Enable location to find the nearest police station.';

  @override
  String get stationChatStartFailed => 'Could not start the station chat.';

  @override
  String get rateConversation => 'Rate this conversation';

  @override
  String get noAccountForCall =>
      'Could not identify your account for this call.';

  @override
  String get noOtherParticipant => 'No other participant to call.';

  @override
  String get callStartFailed => 'Could not start the call.';

  @override
  String get videoCall => 'Video call';

  @override
  String get chatNearestStation => 'Chat with nearest police station';

  @override
  String get dispatcherAvailableNow => 'A dispatcher is available now';

  @override
  String estimatedWaitMinutes(Object minutes) {
    return 'Estimated wait: $minutes min';
  }

  @override
  String get photoAttachment => 'Photo';

  @override
  String get videoAttachment => 'Video';

  @override
  String get audioAttachment => 'Audio';

  @override
  String get fileAttachment => 'File';

  @override
  String get couldNotSubmitFeedback => 'Could not submit your feedback.';

  @override
  String get submitAction => 'Submit';

  @override
  String get reportsFollowUpChat => 'Follow-up / Chat';

  @override
  String get reportsSearchHint => 'Search reports';

  @override
  String get reportFilterAll => 'All';

  @override
  String get reportFilterActive => 'Active';

  @override
  String get reportFilterResolved => 'Resolved';

  @override
  String get reportFilterDrafts => 'Drafts';

  @override
  String get photoCameraRecord => 'Take a photo / record';

  @override
  String get crimeCategoryField => 'Crime category';

  @override
  String get incidentDateTime => 'Incident date/time';

  @override
  String get enterLocationManually => 'Enter location manually';

  @override
  String get otherwiseUseGps => 'Otherwise use GPS';

  @override
  String get addressLabel => 'Address';

  @override
  String get latitudeLabel => 'Latitude';

  @override
  String get longitudeLabel => 'Longitude';

  @override
  String get photo => 'Photo';

  @override
  String get video => 'Video';

  @override
  String get audio => 'Audio';

  @override
  String get signLanguage => 'Sign language';

  @override
  String get link => 'Link';

  @override
  String get file => 'File';

  @override
  String get saveAsDraft => 'Save as draft';

  @override
  String evidenceAttached(Object type) {
    return '$type attached.';
  }

  @override
  String get crimeTheft => 'Theft';

  @override
  String get crimeRobbery => 'Robbery';

  @override
  String get crimeAssault => 'Assault';

  @override
  String get crimeBurglary => 'Burglary / break-in';

  @override
  String get crimeVandalism => 'Vandalism';

  @override
  String get crimeFraud => 'Fraud / scam';

  @override
  String get crimeHarassment => 'Harassment';

  @override
  String get crimeDrug => 'Drug offence';

  @override
  String get crimeTraffic => 'Traffic incident';

  @override
  String get crimeDomesticViolence => 'Domestic violence';

  @override
  String get crimeKidnapping => 'Kidnapping';

  @override
  String get crimeMurder => 'Murder / homicide';

  @override
  String get crimeOther => 'Other';

  @override
  String get severityLow => 'Low';

  @override
  String get severityMedium => 'Medium';

  @override
  String get severityHigh => 'High';

  @override
  String get severityCritical => 'Critical';

  @override
  String get reportsLoadFailed => 'Could not load reports right now.';

  @override
  String get reportSubmissionFailed =>
      'Could not submit the report. Please try again.';

  @override
  String get reportStatusPending => 'PENDING';

  @override
  String get reportStatusSubmitted => 'SUBMITTED';

  @override
  String get reportStatusInReview => 'IN REVIEW';

  @override
  String get reportStatusInvestigating => 'INVESTIGATING';

  @override
  String get reportStatusAssigned => 'ASSIGNED';

  @override
  String get reportStatusRejected => 'REJECTED';

  @override
  String get reportStatusClosed => 'CLOSED';

  @override
  String get noReportsMatchFilter => 'No reports match this filter.';

  @override
  String get untitledReport => 'Untitled report';

  @override
  String rateResponseForReport(Object title) {
    return 'Rate response for report: $title';
  }

  @override
  String get reportDetailsTitle => 'Report details';

  @override
  String get reportDetailsLoadFailed => 'Could not load this report right now.';

  @override
  String get attachEvidence => 'Attach evidence';

  @override
  String get working => 'Working…';

  @override
  String get reportEvidenceAttached => 'Evidence attached.';

  @override
  String get reportEvidenceAttachFailed => 'Could not attach the evidence.';

  @override
  String get reportSubmittedForReview => 'Report submitted for review.';

  @override
  String get reportSubmitFailed => 'Could not submit the report.';

  @override
  String get photoVideo => 'Photo / video';

  @override
  String get documentAudio => 'Document / audio';

  @override
  String incidentDateTimeValue(Object value) {
    return 'Incident date/time: $value';
  }

  @override
  String reportedValue(Object value) {
    return 'Reported: $value';
  }

  @override
  String resolvedValue(Object value) {
    return 'Resolved: $value';
  }

  @override
  String locationCoordinates(Object latitude, Object longitude) {
    return 'Location: $latitude, $longitude';
  }

  @override
  String anonymousValue(Object value) {
    return 'Anonymous: $value';
  }

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get evidenceTitle => 'Evidence';

  @override
  String get statusHistoryTitle => 'Status history';

  @override
  String get noHistoryYet => 'No history yet.';

  @override
  String byUser(Object name) {
    return 'by $name';
  }

  @override
  String get signInToSendSos =>
      'Sign in to send an SOS alert with your live location.';

  @override
  String get sosSendingStatus =>
      'Getting GPS coordinates and connecting to dispatch…';

  @override
  String sosNotifyCountdown(Object seconds) {
    return 'Notifying nearby police in $seconds seconds…';
  }

  @override
  String get sosCancelAbort => 'CANCEL / ABORT';

  @override
  String get sosNoDispatchRecipients =>
      'SOS alert saved, but no station officers or central dispatch recipients are available.';

  @override
  String get sosNearestNoOfficers =>
      'Nearest station has no assigned officers. SOS sent to central dispatch.';

  @override
  String get sosLocationMissingCentral =>
      'SOS sent to central dispatch because location was unavailable.';

  @override
  String sosSentToStation(Object station) {
    return 'SOS sent to $station. Responding officers notified.';
  }

  @override
  String get sosSendFailed =>
      'Could not send the emergency alert. Please try again.';

  @override
  String get sosLiveStreamFailed =>
      'Could not connect the live stream. Please try again.';

  @override
  String get sosEmergencyTitle => 'EMERGENCY SOS';

  @override
  String get sosHelpIsOnWay => 'HELP IS ON THE WAY';

  @override
  String get sosLivePatrolActive => 'Live patrol dispatch active';

  @override
  String get sosRespondingUnits => 'Responding Patrol Units';

  @override
  String get sosRoutingOfficer => 'Routing nearest regional officer…';

  @override
  String sosEtaMinutes(Object minutes) {
    return '$minutes min';
  }

  @override
  String get sosCalculating => 'calculating…';

  @override
  String sosDistanceAway(Object distance) {
    return ' · $distance km away';
  }

  @override
  String get sosOfficerOnDuty => 'Officer On Duty';

  @override
  String sosEtaWithDistance(Object distance, Object eta) {
    return 'ETA: $eta$distance';
  }

  @override
  String get sosSafeEndEmergency => 'I AM SAFE / END EMERGENCY';

  @override
  String get sosLiveConnecting => 'Connecting to dispatch…';

  @override
  String get sosLiveWaiting => 'Waiting for dispatch to answer…';

  @override
  String get sosLiveNow => 'Live with dispatch';

  @override
  String get sosLiveInterrupted => 'Connection interrupted';

  @override
  String get sosLiveEnded => 'Live stream ended';

  @override
  String get sosLiveStartFailed => 'Could not start live stream';

  @override
  String get sosLiveTitle => 'Live audio/video for dispatch';

  @override
  String get sosLivePrivacyNote =>
      'Live media is streamed to dispatch staff and is not saved as a recording.';

  @override
  String get sosEnd => 'END';

  @override
  String get sosStartLiveAudio => 'Start live audio';

  @override
  String get sosStartLiveVideo => 'Start live video';

  @override
  String get sosStatusEnRoute => 'EN ROUTE';

  @override
  String get nearestPoliceStation => 'the nearest police station';

  @override
  String get callbackSessionTitle => 'Callback session';

  @override
  String get otherCallParticipantNotFound =>
      'Could not find the other call participant.';

  @override
  String get inAppChatSession => 'In-app chat session';

  @override
  String inAppSessionMode(Object mode) {
    return 'In-app $mode session';
  }

  @override
  String get callbackVideoActiveDescription =>
      'Callback session active · start a live video call when ready';

  @override
  String get connectedInsideApp =>
      'Connected · this session stays inside ZEGA-ALERT';

  @override
  String get startLiveVideoConversation => 'Start live video conversation';

  @override
  String get ending => 'Ending…';

  @override
  String get endSession => 'End session';

  @override
  String get callbackSessionEndFailed => 'Could not end the session.';

  @override
  String officerNamed(Object name) {
    return 'Officer: $name';
  }

  @override
  String get refreshWantedMissing => 'Refresh wanted and missing people';

  @override
  String reportSightingForPerson(Object name) {
    return 'Report Sighting: $name';
  }

  @override
  String get signInToReportSighting => 'Sign in to report a sighting.';

  @override
  String get writeCommentHint => 'Write a comment...';

  @override
  String get newsScreenDescription =>
      'News, road closures, wanted & missing persons, and lost items';

  @override
  String get refresh => 'Refresh';

  @override
  String get categoryLabel => 'Category';

  @override
  String get allItems => 'All';

  @override
  String get authGateTitle => 'Sign in to continue';

  @override
  String get authGateMessage =>
      'Create a free ZEGA-ALERT account or sign in to use this feature.';

  @override
  String get signInRequiredTitle => 'Sign in required';

  @override
  String get signInRequiredMessage =>
      'Please sign in or create a free account to continue.';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String updateAvailableMessage(Object version) {
    return 'Version $version is available. Update now?';
  }

  @override
  String get later => 'Later';

  @override
  String get download => 'Download';

  @override
  String get backendServer => 'Backend server';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUrlHelp =>
      'Leave blank to auto-detect on the local network.';

  @override
  String get autoDetect => 'Auto-detect';

  @override
  String get save => 'Save';

  @override
  String serverCurrentUrl(Object url) {
    return 'Server: $url';
  }

  @override
  String get ethiopianMobileNumber => 'Ethiopian mobile number';

  @override
  String get validEthiopianMobileNumber =>
      'Enter a valid Ethiopian mobile number.';

  @override
  String get emailOptional => 'Email (optional)';

  @override
  String get emailSignInHint => 'Add an email so you can also sign in with it';

  @override
  String get phoneOrEmail => 'Phone number or email';

  @override
  String get phoneExample => 'e.g. +251 911 234 567';

  @override
  String get signUpAction => 'Sign Up';

  @override
  String get termsAcceptance =>
      'I accept the Terms of Service and Privacy Policy';

  @override
  String get registrationPasswordRequirements =>
      'At least 8 characters with an uppercase letter, number and symbol.';

  @override
  String get invalidEmailAddress => 'Enter a valid email address.';

  @override
  String get invalidPhoneNumber => 'Enter a valid phone number.';

  @override
  String get connectionFailedTryAgain =>
      'Could not connect. Check your internet connection and try again.';

  @override
  String get verifyPhoneNumber => 'Verify Phone Number';

  @override
  String get back => 'Back';

  @override
  String get smsDemoCodeNotice =>
      'SMS is not configured yet. Use this temporary demo code:';

  @override
  String enterOtpSentTo(Object phone) {
    return 'Enter the 6-digit code sent to\n$phone';
  }

  @override
  String get accountRecovery => 'Account recovery';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get passwordResetSuccessful => 'Password reset successful!';

  @override
  String get passwordUpdatedSignIn =>
      'Your password has been updated. Sign in with your new password.';
}
