import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'app_translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'focus_history_service.dart';

class TimerNotificationService {
  static final TimerNotificationService _instance = TimerNotificationService._internal();
  factory TimerNotificationService() => _instance;
  TimerNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const int _notificationId = 999;
  bool _initialized = false;
  bool _tzInitialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  // Timezone'ni faqat zonedSchedule'dan oldin bir marta init qilamiz.
  Future<void> _ensureTimezone() async {
    if (_tzInitialized) return;
    tz.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName.identifier));
    } catch (e) {
      debugPrint('[TimerNotif] timezone init error: $e');
    }
    _tzInitialized = true;
  }

  Future<bool> _shouldShow(String subKey) async {
    final prefs = await SharedPreferences.getInstance();
    bool main = prefs.getBool('notification_main') ?? true;
    if (!main) return false;
    if (subKey.isEmpty) return true;
    return prefs.getBool(subKey) ?? true;
  }

  /// Taymer boshlanganda bildirishnomani ko'rsat (hozircha ishlatilmaydi —
  /// foreground service notifikatsiyasi shu vazifani bajaradi).
  Future<void> showTimerNotification({
    required String timeRemaining,
    required String modeName,
    required String levelTitle,
    required String modeIcon,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await init();

    final body = '$modeIcon $modeName  |  $levelTitle';

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
      // BigTextStyle — foydalanuvchi pastga torsa to'liq matn kichikroq
      // shriftda ochiladi.
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: 'Focus Guard · $timeRemaining',
      ),
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: _notificationId,
      title: 'Focus Guard · $timeRemaining',
      body: body,
      notificationDetails: details,
    );
  }

  /// Taymerni yangilash
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

    body = body.replaceAll('{level}', newLevel.toString()).replaceAll('{rank}', rankTitle);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'achievement_channel',
      'Yutuqlar',
      channelDescription: 'Yangi darajaga erishganda tabriklash',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

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

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_goals_channel',
      'Kunlik Maqsadlar',
      channelDescription: 'Maqsadga erishilmaganda eslatish',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

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

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_goals_channel',
      'Kunlik Maqsadlar',
      channelDescription: 'Maqsadga erishilganda tabriklash',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: 889,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// 23:55 da har kuni ishlaydigan AlarmManager-based notifikatsiya.
  ///
  /// Tick-based check service tirik bo'lishini talab qiladi — Samsung
  /// "Sleeping apps" yoki battery optimization service'ni o'ldirsa
  /// notifikatsiya kelmaydi. zonedSchedule esa Android'ning o'z
  /// AlarmManager'ini ishlatadi va service o'lik bo'lsa ham fired
  /// bo'ladi.
  ///
  /// 23:55 da fired bo'lganda foydalanuvchi telefonni qo'lda olganda
  /// (yoki ekranni yoqqanda) o'sha lahzada ilova background'da bo'lmasa,
  /// notifikatsiya tap qilinganda main isolate ochiladi va FocusHistory
  /// yangilanadi. Foreground service ishlasa shu yerda darrov yoziladi.
  Future<void> scheduleDailySummary() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await init();
    await _ensureTimezone();

    final lang = AppTranslationService();

    // Goal Missed/Achieved'ni 23:55 da bitta umumiy "Kunlik yakun"
    // notifikatsiyasi sifatida yuboramiz. Notifikatsiya matnida 2-ta
    // imkoniyat ham yozilgan; foydalanuvchi Calendar'ga kirib aniq
    // natijani ko'radi. Bu yondashuv — fired-time'da SharedPreferences'ni
    // tekshirib aniq variantni yuborish (kafolatlangan emas, chunki
    // scheduled notification fire callback'i Android'da cheklangan).

    final title = lang.translate('notifications.daily_summary_title') ??
        'Kunlik yakun ⏰';
    final body = lang.translate('notifications.daily_summary_body') ??
        'Bugungi natijangizni Kalendar bo\'limida ko\'rishingiz mumkin. '
            'Kunlik maqsadga erishganmisiz?';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'daily_goals_channel',
      'Kunlik Maqsadlar',
      channelDescription: 'Har kuni 23:55 da kunlik natija eslatmasi',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    // 23:55 ga rejalashtirish
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      23,
      55,
    );
    if (when.isBefore(now)) {
      when = when.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: 890, // unique ID for daily summary scheduled notification
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'open_calendar',
    );

    debugPrint('[TimerNotif] daily summary scheduled at $when');
  }

  /// Taymer to'liq tugaganda chaqiriladigan notifikatsiya. App yopiq,
  /// telefon bloklangan bo'lsa ham foydalanuvchi eshitishi va ko'rishi
  /// uchun:
  ///   • Importance.max — heads-up va lock screen'da ko'rinadi
  ///   • playSound: true — tizim alarm tovushi (kanal sozlamasi)
  ///   • enableVibration: true — qattiq vibratsiya
  ///   • fullScreenIntent: true — telefon bloklangan bo'lsa to'liq
  ///     ekran kelishini majbur qiladi (incoming call kabi)
  ///   • category: alarm — Android tizimga "bu alarm" deydi, alarm
  ///     ringtone'i bilan chaladi
  ///   • BigTextStyle — matn to'liq ko'rinadi (kichik shriftda)
  ///
  /// Tugma matnida XP miqdori ham ko'rsatilib, motivatsiya beradi.
  Future<void> showTimerCompletedNotification({required int minutes}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await init();

    final lang = AppTranslationService();
    final title = lang.translate('notifications.timer_done_title') ??
        'Diqqat vaqti tugadi! 🎯';
    String body = lang.translate('notifications.timer_done_body') ??
        'Ajoyib! {minutes} daqiqa fokus qildingiz. +{xp} XP olasiz.';
    body = body
        .replaceAll('{minutes}', minutes.toString())
        .replaceAll('{xp}', (minutes * 10).toString());

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'timer_completed_channel',
      'Taymer Tugadi',
      channelDescription:
          'Fokus taymer tugaganda chiqadigan asosiy bildirishnoma',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      // fullScreenIntent: telefon bloklangan bo'lsa to'liq ekran chiqaradi.
      // Bu — incoming call tipidagi UX. USE_FULL_SCREEN_INTENT permission
      // talab qiladi (manifest'da deklaratsiya), aks holda bu silently
      // heads-up notification'ga tushadi.
      fullScreenIntent: true,
      // Alarm kategoriyasi — Android tizimga "bu alarm" deydi, DnD
      // (Do Not Disturb) rejimida ham chiqishi mumkin (foydalanuvchi
      // ruxsat bersa).
      category: AndroidNotificationCategory.alarm,
      // Foydalanuvchi notifikatsiyani avtomatik o'chmasligi uchun
      // (autoCancel: false), foydalanuvchi qo'l bilan o'chirsin.
      autoCancel: true,
      styleInformation:
          BigTextStyleInformation(body, contentTitle: title),
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: 555,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Bugungi yakunni darrov (real-time) yuborish — fired-time'da agar
  /// service tirik bo'lsa background_service.dart shu metodni chaqiradi.
  /// SharedPreferences'dan today_focus_seconds o'qib aniq Missed/Achieved
  /// qaysi biri kerakligini hal qiladi.
  Future<void> sendTodayResultBasedOnProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final seconds = prefs.getInt('today_focus_seconds') ?? 0;
      final goal = prefs.getInt('daily_goal_seconds') ?? 7200;
      final sessions = prefs.getInt('today_completed_sessions') ?? 0;
      final xp = prefs.getInt('today_xp_earned') ?? 0;
      // Bugungi activity progress'ni o'qiymiz
      final now = DateTime.now();
      final todayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final progressJson = prefs.getString('activity_progress_$todayKey');
      Map<String, int> activities = const {};
      if (progressJson != null) {
        try {
          final decoded = Uri.splitQueryString(progressJson);
          activities = decoded.map((k, v) => MapEntry(k, int.tryParse(v) ?? 0));
        } catch (_) {}
      }
      // history'ga yozamiz
      await FocusHistoryService.instance.recordDay(
        date: now,
        seconds: seconds,
        goal: goal,
        sessions: sessions,
        xp: xp,
        activities: activities,
      );
      if (seconds >= goal && goal > 0) {
        await showGoalAchievedNotification();
      } else {
        await showGoalMissedNotification();
      }
    } catch (e) {
      debugPrint('[TimerNotif] sendTodayResultBasedOnProgress failed: $e');
    }
  }
}
