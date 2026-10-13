// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Oromo (`om`).
class AppLocalizationsOm extends AppLocalizations {
  AppLocalizationsOm([String locale = 'om']) : super(locale);

  @override
  String get appTitle => 'ZEYGAA-ALERT';

  @override
  String get appSubtitle => 'Kabaja madda kee';

  @override
  String get home => 'Manaa';

  @override
  String get report => 'Waraanna';

  @override
  String get news => 'Oduu';

  @override
  String get messages => 'Ergaa';

  @override
  String get settings => 'Qindaa\'ina';

  @override
  String get sosEmergency => 'SOS AFEEJJII';

  @override
  String get sending => 'Ergamu jira…';

  @override
  String get sosDispatched => '🚨 SOS ergame';

  @override
  String unitsOnTheWay(Object count) {
    return 'Gartuu $count karaa irratti jiru.';
  }

  @override
  String get announcements => 'Beekaa';

  @override
  String get missingPersons => 'Namoota hargartan';

  @override
  String get wantedPersons => 'Namoota barbaachisan';

  @override
  String get reportMissing => 'Hargartan beekaa';

  @override
  String get reportACrime => 'Rookaa beekaa';

  @override
  String get yourReportGoesTo => 'Waraanna kee govtii naannoo keessa ergama.';

  @override
  String get newCrimeReport => 'Waraanna haaraa';

  @override
  String get myReports => 'Waraannan koo';

  @override
  String get noReportsYet => 'Waraanna hin qabdu.';

  @override
  String get title => 'Mata duree';

  @override
  String get description => 'Ibsa';

  @override
  String get category => 'Gosa';

  @override
  String get severity => 'Dandii';

  @override
  String get reportAnonymously => 'Saglamaa hinqabne beekaa';

  @override
  String get evidenceOptional => 'Cunqarfii (optional)';

  @override
  String get submitReport => 'Waraanna ergi';

  @override
  String get submitting => 'Ergamu jira…';

  @override
  String get newsAndInformation => 'Oduu Osoo Abbaa';

  @override
  String get announcementsTab => 'Beekaa';

  @override
  String get legalTab => 'Seera';

  @override
  String get missingTab => 'Hargartan';

  @override
  String get sightingsTab => 'Ilalamaa';

  @override
  String get reportAMissingPerson => 'Namni hargarte beekaa';

  @override
  String get settingsTitle => 'Qindaa\'ina';

  @override
  String get settingsSubtitle => 'Herrega kee, afaan, naannoo qindaa\'i';

  @override
  String get account => 'Herrega';

  @override
  String get fullName => 'Maqaa guutuu';

  @override
  String get location => 'Naannoo';

  @override
  String get locationLabel => 'Naannoo';

  @override
  String get region => 'Naannoo';

  @override
  String get regionLabel => 'Naannoo';

  @override
  String get subCity => 'Naannoo xinnaa / Woredaa';

  @override
  String get subCityLabel => 'Naannoo xinnaa / Woredaa';

  @override
  String get languageLabel => 'Afaan';

  @override
  String get preferredLanguage => 'Afaan filatame';

  @override
  String get safetyZones => 'Naannoo nageenya';

  @override
  String get addSafetyZone => 'Naannoo nageenya dabali';

  @override
  String get legalInformation => 'Osoo seeraa';

  @override
  String get accessibilityTitle => 'Danda\'ina';

  @override
  String get accessibilitySubtitle => 'Barruu guddaa, baxxinnee olaanaa';

  @override
  String get darkMode => 'Naannoo duukaa';

  @override
  String get darkModeSubtitle => 'Miseensaa duukaa fayyadamaa';

  @override
  String get callbackRequests => 'Gaaffii deebii';

  @override
  String get callbackSubtitle => 'Polisiin gaaffii kee adda baasaa';

  @override
  String get requestDirectCall => 'Bilbila karaa barsiisi';

  @override
  String get recordSignLanguage => 'Afaan mallattoo vidyo klemmii';

  @override
  String get saveSettings => 'Qindaa\'ina olkaa\'i';

  @override
  String get logout => 'Ba\'i';

  @override
  String get logoutLabel => 'Ba\'i';

  @override
  String get signingIn => 'Keessa kori';

  @override
  String get createAccount => 'Herrega uumi';

  @override
  String get emergencyAndCrime => 'ZEYGAA-ALERT · Afeejjii fi rookaa waraanna';

  @override
  String get phone => 'Bilbila';

  @override
  String get password => 'Jecha darbii';

  @override
  String get register => 'Galmaa\'i';

