import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:arcade_launcher/onboarding_page.dart';
import 'package:arcade_launcher/settings_page.dart';
import 'package:arcade_launcher/models/app_info.dart';
import 'package:arcade_launcher/models/launcher_settings.dart';
import 'package:arcade_launcher/constants/pref_keys.dart';
import 'package:arcade_launcher/utils/app_sorter.dart';
import 'package:arcade_launcher/services/launcher_service.dart';
import 'package:arcade_launcher/services/safe_prefs.dart';
import 'package:arcade_launcher/services/app_background_service.dart';
import 'package:arcade_launcher/app_lifecycle_observer.dart';
import 'package:arcade_launcher/widgets/gaming_loading_indicator.dart';
import 'package:arcade_launcher/widgets/glass_container.dart';
import 'package:arcade_launcher/widgets/grid_pattern_painter.dart';
import 'package:arcade_launcher/widgets/featured_section.dart';
import 'package:arcade_launcher/widgets/game_card_small.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBackgroundService.init();

  // Pre-warm the app list/icon cache in the background
  LauncherService().getApps();

  // Set preferred orientations - allow both for dynamic adjustment
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Immersive mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const ArcadeLauncherApp());
}

class ArcadeLauncherApp extends StatelessWidget {
  const ArcadeLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARCADE HUB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05050A),
        primaryColor: const Color(0xFF00D4FF),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4FF),
          secondary: Color(0xFF9D4EDD),
          surface: Color(0xFF12121A),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const Initializer(),
        '/home': (context) => const ArcadeLauncherHome(),
        '/onboarding': (context) => const OnboardingPage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}

class Initializer extends StatefulWidget {
  const Initializer({super.key});

  @override
  State<Initializer> createState() => _InitializerState();
}

class _InitializerState extends State<Initializer> {
  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() async {
    final bool complete = await SafePrefs.getBool(PrefKeys.onboardingComplete);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      if (complete) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GamingLoadingIndicator(),
            SizedBox(height: 24),
            Text(
              'INITIALIZING HUB...',
              style: TextStyle(
                color: Color(0xFF00D4FF),
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArcadeLauncherHome extends StatefulWidget {
  const ArcadeLauncherHome({super.key});

  @override
  State<ArcadeLauncherHome> createState() => _ArcadeLauncherHomeState();
}

class _ArcadeLauncherHomeState extends State<ArcadeLauncherHome> {
  final LauncherService _launcherService = LauncherService();
  late AppLifecycleObserver _lifecycleObserver;

  List<AppInfo> _filteredApps = [];
  List<Map<String, dynamic>> _recentAppsStats = [];
  List<AppInfo>? _cachedApps;
  bool _isLoading = true;
  String _currentTab = 'Library';
  Map<String, dynamic>? _featuredItem;

  // Settings Tap Security
  int _settingsTapCount = 0;
  DateTime? _lastSettingsTap;

  // Settings
  int _gridColumns = 3;
  bool _showAppNames = true;
  double _iconScale = 36.0;
  String _launcherTitle = 'GAME LIBRARY'; // Default fallback
  String _launchWarning =
      'SECURITY: Do not leave accounts logged in. Always logout after session.';

  int _lastLoadTime = 0;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = AppLifecycleObserver(onResume: _loadApps);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    _launcherService.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'appChanged':
          _loadApps(force: true);
          break;
        case 'wallpaperChanged':
          setState(() {});
          break;
      }
    });

    _loadApps();
    _checkAndStartArcadeMode();
  }

