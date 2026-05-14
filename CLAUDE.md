# FocusGuard — Claude Xotira Fayli

## MAJBURIY 6 TA QOIDA (har topshiriqdan oldin o'qi)

1. **Ruxsatsiz hech narsa o'zgartirilmaydi** — foydalanuvchi tasdiqlagunga qadar hech qanday fayl tahrir qilinmaydi
2. **Ruxsatsiz GitHub'ga push qilinmaydi** — hech qachon
3. **Har topshiriqni chuqur o'ylab, to'liq ma'no olib, tasdiqlashdan keyin boshla**
4. **Har topshiriq uchun to'liq professional plan + natija prognozi tasdiqlashdan keyin boshlanadi**
5. **Internet va bilim bazasidan keng qidirib eng to'g'ri yo'lni ko'rsat**
6. **Ortiqcha gap, chalkashlik, bachkanalik yo'q — ish yo'lga qo'yiladi**

---

## LOYIHA MA'LUMOTLARI

- **Ilova nomi:** FocusGuard (App Locker)
- **Tur:** Flutter (Android asosiy)
- **Package:** `com.focusguard.app`
- **GitHub:** `https://github.com/asrbekshokirovich-bot/FocusGuard-AppLocker`
- **Firebase Project:** `focus-guard-786ff`
- **Flutter:** Dart 3.3.0+, compileSdk 36, minSdk 24

---

## LOYIHA TUZILISHI

### Dart fayllar (`lib/`)
```
lib/
├── main.dart                    # Entry point + overlayMain() + WidgetsBindingObserver + CloudSyncService init
├── screens/ (22 ta)
│   ├── splash_screen.dart       # Boshlang'ich ekran, ruxsat va auth tekshiruvi
│   ├── language_screen.dart     # Til tanlash (kirish oqimi)
│   ├── onboarding_screen.dart   # Onboarding
│   ├── login_screen.dart        # Firebase Auth login (+ registration_date saqlaydi)
│   ├── register_screen.dart     # Ro'yxatdan o'tish (+ registration_date saqlaydi)
│   ├── legal_screen.dart        # Foydalanish shartlari
│   ├── dashboard_screen.dart    # Asosiy hub (4 tab)
│   ├── focus_timer_screen.dart  # Pomodoro taymer + faoliyatlar (bo'sh placeholder)
│   ├── block_list_screen.dart   # App bloklash ro'yxati
│   ├── stats_screen.dart        # Statistika + "Faoliyat" ro'yxati + haftalik bottom sheet
│   ├── profile_screen.dart      # Profil va sozlamalar (+ "Mening ma'lumotlarim" menusi)
│   ├── permissions_screen.dart  # Ruxsatlar boshqaruvi (Usage Access bug fixed)
│   ├── overlay_screen.dart      # To'siq ekran (blok + alarm 2 rejim)
│   ├── premium_screen.dart      # Premium obuna (+ "Cheksiz bulutli zaxira" feature)
│   ├── my_plans_screen.dart     # Fokus rejalari
│   ├── calendar_screen.dart     # Oylik fokus tarixi + activity breakdown + 🎉 reg date
│   ├── cloud_backup_screen.dart # ⭐ YANGI — Free/Premium + sync mode toggle + manual backup
│   ├── level_screen.dart        # XP darajalari
│   ├── help_support_screen.dart # Yordam
│   ├── interface_language_screen.dart  # Til o'zgartirish
│   ├── notifications_settings_screen.dart
│   └── themes_screen.dart       # 10 rang tema
└── services/ (15 ta)
    ├── app_translation_service.dart  # ASOSIY tarjima servisi (6 til)
    ├── language_service.dart         # Legacy tarjima (faqat kirish oqimi, 3 til)
    ├── firebase_service.dart         # Firebase Auth + Firestore + getRegistrationDate()
    ├── theme_service.dart            # Dark/light + rang tema
    ├── background_service.dart       # ASOSIY fon xizmati (bloklash + taymer)
    ├── focus_timer_service.dart      # Taymer boshqaruvi (stream)
    ├── level_service.dart            # XP, daraja, streak
    ├── focus_history_service.dart    # Kunlik fokus tarixi + DayRecord(sessions, xp, activities)
    ├── pending_results_processor.dart
    ├── crash_logger.dart             # Xato qaydlash
    ├── streak_reminder_service.dart  # 11:25 eslatma
    ├── timer_notification_service.dart
    ├── service_starter.dart
    ├── cloud_sync_service.dart       # ⭐ YANGI — offline-first auto/manual sync
    └── internet_checker.dart         # ⭐ YANGI — connectivity + no-internet dialog
```

