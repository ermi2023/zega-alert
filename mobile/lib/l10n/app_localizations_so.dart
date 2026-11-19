// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Somali (`so`).
class AppLocalizationsSo extends AppLocalizations {
  AppLocalizationsSo([String locale = 'so']) : super(locale);

  @override
  String get appTitle => 'ZEGA-ALERT';

  @override
  String get appSubtitle => 'Saaxiibkaaga badbaadada';

  @override
  String get home => 'Guriga';

  @override
  String get report => 'Warbixin';

  @override
  String get news => 'Wararka';

  @override
  String get messages => 'Fariimaha';

  @override
  String get settings => 'Dejinta';

  @override
  String get sosEmergency => 'Gurmadka SOS';

  @override
  String get sending => 'SENDING…';

  @override
  String get sosDispatched => '🚨 SOS ayaa soo dirtay';

  @override
  String unitsOnTheWay(Object count) {
    return '$count cutubyada ayaa jidka ku jira.';
  }

  @override
  String get announcements => 'Ogaysiisyo';

  @override
  String get missingPersons => 'Dadka maqan';

  @override
  String get wantedPersons => 'Dadka la rabo';

  @override
  String get reportMissing => 'Warbixinta maqan';

  @override
  String get reportACrime => 'Ka warbixi dambi';

  @override
  String get yourReportGoesTo => 'Warbixintaadu waxay aadaysaa booliiska gobolka.';

  @override
  String get newCrimeReport => 'New crime report';

  @override
  String get myReports => 'Warbixinadeyda';

  @override
  String get noReportsYet => 'Wali ma aadan soo gudbin wax warbixin ah.';

  @override
  String get title => 'Ciwaanka';

  @override
  String get description => 'Description';

  @override
  String get category => 'Qaybta';

  @override
  String get severity => 'Darnaanta';

  @override
  String get reportAnonymously => 'Soo sheeg si qarsoodi ah';

  @override
  String get evidenceOptional => 'Caddeyn (ikhtiyaar)';

  @override
  String get submitReport => 'Soo gudbi warbixinta';

  @override
  String get submitting => 'Gudbinta…';

  @override
  String get newsAndInformation => 'Warar & Xog';

  @override
  String get announcementsTab => 'Ogaysiisyo';

  @override
  String get legalTab => 'Legal';

  @override
  String get missingTab => 'Maqan';

  @override
  String get sightingsTab => 'Aragtida';

  @override
  String get reportAMissingPerson => 'Ka warbixi qof maqan';

  @override
  String get settingsTitle => 'Dejinta';

  @override
  String get settingsSubtitle => 'Maamul akoonkaaga, luqadaada, aagaggaaga iyo gelitaankaaga';

  @override
  String get account => 'Xisaab';

  @override
  String get fullName => 'Full name';

  @override
  String get location => 'Goobta';

  @override
  String get locationLabel => 'Location';

  @override
  String get region => 'Gobolka';

  @override
  String get regionLabel => 'Gobolka';

  @override
  String get subCity => 'Xaafadaha/degmada';

  @override
  String get subCityLabel => 'Xaafadaha/degmada';

  @override
  String get languageLabel => 'Luuqad';

  @override
  String get preferredLanguage => 'Luuqada la door biday';

  @override
  String get safetyZones => 'Aagagga badbaadada (geofences)';

  @override
  String get addSafetyZone => 'Ku dar aagga badbaadada';

  @override
  String get legalInformation => 'Xogta sharciga ah';

  @override
  String get accessibilityTitle => 'Accessibility (People of Determination)';

  @override
  String get accessibilitySubtitle => 'Qoraal ka weyn, ka duwanaansho sare, ficilada codka lagu caawiyo';

  @override
  String get darkMode => 'Qaab mugdi ah';

  @override
  String get darkModeSubtitle => 'Isticmaal mawduuca mugdiga ah ee guud ahaan abka';

  @override
  String get callbackRequests => 'Codsiyada soo celinta';

  @override
  String get callbackSubtitle => 'Respond to police follow-up calls on your reports';

  @override
  String get requestDirectCall => 'Codso wicitaan toos ah';

  @override
  String get recordSignLanguage => 'Record sign language video';

  @override
  String get saveSettings => 'Keydi dejinta';

  @override
  String get logout => 'Ka bax';

  @override
  String get logoutLabel => 'Ka bax';

  @override
  String get signingIn => 'Soo gal';

  @override
  String get createAccount => 'Akoon samee';

  @override
  String get emergencyAndCrime => 'ZEGA-ALERT · Warbixinta degdega ah & dembiyada';

  @override
  String get phone => 'Phone';

  @override
  String get password => 'Password';

  @override
  String get register => 'Is diwaangeli';

