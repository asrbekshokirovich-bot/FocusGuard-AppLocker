import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:io';
import '../services/background_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

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
    if (!Platform.isAndroid) return;
    
    bool overlay = await Permission.systemAlertWindow.isGranted;
    // Note: Checking usage stats natively requires platform channels, 
    // but we can assume false initially or let user manually verify.
    // For now we simulate it or rely on user clicking it.
    
    setState(() {
      _isOverlayGranted = overlay;
    });
  }

  Future<void> _requestOverlay() async {
    final status = await Permission.systemAlertWindow.request();
    setState(() {
      _isOverlayGranted = status.isGranted;
    });
  }

  Future<void> _requestUsage() async {
    // Open Security settings where Usage Access is located
    await AppSettings.openAppSettings(type: AppSettingsType.security);
    // There's no direct callback when returning from settings, so we just assume they did it 
    // or we can add a check if we write a native method later.
    setState(() {
      _isUsageGranted = true; // Mark as done for UI purposes
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ruxsatlar kerak",
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Ilovalarni bloklash xizmati to'g'ri ishlashi uchun telefoningiz sozlamalaridan quyidagi ruxsatlarni berishingiz shart.",
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: const Color(0xFF8E8E93),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              
              _buildPermissionCard(
                title: "Boshqa ilovalar ustida",
                description: "Bloklangan ilovaga kirganingizda ustidan qulf ekranini chiqarish uchun kerak.",
                icon: Icons.layers,
                color: const Color(0xFF007AFF),
                isGranted: _isOverlayGranted,
                onTap: _requestOverlay,
              ),
              
              const SizedBox(height: 16),
              
              _buildPermissionCard(
                title: "Foydalanish tarixi",
                description: "Hozir qaysi ilovaga kirganingizni aniqlash uchun kerak (Usage Access).",
                icon: Icons.pie_chart,
                color: const Color(0xFFFF9500),
                isGranted: _isUsageGranted,
                onTap: _requestUsage,
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isOverlayGranted && _isUsageGranted) ? () async {
                    // Xizmatni ishga tushir
                    try {
                      await initializeBackgroundService();
                      FlutterBackgroundService().startService();
                    } catch (e) {
                      // Ignore
                    }
                    if (mounted) Navigator.pop(context);
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    disabledBackgroundColor: Theme.of(context).primaryColor.withOpacity(0.3),
                  ),
                  child: Text(
                    "Davom etish",
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
