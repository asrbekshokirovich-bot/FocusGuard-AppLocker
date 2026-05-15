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
├── main.dart                    # Entry point + overlayMain() + DailyReset init + CloudSync init
├── screens/ (22 ta)
│   ├── splash_screen.dart       # Boshlang'ich ekran, ruxsat va auth tekshiruvi
│   ├── language_screen.dart     # Til tanlash (kirish oqimi)
│   ├── onboarding_screen.dart   # Onboarding
│   ├── login_screen.dart        # Firebase Auth login (+ registration_date saqlaydi)
│   ├── register_screen.dart     # Ro'yxatdan o'tish (+ registration_date saqlaydi)
│   ├── legal_screen.dart        # Foydalanish shartlari
│   ├── dashboard_screen.dart    # Asosiy hub (4 tab); crash banner permission-denied'ni filtrlaydi
│   ├── focus_timer_screen.dart  # Pomodoro: Chuqur/Yengil Fokus, faoliyatlar (mode-aware), audio
│   ├── block_list_screen.dart   # App bloklash + Temir Intizom lock dialog + icon cache
│   ├── stats_screen.dart        # To'liq real ma'lumotlar: chartlar, Aqlli Tahlil, Yengil Fokus karta
│   ├── profile_screen.dart      # Profil + "Mening ma'lumotlarim" + "Ruxsatlar"
│   ├── permissions_screen.dart  # Ruxsatlar (Usage Access cycling fixed)
│   ├── overlay_screen.dart      # To'siq ekran (blok + alarm 2 rejim)
│   ├── premium_screen.dart      # Premium + "Cheksiz bulutli zaxira" feature
│   ├── my_plans_screen.dart     # Fokus rejalari
│   ├── calendar_screen.dart     # Oylik fokus tarixi + activity breakdown + 🎉 reg date
│   ├── cloud_backup_screen.dart # Free/Premium + auto/manual toggle + auto rejim tasdiqlash kartasi
│   ├── level_screen.dart        # 16 ta daraja, XP+daqiqa badge, "Xs Ymin qoldi"
│   ├── help_support_screen.dart # Yordam
│   ├── interface_language_screen.dart  # Til o'zgartirish
│   ├── notifications_settings_screen.dart
│   └── themes_screen.dart       # 10 rang tema
└── services/ (17 ta)
    ├── app_translation_service.dart   # 6 til, barcha ekranlar
    ├── language_service.dart          # Legacy (3 til, faqat kirish oqimi)
    ├── firebase_service.dart          # Auth + Firestore + getRegistrationDate()
    ├── theme_service.dart             # Dark/light + rang tema
    ├── background_service.dart        # ASOSIY fon: timer + bloklash + counter'lar
    ├── focus_timer_service.dart       # Timer stream
    ├── level_service.dart             # 16 darajali XP threshold tizimi + migration
    ├── focus_history_service.dart     # DayRecord(seconds, goal, met, sessions, xp, activities)
    ├── pending_results_processor.dart # Pending XP/streak — yagona XP source
    ├── crash_logger.dart              # Permission/network xato filtri
    ├── streak_reminder_service.dart   # 11:25 eslatma
    ├── timer_notification_service.dart
    ├── service_starter.dart
    ├── cloud_sync_service.dart        # Offline-first auto/manual + circuit breaker
    ├── internet_checker.dart          # connectivity + dialog
    ├── daily_reset_service.dart       # ⭐ Kun reset (app launch/resume'da)
    └── soundscape_service.dart        # ⭐ Tabiat ovozlari (audioplayers)
```

### Assets va boshqa fayllar
```
assets/
├── logo.png
├── uz.png, ru.png, us.png
└── sounds/                     # ⭐ bundled MP3 (~1 MB)
    ├── rain.mp3                # Archive.org, Public Domain
    └── forest.mp3              # Archive.org, Public Domain

