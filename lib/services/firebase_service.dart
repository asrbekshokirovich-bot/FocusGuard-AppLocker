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
        // Email tasdiqlash xatini yuborish
        await user.sendEmailVerification();
        
        // Foydalanuvchi ismini Firestore'da saqlash
        await _firestore.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'isPremium': false,
        });
        
        // Ismni Firebase profiliga ham yangilab qo'yamiz
        await user.updateDisplayName(name);
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
