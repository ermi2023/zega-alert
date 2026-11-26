import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/rendering.dart';

import 'firebase_options.dart';

import 'l10n/fallback_localizations.dart';
import 'l10n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'screens/news_screen.dart';
import 'screens/communication_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/callbacks_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/safety_zones_screen.dart';
import 'screens/video_call_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/api.dart';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'services/notification_state.dart';
import 'services/officer_position_service.dart';
import 'services/person_image_cache_service.dart';
import 'services/safety_zone_tracking_service.dart';

import 'package:workmanager/workmanager.dart' as workmanager;

import 'services/sync_service.dart';
import 'widgets/auth_gate.dart';
import 'widgets/sos_dialog.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _handleExpiredSession() async {
  await SafetyZoneTrackingService.disable();
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your session has ended. Please sign in again.'),
      ),
    );
  });
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  workmanager.Workmanager().executeTask((task, inputData) async {
    // Background work that runs even when the app is closed.
    try {
      if (task == 'zega-officer-position') {
        await OfficerPositionService.reportInBackground();
      } else {
        await SyncService.flushInBackground();
      }
    } catch (_) {}
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Api.onSessionExpired = _handleExpiredSession;
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {}
    try {
      await workmanager.Workmanager().initialize(callbackDispatcher);
      await workmanager.Workmanager().registerPeriodicTask(
        'zega-outbox-sync',
        'zega-outbox-sync',
        frequency: const Duration(minutes: 15),
        constraints: workmanager.Constraints(
          networkType: workmanager.NetworkType.connected,
        ),
      );
      await workmanager.Workmanager().registerPeriodicTask(
        'zega-officer-position',
        'zega-officer-position',
        frequency: const Duration(minutes: 15),
        constraints: workmanager.Constraints(
          networkType: workmanager.NetworkType.connected,
        ),
      );
    } catch (_) {}
  }
  await Api.resolveHost();
  await Api.loadToken();
  await PersonImageCacheService.initialize();

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
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  runApp(
    ZegaAlertApp(
      initialLanguage: savedLanguage,
      onboardingDone: onboardingDone,
    ),
  );
}

class ZegaAlertApp extends StatefulWidget {
  const ZegaAlertApp({
    super.key,
    this.initialLanguage = 'en',
    this.onboardingDone = false,
  });

  final String initialLanguage;
  final bool onboardingDone;

  static ZegaAlertAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<ZegaAlertAppState>();

  @override
  State<ZegaAlertApp> createState() => ZegaAlertAppState();
}

class ZegaAlertAppState extends State<ZegaAlertApp> {
  bool _darkMode = false;
  bool _accessibility = false;
  String _languageCode = 'en';
  late bool _onboardingDone;

  String get languageCode => _languageCode;

  @override
  void initState() {
    super.initState();
    _languageCode = widget.initialLanguage;
    _onboardingDone = widget.onboardingDone;
  }

