import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_usage/app_usage.dart';

bool _isServiceInitialized = false;

Future<void> initializeBackgroundService() async {
  if (kIsWeb || _isServiceInitialized) return;
  
  try {
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

  // Loop har 800ms da - yanada tezroq aniqlash uchun
  Timer.periodic(const Duration(milliseconds: 800), (timer) async {
    try {
      if (blockedApps.isEmpty) return;

      DateTime endDate = DateTime.now();
      // 1 daqiqalik oynani tekshiramiz (ba'zi qurilmalarda kechikish bo'ladi)
      DateTime startDate = endDate.subtract(const Duration(minutes: 1));
      
      List<AppUsageInfo> infoList = await AppUsage().getAppUsage(startDate, endDate);
      
      if (infoList.isNotEmpty) {
        // Eng oxirgi faol ilovani juda aniq topamiz
        infoList.sort((a, b) => b.endDate.compareTo(a.endDate));
        
        // Faqat oxirgi 10 soniya ichida ishlatilgan ilovalarni ko'ramiz
        final latestInfo = infoList.first;
        if (endDate.difference(latestInfo.endDate).inSeconds > 10) {
          return; // Juda eski ma'lumot bo'lsa chetlab o'tamiz
        }

        String currentApp = latestInfo.packageName;

        // O'z ilovamiz bo'lsa bloklamaymiz
        if (currentApp == 'com.focusguard.app') {
          return;
        }

        if (blockedApps.contains(currentApp)) {
          // Overlay ruxsatini yana bir bor tekshiramiz
          bool hasOverlayPermission = await FlutterOverlayWindow.isPermissionGranted();
          if (!hasOverlayPermission) return;

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
      // Background xatoliklarni jimgina o'tkazib yuboramiz
    }
  });
}
