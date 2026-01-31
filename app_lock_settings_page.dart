import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockSettingsPage extends StatefulWidget {
  const AppLockSettingsPage({super.key});

  @override
  State<AppLockSettingsPage> createState() => _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends State<AppLockSettingsPage> {
  final _secureStorage = const FlutterSecureStorage();
  static const _pinKey = 'app_lock_pin';
  static const _lockedAppsKey = 'locked_apps';

  bool _loading = true;
  bool _hasPin = false;
  List<String> _lockedApps = [];
  List<Map<dynamic, dynamic>> _allApps = [];

  static const platform = MethodChannel('com.example.gaminglauncher/apps');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = await _secureStorage.read(key: _pinKey);
    final lockedApps = prefs.getStringList(_lockedAppsKey) ?? [];

    List<Map<dynamic, dynamic>> apps = [];
    try {
      final List<dynamic> result = await platform.invokeMethod('getApps');
      apps = result.cast<Map<dynamic, dynamic>>();
    } on PlatformException catch (e) {
      debugPrint("Error loading apps: ${e.message}");
    }

    if (mounted) {
      setState(() {
        _hasPin = pin != null && pin.isNotEmpty;
        _lockedApps = lockedApps;
        _allApps = apps;
        _loading = false;
      });
    }
  }

  Future<void> _showSetPinDialog() async {
    String? newPin;
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_hasPin ? 'Change PIN' : 'Set PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a 4-digit PIN.'),
            const SizedBox(height: 16),
            Pinput(
              controller: controller,
              length: 4,
              obscureText: true,
              onCompleted: (pin) => newPin = pin,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (newPin != null && newPin!.length == 4) {
                await _secureStorage.write(key: _pinKey, value: newPin);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN has been set.')),
                  );
                  setState(() {
                    _hasPin = true;
                  });
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAppLock(String packageName, bool shouldLock) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (shouldLock) {
        _lockedApps.add(packageName);
      } else {
        _lockedApps.remove(packageName);
      }
    });
    await prefs.setStringList(_lockedAppsKey, _lockedApps);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Lock'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  title: Text(_hasPin ? 'Change PIN' : 'Set PIN'),
                  leading: const Icon(Icons.password),
                  onTap: _showSetPinDialog,
                ),
                if (_hasPin)
                  ListTile(
                    title: const Text('Remove PIN'),
                    leading: const Icon(Icons.lock_reset),
                    onTap: () async {
                      await _secureStorage.delete(key: _pinKey);
                      setState(() {
                        _hasPin = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN removed. App Lock is disabled.')),
                      );
                    },
                  ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Select apps to lock',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!_hasPin)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('You must set a PIN to lock apps.'),
                  )
                else
                  ..._allApps.map((app) {
                    final packageName = app['packageName'] as String;
                    final isLocked = _lockedApps.contains(packageName);
                    final Uint8List? iconBytes = app['icon'];
                    return SwitchListTile(
                      title: Text(app['name']),
                      secondary: iconBytes != null
                          ? Image.memory(iconBytes, width: 40, height: 40)
                          : const Icon(Icons.android),
                      value: isLocked,
                      onChanged: (value) => _toggleAppLock(packageName, value),
                    );
                  }),
              ],
            ),
    );
  }
}