  void toggleDarkMode(bool value) => setState(() => _darkMode = value);
  void toggleAccessibility(bool value) =>
      setState(() => _accessibility = value);

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
        : ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E40AF),
            brightness: Brightness.light,
            primary: const Color(0xFF1E40AF),
            onPrimary: const Color(0xFFFFFFFF),
            secondary: const Color(0xFF3B82F6),
            onSecondary: const Color(0xFFFFFFFF),
            tertiary: const Color(0xFFD97706),
            error: const Color(0xFFDC2626),
            surface: const Color(0xFFF8FAFC),
            onSurface: const Color(0xFF1E293B),
            surfaceContainerHighest: const Color(0xFFE2E8F0),
          );

    final darkScheme = _accessibility
        ? ColorScheme.fromSeed(
            seedColor: const Color(0xFF90EE90),
            brightness: Brightness.dark,
            surface: const Color(0xFF1A1A1A),
          )
        : ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E40AF),
            brightness: Brightness.dark,
            primary: const Color(0xFF3B82F6),
            surface: const Color(0xFF0A192F),
            tertiary: const Color(0xFFF59E0B),
            error: const Color(0xFFEF4444),
          );

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
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF142B4A),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFFFFFFFF),
          elevation: 1,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF1E40AF),
          unselectedItemColor: Color(0xFF64748B),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF1E40AF).withValues(alpha: 0.12),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: !_onboardingDone
          ? OnboardingScreen(
              onDone: () => setState(() => _onboardingDone = true),
            )
          : (Api.token == null ? const LoginScreen() : const MainShell()),
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
  bool _showBottomNav = true;
  final Set<int> _visitedTabs = {0};
  int _newsUnread = 0;
  int _newsUnreadFetchGeneration = 0;
  bool _markingNewsRead = false;
  bool _searchExpanded = false;
  String _homeSearchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification &&
        notification.metrics.axis == Axis.vertical) {
      final direction = notification.direction;

      if (direction == ScrollDirection.reverse && _showBottomNav) {
        setState(() => _showBottomNav = false);
      } else if (direction == ScrollDirection.forward && !_showBottomNav) {
        setState(() => _showBottomNav = true);
      }
    }

    if (notification.metrics.axis == Axis.vertical &&
        notification.metrics.pixels <=
            notification.metrics.minScrollExtent + 2 &&
        !_showBottomNav) {
      setState(() => _showBottomNav = true);
    }

    return false;
  }

  List<Widget> get _tabs => [
    HomeScreen(searchQuery: _homeSearchQuery),
    const ReportScreen(),
    const NewsScreen(),
    const CommunicationScreen(),
    const SafetyZonesScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    NotificationState.changes.addListener(_fetchNewsUnread);
    _fetchNewsUnread();
    if (Api.isLoggedIn) {
      unawaited(NotificationService.initialize());
      _resumeSafetyZoneAlerts();
      SocketService.connect();
      SocketService.onCallbackNew = _onCallbackNew;
      SocketService.onSosStatus = _onSosStatus;
      SocketService.onIncomingCall = _onIncomingCall;
      SyncService.onSynced = _onSynced;
      SyncService.start();
    }
  }

  void _resumeSafetyZoneAlerts() {
    unawaited(
      SafetyZoneTrackingService.resumeIfEnabled().catchError((Object error) {
        debugPrint('Safety Zone monitoring could not resume: $error');
        final loc = AppLocalizations.of(context);
        final message = error is SafetyZoneTrackingException
            ? switch (error.issue) {
                SafetyZoneTrackingIssue.androidOnly =>
                  loc.backgroundLocationAndroidOnly,
                SafetyZoneTrackingIssue.deviceLocationOff =>
                  loc.turnOnDeviceLocation,
                SafetyZoneTrackingIssue.backgroundLocationPermission =>
                  loc.alwaysLocationPermission,
                SafetyZoneTrackingIssue.notificationsUnavailable =>
                  loc.safetyNotificationsUnavailable,
                SafetyZoneTrackingIssue.notificationPermission =>
                  loc.allowSafetyNotifications,
                SafetyZoneTrackingIssue.monitoringStartFailed =>
                  loc.couldNotStartLocationMonitoring,
                SafetyZoneTrackingIssue.monitoringRestartFailed =>
                  loc.couldNotRestartLocationMonitoring,
                SafetyZoneTrackingIssue.monitoringStopped =>
                  loc.locationMonitoringStopped,
                SafetyZoneTrackingIssue.boundaryCheckFailed =>
                  loc.couldNotCheckZoneBoundaries,
              }
            : loc.couldNotEnableSafetyZoneAlerts;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        });
      }),
    );
  }

  void _onSynced(int pending) {
    if (!mounted || pending != 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your saved reports have been submitted.')),
    );
  }

  @override
  void dispose() {
    NotificationState.changes.removeListener(_fetchNewsUnread);
    _searchController.dispose();
    SocketService.onCallbackNew = null;
    SocketService.onSosStatus = null;
    SocketService.onIncomingCall = null;
    SocketService.disconnect();
    SyncService.stop();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() {
      _index = index;
      _visitedTabs.add(index);
      if (index != 0) {
        _searchExpanded = false;
        _homeSearchQuery = '';
        _searchController.clear();
      }
    });
    if (index == 2 && _newsUnread > 0) {
      unawaited(_markNewsNotificationsRead());
    }
  }

  Future<void> _markNewsNotificationsRead() async {
    if (!Api.isLoggedIn || _newsUnread == 0 || _markingNewsRead) return;
    _markingNewsRead = true;
    try {
      await Api.post('/notifications/read-content-updates', {'scope': 'news'});
      if (!mounted) return;
      _newsUnreadFetchGeneration++;
      setState(() => _newsUnread = 0);
      NotificationState.notifyChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Api.userMessage(
              e,
              fallback: 'Could not clear notifications right now.',
            ),
          ),
        ),
      );
    } finally {
      _markingNewsRead = false;
    }
  }

  void _toggleHomeSearch() {
    setState(() {
      _searchExpanded = !_searchExpanded;
      if (!_searchExpanded) {
        _homeSearchQuery = '';
        _searchController.clear();
      }
    });
  }

  void _updateHomeSearch(String value) {
    setState(() => _homeSearchQuery = value);
  }

  Future<void> _fetchNewsUnread() async {
    if (!Api.isLoggedIn) return;
    final generation = ++_newsUnreadFetchGeneration;
    try {
      final res = await Api.get('/notifications/unread-count');
      if (!mounted || generation != _newsUnreadFetchGeneration) return;
      final newsUpdates = res is Map
          ? (res['newsUpdates'] as num?)?.toInt() ?? 0
          : 0;
      setState(() => _newsUnread = newsUpdates);
      if (_index == 2 && newsUpdates > 0) {
        unawaited(_markNewsNotificationsRead());
      }
    } catch (_) {}
  }

  void _onCallbackNew(JsonMap cb) {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    final title = cb['report_title'] ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.newCallbackRequest(title)),
        action: SnackBarAction(
          label: loc.open,
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const CallbacksScreen())),
        ),
      ),
    );
  }

  void _onSosStatus(JsonMap data) {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    final status = (data['status'] ?? 'updated').toString().toUpperCase();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(loc.sosUpdated(status))));
  }

  void _onIncomingCall(dynamic data) {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    final callerName = data['callerName'] ?? loc.unknown;
    final callerId = data['callerId'] ?? '';
    final callType = data['callType'] ?? 'video';
    final roomId = data['roomId'] ?? '';
    final offer = data['offer'] is Map
        ? Map<String, dynamic>.from(data['offer'] as Map)
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(loc.incomingCall),
        content: Text(loc.callerIsCalling(callerName)),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (roomId.toString().isEmpty) return;
              try {
                await Api.post('/webrtc/end', {'roomId': roomId});
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      Api.userMessage(
                        error,
                        fallback: 'Could not decline the call.',
                      ),
                    ),
                  ),
                );
              }
            },
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
            child: Text(
              loc.accept,
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final tabs = _tabs;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF142B4A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.shield, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ),
        title: _index == 0 && _searchExpanded
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white),
                onChanged: _updateHomeSearch,
                decoration: InputDecoration(
                  hintText: loc.searchMissingWantedPeople,
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  suffixIcon: _homeSearchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: loc.clearSearch,
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            _updateHomeSearch('');
                          },
                        ),
                ),
              )
            : _index == 0
            ? const SizedBox.shrink()
            : Text(
                loc.appTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (_index == 0)
            IconButton(
              tooltip: _searchExpanded ? loc.closeSearch : loc.searchPeople,
              icon: Icon(_searchExpanded ? Icons.close : Icons.search),
              onPressed: _toggleHomeSearch,
            ),
          IconButton(
            tooltip: loc.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _selectTab(5),
          ),
          const _NotificationBell(),
          const SizedBox(width: 4),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: IndexedStack(
          index: _index,
          children: List.generate(
            tabs.length,
            (index) => _visitedTabs.contains(index)
                ? tabs[index]
                : const SizedBox.shrink(),
          ),
        ),
      ),

      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.bottomCenter,
        child: ClipRect(
          child: Align(
            heightFactor: _showBottomNav ? 1 : 0,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(Icons.home, loc.home, 0),
                  _navItem(Icons.assignment_outlined, loc.report, 1),
                  _sosNavItem(context),
                  _navItem(
                    Icons.newspaper,
                    loc.news,
                    2,
                    badgeCount: _newsUnread,
                  ),
                  _navItem(
                    Icons.health_and_safety_outlined,
                    loc.safetyZonesTab,
                    4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    int index, {
    int badgeCount = 0,
  }) {
    final isSelected = _index == index;
    final iconWidget = Badge(
      isLabelVisible: badgeCount > 0,
      label: Text('$badgeCount'),
      child: Icon(
        icon,
        color: isSelected ? Colors.white : const Color(0xFF64748B),
        size: isSelected ? 20 : 22,
      ),
    );
    return InkWell(
      onTap: () => _selectTab(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00338D),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: iconWidget,
              )
            else
              iconWidget,
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sosNavItem(BuildContext context) {
    return GestureDetector(
      onTap: () => triggerEmergencySos(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFDC2626),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.emergency_share,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'SOS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatefulWidget {
  const _NotificationBell();

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    NotificationState.changes.addListener(_fetchUnread);
    _fetchUnread();
  }

  @override
  void dispose() {
    NotificationState.changes.removeListener(_fetchUnread);
    super.dispose();
  }

  Future<void> _fetchUnread() async {
    if (!Api.isLoggedIn) return;
    try {
      final res = await Api.get('/notifications/unread-count');
      if (!mounted) return;
      final total = res is Map ? (res['count'] as num?)?.toInt() ?? 0 : 0;
      final newsUpdates = res is Map
          ? (res['newsUpdates'] as num?)?.toInt() ?? 0
          : 0;
      setState(() => _unread = (total - newsUpdates).clamp(0, total).toInt());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return IconButton(
      tooltip: loc.notifications,
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text('$_unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        NotificationState.notifyChanged();
      },
    );
  }
}
