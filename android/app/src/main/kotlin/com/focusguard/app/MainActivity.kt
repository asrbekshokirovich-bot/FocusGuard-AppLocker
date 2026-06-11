package com.focusguard.app

import android.app.NotificationManager
import android.content.ComponentName
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
    private val DEVICE_CHANNEL = "focusguard/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Qurilma / OEM bridge ──────────────────────────────────────
        // Brendni aniqlash va OEM "Autostart" (avtoishga tushish)
        // sahifasini ochish uchun. Xiaomi/Oppo/Vivo/Huawei kabi
        // qurilmalarda background service busiz uxlab qoladi va bloklash
        // to'xtaydi. Har brendning autostart sahifasi alohida component
        // nomida — biz ma'lum bo'lganlarini ketma-ket sinab ko'ramiz.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getManufacturer" -> {
                        result.success((Build.MANUFACTURER ?: "").lowercase())
                    }
                    "isAutoStartSupported" -> {
                        result.success(autoStartIntents().any { canResolve(it) })
                    }
                    "openAutoStartSettings" -> {
                        val opened = autoStartIntents().firstOrNull { canResolve(it) }?.let {
                            try {
                                it.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(it)
                                true
                            } catch (e: Exception) {
                                false
                            }
                        } ?: false
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }

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

    /**
     * Ma'lum OEM "Autostart / Background app management" sahifalari.
     * Component nomlari brend versiyalariga qarab farq qiladi — shuning
     * uchun bir nechta variantni ro'yxatga olamiz va birinchi
     * resolve bo'ladiganini ochamiz.
     */
    private fun autoStartIntents(): List<Intent> {
        val components = listOf(
            // Xiaomi / Redmi / POCO (MIUI / HyperOS)
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            // Oppo (ColorOS)
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            // Vivo / iQOO (Funtouch / OriginOS)
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            // Huawei / Honor (EMUI / MagicOS)
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
            // Letv
            "com.letv.android.letvsafe" to "com.letv.android.letvsafe.AutobootManageActivity",
            // Asus
            "com.asus.mobilemanager" to "com.asus.mobilemanager.MainActivity"
        )
        return components.map { (pkg, cls) ->
            Intent().setComponent(ComponentName(pkg, cls))
        }
    }

    private fun canResolve(intent: Intent): Boolean {
        return packageManager.resolveActivity(intent, 0) != null
    }
}
