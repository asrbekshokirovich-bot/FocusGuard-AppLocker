import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import '../services/app_translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'focus_timer_screen.dart';
import 'block_list_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'permissions_screen.dart';

import '../services/language_service.dart';
import '../services/level_service.dart';
import '../services/crash_logger.dart';
import '../services/pending_results_processor.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_usage/app_usage.dart';
import 'package:flutter/services.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  // Eng oxirgi crash haqida ma'lumot. Banner shu o'zgaruvchi orqali
  // ko'rsatiladi — null bo'lsa banner umuman chiqmaydi.
  CrashRecord? _crashRecord;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      FocusTimerScreen(onNavigateToBlockList: () {
        setState(() {
          _currentIndex = 1; // Blocking tab
        });
      }),
      const BlockListScreen(),
      const StatsScreen(),
      const ProfileScreen(),
    ];

    // Foydalanuvchi statistikalarini tekshirish
    LevelService().ensureUserStatsInitialized();

    // PendingResultsProcessor — background service tomonidan yozilgan
    // XP va streak qiymatlarini qayta ishlash. App birinchi ochilganda
    // va keyin har resume bo'lganda chaqiriladi.
    PendingResultsProcessor.instance.processOnAppOpen();

    // Avvalgi crash mavjudligini tekshirish — agar overlay yoki
    // background service crash bo'lgan bo'lsa, banner ko'rsatamiz.
    _checkRecentCrash();

    // Bildirishnoma ruxsatini tekshirish
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bool redirected = await _checkCriticalPermissions();
      if (!redirected) {
        _checkNotificationPermission();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // App background'dan qaytganida ham pending'larni qayta ishlash —
    // foydalanuvchi telefonni o'chirib qo'yib, taymer fonida tugagan
    // bo'lsa, qaytganida XP/streak avtomatik yangilanadi.
    if (state == AppLifecycleState.resumed) {
      PendingResultsProcessor.instance.processOnAppOpen();
    }
  }

  Future<void> _checkRecentCrash() async {
    final crash = await CrashLogger.instance.getRecentCrash();
    if (mounted && crash != null && crash.isRecent) {
      setState(() => _crashRecord = crash);
    }
  }

  Future<void> _dismissCrashBanner() async {
    await CrashLogger.instance.clear();
    if (mounted) {
      setState(() => _crashRecord = null);
    }
  }

  void _copyCrashToClipboard() {
    final crash = _crashRecord;
    if (crash == null) return;
    final text =
        '[Focus Guard crash]\n'
        'Vaqt: ${crash.timestamp}\n'
        'Manba: ${crash.source}\n'
        'Sabab: ${crash.reason}'
        '${crash.stack != null ? '\n\nStack:\n${crash.stack}' : ''}';
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crash ma\'lumoti nusxa olindi. Bizga jo\'nating!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<bool> _checkCriticalPermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;

    // 1 soniya kutamiz
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return false;

    bool hasOverlay = await Permission.systemAlertWindow.isGranted;
    bool hasBattery = await Permission.ignoreBatteryOptimizations.isGranted;
    bool hasUsage = false;
    try {
      DateTime now = DateTime.now();
      await AppUsage().getAppUsage(now.subtract(const Duration(seconds: 1)), now);
      hasUsage = true;
    } catch (_) {
      hasUsage = false;
    }

    // Battery optimization muhim — ammo dashboard'ga kirishni butunlay
    // bloklamasligi kerak (chunki Samsung uni "Optimizatsiya" sahifasi
    // orqali avtomatik qaytarib qo'yishi mumkin). Faqat overlay/usage
    // bo'lmasa redirect qilamiz; battery yo'q bo'lsa banner ko'rsatamiz
    // (kelajakda) yoki ohirgi ehtimol — dashboard ichida xabar.
    if (!hasOverlay || !hasUsage || !hasBattery) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PermissionsScreen()),
        );
      }
      return true;
    }
    return false;
  }

  Future<void> _checkNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenPrompt = prefs.getBool('has_seen_notification_prompt') ?? false;
    
    if (hasSeenPrompt) return; // Allaqachon ko'rgan bo'lsa qaytib so'ramaymiz

    // 2 soniya kutamiz (UI yaxshilab yuklanishi uchun)
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final status = await Permission.notification.status;
    if (!status.isGranted) {
      _showNotificationDialog();
    }
  }

  void _showNotificationDialog() async {
    final lang = AppTranslationService();
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(CupertinoIcons.bell_fill, color: Color(0xFF007AFF)),
            const SizedBox(width: 12),
            Expanded(child: Text(lang.translate('permissions.notification_dialog_title') ?? 'Bildirishnomalar', style: lang.getFont(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          lang.translate('permissions.notification_dialog_desc') ?? 'Fokus vaqti tugashi va kunlik eslatmalarni o\'tkazib yubormaslik uchun bildirishnomalarga ruxsat bering.',
          style: lang.getFont(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setBool('has_seen_notification_prompt', true);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(lang.translate('profile.btn_understand') ?? 'Tushunarli', style: lang.getFont(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              await prefs.setBool('has_seen_notification_prompt', true);
              if (context.mounted) Navigator.pop(context);
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(lang.translate('profile.btn_redirect') ?? 'Sozlamalar', style: lang.getFont(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppTranslationService();
    return ValueListenableBuilder<String>(
      valueListenable: lang.languageNotifier,
      builder: (context, _, __) {
        return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          // Premium Header with XP and Streak (Only show on Focus tab)
          // Premium Header with XP and Streak (Only show on Focus tab)
          if (_currentIndex == 0)
          StreamBuilder<DocumentSnapshot>(
            stream: LevelService().getUserStatsStream(),
            builder: (context, snapshot) {
              int level = 1;
              int xp = 0;
              int streak = 0;
              String rankTitle = lang.translate('levels.rank_1') ?? 'Yangi Foydalanuvchi';
              double progress = 0.0;

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                level = data['level'] ?? 1;
                xp = data['xp'] ?? 0;
                streak = data['streak'] ?? 0;
                rankTitle = LevelService().getRankTitle(level, lang);
                
                // XP progress bar uchun (1000 XP per level)
                int currentLevelXP = xp % 1000;
                progress = currentLevelXP / 1000.0;
              }

              return Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 20,
                  bottom: 20,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Level & XP
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${lang.translate('levels.level')} $level',
                                style: lang.getFont(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF007AFF),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  rankTitle,
                                  style: lang.getFont(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // XP Progress Bar
                          Container(
                            height: 10,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress.clamp(0.05, 1.0), // Minimal ko'rinishi uchun 0.05
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF007AFF), Color(0xFF5AC8FA)],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Streak Counter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.fireFlameCurved,
                            color: Color(0xFFFF9500),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$streak ${lang.translate('levels.streak')}',
                            style: lang.getFont(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFF9500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Crash banner — faqat oxirgi 24 soat ichida crash bo'lsa.
          // Foydalanuvchi yopgandan keyin SharedPreferences'dan o'chadi.
          if (_crashRecord != null) _buildCrashBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: kIsWeb 
          ? Container(
              height: 90,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05), 
                    width: 0.5,
                  ),
                ),
              ),
              child: _buildBottomNav(lang),
            )
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05), 
                      width: 0.5,
                    ),
                  ),
                ),
                child: _buildBottomNav(lang),
              ),
            ),
      ),
        );
      },
    );
  }
  Widget _buildBottomNav(AppTranslationService lang) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      backgroundColor: Colors.transparent,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500),
      iconSize: 24,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.timer)),
          activeIcon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.timer_fill)),
          label: lang.translate('nav.focus'),
        ),
        BottomNavigationBarItem(
          icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.lock_shield)),
          activeIcon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.lock_shield_fill)),
          label: lang.translate('nav.block'),
        ),
        BottomNavigationBarItem(
          icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.chart_bar_alt_fill)),
          label: lang.translate('nav.stats'),
        ),
        BottomNavigationBarItem(
          icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.person_crop_circle)),
          activeIcon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.person_crop_circle_fill)),
          label: lang.translate('nav.profile'),
        ),
      ],
    );
  }

  // Crash banner — yorqin sariq fon, qisqa sabab, "Nusxa olish" va
  // "Yopish" tugmalari. Foydalanuvchi nusxa olganidan keyin bizga
  // (Telegram, email va h.k.) screenshot/text jo'natadi va biz crash
  // sababini aniq bilamiz, hatto USB orqali logcat o'qiy olmasak ham.
  Widget _buildCrashBanner() {
    final crash = _crashRecord!;
    // Reason juda uzun bo'lishi mumkin — birinchi 200 belgi banner uchun
    // yetarli, qolganini Clipboard'ga to'liq qo'yamiz.
    final shortReason = crash.reason.length > 200
        ? '${crash.reason.substring(0, 200)}…'
        : crash.reason;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC107), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                  color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Oxirgi marta ilova xato bilan to\'xtagan',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7C4A03),
                  ),
                ),
              ),
              IconButton(
                onPressed: _dismissCrashBanner,
                icon: const Icon(CupertinoIcons.xmark,
                    color: Color(0xFF7C4A03), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Manba: ${crash.source}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7C4A03),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            shortReason,
            style: GoogleFonts.robotoMono(
              fontSize: 11,
              color: const Color(0xFF7C4A03),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _copyCrashToClipboard,
                  icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 16),
                  label: Text(
                    'Nusxa olish va jo\'natish',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