firestore.rules                  # ⭐ Firebase Console'ga ko'chirish uchun
```

---

## MUHIM ARXITEKTURA

### Tarjima tizimi
- **`AppTranslationService`** — 6 til (uz, en, ru, ko, de, fr)
- **`LanguageService`** — 3 til (legacy, faqat kirish oqimi)
- Saqlash: `selected_language`

### Fon xizmati arxitekturasi
- **`background_service.dart`** — alohida Dart isolate, har 1 sec ticks
- UI bilan aloqa: `service.invoke()` / `service.on()`
- Background Firebase'ga kira olmaydi → SharedPreferences pending queue
- `prefs.reload()` har stale cache muammosi uchun

### Overlay tizimi
- `overlayMain()` → alohida Flutter engine → `OverlayScreen`
- 2 rejim: `timer_alarm_active` true → Alarm UI | false → Bloklash UI
- Bloklash overlay yopiladi → alarm overlay'i o'tkaziladi (sequencing)
- `prefs.reload()` background isolate'da kerak — main isolate o'zgartirgan `app_in_foreground`'ni jonli o'qish uchun

### Daraja tizimi (16 daraja)
- **`LevelService.levelXpThresholds`** — XP chegaralar:
  - L1: 0 (0s), L2: 600 (1s), L3: 1800 (3s), L4: 4200 (7s), L5: 9000 (15s)
  - L6: 18000 (30s), L7: 30000 (50s), L8: 48000 (80s), L9: 72000 (120s)
  - L10: 108000 (180s), L11: 150000 (250s), L12: 240000 (400s)
  - L13: 360000 (600s), L14: 540000 (900s), L15: 780000 (1300s), L16: 1080000 (1800s)
- 1 daqiqa = 10 XP
- `LevelInfo levelInfoFromXp(int xp)` — UI uchun yagona helper
- `migrateLevelIfNeeded()` — main.dart'da chaqiriladi, eski user'lar uchun
- `getRankTitle(N)` → `rank_N` (1:1 mos)

### Daily reset (`daily_reset_service.dart`) ⭐
- App launch va resume'da `checkAndResetIfNewDay()` chaqiriladi
- `last_focus_date` to'liq ISO sana (YYYY-MM-DD) saqlanadi
- Kun o'tgan bo'lsa: kechagi data history'ga arxivlanadi, today_* counter'lar 0 ga tushadi
- Background service uxlab qolgan bo'lsa ham ishlaydi
- Eski `last_tracked_day` (faqat day raqami) bug'i tuzatildi

### XP/Sessions tracking (single source of truth, sekund aniqligida)
- **XP yagona manba:** `PendingResultsProcessor` — `pending_xp_minutes` + `pending_xp_seconds` → `LevelService.addXpFromSeconds()`
- `_updateProgress`'dan addXP olib tashlandi (avval 2 marta hisoblanardi)
- **Sessions yagona manba:** `today_completed_sessions` + history.sessions (bugungi kalit istisno)
- `addTodayXpFromMinutes(minutes)` — ichida `* 10` (`today_xp_earned` haqiqiy XP)
- `addTodayXpFromSeconds(seconds)` — XP = `(seconds * 10 / 60).round()` (6 sek = 1 XP)
- `queuePendingXpSeconds(seconds)` — qisman to'xtatishlar uchun (1+ sek)
- Stop threshold: >= 1 sekund (avval 60 sek edi — kichik seanslar yo'qotilardi)
- `LevelService.addXpFromSeconds()` — Firestore `totalSeconds` + `totalMinutes` yozadi

### Cloud Sync (offline-first, premium-gated)
- **Yagona haqiqiy manba:** SharedPreferences (lokal)
- **Backup:** Firestore (bulut)
- `recordDay()` → `cloud_pending_dates` queue'ga avtomatik
- Auto rejim: connectivity listener → silent sync
- Manual rejim: tugma orqali, progress bar
- **Circuit breaker:** 3 ta ketma-ket permission/network xato → sessiya davomida to'xtatadi
- FREE: so'nggi 7 kun (seconds/goal/met)
- PREMIUM: cheksiz + sessions/xp/activities

### Audio (Tabiat Ovozlari) ⭐
- **`SoundscapeService`** — `audioplayers` paketdan foydalanadi
- 2 ta bundled MP3 (`assets/sounds/`): rain, forest (~1 MB)
- Sound picker: 3 ta variant (Yo'q / Yomg'ir / O'rmon)
- **FAQAT Yengil Fokus rejimida ijro etiladi** (`_selectedMode == 1`)
- Chuqur Fokus rejimida hech qanday audio chiqmaydi
- ReleaseMode.loop — fayl tugaganda qaytadan boshlanadi
- Volume: 60%
- Timer start/pause/resume/stop/dispose bilan sync
- To'xtatish dialog tasdiqlanganda ham stop chaqiriladi
- Silent fail — fayl yo'q bo'lsa crash yo'q

### Calendar / Activity tracking
- `DayRecord` — `focus_history_YYYY-MM-DD` kalitda
- Fields: seconds, goal, met, sessions, xp, activities (Map)
- `activity_progress_YYYY-MM-DD` — sekund aniqligida saqlanadi (avval daqiqa edi)
- Calendar ranglar: 🟢 met, 🟡 qisman, 🔴 yo'q
- Registration date 🎉 overlay
- Cell shape: `BorderRadius.circular(10)` (yumshoq burchak), `childAspectRatio: 1.0` (kvadrat)
- Kelajak + registration'gacha — xira, bosib bo'lmaydi
- Activity tanlash: bita bossa tanlanadi, ikkinchi bossa tanlash bekor qilinadi (toggle)
- `_selectedActivityIndex = -1` default — foydalanuvchi tanlasagina yoziladi

### Stats — to'liq real ma'lumotlar
- **Fokus Balli:** so'nggi 7 kun (seconds/goal).clamp(0,1) o'rtachasi × 100
- **Haftalik o'rtacha:** so'nggi 7 kun seconds yig'indisi / 7 / 3600
- **Maqsadga erishildi %:** bugun_seconds / bugun_goal × 100
- **Haftalik chart:** Du-Ya joriy hafta, real history dan, ustun tepasida vaqt (0 → ko'rsatilmaydi)
- **Oylik chart:** 4 hafta, drill-down 7 kunlik breakdown
- **Aqlli Tahlil:** real bugun-kecha farqi, hafta-vs-hafta foiz, hafta oxiri prognozi, keyingi milestone'gacha streak
- **Top distractors:** 30 kunlik `block_attempts_*` aggregation + ilova ikonkasi cache
- **Yengil Fokus karta:** `light_focus_total_seconds` kumulativ

### Iron Discipline (mode-aware)
- `_isStrictMode` toggle faqat Chuqur Fokus rejimida UI'da ko'rinadi
- `_effectiveStrict = _isStrictMode && _selectedMode == 0`
- Yengil Fokus'da: `isStrict = false` (orqaga qaytish bemalol, block list ham bemalol)
- `timer_is_strict` SharedPreferences kalitida → `block_list_screen` o'qiydi

---

### SharedPreferences muhim kalitlar
| Kalit | Tur | Maqsad |
|-------|-----|--------|
| `selected_language` | String | Tanlangan til kodi |
| `blocked_apps` | StringList | Bloklangan paket nomlari |
| `timer_alarm_active` | bool | Alarm o'ynayaptimi |
| `timer_alarm_minutes` | int | Necha daqiqa seans bo'ldi |
| `timer_is_running` | bool | Taymer ishlayaptimi |
| `timer_is_paused` | bool | Taymer pauzadami |
| `timer_is_strict` | bool | Joriy seans Temir Intizom rejimidami |
| `timer_is_light` | bool | Joriy seans Yengil Fokus rejimidami |
| `timer_end_timestamp` | int | Taymer tugash vaqti (ms) |
| `app_in_foreground` | bool | App foreground'dami |
| `pending_xp_minutes` | int | Kutayotgan XP daqiqalari (PendingProcessor) |
| `pending_streak_date` | String | Kutayotgan streak sanasi |
| `pending_completion_count` | int | Kutayotgan to'liq seanslar |
| `daily_goal_seconds` | int | Kunlik maqsad (default 7200 = 2 soat) |
| `today_focus_seconds` | int | Bugungi fokus (yagona manba) |
| `today_completed_sessions` | int | Bugun to'liq tugagan seanslar |
| `today_xp_earned` | int | Bugun olingan XP (haqiqiy XP, daqiqa * 10) |
| `last_focus_date` | String | YYYY-MM-DD, daily_reset_service ishlatadi |
| `last_tracked_day` | int | Background service'ning eski kun kalitlovchisi |
| `longest_session_minutes` | int | Eng uzun yakunlangan seans |
| `light_focus_total_seconds` | int | Yengil Fokus jami vaqti (kumulativ) |
| `custom_activities` | StringList | Foydalanuvchi qo'shgan faoliyatlar |
| `activity_progress_YYYY-MM-DD` | String | Kunlik activity breakdown (query string) |
| `focus_history_YYYY-MM-DD` | String | Kunlik DayRecord (JSON) |
| `block_attempts_YYYY-MM-DD` | String | Kunlik bloklangan ilova urinishlari (JSON map) |
| `app_name_cache` | String | package → display name (JSON map) |
| `app_icon_<package>` | String | base64 encoded PNG (per app) |
| `selected_sound` | String | Tabiat ovozi: none/rain/forest |
| `pending_xp_seconds` | int | Kutayotgan XP sekundlari (sekund aniqligida) |
| `totalSeconds` | int (Firestore) | Foydalanuvchining jami fokus sekundlari |
| `registration_date` | String | ISO8601 ro'yxatdan o'tgan sana |
| `cloud_sync_mode` | String | `auto` yoki `manual` |
| `cloud_pending_dates` | StringList | Firestore'ga yuborilmagan kun sanalari |
| `cloud_last_sync_iso` | String | So'nggi sync vaqti |
| `last_progress_reset` | String | Goal Missed notif idempotency |

---

## OXIRGI O'ZGARISHLAR

### 1. Calendar feature (avval qilingan)
- Detail panel, registration day 🎉, ranglar (yashil/sariq/qizil), drill-down
- Day cell `borderRadius: 10`, `childAspectRatio: 1.0` (kvadrat)

### 2. Faoliyat tizimi
- Mock'lar tozalandi, default `[]`
- `_selectedActivityIndex = -1` default — foydalanuvchi o'zi tanlasagina activity_progress yoziladi
- Chuqur Fokus rejimida ko'rinadi, Yengil Fokus'da yashirin

### 3. Stats — to'liq real ma'lumotlar
- Fokus Balli, haftalik o'rtacha, maqsad %, haftalik/oylik chartlar
- Aqlli Tahlil (PRO): real solishtirish, prognoz, streak forecast
- `_buildSessionItem`'da inner GestureDetector olib tashlandi (eski mock chart ko'rinmaydi)
- Bar chart maxVal=0 bug'i tuzatildi, ustun tepasida vaqt yoziladi
- Jami seanslar bugungi history kalitini istisno qiladi (double count fix)

### 4. Cloud Backup (avval qilingan)
- `cloud_sync_service.dart`, `cloud_backup_screen.dart`, `internet_checker.dart`
- Auto rejim → "Avtomatik yoqilgan" yashil tasdiq karta
- Manual rejim → "Bulutga saqlash" ko'k tugma
- Circuit breaker — 3 ta xato → to'xtaydi

### 5. Permissions screen bug fix (avval qilingan)
- Usage Access cycling tuzatildi: har chaqirig'da haqiqiy AppUsage API

### 6. Daraja tizimi yangilandi
- 16 ta daraja, hour-based XP thresholds (1h/3h/7h/.../1800h)
- `LevelService.levelXpThresholds`, `levelFromXp()`, `levelInfoFromXp()`
- Level screen: XP+daqiqa badge yuqori o'ng burchakda
- "1.4 soat qoldi" → "1s 25daq qoldi"
- One-time migration: eski user'lar level qayta hisoblanadi (`migrateLevelIfNeeded`)

### 7. Daily reset (`daily_reset_service.dart`) ⭐
- App launch va resume'da `checkAndResetIfNewDay()`
- `last_focus_date` to'liq ISO sana
- Kechagi data history'ga, today_* → 0
- Background service uxlab qolsa ham ishlaydi

### 8. XP/Sessions double-counting fix
- `_updateProgress`'dan `addXP` olib tashlandi (faqat PendingProcessor)
- Stats jami seanslar bugungi `focus_history_$today` kalitini istisno qiladi
- `addTodayXpFromMinutes` ichida `* 10` (avval daqiqa saqlanardi)

### 9. Default daily goal: 4 soat → 2 soat
- 8 ta faylda `14400` → `7200`
- Mavjud user'lar uchun saqlanadi (faqat yangi user'larga 2s default)

### 10. Iron Discipline mode-aware
- `_effectiveStrict = _isStrictMode && _selectedMode == 0`
- `timer_is_strict` SharedPreferences kalit
- block_list_screen: dialog faqat strict + running paytida

### 11. Light Focus tracking + UI ⭐
- `light_focus_total_seconds` background service yangilab turadi
- Stats'da alohida "Yengil Fokus" karta
- Yengil Fokus rejimida faoliyat bo'limi yashirin
- "Ruxsat Berilganlar" mock UI olib tashlandi (faqat Tabiat Ovozlari qoldi)

### 12. Top blocked attempts + icon cache
- `incrementBlockAttempt(package)` background service'da
- `block_attempts_YYYY-MM-DD` JSON map saqlanadi
- 30 kunlik aggregation, top 5
- `app_name_cache` + `app_icon_<package>` (base64 PNG)
- block_list_screen ilova bloklaganda icon'ni saqlaydi + backfill
- stats_screen: ikonkasi yo'q ilovalar uchun `installed_apps.getAppInfo()` fonida

### 13. Background isolate prefs.reload() fix
- Alarm overlay app fonida ham chiqadi (`app_in_foreground` jonli o'qiladi)
- Mavjud bloklash overlay'i yopiladi → keyin alarm overlay'i
- Permission check + CrashLogger source-tagging

### 14. CrashLogger filtri
- `_shouldIgnore(error)` — permission-denied, network-* xatolarni o'tkazib yuboradi
- Dashboard banner ham eski expected-error'larni auto-clear qiladi

### 15. iOS-style timer completion dialog
- Material Dialog → `CupertinoAlertDialog`

### 16. Tabiat Ovozlari ⭐ — to'liq ishlaydi
- **`soundscape_service.dart`** yaratildi
- `audioplayers: ^6.1.0` qo'shildi
- 2 ta MP3 fayl Archive.org (CC0) dan: rain.mp3, forest.mp3 (cafe/white_noise olib tashlandi)
- Sound picker: 3 ta variant (Yo'q / Yomg'ir / O'rmon)
- **FAQAT Yengil Fokus rejimida** ijro etiladi
- Timer start/pause/resume/stop/dispose bilan sync
- Strict dialog tasdiqlanganda stop chaqiriladi
- ReleaseMode.loop, volume 60%
- Silent fail agar fayl yo'q

### 17. Firestore rules ⭐
- `firestore.rules` fayl yaratildi
- `users/{uid}` + `history/{date}` + `plans/{planId}` matches
- Foydalanuvchi Firebase Console'ga bir martalik ko'chiradi (Publish)

### 18. Sekund aniqligida tracking ⭐
- Activity progress, XP, daily total — barchasi sekundda
- `_updateProgress()` `activity_progress_YYYY-MM-DD`'ga sekund yozadi (avval daqiqa)
- `_formatActivityProgress(int seconds)` — "Xd Ys" formatda
- `LevelService.addXpFromSeconds(seconds)` — 6 sek = 1 XP (`(seconds*10/60).round()`)
- `BackgroundService.addTodayXpFromSeconds()` + `queuePendingXpSeconds()`
- `PendingResultsProcessor` ikkala queue'ni o'qiydi: `pending_xp_minutes` + `pending_xp_seconds`
- Stop threshold: >= 1 sek (avval 60 sek edi — qisqa seanslar yo'qotilardi)
- Stats haftalik activity chart sekundda — "1s 30 daq 45 sek" format
- Firestore `users/{uid}.totalSeconds` field qo'shildi

### 19. Activity toggle UI
- Bita bossa tanlanadi, qaytadan bossa tanlash bekor qilinadi
- `_selectedActivityIndex = -1` default
- Sekund aniqligi bilan ham faoliyat to'g'ri yoziladi

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
  xp: int                        # Bugun olingan XP (haqiqiy XP qiymati)
  activities: Map<String, int>   # {"Dasturlash": 90, "O'qish": 60}
  updatedAt: Timestamp
}
```

