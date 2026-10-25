package com.timetable

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Native Android Foreground Service providing real-time background enforcement ("The Bouncer").
 * - Monitors foreground apps every 1.5 seconds ONLY when screen is interactive.
 * - Auto-pauses on screen off with dynamic BroadcastReceiver (zero battery drain).
 * - Enforces 4 time phases (Morning, Daytime, Night, Sleeping).
 * - Auto-closes apps by firing Home Intent and presenting FocusBlockActivity.
 */
class FocusEnforcementService : Service() {

    companion object {
        const val CHANNEL_ID = "timetable_enforcement_service_channel"
        const val HEADS_UP_CHANNEL_ID = "timetable_heads_up_warning_channel"
        const val NOTIFICATION_ID = 9527
        const val WARNING_NOTIFICATION_ID = 9528

        const val PREFS_NAME = "timetable_enforcement_prefs"
        const val KEY_MASTER_ENABLED = "master_enabled"
        const val KEY_SCHEDULED_RESTRICTION_ENABLED = "scheduled_restriction_enabled"
        const val KEY_DAYTIME_GRACE_ENABLED = "daytime_grace_enabled"
        const val KEY_STRICT_WHITELIST_MODE = "strict_whitelist_mode"
        const val KEY_BROWSER_LOOPHOLE_PROTECTION = "browser_loophole_protection"
        const val KEY_YOUTUBE_STUDY_CHECK = "youtube_study_check"
        const val KEY_GRACE_MINUTES = "grace_minutes"
        const val KEY_COOLDOWN_MINUTES = "cooldown_minutes"
        const val KEY_VIP_PACKAGES = "vip_packages"
        const val KEY_DISTRACTING_PACKAGES = "distracting_packages"
        const val KEY_COOLDOWNS_PREFIX = "cooldown_"
        const val KEY_TODAY_BLOCKS_COUNT = "today_blocks_count"
        const val KEY_LAST_BLOCK_DATE = "last_block_date"

        const val ACTION_UPDATE_CONFIG = "com.timetable.enforcement.UPDATE_CONFIG"
        const val ACTION_STUDY_CONTINUE = "com.timetable.enforcement.STUDY_CONTINUE"

        @Volatile
        var isServiceRunning = false
    }

    enum class Phase {
        MORNING_RESTRICTION,   // 05:00 - 09:00 (Full Restriction)
        DAYTIME_GRACE,         // 09:00 - 20:30 (5m Countdown + Cooldown)
        NIGHT_RESTRICTION,     // 20:30 - 22:15 (Full Restriction)
        SLEEPING_RESTRICTION   // 22:15 - 05:15 (Full Restriction across midnight)
    }

    private val handler = Handler(Looper.getMainLooper())
    private var isScreenInteractive = true
    private var lastKnownForegroundPackage: String? = null

    // Track active daytime session usage
    private var currentTrackingPackage: String? = null
    private var currentSessionSeconds: Int = 0
    private var hasWarnedOneMinuteLeft: Boolean = false