### Android fayllar (`android/`)
```
android/app/src/main/
├── kotlin/com/focusguard/app/MainActivity.kt
├── AndroidManifest.xml          # 13 ruxsat, BackgroundService + OverlayService
└── res/                         # ikonkalar, splash, temalar

packages/flutter_overlay_window/android/src/main/java/.../
├── FlutterOverlayWindowPlugin.java  # Plugin interfeysi
├── OverlayService.java              # Overlay oynasi xizmati
├── OverlayConstants.java            # Kanal nomlari, ID'lar
└── WindowSetup.java                 # Overlay konfiguratsiyasi
```

---

## MUHIM ARXITEKTURA

### Tarjima tizimi
- **`AppTranslationService`** — 6 til (uz, en, ru, ko, de, fr), barcha asosiy ekranlar
- **`LanguageService`** — 3 til (uz, en, ru), faqat kirish oqimi (splash → login)
- Saqlash: `SharedPreferences` kaliti `selected_language`
- Fon xizmati ham `AppTranslationService().init()` chaqiradi

### Fon xizmati arxitekturasi
- **`background_service.dart`** — alohida Dart isolate, `onStart()` entry point
- Taymer + bloklash logikasi har 1 soniyada ishlaydi
- UI bilan aloqa: `service.invoke()` / `service.on()` orqali
- XP/streak → `SharedPreferences` pending queue → main isolate'da `PendingResultsProcessor`
- Background Firebase'ga kira olmaydi → Cloud Sync uchun ham SharedPreferences pending queue

### Overlay tizimi
- `overlayMain()` → alohida Flutter engine → `OverlayScreen`
- **2 rejim:** `timer_alarm_active: true` → Alarm UI | `false` → Bloklash UI
- Kommunikatsiya: `FlutterBackgroundService().invoke()` orqali

### Cloud Sync arxitekturasi (Offline-first)
- **`CloudSyncService`** — main isolate'da ishlaydi, `init()` main.dart'da chaqiriladi
- **Yagona haqiqiy manba:** SharedPreferences (lokal)
- **Backup:** Firestore (bulut)
- Har `recordDay()` → SharedPreferences yoziladi + `cloud_pending_dates` queue'ga qo'shiladi
- `connectivity_plus` internet o'zgarishini kuzatadi → silent sync (auto rejimda)
- Internet yo'q → queue lokal'da kutadi, internet kelganda avtomatik
- `cloud_sync_mode` = `auto` yoki `manual`
- **FREE** plan: faqat so'nggi 7 kun + asosiy ma'lumotlar (seconds/goal/met)
- **PREMIUM** plan: cheksiz tarix + activities/sessions/xp tafsilotlari

