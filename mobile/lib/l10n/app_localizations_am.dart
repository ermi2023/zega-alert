// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appTitle => 'ዛጋ-አለርት';

  @override
  String get appSubtitle => 'የእርስዎ ደህንነት ባልደረባ';

  @override
  String get home => 'መነሻ';

  @override
  String get report => 'ሪፖርት';

  @override
  String get news => 'ዜና';

  @override
  String get messages => 'መልዕክቶች';

  @override
  String get settings => 'ማስተካከያ';

  @override
  String get sosEmergency => 'SOS ድንገተኛ አደጋ';

  @override
  String get sending => 'በመላክ ላይ…';

  @override
  String get sosDispatched => '🚨 SOS ተልኳል';

  @override
  String unitsOnTheWay(Object count) {
    return '$count ክፍሎች በመንገድ ላይ ናቸው።';
  }

  @override
  String get announcements => 'ማሳወቂያዎች';

  @override
  String get missingPersons => 'የጠፉ ሰዎች';

  @override
  String get wantedPersons => 'የሚፈለጉ ሰዎች';

  @override
  String get reportMissing => 'ጠፋውን ለማሳወቅ';

  @override
  String get reportACrime => 'ወንጀል ሪፖርት አድርግ';

  @override
  String get yourReportGoesTo => 'ሪፖርትዎ ወደ ክልላዊ ፖሊስ ይሄዳል።';

  @override
  String get newCrimeReport => 'አዲስ የወንጀል ሪፖርት';

  @override
  String get myReports => 'የእኔ ሪፖርቶች';

  @override
  String get noReportsYet => 'እስካሁን ምንም ሪፖርት አላስገቡም።';

  @override
  String get title => 'ርዕስ';

  @override
  String get description => 'መግለጫ';

  @override
  String get category => 'ምድብ';

  @override
  String get severity => 'የአሳሳቢነት ደረጃ';

  @override
  String get reportAnonymously => 'በስም ሳይገልጹ ሪፖርት አድርግ';

  @override
  String get evidenceOptional => 'ማስረጃ (አማራጭ)';

  @override
  String get submitReport => 'ሪፖርት አስገባ';

  @override
  String get submitting => 'በማስገባት ላይ…';

  @override
  String get newsAndInformation => 'ዜና እና መረጃ';

  @override
  String get announcementsTab => 'ማሳወቂያዎች';

  @override
  String get legalTab => 'ህግ';

  @override
  String get missingTab => 'ጠፋ';

  @override
  String get sightingsTab => 'ትዕይንቶች';

  @override
  String get reportAMissingPerson => 'የጠፋ ሰው ሪፖርት አድርግ';

  @override
  String get settingsTitle => 'ማስተካከያ';

  @override
  String get settingsSubtitle => 'መለያዎን፣ ቋንቋ፣ የደህንነት ቦታዎችን እና ተጠቃሚነትን ያስተዳድሩ';

  @override
  String get account => 'መለያ';

  @override
  String get fullName => 'ሙሉ ስም';

  @override
  String get location => 'አድራሻ';

  @override
  String get locationLabel => 'አድራሻ';

  @override
  String get region => 'ክልል';

  @override
  String get regionLabel => 'ክልል';

  @override
  String get subCity => 'ንዑስ ከተማ / ወረዳ';

  @override
  String get subCityLabel => 'ንዑስ ከተማ / ወረዳ';

  @override
  String get languageLabel => 'ቋንቋ';

  @override
  String get preferredLanguage => 'የመረጡት ቋንቋ';

  @override
  String get safetyZones => 'የደህንነት ቀጠናዎች (ጂኦፌንስ)';

  @override
  String get addSafetyZone => 'የደህንነት ቦታ አክል';

  @override
  String get legalInformation => 'የሕግ መረጃ';

  @override
  String get accessibilityTitle => 'ተጠቃሚነት (የአካል ጉዳተኞች)';

  @override
  String get accessibilitySubtitle => 'ትልቅ ጽሁፍ፣ ከፍተኛ ንጽጽር';

  @override
  String get darkMode => 'ጨለማ ሁኔታ';

  @override
  String get darkModeSubtitle => 'በመተግበሪያው ውስጥ ጨለማ ገጽታ ይጠቀሙ';

  @override
  String get callbackRequests => 'የተመላሽ ጥያቄዎች';

  @override
  String get callbackSubtitle => 'ፖሊስ በሪፖርትዎ ላይ ለሚያደርገው ክትትል ምላሽ ይስጡ';

  @override
  String get requestDirectCall => 'ቀጥታ ጥሪ ጠይቅ';

  @override
  String get recordSignLanguage => 'የምልክት ቋንቋ ቪዲዮ ቀርጽ';

  @override
  String get saveSettings => 'ማስተካከያ አስቀምጥ';

  @override
  String get logout => 'ውጣ';

  @override
  String get logoutLabel => 'መውጣት';

  @override
  String get signingIn => 'ይግቡ';

  @override
  String get createAccount => 'መለያ ፍጠር';

  @override
  String get emergencyAndCrime => 'ዛጋ-አለርት · ድንገተኛ አደጋ እና ወንጀል ሪፖርት';

  @override
  String get phone => 'ስልክ';

  @override
  String get password => 'የይለፍ ቃል';

  @override
  String get register => 'ተመዝገብ';

  @override
  String get alreadyHaveAccount => 'መለያ አለዎት? ይግቡ';

  @override
  String get newHere => 'አዲስ ነዎት? መለያ ፍጠር';

  @override
  String get callbackTitle => 'የተመላሽ ጥያቄዎች';

  @override
  String get callbackDescription => 'ፖሊስ በሪፖርትዎ ላይ ለሚያደርገው ክትትል ጥሪ ይጠይቃል።';

  @override
  String get noCallbacksYet => 'እስካሁን ምንም የተመላሽ ጥያቄ የለም።';

  @override
  String get accept => 'ተቀበል';

  @override
  String get decline => 'ውድቅ አድርግ';

  @override
  String get offlineMode => 'ከመስመር ውጪ — የተቀመጠ መረጃ በማሳየት ላይ';

  @override
  String get ok => 'እሺ';

  @override
  String get sosSent => 'SOS ተልኳል። ክፍሎች ተልከዋል። በቦታው ይቆዩ።';

  @override
  String get share => 'አካፍል';

  @override
  String shareAnnouncement(Object title) {
    return 'ማሳወቂያ አካፍል: $title';
  }

  @override
  String get missing => 'ጠፋ';

  @override
  String get wanted => 'የሚፈለግ';

  @override
  String get reportSighting => 'ትዕይንት ሪፖርት አድርግ';

  @override
  String shareMissingPerson(Object name) {
    return 'የጠፋ ሰው አካፍል: $name';
  }

  @override
  String shareWantedPerson(Object name) {
    return 'የሚፈለግ ሰው አካፍል: $name';
  }

  @override
  String lastSeen(Object location) {
    return 'ለመጨረሻ የታየው: $location';
  }

  @override
  String get nothingHereYet => 'እዚህ እስካሁን ምንም የለም።';

  @override
  String get citizenSightingsInfo => 'የዜጎች ትዕይንቶች ለፖሊስ በቀጥታ ይታያሉ።';

  @override
  String get unknownLocation => 'ያልታወቀ ቦታ';

  @override
  String get pleaseWait => 'እባክዎ ይጠብቁ…';

  @override
  String get enterOtp => 'OTP ያስገቡ';

  @override
  String get checkOtpHint => 'ለልማት OTP የሰርቨር ኮንሶልን ይመልከቱ';

  @override
  String get verify => 'አረጋግጥ';

  @override
  String get required => 'ያስፈልጋል';

  @override
  String get cancel => 'ሰርዝ';

  @override
  String get add => 'አክል';

  @override
  String get rateResponse => 'ምላሹን ደረጃ ይስጡ';

  @override
  String get commentOptional => 'አስተያየት (አማራጭ)';

  @override
  String get thanksFeedback => 'ለአስተያየትዎ እናመሰግናለን!';

  @override
  String get rateThisResponse => 'ይህን ምላሽ ደረጃ ይስጡ';

  @override
  String get reportSubmitted => 'ሪፖርት ተልኳል። እናመሰግናለን።';

  @override
  String uploadFailed(Object error) {
    return 'መጫን አልተሳካም: $error';
  }

  @override
  String addType(Object type) {
    return '$type አክል';
  }

  @override
  String get url => 'URL';

  @override
  String get filePathNote => 'የፋይል መንገድ / ማስታወሻ';

  @override
  String get noScheduledSlot => 'የተያዘ ጊዜ የለም';

  @override
  String get reportFollowUp => 'የሪፖርት ክትትል';

  @override
  String get mode => 'ዘዴ';

  @override
  String get contactStaff => 'ሰራተኛ ያግኙ';

  @override
  String get staffPhoneHint => 'የሰራተኛ ስልክ፣ ምሳሌ 0911000003';

  @override
  String get startChat => 'ውይይት ጀምር';

  @override
  String get userNotFound => 'ተጠቃሚ አልተገኘም';

  @override
  String get noConversations => 'ውይይቶች የሉም';

  @override
  String get newChat => 'አዲስ ውይይት';

  @override
  String get typeMessage => 'መልዕክት ይተይቡ…';

  @override
  String get send => 'ላክ';

  @override
  String get missingPersonReportSubmitted => 'የጠፋ ሰው ሪፖርት ተልኳል።';

  @override
  String get fullNameMissingPerson => 'የጠፋው ሰው ሙሉ ስም';

  @override
  String get ageOptional => 'እድሜ (አማራጭ)';

  @override
  String get gender => 'ጾታ';

  @override
  String get male => 'ወንድ';

  @override
  String get female => 'ሴት';

  @override
  String get unknown => 'ያልታወቀ';

  @override
  String get lastSeenLocation => 'ለመጨረሻ የታየበት ቦታ (አድራሻ)';

  @override
  String get lastSeenDateTime => 'ለመጨረሻ የታየበት ቀን እና ሰዓት (አማራጭ)';

  @override
  String lastSeenPrefix(Object datetime) {
    return 'ለመጨረሻ የታየው: $datetime';
  }

  @override
  String get descriptionIdentifying => 'መግለጫ / መለያ ዝርዝሮች';

  @override
  String get sightingReported => 'ትዕይንት ተመዝግቧል። ስለረዱ እናመሰግናለን።';

  @override
  String get whereSeen => 'የት ነበር ያዩት?';

  @override
  String get whenOptional => 'መቼ? (አማራጭ)';

  @override
  String seenAt(Object datetime) {
    return 'የታየው: $datetime';
  }

  @override
  String get descriptionOptional => 'መግለጫ (አማራጭ)';

  @override
  String get submitSighting => 'ትዕይንት አስገባ';

  @override
  String get takePhoto => 'ፎቶ ያንሱ';

  @override
  String get chooseFromGallery => 'ከጋለሪ ይምረጡ';

  @override
  String get idNumberPhotoRequired => 'እባክዎ የID ቁጥር ያስገቡ እና የID ካርድ ፎቶ ያንሱ።';

  @override
  String get verificationSubmitted => 'ማረጋገጫ ተልኳል።';

  @override
  String get faydaIdVerification => 'የፋይዳ ብሔራዊ መታወቂያ ማረጋገጫ';

  @override
  String get verified => 'የተረጋገጠ';

  @override
  String get notVerified => 'ያልተረጋገጠ';

  @override
  String get identityVerifiedDesc => 'መለያዎ በፋይዳ ብሔራዊ መታወቂያ ተረጋግጧል።';

  @override
  String get verifyIdentityDesc =>
      'እምነት ለመፍጠር እና ሁሉንም ባህሪያት ለማስቻል መለያዎን ያረጋግጡ።';

  @override
  String get scanFaydaId => 'የፋይዳ ብሔራዊ መታወቂያ ካርድዎን ይቃኙ';

  @override
  String get scanIdInstruction =>
      'የመታወቂያ ካርድዎን የፊት ጎን ግልጽ ፎቶ ያንሱ። መረጃዎ ከፋይዳ ዳታቤዝ ጋር ይረጋገጣል።';

  @override
  String get tapToScanId => 'መታወቂያ ካርድ ለመቃኘት ይንኩ';

  @override
  String get faydaIdNumber => 'የፋይዳ መታወቂያ ቁጥር';

  @override
  String get faydaIdHint => 'ምሳሌ 1234567890123';

  @override
  String get fullNameAsOnId => 'ሙሉ ስም (በመታወቂያው ላይ እንዳለ)';

  @override
  String get verifying => 'በማረጋገጥ ላይ...';

  @override
  String get submitForVerification => 'ለማረጋገጥ አስገባ';

  @override
  String get connecting => 'በመገናኘት ላይ...';

  @override
  String get ringing => 'በመደወል ላይ...';

  @override
  String get uploading => 'በመጫን ላይ…';

  @override
  String get newSafetyZone => 'አዲስ የደህንነት ቦታ';

  @override
  String get name => 'ስም';

  @override
  String get type => 'አይነት';

  @override
  String get centerLatitude => 'የማዕከል ኬክሮስ';

  @override
  String get centerLongitude => 'የማዕከል ኬንትሮስ';

  @override
  String get radiusMeters => 'ራዲየስ (ሜትር)';

  @override
  String get create => 'ፍጠር';

  @override
  String get safetyZoneCreated => 'የደህንነት ቦታ ተፈጥሯል።';

  @override
  String get safetyZoneDeleted => 'የደህንነት ቦታ ተሰርዟል።';

  @override
  String get noLegalContent => 'ምንም የሕግ መረጃ የለም።';

  @override
  String get identityVerification => 'የማንነት ማረጋገጫ';

  @override
  String get faydaVerificationSubtitle => 'መለያዎን በብሔራዊ መታወቂያ ካርድ ያረጋግጡ';

  @override
  String get accessibilityModePoD => 'የተጠቃሚነት ሁኔታ (PoD)';

  @override
  String callingNumber(Object number) {
    return '$number በመደወል ላይ…';
  }

  @override
  String couldNotStartCall(Object error) {
    return 'ጥሪውን ማስጀመር አልተቻለም: $error';
  }

  @override
  String get recordingCancelled => 'መመዝገብ ተሰርዟል።';

  @override
  String signLanguageUploaded(Object name) {
    return 'የምልክት ቋንቋ ቪዲዮ ተጭኗል ($name)።';
  }

  @override
  String get signLanguageRecorded => 'የምልክት ቋንቋ ቪዲዮ ተቀርጾ ተጭኗል።';

  @override
  String couldNotRecordVideo(Object error) {
    return 'ቪዲዮ መቅረጽ/መጫን አልተቻለም: $error';
  }

  @override
  String get incomingCall => 'ገቢ ጥሪ';

  @override
  String callerIsCalling(Object name) {
    return '$name በመደወል ላይ ነው';
  }

  @override
  String get photoOfPerson => 'የሰውየው ፎቶ (አማራጭ)';

  @override
  String get photoOfSighting => 'የትዕይንት ፎቶ (አማራጭ)';

  @override
  String newCallbackRequest(Object title) {
    return 'አዲስ የተመላሽ ጥያቄ \"$title\"';
  }

  @override
  String get open => 'ክፈት';

  @override
  String sosUpdated(Object status) {
    return 'SOSዎ አሁን $status ነው';
  }
}
