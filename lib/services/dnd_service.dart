import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Anti-Chalg'itish (Do Not Disturb) boshqaruvi.
///
/// Foydalanuvchi taymerni boshlaganida — agar `_isAntiDistract` toggle yoqilgan
/// bo'lsa — DnD `PRIORITY` rejimiga o'tkaziladi (alarm va asosiy kontaktlar
/// chiqaveradi, qolgan bildirishnomalar jim turadi). Taymer to'xtaganda
/// avvalgi DnD holati qaytariladi.
///
/// Native bridge: `MainActivity.kt` → MethodChannel `focusguard/dnd`.
///
/// Permission: `ACCESS_NOTIFICATION_POLICY` — foydalanuvchi bir martalik
/// "Sukut rejimini boshqarish" ruxsatini Settings'da berishi kerak.
class DndService {
  DndService._();
  static final DndService instance = DndService._();

  static const _channel = MethodChannel('focusguard/dnd');

  // NotificationManager INTERRUPTION_FILTER constants:
  static const int filterAll = 1; // DnD off (normal)
  static const int filterPriority = 2; // Priority only
  static const int filterNone = 3; // All blocked (including alarms)
  static const int filterAlarms = 4; // Alarms only

  // Foydalanuvchini saqlab qolish uchun avvalgi DnD holatini saqlaymiz.
  static const _prevFilterKey = 'dnd_prev_filter';
  static const _activeKey = 'dnd_active_by_us'; // bizning ilova yoqdimi
  static const _toggleKey = 'anti_distract_enabled'; // toggle holati

  /// Foydalanuvchi DnD ruxsatini berganmi.
  Future<bool> isPermissionGranted() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('isPermissionGranted');
      return ok ?? false;
    } catch (e) {
      debugPrint('[DndService] isPermissionGranted error: $e');
      return false;
    }
  }

  /// Settings ekranini ochish — foydalanuvchi ruxsat berishi uchun.
  Future<void> openPermissionSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('openPermissionSettings');
    } catch (e) {
      debugPrint('[DndService] openPermissionSettings error: $e');
    }
  }

  /// Joriy DnD holatini olish (1=All, 2=Priority, 3=None, 4=Alarms).
  Future<int> _getCurrentFilter() async {
    try {
      final f = await _channel.invokeMethod<int>('getCurrentFilter');
      return f ?? filterAll;
    } catch (e) {
      debugPrint('[DndService] getCurrentFilter error: $e');
      return filterAll;
    }
  }

  Future<bool> _setFilter(int filter) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'setFilter',
        {'filter': filter},
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('[DndService] setFilter($filter) error: $e');
      return false;
    }
  }

  /// Taymer boshlanganda chaqiriladi — DnD'ni PRIORITY rejimiga o'tkazadi.
  /// Avvalgi holatni SharedPreferences'ga saqlaydi (taymer tugaganda qaytarish uchun).
  ///
  /// Returns: true agar muvaffaqiyatli yoqilgan bo'lsa.
  Future<bool> enableFocusMode() async {
    if (!await isPermissionGranted()) {
      debugPrint('[DndService] permission not granted — cannot enable');
      return false;
    }
    final prev = await _getCurrentFilter();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prevFilterKey, prev);
    await prefs.setBool(_activeKey, true);
    final ok = await _setFilter(filterPriority);
    debugPrint('[DndService] enabled DnD (prev=$prev, set=Priority, ok=$ok)');
    return ok;
  }

  /// Taymer to'xtaganda chaqiriladi — avvalgi DnD holatini qaytaradi.
  /// Faqat agar BIZ yoqgan bo'lsak ishlaydi (boshqa app yoqgan bo'lsa tegmaymiz).
  Future<void> disableFocusMode() async {
    final prefs = await SharedPreferences.getInstance();
    final activeByUs = prefs.getBool(_activeKey) ?? false;
    if (!activeByUs) {
      debugPrint('[DndService] not active by us, skipping restore');
      return;
    }
    if (!await isPermissionGranted()) {
      debugPrint('[DndService] permission revoked, cannot restore');
      await prefs.setBool(_activeKey, false);
      return;
    }
    final prev = prefs.getInt(_prevFilterKey) ?? filterAll;
    await _setFilter(prev);
    await prefs.setBool(_activeKey, false);
    await prefs.remove(_prevFilterKey);
    debugPrint('[DndService] restored DnD to $prev');
  }

  /// Toggle holatini saqlash — foydalanuvchi qayta ekran ochganda
  /// avvalgi tanlovi qaytadi.
  Future<void> setToggleEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_toggleKey, enabled);
  }

  Future<bool> isToggleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_toggleKey) ?? true; // default yoqiq
  }

  /// Stuck holat tuzatish — agar app crash bo'lib DnD yoqiq qolgan bo'lsa
  /// (`dnd_active_by_us == true`), lekin taymer ishlamayotgan bo'lsa, DnD'ni
  /// o'chirib avvalgi holatga qaytaramiz. main.dart'da app startida chaqiriladi.
  ///
  /// MUHIM: faqat `dnd_active_by_us` flagiga tegamiz. Toggle holati
  /// (`anti_distract_enabled`) tegilmaydi — foydalanuvchi tanlovi saqlanadi.
  Future<void> recoverIfStuck() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final activeByUs = prefs.getBool(_activeKey) ?? false;
      final timerRunning = prefs.getBool('timer_is_running') ?? false;
      if (activeByUs && !timerRunning) {
        debugPrint('[DndService] stuck DnD detected — restoring');
        await disableFocusMode();
      }
    } catch (e) {
      debugPrint('[DndService] recoverIfStuck error: $e');
    }
  }
}
