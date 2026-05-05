import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_usage/app_usage.dart';

bool _isServiceInitialized = false;

Future<void> initializeBackgroundService() async {
  if (_isServiceInitialized) return;
  
  final service = FlutterBackgroundService();

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
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    // Android 14+ uchun kerakli sozlamalar
    service.setForegroundNotificationInfo(
      title: "Focus Guard",
      content: "Bloklash tizimi faol",
    );
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

  // Loop har 1 sekundda - tezkor aniqlash uchun
  Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
    try {
      if (blockedApps.isEmpty) return;

      DateTime endDate = DateTime.now();
      DateTime startDate = endDate.subtract(const Duration(seconds: 30));
      
      List<AppUsageInfo> infoList = await AppUsage().getAppUsage(startDate, endDate);
      
      if (infoList.isNotEmpty) {
        infoList.sort((a, b) => b.endDate.compareTo(a.endDate));
        String currentApp = infoList.first.packageName;

        // O'z ilovamiz bo'lsa hech qachon bloklamaymiz
        if (currentApp == 'com.example.focus_guard') {
          return;
        }

        if (blockedApps.contains(currentApp)) {
          bool isOverlayActive = await FlutterOverlayWindow.isActive();
          if (!isOverlayActive) {
            await FlutterOverlayWindow.showOverlay(
              enableDrag: false,
              overlayTitle: "Focus Guard",
              overlayContent: "Ilova cheklangan. Diqqatni jamlang!",
              flag: OverlayFlag.defaultFlag,
              visibility: NotificationVisibility.visibilitySecret,
              positionGravity: PositionGravity.auto,
              height: WindowSize.matchParent,
              width: WindowSize.matchParent,
            );
          }
        }
      }
    } catch (e) {
      // Xatolik bo'lsa ham loop davom etsin
    }
  });
}
