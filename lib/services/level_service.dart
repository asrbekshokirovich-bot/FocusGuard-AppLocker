import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'streak_reminder_service.dart';
import 'timer_notification_service.dart';
import 'app_translation_service.dart';

class LevelService {
  static final LevelService _instance = LevelService._internal();
  factory LevelService() => _instance;
  LevelService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 16 ta darajaning XP chegaralari. Index N — Level (N+1) ga kirish uchun
  /// kerakli minimum XP. 1 daqiqa fokus = 10 XP. Soatlar `level_screen.dart`
  /// ro'yxatidagi qiymatlarga mos:
  ///   L1 0-1s, L2 1-3s, L3 3-7s, L4 7-15s, L5 15-30s, ...
  static const List<int> levelXpThresholds = [
    0,        // L1 boshlanishi (0 soat)
    600,      // L2 (1 soat)
    1800,     // L3 (3 soat)
    4200,     // L4 (7 soat)
    9000,     // L5 (15 soat)
    18000,    // L6 (30 soat)
    30000,    // L7 (50 soat)
    48000,    // L8 (80 soat)
    72000,    // L9 (120 soat)
    108000,   // L10 (180 soat)
    150000,   // L11 (250 soat)
    240000,   // L12 (400 soat)
    360000,   // L13 (600 soat)
    540000,   // L14 (900 soat)
    780000,   // L15 (1300 soat)
    1080000,  // L16 (1800 soat — maksimal)
  ];

  static const int maxLevel = 16;

  /// XP qiymatidan darajani hisoblash. Eski `(xp/1000).floor()+1` formulasi
  /// yuqori darajalarda noto'g'ri qiymat berardi (cheksiz daraja oshib
  /// ketardi) — endi 16 ta belgilangan chegara bilan ishlaydi.
  static int levelFromXp(int xp) {
    for (int i = levelXpThresholds.length - 1; i >= 0; i--) {
      if (xp >= levelXpThresholds[i]) return i + 1;
    }
    return 1;
  }

  /// Joriy daraja ichidagi progress va keyingi darajagacha qolgan XP.
  /// UI shu helper'dan foydalanadi — formula bir joyda turishi uchun.
  static LevelInfo levelInfoFromXp(int xp) {
    final level = levelFromXp(xp);
    final levelStartXp = levelXpThresholds[level - 1];
    // Maksimal darajada keyingi chegara yo'q — progress 100% deb qaytaramiz.
    if (level >= maxLevel) {
      return LevelInfo(
        level: level,
        progress: 1.0,
        currentLevelXp: xp - levelStartXp,
        remainingXp: 0,
        isMaxLevel: true,
      );
    }
    final nextLevelStartXp = levelXpThresholds[level];
    final xpIntoLevel = xp - levelStartXp;
    final xpRange = nextLevelStartXp - levelStartXp;
    return LevelInfo(
      level: level,
      progress: xpRange > 0 ? (xpIntoLevel / xpRange).clamp(0.0, 1.0) : 0.0,
      currentLevelXp: xpIntoLevel,
      remainingXp: nextLevelStartXp - xp,
      isMaxLevel: false,
    );
  }

  // Foydalanuvchi ma'lumotlarini oqim (stream) shaklida olish
  Stream<DocumentSnapshot> getUserStatsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  /// Sekund aniqligida XP qo'shish — qisqa seanslar uchun (10 sek, 30 sek).
  /// 6 sekund = 1 XP (1 daqiqa = 10 XP). Ichkarida `addXP` ga aylantirib
  /// chaqiramiz, lekin sekundlarni daqiqa ekvivalenti sifatida saqlaymiz —
  /// `totalMinutes` ham aniq bo'lishi uchun.
  Future<void> addXpFromSeconds(int seconds) async {
    if (seconds <= 0) return;
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    try {
      bool levelUp = false;
      int newLevelResult = 1;

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        int currentXP = snapshot.data()?['xp'] ?? 0;
        int currentLevel = snapshot.data()?['level'] ?? 1;
        int currentTotalSec = snapshot.data()?['totalSeconds'] ?? 0;
        // Eski totalMinutes ni jami sekundlardan hisoblaymiz
        int currentTotalMin = (currentTotalSec + seconds) ~/ 60;

        // 6 sekund = 1 XP (round)
        int gainedXP = (seconds * 10 / 60).round();
        int newXP = currentXP + gainedXP;

        int newLevel = levelFromXp(newXP);
        newLevelResult = newLevel;
        if (newLevel > currentLevel) levelUp = true;

        transaction.update(docRef, {
          'xp': newXP,
          'level': newLevel,
          'totalSeconds': currentTotalSec + seconds,
          'totalMinutes': currentTotalMin,
        });
      });

