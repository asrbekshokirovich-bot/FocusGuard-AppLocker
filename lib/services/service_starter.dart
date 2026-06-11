import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_usage/app_usage.dart';
import 'package:usage_stats/usage_stats.dart';
import 'background_service.dart';

/// Background xizmatini ishga tushiradi (agar barcha shartlar bajarilgan bo'lsa).
/// Shartlar: bloklangan ilovalar bor + overlay ruxsat + usage stats ruxsat.
///
/// Bu fayl faqat asosiy isolate ichida ishlatiladi. Shuning uchun
/// permission_handler import background_service.dart ga qo'shilmaydi.
/// Bloklash ishlashi uchun yetarli ruxsatlar bormi (overlay + usage stats).
/// Login/onboarding'dan keyin foydalanuvchini PermissionsScreen'ga
/// yo'naltirish kerakmi yo'qmi — shuni hal qilish uchun ishlatiladi.
Future<bool> hasBlockingPermissions() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
  try {
    final overlayOk = await Permission.systemAlertWindow.isGranted;
    if (!overlayOk) return false;
    // Avval tez yo'l: UsageStats.checkUsagePermission()
    bool usageOk = false;
    try {
      usageOk = await UsageStats.checkUsagePermission() ?? false;
    } catch (_) {}
    if (!usageOk) {
      // Fallback: AppUsage query (agar checkUsagePermission ishlamasa)
      try {
        final now = DateTime.now();
        await AppUsage()
            .getAppUsage(now.subtract(const Duration(seconds: 1)), now)
            .timeout(const Duration(milliseconds: 2000));
        usageOk = true;
      } catch (_) {}
    }
    return usageOk;
  } catch (_) {
    return false;
  }
}

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
      usageOk = await UsageStats.checkUsagePermission() ?? false;
    } catch (_) {}
    if (!usageOk) {
      try {
        final now = DateTime.now();
        await AppUsage()
            .getAppUsage(now.subtract(const Duration(seconds: 1)), now)
            .timeout(const Duration(milliseconds: 2000));
        usageOk = true;
      } catch (_) {}
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
