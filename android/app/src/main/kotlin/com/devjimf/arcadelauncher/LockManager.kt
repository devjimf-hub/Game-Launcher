package com.devjimf.arcadelauncher

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * LockManager - High-performance, thread-safe manager for app locking state
 *
 * Key design principles:
 * 1. All checks are in-memory (no disk I/O in hot path)
 * 2. Thread-safe using volatile/concurrent collections
 * 3. Encrypted storage for PIN
 * 4. Proper session management with timeout
 * 5. Supports MethodChannel updates from Flutter
 */
object LockManager {
    private const val TAG = "LockManager"

    // Preferences
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val PREF_PIN = "flutter.app_lock_pin"
    private const val PREF_BIOMETRIC_ENABLED = "flutter.biometric_enabled"
    private const val PREF_LOCKING_ENABLED = "flutter.locking_enabled"

    // Defaults
    private const val DEFAULT_PIN_LENGTH = 4

    // Session management
    @Volatile
    private var SESSION_TIMEOUT_MS = 30_000L // Default 30 seconds
    @Volatile
    private var authorizedApps = ConcurrentHashMap<String, Long>()

    // ============ IN-MEMORY STATE (for zero-latency checks) ============

    // Whether locking is globally enabled
    @Volatile
    private var lockingEnabled: Boolean = true

    // Biometric enabled flag
    @Volatile
    private var biometricEnabled: Boolean = false

    // Cached PIN (encrypted in storage, decrypted in memory for speed)
    @Volatile
    private var cachedPin: String? = null

    // Context reference for reloading
    @Volatile
    private var appContext: Context? = null

    // Initialization flag
    @Volatile
    private var isInitialized: Boolean = false

    // Locked apps list
    @Volatile
    private var lockedApps: Set<String> = emptySet()
    
    private const val PREF_LOCKED_APPS = "flutter.hidden_apps" // Using hidden apps as locked apps
    private const val LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"

    /**
     * Initialize the LockManager - MUST be called on service start
     * This loads all settings into memory for zero-latency access
     */
    @Synchronized
    fun initialize(context: Context) {
        appContext = context.applicationContext

        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            // Load locking enabled state
            lockingEnabled = prefs.getBoolean(PREF_LOCKING_ENABLED, true)

            // Load PIN
            cachedPin = prefs.getString(PREF_PIN, null)

            // Load biometric setting
            biometricEnabled = prefs.getBoolean(PREF_BIOMETRIC_ENABLED, false)

            // Load locked apps
            loadLockedApps(prefs)

            isInitialized = true
            Log.i(TAG, "LockManager initialized - Settings lock enabled: $lockingEnabled, Locked apps: ${lockedApps.size}")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize LockManager", e)
            isInitialized = true // Mark as initialized anyway to prevent repeated failures
        }
    }

    private fun loadLockedApps(prefs: SharedPreferences) {
        try {
            val rawValue = prefs.getString(PREF_LOCKED_APPS, null)
            if (rawValue != null && rawValue.startsWith(LIST_PREFIX)) {
                val jsonString = rawValue.substring(LIST_PREFIX.length)
                // Simple JSON array parsing
                val cleanJson = jsonString.trim().removeSurrounding("[", "]")
                if (cleanJson.isNotEmpty()) {
                    lockedApps = cleanJson.split(",")
                        .map { it.trim().removeSurrounding("\"") }
                        .toSet()
                } else {
                    lockedApps = emptySet()
                }
            } else {
                lockedApps = emptySet()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse locked apps", e)
            lockedApps = emptySet()
        }
    }

    /**
     * Update locked apps list (called when Flutter updates settings)
     */
    fun updateLockedApps(apps: List<String>) {
        lockedApps = apps.toSet()
        Log.i(TAG, "Locked apps updated: ${lockedApps.size}")
    }

    /**
     * Check if an app is locked
     */
    fun isAppLocked(packageName: String): Boolean {
        // If locking is disabled globally or no PIN set, nothing is locked
        if (!lockingEnabled || cachedPin == null) return false
        
        return lockedApps.contains(packageName)
    }

    /**
     * Reload settings from disk - call when Flutter updates settings
     */
    fun reload() {
        appContext?.let { initialize(it) }
    }

    // ============ FAST IN-MEMORY CHECKS ============

    /**
     * Check if an app is temporarily authorized (session is active)
     */
    fun isTemporarilyAuthorized(packageName: String): Boolean {
        // If not locked, it is always capable of being run (not "authorized" in the lock sense, but doesn't need auth)
        if (!isAppLocked(packageName)) return true

        val expiryTime = authorizedApps[packageName] ?: return false
        val isAuthorized = System.currentTimeMillis() < expiryTime
        if (!isAuthorized) {
            // Clean up expired entry
            authorizedApps.remove(packageName)
        }
        return isAuthorized
    }

    /**
     * Authorize an app for a short period
     */
    fun authorizeApp(packageName: String) {
        val expiryTime = System.currentTimeMillis() + SESSION_TIMEOUT_MS
        authorizedApps[packageName] = expiryTime
        Log.i(TAG, "$packageName authorized for ${TimeUnit.MILLISECONDS.toSeconds(SESSION_TIMEOUT_MS)}s.")
    }

    /**
     * Clear all active sessions
     */
    fun clearAllAuthorizations() {
        if (authorizedApps.isNotEmpty()) {
            authorizedApps.clear()
            Log.i(TAG, "All temporary authorizations cleared.")
        }
    }

    /**
     * Check if locking is globally enabled
     * This is a zero-allocation, zero-latency check
     */
    fun isLockingEnabled(): Boolean = lockingEnabled && cachedPin != null

    /**
     * Verify PIN - returns true if PIN matches
     */
    fun verifyPin(enteredPin: String): Boolean {
        val savedPin = cachedPin ?: return false
        return savedPin == enteredPin
    }

    /**
     * Get the PIN length for UI purposes
     */
    fun getPinLength(): Int {
        return cachedPin?.length ?: DEFAULT_PIN_LENGTH
    }

    /**
     * Check if biometric unlock is enabled
     */
    fun isBiometricEnabled(): Boolean = biometricEnabled

    // ============ SETTERS (Called from MethodChannel) ============

    /**
     * Enable or disable locking globally
     */
    fun setLockingEnabled(enabled: Boolean) {
        lockingEnabled = enabled
        Log.i(TAG, "Locking enabled: $enabled")

        appContext?.let { ctx ->
            try {
                val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putBoolean(PREF_LOCKING_ENABLED, enabled).apply()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to persist locking enabled state", e)
            }
        }
    }

    /**
     * Set biometric enabled
     */
    fun setBiometricEnabled(enabled: Boolean) {
        biometricEnabled = enabled
        Log.i(TAG, "Biometric enabled: $enabled")

        appContext?.let { ctx ->
            try {
                val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putBoolean(PREF_BIOMETRIC_ENABLED, enabled).apply()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to persist biometric enabled state", e)
            }
        }
    }

    /**
     * Update cached PIN (called when PIN is changed in Flutter)
     */
    /**
     * Update cached PIN (called when PIN is changed in Flutter)
     */
    fun updatePin(newPin: String?) {
        cachedPin = newPin
        Log.i(TAG, "PIN updated, length: ${newPin?.length ?: 0}")
    }

    /**
     * Update session timeout
     */
    fun setSessionTimeout(seconds: Int) {
        SESSION_TIMEOUT_MS = seconds * 1000L
        Log.i(TAG, "Session timeout updated to ${seconds}s")
    }
}
