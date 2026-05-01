import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/app_translation_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> with TickerProviderStateMixin {
  int _selectedPlanIndex = 1;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

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
              // Dynamic Animated Header
              Container(
                width: double.infinity,
                height: 180,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Color(0xFF5856D6),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 5)),
                  ],
                ),
                child: Stack(
                  children: [
                    // Moving Orbs Animation
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Stack(
                          children: [
                            _buildOrb(
                              color: const Color(0xFF6366F1),
                              size: 150,
                              top: -30 + sin(_animController.value * pi * 2) * 20,
                              left: -20 + cos(_animController.value * pi * 2) * 30,
                            ),
                            _buildOrb(
                              color: const Color(0xFFEC4899),
                              size: 180,
                              bottom: -40 + cos(_animController.value * pi * 2) * 25,
                              right: -30 + sin(_animController.value * pi * 2) * 40,
                            ),
                            _buildOrb(
                              color: const Color(0xFFA855F7),
                              size: 140,
                              top: 20 + cos(_animController.value * pi * 2 + 1) * 30,
                              right: 20 + sin(_animController.value * pi * 2 + 1) * 20,
                            ),
                            // Glassmorphism Blur
                            BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                              child: Container(color: Colors.transparent),
                            ),
                          ],
                        );
                      },
                    ),
                    
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 10,
                      child: IconButton(
                        icon: const Icon(CupertinoIcons.back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          const FaIcon(FontAwesomeIcons.crown, color: Colors.white, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            'FOCUS GUARD PRO',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.translate('premium.title'), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: 20),
                        _buildPremiumFeature(FontAwesomeIcons.crown, lang.translate('premium.feature_plans_title'), lang.translate('premium.feature_plans_desc')),
                        _buildPremiumFeature(FontAwesomeIcons.palette, lang.translate('premium.feature_colors_title'), lang.translate('premium.feature_colors_desc')),
                        _buildPremiumFeature(FontAwesomeIcons.rectangleAd, lang.translate('premium.feature_ads_title'), lang.translate('premium.feature_ads_desc')),
                        _buildPremiumFeature(FontAwesomeIcons.language, lang.translate('premium.feature_languages_title'), lang.translate('premium.feature_languages_desc')),
                        _buildPremiumFeature(FontAwesomeIcons.wandMagicSparkles, lang.translate('premium.feature_ai_title'), lang.translate('premium.feature_ai_desc')),
                        _buildPremiumFeature(FontAwesomeIcons.lock, lang.translate('premium.feature_limit_title'), lang.translate('premium.feature_limit_desc')),
                        _buildPremiumFeature(FontAwesomeIcons.key, lang.translate('premium.feature_emergency_title'), lang.translate('premium.feature_emergency_desc')),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildPlanCard(0, lang.translate('premium.plan_monthly'), '\$4.99', lang.translate('premium.per_month'), lang)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPlanCard(1, lang.translate('premium.plan_yearly'), '\$2.99', lang.translate('premium.per_month'), lang, isBestValue: true, savings: lang.translate('premium.savings').replaceAll('{percent}', '30'))),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFA855F7).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(24),
                      child: Center(
                        child: Text(
                          lang.translate('premium.checkout_btn'),
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildOrb({required Color color, required double size, double? top, double? left, double? right, double? bottom}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildPlanCard(int index, String title, String price, String period, AppTranslationService lang, {bool isBestValue = false, String? savings}) {
    bool isSelected = _selectedPlanIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF5856D6).withOpacity(0.05) : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? const Color(0xFF5856D6) : const Color(0xFFE5E5EA),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF5856D6) : Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(price, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                    Text('/$period', style: GoogleFonts.inter(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                  ],
                ),
              ],
            ),
          ),
          if (isBestValue)
            Positioned(
              top: -8,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(lang.translate('premium.best_value'), style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          if (savings != null)
            Positioned(
              bottom: -6,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(savings, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeature(dynamic icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF5856D6).withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: FaIcon(icon as dynamic, color: const Color(0xFF5856D6), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                Text(description, style: GoogleFonts.inter(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
