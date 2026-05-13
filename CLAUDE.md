# FocusGuard — Claude Xotira Fayli

## MAJBURIY 6 TA QOIDA (har topshiriqdan oldin o'qi)

1. **Ruxsatsiz hech narsa o'zgartirilmaydi** — foydalanuvchi tasdiqlagunga qadar hech qanday fayl tahrir qilinmaydi
2. **Ruxsatsiz GitHub'ga push qilinmaydi** — hech qachon
3. **Har topshiriqni chuqur o'ylab, to'liq ma'no olib, tasdiqlashdan keyin boshla**
4. **Har topshiriq uchun to'liq professional plan + natija prognozimazidan boshlanmaydi**
5. **Internet va bilim bazasidan keng qidiriб eng to'g'ri yo'lni ko'rsat**
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
├── main.dart                    # Entry point + overlayMain() + WidgetsBindingObserver
├── screens/ (21 ta)
│   ├── splash_screen.dart       # Boshlang'ich ekran, ruxsat va auth tekshiruvi
│   ├── language_screen.dart     # Til tanlash (kirish oqimi)
│   ├── onboarding_screen.dart   # Onboarding
│   ├── login_screen.dart        # Firebase Auth login
│   ├── register_screen.dart     # Ro'yxatdan o'tish
│   ├── legal_screen.dart        # Foydalanish shartlari
│   ├── dashboard_screen.dart    # Asosiy hub (4 tab)
│   ├── focus_timer_screen.dart  # Pomodoro taymer
│   ├── block_list_screen.dart   # App bloklash ro'yxati
│   ├── stats_screen.dart        # Statistika va XP
│   ├── profile_screen.dart      # Profil va sozlamalar
│   ├── permissions_screen.dart  # Ruxsatlar boshqaruvi
│   ├── overlay_screen.dart      # To'siq ekran (blok + alarm 2 rejim)
│   ├── premium_screen.dart      # Premium obuna
│   ├── my_plans_screen.dart     # Fokus rejalari
│   ├── calendar_screen.dart     # Oylik fokus tarixi
│   ├── level_screen.dart        # XP darajalari
│   ├── help_support_screen.dart # Yordam
│   ├── interface_language_screen.dart  # Til o'zgartirish
│   ├── notifications_settings_screen.dart
│   └── themes_screen.dart       # 10 rang tema
└── services/ (13 ta)
    ├── app_translation_service.dart  # ASOSIY tarjima servisi (6 til)
    ├── language_service.dart         # Legacy tarjima (faqat kirish oqimi, 3 til)
    ├── firebase_service.dart         # Firebase Auth + Firestore
    ├── theme_service.dart            # Dark/light + rang tema
    ├── background_service.dart       # ASOSIY fon xizmati (bloklash + taymer)
    ├── focus_timer_service.dart      # Taymer boshqaruvi (stream)
    ├── level_service.dart            # XP, daraja, streak
    ├── focus_history_service.dart    # Kunlik fokus tarixi
    ├── pending_results_processor.dart
    ├── crash_logger.dart             # Xato qaydlash
    ├── streak_reminder_service.dart  # 11:25 eslatma
    ├── timer_notification_service.dart
    └── service_starter.dart
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

### Overlay tizimi
- `overlayMain()` → alohida Flutter engine → `OverlayScreen`
- **2 rejim:** `timer_alarm_active: true` → Alarm UI | `false` → Bloklash UI
- Kommunikatsiya: `FlutterBackgroundService().invoke()` orqali

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
| `daily_goal_seconds` | int | Kunlik maqsad (soniyada) |
| `today_focus_seconds` | int | Bugungi fokus (soniyada) |
| `timer_end_timestamp` | int | Taymer tugash vaqti (ms) |
| `timer_is_running` | bool | Taymer ishlayaptimi |
| `timer_is_paused` | bool | Taymer pauzadami |
| `app_in_foreground` | bool | WidgetsBindingObserver o'rnatadi |

---

## OXIRGI O'ZGARISHLAR (Bu sessiyada bajarildi)

### 1. Alarm dismiss funksiyasi (YANGI)
**Muammo:** Rington chalinib, o'chirish tugmasi yo'q edi.
**Ildiz sabab:**
- `timerFinished` event `FocusTimerService`da tinglanmagan edi
- `_onTimerComplete` shartida `event['wasRunning'] == true` — bu maydon hech qachon yuborilmagan

**Yechim — 6 fayl o'zgartirildi:**

#### `app_translation_service.dart`
- 6 tilda yangi `alarm` sektsiyasi qo'shildi:
  - `alarm.in_app_title`, `alarm.in_app_body`, `alarm.dismiss_btn`
  - `alarm.overlay_title`, `alarm.overlay_body`, `alarm.overlay_btn`

#### `main.dart`
- `FocusGuardApp` → `StatefulWidget` + `WidgetsBindingObserver`
- `app_in_foreground` flagini lifecycle'ga qarab yozadi

#### `background_service.dart`
- `looping: false` → `looping: true` (foydalanuvchi o'chirgacha chaladi)
- Timer tugaganda: `timer_alarm_active: true`, `timer_alarm_minutes: n` yozadi
- `app_in_foreground` tekshirib, fonda bo'lsa alarm overlay ko'rsatadi
- Yangi `stopAlarm` event listener: `FlutterRingtonePlayer().stop()` + flag tozalash
- `timerFinished` invoke'ga `{'minutes': ...}` qo'shildi
- Block detection: `timer_alarm_active: true` bo'lsa overlay yopilmaydi

#### `focus_timer_service.dart`
- `timerFinished` event listeneri qo'shildi (stream'ga `{timerFinished: true}` yuboradi)
- `stopAlarm()` metodi qo'shildi

#### `focus_timer_screen.dart`
- Stream listener'da `timerFinished: true` tekshiruvi qo'shildi
- `_onTimerComplete` to'liq qayta yozildi: yangi Material dialog, rington qayta o'ynamas, `stopAlarm()` chaqiradi

#### `overlay_screen.dart`
- `_isAlarmMode` bool qo'shildi
- `initState`'da `timer_alarm_active` flag o'qiladi
- `_buildAlarmUI()` — to'liq ekran alarm dismiss UI (⏰ ikonka, matn, katta tugma)
- `_buildBlockingUI()` — avvalgi bloklash UI (o'zgarishsiz)

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
```
Firestore: users/{uid}
  - name: String
  - email: String
  - createdAt: Timestamp
  - isPremium: Boolean
  - level: int
  - xp: int
  - totalMinutes: int
  - streak: int
  - lastFocusDate: String (YYYY-MM-DD)
```

---

## MUHIM ESLATMALAR
- Samsung qurilmalarda `SYSTEM_ALERT_WINDOW` jimgina bekor qilinishi mumkin → `CrashLogger`ga yoziladi
- Background isolate Firebase Auth'ga kira olmaydi → `SharedPreferences` pending queue ishlatiladi
- Overlay alohida Flutter engine'da ishlaydi → `DartPluginRegistrant.ensureInitialized()` shart
- `prefs.reload()` har bloklash tekshiruvida chaqiriladi (stale cache muammosi)
- `FlutterRingtonePlayer().stop()` faqat background isolate'da chaqirilishi kerak (u yerda boshlangan)
