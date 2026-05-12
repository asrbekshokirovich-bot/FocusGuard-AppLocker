import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';
import 'app_translation_service.dart';
import 'focus_history_service.dart';

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
    try {
      final currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone.identifier));
    } catch (e) {
      debugPrint('Timezone initialization error: $e');
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Har kuni ma'lum bir vaqtda eslatma yuborishni rejalashtirish.
  ///
  /// Smart skip mantiqi: zonedSchedule notifikatsiya AlarmManager
  /// orqali har kuni 11:25 da fired bo'ladi. LEKIN fired-time'da
  /// notification fire callback bu Android'da cheklangan. Shuning
  /// uchun biz alternativ yondashuv ishlatamiz:
  ///   • Notifikatsiya har doim schedule bo'ladi (kafolatlangan
  ///     yetkazib berish uchun).
  ///   • Notifikatsiya body matnida "agar allaqachon boshlagan
  ///     bo'lsangiz, e'tibor bermang" deyiladi.
  ///   • Yoki — agar foydalanuvchi ilovani allaqachon ochib bugungi
  ///     fokusni boshlagan bo'lsa, biz `cancelTodayReminder()` orqali
  ///     bekor qilishimiz mumkin (FocusTimerService taymerni
  ///     boshlaganda chaqirsa bo'ladi).
  Future<void> scheduleDailyReminder({int hour = 11, int minute = 25}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await init();

    final lang = AppTranslationService();

    final String title = lang.translate('notifications.streak_reminder_title') ??
        'Olovni o\'chirib qo\'ymang! 🔥';
    final String body = lang.translate('notifications.streak_reminder_body') ??
        'Bugun hali fokus qilmadingiz. Streak\'ni saqlab qolish uchun hozir vaqt ajrating!';

    // Bildirishnoma sozlamalari + BigTextStyle (matn to'liq ko'rinishi
    // uchun, foydalanuvchi notifikatsiyani pastga torsa).
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'streak_reminder_channel',
      'Streak Eslatmalari',
      channelDescription: 'Fokus qilishni eslatib turuvchi bildirishnomalar',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
    );

    final NotificationDetails details =
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
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Bugungi eslatmani bekor qilish (foydalanuvchi taymerni boshlasa
  /// chaqiriladi — bekor bo'ladi, ertangi kunga qayta rejalashtiriladi).
  /// Bu smart skip mantiqi: agar foydalanuvchi 09:00 da fokus boshlasa
  /// 11:25 da eslatma kelmaydi.
  Future<void> cancelTodayReminderIfFocused() async {
    try {
      final hasFocused =
          await FocusHistoryService.instance.hasFocusedToday();
      if (hasFocused) {
        await _plugin.cancel(id: _reminderId);
        debugPrint('[StreakReminder] today cancelled — user already focused');
        // Ertangi kun uchun yana rejalashtirib qo'yamiz
        await scheduleDailyReminder();
      }
    } catch (e) {
      debugPrint('[StreakReminder] cancelTodayReminderIfFocused failed: $e');
    }
  }

  /// Bugungi eslatmani bekor qilish
  Future<void> cancelTodayReminder() async {
    await _plugin.cancel(id: _reminderId);
    // Ertangi kun uchun yana rejalashtirib qo'yamiz
    await scheduleDailyReminder();
  }
}
