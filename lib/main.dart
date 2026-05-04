import 'dart:ui';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/legal_screen.dart';
import 'screens/register_screen.dart';
import 'screens/language_screen.dart';

import 'services/language_service.dart';
import 'services/theme_service.dart';
import 'services/background_service.dart';
import 'screens/overlay_screen.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayScreen(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageService().init();
  await ThemeService().init();
  
  try {
    await initializeBackgroundService();
  } catch (e) {
    // Service might fail to start if permissions are missing
  }

  runApp(
    DevicePreview(
      enabled: false,
      builder: (context) => const FocusGuardApp(),
    ),
  );
}

class FocusGuardApp extends StatelessWidget {
  const FocusGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService().themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return ValueListenableBuilder<Color>(
          valueListenable: ThemeService().accentColorNotifier,
          builder: (_, Color accentColor, __) {
            return ValueListenableBuilder<String>(
              valueListenable: LanguageService().languageNotifier,
              builder: (_, String langCode, __) {
                return MaterialApp(
                  scrollBehavior: const MyCustomScrollBehavior(),
                  locale: DevicePreview.locale(context),
                  builder: DevicePreview.appBuilder,
                  navigatorKey: navigatorKey,
                  title: 'FocusGuard',
                  debugShowCheckedModeBanner: false,
                  theme: ThemeData(
                    brightness: Brightness.light,
                    primaryColor: accentColor,
                    scaffoldBackgroundColor: const Color(0xFFF2F2F7),
                    colorScheme: ColorScheme.light(
                      primary: accentColor,
                      surface: Colors.white,
                      onSurface: const Color(0xFF1C1C1E),
                    ),
                    textTheme: langCode == 'ko' 
                        ? GoogleFonts.notoSansKrTextTheme(ThemeData.light().textTheme)
                        : GoogleFonts.interTextTheme(ThemeData.light().textTheme),
                    fontFamilyFallback: const ['Noto Sans KR', 'Malgun Gothic', 'Dotum', 'Apple SD Gothic Neo', 'sans-serif'],
                    appBarTheme: AppBarTheme(
                      backgroundColor: const Color(0xBFF2F2F7),
                      elevation: 0,
                      toolbarHeight: 60,
                      centerTitle: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                      ),
                      titleTextStyle: langCode == 'ko'
                        ? GoogleFonts.notoSansKr(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          )
                        : GoogleFonts.inter(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                      iconTheme: IconThemeData(color: accentColor),
                    ),
                  ),
                  darkTheme: ThemeData(
                    brightness: Brightness.dark,
                    primaryColor: accentColor,
                    scaffoldBackgroundColor: const Color(0xFF0F0F12),
                    colorScheme: ColorScheme.dark(
                      primary: accentColor,
                      surface: const Color(0xFF252529),
                      onSurface: Colors.white,
                    ),
                    textTheme: langCode == 'ko'
                        ? GoogleFonts.notoSansKrTextTheme(ThemeData.dark().textTheme)
                        : GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
                    fontFamilyFallback: const ['Noto Sans KR', 'Malgun Gothic', 'Dotum', 'Apple SD Gothic Neo', 'sans-serif'],
                    appBarTheme: AppBarTheme(
                      backgroundColor: const Color(0xCC0F0F12),
                      elevation: 0,
                      toolbarHeight: 60,
                      centerTitle: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                      ),
                      titleTextStyle: langCode == 'ko'
                        ? GoogleFonts.notoSansKr(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          )
                        : GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                      iconTheme: IconThemeData(color: accentColor),
                    ),
                  ),
                  themeMode: currentMode,
                  home: const SplashScreen(),
                );
              },
            );
          },
        );
      },
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  const MyCustomScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}
