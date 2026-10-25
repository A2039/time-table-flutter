package com.timetable

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * Full-screen native block shield & interruption activity ("The Bouncer").
 * Intercepts distracting apps immediately when grace periods expire or during Full Restriction phases.
 */
class FocusBlockActivity : Activity() {

    companion object {
        const val EXTRA_BLOCKED_APP_NAME = "extra_blocked_app_name"
        const val EXTRA_BLOCKED_PACKAGE = "extra_blocked_package"
        const val EXTRA_BLOCK_REASON = "extra_block_reason"
        const val EXTRA_IS_STUDY_CHECK = "extra_is_study_check"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Ensure activity can display over lock screen & turn screen on if needed
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        val appName = intent.getStringExtra(EXTRA_BLOCKED_APP_NAME) ?: "Distracting App"
        val packageNameStr = intent.getStringExtra(EXTRA_BLOCKED_PACKAGE) ?: ""
        val blockReason = intent.getStringExtra(EXTRA_BLOCK_REASON) ?: "Focus Restriction Active"
        val isStudyCheck = intent.getBooleanExtra(EXTRA_IS_STUDY_CHECK, false)

        val root = createView(appName, packageNameStr, blockReason, isStudyCheck)
        setContentView(root)
    }

    private fun createView(appName: String, packageNameStr: String, blockReason: String, isStudyCheck: Boolean): LinearLayout {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#090D16")) // Deep midnight slate
            gravity = Gravity.CENTER
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            val pad = dp(24)
            setPadding(pad, pad, pad, pad)
        }

        val scroll = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            isFillViewport = true
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#151D2C"))
                cornerRadius = dp(24).toFloat()
                setStroke(dp(1), Color.parseColor("#2E3E58"))
            }
            background = bg
            val p = dp(28)
            setPadding(p, p, p, p)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        // Shield Icon with glowing badge
        val iconContainer = LinearLayout(this).apply {
            gravity = Gravity.CENTER
            val s = dp(76)
            layoutParams = LinearLayout.LayoutParams(s, s).apply {
                bottomMargin = dp(20)
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(if (isStudyCheck) Color.parseColor("#3B82F6") else Color.parseColor("#EF4444"))
            }
        }

        val iconView = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_lock_lock)
            setColorFilter(Color.WHITE)
            val isz = dp(38)
            layoutParams = LinearLayout.LayoutParams(isz, isz)
        }
        iconContainer.addView(iconView)
        card.addView(iconContainer)

        // Header Title
        val titleView = TextView(this).apply {
            text = if (isStudyCheck) "30-Minute Study Check" else "Focus Mode Restriction"
            textSize = 20f
            setTypeface(null, Typeface.BOLD)
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(8)
            }
        }
        card.addView(titleView)

        // Blocked App Pill
        val appBadge = TextView(this).apply {
            text = appName
            textSize = 14f
            setTypeface(null, Typeface.BOLD)
            setTextColor(if (isStudyCheck) Color.parseColor("#60A5FA") else Color.parseColor("#FCA5A5"))
            val bp = dp(10)
            val bpv = dp(4)
            setPadding(bp, bpv, bp, bpv)
            background = GradientDrawable().apply {
                setColor(if (isStudyCheck) Color.parseColor("#1E3A8A") else Color.parseColor("#7F1D1D"))
                cornerRadius = dp(12).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(16)
            }
        }
        card.addView(appBadge)

        // Reason Explanation
        val reasonView = TextView(this).apply {
            text = if (isStudyCheck) {
                "Are you watching an educational lecture or scrolling Shorts? Take a mindful pause to protect your study time."
            } else {
                blockReason
            }
            textSize = 14f
            setTextColor(Color.parseColor("#94A3B8")) // Slate 400
            gravity = Gravity.CENTER
            setLineSpacing(dp(4).toFloat(), 1.0f)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(28)
            }
        }
        card.addView(reasonView)

        // Buttons
        if (isStudyCheck) {
            val continueBtn = Button(this).apply {
                text = "Studying (Continue 30m)"
                setTextColor(Color.WHITE)
                textSize = 14f
                setTypeface(null, Typeface.BOLD)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#2563EB")) // Royal blue
                    cornerRadius = dp(14).toFloat()
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dp(48)
                ).apply {
                    bottomMargin = dp(10)
                }
                setOnClickListener {
                    // Send broadcast to grant 30 mins study time on YouTube
                    val intent = Intent("com.timetable.enforcement.STUDY_CONTINUE").apply {
                        setPackage(packageName)
                    }
                    sendBroadcast(intent)
                    finish()
                }
            }
            card.addView(continueBtn)

            val closeBtn = Button(this).apply {
                text = "Close YouTube"
                setTextColor(Color.parseColor("#E2E8F0"))
                textSize = 14f
                setTypeface(null, Typeface.BOLD)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#334155"))
                    cornerRadius = dp(14).toFloat()
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dp(48)
                )
                setOnClickListener {
                    returnToHome()
                }
            }
            card.addView(closeBtn)
        } else {
            val returnBtn = Button(this).apply {
                text = "Return to TimeTable / Home"
                setTextColor(Color.WHITE)
                textSize = 14f
                setTypeface(null, Typeface.BOLD)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#EF4444")) // Crimson red
                    cornerRadius = dp(14).toFloat()
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dp(50)
                )
                setOnClickListener {
                    returnToHome()
                }
            }
            card.addView(returnBtn)
        }

        scroll.addView(card)
        root.addView(scroll)
        return root
    }

    private fun returnToHome() {
        try {
            // First send to TimeTable
            val ttIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(ttIntent)
        } catch (_: Exception) {
            // Fallback to Android Home
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(homeIntent)
        }
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Prevent bypassing restriction via the Android back key: kick to Home
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}
