import 'package:flutter/material.dart';
import 'constants/pref_keys.dart';
import 'services/launcher_service.dart';
import 'services/safe_prefs.dart';
import 'widgets/grid_pattern_painter.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with WidgetsBindingObserver {
  final LauncherService _launcherService = LauncherService();

  // Permission states
  bool _usageStatsGranted = false;
  bool _overlayGranted = false;
  bool _accessibilityGranted = false;
  bool _deviceAdminGranted = false;
  bool _batteryOptimizationExempt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final usage = await _launcherService.checkUsageStatsPermission();
    final overlay = await _launcherService.checkOverlayPermission();
    final accessibility = await _launcherService.checkAccessibilityPermission();
    final deviceAdmin = await _launcherService.checkDeviceAdminEnabled();
    final batteryExempt = await _launcherService.checkBatteryOptimizationExempt();

    if (mounted) {
      setState(() {
        _usageStatsGranted = usage;
        _overlayGranted = overlay;
        _accessibilityGranted = accessibility;
        _deviceAdminGranted = deviceAdmin;
        _batteryOptimizationExempt = batteryExempt;
      });

      // Automatically proceed if all critical permissions are granted
      if (_allCriticalPermissionsGranted) {
        _finishOnboarding();
      }
    }
  }

  bool get _allCriticalPermissionsGranted =>
      _usageStatsGranted && _overlayGranted;

  bool get _allPermissionsGranted =>
      _usageStatsGranted &&
      _overlayGranted &&
      _accessibilityGranted &&
      _deviceAdminGranted &&
      _batteryOptimizationExempt;

  int get _grantedCount {
    int count = 0;
    if (_usageStatsGranted) count++;
    if (_overlayGranted) count++;
    if (_accessibilityGranted) count++;
    if (_deviceAdminGranted) count++;
    if (_batteryOptimizationExempt) count++;
    return count;
  }

  Future<void> _finishOnboarding() async {
    await SafePrefs.setBool(PrefKeys.onboardingComplete, true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Cyberpunk Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F0F1E),
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                ],
              ),
            ),
          ),
          CustomPaint(
            size: Size.infinite,
            painter: GridPatternPainter(
              color: const Color(0xFF00D4FF).withOpacity(0.05),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 32.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 32),
                        _buildProgressIndicator(),
                        const SizedBox(height: 24),

                        // Critical Permissions Section
                        _buildSectionHeader('CRITICAL PERMISSIONS', const Color(0xFFFF6B6B)),
                        const SizedBox(height: 12),
                        _buildPermissionStep(
                          title: 'USAGE MONITORING',
                          description:
                              'Required to track and manage app sessions.',
                          isGranted: _usageStatsGranted,
                          icon: Icons.analytics_outlined,
                          onTap: () async {
                            await _launcherService.openUsageAccessSettings();
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildPermissionStep(
                          title: 'ARCADE OVERLAY',
                          description:
                              'Enables the immersive arcade HUD and lock screen.',
                          isGranted: _overlayGranted,
                          icon: Icons.layers_outlined,
                          onTap: () async {
                            await _launcherService.openOverlaySettings();
                          },
                        ),

                        const SizedBox(height: 24),

                        // Recommended Permissions Section
                        _buildSectionHeader('RECOMMENDED PERMISSIONS', const Color(0xFF9D4EDD)),
                        const SizedBox(height: 12),
                        _buildPermissionStep(
                          title: 'ACCESSIBILITY SERVICE',
                          description:
                              'Blocks system UI and enables touch blocking for kiosk mode.',
                          isGranted: _accessibilityGranted,
                          icon: Icons.accessibility_new,
                          onTap: () async {
                            await _launcherService.openAccessibilitySettings();
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildPermissionStep(
                          title: 'DEVICE ADMIN',
                          description:
                              'Allows screen lock after countdown timer expires.',
                          isGranted: _deviceAdminGranted,
                          icon: Icons.admin_panel_settings_outlined,
                          onTap: () async {
                            await _launcherService.openDeviceAdminSettings();
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildPermissionStep(
                          title: 'BATTERY OPTIMIZATION',
                          description:
                              'Prevents system from killing the app in background.',
                          isGranted: _batteryOptimizationExempt,
                          icon: Icons.battery_saver,
                          onTap: () async {
                            await _launcherService.openBatteryOptimizationSettings();
                          },
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                // Fixed bottom button
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildContinueButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SYSTEM',
          style: TextStyle(
            color: Color(0xFF00D4FF),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'INITIALIZATION',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00D4FF), Color(0xFF9D4EDD)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _allPermissionsGranted
              ? const Color(0xFF00D4FF)
              : Colors.white10,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  value: _grantedCount / 5,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _allPermissionsGranted
                        ? const Color(0xFF00D4FF)
                        : const Color(0xFF9D4EDD),
                  ),
                  strokeWidth: 4,
                ),
              ),
              Text(
                '$_grantedCount/5',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _allPermissionsGranted
                      ? 'ALL SYSTEMS ONLINE'
                      : 'PERMISSIONS REQUIRED',
                  style: TextStyle(
                    color: _allPermissionsGranted
                        ? const Color(0xFF00D4FF)
                        : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _allPermissionsGranted
                      ? 'Ready to launch'
                      : 'Grant permissions for full functionality',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionStep({
    required String title,
    required String description,
    required bool isGranted,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted ? const Color(0xFF00D4FF) : Colors.white10,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFF00D4FF).withOpacity(0.1)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isGranted ? const Color(0xFF00D4FF) : Colors.white54,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isGranted ? const Color(0xFF00D4FF) : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (isGranted)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF00D4FF),
                        size: 18,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (!isGranted) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF).withOpacity(0.1),
                  foregroundColor: const Color(0xFF00D4FF),
                  side: const BorderSide(color: Color(0xFF00D4FF), width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'GRANT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    final bool allGranted = _allPermissionsGranted;
    final bool criticalGranted = _allCriticalPermissionsGranted;

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: allGranted
                ? [const Color(0xFF00D4FF), const Color(0xFF9D4EDD)]
                : [Colors.white24, Colors.white12],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: allGranted
              ? [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: _finishOnboarding,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            allGranted
                ? 'INITIALIZE SYSTEM'
                : criticalGranted
                    ? 'CONTINUE (${5 - _grantedCount} OPTIONAL)'
                    : 'SKIP FOR NOW',
            style: TextStyle(
              color: allGranted ? Colors.white : Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
