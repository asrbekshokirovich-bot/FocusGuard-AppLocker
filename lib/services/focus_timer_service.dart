import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'streak_reminder_service.dart';

class FocusTimerService {
  static final FocusTimerService _instance = FocusTimerService._internal();
  factory FocusTimerService() => _instance;
  FocusTimerService._internal();

  final _service = FlutterBackgroundService();
  
  // Taymer holati haqida UI ga xabar berish uchun
  final _timerController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get timerStream => _timerController.stream;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Xizmatni va listenerlarni ishga tushirish
  Future<void> init() async {
    _service.on('timerTick').listen((event) {
      if (event != null) {
        _timerController.add(event);
        _isRunning = event['isRunning'] ?? false;
      }
    });

    // Timer tabiiy tugaganda background service shu eventni yuboradi.
    // UI bu signalni tutib alarm dismiss dialog ko'rsatadi.
    _service.on('timerFinished').listen((event) {
      _isRunning = false;
      _timerController.add({
        'timerFinished': true,
        'minutes': event?['minutes'] ?? 0,
        'isRunning': false,
        'isPaused': false,
        'seconds': 0,
      });
    });
  }

  /// Alarm ringtoni va flagini o'chirish — background service orqali.
  Future<void> stopAlarm() async {
    _service.invoke('stopAlarm');
  }

  /// Xizmat haqiqatan ishga tushganiga ishonch hosil qiladi.
  ///
  /// Avval bu yerda qat'iy 500ms kutish bor edi — background isolate'ning
  /// sovuq starti (yangi FlutterEngine + plugin registratsiyasi) real
  /// qurilmalarda 1-3 soniya olishi mumkin, shuning uchun `invoke` ba'zan
  /// hali listener'lari tayyor bo'lmagan xizmatga ketib JIMGINA yo'qolardi
  /// ("tugma bosildi, taymer sanamadi" bug'ining bir qismi). Endi polling
  /// bilan maksimal ~6 soniya kutamiz.
  Future<bool> _ensureServiceRunning() async {
    try {
      if (await _service.isRunning()) return true;
      await _service.startService();
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (await _service.isRunning()) return true;
      }
    } catch (e) {
      debugPrint('[FocusTimerService] ensureServiceRunning failed: $e');
    }
    return false;
  }

  /// Taymerni boshlash.
  ///
  /// MUSTAHKAM START PROTOKOLI (invoke yo'qolishiga chidamli):
  ///   1. Taymer holatini AVVAL SharedPreferences'ga to'liq yozamiz.
  ///      Background service sovuq startda o'zining restore bloki orqali
  ///      aynan shu kalitlarni o'qib taymerni tiklaydi — ya'ni `invoke`
  ///      yo'qolib ketsa ham taymer baribir ishlaydi.
  ///   2. Xizmat ishlayotganiga polling bilan ishonch hosil qilamiz.
  ///   3. `startTimer` invoke yuboramiz — xizmat allaqachon ishlayotgan
  ///      bo'lsa darhol qabul qiladi; endigina ishga tushgan bo'lsa restore
  ///      allaqachon prefs'dan tiklagan, invoke esa shunchaki qayta sync
  ///      qiladi (idempotent).
  Future<void> startTimer({
    required int minutes,
    required String modeName,
    required String modeIcon,
    required String levelTitle,
    required bool isStrict,
    required bool isLight,
  }) async {
    // 1-qadam: holatni avval diskka yozamiz — yagona haqiqat manbai.
    final prefs = await SharedPreferences.getInstance();
    final totalSeconds = minutes * 60;
    final endTime = DateTime.now().add(Duration(seconds: totalSeconds));
    await prefs.setInt('timer_end_timestamp', endTime.millisecondsSinceEpoch);
    await prefs.setInt('session_initial_seconds', totalSeconds);
    await prefs.setBool('timer_is_running', true);
    await prefs.setBool('timer_is_paused', false);
    await prefs.setBool('timer_is_strict', isStrict);
    await prefs.setBool('timer_is_light', isLight);
    await prefs.setString('timer_mode_name', modeName);
    await prefs.setString('timer_mode_icon', modeIcon);
    await prefs.setString('timer_level_title', levelTitle);

    // 2-qadam: xizmat ishga tushganiga ishonch hosil qilamiz.
    final serviceUp = await _ensureServiceRunning();

    // 3-qadam: invoke — ishlayotgan xizmatga to'g'ridan-to'g'ri buyruq.
    // Guard: polling davomida (sovuq startda bir necha soniya) foydalanuvchi
    // Stop bosib ulgurgan bo'lishi mumkin — u holda invoke yubormaymiz,
    // aks holda UI "to'xtagan" ko'rsatib service'da sharpa taymer ishlardi.
    final stillWanted = prefs.getBool('timer_is_running') ?? false;
    if (serviceUp && stillWanted) {
      _service.invoke('startTimer', {
        'minutes': minutes,
        'modeName': modeName,
        'modeIcon': modeIcon,
        'levelTitle': levelTitle,
        'isStrict': isStrict,
        'isLight': isLight,
      });
    } else if (!serviceUp) {
      debugPrint('[FocusTimerService] service failed to start — '
          'timer state persisted, will recover on next service start');
    } else {
      debugPrint('[FocusTimerService] start aborted — user stopped during '
          'service cold start');
      return; // foydalanuvchi polling paytida Stop bosgan
    }
    _isRunning = true;

    // Smart skip — foydalanuvchi fokusni boshladi, demak 11:25 da
    // "siz hali boshlamadingiz" eslatma keraksiz. Bekor qilamiz va
    // ertangi kunga qayta rejalashtiramiz.
    StreakReminderService().cancelTodayReminderIfFocused();
  }

  /// Taymerni to'xtatish (manuil)
  Future<void> stopTimer() async {
    _service.invoke('stopTimer');
    _isRunning = false;
    // Prefs'dagi running holatini UI tomondan ham darhol tozalaymiz.
    // Aks holda service o'lik bo'lsa `timer_is_running=true` qolib,
    // keyingi service startida "sharpa taymer" qayta tiklanardi.
    // Service tirik bo'lsa uning stopTimer listener'i ham xuddi shu
    // qiymatlarni yozadi — idempotent, to'qnashuv yo'q.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('timer_is_running', false);
      await prefs.setBool('timer_is_paused', false);
      await prefs.remove('timer_end_timestamp');
    } catch (_) {}
  }

  /// Taymerni vaqtincha to'xtatish
  Future<void> pauseTimer() async {
    _service.invoke('pauseTimer');
    _isRunning = false;
  }

  /// Taymerni davom ettirish
  Future<void> resumeTimer() async {
    _service.invoke('resumeTimer');
    _isRunning = true;
  }

  /// Hozirgi holatni olish (masalan, ilova qayta ochilganda)
  Future<void> syncState() async {
    _service.invoke('requestTimerSync');
  }

  /// Kunlik maqsadni yangilash
  Future<void> updateDailyGoal(int seconds) async {
    _service.invoke('updateDailyGoal', {'seconds': seconds});
  }
}
