import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_translation_service.dart';

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  // Alarm rejimi: timer tugagan → to'liq ekran dismiss UI.
  // Bloklash rejimi: foydalanuvchi bloklangan ilovani ochgan → qulf ekran.
  bool _isAlarmMode = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: const [],
    );
    // SharedPreferences'dan timer_alarm_active flagini tekshiramiz.
    // Agar true bo'lsa — alarm dismiss UI ko'rsatamiz.
    SharedPreferences.getInstance().then((prefs) {
      final alarmActive = prefs.getBool('timer_alarm_active') ?? false;
      if (alarmActive && mounted) {
        setState(() => _isAlarmMode = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQueryData.fromView(WidgetsBinding.instance.window);
    final screenW = mq.size.width;
    final screenH = mq.size.height +
        mq.padding.top +
        mq.padding.bottom +
        mq.viewPadding.top +
        mq.viewPadding.bottom;

    return _isAlarmMode
        ? _buildAlarmUI(screenW, screenH)
        : _buildBlockingUI(screenW, screenH);
  }

  // ─── ALARM DISMISS UI ────────────────────────────────────────────────────
  Widget _buildAlarmUI(double screenW, double screenH) {
    final lang = AppTranslationService();
    final title = lang.translate('alarm.overlay_title');
    final body = lang.translate('alarm.overlay_body');
    final btnLabel = lang.translate('alarm.overlay_btn');

    return Material(
      color: const Color(0xFF0A0A0F),
      child: SizedBox.expand(
        child: Container(
          width: screenW,
          height: screenH,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animatsiya o'rniga katta ikonka
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1C1C2E),
                  border: Border.all(
                    color: const Color(0xFF007AFF).withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Text('⏰', style: TextStyle(fontSize: 56)),
                ),
              ),
              const SizedBox(height: 36),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white60,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 56),
              // Dismiss tugmasi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // 1. Background service'ga ringtoni o'chirish signali
                      try {
                        FlutterBackgroundService().invoke('stopAlarm');
                      } catch (_) {}
                      // 2. Overlay yopiladi
                      await FlutterOverlayWindow.closeOverlay();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: Text(
                      btnLabel,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── APP BLOCKING UI (o'zgarishsiz) ──────────────────────────────────────
  Widget _buildBlockingUI(double screenW, double screenH) {
    final lang = AppTranslationService();
    final blockedTitle =
        lang.translate('overlay.blocked_title');
    final blockedMessage = lang.translate('overlay.blocked_message');
    final backLabel = lang.translate('overlay.back_button');

    return Material(
      color: Colors.black,
      child: SizedBox.expand(
        child: Container(
          width: screenW,
          height: screenH,
          color: Colors.black,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.lock_shield_fill,
                  color: Color(0xFF007AFF), size: 100),
              const SizedBox(height: 30),
              Text(
                blockedTitle,
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  blockedMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () async {
                  try {
                    FlutterBackgroundService().invoke('overlayClosedByUser');
                  } catch (_) {}
                  try {
                    const channel = MethodChannel('x-slayer/overlay');
                    await channel.invokeMethod('goHome');
                  } catch (_) {}
                  await FlutterOverlayWindow.closeOverlay();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  backLabel,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