    // Track continuous YouTube duration for study check
    private var continuousYouTubeSeconds: Int = 0

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    isScreenInteractive = false
                    lastKnownForegroundPackage = null
                    currentTrackingPackage = null
                    currentSessionSeconds = 0
                }
                Intent.ACTION_SCREEN_ON,
                Intent.ACTION_USER_PRESENT -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    isScreenInteractive = powerManager?.isInteractive ?: true
                    if (isScreenInteractive) {
                        scheduleNextTick(100) // resume check immediately on unlock
                    }
                }
                ACTION_UPDATE_CONFIG -> {
                    // Update notification and re-evaluate immediately
                    updateNotification()
                }
                ACTION_STUDY_CONTINUE -> {
                    // User confirmed educational study on YouTube: grant 30 mins
                    continuousYouTubeSeconds = 0
                }
            }
        }
    }

    private val checkRunnable = object : Runnable {
        override fun run() {
            if (!isServiceRunning) return

            if (isScreenInteractive) {
                try {
                    enforceFocusRules()
                } catch (e: Exception) {
                    // Keep running safely
                }
            }

            scheduleNextTick(1500L) // 1.5 seconds tick
        }
    }

    private fun scheduleNextTick(delayMs: Long) {
        handler.removeCallbacks(checkRunnable)
        if (isServiceRunning) {
            handler.postDelayed(checkRunnable, delayMs)
        }
    }

    override fun onCreate() {
        super.onCreate()
        isServiceRunning = true

        createNotificationChannels()
        startForegroundServiceNotification()

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(ACTION_UPDATE_CONFIG)
            addAction(ACTION_STUDY_CONTINUE)
        }
        registerReceiver(screenReceiver, filter)

        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        isScreenInteractive = powerManager?.isInteractive ?: true

        scheduleNextTick(1000L)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        updateNotification()
        return START_STICKY
    }

    override fun onDestroy() {
        isServiceRunning = false
        handler.removeCallbacks(checkRunnable)
        try {
            unregisterReceiver(screenReceiver)
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ---------------------------------------------------------------------------------------------
    // Core Enforcement Engine
    // ---------------------------------------------------------------------------------------------

    private fun enforceFocusRules() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val masterEnabled = prefs.getBoolean(KEY_MASTER_ENABLED, true)
        if (!masterEnabled) return

        val currentPhase = getCurrentPhase()
        val isFullRestriction = when (currentPhase) {
            Phase.MORNING_RESTRICTION,
            Phase.NIGHT_RESTRICTION,
            Phase.SLEEPING_RESTRICTION -> true
            Phase.DAYTIME_GRACE -> false
        }

        val fgPackage = detectCurrentForegroundPackage() ?: return
        lastKnownForegroundPackage = fgPackage

        // 1. TimeTable app itself is ALWAYS permitted
        if (fgPackage == packageName || fgPackage == "com.timetable") {
            resetDaytimeSession()
            return
        }

        // 2. Default Home Launcher is ALWAYS permitted
        if (isDefaultLauncher(fgPackage)) {
            resetDaytimeSession()
            return
        }

        // 3. System UI & System Settings are ALWAYS permitted
        if (fgPackage == "com.android.systemui" || fgPackage == "com.android.settings") {
            resetDaytimeSession()
            return
        }

        val vipPackages = getVipPackages(prefs)
        val isVip = isPackageInVipList(fgPackage, vipPackages)

        // 4. Handle YouTube Study Check
        if (fgPackage == "com.google.android.youtube") {
            val studyCheckEnabled = prefs.getBoolean(KEY_YOUTUBE_STUDY_CHECK, true)
            if (studyCheckEnabled) {
                continuousYouTubeSeconds += 2
                if (continuousYouTubeSeconds >= 30 * 60) { // 30 mins
                    continuousYouTubeSeconds = 0
                    launchBlockShield(
                        appName = "YouTube",
                        packageNameStr = fgPackage,
                        reason = "30-Minute Study Check: Are you watching a study lecture or scrolling Shorts?",
                        isStudyCheck = true
                    )
                    return
                }
            }
        } else {
            continuousYouTubeSeconds = 0
        }

        // 5. If app is on the VIP Exception list, allow without restriction
        if (isVip) {
            resetDaytimeSession()
            return
        }

        // 6. Handle Browsers loophole protection
        val isBrowser = isBrowserApp(fgPackage)
        val browserProtection = prefs.getBoolean(KEY_BROWSER_LOOPHOLE_PROTECTION, true)

        val distractingPackages = getDistractingPackages(prefs)
        val isDistracting = distractingPackages.contains(fgPackage) || (isBrowser && browserProtection)

        val appName = getAppLabel(fgPackage)

        // =========================================================================================
        // CASE A: Full Restriction Phases (Morning 5-9 AM, Night 8:30-10:15 PM, Sleeping 10:15 PM-5:15 AM)
        // =========================================================================================
        if (isFullRestriction) {
            val scheduledRestrictionEnabled = prefs.getBoolean(KEY_SCHEDULED_RESTRICTION_ENABLED, true)
            if (scheduledRestrictionEnabled) {
                val strictWhitelistMode = prefs.getBoolean(KEY_STRICT_WHITELIST_MODE, true)
                val shouldBlock = if (strictWhitelistMode) {
                    !isVip // In Strict Whitelist mode, anything not in VIP is blocked
                } else {
                    isDistracting
                }

                if (shouldBlock) {
                    val phaseName = when (currentPhase) {
                        Phase.MORNING_RESTRICTION -> "Morning Restriction (05:00 AM – 09:00 AM)"
                        Phase.NIGHT_RESTRICTION -> "Night Restriction (08:30 PM – 10:15 PM)"
                        Phase.SLEEPING_RESTRICTION -> "Sleeping Restriction (10:15 PM – 05:15 AM)"
                        else -> "Full Restriction Active"
                    }
                    executeForcefulAutoClose(
                        packageNameStr = fgPackage,
                        appName = appName,
                        reason = "$phaseName is active with 0-second grace. Restrictive focus is enforced."
                    )
                    return
                }
            }
        }

        // =========================================================================================
        // CASE B: Daytime Flexible Phase (09:00 AM - 08:30 PM) -> 5-Minute Grace Timer + Cooldown
        // =========================================================================================
        val daytimeGraceEnabled = prefs.getBoolean(KEY_DAYTIME_GRACE_ENABLED, true)
        if (daytimeGraceEnabled && isDistracting) {
            val now = System.currentTimeMillis()
            val cooldownUntil = prefs.getLong(KEY_COOLDOWNS_PREFIX + fgPackage, 0L)

            // Subcase B1: App is currently locked in COOLDOWN
            if (now < cooldownUntil) {
                val timeStr = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(cooldownUntil))
                executeForcefulAutoClose(
                    packageNameStr = fgPackage,
                    appName = appName,
                    reason = "5-Minute Limit Exceeded — Cooldown locked until $timeStr."
                )
                return
            }

            // Subcase B2: App is active in a Daytime session -> track usage
            if (currentTrackingPackage == fgPackage) {
                currentSessionSeconds += 2 // 1.5 - 2s tick
            } else {
                currentTrackingPackage = fgPackage
                currentSessionSeconds = 2
                hasWarnedOneMinuteLeft = false
            }

            val graceMinutes = prefs.getInt(KEY_GRACE_MINUTES, 5)
            val graceSeconds = graceMinutes * 60
            val oneMinuteWarningSec = if (graceSeconds > 60) graceSeconds - 60 else (graceSeconds / 2)

            // Warning at 1 minute left (4 mins elapsed for 5m limit)
            if (currentSessionSeconds >= oneMinuteWarningSec && !hasWarnedOneMinuteLeft && currentSessionSeconds < graceSeconds) {
                hasWarnedOneMinuteLeft = true
                postOneMinuteWarningNotification(appName)
            }

            // Limit Reached -> Kick Out & Lock Cooldown
            if (currentSessionSeconds >= graceSeconds) {
                val cooldownMinutes = prefs.getInt(KEY_COOLDOWN_MINUTES, 60)
                val expiresAt = now + (cooldownMinutes * 60 * 1000L)
                prefs.edit().putLong(KEY_COOLDOWNS_PREFIX + fgPackage, expiresAt).apply()

                resetDaytimeSession()

                val timeStr = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(expiresAt))
                executeForcefulAutoClose(
                    packageNameStr = fgPackage,
                    appName = appName,
                    reason = "$graceMinutes-Minute Limit Reached! $appName is in cooldown until $timeStr."
                )
                return
            }
        } else {
            resetDaytimeSession()
        }
    }

    private fun resetDaytimeSession() {
        currentTrackingPackage = null
        currentSessionSeconds = 0
        hasWarnedOneMinuteLeft = false
    }

    // ---------------------------------------------------------------------------------------------
    // Two-Step Forceful Auto-Close ("The Bouncer")
    // ---------------------------------------------------------------------------------------------

    private fun executeForcefulAutoClose(packageNameStr: String, appName: String, reason: String) {
        // Step 1: Immediately fire Home Intent to kick app out of foreground
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        startActivity(homeIntent)

        // Step 2: Launch Full-Screen Block Shield on top
        launchBlockShield(appName, packageNameStr, reason, isStudyCheck = false)

        // Increment today's block counter
        recordBlockEvent()
    }

    private fun launchBlockShield(appName: String, packageNameStr: String, reason: String, isStudyCheck: Boolean) {
        val shieldIntent = Intent(this, FocusBlockActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION
            putExtra(FocusBlockActivity.EXTRA_BLOCKED_APP_NAME, appName)
            putExtra(FocusBlockActivity.EXTRA_BLOCKED_PACKAGE, packageNameStr)
            putExtra(FocusBlockActivity.EXTRA_BLOCK_REASON, reason)
            putExtra(FocusBlockActivity.EXTRA_IS_STUDY_CHECK, isStudyCheck)
        }
        startActivity(shieldIntent)
    }

    private fun recordBlockEvent() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val lastDate = prefs.getString(KEY_LAST_BLOCK_DATE, "")
        var count = if (lastDate == today) prefs.getInt(KEY_TODAY_BLOCKS_COUNT, 0) else 0
        count++
        prefs.edit()
            .putString(KEY_LAST_BLOCK_DATE, today)
            .putInt(KEY_TODAY_BLOCKS_COUNT, count)
            .apply()
    }

    // ---------------------------------------------------------------------------------------------
    // Foreground App Detection via UsageStatsManager
    // ---------------------------------------------------------------------------------------------

    private fun detectCurrentForegroundPackage(): String? {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return null
        val now = System.currentTimeMillis()
        val events = usageStatsManager.queryEvents(now - 4000, now) ?: return lastKnownForegroundPackage

        val event = UsageEvents.Event()
        var fg: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    fg = event.packageName
                }
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    if (fg == event.packageName) {
                        fg = null
                    }
                }
                UsageEvents.Event.KEYGUARD_SHOWN,
                UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
                    fg = null
                }
            }
        }

        return fg ?: lastKnownForegroundPackage
    }

    // ---------------------------------------------------------------------------------------------
    // Phase & Timing Logic
    // ---------------------------------------------------------------------------------------------

    private fun getCurrentPhase(): Phase {
        val cal = Calendar.getInstance()
        val minuteOfDay = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

        val morningStart = 5 * 60        // 05:00 AM (300)
        val morningEnd = 9 * 60          // 09:00 AM (540)
        val daytimeEnd = 20 * 60 + 30    // 08:30 PM (1230)
        val nightEnd = 22 * 60 + 15      // 10:15 PM (1335)
        val sleepEnd = 5 * 60 + 15       // 05:15 AM (315)

        // Morning: 05:00 - 09:00
        if (minuteOfDay >= morningStart && minuteOfDay < morningEnd) {
            return Phase.MORNING_RESTRICTION
        }

        // Daytime: 09:00 - 20:30
        if (minuteOfDay >= morningEnd && minuteOfDay < daytimeEnd) {
            return Phase.DAYTIME_GRACE
        }

        // Night: 20:30 - 22:15
        if (minuteOfDay >= daytimeEnd && minuteOfDay < nightEnd) {
            return Phase.NIGHT_RESTRICTION
        }

        // Sleeping: 22:15 - 05:15 (crosses midnight)
        return Phase.SLEEPING_RESTRICTION
    }

    // ---------------------------------------------------------------------------------------------
    // Notifications & Channels
    // ---------------------------------------------------------------------------------------------

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

            // Service status ongoing channel
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "TimeTable Restriction Guard Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows active restriction schedule and guard status"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(serviceChannel)

            // Heads-up warning channel for 1 minute remaining
            val warningChannel = NotificationChannel(
                HEADS_UP_CHANNEL_ID,
                "TimeTable Grace Warnings",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Heads-up warning when 1 minute remains on distracting app"
                enableVibration(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(warningChannel)
        }
    }

    private fun startForegroundServiceNotification() {
        val notification = buildOngoingNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        notificationManager.notify(NOTIFICATION_ID, buildOngoingNotification())
    }

    private fun buildOngoingNotification(): Notification {
        val phase = getCurrentPhase()
        val phaseText = when (phase) {
            Phase.MORNING_RESTRICTION -> "Morning Restriction Active (05:00 AM – 09:00 AM)"
            Phase.DAYTIME_GRACE -> "Daytime Guard: 5m limit + 60m cooldown"
            Phase.NIGHT_RESTRICTION -> "Night Restriction Active (08:30 PM – 10:15 PM)"
            Phase.SLEEPING_RESTRICTION -> "Sleeping Restriction Active (10:15 PM – 05:15 AM)"
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val appIcon = applicationInfo.icon.takeIf { it != 0 } ?: android.R.drawable.ic_lock_idle_lock

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(appIcon)
            .setContentTitle("TimeTable Restriction Guard")
            .setContentText(phaseText)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun postOneMinuteWarningNotification(appName: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

        // Vibrate phone briefly
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createOneShot(350, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(350)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            1,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val title = "1 Minute Left on $appName!"
        val text = "Grace period ending soon. Wrap up what you are doing before restriction kicks in."

        val appIcon = applicationInfo.icon.takeIf { it != 0 } ?: android.R.drawable.ic_dialog_alert

        val notif = NotificationCompat.Builder(this, HEADS_UP_CHANNEL_ID)
            .setSmallIcon(appIcon)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(WARNING_NOTIFICATION_ID, notif)
    }

    // ---------------------------------------------------------------------------------------------
    // Helper Checks & Default Sets
    // ---------------------------------------------------------------------------------------------

    private fun isDefaultLauncher(pkg: String): Boolean {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolveInfo = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        val defaultLauncherPkg = resolveInfo?.activityInfo?.packageName
        return defaultLauncherPkg == pkg
    }

    private fun isBrowserApp(pkg: String): Boolean {
        val knownBrowsers = setOf(
            "com.android.chrome",
            "org.mozilla.firefox",
            "com.brave.browser",
            "com.microsoft.emmx",
            "com.sec.android.app.sbrowser",
            "com.opera.browser",
            "com.duckduckgo.mobile.android"
        )
        return knownBrowsers.contains(pkg)
    }

    private fun getAppLabel(pkg: String): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (_: Exception) {
            pkg
        }
    }

    private fun isPackageInVipList(pkg: String, vipSet: Set<String>): Boolean {
        if (vipSet.contains(pkg)) return true

        // Keyword heuristics for standard dialers, clock, emergency, banking
        val lower = pkg.lowercase(Locale.ROOT)
        if (lower.contains("dialer") ||
            lower.contains("incallui") ||
            lower.contains("telecom") ||
            lower.contains("deskclock") ||
            lower.contains("clockpackage") ||
            lower.contains("emergency") ||
            lower.contains("super.money") ||
            lower.contains("supermoney") ||
            lower.contains("bhim") ||
            lower.contains("npci") ||
            lower.contains("upi") ||
            lower.contains("banking")
        ) {
            return true
        }

        return false
    }

    private fun getVipPackages(prefs: android.content.SharedPreferences): Set<String> {
        val customSet = prefs.getStringSet(KEY_VIP_PACKAGES, null)
        if (customSet != null && customSet.isNotEmpty()) {
            return customSet
        }

        // Default out-of-the-box VIP packages
        return setOf(
            packageName,
            "com.timetable",
            // Phone, Calls & SMS
            "com.google.android.dialer",
            "com.android.dialer",
            "com.android.incallui",
            "com.samsung.android.incallui",
            "com.samsung.android.dialer",
            "com.android.emergency",
            "com.google.android.apps.messaging",
            "com.android.mms",
            "com.samsung.android.messaging",
            // Messaging
            "com.whatsapp",
            "com.whatsapp.w4b",
            // Clock & Alarm
            "com.google.android.deskclock",
            "com.android.deskclock",
            "com.sec.android.app.clockpackage",
            "com.oneplus.deskclock",
            "com.coloros.alarmclock",
            "com.miui.clock",
            // Maps & Navigation
            "com.google.android.apps.maps",
            // Study & AI
            "com.google.android.youtube",
            "com.openai.chatgpt",
            "com.google.android.apps.bard",
            "com.google.android.googlequicksearchbox",
            // UPI & Banking
            "money.super.app",
            "in.super.money",
            "com.supermoney.app",
            "com.google.android.apps.nbu.paisa.user",
            "com.phonepe.app",
            "net.one97.paytm",
            "in.org.npci.upiapp",
            "com.dreamplug.androidapp",
            "com.sbi.lotusintouch",
            "com.snapwork.hdfc",
            "com.csam.icici.bank.imobile",
            "com.axis.mobile",
            "com.msf.kbank.mobile"
        )
    }

    private fun getDistractingPackages(prefs: android.content.SharedPreferences): Set<String> {
        val customSet = prefs.getStringSet(KEY_DISTRACTING_PACKAGES, null)
        if (customSet != null && customSet.isNotEmpty()) {
            return customSet
        }

        // Default distracting apps
        return setOf(
            "com.instagram.android",
            "com.instagram.lite",
            "com.facebook.katana",
            "com.facebook.lite",
            "com.twitter.android",
            "com.instagram.barcelona", // Threads
            "com.reddit.frontpage",
            "com.snapchat.android",
            "com.zhiliaoapp.musically" // TikTok
        )
    }
}
