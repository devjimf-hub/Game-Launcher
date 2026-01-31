package com.devjimf.arcadelauncher

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.view.animation.Animation
import android.view.animation.TranslateAnimation
import android.widget.Button
import android.widget.FrameLayout
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * LockActivity - Native fullscreen lock screen
 *
 * Critical design requirements:
 * 1. FLAG_SECURE to prevent screenshots/screen recording
 * 2. No animation on launch (instant visual blocking)
 * 3. Fullscreen immersive (no status/nav bars visible)
 * 4. Back button goes home (not to locked app)
 * 5. Native biometric support
 * 6. Touch events NEVER reach underlying app
 */
class LockActivity : Activity() {

    companion object {
        private const val TAG = "LockActivity"
        const val EXTRA_TARGET_PACKAGE = "target_package"
        private const val MAX_ATTEMPTS = 5
        private const val LOCKOUT_DURATION_MS = 30_000L // 30 second lockout after max attempts
    }

    // UI Elements
    private lateinit var rootLayout: FrameLayout
    private lateinit var pinDisplay: TextView
    private lateinit var statusText: TextView

    // State
    private var targetPackage: String? = null
    private var enteredPin = ""
    private var pinLength = 4
    private var attemptCount = 0
    private var isLockedOut = false
    private var lockoutEndTime = 0L

    // Handlers
    private val mainHandler = Handler(Looper.getMainLooper())
    private var biometricCancellationSignal: CancellationSignal? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // CRITICAL: No animation on startup - instant visual blocking
        overridePendingTransition(0, 0)

        // Extract target package
        targetPackage = intent.getStringExtra(EXTRA_TARGET_PACKAGE)
        Log.d(TAG, "LockActivity created for: $targetPackage")

        // If somehow already authorized, finish immediately
        if (targetPackage != null && LockManager.isTemporarilyAuthorized(targetPackage!!)) {
            Log.d(TAG, "Already authorized, finishing")
            finishWithoutAnimation()
            return
        }

        // Get PIN length from LockManager
        pinLength = LockManager.getPinLength()

        // Setup window flags - MUST be before setContentView
        setupWindowFlags()

        // Build UI programmatically (no XML inflation delay)
        buildUI()

