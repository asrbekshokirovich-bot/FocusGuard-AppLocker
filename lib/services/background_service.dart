import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide NotificationVisibility;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_usage/app_usage.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'timer_notification_service.dart';
import 'app_translation_service.dart';
import 'crash_logger.dart';
import 'focus_history_service.dart';

bool _isServiceInitialized = false;

Future<void> initializeBackgroundService() async {
  if (kIsWeb || _isServiceInitialized) return;
  
  try {
    // Android 8+ uchun bildirishnoma kanalini avval yaratish kerak.
    // Aks holda startForeground "Bad notification" xatosi bilan ilova yiqiladi.
    const channel = AndroidNotificationChannel(
      'app_locker_channel',
      'App Locker Service',
      description: 'Keeps app blocker running in background',
      importance: Importance.low,
    );
    final notifications = FlutterLocalNotificationsPlugin();
    final androidNotifications = notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidNotifications?.createNotificationChannel(channel);

    // Pre-create the overlay's foreground service channel with LOW
    // importance so the "Ilova cheklangan" banner doesn't pop with a
    // sound/vibration each time the cover appears.
    //
    // The exact channel id used by flutter_overlay_window 0.5.0 is
    // "Overlay Channel" (with a space, see OverlayConstants.CHANNEL_ID
    // in the package source). Once a channel exists Android keeps our
    // settings even if the package later recreates a channel with the
    // same id at IMPORTANCE_DEFAULT.
    //
    // IMPORTANCE_LOW (not MIN) is required: Samsung One UI's
    // EdgeLightingPolicyManager evicts MIN-priority foreground service
    // notifications, which kills the overlay process and makes the
    // cover blink off ~5s after it appears. LOW is the lowest level
    // Samsung keeps for sticky foreground services.
    await androidNotifications?.createNotificationChannel(
      const AndroidNotificationChannel(
        'Overlay Channel',
        'Overlay Channel',
        description: 'Blocking screen for restricted apps',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );

    // ───────────────── TAYMER TUGADI KANALI ─────────────────
    // Foydalanuvchi tayyorlangan vaqt tugaganda yangrash uchun
    // alohida kanal. Importance.max + playSound + vibration —
    // app yopiq, telefon bloklangan bo'lsa ham foydalanuvchi
    // eshitishi va ko'rishi uchun. Kanal bir marta yaratilgach,
    // Android tomon sozlamalarini saqlab qoladi.
    await androidNotifications?.createNotificationChannel(
      const AndroidNotificationChannel(
        'timer_completed_channel',
        'Taymer Tugadi',
        description: 'Fokus taymer tugaganda chiqadigan asosiy bildirishnoma',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );

    // #6/#7: Yangi YUMSHOQ taymer-tugadi kanali. Eski 'timer_completed_channel'
    // Importance.max + alarm uslubida edi (qo'pol). Bu kanal yumshoqroq:
    // heads-up bo'ladi, tizimning standart (yumshoq) bildirishnoma ovozi bilan,
    // delikat vibratsiya. Kanal ID yangi — shunda eski qattiq sozlama
    // (Android kanal sozlamasini bir marta yaratgach saqlab qoladi) ta'sir
    // qilmaydi.
    await androidNotifications?.createNotificationChannel(
      const AndroidNotificationChannel(
        'timer_done_soft',
        'Taymer tugadi',
        description: 'Fokus taymer tugaganda yumshoq, motivatsion bildirishnoma',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
    // Lekin eng xavfsizi pluginni chaqirishdan oldin tekshirish
    final service = FlutterBackgroundService();

    // Avval xizmat allaqachon sozlanganini tekshiramiz
    // (ba'zi qurilmalarda configure ni qayta chaqirish crash beradi)
    //
    // foregroundServiceNotificationId 888 dan 7777 ga ko'chirildi —
    // chunki avvalgi qiymat StreakReminderService (_reminderId=888) va
    // showGoalMissedNotification (id=888) bilan to'qnash kelar edi.
    // Android foreground service notifikatsiyasini doimiy (ongoing)
    // qilib qo'yadi, shuning uchun ID 888 ga keladigan har qanday
    // user-facing notifikatsiya merge bo'lib, swipe bilan o'chmas edi.
    // Endi 7777 — service uchun, 888 — streak/goal uchun bo'lib,
    // streak/goal notifikatsiyalari normal (dismissible) bo'ladi.
    // i18n — initial notifikatsiya matnini foydalanuvchi tanlagan
    // tilda ko'rsatamiz. Main isolate'da AppTranslationService init
    // qilingan, shuning uchun bu yerda darhol tarjima qaytaradi.
    final lang = AppTranslationService();
    final initialTitle =
        lang.translate('service_notif.idle_title') ?? 'Focus Guard';
    final initialContent =
        lang.translate('service_notif.idle_content') ?? 'Monitoring faol';

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'app_locker_channel',
        initialNotificationTitle: initialTitle,
        initialNotificationContent: initialContent,
        foregroundServiceNotificationId: 7777,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );
    _isServiceInitialized = true;
  } catch (e) {
    debugPrint('Service configure error: $e');
  }
}

/// Pauza budjeti qoidasi — YAGONA manba. UI dialogi, focus_timer_service
/// prewrite'i va background 'startTimer' listener'i hammasi shu funksiyani
/// chaqiradi. Qoidani o'zgartirish faqat shu yerda qilinadi, aks holda
/// dialog va'dasi bilan haqiqiy budjet farq qilib qoladi.
///   Premium yoki Yengil Fokus → cheksiz.
///   ≤30 daq → pauza yo'q · 31–60 daq → 5 daq · 60+ daq → 10 daq.
({int seconds, bool unlimited}) computePauseBudget({
  required int minutes,
  required bool isPremium,
  required bool isLight,
}) {
  if (isPremium || isLight) return (seconds: 0, unlimited: true);
  if (minutes <= 30) return (seconds: 0, unlimited: false);
  if (minutes <= 60) return (seconds: 300, unlimited: false);
  return (seconds: 600, unlimited: false);
}

@pragma('vm:entry-point')
/// Faol jadval(lar) bo'yicha hozir bloklanishi kerak bo'lgan ilovalar to'plami.
/// `focus_schedules` (ScheduleScreen saqlaydi) JSON ro'yxatini o'qiydi; joriy
/// vaqt va kun biror yoqilgan jadval oynasiga tushsa, o'sha jadvalning
/// ilovalarini qaytaradi. Tungi oyna (masalan 23:00–07:00) ham qo'llab-
/// quvvatlanadi. Bu doimiy `blocked_apps`ga QO'SHIMCHA — uni o'zgartirmaydi.
Set<String> activeScheduleBlockedApps(SharedPreferences prefs) {
  try {
    final raw = prefs.getString('focus_schedules');
    if (raw == null || raw.isEmpty) return <String>{};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String>{};
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final weekday = now.weekday; // 1=Mon .. 7=Sun
    final Set<String> result = <String>{};
    for (final item in decoded) {
      // Har bir jadval elementini ALOHIDA himoyalaymiz — bitta buzuq
      // yozuv butun ro'yxatni bekor qilmasin (boshqa jadvallar ishlasin).
      try {
        if (item is! Map) continue;
        if (item['enabled'] != true) continue;
        final daysRaw = item['days'];
        final List<int> days = [];
        if (daysRaw is List) {
          for (final e in daysRaw) {
            if (e is num) days.add(e.toInt());
          }
        }
        if (days.isNotEmpty && !days.contains(weekday)) continue;
        final start = (item['start'] as num?)?.toInt() ?? 0;
        final end = (item['end'] as num?)?.toInt() ?? 0;
        bool inWindow;
        if (start == end) {
          inWindow = false;
        } else if (start < end) {
          inWindow = nowMin >= start && nowMin < end;
        } else {
          // Tungi oyna: masalan 23:00–07:00 (yarim tundan o'tadi).
          inWindow = nowMin >= start || nowMin < end;
        }
        if (!inWindow) continue;
        final appsRaw = item['apps'];
        if (appsRaw is List) {
          for (final a in appsRaw) {
            if (a != null) result.add(a.toString());
          }
        }
      } catch (_) {
        continue;
      }
    }
    return result;
  } catch (_) {
    return <String>{};
  }
}

void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // MUHIM: AppTranslationService().init() avval shu yerda (eng tepada)
  // chaqirilardi — lekin u `await` bo'lgani uchun, agar UI startService()
  // dan keyin darrov invoke('startTimer') yuborsa, event 'startTimer'
  // listeneri (pastda) hali RO'YXATDAN O'TMAGAN paytda kelib YO'QOLARDI.
  // Natijada taymer sanamasdi va bloklash ishlamasdi (Light Focus ham).
  // Yechim: barcha service.on(...) listenerlarni AVVAL ro'yxatdan
  // o'tkazamiz (sinxron, await yo'q), keyin init() ni chaqiramiz.

  if (service is AndroidServiceInstance) {
    // Android 12+ uchun xizmatni darhol foreground qilish shart
    service.setAsForegroundService();

    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    // Bildirishnoma sozlamalari
    service.setForegroundNotificationInfo(
      title: "Focus Guard",
      content: "Tayyorlanmoqda...",
    );
  }

  // Taymer holati o'zgaruvchilari
  int remainingSeconds = 0;
  bool isTimerRunning = false;
  // Pauza holati alohida kuzatiladi: isTimerRunning=false bo'lishi
  // "to'xtagan" yoki "umuman boshlanmagan" degani ham bo'lishi mumkin.
  // isPaused=true bo'lganda foydalanuvchi taymerni vaqtincha to'xtatgan
  // va `remainingSeconds` saqlanib turibdi — "Davom etish" tugmasi
  // shu qiymatdan davom ettirishi kerak (start qilib qayta boshlamasligi
  // kerak). UI shu bayroq orqali "Pause" yoki "Davom etish" matnini
  // ko'rsatadi va to'g'ri method'ni chaqiradi.
  bool isPaused = false;
  // Joriy sessiya boshlangandagi to'liq sekundlar soni — partial XP
  // hisoblashda kerak (foydalanuvchi taymer to'liq tugaguncha kutmasdan
  // to'xtatsa, qancha vaqt o'tganini bilish uchun).
  int sessionInitialSeconds = 0;
  String modeName = "";
  String modeIcon = "";
  String levelTitle = "";
  bool isStrict = false;
  // Yengil Fokus rejimi flagi — UI explicit uzatadi. Avval `!isStrict` proxy
  // ishlatardik, lekin Deep Focus + Strict OFF ham `light` deb hisoblanardi.
  bool isLightMode = false;
  // Yengil Fokus seconds counter — saqlash oralig'i ichida (10 sek) yo'qotmaslik
  // uchun memoryda yig'amiz, stop/pause/complete'da flush qilamiz.
  int lightFocusBuffer = 0;

  // ───────────── Pauza budjeti (Chuqur Fokus) ─────────────
  // Bepul foydalanuvchida pauza vaqti cheklangan:
  //   • ≤30 daq seans: 0 (pauza yo'q)
  //   • 30–60 daq: jami 5 daqiqa (300 sek)
  //   • 60+ daq: jami 10 daqiqa (600 sek)
  // Pauza paytida bloklangan ilovalardan foydalanish mumkin — shu vaqt
  // budjetdan yechiladi. Budjet tugasa taymer avtomatik davom etadi va
  // bloklash qaytadi. Premium foydalanuvchida pauza cheksiz.
  int pauseRemainingSeconds = 0;
  bool pauseUnlimited = false;

  // Kunlik maqsad o'zgaruvchilari
  int todayFocusSeconds = 0;
  int dailyGoalSeconds = 7200; // Standart 2 soat (foydalanuvchi o'zgartira oladi)
  bool analysisSent = false;
  int lastDay = DateTime.now().day;

  // Overlay holati o'zgaruvchilari.
  // currentBlockedApp — overlay hozir qaysi paket uchun ko'rsatilmoqda;
  // bir paketga bir marta vibratsiya berishimiz uchun.
  // suppressUntil — foydalanuvchi "Orqaga qaytish" tugmasini bossa,
  // shundan keyin qisqa vaqt overlayni qayta ko'rsatmaymiz (HOME intent
  // uchgunicha). Bloklanmagan/ketma-ket ticks hisobi 250ms timer ichida
  // lokal (notBlockedFastTicks).
  String? currentBlockedApp;
  DateTime? suppressUntil;

  // Taymerni saqlash va yuklash
  final prefs = await SharedPreferences.getInstance();

  // ─────────────────────────────────────────────────────────────
  // PENDING QUEUE — background → main isolate o'rtasidagi ma'lumot
  // almashinuvi. Background service Firebase Auth context'iga ega
  // emas (alohida isolate), shuning uchun XP va streak yangilanishini
  // bevosita Firestore'ga yoza olmaymiz. Buning o'rniga
  // SharedPreferences'ga "pending" qiymatlarini yozamiz; foydalanuvchi
  // app'ni ochganda PendingResultsProcessor (Faza 2) shu qiymatlarni
  // ko'tarib, LevelService.addXP() va updateStreak() chaqiradi va
  // pending flag'larni tozalaydi.
  //
  // Kalitlar:
  //   pending_xp_minutes      (int)    — kutilayotgan XP daqiqalari
  //   pending_streak_date     (String) — YYYY-MM-DD, bugun fokus boshlandi
  //   pending_completion_count(int)    — to'liq tugagan sessiyalar soni
  // ─────────────────────────────────────────────────────────────

  String todayDateKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Bir kun uchun activity progress map'ini SharedPreferences'dan o'qiydi.
  /// `activity_progress_YYYY-MM-DD` kalitidan URL-encoded query string'ni
  /// parslab Map<String, int> ko'rinishida qaytaradi.
  Map<String, int> activitiesForDay(String dateKey) {
    try {
      final progressJson = prefs.getString('activity_progress_$dateKey');
      if (progressJson == null) return const {};
      final decoded = Uri.splitQueryString(progressJson);
      return decoded.map((k, v) => MapEntry(k, int.tryParse(v) ?? 0));
    } catch (_) {
      return const {};
    }
  }

  Future<void> queuePendingXP(int minutes) async {
    if (minutes <= 0) return;
    final existing = prefs.getInt('pending_xp_minutes') ?? 0;
    await prefs.setInt('pending_xp_minutes', existing + minutes);
    debugPrint('[Pending] +$minutes XP min, total=${existing + minutes}');
  }

  /// Sekund aniqligida XP queue — qisqa seanslar (10 sek, 30 sek) uchun.
  /// Daqiqalar pending'iga qaramay alohida saqlanadi va PendingResultsProcessor
  /// uni o'qib `LevelService.addXpFromSeconds()` chaqiradi.
  Future<void> queuePendingXpSeconds(int seconds) async {
    if (seconds <= 0) return;
    final existing = prefs.getInt('pending_xp_seconds') ?? 0;
    await prefs.setInt('pending_xp_seconds', existing + seconds);
    debugPrint('[Pending] +$seconds XP sec, total=${existing + seconds}');
  }

  Future<void> queueStreakForToday() async {
    final today = todayDateKey();
    final existing = prefs.getString('pending_streak_date');
    if (existing == today) return; // bugun uchun allaqachon qo'yilgan
    await prefs.setString('pending_streak_date', today);
    debugPrint('[Pending] streak date set: $today');
  }

  Future<void> queueCompletion() async {
    final n = prefs.getInt('pending_completion_count') ?? 0;
    await prefs.setInt('pending_completion_count', n + 1);
  }

  /// Bugungi seans hisoblagichini bittaga oshirish (Calendar detail
  /// panel ko'rsatadi: "bugun 3 marta to'liq seans"). Kun reset bo'lganda
  /// 0 ga tushadi va history'ga yoziladi.
  Future<void> incrementTodaySessions() async {
    final n = prefs.getInt('today_completed_sessions') ?? 0;
    await prefs.setInt('today_completed_sessions', n + 1);
  }

  /// Bugungi XP hisoblagichini oshirish. Parametr — DAQIQALAR (eski API).
  /// Ichkarida 1 daqiqa = 10 XP formulasi qo'llaniladi.
  /// XP'ni vaqtdan formula bilan hisoblash — yagona joy. 1 daq = 10 XP.
  /// 6 sek = 1 XP. Hech qaerda boshqa formula ishlatilmasligi kerak.
  int xpFromSeconds(int seconds) => (seconds * 10 / 60).round();

  /// today_xp_earned ni today_focus_seconds'dan qayta hisoblab yozadi.
  /// Yagona haqiqat manbai: today_focus_seconds. XP — formula bilan.
  /// Bu chaqirilgandan keyin vaqt va XP doim bir-biriga aniq mos keladi.
  Future<void> syncTodayXpFromFocusSeconds() async {
    final xp = xpFromSeconds(todayFocusSeconds);
    await prefs.setInt('today_xp_earned', xp);
  }

  /// today_focus_seconds'ga sekund qo'shish + XP'ni qayta hisoblash.
  /// Late detection (background uxlab qolgan paytda tugagan seans) uchun:
  /// tick loop bu vaqtni ko'rmagan bo'lsa, manual qo'shish kerak.
  Future<void> addToFocusSeconds(int seconds) async {
    if (seconds <= 0) return;
    todayFocusSeconds += seconds;
    await prefs.setInt('today_focus_seconds', todayFocusSeconds);
    await syncTodayXpFromFocusSeconds();
  }

  /// DEPRECATED: bu metodlar endi XP'ni alohida qo'shmaydi. XP yagona
  /// formula bilan `today_focus_seconds`'dan keladi. Tick loop allaqachon
  /// focus_seconds'ni oshirgan bo'ladi (natural complete, partial stop). Faqat
  /// XP'ni qayta sinxronlashtirish kerak. Late detection holatida esa
  /// `addToFocusSeconds()` chaqirilishi kerak — tick loop ishlamagan.
  Future<void> addTodayXpFromMinutes(int minutes) async {
    if (minutes <= 0) return;
    await syncTodayXpFromFocusSeconds();
  }

  Future<void> addTodayXpFromSeconds(int seconds) async {
    if (seconds <= 0) return;
    await syncTodayXpFromFocusSeconds();
  }

  /// Eng uzun seans sekundlarini yangilash. Statistika ekrani shu qiymatdan
  /// foydalanadi ("Eng uzun seans" karta). Faqat o'sganda yoziladi.
  /// Sekund aniqligida — qisqa seanslar (1-59 sek) ham yo'qotilmaydi.
  /// Backward-compat uchun `longest_session_minutes`'ni ham yangilab qo'yamiz.
  Future<void> updateLongestSessionSeconds(int seconds) async {
    if (seconds <= 0) return;
    final current = prefs.getInt('longest_session_seconds') ?? 0;
    if (seconds > current) {
      await prefs.setInt('longest_session_seconds', seconds);
      await prefs.setInt('longest_session_minutes', seconds ~/ 60);
    }
  }

  /// Yengil Fokus bufferini Saqlangan jami qiymatga qo'shamiz va resetlaymiz.
  /// Stop/pause/complete'da chaqiriladi — 0-9 sek qoldiq yo'qolmasligi uchun.
  Future<void> flushLightFocusBuffer() async {
    if (lightFocusBuffer <= 0) return;
    final lightTotal = prefs.getInt('light_focus_total_seconds') ?? 0;
    await prefs.setInt('light_focus_total_seconds', lightTotal + lightFocusBuffer);
    lightFocusBuffer = 0;
  }

  /// Bloklangan ilovaga kirishga urinish — statistikaga +1. Har kun uchun
  /// alohida `block_attempts_YYYY-MM-DD` kalitida JSON map saqlanadi:
  ///   {"com.instagram.android": 5, "com.tiktok": 3}
  /// Statistika ekrani so'nggi 30 kunni o'qib top eng ko'p urinilgan
  /// ilovalarni ko'rsatadi.
  Future<void> incrementBlockAttempt(String packageName) async {
    if (packageName.isEmpty) return;
    try {
      final key = 'block_attempts_${todayDateKey()}';
      final raw = prefs.getString(key);
      Map<String, dynamic> data = {};
      if (raw != null) {
        try {
          data = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {}
      }
      final current = (data[packageName] as num?)?.toInt() ?? 0;
      data[packageName] = current + 1;
      await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      debugPrint('[BlockAttempt] increment failed: $e');
    }
  }

  // Har soniyada UI ga timerTick yuboramiz — stream chaqirig'i arzon,
  // dashboard sanog'i shu sababli aniq 1s qadamda yangilanadi
  // (45 → 44 → 43 ...). Notification update'i esa qimmatroq, shuning
  // uchun uni har 5 soniyada chaqiramiz — `updateNotification` flag
  // bilan boshqariladi.
  void syncTimer({bool updateNotification = true}) {
    service.invoke('timerTick', {
      'seconds': remainingSeconds,
      'isRunning': isTimerRunning,
      // isPaused ham UI'ga yuboriladi — Pause bug fix uchun. UI shu
      // bayroq orqali Pause/Resume tugmasini to'g'ri ko'rsatadi va
      // bosilganda startTimer o'rniga resumeTimer'ni chaqiradi.
      'isPaused': isPaused,
      'modeName': modeName,
      'modeIcon': modeIcon,
      // Pauza budjeti — UI "Pauza: 3:45 qoldi" ko'rsatadi va budjet 0 bo'lsa
      // pauza tugmasini o'chiradi.
      'pauseRemaining': pauseRemainingSeconds,
      'pauseUnlimited': pauseUnlimited,
      // Joriy SEANSNING rejimi — UI stop/pauza qulflarini jonli tab emas,
      // haqiqiy seans rejimiga bog'lashi uchun (ekran qayta ochilsa ham).
      'isLight': isLightMode,
    });

    if (updateNotification && service is AndroidServiceInstance) {
      int m = remainingSeconds ~/ 60;
      int s = remainingSeconds % 60;
      String timeStr = "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";

      // i18n — foydalanuvchi tanlagan tilga moslab matnlarni olamiz.
      // AppTranslationService onStart ichida init qilingan, shu sababli
      // bu yerda translate() to'g'ri til qaytaradi.
      final lang = AppTranslationService();
      final idleTitle =
          lang.translate('service_notif.idle_title') ?? 'Focus Guard';
      final idleContent =
          lang.translate('service_notif.idle_content') ?? 'Monitoring faol';
      final runningPrefix =
          lang.translate('service_notif.running_prefix') ?? '⏱ Focus Guard';
      final pausedPrefix =
          lang.translate('service_notif.paused_prefix') ?? '⏸ Focus Guard';
      final pausedLabel =
          lang.translate('service_notif.paused_label') ?? 'Pauza';

      // Notifikatsiya title — 3 ta holatga qarab:
      //   • Taymer ishlayapti: "⏱ Focus Guard · 24:30"
      //   • Pauza:             "⏸ Focus Guard · 24:30"
      //   • Default monitoring: "Focus Guard"
      String title;
      String content;
      if (isTimerRunning) {
        title = "$runningPrefix · $timeStr";
        content = "$modeIcon $modeName | $levelTitle";
      } else if (isPaused) {
        title = "$pausedPrefix · $timeStr";
        content = "$pausedLabel · $modeIcon $modeName";
      } else {
        title = idleTitle;
        content = idleContent;
      }

      service.setForegroundNotificationInfo(
        title: title,
        content: content,
      );
    }
  }

  service.on('startTimer').listen((event) async {
    if (event == null) return;
    // Null-safe parsing — noto'g'ri/null qiymat kelsa ham listener crash
    // bo'lmasin (avval `as int` hard cast edi, null kelsa exception berardi
    // va isTimerRunning=true qo'yilmasdan timer boshlanmasdi).
    final minutes = (event['minutes'] as num?)?.toInt() ?? 0;
    if (minutes <= 0) {
      debugPrint('[BackgroundTimer] startTimer: invalid minutes=$minutes');
      return;
    }
    remainingSeconds = minutes * 60;
    sessionInitialSeconds = remainingSeconds; // partial XP uchun saqlash
    modeName = (event['modeName'] as String?) ?? "";
    modeIcon = (event['modeIcon'] as String?) ?? "";
    levelTitle = (event['levelTitle'] as String?) ?? "";
    isStrict = (event['isStrict'] as bool?) ?? false;
    // Yengil Fokus rejimini UI explicit uzatadi (mode==1). Avval `!isStrict`
    // proxy ishlatardik — Deep Focus + Strict OFF holatida noto'g'ri "Light"
    // deb yozardi. Endi flag aniq UI'dan keladi.
    isLightMode = (event['isLight'] as bool?) ?? false;
    lightFocusBuffer = 0; // yangi seans — buffer reset
    await prefs.setBool('timer_is_light', isLightMode);
    isTimerRunning = true;
    isPaused = false; // yangi sessiya — paused emas

    // ───────── Pauza budjeti hisoblash ─────────
    // Yagona manba — computePauseBudget (UI dialogi va prewrite ham shuni
    // chaqiradi, qoidalar hech qachon farq qilmaydi).
    final bool isPremium = (event['isPremium'] as bool?) ?? false;
    final budget = computePauseBudget(
        minutes: minutes, isPremium: isPremium, isLight: isLightMode);
    pauseUnlimited = budget.unlimited;
    pauseRemainingSeconds = budget.seconds;
    await prefs.setInt('focus_pause_remaining_seconds', pauseRemainingSeconds);
    await prefs.setBool('focus_pause_unlimited', pauseUnlimited);

    // Tugash vaqtini saqlash
    final endTime = DateTime.now().add(Duration(seconds: remainingSeconds));
    await prefs.setInt('timer_end_timestamp', endTime.millisecondsSinceEpoch);
    await prefs.setInt('session_initial_seconds', sessionInitialSeconds);
    // Yangi seans — late-detection uchun "qancha sekund allaqachon hisobga
    // olingan" hisoblagichini nolga tushiramiz (FIX: double-credit).
    await prefs.setInt('session_credited_seconds', 0);
    await prefs.setBool('timer_is_running', true);
    await prefs.setBool('timer_is_paused', false);
    // Temir Intizom — block_list_screen shu flagni o'qib toggle'larni
    // qulflaydi (foydalanuvchi seans davomida bloklangan ilovani o'chira olmaydi).
    await prefs.setBool('timer_is_strict', isStrict);
    await prefs.setString('timer_mode_name', modeName);
    await prefs.setString('timer_mode_icon', modeIcon);
    await prefs.setString('timer_level_title', levelTitle);

    // Bugun birinchi marta fokus boshlandi — streak update'ni
    // pending queue'ga qo'yamiz. Foydalanuvchi app'ni keyin ochganda
    // PendingResultsProcessor LevelService.updateStreak() chaqiradi.
    await queueStreakForToday();

    syncTimer();
  });

  service.on('stopTimer').listen((event) async {
    // Partial XP: foydalanuvchi taymerni to'liq tugatishini kutmadi.
    // SEKUND aniqligida XP beriladi — hatto 10 sekund ham hisoblanadi
    // (1 daqiqa = 10 XP, 6 sek = 1 XP).
    if (sessionInitialSeconds > 0 && remainingSeconds < sessionInitialSeconds) {
      final elapsed = sessionInitialSeconds - remainingSeconds;
      if (elapsed >= 1) {
        await queuePendingXpSeconds(elapsed);
        await addTodayXpFromSeconds(elapsed);
        // Partial stop ham seans deb hisoblanadi (foydalanuvchi vaqt sarflagan).
        await incrementTodaySessions();
        // Eng uzun seans — sekund aniqligida, qisqa seans (1-59 sek) ham
        // hisoblansin (avval daqiqaga aylantirilardi → 0 bo'lib qolardi).
        await updateLongestSessionSeconds(elapsed);
        debugPrint(
            '[BackgroundTimer] partial stop: ${elapsed}s queued for XP + session counted');
      }
      // Yengil Fokus bufferini flush — qisqa qoldiq yo'qolmasin.
      await flushLightFocusBuffer();
      // Calendar uchun ham bugungi kun history'ga darrov yozib qo'yamiz
      // (todayFocusSeconds tick loop'da yangilangan).
      await FocusHistoryService.instance.recordDay(
        date: DateTime.now(),
        seconds: todayFocusSeconds,
        goal: dailyGoalSeconds,
        sessions: prefs.getInt('today_completed_sessions') ?? 0,
        xp: prefs.getInt('today_xp_earned') ?? 0,
        activities: activitiesForDay(todayDateKey()),
      );
    }

    isTimerRunning = false;
    isPaused = false; // to'liq to'xtatildi
    remainingSeconds = 0;
    sessionInitialSeconds = 0;
    isStrict = false;
    isLightMode = false;
    await prefs.remove('timer_end_timestamp');
    await prefs.remove('timer_remaining_seconds');
    await prefs.remove('session_initial_seconds');
    await prefs.remove('session_credited_seconds');
    await prefs.setBool('timer_is_running', false);
    await prefs.setBool('timer_is_paused', false);
    await prefs.setBool('timer_is_strict', false);
    await prefs.setBool('timer_is_light', false);

    // syncTimer() o'zi notifikatsiyani "Focus Guard / Monitoring faol"
    // ga qaytaradi (chunki isTimerRunning=false va isPaused=false).
    syncTimer();
  });

  service.on('pauseTimer').listen((event) async {
    isTimerRunning = false;
    isPaused = true; // PAUSE — saqlab turamiz
    await prefs.setBool('timer_is_running', false);
    await prefs.setBool('timer_is_paused', true);
    // Qolgan vaqtni saqlab qo'yamiz — resume paytida shu yerdan davom
    await prefs.setInt('timer_remaining_seconds', remainingSeconds);
    // Pauza — Yengil Fokus bufferini saqlash. Resume'da yangidan yig'ila boshlaydi.
    await flushLightFocusBuffer();
    syncTimer();
  });

  service.on('resumeTimer').listen((event) async {
    // Qolgan vaqt allaqachon `remainingSeconds` ichida (pauseTimer
    // listener uni reset qilmagan). Yangi tugash vaqtini hisoblaymiz.
    isTimerRunning = true;
    isPaused = false;
    final endTime = DateTime.now().add(Duration(seconds: remainingSeconds));
    await prefs.setInt('timer_end_timestamp', endTime.millisecondsSinceEpoch);
    await prefs.setBool('timer_is_running', true);
    await prefs.setBool('timer_is_paused', false);
    syncTimer();
  });

  service.on('updateDailyGoal').listen((event) async {
    if (event == null) return;
    final secs = (event['seconds'] as num?)?.toInt();
    if (secs == null || secs <= 0) return;
    dailyGoalSeconds = secs;
    await prefs.setInt('daily_goal_seconds', dailyGoalSeconds);
  });

  service.on('requestTimerSync').listen((event) {
    syncTimer();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // BLOKLASH DETEKSIYASI — alohida 250ms timer, ENG ERTA ro'yxatdan o'tadi.
  //
  // MUHIM: bu timer pastdagi og'ir await'lardan (AppTranslationService.init,
  // restore, recordDay, loadBlockedApps, prefs.reload) OLDIN ro'yxatdan
  // o'tadi. Agar o'sha await'lardan biri sekin qurilmada OSILIB qolsa, xizmat
  // "ishlayapti" ko'rinadi (isRunning=true) — lekin onStart pastga yetmaydi.
  // Bloklashni shu yerga qo'yib, bu holatda ham bloklash ISHLASHINI
  // kafolatlaymiz ('hammasi true, lekin bloklash yo'q' muammosining yechimi).
  //
  // blocked_apps to'g'ridan-to'g'ri prefs'dan o'qiladi (captured var emas) —
  // loadBlockedApps tugamagan bo'lsa ham ishlaydi.
  int notBlockedFastTicks = 0;
  int fastReloadTick = 0;

  Timer.periodic(const Duration(milliseconds: 250), (fastTimer) async {
    try {
      fastReloadTick++;
      if (fastReloadTick >= 120) {
        fastReloadTick = 0;
        try {
          await prefs.reload();
        } catch (_) {}
      }

      final List<String> blocked =
          prefs.getStringList('blocked_apps') ?? const [];
      final Set<String> scheduleBlocked = activeScheduleBlockedApps(prefs);
      final Set<String> effectiveBlocked;
      if (isPaused && !isLightMode) {
        effectiveBlocked = scheduleBlocked;
      } else {
        effectiveBlocked = {...blocked, ...scheduleBlocked};
      }

      if (effectiveBlocked.isEmpty) {
        notBlockedFastTicks = 0;
        if (currentBlockedApp != null) {
          try {
            if (await FlutterOverlayWindow.isActive()) {
              await FlutterOverlayWindow.closeOverlay();
            }
          } catch (_) {}
          currentBlockedApp = null;
        }
        return;
      }

      final now = DateTime.now();
      String? currentApp;
      try {
        final startDate = now.subtract(const Duration(seconds: 5));
        final events = await UsageStats.queryEvents(startDate, now);
        EventUsageInfo? latest;
        int latestTs = -1;
        for (final e in events) {
          if (e.eventType != '1') continue; // ACTIVITY_RESUMED
          if (e.packageName == null || e.timeStamp == null) continue;
          final ts = int.tryParse(e.timeStamp!) ?? -1;
          if (ts > latestTs) {
            latestTs = ts;
            latest = e;
          }
        }
        if (latest != null) currentApp = latest.packageName;
      } catch (_) {}

      if (currentApp == null) return;

      if (currentApp == 'com.focusguard.app') {
        currentBlockedApp = null;
        notBlockedFastTicks = 0;
        final alarmActive = prefs.getBool('timer_alarm_active') ?? false;
        if (!alarmActive && await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
        }
        return;
      }

      if (effectiveBlocked.contains(currentApp)) {
        notBlockedFastTicks = 0;
        if (suppressUntil != null && now.isBefore(suppressUntil!)) return;

        final hasOverlayPermission =
            await FlutterOverlayWindow.isPermissionGranted();
        if (!hasOverlayPermission) {
          await CrashLogger.instance.recordError(
              'SYSTEM_ALERT_WINDOW permission missing', null,
              source: 'overlay-permission-check');
          return;
        }

        if (!await FlutterOverlayWindow.isActive()) {
          if (currentBlockedApp != currentApp) {
            await incrementBlockAttempt(currentApp!);
            try {
              if ((await Vibration.hasVibrator()) ?? false) {
                Vibration.vibrate(duration: 250);
              }
            } catch (_) {}
          }
          currentBlockedApp = currentApp;
          try {
            final lang = AppTranslationService();
            await FlutterOverlayWindow.showOverlay(
              enableDrag: false,
              overlayTitle:
                  lang.translate('overlay.notif_title') ?? 'Focus Guard',
              overlayContent: lang.translate('overlay.notif_content') ??
                  'Ilova cheklangan. Diqqatni jamlang!',
              flag: OverlayFlag.defaultFlag,
              visibility: NotificationVisibility.visibilitySecret,
              positionGravity: PositionGravity.auto,
              height: WindowSize.fullCover,
              width: WindowSize.fullCover,
            );
          } catch (e, st) {
            debugPrint('[FocusGuard] showOverlay failed: $e');
            await CrashLogger.instance
                .recordError(e, st, source: 'showOverlay');
            currentBlockedApp = null;
          }
        } else {
          currentBlockedApp = currentApp;
        }
      } else {
        notBlockedFastTicks++;
        if (notBlockedFastTicks >= 3) {
          currentBlockedApp = null;
          notBlockedFastTicks = 0;
          if (suppressUntil != null) suppressUntil = null;
          if (await FlutterOverlayWindow.isActive()) {
            await FlutterOverlayWindow.closeOverlay();
          }
        }
      }
    } catch (e) {
      debugPrint('[FocusGuard] fast block check error: $e');
    }
  });

  // Endi barcha listener'lar ro'yxatdan o'tdi — til faylini init qilamiz.
  // (Bu await yuqorida edi; listener'lardan oldin bo'lgani uchun invoke
  // eventi yo'qolardi. Endi listener'lardan keyin.) Notif/overlay matnlari
  // foydalanuvchi tilida chiqsin.
  try {
    await AppTranslationService().init();
  } catch (_) {}

  // Avvalgi holatni tiklash. Uchta ssenariy:
  //   1. Taymer ishlayotgan edi (running=true, paused=false) — qolgan
  //      vaqtni endTime'dan hisoblab davom ettiramiz.
  //   2. Taymer pauza qilingan edi (paused=true) — saqlangan
  //      `timer_remaining_seconds` dan davom ettiramiz, lekin
  //      isTimerRunning=false bo'lib turadi (foydalanuvchi "Davom
  //      etish"ni bossagina ishga tushadi).
  //   3. Hech narsa yo'q — odatdagi yangi sessiya.
  //
  // MUHIM: butun restore + day-check bloki try/catch ichida. Aks holda
  // bu yerdagi biror await (masalan recordDay) throw qilsa, onStart shu
  // yerda to'xtab qoladi va PASTDAGI Timer.periodic HECH QACHON
  // ro'yxatdan o'tmaydi → taymer sanamaydi VA bloklash ishlamaydi.
  // Bu eng kritik himoya.
  try {
  final savedIsPaused = prefs.getBool('timer_is_paused') ?? false;
  final savedIsRunning = prefs.getBool('timer_is_running') ?? false;
  final savedEndTime = prefs.getInt('timer_end_timestamp');

  if (savedIsRunning && savedEndTime != null) {
    final end = DateTime.fromMillisecondsSinceEpoch(savedEndTime);
    final now = DateTime.now();
    if (end.isAfter(now)) {
      remainingSeconds = end.difference(now).inSeconds;
      isTimerRunning = true;
      isPaused = false;
      sessionInitialSeconds = prefs.getInt('session_initial_seconds') ?? 0;
      modeName = prefs.getString('timer_mode_name') ?? "";
      modeIcon = prefs.getString('timer_mode_icon') ?? "";
      levelTitle = prefs.getString('timer_level_title') ?? "";
      isStrict = prefs.getBool('timer_is_strict') ?? false;
      isLightMode = prefs.getBool('timer_is_light') ?? false;
      // Pauza budjeti — focus_timer_service start paytida prefs'ga yozadi.
      // Cold start'da invoke yo'qolsa ham shu yerdan tiklanadi.
      pauseRemainingSeconds = prefs.getInt('focus_pause_remaining_seconds') ?? 0;
      pauseUnlimited = prefs.getBool('focus_pause_unlimited') ?? false;
      // Cold start'da invoke yo'qolgan bo'lsa listener streak'ni queue
      // qilmagan — bu yerda ham qo'yamiz (sana bo'yicha idempotent).
      await queueStreakForToday();
    } else {
      // Taymer service uxlab turganida tabiiy ravishda tugagan.
      // Saqlangan session uchun pending XP yozamiz va history'ga
      // yangilanish qo'shamiz — foydalanuvchi mehnati yo'qotilmasin.
      final savedInitial = prefs.getInt('session_initial_seconds') ?? 0;
      if (savedInitial > 0) {
        // MUHIM: bu blok service ishga tushishida ishlaydi va tick loop
        // ishlamagan. today_focus_seconds'ni avval prefs'dan o'qib olamiz,
        // keyin FAQAT hisobga olinmagan qismni qo'shamiz. Jonli tick har
        // 10 sek'da session_credited_seconds'ni saqlab boradi — service
        // 20-daqiqada o'lgan bo'lsa, o'sha 20 daqiqa allaqachon
        // today_focus_seconds ichida; bu yerda faqat qolgan 5 daqiqa
        // qo'shiladi. Aks holda 25-daqiqalik seans 45 daqiqa bo'lib
        // yozilardi (double-credit).
        todayFocusSeconds = prefs.getInt('today_focus_seconds') ?? 0;
        final credited = prefs.getInt('session_credited_seconds') ?? 0;
        final lateSeconds = (savedInitial - credited).clamp(0, savedInitial);
        await queuePendingXpSeconds(lateSeconds);
        await queueCompletion();
        await incrementTodaySessions();
        // Streak ham — seans haqiqatan yakunlandi (invoke yo'qolgan cold
        // start'da listener queueStreakForToday'ga yetmagan bo'lishi mumkin).
        await queueStreakForToday();
        // Late detection: faqat hisobga olinmagan qoldiq
        await addToFocusSeconds(lateSeconds); // XP ham ichida sync bo'ladi
        await updateLongestSessionSeconds(savedInitial);
        await flushLightFocusBuffer();
        debugPrint(
            '[BackgroundTimer] late-detected completion: ${lateSeconds}s '
            'of ${savedInitial}s (credited=$credited) added to focus_seconds');
        await FocusHistoryService.instance.recordDay(
          date: DateTime.now(),
          seconds: todayFocusSeconds,
          goal: dailyGoalSeconds,
          sessions: prefs.getInt('today_completed_sessions') ?? 0,
          xp: prefs.getInt('today_xp_earned') ?? 0,
          activities: activitiesForDay(todayDateKey()),
        );
      }
      await prefs.remove('timer_end_timestamp');
      await prefs.remove('session_initial_seconds');
      await prefs.remove('session_credited_seconds');
      await prefs.setBool('timer_is_running', false);
      await prefs.setBool('timer_is_strict', false);
    }
  } else if (savedIsPaused) {
    // Pause holatida saqlangan qolgan sekundlarni tiklaymiz.
    remainingSeconds = prefs.getInt('timer_remaining_seconds') ?? 0;
    sessionInitialSeconds = prefs.getInt('session_initial_seconds') ?? 0;
    isTimerRunning = false;
    isPaused = remainingSeconds > 0;
    modeName = prefs.getString('timer_mode_name') ?? "";
    modeIcon = prefs.getString('timer_mode_icon') ?? "";
    levelTitle = prefs.getString('timer_level_title') ?? "";
    // Pauza budjetini tiklash (app o'ldirilib qayta ochilgan bo'lsa).
    pauseRemainingSeconds = prefs.getInt('focus_pause_remaining_seconds') ?? 0;
    pauseUnlimited = prefs.getBool('focus_pause_unlimited') ?? false;
  }

  // Kunlik ma'lumotlarni yuklash
  todayFocusSeconds = prefs.getInt('today_focus_seconds') ?? 0;
  dailyGoalSeconds = prefs.getInt('daily_goal_seconds') ?? 7200;
  analysisSent = prefs.getBool('analysis_sent_${DateTime.now().day}') ?? false;
  lastDay = prefs.getInt('last_tracked_day') ?? DateTime.now().day;

  // Kun almashganini tekshirish (service ishga tushishida). Avval
  // kechagi kun ma'lumotini history'ga yozib qo'yamiz — Calendar
  // shu yerdan ✅/❌ ko'rsatadi.
  if (lastDay != DateTime.now().day) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    // lastDay raqami bo'lgani uchun aniq sana qurib bo'lmaydi —
    // shunday ham eng yaqin yondashuv kechagi kun.
    await FocusHistoryService.instance.recordDay(
      date: yesterday,
      seconds: todayFocusSeconds,
      goal: dailyGoalSeconds,
    );
    todayFocusSeconds = 0;
    analysisSent = false;
    await prefs.setInt('today_focus_seconds', 0);
    await prefs.setInt('last_tracked_day', DateTime.now().day);
  }
  } catch (e, st) {
    // Restore/init bosqichida xato — log qilamiz, lekin DAVOM etamiz.
    // Timer.periodic baribir ro'yxatdan o'tishi shart.
    debugPrint('[BackgroundService] restore/init error: $e');
    try {
      await CrashLogger.instance
          .recordError(e, st, source: 'onStart-restore');
    } catch (_) {}
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Bloklangan ilovalar ro'yxatini yuklaymiz.
  //
  // CRITICAL: SharedPreferences keeps a per-isolate Dart-side cache
  // that is populated on the first getInstance() call. When the UI
  // isolate writes blocked_apps via setStringList, our cache stays
  // stale. Without prefs.reload() the toggle on the block-list screen
  // looks like it does nothing — the user can never untoggle a
  // blocked app and newly added apps are never picked up. reload()
  // forces a re-read from the platform side so we always see the
  // freshest list.
  List<String> blockedApps = [];
  final loadBlockedApps = () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      blockedApps = prefs.getStringList('blocked_apps') ?? [];
    } catch (_) {}
  };

  await loadBlockedApps();

  // Ro'yxat o'zgarganda yangilash uchun listener
  service.on('updateBlockedApps').listen((event) async {
    await loadBlockedApps();
  });

  // Foydalanuvchi overlay'dagi "Orqaga qaytish" tugmasini bosganda
  // overlay isolate biz tomonga shu eventni yuboradi. Biz HOME intent
  // ishga tushishi uchun ozgina vaqt suppress qilamiz.
  //
  // 5 soniya juda uzun edi — foydalanuvchi tugmani bosib, darhol
  // qaytib bloklangan ilovaga kirsa, 5 sekund overlay yo'q va u
  // ilovada normalda ishlay olib kelardi. 2 soniya — HOME intent
  // uchun yetarli, foydalanuvchi tezda qaytsa darhol overlay
  // qaytadi.
  //
  // Bundan tashqari pastdagi tick loop'da "agar bu vaqtda bloklanmagan
  // ilova foreground'da bo'lsa suppress'ni darhol bekor qilamiz" — bu
  // foydalanuvchi haqiqatan home'ga chiqsa keyingi tickda darhol
  // qaytadigan bloklash mumkinligini ta'minlaydi.
  service.on('overlayClosedByUser').listen((event) {
    suppressUntil = DateTime.now().add(const Duration(seconds: 2));
    currentBlockedApp = null;
  });

  // Alarm dismiss — overlay yoki UI dan signal kelganda ringtoni
  // o'chiramiz va flagni tozalaymiz. Ringtone shu isolate'da
  // boshlangani uchun stop() ham shu yerda chaqirilishi kerak.
  service.on('stopAlarm').listen((event) async {
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
    await prefs.setBool('timer_alarm_active', false);
    await prefs.remove('timer_alarm_minutes');
    debugPrint('[BackgroundTimer] alarm stopped by user');
  });


  // Loop har 1 soniya da
  Timer.periodic(const Duration(seconds: 1), (timer) async {
   try {
    // 1. Taymer logikasi
    if (isTimerRunning) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        // UI streamga har soniyada yuboramiz — dashboard sanog'i
        // aniq 1s qadamda tikladi. Notification update'ni esa
        // batareya uchun har 5 soniyada (yoki oxirgi 10 sda har
        // soniya) qilamiz — `updateNotification` flag orqali.
        final bool updateNotif = remainingSeconds % 5 == 0 || remainingSeconds < 10;
        syncTimer(updateNotification: updateNotif);
      } else {
        // ────────────── TAYMER TABIIY TUGADI ──────────────
        // Foydalanuvchi taymerni to'liq oxirigacha bajardi.
        // 1. To'liq sessiya XP'sini pending queue'ga qo'shamiz
        // 2. Calendar history'ni darrov yangilaymiz
        // 3. Completion countni oshiramiz
        // 4. Rington-bilan notifikatsiya yuboramiz (app yopiq bo'lsa ham)
        isTimerRunning = false;
        isStrict = false;
        isLightMode = false;
        await prefs.setBool('timer_is_running', false);
        await prefs.setBool('timer_is_strict', false);
        await prefs.setBool('timer_is_light', false);

        if (sessionInitialSeconds > 0) {
          final sessionMinutes = sessionInitialSeconds ~/ 60;
          // Pending queue → Firestore level XP (sekund aniqligida).
          // Daqiqa o'rniga sekund queue ishlatamiz — sub-minute yo'qolmasin.
          await queuePendingXpSeconds(sessionInitialSeconds);
          await queueCompletion();
          await incrementTodaySessions();
          // Tick loop allaqachon today_focus_seconds'ni oshirgan. XP'ni sinxronlash:
          // XP = round(focus_seconds * 10 / 60). Drift bo'lmaydi.
          await syncTodayXpFromFocusSeconds();
          await updateLongestSessionSeconds(sessionInitialSeconds);
          // Yengil Fokus bufferini flush — natural complete'da ham qoldiq saqlanadi.
          await flushLightFocusBuffer();
          debugPrint(
              '[BackgroundTimer] timer completed: ${sessionInitialSeconds}s '
              '(${sessionMinutes}m), focus=${todayFocusSeconds}s, xp synced');

          // Calendar uchun darrov bugungi history yangilash —
          // foydalanuvchi Calendar'ga kirsa, bugun ✅ ko'rishi uchun
          // ertaga 00:00 kun reset bo'lguncha kutmasdan.
          await FocusHistoryService.instance.recordDay(
            date: DateTime.now(),
            seconds: todayFocusSeconds,
            goal: dailyGoalSeconds,
            sessions: prefs.getInt('today_completed_sessions') ?? 0,
            xp: prefs.getInt('today_xp_earned') ?? 0,
            activities: activitiesForDay(todayDateKey()),
          );

          // Rington + notifikatsiya — app yopiq bo'lsa ham foydalanuvchi
          // eshitishi va ko'rishi uchun. Ikki yo'l birga ishlatamiz:
          //   1. fullScreenIntent + sound bo'lgan notifikatsiya (tizim
          //      darajasida, kanal sozlamalari orqali alarm tovushi)
          //   2. FlutterRingtonePlayer looping=true — foydalanuvchi
          //      tugmani bosguncha chaladi (dismiss UI bilan birga).
          try {
            await TimerNotificationService()
                .showTimerCompletedNotification(
              minutes: sessionMinutes,
            );
          } catch (e) {
            debugPrint('[BackgroundTimer] completion notif failed: $e');
          }
          // #6: Endi loop'li, to'liq ovozli alarm chalmaymiz. Yumshoq bitta
          // "ding" ovozi taymer tugash bildirishnomasining yumshoq kanalidan
          // (timer_done_soft) keladi. Shuning uchun FlutterRingtonePlayer()
          // .playAlarm(...) olib tashlandi.
          // Vibratsiya ham yumshatildi: uzun 3 pulse o'rniga bitta qisqa puls.
          try {
            if ((await Vibration.hasVibrator()) ?? false) {
              Vibration.vibrate(duration: 300);
            }
          } catch (_) {}

          // Alarm flagini SharedPreferences ga yozamiz.
          // overlay_screen.dart va focus_timer_screen.dart shu flagni
          // o'qib dismiss UI ko'rsatadi.
          await prefs.setBool('timer_alarm_active', true);
          await prefs.setInt('timer_alarm_minutes', sessionMinutes);

          // App fonda bo'lsa (foydalanuvchi boshqa ilova yoki uy ekranida)
          // to'liq ekran alarm overlay ko'rsatamiz. App foreground bo'lsa
          // main isolate timerFinished eventini tutib dialog ko'rsatadi.
          //
          // MUHIM: prefs.reload() — background isolate'ning SharedPreferences
          // o'z keshiga ega. Main isolate `app_in_foreground` ni o'zgartirsa
          // bu yerda eski qiymat ko'rinardi va overlay chiqmasdi. Reload
          // qilib eng so'nggi qiymatni o'qiymiz.
          await prefs.reload();
          final appInForeground = prefs.getBool('app_in_foreground') ?? false;
          debugPrint(
              '[BackgroundTimer] alarm: appInForeground=$appInForeground');
          if (!appInForeground) {
            try {
              // Overlay ruxsati borligini tekshiramiz. Samsung'da ba'zan
              // jimgina bekor qilinadi — bunday holatda fallback uchun
              // ringtone va notifikatsiya allaqachon ishlamoqda.
              final hasOverlayPermission =
                  await FlutterOverlayWindow.isPermissionGranted();
              if (!hasOverlayPermission) {
                debugPrint(
                    '[BackgroundTimer] alarm: no overlay permission, only notif');
                await CrashLogger.instance.recordError(
                  'Alarm overlay skipped: permission missing',
                  null,
                  source: 'alarm-overlay-permission',
                );
              } else {
                // Avval mavjud overlay'ni yopamiz (bloklash overlay'i
                // bo'lishi mumkin), keyin alarm overlay'ini ochamiz —
                // shunda alarm UI alohida chiqadi.
                if (await FlutterOverlayWindow.isActive()) {
                  await FlutterOverlayWindow.closeOverlay();
                  await Future.delayed(const Duration(milliseconds: 100));
                }
                final lang = AppTranslationService();
                final overlayNotifTitle =
                    lang.translate('overlay.notif_title') ?? 'Focus Guard';
                final overlayNotifContent =
                    lang.translate('alarm.overlay_title') ??
                        'Fokus vaqti tugadi!';
                await FlutterOverlayWindow.showOverlay(
                  enableDrag: false,
                  overlayTitle: overlayNotifTitle,
                  overlayContent: overlayNotifContent,
                  flag: OverlayFlag.defaultFlag,
                  visibility: NotificationVisibility.visibilitySecret,
                  positionGravity: PositionGravity.auto,
                  height: WindowSize.fullCover,
                  width: WindowSize.fullCover,
                );
                debugPrint('[BackgroundTimer] alarm overlay shown');
              }
            } catch (e, st) {
              debugPrint('[BackgroundTimer] alarm overlay failed: $e');
              await CrashLogger.instance.recordError(e, st,
                  source: 'alarm-overlay');
            }
          }
        }

        sessionInitialSeconds = 0;
        await prefs.remove('session_initial_seconds');
        await prefs.remove('session_credited_seconds');
        // timer_alarm_minutes prefs'ga yuqorida yozilgan — shu qiymatni
        // timerFinished eventiga ham qo'shamiz.
        service.invoke('timerFinished', {
          'minutes': prefs.getInt('timer_alarm_minutes') ?? 0,
        });
        syncTimer();
      }

      // Har soniyada progressni oshiramiz
      todayFocusSeconds++;
      if (todayFocusSeconds % 10 == 0) { // Har 10 soniyada saqlaymiz
        await prefs.setInt('today_focus_seconds', todayFocusSeconds);
        // XP ham har 10 sek'da sync — UI live yangilanib turadi.
        // Formula: round(focus_seconds * 10 / 60). Drift bo'lmaydi.
        await prefs.setInt('today_xp_earned', xpFromSeconds(todayFocusSeconds));
        // Late-detection uchun: joriy seansning qancha sekundi ALLAQACHON
        // jonli tick orqali hisobga olingani. Service o'lib, keyin restore
        // bo'lsa, faqat qolgan (hisobga olinmagan) qismi qo'shiladi —
        // double-credit bo'lmaydi.
        if (sessionInitialSeconds > 0) {
          await prefs.setInt('session_credited_seconds',
              sessionInitialSeconds - remainingSeconds);
        }
      }
      // Yengil Fokus rejimi bo'lsa — bufferni har soniyada oshiramiz.
      // 10 sekundga yetganda saqlanadi (batareyaga yengil). Stop/pause/complete
      // paytida qoldiq ham flush qilinadi — 0-9 sek yo'qotilmaydi.
      // `isLightMode` UI'dan keladi (avval `!isStrict` proxy edi va Deep+No-Strict'ni Light deb belgilardi).
      if (isLightMode) {
        lightFocusBuffer++;
        if (lightFocusBuffer >= 10) {
          await flushLightFocusBuffer();
        }
      }
    } else if (isPaused && !pauseUnlimited) {
      // ───────── Pauza budjeti sarflanmoqda ─────────
      // Foydalanuvchi pauzada — bloklangan ilovalardan foydalanyapti.
      // Har soniyada budjetdan ayiramiz. Budjet tugasa taymer avtomatik
      // davom etadi va bloklash qaytadi.
      if (pauseRemainingSeconds > 0) {
        pauseRemainingSeconds--;
        if (pauseRemainingSeconds % 5 == 0 || pauseRemainingSeconds < 10) {
          await prefs.setInt(
              'focus_pause_remaining_seconds', pauseRemainingSeconds);
        }
      }
      if (pauseRemainingSeconds <= 0) {
        // Budjet tugadi — avtomatik davom ettiramiz.
        isPaused = false;
        isTimerRunning = true;
        pauseRemainingSeconds = 0;
        await prefs.setInt('focus_pause_remaining_seconds', 0);
        final endTime =
            DateTime.now().add(Duration(seconds: remainingSeconds));
        await prefs.setInt(
            'timer_end_timestamp', endTime.millisecondsSinceEpoch);
        await prefs.setBool('timer_is_running', true);
        await prefs.setBool('timer_is_paused', false);
        service.invoke('pauseEnded', {});
        debugPrint('[BackgroundTimer] pause budget exhausted → auto-resume');
      }
      syncTimer();
    }

    // 2. Kunlik tahlil logikasi
    final now = DateTime.now();

    // Kun almashganini tekshirish (yarim tunda reset). Reset oldidan
    // kechagi kun ma'lumotini history'ga yozamiz — Calendar shu
    // manbadan ✅/❌ ko'rsatadi.
    if (now.day != lastDay) {
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayKey =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-'
          '${yesterday.day.toString().padLeft(2, '0')}';
      // Kechagi kun ma'lumotini history'ga yozamiz (sessions/xp/activities bilan)
      await FocusHistoryService.instance.recordDay(
        date: yesterday,
        seconds: todayFocusSeconds,
        goal: dailyGoalSeconds,
        sessions: prefs.getInt('today_completed_sessions') ?? 0,
        xp: prefs.getInt('today_xp_earned') ?? 0,
        activities: activitiesForDay(yesterdayKey),
      );
      todayFocusSeconds = 0;
      analysisSent = false;
      lastDay = now.day;
      await prefs.setInt('today_focus_seconds', 0);
      await prefs.setInt('last_tracked_day', lastDay);
      // Bugungi seans/XP hisoblagichlarini ham nolga tushuramiz
      await prefs.setInt('today_completed_sessions', 0);
      await prefs.setInt('today_xp_earned', 0);
    }

    // Soat 23:55 da kunlik yakun (Goal Missed/Achieved). Bu hali ham
    // tick-based ishlaydi (fallback), lekin asosiy schedule
    // TimerNotificationService.scheduleDailySummary() orqali AlarmManager
    // boshqaradi — hatto service o'lik bo'lsa ham notifikatsiya keladi.
    // Bu yerda esa service ishlab turgan paytda history'ni yangilab
    // qo'yamiz (Calendar bu kunni darrov ✅/❌ qilib ko'rsata olishi
    // uchun, ertaga 00:01 da day-reset bo'lguncha kutmasdan).
    if (now.hour == 23 && now.minute == 55 && !analysisSent) {
      analysisSent = true;
      await prefs.setBool('analysis_sent_${now.day}', true);

      // History'ga BUGUNGI kunni yozamiz (kun hali tugamagan bo'lsa
      // ham — qolgan 5 daqiqa juda kichik xatolik beradi).
      await FocusHistoryService.instance.recordDay(
        date: now,
        seconds: todayFocusSeconds,
        goal: dailyGoalSeconds,
        sessions: prefs.getInt('today_completed_sessions') ?? 0,
        xp: prefs.getInt('today_xp_earned') ?? 0,
        activities: activitiesForDay(todayDateKey()),
      );

      // Tick-based notifikatsiya — fallback sifatida qoldirildi.
      // Asosiy schedule TimerNotificationService.scheduleDailySummary
      // ichida AlarmManager bilan qilingan.
      final notificationService = TimerNotificationService();
      if (todayFocusSeconds < dailyGoalSeconds) {
        await notificationService.showGoalMissedNotification();
      } else {
        await notificationService.showGoalAchievedNotification();
      }
    }

    // 2. Bloklash logikasi — bu yerda EMAS.
    // Bloklash deteksiyasi alohida, mustaqil 250ms timer'da bajariladi
    // (onStart'da yuqorida ro'yxatdan o'tgan). Sabab: u 1s tick'dagi taymer
    // mantig'i, restore yoki sekinlikdan BUTUNLAY mustaqil bo'lishi kerak —
    // aks holda tickda biror muammo bloklashni ham o'chirardi. 1s tick endi
    // faqat taymer + statistika uchun.
   } catch (e, st) {
     // Tick callback'da kutilmagan xato — log qilamiz va keyingi tickda
     // davom etamiz. Timer.periodic bitta tick fail bo'lsa ham to'xtamaydi,
     // bu faqat unhandled-error shovqinini oldini oladi.
     debugPrint('[BackgroundService] tick error: $e');
     try {
       await CrashLogger.instance.recordError(e, st, source: 'timer-tick');
     } catch (_) {}
   }
  });
}