      if (levelUp) {
        final lang = AppTranslationService();
        final rankTitle = getRankTitle(newLevelResult, lang);
        TimerNotificationService().showLevelUpNotification(
          newLevel: newLevelResult,
          rankTitle: rankTitle,
        );
      }
    } catch (e) {
      debugPrint('Add XP from seconds Error: $e');
    }
  }

  // Tajriba ballarini (XP) qo'shish
  Future<void> addXP(int minutes) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);

    try {
      bool levelUp = false;
      int newLevelResult = 1;

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        int currentXP = snapshot.data()?['xp'] ?? 0;
        int currentLevel = snapshot.data()?['level'] ?? 1;

        // Har bir minut uchun 10 XP
        int gainedXP = minutes * 10;
        int newXP = currentXP + gainedXP;

        // Darajani hisoblash — yangi threshold jadvali asosida
        int newLevel = levelFromXp(newXP);
        newLevelResult = newLevel;

        if (newLevel > currentLevel) {
          levelUp = true;
        }

        transaction.update(docRef, {
          'xp': newXP,
          'level': newLevel,
          'totalMinutes': (snapshot.data()?['totalMinutes'] ?? 0) + minutes,
        });
      });

      // Agar daraja oshgan bo'lsa, bildirishnoma ko'rsatish
      if (levelUp) {
        final lang = AppTranslationService();
        final rankTitle = getRankTitle(newLevelResult, lang);
        TimerNotificationService().showLevelUpNotification(
          newLevel: newLevelResult,
          rankTitle: rankTitle,
        );
      }
    } catch (e) {
      debugPrint('Add XP Error: $e');
    }
  }

  // Streak (ketma-ketlik)ni yangilash
  Future<void> updateStreak() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    
    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data();
      final Timestamp? lastFocusDate = data?['lastFocusDate'];
      int currentStreak = data?['streak'] ?? 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (lastFocusDate == null) {
        // Birinchi marta fokus qilyapti
        await docRef.update({
          'streak': 1,
          'lastFocusDate': Timestamp.fromDate(today),
        });
      } else {
        final lastDate = lastFocusDate.toDate();
        final difference = today.difference(lastDate).inDays;

        if (difference == 1) {
          // Ketma-ketlik davom etyapti
          await docRef.update({
            'streak': currentStreak + 1,
            'lastFocusDate': Timestamp.fromDate(today),
          });
        } else if (difference > 1) {
          // Ketma-ketlik buzilgan, qaytadan boshlanadi
          await docRef.update({
            'streak': 1,
            'lastFocusDate': Timestamp.fromDate(today),
          });
        }
        // Agar difference == 0 bo'lsa (bugun allaqachon fokus qilgan), streak o'zgarmaydi
      }
      
      // Bugun fokus qilingani uchun eslatmani bekor qilish
      await StreakReminderService().cancelTodayReminder();
    } catch (e) {
      debugPrint('Update Streak Error: $e');
    }
  }

  // Darajaga qarab unvonni aniqlash. 16 ta daraja 1:1 mos keladi:
  //   Level 1 → rank_1 (Yangi Foydalanuvchi)
  //   Level 2 → rank_2 (Birinchi Qadam)
  //   ...
  //   Level 16 → rank_16 (Afsonaviy Fokuschi)
  String getRankTitle(int level, dynamic lang) {
    final clamped = level.clamp(1, maxLevel);
    return lang.translate('levels.rank_$clamped') ??
        'Yangi Foydalanuvchi';
  }

  /// Bir martalik migration: eski (flat 1000 XP) formuladan yangi threshold
  /// tizimiga o'tish. Foydalanuvchi level qiymati yangi formula bilan qayta
  /// hisoblanadi. Ilova ochilganda asynchronously chaqirilishi mumkin.
  Future<void> migrateLevelIfNeeded() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final snapshot = await docRef.get();
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? {};
      final int xp = (data['xp'] as num?)?.toInt() ?? 0;
      final int oldLevel = (data['level'] as num?)?.toInt() ?? 1;
      final int correctLevel = levelFromXp(xp);
      if (oldLevel != correctLevel) {
        await docRef.update({'level': correctLevel});
        debugPrint('[LevelService] migrated level $oldLevel → $correctLevel (xp=$xp)');
      }
    } catch (e) {
      debugPrint('migrateLevelIfNeeded error: $e');
    }
  }

  // Boshlang'ich ma'lumotlarni tekshirish va yaratish
  Future<void> ensureUserStatsInitialized() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    
    if (!snapshot.exists || snapshot.data()?['level'] == null) {
      await docRef.set({
        'name': user.displayName ?? 'User',
        'email': user.email,
        'level': 1,
        'xp': 0,
        'streak': 0,
        'totalMinutes': 0,
        'lastFocusDate': null,
        'isPremium': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}

/// Daraja haqidagi to'liq ma'lumot — UI shu modeldan foydalanadi.
/// Formula bir joyda (LevelService.levelInfoFromXp) hisoblanadi va
/// barcha ekranlarda yagona qiymat qaytariladi.
class LevelInfo {
  final int level;            // 1..16
  final double progress;      // 0.0..1.0
  final int currentLevelXp;   // Joriy daraja ichidagi XP
  final int remainingXp;      // Keyingi darajagacha qolgan XP
  final bool isMaxLevel;      // Level 16 ga yetganmi

  const LevelInfo({
    required this.level,
    required this.progress,
    required this.currentLevelXp,
    required this.remainingXp,
    required this.isMaxLevel,
  });
}
