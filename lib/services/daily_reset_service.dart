import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'focus_history_service.dart';

/// Kunlik reset — har ilova ochilganda chaqiriladi (main.dart). Background
/// service uxlab qolgan bo'lsa, `today_focus_seconds` va boshqa bugungi
/// counter'lar avtomatik reset bo'lmasdi. Endi shu xizmat darrov tekshiradi:
///   - Agar saqlangan sana (YYYY-MM-DD) bugundan farqli bo'lsa →
///     o'sha kun ma'lumotini history'ga yozadi va counter'larni 0 ga tushiradi.
///
/// Avval `last_tracked_day` faqat `day` raqami (1-31) edi — oy o'tganda
/// xato bo'lardi (masalan 31-yanvar → 1-fevral, 31 != 1 ishlardi; lekin
/// 14-may → 14-iyun, 14 == 14 ishlamasdi). Endi to'liq sana saqlanadi.
class DailyResetService {
  DailyResetService._();
  static final DailyResetService instance = DailyResetService._();

  static const _key = 'last_focus_date';

  /// Bugunni `YYYY-MM-DD` formatida qaytaradi.
  String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Saqlangan oxirgi sanani bugun bilan solishtirib, kerak bo'lsa reset
  /// qiladi. Idempotent — bir kunda bir necha marta chaqirilsa ham xatosiz.
  Future<void> checkAndResetIfNewDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final today = _todayKey();
      final saved = prefs.getString(_key);

      if (saved == null) {
        // Birinchi ishga tushirish — faqat sanani belgilab qo'yamiz, hech
        // narsa reset qilmaymiz (yangi user, hali ma'lumot yo'q).
        await prefs.setString(_key, today);
        return;
      }

      if (saved == today) {
        // O'sha kun — reset kerakmas
        return;
      }

      // Kun o'tgan: kechagi/avvalgi kun ma'lumotini history'ga yozamiz.
      // Sanani `saved` (YYYY-MM-DD) dan parslaymiz.
      DateTime? lastDate;
      try {
        lastDate = DateTime.parse(saved);
      } catch (_) {}

      final seconds = prefs.getInt('today_focus_seconds') ?? 0;
      final goal = prefs.getInt('daily_goal_seconds') ?? 7200;
      final sessions = prefs.getInt('today_completed_sessions') ?? 0;
      final xp = prefs.getInt('today_xp_earned') ?? 0;

      if (lastDate != null && seconds > 0) {
        // Avvalgi kun ma'lumotini saqlaymiz — Calendar history'da turadi.
        final progressJson = prefs.getString('activity_progress_$saved');
        Map<String, int> activities = const {};
        if (progressJson != null) {
          try {
            final decoded = Uri.splitQueryString(progressJson);
            activities = decoded.map((k, v) => MapEntry(k, int.tryParse(v) ?? 0));
          } catch (_) {}
        }
        await FocusHistoryService.instance.recordDay(
          date: lastDate,
          seconds: seconds,
          goal: goal,
          sessions: sessions,
          xp: xp,
          activities: activities,
        );
      }

      // Bugungi counter'larni 0 ga tushuramiz.
      await prefs.setInt('today_focus_seconds', 0);
      await prefs.setInt('today_completed_sessions', 0);
      await prefs.setInt('today_xp_earned', 0);
      // Background service'dagi eski `last_tracked_day` ni ham yangilab
      // qo'yamiz — bir paytning o'zida ikkita reset bo'lmasligi uchun.
      await prefs.setInt('last_tracked_day', DateTime.now().day);
      // O'z kalitimizni yangilaymiz.
      await prefs.setString(_key, today);

      debugPrint('[DailyReset] day changed: $saved → $today, '
          'archived seconds=$seconds, sessions=$sessions, xp=$xp');
    } catch (e) {
      debugPrint('[DailyReset] checkAndResetIfNewDay failed: $e');
    }
  }
}
