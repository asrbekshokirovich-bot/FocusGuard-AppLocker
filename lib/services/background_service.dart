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

    // Pre-create the overlay's foreground service channel(s) with MIN
    // importance so the "Ilova cheklangan" banner doesn't pop with a
    // sound/vibration each time the cover appears. Once a channel
    // exists Android keeps our settings even if the package recreates
    // it with the same id later. We register the IDs the package is
    // most likely to use; harmless if unused.
    const overlayChannelIds = <String>[
      'flutter_overlay_window',
      'OverlayServiceChannel',
      'OverlayChannel',
      'overlay_window_channel',
    ];
    for (final id in overlayChannelIds) {
      await androidNotifications?.createNotificationChannel(
        AndroidNotificationChannel(
          id,
          'Block Overlay',
          description: 'Blocking screen for restricted apps',
          importance: Importance.min,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );
    }

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
  int notBlockedTicks = 0;
  String? currentBlockedApp;

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

  // Bloklangan ilovalar ro'yxatini yuklaymiz
  List<String> blockedApps = [];
  final loadBlockedApps = () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      blockedApps = prefs.getStringList('blocked_apps') ?? [];
    } catch (_) {}
  };

  await loadBlockedApps();

  // Ro'yxat o'zgarganda yangilash uchun listener
  service.on('updateBlockedApps').listen((event) async {
    await loadBlockedApps();
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

    // 2. Bloklash logikasi - aggressive multi-source detection.
    //
    // Some apps slip past a "latest event" check because foreground
    // events are interleaved with launchers, system UI, IME, etc.
    // Instead, collect EVERY recently-active package from both
    // queryEvents and getAppUsage, then check whether any of them is
    // in the blocked list. This way we catch the blocked app even if
    // it isn't the very last event Android reported.
    try {
      if (blockedApps.isEmpty) return;

      DateTime now = DateTime.now();
      final Set<String> recentApps = <String>{};
      String? latestApp; // best-effort "current" foreground for overlay logic

      // 1) Real-time foreground events (last 5s window)
      try {
        DateTime startDate = now.subtract(const Duration(seconds: 5));
        List<EventUsageInfo> events =
            await UsageStats.queryEvents(startDate, now);

        // ACTIVITY_RESUMED = 1 (old name MOVE_TO_FOREGROUND)
        final foregroundEvents = events
            .where((e) =>
                e.eventType == "1" &&
                e.packageName != null &&
                e.timeStamp != null)
            .toList();

        for (final e in foregroundEvents) {
          recentApps.add(e.packageName!);
        }

        if (foregroundEvents.isNotEmpty) {
          foregroundEvents.sort((a, b) {
            final ta = int.tryParse(a.timeStamp ?? "0") ?? 0;
            final tb = int.tryParse(b.timeStamp ?? "0") ?? 0;
            return tb.compareTo(ta);
          });
          latestApp = foregroundEvents.first.packageName;
          debugPrint('[FocusGuard] queryEvents fg=${foregroundEvents.length} '
              'recent=${recentApps.length} latest=$latestApp');
        } else {
          debugPrint('[FocusGuard] queryEvents 0 fg events '
              '(total ${events.length})');
        }
      } catch (e) {
        debugPrint('[FocusGuard] queryEvents failed: $e');
      }

      // 2) Aggregated usage as a second source
      try {
        DateTime startDate = now.subtract(const Duration(seconds: 30));
        List<AppUsageInfo> infoList =
            await AppUsage().getAppUsage(startDate, now);
        for (final info in infoList) {
          // Anything used in the last 5 seconds counts as "recent"
          if (now.difference(info.endDate).inSeconds <= 5) {
            recentApps.add(info.packageName);
          }
        }
        if (latestApp == null && infoList.isNotEmpty) {
          infoList.sort((a, b) => b.endDate.compareTo(a.endDate));
          final latestInfo = infoList.first;
          if (now.difference(latestInfo.endDate).inSeconds <= 10) {
            latestApp = latestInfo.packageName;
            debugPrint('[FocusGuard] getAppUsage fallback -> $latestApp');
          }
        }
      } catch (e) {
        debugPrint('[FocusGuard] getAppUsage failed: $e');
      }

      // Always remove ourselves from the recent set; we don't block ourselves.
      recentApps.remove('com.focusguard.app');

      // If ANY recently-active package is on the blocked list, that's
      // what we surface — even if it isn't the very latest event.
      String? currentApp;
      try {
        currentApp = recentApps.firstWhere((p) => blockedApps.contains(p));
        debugPrint('[FocusGuard] HIT blocked app in recent set: $currentApp');
      } catch (_) {
        currentApp = latestApp;
      }

      if (currentApp == null) {
        // Detection couldn't read anything this tick — DO NOT touch the
        // overlay state. A noisy reading shouldn't tear the cover down.
        return;
      }

      // O'z ilovamiz bo'lsa: foydalanuvchi Focus Guardga qaytdi,
      // overlayni yopamiz va hisoblagichni tozalaymiz.
      if (currentApp == 'com.focusguard.app') {
        notBlockedTicks = 0;
        currentBlockedApp = null;
        bool isOverlayActive = await FlutterOverlayWindow.isActive();
        if (isOverlayActive) {
          await FlutterOverlayWindow.closeOverlay();
        }
        return;
      }

      if (blockedApps.contains(currentApp)) {
        // Bloklangan ilova foreground'da — overlayni ushlab turamiz.
        notBlockedTicks = 0;

        bool hasOverlayPermission =
            await FlutterOverlayWindow.isPermissionGranted();
        if (!hasOverlayPermission) return;

        bool isOverlayActive = await FlutterOverlayWindow.isActive();
        if (!isOverlayActive) {
          // Yangi blok seansida bir marta vibratsiya beramiz.
          // Avvalgi seans bilan bir xil paket bo'lsa qayta titramaymiz.
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
            // fullCover — status bar va navigation bar ustidan ham
            // chiziladi, hech qanday bo'shliq qoldirmaydi.
            height: WindowSize.fullCover,
            width: WindowSize.fullCover,
          );
        } else {
          currentBlockedApp = currentApp;
        }
      } else {
        // Foreground bloklanmagan ilova bo'lib chiqdi.
        // BIRINCHI tickdayoq overlayni yopib qo'ymaymiz: detection
        // ba'zi tickda vaqtinchalik launcher/system UI'ni qaytarib
        // yuborishi mumkin va overlay tushib qolardi. 3 ketma-ket
        // tick bloklanmagan bo'lsa — endi haqiqatan chiqib ketgan,
        // shu paytda overlayni yopamiz.
        notBlockedTicks++;
        if (notBlockedTicks >= 3) {
          currentBlockedApp = null;
          bool isOverlayActive = await FlutterOverlayWindow.isActive();
          if (isOverlayActive) {
            await FlutterOverlayWindow.closeOverlay();
          }
        }
      }
    } catch (e) {
      debugPrint('[FocusGuard] Block detection error: $e');
    }
  });
}
