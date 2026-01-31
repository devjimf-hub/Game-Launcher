import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'safe_prefs.dart';

class AppBackgroundService {
  static const String _backgroundsKey = 'app_backgrounds';
  static final Map<String, String?> _cache = {};

  static Future<String> get _backgroundsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/app_backgrounds');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  static bool _isInitialized = false;

  /// Initialize the cache by loading all background mappings
  static Future<void> init() async {
    if (_isInitialized) return;

    final backgrounds = await SafePrefs.getStringList(_backgroundsKey);

    for (final entry in backgrounds) {
      final parts = entry.split('::');
      if (parts.length == 2) {
        _cache[parts[0]] = parts[1];
      }
    }
    _isInitialized = true;
  }

  /// Get the background image path for a specific app
  static Future<String?> getBackgroundPath(String packageName) async {
    if (!_isInitialized) await init();
    return _cache[packageName];
  }

  /// Synchronous version of getBackgroundPath, assumes init() has been called
  static String? getBackgroundSync(String packageName) {
    return _cache[packageName];
  }

  /// Save a background image for a specific app
  static Future<String> saveBackground(
    String packageName,
    File imageFile,
  ) async {
    final dir = await _backgroundsDir;
    final extension = imageFile.path.split('.').last;
    final newPath = '$dir/${packageName.replaceAll('.', '_')}.$extension';

    // Copy the image to app's private directory
    await imageFile.copy(newPath);

    // Save the mapping
    final backgrounds = await SafePrefs.getStringList(_backgroundsKey);

    // Remove old entry if exists
    backgrounds.removeWhere((entry) => entry.startsWith('$packageName::'));

    // Add new entry
    backgrounds.add('$packageName::$newPath');
    await SafePrefs.setStringList(_backgroundsKey, backgrounds);

    // Update cache
    _cache[packageName] = newPath;

    return newPath;
  }

  /// Remove background image for a specific app
  static Future<void> removeBackground(String packageName) async {
    final backgrounds = await SafePrefs.getStringList(_backgroundsKey);

    // Find and delete the file
    for (final entry in backgrounds) {
      final parts = entry.split('::');
      if (parts.length == 2 && parts[0] == packageName) {
        final file = File(parts[1]);
        if (await file.exists()) {
          await file.delete();
        }
        break;
      }
    }

    // Remove from preferences
    backgrounds.removeWhere((entry) => entry.startsWith('$packageName::'));
    await SafePrefs.setStringList(_backgroundsKey, backgrounds);

    // Update cache
    _cache[packageName] = null;
  }

  /// Get all apps with custom backgrounds
  static Future<Map<String, String>> getAllBackgrounds() async {
    final backgrounds = await SafePrefs.getStringList(_backgroundsKey);
    final result = <String, String>{};

    for (final entry in backgrounds) {
      final parts = entry.split('::');
      if (parts.length == 2) {
        final path = parts[1];
        if (await File(path).exists()) {
          result[parts[0]] = path;
        }
      }
    }

    return result;
  }
}
