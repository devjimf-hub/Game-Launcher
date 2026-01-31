/// Centralized preference keys to avoid string duplication and typos.
/// All SharedPreferences keys should be defined here.
class PrefKeys {
  PrefKeys._(); // Private constructor to prevent instantiation

  // Onboarding
  static const String onboardingComplete = 'onboarding_complete';

  // Visual Settings
  static const String gridColumns = 'grid_columns';
  static const String showAppNames = 'show_app_names';
  static const String cardIconSize = 'card_icon_size';
  static const String launcherTitle = 'launcher_title';

  // Security
  static const String launchWarningText = 'launch_warning_text';
  static const String arcadeModeEnabled = 'arcade_mode_enabled';
  static const String hiddenApps = 'hidden_apps';
  static const String lockedApps = 'locked_apps';
  static const String sessionTimeout = 'session_timeout';
  static const String biometricEnabled = 'biometric_enabled';

  // App Data
  static const String recentAppsData = 'recent_apps_data';
  static const String appOrder = 'app_order';
  static const String appBackgrounds = 'app_backgrounds';

  // Default Values
  static const int defaultGridColumns = 3;
  static const bool defaultShowAppNames = true;
  static const double defaultCardIconSize = 36.0;
  static const String defaultLauncherTitle = 'GAME LIBRARY';
  static const String defaultLaunchWarning =
      'SECURITY: Do not leave accounts logged in. Always logout after session.';
  static const int defaultSessionTimeout = 30;
}
