import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'app_translation_service.dart';

/// Foydalanuvchining shaxsiy rejalari (Reminder/Calendar plans).
///
/// Saqlash:
///   • SharedPreferences (`plans_list`) — asosiy lokal manba.
///   • Firestore `users/{uid}/plans/{id}` — bulutga zaxira (auto sync).
///
/// Notifikatsiya:
///   • Har bir reja uchun `flutter_local_notifications.zonedSchedule()`.
///   • Notif ID — har plan'da alohida (`next_plan_notif_id` counter, 10000+).
///   • `notification_main` + `notification_plans` toggle'lariga buysunadi.
///   • App startda barcha kelajakdagi rejalar qayta rejalashtiriladi (reboot fix).
class PlanService {
  PlanService._();
  static final PlanService instance = PlanService._();

  static const _prefsKey = 'plans_list';
  static const _notifIdCounterKey = 'next_plan_notif_id';
  static const _notifIdStart = 10000; // 0-9999 oraliq boshqa notif'lar uchun

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _tzInitialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: settings);

    // Notification channel'ni OLDINDAN yaratamiz. Android 8+da channel
    // birinchi marta `show()` paytida lazy yaratilardi, lekin `zonedSchedule`
    // alarm sifatida ishlaydi — fire vaqtida channel hali yo'q bo'lsa
    // bildirishnoma sukutda chiqishi mumkin. Shu sababli channel'ni
    // BOSHIDAN ro'yxatdan o'tkazib qo'yamiz.
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      const channel = AndroidNotificationChannel(
        'plan_reminder_channel',
        'Rejalar eslatmasi',
        description: 'Foydalanuvchi rejalari haqida eslatma',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await android.createNotificationChannel(channel);
    }
    _initialized = true;
  }

  /// POST_NOTIFICATIONS runtime ruxsati tekshirish. Android 13+da kerak.
  /// Yo'q bo'lsa notification jim qoladi.
  Future<bool> _hasNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('[PlanService] permission check failed: $e');
      return false;
    }
  }

  /// Android 12+da exact alarm ruxsati tekshirish. Yo'q bo'lsa
  /// SecurityException yoki silent failure bo'lishi mumkin.
  Future<bool> _canScheduleExactAlarms() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final ok = await android?.canScheduleExactNotifications();
      return ok ?? true; // bilolmasak optimistik
    } catch (e) {
      debugPrint('[PlanService] canScheduleExactNotifications failed: $e');
      return true;
    }
  }

  /// Foydalanuvchidan exact alarm ruxsatini so'rash (Android 12-13).
  /// Android 14+da USE_EXACT_ALARM avtomatik beriladi, bu chaqirilmaydi.
  /// Reja qo'shishdan OLDIN ruxsatlarni proaktiv ta'minlash. Ko'p
  /// qurilmalarda (Samsung/Xiaomi) POST_NOTIFICATIONS va "Signallar va
  /// eslatmalar" (exact alarm) ruxsatlari boshda yo'q — bo'lmasa bildirishnoma
  /// jimgina rejalashtirilmaydi yoki noaniq vaqtda keladi. Shuni oldini olamiz.
  ///
  /// Returns: ikkala ruxsat ham berilgan bo'lsa true.
  Future<bool> ensurePermissionsForScheduling() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    // 1. POST_NOTIFICATIONS (Android 13+) — runtime so'rash.
    var notif = await Permission.notification.status;
    if (!notif.isGranted) {
      notif = await Permission.notification.request();
    }
    // 2. Exact alarm (Android 12+) — yo'q bo'lsa so'rash dialogini ochamiz.
    final canExact = await _canScheduleExactAlarms();
    if (!canExact) {
      await requestExactAlarmPermission();
    }
    final canExactAfter = await _canScheduleExactAlarms();
    return notif.isGranted && canExactAfter;
  }

  Future<void> requestExactAlarmPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('[PlanService] requestExactAlarmsPermission failed: $e');
    }
  }

  Future<void> _ensureTimezone() async {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName.identifier));
    } catch (e) {
      debugPrint('[PlanService] timezone init error: $e');
    }
    _tzInitialized = true;
  }

  /// Foydalanuvchi notif'larni o'chirib qo'ygan bo'lsa — false. Master tugma + plans toggle.
  Future<bool> _notifAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    final main = prefs.getBool('notification_main') ?? true;
    if (!main) return false;
    return prefs.getBool('notification_plans') ?? true;
  }

  /// Lokal SharedPreferences'dan barcha rejalarni o'qish.
  Future<List<Plan>> getAllPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? <String>[];
    final plans = <Plan>[];
    for (final raw in list) {
      try {
        plans.add(Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (e) {
        debugPrint('[PlanService] failed to decode plan: $e');
      }
    }
    // Vaqt bo'yicha sortlash (yaqin → uzoq)
    plans.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return plans;
  }

  Future<void> _saveAllPlans(List<Plan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = plans.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_prefsKey, raw);
  }

  /// Keyingi notif ID — har plan o'ziga xos ID oladi (collision yo'q).
  Future<int> _nextNotifId() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_notifIdCounterKey) ?? _notifIdStart;
    final next = current + 1;
    await prefs.setInt(_notifIdCounterKey, next);
    return current;
  }

  /// Yangi reja qo'shish + notification rejalashtirish + Firestore'ga sync.
  /// Returns: `AddPlanResult` — yaratilgan plan + scheduling natijasi.
  Future<AddPlanResult> addPlan({
    required String title,
    required DateTime dateTime,
  }) async {
    final notifId = await _nextNotifId();
    final plan = Plan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      dateTime: dateTime,
      notifId: notifId,
    );
    final plans = await getAllPlans();
    plans.add(plan);
    await _saveAllPlans(plans);
    final schedResult = await _schedulePlanNotification(plan);
    _syncPlanToFirestore(plan);
    debugPrint('[PlanService] added plan ${plan.id} "${plan.title}" '
        'at ${plan.dateTime.toIso8601String()} '
        '(scheduled=${schedResult.scheduled}, reason=${schedResult.reason})');
    return AddPlanResult(plan: plan, schedResult: schedResult);
  }

  /// Mavjud rejani yangilash. Returns: `SchedResult` — yangi schedulingning natijasi.
  Future<SchedResult> updatePlan({
    required String id,
    required String title,
    required DateTime dateTime,
  }) async {
    final plans = await getAllPlans();
    final idx = plans.indexWhere((p) => p.id == id);
    if (idx == -1) {
      return SchedResult(
          scheduled: false, reason: SchedFailReason.scheduleError);
    }
    final oldPlan = plans[idx];
    await _cancelPlanNotification(oldPlan.notifId);
    final updated = Plan(
      id: id,
      title: title,
      dateTime: dateTime,
      notifId: oldPlan.notifId,
    );
    plans[idx] = updated;
    await _saveAllPlans(plans);
    final schedResult = await _schedulePlanNotification(updated);
    _syncPlanToFirestore(updated);
    debugPrint('[PlanService] updated plan $id '
        '(scheduled=${schedResult.scheduled})');
    return schedResult;
  }

  /// Rejani o'chirish — lokal + Firestore + notif bekor qilish.
  Future<void> deletePlan(String id) async {
    final plans = await getAllPlans();
    final idx = plans.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final plan = plans[idx];
    await _cancelPlanNotification(plan.notifId);
    plans.removeAt(idx);
    await _saveAllPlans(plans);
    _deletePlanFromFirestore(id);
    debugPrint('[PlanService] deleted plan $id');
  }

  /// Plan uchun notification rejalashtirish. O'tib ketgan rejalar
  /// rejalashtirilmaydi.
  ///
  /// Returns: `SchedResult` — rejalashtirish muvaffaqiyatli bo'ldimi va sabab.
  Future<SchedResult> _schedulePlanNotification(Plan plan) async {
    if (!await _notifAllowed()) {
      return SchedResult(scheduled: false, reason: SchedFailReason.toggleOff);
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return SchedResult(scheduled: false, reason: SchedFailReason.notAndroid);
    }
    if (plan.dateTime.isBefore(DateTime.now())) {
      return SchedResult(scheduled: false, reason: SchedFailReason.pastDate);
    }
    // POST_NOTIFICATIONS runtime ruxsati shart (Android 13+).
    if (!await _hasNotificationPermission()) {
      debugPrint('[PlanService] POST_NOTIFICATIONS denied — cannot schedule');
      return SchedResult(
          scheduled: false, reason: SchedFailReason.notificationDenied);
    }

    await _init();
    await _ensureTimezone();

    // Exact alarm ruxsati Android 12+ uchun. Bo'lmasa inexact rejimga tushamiz —
    // taxminan vaqtda chiqaradi (lekin chiqaradi).
    final canExact = await _canScheduleExactAlarms();
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final lang = AppTranslationService();
    final title = lang.translate('notifications.plan_reminder_title') ??
        'Reja vaqti yetdi! ⏰';
    final body = plan.title;

    final androidDetails = AndroidNotificationDetails(
      'plan_reminder_channel',
      lang.translate('notifications.plan_channel_name') ?? 'Rejalar eslatmasi',
      channelDescription:
          lang.translate('notifications.plan_channel_desc') ??
              'Foydalanuvchi rejalari haqida eslatma',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
      autoCancel: true,
      icon: '@mipmap/launcher_icon',
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
    );
    final details = NotificationDetails(android: androidDetails);

    final scheduled = tz.TZDateTime.from(plan.dateTime, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: plan.notifId,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: mode,
      );
      debugPrint(
          '[PlanService] scheduled notif ${plan.notifId} at $scheduled (mode=$mode)');
      return SchedResult(
          scheduled: true,
          reason: canExact ? SchedFailReason.none : SchedFailReason.inexactOnly);
    } catch (e) {
      debugPrint('[PlanService] schedule failed for ${plan.id}: $e');
      return SchedResult(
          scheduled: false, reason: SchedFailReason.scheduleError);
    }
  }

  Future<void> _cancelPlanNotification(int notifId) async {
    try {
      await _plugin.cancel(id: notifId);
    } catch (e) {
      debugPrint('[PlanService] cancel failed for $notifId: $e');
    }
  }

  /// App startda — barcha kelajakdagi rejalarni qayta rejalashtirish.
  /// Android reboot/upgrade'dan keyin scheduled alarm'lar tozalanadi,
  /// shu sababli bu metod main.dart'da chaqirilishi kerak.
  Future<void> rescheduleAllPlans() async {
    final plans = await getAllPlans();
    final now = DateTime.now();
    int scheduled = 0;
    for (final plan in plans) {
      if (plan.dateTime.isAfter(now)) {
        await _schedulePlanNotification(plan);
        scheduled++;
      }
    }
    debugPrint('[PlanService] rescheduled $scheduled future plans on app start');
  }

  /// Toggle o'zgarganda — barcha mavjud notif'larni bekor qilish yoki
  /// qayta rejalashtirish. NotificationsSettings ekran chaqiradi.
  Future<void> applyNotificationToggle() async {
    final plans = await getAllPlans();
    final allowed = await _notifAllowed();
    if (!allowed) {
      // Toggle o'chirildi — barcha rejalashtirilgan notif'larni bekor qilamiz.
      for (final plan in plans) {
        await _cancelPlanNotification(plan.notifId);
      }
      debugPrint('[PlanService] toggle off → cancelled all plan notifs');
    } else {
      // Toggle yoqildi — barcha kelajakdagi rejalarni qayta rejalashtiramiz.
      await rescheduleAllPlans();
    }
  }

  // ────────── Firestore sync (fire-and-forget) ──────────

  void _syncPlanToFirestore(Plan plan) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('plans')
        .doc(plan.id)
        .set(plan.toJson(), SetOptions(merge: true))
        .catchError((e) {
      debugPrint('[PlanService] Firestore sync failed for ${plan.id}: $e');
    });
  }

  void _deletePlanFromFirestore(String id) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('plans')
        .doc(id)
        .delete()
        .catchError((e) {
      debugPrint('[PlanService] Firestore delete failed for $id: $e');
    });
  }

  /// Bulutdan lokal'ga tiklash (foydalanuvchi yangi qurilmaga o'tganda).
  ///
  /// `overwrite`:
  ///   • false (default) — faqat lokal bo'sh bo'lsa tiklaydi. Foydalanuvchi
  ///     allaqachon yangi rejalar qo'shgan bo'lsa, ularni saqlaydi.
  ///   • true — Cloud Backup ekranidan "Bulutdan tortish" tugmasi bossa.
  Future<int> restoreFromFirestore({bool overwrite = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    try {
      // Lokal ro'yxatni tekshiramiz — bo'sh emas + overwrite yo'q bo'lsa, qaytamiz.
      if (!overwrite) {
        final localPlans = await getAllPlans();
        if (localPlans.isNotEmpty) {
          debugPrint('[PlanService] local has ${localPlans.length} plans, skipping restore');
          return 0;
        }
      }
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('plans')
          .get();
      final plans = <Plan>[];
      for (final doc in snap.docs) {
        try {
          plans.add(Plan.fromJson(doc.data()));
        } catch (e) {
          debugPrint('[PlanService] restore decode failed: $e');
        }
      }
      await _saveAllPlans(plans);
      await rescheduleAllPlans();
      debugPrint('[PlanService] restored ${plans.length} plans from cloud');
      return plans.length;
    } catch (e) {
      debugPrint('[PlanService] restoreFromFirestore failed: $e');
      return 0;
    }
  }
}

/// Bir reja yozuvi. JSON serializable.
class Plan {
  final String id;
  final String title;
  final DateTime dateTime;
  final int notifId;

  const Plan({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.notifId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dateTime': dateTime.toIso8601String(),
        'notifId': notifId,
      };

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: json['id'] as String,
        title: json['title'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        notifId: (json['notifId'] as num).toInt(),
      );
}

/// Notification rejalashtirish natijasi va sababi.
enum SchedFailReason {
  none,                  // muvaffaqiyatli
  toggleOff,             // foydalanuvchi master/plans toggle'ni o'chirgan
  notAndroid,            // web/iOS
  pastDate,              // sana o'tib ketgan
  notificationDenied,    // POST_NOTIFICATIONS ruxsati yo'q
  inexactOnly,           // exact alarm ruxsati yo'q, inexact rejimda
  scheduleError,         // zonedSchedule exception
}

class SchedResult {
  final bool scheduled;
  final SchedFailReason reason;
  const SchedResult({required this.scheduled, required this.reason});
}

class AddPlanResult {
  final Plan plan;
  final SchedResult schedResult;
  const AddPlanResult({required this.plan, required this.schedResult});
}
