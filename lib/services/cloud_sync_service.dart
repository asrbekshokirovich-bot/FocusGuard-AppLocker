import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'focus_history_service.dart';
import 'internet_checker.dart';

/// Cloud Sync — offline-first arxitektura.
///
/// **Asosiy g'oya:** SharedPreferences (lokal) — yagona haqiqiy manba.
/// Firebase Firestore — backup. Foydalanuvchi har qanday amal qilsa,
/// avval lokal yoziladi (instant), keyin orqada Firestore'ga sync.
///
/// Internet yo'q bo'lsa — lokal yozuv saqlanadi va `pending_cloud_dates`
/// queue'ga qo'shiladi. Internet kelganda yoki ilova qayta ochilganda
/// queue avtomatik bo'shatiladi.
///
/// **FREE / PREMIUM ajratish:**
///   - FREE: streak/XP/level + activities ro'yxati + so'nggi 7 kun
///   - PREMIUM: hammasi + cheksiz tarix + activity breakdown + sessions
class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  StreamSubscription<bool>? _connectivitySub;
  bool _isSyncing = false;
  // Circuit breaker — ketma-ket permission/network xatolari sonini sanaydi.
  // 3 marta bo'lsa, sessiya davomida qayta urinmaymiz (foydalanuvchi
  // Firebase rules'ni sozlamagan yoki internet uzilgan bo'lishi mumkin).
  // Ilova qayta ochilganda counter resetlanadi.
  int _consecutiveErrors = 0;
  static const _maxConsecutiveErrors = 3;

  // SharedPreferences kalitlari:
  static const _kSyncMode = 'cloud_sync_mode'; // 'auto' yoki 'manual'
  static const _kLastSyncTime = 'cloud_last_sync_iso';
  static const _kPendingDates = 'cloud_pending_dates'; // List<String>

  // Backup progress stream — UI ko'rsatish uchun.
  final _progressController = StreamController<BackupProgress>.broadcast();
  Stream<BackupProgress> get progressStream => _progressController.stream;

  /// Ilova ochilganda chaqiriladi (main.dart). Connectivity listener
  /// boshlanadi: internet yondi → silent sync.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // Default rejim: avtomatik
    if (!prefs.containsKey(_kSyncMode)) {
      await prefs.setString(_kSyncMode, 'auto');
    }

    // Internet o'zgarishini kuzatamiz
    _connectivitySub?.cancel();
    _connectivitySub = InternetChecker.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        // Internet yondi → silent sync (auto rejimda bo'lsa)
        _maybeSilentSync();
      }
    });

    // Ilova ochilishi bilan ham bir marta tekshiramiz
    _maybeSilentSync();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _progressController.close();
  }

  /// Sync rejimini olish: 'auto' yoki 'manual'
  Future<String> getSyncMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSyncMode) ?? 'auto';
  }

  /// Sync rejimini saqlash
  Future<void> setSyncMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSyncMode, mode);
  }

  /// So'nggi sync vaqti (UI ko'rsatish uchun)
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_kLastSyncTime);
    if (iso == null) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  /// Bir kun history Firestore'ga yuborishni belgilash (queue).
  /// `background_service.dart` va `timer_notification_service.dart`
  /// shu metodni chaqiradi har recordDay()'dan keyin.
  Future<void> markDayPending(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final pending = prefs.getStringList(_kPendingDates) ?? <String>[];
    if (!pending.contains(dateKey)) {
      pending.add(dateKey);
      await prefs.setStringList(_kPendingDates, pending);
    }
  }

  /// Auto rejimda silent sync: internet bor + auto rejim + pending bor → sync.
  /// Foydalanuvchi sezmaydi, hech qanday UI ko'rsatilmaydi.
  Future<void> _maybeSilentSync() async {
    if (_isSyncing) return;
    try {
      final mode = await getSyncMode();
      if (mode != 'auto') return;
      if (_auth.currentUser == null) return;
      if (!await InternetChecker.isOnline()) return;
      await _syncPending(silent: true);
    } catch (e) {
      debugPrint('[CloudSync] silent sync failed: $e');
    }
  }

  /// Xatolik permission/network sababli yuz berganmi tekshirish.
  /// Bunday xatolar haqiqiy crash emas — Firebase rules sozlanmagan yoki
  /// internet uzilgan. Circuit breaker shularda tetiklanadi.
  bool _isExpectedError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('permission-denied') ||
        s.contains('permission_denied') ||
        s.contains('network') ||
        s.contains('unavailable') ||
        s.contains('socketexception');
  }

  /// Pending queue'dagi kunlarni Firestore'ga yuborish.
  /// `silent=true` bo'lsa progress stream'ga yozmaydi.
  Future<void> _syncPending({required bool silent}) async {
    if (_isSyncing) return;
    // Circuit breaker — sessiya davomida juda ko'p permission xato bo'lsa,
    // qayta urinmaymiz. Foydalanuvchi keyin Firebase rules sozlasa, ilova
    // qayta ochilganda sync ishlay boshlaydi.
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      debugPrint('[CloudSync] circuit breaker open, skipping');
      return;
    }
    _isSyncing = true;
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final pending =
          List<String>.from(prefs.getStringList(_kPendingDates) ?? <String>[]);
      if (pending.isEmpty) return;

      final isPremium = await _isPremiumUser(user.uid);
      final daysToKeep = isPremium ? 365 * 10 : 7; // Free: 7 kun, Premium: cheksiz

      final now = DateTime.now();
      final successful = <String>[];

      for (int i = 0; i < pending.length; i++) {
        final dateKey = pending[i];
        // Circuit breaker — qatorda ko'p xato bo'lsa to'xtatamiz
        if (_consecutiveErrors >= _maxConsecutiveErrors) {
          debugPrint('[CloudSync] too many errors, stopping batch');
          break;
        }
        try {
          final date = DateTime.parse(dateKey);
          final daysAgo = now.difference(date).inDays;
          if (daysAgo > daysToKeep) {
            // FREE'da 7 kundan eski yozuvlar yuborilmaydi
            successful.add(dateKey); // queue'dan olib tashlaymiz
            continue;
          }
          final record = await FocusHistoryService.instance.getDay(date);
          if (record == null) {
            successful.add(dateKey);
            continue;
          }
          final data = _recordToFirestore(record, isPremium);
          data['updatedAt'] = FieldValue.serverTimestamp();
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('history')
              .doc(dateKey)
              .set(data, SetOptions(merge: true));
          successful.add(dateKey);
          _consecutiveErrors = 0; // muvaffaqiyat — counter resetlanadi

          if (!silent) {
            _progressController.add(BackupProgress(
              current: i + 1,
              total: pending.length,
              currentItem: dateKey,
            ));
          }
        } catch (e) {
          if (_isExpectedError(e)) {
            _consecutiveErrors++;
            debugPrint(
                '[CloudSync] expected error ($_consecutiveErrors/$_maxConsecutiveErrors): $e');
          } else {
            debugPrint('[CloudSync] unexpected error syncing $dateKey: $e');
          }
          // Bu kun queue'da qoladi, keyingi marta urinib ko'ramiz
        }
      }

      // Faqat muvaffaqiyatli yuborilganlarni queue'dan olib tashlaymiz
      final remaining =
          pending.where((d) => !successful.contains(d)).toList();
      await prefs.setStringList(_kPendingDates, remaining);
      await prefs.setString(
          _kLastSyncTime, DateTime.now().toIso8601String());
    } catch (e) {
      // Eng tashqi catch — kutilmagan xato sodir bo'lsa ham sukunatda.
      // CrashLogger banner ko'rsatmaydi (filter `_shouldIgnore` ishlaydi).
      debugPrint('[CloudSync] _syncPending top-level error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Foydalanuvchi Premium ekanini Firestore'dan tekshirish.
  Future<bool> _isPremiumUser(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache));
      return doc.data()?['isPremium'] == true;
    } catch (_) {
      return false;
    }
  }

  /// DayRecord → Firestore document. FREE va PREMIUM uchun farqi:
  ///   - FREE: faqat seconds, goal, met
  ///   - PREMIUM: sessions, xp, activities ham qo'shiladi
  Map<String, dynamic> _recordToFirestore(DayRecord record, bool isPremium) {
    final data = <String, dynamic>{
      'seconds': record.seconds,
      'goal': record.goal,
      'met': record.met,
    };
    if (isPremium) {
      data['sessions'] = record.sessions;
      data['xp'] = record.xp;
      data['activities'] = record.activities;
    }
    return data;
  }

  /// Faoliyatlar ro'yxatini Firestore'ga yuborish.
  /// Foydalanuvchi activity qo'shsa/o'chirsa chaqiriladi.
  Future<void> syncActivitiesList() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      if (!await InternetChecker.isOnline()) return;
      final prefs = await SharedPreferences.getInstance();
      final activitiesJson = prefs.getStringList('custom_activities') ?? [];
      await _firestore.collection('users').doc(user.uid).set({
        'customActivities': activitiesJson,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[CloudSync] syncActivitiesList failed: $e');
    }
  }

  /// **MANUAL backup** — foydalanuvchi Cloud Backup ekranida tugmani
  /// bosganida chaqiriladi. Hamma history'ni qaytadan yuboradi (queue
  /// emas) — bu "to'liq backup" operatsiyasi.
  ///
  /// Manual operatsiyaga circuit breaker ta'sir qilmaydi — foydalanuvchi
  /// aniq bosgan, qayta urinishga arziydi. Boshida counter resetlanadi.
  Future<bool> uploadAllManual() async {
    if (_isSyncing) return false;
    final user = _auth.currentUser;
    if (user == null) return false;
    _consecutiveErrors = 0; // manual urinishda circuit breaker resetlanadi
    _isSyncing = true;
    try {
      final isPremium = await _isPremiumUser(user.uid);
      final daysToKeep = isPremium ? 365 * 10 : 7;

      // 1. Faoliyatlar ro'yxatini yuborish
      await syncActivitiesList();

      // 2. Tarixni yuborish: bugundan orqaga kerakli kunlar
      final now = DateTime.now();
      final dates = <DateTime>[];
      for (int i = 0; i < daysToKeep; i++) {
        dates.add(now.subtract(Duration(days: i)));
      }

      int processed = 0;
      for (final date in dates) {
        final record = await FocusHistoryService.instance.getDay(date);
        if (record == null) {
          processed++;
          _progressController.add(BackupProgress(
            current: processed,
            total: dates.length,
            currentItem: '',
          ));
          continue;
        }
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
        final data = _recordToFirestore(record, isPremium);
        data['updatedAt'] = FieldValue.serverTimestamp();
        try {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('history')
              .doc(dateKey)
              .set(data, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[CloudSync] manual upload $dateKey failed: $e');
        }
        processed++;
        _progressController.add(BackupProgress(
          current: processed,
          total: dates.length,
          currentItem: dateKey,
        ));
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kLastSyncTime, DateTime.now().toIso8601String());
      // Pending queue'ni tozalaymiz — barchasi yangidan yuborildi
      await prefs.setStringList(_kPendingDates, <String>[]);
      return true;
    } finally {
      _isSyncing = false;
    }
  }

  /// Login'da chaqiriladi — Firestore'dan history'ni lokal'ga yuklab oladi.
  /// Yangi telefonda yoki qayta o'rnatishdan keyin tarixni tiklaydi.
  Future<void> restoreFromCloud() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      if (!await InternetChecker.isOnline()) return;
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .get();
      final prefs = await SharedPreferences.getInstance();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Eski yozuv yo'q bo'lsa lokal'ga yozamiz; bo'lsa ham qaytadan
        // yozish xavfli emas (idempotent).
        try {
          final record = DayRecord(
            seconds: (data['seconds'] as num?)?.toInt() ?? 0,
            goal: (data['goal'] as num?)?.toInt() ?? 0,
            met: data['met'] as bool? ?? false,
            sessions: (data['sessions'] as num?)?.toInt() ?? 0,
            xp: (data['xp'] as num?)?.toInt() ?? 0,
            activities: data['activities'] is Map
                ? (data['activities'] as Map).map(
                    (k, v) => MapEntry(k.toString(), (v as num).toInt()),
                  )
                : const {},
          );
          await prefs.setString(
              'focus_history_${doc.id}', jsonEncode(record.toJson()));
        } catch (e) {
          debugPrint('[CloudSync] restore ${doc.id} failed: $e');
        }
      }
      // Activities list'ni ham tiklaymiz
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final cloudActivities = userDoc.data()?['customActivities'];
      if (cloudActivities is List) {
        await prefs.setStringList(
            'custom_activities', cloudActivities.cast<String>());
      }
    } catch (e) {
      debugPrint('[CloudSync] restoreFromCloud failed: $e');
    }
  }
}

/// Manual backup paytida UI'ga progress xabar berish uchun model.
class BackupProgress {
  final int current;
  final int total;
  final String currentItem;
  const BackupProgress({
    required this.current,
    required this.total,
    required this.currentItem,
  });

  double get ratio => total > 0 ? current / total : 0.0;
}
