import 'package:flutter/material.dart';
import 'package:arcade_launcher/app_order_page.dart';
import 'package:arcade_launcher/app_backgrounds_page.dart';
import 'package:arcade_launcher/node_security_page.dart';
import 'package:arcade_launcher/constants/pref_keys.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import 'package:arcade_launcher/widgets/settings/permission_tile.dart';

import 'services/launcher_service.dart';
import 'services/safe_prefs.dart';
import 'models/app_info.dart';

import 'widgets/grid_pattern_painter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  final LauncherService _launcherService = LauncherService();
  int _currentGridSize = 2;
  bool _arcadeModeEnabled = false;
  bool _showAppNames = true;
  double _cardIconSize = 36.0;
  String _launchWarningText =
      'SECURITY: Do not leave accounts logged in. Always logout after session.';

  // Permission states
  bool _overlayEnabled = false;
  bool _accessibilityEnabled = false;
  bool _deviceAdminEnabled = false;
  bool _batteryOptimizationExempt = false;

  // Overlay image
  String? _overlayImagePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPermissions();
    }
  }

  Future<void> _loadPermissions() async {
    final overlay = await _launcherService.checkOverlayPermission();
    final accessibility = await _launcherService.checkAccessibilityPermission();
    final deviceAdmin = await _launcherService.checkDeviceAdminEnabled();
    final batteryExempt =
        await _launcherService.checkBatteryOptimizationExempt();

    if (mounted) {
      setState(() {
        _overlayEnabled = overlay;
        _accessibilityEnabled = accessibility;
        _deviceAdminEnabled = deviceAdmin;
        _batteryOptimizationExempt = batteryExempt;
      });
    }
  }

  void _loadSettings() async {
    final gridColumns = await SafePrefs.getInt(PrefKeys.gridColumns,
        defaultValue: PrefKeys.defaultGridColumns);
    final arcadeMode = await SafePrefs.getBool(PrefKeys.arcadeModeEnabled);
    final showNames = await SafePrefs.getBool(PrefKeys.showAppNames,
        defaultValue: PrefKeys.defaultShowAppNames);
    final iconSize = await SafePrefs.getDouble(PrefKeys.cardIconSize,
        defaultValue: PrefKeys.defaultCardIconSize);
    final warningText = await SafePrefs.getString(PrefKeys.launchWarningText);
    final overlayImagePath = await _launcherService.getOverlayImagePath();

    // Load permissions
    await _loadPermissions();

    if (mounted) {
      setState(() {
        _currentGridSize = gridColumns;
        _arcadeModeEnabled = arcadeMode;
        _showAppNames = showNames;
        _cardIconSize = iconSize;
        _launchWarningText = warningText ?? _launchWarningText;
        _overlayImagePath = overlayImagePath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black, // Fallback
      appBar: AppBar(
        title: const Text(
          'SYSTEM CONFIG',
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
      ),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _buildSettingsCard(
                  context,
                  title: 'CORE INTERFACE',
                  icon: Icons.hub,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.home, color: Color(0xFF00D4FF)),
                      title: const Text('DEFAULT TERMINAL',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)), // Reduced font size
                      subtitle: const Text('Set as default system launcher',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11)), // Reduced font size
                      onTap: () async {
                        await _launcherService.openHomeSettings();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit, color: Color(0xFF00D4FF)),
                      title: const Text('LIBRARY DESIGNATION',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)), // Reduced font size
                      subtitle: const Text('Change launcher title',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11)), // Reduced font size
                      onTap: _showChangeTitleDialog,
                    ),
                  ],
                ),
                _buildSettingsCard(
                  context,
                  title: 'VISUAL OVERRIDE',
                  icon: Icons.visibility,
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.wallpaper, color: Color(0xFF00D4FF)),
                      title: const Text('WALLPAPER LINK',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)), // Reduced font size
                      subtitle: const Text('Set custom atmospheric background',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11)), // Reduced font size
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _launcherService.changeWallpaper();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('RELOADING ATMOSPHERE...'),
                              backgroundColor: Color(0xFF00D4FF),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('ERROR: $e')),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.grid_view, color: Color(0xFF00D4FF)),
                      title: const Text('GRID DENSITY',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)), // Reduced font size
                      subtitle: Text('Current: $_currentGridSize columns',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11)), // Reduced font size
                      onTap: _showGridSizeDialog,
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.zoom_in, color: Color(0xFF00D4FF)),
                      title: const Text('ICON SCALE',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)), // Reduced font size
                      subtitle: Text(
                        'Internal icon magnification: ${_cardIconSize.toInt()}%',
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11), // Reduced font size
                      ),
                      onTap: _showIconSizeDialog,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.label_outline,
                          color: Color(0xFF00D4FF)),
                      title: const Text('APP NAMES',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)), // Reduced font size
                      subtitle: const Text('Show names below icons',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11)), // Reduced font size
                      value: _showAppNames,
                      activeColor: const Color(0xFF00D4FF),
                      inactiveTrackColor: Colors.white10,
                      onChanged: (bool value) async {
                        await SafePrefs.setBool(PrefKeys.showAppNames, value);
                        setState(() {
                          _showAppNames = value;
                        });
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.image, color: Color(0xFF00D4FF)),
                      title: const Text('APP BACKGROUNDS',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)), // Reduced font size
                      subtitle: const Text('Set custom card backgrounds',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11)), // Reduced font size
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AppBackgroundsPage(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.sort, color: Color(0xFF00D4FF)),
                      title: const Text('MANAGE APP ORDER',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)), // Reduced font size
                      subtitle: const Text('Change the library sequence',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11)), // Reduced font size
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AppOrderPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                _buildSettingsCard(
                  context,
                  title: 'SECURITY PROTOCOLS',
                  icon: Icons.security,
                  borderColor: const Color(0xFF9D4EDD), // Purple
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.lock,
                        color: Color(0xFF9D4EDD),
                      ),
                      title: const Text('ACCESS CONTROL',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      subtitle: const Text('Set PIN lock for settings access',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NodeSecurityPage(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.shield,
                        color: Color(0xFF9D4EDD),
                      ),
                      title: const Text('HIDDEN NODES',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      subtitle: const Text('Management of hidden applications',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HiddenNodesPage(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.warning,
                        color: Color(0xFF9D4EDD),
                      ),
                      title: const Text('LAUNCH WARNING',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      subtitle: const Text('Edit security warning message',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                      onTap: _showChangeWarningDialog,
                    ),
                    SwitchListTile(
                      secondary:
                          const Icon(Icons.gamepad, color: Color(0xFF9D4EDD)),
                      title: const Text('ARCADE MODE',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      subtitle: const Text('Auto-lock when power link severed',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                      value: _arcadeModeEnabled,
                      activeColor: const Color(0xFF9D4EDD),
                      inactiveTrackColor: Colors.white10,
                      onChanged: (bool value) async {
                        if (value) {
                          if (await Permission.systemAlertWindow.isGranted) {
                            await _launcherService.startOverlayService();
                            await SafePrefs.setBool(
                                PrefKeys.arcadeModeEnabled, true);
                            setState(() {
                              _arcadeModeEnabled = true;
                            });
                          } else {
                            await _launcherService.openOverlaySettings();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'GRANT OVERLAY PERMISSION TO ENGAGE ARCADE MODE.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        } else {
                          await _launcherService.stopOverlayService();
                          await SafePrefs.setBool(
                              PrefKeys.arcadeModeEnabled, false);
                          setState(() {
                            _arcadeModeEnabled = false;
                          });
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.image,
                        color: _overlayImagePath != null
                            ? const Color(0xFF00FF9D)
                            : const Color(0xFF9D4EDD),
                      ),
                      title: const Text('OVERLAY IMAGE',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      subtitle: Text(
                          _overlayImagePath != null
                              ? 'Custom image set (tap to change)'
                              : 'Set custom lock screen image/GIF',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                      trailing: _overlayImagePath != null
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Color(0xFFFF6B6B)),
                              onPressed: () async {
                                await _launcherService.clearOverlayImage();
                                setState(() {
                                  _overlayImagePath = null;
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('OVERLAY IMAGE CLEARED'),
                                      backgroundColor: Color(0xFF9D4EDD),
                                    ),
                                  );
                                }
                              },
                            )
                          : null,
                      onTap: () async {
                        await _launcherService.pickOverlayImage();
                        // Reload the path after picking
                        final newPath =
                            await _launcherService.getOverlayImagePath();
                        if (mounted && newPath != null) {
                          setState(() {
                            _overlayImagePath = newPath;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('OVERLAY IMAGE SET'),
                              backgroundColor: Color(0xFF00D4FF),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                _buildSettingsCard(
                  context,
                  title: 'SYSTEM PERMISSIONS',
                  icon: Icons.verified_user,
                  borderColor: const Color(0xFF00D4FF),
                  children: [
                    PermissionTile(
                      title: 'OVERLAY PERMISSION',
                      subtitle: 'Required for arcade lock screen',
                      icon: Icons.layers_outlined,
                      isEnabled: _overlayEnabled,
                      onTap: () => _launcherService.openOverlaySettings(),
                    ),
                    PermissionTile(
                      title: 'ACCESSIBILITY SERVICE',
                      subtitle: 'Blocks system UI in kiosk mode',
                      icon: Icons.accessibility_new,
                      isEnabled: _accessibilityEnabled,
                      onTap: () => _launcherService.openAccessibilitySettings(),
                    ),
                    PermissionTile(
                      title: 'DEVICE ADMIN',
                      subtitle: 'Enables screen lock on timeout',
                      icon: Icons.admin_panel_settings_outlined,
                      isEnabled: _deviceAdminEnabled,
                      onTap: () => _launcherService.openDeviceAdminSettings(),
                    ),
                    PermissionTile(
                      title: 'BATTERY OPTIMIZATION',
                      subtitle: 'Keeps app running in background',
                      icon: Icons.battery_saver,
                      isEnabled: _batteryOptimizationExempt,
                      onTap: () =>
                          _launcherService.openBatteryOptimizationSettings(),
                    ),
                  ],
                ),
                _buildSettingsCard(
                  context,
                  title: 'SYSTEM INFO',
                  icon: Icons.info_outline,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.info,
                        color: Colors.white54,
                      ),
                      title: const Text('MANIFEST',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'ARCADE LAUNCHER',
                          applicationVersion: '1.0.0',
                          applicationLegalese: '© 2026 DEV JIMF',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 60),
              ],
            ),
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

  Future<void> _showChangeWarningDialog() async {
    TextEditingController controller = TextEditingController(
      text: _launchWarningText,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF00D4FF), width: 1),
          borderRadius: BorderRadius.circular(0),
        ),
        title: const Text('SET LAUNCH WARNING',
            style: TextStyle(
                color: Color(0xFF00D4FF), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter security warning',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white30)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00D4FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await SafePrefs.setString(
                  PrefKeys.launchWarningText, controller.text);
              if (mounted) {
                setState(() {
                  _launchWarningText = controller.text;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Warning updated.'),
                      backgroundColor: Color(0xFF00D4FF)),
                );
              }
            },
            child: const Text('SAVE',
                style: TextStyle(
                    color: Color(0xFF00D4FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangeTitleDialog() async {
    String currentTitle = await SafePrefs.getString(PrefKeys.launcherTitle) ??
        PrefKeys.defaultLauncherTitle;
    TextEditingController controller = TextEditingController(
      text: currentTitle,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF00D4FF), width: 1),
          borderRadius: BorderRadius.circular(0),
        ),
        title: const Text('SET LAUNCHER TITLE',
            style: TextStyle(
                color: Color(0xFF00D4FF), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter title',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white30)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00D4FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await SafePrefs.setString(
                  PrefKeys.launcherTitle, controller.text);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(
                    content: Text('Title updated.'),
                    backgroundColor: Color(0xFF00D4FF)));
              }
            },
            child: const Text('SAVE',
                style: TextStyle(
                    color: Color(0xFF00D4FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showGridSizeDialog() async {
    int? selectedSize = _currentGridSize;

    int? newSize = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D0D0D),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFF00D4FF), width: 1),
            borderRadius: BorderRadius.circular(0),
          ),
          title: const Text('SELECT GRID SIZE',
              style: TextStyle(
                  color: Color(0xFF00D4FF), fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$selectedSize Columns',
                      style: const TextStyle(color: Colors.white)),
                  Slider(
                    value: selectedSize!.toDouble(),
                    min: 2,
                    max: 10,
                    divisions: 8,
                    activeColor: const Color(0xFF00D4FF),
                    inactiveColor: Colors.white10,
                    label: selectedSize.toString(),
                    onChanged: (double value) {
                      setState(() {
                        selectedSize = value.toInt();
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('OK',
                  style: TextStyle(
                      color: Color(0xFF00D4FF), fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(selectedSize),
            ),
          ],
        );
      },
    );

    if (newSize != null) {
      await SafePrefs.setInt(PrefKeys.gridColumns, newSize);
      setState(() {
        _currentGridSize = newSize;
      });
    }
  }

  Future<void> _showIconSizeDialog() async {
    double selectedSize = _cardIconSize;

    double? newSize = await showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D0D0D),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFF00D4FF), width: 1),
            borderRadius: BorderRadius.circular(0),
          ),
          title: const Text('ADJUST ICON SCALE',
              style: TextStyle(
                  color: Color(0xFF00D4FF), fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${selectedSize.toInt()}% Scaling',
                      style: const TextStyle(color: Colors.white)),
                  Slider(
                    value: selectedSize,
                    min: 24,
                    max: 100,
                    divisions: 76,
                    activeColor: const Color(0xFF00D4FF),
                    inactiveColor: Colors.white10,
                    label: selectedSize.toInt().toString(),
                    onChanged: (double value) {
                      setState(() {
                        selectedSize = value;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('OK',
                  style: TextStyle(
                      color: Color(0xFF00D4FF), fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(selectedSize),
            ),
          ],
        );
      },
    );

    if (newSize != null) {
      await SafePrefs.setDouble(PrefKeys.cardIconSize, newSize);
      setState(() {
        _cardIconSize = newSize;
      });
    }
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color borderColor = const Color(0xFF00D4FF),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A).withOpacity(0.8),
        border: Border(
          left: BorderSide(color: borderColor, width: 2),
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
          right: BorderSide(color: Colors.white.withOpacity(0.05)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            color: Colors.white.withOpacity(0.02),
            child: Row(
              children: [
                Icon(icon, size: 16, color: borderColor),
                const SizedBox(width: 10),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: borderColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          ...children,
        ],
      ),
    );
  }
}

class HiddenNodesPage extends StatefulWidget {
  const HiddenNodesPage({super.key});

  @override
  State<HiddenNodesPage> createState() => _HiddenNodesPageState();
}

class _HiddenNodesPageState extends State<HiddenNodesPage> {
  final LauncherService _launcherService = LauncherService();
  List<AppInfo> _apps = [];
  List<String> _secureApps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final secure = await SafePrefs.getStringList(PrefKeys.hiddenApps);
    final apps = await _launcherService.getApps();

    if (mounted) {
      setState(() {
        _secureApps = secure;
        _apps = apps;
        _loading = false;
      });
    }
  }

  Future<void> _toggleAppVisibility(String packageName, bool isHidden) async {
    setState(() {
      if (isHidden) {
        if (!_secureApps.contains(packageName)) {
          _secureApps.add(packageName);
        }
      } else {
        _secureApps.remove(packageName);
      }
    });

    await SafePrefs.setStringList(PrefKeys.hiddenApps, _secureApps);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'HIDDEN NODES',
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
      ),
      body: Stack(
        children: [
          _buildBackground(),
          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top +
                              kToolbarHeight +
                              10),
                    ),

                    // --- SECURE APPS SECTION ---
                    if (_secureApps.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                          child: Row(
                            children: [
                              Icon(Icons.shield,
                                  color: Color(0xFF00D4FF), size: 16),
                              SizedBox(width: 8),
                              Text(
                                'HIDDEN APPLICATIONS',
                                style: TextStyle(
                                  color: Color(0xFF00D4FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final packageName = _secureApps[index];
                            final app = _apps.firstWhere(
                              (a) => a.packageName == packageName,
                              orElse: () => AppInfo(
                                  name: packageName, packageName: packageName),
                            );
                            return _buildAppListTile(app, isSecure: true);
                          },
                          childCount: _secureApps.length,
                        ),
                      ),
                    ],

                    // --- ALL APPS SECTION ---
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 32, 16, 12),
                        child: Row(
                          children: [
                            Icon(Icons.apps, color: Colors.white54, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'AVAILABLE APPS',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // Filter available apps (not in secure list)
                          final availableApps = _apps
                              .where(
                                  (a) => !_secureApps.contains(a.packageName))
                              .toList();

                          if (index >= availableApps.length) return null;

                          final app = availableApps[index];
                          return _buildAppListTile(app, isSecure: false);
                        },
                        childCount: _apps
                            .where((a) => !_secureApps.contains(a.packageName))
                            .length,
                      ),
                    ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
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

  Widget _buildAppListTile(AppInfo app, {required bool isSecure}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A).withOpacity(0.6),
        border: Border(
          left: isSecure
              ? const BorderSide(color: Color(0xFF00D4FF), width: 2)
              : BorderSide.none,
          bottom: const BorderSide(color: Colors.white10),
        ),
      ),
      child: ListTile(
        leading: _buildAppIcon(app),
        title: Text(
          app.name,
          style: TextStyle(
            color: isSecure ? const Color(0xFF00D4FF) : Colors.white,
            fontSize: 13,
            fontWeight: isSecure ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Switch(
          value: isSecure,
          activeColor: const Color(0xFF00D4FF),
          inactiveTrackColor: Colors.white10,
          onChanged: (val) => _toggleAppVisibility(app.packageName, val),
        ),
      ),
    );
  }

  Widget _buildAppIcon(AppInfo app) {
    const int cacheSize = 80;
    if (app.iconPath != null) {
      return Image.file(
        File(app.iconPath!),
        width: 32,
        height: 32,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
      );
    } else if (app.iconBytes != null) {
      return Image.memory(
        app.iconBytes!,
        width: 32,
        height: 32,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
      );
    } else {
      return const Icon(Icons.android, color: Colors.white24);
    }
  }
}
