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
    private var systemUiShieldView: FrameLayout? = null
    private lateinit var windowManager: WindowManager
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

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
        removeTouchBlocker()
        removeSystemUiShield()
        OverlayService.isOverlayVisible = false
        android.util.Log.d("ArcadeAccessibility", "Service connected - state reset, blocker removed")
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(blockReceiver)
        removeTouchBlocker()
        removeSystemUiShield()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Kiosk mode: Detect when system UI (notifications/quick settings) is interacted with
        if (event?.packageName == "com.android.systemui") {
             if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                 event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {

                // 1. Show the "Untouchable" shield immediately to block interaction
                showSystemUiShield()

                // 2. Start the "Force-Clamp" loop
                // This spams the dismiss command to simulate a "virtual release"
                startForceClampLoop()
            }
        }
    }

    private val systemUiShieldToken = Any()
    private var isClamping = false
    private val forceClampRunnable = object : Runnable {
        override fun run() {
            if (!isClamping) return
            
            // Forcefully dismiss the shade
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                performGlobalAction(GLOBAL_ACTION_DISMISS_NOTIFICATION_SHADE)
            } else {
                @Suppress("DEPRECATION")
                sendBroadcast(Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS))
            }
            
            // Also perform a "BACK" action which can break touch focus on the shade
            performGlobalAction(GLOBAL_ACTION_BACK)
            
            // Repeat rapidly for a short burst (500ms total) to ensure "Virtual Release"
            mainHandler.postDelayed(this, 100)
        }
    }

    private fun startForceClampLoop() {
        if (isClamping) return
        isClamping = true
        mainHandler.post(forceClampRunnable)
        
        // Stop clamping after 1.5 seconds high-frequency burst
        mainHandler.postDelayed({
            isClamping = false
            removeSystemUiShield()
        }, systemUiShieldToken, 1500)
    }

    private fun showSystemUiShield() {
        if (systemUiShieldView != null) return
        
        android.util.Log.d("ArcadeAccessibility", "Triggering System UI Shield Overlay")
        
        systemUiShieldView = FrameLayout(this).apply {
            setBackgroundColor(Color.argb(1, 0, 0, 0)) // Almost invisible
            setOnTouchListener { _, _ -> true } // Consume all touches
            isFocusable = true
            isClickable = true
        }

        // REMOVED FLAG_NOT_TOUCH_MODAL to be more greedy with touch focus
        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        )
        
        layoutParams.gravity = Gravity.TOP or Gravity.START
        
        try {
            windowManager.addView(systemUiShieldView, layoutParams)
        } catch (e: Exception) {
            android.util.Log.e("ArcadeAccessibility", "Failed to add shield: ${e.message}")
        }
    }

    private fun removeSystemUiShield() {
        systemUiShieldView?.let {
            try {
                windowManager.removeView(it)
                android.util.Log.d("ArcadeAccessibility", "System UI Shield removed")
            } catch (e: Exception) {}
            systemUiShieldView = null
        }
    }

    override fun onInterrupt() {
        removeTouchBlocker()
    }

    private fun addTouchBlocker() {
        if (touchBlockerView != null) return
        
        // Safety: Only block if OverlayService says it's visible AND we are NOT charging
        val overlayVisible = OverlayService.isOverlayVisible
        val charging = ArcadeUtils.isDeviceCharging(this)
        
        android.util.Log.d("ArcadeAccessibility", "addTouchBlocker check: overlayVisible=$overlayVisible, charging=$charging")
        
        if (!overlayVisible || charging) {
            return
        }

        touchBlockerView = FrameLayout(this).apply {
            setBackgroundColor(Color.TRANSPARENT)
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
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            layoutParams.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        
        layoutParams.gravity = Gravity.TOP or Gravity.START
        layoutParams.x = 0
        layoutParams.y = 0
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            touchBlockerView?.systemGestureExclusionRects = listOf(
                android.graphics.Rect(0, 0, 10000, 10000)
            )
        }
        
        try {
            windowManager.addView(touchBlockerView, layoutParams)
            android.util.Log.d("ArcadeAccessibility", "Touch blocker added")
        } catch (e: Exception) {
            android.util.Log.e("ArcadeAccessibility", "Failed to add touch blocker: ${e.message}")
        }
    }

    private fun removeTouchBlocker() {
        touchBlockerView?.let {
            try {
                windowManager.removeView(it)
                android.util.Log.d("ArcadeAccessibility", "Touch blocker removed")
            } catch (e: Exception) {
                android.util.Log.e("ArcadeAccessibility", "Failed to remove touch blocker: ${e.message}")
            }
            touchBlockerView = null
        }
    }

    companion object {
        const val ACTION_BLOCK_TOUCHES = "com.devjimf.arcadelauncher.ACTION_BLOCK_TOUCHES"
        const val ACTION_UNBLOCK_TOUCHES = "com.devjimf.arcadelauncher.ACTION_UNBLOCK_TOUCHES"
    }
}
