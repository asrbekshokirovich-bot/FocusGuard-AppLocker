import 'dart:async';
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

    // kIsWeb ni import qilishimiz kerak yoki Platform.isAndroid ni tekshirishimiz kerak
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
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'app_locker_channel',
        initialNotificationTitle: 'Focus Guard',
        initialNotificationContent: 'Monitoring faol',
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
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
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
  String modeName = "";
  String modeIcon = "";
  String levelTitle = "";
  bool isStrict = false;
  
  // Kunlik maqsad o'zgaruvchilari
  int todayFocusSeconds = 0;
  int dailyGoalSeconds = 14400; // Standart 4 soat
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
    });

    if (updateNotification && service is AndroidServiceInstance) {
      int m = remainingSeconds ~/ 60;
      int s = remainingSeconds % 60;
      String timeStr = "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";

      // Notifikatsiya title — 3 ta holatga qarab:
      //   • Taymer ishlayapti: "⏱ Focus Guard · 24:30"
      //   • Pauza:             "⏸ Focus Guard · 24:30"
      //   • Default monitoring: "Focus Guard"
      String title;
      String content;
      if (isTimerRunning) {
        title = "⏱ Focus Guard · $timeStr";
        content = "$modeIcon $modeName | $levelTitle";
      } else if (isPaused) {
        title = "⏸ Focus Guard · $timeStr";
        content = "Pauza · $modeIcon $modeName";
      } else {
        title = "Focus Guard";
        content = "Monitoring faol";
      }

      service.setForegroundNotificationInfo(
        title: title,
        content: content,
      );
    }
  }

  service.on('startTimer').listen((event) async {
    if (event == null) return;
    remainingSeconds = (event['minutes'] as int) * 60;
    modeName = event['modeName'];
    modeIcon = event['modeIcon'];
    levelTitle = event['levelTitle'];
    isStrict = event['isStrict'];
    isTimerRunning = true;
    isPaused = false; // yangi sessiya — paused emas

    // Tugash vaqtini saqlash
    final endTime = DateTime.now().add(Duration(seconds: remainingSeconds));
    await prefs.setInt('timer_end_timestamp', endTime.millisecondsSinceEpoch);
    await prefs.setBool('timer_is_running', true);
    await prefs.setBool('timer_is_paused', false);
    await prefs.setString('timer_mode_name', modeName);
    await prefs.setString('timer_mode_icon', modeIcon);
    await prefs.setString('timer_level_title', levelTitle);

    syncTimer();
  });

  service.on('stopTimer').listen((event) async {
    isTimerRunning = false;
    isPaused = false; // to'liq to'xtatildi
    remainingSeconds = 0;
    await prefs.remove('timer_end_timestamp');
    await prefs.remove('timer_remaining_seconds');
    await prefs.setBool('timer_is_running', false);
    await prefs.setBool('timer_is_paused', false);

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
    dailyGoalSeconds = (event['seconds'] as int);
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
      modeName = prefs.getString('timer_mode_name') ?? "";
      modeIcon = prefs.getString('timer_mode_icon') ?? "";
      levelTitle = prefs.getString('timer_level_title') ?? "";
    } else {
      await prefs.remove('timer_end_timestamp');
      await prefs.setBool('timer_is_running', false);
    }
  } else if (savedIsPaused) {
    // Pause holatida saqlangan qolgan sekundlarni tiklaymiz.
    remainingSeconds = prefs.getInt('timer_remaining_seconds') ?? 0;
    isTimerRunning = false;
    isPaused = remainingSeconds > 0;
    modeName = prefs.getString('timer_mode_name') ?? "";
    modeIcon = prefs.getString('timer_mode_icon') ?? "";
    levelTitle = prefs.getString('timer_level_title') ?? "";
  }

  // Kunlik ma'lumotlarni yuklash
  todayFocusSeconds = prefs.getInt('today_focus_seconds') ?? 0;
  dailyGoalSeconds = prefs.getInt('daily_goal_seconds') ?? 14400;
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

  // Loop har 1 soniya da
  Timer.periodic(const Duration(seconds: 1), (timer) async {
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
        isTimerRunning = false;
        await prefs.setBool('timer_is_running', false);
        service.invoke('timerFinished');
        syncTimer();
      }
      
      // Har soniyada progressni oshiramiz
      todayFocusSeconds++;
      if (todayFocusSeconds % 10 == 0) { // Har 10 soniyada saqlaymiz
        await prefs.setInt('today_focus_seconds', todayFocusSeconds);
      }
    }

    // 2. Kunlik tahlil logikasi
    final now = DateTime.now();

    // Kun almashganini tekshirish (yarim tunda reset). Reset oldidan
    // kechagi kun ma'lumotini history'ga yozamiz — Calendar shu
    // manbadan ✅/❌ ko'rsatadi.
    if (now.day != lastDay) {
      final yesterday = now.subtract(const Duration(days: 1));
      await FocusHistoryService.instance.recordDay(
        date: yesterday,
        seconds: todayFocusSeconds,
        goal: dailyGoalSeconds,
      );
      todayFocusSeconds = 0;
      analysisSent = false;
      lastDay = now.day;
      await prefs.setInt('today_focus_seconds', 0);
      await prefs.setInt('last_tracked_day', lastDay);
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
      if (blockedApps.isEmpty) return;

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
      if (currentApp == 'com.focusguard.app') {
        currentBlockedApp = null;
        notBlockedTicks = 0;
        bool isOverlayActive = await FlutterOverlayWindow.isActive();
        if (isOverlayActive) {
          await FlutterOverlayWindow.closeOverlay();
        }
        return;
      }

      if (blockedApps.contains(currentApp)) {
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
            await FlutterOverlayWindow.showOverlay(
              enableDrag: false,
              overlayTitle: "Focus Guard",
              overlayContent: "Ilova cheklangan. Diqqatni jamlang!",
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
  });
}
