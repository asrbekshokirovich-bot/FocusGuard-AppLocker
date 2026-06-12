import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'premium_screen.dart';
import '../services/app_translation_service.dart';
import '../services/timer_notification_service.dart';
import '../services/level_service.dart';
import '../services/focus_timer_service.dart';
import '../services/soundscape_service.dart';
import '../services/dnd_service.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_usage/app_usage.dart';
import 'package:usage_stats/usage_stats.dart';
import 'permissions_screen.dart';

class FocusTimerScreen extends StatefulWidget {
  final VoidCallback? onNavigateToBlockList;
  const FocusTimerScreen({super.key, this.onNavigateToBlockList});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Standart Pomodoro qiymati — 25 daqiqa. Foydalanuvchi oziga moslab
  // o'zgartirishi mumkin (25 / 45 / 60 / 120 va custom picker).
  int _selectedMinutes = 25;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  bool _isPaused = false;
  final _timerService = FocusTimerService();
  StreamSubscription? _timerSubscription;
  
  bool _isStrictMode = true;
  bool _isAntiDistract = true;
  
  String _selectedSound = 'none';
  int _selectedMode = 0; // 0: Deep Work, 1: Light Focus
  
  // Dynamic Activities — yangi user'da bo'sh.
  // Mock'lar olib tashlandi: foydalanuvchi "+" tugmasi orqali
  // o'zining haqiqiy faoliyatlarini qo'shadi.
  List<Map<String, dynamic>> _customActivities = [];
  // -1 — hech qaysi faoliyat tanlanmagan (default). Foydalanuvchi o'zi
  // tanlasagina qiymat 0..N bo'ladi. Tanlanmagan holatda timer ishlasa,
  // umumiy statistika (today_focus_seconds, XP, sessions) ishlaveradi —
  // faqat activity_progress yozilmaydi.
  int _selectedActivityIndex = -1;
  
  double _dailyGoalHours = 2.0;
  double _currentProgressHours = 0.0;
  Map<String, int> _activityProgress = {}; // Activity key/name -> minutes spent today
  String _motivationPhrase = 'Bugun ajoyib kun bo\'ladi!';
  final TextEditingController _motivationController = TextEditingController(text: 'Bugun ajoyib kun bo\'ladi!');
  late ScrollController _marqueeController;
  late PageController _activityPageController;
  int _currentActivityPage = 0;

  // Premium holati — Chuqur Fokus pauza/to'xtatish cheklovlarini boshqaradi.
  bool _isPremium = false;
  // Pauza budjeti (background service'dan timerTick orqali keladi).
  int _pauseRemaining = 0;
  bool _pauseUnlimited = false;
  // Kunlik bajarilgan faoliyatlar (odat checkbox) — `activity_done_$today`.
  Set<String> _activityDone = {};
  // Default faoliyatlar birinchi marta qo'shilganini belgilash (saqlash uchun).
  bool _seedDefaultActivities = false;
  // Tepadagi shaffof banner — aylanma maslahatlar.
  int _tipIndex = 0;
  Timer? _tipTimer;

  /// Mashhur faoliyatlar — yangi foydalanuvchiga tayyor turadi.
  List<Map<String, dynamic>> _defaultActivities() {
    final lang = AppTranslationService();
    return [
      {'name': lang.translate('focus_timer.preset.reading'), 'minutes': 45},
      {'name': lang.translate('focus_timer.preset.exercise'), 'minutes': 30},
      {'name': lang.translate('focus_timer.preset.coding'), 'minutes': 60},
      {'name': lang.translate('focus_timer.preset.language'), 'minutes': 30},
      {'name': lang.translate('focus_timer.preset.meditation'), 'minutes': 15},
      {'name': lang.translate('focus_timer.preset.work'), 'minutes': 60},
    ];
  }

  @override
  void initState() {
    super.initState();
    final lang = AppTranslationService();
    _motivationPhrase = lang.translate('focus_timer.motivation_default');
    _motivationController.text = _motivationPhrase;
    _marqueeController = ScrollController();
    _activityPageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());

    _timerService.init();
    _timerService.syncState();
    
