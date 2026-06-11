import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_usage/app_usage.dart';
import 'background_service.dart';

/// Background xizmatini ishga tushiradi (agar barcha shartlar bajarilgan bo'lsa).
/// Shartlar: bloklangan ilovalar bor + overlay ruxsat + usage stats ruxsat.
///
/// Bu fayl faqat asosiy isolate ichida ishlatiladi. Shuning uchun
/// permission_handler import background_service.dart ga qo'shilmaydi.
Future<bool> startBackgroundServiceIfReady() async {
  if (kIsWeb) return false;

  try {
    final prefs = await SharedPreferences.getInstance();
    final blockedApps = prefs.getStringList('blocked_apps') ?? [];
    if (blockedApps.isEmpty) {
      debugPrint('Service not started: no blocked apps');
      return false;
    }

    bool overlayOk = await Permission.systemAlertWindow.isGranted;
    if (!overlayOk) {
      debugPrint('Service not started: overlay permission missing');
      return false;
    }

    bool usageOk = false;
    try {
      // 30 daqiqalik oyna — 1 soniyalik oyna ba'zi qurilmalarda permission
      // berilgan bo'lsa ham xato tashlardi (bo'sh diapazon) va service
      // bekorga ishga tushmasdi.
      final now = DateTime.now();
      await AppUsage()
          .getAppUsage(now.subtract(const Duration(minutes: 30)), now);
      usageOk = true;
    } catch (_) {
      usageOk = false;
    }
    if (!usageOk) {
      debugPrint('Service not started: usage stats permission missing');
      return false;
    }

    await initializeBackgroundService();
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
      debugPrint('Background service started');
    } else {
      debugPrint('Background service already running');
    }
    return true;
  } catch (e) {
    debugPrint('startBackgroundServiceIfReady error: $e');
    return false;
  }
}
