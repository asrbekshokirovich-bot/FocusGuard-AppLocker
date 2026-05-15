import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'premium_screen.dart';
import '../services/app_translation_service.dart';
import 'dart:math' as math;

import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/language_service.dart';
import '../services/level_service.dart';
import '../services/focus_timer_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}
class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;

  // Real data
  List<double> _weeklyHours = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  Map<String, int> _activityProgress = {};
  List<Map<String, dynamic>> _customActivities = [];
  bool _isDataLoading = true;
  int _streak = 0;
  int _level = 1;
  int _xp = 0;
  int _totalMinutes = 0;
  // Lokal'dan hisoblanadigan metriklar — internetdan mustaqil.
  int _totalSessions = 0;
  // Eng uzun seans — sekund aniqligida (yangi `longest_session_seconds` kalit).
  // Statistika ekrani "Xmin Ysek" yoki "Xs Ymin" formatda chiqaradi.
  int _longestSessionSeconds = 0;
  // Real haftalik ma'lumot: 7 ta soat qiymati (Du-Ya, joriy hafta).
  List<double> _realWeeklyHours = [0, 0, 0, 0, 0, 0, 0];
  // Real oylik ma'lumot: 4-5 ta soat qiymati (oydagi haftalar).
  List<double> _realMonthlyHours = [0, 0, 0, 0];
  // Detalizatsiya uchun — har hafta ichidagi 7 kun.
  List<List<double>> _realMonthlyDays = [];
  // Bugungi maqsadga erishish foizi (real)
  int _todayGoalPercent = 0;
  // So'nggi 7 kun o'rtachasi (real, soatda)
  double _weeklyAvgHours = 0.0;
  // Fokus balli (0-100): so'nggi 7 kun maqsad/erishish nisbati
  int _focusScore = 0;
  // Aqlli Tahlil (PRO) — orqa fonida doim hisoblanadi
  int _dailyCompDiffMinutes = 0;
  double _weeklyChangePercent = 0.0;
  double _weekEndForecastHours = 0.0;
  int _streakForecastDays = 0;
  // Top eng ko'p kirishga urinilgan ilovalar (so'nggi 30 kun).
  // Har element: {package: String, name: String, count: int}
  List<Map<String, dynamic>> _topBlockedAttempts = [];
  // Yengil Fokus (Light Focus) rejimida o'tkazilgan jami vaqt (sekundda).
  // Foydalanuvchi mode==1 (yengil fokus) tanlasa, background service har
  // soniya `light_focus_total_seconds` ni oshiradi. Bu hisob umumiy
  // statistika emas — alohida ko'rsatkich.
  int _lightFocusTotalSeconds = 0;
  StreamSubscription? _timerSub;
  Timer? _refreshTimer;
  final List<String> _weekDays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _loadRealData();

    // Live yangilanish: timer stream'ga ulanamiz. Har timer tick'da
    // (taymer ishlasa) yoki tugashda ekran avtomatik yangilanadi.
    // Internet kerakmas — lokal SharedPreferences'dan o'qiymiz.
    _timerSub = FocusTimerService().timerStream.listen((_) {
      if (mounted) _refreshLocalStats();
    });

    // Backup: har 3 soniyada lokal qiymatlarni qayta o'qiymiz
    // (taymer ishlamayotgan bo'lsa ham ekran ochiq turganida yangilanib turadi).
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _refreshLocalStats();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App qayta foreground'ga kelganda darrov yangilash
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshLocalStats();
    }
  }

  /// Lokal SharedPreferences'dan barcha statistik qiymatlarni qayta o'qish.
  /// Internet kerakmas, har qanday vaqtda chaqirilsa bo'ladi.
  Future<void> _refreshLocalStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final today = DateTime.now().toString().split(' ')[0];

      // Faoliyatlar ro'yxati — Dashboard'da qo'shilgan/o'chirilgan bo'lsa
      // bu yerda darrov ko'rinishi uchun har refresh'da qayta o'qiymiz.
      final activitiesJson = prefs.getStringList('custom_activities');
      List<Map<String, dynamic>> loadedActivities = [];
      if (activitiesJson != null) {
        loadedActivities = activitiesJson
            .map((a) => Map<String, dynamic>.from(Uri.splitQueryString(a)))
            .toList();
        for (var a in loadedActivities) {
          a['minutes'] = int.tryParse(a['minutes'].toString()) ?? 25;
        }
      }

      // Bugungi activity progress'ni live o'qiymiz
      final progressJson = prefs.getString('activity_progress_$today');
      Map<String, int> loadedProgress = {};
      if (progressJson != null) {
        final decoded = Uri.splitQueryString(progressJson);
        loadedProgress =
            decoded.map((k, v) => MapEntry(k, int.tryParse(v) ?? 0));
      }
      // Lokal history'dan jami seanslar va eng uzun seansni hisoblash.
      // BUGUNGI history yozuvi `today_completed_sessions` qiymatini ham
      // o'z ichiga olishi mumkin (background service har timer tugashida
      // recordDay chaqiradi). Shuning uchun bugungi kalitni ATKAB
      // o'tkazib yuboramiz — aks holda bir kun ikki marta hisoblanardi.
      int totalSessions = prefs.getInt('today_completed_sessions') ?? 0;
      final now = DateTime.now();
      final todayKey =
          'focus_history_${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      for (final key in prefs.getKeys()) {
        if (!key.startsWith('focus_history_')) continue;
        if (key == todayKey) continue; // bugungi kunni `today_*` dan oldik
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          totalSessions += (data['sessions'] as num?)?.toInt() ?? 0;
        } catch (_) {}
      }
      // Eng uzun seans — yangi sekund kaliti, eskisi (minutes) backward-compat.
      final longestSec = prefs.getInt('longest_session_seconds') ??
          ((prefs.getInt('longest_session_minutes') ?? 0) * 60);
      final lightTotal = prefs.getInt('light_focus_total_seconds') ?? 0;

      // Real haftalik/oylik ma'lumotlarni history'dan hisoblash
      final chartData = await _computeChartData(prefs);

      // So'nggi 30 kun ichidagi top bloklangan ilovalarga urinishlar.
      // Ikonkasi yo'q ilovalar uchun fonda yuklab cache'ga qo'yamiz.
      final topAttempts = _computeTopBlockedAttempts(prefs);
      _fetchMissingIcons(prefs, topAttempts);

      if (mounted) {
        setState(() {
          _customActivities = loadedActivities;
          _activityProgress = loadedProgress;
          _totalSessions = totalSessions;
          _longestSessionSeconds = longestSec;
          _lightFocusTotalSeconds = lightTotal;
          _realWeeklyHours = chartData.weeklyHours;
          _realMonthlyHours = chartData.monthlyHours;
          _realMonthlyDays = chartData.monthlyDays;
          _todayGoalPercent = chartData.todayGoalPercent;
          _weeklyAvgHours = chartData.weeklyAvgHours;
          _focusScore = chartData.focusScore;
          _dailyCompDiffMinutes = chartData.dailyCompDiffMinutes;
          _weeklyChangePercent = chartData.weeklyChangePercent;
          _weekEndForecastHours = chartData.weekEndForecastHours;
          _streakForecastDays = chartData.streakForecastDays;
          _topBlockedAttempts = topAttempts;
        });
      }
    } catch (_) {}
  }

  /// So'nggi 30 kun ichidagi `block_attempts_YYYY-MM-DD` kalitlarini
  /// o'qib, har bir ilova uchun jami urinishlar sonini hisoblaydi va
  /// top 5 ni qaytaradi.
  List<Map<String, dynamic>> _computeTopBlockedAttempts(SharedPreferences prefs) {
    try {
      final Map<String, int> aggregated = {};
      final now = DateTime.now();
      for (int i = 0; i < 30; i++) {
        final date = DateTime(now.year, now.month, now.day - i);
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
        final raw = prefs.getString('block_attempts_$dateKey');
        if (raw == null) continue;
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          data.forEach((pkg, count) {
            final c = (count as num?)?.toInt() ?? 0;
            aggregated[pkg] = (aggregated[pkg] ?? 0) + c;
          });
        } catch (_) {}
      }
      // Ilova nomlari cache
      Map<String, dynamic> nameCache = {};
      final cacheRaw = prefs.getString('app_name_cache');
      if (cacheRaw != null) {
        try {
          nameCache = jsonDecode(cacheRaw) as Map<String, dynamic>;
        } catch (_) {}
      }
      final list = aggregated.entries.map((e) {
        // Ilova ikonkasini cache'dan o'qish (block_list_screen saqlagan)
        Uint8List? iconBytes;
        try {
          final iconStr = prefs.getString('app_icon_${e.key}');
          if (iconStr != null && iconStr.isNotEmpty) {
            iconBytes = base64Decode(iconStr);
          }
        } catch (_) {}
        return {
          'package': e.key,
          'name': nameCache[e.key]?.toString(),
          'count': e.value,
          'icon': iconBytes,
        };
      }).toList();
      list.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      // Top 5 ni qaytaramiz
      return list.take(5).toList();
    } catch (_) {
      return [];
    }
  }

  /// Ikonkasi yo'q ilovalar uchun `installed_apps` orqali fonda yuklab
  /// cache'ga saqlash. Tugaganda `_refreshLocalStats()` qayta ishlatib
  /// UI yangilanadi. Idempotent — har yangi ikonka topilganda qayta yozadi.
  Future<void> _fetchMissingIcons(
      SharedPreferences prefs, List<Map<String, dynamic>> items) async {
    bool anyFetched = false;
    for (final item in items) {
      if (item['icon'] != null) continue; // allaqachon bor
      final pack = item['package'] as String;
      try {
        final AppInfo? info = await InstalledApps.getAppInfo(pack);
        if (info?.icon != null) {
          await prefs.setString(
              'app_icon_$pack', base64Encode(info!.icon!));
          // Nomni ham yangilab qo'yamiz (agar yo'q bo'lsa)
          if (item['name'] == null && info.name.isNotEmpty) {
            final cacheRaw = prefs.getString('app_name_cache');
            final cache = cacheRaw != null
                ? (jsonDecode(cacheRaw) as Map<String, dynamic>)
                : <String, dynamic>{};
            cache[pack] = info.name;
            await prefs.setString('app_name_cache', jsonEncode(cache));
          }
          anyFetched = true;
        }
      } catch (_) {
        // Ilova o'chirilgan bo'lishi mumkin — o'tkazib yuboramiz
      }
    }
    // Agar biror ikonka yuklangan bo'lsa, ro'yxatni qayta hisoblab UI'ni
    // yangilaymiz (yangi ikonkalar bilan).
    if (anyFetched && mounted) {
      final newItems = _computeTopBlockedAttempts(prefs);
      if (mounted) {
        setState(() {
          _topBlockedAttempts = newItems;
        });
      }
    }
  }

  /// Real chart ma'lumotlarini hisoblash:
  ///   1. Joriy haftaning 7 kuni soatda (Du-Ya)
  ///   2. Joriy oydagi 4-5 hafta jami soatda
  ///   3. Har bir oy ichi hafta uchun 7 kunlik breakdown
  ///   4. Bugungi maqsadga erishish foizi
  ///   5. So'nggi 7 kun o'rtachasi
  ///   6. Fokus balli (0-100): so'nggi 7 kun erishish foizi o'rtachasi
  Future<_ChartData> _computeChartData(SharedPreferences prefs) async {
    final now = DateTime.now();

    /// Kunni `focus_history_YYYY-MM-DD` dan o'qib sekundlarni qaytarish.
    /// Bugun uchun jonli `today_focus_seconds` ishlatamiz.
    int secondsForDate(DateTime date) {
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      if (isToday) return prefs.getInt('today_focus_seconds') ?? 0;
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final raw = prefs.getString('focus_history_$dateKey');
      if (raw == null) return 0;
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        return (data['seconds'] as num?)?.toInt() ?? 0;
      } catch (_) {
        return 0;
      }
    }

    int goalForDate(DateTime date) {
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      if (isToday) return prefs.getInt('daily_goal_seconds') ?? 7200;
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final raw = prefs.getString('focus_history_$dateKey');
      if (raw == null) return prefs.getInt('daily_goal_seconds') ?? 7200;
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        return (data['goal'] as num?)?.toInt() ?? 7200; // 2 soat default
      } catch (_) {
        return 7200;
      }
    }

    // 1. Joriy haftaning 7 kuni (Du=Monday → Ya=Sunday)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weeklyHours = <double>[];
    for (int i = 0; i < 7; i++) {
      final date = DateTime(monday.year, monday.month, monday.day + i);
      // Kelajak kunlar uchun 0 ko'rsatamiz
      if (date.isAfter(DateTime(now.year, now.month, now.day))) {
        weeklyHours.add(0);
      } else {
        weeklyHours.add(secondsForDate(date) / 3600);
      }
    }

    // 2. Joriy oydagi haftalar (4-5 ta)
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    // 4 ta hafta: 1-7, 8-14, 15-21, 22-oxir
    final List<double> monthlyHours = [0, 0, 0, 0];
    final List<List<double>> monthlyDays =
        List.generate(4, (_) => List<double>.filled(7, 0));
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(firstOfMonth.year, firstOfMonth.month, day);
      // Kelajak kunlar uchun hisoblamaymiz
      if (date.isAfter(DateTime(now.year, now.month, now.day))) break;
      final weekIndex = ((day - 1) ~/ 7).clamp(0, 3);
      final dayInWeek = (day - 1) % 7;
      final hours = secondsForDate(date) / 3600;
      monthlyHours[weekIndex] += hours;
      if (dayInWeek < 7) monthlyDays[weekIndex][dayInWeek] = hours;
    }

    // 3. Bugungi maqsad foizi
    final todaySeconds = prefs.getInt('today_focus_seconds') ?? 0;
    final todayGoal = prefs.getInt('daily_goal_seconds') ?? 7200;
    final todayPercent =
        todayGoal > 0 ? ((todaySeconds / todayGoal) * 100).round().clamp(0, 100) : 0;

    // 4. So'nggi 7 kun o'rtachasi va Fokus balli
    int totalSecondsLast7 = 0;
    double sumRatio = 0;
    int countDays = 0;
    for (int i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final secs = secondsForDate(date);
      final goal = goalForDate(date);
      totalSecondsLast7 += secs;
      if (goal > 0) {
        sumRatio += (secs / goal).clamp(0.0, 1.0);
        countDays++;
      }
    }
    final weeklyAvgHours = (totalSecondsLast7 / 7) / 3600;
    final focusScore =
        countDays > 0 ? ((sumRatio / countDays) * 100).round().clamp(0, 100) : 0;

    // 5. Aqlli Tahlil (PRO) hisoblari ─────────────────────────────────
    // Bugun va kecha solishtirish (daqiqada)
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final todayMinutes = todaySeconds ~/ 60;
    final yesterdayMinutes = secondsForDate(yesterday) ~/ 60;
    final dailyCompDiff = todayMinutes - yesterdayMinutes;

    // Bu hafta vs o'tgan hafta (foiz farqi)
    int thisWeekSeconds = 0;
    for (int i = 0; i < 7; i++) {
      final d = DateTime(monday.year, monday.month, monday.day + i);
      if (d.isAfter(now)) break;
      thisWeekSeconds += secondsForDate(d);
    }
    final lastMonday = monday.subtract(const Duration(days: 7));
    int lastWeekSeconds = 0;
    for (int i = 0; i < 7; i++) {
      final d = DateTime(lastMonday.year, lastMonday.month, lastMonday.day + i);
      lastWeekSeconds += secondsForDate(d);
    }
    double weeklyChangePercent = 0.0;
    if (lastWeekSeconds > 0) {
      weeklyChangePercent =
          ((thisWeekSeconds - lastWeekSeconds) / lastWeekSeconds) * 100;
    } else if (thisWeekSeconds > 0) {
      // O'tgan hafta 0 bo'lsa, foiz cheksiz bo'lardi. UI tushunarli bo'lishi
      // uchun 100% sifatida ko'rsatamiz (yaxshilanish bor).
      weeklyChangePercent = 100.0;
    }

    // Hafta oxiriga prognoz — joriy haftaning o'rtachasi × 7 kun
    final daysElapsedInWeek = now.weekday; // 1..7
    final avgPerDay = daysElapsedInWeek > 0
        ? thisWeekSeconds / daysElapsedInWeek
        : 0.0;
    final weekEndForecastSeconds = avgPerDay * 7;
    final weekEndForecastHours = weekEndForecastSeconds / 3600;

    // Streak prognozi — keyingi milestone'ga necha kun qoldi.
    // Milestone'lar: 3, 7, 14, 30, 60, 100, 200, 365.
    final currentStreak = _streak; // Firestore'dan keladi
    const milestones = [3, 7, 14, 30, 60, 100, 200, 365];
    int nextMilestone = milestones.last;
    for (final m in milestones) {
      if (currentStreak < m) {
        nextMilestone = m;
        break;
      }
    }
    final streakForecastDays =
        (nextMilestone - currentStreak).clamp(0, nextMilestone);

    return _ChartData(
      weeklyHours: weeklyHours,
      monthlyHours: monthlyHours,
      monthlyDays: monthlyDays,
      todayGoalPercent: todayPercent,
      weeklyAvgHours: weeklyAvgHours,
      focusScore: focusScore,
      dailyCompDiffMinutes: dailyCompDiff,
      weeklyChangePercent: weeklyChangePercent,
      weekEndForecastHours: weekEndForecastHours,
      streakForecastDays: streakForecastDays,
    );
  }

  Future<void> _loadRealData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    
    // Faoliyatlarni yuklash — yangi user'da bo'sh.
    // Mock'lar olib tashlandi: foydalanuvchi Dashboard'da o'zining
    // faoliyatlarini qo'shsa, shu yerda statistikada ko'rinadi.
    final activitiesJson = prefs.getStringList('custom_activities');
    List<Map<String, dynamic>> loadedActivities = [];
    if (activitiesJson != null) {
      loadedActivities = activitiesJson.map((a) => Map<String, dynamic>.from(Uri.splitQueryString(a))).toList();
      for (var a in loadedActivities) {
        a['minutes'] = int.tryParse(a['minutes'].toString()) ?? 25;
      }
    }

    // Progressni yuklash
    final progressJson = prefs.getString('activity_progress_$today');
    Map<String, int> loadedProgress = {};
    if (progressJson != null) {
      final Map<String, dynamic> decoded = Uri.splitQueryString(progressJson);
      loadedProgress = decoded.map((key, value) => MapEntry(key, int.parse(value)));
    }

    // Lokal'dan jami seanslar (today + history) va eng uzun seansni hisoblash.
    // Bugungi `focus_history_*` kalitni o'tkazib yuboramiz — chunki uning
    // `sessions` qiymati `today_completed_sessions` bilan bir xil bo'ladi.
    int totalSessions = prefs.getInt('today_completed_sessions') ?? 0;
    final nowDt = DateTime.now();
    final todayKey0 =
        'focus_history_${nowDt.year}-${nowDt.month.toString().padLeft(2, '0')}-'
        '${nowDt.day.toString().padLeft(2, '0')}';
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('focus_history_')) continue;
      if (key == todayKey0) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        totalSessions += (data['sessions'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }
    // Eng uzun seans — yangi sekund kaliti, eskisi backward-compat.
    final longestSec = prefs.getInt('longest_session_seconds') ??
        ((prefs.getInt('longest_session_minutes') ?? 0) * 60);
    final lightTotal = prefs.getInt('light_focus_total_seconds') ?? 0;
    // Real chart ma'lumotlarini birinchi yuklashda ham hisoblaymiz
    final chartData = await _computeChartData(prefs);
    final topAttempts = _computeTopBlockedAttempts(prefs);
    // Yo'q ikonkalarni fonda yuklash
    _fetchMissingIcons(prefs, topAttempts);

    if (mounted) {
      setState(() {
        _customActivities = loadedActivities;
        _activityProgress = loadedProgress;
        _totalSessions = totalSessions;
        _longestSessionSeconds = longestSec;
        _lightFocusTotalSeconds = lightTotal;
        _realWeeklyHours = chartData.weeklyHours;
        _realMonthlyHours = chartData.monthlyHours;
        _realMonthlyDays = chartData.monthlyDays;
        _todayGoalPercent = chartData.todayGoalPercent;
        _weeklyAvgHours = chartData.weeklyAvgHours;
        _focusScore = chartData.focusScore;
        _dailyCompDiffMinutes = chartData.dailyCompDiffMinutes;
        _weeklyChangePercent = chartData.weeklyChangePercent;
        _weekEndForecastHours = chartData.weekEndForecastHours;
        _streakForecastDays = chartData.streakForecastDays;
        _topBlockedAttempts = topAttempts;
        _isDataLoading = false;
      });
    }

    // Firebase ma'lumotlarini yuklash
    final userStream = LevelService().getUserStatsStream();
    userStream.listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _streak = data['streak'] ?? 0;
          _level = data['level'] ?? 1;
          _xp = data['xp'] ?? 0;
          _totalMinutes = data['totalMinutes'] ?? 0;
          
          // Haftalik grafik uchun mock o'rniga totalMinutes'dan qisman foydalanamiz (agar bazada bo'lmasa)
          // To'liq tarix uchun alohida collection kerak, hozircha o'rtacha qiymat bilan to'ldiramiz
          double avgDaily = (_totalMinutes / 60) / ( _streak > 0 ? _streak : 1);
          _weeklyHours = List.generate(7, (index) => (index == 6) ? (_totalMinutes % 600 / 60) : avgDaily.clamp(0, 8));
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerSub?.cancel();
    _refreshTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppTranslationService();
    return ValueListenableBuilder<String>(
      valueListenable: lang.languageNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 10,
                  bottom: 16,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        lang.translate('stats.title'),
                        style: lang.getFont(fontSize: 24, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.8),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF34C759).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.flame_fill, color: Color(0xFF34C759), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            lang.translate('stats.streak_days').replaceAll('{count}', _streak.toString()), 
                            style: lang.getFont(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF34C759))
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Focus Score & Weekly Activity Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFocusScoreCard(lang),
                          const SizedBox(width: 16),
                          Expanded(child: _buildWeeklyMiniSummary(lang)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Weekly Activity Chart
                      _buildMainActivityChart(lang),
                      const SizedBox(height: 14),

                      // Comparison & Forecast Card
                      _buildComparisonForecastCard(lang),
                      const SizedBox(height: 14),

                      // Metrics Grid
                      _buildMetricsGrid(lang),
                      const SizedBox(height: 14),

                      // Yengil Fokus — alohida karta
                      _buildLightFocusCard(lang),
                      const SizedBox(height: 14),

                      // Activity Breakdown
                      _buildActivityBreakdown(lang),
                      const SizedBox(height: 14),

                      // Faoliyat — Dashboard'ga qo'shilgan har bir activity
                      // bu yerda darrov chiqadi (`_customActivities` dan).
                      // Bugun shu activity'ga vaqt sarflanmagan bo'lsa "0 daq"
                      // ko'rsatamiz. Foydalanuvchi bossa haftalik tarix ochiladi.
                      Text(
                        lang.translate('stats.recent_sessions'),
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)
                      ),
                      const SizedBox(height: 10),
                      if (_customActivities.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              lang.translate('focus_timer.no_activities_title') ??
                                  'Sevimli faoliyatingizni qo\'shing',
                              style: GoogleFonts.inter(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ..._customActivities.map((activity) {
                          final activityKey =
                              activity['key'] ?? activity['name'];
                          final displayName = activity.containsKey('key')
                              ? (lang.translate('focus_timer.${activity['key']}') ??
                                  activity['name'] ??
                                  activityKey)
                              : (activity['name'] ?? activityKey);
                          final todayMinutes =
                              _activityProgress[activityKey] ?? 0;
                          return GestureDetector(
                            onTap: () => _showActivityWeeklyDetails(
                                activityKey, displayName, lang),
                            child: _buildSessionItem(
                              context,
                              displayName,
                              '$todayMinutes${lang.translate('stats.unit_m')}',
                              lang.translate('stats.today'),
                              Theme.of(context).primaryColor,
                            ),
                          );
                        }),
                      
                      const SizedBox(height: 16),
                      // Top Distractors
                      _buildTopDistractors(lang),
                      const SizedBox(height: 16),

                      const SizedBox(height: 24),
                      // Premium Banner
                      _buildPremiumBanner(context, lang),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFocusScoreCard(AppTranslationService lang) {
    // Fokus Balli (0-100) — so'nggi 7 kun maqsadga erishish foizi o'rtachasi.
    // Formula: sum( (kun_seconds / kun_goal).clamp(0,1) ) / 7 * 100
    final score = _focusScore.toDouble();
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(
            lang.translate('stats.focus_score'),
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _FocusScorePainter(
                score: score,
                animationValue: _animationController.value,
              ),
              child: Center(
                child: Text('$_focusScore', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _focusScoreFeedback(lang),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _focusScoreColor()),
          ),
        ],
      ),
    );
  }

  String _focusScoreFeedback(AppTranslationService lang) {
    if (_focusScore >= 80) return lang.translate('stats.score_feedback') ?? 'Ajoyib!';
    if (_focusScore >= 50) return lang.translate('stats.score_good') ?? 'Yaxshi!';
    if (_focusScore > 0) return lang.translate('stats.score_keep_going') ?? 'Davom eting!';
    return lang.translate('stats.score_start') ?? 'Boshlang!';
  }

  Color _focusScoreColor() {
    if (_focusScore >= 80) return const Color(0xFF34C759);
    if (_focusScore >= 50) return const Color(0xFFFF9500);
    return const Color(0xFF8E8E93);
  }

  Widget _buildWeeklyMiniSummary(AppTranslationService lang) {
    return Column(
      children: [
        _buildMiniMetric(
          lang.translate('stats.weekly_avg'),
          '${_weeklyAvgHours.toStringAsFixed(1)} s',
          CupertinoIcons.graph_circle_fill,
          Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 12),
        _buildMiniMetric(
          lang.translate('stats.goal_reached'),
          '$_todayGoalPercent%',
          CupertinoIcons.checkmark_seal_fill,
          const Color(0xFF34C759),
        ),
      ],
    );
  }

  Widget _buildMiniMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
                Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _selectedChartType = 0; // 0: Hafta, 1: Oy
  int? _detailedWeekIndex; // null: umumiy, 0-3: hafta tafsilotlari

  Widget _buildMainActivityChart(AppTranslationService lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedChartType == 0 
                        ? lang.translate('stats.chart_weekly') 
                        : (_detailedWeekIndex == null 
                            ? lang.translate('stats.chart_monthly') 
                            : lang.translate('stats.chart_week_detail').replaceAll('{week}', (_detailedWeekIndex! + 1).toString())),
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_detailedWeekIndex != null)
                      GestureDetector(
                        onTap: () => setState(() => _detailedWeekIndex = null),
                        child: Text(
                          lang.translate('stats.back'), 
                          style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_detailedWeekIndex == null)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      _buildChartToggleBtn(0, lang.translate('stats.toggle_week'), lang),
                      _buildChartToggleBtn(1, lang.translate('stats.toggle_month'), lang),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapUp: (details) {
                  if (_selectedChartType == 1 && _detailedWeekIndex == null) {
                    final double barWidthWithSpacing = constraints.maxWidth / 4;
                    final int index = (details.localPosition.dx / barWidthWithSpacing).floor();
                    if (index >= 0 && index < 4) {
                      setState(() => _detailedWeekIndex = index);
                      _animationController.reset();
                      _animationController.forward();
                    }
                  }
                },
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _BarChartPainter(
                          data: _getChartData(),
                          labels: _getChartLabels(lang),
                          animationValue: _animationController.value,
                          activeColor: _detailedWeekIndex != null ? const Color(0xFF34C759) : Theme.of(context).primaryColor,
                          onSurfaceColor: Theme.of(context).colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  List<double> _getChartData() {
    if (_selectedChartType == 0) return _realWeeklyHours;
    if (_detailedWeekIndex != null) {
      // Tanlangan hafta uchun 7 kunlik real ma'lumot
      if (_detailedWeekIndex! < _realMonthlyDays.length) {
        return _realMonthlyDays[_detailedWeekIndex!];
      }
      return List<double>.filled(7, 0);
    }
    return _realMonthlyHours;
  }

  List<String> _getChartLabels(AppTranslationService lang) {
    List<dynamic> labels = lang.translateList('plans.weekdays_short');
    if (_selectedChartType == 0) {
      return labels is List ? List<String>.from(labels) : ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
    }
    if (_detailedWeekIndex != null) {
      final startDay = (_detailedWeekIndex! * 7) + 1;
      final shortDays = labels is List ? List<String>.from(labels) : ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
      // Har bir kunning haqiqiy hafta kunini DateTime'dan olamiz —
      // statik [Du, Se, ...] ro'yxat hafta sanasiga mos kelmaydi.
      final now = DateTime.now();
      return List.generate(7, (i) {
        final day = startDay + i;
        final date = DateTime(now.year, now.month, day);
        return '${shortDays[date.weekday - 1]} $day';
      });
    }
    return List.generate(4, (i) => lang.translate('stats.week_label').toString().replaceAll('{count}', (i + 1).toString()));
  }

  Widget _buildChartToggleBtn(int index, String label, AppTranslationService lang) {
    bool active = _selectedChartType == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedChartType = index;
          if (index == 0) _detailedWeekIndex = null;
        });
        _animationController.reset();
        _animationController.forward();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
        ),
        child: Text(
          label,
          style: lang.getFont(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? const Color(0xFF1C1C1E) : const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }

  /// Aqlli Tahlil: bugun va kecha solishtirish matnini formatlash.
  /// Misol: "Bugun kechagidan 45daq ko'p" yoki "Bugun kechagidan 10daq kam"
  String _dailyComparisonText(AppTranslationService lang) {
    final lessKey = lang.translate('stats.daily_comparison_less');
    final moreKey = lang.translate('stats.daily_comparison');
    final m = _dailyCompDiffMinutes;
    final unit = lang.translate('stats.unit_m') ?? 'daq';
    if (m == 0) {
      return lang.translate('stats.daily_comparison_same') ??
          'Bugun kechagiga teng';
    }
    if (m > 0) {
      // "Bugun kechagidan {diff} ko'p"
      return moreKey.replaceAll('{diff}', '$m $unit');
    }
    // Manfiy
    final less = lessKey ?? 'Bugun kechagidan {diff} kam';
    return less.replaceAll('{diff}', '${-m} $unit');
  }

  /// "+18.4%" yoki "-12.3%" formatida solishtirish foizini chiqarish.
  String _formatComparison() {
    final sign = _weeklyChangePercent >= 0 ? '+' : '';
    return '$sign${_weeklyChangePercent.toStringAsFixed(1)}%';
  }

  /// Hafta oxiriga prognoz: "28s 45daq" yoki "45daq"
  String _formatForecast(AppTranslationService lang) {
    final totalMinutes = (_weekEndForecastHours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    final hourLabel = lang.translate('stats.unit_h') ?? 's';
    final minLabel = lang.translate('stats.unit_m') ?? 'daq';
    if (h == 0) return '$m$minLabel';
    if (m == 0) return '$h$hourLabel';
    return '$h$hourLabel $m$minLabel';
  }

  Widget _buildComparisonForecastCard(AppTranslationService lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF007AFF), Color(0xFFA855F7), Color(0xFFEC4899)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: const Color(0xFFA855F7).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lang.translate('stats.smart_analysis'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('PRO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Streak Forecast — real: keyingi milestone'gacha kunlar
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.fire, size: 14, color: Color(0xFFFFD700)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.translate('stats.streak_forecast').replaceAll(
                      '{days}', '$_streakForecastDays'),
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Daily Comparison — real: bugun vs kecha (daqiqada)
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.clockRotateLeft, size: 12, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dailyComparisonText(lang),
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white24, height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.chartLine, size: 14, color: Color(0xFF34C759)),
                        const SizedBox(width: 6),
                        Text(
                          lang.translate('stats.comparison'), 
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatComparison(),
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    Text(lang.translate('stats.vs_last_week'), style: GoogleFonts.inter(fontSize: 10, color: Colors.white60)),
                  ],
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white24),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 14, color: Color(0xFFFFD700)),
                        const SizedBox(width: 6),
                        Text(
                          lang.translate('stats.forecast'),
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatForecast(lang),
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    Text(lang.translate('stats.week_end_forecast'), style: GoogleFonts.inter(fontSize: 10, color: Colors.white60)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(AppTranslationService lang) {
    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildGridMetric(
          lang.translate('stats.metrics_sessions'),
          '$_totalSessions ${lang.translate('stats.unit_session')}',
          CupertinoIcons.cube_box_fill,
          const Color(0xFF5856D6),
        ),
        _buildGridMetric(
          lang.translate('stats.metrics_longest'),
          _formatLongestSession(_longestSessionSeconds, lang),
          CupertinoIcons.timer_fill,
          const Color(0xFFFF9500),
        ),
      ],
    );
  }

  /// Yengil Fokus rejimida o'tkazilgan jami vaqt — alohida karta.
  /// Foydalanuvchi Yengil Fokus mode'da har soniya `light_focus_total_seconds`
  /// oshadi. Bu karta umumiy statistikaga to'sqinlik qilmaydi (XP, level,
  /// streak hammasi yagona today_focus_seconds asosida).
  Widget _buildLightFocusCard(AppTranslationService lang) {
    final minutes = _lightFocusTotalSeconds ~/ 60;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hourLabel = lang.translate('stats.unit_h') ?? 's';
    final minLabel = lang.translate('stats.unit_m') ?? 'daq';
    String label;
    if (h == 0) {
      label = '$m $minLabel';
    } else if (m == 0) {
      label = '$h $hourLabel';
    } else {
      label = '$h $hourLabel $m $minLabel';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              CupertinoIcons.leaf_arrow_circlepath,
              color: Color(0xFF34C759),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.translate('stats.metrics_light_focus') ?? 'Yengil Fokus',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lang.translate('stats.light_focus_desc') ?? 'Jami yengil fokus vaqti',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF34C759),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.w500)),
          Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildTopDistractors(AppTranslationService lang) {
    // _topBlockedAttempts — _refreshLocalStats() da hisoblanadi.
    // So'nggi 30 kun ichidagi top eng ko'p urinilgan ilovalar.
    final items = _topBlockedAttempts;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  lang.translate('stats.top_distractors') ??
                      'Eng ko\'p kirishga urinilgan ilovalar',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  lang.translate('stats.monthly_label') ?? '1 oylik',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFF3B30),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  lang.translate('stats.no_distractors') ??
                      'Hali bloklangan ilovaga kirishga urinish bo\'lmagan',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                ),
              ),
            )
          else
            ...items.map((d) {
              final pack = d['package'] as String;
              final name = (d['name'] as String?) ?? _shortPackageName(pack);
              final count = d['count'] as int;
              final iconBytes = d['icon'] as Uint8List?;
              final color = _colorForPackage(pack);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // Haqiqiy ilova ikonkasi (block_list'da saqlangan)
                    // mavjud bo'lsa ko'rsatamiz. Aks holda — fallback:
                    // mashhur ilovalar uchun brend ikonkasi yoki "ban".
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconBytes != null
                            ? Colors.transparent
                            : color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: iconBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                iconBytes,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                            )
                          : Center(
                              child: FaIcon(
                                _iconForPackage(pack),
                                color: color,
                                size: 18,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$count ${lang.translate('stats.unit_attempt')}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFFF3B30),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Package nomidan o'qish mumkin bo'lgan qisqa nom ("com.instagram.android"
  /// → "Instagram"). Cache topilmasa fallback.
  String _shortPackageName(String pack) {
    if (pack.isEmpty) return '?';
    final parts = pack.split('.');
    if (parts.length < 2) return pack;
    return parts[1][0].toUpperCase() + parts[1].substring(1);
  }

  /// Mashhur ilovalar uchun brend rangi. Boshqalari uchun universal qizil.
  Color _colorForPackage(String pack) {
    final p = pack.toLowerCase();
    if (p.contains('instagram')) return const Color(0xFFE1306C);
    if (p.contains('tiktok') || p.contains('musical')) return Colors.black;
    if (p.contains('youtube')) return const Color(0xFFFF0000);
    if (p.contains('facebook') || p.contains('katana')) {
      return const Color(0xFF1877F2);
    }
    if (p.contains('telegram')) return const Color(0xFF0088CC);
    if (p.contains('twitter') || p.contains('x.android')) {
      return const Color(0xFF1DA1F2);
    }
    if (p.contains('snapchat')) return const Color(0xFFFFFC00);
    if (p.contains('whatsapp')) return const Color(0xFF25D366);
    return const Color(0xFFFF3B30);
  }

  // FontAwesome icons return `IconDataBrands`/`IconDataSolid` (subtype of
  // IconData). Use dynamic return to satisfy both FaIcon's expected
  // FaIconData and Flutter's IconData.
  dynamic _iconForPackage(String pack) {
    final p = pack.toLowerCase();
    if (p.contains('instagram')) return FontAwesomeIcons.instagram;
    if (p.contains('tiktok') || p.contains('musical')) return FontAwesomeIcons.tiktok;
    if (p.contains('youtube')) return FontAwesomeIcons.youtube;
    if (p.contains('facebook') || p.contains('katana')) return FontAwesomeIcons.facebook;
    if (p.contains('telegram')) return FontAwesomeIcons.telegram;
    if (p.contains('twitter') || p.contains('x.android')) return FontAwesomeIcons.xTwitter;
    if (p.contains('snapchat')) return FontAwesomeIcons.snapchat;
    if (p.contains('whatsapp')) return FontAwesomeIcons.whatsapp;
    return FontAwesomeIcons.ban;
  }

  Widget _buildSessionItem(BuildContext context, String title, String duration, String time, Color color) {
    // Tashqi GestureDetector (`_showActivityWeeklyDetails`'ga ulangan)
    // tap'ni qabul qiladi — bu yerda alohida onTap'siz container.
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(time, style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                ],
              ),
            ),
            Text(duration, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );
  }

  Widget _buildActivityBreakdown(AppTranslationService lang) {
    if (_activityProgress.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.translate('stats.chart_weekly'), // "Faollik"
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)
          ),
          const SizedBox(height: 16),
          ..._customActivities.where((a) => _activityProgress.containsKey(a['key'] ?? a['name'])).map((activity) {
            final key = activity['key'] ?? activity['name'];
            final done = _activityProgress[key] ?? 0;
            final target = activity['minutes'] ?? 45;
            final percent = (done / target).clamp(0.0, 1.0);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(activity['name'], style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('$done / $target ${lang.translate('stats.unit_m')}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 8,
                      backgroundColor: Colors.grey.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPremiumBanner(BuildContext context, AppTranslationService lang) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF007AFF), Color(0xFFA855F7), Color(0xFFEC4899)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFFA855F7).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const FaIcon(FontAwesomeIcons.crown, color: Color(0xFFFFD700), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.translate('stats.pro_banner_title'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(lang.translate('stats.pro_banner_desc'), style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  void _showSessionDetails(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Haftalik tahlil', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 32),
            Expanded(
              child: CustomPaint(
                size: Size.infinite,
                painter: _BarChartPainter(
                  data: _weeklyHours,
                  labels: _weekDays,
                  animationValue: 1.0,
                  activeColor: Theme.of(context).primaryColor,
                  onSurfaceColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildMiniMetric('O\'rtacha fokus', '4.2 s', CupertinoIcons.time, const Color(0xFF34C759)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Faoliyat bosilganda haftalik tarixni bottom sheet'da ko'rsatadi.
  /// So'nggi 7 kun davomida `activity_progress_YYYY-MM-DD` kalitlaridan
  /// shu activity uchun nechta SEKUND sarflanganini o'qiydi.
  Future<void> _showActivityWeeklyDetails(
      String activityKey, String displayName, AppTranslationService lang) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final List<MapEntry<DateTime, int>> weeklyData = [];
    int totalSeconds = 0;
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final progressJson = prefs.getString('activity_progress_$dateKey');
      int seconds = 0;
      if (progressJson != null) {
        try {
          final decoded = Uri.splitQueryString(progressJson);
          seconds = int.tryParse(decoded[activityKey] ?? '0') ?? 0;
        } catch (_) {}
      }
      totalSeconds += seconds;
      weeklyData.add(MapEntry(date, seconds));
    }
    if (!mounted) return;
    final maxSeconds =
        weeklyData.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: lang.getFont(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lang.translate('stats.activity_weekly_title') ??
                  'Haftalik faoliyat',
              style: lang.getFont(
                fontSize: 13,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 20),
            if (totalSeconds == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    lang.translate('stats.activity_no_data') ??
                        'Bu hafta hali ma\'lumot yo\'q',
                    style: lang.getFont(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
                  ),
                ),
              )
            else
              ...weeklyData.map((entry) {
                final dayLabel = _weekdayShort(entry.key.weekday, lang);
                final secs = entry.value;
                final ratio = maxSeconds > 0 ? secs / maxSeconds : 0.0;
                final m = secs ~/ 60;
                final s = secs % 60;
                final label = m == 0
                    ? '${s}s'
                    : (s == 0 ? '${m}d' : '${m}d ${s}s');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          dayLabel,
                          style: lang.getFont(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.06),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 64,
                        child: Text(
                          label,
                          textAlign: TextAlign.right,
                          style: lang.getFont(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 16),
            Divider(
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang.translate('stats.activity_weekly_total') ?? 'Jami',
                  style: lang.getFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  _formatSecondsToHms(totalSeconds, lang),
                  style: lang.getFont(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Haftaning qisqa nomi (DateTime.weekday: 1..7 → Mon..Sun).
  String _weekdayShort(int weekday, AppTranslationService lang) {
    const keys = [
      'calendar.wd_mon',
      'calendar.wd_tue',
      'calendar.wd_wed',
      'calendar.wd_thu',
      'calendar.wd_fri',
      'calendar.wd_sat',
      'calendar.wd_sun',
    ];
    return lang.translate(keys[weekday - 1]) ?? '';
  }

  /// "65" → "1s 5d", "30" → "30d"
  String _formatMinutesToHm(int minutes, AppTranslationService lang) {
    if (minutes <= 0) return '0 ${lang.translate('stats.unit_m') ?? 'daq'}';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m ${lang.translate('stats.unit_m') ?? 'daq'}';
    if (m == 0) return '$h ${lang.translate('stats.unit_h') ?? 's'}';
    return '$h ${lang.translate('stats.unit_h') ?? 's'} $m ${lang.translate('stats.unit_m') ?? 'daq'}';
  }

  /// Sekundlardan "1s 5d 30sek" yoki "30sek" yoki "5d" formatiga.
  /// Kichik vaqtlar uchun (activity weekly chart jami).
  String _formatSecondsToHms(int seconds, AppTranslationService lang) {
    if (seconds <= 0) return '0 sek';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final parts = <String>[];
    if (h > 0) parts.add('$h ${lang.translate('stats.unit_h') ?? 's'}');
    if (m > 0) parts.add('$m ${lang.translate('stats.unit_m') ?? 'daq'}');
    if (s > 0 && h == 0) parts.add('$s sek');
    return parts.join(' ');
  }

  /// Eng uzun seans metric kartasi uchun ixcham format:
  /// 0 → "0 sek", 30 → "30 sek", 90 → "1 daq 30 sek", 3700 → "1 s 1 daq"
  String _formatLongestSession(int seconds, AppTranslationService lang) {
    if (seconds <= 0) return '0 sek';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final hUnit = lang.translate('stats.unit_h') ?? 's';
    final mUnit = lang.translate('stats.unit_m') ?? 'daq';
    if (h > 0) {
      // Soat va daqiqa — sekundlarni tashlaymiz, ixchamlik uchun
      if (m == 0) return '$h $hUnit';
      return '$h $hUnit $m $mUnit';
    }
    if (m > 0) {
      if (s == 0) return '$m $mUnit';
      return '$m $mUnit $s sek';
    }
    return '$s sek';
  }
}

class _FocusScorePainter extends CustomPainter {
  final double score;
  final double animationValue;

  _FocusScorePainter({required this.score, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 8.0;

    final bgPaint = Paint()
      ..color = const Color(0xFFF2F2F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF34C759), Color(0xFF30D158)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    final sweepAngle = (score / 100) * 2 * math.pi * animationValue;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BarChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final double animationValue;
  final Color activeColor;
  final Color onSurfaceColor;
  
  _BarChartPainter({required this.data, required this.labels, required this.animationValue, required this.activeColor, required this.onSurfaceColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double barWidth = (size.width - (labels.length - 1) * 16) / labels.length;
    // Maksimal qiymat — eng baland ustun. Agar barcha ma'lumot 0 bo'lsa
    // (yangi user, hech qachon fokus qilmagan) bo'lib chiqarish xatosini
    // oldini olamiz va hech qanday ustun chizmaymiz (faqat label'lar).
    double maxVal = 0.0;
    for (final v in data) {
      if (v > maxVal) maxVal = v;
    }

    // Tepada qiymat yozish uchun joy ajratamiz — chart bar'lari uchun
    // mavjud balandlik biroz kichikroq bo'ladi.
    const double topLabelPadding = 18;
    final double chartAreaHeight = (size.height - topLabelPadding).clamp(0, size.height);

    for (int i = 0; i < data.length; i++) {
      final double left = i * (barWidth + 16);
      // 1. Bar (faqat maxVal > 0 bo'lsa va data[i] > 0 bo'lsa)
      if (maxVal > 0 && data[i] > 0) {
        final double barHeight =
            (data[i] / maxVal) * chartAreaHeight * animationValue;
        final double top = size.height - barHeight;
        final RRect rrect = RRect.fromLTRBR(
          left, top, left + barWidth, size.height,
          const Radius.circular(8),
        );
        final paint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [activeColor, activeColor.withOpacity(0.4)],
          ).createShader(rrect.outerRect);
        canvas.drawRRect(rrect, paint);

        // Bar TEPASIDA qiymat — "1s 30daq" yoki "45daq" yoki "0"
        final valueLabel = _formatBarValue(data[i]);
        final valuePainter = TextPainter(
          text: TextSpan(
            text: valueLabel,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: activeColor,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(minWidth: barWidth, maxWidth: barWidth);
        // Ustundan biroz tepada
        final valueTop = (top - valuePainter.height - 2).clamp(0.0, size.height);
        valuePainter.paint(canvas, Offset(left, valueTop));
      }

      // 2. Pastda label (Du, Se, ...)
      final labelPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: onSurfaceColor.withOpacity(0.6),
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(minWidth: barWidth, maxWidth: barWidth);
      labelPainter.paint(canvas, Offset(left, size.height + 8));
    }
  }

  /// Bar tepasidagi qiymatni qisqa formatda chiqarish: "0", "30daq",
  /// "1s", "2s 15daq". `data[i]` SOATDA berilgan double qiymat.
  String _formatBarValue(double hours) {
    final totalMinutes = (hours * 60).round();
    if (totalMinutes <= 0) return '0';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}daq';
    if (m == 0) return '${h}s';
    return '${h}s ${m}daq';
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Statistika diagrammalari uchun real ma'lumotlar to'plami.
/// `_computeChartData()` shu modelni qaytaradi va `_refreshLocalStats()`
/// uni state ga yozadi.
///
/// Aqlli Tahlil (PRO) ko'rsatkichlari ham shu modelga kiritilgan — fonida
/// doim hisoblanadi. Premium chiqarilganda free user'larda UI yopiq bo'ladi,
/// lekin hisoblash to'xtamaydi (ma'lumot doim mavjud).
class _ChartData {
  final List<double> weeklyHours;        // Du-Ya joriy hafta (7 ta)
  final List<double> monthlyHours;       // Joriy oydagi haftalar (4 ta)
  final List<List<double>> monthlyDays;  // Har hafta uchun 7 kun (4×7)
  final int todayGoalPercent;            // 0..100
  final double weeklyAvgHours;           // So'nggi 7 kun o'rtacha
  final int focusScore;                  // 0..100, met% o'rtachasi
  // ─── Aqlli Tahlil (PRO) ──────────────────────────────────────
  final int dailyCompDiffMinutes;        // Bugun - kecha (daqiqada, +/-)
  final double weeklyChangePercent;      // Bu hafta vs o'tgan hafta (%, +/-)
  final double weekEndForecastHours;     // Bu hafta oxiriga prognoz (soat)
  final int streakForecastDays;          // Keyingi rekordgacha (kun)

  const _ChartData({
    required this.weeklyHours,
    required this.monthlyHours,
    required this.monthlyDays,
    required this.todayGoalPercent,
    required this.weeklyAvgHours,
    required this.focusScore,
    required this.dailyCompDiffMinutes,
    required this.weeklyChangePercent,
    required this.weekEndForecastHours,
    required this.streakForecastDays,
  });
}
