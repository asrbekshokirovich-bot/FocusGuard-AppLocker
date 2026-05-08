import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'app_translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<bool> _shouldShow(String subKey) async {
    final prefs = await SharedPreferences.getInstance();
    bool main = prefs.getBool('notification_main') ?? true;
    if (!main) return false;
    if (subKey.isEmpty) return true;
    return prefs.getBool(subKey) ?? true;
  }

  /// Taymer boshlanganda bildirishnomani ko'rsat
  Future<void> showTimerNotification({
    required String timeRemaining,  // "44:30"
    required String modeName,       // "Chuqur Diqqat"
    required String levelTitle,     // "Мастер Фокуса · Daraja 4"
    required String modeIcon,       // emoji icon
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
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

  /// Daraja oshganda tabrik xabarini ko'rsat
  Future<void> showLevelUpNotification({
    required int newLevel,
    required String rankTitle,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!await _shouldShow('notification_achievements')) return;
    await init();

    final lang = AppTranslationService();
    String title = lang.translate('notifications.level_up_title') ?? 'Yangi daraja! 🎉';
    String body = lang.translate('notifications.level_up_body') ?? 
        'Tabriklaymiz! Siz $newLevel-darajaga ko\'tarildingiz. Yangi maqomingiz: $rankTitle';
    
    // Placeholderlarni almashtirish
    body = body.replaceAll('{level}', newLevel.toString()).replaceAll('{rank}', rankTitle);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'achievement_channel',
      'Yutuqlar',
      channelDescription: 'Yangi darajaga erishganda tabriklash',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: 777,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Kunlik maqsad bajarilmaganda achinarli xabar yuborish
  Future<void> showGoalMissedNotification() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!await _shouldShow('notification_analysis')) return;
    await init();

    final lang = AppTranslationService();
    String title = lang.translate('notifications.goal_not_met_title') ?? 'Boy berilgan imkoniyat... 😔';
    String body = lang.translate('notifications.goal_not_met_body') ?? 
        'Bugun maqsadingizga erisha olmadingiz. Ertaga o\'zingizni isbotlashga va\'da berasizmi?';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_goals_channel',
      'Kunlik Maqsadlar',
      channelDescription: 'Maqsadga erishilmaganda eslatish',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: 888,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Kunlik maqsad bajarilganda tabrik xabari
  Future<void> showGoalAchievedNotification() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!await _shouldShow('notification_analysis')) return;
    await init();

    final lang = AppTranslationService();
    String title = lang.translate('notifications.goal_met_title') ?? 'Maqsad bajarildi! 🎯';
    String body = lang.translate('notifications.goal_met_body') ?? 
        'Bugungi maqsadingizga to\'liq erishdingiz! Irodangizga qoyil.';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_goals_channel',
      'Kunlik Maqsadlar',
      channelDescription: 'Maqsadga erishilganda tabriklash',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: 889,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
