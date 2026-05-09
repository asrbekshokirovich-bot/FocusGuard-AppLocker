import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  @override
  void initState() {
    super.initState();
    // Make the system status bar and nav bar match the overlay so the
    // dark cover visually extends edge-to-edge.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    // Hide system bars where the OEM allows it (immersive sticky lets
    // them peek when the user swipes from the edge).
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Compute the absolute device size so the cover paints over every
    // pixel even if the overlay window's reported logical size excludes
    // system bar insets on this device.
    final mq = MediaQueryData.fromView(WidgetsBinding.instance.window);
    final screenW = mq.size.width;
    final screenH = mq.size.height +
        mq.padding.top +
        mq.padding.bottom +
        mq.viewPadding.top +
        mq.viewPadding.bottom;

    // Solid black Material covers the entire surface — no transparency,
    // no blur layer, no Scaffold/SafeArea so nothing eats screen edges.
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
                "Ilova Bloklangan",
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
                  "Siz bu ilovani Focus Guard ilovasi orqali vaqtinchalik bloklagansiz. Diqqatingizni maqsadlaringizga qarating!",
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
                  // Background isolate'ga "foydalanuvchi tugmani bosdi"
                  // deb xabar beramiz — u keyingi 5 soniya overlayni
                  // qayta ko'rsatmaydi, home intent ishga tushishi va
                  // foydalanuvchi launcher'ga chiqishi uchun fursat
                  // berishi kerak. Aks holda detection bizdan oldin
                  // ishlab overlay'ni darhol qaytadan ochib yuboradi.
                  try {
                    FlutterBackgroundService().invoke('overlayClosedByUser');
                  } catch (_) {}

                  // Foydalanuvchini bloklangan ilovadan chiqaramiz
                  // (home ekranga). Native Java tomondan HOME intent
                  // chaqiramiz — bu yondashuv plugin registration
                  // muammolaridan butunlay xalos: OverlayService.java
                  // 'goHome' methodini qabul qilib, to'g'ridan-to'g'ri
                  // getApplicationContext().startActivity(homeIntent)
                  // chaqiradi. android_intent_plus paketiga ehtiyoj
                  // qolmaydi.
                  try {
                    const channel = MethodChannel('x-slayer/overlay');
                    await channel.invokeMethod('goHome');
                  } catch (_) {
                    // Native goHome ishlamasa ham overlayni yopamiz.
                  }
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
                  "Orqaga qaytish",
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
