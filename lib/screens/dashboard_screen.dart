import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/app_translation_service.dart';

import 'focus_timer_screen.dart';
import 'block_list_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';

import '../services/language_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const FocusTimerScreen(),
    const BlockListScreen(),
    const StatsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = AppTranslationService();
    return ValueListenableBuilder<String>(
      valueListenable: lang.languageNotifier,
      builder: (context, _, __) {
        return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          // Premium Header with XP and Streak (Only show on Focus tab)
          if (_currentIndex == 0)
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                bottom: 12,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Level & XP
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${lang.translate('levels.level')} 4',
                              style: LanguageService.getFont(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF007AFF),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                lang.translate('levels.master'),
                                style: LanguageService.getFont(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // XP Progress Bar
                        Container(
                          height: 6,
                          width: 140,
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.65,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF007AFF), Color(0xFF5AC8FA)],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Streak Counter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.fireFlameCurved,
                          color: Color(0xFFFF9500),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '7 ${lang.translate('levels.streak')}',
                          style: LanguageService.getFont(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFF9500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _screens[_currentIndex],
          ),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05), 
                  width: 0.5,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: Colors.transparent,
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500),
              iconSize: 24,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                  icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.timer)),
                  activeIcon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.timer_fill)),
                  label: lang.translate('nav.focus'),
                ),
                BottomNavigationBarItem(
                  icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.lock_shield)),
                  activeIcon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.lock_shield_fill)),
                  label: lang.translate('nav.block'),
                ),
                BottomNavigationBarItem(
                  icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.chart_bar_alt_fill)),
                  label: lang.translate('nav.stats'),
                ),
                BottomNavigationBarItem(
                  icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.person_crop_circle)),
                  activeIcon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(CupertinoIcons.person_crop_circle_fill)),
                  label: lang.translate('nav.profile'),
                ),
              ],
            ),
          ),
        ),
      ),
        );
      },
    );
  }
}