  @override
  String get alreadyHaveAccount => 'Herrega qabdaa? Keessa kori';

  @override
  String get newHere => 'Haaraa? Herrega uumi';

  @override
  String get callbackTitle => 'Gaaffii deebii';

  @override
  String get callbackDescription =>
      'Polisiin gaaffii keessa argamuuf waraanna kee faana buusuuf gaaffii godhaa.';

  @override
  String get noCallbacksYet => 'Gaaffii deebii hin jirre.';

  @override
  String get accept => 'Fudhadhu';

  @override
  String get decline => 'Dhiisi';

  @override
  String get offlineMode => 'Meeffamaa keessa — tuqaalii kee agarsiisa';

  @override
  String get ok => 'Tole';

  @override
  String get sosSent => 'SOS ergame. Gartuu ergame. Naannoo kee keessa jiru.';

  @override
  String get share => 'Qoodi';

  @override
  String shareAnnouncement(Object title) {
    return 'Beekaa qoodi: $title';
  }

  @override
  String get missing => 'HARGARTAN';

  @override
  String get wanted => 'BARBADHISAN';

  @override
  String get reportSighting => 'Ilalamaa beekaa';

  @override
  String shareMissingPerson(Object name) {
    return 'Namni hargarte qoodi: $name';
  }

  @override
  String shareWantedPerson(Object name) {
    return 'Namni barbaachise qoodi: $name';
  }

  @override
  String lastSeen(Object location) {
    return 'Sanatti ilaalame: $location';
  }

  @override
  String get nothingHereYet => 'Kunuma keessatti miidhaa hin jiru.';

  @override
  String get citizenSightingsInfo =>
      'Ilalamaa herrega polisiin yeroo hundaatti mul\'ata.';

  @override
  String get unknownLocation => 'Naannoo hin beekamne';

  @override
  String get pleaseWait => 'Maaloo eegi…';

  @override
  String get enterOtp => 'OTP galchi';

  @override
  String get checkOtpHint => 'OTP dev screeni keessaa ilaali';

  @override
  String get verify => 'Mirmaasi';

  @override
  String get required => 'Barbaachisa';

  @override
  String get cancel => 'Haquu';

  @override
  String get add => 'Dabali';

  @override
  String get rateResponse => 'Deebii graduating';

  @override
  String get commentOptional => 'Yaada (optional)';

  @override
  String get thanksFeedback => 'Yaada kee kabajaa!';

  @override
  String get rateThisResponse => 'Deebii kana graduating';

  @override
  String get reportSubmitted => 'Waraanna ergame. Galatoomaa.';

  @override
  String uploadFailed(Object error) {
    return 'Upload hin milkin: $error';
  }

  @override
  String addType(Object type) {
    return '$type dabali';
  }

  @override
  String get url => 'URL';

  @override
  String get filePathNote => 'Naannoo fayilii / yaada';

  @override
  String get noScheduledSlot => 'Yeroon hin qabamne';

  @override
  String get reportFollowUp => 'Waraanna faanaa';

  @override
  String get mode => 'Akkaataa';

  @override
  String get contactStaff => 'Hojjataa qunnamsiisi';

  @override
  String get staffPhoneHint => 'Bilbila hojjataa, fakkeenya 0911000003';

  @override
  String get startChat => 'Waadaa eegali';

  @override
  String get userNotFound => 'Hojjataa hin argamne';

  @override
  String get noConversations => 'Waadaa hin jiru';

  @override
  String get newChat => 'Waadaa haaraa';

  @override
  String get typeMessage => 'Ergaa barreessi…';

  @override
  String get send => 'Ergi';

  @override
  String get missingPersonReportSubmitted => 'Namni hargarte waraanna ergame.';

  @override
  String get fullNameMissingPerson => 'Maqaa guutuu namni hargarte';

  @override
  String get ageOptional => 'Umrii (optional)';

  @override
  String get gender => 'Sa\'a';

  @override
  String get male => 'Elee';

  @override
  String get female => 'Daaqqii';

  @override
  String get unknown => 'Hin beekamne';

  @override
  String get lastSeenLocation => 'Sanatti ilaalame naannoo (teessoo)';

  @override
  String get lastSeenDateTime =>
      'Sanatti ilaalame guyyaa fi sa\'aati (optional)';

  @override
  String lastSeenPrefix(Object datetime) {
    return 'Sanatti ilaalame: $datetime';
  }

  @override
  String get descriptionIdentifying => 'Ibsa / mallattoo';

  @override
  String get sightingReported => 'Ilalamaa galmaa\'ame. Gargaarsa kee kabajaa.';

