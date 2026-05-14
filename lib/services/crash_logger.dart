import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lokal "qora quti" — ilovamiz crash bo'lganda yoki kritik xato
/// yuz berganda sababini SharedPreferences'ga yozadi. Keyingi safar
/// foydalanuvchi ilovani ochganda dashboard buni banner sifatida
/// ko'rsatadi, foydalanuvchi screenshot olib bizga jo'natishi mumkin.
///
/// Bu sof Dart kutubxonasi — Android tomondan ham xuddi shu kalitlarga
/// yozish mumkin (OverlayService.java ham buni qiladi). Kalitlar
/// "flutter." prefiksi bilan boshlanadi, chunki shared_preferences
/// plagini Android tomonda har bir kalitga shu prefiksni qo'shadi.
class CrashLogger {
  CrashLogger._();
  static final CrashLogger instance = CrashLogger._();

  static const String _kReason = 'last_crash_reason';
  static const String _kSource = 'last_crash_source';
  static const String _kTime = 'last_crash_time';
  static const String _kStack = 'last_crash_stack';

  // OverlayService.java ishlatadigan kalitlar — bularni alohida
  // o'qiymiz, chunki ular Java tomondan kelganda ko'pincha aniqroq.
  static const String _kOverlayReason = 'last_overlay_crash_reason';
  static const String _kOverlaySource = 'last_overlay_crash_source';
  static const String _kOverlayTime = 'last_overlay_crash_time';

  /// Bu xato banner sifatida ko'rsatilmasligi kerakmi? "Crash" emas, balki
  /// "kutiladigan" xatolar (network, permission denied, h.k.) — ular
  /// ilova ishlashiga to'siq qilmaydi va foydalanuvchini bezovta qilmaslik
  /// kerak. Ular debugPrint'ga yoziladi, lekin diskka SAQLANMAYDI.
  bool _shouldIgnore(Object error) {
    final s = error.toString().toLowerCase();
    // Firestore permission errors — rules sozlanmagan bo'lsa kutiladi
    if (s.contains('permission-denied') ||
        s.contains('permission_denied') ||
        s.contains('cloud_firestore/permission')) {
      return true;
    }
    // Network errors — internetsiz holatda kutiladi
    if (s.contains('network') && s.contains('unavailable')) return true;
    if (s.contains('socketexception')) return true;
    if (s.contains('unable to resolve host')) return true;
    // Firebase Auth network errors
    if (s.contains('network-request-failed')) return true;
    return false;
  }

  /// Crash sababini yozish. `source` — qaysi joydan kelganini ko'rsatadi
  /// (masalan "showOverlay", "FlutterError", "PlatformDispatcher").
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    required String source,
  }) async {
    // Kutiladigan xatolarni o'tkazib yuboramiz — bu crash emas
    if (_shouldIgnore(error)) {
      debugPrint('[CrashLogger] ignored expected error: $source — $error');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final reason = '${error.runtimeType}: $error';
      await prefs.setString(_kReason, reason);
      await prefs.setString(_kSource, source);
      await prefs.setInt(_kTime, DateTime.now().millisecondsSinceEpoch);
      if (stack != null) {
        // Stack juda uzun bo'lishi mumkin — birinchi 1500 belgisini
        // saqlaymiz, banner uchun yetarli.
        final s = stack.toString();
        await prefs.setString(
          _kStack,
          s.length > 1500 ? s.substring(0, 1500) : s,
        );
      }
      debugPrint('[CrashLogger] recorded: $source — $reason');
    } catch (e) {
      debugPrint('[CrashLogger] failed to record: $e');
    }
  }

  /// Eng oxirgi crashni o'qish. Native (OverlayService.java) yozgan
  /// va Dart yozgan kalitlardan eng yangisini qaytaradi. Hech narsa
  /// yo'q bo'lsa `null` qaytadi.
  Future<CrashRecord?> getRecentCrash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final dartTime = prefs.getInt(_kTime) ?? 0;
      final nativeTime = prefs.getInt(_kOverlayTime) ?? 0;

      if (dartTime == 0 && nativeTime == 0) return null;

      if (nativeTime >= dartTime) {
        // Native (overlay service) crashi ustun
        return CrashRecord(
          source: prefs.getString(_kOverlaySource) ?? 'native',
          reason: prefs.getString(_kOverlayReason) ?? 'unknown',
          timestamp: DateTime.fromMillisecondsSinceEpoch(nativeTime),
          stack: null,
          isNative: true,
        );
      } else {
        return CrashRecord(
          source: prefs.getString(_kSource) ?? 'dart',
          reason: prefs.getString(_kReason) ?? 'unknown',
          timestamp: DateTime.fromMillisecondsSinceEpoch(dartTime),
          stack: prefs.getString(_kStack),
          isNative: false,
        );
      }
    } catch (e) {
      debugPrint('[CrashLogger] failed to read: $e');
      return null;
    }
  }

  /// Crash banner'ni foydalanuvchi yopgandan keyin chaqiriladi.
  /// Barcha crash kalitlarini tozalaydi.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kReason);
      await prefs.remove(_kSource);
      await prefs.remove(_kTime);
      await prefs.remove(_kStack);
      await prefs.remove(_kOverlayReason);
      await prefs.remove(_kOverlaySource);
      await prefs.remove(_kOverlayTime);
    } catch (_) {}
  }
}

class CrashRecord {
  final String source;
  final String reason;
  final DateTime timestamp;
  final String? stack;
  final bool isNative;

  CrashRecord({
    required this.source,
    required this.reason,
    required this.timestamp,
    required this.stack,
    required this.isNative,
  });

  /// Banner ko'rsatish uchun "yaqinmi?" — 24 soatdan keyin ko'rsatmaymiz.
  bool get isRecent =>
      DateTime.now().difference(timestamp) < const Duration(hours: 24);
}
