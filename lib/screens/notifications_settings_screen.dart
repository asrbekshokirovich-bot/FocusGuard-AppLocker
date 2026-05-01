import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_translation_service.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  bool _mainNotifications = true;
  bool _focusReminders = true;
  bool _achievementAlerts = true;
  bool _planReminders = true;
  bool _dailyAnalysis = false;

  @override
  Widget build(BuildContext context) {
    final lang = AppTranslationService();
    return ValueListenableBuilder<String>(
      valueListenable: lang.languageNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(lang),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(lang.translate('notifications.section_main')),
                      _buildSettingsCard([
                        _buildSwitchItem(
                          lang.translate('notifications.push_title'), 
                          lang.translate('notifications.push_desc'), 
                          _mainNotifications, 
                          (val) => setState(() => _mainNotifications = val),
                          CupertinoIcons.bell_fill,
                          Theme.of(context).primaryColor,
                        ),
                      ]),
                      
                      const SizedBox(height: 24),
                      _buildSectionTitle(lang.translate('notifications.section_focus')),
                      _buildSettingsCard([
                        _buildSwitchItem(
                          lang.translate('notifications.focus_reminders_title'), 
                          lang.translate('notifications.focus_reminders_desc'), 
                          _focusReminders, 
                          (val) => setState(() => _focusReminders = val),
                          CupertinoIcons.timer_fill,
                          const Color(0xFFFF9500),
                        ),
                        _buildDivider(),
                        _buildSwitchItem(
                          lang.translate('notifications.achievements_title'), 
                          lang.translate('notifications.achievements_desc'), 
                          _achievementAlerts, 
                          (val) => setState(() => _achievementAlerts = val),
                          CupertinoIcons.star_fill,
                          const Color(0xFFFFCC00),
                        ),
                      ]),

                      const SizedBox(height: 24),
                      _buildSectionTitle(lang.translate('notifications.section_plans')),
                      _buildSettingsCard([
                        _buildSwitchItem(
                          lang.translate('notifications.plans_reminders_title'), 
                          lang.translate('notifications.plans_reminders_desc'), 
                          _planReminders, 
                          (val) => setState(() => _planReminders = val),
                          CupertinoIcons.calendar_badge_plus,
                          const Color(0xFF34C759),
                        ),
                        _buildDivider(),
                        _buildSwitchItem(
                          lang.translate('notifications.daily_analysis_title'), 
                          lang.translate('notifications.daily_analysis_desc'), 
                          _dailyAnalysis, 
                          (val) => setState(() => _dailyAnalysis = val),
                          CupertinoIcons.graph_circle_fill,
                          Theme.of(context).primaryColor,
                        ),
                      ]),
                      
                      const SizedBox(height: 40),
                      _buildPremiumNotice(lang),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(AppTranslationService lang) {
    return SliverAppBar(
      expandedHeight: 70.0,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).primaryColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      leading: IconButton(
        icon: const Icon(CupertinoIcons.left_chevron, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          lang.translate('notifications.title'),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        background: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.8)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(
                    CupertinoIcons.bell_fill,
                    size: 150,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchItem(String title, String subtitle, bool value, Function(bool) onChanged, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeColor: Theme.of(context).primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).scaffoldBackgroundColor,
      indent: 60,
    );
  }

  Widget _buildPremiumNotice(AppTranslationService lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.info_circle_fill, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lang.translate('notifications.permission_notice'),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).primaryColor.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
