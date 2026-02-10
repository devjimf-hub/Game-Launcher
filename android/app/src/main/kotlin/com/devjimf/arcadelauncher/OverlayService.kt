package com.devjimf.arcadelauncher

import android.app.Service
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.CountDownTimer
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.ImageView
import java.lang.reflect.Method
import java.io.File

class OverlayService : Service() {
    companion object {
        var isOverlayVisible: Boolean = false
        private const val TAG = "ArcadeOverlay"
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
    private var isLocking = false
    private var isCreatingOverlay = false

    private val powerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            android.util.Log.d(TAG, "Received broadcast: ${intent.action}")
            when (intent.action) {
                Intent.ACTION_POWER_DISCONNECTED -> showOverlay(forceWake = true)
                Intent.ACTION_POWER_CONNECTED -> removeOverlay()
                Intent.ACTION_SCREEN_OFF -> {
                    isLocking = false
                    removeOverlay()
                }
                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> {
                    updateOverlayState(context)
                }
            }
        }
    }

    override fun onBind(intent: Intent): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isOverlayVisible = false
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        registerReceiver(powerReceiver, IntentFilter().apply {
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        })
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        handler.postDelayed({ updateOverlayState(this) }, 2000)
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(powerReceiver)
        } catch (e: Exception) {}
        removeOverlay()
        handler.removeCallbacksAndMessages(null)
    }

    private fun updateOverlayState(context: Context) {
        if (!ArcadeUtils.isArcadeModeEnabled(context) || isLocking) {
            if (!isLocking) removeOverlay()
            return
        }
        
        if (!ArcadeUtils.isDeviceCharging(context)) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val isScreenOn = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                pm.isInteractive
            } else {
                @Suppress("DEPRECATION")
                pm.isScreenOn
            }

            if (isScreenOn) showOverlay(forceWake = false)
        } else {
            removeOverlay()
        }
    }

    private fun showOverlay(forceWake: Boolean = false) {
        if (isCreatingOverlay || overlayView != null || isLocking) return
        
        isCreatingOverlay = true
        android.util.Log.d(TAG, "showOverlay (forceWake=$forceWake)")

        try {
            val params = createOverlayLayoutParams(forceWake)
            val container = createOverlayContainer()
            val layout = createOverlayContent(container)

            overlayView = container
            windowManager.addView(overlayView, params)
            
            isOverlayVisible = true
            sendBroadcast(Intent(ArcadeAccessibilityService.ACTION_BLOCK_TOUCHES).apply {
                setPackage(packageName)
            })
            
            if (!ArcadeUtils.isAccessibilityServiceEnabled(this)) {
                android.util.Log.w(TAG, "Accessibility service NOT enabled!")
            }

            addStatusBarBlocker()
            startKioskMode()
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to show overlay: ${e.message}")
        } finally {
            isCreatingOverlay = false
        }
    }

    private fun createOverlayLayoutParams(forceWake: Boolean): WindowManager.LayoutParams {
        val layoutParamsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ERROR
        }

        var flags = WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_SECURE or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED

        if (forceWake) flags = flags or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT, layoutParamsType, flags, PixelFormat.TRANSLUCENT
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }

        if (Build.VERSION.SDK_INT >= 31) {
            params.blurBehindRadius = 100
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_DIM_BEHIND
            params.dimAmount = 0.8f
        }
        
        params.gravity = Gravity.TOP or Gravity.START
        return params
    }

    private fun createOverlayContainer(): FrameLayout {
        return FrameLayout(this).apply {
            systemUiVisibility = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
            isClickable = true
            isFocusable = true
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#CC000000"))
                setStroke(12, Color.YELLOW)
            }
            setOnKeyListener { _, _, _ -> true }
            setOnTouchListener { _, _ -> true }
        }
    }

    private fun createOverlayContent(container: FrameLayout): LinearLayout {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val imagePath = prefs.getString("flutter.overlay_image_path", null)
        
        if (imagePath != null && File(imagePath).exists()) {
            addCustomImage(layout, imagePath)
        } else {
            addDefaultText(layout)
        }

        val countdownView = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 20f
            gravity = Gravity.CENTER
            setPadding(0, 20, 0, 0)
        }
        layout.addView(countdownView)
        container.addView(layout)

        val headerName = prefs.getString("flutter.launcher_title", "ARCADE HUB") ?: "ARCADE HUB"
        startCountdown(countdownView, headerName)
        
        return layout
    }

    private fun addCustomImage(layout: LinearLayout, path: String) {
        try {
            val imageView = ImageView(this)
            val file = File(path)
            
            if (path.lowercase().endsWith(".gif") && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val source = android.graphics.ImageDecoder.createSource(file)
                val drawable = android.graphics.ImageDecoder.decodeDrawable(source)
                imageView.setImageDrawable(drawable)
                if (drawable is android.graphics.drawable.AnimatedImageDrawable) drawable.start()
            } else {
                imageView.setImageBitmap(android.graphics.BitmapFactory.decodeFile(path))
            }

            imageView.scaleType = ImageView.ScaleType.FIT_CENTER
            imageView.adjustViewBounds = true
            
            val dm = resources.displayMetrics
            val params = LinearLayout.LayoutParams((dm.widthPixels * 0.6).toInt(), (dm.heightPixels * 0.4).toInt())
            params.gravity = Gravity.CENTER
            imageView.layoutParams = params
            layout.addView(imageView)
            
            layout.addView(View(this).apply {
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 20)
            })
        } catch (e: Exception) {
            addDefaultText(layout)
        }
    }

    private fun addDefaultText(layout: LinearLayout) {
        layout.addView(TextView(this).apply {
            text = "Insert Coin"
            setTextColor(Color.YELLOW)
            textSize = 48f
            gravity = Gravity.CENTER
        })
    }

    private fun startKioskMode() {
        stopKioskMode()
        collapseStatusBar()
        
        overlayView?.setOnSystemUiVisibilityChangeListener { visibility ->
            if (visibility and View.SYSTEM_UI_FLAG_FULLSCREEN == 0) {
                hideSystemUI()
                collapseStatusBar()
            }
        }

        hideSystemUiRunnable = object : Runnable {
            override fun run() {
                if (overlayView != null) {
                    collapseStatusBar()
                    hideSystemUI()
                    // Adaptive loop: if we are locking, stop. If not, continue.
                    if (!isLocking) handler.postDelayed(this, 500)
                }
            }
        }
        handler.post(hideSystemUiRunnable!!)
    }

    private fun stopKioskMode() {
        overlayView?.setOnSystemUiVisibilityChangeListener(null)
        hideSystemUiRunnable?.let { handler.removeCallbacks(it) }
        hideSystemUiRunnable = null
    }

    private fun collapseStatusBar() {
        try {
            @Suppress("WrongConstant")
            val service = getSystemService("statusbar")
            val manager = Class.forName("android.app.StatusBarManager")
            listOf("collapsePanels", "collapse").forEach { methodName ->
                try {
                    manager.getMethod(methodName).invoke(service)
                    return@forEach
                } catch (e: Exception) {}
            }
        } catch (e: Exception) {}

        // Device Owner blocking
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val component = ComponentName(this, MyDeviceAdminReceiver::class.java)
            if (dpm.isAdminActive(component) && dpm.isDeviceOwnerApp(packageName)) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    dpm.setStatusBarDisabled(component, true)
                }
            }
        } catch (e: Exception) {}

        try { sendBroadcast(Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)) } catch (e: Exception) {}
    }

    private fun hideSystemUI() {
        overlayView?.let { view ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                view.windowInsetsController?.run {
                    hide(android.view.WindowInsets.Type.systemBars())
                    systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                }
            } else {
                @Suppress("DEPRECATION")
                view.systemUiVisibility = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
            }
        }
    }

    private fun addStatusBarBlocker() {
        removeStatusBarBlocker()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ERROR
        }

        val sbH = ArcadeUtils.getStatusBarHeight(resources)
        val nbH = ArcadeUtils.getNavigationBarHeight(resources)

        statusBarBlockerTop = createBlockerView()
        statusBarBlockerBottom = createBlockerView()
        statusBarBlockerLeft = createBlockerView()
        statusBarBlockerRight = createBlockerView()

        try {
            windowManager.addView(statusBarBlockerTop, createBlockerParams(type, -1, sbH, Gravity.TOP))
            windowManager.addView(statusBarBlockerBottom, createBlockerParams(type, -1, nbH, Gravity.BOTTOM))
            windowManager.addView(statusBarBlockerLeft, createBlockerParams(type, 100, -1, Gravity.START))
            windowManager.addView(statusBarBlockerRight, createBlockerParams(type, 100, -1, Gravity.END))
        } catch (e: Exception) {}
    }

    private fun createBlockerView(): View = View(this).apply {
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

    private fun createBlockerParams(type: Int, w: Int, h: Int, g: Int): WindowManager.LayoutParams {
        val params = WindowManager.LayoutParams(w, h, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        params.gravity = g
        return params
    }

    private fun removeStatusBarBlocker() {
        listOf(statusBarBlockerTop, statusBarBlockerBottom, statusBarBlockerLeft, statusBarBlockerRight).forEach {
            it?.let { try { windowManager.removeView(it) } catch (e: Exception) {} }
        }
        statusBarBlockerTop = null; statusBarBlockerBottom = null; statusBarBlockerLeft = null; statusBarBlockerRight = null
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        handler.postDelayed({ if (overlayView != null) addStatusBarBlocker() }, 200)
    }

    private fun removeOverlay() {
        isCreatingOverlay = false; isLocking = false; isOverlayVisible = false
        sendBroadcast(Intent(ArcadeAccessibilityService.ACTION_UNBLOCK_TOUCHES).apply { setPackage(packageName) })
        timer?.cancel(); timer = null
        stopKioskMode()
        removeStatusBarBlocker()
        overlayView?.let { try { windowManager.removeView(it) } catch (e: Exception) {}; overlayView = null }
    }

    private fun startCountdown(textView: TextView, headerName: String) {
        timer?.cancel()
        timer = object : CountDownTimer(10000, 1000) {
            override fun onTick(ms: Long) {
                 textView.text = "$headerName will Shutdown in ${ms / 1000}" 
            }

            override fun onFinish() {
                textView.text = "$headerName will Shutdown in 0"
                isLocking = true
                stopKioskMode()

                // Clear FLAG_TURN_SCREEN_ON to prevent immediate wake/conflict
                try {
                    overlayView?.let { v ->
                        val params = v.layoutParams as WindowManager.LayoutParams
                        params.flags = params.flags and WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON.inv()
                        windowManager.updateViewLayout(v, params)
                    }
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "Failed to clear screen on flag: ${e.message}")
                }

                val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                val component = ComponentName(this@OverlayService, MyDeviceAdminReceiver::class.java)
                if (dpm.isAdminActive(component)) {
                    try { 
                        dpm.lockNow() 
                    } catch (e: Exception) { 
                        android.util.Log.e(TAG, "Lock failed: ${e.message}")
                        isLocking = false
                        updateOverlayState(this@OverlayService) 
                    }
                } else {
                    isLocking = false
                    updateOverlayState(this@OverlayService)
                }
            }
        }.start()
    }
}
