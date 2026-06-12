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

  // Background isolate'da AppTranslationService alohida nusxa —
  // tilni SharedPreferences'dan o'qib initialize qilamiz. Aks holda
  // notifikatsiya matnlari va overlay sarlavhasi har doim o'zbekcha
  // ko'rinardi (default _currentLanguage = 'uz').
  try {
    await AppTranslationService().init();
  } catch (_) {}

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
  //
  // notBlockedTicks — foydalanuvchi bloklangan ilovada bo'lmagan
  // ketma-ket soniyalar soni. Faqat shu hisob >= 3 bo'lganda
  // overlay yopiladi. Bu detection bir-ikki tickda noto'g'ri
  // ko'rsatsa ham overlay tushib qolmasligini ta'minlaydi.
  // currentBlockedApp — overlay hozir qaysi paket uchun ko'rsatilmoqda;
  // bir paketga bir marta vibratsiya berishimiz uchun.
  // suppressUntil — foydalanuvchi "Orqaga qaytish" tugmasini bossa,
  // shundan keyin 5 soniya overlayni qayta ko'rsatmaymiz. Aks holda
  // home intent uchgunicha biz yana overlayni ochib yuboramiz va
  // foydalanuvchi loop'da qoladi.
  int notBlockedTicks = 0;
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
    // Premium foydalanuvchi yoki Yengil Fokus → cheksiz pauza.
    // Bepul + Chuqur Fokus → seans davomiyligiga qarab bosqichli budjet.
    final bool isPremium = (event['isPremium'] as bool?) ?? false;
    await prefs.setBool('timer_is_premium', isPremium);
    if (isPremium || isLightMode) {
      pauseUnlimited = true;
      pauseRemainingSeconds = 0;
    } else {
      pauseUnlimited = false;
      if (minutes <= 30) {
        pauseRemainingSeconds = 0; // qisqa seans — pauza yo'q
      } else if (minutes <= 60) {
        pauseRemainingSeconds = 300; // 5 daqiqa
      } else {
        pauseRemainingSeconds = 600; // 10 daqiqa
      }
    }
    await prefs.setInt('focus_pause_remaining_seconds', pauseRemainingSeconds);
    await prefs.setBool('focus_pause_unlimited', pauseUnlimited);

    // Tugash vaqtini saqlash
    final endTime = DateTime.now().add(Duration(seconds: remainingSeconds));
    await prefs.setInt('timer_end_timestamp', endTime.millisecondsSinceEpoch);
    await prefs.setInt('session_initial_seconds', sessionInitialSeconds);
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
    } else {
      // Taymer service uxlab turganida tabiiy ravishda tugagan.
      // Saqlangan session uchun pending XP yozamiz va history'ga
      // yangilanish qo'shamiz — foydalanuvchi mehnati yo'qotilmasin.
      final savedInitial = prefs.getInt('session_initial_seconds') ?? 0;
      if (savedInitial > 0) {
        // MUHIM: bu blok service ishga tushishida ishlaydi va tick loop
        // ishlamagan. today_focus_seconds'ni avval prefs'dan o'qib olamiz,
        // keyin savedInitial'ni qo'shamiz — XP/vaqt sinxron qoladi.
        todayFocusSeconds = prefs.getInt('today_focus_seconds') ?? 0;
        final sessionMinutes = savedInitial ~/ 60;
        await queuePendingXP(sessionMinutes);
        await queueCompletion();
        await incrementTodaySessions();
        // Late detection: tick loop ishlamagan → focus_seconds'ni manual oshirish
        await addToFocusSeconds(savedInitial); // XP ham ichida sync bo'ladi
        await updateLongestSessionSeconds(savedInitial);
        await flushLightFocusBuffer();
        debugPrint(
            '[BackgroundTimer] late-detected completion: ${savedInitial}s '
            '(${sessionMinutes}m) added to focus_seconds');
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

    // 2. Bloklash logikasi.
    //
    // Foreground holatining yagona ishonchli manbai — UsageStats event
    // oqimidagi eng ohirgi ACTIVITY_RESUMED hodisasi. Boshqa hech narsa
    // (getAppUsage agregatlari, system UI peeklari va h.k.) bizga
    // foydalanuvchi qayerdaligini aniq ayta olmaydi. Shuning uchun
    // har tickda quyidagini bajaramiz:
    //
    //   1. Oxirgi 60 soniyadagi RESUMED hodisalarini olamiz.
    //   2. Eng so'nggi RESUMED — joriy foreground.
    //      • Bloklangan ilova bo'lsa → coverni ushlab turamiz va
    //        yangi seans bo'lsa bir marta vibratsiya beramiz.
    //      • Focus Guard yoki boshqa ilova bo'lsa → coverni yopamiz.
    //   3. Hech qanday RESUMED topilmasa (foydalanuvchi 60 soniya
    //      mobaynida hech narsa qilmadi) → cover holatini saqlab
    //      turamiz, hech narsani o'zgartirmaymiz.
    //
    // Bu yondashuv "system UI bir lahzaga ko'rinib ketgan" yoki
    // "queryEvents bir-ikki tickda bo'sh qaytdi" kabi shovqinli
    // hodisalardan ta'sirlanmaydi.
    try {
      // Pauza paytida bloklash to'xtaydi — foydalanuvchi pauza budjeti
      // doirasida bloklangan ilovalardan foydalana oladi. Ochiq overlay
      // bo'lsa yopamiz.
      if (isPaused) {
        if (await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
        }
        currentBlockedApp = null;
        return;
      }

      // Doimiy bloklangan ilovalar + faol jadval oynasidagi ilovalar.
      final Set<String> effectiveBlocked = {
        ...blockedApps,
        ...activeScheduleBlockedApps(prefs),
      };
      if (effectiveBlocked.isEmpty) return;

      DateTime now = DateTime.now();

      String? currentApp;
      try {
        DateTime startDate = now.subtract(const Duration(seconds: 60));
        final events = await UsageStats.queryEvents(startDate, now);

        // ACTIVITY_RESUMED = "1" — eng ohirgi shu turdagi event bizga
        // hozir foreground'da kim turganini aniq aytadi.
        EventUsageInfo? latest;
        int latestTs = -1;
        for (final e in events) {
          if (e.eventType != '1') continue;
          if (e.packageName == null || e.timeStamp == null) continue;
          final ts = int.tryParse(e.timeStamp!) ?? -1;
          if (ts > latestTs) {
            latestTs = ts;
            latest = e;
          }
        }
        if (latest != null) {
          currentApp = latest.packageName;
          debugPrint('[FocusGuard] latest RESUMED -> $currentApp');
        } else {
          debugPrint('[FocusGuard] no RESUMED in last 60s '
              '(${events.length} events total)');
        }
      } catch (e) {
        debugPrint('[FocusGuard] queryEvents failed: $e');
      }

      if (currentApp == null) {
        // Hech qanday signal yo'q — overlay holatini o'zgartirmaymiz.
        return;
      }

      // Focus Guard'ga qaytildi — coverni yopamiz va hisobni tozalaymiz.
      // Istisno: timer_alarm_active=true bo'lsa alarm overlay ko'rsatilayapti,
      // uni yopmaymiz — foydalanuvchi dismiss tugmasini bossin.
      if (currentApp == 'com.focusguard.app') {
        currentBlockedApp = null;
        notBlockedTicks = 0;
        final alarmActive = prefs.getBool('timer_alarm_active') ?? false;
        if (!alarmActive) {
          bool isOverlayActive = await FlutterOverlayWindow.isActive();
          if (isOverlayActive) {
            await FlutterOverlayWindow.closeOverlay();
          }
        }
        return;
      }

      if (effectiveBlocked.contains(currentApp)) {
        // Bloklangan ilova foreground'da. Cover ko'rsatish (kerak bo'lsa)
        // va yangi seans bo'lsa bitta vibratsiya berish.
        notBlockedTicks = 0;

        // Foydalanuvchi hozirgina "Orqaga qaytish"ni bosgan bo'lsa,
        // home intent ishga tushishi uchun bir necha soniya jim turamiz.
        if (suppressUntil != null && now.isBefore(suppressUntil!)) {
          return;
        }

        bool hasOverlayPermission =
            await FlutterOverlayWindow.isPermissionGranted();
        if (!hasOverlayPermission) {
          // Samsung ba'zan ruxsatni "jimgina" qaytarib oladi va
          // foydalanuvchi buni sezmaydi. Logga yozib, banner orqali
          // ogohlantiramiz, lekin crash qilmaymiz.
          await CrashLogger.instance.recordError(
            'SYSTEM_ALERT_WINDOW permission missing',
            null,
            source: 'overlay-permission-check',
          );
          return;
        }

        bool isOverlayActive = await FlutterOverlayWindow.isActive();
        if (!isOverlayActive) {
          if (currentBlockedApp != currentApp) {
            // YANGI bloklangan ilova kirishga urinishi — statistika
            // counter'ini oshiramiz. Aynan o'sha ilovaga bir necha
            // sekund chap-rost qaytsa qayta sanalmaydi, chunki
            // `currentBlockedApp` saqlanib turadi.
            await incrementBlockAttempt(currentApp);
            try {
              if ((await Vibration.hasVibrator()) ?? false) {
                Vibration.vibrate(duration: 250);
              }
            } catch (_) {}
          }
          currentBlockedApp = currentApp;

          // showOverlay() ostida startService chaqiriladi — Samsung'da
          // BadTokenException, ForegroundServiceStartNotAllowed yoki
          // SecurityException tashlashi mumkin. Hech bir holatda
          // background service crash bo'lmasligi kerak, aks holda
          // foydalanuvchi "Focus Guard yana ishdan chiqdi" ni ko'radi.
          try {
            // i18n — overlay'ning ichki notifikatsiyasi ham
            // foydalanuvchi tanlagan tilda chiqsin.
            final lang = AppTranslationService();
            final overlayNotifTitle =
                lang.translate('overlay.notif_title') ?? 'Focus Guard';
            final overlayNotifContent =
                lang.translate('overlay.notif_content') ??
                    'Ilova cheklangan. Diqqatni jamlang!';
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
          } catch (e, st) {
            debugPrint('[FocusGuard] showOverlay failed: $e');
            await CrashLogger.instance.recordError(
              e,
              st,
              source: 'showOverlay',
            );
            // currentBlockedApp ni reset qilamiz — keyingi tickda
            // qayta urinish uchun
            currentBlockedApp = null;
          }
        } else {
          currentBlockedApp = currentApp;
        }
      } else {
        // Bloklanmagan haqiqiy ilova foreground'da — coverni darhol
        // yopamiz. Eng ohirgi RESUMED bizga aniq signal beradi, shuning
        // uchun ko'p tickli "tasdiqlash" kerak emas.
        currentBlockedApp = null;
        notBlockedTicks = 0;

        // Smart suppress clear: agar foydalanuvchi bloklanmagan ilovaga
        // (masalan launcher'ga) chiqib bo'lgan bo'lsa, suppress
        // shartining maqsadi (HOME intent ishga tushishini kutish)
        // bajarildi — endi keyingi safar bloklangan ilovaga kirsa
        // overlay darhol qaytadigan bo'lishi uchun suppressUntil'ni
        // bekor qilamiz.
        if (suppressUntil != null) {
          suppressUntil = null;
        }

        bool isOverlayActive = await FlutterOverlayWindow.isActive();
        if (isOverlayActive) {
          await FlutterOverlayWindow.closeOverlay();
        }
      }
    } catch (e) {
      debugPrint('[FocusGuard] Block detection error: $e');
    }
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
