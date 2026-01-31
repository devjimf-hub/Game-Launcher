package com.devjimf.arcadelauncher

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BootReceiver - Handles boot completion and service restart requests
 *
 * This receiver starts the AppLockService when:
 * 1. Device boots (BOOT_COMPLETED)
 * 2. App is updated (MY_PACKAGE_REPLACED)
 * 3. Service requests restart (RESTART_SERVICE)
 *
 * Note: The AccessibilityService auto-starts when enabled by the user,
 * but this ensures our foreground service is also running to keep process alive.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
        private const val ACTION_RESTART_SERVICE = "com.devjimf.arcadelauncher.RESTART_SERVICE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "Received broadcast: ${intent.action}")

        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            ACTION_RESTART_SERVICE -> {
                Log.i(TAG, "App lock service is disabled, not starting on boot.")
            }

            Intent.ACTION_LOCKED_BOOT_COMPLETED -> {
                // Direct boot mode - limited functionality
                // We'll start the full service after regular boot
                Log.d(TAG, "Direct boot completed, waiting for full boot")
            }
        }
    }
}
