import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_usage/app_usage.dart';
import 'language_screen.dart';
import 'dashboard_screen.dart';
import 'permissions_screen.dart';
import '../services/cloud_sync_service.dart';
import '../services/plan_service.dart';
import '../services/timer_notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn)
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 3000), () async {
      if (!mounted) return;
      
      final User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Bulutdan tiklash (bir martalik) — uninstall/reinstall yoki yangi
        // qurilmada login bo'lganda Firestore'dagi history'ni lokal'ga
        // tortib oladi. Mavjud lokal yozuvlarning ustidan yozmaydi.
        // Fire-and-forget — UI'ni bloklamaymiz, dashboard'da chart 1-2
        // sekundda paydo bo'ladi.
        CloudSyncService.instance.autoRestoreOnFirstRun();
        // Plans ham — Firestore'dan tortib qayta sozlash.
        PlanService.instance.restoreFromFirestore();

        // Ruxsatlarni tekshirish (faqat passiv)
        bool hasPermissions = true;
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          bool overlayOk = await Permission.systemAlertWindow.isGranted;
          bool usageOk = false;
          try {
            // Shunchaki ruxsat holatini tekshirish
            DateTime now = DateTime.now();
            await AppUsage().getAppUsage(now.subtract(const Duration(seconds: 1)), now).timeout(const Duration(milliseconds: 500));
            usageOk = true;
          } catch (_) {
            usageOk = false;
          }
          
          hasPermissions = overlayOk && usageOk;
        }

        if (mounted) {
          // Ruxsatlar yetishmasa (overlay/usage) avval PermissionsScreen'ga
          // olib boramiz — bloklash bularsiz umuman ishlamaydi. Bu, ayniqsa,
          // qurilma fon xizmatini o'ldirgan yoki ruxsat qaytarib olingan
          // holatlarda foydalanuvchini to'g'ri yo'naltiradi.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => hasPermissions
                  ? const DashboardScreen()
                  : const PermissionsScreen(isFromOnboarding: true),
            ),
          );
        }
        // Ruxsat yetishmasa — ~30 daqiqadan keyin yumshoq eslatma
        // rejalashtiramiz ("Diqqatingizni jamlang..."). Ruxsat bo'lsa, ehtimol
        // ilgari rejalashtirilgan eslatmani bekor qilamiz.
        if (!hasPermissions) {
          TimerNotificationService().schedulePermissionNudge();
        } else {
          TimerNotificationService().cancelPermissionNudge();
        }
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LanguageScreen()));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF007AFF), // Beautiful deep blue background
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'FOCUS GUARD',
                      style: GoogleFonts.inter(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
