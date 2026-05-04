import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'app_locker_channel',
      initialNotificationTitle: 'Focus Guard',
      initialNotificationContent: 'Qorovul xizmati faol: Ilovalar himoyalanmoqda',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
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

  // Loop every 2 seconds
  Timer.periodic(const Duration(seconds: 2), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    final blockedApps = prefs.getStringList('blocked_apps') ?? [];
    
    if (blockedApps.isEmpty) return;

    DateTime endDate = DateTime.now();
    DateTime startDate = endDate.subtract(const Duration(seconds: 10)); 
    
    try {
      List<UsageInfo> usageStats = await UsageStats.queryUsageStats(startDate, endDate);
      
      if (usageStats.isNotEmpty) {
        usageStats.sort((a, b) => int.parse(b.lastTimeUsed ?? '0').compareTo(int.parse(a.lastTimeUsed ?? '0')));
        String currentApp = usageStats.first.packageName ?? "";

        if (blockedApps.contains(currentApp)) {
          bool isOverlayActive = await FlutterOverlayWindow.isActive();
          if (!isOverlayActive) {
            await FlutterOverlayWindow.showOverlay(
              enableDrag: false,
              overlayTitle: "Focus Guard",
              overlayContent: "Ilova bloklangan",
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
      // Ignore errors in background
    }
  });
}
