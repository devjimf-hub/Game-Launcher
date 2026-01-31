import 'package:arcade_launcher/constants/pref_keys.dart';
import 'package:arcade_launcher/services/safe_prefs.dart';

/// Immutable settings class that loads all launcher settings in a single batch.
/// This reduces the number of async calls from 5+ to 1.
class LauncherSettings {
  final int gridColumns;
  final bool showAppNames;
  final double iconScale;
  final String launcherTitle;
  final String launchWarning;
  final bool arcadeModeEnabled;

  const LauncherSettings({
    required this.gridColumns,
    required this.showAppNames,
    required this.iconScale,
    required this.launcherTitle,
    required this.launchWarning,
    required this.arcadeModeEnabled,
  });

  /// Default settings instance
  static const LauncherSettings defaults = LauncherSettings(
    gridColumns: PrefKeys.defaultGridColumns,
    showAppNames: PrefKeys.defaultShowAppNames,
    iconScale: PrefKeys.defaultCardIconSize,
    launcherTitle: PrefKeys.defaultLauncherTitle,
    launchWarning: PrefKeys.defaultLaunchWarning,
    arcadeModeEnabled: false,
  );

  /// Load all settings in a single batch operation.
  /// Uses Future.wait to parallelize the SharedPreferences reads.
  static Future<LauncherSettings> load() async {
    final results = await Future.wait([
      SafePrefs.getInt(PrefKeys.gridColumns, defaultValue: PrefKeys.defaultGridColumns),
      SafePrefs.getBool(PrefKeys.showAppNames, defaultValue: PrefKeys.defaultShowAppNames),
      SafePrefs.getDouble(PrefKeys.cardIconSize, defaultValue: PrefKeys.defaultCardIconSize),
      SafePrefs.getString(PrefKeys.launcherTitle),
      SafePrefs.getString(PrefKeys.launchWarningText),
      SafePrefs.getBool(PrefKeys.arcadeModeEnabled),
    ]);

    return LauncherSettings(
      gridColumns: results[0] as int,
      showAppNames: results[1] as bool,
      iconScale: results[2] as double,
      launcherTitle: (results[3] as String?) ?? PrefKeys.defaultLauncherTitle,
      launchWarning: (results[4] as String?) ?? PrefKeys.defaultLaunchWarning,
      arcadeModeEnabled: results[5] as bool,
    );
  }

  /// Create a copy with modified values
  LauncherSettings copyWith({
    int? gridColumns,
    bool? showAppNames,
    double? iconScale,
    String? launcherTitle,
    String? launchWarning,
    bool? arcadeModeEnabled,
  }) {
    return LauncherSettings(
      gridColumns: gridColumns ?? this.gridColumns,
      showAppNames: showAppNames ?? this.showAppNames,
      iconScale: iconScale ?? this.iconScale,
      launcherTitle: launcherTitle ?? this.launcherTitle,
      launchWarning: launchWarning ?? this.launchWarning,
      arcadeModeEnabled: arcadeModeEnabled ?? this.arcadeModeEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LauncherSettings &&
          runtimeType == other.runtimeType &&
          gridColumns == other.gridColumns &&
          showAppNames == other.showAppNames &&
          iconScale == other.iconScale &&
          launcherTitle == other.launcherTitle &&
          launchWarning == other.launchWarning &&
          arcadeModeEnabled == other.arcadeModeEnabled;

  @override
  int get hashCode =>
      gridColumns.hashCode ^
      showAppNames.hashCode ^
      iconScale.hashCode ^
      launcherTitle.hashCode ^
      launchWarning.hashCode ^
      arcadeModeEnabled.hashCode;
}
