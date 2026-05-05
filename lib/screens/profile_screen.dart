import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/app_translation_service.dart';
import 'premium_screen.dart';
import 'my_plans_screen.dart';
import 'level_screen.dart';
import 'notifications_settings_screen.dart';
import 'interface_language_screen.dart';
import 'themes_screen.dart';
import 'splash_screen.dart';
import 'help_support_screen.dart';


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = AppTranslationService();
    return ValueListenableBuilder<String>(
      valueListenable: lang.languageNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              // Custom Header Block
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 10,
                  bottom: 16,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(28),
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
                    Text(
                      lang.translate('profile.title'),
                      style: AppTranslationService().getFont(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Color(0xFFD1D1D6),
                          child: Icon(
                            CupertinoIcons.person_solid,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.translate('profile.user_name'),
                                style: AppTranslationService().getFont(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34C759).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  lang.translate('profile.free_plan'),
                                  style: AppTranslationService().getFont(
                                    color: const Color(0xFF34C759),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    24,
                    20,
                    140,
                  ), // Large bottom padding
                  children: [
                    // Profile row moved to header

                    // Premium Glass/Gradient Banner
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFFA855F7),
                                Color(0xFFEC4899),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFA855F7).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const FaIcon(
                                    FontAwesomeIcons.crown,
                                    color: Color(0xFFFFD700),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    lang.translate('profile.premium_title'),
                                    style: AppTranslationService().getFont(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                lang.translate('profile.premium_desc'),
                                style: AppTranslationService().getFont(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const PremiumScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Theme.of(context).primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  lang.translate('profile.premium_btn'),
                                  style: AppTranslationService().getFont(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      lang.translate('profile.section_for_you'),
                      style: AppTranslationService().getFont(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsItem(
                      context,
                      CupertinoIcons.graph_square_fill,
                      lang.translate('profile.menu_level'),
                      Theme.of(context).primaryColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LevelScreen(),
                        ),
                      ),
                    ),
                    _buildSettingsItem(
                      context,
                      CupertinoIcons.star_circle_fill,
                      lang.translate('profile.menu_plans'),
                      const Color(0xFFFF9500),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyPlansScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      lang.translate('profile.section_settings'),
                      style: AppTranslationService().getFont(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsItem(
                      context,
                      CupertinoIcons.bell_fill,
                      lang.translate('profile.menu_notifications'),
                      const Color(0xFFFF3B30),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsSettingsScreen(),
                        ),
                      ),
                    ),
                    _buildSettingsItem(
                      context,
                      CupertinoIcons.globe,
                      lang.translate('profile.menu_language'),
                      Theme.of(context).primaryColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InterfaceLanguageScreen(),
                        ),
                      ),
                    ),
                    _buildSettingsItem(
                      context,
                      CupertinoIcons.paintbrush_fill,
                      lang.translate('profile.menu_themes'),
                      Theme.of(context).primaryColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ThemesScreen(),
                        ),
                      ),
                    ),
                    _buildSettingsItem(
                      context,
                      CupertinoIcons.question_circle_fill,
                      lang.translate('profile.menu_help'),
                      Theme.of(context).primaryColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpSupportScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        showGeneralDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: '',
                          transitionDuration: const Duration(milliseconds: 200),
                          pageBuilder: (context, anim1, anim2) => Container(),
                          transitionBuilder: (context, anim1, anim2, child) {
                            return Transform.scale(
                              scale: anim1.value,
                              child: FadeTransition(
                                opacity: anim1,
                                child: CupertinoTheme(
                                  data: CupertinoThemeData(
                                    brightness: Theme.of(context).brightness,
                                  ),
                                  child: CupertinoAlertDialog(
                                    title: Text(
                                      lang.translate('profile.logout_confirm_title'),
                                      style: AppTranslationService().getFont(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: Text(
                                      lang.translate('profile.logout_confirm_desc'),
                                      style: GoogleFonts.inter(),
                                    ),
                                    actions: [
                                      CupertinoDialogAction(
                                        child: Text(
                                          lang.translate('profile.cancel'),
                                          style: AppTranslationService().getFont(
                                            color: Theme.of(context).primaryColor,
                                          ),
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      CupertinoDialogAction(
                                        isDestructiveAction: true,
                                        child: Text(
                                          lang.translate('profile.logout'),
                                          style: GoogleFonts.inter(),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          Navigator.of(
                                            context,
                                            rootNavigator: true,
                                          ).pushReplacement(
                                            MaterialPageRoute(
                                              builder: (context) => const SplashScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            lang.translate('profile.logout'),
                            style: AppTranslationService().getFont(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFF3B30),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsItem(
    BuildContext context,
    IconData icon,
    String title,
    Color bg, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bg.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: bg, size: 18),
          ),
          title: Text(
            title,
            style: AppTranslationService().getFont(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.2,
            ),
          ),
          trailing: const Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: Color(0xFFC7C7CC),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 0,
          ),
        ),
      ),
    );
  }
}
