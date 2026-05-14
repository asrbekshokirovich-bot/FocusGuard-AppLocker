import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tabiat ovozlari servisi — Yengil Fokus rejimida loop tarzda chaladi.
///
/// Foydalanuvchi tanlagan ovoz `selected_sound` SharedPreferences kalitida
/// saqlanadi (rain/forest/cafe/white_noise/none). Yangi seans boshlanganda
/// `play()` chaqiriladi va seans tugaganda yoki to'xtatilganda `stop()`.
///
/// MP3 fayllar `assets/sounds/` papkasida. Fayl topilmasa silently fail —
/// ilova crash bo'lmaydi. README.md kerak fayllar ro'yxati uchun.
class SoundscapeService {
  SoundscapeService._();
  static final SoundscapeService instance = SoundscapeService._();

  final AudioPlayer _player = AudioPlayer();
  String? _currentSound;

  static const String _kSelectedSound = 'selected_sound';

  /// Tanlangan ovozni SharedPreferences'dan o'qish. Default — 'none'.
  Future<String> getSelectedSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSelectedSound) ?? 'none';
  }

  /// Foydalanuvchi tanloviga saqlash. Agar seans hozir ishlayotgan bo'lsa,
  /// ovoz darrov almashtiriladi.
  Future<void> setSelectedSound(String sound) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedSound, sound);
    // Agar hozir bir ovoz chalinayotgan bo'lsa — yangisiga almashtiramiz
    if (_currentSound != null) {
      await play(sound);
    }
  }

  /// Tanlangan ovozni loop tarzda chalish. `none` — to'xtatadi.
  /// Foydalanuvchi seansni boshlaganida shu chaqiriladi.
  Future<void> play(String sound) async {
    try {
      if (sound == 'none' || sound.isEmpty) {
        await stop();
        return;
      }
      // Allaqachon shu ovoz chalinayotgan bo'lsa — qayta boshlamaymiz
      if (_currentSound == sound) return;

      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(0.6); // moderate, foreground sound
      await _player.play(AssetSource('sounds/$sound.mp3'));
      _currentSound = sound;
      debugPrint('[Soundscape] playing $sound');
    } catch (e) {
      // Fayl topilmasa yoki audio session muammosi bo'lsa — sukunatda.
      // Foydalanuvchi `Hech qanday` deb qo'yganga teng tajriba oladi.
      debugPrint('[Soundscape] play failed for $sound: $e');
      _currentSound = null;
    }
  }

  /// Ovozni to'xtatish — seans tugaganda yoki to'xtatilganda chaqiriladi.
  Future<void> stop() async {
    try {
      await _player.stop();
      _currentSound = null;
      debugPrint('[Soundscape] stopped');
    } catch (_) {}
  }

  /// App yopilganda resource'ni bo'shatish.
  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }

  /// Hozir biror ovoz chalinayotganmi?
  bool get isPlaying => _currentSound != null;

  /// Hozirgi ovoz nomi (yoki null).
  String? get currentSound => _currentSound;
}