  @override
  String get whereSeen => 'Eessa ilaalte?';

  @override
  String get whenOptional => 'Yaa? (optional)';

  @override
  String seenAt(Object datetime) {
    return 'Sanatti ilaalame: $datetime';
  }

  @override
  String get descriptionOptional => 'Ibsa (optional)';

  @override
  String get submitSighting => 'Ilalamaa ergi';

  @override
  String get takePhoto => 'Fotootti qabachi';

  @override
  String get chooseFromGallery => 'Gallery keessaa filadhu';

  @override
  String get idNumberPhotoRequired =>
      'Maaloo herrega lakkoofsa ID kee galchi fi kaardiin ID kee foto qabachi.';

  @override
  String get verificationSubmitted => 'Mirmaasii ergame.';

  @override
  String get faydaIdVerification => 'Fayda Herrega Milmaasii';

  @override
  String get verified => 'Mirmaa\'eera';

  @override
  String get notVerified => 'Hin mirmane';

  @override
  String get identityVerifiedDesc =>
      'Herrega kee Fayda Herrega Milmaasiin mirmaa\'eera.';

  @override
  String get verifyIdentityDesc =>
      'Herrega kee mirmaasi ka\'i amanina uumuuf fi dorgommii hunda galmaasuu.';

  @override
  String get scanFaydaId => 'Kaardiin Fayda Herrega kee ilaali';

  @override
  String get scanIdInstruction =>
      'Kaardiin ID kee fuula keessaa foto ifaa qabachi. Osoo kee Fayda databasee waliin mirmaatama.';

  @override
  String get tapToScanId => 'ID kaardii ilaaluuf tuqi';

  @override
  String get faydaIdNumber => 'Lakkoofsa ID Fayda';

  @override
  String get faydaIdHint => 'fakkeenya 1234567890123';

  @override
  String get fullNameAsOnId => 'Maqaa guutuu (ID irra jiru)';

  @override
  String get verifying => 'Mirmaasu jira...';

  @override
  String get submitForVerification => 'Mirmaasuuf ergi';

  @override
  String get connecting => 'Wal qabsaa\'aa jira...';

  @override
  String get ringing => 'Bilbilaa jira...';

  @override
  String get uploading => 'Upload godhu jira…';

  @override
  String get newSafetyZone => 'Naannoo nageenya haaraa';

  @override
  String get name => 'Maqaa';

  @override
  String get type => 'Akaakuu';

  @override
  String get centerLatitude => 'Lattoofoo iwjii';

  @override
  String get centerLongitude => 'Boqonnaa iwjii';

  @override
  String get radiusMeters => 'Laafata (meetira)';

  @override
  String get create => 'Uumi';

  @override
  String get safetyZoneCreated => 'Naannoo nageenya uumeera.';

  @override
  String get safetyZoneDeleted => 'Naannoo nageenya haquu.';

  @override
  String get noLegalContent => 'Osoo seeraa hin jiru.';

  @override
  String get identityVerification => 'Herrega Milmaasii';

  @override
  String get faydaVerificationSubtitle =>
      'Herrega kee Kaardii Herrega Biyyoolessaa keessaa mirmaasi ka\'i';

  @override
  String get accessibilityModePoD => 'Danda\'ina haala (PoD)';

  @override
  String callingNumber(Object number) {
    return '$number bilbilaa jira…';
  }

  @override
  String couldNotStartCall(Object error) {
    return 'Bilbila jalqabuu hin dandeenye: $error';
  }

  @override
  String get recordingCancelled => 'Galmaa\'uu haquu.';

  @override
  String signLanguageUploaded(Object name) {
    return 'Vidyo Afaan Mallattoo upload godame ($name).';
  }

  @override
  String get signLanguageRecorded =>
      'Vidyo Afaan Mallattoo galmaa\'ame fi upload godame.';

  @override
  String couldNotRecordVideo(Object error) {
    return 'Vidyo galmaa\'uu/upload hin dandeenye: $error';
  }

  @override
  String get incomingCall => 'Bilbila Keessa Dhufaa';

  @override
  String callerIsCalling(Object name) {
    return '$name bilbila jira';
  }

  @override
  String get photoOfPerson => 'Foto namaa (optional)';

  @override
  String get photoOfSighting => 'Foto ilalamaa (optional)';

  @override
  String newCallbackRequest(Object title) {
    return 'Gaaffii deebii haaraa \"$title\"';
  }

  @override
  String get open => 'Bani';

  @override
  String sosUpdated(Object status) {
    return 'SOS kee amma $status jira';
  }
}
