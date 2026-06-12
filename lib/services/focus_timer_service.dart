import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'streak_reminder_service.dart';
import 'background_service.dart';

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

  /// Taymerni boshlash. `true` — xizmat ishga tushdi va taymer haqiqatan
  /// boshlandi; `false` — xizmat ko'tarilmadi (UI foydalanuvchiga aytadi).
  Future<bool> startTimer({
    required int minutes,
    required String modeName,
    required String modeIcon,
    required String levelTitle,
    required bool isStrict,
    required bool isLight,
    bool isPremium = false,
  }) async {
    // ROBUST START: taymer holatini AVVAL SharedPreferences'ga yozamiz.
    // Sabab: cold start'da background isolate hali to'liq ko'tarilmagan
    // bo'lsa, invoke('startTimer') eventi yo'qolishi mumkin (listener hali
    // ulanmagan). Lekin onStart restore fazasi prefs'dan timer_is_running +
    // timer_end_timestamp'ni o'qiydi — shu sababli bu yozuv kafolat beradi:
    // event yo'qolsa ham taymer baribir sanaydi va bloklash ishga tushadi.
    try {
      final prefs = await SharedPreferences.getInstance();
      final endTime = DateTime.now().add(Duration(seconds: minutes * 60));
      // Pauza budjeti — yagona manba: computePauseBudget (background
      // listener va UI dialogi ham aynan shu funksiyani chaqiradi).
      final budget = computePauseBudget(
          minutes: minutes, isPremium: isPremium, isLight: isLight);
      // Yozuvlar bir-biriga bog'liq emas — parallel yozamiz (12 ta
      // ketma-ket platform round-trip o'rniga bitta kutish).
      await Future.wait([
        prefs.setBool('timer_is_running', true),
        prefs.setBool('timer_is_paused', false),
        prefs.setInt('timer_end_timestamp', endTime.millisecondsSinceEpoch),
        prefs.setInt('session_initial_seconds', minutes * 60),
        prefs.setInt('session_credited_seconds', 0),
        prefs.setBool('timer_is_strict', isStrict),
        prefs.setBool('timer_is_light', isLight),
        prefs.setString('timer_mode_name', modeName),
        prefs.setString('timer_mode_icon', modeIcon),
        prefs.setString('timer_level_title', levelTitle),
        prefs.setInt('focus_pause_remaining_seconds', budget.seconds),
        prefs.setBool('focus_pause_unlimited', budget.unlimited),
      ]);
    } catch (e) {
      debugPrint('[FocusTimerService] prefs pre-write error: $e');
    }

    // Xizmat ishlayotganini tekshiramiz, agar yo'q bo'lsa boshlaymiz.
    // BARCHA bosqichlar himoyalangan — bironta exception ham timer
    // boshlanishini to'xtatmasligi kerak. Avval xizmat to'g'ri
    // sozlanganini kafolatlaymiz (configure), keyin start qilamiz va
    // tayyor bo'lguncha polling qilamiz (maks 3 sekund).
    bool running = false;
    try {
      // Xizmat sozlangani kafolati — main.dart'da configure fail bo'lsa ham
      // bu yerda qayta urinadi (_isServiceInitialized flag bilan idempotent).
      await initializeBackgroundService();
      running = await _service.isRunning();
      if (!running) {
        await _service.startService();
        for (int i = 0; i < 30; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          running = await _service.isRunning();
          if (running) break;
        }
      }
    } catch (e) {
      debugPrint('[FocusTimerService] startService error: $e');
    }

    if (!running) {
      // Xizmat 3 sekundda ham ko'tarilmadi — pre-write'ni QAYTARAMIZ.
      // Aks holda prefs'da "strict seans ishlayapti" degan soxta holat
      // qoladi: block_list toggle'lari qulflanadi, DnD recovery o'tkazib
      // yuboriladi, keyinroq xizmat ko'tarilsa arvoh seans uchun XP
      // yoziladi. Rollback'dan keyin foydalanuvchi qayta urinadi.
      try {
        final prefs = await SharedPreferences.getInstance();
        await Future.wait([
          prefs.setBool('timer_is_running', false),
          prefs.setBool('timer_is_strict', false),
          prefs.remove('timer_end_timestamp'),
          prefs.remove('session_initial_seconds'),
          prefs.remove('session_credited_seconds'),
        ]);
      } catch (_) {}
      debugPrint('[FocusTimerService] service failed to start — rolled back');
      return false;
    }

    _service.invoke('startTimer', {
      'minutes': minutes,
      'modeName': modeName,
      'modeIcon': modeIcon,
      'levelTitle': levelTitle,
      'isStrict': isStrict,
      'isLight': isLight,
      'isPremium': isPremium,
    });
    _isRunning = true;

    // Smart skip — foydalanuvchi fokusni boshladi, demak 11:25 da
    // "siz hali boshlamadingiz" eslatma keraksiz. Bekor qilamiz va
    // ertangi kunga qayta rejalashtiramiz.
    StreakReminderService().cancelTodayReminderIfFocused();
    return true;
  }

  /// Taymerni to'xtatish (manuil)
  Future<void> stopTimer() async {
    _service.invoke('stopTimer');
    _isRunning = false;
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