  @override
  String get alreadyHaveAccount => 'Horeba akoon u yeeshay? Soo gal';

  @override
  String get newHere => 'Halkan ka cusub? Akoon samee';

  @override
  String get callbackTitle => 'Codsiyada soo celinta';

  @override
  String get callbackDescription => 'Booliisku waxay codsadaan in dib loo soo waco si ay ula socdaan warbixinahaaga.';

  @override
  String get noCallbacksYet => 'Weli ma jiraan codsiyo dib u soo yeedhis ah';

  @override
  String get accept => 'Aqbal';

  @override
  String get decline => 'Diid';

  @override
  String get offlineMode => 'Qaabka khadka tooska ah - oo muujinaya xogta kaydsan';

  @override
  String get ok => 'OK';

  @override
  String get sosSent => 'SOS soo dirtay. Cutubyo la diray. Joog meeshaad joogto.';

  @override
  String get share => 'La wadaag';

  @override
  String shareAnnouncement(Object title) {
    return 'La wadaag ogeysiiska: $title';
  }

  @override
  String get missing => 'MISSING';

  @override
  String get wanted => 'LA RABAA';

  @override
  String get reportSighting => 'Ka warbixi aragti';

  @override
  String shareMissingPerson(Object name) {
    return 'La wadaag qofka maqan: $name';
  }

  @override
  String shareWantedPerson(Object name) {
    return 'La wadaag qofka la rabo: $name';
  }

  @override
  String lastSeen(Object location) {
    return 'Markii u dambaysay ee la arkay: $location';
  }

  @override
  String get nothingHereYet => 'Weli waxba halkan ma jiraan.';

  @override
  String get citizenSightingsInfo => 'Citizen sightings are shown to police in real time.';

  @override
  String get unknownLocation => 'Meel aan la garanayn';

  @override
  String get pleaseWait => 'Fadlan sug…';

  @override
  String get enterOtp => 'Enter OTP';

  @override
  String get checkOtpHint => 'Hubi console-ka server-ka ee Dev OTP';

  @override
  String get verify => 'Xaqiiji';

  @override
  String get required => 'Loo baahan yahay';

  @override
  String get cancel => 'Jooji';

  @override
  String get add => 'Ku dar';

  @override
  String get rateResponse => 'Qiimee jawaabta';

  @override
  String get commentOptional => 'Faallo (ikhtiyaar)';

  @override
  String get thanksFeedback => 'Waad ku mahadsan tahay faallo celintaada!';

  @override
  String get rateThisResponse => 'Qiimee jawaabtan';

  @override
  String get reportSubmitted => 'Warbixin la gudbiyay. Mahadsanid';

  @override
  String uploadFailed(Object error) {
    return 'Soo dejintu waa fashilantay: { khalad} $error';
  }

  @override
  String addType(Object type) {
    return 'Ku dar $type';
  }

  @override
  String get url => 'URL';

  @override
  String get filePathNote => 'Jidka faylka / note';

  @override
  String get noScheduledSlot => 'No scheduled slot';

  @override
  String get reportFollowUp => 'Ka warbixi daba-galka';

  @override
  String get mode => 'Habka';

  @override
  String get contactStaff => 'La xidhiidh xubin shaqaale';

  @override
  String get staffPhoneHint => 'Taleefanka shaqaalaha, tusaale 0911000003';

  @override
  String get startChat => 'Bilow sheekada';

  @override
  String get userNotFound => 'Isticmaalaha lama helin';

  @override
  String get noConversations => 'Sheeko ma leh';

  @override
  String get newChat => 'Sheeko cusub';

  @override
  String get typeMessage => 'Type a message…';

  @override
  String get send => 'Dir';

  @override
  String get missingPersonReportSubmitted => 'Warbixinta qofka maqan ayaa la gudbiyay.';

  @override
  String get fullNameMissingPerson => 'Magaca buuxa ee qofka maqan';

  @override
  String get ageOptional => 'Age (optional)';

  @override
  String get gender => 'Jinsiga';

  @override
  String get male => 'Male';

  @override
  String get female => 'Dheddig';

  @override
  String get unknown => 'Lama garanayo';

  @override
  String get lastSeenLocation => 'Goobtii ugu dambaysay ee la arkay (cinwaanka)';

  @override
  String get lastSeenDateTime => 'Taariikhda iyo wakhtiga la arkay ee u dambeeyay (ikhtiyaar)';

  @override
  String lastSeenPrefix(Object datetime) {
    return 'Markii u dambaysay ee la arkay: $datetime';
  }

  @override
  String get descriptionIdentifying => 'Description / identifying details';

  @override
  String get sightingReported => 'Aragtida ayaa la sheegay. Waad ku mahadsan tahay caawinta.';

