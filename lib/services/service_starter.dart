import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_usage/app_usage.dart';
import 'background_service.dart';

/// `focus_schedules` ichida hech bo'lmaganda bitta YOQILGAN jadval bormi?
/// Jadval focus taymeridan mustaqil ishlaydi — shu sababli yoqilgan jadval
/// bo'lsa background service ishga tushishi kerak (blocked_apps bo'sh bo'lsa ham).
bool _hasEnabledSchedules(String? raw) {
  if (raw == null || raw.isEmpty) return false;
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    for (final item in list) {
      if ((item as Map)['enabled'] == true) return true;
    }
  } catch (_) {}
  return false;
}

/// Background xizmatini ishga tushiradi (agar barcha shartlar bajarilgan bo'lsa).
/// Shartlar: (bloklangan ilovalar YOKI yoqilgan jadval) + overlay + usage stats.
///
/// Bu fayl faqat asosiy isolate ichida ishlatiladi. Shuning uchun
/// permission_handler import background_service.dart ga qo'shilmaydi.
Future<bool> startBackgroundServiceIfReady() async {
  if (kIsWeb) return false;

  try {
    final prefs = await SharedPreferences.getInstance();
    final blockedApps = prefs.getStringList('blocked_apps') ?? [];
    final hasSchedules = _hasEnabledSchedules(prefs.getString('focus_schedules'));
    // Bloklangan ilova ham, yoqilgan jadval ham bo'lmasa — service kerak emas.
    // (Eslatma: focus taymeri boshlanganda focus_timer_service uni o'zi
    // ishga tushiradi, shu sababli bu yerda blocked_apps majburiy emas.)
    if (blockedApps.isEmpty && !hasSchedules) {
      debugPrint('Service not started: no blocked apps and no enabled schedules');
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
