import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../services/theme_service.dart';
import '../services/app_translation_service.dart';

class AppColorTheme {
  final String name;
  final Color color;
  final List<Color> gradient;

  AppColorTheme({required this.name, required this.color, required this.gradient});
}

class ThemesScreen extends StatefulWidget {
  const ThemesScreen({super.key});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> with SingleTickerProviderStateMixin {
  late AnimationController _notificationController;
  late Animation<double> _notificationAnimation;

  bool _isDarkMode = false;
  Color _selectedColor = const Color(0xFF007AFF);
  Color _tempSelectedColor = const Color(0xFF007AFF);
  
  late List<AppColorTheme> _themes;

  @override
  void initState() {
    super.initState();
    _isDarkMode = ThemeService().isDarkMode;
    _selectedColor = ThemeService().accentColorNotifier.value;
    _tempSelectedColor = _selectedColor;
    _themes = [
      AppColorTheme(name: 'Ocean', color: const Color(0xFF007AFF), gradient: [const Color(0xFF007AFF), const Color(0xFF47A1FF)]),
      AppColorTheme(name: 'Galaxy', color: const Color(0xFF6366F1), gradient: [const Color(0xFF6366F1), const Color(0xFF818CF8)]),
      AppColorTheme(name: 'Emerald', color: const Color(0xFF10B981), gradient: [const Color(0xFF10B981), const Color(0xFF34D399)]),
      AppColorTheme(name: 'Amber', color: const Color(0xFFFF9500), gradient: [const Color(0xFFFF9500), const Color(0xFFFFB340)]),
      AppColorTheme(name: 'Pink', color: const Color(0xFFEC4899), gradient: [const Color(0xFFEC4899), const Color(0xFFF472B6)]),
      AppColorTheme(name: 'Cyan', color: const Color(0xFF06B6D4), gradient: [const Color(0xFF06B6D4), const Color(0xFF22D3EE)]),
      AppColorTheme(name: 'Indigo', color: const Color(0xFF4F46E5), gradient: [const Color(0xFF4F46E5), const Color(0xFF6366F1)]),
      AppColorTheme(name: 'Lime', color: const Color(0xFF84CC16), gradient: [const Color(0xFF84CC16), const Color(0xFFA3E635)]),
      AppColorTheme(name: 'Violet', color: const Color(0xFF8B5CF6), gradient: [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)]),
      AppColorTheme(name: 'Sky', color: const Color(0xFF0EA5E9), gradient: [const Color(0xFF0EA5E9), const Color(0xFF38BDF8)]),
    ];

    _notificationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _notificationAnimation = CurvedAnimation(
      parent: _notificationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _notificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppTranslationService();
    return ValueListenableBuilder<String>(
      valueListenable: lang.languageNotifier,
      builder: (context, _, __) {
        final bgColor = _isDarkMode ? const Color(0xFF0F0F12) : const Color(0xFFF2F2F7);
        final cardColor = _isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
        final textColor = _isDarkMode ? Colors.white : const Color(0xFF1C1C1E);

        return Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildAppBar(textColor, cardColor, lang),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildSectionHeader(lang.translate('themes.section_appearance'), textColor),
                        const SizedBox(height: 16),
                        _buildModernToggle(cardColor, textColor, lang),
                        const SizedBox(height: 40),
                        _buildSectionHeader(lang.translate('themes.section_accent'), textColor),
                        const SizedBox(height: 16),
                        _buildPremiumPalette(cardColor),
                        
                        // Show apply button only if selection changed
                        if (_tempSelectedColor.value != _selectedColor.value)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildApplyButton(lang),
                          ),
                          
                        const SizedBox(height: 40),
                        _buildSectionHeader(lang.translate('themes.section_preview'), textColor),
                        const SizedBox(height: 16),
                        _buildCardPreview(cardColor, textColor, lang),
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ],
              ),
              FadeTransition(
                opacity: _notificationAnimation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(_notificationAnimation),
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: _selectedColor.withOpacity(0.35),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(CupertinoIcons.checkmark, color: _selectedColor, size: 14),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              lang.translate('themes.success_msg'),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(Color textColor, Color cardColor, AppTranslationService lang) {
    return SliverAppBar(
      backgroundColor: cardColor,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.2),
      pinned: true,
      centerTitle: true,
      shape: Border(
        bottom: BorderSide(
          color: textColor.withOpacity(0.05),
          width: 1,
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: _selectedColor.withOpacity(0.1),
              child: IconButton(
                icon: Icon(CupertinoIcons.left_chevron, color: textColor, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
      title: Text(
        lang.translate('themes.title'),
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: textColor,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: textColor.withOpacity(0.4),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildModernToggle(Color cardColor, Color textColor, AppTranslationService lang) {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
            alignment: _isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: (MediaQuery.of(context).size.width - 60) / 2,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: _selectedColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    setState(() => _isDarkMode = false);
                    await Future.delayed(const Duration(milliseconds: 300));
                    ThemeService().toggleTheme(false);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.sun_max_fill, 
                          color: !_isDarkMode ? Colors.white : textColor.withOpacity(0.4), 
                          size: 18),
                        const SizedBox(width: 8),
                        Text(lang.translate('themes.mode_light'), style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: !_isDarkMode ? Colors.white : textColor.withOpacity(0.4),
                        )),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    setState(() => _isDarkMode = true);
                    await Future.delayed(const Duration(milliseconds: 300));
                    ThemeService().toggleTheme(true);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.moon_fill, 
                          color: _isDarkMode ? Colors.white : textColor.withOpacity(0.4), 
                          size: 18),
                        const SizedBox(width: 8),
                        Text(lang.translate('themes.mode_dark'), style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: _isDarkMode ? Colors.white : textColor.withOpacity(0.4),
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPalette(Color cardColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: _themes.map((theme) {
          final isSelected = _tempSelectedColor.value == theme.color.value;
          return GestureDetector(
            onTap: () => setState(() => _tempSelectedColor = theme.color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: theme.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? (_isDarkMode ? Colors.white : Colors.black) : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                  if (isSelected)
                  BoxShadow(
                    color: theme.color.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: isSelected 
                ? const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 24) 
                : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildApplyButton(AppTranslationService lang) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = _tempSelectedColor;
        });
        ThemeService().setAccentColor(_selectedColor);
        _notificationController.forward();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _notificationController.reverse();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 50,
        decoration: BoxDecoration(
          color: _tempSelectedColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _tempSelectedColor.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                lang.translate('themes.apply_btn'),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardPreview(Color cardColor, Color textColor, AppTranslationService lang) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: _tempSelectedColor.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _tempSelectedColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _tempSelectedColor.withOpacity(0.2),
                  child: Icon(CupertinoIcons.person_fill, color: _tempSelectedColor, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 100, height: 8, decoration: BoxDecoration(color: textColor.withOpacity(0.8), borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(width: 60, height: 6, decoration: BoxDecoration(color: textColor.withOpacity(0.3), borderRadius: BorderRadius.circular(3))),
                  ],
                ),
                const Spacer(),
                Icon(CupertinoIcons.bell_fill, color: _tempSelectedColor, size: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMockStat(lang.translate('nav.focus'), '12s', textColor),
                    _buildMockStat(lang.translate('stats.metrics_sessions'), '4', textColor),
                    _buildMockStat(lang.translate('stats.focus_score'), '85', textColor),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  height: 54,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_tempSelectedColor, _tempSelectedColor.withOpacity(0.8)]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: _tempSelectedColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                    ],
                  ),
                  child: Center(
                    child: Text(
                      lang.translate('focus_timer.btn_start'),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockStat(String label, String val, Color textColor) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.4))),
      ],
    );
  }
}
