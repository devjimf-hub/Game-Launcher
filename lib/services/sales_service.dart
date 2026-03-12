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
  }

  static Future<List<ChargingSession>> getLogs() async {
    final logsJson = await SafePrefs.getString(PrefKeys.chargingLogs) ?? '[]';
    final List<dynamic> decoded = jsonDecode(logsJson);
    return decoded.map((j) => ChargingSession.fromJson(j)).toList().reversed.toList();
  }

  static Future<double> calculateTotalSales() async {
    final logs = await getLogs();
    final minsPerPeso = await SafePrefs.getInt(PrefKeys.minsPerPeso, 
        defaultValue: PrefKeys.defaultMinsPerPeso);
    
    int totalMinutes = 0;
    for (var log in logs) {
      totalMinutes += log.durationInMinutes;
    }
    
    if (minsPerPeso == 0) return 0.0;
    return totalMinutes / minsPerPeso;
  }
  
  static Future<void> clearLogs() async {
    await SafePrefs.setString(PrefKeys.chargingLogs, '[]');
  }
}
