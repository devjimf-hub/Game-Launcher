import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';

/// Result class for operations that can fail with user-friendly messages
class ServiceResult<T> {
  final T? data;
  final String? error;
  final bool success;

  ServiceResult.success([this.data])
      : success = true,
        error = null;

  ServiceResult.failure(this.error)
      : success = false,
        data = null;
}

class LauncherService {
  static const MethodChannel _appsChannel = MethodChannel(
    'com.devjimf.arcadelauncher/apps',
  );
  static const MethodChannel _overlayChannel = MethodChannel(
    'com.devjimf.arcadelauncher/overlay',
  );
  // NEW: App Lock channel for Flutter -> Native communication
  static const MethodChannel _appLockChannel = MethodChannel(
    'com.devjimf.arcadelauncher/applock',
  );

  // ============ APP LISTING & LAUNCHING ============

  Future<List<AppInfo>> getApps() async {
    try {
      final List<dynamic>? result = await _appsChannel.invokeMethod('getApps');
      if (result == null) return [];
      return result
          .map((map) => AppInfo.fromMap(map as Map<dynamic, dynamic>))
          .toList();
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to get apps - ${e.code}");
      return [];
    }
  }

  Future<ServiceResult<void>> launchApp(String packageName) async {
    try {
      await _appsChannel.invokeMethod('launchApp', {
        'packageName': packageName,
      });
      return ServiceResult.success();
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to launch app - ${e.code}");
      return ServiceResult.failure(_getAppLaunchErrorMessage(e.code));
    }
  }

  String _getAppLaunchErrorMessage(String? code) {
    switch (code) {
      case 'APP_NOT_FOUND':
        return 'Application not found or has been uninstalled';
      case 'PERMISSION_DENIED':
        return 'Permission denied to launch this application';
      case 'ACTIVITY_NOT_FOUND':
        return 'Unable to start application - no launchable activity';
      default:
        return 'Failed to launch application. Please try again.';
    }
  }

  // ============ WALLPAPER ============

  Future<void> changeWallpaper() async {
    try {
      await _appsChannel.invokeMethod('changeWallpaper');
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to change wallpaper - ${e.code}");
    }
  }

  Future<String?> getWallpaperPath() async {
    try {
      return await _appsChannel.invokeMethod('getWallpaperPath');
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to get wallpaper path - ${e.code}");
      return null;
    }
  }

  // ============ SETTINGS PAGES ============

  Future<void> openHomeSettings() async {
    try {
      await _appsChannel.invokeMethod('openHomeSettings');
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to open home settings - ${e.code}");
    }
  }

  Future<void> openOverlaySettings() async {
    try {
      await _appsChannel.invokeMethod('openOverlaySettings');
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to open overlay settings - ${e.code}");
    }
  }

  Future<void> openDeviceAdminSettings() async {
    try {
      await _appsChannel.invokeMethod('openDeviceAdminSettings');
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to open device admin settings - ${e.code}");
    }
  }

  Future<void> openUsageAccessSettings() async {
    try {
      await _appsChannel.invokeMethod('openUsageAccessSettings');
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to open usage access settings - ${e.code}");
    }
  }

  Future<void> openAppSettings() async {
    try {
      await _appsChannel.invokeMethod('openAppSettings');
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to open app settings - ${e.code}");
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _appsChannel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to open accessibility settings - ${e.code}");
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _appsChannel.invokeMethod('openBatteryOptimizationSettings');
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to open battery optimization settings - ${e.code}");
    }
  }

  Future<void> openAutoStartSettings() async {
    try {
      await _appsChannel.invokeMethod('openAutoStartSettings');
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to open auto start settings - ${e.code}");
    }
  }

  // ============ SERVICES ============

  Future<void> startAppMonitorService() async {
    try {
      await _appsChannel.invokeMethod('startAppMonitorService');
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to start app monitor service - ${e.code}");
    }
  }

  Future<void> stopAppMonitorService() async {
    try {
      await _appsChannel.invokeMethod('stopAppMonitorService');
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to stop app monitor service - ${e.code}");
    }
  }

  Future<void> startOverlayService() async {
    try {
      await _overlayChannel.invokeMethod('startOverlayService');
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to start overlay service - ${e.code}");
    }
  }

  Future<void> stopOverlayService() async {
    try {
      await _overlayChannel.invokeMethod('stopOverlayService');
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to stop overlay service - ${e.code}");
    }
  }

  // ============ LOCK TASK MODE ============

  Future<void> startLockTask() async {
    try {
      await _appsChannel.invokeMethod('startLockTask');
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to start lock task - ${e.code}");
    }
  }

  Future<void> stopLockTask() async {
    try {
      await _appsChannel.invokeMethod('stopLockTask');
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to stop lock task - ${e.code}");
    }
  }

  Future<bool> isInLockTaskMode() async {
    try {
      return await _appsChannel.invokeMethod('isInLockTaskMode') ?? false;
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to check lock task mode - ${e.code}");
      return false;
    }
  }

  Future<bool> isDeviceOwner() async {
    try {
      return await _appsChannel.invokeMethod('isDeviceOwner') ?? false;
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to check device owner - ${e.code}");
      return false;
    }
  }

  // ============ PERMISSION CHECKS ============

  Future<bool> checkUsageStatsPermission() async {
    try {
      return await _appsChannel.invokeMethod('checkUsageStatsPermission') ??
          false;
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to check usage stats permission - ${e.code}");
      return false;
    }
  }