        // Start biometric if enabled
        if (LockManager.isBiometricEnabled()) {
            mainHandler.postDelayed({ startBiometricAuth() }, 300)
        }
    }

    private fun setupWindowFlags() {
        // CRITICAL: FLAG_SECURE prevents screenshots and screen recording
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        // Keep screen on while lock is showing
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Show when locked (for device lock screen integration)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }

        // Fullscreen immersive
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
            window.setDecorFitsSystemWindows(false)
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
        }

        // Prevent activity from being moved to background
        window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL)

        // Set status bar and nav bar colors to match background
        window.statusBarColor = Color.parseColor("#1A1A2E")
        window.navigationBarColor = Color.parseColor("#1A1A2E")
    }

    private fun buildUI() {
        // Root layout - solid opaque background to fully hide underlying app
        rootLayout = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#1A1A2E"))
            isClickable = true // Consume all touches
            isFocusable = true
        }

        // Content container
        val contentLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(32), dpToPx(48), dpToPx(32), dpToPx(32))
        }

        // Lock icon
        val lockIcon = TextView(this).apply {
            text = "\uD83D\uDD12" // Lock emoji
            textSize = 48f
            gravity = Gravity.CENTER
        }
        contentLayout.addView(lockIcon)

        // Header
        val header = TextView(this).apply {
            text = "APP LOCKED"
            setTextColor(Color.parseColor("#00D4FF"))
            textSize = 28f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dpToPx(16), 0, dpToPx(8))
            letterSpacing = 0.15f
        }
        contentLayout.addView(header)

        // App name (if we can get it)
        val appNameText = TextView(this).apply {
            text = getAppName(targetPackage)
            setTextColor(Color.parseColor("#888888"))
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dpToPx(24))
        }
        contentLayout.addView(appNameText)

        // Status text (for errors, lockout messages)
        statusText = TextView(this).apply {
            text = "Enter PIN to unlock"
            setTextColor(Color.WHITE)
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dpToPx(16))
        }
        contentLayout.addView(statusText)

        // PIN Display (dots)
        pinDisplay = TextView(this).apply {
            text = ""
            setTextColor(Color.parseColor("#9D4EDD"))
            textSize = 36f
            gravity = Gravity.CENTER
            letterSpacing = 0.5f
            setPadding(0, 0, 0, dpToPx(32))
            minHeight = dpToPx(50)
        }
        contentLayout.addView(pinDisplay)

        // Number pad
        val numberPad = createNumberPad()
        contentLayout.addView(numberPad)

        // Biometric button (if enabled)
        if (LockManager.isBiometricEnabled()) {
            val biometricContainer = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                setPadding(dpToPx(16), dpToPx(24), dpToPx(16), dpToPx(16))
                setOnClickListener { startBiometricAuth() }
            }

            val fingerprintText = TextView(this).apply {
                text = "\uD83D\uDD90" // Hand/fingerprint emoji as fallback
                textSize = 24f
                setTextColor(Color.parseColor("#00D4FF"))
            }
            biometricContainer.addView(fingerprintText)

            val biometricLabel = TextView(this).apply {
                text = "  Use Fingerprint"
                textSize = 14f
                setTextColor(Color.parseColor("#00D4FF"))
            }
            biometricContainer.addView(biometricLabel)

            contentLayout.addView(biometricContainer)
        }

        // Cancel button
        val cancelButton = Button(this).apply {
            text = "CANCEL"
            setBackgroundColor(Color.TRANSPARENT)
            setTextColor(Color.parseColor("#666666"))
            textSize = 14f
            setPadding(0, dpToPx(24), 0, 0)
            setOnClickListener { goHome() }
        }
        contentLayout.addView(cancelButton)

        // Center content in root
        val contentParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER
        )
        rootLayout.addView(contentLayout, contentParams)

        setContentView(rootLayout)
    }

    private fun createNumberPad(): GridLayout {
        val grid = GridLayout(this).apply {
            columnCount = 3
            rowCount = 4
            alignmentMode = GridLayout.ALIGN_BOUNDS
        }

        // Numbers 1-9
        for (i in 1..9) {
            grid.addView(createNumberButton(i.toString()))
        }

        // Clear button
        grid.addView(createActionButton("C") {
            if (!isLockedOut) {
                enteredPin = ""
                updatePinDisplay()
            }
        })

        // Number 0
        grid.addView(createNumberButton("0"))

        // Backspace button
        grid.addView(createActionButton("⌫") {
            if (!isLockedOut && enteredPin.isNotEmpty()) {
                enteredPin = enteredPin.dropLast(1)
                updatePinDisplay()
            }
        })

        return grid
    }

    private fun createNumberButton(num: String): Button {
        return Button(this).apply {
            text = num
            setTextColor(Color.WHITE)
            textSize = 28f
            background = createButtonDrawable()

            val params = GridLayout.LayoutParams().apply {
                width = dpToPx(80)
                height = dpToPx(80)
                setMargins(dpToPx(8), dpToPx(8), dpToPx(8), dpToPx(8))
            }
            layoutParams = params

            setOnClickListener {
                if (isLockedOut) {
                    checkLockoutStatus()
                    return@setOnClickListener
                }

                if (enteredPin.length < pinLength) {
                    enteredPin += num
                    updatePinDisplay()
                    vibrateLight()

                    if (enteredPin.length == pinLength) {
                        checkPin()
                    }
                }
            }
        }
    }

    private fun createActionButton(label: String, action: () -> Unit): Button {
        return Button(this).apply {
            text = label
            setTextColor(Color.parseColor("#888888"))
            textSize = 22f
            background = createButtonDrawable()

            val params = GridLayout.LayoutParams().apply {
                width = dpToPx(80)
                height = dpToPx(80)
                setMargins(dpToPx(8), dpToPx(8), dpToPx(8), dpToPx(8))
            }
            layoutParams = params

            setOnClickListener { action() }
        }
    }

    private fun createButtonDrawable(): GradientDrawable {
        return GradientDrawable().apply {
            setColor(Color.parseColor("#252540"))
            setStroke(2, Color.parseColor("#00D4FF"))
            cornerRadius = dpToPx(12).toFloat()
        }
    }

    private fun updatePinDisplay() {
        pinDisplay.text = "●".repeat(enteredPin.length)
        pinDisplay.setTextColor(Color.parseColor("#9D4EDD"))
    }

    private fun checkPin() {
        if (LockManager.verifyPin(enteredPin)) {
            onUnlockSuccess()
        } else {
            onUnlockFailed()
        }
    }

    private fun onUnlockSuccess() {
        Log.i(TAG, "Unlock successful for: $targetPackage")

        // Authorize the app
        targetPackage?.let { pkg ->
            LockManager.authorizeApp(pkg)
            // AppLockAccessibilityService.getInstance()?.onAppUnlocked(pkg) // TODO: Re-enable if using Accessibility Service
        }

        // Success feedback
        vibrateSuccess()
        pinDisplay.setTextColor(Color.parseColor("#00FF00"))
        statusText.text = "UNLOCKED"
        statusText.setTextColor(Color.parseColor("#00FF00"))

        // Finish after brief delay so user sees success
        mainHandler.postDelayed({
            finishWithoutAnimation()
        }, 150)
    }

    private fun onUnlockFailed() {
        attemptCount++
        Log.w(TAG, "Unlock failed, attempt $attemptCount of $MAX_ATTEMPTS")

        // Clear PIN
        enteredPin = ""

        // Error feedback
        vibrateError()
        showError("Wrong PIN")

        // Shake animation
        val shake = TranslateAnimation(0f, 20f, 0f, 0f).apply {
            duration = 50
            repeatCount = 5
            repeatMode = Animation.REVERSE
        }
        pinDisplay.startAnimation(shake)

        // Check for lockout
        if (attemptCount >= MAX_ATTEMPTS) {
            startLockout()
        }
    }

    private fun showError(message: String) {
        statusText.text = message
        statusText.setTextColor(Color.parseColor("#FF4444"))

        mainHandler.postDelayed({
            if (!isFinishing) {
                statusText.text = "Enter PIN to unlock"
                statusText.setTextColor(Color.WHITE)
                updatePinDisplay()
            }
        }, 1500)
    }

    private fun startLockout() {
        isLockedOut = true
        lockoutEndTime = System.currentTimeMillis() + LOCKOUT_DURATION_MS

        updateLockoutUI()

        // Schedule lockout end
        mainHandler.postDelayed({
            endLockout()
        }, LOCKOUT_DURATION_MS)
    }

    private fun updateLockoutUI() {
        val remainingSeconds = ((lockoutEndTime - System.currentTimeMillis()) / 1000).coerceAtLeast(0)
        statusText.text = "Too many attempts. Try again in ${remainingSeconds}s"
        statusText.setTextColor(Color.parseColor("#FF4444"))
        pinDisplay.text = ""

        if (isLockedOut && remainingSeconds > 0) {
            mainHandler.postDelayed({ updateLockoutUI() }, 1000)
        }
    }

    private fun checkLockoutStatus() {
        if (System.currentTimeMillis() >= lockoutEndTime) {
            endLockout()
        }
    }

    private fun endLockout() {
        isLockedOut = false
        attemptCount = 0
        statusText.text = "Enter PIN to unlock"
        statusText.setTextColor(Color.WHITE)
    }

    // ============ BIOMETRIC AUTHENTICATION ============

    private fun startBiometricAuth() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            // Biometric API not available
            return
        }

        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (!keyguardManager.isDeviceSecure) {
            Log.w(TAG, "Device not secure, skipping biometric")
            return
        }

        try {
            biometricCancellationSignal = CancellationSignal()

            val callback = object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult?) {
                    super.onAuthenticationSucceeded(result)
                    Log.i(TAG, "Biometric authentication succeeded")
                    mainHandler.post { onUnlockSuccess() }
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    Log.w(TAG, "Biometric authentication failed")
                    mainHandler.post {
                        statusText.text = "Biometric not recognized"
                        statusText.setTextColor(Color.parseColor("#FF4444"))
                        vibrateError()
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence?) {
                    super.onAuthenticationError(errorCode, errString)
                    Log.w(TAG, "Biometric error: $errorCode - $errString")
                    // Don't show error for user cancellation
                    if (errorCode != BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED &&
                        errorCode != BiometricPrompt.BIOMETRIC_ERROR_CANCELED) {
                        mainHandler.post {
                            statusText.text = errString?.toString() ?: "Biometric error"
                            statusText.setTextColor(Color.parseColor("#FFAA00"))
                        }
                    }
                }
            }

            val promptInfo = BiometricPrompt.Builder(this)
                .setTitle("Unlock App")
                .setSubtitle(getAppName(targetPackage))
                .setDescription("Use your fingerprint to unlock")
                .setNegativeButton("Use PIN", mainExecutor) { _, _ ->
                    // User chose to use PIN instead
                    statusText.text = "Enter PIN to unlock"
                    statusText.setTextColor(Color.WHITE)
                }
                .build()

            promptInfo.authenticate(
                biometricCancellationSignal!!,
                mainExecutor,
                callback
            )

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start biometric auth", e)
        }
    }

    // ============ NAVIGATION ============

    private fun goHome() {
        Log.d(TAG, "Going home, returning to launcher")

        // Return to our launcher's MainActivity instead of system home
        // This prevents the user from being sent to another launcher
        val launcherIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(launcherIntent)
        finishWithoutAnimation()
    }

    private fun finishWithoutAnimation() {
        finish()
        overridePendingTransition(0, 0)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // NEVER go back to the locked app
        goHome()
    }

    override fun onPause() {
        super.onPause()
        // Cancel biometric if showing
        biometricCancellationSignal?.cancel()
    }

    override fun onDestroy() {
        biometricCancellationSignal?.cancel()
        mainHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        // Handle being relaunched for a different package
        val newTarget = intent?.getStringExtra(EXTRA_TARGET_PACKAGE)
        if (newTarget != null && newTarget != targetPackage) {
            Log.d(TAG, "New target package: $newTarget")
            targetPackage = newTarget
            enteredPin = ""
            updatePinDisplay()
            statusText.text = "Enter PIN to unlock"
            statusText.setTextColor(Color.WHITE)
        }
    }

    // ============ UTILITIES ============

    private fun getAppName(packageName: String?): String {
        if (packageName == null) return "App"
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName.substringAfterLast('.')
        }
    }

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()
    }

    private fun vibrateLight() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(20, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(20)
            }
        } catch (e: Exception) {
            // Vibration not available
        }
    }

    private fun vibrateSuccess() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(50)
            }
        } catch (e: Exception) {
            // Vibration not available
        }
    }

    private fun vibrateError() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val pattern = longArrayOf(0, 100, 50, 100)
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(longArrayOf(0, 100, 50, 100), -1)
            }
        } catch (e: Exception) {
            // Vibration not available
        }
    }
}
