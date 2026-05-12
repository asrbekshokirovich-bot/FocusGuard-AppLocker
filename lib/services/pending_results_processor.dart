import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'level_service.dart';

/// Background → Main isolate o'rtasidagi "pending queue" tahlilchisi.
///
/// Background service (alohida isolate) Firebase Auth contextiga ega
/// emas — XP, streak va Firestore yangilanishini bevosita bajara
/// olmaydi. Buning o'rniga `background_service.dart` SharedPreferences'ga
/// pending qiymatlarni yozib qo'yadi:
///
///   pending_xp_minutes       (int)    — kutilayotgan XP daqiqalari
///   pending_streak_date      (String) — YYYY-MM-DD, bugun fokus boshlandi
///   pending_completion_count (int)    — to'liq tugagan sessiyalar soni
///
/// Foydalanuvchi app'ni ochganda — bu service shu kalitlarni o'qib,
/// `LevelService.addXP()` va `LevelService.updateStreak()` chaqiradi,
/// va keyin pending flag'larni tozalaydi. Bu yondashuv:
///
///   • App yopiq bo'lganda tugagan taymerlar uchun XP yo'qotilmaydi
///   • Background → Firestore to'g'ridan-to'g'ri yozish kerak emas
///   • Atomic — bir tomon yozadi, ikkinchi tomon o'qib o'chiradi
///   • Idempotent — agar ikki marta chaqirilsa, ikkinchisi bo'sh
class PendingResultsProcessor {
  PendingResultsProcessor._();
  static final PendingResultsProcessor instance = PendingResultsProcessor._();

  /// Birorta sessiyada birdan ortiq marta chaqirilmasligi uchun guard.
  /// initState'da chaqirilganda race condition'lardan saqlanish.
  bool _busy = false;

  /// App ochilganda yoki resume bo'lganda chaqiriladi. Pending'da
  /// XP/streak bor bo'lsa, ularni qayta ishlaydi va tozalaydi.
  ///
  /// Bir nechta marta chaqirilsa ham xavfsiz — _busy guard va atomic
  /// remove() ishlatish bilan duplicate'lar oldini olamiz.
  Future<void> processOnAppOpen() async {
    if (_busy) {
      debugPrint('[PendingProcessor] already busy, skip');
      return;
    }
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      // CRITICAL: boshqa isolate yozgan qiymatlar uchun cache'ni reset
      await prefs.reload();

      // 1) Pending XP
      final pendingXp = prefs.getInt('pending_xp_minutes') ?? 0;
      if (pendingXp > 0) {
        debugPrint('[PendingProcessor] processing $pendingXp XP minutes');
        // Avval prefs'dan o'chirib qo'yamiz — agar addXP fail bo'lsa
        // ikkinchi safar qayta-qayta yozilmasligi uchun. Idempotency'ni
        // saqlash uchun bu eng muhim qadam.
        await prefs.remove('pending_xp_minutes');
        try {
          await LevelService().addXP(pendingXp);
        } catch (e) {
          debugPrint('[PendingProcessor] addXP failed: $e — re-queuing');
          // Agar Firestore offline va saqlay olmasa, qayta queuega
          // yozib qo'yamiz — keyingi safarda urinish qilamiz.
          final retryPending = (prefs.getInt('pending_xp_minutes') ?? 0) +
              pendingXp;
          await prefs.setInt('pending_xp_minutes', retryPending);
        }
      }

      // 2) Pending streak — kuniga 1 marta yangilanadi.
      // pending_streak_date YYYY-MM-DD formatida. Agar bugun bo'lsa va
      // hali yangilanmagan bo'lsa — update qilamiz.
      final pendingDate = prefs.getString('pending_streak_date');
      if (pendingDate != null) {
        final today = _todayDateKey();
        if (pendingDate == today) {
          // Bugun uchun streak yangilanishini Firestore tomonda
          // updateStreak idempotent qilishga ishonamiz (lastFocusDate
          // bilan check qiladi). Avval o'chirib qo'yamiz.
          await prefs.remove('pending_streak_date');
          try {
            await LevelService().updateStreak();
            debugPrint('[PendingProcessor] streak updated for $today');
          } catch (e) {
            debugPrint('[PendingProcessor] updateStreak failed: $e');
            // Qaytadan queuega yozamiz
            await prefs.setString('pending_streak_date', today);
          }
        } else {
          // Eski sana — tozalaymiz (ehtimol kechagi noma'lum tarix)
          await prefs.remove('pending_streak_date');
        }
      }

      // 3) Completion count — hozir faqat tozalaymiz, kelajakda stats
      // ekraniga ko'rsatish uchun ishlatish mumkin.
      final completions = prefs.getInt('pending_completion_count') ?? 0;
      if (completions > 0) {
        debugPrint(
            '[PendingProcessor] $completions sessions completed in background');
        await prefs.remove('pending_completion_count');
      }
    } catch (e, st) {
      debugPrint('[PendingProcessor] error: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  String _todayDateKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
