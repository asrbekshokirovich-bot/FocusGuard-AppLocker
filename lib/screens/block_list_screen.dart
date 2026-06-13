import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/app_translation_service.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:convert';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import '../services/background_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_usage/app_usage.dart';
import 'package:usage_stats/usage_stats.dart';
import 'permissions_screen.dart';
import 'schedule_screen.dart';

class BlockListScreen extends StatefulWidget {
  const BlockListScreen({super.key});

  @override
  State<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<BlockListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  List<dynamic> _appsList = [];
  bool _isLoading = true;

  // Sort holati: false = A-Z, true = Ko'p ishlatilgan/tavsiya
  bool _sortByUsage = false;
  // AppUsage dan olingan so'nggi 30 kunlik ishlatilish daqiqalari
  Map<String, int> _usageMinutes = {};

  final List<Map<String, dynamic>> _mockApps = [
    {'name': 'Instagram', 'icon': FontAwesomeIcons.instagram, 'color': const Color(0xFFE1306C), 'category': 'social', 'blocked': true},
    {'name': 'TikTok', 'icon': FontAwesomeIcons.tiktok, 'color': Colors.black, 'category': 'social', 'blocked': true},
    {'name': 'YouTube', 'icon': FontAwesomeIcons.youtube, 'color': const Color(0xFFFF0000), 'category': 'entertainment', 'blocked': false},
    {'name': 'Telegram', 'icon': FontAwesomeIcons.telegram, 'color': const Color(0xFF24A1DE), 'category': 'communication', 'blocked': false},
    {'name': 'WhatsApp', 'icon': FontAwesomeIcons.whatsapp, 'color': const Color(0xFF25D366), 'category': 'communication', 'blocked': false},
    {'name': 'PUBG Mobile', 'icon': FontAwesomeIcons.gamepad, 'color': const Color(0xFFFBC02D), 'category': 'games', 'blocked': true},
  ];

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> blockedPackages = prefs.getStringList('blocked_apps') ?? [];

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        // 1-qadam: Ikonkasiz tez yukla (darhol ro'yxat ko'rinadi)
        List<AppInfo> apps = await InstalledApps.getInstalledApps(
          excludeSystemApps: false, // Tizim ilovalarini ham ko'rsat
          withIcon: false,          // Avval ikonkasiz yukla - TEZROQ
        );