    _timerSubscription = _timerService.timerStream.listen((event) {
      if (mounted) {
        // timerFinished — background service taymer tabiiy tugaganda
        // yuboradi. Bu holda dialog ko'rsatamiz va ringtoni o'chiramiz.
        if (event['timerFinished'] == true) {
          final minutes = (event['minutes'] as int?) ?? _selectedMinutes;
          _onTimerComplete(minutes);
          return;
        }

        // Pauza budjeti tugab avtomatik davom etganini aniqlaymiz —
        // foydalanuvchini qisqa xabar bilan ogohlantiramiz.
        final wasPaused = _isPaused;
        final newPaused = event['isPaused'] ?? _isPaused;
        final newRunning = event['isRunning'] ?? _isRunning;
        setState(() {
          _remainingSeconds = event['seconds'] ?? _remainingSeconds;
          _isRunning = newRunning;
          _isPaused = newPaused;
          _pauseRemaining = (event['pauseRemaining'] as num?)?.toInt() ?? _pauseRemaining;
          _pauseUnlimited = event['pauseUnlimited'] ?? _pauseUnlimited;
        });
        if (wasPaused && !newPaused && newRunning && !_pauseUnlimited && _pauseRemaining <= 0) {
          final lang = AppTranslationService();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lang.translate('focus_timer.pause_over_msg')),
            behavior: SnackBarBehavior.floating,
          ));
        }
        // Har stream tick — bugungi progress'ni jonli yangilab turamiz
        // (today_focus_seconds background'da o'sib boryapti).
        _refreshTodayProgress();
      }
    });

    WidgetsBinding.instance.addObserver(this);
    _loadDailyProgress();
    _loadPremiumStatus();
    // Tepadagi maslahat bannerini har 6 soniyada aylantiramiz.
    _tipTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) setState(() => _tipIndex++);
    });
    // Anti-Chalg'itish toggle holatini saqlangan qiymatdan yuklash.
    // Foydalanuvchi avval yoqgan/o'chirgan bo'lsa shu qiymat saqlanadi.
    DndService.instance.isToggleEnabled().then((enabled) {
      if (mounted) setState(() => _isAntiDistract = enabled);
    });
    // Xavfsizlik: agar oldingi sessiyadan DnD stuck holatda qolgan bo'lsa
    // (crash, force stop, fonda timer tugagan), darrov tuzatamiz.
    // Bu Focus Timer ekran ochilishi bilan ishlaydi — main.dart'dagi check'ga
    // qo'shimcha qatlam.
    DndService.instance.recoverIfStuck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App qayta foreground'ga kelganda bugungi progress'ni qayta o'qiymiz.
    // Bu kun o'tgan bo'lsa (today_focus_seconds = 0 ga tushgan) UI darrov
    // yangilanadi va eski 4d/4d ko'rinmaydi.
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshTodayProgress();
      _loadDailyProgress();
      // Fonda timer tugagan bo'lsa (foydalanuvchi app'da yo'q edi) — DnD
      // hali yoqiq qolgan bo'lishi mumkin. recoverIfStuck darrov tuzatadi:
      // timer_is_running=false bo'lsa va dnd_active_by_us=true bo'lsa,
      // DnD avvalgi holatga qaytadi.
      DndService.instance.recoverIfStuck();
    }
  }

  Future<void> _loadDailyProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final today = DateTime.now().toString().split(' ')[0];

    // Bugungi progress'ni `today_focus_seconds` dan o'qiymiz — bu yagona
    // haqiqiy manba. Background service har yangi kunda 00:00 da uni
    // nolga tushiradi. Avval ishlatilgan `daily_progress_hours` kaliti
    // background service bilan sinxronlashmasdi va kun o'tishi bilan
    // yangi kunda eski qiymat saqlanib qolardi.
    final todayFocusSeconds = prefs.getInt('today_focus_seconds') ?? 0;

    // "Yo'qotilgan maqsad" notifikatsiyasi — bir kuniga 1 marta yuboramiz.
    // Eski `last_progress_reset` kaliti shu maqsad uchun saqlanadi.
    final lastReset = prefs.getString('last_progress_reset') ?? '';
    if (lastReset != today && lastReset.isNotEmpty) {
      // Yangi kun: kechagi natijani tekshiramiz (background service
      // allaqachon today_focus_seconds ni reset qilgan, kechagi qiymat
      // history'da). Notifikatsiya logikasi background_service'da bor —
      // bu yerda qaytarib chaqirmaymiz.
      await prefs.setString('last_progress_reset', today);
    } else if (lastReset.isEmpty) {
      await prefs.setString('last_progress_reset', today);
    }

    setState(() {
      _dailyGoalHours = (prefs.getInt('daily_goal_seconds') ?? 7200) / 3600;
      _currentProgressHours = todayFocusSeconds / 3600;
      _motivationPhrase = prefs.getString('motivation_phrase') ?? AppTranslationService().translate('focus_timer.motivation_default');
      _motivationController.text = _motivationPhrase;
      // Tabiat ovozi tanlangani — SoundscapeService kalitidan o'qiymiz
      _selectedSound = prefs.getString('selected_sound') ?? 'none';

      // Faoliyatlarni yuklash
      final activitiesJson = prefs.getStringList('custom_activities');
      if (activitiesJson != null) {
        _customActivities = activitiesJson.map((a) => Map<String, dynamic>.from(Uri.splitQueryString(a))).toList();
        // Convert minutes back to int
        for (var a in _customActivities) {
          a['minutes'] = int.tryParse(a['minutes'].toString()) ?? 25;
        }
      } else {
        // Birinchi ishga tushirish — mashhur faoliyatlarni tayyor qo'yamiz.
        // Foydalanuvchi o'chirishi yoki o'zinikini qo'shishi mumkin.
        _customActivities = _defaultActivities();
        _seedDefaultActivities = true;
      }

      // Faoliyat progressini yuklash
      final progressJson = prefs.getString('activity_progress_$today');
      if (progressJson != null) {
        final Map<String, dynamic> decoded = Uri.splitQueryString(progressJson);
        _activityProgress = decoded.map((key, value) => MapEntry(key, int.parse(value)));
      } else {
        _activityProgress = {};
      }

      // Kunlik bajarilgan faoliyatlar (odat checkbox).
      _activityDone = (prefs.getStringList('activity_done_$today') ?? []).toSet();
    });

    // Default faoliyatlar birinchi marta qo'shildi — saqlaymiz.
    if (_seedDefaultActivities) {
      _seedDefaultActivities = false;
      await _saveActivities();
    }

    // Background servicega maqsadni yuborish
    _timerService.updateDailyGoal((_dailyGoalHours * 3600).toInt());
  }

  /// Bugungi maqsad progressini SharedPreferences'dan jonli o'qib UI'ni
  /// yangilaydi. Taymer ishlayotganda har stream tick'da chaqiriladi,
  /// shuningdek ilova qayta foreground'ga kelganda ham. Bu funksiya
  /// `today_focus_seconds` (background service yangilab turadi) ga
  /// asoslangan — yagona haqiqiy manba.
  Future<void> _refreshTodayProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final todayFocusSeconds = prefs.getInt('today_focus_seconds') ?? 0;
      final today = DateTime.now().toString().split(' ')[0];
      final progressJson = prefs.getString('activity_progress_$today');
      Map<String, int> updatedProgress = {};
      if (progressJson != null) {
        final decoded = Uri.splitQueryString(progressJson);
        updatedProgress =
            decoded.map((k, v) => MapEntry(k, int.tryParse(v) ?? 0));
      }
      if (mounted) {
        setState(() {
          _currentProgressHours = todayFocusSeconds / 3600;
          _activityProgress = updatedProgress;
        });
      }
    } catch (_) {}
  }

  /// Premium holatini yuklash — avval lokal kesh (`is_premium`), keyin
  /// Firestore'dan yangilaymiz. Bu Chuqur Fokus pauza/to'xtatish
  /// cheklovlarini boshqaradi.
  Future<void> _loadPremiumStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _isPremium = prefs.getBool('is_premium') ?? false);
    } catch (_) {}
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 2));
        final p = doc.data()?['isPremium'] == true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_premium', p);
        if (mounted) setState(() => _isPremium = p);
      }
    } catch (_) {}
  }

  /// Bepul foydalanuvchi uchun seans davomiyligiga qarab pauza budjeti.
  /// -1 = cheksiz (premium). 0 = pauza yo'q (qisqa seans).
  int _pauseBudgetFor(int minutes) {
    if (_isPremium) return -1;
    if (minutes <= 30) return 0;
    if (minutes <= 60) return 300;
    return 600;
  }

  /// Kunlik bajarilgan faoliyat belgisini almashtirish (odat tracking).
  Future<void> _toggleActivityDone(String key) async {
    final today = DateTime.now().toString().split(' ')[0];
    final prefs = await SharedPreferences.getInstance();
    final done = (prefs.getStringList('activity_done_$today') ?? []).toSet();
    if (done.contains(key)) {
      done.remove(key);
    } else {
      done.add(key);
    }
    await prefs.setStringList('activity_done_$today', done.toList());
    if (mounted) setState(() => _activityDone = done);
  }

  Future<void> _saveGoal(double goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('daily_goal_hours', goal);
    setState(() => _dailyGoalHours = goal);
  }

  Future<void> _updateProgress(int secondsAdded) async {
    final prefs = await SharedPreferences.getInstance();

    // `daily_progress_hours` ga yozmaymiz — `today_focus_seconds` yagona
    // manba (background service yangilab turadi). Faqat UI'ni qayta
    // o'qib darrov yangilaymiz.
    await prefs.reload();
    final todayFocusSeconds = prefs.getInt('today_focus_seconds') ?? 0;
    setState(() => _currentProgressHours = todayFocusSeconds / 3600);

    // XP va streak update'lari `PendingResultsProcessor` orqali bajariladi.

    // Faoliyat progressini yangilash — `_activityProgress[key]` endi
    // SEKUNDLARDA saqlanadi (avval daqiqada edi — 10 sek 0 ga aylanardi).
    // Bu yerda raw sekundlarni qo'shamiz, aniqlik saqlanadi.
    if (_selectedActivityIndex >= 0 &&
        _selectedActivityIndex < _customActivities.length &&
        secondsAdded > 0) {
      final activity = _customActivities[_selectedActivityIndex];
      final activityKey = activity['key'] ?? activity['name'];
      final currentSeconds = _activityProgress[activityKey] ?? 0;

      setState(() {
        _activityProgress[activityKey] = currentSeconds + secondsAdded;
      });

      // Saqlash (sekundda)
      final today = DateTime.now().toString().split(' ')[0];
      final progressString = Uri(
        queryParameters:
            _activityProgress.map((key, value) => MapEntry(key, value.toString())),
      ).query;
      await prefs.setString('activity_progress_$today', progressString);
    }
  }

  /// Sekundlarni "M:SS" formatiga (pauza budjeti ko'rsatkichi uchun).
  String _formatMSS(int seconds) {
    if (seconds < 0) seconds = 0;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Sekundlarni "5d 30s" yoki "30s" yoki "5d" formatiga aylantirish.
  /// Activity progress'ni ko'rsatish uchun (kichik vaqtlar uchun aniqlik).
  String _formatActivityProgress(int seconds) {
    if (seconds <= 0) return '0';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}d';
    return '${m}d ${s}s';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerSubscription?.cancel();
    _tipTimer?.cancel();
    _marqueeController.dispose();
    _activityPageController.dispose();
    _motivationController.dispose();
    // Tabiat ovozini ham to'xtatamiz — ekran yopildi
    SoundscapeService.instance.stop();
    super.dispose();
  }

  String get _formattedTime {
    int m = _remainingSeconds ~/ 60;
    int s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Bloklash ishlashi uchun overlay ruxsati kerak.
  /// Usage stats ruxsatini ham tekshiramiz — lekin sekin qurilmalarda
  /// AppUsage query 700ms'dan ko'p vaqt olishi mumkin. Shuning uchun
  /// timeout'ni 2 sekundga ko'tardik va UsageStats permission API'ga
  /// ham fallback qo'shdik (query qilmasdan faqat ruxsat holatini tekshiradi).
  Future<bool> _hasBlockingPermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    bool overlayOk = await Permission.systemAlertWindow.isGranted;
    if (!overlayOk) return false;
    // Usage stats — avval tez yo'l (UsageStats.checkUsagePermission),
    // keyin AppUsage query fallback.
    bool usageOk = false;
    try {
      usageOk = await UsageStats.checkUsagePermission() ?? false;
    } catch (_) {}
    if (!usageOk) {
      try {
        final now = DateTime.now();
        await AppUsage()
            .getAppUsage(now.subtract(const Duration(seconds: 1)), now)
            .timeout(const Duration(milliseconds: 2000));
        usageOk = true;
      } catch (_) {
        usageOk = false;
      }
    }
    return usageOk;
  }

  Future<bool> _ensurePermissionsForTimer() async {
    if (await _hasBlockingPermissions()) return true;
    if (!mounted) return false;
    // Ruxsat yetishmaydi — PermissionsScreen'ga olib boramiz.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PermissionsScreen(isFromOnboarding: false),
      ),
    );
    // Qaytib kelgach qayta tekshiramiz. Berilgan bo'lsa eslatmani bekor qilamiz.
    final ok = await _hasBlockingPermissions();
    if (ok) TimerNotificationService().cancelPermissionNudge();
    return ok;
  }

  void _startTimer() async {
    // Bloklash uchun ruxsatlar FAQAT Chuqur Fokus (mode 0)'da talab qilinadi —
    // o'sha rejim ilovalarni bloklaydi. Yengil Fokus (mode 1) shunchaki
    // taymer + tabiat ovozi; u overlay/usage ruxsatisiz ham ishlashi kerak.
    // Avval ikkala rejim ham gate ortida edi — shuning uchun Yengil Fokus ham
    // ruxsatsiz qurilmada "ishlamayotgandek" ko'rinardi.
    if (_selectedMode == 0) {
      if (!await _ensurePermissionsForTimer()) return;
      // Chuqur Fokus boshlashdan oldin eslatma — bu seansda to'xtatish va
      // pauza cheklovlari haqida ogohlantirib, tasdiqlatamiz.
      if (!await _showDeepFocusReminder()) return;
    }
    final lang = AppTranslationService();
    
    int level = 1;
    String rankTitle = lang.translate('levels.rank_1') ?? 'Yangi Foydalanuvchi';
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Haqiqiy daraja va unvonni olish (timeout bilan va keshdan)
        final stats = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 1));
        
        if (stats.exists) {
          level = stats.data()?['level'] ?? 1;
          rankTitle = LevelService().getRankTitle(level, lang);
        }
      }
    } catch (e) {
      debugPrint('Error getting stats for timer: $e');
    }

    final levelLabel = lang.translate('levels.level') ?? 'Daraja';
    final fullLevelTitle = '$levelLabel $level · $rankTitle';
    
    _timerService.startTimer(
      minutes: _selectedMinutes,
      modeName: _selectedMode == 0 ? lang.translate('focus_timer.status_deep') : lang.translate('focus_timer.status_light'),
      modeIcon: _selectedMode == 0 ? '⚡' : '🌿',
      levelTitle: fullLevelTitle,
      // Temir Intizom faqat Chuqur Fokus'da: foydalanuvchi toggle yoqib
      // qo'ygan + mode==0 bo'lgan paytda. Yengil Fokus'da isStrict=false.
      isStrict: _effectiveStrict,
      // Yengil Fokus rejimi flagini alohida uzatamiz — background service
      // shu qiymat asosida `light_focus_total_seconds` counterni oshiradi.
      isLight: _selectedMode == 1,
      // Premium foydalanuvchida pauza cheksiz, to'xtatish ham mumkin.
      isPremium: _isPremium,
    );

    // Tabiat ovozi FAQAT Yengil Fokus rejimida chalinadi. Chuqur Fokus —
    // jimgina ishlash kerak (chalg'itmasin). Foydalanuvchi Yengil Fokus'da
    // "Yomg'ir" tanlab qo'ygan bo'lsa-da, Chuqur Fokus'ga o'tib seansni
    // boshlasa, ovoz ishlamaydi.
    if (_selectedMode == 1) {
      SoundscapeService.instance.play(_selectedSound);
    } else {
      // Xavfsizlik uchun: agar avvalgi seansdan audio qolgan bo'lsa to'xtaymiz.
      SoundscapeService.instance.stop();
    }

    // Anti-Chalg'itish (DnD) — faqat Chuqur Fokus + toggle yoqilgan bo'lsa.
    // Yengil Fokus'da chalg'itmaymiz, foydalanuvchi notifikatsiyalarni
    // bemalol ko'rishi mumkin.
    if (_selectedMode == 0 && _isAntiDistract) {
      DndService.instance.enableFocusMode();
    }
  }

  /// Chuqur Fokus boshlashdan oldingi eslatma dialogi. Bu seansda
  /// to'xtatib bo'lmasligi va pauza budjeti haqida qisqacha tushuntiradi.
  /// Foydalanuvchi "Boshlash"ni bossa true qaytaradi.
  Future<bool> _showDeepFocusReminder() async {
    final lang = AppTranslationService();
    final budget = _pauseBudgetFor(_selectedMinutes);
    String pauseLine;
    if (budget < 0) {
      pauseLine = lang.translate('focus_timer.reminder.pause_unlimited');
    } else if (budget == 0) {
      pauseLine = lang.translate('focus_timer.reminder.pause_none');
    } else {
      pauseLine = lang
          .translate('focus_timer.reminder.pause_limited')
          .replaceAll('{min}', (budget ~/ 60).toString());
    }
    final stopLine = _isPremium
        ? lang.translate('focus_timer.reminder.stop_premium')
        : lang.translate('focus_timer.reminder.stop_locked');

    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(lang.translate('focus_timer.reminder.title')),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('⏸  $pauseLine',
                  style: GoogleFonts.inter(fontSize: 13.5, height: 1.4)),
              const SizedBox(height: 8),
              Text('🛑  $stopLine',
                  style: GoogleFonts.inter(fontSize: 13.5, height: 1.4)),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.translate('focus_timer.cancel')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.translate('focus_timer.reminder.confirm')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Premium taklif dialogi — bepul foydalanuvchi to'xtatish/pauza
  /// cheklovga urilganda ko'rsatiladi.
  void _showPremiumUpsell(String body) {
    final lang = AppTranslationService();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(lang.translate('focus_timer.upsell.title')),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(body, style: GoogleFonts.inter(fontSize: 13.5, height: 1.4)),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.translate('focus_timer.cancel')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            child: Text(lang.translate('focus_timer.upsell.cta')),
          ),
        ],
      ),
    );
  }

  void _pauseTimer() {
    _timerService.pauseTimer();
    // Pauza paytida ovozni ham to'xtatamiz. Resume'da qaytadan boshlanadi.
    SoundscapeService.instance.stop();
  }

  void _resumeTimer() {
    _timerService.resumeTimer();
    // Pauza qaytarilganda ovozni qayta yoqamiz — faqat Yengil Fokus'da.
    if (_selectedMode == 1) {
      SoundscapeService.instance.play(_selectedSound);
    }
    // Pauza paytida foydalanuvchi Anti-Chalg'itish toggle'ni yoqib qo'ygan
    // bo'lishi mumkin. Resume bilan birga DnD'ni darrov qo'llaymiz.
    if (_selectedMode == 0 && _isAntiDistract) {
      DndService.instance.enableFocusMode();
    }
  }

  /// Anti-Chalg'itish toggle bosilganda — toggle holatini saqlash va
  /// agar ON bo'lsa permission tekshirish. Yo'q bo'lsa dialog ko'rsatamiz.
  ///
  /// Agar Chuqur Fokus seansi hozir ishlayotgan/pauzada bo'lsa, toggle
  /// o'zgarishi darrov qo'llanadi:
  ///   - ON bosildi → DnD darrov yoqiladi
  ///   - OFF bosildi → DnD darrov o'chiriladi (avvalgi holatga qaytadi)
  void _onAntiDistractToggle(bool value) async {
    setState(() => _isAntiDistract = value);
    await DndService.instance.setToggleEnabled(value);

    // Hozir Chuqur Fokus seansi faolmi? (ishlayapti yoki pauzada)
    final isActiveDeepSession =
        (_isRunning || _isPaused) && _selectedMode == 0;

    if (!value) {
      // Toggle OFF — agar biz DnD yoqgan bo'lsak, darrov o'chiramiz
      await DndService.instance.disableFocusMode();
      return;
    }

    // Toggle ON — permission tekshirish
    final granted = await DndService.instance.isPermissionGranted();
    if (!granted && mounted) {
      _showDndPermissionDialog();
      return;
    }
    // Agar fokus hozir faol bo'lsa, DnD'ni darrov yoqamiz
    if (isActiveDeepSession) {
      await DndService.instance.enableFocusMode();
    }
  }

  /// DnD permission so'rash dialogi. Foydalanuvchi "Berish" bossa
  /// tizim Settings ekrani ochiladi.
  void _showDndPermissionDialog() {
    final lang = AppTranslationService();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          lang.translate('focus_timer.dnd_permission_title') ??
              'Sukut rejimi ruxsati kerak',
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            lang.translate('focus_timer.dnd_permission_body') ??
                'Anti-Chalg\'itish funksiyasi ishlashi uchun "Sukut rejimini boshqarish" ruxsatini berishingiz kerak. Ruxsat bersangiz, taymer paytida barcha bildirishnomalar jim turadi.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(lang.translate('focus_timer.later') ?? 'Keyinroq'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(lang.translate('focus_timer.grant') ?? 'Berish'),
            onPressed: () {
              Navigator.pop(ctx);
              DndService.instance.openPermissionSettings();
            },
          ),
        ],
      ),
    );
  }

  /// Temir Intizom faqat Chuqur Fokus rejimida ishlaydi. Yengil Fokus'da
  /// foydalanuvchi istagan paytda chiqishi mumkin. UI da toggle Yengil
  /// Fokus'da yashirilgan, lekin `_isStrictMode` state qiymati default'da
  /// `true` bo'lib qoladi — shu sababli mantiqda mode'ni ham tekshiramiz.
  bool get _effectiveStrict => _isStrictMode && _selectedMode == 0;

  void _stopTimer() {
    if (_effectiveStrict && _isRunning) {
      // Temir Intizom yoqilgan + ishlayotgan paytda dialog chiqadi.
      // Dialog ichida tasdiqlasa audio ham, timer ham to'xtaydi.
      _showStopConfirmationDialog();
    } else {
      // To'xtatishdan oldin o'tgan vaqtni activity progress'iga
      // yozib qo'yamiz — hatto 10 sekund ham hisoblanadi (sekund
      // aniqligida saqlanadi).
      final elapsedSeconds = (_selectedMinutes * 60) - _remainingSeconds;
      if (elapsedSeconds >= 1 && _selectedActivityIndex >= 0) {
        _updateProgress(elapsedSeconds);
      }
      _timerService.stopTimer();
      SoundscapeService.instance.stop();
      // DnD'ni avvalgi holatga qaytarish (agar biz yoqgan bo'lsak).
      DndService.instance.disableFocusMode();
    }
  }

  void _showStopConfirmationDialog() {
    final lang = AppTranslationService();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(lang.translate('focus_timer.stop_confirm_title') ?? 'Taslim bo\'lasizmi?'),
        content: Text(lang.translate('focus_timer.stop_confirm_body') ?? 'Haqiqatan ham taslim bo\'lmoqchimisiz? Maqsadingizga erishishingizga oz qoldi!'),
        actions: [
          CupertinoDialogAction(
            child: Text(lang.translate('focus_timer.continue') ?? 'Davom etish'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              // Strict dialog orqali to'xtatilganda ham activity progress
              // saqlanadi (sekund aniqligi) va audio to'xtatiladi.
              final elapsedSeconds =
                  (_selectedMinutes * 60) - _remainingSeconds;
              if (elapsedSeconds >= 1 && _selectedActivityIndex >= 0) {
                _updateProgress(elapsedSeconds);
              }
              _timerService.stopTimer();
              SoundscapeService.instance.stop();
              // DnD ham qaytariladi (agar biz yoqgan bo'lsak).
              DndService.instance.disableFocusMode();
            },
            child: Text(lang.translate('focus_timer.give_up') ?? 'Taslim bo\'lish'),
          ),
        ],
      ),
    );
  }

  void _onTimerComplete(int minutes) async {
    _updateProgress(minutes * 60);
    HapticFeedback.vibrate();
    // Tabiat ovozini to'xtatamiz — endi taymer alarm ringtoni o'ynaydi.
    SoundscapeService.instance.stop();
    // Anti-Chalg'itish DnD'ni qaytaramiz — foydalanuvchi yutuqdan keyin
    // notifikatsiyalarni qabul qilishi mumkin.
    DndService.instance.disableFocusMode();

    // Rington background service tomonidan allaqachon o'ynalmoqda
    // (looping=true). Bu yerda qayta o'ynatmaymiz.
    // stopAlarm() orqali background service'ga signal yuboramiz — u
    // FlutterRingtonePlayer().stop() chaqiradi.

    final lang = AppTranslationService();
    if (!mounted) return;

    // iPhone uslubidagi CupertinoAlertDialog — ilova ichida timer
    // tugaganda chiqadi. App tashqarisida bo'lsa overlay (overlay_screen.dart)
    // chiqadi — bu joyda emas.
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              lang.translate('alarm.in_app_title'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            lang.translate('alarm.in_app_body'),
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              _timerService.stopAlarm();
              Navigator.of(ctx).pop();
            },
            child: Text(
              lang.translate('alarm.dismiss_btn'),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoBlockedAppsDialog() {
    final lang = AppTranslationService();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(lang.translate('focus_timer.no_blocked_apps_title') ?? "Diqqat! 🛡️"),
        content: Text(
          lang.translate('focus_timer.no_blocked_apps_desc') ?? 
          "Sizni chalg'itadigan ilovalarni hali tanlamadingiz. "
          "Chuqur diqqat rejimi samarali bo'lishi uchun ilovalarni bloklashni tavsiya qilamiz."
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(lang.translate('focus_timer.btn_block') ?? "Bloklash"),
            onPressed: () {
              Navigator.pop(context);
              widget.onNavigateToBlockList?.call();
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(lang.translate('focus_timer.btn_start') ?? "Boshlash"),
            onPressed: () {
              Navigator.pop(context);
              _startTimer();
            },
          ),
        ],
      ),
    );
  }

  void _showActivityEditor() {
    final lang = AppTranslationService();
    final nameController = TextEditingController();
    int tempMinutes = 45;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final lang = AppTranslationService();
        return StatefulBuilder(
          builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(lang.translate('focus_timer.add_activity'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '${lang.translate('focus_timer.activity_name')}...',
                    hintStyle: GoogleFonts.inter(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.4) : const Color(0xFF3C3C43).withOpacity(0.3),
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(CupertinoIcons.pencil, color: Color(0xFF007AFF)),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : const Color(0xFFF2F2F7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lang.translate('focus_timer.time_minutes'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        IconButton(icon: const Icon(CupertinoIcons.minus_circle), onPressed: () => setModalState(() => tempMinutes = (tempMinutes > 5) ? tempMinutes - 5 : 5)),
                        Text('$tempMinutes ${lang.translate('focus_timer.min')}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                        IconButton(icon: const Icon(CupertinoIcons.plus_circle), onPressed: () => setModalState(() => tempMinutes += 5)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty) {
                        setState(() {
                          _customActivities.add({'name': nameController.text, 'minutes': tempMinutes});
                        });
                        
                        // Saqlash
                        _saveActivities();
                        
                        Navigator.pop(context);
                        
                        // Auto-scroll to the new page
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (_activityPageController.hasClients) {
                            int lastPage = (_customActivities.length / 3).ceil() - 1;
                            _activityPageController.animateToPage(
                              lastPage,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: Text(lang.translate('focus_timer.add'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    },
  );
}

  void _startMarquee() async {
    while (mounted) {
      if (!_marqueeController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }
      
      final textStyle = GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600);
      final textPainter = TextPainter(
        text: TextSpan(text: '$_motivationPhrase   •   ', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      
      double singleWidth = textPainter.width;
      
      if (singleWidth > 0 && _marqueeController.hasClients) {
        try {
          // Always scroll from 0 to singleWidth
          _marqueeController.jumpTo(0);
          await _marqueeController.animateTo(
            singleWidth,
            duration: Duration(milliseconds: (singleWidth * 50).toInt()),
            curve: Curves.linear,
          );
        } catch (e) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }


  List<String> _getLocalizedActivities(AppTranslationService lang) {
    return [
      lang.translate('focus_timer.activities.coding'),
      lang.translate('focus_timer.activities.reading'),
      lang.translate('focus_timer.activities.work'),
      lang.translate('focus_timer.activities.meditation'),
      lang.translate('focus_timer.activities.sport'),
      lang.translate('focus_timer.activities.other'),
    ];
  }

  void _showSoundscapePicker() {
    final lang = AppTranslationService();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext context) {
        final lang = AppTranslationService();
        // Faqat 3 ta variant — Kafe va Oq shovqin olib tashlandi.
        final sounds = [
          {'name': 'none', 'icon': CupertinoIcons.slash_circle},
          {'name': 'rain', 'icon': CupertinoIcons.cloud_rain},
          {'name': 'forest', 'icon': CupertinoIcons.tree},
        ];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lang.translate('focus_timer.sounds.title'),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...sounds.map((sound) => ListTile(
                leading: Icon(sound['icon'] as IconData, color: Theme.of(context).primaryColor),
                title: Text(_getLocalizedSoundName(sound['name'] as String, lang), style: GoogleFonts.inter()),
                trailing: _selectedSound == sound['name'] ? const Icon(CupertinoIcons.check_mark, color: Color(0xFF34C759)) : null,
                onTap: () async {
                  final newSound = sound['name'] as String;
                  setState(() => _selectedSound = newSound);
                  // Tanlovni saqlaymiz va agar seans hozir ishlayotgan
                  // bo'lsa, ovoz darrov yangisiga almashtiriladi.
                  await SoundscapeService.instance.setSelectedSound(newSound);
                  // Qisqa namuna chalamiz — foydalanuvchi ovozni darrov
                  // eshitadi (seans boshlanmagan bo'lsa ~6s keyin to'xtaydi).
                  SoundscapeService.instance.preview(newSound);
                  if (mounted) Navigator.pop(context);
                },
              )),
            ],
          ),
        );
      },
    );
  }

  void _showGoalEditPicker() {
    final lang = AppTranslationService();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext context) {
        final lang = AppTranslationService();
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 24),
              Text(lang.translate('focus_timer.edit_goal_title'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 24),
              // Motivation TextField
              TextField(
                controller: _motivationController,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: InputDecoration(
                  labelText: lang.translate('focus_timer.motivation_label'),
                  labelStyle: GoogleFonts.inter(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.5) : const Color(0xFF8E8E93)),
                  hintStyle: GoogleFonts.inter(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.4) : const Color(0xFF3C3C43).withOpacity(0.3)),
                  hintText: lang.translate('focus_timer.motivation_hint'),
                  prefixIcon: const Icon(CupertinoIcons.heart_fill, color: Color(0xFF007AFF), size: 20),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      pickerTextStyle: GoogleFonts.inter(
                        fontSize: 22,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: Duration(minutes: (_dailyGoalHours * 60).toInt()),
                    onTimerDurationChanged: (Duration newDuration) {
                      HapticFeedback.selectionClick();
                      SystemSound.play(SystemSoundType.click);
                      setState(() {
                        _dailyGoalHours = newDuration.inMinutes / 60.0;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _motivationPhrase = _motivationController.text;
                  });
                  
                  // Background servicega maqsadni yuborish
                  _timerService.updateDailyGoal((_dailyGoalHours * 3600).toInt());
                  
                  // SharedPreferences ga saqlash
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setDouble('daily_goal_hours', _dailyGoalHours);
                  await prefs.setString('motivation_phrase', _motivationPhrase);
                  
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(lang.translate('focus_timer.save'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFeatureInfo(String title, String description, IconData icon, Color iconColor) {
    final lang = AppTranslationService();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        final lang = AppTranslationService();
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF8E8E93), height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2F2F7),
                  foregroundColor: const Color(0xFF1C1C1E),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(lang.translate('focus_timer.understood'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showManualTimePicker() {
    if (_isRunning) return;
    final lang = AppTranslationService();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext context) {
        final lang = AppTranslationService();
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(foregroundColor: Theme.of(context).primaryColor),
                      child: Text(lang.translate('focus_timer.cancel'), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      child: Text(
                        lang.translate('focus_timer.set_time'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(foregroundColor: Theme.of(context).primaryColor),
                      child: Text(lang.translate('focus_timer.done'), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      pickerTextStyle: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: Duration(minutes: _selectedMinutes),
                    onTimerDurationChanged: (Duration newDuration) {
                      HapticFeedback.selectionClick();
                      SystemSound.play(SystemSoundType.click);
                      if (newDuration.inMinutes > 0) {
                        setState(() {
                          _selectedMinutes = newDuration.inMinutes;
                          if (!_isRunning) _remainingSeconds = _selectedMinutes * 60;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }  @override
  Widget build(BuildContext context) {
    final lang = AppTranslationService();
    return ValueListenableBuilder<String>(
      valueListenable: lang.languageNotifier,
      builder: (context, _, __) {
        return PopScope(
          canPop: !(_effectiveStrict && _isRunning),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_effectiveStrict && _isRunning) {
              _showStopConfirmationDialog();
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
        children: [
          const SizedBox(height: 10), 
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildFocusTipBanner(lang),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildModeTab(0, lang.translate('focus_timer.mode_deep'), CupertinoIcons.bolt_fill),
                          _buildModeTab(1, lang.translate('focus_timer.mode_light'), CupertinoIcons.tree),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(
                            value: _selectedMinutes > 0 ? (_remainingSeconds / (_selectedMinutes * 60)) : 0,
                            strokeWidth: 12,
                            backgroundColor: const Color(0xFFE5E5EA),
                            strokeCap: StrokeCap.round,
                            valueColor: AlwaysStoppedAnimation<Color>(_selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759)),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            _formattedTime,
                            style: GoogleFonts.inter(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedMode == 0 ? lang.translate('focus_timer.status_deep') : lang.translate('focus_timer.status_light'),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _isRunning ? null : () {
                      if (_isPaused) {
                        setState(() {
                          _isPaused = false;
                          _remainingSeconds = _selectedMinutes * 60;
                        });
                      }
                      _showManualTimePicker();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: (_selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759)).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.pencil,
                            size: 18,
                            color: _selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            lang.translate('focus_timer.change_time'),
                            style: GoogleFonts.inter(
                              color: _selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildTimeChip(25, lang),
                      _buildTimeChip(45, lang),
                      _buildTimeChip(60, lang),
                      _buildTimeChip(120, lang),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (_selectedMode == 0) ...[
                            // Toggle qulflari:
                            //   Temir Intizom — seans (running yoki pauza)
                            //     paytida o'zgartirib bo'lmaydi. Seans
                            //     boshlangach foydalanuvchi mantiq qoidalarini
                            //     buzmasligi uchun.
                            //   Anti-Chalg'itish — faqat ishlayotgan paytda
                            //     qulflanadi. PAUZADA o'zgartirib bo'ladi
                            //     (foydalanuvchi keyingi bosqichda DnD'ni
                            //     yoqishni xohlasa, pauza qilib yoqishi mumkin).
                            _buildOptionRow(
                              CupertinoIcons.shield_fill,
                              const Color(0xFF34C759),
                              lang.translate('focus_timer.strict_mode'),
                              lang.translate('focus_timer.strict_desc'),
                              true,
                              value: _isStrictMode,
                              onChanged: (_isRunning || _isPaused)
                                  ? null
                                  : (v) => setState(() => _isStrictMode = v),
                              onTap: () => _showFeatureInfo(
                                lang.translate('focus_timer.strict_mode'),
                                lang.translate('focus_timer.strict_mode_info'),
                                CupertinoIcons.shield_fill,
                                const Color(0xFF34C759),
                              ),
                            ),
                            Divider(color: Colors.grey.withOpacity(0.1), height: 1),
                            _buildOptionRow(
                              CupertinoIcons.moon_zzz_fill,
                              const Color(0xFF5856D6),
                              lang.translate('focus_timer.anti_distract'),
                              lang.translate('focus_timer.anti_distract_desc'),
                              true,
                              value: _isAntiDistract,
                              onChanged: _isRunning
                                  ? null
                                  : (v) => _onAntiDistractToggle(v),
                              onTap: () => _showFeatureInfo(
                                lang.translate('focus_timer.anti_distract'),
                                lang.translate('focus_timer.anti_distract_info'),
                                CupertinoIcons.moon_zzz_fill,
                                const Color(0xFF5856D6),
                              ),
                            ),
                          ] else ...[
                            // Yengil Fokus rejimida faqat Tabiat Ovozlari
                            // ko'rsatiladi. "Ruxsat Berilganlar" mock funksiyasi
                            // olib tashlandi — soddaroq UX uchun.
                            _buildOptionRow(
                              CupertinoIcons.speaker_2_fill,
                              const Color(0xFF5E5CE6),
                              lang.translate('focus_timer.nature_sounds'),
                              _getLocalizedSoundName(_selectedSound, lang),
                              false,
                              onTap: _showSoundscapePicker,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton(
                      onPressed: () async {
                        // 3 ta holat:
                        //   1. Taymer ishlayapti  → Pauza qilamiz
                        //   2. Pauzada turibdi    → Resume qilamiz (boshidan
                        //      boshlamaymiz, qolgan vaqtdan davom etamiz)
                        //   3. Hech narsa ishlamayapti → Yangi taymer
                        if (_isRunning) {
                          // Pauza gating — Chuqur Fokusda budjet bo'lsagina.
                          // Yengil Fokus va Premium → cheksiz.
                          final canPause = _selectedMode == 1 ||
                              _pauseUnlimited ||
                              _pauseRemaining > 0;
                          if (!canPause) {
                            _showPremiumUpsell(lang
                                .translate('focus_timer.upsell.pause_body'));
                            return;
                          }
                          _pauseTimer();
                        } else if (_isPaused) {
                          _resumeTimer();
                        } else {
                          // Agar Deep Mode bo'lsa va bloklangan ilovalar bo'lmasa, dialog chiqaramiz
                          if (_selectedMode == 0) {
                            final prefs = await SharedPreferences.getInstance();
                            final blockedApps = prefs.getStringList('blocked_apps') ?? [];

                            if (blockedApps.isEmpty) {
                              _showNoBlockedAppsDialog();
                              return;
                            }
                          }
                          _startTimer();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRunning 
                            ? const Color(0xFFFF3B30) 
                            : (_selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759)),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 64),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        elevation: 2,
                        shadowColor: (_isRunning 
                            ? const Color(0xFFFF3B30) 
                            : (_selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759))).withOpacity(0.4),
                      ),
                      child: Text(
                        _isRunning 
                            ? (lang.translate('focus_timer.pause') ?? 'Pauza')
                            : (_isPaused
                                ? (lang.translate('focus_timer.resume') ?? 'Davom etish')
                                : (_selectedMode == 0 ? lang.translate('focus_timer.start_deep') : lang.translate('focus_timer.start_light'))),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Pauza budjeti ko'rsatkichi — pauzada va cheklangan bo'lsa.
                  if (_isPaused && !_pauseUnlimited) ...[
                    const SizedBox(height: 10),
                    Text(
                      '⏸ ${lang.translate('focus_timer.pause_left')}: ${_formatMSS(_pauseRemaining)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF9500),
                      ),
                    ),
                  ],
                  if (_isRunning || _isPaused) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        // To'xtatish — bepul foydalanuvchida qulflangan.
                        // Chuqur Fokusda faqat Premium erta to'xtata oladi.
                        if (_selectedMode == 0 && !_isPremium) {
                          _showPremiumUpsell(lang
                              .translate('focus_timer.upsell.stop_body'));
                          return;
                        }
                        _stopTimer();
                      },
                      child: Text(
                        (_selectedMode == 0 && !_isPremium)
                            ? '🔒 ${lang.translate('focus_timer.stop')}'
                            : lang.translate('focus_timer.stop'),
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildSummaryCard(
                          lang.translate('focus_timer.daily_goal'),
                          // Soat-daqiqa formatida ko'rsatamiz: "2s 30d / 5s 45d"
                          // (avval "2.5 / 5.8 soat" edi — uzun maqsadlarda
                          // (5h 45m) o'qish noqulay edi).
                          '${_formatHoursToHm(_currentProgressHours)} / ${_formatHoursToHm(_dailyGoalHours)}',
                          (_dailyGoalHours > 0 ? _currentProgressHours / _dailyGoalHours : 0.0).clamp(0.0, 1.0),
                          CupertinoIcons.flag_fill,
                          _selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759),
                          showEdit: true,
                          onTap: _showGoalEditPicker,
                          motivationWidget: (_motivationPhrase.trim().isEmpty) ? null : SizedBox(
                            width: double.infinity,
                            height: 20,
                            child: SingleChildScrollView(
                              controller: _marqueeController,
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: Text(
                                '$_motivationPhrase   •   ' * 10,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: (_selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759)).withOpacity(0.7),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Faoliyat turlari faqat Chuqur Fokus (Deep Work) rejimida
                  // ko'rinadi. Yengil Fokus rejimida foydalanuvchi shunchaki
                  // fokus qiladi — faoliyat tanlash kerakmas.
                  if (_selectedMode == 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            lang.translate('focus_timer.activity'),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(CupertinoIcons.plus, size: 11, color: Theme.of(context).primaryColor),
                              onPressed: _showActivityEditor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_selectedMode == 0) const SizedBox(height: 12),
                  Column(
                    children: [
                      if (_selectedMode != 0)
                        const SizedBox.shrink()
                      else if (_customActivities.isEmpty)
                        _buildEmptyActivities(lang)
                      else ...[
                        SizedBox(
                          height: 65,
                          child: ScrollConfiguration(
                            behavior: const MaterialScrollBehavior().copyWith(
                              dragDevices: {
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.touch,
                                PointerDeviceKind.stylus,
                                PointerDeviceKind.unknown,
                              },
                            ),
                            child: PageView.builder(
                              controller: _activityPageController,
                              physics: const BouncingScrollPhysics(),
                              onPageChanged: (int page) {
                                setState(() {
                                  _currentActivityPage = page;
                                });
                              },
                              itemCount: (_customActivities.length / 3).ceil(),
                              itemBuilder: (context, pageIndex) {
                                int startIndex = pageIndex * 3;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Row(
                                    children: [
                                      for (int i = 0; i < 3; i++)
                                        if (startIndex + i < _customActivities.length)
                                          Expanded(
                                            child: _buildActivityCard(
                                              startIndex + i,
                                              _customActivities[startIndex + i].containsKey('key')
                                                ? lang.translate('focus_timer.' + _customActivities[startIndex + i]['key'])
                                                : _customActivities[startIndex + i]['name'],
                                              _customActivities[startIndex + i]['minutes'],
                                              lang,
                                            ),
                                          )
                                        else
                                          const Expanded(child: SizedBox()),
                                    ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              (_customActivities.length / 3).ceil(),
                              (index) => GestureDetector(
                                onTap: () {
                                  _activityPageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOut,
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  height: 6,
                                  width: _currentActivityPage == index ? 16 : 6,
                                  decoration: BoxDecoration(
                                    color: _currentActivityPage == index
                                        ? (_selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759))
                                        : const Color(0xFFE5E5EA),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _buildPremiumBanner(lang),
                        const SizedBox(height: 40), // Reduced bottom spacing
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);
}

  String _getLocalizedSoundName(String sound, AppTranslationService lang) {
    switch (sound) {
      case 'none': return lang.translate('focus_timer.sounds.none');
      case 'rain': return lang.translate('focus_timer.sounds.rain');
      case 'forest': return lang.translate('focus_timer.sounds.forest');
      case 'cafe': return lang.translate('focus_timer.sounds.cafe');
      case 'white_noise': return lang.translate('focus_timer.sounds.white_noise');
      default: return lang.translate('focus_timer.sounds.none');
    }
  }

  /// Tepadagi shaffof (suvdek) maslahat banneri — aylanma takliflar.
  Widget _buildFocusTipBanner(AppTranslationService lang) {
    final tips = lang.translateList('focus_timer.tips');
    final List<String> list = tips.isNotEmpty
        ? tips.map((e) => e.toString()).toList()
        : [lang.translate('focus_timer.tips_fallback')];
    final tip = list[_tipIndex % list.length];
    final accent = _selectedMode == 0
        ? Theme.of(context).primaryColor
        : const Color(0xFF34C759);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: Container(
              key: ValueKey(tip),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.sparkles, size: 18, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumBanner(AppTranslationService lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (context) => const PremiumScreen()),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA855F7).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(
                  FontAwesomeIcons.crown,
                  color: Color(0xFFFFD700),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.translate('focus_timer.premium_banner_title'),
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.surface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lang.translate('focus_timer.premium_banner_desc'),
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChip(int minutes, AppTranslationService lang) {
    bool active = _selectedMinutes == minutes;
    Color activeColor = _selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759);
    return GestureDetector(
      onTap: () {
        if (_isRunning) return;
        setState(() {
          _selectedMinutes = minutes;
          _remainingSeconds = minutes * 60;
          _isPaused = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeColor : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? Colors.transparent : Colors.grey.withOpacity(0.2)),
          boxShadow: active ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))] : [],
        ),
        child: Text(
          '${minutes} ${lang.translate('focus_timer.min')}',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow(IconData icon, Color iconColor, String title, String subtitle, bool isToggle, {bool? value, ValueChanged<bool>? onChanged, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                ],
              ),
            ),
            if (isToggle)
              Transform.scale(
                scale: 0.85,
                child: CupertinoSwitch(
                  value: value ?? false,
                  activeColor: const Color(0xFF34C759),
                  onChanged: _isRunning ? null : onChanged,
                ),
              )
            else
              const Icon(CupertinoIcons.chevron_right, color: Color(0xFFC7C7CC), size: 18),
          ],
        ),
      ),
    );
  }

  // Float soat (5.75) ni "5s 45d" formatiga aylantiruvchi helper.
  // Foydalanuvchining tushunarli formatda ko'rishi uchun — qisqa
  // belgilar bilan (s = soat, d = daqiqa) kartochkaga sig'ishi
  // kafolatlangan.
  String _formatHoursToHm(double hours) {
    if (hours <= 0) return '0d';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}d';
    if (m == 0) return '${h}s';
    return '${h}s ${m}d';
  }

  Widget _buildSummaryCard(String title, String value, double progress, IconData icon, Color color, {bool showEdit = false, VoidCallback? onTap, Widget? motivationWidget}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF8E8E93), fontWeight: FontWeight.w600)),
                      if (showEdit)
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(CupertinoIcons.pencil, size: 13, color: color),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // FittedBox bilan o'rab — agar matn juda uzun bo'lsa
                  // (masalan "5s 45d / 12s 30d") shrift avtomatik kichik
                  // bo'ladi va matn 1 qatorda to'liq ko'rinadi. Aks
                  // holda matn kesilib ".." bo'lardi.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (motivationWidget != null) ...[
                    const SizedBox(height: 4),
                    motivationWidget,
                  ],
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFFE5E5EA),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Faoliyatlar bo'sh bo'lganda chiroyli placeholder ko'rsatadi.
  /// Yangi foydalanuvchi mock'lar o'rniga shu matnni ko'radi va
  /// yuqoridagi "+" tugmasi orqali o'z faoliyatlarini qo'shadi.
  Widget _buildEmptyActivities(AppTranslationService lang) {
    final accentColor = _selectedMode == 0
        ? Theme.of(context).primaryColor
        : const Color(0xFF34C759);
    return GestureDetector(
      onTap: _showActivityEditor,
      behavior: HitTestBehavior.opaque,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.add_circled,
              color: accentColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            lang.translate('focus_timer.no_activities_title') ??
                'Sevimli faoliyatingizni qo\'shing',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lang.translate('focus_timer.no_activities_hint') ??
                '"+" tugmasini bosing va boshlang',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildActivityCard(int index, String name, int minutes, AppTranslationService lang) {
    bool active = _selectedActivityIndex == index;
    Color color = _selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759);
    
    final activityKey = _customActivities[index]['key'] ?? _customActivities[index]['name'];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () {
          if (_isRunning) return;
          setState(() {
            // TOGGLE — agar shu activity allaqachon tanlangan bo'lsa,
            // qaytib bekor qilinadi (-1). Aks holda yangi tanlov.
            if (_selectedActivityIndex == index) {
              _selectedActivityIndex = -1;
            } else {
              _selectedActivityIndex = index;
              // Smart pickup — bugun shu faoliyatda sarflangan vaqtni
              // hisobga olib, faqat QOLGAN vaqtni taymerga qo'yamiz.
              // Misol: 45 daq maqsad, 1m6s qilingan → 43m54s qoldi → taymer 44 daq.
              //
              // Kunlik reset: `_activityProgress` har kuni 0 ga tushadi
              // (DailyResetService), demak ertaga to'liq 45 daq qaytadan boshlanadi.
              final completedSec = _activityProgress[activityKey] ?? 0;
              final targetSec = minutes * 60;
              final remainingSec = (targetSec - completedSec).clamp(0, targetSec);
              // Agar deyarli bajarilgan bo'lsa (< 30 sek qoldi), foydalanuvchi
              // yana ishlamoqchi bo'lsa — to'liq vaqtni qaytadan beramiz.
              final useSec = remainingSec >= 30 ? remainingSec : targetSec;
              // Daqiqaga yumalatish (yuqoriga, kam qilmaymiz).
              _selectedMinutes = (useSec / 60).ceil();
              _remainingSeconds = _selectedMinutes * 60;
              _isPaused = false;
            }
          });
        },
        onLongPress: () {
          // Show delete confirmation
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: Text(lang.translate('focus_timer.delete_activity_confirm')), // Need to add these to service
              content: Text('"${name}" ${lang.translate('focus_timer.delete_activity_desc')}'), 
              actions: [
                CupertinoDialogAction(
                  child: Text(lang.translate('focus_timer.cancel')),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () {
                    setState(() {
                      _customActivities.removeAt(index);
                    });
                    _saveActivities();
                    Navigator.pop(context);
                  },
                  child: Text(lang.translate('focus_timer.delete')),
                ),
              ],
            ),
          );
        },
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 26, 8),
              decoration: BoxDecoration(
                color: active ? color : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? Colors.transparent : Colors.grey.withOpacity(0.1)),
                boxShadow: active ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))] : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // `_activityProgress` endi sekundda saqlanadi. "5d 30s / 45 daq"
                    // ko'rinishida ko'rsatamiz — kichik vaqtlar ham ko'rinadi.
                    '${_formatActivityProgress(_activityProgress[activityKey] ?? 0)} / $minutes ${lang.translate('focus_timer.min')}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: active ? Colors.white.withOpacity(0.8) : const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            // Kunlik "bajardim" belgisi (odat tracking). Bosilganda card
            // tanloviga ta'sir qilmaydi — alohida GestureDetector ushlaydi.
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _toggleActivityDone(activityKey),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _activityDone.contains(activityKey)
                        ? const Color(0xFF34C759)
                        : (active ? Colors.white.withOpacity(0.25) : Colors.grey.withOpacity(0.15)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.checkmark_alt,
                    size: 12,
                    color: _activityDone.contains(activityKey)
                        ? Colors.white
                        : (active ? Colors.white : const Color(0xFF8E8E93)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(int index, String label, IconData icon) {
    bool active = _selectedMode == index;
    Color activeColor = index == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: active ? Colors.white : const Color(0xFF8E8E93)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : const Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final activitiesJson = _customActivities.map((a) => Uri(queryParameters: a.map((key, value) => MapEntry(key, value.toString()))).query).toList();
    await prefs.setStringList('custom_activities', activitiesJson);
  }
}