### Calendar / Activity tracking
- **`DayRecord`** — `focus_history_YYYY-MM-DD` kalitda saqlanadi
- Fields: `seconds`, `goal`, `met`, `sessions`, `xp`, `activities: Map<String, int>`
- Activity progress kunlik: `activity_progress_YYYY-MM-DD` (URL-encoded query string)
- Calendar ranglari: 🟢 yashil (met), 🟡 sariq (qisman), 🔴 qizil (umuman yo'q)
- Registration date 🎉 overlay (haqiqiy `users/{uid}.createdAt` dan)
- Kelajak + registration'gacha kunlar — xira, bosib bo'lmaydi

### SharedPreferences muhim kalitlar
| Kalit | Tur | Maqsad |
|-------|-----|--------|
| `selected_language` | String | Tanlangan til kodi |
| `blocked_apps` | StringList | Bloklangan paket nomlari |
| `timer_alarm_active` | bool | Alarm o'ynayaptimi |
| `timer_alarm_minutes` | int | Necha daqiqa seans bo'ldi |
| `app_in_foreground` | bool | App foreground'dami |
| `pending_xp_minutes` | int | Kutayotgan XP daqiqalari |
| `pending_streak_date` | String | Kutayotgan streak sanasi |
| `pending_completion_count` | int | Kutayotgan to'liq seanslar |
| `daily_goal_seconds` | int | Kunlik maqsad (soniyada) |
| `today_focus_seconds` | int | Bugungi fokus (soniyada) |
| `today_completed_sessions` | int | Bugun to'liq tugagan seanslar |
| `today_xp_earned` | int | Bugun olingan XP (daqiqada) |
| `timer_end_timestamp` | int | Taymer tugash vaqti (ms) |
| `timer_is_running` | bool | Taymer ishlayaptimi |
| `timer_is_paused` | bool | Taymer pauzadami |
| `custom_activities` | StringList | Foydalanuvchi qo'shgan faoliyatlar |
| `activity_progress_YYYY-MM-DD` | String | Kunlik activity breakdown (query string) |
| `focus_history_YYYY-MM-DD` | String | Kunlik DayRecord (JSON) |
| `registration_date` | String | ISO8601 ro'yxatdan o'tgan sana |
| `cloud_sync_mode` | String | `auto` yoki `manual` |
| `cloud_pending_dates` | StringList | Firestore'ga yuborilmagan kun sanalari |
| `cloud_last_sync_iso` | String | So'nggi sync vaqti (ISO8601) |

---

## OXIRGI O'ZGARISHLAR (Bu sessiyada bajarildi)

### 1. Calendar feature kengaytirildi
**Maqsad:** Kun bosilsa to'liq tafsilotlar, registration day belgisi, yangi rang sxemasi.

**Fayllar:**
- `calendar_screen.dart` — Detail panel (sana, fokus/goal, sessions, XP, met, activity breakdown, 🎉 banner). Day cell ranglari: yashil/sariq/qizil/xira. Kelajak + reg'dan oldingi kunlar bosib bo'lmaydi (`onTap: null`).
- `focus_history_service.dart` — `DayRecord` ga `sessions`, `xp`, `activities` qo'shildi. `recordDay()` har chaqirilganda `cloud_pending_dates` queue'ga avtomatik qo'shadi.
- `background_service.dart` — `today_completed_sessions`, `today_xp_earned` counter'lar. `recordDay()` chaqiriqlariga `activities: activitiesForDay(dateKey)` qo'shildi (5 joyda).
- `timer_notification_service.dart` — `sendTodayResultBasedOnProgress` ham activities/sessions/xp ni yozadi.
- `firebase_service.dart` — `getRegistrationDate(uid)` metodi qo'shildi.
- `login_screen.dart` — Login'da Firestore'dan `registration_date` o'qib SharedPreferences'ga saqlaydi.
- `register_screen.dart` — Ro'yxatdan o'tishda `DateTime.now()` ni `registration_date` qilib saqlaydi.

### 2. Faoliyat tizimi (mock'lar tozalandi)
**Muammo:** Yangi user'da 4 ta mock (Dasturlash, O'qish, Ish, Meditatsiya) chiqib turardi.

**Fayllar:**
- `focus_timer_screen.dart` — `_customActivities = []` default. Bo'sh holatda `_buildEmptyActivities()` widget ("Sevimli faoliyatingizni qo'shing").
- `stats_screen.dart` — Default loadedActivities olib tashlandi. Faoliyat ro'yxati `GestureDetector`ga o'raldi.
- "+" tugmasi kichraytirildi: 26×26 px, ikonka 11 px.

### 3. Stats — "Oxirgi seanslar" → "Faoliyat" + haftalik bottom sheet
- `stats.recent_sessions` matni "Faoliyat" qilindi (6 tilda).
- Yangi keys: `stats.activity_weekly_title`, `stats.activity_weekly_total`, `stats.activity_no_data`.
- `_showActivityWeeklyDetails()` metodi — so'nggi 7 kun `activity_progress_YYYY-MM-DD` o'qib bar chart ko'rsatadi.
- `_weekdayShort()`, `_formatMinutesToHm()` helper'lar.

### 4. Cloud Backup tizimi (offline-first)
**Yangi fayllar:**

#### `lib/services/internet_checker.dart`
- `isOnline()` — `connectivity_plus` orqali tekshiruv
- `onConnectivityChanged` — internet o'zgarishi stream'i
- `ensureOnline(context)` — internet yo'q bo'lsa "Tushunarli" dialog ko'rsatadi
- Menyularga kirishda emas, faqat internet kerak bo'lgan tugma bosilganda chaqiriladi

#### `lib/services/cloud_sync_service.dart`
- `init()` — main.dart'da chaqiriladi, connectivity listener boshlaydi
- `_maybeSilentSync()` — auto rejimda internet bor + pending bor → silent yuboradi
- `_syncPending(silent: true/false)` — queue'dagi kunlarni Firestore'ga yuboradi
- `uploadAllManual()` — foydalanuvchi tugmasi bosgandan keyin to'liq backup
- `restoreFromCloud()` — login'da Firestore'dan lokal'ga tortib oladi
- `BackupProgress` model — progress stream UI uchun
- FREE/PREMIUM: `_isPremiumUser(uid)` Firestore'dan tekshiradi, FREE faqat 7 kun

