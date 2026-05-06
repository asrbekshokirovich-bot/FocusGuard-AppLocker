import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:app_usage/app_usage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/language_service.dart';
import '../services/background_service.dart';
import 'dashboard_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  bool _isOverlayGranted = false;
  bool _isUsageGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
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

  Future<void> _checkPermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    
    bool overlay = await Permission.systemAlertWindow.isGranted;
    bool usage = await _checkUsagePermission();
    
    if (mounted) {
      setState(() {
        _isOverlayGranted = overlay;
        _isUsageGranted = usage;
      });
    }
  }

  Future<bool> _checkUsagePermission() async {
    try {
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

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                lang.translate('permissions.title'),
                style: LanguageService.getFont(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                lang.translate('permissions.subtitle'),
                style: LanguageService.getFont(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              
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
              
              const Spacer(),
              
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    if (_isOverlayGranted && _isUsageGranted)
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: (_isOverlayGranted && _isUsageGranted) ? () {
                    Navigator.pushReplacement(
                      context, 
                      MaterialPageRoute(builder: (context) => const DashboardScreen())
                    );
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    disabledBackgroundColor: Theme.of(context).primaryColor.withOpacity(0.3),
                  ),
                  child: Text(
                    lang.translate('common.continue'),
                    style: LanguageService.getFont(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isGranted,
    required VoidCallback onTap,
    required LanguageService lang,
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
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
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
              isGranted ? "Yoqilgan" : "Ruxsat",
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
