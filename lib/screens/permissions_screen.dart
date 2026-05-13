import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:app_usage/app_usage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_translation_service.dart';
import '../services/service_starter.dart';
import 'dashboard_screen.dart';

class PermissionsScreen extends StatefulWidget {
  final bool isFromOnboarding;
  const PermissionsScreen({super.key, this.isFromOnboarding = false});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  bool _isOverlayGranted = false;
  bool _isUsageGranted = false;
  bool _isNotificationsGranted = false;
  // Cheksiz batareya — Samsung va boshqa OEM'lar background service'ni
  // 2-3 soatdan keyin "uxlatib qo'yadi". Bu ruxsat shu xatti-harakatni
  // to'xtatadi.
  bool _isBatteryIgnored = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Darhol tekshirmasdan, oyna yuklanishini kutamiz
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _checkPermissions(isPassive: true);
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
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions({bool isPassive = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      setState(() => _isLoading = false);
      return;
    }

    bool overlay = await Permission.systemAlertWindow.isGranted;
    bool notifications = await Permission.notification.isGranted;
    bool battery = await Permission.ignoreBatteryOptimizations.isGranted;

    // Usage Access ruxsatini har doim haqiqiy API orqali tekshiramiz.
    // _checkUsagePermission() o'zi passive — hech qanday dialog yoki
    // settings ekranni triggerlamaydi, faqat AppUsage().getAppUsage()
    // chaqirib exception bormi yo'qmi tekshiradi. Shu sababli passive/
    // non-passive farqi keraksiz. Avval shunchaki cached `_isUsageGranted`
    // qaytarilardi, lekin bu screen yangidan ochilganda har doim default
    // `false` bo'lib qolardi va "Davom etish" tugmasi yana yonardi —
    // foydalanuvchi ruxsat bergan bo'lsa ham. SharedPreferences'ga ham
    // saqlaymiz — agar API bir oz sekin javob bersa, eski qiymat
    // ko'rinadi (flicker oldini olish uchun).
    bool usage = await _checkUsagePermission();

    if (mounted) {
      setState(() {
        _isOverlayGranted = overlay;
        _isUsageGranted = usage;
        _isNotificationsGranted = notifications;
        _isBatteryIgnored = battery;
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkUsagePermission() async {
    try {
      // Shunchaki tekshirish uchun qisqa vaqt oralig'ini olamiz.
      // Agar PACKAGE_USAGE_STATS berilmagan bo'lsa SecurityException
      // beradi va catch bloki false qaytaradi. Hech qanday UI/dialog
      // ochilmaydi — to'liq passive operatsiya.
      DateTime now = DateTime.now();
      await AppUsage().getAppUsage(now.subtract(const Duration(seconds: 1)), now);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _requestOverlay() async {
    await Permission.systemAlertWindow.request();
    await _checkPermissions();
  }

  Future<void> _requestUsage() async {
    try {
      await launchUrl(
        Uri.parse('intent:#Intent;action=android.settings.USAGE_ACCESS_SETTINGS;end'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      await AppSettings.openAppSettings(type: AppSettingsType.settings);
    }
  }

  Future<void> _requestNotifications() async {
    await Permission.notification.request();
    await _checkPermissions();
  }

  // Cheksiz batareya — Android'ning standart dialog'ini chiqaradi.
  // Foydalanuvchi "Allow" bossa, OEM agressiv battery saver service'ni
  // o'ldirmaydi. Samsung uchun bu eng muhim qadam — usiz 2-3 soatdan
  // keyin service uxlab qoladi va bloklash to'xtaydi.
  Future<void> _requestBatteryOptimization() async {
    await Permission.ignoreBatteryOptimizations.request();
    await _checkPermissions();
  }

  // Samsung qurilmalari uchun "Never sleeping apps" sahifasiga
  // to'g'ridan-to'g'ri olib boruvchi tugma. Standart ignoreBattery-
  // Optimizations Samsung'ning ichki "Sleeping apps" ro'yxatini hech
  // tegmaydi — alohida sozlash kerak.
  Future<void> _openSamsungSleepingApps() async {
    try {
      // Samsung Device Care → Battery → Background usage limits sahifasi.
      await launchUrl(
        Uri.parse('intent:#Intent;'
            'action=com.samsung.android.sm.ACTION_BATTERY_USAGE;'
            'end'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Agar Samsung intent ishlamasa — odatdagi Battery sahifasi.
      try {
        await launchUrl(
          Uri.parse('intent:#Intent;'
              'action=android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS;'
              'end'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        await AppSettings.openAppSettings(type: AppSettingsType.settings);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppTranslationService();
    return ValueListenableBuilder<String>(
      valueListenable: lang.languageNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: widget.isFromOnboarding 
              ? null 
              : IconButton(
                  icon: const Icon(CupertinoIcons.back),
                  onPressed: () => Navigator.pop(context),
                ),
            title: Text(
              lang.translate('permissions.title'),
              style: lang.getFont(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  // Column endi 2 ta qismdan iborat:
                  //   1. Expanded(SingleChildScrollView(...)) — kartalar
                  //      ko'p bo'lganda foydalanuvchi pastga scroll qila
                  //      oladi. Kichik ekranlarda ham hamma narsa
                  //      ko'rinadi (Spacer bilan to'lib qolmaydi).
                  //   2. "Tayyor" tugmasi — pastda doim ko'rinib turadi,
                  //      scroll'dan tashqarida.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      const SizedBox(height: 10),
                      Text(
                        lang.translate('permissions.subtitle'),
                        style: lang.getFont(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),

                      _buildPermissionCard(
                        title: lang.translate('permissions.overlay.title'),
                        description: lang.translate('permissions.overlay.desc'),
                        icon: Icons.layers_rounded,
                        color: const Color(0xFF007AFF),
                        isGranted: _isOverlayGranted,
                        onTap: _requestOverlay,
                        lang: lang,
                      ),

                      const SizedBox(height: 16),

                      _buildPermissionCard(
                        title: lang.translate('permissions.usage.title'),
                        description: lang.translate('permissions.usage.desc'),
                        icon: Icons.pie_chart_rounded,
                        color: const Color(0xFFFF9500),
                        isGranted: _isUsageGranted,
                        onTap: _requestUsage,
                        lang: lang,
                      ),

                      const SizedBox(height: 16),

                      _buildPermissionCard(
                        title: lang.translate('permissions.notifications.title'),
                        description: lang.translate('permissions.notifications.desc'),
                        icon: Icons.notifications_active_rounded,
                        color: const Color(0xFFFF2D55),
                        isGranted: _isNotificationsGranted,
                        onTap: _requestNotifications,
                        lang: lang,
                      ),

                      const SizedBox(height: 16),

                      // Cheksiz batareya — 2-3 soatlik "uxlash" muammosini
                      // hal qiluvchi asosiy ruxsat. Samsung, Xiaomi, Huawei
                      // va boshqa OEM'lar background service'ni shu ruxsatsiz
                      // ishlatishni cheklaydi. Tugma 2 amal qiladi:
                      //   1) Standart Android "Allow battery optimization off"
                      //      dialog'ini chiqaradi.
                      //   2) Yana Samsung-specific deep link tugmachasi —
                      //      "Sleeping apps" ro'yxatiga qo'shilishi uchun.
                      _buildPermissionCard(
                        title: 'Cheksiz batareya',
                        description: 'Telefon ilovamizni 2-3 soatdan keyin '
                            'uxlatib qo\'ymasligi uchun. Samsung uchun zarur.',
                        icon: Icons.battery_charging_full_rounded,
                        color: const Color(0xFF34C759),
                        isGranted: _isBatteryIgnored,
                        onTap: _requestBatteryOptimization,
                        lang: lang,
                      ),

                      const SizedBox(height: 8),

                      // Samsung-specific "Sleeping apps" sahifasiga olib
                      // boruvchi qo'shimcha link. Faqat agar cheksiz
                      // batareya berilgan bo'lsa ko'rsatiladi — chunki
                      // siz avval standart ruxsatni olishingiz kerak,
                      // keyin Samsung'ning maxsus sozlamasi.
                      if (_isBatteryIgnored)
                        TextButton.icon(
                          onPressed: _openSamsungSleepingApps,
                          icon: const Icon(CupertinoIcons.moon_zzz,
                              size: 18, color: Color(0xFF8E8E93)),
                          label: Text(
                            'Samsung: "Sleeping apps" ro\'yxatidan olib tashlash',
                            style: lang.getFont(
                              fontSize: 12,
                              color: const Color(0xFF8E8E93),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      
                      Container(
                        width: double.infinity,
                        height: 56,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            if (_isOverlayGranted &&
                                _isUsageGranted &&
                                _isNotificationsGranted &&
                                _isBatteryIgnored)
                              BoxShadow(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: (_isOverlayGranted &&
                                  _isUsageGranted &&
                                  _isNotificationsGranted &&
                                  _isBatteryIgnored)
                              ? () async {
                                  // Ruxsatlar berildi — agar bloklangan ilovalar bo'lsa, xizmatni boshlaymiz
                                  await startBackgroundServiceIfReady();
                                  if (!mounted) return;
                                  if (widget.isFromOnboarding) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const DashboardScreen()),
                                    );
                                  } else {
                                    Navigator.pop(context);
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            disabledBackgroundColor: Theme.of(context).primaryColor.withOpacity(0.3),
                          ),
                          child: Text(
                            lang.translate('common.done'),
                            style: lang.getFont(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isGranted,
    required VoidCallback onTap,
    required AppTranslationService lang,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGranted ? const Color(0xFF34C759).withOpacity(0.5) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: lang.getFont(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: lang.getFont(
                    fontSize: 12,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: isGranted ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isGranted ? const Color(0xFF34C759).withOpacity(0.1) : Theme.of(context).primaryColor,
              foregroundColor: isGranted ? const Color(0xFF34C759) : Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isGranted ? lang.translate('common.save') : lang.translate('common.continue'),
              style: lang.getFont(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
