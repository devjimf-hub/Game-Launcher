package com.devjimf.arcadelauncher

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log

/**
 * NOTE: The app locking feature has been removed. This service is now a stub.
 * It is recommended to remove this file and its declaration from AndroidManifest.xml.
 */
class AppMonitorService : Service() {

    companion object {
        private const val TAG = "AppMonitorService"
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        Log.w(TAG, "AppMonitorService created, but is disabled.")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.w(TAG, "AppMonitorService started, but is disabled.")
        stopSelf()
        return START_STICKY
    }

    override fun onDestroy() {
        Log.w(TAG, "AppMonitorService destroyed.")
        super.onDestroy()
    }
}
