import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Markaziy "qora quti" — har kunlik fokus statistikasini saqlaydi.
///
/// Bu service ilovaning yagona ishonchli manbaidir:
///   • Calendar ekrani shu yerdan ✅/❌ ma'lumotini oladi.
///   • Goal Missed/Achieved notifikatsiyalari shu yerga yozadi.
///   • Streak Reminder bugungi fokus borligini shu yerdan tekshiradi.
///   • Streak hisoblash ham shu yerdan amalga oshiriladi.
///
/// SharedPreferences'da har bir kun alohida kalit sifatida saqlanadi:
///   focus_history_2025-01-15 → '{"seconds":14400,"goal":14400,"met":true}'
///
/// Bu yondashuv 1 yillik tarix ~30 KB joy egallaydi (juda kichik).
class FocusHistoryService {
  FocusHistoryService._();
  static final FocusHistoryService instance = FocusHistoryService._();

  static const String _keyPrefix = 'focus_history_';

  /// Sana formatlash: DateTime → "2025-01-15" (Calendar standart format,
  /// til/timezone bog'liq emas, alfabetik sortlash sanaga teng).
  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$_keyPrefix$y-$m-$d';
  }

  /// Bir kunni yozish. Agar `seconds >= goal` bo'lsa `met=true` ko'rsatiladi.
  /// Bir xil kunga qayta chaqirilsa eski yozuvni ustidan yozadi (idempotent).
  Future<void> recordDay({
    required DateTime date,
    required int seconds,
    required int goal,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final record = DayRecord(
        seconds: seconds,
        goal: goal,
        met: seconds >= goal && goal > 0,
      );
      await prefs.setString(_dateKey(date), jsonEncode(record.toJson()));
      debugPrint('[FocusHistory] saved ${_dateKey(date)}: '
          '${record.seconds}s / ${record.goal}s (met=${record.met})');
    } catch (e) {
      debugPrint('[FocusHistory] recordDay failed: $e');
    }
  }

  /// Bir kunning yozuvini olish. Mavjud bo'lmasa `null` qaytaradi.
  ///
  /// MUHIM: agar so'ralgan sana BUGUNGI kun bo'lsa, biz history'ga
  /// hali yozilmagan bo'lsa ham SharedPreferences'dan jonli (live)
  /// ma'lumotni o'qib qaytaramiz. Bu Calendar bugungi maqsadning
  /// real-time progress'ini ko'rsata olishi uchun zarur — aks holda
  /// foydalanuvchi taymerni ishlatib qo'ygan bo'lsa ham Calendar
  /// uchun bugungi kun "ma'lumot yo'q" ko'rinardi (chunki history
  /// yozuvi faqat ertaga 00:00 da kun reset bo'lganda saqlanadi).
  Future<DayRecord?> getDay(DateTime date) async {
    try {
      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // boshqa isolate yozgan bo'lsa freshni o'qiymiz

      if (isToday) {
        final seconds = prefs.getInt('today_focus_seconds') ?? 0;
        final goal = prefs.getInt('daily_goal_seconds') ?? 14400;
        return DayRecord(
          seconds: seconds,
          goal: goal,
          met: seconds >= goal && goal > 0,
        );
      }

      final raw = prefs.getString(_dateKey(date));
      if (raw == null) return null;
      return DayRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[FocusHistory] getDay failed: $e');
      return null;
    }
  }

  /// Bir oyning hamma yozuvlarini olish — Calendar ekrani uchun. Map'da
  /// kalit — kun raqami (1..31), qiymat — DayRecord.
  ///
  /// Bugungi kun uchun ham yozuv qo'shamiz — `today_focus_seconds` va
  /// `daily_goal_seconds` dan live ravishda qurib. Bu Calendar bugungi
  /// progressni ko'rsata olishi uchun.
  Future<Map<int, DayRecord>> getMonthRecords(int year, int month) async {
    final Map<int, DayRecord> result = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      // Oyning oxirgi kuni: keyingi oyning 0-kuni
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final now = DateTime.now();
      for (int d = 1; d <= daysInMonth; d++) {
        final date = DateTime(year, month, d);
        final isToday = date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
        if (isToday) {
          final seconds = prefs.getInt('today_focus_seconds') ?? 0;
          final goal = prefs.getInt('daily_goal_seconds') ?? 14400;
          result[d] = DayRecord(
            seconds: seconds,
            goal: goal,
            met: seconds >= goal && goal > 0,
          );
          continue;
        }
        final raw = prefs.getString(_dateKey(date));
        if (raw == null) continue;
        try {
          result[d] = DayRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[FocusHistory] getMonthRecords failed: $e');
    }
    return result;
  }

  /// Bugun foydalanuvchi fokus qilganmi? Streak Reminder shu metodga
  /// qaraydi — agar `true` bo'lsa 11:25 da notifikatsiya yubormaydi.
  Future<bool> hasFocusedToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      // Bugungi sekundlar live ravishda `today_focus_seconds` da turadi
      // (background_service.dart har soniyada yangilaydi).
      final seconds = prefs.getInt('today_focus_seconds') ?? 0;
      return seconds > 0;
    } catch (_) {
      return false;
    }
  }

  /// Uzluksiz "goal met" kunlari — bugundan orqaga ketaman. Bugun
  /// hisobga olinmaydi (chunki 23:59 da yopilmaguncha noma'lum),
  /// kechagi kundan boshlanadi. Maksimal 365 kun qarab chiqiladi.
  Future<int> getStreak() async {
    int streak = 0;
    try {
      DateTime cursor =
          DateTime.now().subtract(const Duration(days: 1));
      for (int i = 0; i < 365; i++) {
        final rec = await getDay(cursor);
        if (rec == null || !rec.met) break;
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    } catch (e) {
      debugPrint('[FocusHistory] getStreak failed: $e');
    }
    return streak;
  }

  /// Joriy oy uchun qisqa hisobot — Calendar ekranida pastda ko'rsatiladi.
  Future<MonthSummary> getMonthSummary(int year, int month) async {
    final records = await getMonthRecords(year, month);
    int focused = 0;
    int missed = 0;
    for (final r in records.values) {
      if (r.met) {
        focused++;
      } else {
        missed++;
      }
    }
    return MonthSummary(focused: focused, missed: missed);
  }
}

/// Bir kunning yozuvi — `focus_history_YYYY-MM-DD` kalit ostida saqlanadi.
class DayRecord {
  final int seconds;
  final int goal;
  final bool met;

  const DayRecord({
    required this.seconds,
    required this.goal,
    required this.met,
  });

  Map<String, dynamic> toJson() => {
        'seconds': seconds,
        'goal': goal,
        'met': met,
      };

  factory DayRecord.fromJson(Map<String, dynamic> json) => DayRecord(
        seconds: (json['seconds'] as num?)?.toInt() ?? 0,
        goal: (json['goal'] as num?)?.toInt() ?? 0,
        met: json['met'] as bool? ?? false,
      );
}

/// Oy bo'yicha qisqa hisobot — Calendar ekranida ko'rsatiladi.
class MonthSummary {
  final int focused;
  final int missed;

  const MonthSummary({required this.focused, required this.missed});
}
