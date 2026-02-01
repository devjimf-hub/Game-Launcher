package com.devjimf.arcadelauncher

import android.app.Service
import android.app.StatusBarManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.BatteryManager
import android.os.Build
import android.os.CountDownTimer
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import java.lang.reflect.Method

class OverlayService : Service() {
    companion object {
        var isOverlayVisible: Boolean = false
    }

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private var statusBarBlockerTop: View? = null
    private var statusBarBlockerLeft: View? = null
    private var statusBarBlockerRight: View? = null
    private var statusBarBlockerBottom: View? = null
    private var timer: CountDownTimer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var hideSystemUiRunnable: Runnable? = null

    private val powerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_POWER_DISCONNECTED) {
                showOverlay()
            } else if (intent.action == Intent.ACTION_POWER_CONNECTED) {
                removeOverlay()
            }
        }
    }

    override fun onBind(intent: Intent): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        // Reset state on service creation
        isOverlayVisible = false
        android.util.Log.d("ArcadeOverlay", "Service created, isOverlayVisible reset to false")
        
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        registerReceiver(powerReceiver, IntentFilter().apply {
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
        })
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Delay initial check by 2 seconds to prevent "Immediate Block" on startup
        handler.postDelayed({
            updateOverlayState(this)
        }, 2000)
        
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(powerReceiver)
        removeOverlay()
    }

    private fun updateOverlayState(context: Context) {
        if (!isArcadeModeEnabled()) {
            removeOverlay()
            return
        }
        
        val isCharging = isDeviceCharging(context)
        if (!isCharging) {
            showOverlay()
        } else {
            removeOverlay()
        }
    }

    private fun isDeviceCharging(context: Context): Boolean {
        val batteryStatus: Intent? = IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { iFilter ->
            context.registerReceiver(null, iFilter)
        }
        
        // If battery status is null, default to true (safe/plugged) to avoid accidental lockout
        if (batteryStatus == null) {
            android.util.Log.d("ArcadeOverlay", "Battery status unknown, defaulting to Charging (Safe)")
            return true 
        }

        val status: Int = batteryStatus.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        val plugType: Int = batteryStatus.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1)
        
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || 
                         status == BatteryManager.BATTERY_STATUS_FULL ||
                         plugType == BatteryManager.BATTERY_PLUGGED_AC || 
                         plugType == BatteryManager.BATTERY_PLUGGED_USB || 
                         plugType == BatteryManager.BATTERY_PLUGGED_WIRELESS

        android.util.Log.d("ArcadeOverlay", "Charging check: status=$status, plugType=$plugType, isCharging=$isCharging")
        return isCharging
    }

    private fun isArcadeModeEnabled(): Boolean {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("flutter.arcade_mode_enabled", false)
    }
    
    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityManager = getSystemService(Context.ACCESSIBILITY_SERVICE) as android.view.accessibility.AccessibilityManager
        val enabledServices = android.provider.Settings.Secure.getString(
            contentResolver,
            android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        val colonSplitter = android.text.TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices ?: "")
        
        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals("$packageName/${ArcadeAccessibilityService::class.java.name}", ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    private fun showOverlay() {
        if (overlayView == null) {
            android.util.Log.d("ArcadeOverlay", "showOverlay called - creating overlay")
            val layoutParamsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ERROR
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                layoutParamsType,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                        WindowManager.LayoutParams.FLAG_FULLSCREEN or
                        WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS or
                        WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS or
                        WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_SECURE or
                        WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT
            )

            // Extend into display cutout areas (notches) on Android P+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }

            if (Build.VERSION.SDK_INT >= 31) {
                params.blurBehindRadius = 100
                params.flags = params.flags or WindowManager.LayoutParams.FLAG_DIM_BEHIND
                params.dimAmount = 0.8f
            }
            params.gravity = Gravity.TOP or Gravity.START
            params.x = 0
            params.y = 0

            val container = FrameLayout(this)
            container.systemUiVisibility = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or View.SYSTEM_UI_FLAG_LOW_PROFILE)

            container.isClickable = true
            container.isFocusable = true
            
            // Create full screen border drawable
            val screenBorder = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#CC000000")) // 80% Black background
                setStroke(12, Color.YELLOW) // Thick yellow border
                cornerRadius = 0f // Sharp corners for full screen
            }
            container.background = screenBorder
            
            container.setOnKeyListener { _, _, _ -> true } // Block hardware keys
            container.setOnTouchListener { _, _ -> true } // Block all touches

            val layout = LinearLayout(this)
            layout.orientation = LinearLayout.VERTICAL
            layout.gravity = Gravity.CENTER

            val textView = TextView(this)
            textView.text = "Insert Coin"
            textView.setTextColor(Color.YELLOW)
            textView.textSize = 48f
            textView.gravity = Gravity.CENTER
            // Removed border from here

            val countdownView = TextView(this)
            countdownView.setTextColor(Color.WHITE)
            countdownView.textSize = 20f
            countdownView.gravity = Gravity.CENTER
            countdownView.setPadding(0, 20, 0, 0)

            layout.addView(textView)
            layout.addView(countdownView)
            container.addView(layout)

            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val headerName = prefs.getString("flutter.launcher_title", "ARCADE HUB") ?: "ARCADE HUB"

            startCountdown(countdownView, headerName)

            overlayView = container
            windowManager.addView(overlayView, params)
            
            // Only set the flag AFTER the overlay is successfully added
            isOverlayVisible = true
            android.util.Log.d("ArcadeOverlay", "Overlay shown and flag set to true")
            
            // NOW send the broadcast to accessibility service
            val blockIntent = Intent(ArcadeAccessibilityService.ACTION_BLOCK_TOUCHES).apply {
                setPackage(packageName) // Make it explicit
            }
            sendBroadcast(blockIntent)
            
            // Check if accessibility service is enabled
            val isAccessibilityEnabled = isAccessibilityServiceEnabled()
            android.util.Log.d("ArcadeOverlay", "Broadcast sent to block touches (explicit), Accessibility enabled: $isAccessibilityEnabled")
            
            if (!isAccessibilityEnabled) {
                android.util.Log.w("ArcadeOverlay", "WARNING: Accessibility service is NOT enabled! System UI blocking will not work.")
            }

            // Add status bar blocker to prevent pull-down in all orientations
            addStatusBarBlocker()

            // Start kiosk mode - continuously hide system UI and collapse status bar
            startKioskMode()
        }
    }

    private fun startKioskMode() {
        stopKioskMode()

        // Collapse status bar immediately
        collapseStatusBar()

        // Use a more efficient approach for keeping the UI hidden
        // Instead of a 500ms loop, we'll use a listener for system UI visibility changes
        overlayView?.setOnSystemUiVisibilityChangeListener { visibility ->
            if (visibility and View.SYSTEM_UI_FLAG_FULLSCREEN == 0) {
                hideSystemUI()
                collapseStatusBar()
            }
        }

        // Aggressive loop to keep status bar collapsed (important for tablets with power buttons in status bar)
        // Run every 200ms to quickly collapse any pulled-down status bar
        hideSystemUiRunnable = object : Runnable {
            override fun run() {
                if (overlayView != null) {
                    collapseStatusBar()
                    hideSystemUI()
                    // Use shorter interval (200ms) for more responsive blocking
                    handler.postDelayed(this, 200)
                }
            }
        }
        handler.post(hideSystemUiRunnable!!)
    }

    private fun stopKioskMode() {
        overlayView?.setOnSystemUiVisibilityChangeListener(null)
        hideSystemUiRunnable?.let {
            handler.removeCallbacks(it)
        }
        hideSystemUiRunnable = null
    }

    private fun collapseStatusBar() {
        // Method 1: Use StatusBarManager via reflection (Standard approach)
        try {
            @Suppress("WrongConstant")
            val statusBarService = getSystemService("statusbar")
            val statusBarManager = Class.forName("android.app.StatusBarManager")
            val collapse: Method = statusBarManager.getMethod("collapsePanels")
            collapse.invoke(statusBarService)
        } catch (e: Exception) {
            // Try alternative method name used by some manufacturers
            try {
                @Suppress("WrongConstant")
                val statusBarService = getSystemService("statusbar")
                val statusBarManager = Class.forName("android.app.StatusBarManager")
                val collapse: Method = statusBarManager.getMethod("collapse")
                collapse.invoke(statusBarService)
            } catch (e2: Exception) {}
        }

        // Method 2: Use EXPAND_STATUS_BAR permission to collapse (works on some devices)
        try {
            val sbm = Class.forName("android.app.StatusBarManager")
            @Suppress("WrongConstant")
            val service = getSystemService("statusbar")
            // Try disable method if available
            try {
                val disable = sbm.getMethod("disable", Int::class.javaPrimitiveType)
                // DISABLE_EXPAND = 0x00010000, DISABLE_NOTIFICATION_ALERTS = 0x00040000
                disable.invoke(service, 0x00010000 or 0x00040000)
            } catch (e: Exception) {}
        } catch (e: Exception) {}

        // Method 3: Device Owner specific blocking (Most robust)
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val componentName = ComponentName(this, MyDeviceAdminReceiver::class.java)
            if (dpm.isAdminActive(componentName) && dpm.isDeviceOwnerApp(packageName)) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    dpm.setStatusBarDisabled(componentName, true)
                    dpm.setKeyguardDisabled(componentName, true)
                }
            }
        } catch (e: Exception) {}

        // Method 4: Send broadcast to collapse (works on some custom ROMs)
        try {
            sendBroadcast(Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS))
        } catch (e: Exception) {}
    }

    private fun hideSystemUI() {
        overlayView?.let { view ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                view.windowInsetsController?.let { controller ->
                    controller.hide(android.view.WindowInsets.Type.systemBars())
                    controller.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                }
            } else {
                @Suppress("DEPRECATION")
                view.systemUiVisibility = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        or View.SYSTEM_UI_FLAG_LOW_PROFILE)
            }
        }
    }

    private fun addStatusBarBlocker() {
        removeStatusBarBlocker()

        val layoutParamsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ERROR
        }

        // Use slightly smaller blockers to reduce GPU overdraw, but keep them effective
        val statusBarH = getStatusBarHeight()
        val navBarH = getNavigationBarHeight()

        // Create blocker for TOP edge
        statusBarBlockerTop = createBlockerView()
        val topParams = createBlockerParams(layoutParamsType, WindowManager.LayoutParams.MATCH_PARENT, statusBarH, Gravity.TOP)
        
        // Create blocker for BOTTOM edge
        statusBarBlockerBottom = createBlockerView()
        val bottomParams = createBlockerParams(layoutParamsType, WindowManager.LayoutParams.MATCH_PARENT, navBarH + 50, Gravity.BOTTOM)

        // Create blocker for LEFT edge (wider to block edge swipe gestures)
        statusBarBlockerLeft = createBlockerView()
        val leftParams = createBlockerParams(layoutParamsType, 150, WindowManager.LayoutParams.MATCH_PARENT, Gravity.START)

        // Create blocker for RIGHT edge (wider to block edge swipe gestures)
        statusBarBlockerRight = createBlockerView()
        val rightParams = createBlockerParams(layoutParamsType, 150, WindowManager.LayoutParams.MATCH_PARENT, Gravity.END)

        try {
            windowManager.addView(statusBarBlockerTop, topParams)
            windowManager.addView(statusBarBlockerBottom, bottomParams)
            windowManager.addView(statusBarBlockerLeft, leftParams)
            windowManager.addView(statusBarBlockerRight, rightParams)
        } catch (e: Exception) {}
    }

    private fun createBlockerView(): View {
        return View(this).apply {
            setBackgroundColor(Color.TRANSPARENT)
            isClickable = true
            isFocusable = true
            setOnTouchListener { _, _ -> true }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                addOnLayoutChangeListener { v, _, _, _, _, _, _, _, _ ->
                    v.systemGestureExclusionRects = listOf(android.graphics.Rect(0, 0, v.width, v.height))
                }
            }
        }
    }

    private fun createBlockerParams(layoutType: Int, width: Int, height: Int, gravity: Int): WindowManager.LayoutParams {
        val params = WindowManager.LayoutParams(
            width, height, layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_SECURE,
            PixelFormat.TRANSLUCENT
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        params.gravity = gravity
        return params
    }

    private fun removeStatusBarBlocker() {
        listOf(statusBarBlockerTop, statusBarBlockerBottom, statusBarBlockerLeft, statusBarBlockerRight).forEach { blocker ->
            blocker?.let {
                try { windowManager.removeView(it) } catch (e: Exception) {}
            }
        }
        statusBarBlockerTop = null
        statusBarBlockerBottom = null
        statusBarBlockerLeft = null
        statusBarBlockerRight = null
    }

    private fun getStatusBarHeight(): Int {
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        val systemHeight = if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else 100
        // Use a larger blocker height for tablets (like Itel) with power buttons in status bar
        // Minimum 150px to ensure we cover any manufacturer-added buttons
        return maxOf(systemHeight + 50, 150)
    }

    private fun getNavigationBarHeight(): Int {
        val resourceId = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        val systemHeight = if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else 150
        // Use a larger blocker for navigation bar area
        return maxOf(systemHeight + 50, 200)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // Delay re-adding blockers slightly to let system UI layout settle
        handler.postDelayed({
            if (overlayView != null) addStatusBarBlocker()
        }, 200)
    }

    private fun removeOverlay() {
        isOverlayVisible = false
        android.util.Log.d("ArcadeOverlay", "removeOverlay called, flag set to false")
        val unblockIntent = Intent(ArcadeAccessibilityService.ACTION_UNBLOCK_TOUCHES).apply {
            setPackage(packageName)
        }
        sendBroadcast(unblockIntent)
        android.util.Log.d("ArcadeOverlay", "Unblock broadcast sent (explicit)")
        timer?.cancel()
        timer = null
        stopKioskMode()
        removeStatusBarBlocker()
        overlayView?.let {
            try {
                windowManager.removeView(it)
            } catch (e: Exception) {}
            overlayView = null
        }
    }

    private fun startCountdown(textView: TextView, headerName: String) {
        timer?.cancel()
        timer = object : CountDownTimer(10000, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                textView.text = "$headerName will Shutdown in ${millisUntilFinished / 1000}"
            }

            override fun onFinish() {
                textView.text = "$headerName will Shutdown in 0"
                val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                val componentName = ComponentName(this@OverlayService, MyDeviceAdminReceiver::class.java)
                android.util.Log.d("ArcadeOverlay", "Countdown finished, attempting to lock device")
                android.util.Log.d("ArcadeOverlay", "Device Admin active: ${dpm.isAdminActive(componentName)}")
                if (dpm.isAdminActive(componentName)) {
                    try {
                        dpm.lockNow()
                        android.util.Log.d("ArcadeOverlay", "lockNow() called successfully")
                    } catch (e: Exception) {
                        android.util.Log.e("ArcadeOverlay", "lockNow() failed: ${e.message}")
                    }
                } else {
                    android.util.Log.w("ArcadeOverlay", "Device Admin not active - cannot lock screen. Please enable Device Admin in Settings.")
                }
            }
        }.start()
    }
}
