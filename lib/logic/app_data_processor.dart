import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/app_info.dart';

/// A utility class to handle heavy data processing in background isolates
/// to avoid blocking the main UI thread.
class AppDataProcessor {
  /// Parses the App List JSON in a background isolate.
  ///
  /// [jsonStr] - The JSON string representing a list of apps.
  /// Returns a List of [AppInfo].
  static Future<List<AppInfo>> parseAppListJsonBackground(
      String jsonStr) async {
    if (jsonStr.isEmpty) return [];
    return compute(_parseAppListJson, jsonStr);
  }

  /// Encodes the App List to JSON in a background isolate.
  ///
  /// [apps] - The list of apps to encode.
  /// Returns a JSON string.
  static Future<String> encodeAppListJsonBackground(List<AppInfo> apps) async {
    return compute(_encodeAppListJson, apps);
  }

  /// Parses the Recent Apps JSON in a background isolate.
  static Future<List<Map<String, dynamic>>> parseRecentsJsonBackground(
      String jsonStr) async {
    if (jsonStr.isEmpty) return [];
    return compute(_parseRecentsJson, jsonStr);
  }

  // --- Private static methods for compute ---

  static List<AppInfo> _parseAppListJson(String jsonStr) {
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded
          .map((m) => AppInfo.fromMap(m as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error parsing app list JSON: $e');
      return [];
    }
  }

  static String _encodeAppListJson(List<AppInfo> apps) {
    try {
      return jsonEncode(apps.map((a) => a.toMap()).toList());
    } catch (e) {
      debugPrint('Error encoding app list JSON: $e');
      return '[]';
    }
  }

  static List<Map<String, dynamic>> _parseRecentsJson(String jsonStr) {
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
    } catch (e) {
      debugPrint('Error parsing recents JSON: $e');
      return [];
    }
  }
}
