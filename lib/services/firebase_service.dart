import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Foydalanuvchi holatini kuzatish
  Stream<User?> get user => _auth.authStateChanges();

  // Ro'yxatdan o'tish
  Future<UserCredential?> registerWithEmail(String name, String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      User? user = result.user;
      if (user != null) {
        // 1. Birinchi navbatda Auth profilini yangilaymiz (Console'da ko'rinishi uchun)
        await user.updateDisplayName(name);
        
        // 2. Firestore'ga ma'lumotni saqlaymiz (Bazada ko'rinishi uchun)
        // Buni fonda (non-blocking) bajarishimiz mumkin, lekin kutish ishonchliroq
        await _firestore.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'isPremium': false,
        });

        // 3. Email tasdiqlashni fonda yuboramiz (bu kutishga arzimaydi)
        user.sendEmailVerification().catchError((e) => debugPrint('Email verify error: $e'));
      }
      return result;
    } catch (e) {
      debugPrint('Registration Error: $e');
      rethrow;
    }
  }

  // Tizimga kirish
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } catch (e) {
      debugPrint('SignIn Error: $e');
      rethrow;
    }
  }

  // Parolni tiklash
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password Reset Error: $e');
      rethrow;
    }
  }

  // Email mavjudligini tekshirish
  Future<bool> checkEmailExists(String email) async {
    try {
      final result = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      return result.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Check Email Exists Error: $e');
      return false;
    }
  }

  // Foydalanuvchi ma'lumotlarini olish
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Get User Data Error: $e');
      return null;
    }
  }

  // Tizimdan chiqish
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
