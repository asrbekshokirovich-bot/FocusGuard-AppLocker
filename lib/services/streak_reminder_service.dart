import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart';
import 'app_translation_service.dart';

class StreakReminderService {
  static final StreakReminderService _instance =
      StreakReminderService._internal();
  factory StreakReminderService() => _instance;
  StreakReminderService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const int _reminderId = 888;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Har kuni ma'lum bir vaqtda eslatma yuborishni rejalashtirish
  Future<void> scheduleDailyReminder({int hour = 10, int minute = 40}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await init();

    final lang = AppTranslationService();

    // Bildirishnoma sozlamalari
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'streak_reminder_channel',
      'Streak Eslatmalari',
      channelDescription: 'Fokus qilishni eslatib turuvchi bildirishnomalar',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    // Vaqtni hisoblash
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Agar belgilangan vaqt o'tib ketgan bo'lsa, ertangi kunga rejalashtirish
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _reminderId,
      title: lang.translate('notifications.streak_reminder_title') ??
          'Olovni o\'chirib qo\'ymang! 🔥',
      body: lang.translate('notifications.streak_reminder_body') ??
          'Bugun hali fokus qilmadingiz. Streak\'ni saqlab qolish uchun hozir vaqt ajrating!',
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Bugungi eslatmani bekor qilish
  Future<void> cancelTodayReminder() async {
    await _plugin.cancel(id: _reminderId);
    // Ertangi kun uchun yana rejalashtirib qo'yamiz
    await scheduleDailyReminder();
  }
}
