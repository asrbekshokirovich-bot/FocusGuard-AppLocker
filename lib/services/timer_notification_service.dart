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

    await _plugin.initialize(settings: settings);
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
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/launcher_icon',
      // LargeIcon olib tashlandi (o'ng tomondagi katta logo)
      styleInformation: const DefaultStyleInformation(false, false), 
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: _notificationId,
      title: 'Focus Guard · $timeRemaining', // 1-qator: Ilova nomi va vaqt
      body: '$modeIcon $modeName  |  $levelTitle', // 2-qator: Rejim va Daraja
      notificationDetails: details,
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
    await _plugin.cancel(id: _notificationId);
  }
}
