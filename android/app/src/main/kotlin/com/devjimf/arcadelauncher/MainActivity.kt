package com.devjimf.arcadelauncher

import android.accessibilityservice.AccessibilityService
import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.text.TextUtils
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import android.content.BroadcastReceiver
import android.content.IntentFilter

/**
 * MainActivity - Flutter host activity with MethodChannel bridges
 *
 * Channels:
 * - com.devjimf.arcadelauncher/apps - App listing, launching, settings
 * - com.devjimf.arcadelauncher/applock - App lock control (Flutter -> Native)
 * - com.devjimf.arcadelauncher/overlay - Overlay service control
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL_APPS = "com.devjimf.arcadelauncher/apps"
        private const val CHANNEL_APP_LOCK = "com.devjimf.arcadelauncher/applock"
        private const val CHANNEL_OVERLAY = "com.devjimf.arcadelauncher/overlay"
        private const val PICK_IMAGE_REQUEST = 1001
    }

    private var appInstallReceiver: BroadcastReceiver? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Set window background to app color to prevent black flash during load
        // This matches the Scaffold background color in main.dart
        window.setBackgroundDrawable(android.graphics.drawable.ColorDrawable(android.graphics.Color.parseColor("#05050A")))

        // Sanitize preferences to prevent Flutter crash
        sanitizePreferences()

        // Initialize LockManager early
        try {
            LockManager.initialize(applicationContext)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize LockManager", e)
        }
    }

    private fun sanitizePreferences() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            val allPrefs = prefs.all
            val listPrefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"

            // List of keys known to be lists in Flutter
            val listKeys = listOf("flutter.locked_apps", "flutter.hidden_apps", "flutter.app_order")

            for (key in listKeys) {
                val value = allPrefs[key]
                if (value is String) {
                    if (!value.startsWith(listPrefix)) {
                        // It's missing the prefix. It might be raw JSON.
                        // If we leave it, LegacySharedPreferencesPlugin might crash trying to deserialize it as an ObjectStream.
                        // We should fix it by adding the prefix if it looks like a JSON array, or clearing it.
                        
                        if (value.trim().startsWith("[")) {
                            // Looks like JSON, prepend prefix
                            editor.putString(key, listPrefix + value)
                            Log.i(TAG, "Fixed missing prefix for preference: $key")
                        } else {
                            // Invalid format, remove to prevent crash
                            editor.remove(key)
                            Log.w(TAG, "Removed corrupted preference: $key")
                        }
                    }
                }
            }
            editor.apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to sanitize preferences", e)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register broadcast receiver for app install/uninstall
        registerAppInstallReceiver(flutterEngine)

        // Setup Apps Channel
        setupAppsChannel(flutterEngine)

        // Setup App Lock Channel (NEW - for Flutter -> Native communication)
        setupAppLockChannel(flutterEngine)

        // Setup Overlay Channel
        setupOverlayChannel(flutterEngine)
    }

    // ============ APPS CHANNEL ============

    private fun setupAppsChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_APPS).setMethodCallHandler { call, result ->
            when (call.method) {
                "getApps" -> {
                    executor.execute {
                        try {
                            val apps = getInstalledApps()
                            mainHandler.post { result.success(apps) }
                        } catch (e: Throwable) {
                            Log.e(TAG, "Error fetching apps", e)
                            mainHandler.post { result.error("FETCH_ERROR", "Failed to load apps: ${e.message}", null) }
                        }
                    }
                }

                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        launchApp(packageName)
                        result.success(null)
                    } else {
                        result.error("INVALID", "Package name is null", null)
                    }
                }

                "changeWallpaper" -> {
                    try {
                        val intent = Intent(Intent.ACTION_PICK)
                        intent.type = "image/*"
                        startActivityForResult(intent, PICK_IMAGE_REQUEST)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Image picker not found", e.message)
                    }
                }

                "getWallpaperPath" -> {
                    val prefs = getSharedPreferences("launcher_prefs", Context.MODE_PRIVATE)
                    result.success(prefs.getString("wallpaper_path", null))
                }

                "openHomeSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open home settings", e.message)
                    }
                }

                "openOverlaySettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName"))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Could not open overlay settings", e.message)
                        }
                    } else {
                        result.success(null)
                    }
                }

                "openDeviceAdminSettings" -> {
                    try {
                        val componentName = ComponentName(this, MyDeviceAdminReceiver::class.java)
                        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
                            putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                "Required to lock the screen in Arcade Mode.")
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open device admin settings", e.message)
                    }
                }

                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open app settings", e.message)
                    }
                }

                "openBatteryOptimizationSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                intent.data = Uri.parse("package:$packageName")
                                startActivity(intent)
                            }
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        // Fallback: If direct request fails (some devices block it), open the list settings
                        try {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            result.success(null)
                        } catch (e2: Exception) {
                            result.error("ERROR", "Could not open battery settings", e.message)
                        }
                    }
                }

                "openAutoStartSettings" -> {
                    openAutoStartSettings()
                    result.success(null)
                }

                "openAccessibilitySettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open accessibility settings", e.message)
                    }
                }

                "checkOverlayPermission" -> {
                    result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else true)
                }

                "checkAccessibilityPermission" -> {
                    result.success(isAccessibilityServiceEnabled(ArcadeAccessibilityService::class.java))
                }

                "checkBatteryOptimizationExempt" -> {
                    result.success(isBatteryOptimizationExempt())
                }

                "isDeviceOwner" -> {
                    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                    result.success(dpm.isDeviceOwnerApp(packageName))
                }

                "startLockTask" -> {
                    try {
                        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val componentName = ComponentName(this, MyDeviceAdminReceiver::class.java)
                        if (dpm.isDeviceOwnerApp(packageName)) {
                            dpm.setLockTaskPackages(componentName, arrayOf(packageName))
                        }
                        startLockTask()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", "Could not start lock task mode", e.message)
                    }
                }

                "stopLockTask" -> {
                    try {
                        stopLockTask()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", "Could not stop lock task mode", e.message)
                    }
                }

                "isInLockTaskMode" -> {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val isLocked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
                    } else {
                        @Suppress("DEPRECATION")
                        am.isInLockTaskMode
                    }
                    result.success(isLocked)
                }

                else -> result.notImplemented()
            }
        }
    }

    // ============ APP LOCK CHANNEL (NEW) ============

    private fun setupAppLockChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_APP_LOCK).setMethodCallHandler { call, result ->
            when (call.method) {
                // Enable/disable locking globally
                "setLockingEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    LockManager.setLockingEnabled(enabled)
                    result.success(null)
                }

                // Check if locking is enabled
                "isLockingEnabled" -> {
                    result.success(LockManager.isLockingEnabled())
                }

                // Update biometric setting
                "setBiometricEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    LockManager.setBiometricEnabled(enabled)
                    result.success(null)
                }

                // Check if biometric is enabled
                "isBiometricEnabled" -> {
                    result.success(LockManager.isBiometricEnabled())
                }

                // Notify native that PIN was updated
                "onPinUpdated" -> {
                    val pin = call.argument<String>("pin")
                    LockManager.updatePin(pin)
                    result.success(null)
                }

                // Reload all settings from SharedPreferences
                "reloadSettings" -> {
                    LockManager.reload()
                    result.success(null)
                }

                // Update locked apps list
                "updateLockedApps" -> {
                    val apps = call.argument<List<String>>("apps") ?: emptyList()
                    LockManager.updateLockedApps(apps)
                    result.success(null)
                }

                // Unlock app temporarily
                "unlockTemporarily" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        LockManager.authorizeApp(packageName)
                    }
                    result.success(null)
                }

                // Clear all authorizations
                "clearAllAuthorizations" -> {
                    LockManager.clearAllAuthorizations()
                    result.success(null)
                }

                // Revoke authorization (placeholder)
                "revokeAuthorization" -> {
                    result.success(null)
                }

                // Set session timeout (placeholder)
                "setSessionTimeout" -> {
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    // ============ OVERLAY CHANNEL ============

    private fun setupOverlayChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_OVERLAY).setMethodCallHandler { call, result ->
            when (call.method) {
                "startOverlayService" -> {
                    startService(Intent(this, OverlayService::class.java))
                    result.success(null)
                }
                "stopOverlayService" -> {
                    stopService(Intent(this, OverlayService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ============ HELPER METHODS ============

    private val appCache = ArrayList<Map<String, Any>>()
    private var isCacheValid = false

    private fun getInstalledApps(): List<Map<String, Any>> {
        if (isCacheValid && appCache.isNotEmpty()) {
            return appCache
        }

        val apps = ArrayList<Map<String, Any>>()
        
        try {
            val pm = packageManager
            val intent = Intent(Intent.ACTION_MAIN, null)
            intent.addCategory(Intent.CATEGORY_LAUNCHER)
            val activities = pm.queryIntentActivities(intent, 0)

            val iconDir = File(cacheDir, "icons_hd")
            if (!iconDir.exists()) iconDir.mkdirs()

            for (resolveInfo in activities) {
                try {
                    val activityInfo = resolveInfo.activityInfo
                    if (activityInfo.packageName == context.packageName) continue

                    val name = resolveInfo.loadLabel(pm).toString()
                    val packageName = activityInfo.packageName

                    val iconFile = File(iconDir, "$packageName.png")
                    if (!iconFile.exists()) {
                        val iconDrawable = resolveInfo.loadIcon(pm)
                        saveIconToFile(iconDrawable, iconFile)
                    }

                    val appMap = HashMap<String, Any>()
                    appMap["name"] = name
                    appMap["packageName"] = packageName
                    appMap["iconPath"] = iconFile.absolutePath
                    apps.add(appMap)
                } catch (e: Throwable) {
                    Log.e(TAG, "Error processing app: ${resolveInfo.activityInfo?.packageName}", e)
                }
            }
            
            synchronized(appCache) {
                appCache.clear()
                appCache.addAll(apps)
                isCacheValid = true
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error querying installed apps", e)
        }
        return apps
    }

    private fun launchApp(packageName: String) {
        // IMPORTANT: Authorize the app via LockManager BEFORE launching
        // This prevents the lock screen from immediately appearing
        LockManager.authorizeApp(packageName)

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launchIntent)
        }
    }

    private fun isBatteryOptimizationExempt(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }

    private fun isAccessibilityServiceEnabled(serviceClass: Class<out AccessibilityService>): Boolean {
        val expectedComponentName = ComponentName(this, serviceClass)
        val enabledServicesSetting = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledComponent = ComponentName.unflattenFromString(componentNameString)
            if (enabledComponent != null && enabledComponent == expectedComponentName) return true
        }
        return false
    }

    private fun saveIconToFile(drawable: Drawable, file: File) {
        try {
            // Increase icon size for HD quality (e.g., 256x256 or higher if source allows)
            val size = 256
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else size
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else size
            
            // Use optimal dimensions ensuring at least HD size
            val finalWidth = width.coerceAtLeast(size)
            val finalHeight = height.coerceAtLeast(size)

            val bitmap = Bitmap.createBitmap(finalWidth, finalHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)

            FileOutputStream(file).use { out ->
                // Compress at max quality
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save icon", e)
        }
    }

    private fun registerAppInstallReceiver(flutterEngine: FlutterEngine) {
        appInstallReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val packageName = intent.data?.schemeSpecificPart ?: return
                val action = when (intent.action) {
                    Intent.ACTION_PACKAGE_ADDED -> {
                        isCacheValid = false
                        "installed"
                    }
                    Intent.ACTION_PACKAGE_REMOVED -> {
                        isCacheValid = false
                        "uninstalled"
                    }
                    Intent.ACTION_PACKAGE_REPLACED -> {
                        isCacheValid = false
                        "updated"
                    }
                    else -> return
                }

                flutterEngine.dartExecutor.binaryMessenger.let { messenger ->
                    MethodChannel(messenger, CHANNEL_APPS).invokeMethod(
                        "appChanged",
                        mapOf("action" to action, "packageName" to packageName)
                    )
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addDataScheme("package")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(appInstallReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(appInstallReceiver, filter)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == PICK_IMAGE_REQUEST && resultCode == RESULT_OK) {
            data?.data?.let { uri ->
                try {
                    val inputStream = contentResolver.openInputStream(uri)
                    val wallpaperFile = File(filesDir, "launcher_wallpaper.jpg")
                    val outputStream = FileOutputStream(wallpaperFile)

                    inputStream?.use { input ->
                        outputStream.use { output ->
                            input.copyTo(output)
                        }
                    }

                    val prefs = getSharedPreferences("launcher_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putString("wallpaper_path", wallpaperFile.absolutePath).apply()

                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, CHANNEL_APPS).invokeMethod("wallpaperChanged", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to save wallpaper", e)
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Reload lock manager settings in case they changed
        LockManager.reload()
    }

    /**
     * Handle new intent when activity is already running (e.g., HOME button pressed)
     * This is critical for proper launcher behavior
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        // If this is a HOME intent, make sure we're brought to front properly
        if (intent.hasCategory(Intent.CATEGORY_HOME)) {
            Log.d(TAG, "HOME button pressed - bringing launcher to front")
        }
    }

    /**
     * Prevent back button from exiting the launcher
     * Launchers should not exit when back is pressed
     */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Do nothing - launchers should not exit on back press
        // The Flutter PopScope also handles this, but this is a safety net
        Log.d(TAG, "Back pressed - ignoring (launcher should not exit)")
    }

    override fun onDestroy() {
        appInstallReceiver?.let {
            unregisterReceiver(it)
            appInstallReceiver = null
        }
        super.onDestroy()
    }

    private fun openAutoStartSettings() {
        try {
            val intent = Intent()
            val manufacturer = Build.MANUFACTURER.lowercase()
            var componentName: ComponentName? = null

            if (manufacturer.contains("xiaomi")) {
                componentName = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
            } else if (manufacturer.contains("oppo")) {
                componentName = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
            } else if (manufacturer.contains("vivo")) {
                componentName = ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
            } else if (manufacturer.contains("letv")) {
                componentName = ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity")
            } else if (manufacturer.contains("honor") || manufacturer.contains("huawei")) {
                componentName = ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
            } else if (manufacturer.contains("asus")) {
                componentName = ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.entry.FunctionActivity")
            }

            if (componentName != null) {
                intent.component = componentName
                val list = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
                if (list.isNotEmpty()) startActivity(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open AutoStart settings", e)
        }
    }
}
