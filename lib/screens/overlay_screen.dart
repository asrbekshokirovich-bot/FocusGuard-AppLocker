import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

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

    // Material is needed for text rendering, but kept transparent so
    // ONLY the layers we control draw the background — no Scaffold,
    // no SafeArea, no implicit insets eating screen edges.
    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1 — frosted blur of whatever the user was looking at.
            // BackdropFilter blurs everything painted behind the overlay
            // window; combined with our patched FlutterView (no system
            // window padding) the blur reaches every edge of the screen.
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                width: screenW,
                height: screenH,
                // Slight dark wash so the white text stays readable on
                // top of bright wallpapers / app screenshots.
                color: Colors.black.withOpacity(0.55),
              ),
            ),
            // Layer 2 — the actual cover content (icon, texts, button).
            Center(
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
                  // Avval foydalanuvchini bloklangan ilovadan chiqaramiz
                  // (home ekranga olib boramiz). Bu ilovani background'ga
                  // tushiradi va Focus Guard'ning aniqlash sikli endi
                  // bloklangan paketni ko'rmaydi — overlay qayta
                  // chiqib ketmaydi.
                  //
                  // ACTION_MAIN + CATEGORY_HOME — Android'ning standart
                  // launcher chaqiruvi. FLAG_ACTIVITY_NEW_TASK overlay
                  // service kontekstidan startActivity ishlashi uchun
                  // shart.
                  try {
                    const intent = AndroidIntent(
                      action: 'action_main',
                      category: 'category_home',
                      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
                    );
                    await intent.launch();
                  } catch (_) {
                    // Intent ishlamasa ham overlayni yopib qo'yamiz.
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
          ],
        ),
      ),
    );
  }
}
