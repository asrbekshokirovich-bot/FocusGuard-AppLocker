package com.focusguard.app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray
import java.util.Calendar

/**
 * Ilovalarni bloklash uchun AccessibilityService.
 *
 * NEGA AccessibilityService: haqiqiy ilova-bloklovchilar (AppBlock, Stay
 * Focused, ...) aynan shu usulni ishlatadi. U event-asosli — foydalanuvchi
 * biror ilovani ochishi bilan TIZIM darhol `TYPE_WINDOW_STATE_CHANGED`
 * eventini yuboradi. Bu UsageStats'ni fon izolatida har 250ms tekshirishdan
 * ko'ra ANCHA ishonchli va tez (ayniqsa Android 14/15/16 va OEM qurilmalarda,
 * u yerda fon xizmati uxlab qoladi yoki butunlay ishga tushmaydi).
 *
 * Bloklangan ilovalar ro'yxati Flutter SharedPreferences'dan o'qiladi
 * (Dart tomoni `native_blocked_csv` va `native_schedules_json`'ni yozadi).
 * Bloklangan ilova foreground'ga chiqsa — to'siq ekran (BlockActivity)
 * ustiga ochiladi.
 */
class AppBlockerService : AccessibilityService() {

    private var lastPackage: String? = null
    private var lastBlockAtMs: Long = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val pkg = event.packageName?.toString() ?: return
        // O'zimiz, launcher, system UI va sozlamalar — bloklamaymiz.
        if (pkg == packageName) return
        if (pkg == "com.android.systemui") return

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // Deep Focus pauza paytida bloklash vaqtincha o'chiriladi (Dart yozadi).
        val paused = prefs.getBoolean("flutter.native_block_paused", false)
        if (paused) return

        if (!isBlocked(pkg, prefs)) {
            lastPackage = pkg
            return
        }

        // Aynan o'sha ilovaga 1 soniya ichida qayta blok ko'rsatmaymiz
        // (BlockActivity ochilayotganda takror eventlarni e'tiborsiz qoldiramiz).
        val now = System.currentTimeMillis()
        if (pkg == lastPackage && now - lastBlockAtMs < 1200) return
        lastPackage = pkg
        lastBlockAtMs = now

        try {
            val i = Intent(this, BlockActivity::class.java)
            i.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION
            )
            i.putExtra("blocked_package", pkg)
            startActivity(i)
        } catch (_: Exception) {
        }
    }

    /** Paket doimiy ro'yxatda yoki faol jadval oynasida bloklanganmi. */
    private fun isBlocked(pkg: String, prefs: android.content.SharedPreferences): Boolean {
        // 1) Doimiy bloklangan ilovalar — Dart vergul bilan yozadi.
        val csv = prefs.getString("flutter.native_blocked_csv", "") ?: ""
        if (csv.isNotEmpty()) {
            for (p in csv.split(",")) {
                if (p.trim() == pkg) return true
            }
        }
        // 2) Faol jadval oynalari (focus_schedules JSON).
        val schedJson = prefs.getString("flutter.native_schedules_json", "") ?: ""
        if (schedJson.isNotEmpty() && scheduleBlocks(pkg, schedJson)) return true
        return false
    }

    /** Joriy vaqt biror yoqilgan jadval oynasiga tushsa va pkg o'sha jadvalda bo'lsa true. */
    private fun scheduleBlocks(pkg: String, json: String): Boolean {
        try {
            val arr = JSONArray(json)
            val cal = Calendar.getInstance()
            val nowMin = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
            // Dart weekday: Mon=1..Sun=7. Kotlin: Sun=1..Sat=7.
            val k = cal.get(Calendar.DAY_OF_WEEK)
            val weekday = if (k == Calendar.SUNDAY) 7 else k - 1
            for (idx in 0 until arr.length()) {
                val item = arr.optJSONObject(idx) ?: continue
                if (!item.optBoolean("enabled", false)) continue
                // kunlar
                val days = item.optJSONArray("days")
                if (days != null && days.length() > 0) {
                    var match = false
                    for (d in 0 until days.length()) {
                        if (days.optInt(d) == weekday) { match = true; break }
                    }
                    if (!match) continue
                }
                val start = item.optInt("start", 0)
                val end = item.optInt("end", 0)
                val inWindow = when {
                    start == end -> false
                    start < end -> nowMin >= start && nowMin < end
                    else -> nowMin >= start || nowMin < end // tungi oyna
                }
                if (!inWindow) continue
                val apps = item.optJSONArray("apps") ?: continue
                for (a in 0 until apps.length()) {
                    if (apps.optString(a) == pkg) return true
                }
            }
        } catch (_: Exception) {
        }
        return false
    }

    override fun onInterrupt() {}
}