### Firestore Rules (`firestore.rules` fayl)
- `users/{userId}` — faqat egasi o'qishi/yozishi mumkin
- `users/{userId}/history/{date}` — egasi uchun cheksiz
- `users/{userId}/plans/{planId}` — kelajak uchun tayyor

---

## MUHIM ESLATMALAR

- Samsung qurilmalarda `SYSTEM_ALERT_WINDOW` jimgina bekor qilinishi mumkin → `CrashLogger`ga yoziladi
- Background isolate Firebase Auth/Firestore'ga kira olmaydi → SharedPreferences pending queue
- `prefs.reload()` background isolate'da KRITIK — main isolate yozgan o'zgarishlar uchun
- `FlutterRingtonePlayer().stop()` faqat background isolate'da (u yerda boshlangan)
- Cloud Sync internet kerak bo'lgan tugma bosilgandagina `ensureOnline` chaqiriladi
- Firestore offline persistence yoqilgan (`main.dart`) → 100 MB cache avtomatik
- Activity kalitlari 2 xil: `activities.coding` (legacy) yoki ism ("Dasturlash")
- `_activityDisplayName(key, lang)` — legacy kalitlarni tarjima qiladi
- `connectivity_plus` v6+ `List<ConnectivityResult>` qaytaradi — `.any((r) => r != none)`
- XP yagona manba — `PendingResultsProcessor`, foreground'dan addXP chaqirilmaydi
- `today_focus_seconds` yagona progress manba — `daily_progress_hours` ishlatilmaydi
- Audio player main isolate'da ishlaydi — app foreground'da bo'lganda
- `firestore.rules` Firebase Console'da Publish qilinishi kerak (kelajak premium uchun)
- Mp3 fayllar `assets/sounds/`'da bundled — foydalanuvchi tortib olmaydi
- 1 daqiqa fokus = 10 XP (`level_service.dart`, formula yagona joyda)
- 16 ta daraja, soat-asosli chegaralar (1, 3, 7, 15, 30, 50, 80, 120, 180, 250, 400, 600, 900, 1300, 1800)
- Sekund aniqligida tracking: 6 sek = 1 XP, qisqa seanslar (10 sek) ham hisoblanadi
- Audio FAQAT Yengil Fokus rejimida, sound picker 3 variant (none/rain/forest)
- Activity toggle: tanlash/bekor qilish bita bosish bilan
