import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:geolocator/geolocator.dart';
import 'l10n/app_localizations.dart';
import 'l10n/fallback_localizations.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'screens/news_screen.dart';
import 'screens/communication_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/callbacks_screen.dart';
import 'screens/video_call_screen.dart';
import 'services/api.dart';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'services/officer_position_service.dart';
import 'services/sync_service.dart';
import 'widgets/auth_gate.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {}
  }
  if (!kIsWeb) {
    try {
      await Geolocator.requestPermission();
    } catch (_) {}
  }
  await Api.resolveHost();
  await Api.loadToken();
  if (Api.token != null && !kIsWeb) {
    await NotificationService.initialize();
  }

  if (Api.token != null) {
    try {
      final me = await Api.get('/auth/me') as Map<String, dynamic>?;
      await Api.setProfile(me);
      final role = me?['role'] ?? '';
      if ((role == 'police' || role == 'dispatcher') && !kIsWeb) {
        OfficerPositionService.start();
      }
    } catch (_) {}
  }

  final prefs = await SharedPreferences.getInstance();
  final savedLanguage = prefs.getString('languageCode') ?? 'en';
  runApp(ZegaAlertApp(initialLanguage: savedLanguage));
}

class ZegaAlertApp extends StatefulWidget {
  const ZegaAlertApp({super.key, this.initialLanguage = 'en'});

  final String initialLanguage;

  static ZegaAlertAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<ZegaAlertAppState>();

  @override
  State<ZegaAlertApp> createState() => ZegaAlertAppState();
}

class ZegaAlertAppState extends State<ZegaAlertApp> {
  bool _darkMode = false;
  bool _accessibility = false;
  String _languageCode = 'en';

  String get languageCode => _languageCode;

  @override
  void initState() {
    super.initState();
    _languageCode = widget.initialLanguage;
  }

  void toggleDarkMode(bool value) => setState(() => _darkMode = value);
  void toggleAccessibility(bool value) => setState(() => _accessibility = value);

  void setLanguage(String code) {
    setState(() => _languageCode = code);
    SharedPreferences.getInstance()
        .then((p) => p.setString('languageCode', code))
        .catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final textScale = _accessibility ? 1.3 : 1.0;

    final lightScheme = _accessibility
        ? ColorScheme.fromSeed(
            seedColor: const Color(0xFF000000),
            brightness: Brightness.light,
            surface: const Color(0xFFF5F5F5),
            onSurface: const Color(0xFF000000),
            primary: const Color(0xFF000000),
            onPrimary: const Color(0xFFFFFFFF),
          )
        : ColorScheme.fromSeed(seedColor: const Color(0xFF16a34a), brightness: Brightness.light);

    final darkScheme = _accessibility
        ? ColorScheme.fromSeed(seedColor: const Color(0xFF90EE90), brightness: Brightness.dark, surface: const Color(0xFF1A1A1A))
        : ColorScheme.fromSeed(seedColor: const Color(0xFF16a34a), brightness: Brightness.dark);

    return MaterialApp(
      title: 'ZEGA-ALERT',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      locale: Locale(_languageCode),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FallbackMaterialLocalizationsDelegate(),
        GlobalWidgetsLocalizations.delegate,
        FallbackCupertinoLocalizationsDelegate(),
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => Semantics(
        label: 'ZEGA-ALERT application. Safety companion for emergency and crime reporting.',
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
      ),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: Api.token == null ? const AuthScreen() : const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    AuthGate(
      child: ReportScreen(),
      title: 'Sign in to file a report',
      message: 'You can browse announcements, missing & wanted persons as a guest. Sign in to submit crime reports.',
    ),
    NewsScreen(),
    AuthGate(
      child: CommunicationScreen(),
      title: 'Sign in to send messages',
      message: 'Messaging and callbacks are available once you create a free account or sign in.',
    ),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    if (Api.isLoggedIn) {
      SocketService.connect();
      SocketService.onCallbackNew = _onCallbackNew;
      SocketService.onSosStatus = _onSosStatus;
      SocketService.onIncomingCall = _onIncomingCall;
      SyncService.onSynced = _onSynced;
      SyncService.start();
    }
  }

  void _onSynced(int pending) {
    if (!mounted || pending != 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your saved reports have been submitted.')),
    );
  }

  @override
  void dispose() {
    SocketService.onCallbackNew = null;
    SocketService.onSosStatus = null;
    SocketService.onIncomingCall = null;
    SocketService.disconnect();
    SyncService.stop();
    super.dispose();
  }

  void _onCallbackNew(JsonMap cb) {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    final title = cb['report_title'] ?? '';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(loc.newCallbackRequest(title)),
      action: SnackBarAction(
        label: loc.open,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CallbacksScreen())),
      ),
    ));
  }

  void _onSosStatus(JsonMap data) {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    final status = (data['status'] ?? 'updated').toString().toUpperCase();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.sosUpdated(status))));
  }

  void _onIncomingCall(dynamic data) {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    final callerName = data['callerName'] ?? loc.unknown;
    final callerId = data['callerId'] ?? '';
    final callType = data['callType'] ?? 'video';
    final roomId = data['roomId'] ?? '';
    final offer = data['offer'] is Map ? Map<String, dynamic>.from(data['offer'] as Map) : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(loc.incomingCall),
        content: Text(loc.callerIsCalling(callerName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.decline, style: const TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VideoCallScreen(
                    targetUserId: callerId,
                    targetName: callerName,
                    callType: callType,
                    roomId: roomId,
                    incomingOffer: offer,
                  ),
                ),
              );
            },
            child: Text(loc.accept, style: const TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      body: _tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home), label: loc.home),
          NavigationDestination(icon: const Icon(Icons.report), label: loc.report),
          NavigationDestination(icon: const Icon(Icons.newspaper), label: loc.news),
          NavigationDestination(icon: const Icon(Icons.chat), label: loc.messages),
          NavigationDestination(icon: const Icon(Icons.settings), label: loc.settings),
        ],
      ),
    );
  }
}
