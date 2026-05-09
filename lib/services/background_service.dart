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
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'app_locker_channel',
        initialNotificationTitle: 'Focus Guard',
        initialNotificationContent: 'Monitoring faol',
        foregroundServiceNotificationId: 888,
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
  
  void syncTimer() {
    service.invoke('timerTick', {
      'seconds': remainingSeconds,
      'isRunning': isTimerRunning,
      'modeName': modeName,
      'modeIcon': modeIcon,
    });

    if (service is AndroidServiceInstance && isTimerRunning) {
      int m = remainingSeconds ~/ 60;
      int s = remainingSeconds % 60;
      String timeStr = "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
      
      service.setForegroundNotificationInfo(
        title: "Focus Guard · $timeStr",
        content: "$modeIcon $modeName | $levelTitle",
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
    
    // Tugash vaqtini saqlash
    final endTime = DateTime.now().add(Duration(seconds: remainingSeconds));
    await prefs.setInt('timer_end_timestamp', endTime.millisecondsSinceEpoch);
    await prefs.setBool('timer_is_running', true);
    await prefs.setString('timer_mode_name', modeName);
    await prefs.setString('timer_mode_icon', modeIcon);
    await prefs.setString('timer_level_title', levelTitle);

    syncTimer();
  });

  service.on('stopTimer').listen((event) async {
    isTimerRunning = false;
    remainingSeconds = 0;
    await prefs.remove('timer_end_timestamp');
    await prefs.setBool('timer_is_running', false);
    
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Focus Guard",
        content: "Monitoring faol",
      );
    }
    syncTimer();
  });

  service.on('pauseTimer').listen((event) async {
    isTimerRunning = false;
    await prefs.setBool('timer_is_running', false);
    // Qolgan vaqtni saqlab qo'yamiz
    await prefs.setInt('timer_remaining_seconds', remainingSeconds);
    syncTimer();
  });

  service.on('resumeTimer').listen((event) async {
    isTimerRunning = true;
    await prefs.setBool('timer_is_running', true);
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

  // Avvalgi holatni tiklash
  final savedEndTime = prefs.getInt('timer_end_timestamp');
  final savedIsRunning = prefs.getBool('timer_is_running') ?? false;
  if (savedEndTime != null && savedIsRunning) {
    final end = DateTime.fromMillisecondsSinceEpoch(savedEndTime);
    final now = DateTime.now();
    if (end.isAfter(now)) {
      remainingSeconds = end.difference(now).inSeconds;
      isTimerRunning = true;
      modeName = prefs.getString('timer_mode_name') ?? "";
      modeIcon = prefs.getString('timer_mode_icon') ?? "";
      levelTitle = prefs.getString('timer_level_title') ?? "";
    } else {
      await prefs.remove('timer_end_timestamp');
      await prefs.setBool('timer_is_running', false);
    }
  }

  // Kunlik ma'lumotlarni yuklash
  todayFocusSeconds = prefs.getInt('today_focus_seconds') ?? 0;
  dailyGoalSeconds = prefs.getInt('daily_goal_seconds') ?? 14400;
  analysisSent = prefs.getBool('analysis_sent_${DateTime.now().day}') ?? false;
  lastDay = prefs.getInt('last_tracked_day') ?? DateTime.now().day;

  // Kun almashganini tekshirish
  if (lastDay != DateTime.now().day) {
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
  // overlay isolate biz tomonga shu eventni yuboradi. Biz keyingi 5
  // soniya overlay'ni qayta ko'rsatmaymiz, foydalanuvchi home'ga
  // chiqib ulgursin.
  service.on('overlayClosedByUser').listen((event) {
    suppressUntil = DateTime.now().add(const Duration(seconds: 5));
    currentBlockedApp = null;
  });

  // Loop har 1 soniya da
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    // 1. Taymer logikasi
    if (isTimerRunning) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        if (remainingSeconds % 5 == 0) { // Har 5 soniyada UI ga vaqtni yuboramiz (resursni tejash uchun)
          syncTimer();
        } else if (remainingSeconds < 10) { // Oxirgi 10 soniyada har soniya
          syncTimer();
        }
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
    
    // Kun almashganini tekshirish (yarim tunda reset)
    if (now.day != lastDay) {
      todayFocusSeconds = 0;
      analysisSent = false;
      lastDay = now.day;
      await prefs.setInt('today_focus_seconds', 0);
      await prefs.setInt('last_tracked_day', lastDay);
    }

    // Soat 23:55 da tahlil bildirishnomasini yuborish
    if (now.hour == 23 && now.minute == 55 && !analysisSent) {
      analysisSent = true;
      await prefs.setBool('analysis_sent_${now.day}', true);
      
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
        if (!hasOverlayPermission) return;

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
        } else {
          currentBlockedApp = currentApp;
        }
      } else {
        // Bloklanmagan haqiqiy ilova foreground'da — coverni darhol
        // yopamiz. Eng ohirgi RESUMED bizga aniq signal beradi, shuning
        // uchun ko'p tickli "tasdiqlash" kerak emas.
        currentBlockedApp = null;
        notBlockedTicks = 0;
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
