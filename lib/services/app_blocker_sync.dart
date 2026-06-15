import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ilovalarni bloklash — AccessibilityService bilan bog'lovchi qatlam.
///
/// Bloklash endi native `AppBlockerService` (AccessibilityService) orqali
/// amalga oshiriladi — bu haqiqiy app-blocker'lar ishlatadigan ishonchli,
/// event-asosli usul (UsageStats + fon izolati o'rniga). Bu servis:
///   1. Bloklangan ilovalar ro'yxati va jadvalni native o'qiy oladigan
///      sodda kalitlarga ko'chiradi (`native_blocked_csv`, `native_schedules_json`).
///   2. AccessibilityService yoqilganini tekshiradi va Sozlamani ochadi.
class AppBlockerSync {
  AppBlockerSync._();
  static final AppBlockerSync instance = AppBlockerSync._();

  static const MethodChannel _channel = MethodChannel('focusguard/accessibility');

  /// Dart'dagi `blocked_apps` (StringList) va `focus_schedules`'ni native
  /// AccessibilityService o'qiy oladigan sodda kalitlarga yozadi. Ilova
  /// bloklash/jadval o'zgargan har safar va ishga tushganda chaqiriladi.
  Future<void> syncToNative() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blocked = prefs.getStringList('blocked_apps') ?? const [];
      await prefs.setString('native_blocked_csv', blocked.join(','));
      final schedules = prefs.getString('focus_schedules') ?? '';
      await prefs.setString('native_schedules_json', schedules);
    } catch (e) {
      debugPrint('[AppBlockerSync] syncToNative failed: $e');
    }
  }

  /// Deep Focus pauza paytida bloklashni vaqtincha o'chirish/yoqish.
  /// (Pauza budjeti doirasida foydalanuvchi bloklangan ilovaga kira oladi.)
  Future<void> setBlockingPaused(bool paused) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('native_block_paused', paused);
    } catch (_) {}
  }

  /// AppBlockerService (AccessibilityService) yoqilganmi.
  Future<bool> isEnabled() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Tizim "Maxsus imkoniyatlar" (Accessibility) sahifasini ochadi —
  /// foydalanuvchi FocusGuard xizmatini qo'lda yoqadi.
  Future<void> openSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('openSettings');
    } catch (_) {}
  }
}
