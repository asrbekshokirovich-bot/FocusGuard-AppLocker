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

class FocusTimerScreen extends StatefulWidget {
  final VoidCallback? onNavigateToBlockList;
  const FocusTimerScreen({super.key, this.onNavigateToBlockList});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> with SingleTickerProviderStateMixin {
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
  
  // Dynamic Activities
  List<Map<String, dynamic>> _customActivities = [
    {'key': 'activities.coding', 'minutes': 45},
    {'key': 'activities.reading', 'minutes': 25},
    {'key': 'activities.work', 'minutes': 60},
    {'key': 'activities.meditation', 'minutes': 15},
  ];
  int _selectedActivityIndex = 0;
  
  double _dailyGoalHours = 4.0;
  double _currentProgressHours = 0.0;
  Map<String, int> _activityProgress = {}; // Activity key/name -> minutes spent today
  String _motivationPhrase = 'Bugun ajoyib kun bo\'ladi!';
  final TextEditingController _motivationController = TextEditingController(text: 'Bugun ajoyib kun bo\'ladi!');
  late ScrollController _marqueeController;
  late PageController _activityPageController;
  int _currentActivityPage = 0;

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
        setState(() {
          _remainingSeconds = event['seconds'] ?? _remainingSeconds;
          _isRunning = event['isRunning'] ?? _isRunning;
          _isPaused = event['isPaused'] ?? _isPaused;
        });
        
        if (_remainingSeconds == 0 && _isRunning == false && event['wasRunning'] == true) {
          _onTimerComplete(event['duration'] ?? (_selectedMinutes * 60));
        }
      }
    });

    _loadDailyProgress();
  }

  Future<void> _loadDailyProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReset = prefs.getString('last_progress_reset') ?? '';
    final today = DateTime.now().toString().split(' ')[0];

    if (lastReset != today) {
      // Kechagi maqsad tekshiruvi
      final lastGoal = prefs.getDouble('daily_goal_hours') ?? 4.0;
      final lastProgress = prefs.getDouble('daily_progress_hours') ?? 0.0;
      
      if (lastProgress < lastGoal && lastReset != '') {
        // Maqsadga erishilmagan - bildirishnoma yuborish
        TimerNotificationService().showGoalMissedNotification();
      }

      // Yangi kun - progressni nolga tushiramiz
      await prefs.setDouble('daily_progress_hours', 0.0);
      await prefs.setString('last_progress_reset', today);
    }

    setState(() {
      _dailyGoalHours = prefs.getDouble('daily_goal_hours') ?? 4.0;
      _currentProgressHours = prefs.getDouble('daily_progress_hours') ?? 0.0;
      _motivationPhrase = prefs.getString('motivation_phrase') ?? AppTranslationService().translate('focus_timer.motivation_default');
      _motivationController.text = _motivationPhrase;
      
      // Faoliyatlarni yuklash
      final activitiesJson = prefs.getStringList('custom_activities');
      if (activitiesJson != null) {
        _customActivities = activitiesJson.map((a) => Map<String, dynamic>.from(Uri.splitQueryString(a))).toList();
        // Convert minutes back to int
        for (var a in _customActivities) {
          a['minutes'] = int.tryParse(a['minutes'].toString()) ?? 25;
        }
      }
      
      // Faoliyat progressini yuklash
      final progressJson = prefs.getString('activity_progress_$today');
      if (progressJson != null) {
        final Map<String, dynamic> decoded = Uri.splitQueryString(progressJson);
        _activityProgress = decoded.map((key, value) => MapEntry(key, int.parse(value)));
      } else {
        _activityProgress = {};
      }
    });
    
    // Background servicega maqsadni yuborish
    _timerService.updateDailyGoal((_dailyGoalHours * 3600).toInt());
  }

  Future<void> _saveGoal(double goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('daily_goal_hours', goal);
    setState(() => _dailyGoalHours = goal);
  }

  Future<void> _updateProgress(int secondsAdded) async {
    final prefs = await SharedPreferences.getInstance();
    double hoursAdded = secondsAdded / 3600;
    double newProgress = _currentProgressHours + hoursAdded;
    
    await prefs.setDouble('daily_progress_hours', newProgress);
    setState(() => _currentProgressHours = newProgress);
    
    // XP va Level Service bilan integratsiya
    await LevelService().addXP((secondsAdded / 60).toInt());

    // Faoliyat progressini yangilash
    if (_selectedActivityIndex < _customActivities.length) {
      final activity = _customActivities[_selectedActivityIndex];
      final activityKey = activity['key'] ?? activity['name'];
      final currentActivityMinutes = _activityProgress[activityKey] ?? 0;
      final minutesToAdd = (secondsAdded / 60).round();
      
      setState(() {
        _activityProgress[activityKey] = currentActivityMinutes + minutesToAdd;
      });
      
      // Saqlash
      final today = DateTime.now().toString().split(' ')[0];
      final progressString = Uri(queryParameters: _activityProgress.map((key, value) => MapEntry(key, value.toString()))).query;
      await prefs.setString('activity_progress_$today', progressString);
    }
  }

  @override
  void dispose() {
    _timerSubscription?.cancel();
    _marqueeController.dispose();
    _activityPageController.dispose();
    _motivationController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    int m = _remainingSeconds ~/ 60;
    int s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startTimer() async {
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
      isStrict: _selectedMode == 0,
    );
  }

  void _pauseTimer() {
    _timerService.pauseTimer();
  }
  
  void _resumeTimer() {
    _timerService.resumeTimer();
  }

  void _stopTimer() {
    if (_isStrictMode && _isRunning) {
      _showStopConfirmationDialog();
    } else {
      _timerService.stopTimer();
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
              _timerService.stopTimer();
            },
            child: Text(lang.translate('focus_timer.give_up') ?? 'Taslim bo\'lish'),
          ),
        ],
      ),
    );
  }

  void _onTimerComplete(int durationSeconds) async {
    _updateProgress(durationSeconds);
    
    HapticFeedback.vibrate();
    FlutterRingtonePlayer().playAlarm(looping: false);

    final lang = AppTranslationService();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(lang.translate('focus_timer.completed_title') ?? 'Diqqat vaqti tugadi!'),
        content: Text(lang.translate('focus_timer.completed_desc') ?? 'Ajoyib natija, belgilangan vaqtni muvaffaqiyatli yakunladingiz!'),
        actions: [
          CupertinoDialogAction(
            child: Text(lang.translate('focus_timer.ok') ?? 'OK'),
            onPressed: () {
              FlutterRingtonePlayer().stop();
              Navigator.pop(context);
            },
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
        final sounds = [
          {'name': 'none', 'icon': CupertinoIcons.slash_circle},
          {'name': 'rain', 'icon': CupertinoIcons.cloud_rain},
          {'name': 'forest', 'icon': CupertinoIcons.tree},
          {'name': 'cafe', 'icon': CupertinoIcons.house},
          {'name': 'white_noise', 'icon': CupertinoIcons.waveform_path_ecg},
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
                onTap: () {
                  setState(() => _selectedSound = sound['name'] as String);
                  Navigator.pop(context);
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
          canPop: !(_isStrictMode && _isRunning),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_isStrictMode && _isRunning) {
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
                            _buildOptionRow(
                              CupertinoIcons.shield_fill,
                              const Color(0xFF34C759),
                              lang.translate('focus_timer.strict_mode'),
                              lang.translate('focus_timer.strict_desc'),
                              true,
                              value: _isStrictMode,
                              onChanged: (v) => setState(() => _isStrictMode = v),
                              onTap: () => _showFeatureInfo(
                                lang.translate('focus_timer.strict_mode'),
                                lang.translate('focus_timer.strict_mode_info'), // Need to add this to service
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
                              onChanged: (v) => setState(() => _isAntiDistract = v),
                              onTap: () => _showFeatureInfo(
                                lang.translate('focus_timer.anti_distract'),
                                lang.translate('focus_timer.anti_distract_info'), // Need to add this to service
                                CupertinoIcons.moon_zzz_fill,
                                const Color(0xFF5856D6),
                              ),
                            ),
                          ] else ...[
                            _buildOptionRow(
                              CupertinoIcons.square_grid_2x2,
                              const Color(0xFF34C759),
                              lang.translate('focus_timer.allowed_apps'),
                              lang.translate('focus_timer.allowed_desc').replaceAll('{count}', '3'),
                              false,
                              onTap: () => _showFeatureInfo(
                                lang.translate('focus_timer.allowed_apps'),
                                lang.translate('focus_timer.allowed_apps_info'), // Need to add this to service
                                CupertinoIcons.square_grid_2x2,
                                const Color(0xFF34C759),
                              ),
                            ),
                            Divider(color: Colors.grey.withOpacity(0.1), height: 1),
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
                  if (_isRunning || _isPaused) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _stopTimer,
                      child: Text(
                        lang.translate('focus_timer.stop') ?? "To'xtatish",
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
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (_selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759)).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(CupertinoIcons.plus, size: 14, color: _selectedMode == 0 ? Theme.of(context).primaryColor : const Color(0xFF34C759)),
                            onPressed: _showActivityEditor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
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
            _selectedActivityIndex = index;
            _selectedMinutes = minutes; // Update main timer
            _remainingSeconds = minutes * 60;
            _isPaused = false;
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                '${_activityProgress[activityKey] ?? 0} / $minutes ${lang.translate('focus_timer.min')}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: active ? Colors.white.withOpacity(0.8) : const Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
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

