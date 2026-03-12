import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import '../constants/pref_keys.dart';
import 'safe_prefs.dart';

class ChargingSession {
  final DateTime startTime;
  DateTime? endTime;
  final bool isCharging;

  ChargingSession({
    required this.startTime,
    this.endTime,
    this.isCharging = true,
  });

  Map<String, dynamic> toJson() => {
        'start': startTime.millisecondsSinceEpoch,
        'end': endTime?.millisecondsSinceEpoch,
      };

  factory ChargingSession.fromJson(Map<String, dynamic> json) => ChargingSession(
        startTime: DateTime.fromMillisecondsSinceEpoch(json['start']),
        endTime: json['end'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['end'])
            : null,
      );

  int get durationInMinutes {
    if (endTime == null) return 0;
    return endTime!.difference(startTime).inMinutes;
  }
}

class SalesService {
  static final Battery _battery = Battery();
  static ChargingSession? _currentSession;

  /// Initialize battery listener
  static void init() {
    _battery.onBatteryStateChanged.listen((BatteryState state) {
      if (state == BatteryState.charging || state == BatteryState.full) {
        _onStartCharging();
      } else {
        _onStopCharging();
      }
    });

    // Check initial state
    _battery.batteryState.then((state) {
      if (state == BatteryState.charging || state == BatteryState.full) {
        _onStartCharging();
      }
    });
  }

  static void _onStartCharging() async {
    final arcadeMode = await SafePrefs.getBool(PrefKeys.arcadeModeEnabled);
    if (!arcadeMode) return;
    
    if (_currentSession != null) return;
    _currentSession = ChargingSession(startTime: DateTime.now());
    debugPrint("SalesService: Started charging at ${_currentSession!.startTime}");
  }

  static Future<void> _onStopCharging() async {
    // We already check if _currentSession is null, which is only set if arcadeMode was true at start
    if (_currentSession == null) return;
    _currentSession!.endTime = DateTime.now();
    
    final duration = _currentSession!.durationInMinutes;
    if (duration >= 1) { // Only log if at least 1 minute
      await _logSession(_currentSession!);
    }
    
    debugPrint("SalesService: Stopped charging. Duration: $duration mins");
    _currentSession = null;
  }

  static Future<void> _logSession(ChargingSession session) async {
    final logsJson = await SafePrefs.getString(PrefKeys.chargingLogs) ?? '[]';
    final List<dynamic> decoded = jsonDecode(logsJson);
    decoded.add(session.toJson());
    
    // Keep only last 100 sessions to save space
    if (decoded.length > 100) {
      decoded.removeAt(0);
    }
    
    await SafePrefs.setString(PrefKeys.chargingLogs, jsonEncode(decoded));
    
    // Invalidate cache
    _cachedLogs = null;
    _lastCacheTime = null;
  }

  static List<ChargingSession>? _cachedLogs;
  static DateTime? _lastCacheTime;

  static Future<List<ChargingSession>> getLogs({bool forceRefresh = false}) async {
    // Return cache if it's fresh (less than 5 seconds old) and not forced
    if (!forceRefresh && _cachedLogs != null && _lastCacheTime != null) {
      final now = DateTime.now();
      if (now.difference(_lastCacheTime!) < const Duration(seconds: 5)) {
        return _cachedLogs!;
      }
    }

    final logsJson = await SafePrefs.getString(PrefKeys.chargingLogs) ?? '[]';
    final List<dynamic> decoded = jsonDecode(logsJson);
    final logs = decoded.map((j) => ChargingSession.fromJson(j)).toList().reversed.toList();
    
    _cachedLogs = logs;
    _lastCacheTime = DateTime.now();
    return logs;
  }

  static Future<double> calculateTotalSales() async {
    final logs = await getLogs();
    final minsPerPeso = await SafePrefs.getInt(PrefKeys.minsPerPeso, 
        defaultValue: PrefKeys.defaultMinsPerPeso);
    
    // Use fold for a slightly more functional and concise sum
    int totalMinutes = logs.fold(0, (sum, log) => sum + log.durationInMinutes);
    
    if (minsPerPeso == 0) return 0.0;
    return totalMinutes / minsPerPeso;
  }
  
  static Future<void> clearLogs() async {
    _cachedLogs = null;
    _lastCacheTime = null;
    await SafePrefs.setString(PrefKeys.chargingLogs, '[]');
  }
}
