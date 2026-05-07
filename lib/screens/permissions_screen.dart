import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:app_usage/app_usage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_translation_service.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Darhol tekshirmasdan, oyna yuklanishini kutamiz
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _checkPermissions();
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

  Future<void> _checkPermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      setState(() => _isLoading = false);
      return;
    }
    
    bool overlay = await Permission.systemAlertWindow.isGranted;
    bool usage = await _checkUsagePermission();
    bool notifications = await Permission.notification.isGranted;
    
    if (mounted) {
      setState(() {
        _isOverlayGranted = overlay;
        _isUsageGranted = usage;
        _isNotificationsGranted = notifications;
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkUsagePermission() async {
    try {
      // Shunchaki tekshirish uchun qisqa vaqt oralig'ini olamiz
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
                      
                      const Spacer(),
                      
                      Container(
                        width: double.infinity,
                        height: 56,
                        margin: const EdgeInsets.only(bottom: 24),
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
                          onPressed: (_isOverlayGranted && _isUsageGranted && _isNotificationsGranted) ? () {
                            if (widget.isFromOnboarding) {
                              Navigator.pushReplacement(
                                context, 
                                MaterialPageRoute(builder: (context) => const DashboardScreen())
                              );
                            } else {
                              Navigator.pop(context);
                            }
                          } : null,
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