  Future<bool> checkOverlayPermission() async {
    try {
      return await _appsChannel.invokeMethod('checkOverlayPermission') ?? false;
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to check overlay permission - ${e.code}");
      return false;
    }
  }

  Future<bool> checkAccessibilityPermission() async {
    try {
      return await _appsChannel.invokeMethod('checkAccessibilityPermission') ??
          false;
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to check accessibility permission - ${e.code}");
      return false;
    }
  }

  Future<bool> checkBatteryOptimizationExempt() async {
    try {
      return await _appsChannel.invokeMethod('checkBatteryOptimizationExempt') ??
          false;
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to check battery optimization - ${e.code}");
      return false;
    }
  }

  Future<bool> checkDeviceAdminEnabled() async {
    try {
      return await _appsChannel.invokeMethod('checkDeviceAdminEnabled') ?? false;
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to check device admin - ${e.code}");
      return false;
    }
  }

  // ============ APP LOCK METHODS (NEW) ============

  /// Update the list of locked apps in native LockManager
  /// Call this whenever the user changes locked apps in Flutter UI
  Future<void> setLockedApps(List<String> packages) async {
    try {
      await _appLockChannel.invokeMethod('setLockedApps', {
        'packages': packages,
      });
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to set locked apps - ${e.code}");
    }
  }

  /// Get the current list of locked apps from native
  Future<List<String>> getLockedApps() async {
    try {
      final List<dynamic>? result =
          await _appLockChannel.invokeMethod('getLockedApps');
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to get locked apps - ${e.code}");
      return [];
    }
  }

  /// Enable or disable app locking globally
  Future<void> setLockingEnabled(bool enabled) async {
    try {
      await _appLockChannel.invokeMethod('setLockingEnabled', {
        'enabled': enabled,
      });
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to set locking enabled - ${e.code}");
    }
  }

  /// Check if app locking is currently enabled
  Future<bool> isLockingEnabled() async {
    try {
      return await _appLockChannel.invokeMethod('isLockingEnabled') ?? false;
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to check locking enabled - ${e.code}");
      return false;
    }
  }

  /// Temporarily unlock an app (e.g., when launched from our launcher)
  /// This prevents the lock screen from appearing immediately
  Future<void> unlockTemporarily(String packageName, {int? durationMs}) async {
    try {
      await _appLockChannel.invokeMethod('unlockTemporarily', {
        'packageName': packageName,
        if (durationMs != null) 'durationMs': durationMs,
      });
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to unlock temporarily - ${e.code}");
    }
  }

  /// Revoke temporary authorization for an app
  Future<void> revokeAuthorization(String packageName) async {
    try {
      await _appLockChannel.invokeMethod('revokeAuthorization', {
        'packageName': packageName,
      });
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to revoke authorization - ${e.code}");
    }
  }

  /// Clear all temporary authorizations
  Future<void> clearAllAuthorizations() async {
    try {
      await _appLockChannel.invokeMethod('clearAllAuthorizations');
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to clear authorizations - ${e.code}");
    }
  }

  /// Update session timeout (time before requiring PIN again)
  Future<void> setSessionTimeout(int seconds) async {
    try {
      await _appLockChannel.invokeMethod('setSessionTimeout', {
        'seconds': seconds,
      });
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to set session timeout - ${e.code}");
    }
  }

  /// Enable or disable biometric unlock
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _appLockChannel.invokeMethod('setBiometricEnabled', {
        'enabled': enabled,
      });
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to set biometric enabled - ${e.code}");
    }
  }

  /// Check if biometric unlock is enabled
  Future<bool> isBiometricEnabled() async {
    try {
      return await _appLockChannel.invokeMethod('isBiometricEnabled') ?? false;
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to check biometric enabled - ${e.code}");
      return false;
    }
  }

  /// Notify native that PIN was updated
  /// Call this after saving PIN in Flutter
  Future<void> onPinUpdated(String? pin) async {
    try {
      await _appLockChannel.invokeMethod('onPinUpdated', {
        'pin': pin,
      });
    } on PlatformException catch (e) {
      debugPrint("LauncherService: Failed to notify PIN update - ${e.code}");
    }
  }

  /// Reload all settings from SharedPreferences into native LockManager
  /// Call this if settings might have changed externally
  Future<void> reloadLockSettings() async {
    try {
      await _appLockChannel.invokeMethod('reloadSettings');
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to reload lock settings - ${e.code}");
    }
  }

  /// Check if the accessibility service is currently running
  Future<bool> isAccessibilityServiceRunning() async {
    try {
      return await _appLockChannel.invokeMethod('isAccessibilityServiceRunning') ??
          false;
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to check accessibility service - ${e.code}");
      return false;
    }
  }

  /// Check if the foreground service is currently running
  Future<bool> isForegroundServiceRunning() async {
    try {
      return await _appLockChannel.invokeMethod('isForegroundServiceRunning') ??
          false;
    } on PlatformException catch (e) {
      debugPrint(
          "LauncherService: Failed to check foreground service - ${e.code}");
      return false;
    }
  }

  // ============ METHOD CALL HANDLER ============

  void setMethodCallHandler(Future<dynamic> Function(MethodCall) handler) {
    _appsChannel.setMethodCallHandler(handler);
  }
}
