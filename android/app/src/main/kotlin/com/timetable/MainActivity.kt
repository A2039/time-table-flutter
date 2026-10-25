package com.timetable

import android.Manifest
import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val FOCUS_CHANNEL = "com.timetable.app/focus_mode"
    private val NOTIFICATION_CHANNEL_ID = "timetable_focus_channel"
    private val NOTIFICATION_ID_DISTRACTION = 8001
    private val NOTIFICATION_ID_TEST = 8002
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 9001

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ensure notification channel is initialized early
        createNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOCUS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // 1. Permission checks & settings
                "isUsagePermissionGranted" -> {
                    result.success(isUsageAccessGranted())
                }
                "testUsageQuery" -> {
                    result.success(testUsageQuery())
                }
                "checkNotificationPermission" -> {
                    result.success(checkNotificationStatus())
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission(result)
                }
                "isOverlayPermissionGranted" -> {
                    result.success(isOverlayPermissionGranted())
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(true)
                }
                "openUsageSettings" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "openNotificationSettings" -> {
                    openNotificationSettings(result)
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                // 2. Real Usage Detection & Installed Apps
                "queryDistractingUsage" -> {
                    val sinceEpochMs = (call.argument<Number>("sinceEpochMs"))?.toLong() ?: 0L
                    val distractingList = call.argument<List<String>>("distractingPackages") ?: emptyList()
                    val allowlist = call.argument<List<String>>("allowlistPackages") ?: emptyList()
                    result.success(queryDistractingUsage(sinceEpochMs, distractingList, allowlist))
                }
                "getInstalledApps" -> {
                    result.success(getInstalledApps())
                }

                // 3. Native Background Enforcement Service ("The Bouncer")
                "isEnforcementServiceRunning" -> {
                    result.success(FocusEnforcementService.isServiceRunning)
                }
                "startEnforcementService" -> {
                    startEnforcementService()
                    result.success(true)
                }
                "stopEnforcementService" -> {
                    stopEnforcementService()
                    result.success(true)
                }
                "syncEnforcementConfig" -> {
                    @Suppress("UNCHECKED_CAST")
                    val config = call.arguments as? Map<String, Any?> ?: emptyMap()
                    syncEnforcementConfig(config)
                    result.success(true)
                }
                "getEnforcementLiveState" -> {
                    result.success(getEnforcementLiveState())
                }
                "showTestBlockShield" -> {
                    val appName = call.argument<String>("appName") ?: "Instagram"
                    val pkg = call.argument<String>("packageName") ?: "com.instagram.android"
                    val reason = call.argument<String>("reason") ?: "Demonstration Mode — 5-Minute Grace Limit Exceeded"
                    showTestBlockShield(appName, pkg, reason)
                    result.success(true)
                }

                // 4. Notification Posting
                "postDistractionNotification" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    val appName = call.argument<String>("appName") ?: pkg
                    val usedMin = (call.argument<Number>("usedMinutes"))?.toInt() ?: 5
                    val graceMin = (call.argument<Number>("graceMinutes"))?.toInt() ?: 5
                    result.success(postDistractionNotification(pkg, appName, usedMin, graceMin))
                }
                "postTestNotification" -> {
                    result.success(postTestNotification())
                }
                "cancelDistractionNotifications" -> {
                    cancelDistractionNotifications()
                    result.success(true)
                }

                // 5. System Diagnostics
                "getSystemDiagnostics" -> {
                    result.success(getSystemDiagnostics())
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Usage Access & UsageStatsManager Query
    // ---------------------------------------------------------------------------------------------

    private fun isUsageAccessGranted(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    private fun testUsageQuery(): Boolean {
        return try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return false
            val now = System.currentTimeMillis()
            val events = usageStatsManager.queryEvents(now - 15 * 60 * 1000, now)
            events != null && events.hasNextEvent()
        } catch (e: Exception) {
            false
        }
    }

    private fun queryDistractingUsage(
        sinceEpochMs: Long,
        distractingPackages: List<String>,
        allowlistPackages: List<String>
    ): Map<String, Any?> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return mapOf("querySuccessful" to false, "packageDurations" to emptyMap<String, Long>())

        val now = System.currentTimeMillis()
        val startTime = if (sinceEpochMs > 0 && sinceEpochMs < now) sinceEpochMs else (now - 24 * 60 * 60 * 1000)

        val distractingSet = distractingPackages.toSet()
        val allowlistSet = allowlistPackages.toSet()

        return try {
            val usageEvents = usageStatsManager.queryEvents(startTime, now)
            val event = UsageEvents.Event()

            var currentForegroundPackage: String? = null
            var currentForegroundStartTime: Long = 0
            val durations = mutableMapOf<String, Long>() // accumulated in seconds
            var lastEventTimestamp: Long = 0

            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                val pkg = event.packageName ?: continue
                val time = event.timeStamp
                if (time > lastEventTimestamp) {
                    lastEventTimestamp = time
                }

                when (event.eventType) {
                    UsageEvents.Event.ACTIVITY_RESUMED,
                    UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                        // Accumulate time for previously active distracting app
                        if (currentForegroundPackage != null && currentForegroundStartTime > 0 && time > currentForegroundStartTime) {
                            val durationSec = (time - currentForegroundStartTime) / 1000
                            durations[currentForegroundPackage!!] = (durations[currentForegroundPackage!!] ?: 0L) + durationSec
                        }

                        // Determine if the newly resumed app is a tracked distracting app
                        if (distractingSet.contains(pkg) && !allowlistSet.contains(pkg)) {
                            currentForegroundPackage = pkg
                            currentForegroundStartTime = time
                        } else {
                            currentForegroundPackage = null
                            currentForegroundStartTime = 0
                        }
                    }

                    UsageEvents.Event.ACTIVITY_PAUSED,
                    UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                        if (currentForegroundPackage == pkg && currentForegroundStartTime > 0 && time > currentForegroundStartTime) {
                            val durationSec = (time - currentForegroundStartTime) / 1000
                            durations[pkg] = (durations[pkg] ?: 0L) + durationSec
                            currentForegroundPackage = null
                            currentForegroundStartTime = 0
                        }
                    }

                    UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                    UsageEvents.Event.KEYGUARD_SHOWN -> {
                        // Device locked or screen turned off: stop accumulating time
                        if (currentForegroundPackage != null && currentForegroundStartTime > 0 && time > currentForegroundStartTime) {
                            val durationSec = (time - currentForegroundStartTime) / 1000
                            durations[currentForegroundPackage!!] = (durations[currentForegroundPackage!!] ?: 0L) + durationSec
                        }
                        currentForegroundPackage = null
                        currentForegroundStartTime = 0
                    }
                }
            }

            // Close open interval if currently in a distracting app right now
            if (currentForegroundPackage != null && currentForegroundStartTime > 0 && now > currentForegroundStartTime) {
                val durationSec = (now - currentForegroundStartTime) / 1000
                durations[currentForegroundPackage!!] = (durations[currentForegroundPackage!!] ?: 0L) + durationSec
            }

            mapOf(
                "querySuccessful" to true,
                "activePackage" to currentForegroundPackage,
                "packageDurations" to durations,
                "lastEventTimestamp" to lastEventTimestamp
            )
        } catch (e: Exception) {
            mapOf(
                "querySuccessful" to false,
                "error" to (e.message ?: "Failed querying usage events"),
                "packageDurations" to emptyMap<String, Long>()
            )
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Notifications & NotificationChannel
    // ---------------------------------------------------------------------------------------------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "TimeTable Focus Reminders"
            val descriptionText = "Alerts and mindful reminders when distracting apps exceed the focus grace period."
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                setShowBadge(true)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun checkNotificationStatus(): Map<String, Any?> {
        val areEnabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
        val runtimeGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        var channelStatus = "created_enabled"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            val channel = notificationManager?.getNotificationChannel(NOTIFICATION_CHANNEL_ID)
            if (channel == null) {
                channelStatus = "not_created"
            } else if (channel.importance == NotificationManager.IMPORTANCE_NONE) {
                channelStatus = "blocked"
            }
        }

        return mapOf(
            "notificationsEnabled" to areEnabled,
            "runtimePermissionGranted" to runtimeGranted,
            "channelStatus" to channelStatus
        )
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                result.success(true)
            } else {
                pendingPermissionResult = result
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST_CODE
                )
            }
        } else {
            result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun openNotificationSettings(result: MethodChannel.Result) {
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun postDistractionNotification(packageName: String, appName: String, usedMinutes: Int, graceMinutes: Int): Boolean {
        return try {
            createNotificationChannel()
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return false

            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val title = "Focus Reminder: $appName"
            val text = "You've spent $usedMinutes mins in $appName (grace limit: $graceMinutes mins). Tap to return to TimeTable."

            val appIcon = applicationInfo.icon.takeIf { it != 0 } ?: android.R.drawable.ic_dialog_info

            val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(appIcon)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()

            notificationManager.notify(NOTIFICATION_ID_DISTRACTION, notification)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun postTestNotification(): Boolean {
        return try {
            createNotificationChannel()
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return false

            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val appIcon = applicationInfo.icon.takeIf { it != 0 } ?: android.R.drawable.ic_dialog_info

            val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(appIcon)
                .setContentTitle("TimeTable Test Notification")
                .setContentText("Focus notifications are active and properly configured!")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()

            notificationManager.notify(NOTIFICATION_ID_TEST, notification)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun cancelDistractionNotifications() {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.cancel(NOTIFICATION_ID_DISTRACTION)
            notificationManager?.cancel(NOTIFICATION_ID_TEST)
        } catch (_: Exception) {}
    }

    // ---------------------------------------------------------------------------------------------
    // System Diagnostics
    // ---------------------------------------------------------------------------------------------

    private fun getSystemDiagnostics(): Map<String, Any?> {
        val usageGranted = isUsageAccessGranted()
        val queryWorking = if (usageGranted) testUsageQuery() else false
        val notifStatus = checkNotificationStatus()
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val batteryOptIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && powerManager != null) {
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }

        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "sdkInt" to Build.VERSION.SDK_INT,
            "androidVersion" to Build.VERSION.RELEASE,
            "usageAccessGranted" to usageGranted,
            "usageQueryWorking" to queryWorking,
            "notificationsEnabled" to notifStatus["notificationsEnabled"],
            "runtimePermissionGranted" to notifStatus["runtimePermissionGranted"],
            "channelStatus" to notifStatus["channelStatus"],
            "batteryOptimizationIgnored" to batteryOptIgnored,
            "overlayPermissionGranted" to isOverlayPermissionGranted(),
            "enforcementServiceRunning" to FocusEnforcementService.isServiceRunning
        )
    }

    // ---------------------------------------------------------------------------------------------
    // Overlay Permission & Enforcement Service Controls
    // ---------------------------------------------------------------------------------------------

    private fun isOverlayPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                ).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
            } catch (e: Exception) {
                val fallbackIntent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(fallbackIntent)
            }
        }
    }

    private fun startEnforcementService() {
        try {
            val intent = Intent(this, FocusEnforcementService::class.java)
            ContextCompat.startForegroundService(this, intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopEnforcementService() {
        try {
            val intent = Intent(this, FocusEnforcementService::class.java)
            stopService(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun syncEnforcementConfig(config: Map<String, Any?>) {
        val prefs = getSharedPreferences(FocusEnforcementService.PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()

        if (config.containsKey("masterEnabled")) {
            editor.putBoolean(FocusEnforcementService.KEY_MASTER_ENABLED, config["masterEnabled"] as? Boolean ?: false)
        }
        if (config.containsKey("scheduledRestrictionEnabled")) {
            editor.putBoolean(FocusEnforcementService.KEY_SCHEDULED_RESTRICTION_ENABLED, config["scheduledRestrictionEnabled"] as? Boolean ?: true)
        }
        if (config.containsKey("daytimeGraceEnabled")) {
            editor.putBoolean(FocusEnforcementService.KEY_DAYTIME_GRACE_ENABLED, config["daytimeGraceEnabled"] as? Boolean ?: true)
        }
        if (config.containsKey("strictWhitelistMode")) {
            editor.putBoolean(FocusEnforcementService.KEY_STRICT_WHITELIST_MODE, config["strictWhitelistMode"] as? Boolean ?: true)
        }
        if (config.containsKey("browserLoopholeProtection")) {
            editor.putBoolean(FocusEnforcementService.KEY_BROWSER_LOOPHOLE_PROTECTION, config["browserLoopholeProtection"] as? Boolean ?: true)
        }
        if (config.containsKey("youtubeStudyCheck")) {
            editor.putBoolean(FocusEnforcementService.KEY_YOUTUBE_STUDY_CHECK, config["youtubeStudyCheck"] as? Boolean ?: true)
        }
        if (config.containsKey("graceMinutes")) {
            editor.putInt(FocusEnforcementService.KEY_GRACE_MINUTES, (config["graceMinutes"] as? Number)?.toInt() ?: 5)
        }
        if (config.containsKey("cooldownMinutes")) {
            editor.putInt(FocusEnforcementService.KEY_COOLDOWN_MINUTES, (config["cooldownMinutes"] as? Number)?.toInt() ?: 60)
        }
        if (config.containsKey("vipPackages")) {
            @Suppress("UNCHECKED_CAST")
            val vips = (config["vipPackages"] as? List<String>)?.toSet() ?: emptySet()
            editor.putStringSet(FocusEnforcementService.KEY_VIP_PACKAGES, vips)
        }
        if (config.containsKey("distractingPackages")) {
            @Suppress("UNCHECKED_CAST")
            val distractings = (config["distractingPackages"] as? List<String>)?.toSet() ?: emptySet()
            editor.putStringSet(FocusEnforcementService.KEY_DISTRACTING_PACKAGES, distractings)
        }
        editor.apply()

        val masterEnabled = config["masterEnabled"] as? Boolean ?: prefs.getBoolean(FocusEnforcementService.KEY_MASTER_ENABLED, false)
        if (masterEnabled) {
            startEnforcementService()
        } else {
            stopEnforcementService()
        }
    }

    private fun getEnforcementLiveState(): Map<String, Any?> {
        val prefs = getSharedPreferences(FocusEnforcementService.PREFS_NAME, Context.MODE_PRIVATE)
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
        val lastDate = prefs.getString(FocusEnforcementService.KEY_LAST_BLOCK_DATE, "")
        val todayBlocks = if (lastDate == today) prefs.getInt(FocusEnforcementService.KEY_TODAY_BLOCKS_COUNT, 0) else 0

        // Collect active cooldowns
        val allEntries = prefs.all
        val now = System.currentTimeMillis()
        val activeCooldowns = mutableMapOf<String, Long>()
        for ((key, value) in allEntries) {
            if (key.startsWith(FocusEnforcementService.KEY_COOLDOWNS_PREFIX) && value is Long) {
                if (value > now) {
                    val pkg = key.removePrefix(FocusEnforcementService.KEY_COOLDOWNS_PREFIX)
                    activeCooldowns[pkg] = value
                }
            }
        }

        // Determine current phase
        val cal = java.util.Calendar.getInstance()
        val hour = cal.get(java.util.Calendar.HOUR_OF_DAY)
        val min = cal.get(java.util.Calendar.MINUTE)
        val timeMinutes = hour * 60 + min

        val isMasterEnabled = prefs.getBoolean(FocusEnforcementService.KEY_MASTER_ENABLED, false)
        val currentPhase = if (!isMasterEnabled) {
            "disabled"
        } else when {
            timeMinutes in (5 * 60) until (9 * 60) -> "morning_restriction"
            timeMinutes in (9 * 60) until (20 * 60 + 30) -> "daytime_grace"
            timeMinutes in (20 * 60 + 30) until (22 * 60 + 15) -> "night_restriction"
            else -> "sleeping_restriction"
        }

        return mapOf(
            "isServiceRunning" to FocusEnforcementService.isServiceRunning,
            "isOverlayPermissionGranted" to isOverlayPermissionGranted(),
            "isUsagePermissionGranted" to isUsageAccessGranted(),
            "currentPhase" to currentPhase,
            "todayBlocksCount" to todayBlocks,
            "activeCooldowns" to activeCooldowns
        )
    }

    private fun showTestBlockShield(appName: String, packageNameStr: String, reason: String) {
        val intent = Intent(this, FocusBlockActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(FocusBlockActivity.EXTRA_BLOCKED_APP_NAME, appName)
            putExtra(FocusBlockActivity.EXTRA_BLOCKED_PACKAGE, packageNameStr)
            putExtra(FocusBlockActivity.EXTRA_BLOCK_REASON, reason)
            putExtra(FocusBlockActivity.EXTRA_IS_STUDY_CHECK, false)
        }
        startActivity(intent)
    }

    private fun getInstalledApps(): List<Map<String, Any?>> {
        val packageManager = packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = packageManager.queryIntentActivities(intent, 0)
        val result = mutableListOf<Map<String, Any?>>()
        val seenPackages = mutableSetOf<String>()

        for (info in resolveInfos) {
            val pkg = info.activityInfo.packageName
            if (pkg == packageName || seenPackages.contains(pkg)) continue
            seenPackages.add(pkg)

            val label = info.loadLabel(packageManager).toString()
            val isSystem = (info.activityInfo.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0

            result.add(
                mapOf(
                    "packageName" to pkg,
                    "appName" to label,
                    "isSystem" to isSystem
                )
            )
        }
        result.sortBy { (it["appName"] as? String)?.lowercase(java.util.Locale.ROOT) ?: "" }
        return result
    }
}
