package com.timetable

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * Automatically resumes FocusEnforcementService on device boot if Master Restriction is enabled.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            val prefs = context.getSharedPreferences(
                FocusEnforcementService.PREFS_NAME,
                Context.MODE_PRIVATE
            )
            val isMasterEnabled = prefs.getBoolean(FocusEnforcementService.KEY_MASTER_ENABLED, false)

            if (isMasterEnabled) {
                try {
                    val serviceIntent = Intent(context, FocusEnforcementService::class.java)
                    ContextCompat.startForegroundService(context, serviceIntent)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }
}
