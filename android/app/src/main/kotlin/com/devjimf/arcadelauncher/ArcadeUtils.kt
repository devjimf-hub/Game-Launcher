package com.devjimf.arcadelauncher

import android.accessibilityservice.AccessibilityService
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Resources
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import android.util.Log

object ArcadeUtils {
    private const val TAG = "ArcadeUtils"
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_ARCADE_MODE = "flutter.arcade_mode_enabled"

    fun isArcadeModeEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_ARCADE_MODE, false)
    }

    fun isDeviceCharging(context: Context): Boolean {
        return try {
            val batteryStatus: Intent? = IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { iFilter ->
                context.registerReceiver(null, iFilter)
            }
            
            if (batteryStatus == null) {
                Log.d(TAG, "Battery status unknown, defaulting to Charging (Safe)")
                return true 
            }

            val status: Int = batteryStatus.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
            val plugType: Int = batteryStatus.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1)
            
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || 
                             status == BatteryManager.BATTERY_STATUS_FULL ||
                             plugType == BatteryManager.BATTERY_PLUGGED_AC || 
                             plugType == BatteryManager.BATTERY_PLUGGED_USB || 
                             plugType == BatteryManager.BATTERY_PLUGGED_WIRELESS

            Log.d(TAG, "Charging check: status=$status, plugType=$plugType, isCharging=$isCharging")
            isCharging
        } catch (e: Exception) {
            Log.e(TAG, "Error checking battery status", e)
            true // Default to safe
        }
    }

    fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val expectedComponentName = ComponentName(context, ArcadeAccessibilityService::class.java)
        val enabledServicesSetting = Settings.Secure.getString(
            context.contentResolver, 
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        
        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledComponent = ComponentName.unflattenFromString(componentNameString)
            if (enabledComponent != null && enabledComponent == expectedComponentName) return true
        }
        return false
    }

    fun isBatteryOptimizationExempt(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(context.packageName)
        }
        return true
    }

    fun getStatusBarHeight(resources: Resources): Int {
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        val systemHeight = if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else 100
        // Use a larger blocker height for tablets and safety margin
        return maxOf(systemHeight + 50, 150)
    }

    fun getNavigationBarHeight(resources: Resources): Int {
        val resourceId = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        val systemHeight = if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else 150
        return maxOf(systemHeight + 50, 200)
    }

    fun isDeviceOwner(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isDeviceOwnerApp(context.packageName)
    }

    fun isAdminActive(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val componentName = ComponentName(context, MyDeviceAdminReceiver::class.java)
        return dpm.isAdminActive(componentName)
    }
}
