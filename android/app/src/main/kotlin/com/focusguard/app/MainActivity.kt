package com.focusguard.app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Do Not Disturb (DnD) — Anti-Chalg'itish funksiyasi uchun native bridge.
 *
 * Flutter tomonidan `focusguard/dnd` MethodChannel orqali chaqiriladi:
 *   • `isPermissionGranted` → Bool (foydalanuvchi ruxsat berganmi)
 *   • `openPermissionSettings` → Settings ekranini ochadi
 *   • `getCurrentFilter` → Int (joriy DnD holatini qaytaradi)
 *   • `setFilter(filter: Int)` → Bool (yangi filtrni qo'llaydi)
 *
 * Filter qiymatlari (NotificationManager constants):
 *   1 (ALL)      — DnD off (normal)
 *   2 (PRIORITY) — Faqat priority bildirishnomalar (alarm, kontaktlar)
 *   3 (NONE)     — Hech qanday bildirishnoma (alarm ham yo'q)
 *   4 (ALARMS)   — Faqat alarm
 *
 * Biz `PRIORITY` (2) ishlatamiz — alarm va qo'ng'iroqlar uchun
 * foydalanuvchini saqlab, ijtimoiy tarmoqlardan keladigan
 * shovqinli notifikatsiyalarni jim qiladi.
 */
class MainActivity : FlutterActivity() {
    private val CHANNEL = "focusguard/dnd"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                when (call.method) {
                    "isPermissionGranted" -> {
                        // Android M+ da DnD policy access kerak. Eski versiyada hamma narsa allowed.
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            nm.isNotificationPolicyAccessGranted
                        } else true
                        result.success(granted)
                    }
                    "openPermissionSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", e.message, null)
                        }
                    }
                    "getCurrentFilter" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                                nm.isNotificationPolicyAccessGranted
                            ) {
                                result.success(nm.currentInterruptionFilter)
                            } else {
                                result.success(NotificationManager.INTERRUPTION_FILTER_ALL)
                            }
                        } catch (e: Exception) {
                            result.error("GET_FAILED", e.message, null)
                        }
                    }
                    "setFilter" -> {
                        try {
                            val filter = call.argument<Int>("filter")
                                ?: NotificationManager.INTERRUPTION_FILTER_ALL
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                                nm.isNotificationPolicyAccessGranted
                            ) {
                                nm.setInterruptionFilter(filter)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.error("SET_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
