import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A wrapper around SharedPreferences that handles corruption gracefully.
/// If corruption is detected, it returns default values instead of crashing.
class SafePrefs {
  static SharedPreferences? _prefs;
  static bool _isCorrupted = false;

  /// Get SharedPreferences instance safely.
  static Future<SharedPreferences?> getInstance() async {
    if (_isCorrupted) {
      return null;
    }

    if (_prefs != null) {
      return _prefs!;
    }

    try {
      _prefs = await SharedPreferences.getInstance();
      return _prefs!;
    } catch (e) {
      debugPrint('SharedPreferences corrupted: $e');
      _isCorrupted = true;
      return null;
    }
  }

  /// Check if preferences are corrupted
  static bool get isCorrupted => _isCorrupted;

  /// Reset corruption flag to retry
  static void resetCorruptionFlag() {
    _isCorrupted = false;
    _prefs = null;
  }

  /// Safely get a string list, returns empty list on error
  static Future<List<String>> getStringList(String key) async {
    try {
      final prefs = await getInstance();
      if (prefs == null) return [];
      return prefs.getStringList(key) ?? [];
    } catch (e) {
      debugPrint('Error reading StringList "$key": $e');
      return [];
    }
  }

  /// Safely set a string list, with error handling
  static Future<bool> setStringList(String key, List<String> value) async {
    try {
      final prefs = await getInstance();
      if (prefs == null) return false;
      return await prefs.setStringList(key, value);
    } catch (e) {
      debugPrint('Error writing StringList "$key": $e');
      // Try to recover by removing the key first
      try {
        final prefs = await getInstance();
        if (prefs == null) return false;
        await prefs.remove(key);
        return await prefs.setStringList(key, value);
      } catch (e2) {
        debugPrint('Failed to recover from StringList write error: $e2');
        return false;
      }
    }
  }

  /// Safely get a string, returns null on error
  static Future<String?> getString(String key) async {
    try {
      final prefs = await getInstance();
      if (prefs == null) return null;
      return prefs.getString(key);
    } catch (e) {
      debugPrint('Error reading String "$key": $e');
      return null;
    }
  }

  /// Safely set a string
  static Future<bool> setString(String key, String value) async {
    try {
      final prefs = await getInstance();
      if (prefs == null) return false;
      return await prefs.setString(key, value);
    } catch (e) {
      debugPrint('Error writing String "$key": $e');
      return false;
    }
  }

  /// Safely get an int, returns default on error
  static Future<int> getInt(String key, {int defaultValue = 0}) async {
    try {
      final prefs = await getInstance();
      if (prefs == null) return defaultValue;
      return prefs.getInt(key) ?? defaultValue;
    } catch (e) {
      debugPrint('Error reading Int "$key": $e');
      return defaultValue;
    }
  }

  /// Safely set an int
  static Future<bool> setInt(String key, int value) async {
    try {
      final prefs = await getInstance();
      if (prefs == null) return false;
      return await prefs.setInt(key, value);
    } catch (e) {
      debugPrint('Error writing Int "$key": $e');
      return false;
    }
  }

  /// Safely get a bool, returns default on error
  static Future<bool> getBool(String key, {bool defaultValue = false}) async {
    try {
      final prefs = await getInstance();
      if (prefs == null) return defaultValue;
      return prefs.getBool(key) ?? defaultValue;
    } catch (e) {
      debugPrint('Error reading Bool "$key": $e');
      return defaultValue;
    }
  }

  /// Safely set a bool
  static Future<bool> setBool(String key, bool value) async {
    try {
      final prefs = await getInstance();
      if (prefs == null) return false;
      return await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Error writing Bool "$key": $e');
      return false;
    }
  }

  /// Safely get a double, returns default on error
  static Future<double> getDouble(String key, {double defaultValue = 0.0}) async {
    try {
      final prefs = await getInstance();
      if (prefs == null) return defaultValue;
      return prefs.getDouble(key) ?? defaultValue;
    } catch (e) {
      debugPrint('Error reading Double "$key": $e');
      return defaultValue;
    }
  }

  /// Safely set a double
  static Future<bool> setDouble(String key, double value) async {
    try {
      final prefs = await getInstance();
      if (prefs == null) return false;
      return await prefs.setDouble(key, value);
    } catch (e) {
      debugPrint('Error writing Double "$key": $e');
      return false;
    }
  }

  /// Safely remove a key
  static Future<bool> remove(String key) async {
    try {
      final prefs = await getInstance();
      if (prefs == null) return false;
      return await prefs.remove(key);
    } catch (e) {
      debugPrint('Error removing key "$key": $e');
      return false;
    }
  }

  /// Clear all preferences (use with caution)
  static Future<bool> clear() async {
    try {
      final prefs = await getInstance();
      if (prefs == null) return false;
      return await prefs.clear();
    } catch (e) {
      debugPrint('Error clearing preferences: $e');
      return false;
    }
  }
}
