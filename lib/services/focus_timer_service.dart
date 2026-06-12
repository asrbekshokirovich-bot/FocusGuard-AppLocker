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

  /// Taymerni boshlash
  Future<void> startTimer({
    required int minutes,
    required String modeName,
    required String modeIcon,
    required String levelTitle,
    required bool isStrict,
    required bool isLight,
    bool isPremium = false,
  }) async {
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

    // Xizmat tayyor bo'lmasa ham invoke yuboramiz — ba'zi qurilmalarda
    // isRunning() kech true qaytaradi, lekin event navbatga tushib
    // qabul qilinadi. Agar xizmat haqiqatan ko'tarilmagan bo'lsa, keyingi
    // app resume'da startBackgroundServiceIfReady qayta urinadi.
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
