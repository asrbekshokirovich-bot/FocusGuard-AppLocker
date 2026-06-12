import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// OEM (qurilma ishlab chiqaruvchi) ga bog'liq sozlamalar uchun ko'prik.
///
/// Xiaomi/Oppo/Vivo/Huawei kabi qurilmalar background service'ni
/// agressiv "uxlatib qo'yadi" — natijada bloklash 5-10 daqiqada
/// to'xtaydi. Yagona ishonchli yechim — foydalanuvchini OEM'ning
/// "Autostart / Avtoishga tushish" sahifasiga olib borib, ilovani
/// qo'lda yoqishini so'rash. Bu funksiyani hech bir ilova kod bilan
/// avtomatik bajara olmaydi (OS himoyasi), faqat yo'naltira oladi.
class DeviceOemService {
  DeviceOemService._();
  static final DeviceOemService instance = DeviceOemService._();

  static const MethodChannel _channel = MethodChannel('focusguard/device');

  String? _cachedManufacturer;

  /// Brend nomi kichik harflarda (masalan "xiaomi", "samsung", "oppo").
  /// Web yoki xato holatida bo'sh satr qaytadi.
  Future<String> manufacturer() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return '';
    if (_cachedManufacturer != null) return _cachedManufacturer!;
    try {
      _cachedManufacturer =
          (await _channel.invokeMethod<String>('getManufacturer')) ?? '';
    } catch (_) {
      _cachedManufacturer = '';
    }
    return _cachedManufacturer!;
  }

  /// Bu qurilmada autostart sozlamasi mavjudmi (Xiaomi/Oppo/Vivo/...)?
  /// Samsung va toza Android'da odatda yo'q — false qaytadi.
  Future<bool> isAutoStartSupported() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return (await _channel.invokeMethod<bool>('isAutoStartSupported')) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// OEM autostart sahifasini ochadi. Topilmasa false qaytadi.
  Future<bool> openAutoStartSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return (await _channel.invokeMethod<bool>('openAutoStartSettings')) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Agressiv OEM (Xiaomi/Oppo/Vivo/Huawei/Realme/iQOO va h.k.)mi?
  /// Bu brendlarda batareya + autostart sozlamalari kritik.
  Future<bool> isAggressiveOem() async {
    final m = await manufacturer();
    const aggressive = [
      'xiaomi',
      'redmi',
      'poco',
      'oppo',
      'vivo',
      'iqoo',
      'huawei',
      'honor',
      'realme',
      'oneplus',
      'meizu',
      'asus',
      'letv',
    ];
    return aggressive.any((b) => m.contains(b));
  }
}
