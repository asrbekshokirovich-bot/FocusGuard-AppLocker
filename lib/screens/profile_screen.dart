import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_translation_service.dart';
import 'premium_screen.dart';
import 'my_plans_screen.dart';
import 'level_screen.dart';
import 'calendar_screen.dart';
import 'notifications_settings_screen.dart';
import 'interface_language_screen.dart';
import 'themes_screen.dart';
import 'splash_screen.dart';
import 'help_support_screen.dart';
import 'permissions_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSendingVerification = false;
  bool _isRefreshing = false;

  Future<void> _refreshUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() => _isRefreshing = true);
      try {
        await user.reload();
      } catch (e) {
        debugPrint("Error refreshing user: $e");
      } finally {
        if (mounted) setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      setState(() => _isSendingVerification = true);
      try {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppTranslationService().translate('profile.verify_sent')),
              backgroundColor: const Color(0xFF34C759),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: const Color(0xFFFF3B30),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSendingVerification = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppTranslationService();
    return StreamBuilder<User?>(
      stream: _auth.userChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        final bool isVerified = user?.emailVerified ?? false;
        final String displayName = user?.displayName ?? lang.translate('profile.user_name');
        final String email = user?.email ?? '';

        return StreamBuilder<DocumentSnapshot>(
          stream: user != null 
              ? _firestore.collection('users').doc(user.uid).snapshots()
              : const Stream.empty(),
          builder: (context, firestoreSnapshot) {
            bool isPremium = false;
            if (firestoreSnapshot.hasData && firestoreSnapshot.data!.exists) {
              isPremium = firestoreSnapshot.data!.get('isPremium') ?? false;
            }

            return ValueListenableBuilder<String>(
              valueListenable: lang.languageNotifier,
              builder: (context, _, __) {
                bool finalIsPremium = isPremium;
                
                // Background validation: if expiry date exists and is passed, treat as not premium
                if (isPremium && firestoreSnapshot.hasData && firestoreSnapshot.data!.exists) {
                  final data = firestoreSnapshot.data!;
                  if (data.data() is Map<String, dynamic>) {
                    final map = data.data() as Map<String, dynamic>;
                    if (map.containsKey('premiumExpiryDate')) {
                      final expiry = map['premiumExpiryDate'];
                      if (expiry is Timestamp) {
                        final expiryDate = expiry.toDate();
                        if (DateTime.now().isAfter(expiryDate)) {
                          finalIsPremium = false;
                        }
                      }
                    }
                  }
                }

                return Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  body: Column(
                    children: [
                      // Custom Header Block
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 10,
                          bottom: 20,
                          left: 20,
                          right: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SizedBox(width: 40), // Spacing for balance
                                Text(
                                  lang.translate('profile.title'),
                                  style: lang.getFont(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    letterSpacing: -0.7,
                                  ),
                                ),
                                _isRefreshing 
                                  ? const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
                                  : IconButton(
                                      onPressed: _refreshUser,
                                      icon: const Icon(CupertinoIcons.refresh, size: 22),
                                      color: const Color(0xFF007AFF),
                                    ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Stack(
                                  children: [
                                    const CircleAvatar(
                                      radius: 35,
                                      backgroundColor: Color(0xFFF2F2F7),
                                      child: Icon(
                                        CupertinoIcons.person_solid,
                                        size: 38,
                                        color: Color(0xFFC7C7CC),
                                      ),
                                    ),
                                    if (isVerified)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF007AFF),
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: lang.getFont(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              email,
                                              style: lang.getFont(
                                                fontSize: 13,
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isVerified) ...[
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.verified,
                                              color: Color(0xFF34C759),
                                              size: 14,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: finalIsPremium 
                                              ? const Color(0xFF34C759).withOpacity(0.1)
                                              : const Color(0xFFFF3B30).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          finalIsPremium ? lang.translate('profile.premium_plan') : lang.translate('profile.free_plan'),
                                          style: lang.getFont(
                                            color: finalIsPremium ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (!isVerified && email.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3B30).withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.1)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(CupertinoIcons.exclamationmark_triangle, color: Color(0xFFFF3B30), size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        lang.translate('profile.email_not_verified'),
                                        style: lang.getFont(color: const Color(0xFFFF3B30), fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _isSendingVerification ? null : _sendVerificationEmail,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        backgroundColor: const Color(0xFFFF3B30),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: _isSendingVerification 
                                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : Text(
                                            lang.translate('profile.verify_now'),
                                            style: lang.getFont(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                          children: [
                            // Premium Banner - only show if NOT premium
                            if (!finalIsPremium) ...[
                              _buildPremiumBanner(context, lang, isVerified),
                              const SizedBox(height: 24),
                            ],
                            Text(
                              lang.translate('profile.section_for_you'),
                              style: lang.getFont(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSettingsItem(
                              context,
                              lang,
                              CupertinoIcons.graph_square_fill,
                              lang.translate('profile.menu_level'),
                              const Color(0xFF5856D6),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LevelScreen())),
                            ),
                            _buildSettingsItem(
                              context,
                              lang,
                              CupertinoIcons.star_circle_fill,
                              lang.translate('profile.menu_plans'),
                              const Color(0xFFFF9500),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPlansScreen())),
                            ),
                            // Kalendar — kunlik fokus tarixini ko'rsatadi
                            // (✅ Fokusladim / ❌ Bo'shashdim). Ma'lumot
                            // FocusHistoryService'dan keladi.
                            _buildSettingsItem(
                              context,
                              lang,
                              CupertinoIcons.calendar,
                              lang.translate('profile.menu_calendar'),
                              const Color(0xFF34C759),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarScreen())),
                            ),

                            const SizedBox(height: 24),
                            Text(
                              lang.translate('profile.section_settings'),
                              style: lang.getFont(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSettingsItem(
                              context,
                              lang,
                              CupertinoIcons.lock_shield,
                              lang.translate('profile.menu_permissions'),
                              const Color(0xFF34C759),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PermissionsScreen(isFromOnboarding: false))),
                            ),
                            _buildSettingsItem(
                              context,
                              lang,
                              CupertinoIcons.bell_fill,
                              lang.translate('profile.menu_notifications'),
                              const Color(0xFFFF3B30),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsSettingsScreen())),
                            ),
                            _buildSettingsItem(
                              context,
                              lang,
                              CupertinoIcons.globe,
                              lang.translate('profile.menu_language'),
                              const Color(0xFF007AFF),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InterfaceLanguageScreen())),
                            ),
                            _buildSettingsItem(
                              context,
                              lang,
                              CupertinoIcons.paintbrush_fill,
                              lang.translate('profile.menu_themes'),
                              const Color(0xFF34C759),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ThemesScreen())),
                            ),
                            _buildSettingsItem(
                              context,
                              lang,
                              CupertinoIcons.question_circle_fill,
                              lang.translate('profile.menu_help'),
                              const Color(0xFF8E8E93),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpSupportScreen())),
                            ),

                            const SizedBox(height: 32),
                            _buildLogoutButton(context, lang),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPremiumBanner(BuildContext context, AppTranslationService lang, bool isVerified) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA855F7).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handlePremiumTap(context, lang, isVerified),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.crown, color: Color(0xFFFFD700), size: 22),
                        const SizedBox(width: 10),
                        Text(
                          lang.translate('profile.premium_title'),
                          style: lang.getFont(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Icon(CupertinoIcons.chevron_right, color: Colors.white, size: 18),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  lang.translate('profile.premium_desc'),
                  style: lang.getFont(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    lang.translate('profile.premium_btn'),
                    style: lang.getFont(color: const Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handlePremiumTap(BuildContext context, AppTranslationService lang, bool isVerified) {
    if (!isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.translate('profile.premium_unverified_error')),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumScreen()));
    }
  }

  Widget _buildLogoutButton(BuildContext context, AppTranslationService lang) {
    return GestureDetector(
      onTap: () => _showLogoutDialog(context, lang),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30).withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            lang.translate('profile.logout'),
            style: lang.getFont(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFFF3B30)),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AppTranslationService lang) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(lang.translate('profile.logout_confirm_title')),
        content: Text(lang.translate('profile.logout_confirm_desc')),
        actions: [
          CupertinoDialogAction(
            child: Text(lang.translate('common.cancel')),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await FirebaseAuth.instance.signOut();
              await prefs.remove('is_logged_in');
              await prefs.remove('onboarding_completed');
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const SplashScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(lang.translate('profile.logout')),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(BuildContext context, AppTranslationService lang, IconData icon, String title, Color color, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: lang.getFont(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
                const Icon(CupertinoIcons.chevron_right, size: 16, color: Color(0xFFC7C7CC)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
