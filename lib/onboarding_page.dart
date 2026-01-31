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
  bool _usageStatsGranted = false;
  bool _overlayGranted = false;

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

    if (mounted) {
      setState(() {
        _usageStatsGranted = usage;
        _overlayGranted = overlay;
      });

      if (usage && overlay) {
        // Automatically proceed if all granted
        _finishOnboarding();
      }
    }
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
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 40.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 48),
                  _buildPermissionStep(
                    title: 'USAGE MONITORING',
                    description:
                        'Required to track and lock unauthorized apps during gaming sessions.',
                    isGranted: _usageStatsGranted,
                    onTap: () async {
                      await _launcherService.openUsageAccessSettings();
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildPermissionStep(
                    title: 'ARCADE OVERLAY',
                    description:
                        'Enables the immersive arcade HUD and status bar blocking.',
                    isGranted: _overlayGranted,
                    onTap: () async {
                      await _launcherService.openOverlaySettings();
                    },
                  ),
                  const Spacer(),
                  _buildContinueButton(),
                ],
              ),
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
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
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

  Widget _buildPermissionStep({
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? const Color(0xFF00D4FF) : Colors.white10,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isGranted ? const Color(0xFF00D4FF) : Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (isGranted)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF00D4FF),
                  size: 20,
                )
              else
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFF9D4EDD),
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (!isGranted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF).withOpacity(0.1),
                  foregroundColor: const Color(0xFF00D4FF),
                  side: const BorderSide(color: Color(0xFF00D4FF)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('GRANT ACCESS'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    final bool allGranted = _usageStatsGranted && _overlayGranted;

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00D4FF), Color(0xFF9D4EDD)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D4FF).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _finishOnboarding,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            allGranted ? 'CONTINUE TO HUB' : 'SKIP FOR NOW',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
