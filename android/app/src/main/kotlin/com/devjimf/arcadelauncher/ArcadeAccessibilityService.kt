package com.devjimf.arcadelauncher

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.view.Gravity
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.FrameLayout

class ArcadeAccessibilityService : AccessibilityService() {

    private var touchBlockerView: FrameLayout? = null
    private lateinit var windowManager: WindowManager

    // Broadcast receiver to listen for block/unblock requests
    private val blockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            android.util.Log.d("ArcadeAccessibility", "Received action: ${intent.action}")
            when (intent.action) {
                ACTION_BLOCK_TOUCHES -> addTouchBlocker()
                ACTION_UNBLOCK_TOUCHES -> removeTouchBlocker()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val filter = IntentFilter().apply {
            addAction(ACTION_BLOCK_TOUCHES)
            addAction(ACTION_UNBLOCK_TOUCHES)
        }
        // Register with appropriate flags for Android 13+ if target SDK is high, 
        // but for now simple registration.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
             registerReceiver(blockReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
             registerReceiver(blockReceiver, filter)
        }
        
        android.util.Log.d("ArcadeAccessibility", "Service created - waiting for commands")
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        // CRITICAL: When service is first enabled, ensure we start in a clean state
        // Remove any existing blocker and reset the OverlayService flag
        removeTouchBlocker()
        OverlayService.isOverlayVisible = false
        android.util.Log.d("ArcadeAccessibility", "Service connected - state reset, blocker removed")
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(blockReceiver)
        removeTouchBlocker()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Kiosk mode: Close notification shade and quick settings when they open
        if (event?.packageName == "com.android.systemui" &&
            (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
             event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED)) {

            // Close the system dialogs (notification shade, quick settings, power menu)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                performGlobalAction(GLOBAL_ACTION_DISMISS_NOTIFICATION_SHADE)
            } else {
                @Suppress("DEPRECATION")
                sendBroadcast(Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS))
            }
        }
    }

    override fun onInterrupt() {
        removeTouchBlocker()
    }

    private fun addTouchBlocker() {
        android.util.Log.d("ArcadeAccessibility", "addTouchBlocker called")
        
        if (touchBlockerView != null) {
            android.util.Log.d("ArcadeAccessibility", "Blocker already exists, ignoring")
            return
        }
        
        // Safety: Only block if OverlayService says it's visible AND we are NOT charging
        val overlayVisible = OverlayService.isOverlayVisible
        android.util.Log.d("ArcadeAccessibility", "OverlayService.isOverlayVisible = $overlayVisible")
        
        if (!overlayVisible) {
            android.util.Log.d("ArcadeAccessibility", "Blocking ignored: Overlay not visible")
            return
        }

        val charging = isCurrentlyCharging()
        android.util.Log.d("ArcadeAccessibility", "isCurrentlyCharging() = $charging")
        
        if (charging) {
            android.util.Log.d("ArcadeAccessibility", "Blocking ignored: Device is charging")
            return
        }
        
        android.util.Log.d("ArcadeAccessibility", "All checks passed - ADDING TOUCH BLOCKER")

        touchBlockerView = FrameLayout(this).apply {
            setBackgroundColor(Color.TRANSPARENT)
            
            // Block all touches - no emergency unlock
            setOnTouchListener { _, _ -> true }
            
            isFocusable = true
            isClickable = true
        }

        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR or
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        )
        
        // Extend into display cutout areas on Android P+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            layoutParams.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        
        // Position at top-left and cover entire screen including system bars
        layoutParams.gravity = Gravity.TOP or Gravity.START
        layoutParams.x = 0
        layoutParams.y = 0
        layoutParams.width = WindowManager.LayoutParams.MATCH_PARENT
        layoutParams.height = WindowManager.LayoutParams.MATCH_PARENT
        
        // On Android Q+, exclude system gesture areas to prevent swipe-up/back gestures
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            touchBlockerView?.systemGestureExclusionRects = listOf(
                android.graphics.Rect(0, 0, 10000, 10000) // Exclude entire screen from system gestures
            )
        }
        
        android.util.Log.d("ArcadeAccessibility", "Adding touch blocker with full system UI coverage")
        
        try {
            windowManager.addView(touchBlockerView, layoutParams)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun isCurrentlyCharging(): Boolean {
        val batteryStatus: Intent? = IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { iFilter ->
            registerReceiver(null, iFilter)
        }
        val status: Int = batteryStatus?.getIntExtra(android.os.BatteryManager.EXTRA_STATUS, -1) ?: -1
        val plugType: Int = batteryStatus?.getIntExtra(android.os.BatteryManager.EXTRA_PLUGGED, -1) ?: -1
        
        val isCharging = status == android.os.BatteryManager.BATTERY_STATUS_CHARGING || 
               status == android.os.BatteryManager.BATTERY_STATUS_FULL ||
               plugType == android.os.BatteryManager.BATTERY_PLUGGED_AC || 
               plugType == android.os.BatteryManager.BATTERY_PLUGGED_USB || 
               plugType == android.os.BatteryManager.BATTERY_PLUGGED_WIRELESS
        
        android.util.Log.d("ArcadeAccessibility", "Battery check: status=$status, plugType=$plugType, isCharging=$isCharging")
        return isCharging
    }

    private fun removeTouchBlocker() {
        touchBlockerView?.let {
            try {
                windowManager.removeView(it)
            } catch (e: Exception) {
                e.printStackTrace()
            }
            touchBlockerView = null
        }
    }

    companion object {
        const val ACTION_BLOCK_TOUCHES = "com.devjimf.arcadelauncher.ACTION_BLOCK_TOUCHES"
        const val ACTION_UNBLOCK_TOUCHES = "com.devjimf.arcadelauncher.ACTION_UNBLOCK_TOUCHES"
    }
}
