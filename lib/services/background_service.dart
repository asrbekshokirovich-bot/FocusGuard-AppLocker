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
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Loop every 2.5 seconds - biroz sekinlashtiramiz barqarorlik uchun
  Timer.periodic(const Duration(milliseconds: 2500), (timer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockedApps = prefs.getStringList('blocked_apps') ?? [];
      
      if (blockedApps.isEmpty) return;

      // Usage access ruxsatini fon rejimida tekshirib bo'lmasligi mumkin, 
      // shuning uchun try-catch ichida ehtiyotkorlik bilan ishlatamiz.
      DateTime endDate = DateTime.now();
      DateTime startDate = endDate.subtract(const Duration(seconds: 15));
      
      List<AppUsageInfo> infoList = await AppUsage().getAppUsage(startDate, endDate);
      
      if (infoList.isNotEmpty) {
        infoList.sort((a, b) => b.endDate.compareTo(a.endDate));
        String currentApp = infoList.first.packageName;

        if (blockedApps.contains(currentApp)) {
          // Overlay ruxsatini tekshiramiz
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
      debugPrint('Background loop error: $e');
    }
  });
}