#### `lib/screens/cloud_backup_screen.dart`
- Header: ☁️ ikonka + matn
- Sync mode toggle: Avtomatik / Qo'lda (radio button)
- Free Plan card: yashil border (current bo'lsa)
- Premium Plan card: binafsha gradient + "Premium'ga o'tish" tugmasi
- Backup tugma: bosilsa internet tekshiriladi, yuklash progress bar bilan ("45/120 kun")
- So'nggi backup vaqti

#### O'zgartirilgan fayllar:
- `main.dart` — `await CloudSyncService.instance.init()` qo'shildi
- `profile_screen.dart` — "Mening ma'lumotlarim" menyu item Calendar'dan keyin
- `premium_screen.dart` — `feature_cloud_title` / `feature_cloud_desc` qo'shildi
- `pubspec.yaml` — `connectivity_plus: ^6.1.0`
- `app_translation_service.dart` — 6 tilda ~60 yangi tarjima keys (`cloud_backup.*`, `internet.*`, `profile.menu_cloud_backup`, `premium.feature_cloud_*`)

### 5. Permissions screen bug fix (Usage Access cycling)
**Muammo:** Foydalanuvchi Usage Access ruxsatini bersa, qaytib kirsa yana yoniq ko'rinardi (aylanish).

**Sabab:** `_checkPermissions(isPassive: true)`'da `usage = _isUsageGranted` cached qiymat (default `false`) qaytarilardi.

**Yechim:** `permissions_screen.dart` — har chaqiriqda `_checkUsagePermission()` chaqiriladi (u allaqachon passive, AppUsage API faqat exception qaytaradi).

---

## NOTIFICATION ID'LAR (to'qnashmaslik uchun)
| ID | Maqsad |
|----|--------|
| 555 | Timer tugadi (timer_completed_channel) |
| 777 | Level up (achievement_channel) |
| 888 | Streak reminder / Goal missed |
| 889 | Goal achieved |
| 890 | Daily summary (23:55) |
| 999 | Timer running (focus_timer_channel) |
| 7777 | Foreground service (app_locker_channel) |

---

## FIREBASE TUZILISHI

### `users/{uid}` (asosiy user document)
```
{
  name: String
  email: String
  createdAt: Timestamp           # Calendar'da 🎉 belgisi shu sanaga qo'yiladi
  isPremium: Boolean             # CloudSync FREE/PREMIUM ajratish uchun
  level: int
  xp: int
  totalMinutes: int
  streak: int
  lastFocusDate: String          # YYYY-MM-DD
  customActivities: List<String> # CloudSync orqali sync qilingan faoliyatlar
  updatedAt: Timestamp           # CloudSync so'nggi yangilash vaqti
}
```

### `users/{uid}/history/{YYYY-MM-DD}` (kunlik history)
```
FREE plan (so'nggi 7 kun):
{
  seconds: int
  goal: int
  met: bool
  updatedAt: Timestamp
}

PREMIUM plan (cheksiz):
{
  seconds: int
  goal: int
  met: bool
  sessions: int                  # Bugun to'liq tugagan timer seanslar soni
  xp: int                        # Bugun olingan XP (daqiqa)
  activities: Map<String, int>   # {"Dasturlash": 90, "O'qish": 60}
  updatedAt: Timestamp
}
```

---

## MUHIM ESLATMALAR
- Samsung qurilmalarda `SYSTEM_ALERT_WINDOW` jimgina bekor qilinishi mumkin → `CrashLogger`ga yoziladi
- Background isolate Firebase Auth/Firestore'ga kira olmaydi → `SharedPreferences` pending queue ishlatiladi
- Overlay alohida Flutter engine'da ishlaydi → `DartPluginRegistrant.ensureInitialized()` shart
- `prefs.reload()` har bloklash tekshiruvida chaqiriladi (stale cache muammosi)
- `FlutterRingtonePlayer().stop()` faqat background isolate'da chaqirilishi kerak (u yerda boshlangan)
- Cloud Sync internet kerak bo'lgan tugma bosilgandagina ensureOnline chaqiriladi — menyularga kirishda emas
- Firestore offline persistence yoqilgan (`main.dart`'da) → 100 MB cache avtomatik
- Activity kalitlari 2 xil bo'lishi mumkin: `activities.coding` (eski mock) yoki to'g'ridan-to'g'ri ism ("Dasturlash")
- `_activityDisplayName(key, lang)` — eski format'dagi kalitlarni tarjima qiladi
- `connectivity_plus` v6+ `List<ConnectivityResult>` qaytaradi — `any((r) => r != none)` orqali tekshirish
