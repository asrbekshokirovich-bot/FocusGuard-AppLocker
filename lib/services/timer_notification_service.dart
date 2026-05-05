import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

class TimerNotificationService {
  static final TimerNotificationService _instance = TimerNotificationService._internal();
  factory TimerNotificationService() => _instance;
  TimerNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const int _notificationId = 999;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Taymer boshlanganda bildirishnomani ko'rsat
  Future<void> showTimerNotification({
    required String timeRemaining,  // "44:30"
    required String modeName,       // "Chuqur Diqqat"
    required String levelTitle,     // "Мастер Фокуса · Daraja 4"
    required String modeIcon,       // emoji icon
  }) async {
    if (!Platform.isAndroid) return;
    await init();

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'focus_timer_channel',
      'Fokus Taymer',
      channelDescription: 'Fokus taymer ishlayotganda ko\'rsatiladi',
      importance: Importance.low,       // Past tovush - bezovta qilmasin
      priority: Priority.low,
      ongoing: true,                    // Foydalanuvchi yopa olmasin (taymer ishlayotganda)
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/launcher_icon',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      styleInformation: BigTextStyleInformation(
        '$modeIcon  $modeName  ·  $timeRemaining qoldi',
        contentTitle: '🎯 Focus Guard',
        summaryText: levelTitle,
      ),
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      _notificationId,
      '🎯 Focus Guard — $timeRemaining',
      '$modeIcon $modeName  ·  $levelTitle',
      details,
    );
  }

  /// Taymerni yangilash (har soniyada chaqiriladi)
  Future<void> updateTimer({
    required String timeRemaining,
    required String modeName,
    required String levelTitle,
    required String modeIcon,
  }) async {
    await showTimerNotification(
      timeRemaining: timeRemaining,
      modeName: modeName,
      levelTitle: levelTitle,
      modeIcon: modeIcon,
    );
  }

  /// Taymer to'xtaganda bildirishnomani o'chir
  Future<void> cancelTimerNotification() async {
    await _plugin.cancel(_notificationId);
  }
}
