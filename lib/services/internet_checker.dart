import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_translation_service.dart';

/// Internet aloqasini tekshirish va foydalanuvchiga dialog ko'rsatish
/// uchun yagona joy.
///
/// Bu klass faqat foydalanuvchi **internet talab qiluvchi tugmani**
/// bosganda chaqiriladi (masalan "Bulutga saqlash"). Menyularga oddiy
/// kirgan paytda tekshirilmaydi — bu UX qoidasi.
class InternetChecker {
  InternetChecker._();

  /// Hozir qurilmada internet ulanmasi bormi? (WiFi yoki mobile data)
  static Future<bool> isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      // connectivity_plus v6+ List<ConnectivityResult> qaytaradi.
      // None bo'lmasa kamida bitta ulanma bor (WiFi/mobile/ethernet/vpn).
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // Plugin xatolik bersa, "online" deb hisoblaymiz — Firebase
      // o'zi qayta urinib ko'radi va offline cache'ga tushadi.
      return true;
    }
  }

  /// Internet aloqasi o'zgarishlarini kuzatish stream'i.
  /// Cloud Sync Service shu stream'ga obuna bo'ladi va internet
  /// yondi degan signal kelganda silent sync boshlaydi.
  static Stream<bool> get onConnectivityChanged {
    return Connectivity()
        .onConnectivityChanged
        .map((results) => results.any((r) => r != ConnectivityResult.none));
  }

  /// Internet kerak bo'lgan amalni bajarish oldidan tekshiruv.
  /// Agar internet bo'lmasa — modal dialog ko'rsatadi va `false` qaytaradi.
  /// Internet bor bo'lsa — `true` qaytaradi va amalni davom ettirish mumkin.
  static Future<bool> ensureOnline(BuildContext context) async {
    if (await isOnline()) return true;
    if (!context.mounted) return false;
    await _showNoInternetDialog(context);
    return false;
  }

  static Future<void> _showNoInternetDialog(BuildContext context) async {
    final lang = AppTranslationService();
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.wifi_slash,
                color: Color(0xFFFF3B30),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              lang.translate('internet.no_internet_title') ??
                  'Internet aloqasi yo\'q',
              textAlign: TextAlign.center,
              style: lang.getFont(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lang.translate('internet.no_internet_desc') ??
                  'Bu amalni bajarish uchun internet ulanmasi kerak.',
              textAlign: TextAlign.center,
              style: lang.getFont(
                fontSize: 14,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                lang.translate('internet.understood') ?? 'Tushunarli',
                style: lang.getFont(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF007AFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