  Future<void> _checkAndStartArcadeMode() async {
    // Check if Arcade Mode was previously enabled
    final arcadeModeEnabled = await SafePrefs.getBool(PrefKeys.arcadeModeEnabled);
    if (arcadeModeEnabled) {
      // Ensure the OverlayService is running
      try {
        await _launcherService.startOverlayService();
        debugPrint('Arcade Mode auto-started on app launch');
      } catch (e) {
        debugPrint('Error auto-starting Arcade Mode: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  Future<void> _loadApps({bool showLoading = true, bool force = false}) async {
    if (!mounted) return;

    // Debounce: If loaded less than 500ms ago and not forced, skip.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastLoadTime < 500 && _filteredApps.isNotEmpty) {
      return;
    }
    _lastLoadTime = now;

    // Only show loading indicator if explicitly requested and we don't have apps yet
    if (showLoading && _filteredApps.isEmpty && _cachedApps == null) {
      setState(() => _isLoading = true);
    }

    List<AppInfo> apps;
    if (_cachedApps != null && !force) {
      apps = _cachedApps!;
    } else {
      apps = await _launcherService.getApps();
      _cachedApps = apps;
    }

    // Batch load settings and app data in parallel for better performance
    final results = await Future.wait([
      SafePrefs.getStringList(PrefKeys.hiddenApps),
      SafePrefs.getString(PrefKeys.recentAppsData),
      SafePrefs.getStringList(PrefKeys.appOrder),
      LauncherSettings.load(),
    ]);

    final hidden = results[0] as List<String>;
    final recentsData = results[1] as String?;
    final appOrder = results[2] as List<String>;
    final settings = results[3] as LauncherSettings;

    List<Map<String, dynamic>> recents = [];
    if (recentsData != null) {
      try {
        recents = List<Map<String, dynamic>>.from(jsonDecode(recentsData));
      } catch (e) {
        debugPrint("Error parsing recents: $e");
      }
    }

    final filtered =
        apps.where((app) => !hidden.contains(app.packageName)).toList();

    // Use optimized sorting with HashMap (O(n log n) instead of O(n²))
    AppSorter.sortByOrder(filtered, appOrder);

    // Use batch-loaded settings
    final gridCols = settings.gridColumns;
    final showNames = settings.showAppNames;
    final iconSize = settings.iconScale;
    final title = settings.launcherTitle;
    final warning = settings.launchWarning;

    List<Map<String, dynamic>> recentAppsWithStats = [];
    for (var recent in recents) {
      final packageName = recent['packageName'];
      final app = apps.firstWhere(
        (a) => a.packageName == packageName,
        orElse: () => AppInfo(name: '', packageName: ''),
      );
      if (app.name.isNotEmpty && !hidden.contains(packageName)) {
        recentAppsWithStats.add({
          'app': app,
          'stats': recent,
        });
      }
    }

    if (mounted) {
      // Check if anything actually changed to avoid redundant rebuilds
      bool appsChanged = false;
      if (_filteredApps.length != filtered.length) {
        appsChanged = true;
      } else {
        for (int i = 0; i < filtered.length; i++) {
          if (_filteredApps[i].packageName != filtered[i].packageName ||
              _filteredApps[i].name != filtered[i].name ||
              _filteredApps[i].iconPath != filtered[i].iconPath) {
            appsChanged = true;
            break;
          }
        }
      }

      bool recentsChanged = false;
      if (_recentAppsStats.length != recentAppsWithStats.length) {
        recentsChanged = true;
      } else {
        for (int i = 0; i < _recentAppsStats.length; i++) {
          if (_recentAppsStats[i]['stats']?.toString() !=
              recentAppsWithStats[i]['stats']?.toString()) {
            recentsChanged = true;
            break;
          }
        }
      }

      bool hasChanged = appsChanged ||
          recentsChanged ||
          _gridColumns != gridCols ||
          _showAppNames != showNames ||
          _iconScale != iconSize ||
          _launcherTitle != title ||
          _launchWarning != warning;

      if (hasChanged || _isLoading) {
        setState(() {
          _filteredApps = filtered;
          _recentAppsStats = recentAppsWithStats;

          _gridColumns = gridCols;
          _showAppNames = showNames;
          _iconScale = iconSize;
          _launcherTitle = title;
          _launchWarning = warning;

          if (recentAppsWithStats.isNotEmpty) {
            _featuredItem = recentAppsWithStats.first;
          } else if (filtered.isNotEmpty) {
            _featuredItem = {'app': filtered.first, 'stats': null};
          } else {
            _featuredItem = null;
          }

          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchApp(AppInfo app) async {
    // Check launch warning FIRST
    if (_launchWarning.isNotEmpty) {
      if (mounted) {
        bool? shouldLaunch = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF0D0D0D),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFF00D4FF), width: 1),
              borderRadius: BorderRadius.circular(0),
            ),
            title: const Text(
              'SECURITY WARNING',
              style: TextStyle(
                color: Color(0xFF00D4FF),
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 14,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App icon
                if (app.iconPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(app.iconPath!),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 12),
                // App name
                Text(
                  app.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Warning message
                Text(
                  _launchWarning,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child:
                    const Text('CANCEL', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF),
                  foregroundColor: Colors.black,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, size: 16),
                    SizedBox(width: 6),
                    Text('PLAY',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );

        if (shouldLaunch != true) return;
      }
    }

    // Proceed with stats update and launch
    HapticFeedback.lightImpact();

    List<Map<String, dynamic>> recents = [];
    final recentsData = await SafePrefs.getString(PrefKeys.recentAppsData);
    if (recentsData != null) {
      try {
        recents = List<Map<String, dynamic>>.from(jsonDecode(recentsData));
      } catch (_) {}
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    bool found = false;
    for (var r in recents) {
      if (r['packageName'] == app.packageName) {
        r['lastPlayed'] = now;
        r['playtime'] = (r['playtime'] ?? 0) + 1;
        found = true;
        break;
      }
    }

    if (!found) {
      recents.insert(0, {
        'packageName': app.packageName,
        'lastPlayed': now,
        'playtime': 1,
      });
    }

    recents.sort(
        (a, b) => (b['lastPlayed'] as int).compareTo(a['lastPlayed'] as int));
    if (recents.length > 30) recents = recents.sublist(0, 30);

    await SafePrefs.setString(PrefKeys.recentAppsData, jsonEncode(recents));

    try {
      await _launcherService.launchApp(app.packageName);
    } catch (e) {
      debugPrint("Error launching app: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to launch: $e')),
        );
      }
    }

    _loadApps();
  }

  Future<void> _handleSettingsAccess() async {
    final now = DateTime.now();
    if (_lastSettingsTap == null ||
        now.difference(_lastSettingsTap!) > const Duration(seconds: 2)) {
      _settingsTapCount = 1;
    } else {
      _settingsTapCount++;
    }
    _lastSettingsTap = now;

    if (_settingsTapCount < 5) return;

    // Reset count after successful sequence
    _settingsTapCount = 0;

    const storage = FlutterSecureStorage();
    final pin = await storage.read(key: 'app_lock_pin');

    if (pin == null || pin.isEmpty) {
      if (mounted) {
        await Navigator.pushNamed(context, '/settings');
        _loadApps();
      }
      return;
    }

    if (!mounted) return;

    final authorized = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinVerificationDialog(correctPin: pin),
    );

    if (authorized == true && mounted) {
      await Navigator.pushNamed(context, '/settings');
      _loadApps();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: GamingLoadingIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            _buildBackground(),
            SafeArea(
              child: OrientationBuilder(
                builder: (context, orientation) {
                  final isLandscape = orientation == Orientation.landscape;

                  return Column(
                    children: [
                      _buildTopBar(),
                      Expanded(
                        child: isLandscape
                            ? Row(
                                children: [
                                  if (_featuredItem != null)
                                    Expanded(
                                      flex: 2,
                                      child: _buildFeaturedSection(
                                          _featuredItem!['app'],
                                          _featuredItem!['stats']),
                                    ),
                                  Expanded(
                                    flex: 3,
                                    child: _buildContentSection(),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  if (_featuredItem != null)
                                    SizedBox(
                                      height: MediaQuery.of(context).size.height *
                                          0.35,
                                      child: _buildFeaturedSection(
                                          _featuredItem!['app'],
                                          _featuredItem!['stats']),
                                    ),
                                  Expanded(
                                    child: _buildContentSection(),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: const Color(0xFF05050A)),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: GridPatternPainter(
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.7, -0.3),
                radius: 1.5,
                colors: [
                  const Color(0xFF1E1E3F).withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          InkWell(
            onTap: _handleSettingsAccess,
            borderRadius: BorderRadius.circular(30),
            child: GlassContainer(
              borderRadius: 30,
              opacity: 0.1,
              blur: 10,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child:
                    Icon(Icons.person_outline, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title Display
          Text(
            _launcherTitle.toUpperCase(),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 2.0),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildFeaturedSection(AppInfo app, Map<String, dynamic>? stats) {
    return FeaturedSection(
      app: app,
      stats: stats,
      iconScale: _iconScale,
      onTap: () => _launchApp(app),
    );
  }

  Widget _buildContentSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTab('Recently Played'),
              const SizedBox(width: 32),
              _buildTab('Library'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _currentTab == 'Recently Played'
                ? _buildRecentGrid()
                : _buildLibraryGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title) {
    final bool isActive = _currentTab == title;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = title),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white38,
                fontSize: 14, // REDUCED FONT SIZE
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            if (isActive)
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF00D4FF),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentGrid() {
    if (_recentAppsStats.isEmpty) {
      return Center(
        child: Text(
          'No recent activity',
          style: TextStyle(color: Colors.white12, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            MediaQuery.of(context).orientation == Orientation.landscape
                ? _gridColumns
                : 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: _recentAppsStats.length.clamp(0, 12),
      itemBuilder: (context, index) {
        final item = _recentAppsStats[index];
        return RepaintBoundary(
          child: _buildGameCardSmall(item['app'],
              stats: item['stats'], isRecent: true),
        );
      },
    );
  }

  Widget _buildLibraryGrid() {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            MediaQuery.of(context).orientation == Orientation.landscape
                ? _gridColumns
                : 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: _filteredApps.length,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: _buildGameCardSmall(_filteredApps[index], isRecent: false),
        );
      },
    );
  }

  Widget _buildGameCardSmall(AppInfo app,
      {Map<String, dynamic>? stats, required bool isRecent}) {
    return GameCardSmall(
      app: app,
      stats: stats,
      isRecent: isRecent,
      showAppName: _showAppNames,
      iconScale: _iconScale,
      onTap: () => _launchApp(app),
    );
  }
}
