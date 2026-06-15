package com.focusguard.app

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Bloklangan ilova ochilganda chiqadigan to'liq ekran to'siq.
 *
 * AccessibilityService (AppBlockerService) bloklangan ilovani aniqlaganda
 * shu Activity'ni ustiga ochadi. To'liq native — Flutter engine, overlay
 * ruxsati yoki fon xizmati kerak emas, shuning uchun har qanday Android
 * versiyasida (shu jumladan 16) ishonchli ishlaydi.
 *
 * "Bosh ekranga" tugmasi foydalanuvchini HOME'ga chiqaradi. Agar bloklangan
 * ilovaga qайta kirsa, AccessibilityService yana shu ekranni ochadi.
 */
class BlockActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0B1020"))
            setPadding(64, 64, 64, 64)
        }

        val icon = TextView(this).apply {
            text = "🛡️"
            textSize = 64f
            gravity = Gravity.CENTER
        }

        val title = TextView(this).apply {
            text = "Bu ilova bloklangan"
            setTextColor(Color.WHITE)
            textSize = 24f
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 12)
        }

        val subtitle = TextView(this).apply {
            text = "Diqqatingizni jamlang — FocusGuard sizni chalg'ishdan himoya qilmoqda."
            setTextColor(Color.parseColor("#9AA4B2"))
            textSize = 15f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        }

        val homeBtn = Button(this).apply {
            text = "Bosh ekranga qaytish"
            setOnClickListener { goHome() }
        }

        root.addView(icon)
        root.addView(title)
        root.addView(subtitle)
        root.addView(homeBtn)
        setContentView(root)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        // Allaqachon ochiq — qayta ishlatamiz (singleTop).
    }

    // Orqaga tugmasi ham bosh ekranga chiqaradi (bloklangan ilovaga qaytmaslik).
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        goHome()
    }

    private fun goHome() {
        val home = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(home)
        finish()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Animatsiyasiz yopilish (ixtiyoriy)
        }
    }
}