  @override
  String get whereSeen => 'Xageed ku aragtay?';

  @override
  String get whenOptional => 'Goorma? (ikhtiyaar)';

  @override
  String seenAt(Object datetime) {
    return 'Seen at: $datetime';
  }

  @override
  String get descriptionOptional => 'Sharaxaad (ikhtiyaar)';

  @override
  String get submitSighting => 'Submit sighting';

  @override
  String get takePhoto => 'Sawir qaad';

  @override
  String get chooseFromGallery => 'Ka dooro gallery';

  @override
  String get idNumberPhotoRequired => 'Fadlan geli lambarkaaga aqoonsiga oo sawir ka qaad kaadhkaaga aqoonsiga.';

  @override
  String get verificationSubmitted => 'Xaqiijinta waa la gudbiyay';

  @override
  String get faydaIdVerification => 'Fayda Xaqiijinta Aqoonsiga Qaranka';

  @override
  String get verified => 'La xaqiijiyay';

  @override
  String get notVerified => 'Lama Xaqiijin';

  @override
  String get identityVerifiedDesc => 'Aqoonsigaaga waxa lagu xaqiijiyay Fayda ID National.';

  @override
  String get verifyIdentityDesc => 'Xaqiiji aqoonsigaaga si aad u dhisto kalsooni oo aad awood u siiso dhammaan sifooyinka';

  @override
  String get scanFaydaId => 'Baadh kaadhka aqoonsiga qaranka ee Fayda';

  @override
  String get scanIdInstruction => 'Sawir cad ka qaad xagga hore ee kaadhkaaga aqoonsiga. Macluumaadkaaga waxaa lagu xaqiijin doonaa si ka dhanka ah xogta Fayda.';

  @override
  String get tapToScanId => 'Taabo si aad u sawirto kaadhka aqoonsiga';

  @override
  String get faydaIdNumber => 'Fayda ID Number';

  @override
  String get faydaIdHint => 'tusaale. 1234567890123';

  @override
  String get fullNameAsOnId => 'Magaca buuxa (sida ku qoran aqoonsiga)';

  @override
  String get verifying => 'Xaqiijinaya...';

  @override
  String get submitForVerification => 'Gudbi si loo xaqiijiyo';

  @override
  String get connecting => 'Isku xidhka...';

  @override
  String get ringing => 'soo wacaya...';

  @override
  String get uploading => 'Uploading…';

  @override
  String get newSafetyZone => 'Aagga badbaadada cusub';

  @override
  String get name => 'Magaca';

  @override
  String get type => 'Type';

  @override
  String get centerLatitude => 'Latitude dhexe';

  @override
  String get centerLongitude => 'Longitude Center';

  @override
  String get radiusMeters => 'Radius (mitir)';

  @override
  String get create => 'Abuur';

  @override
  String get safetyZoneCreated => 'Aaga badbaadada ayaa la sameeyay.';

  @override
  String get safetyZoneDeleted => 'Aagga badbaadada waa la tirtiray';

  @override
  String get noLegalContent => 'Wax sharci ah lagama hayo';

  @override
  String get identityVerification => 'Identity Verification';

  @override
  String get faydaVerificationSubtitle => 'Ku cadee aqoonsigaaga kaarka aqoonsiga qaranka';

  @override
  String get accessibilityModePoD => 'Habka gelitaanka (PoD)';

  @override
  String callingNumber(Object number) {
    return 'wacaya $number…';
  }

  @override
  String couldNotStartCall(Object error) {
    return 'Ma bilaabi karo wacitaanka: $error';
  }

  @override
  String get recordingCancelled => 'Duubista waa la joojiyay';

  @override
  String signLanguageUploaded(Object name) {
    return 'Fiidiyowga luqadda dhegoolaha ayaa la soo galiyay ($name).';
  }

  @override
  String get signLanguageRecorded => 'Fiidiyowga luqadda dhegoolaha waa la duubay oo la soo galiyay.';

  @override
  String couldNotRecordVideo(Object error) {
    return 'Ma duubi karo/ soo dejin kari waayay muqaal: $error';
  }

  @override
  String get incomingCall => 'Incoming Call';

  @override
  String callerIsCalling(Object name) {
    return '$name ayaa ku soo wacaya';
  }

  @override
  String get photoOfPerson => 'Photo of the person (optional)';

  @override
  String get photoOfSighting => 'Sawirka muuqaalka (ikhtiyaar)';

  @override
  String newCallbackRequest(Object title) {
    return 'Codsiga dib u soo celinta cusub ee \"$title\"';
  }

  @override
  String get open => 'Furan';

  @override
  String sosUpdated(Object status) {
    return 'SOS kaaga hadda waa $status';
  }

}
