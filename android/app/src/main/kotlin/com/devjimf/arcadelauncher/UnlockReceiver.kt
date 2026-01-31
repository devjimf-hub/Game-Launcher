package com.devjimf.arcadelauncher

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receiver to handle app unlock broadcasts from LockActivity
 */
class UnlockReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "UnlockReceiver"
        const val ACTION_UNLOCK_APP = "com.devjimf.arcadelauncher.UNLOCK_APP"
        const val EXTRA_PACKAGE_NAME = "package_name"

        // Store authorized apps with timestamps
        private val authorizedApps = mutableMapOf<String, Long>()
        private var sessionTimeoutMs = 30000L // Default 30 seconds

        fun setSessionTimeout(timeoutSeconds: Int) {
            sessionTimeoutMs = timeoutSeconds * 1000L
            Log.d(TAG, "Session timeout set to ${timeoutSeconds}s")
        }

        fun getSessionTimeoutMs(): Long = sessionTimeoutMs

        fun isAppAuthorized(packageName: String): Boolean {
            val timestamp = authorizedApps[packageName] ?: return false
            val currentTime = System.currentTimeMillis()

            return if (currentTime - timestamp < sessionTimeoutMs) {
                true
            } else {
                // Session expired
                authorizedApps.remove(packageName)
                false
            }
        }

        fun authorizeApp(packageName: String) {
            authorizedApps[packageName] = System.currentTimeMillis()
            Log.d(TAG, "App authorized: $packageName (timeout: ${sessionTimeoutMs / 1000}s)")
        }

        fun clearAllSessions() {
            if (authorizedApps.isNotEmpty()) {
                Log.d(TAG, "Clearing all authorization sessions")
                authorizedApps.clear()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_UNLOCK_APP) {
            val packageName = intent.getStringExtra(EXTRA_PACKAGE_NAME)
            if (packageName != null) {
                // Load session timeout from preferences
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val timeout = prefs.getInt("flutter.session_timeout", 30)
                setSessionTimeout(timeout)

                authorizeApp(packageName)
            }
        }
    }
}
