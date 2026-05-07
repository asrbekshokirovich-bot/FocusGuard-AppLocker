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

  // Foydalanuvchi ma'lumotlarini oqim (stream) shaklida olish
  Stream<DocumentSnapshot> getUserStatsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore.collection('users').doc(user.uid).snapshots();
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
        
        // Darajani hisoblash
        int newLevel = (newXP / 1000).floor() + 1;
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

  // Darajaga qarab unvonni aniqlash (AppTranslationService kalitlari bilan)
  String getRankTitle(int level, dynamic lang) {
    if (level <= 1) return lang.translate('levels.rank_1') ?? 'Yangi Foydalanuvchi';
    if (level <= 3) return lang.translate('levels.rank_2') ?? 'Birinchi Qadam';
    if (level <= 5) return lang.translate('levels.rank_3') ?? 'Ambitsioz';
    if (level <= 8) return lang.translate('levels.rank_4') ?? 'Entuziast';
    if (level <= 12) return lang.translate('levels.rank_5') ?? 'Diqqatli';
    if (level <= 16) return lang.translate('levels.rank_6') ?? 'G\'ayratli';
    if (level <= 20) return lang.translate('levels.rank_7') ?? 'Mutaxassis';
    if (level <= 25) return lang.translate('levels.rank_8') ?? 'Professional';
    if (level <= 30) return lang.translate('levels.rank_9') ?? 'Chempion';
    if (level <= 35) return lang.translate('levels.rank_10') ?? 'Super Fokus';
    if (level <= 40) return lang.translate('levels.rank_11') ?? 'Elite';
    if (level <= 50) return lang.translate('levels.rank_12') ?? 'Legend';
    if (level <= 65) return lang.translate('levels.rank_13') ?? 'Master';
    if (level <= 80) return lang.translate('levels.rank_14') ?? 'Grandmaster';
    if (level <= 100) return lang.translate('levels.rank_15') ?? 'Fokus Qiroli';
    return lang.translate('levels.rank_16') ?? 'Fokus Xudosi';
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
