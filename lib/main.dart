import 'dart:ui';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/legal_screen.dart';
import 'screens/register_screen.dart';
import 'screens/language_screen.dart';
import 'screens/overlay_screen.dart';
import 'services/streak_reminder_service.dart';
import 'services/timer_notification_service.dart';

import 'services/theme_service.dart';
import 'services/background_service.dart';
import 'services/service_starter.dart';
import 'services/app_translation_service.dart';
import 'services/language_service.dart';
import 'services/crash_logger.dart';
import 'services/cloud_sync_service.dart';
import 'services/level_service.dart';
import 'services/daily_reset_service.dart';
import 'services/plan_service.dart';
import 'services/dnd_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global xato tutuvchilari — har qanday uncaught exception yoki
  // platform xatosi diskka (SharedPreferences) yoziladi. Keyingi
  // safar ilova ochilganda dashboard banner ko'rsatadi, foydalanuvchi
  // screenshot olib bizga jo'natadi. Bu ayniqsa boshqa Samsung
  // qurilmalarda (masalan A52) qanday crash bo'lganini bilish uchun
  // muhim — logcat'ga ulanmasdan diagnostika qila olamiz.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    CrashLogger.instance.recordError(
      details.exception,
      details.stack,
      source: 'FlutterError',
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    CrashLogger.instance.recordError(
      error,
      stack,
      source: 'PlatformDispatcher',
    );
    return true;
  };

  // Firebase initialization
  try {
    await Firebase.initializeApp();
    // Firestore oflayn rejimini yoqish
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  
  await AppTranslationService().init();
  await LanguageService().init();
  await ThemeService().init();

  // Kunlik reset — agar bugun yangi kun bo'lsa, kechagi ma'lumotni
  // history'ga yozamiz va bugungi counter'larni 0 ga tushiramiz. Background
  // service uxlab qolgan bo'lsa ham bu yerda darrov bajariladi.
  await DailyResetService.instance.checkAndResetIfNewDay();

  // Fon xizmatini ishga tushirish
  await initializeBackgroundService();
  // Agar barcha ruxsatlar va bloklangan ilovalar bo'lsa, xizmatni darhol boshlaymiz
  await startBackgroundServiceIfReady();
  
  // Streak eslatmasini faollashtirish (Har kuni 11:25 da)
  StreakReminderService().scheduleDailyReminder(hour: 11, minute: 25);

  // Kunlik yakun notifikatsiyasini AlarmManager orqali rejalashtirish
  // (Har kuni 23:55 da, service o'lik bo'lsa ham kafolatlangan).
  TimerNotificationService().scheduleDailySummary();

  // Cloud Sync xizmatini ishga tushirish — internet o'zgarishini
  // kuzatadi va auto rejimda fon'da silent sync qiladi. Foydalanuvchi
  // hech narsa sezmaydi.
  await CloudSyncService.instance.init();

  // Eski daraja formulasidan yangi threshold tizimiga bir martalik
  // migratsiya. Login bo'lmagan bo'lsa metod o'zi ichida hech narsa
  // qilmaydi. Foydalanuvchini bloklamaslik uchun fonida ishlatamiz.
  LevelService().migrateLevelIfNeeded();

  // Rejalar uchun scheduled notif'larni qayta sozlash. Android reboot
  // yoki ilova yangilashdan keyin alarm'lar tozalanadi — bu yerda
  // barcha kelajakdagi rejalar qaytadan AlarmManager'ga qo'yiladi.
  PlanService.instance.rescheduleAllPlans();

  // Stuck DnD'ni tuzatish — agar oldingi seans crash bilan tugab DnD
  // yoqiq qolgan bo'lsa, app ochilganda darrov avvalgi holatga qaytaramiz.
  // Toggle holati tegilmaydi (foydalanuvchi tanlovi saqlanadi).
  // AWAIT — UI ochilgunga qadar tugashi kerak (DnD jonsiz tursin).
  await DndService.instance.recoverIfStuck();

  runApp(
    DevicePreview(
      enabled: false,
      builder: (context) => const FocusGuardApp(),
    ),
  );
}

class FocusGuardApp extends StatefulWidget {
  const FocusGuardApp({super.key});

  @override
  State<FocusGuardApp> createState() => _FocusGuardAppState();
}

class _FocusGuardAppState extends State<FocusGuardApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ilova ochilganda foreground flag'ini yoqamiz.
    SharedPreferences.getInstance()
        .then((p) => p.setBool('app_in_foreground', true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App qayta foreground'ga kelganda kun resetini darrov tekshiramiz.
      // Foydalanuvchi telefon ekranini yarim tunda yopib qo'yib, ertaga
      // ochsa — kechagi 4 daq ko'rinmasdan, 0d / 4d ko'rinishi uchun.
      DailyResetService.instance.checkAndResetIfNewDay();
      // OEM (Xiaomi/Oppo/Vivo...) fon xizmatini o'ldirgan bo'lishi mumkin.
      // App ochilganda — agar bloklangan ilovalar + ruxsatlar bo'lsa —
      // xizmatni jimgina qayta tiklaymiz. isRunning() tekshiriladi, shuning
      // uchun ortiqcha start bo'lmaydi.
      startBackgroundServiceIfReady();
    }
    SharedPreferences.getInstance().then((p) {
      if (state == AppLifecycleState.resumed) {
        p.setBool('app_in_foreground', true);
      } else if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.detached) {
        p.setBool('app_in_foreground', false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService().themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return ValueListenableBuilder<Color>(
          valueListenable: ThemeService().accentColorNotifier,
          builder: (_, Color accentColor, __) {
            return ValueListenableBuilder<String>(
              valueListenable: AppTranslationService().languageNotifier,
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

// Overlay oynasi uchun alohida kirish nuqtasi.
//
// Bu funksiya flutter_overlay_window paketi tomonidan yangi Flutter
// engine'da ishga tushiriladi. Standart bindings hali ulanmagan,
// shuning uchun avval ularni qo'lda yoqamiz va Dart-tomon plugin
// reyestrini ham ishga tushiramiz — aks holda android_intent_plus
// (home intent uchun) va flutter_background_service (asosiy isolate
// bilan aloqa uchun) overlay ichida MissingPluginException beradi.
@pragma("vm:entry-point")
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  // Overlay alohida Dart isolate'da ishlaydi — AppTranslationService
  // singleton'i bu yerda alohida nusxa. Foydalanuvchi tanlagan tilni
  // SharedPreferences'dan o'qib chiqamiz, aks holda til 'uz' default
  // bo'lib qoladi va overlay matni har doim o'zbekcha bo'lardi.
  try {
    await AppTranslationService().init();
  } catch (_) {}
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayScreen(),
  ));
}
