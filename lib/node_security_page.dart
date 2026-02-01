import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pinput/pinput.dart';
import 'package:flutter/services.dart';

import 'services/launcher_service.dart';
import 'services/safe_prefs.dart';
import 'app_lifecycle_observer.dart';
import 'widgets/grid_pattern_painter.dart';

class NodeSecurityPage extends StatefulWidget {
  const NodeSecurityPage({super.key});

  @override
  State<NodeSecurityPage> createState() => _NodeSecurityPageState();
}

class _NodeSecurityPageState extends State<NodeSecurityPage> {
  final LauncherService _launcherService = LauncherService();
  final _secureStorage = const FlutterSecureStorage();
  static const _pinKey = 'app_lock_pin';

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _loading = true;
  bool _hasPin = false;
  int _pinLength = 4; // Default to 4-digit PIN
  int _sessionTimeout = 30; // Default 30 seconds
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  // Permission states
  bool _overlayEnabled = false;
  bool _accessibilityEnabled = false;
  bool _deviceAdminEnabled = false;
  bool _batteryOptimizationExempt = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    WidgetsBinding.instance.addObserver(_appLifecycleObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_appLifecycleObserver);
    super.dispose();
  }

  late final AppLifecycleObserver _appLifecycleObserver = AppLifecycleObserver(
    onResume: _loadSettings,
  );

  Future<void> _loadSettings() async {
    try {
      final pin = await _secureStorage.read(key: _pinKey);
      final sessionTimeout =
          await SafePrefs.getInt('session_timeout', defaultValue: 30);
      final biometricEnabled = await SafePrefs.getBool('biometric_enabled');

      // Load all permissions
      final overlayEnabled = await _launcherService.checkOverlayPermission();
      final accessibilityEnabled =
          await _launcherService.checkAccessibilityPermission();
      final deviceAdminEnabled =
          await _launcherService.checkDeviceAdminEnabled();
      final batteryExempt =
          await _launcherService.checkBatteryOptimizationExempt();

      // Check if biometric is available on this device
      bool canCheckBiometrics = false;
      try {
        canCheckBiometrics = await _localAuth.canCheckBiometrics;
        final isDeviceSupported = await _localAuth.isDeviceSupported();
        canCheckBiometrics = canCheckBiometrics && isDeviceSupported;
      } catch (e) {
        canCheckBiometrics = false;
      }

      if (mounted) {
        setState(() {
          _hasPin = pin != null && pin.isNotEmpty;
          _pinLength = pin?.length ?? 4;
          _sessionTimeout = sessionTimeout;
          _biometricAvailable = canCheckBiometrics;
          _biometricEnabled = biometricEnabled && canCheckBiometrics;
          _overlayEnabled = overlayEnabled;
          _accessibilityEnabled = accessibilityEnabled;
          _deviceAdminEnabled = deviceAdminEnabled;
          _batteryOptimizationExempt = batteryExempt;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showSetPinDialog() async {
    String? newPin;
    final controller = TextEditingController();
    int selectedLength = _pinLength;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Theme(
          data: ThemeData.dark(),
          child: AlertDialog(
            backgroundColor: const Color(0xFF0D0D0D),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFF00D4FF), width: 1),
              borderRadius: BorderRadius.circular(0),
            ),
            title: Text(
              _hasPin ? 'CHANGE ACCESS KEY' : 'SET ACCESS KEY',
              style: const TextStyle(
                color: Color(0xFF00D4FF),
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // PIN Length Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPinLengthOption(4, selectedLength, (val) {
                      setDialogState(() {
                        selectedLength = val;
                        controller.clear();
                        newPin = null;
                      });
                    }),
                    const SizedBox(width: 12),
                    _buildPinLengthOption(6, selectedLength, (val) {
                      setDialogState(() {
                        selectedLength = val;
                        controller.clear();
                        newPin = null;
                      });
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'ENTER $selectedLength-DIGIT AUTHORIZATION CODE',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                if (selectedLength == 6)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '(STRONGER SECURITY)',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF00FF9D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Pinput(
                  key: ValueKey(selectedLength),
                  controller: controller,
                  length: selectedLength,
                  obscureText: true,
                  defaultPinTheme: PinTheme(
                    width: selectedLength == 6 ? 44 : 56,
                    height: selectedLength == 6 ? 44 : 56,
                    textStyle: const TextStyle(
                      fontSize: 20,
                      color: Color(0xFF9D4EDD),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF333333)),
                      borderRadius: BorderRadius.circular(0),
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  focusedPinTheme: PinTheme(
                    width: selectedLength == 6 ? 44 : 56,
                    height: selectedLength == 6 ? 44 : 56,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF00D4FF)),
                      borderRadius: BorderRadius.circular(0),
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  onCompleted: (pin) => newPin = pin,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child:
                    const Text('CANCEL', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () async {
                  if (newPin != null && newPin!.length == selectedLength) {
                    await _secureStorage.write(key: _pinKey, value: newPin);
                    await SafePrefs.setString(
                      _pinKey,
                      newPin!,
                    );

                    await _launcherService.onPinUpdated(newPin);

                    if (mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('ACCESS KEY GRANTED'),
                          backgroundColor: Color(0xFF00D4FF),
                        ),
                      );
                      setState(() {
                        _hasPin = true;
                        _pinLength = selectedLength;
                      });
                    }
                  }
                },
                child: const Text(
                  'SAVE',
                  style: TextStyle(
                    color: Color(0xFF00D4FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinLengthOption(
      int length, int selectedLength, ValueChanged<int> onSelect) {
    final isSelected = length == selectedLength;
    return GestureDetector(
      onTap: () => onSelect(length),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00D4FF) : const Color(0xFF1A1A1A),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF00D4FF) : const Color(0xFF333333),
          ),
        ),
        child: Text(
          '$length DIGITS',
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A).withOpacity(0.8),
        border: Border.all(
          color: _biometricEnabled
              ? const Color(0xFF00FF9D)
              : const Color(0xFF333333),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fingerprint,
            color: _biometricEnabled ? const Color(0xFF00FF9D) : Colors.white54,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BIOMETRIC UNLOCK',
                  style: TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _biometricEnabled
                      ? 'Use fingerprint or face to unlock'
                      : 'Enable biometric authentication',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: _biometricEnabled,
            activeColor: const Color(0xFF00FF9D),
            onChanged: (value) async {
              if (value) {
                final authenticated = await _authenticateWithBiometric();
                if (authenticated) {
                  await SafePrefs.setBool('biometric_enabled', true);
                  await _launcherService.setBiometricEnabled(true);
                  setState(() => _biometricEnabled = true);
                }
              } else {
                await SafePrefs.setBool('biometric_enabled', false);
                await _launcherService.setBiometricEnabled(false);
                setState(() => _biometricEnabled = false);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _authenticateWithBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Verify your identity to enable biometric unlock',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  Widget _buildSessionTimeoutSelector() {
    final timeoutOptions = [15, 30, 60, 120, 300];
    final timeoutLabels = ['15s', '30s', '1m', '2m', '5m'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A).withOpacity(0.8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer, color: Color(0xFF00D4FF), size: 20),
              SizedBox(width: 8),
              Text(
                'SESSION TIMEOUT',
                style: TextStyle(
                  color: Color(0xFF00D4FF),
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Time before requiring PIN again after unlock',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(timeoutOptions.length, (index) {
              final isSelected = _sessionTimeout == timeoutOptions[index];
              return GestureDetector(
                onTap: () async {
                  await SafePrefs.setInt(
                      'session_timeout', timeoutOptions[index]);
                  await _launcherService
                      .setSessionTimeout(timeoutOptions[index]);
                  setState(() {
                    _sessionTimeout = timeoutOptions[index];
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF9D4EDD)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF9D4EDD)
                          : const Color(0xFF333333),
                    ),
                  ),
                  child: Text(
                    timeoutLabels[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'ACCESS CONTROL',
          style: TextStyle(
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.9),
                Colors.transparent,
              ],
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF00D4FF)),
        actions: [
          if (_hasPin)
            IconButton(
              icon: const Icon(Icons.lock_reset, color: Color(0xFF9D4EDD)),
              onPressed: () async {
                await _secureStorage.delete(key: _pinKey);
                await SafePrefs.remove(_pinKey);
                setState(() {
                  _hasPin = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('SECURITY OVERRIDE: PIN REMOVED'),
                      backgroundColor: Color(0xFFFF0055),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildBackground(),
          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
                )
              : ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  children: [
                    _buildSecurityStatus(),
                    const SizedBox(height: 16),
                    if (_hasPin) _buildSessionTimeoutSelector(),
                    if (_hasPin && _biometricAvailable) ...[
                      const SizedBox(height: 16),
                      _buildBiometricToggle(),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'ACCESS PROTECTION',
                      style: TextStyle(
                        color: Color(0xFF00D4FF),
                        fontSize: 12,
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: Color(0xFF333333), height: 32),
                    if (!_hasPin)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF12121A).withOpacity(0.8),
                          border: Border.all(
                            color: const Color(0xFFFF0055).withOpacity(0.5),
                          ),
                        ),
                        child: const Text(
                          'WARNING: PASSKEY NOT SET. CONTROL PANEL IS UNRESTRICTED.',
                          style: TextStyle(
                            color: Color(0xFFFF0055),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    _buildPermissionsCard(),
                    const SizedBox(height: 24),
                  ],
                ),
        ],
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
          child: CustomPaint(
            painter: GridPatternPainter(
              color: Colors.white.withOpacity(0.03),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 1.5,
                colors: [
                  const Color(0xFF1E1E3F).withOpacity(0.2),
                  const Color(0xFF05050A).withOpacity(0.9),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A).withOpacity(0.8),
        border: Border.all(
          color: _hasPin ? const Color(0xFF00D4FF) : const Color(0xFFFF0055),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _hasPin ? Icons.shield : Icons.shield_outlined,
            color: _hasPin ? const Color(0xFF00D4FF) : const Color(0xFFFF0055),
            size: 40,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasPin ? 'ACCESS RESTRICTED' : 'ACCESS UNRESTRICTED',
                  style: TextStyle(
                    color: _hasPin
                        ? const Color(0xFF00D4FF)
                        : const Color(0xFFFF0055),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  _hasPin
                      ? '$_pinLength-digit PIN active'
                      : 'Set a PIN to restrict access',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _showSetPinDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: Colors.black,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: Text(
              _hasPin ? 'UPDATE' : 'SET PIN',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  int get _permissionCount {
    int count = 0;
    if (_overlayEnabled) count++;
    if (_accessibilityEnabled) count++;
    if (_deviceAdminEnabled) count++;
    if (_batteryOptimizationExempt) count++;
    return count;
  }

  Widget _buildPermissionsCard() {
    final allEnabled = _permissionCount == 4;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A).withOpacity(0.8),
        border: Border.all(
          color: allEnabled ? const Color(0xFF00FF9D) : const Color(0xFF9D4EDD),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allEnabled ? Icons.verified_user : Icons.security,
                color: allEnabled ? const Color(0xFF00FF9D) : const Color(0xFF9D4EDD),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'SYSTEM PERMISSIONS',
                style: TextStyle(
                  color: allEnabled ? const Color(0xFF00FF9D) : const Color(0xFF9D4EDD),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: allEnabled
                      ? const Color(0xFF00FF9D).withOpacity(0.1)
                      : const Color(0xFF9D4EDD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$_permissionCount/4',
                  style: TextStyle(
                    color: allEnabled ? const Color(0xFF00FF9D) : const Color(0xFF9D4EDD),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPermissionRow(
            'Overlay Permission',
            'Lock screen display',
            Icons.layers_outlined,
            _overlayEnabled,
            () => _launcherService.openOverlaySettings(),
          ),
          const SizedBox(height: 8),
          _buildPermissionRow(
            'Accessibility Service',
            'System UI blocking',
            Icons.accessibility_new,
            _accessibilityEnabled,
            () => _launcherService.openAccessibilitySettings(),
          ),
          const SizedBox(height: 8),
          _buildPermissionRow(
            'Device Admin',
            'Screen lock on timeout',
            Icons.admin_panel_settings_outlined,
            _deviceAdminEnabled,
            () => _launcherService.openDeviceAdminSettings(),
          ),
          const SizedBox(height: 8),
          _buildPermissionRow(
            'Battery Optimization',
            'Background operation',
            Icons.battery_saver,
            _batteryOptimizationExempt,
            () => _launcherService.openBatteryOptimizationSettings(),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(
      String title, String description, IconData icon, bool isGranted, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF05050A).withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: isGranted
                  ? const Color(0xFF00FF9D).withOpacity(0.3)
                  : const Color(0xFFFF6B6B).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isGranted ? const Color(0xFF00FF9D) : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isGranted ? const Color(0xFF00FF9D) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isGranted
                    ? const Color(0xFF00FF9D).withOpacity(0.1)
                    : const Color(0xFFFF6B6B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isGranted ? 'ON' : 'OFF',
                style: TextStyle(
                  color: isGranted ? const Color(0xFF00FF9D) : const Color(0xFFFF6B6B),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
