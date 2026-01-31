package com.devjimf.arcadelauncher

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent

/**
 * NOTE: The app locking feature has been removed. This service is now a stub.
 * It is recommended to remove this file and its declaration from AndroidManifest.xml.
 */
class AppLockAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AppLockAccSvc"

        @Volatile
        private var instance: AppLockAccessibilityService? = null
        fun isRunning(): Boolean = instance != null
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.w(TAG, "AppLockAccessibilityService created, but is disabled.")
    }

    override fun onServiceConnected() {
        Log.w(TAG, "AppLockAccessibilityService connected, but is disabled.")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // App locking feature is disabled.
    }

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility Service Interrupted")
    }

    override fun onDestroy() {
        instance = null
        Log.w(TAG, "Accessibility Service Destroyed")
        super.onDestroy()
    }
}
