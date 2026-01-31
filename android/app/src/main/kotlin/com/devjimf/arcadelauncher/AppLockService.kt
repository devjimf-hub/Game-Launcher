package com.devjimf.arcadelauncher

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log

/**
 * NOTE: The app locking feature has been removed. This service is now a stub.
 * It is recommended to remove this file and its declaration from AndroidManifest.xml.
 */
class AppLockService : Service() {

    companion object {
        private const val TAG = "AppLockService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "app_lock_service_channel"
        private const val CHANNEL_NAME = "App Lock Service"

        @Volatile
        private var instance: AppLockService? = null

        fun isRunning(): Boolean = instance != null
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.w(TAG, "AppLockService created, but is disabled.")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.w(TAG, "AppLockService started, but is disabled.")
        stopSelf()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.w(TAG, "AppLockService destroyed.")
        instance = null
        super.onDestroy()
    }
}