        if (!mounted) return;
        setState(() {
          _appsList = apps
              .where((app) => 
                  app.packageName != 'com.focusguard.app' &&
                  (app.name ?? '').isNotEmpty)
              .map((app) {
            return {
              'package': app.packageName,
              'name': app.name ?? app.packageName,
              'icon': null, // Hozircha null
              'color': const Color(0xFF007AFF),
              'category': 'social',
              'blocked': blockedPackages.contains(app.packageName),
              'isReal': true,
            };
          }).toList();
          _appsList.sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));
          _isLoading = false; // Ro'yxat darhol ko'rinadi
        });

        // 2-qadam: Ikonkalarni orqa fonda yukla
        _loadIconsInBackground(apps);

        // Fon da ishlatilish statistikasini yuklaymiz (sort uchun)
        _loadUsageData();

      } catch (e) {
        if (!mounted) return;
        setState(() {
          _appsList = List.from(_mockApps);
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _appsList = List.from(_mockApps);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadIconsInBackground(List<AppInfo> apps) async {
    SharedPreferences? prefs;
    Set<String> blockedSet = <String>{};
    try {
      prefs = await SharedPreferences.getInstance();
      blockedSet = (prefs.getStringList('blocked_apps') ?? []).toSet();
    } catch (_) {}

    for (final app in apps) {
      if (!mounted) return;
      // Faqat ro'yxatdagi ilovalar uchun icon yukla
      final idx = _appsList.indexWhere((a) => a['package'] == app.packageName);
      if (idx == -1) continue;

      try {
        final AppInfo? detailed = await InstalledApps.getAppInfo(app.packageName);
        if (detailed?.icon != null && mounted) {
          setState(() {
            _appsList[idx]['icon'] = detailed!.icon;
          });

          // Bloklangan ilovalar uchun ikonkani statistika ekraniga
          // saqlaymiz. Eski bloklangan ilovalar uchun ham bir martalik
          // backfill — keyin "Eng ko'p urinilgan" karta ularning real
          // ikonkasini ko'rsatadi.
          if (prefs != null && blockedSet.contains(app.packageName)) {
            try {
              await prefs.setString(
                'app_icon_${app.packageName}',
                base64Encode(detailed!.icon!),
              );
            } catch (_) {}
          }
        }
      } catch (_) {
        continue;
      }
      // Har ikonkadan keyin biroz kut - UI ni bloklamaslik uchun
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<bool> _checkNotificationPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    return await Permission.notification.isGranted;
  }

  Future<void> _handlePermissionSequence(Map<String, dynamic> app) async {
    bool overlayOk = await Permission.systemAlertWindow.isGranted;
    // Usage accessni bu yerda tekshirmaymiz (redirektni oldini olish uchun)

    if (!overlayOk) {
      // Agar ruxsatlar bo'lmasa, switchni qaytaramiz va oynani chiqaramiz
      _resetSwitch(app);
      _showPermissionPromptDialog();
      return;
    }

    // Hamma ruxsatlar bo'lsa xizmatni yoqish
    await _startBlockingService();
    if (!kIsWeb) {
      FlutterBackgroundService().invoke('updateBlockedApps');
    }
  }

  void _resetSwitch(Map<String, dynamic> app) {
    setState(() {
      app['blocked'] = false;
    });
  }

  /// Temir Intizom yoqilgan seans davomida foydalanuvchi bloklangan ilovani
  /// o'chirmoqchi bo'lsa, bu dialog chiqib tushuntirish beradi va amalni
  /// bekor qiladi. Toggle holati o'zgartirilmaydi.
  void _showStrictModeBlockedDialog() {
    final lang = AppTranslationService();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          lang.translate('block_list.strict_locked_title') ??
              '🛡️ Temir Intizom yoqilgan',
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            lang.translate('block_list.strict_locked_desc') ??
                'Seans tugaguncha bloklangan ilovalarni o\'chira olmaysiz. Irodangizni sinab ko\'ring va maqsadingizga sodiq qoling!',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(lang.translate('focus_timer.understood') ?? 'Tushunarli'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showPermissionPromptDialog() {
    final lang = AppTranslationService();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(lang.translate('profile.permission_dialog_title')),
        content: Text(lang.translate('profile.permission_dialog_desc')),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(lang.translate('profile.btn_redirect')),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PermissionsScreen(isFromOnboarding: false)),
              );
            },
          ),
          CupertinoDialogAction(
            child: Text(lang.translate('profile.btn_understand')),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _offerDisableNotifications(String packageName, String appName) async {
    if (!mounted) return;
    final lang = AppTranslationService();
    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(lang.translate('block_list.notify_offer.title').replaceAll('{app}', appName)),
        content: Text(lang.translate('block_list.notify_offer.content').replaceAll('{app}', appName)),
        actions: [
          CupertinoDialogAction(
            child: Text(lang.translate('block_list.notify_offer.no')),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              // Android da o'sha ilovaning bildirishnoma sozlamalariga o't
              try {
                final settingsUri = Uri(
                  scheme: 'android.settings',
                  path: 'APP_NOTIFICATION_SETTINGS',
                  queryParameters: {'android.provider.extra.APP_PACKAGE': packageName},
                );
                if (await canLaunchUrl(settingsUri)) {
                  await launchUrl(settingsUri, mode: LaunchMode.externalApplication);
                } else {
                  // Fallback: umumiy bildirishnoma sozlamalar
                  await AppSettings.openAppSettings(type: AppSettingsType.notification);
                }
              } catch (_) {
                await AppSettings.openAppSettings(type: AppSettingsType.notification);
              }
            },
            child: Text(lang.translate('block_list.notify_offer.yes')),
          ),
        ],
      ),
    );
  }

  Future<void> _startBlockingService() async {
    if (kIsWeb) return;
    
    try {
      // Faqat ruxsatlar bo'lsa xizmatni ishga tushiramiz
      bool usageOk = await _checkUsagePermission();
      bool overlayOk = await Permission.systemAlertWindow.isGranted;
      
      if (!usageOk || !overlayOk) {
        debugPrint('Service not started: Missing permissions');
        return;
      }

      await initializeBackgroundService();
      
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();
      
      if (!isRunning) {
        await service.startService();
      }
    } catch (e) {
      debugPrint('Service start error: $e');
    }
  }

  Widget _buildScheduleEntryCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScheduleScreen()),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF5856D6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(CupertinoIcons.moon_stars_fill,
                  color: Color(0xFF5856D6), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kengaytirilgan jadval',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 2),
                  Text('Ma\'lum vaqtda (masalan 23:00–07:00) avtomatik bloklash',
                      style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFF8E8E93),
                          height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), size: 18),
          ],
        ),
      ),
    );
  }

  // Ijtimoiy media + mashhur o'yin paketlari — tavsiya sortida tepada turadi.
  static const Set<String> _recommendCategory = {
    'com.instagram.android', 'com.google.android.youtube',
    'com.zhiliaoapp.musically', 'com.ss.android.ugc.trill',
    'org.telegram.messenger', 'com.facebook.katana',
    'com.snapchat.android', 'com.twitter.android',
    'com.tencent.ig', 'com.dts.freefireth', 'com.dts.freefiremax',
    'com.supercell.clashofclans', 'com.supercell.clashroyale',
    'com.supercell.brawlstars', 'com.mojang.minecraftpe', 'com.roblox.client',
    'com.activision.callofduty.shooter', 'com.miHoYo.GenshinImpact',
    'com.ea.gp.fifamobile', 'com.king.candycrushsaga', 'com.pubg.imobile',
  };

  Future<void> _loadUsageData() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final now = DateTime.now();
      final infos = await AppUsage()
          .getAppUsage(now.subtract(const Duration(days: 30)), now);
      final map = <String, int>{};
      for (final i in infos) {
        map[i.packageName] =
            (map[i.packageName] ?? 0) + i.usage.inMinutes;
      }
      if (mounted) setState(() => _usageMinutes = map);
    } catch (_) {}
  }

  List<dynamic> get _displayList {
    final query = _searchQuery.trim().toLowerCase();
    final base = query.isEmpty
        ? List<dynamic>.from(_appsList)
        : _appsList.where((app) {
            return (app as Map)['name']
                .toString()
                .toLowerCase()
                .contains(query);
          }).toList();

    if (_sortByUsage) {
      base.sort((a, b) {
        final aPkg = (a as Map)['package'] as String? ?? '';
        final bPkg = (b as Map)['package'] as String? ?? '';
        final aCat = _recommendCategory.contains(aPkg) ? 0 : 1;
        final bCat = _recommendCategory.contains(bPkg) ? 0 : 1;
        if (aCat != bCat) return aCat - bCat;
        final aMin = _usageMinutes[aPkg] ?? 0;
        final bMin = _usageMinutes[bPkg] ?? 0;
        return bMin - aMin;
      });
    }
    return base;
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
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 20, right: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  children: [
                    Text(
                      lang.translate('block_list.title'), 
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.8)
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 46,
                      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value),
                        style: GoogleFonts.inter(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: lang.translate('block_list.search_hint'),
                          hintStyle: GoogleFonts.inter(color: const Color(0xFF8E8E93), fontSize: 15),
                          prefixIcon: const Icon(CupertinoIcons.search, color: Color(0xFF8E8E93), size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  children: [
                    // Info Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.info_circle_fill, color: Color(0xFF007AFF), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              lang.translate('block_list.info_banner'),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    if (!_isLoading) _buildScheduleEntryCard(),
                    if (!_isLoading) const SizedBox(height: 16),

                    // Sort tugmalari
                    if (!_isLoading) _buildSortRow(),
                    if (!_isLoading) const SizedBox(height: 12),

                    // App List
                    if (_isLoading)
                      const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: CupertinoActivityIndicator()))
                    else if (_displayList.isEmpty)
                      _buildEmptyState(lang)
                    else
                      ...List.generate(
                        _displayList.length,
                        (index) => _buildAppTile(_displayList[index], lang),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortRow() {
    final primary = Theme.of(context).primaryColor;
    return Row(
      children: [
        _sortChip(
          label: 'A-Z',
          icon: CupertinoIcons.sort_down,
          active: !_sortByUsage,
          primary: primary,
          onTap: () => setState(() => _sortByUsage = false),
        ),
        const SizedBox(width: 8),
        _sortChip(
          label: 'Tavsiya',
          icon: CupertinoIcons.flame_fill,
          active: _sortByUsage,
          primary: primary,
          onTap: () {
            setState(() => _sortByUsage = true);
            if (_usageMinutes.isEmpty) _loadUsageData();
          },
        ),
      ],
    );
  }

  Widget _sortChip({
    required String label,
    required IconData icon,
    required bool active,
    required Color primary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? primary : primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppTranslationService lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.search, size: 60, color: const Color(0xFF8E8E93).withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(lang.translate('block_list.not_found'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF8E8E93))),
        ],
      ),
    );
  }

  Future<bool> _checkUsagePermission() async {
    try {
      final ok = await UsageStats.checkUsagePermission() ?? false;
      if (ok) return true;
    } catch (_) {}
    try {
      final now = DateTime.now();
      await AppUsage()
          .getAppUsage(now.subtract(const Duration(seconds: 1)), now)
          .timeout(const Duration(milliseconds: 2000));
      return true;
    } catch (_) {
      return false;
    }
  }

  Widget _buildAppTile(Map<String, dynamic> app, AppTranslationService lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: app['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: app['isReal'] == true && app['icon'] != null
                ? Image.memory(app['icon'] as Uint8List, width: 22, height: 22)
                : FaIcon(app['icon'], color: app['color'], size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app['name'], style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                Text(
                  app['isReal'] == true 
                    ? lang.translate('block_list.categories.other')
                    : lang.translate('block_list.categories.${app['category']}'), 
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8E8E93), fontWeight: FontWeight.w500)
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: app['blocked'],
            activeColor: Theme.of(context).primaryColor,
            onChanged: (val) async {
              // Temir Intizom himoyasi — agar seans davomida foydalanuvchi
              // bloklangan ilovani O'CHIRMOQCHI bo'lsa (val=false), ruxsat
              // bermaymiz va dialog ko'rsatamiz. Yangi ilova qo'shish
              // (val=true) cheklanmagan.
              if (!val && app['blocked'] == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.reload();
                final isRunning = prefs.getBool('timer_is_running') ?? false;
                final isPaused = prefs.getBool('timer_is_paused') ?? false;
                final isStrict = prefs.getBool('timer_is_strict') ?? false;
                // Temir Intizom yoqilganda — bloklangan ilovalarni
                // tugagunga (yoki to'xtatilgunga) qadar ochib bo'lmaydi.
                // Pauza paytida ham qulf saqlanadi — chunki taymer hali
                // bekor qilinmagan, foydalanuvchi davom etishi mumkin.
                if ((isRunning || isPaused) && isStrict) {
                  _showStrictModeBlockedDialog();
                  return;
                }
              }

              if (val && app['isReal'] == true) {
                // Avval ruxsatni tekshiramiz
                bool overlayOk = await Permission.systemAlertWindow.isGranted;
                if (!overlayOk) {
                  _showPermissionPromptDialog();
                  return; // Switchni surishga yo'l qo'ymaymiz
                }
              }

              setState(() {
                app['blocked'] = val;
              });

              if (app['isReal'] != true) return;

              // 1) Yangi ro'yxatni AVVAL diskda saqlaymiz.
              //    Aks holda quyidagi invoke 'updateBlockedApps' background
              //    isolate'ga yetib borganda u hali eski ro'yxatni o'qiydi
              //    va toggle off effektsiz qoladi yoki yangi ilova
              //    bloklanmaydi.
              final prefs = await SharedPreferences.getInstance();
              List<String> blockedPackages =
                  prefs.getStringList('blocked_apps') ?? [];

              if (val) {
                if (!blockedPackages.contains(app['package'])) {
                  blockedPackages.add(app['package']);
                }
              } else {
                blockedPackages.remove(app['package']);
              }

              await prefs.setStringList('blocked_apps', blockedPackages);

              // Ilova nomi va ikonkasi cache — Statistika "Eng ko'p urinilgan
              // ilovalar" ekrani package nomidan haqiqiy nom va ikonkasini
              // olib ko'rsatish uchun shu cache'larni o'qiydi.
              if (val && app['isReal'] == true) {
                try {
                  // 1. Ilova nomi cache (JSON map: package → name)
                  final cacheRaw = prefs.getString('app_name_cache');
                  final Map<String, dynamic> cache = cacheRaw != null
                      ? (jsonDecode(cacheRaw) as Map<String, dynamic>)
                      : <String, dynamic>{};
                  cache[app['package']] = app['name'];
                  await prefs.setString('app_name_cache', jsonEncode(cache));

                  // 2. Ilova ikonkasi cache (base64 encoded) — har bir
                  // package alohida kalit: `app_icon_<package>`
                  final iconBytes = app['icon'];
                  if (iconBytes is Uint8List) {
                    await prefs.setString(
                      'app_icon_${app['package']}',
                      base64Encode(iconBytes),
                    );
                  }
                } catch (_) {}
              }

              // 2) Endi xavfsiz: service prefs'dan yangilangan ro'yxatni oladi.
              if (val) {
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
                  await _handlePermissionSequence(app);
                }
              } else {
                if (!kIsWeb) {
                  FlutterBackgroundService().invoke('updateBlockedApps');
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
