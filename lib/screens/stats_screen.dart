import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'premium_screen.dart';
import '../services/app_translation_service.dart';
import 'dart:math' as math;

import '../services/language_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  // Mock data for weekly focus hours
  final List<double> _weeklyHours = [3.5, 4.2, 2.8, 5.0, 3.8, 4.5, 3.2];
  final List<String> _weekDays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
              // Header
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
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        lang.translate('stats.title'),
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.8),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF34C759).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.flame_fill, color: Color(0xFF34C759), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            lang.translate('stats.streak_days').replaceAll('{count}', '5'), 
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF34C759))
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Focus Score & Weekly Activity Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFocusScoreCard(lang),
                          const SizedBox(width: 16),
                          Expanded(child: _buildWeeklyMiniSummary(lang)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Weekly Activity Chart
                      _buildMainActivityChart(lang),
                      const SizedBox(height: 14),

                      // Comparison & Forecast Card
                      _buildComparisonForecastCard(lang),
                      const SizedBox(height: 14),

                      // Metrics Grid
                      _buildMetricsGrid(lang),
                      const SizedBox(height: 14),

                      // Top Distractors
                      _buildTopDistractors(lang),
                      const SizedBox(height: 16),

                      // Recent Sessions
                      Text(
                        lang.translate('stats.recent_sessions'), 
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)
                      ),
                      const SizedBox(height: 10),
                      _buildSessionItem(context, lang.translate('focus_timer.mode_deep'), '1${lang.translate('stats.unit_h')} 45${lang.translate('stats.unit_m')}', lang.translate('stats.today') + ', 09:30', Theme.of(context).primaryColor),
                      _buildSessionItem(context, 'Kitob O\'qish', '30${lang.translate('stats.unit_m')}', lang.translate('stats.today') + ', 14:15', const Color(0xFF34C759)),
                      _buildSessionItem(context, 'Dasturlash', '2${lang.translate('stats.unit_h')} 15${lang.translate('stats.unit_m')}', lang.translate('stats.yesterday') + ', 18:00', const Color(0xFF5856D6)),

                      const SizedBox(height: 24),
                      // Premium Banner
                      _buildPremiumBanner(context, lang),
                      const SizedBox(height: 40),
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

  Widget _buildFocusScoreCard(AppTranslationService lang) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(
            lang.translate('stats.focus_score'), 
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _FocusScorePainter(score: 85, animationValue: _animationController.value),
              child: Center(
                child: Text('85', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            lang.translate('stats.score_feedback'), 
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF34C759))
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyMiniSummary(AppTranslationService lang) {
    return Column(
      children: [
        _buildMiniMetric(lang.translate('stats.weekly_avg'), '3.8 s', CupertinoIcons.graph_circle_fill, Theme.of(context).primaryColor),
        const SizedBox(height: 12),
        _buildMiniMetric(lang.translate('stats.goal_reached'), '85%', CupertinoIcons.checkmark_seal_fill, const Color(0xFF34C759)),
      ],
    );
  }

  Widget _buildMiniMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
                Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _selectedChartType = 0; // 0: Hafta, 1: Oy
  int? _detailedWeekIndex; // null: umumiy, 0-3: hafta tafsilotlari

  Widget _buildMainActivityChart(AppTranslationService lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedChartType == 0 
                        ? lang.translate('stats.chart_weekly') 
                        : (_detailedWeekIndex == null 
                            ? lang.translate('stats.chart_monthly') 
                            : lang.translate('stats.chart_week_detail').replaceAll('{week}', (_detailedWeekIndex! + 1).toString())),
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_detailedWeekIndex != null)
                      GestureDetector(
                        onTap: () => setState(() => _detailedWeekIndex = null),
                        child: Text(
                          lang.translate('stats.back'), 
                          style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_detailedWeekIndex == null)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      _buildChartToggleBtn(0, lang.translate('stats.toggle_week'), lang),
                      _buildChartToggleBtn(1, lang.translate('stats.toggle_month'), lang),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapUp: (details) {
                  if (_selectedChartType == 1 && _detailedWeekIndex == null) {
                    final double barWidthWithSpacing = constraints.maxWidth / 4;
                    final int index = (details.localPosition.dx / barWidthWithSpacing).floor();
                    if (index >= 0 && index < 4) {
                      setState(() => _detailedWeekIndex = index);
                      _animationController.reset();
                      _animationController.forward();
                    }
                  }
                },
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _BarChartPainter(
                          data: _getChartData(),
                          labels: _getChartLabels(lang),
                          animationValue: _animationController.value,
                          activeColor: _detailedWeekIndex != null ? const Color(0xFF34C759) : Theme.of(context).primaryColor,
                          onSurfaceColor: Theme.of(context).colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  List<double> _getChartData() {
    if (_selectedChartType == 0) return _weeklyHours;
    if (_detailedWeekIndex != null) {
      // Mock data for a specific week's days
      return [4.2, 3.5, 5.0, 2.8, 4.0, 5.5, 3.0];
    }
    return [25.5, 32.8, 28.2, 35.0];
  }

  List<String> _getChartLabels(AppTranslationService lang) {
    dynamic labels = lang.translate('plans.weekdays_short');
    if (_selectedChartType == 0) {
      return labels is List ? List<String>.from(labels) : ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
    }
    if (_detailedWeekIndex != null) {
      final startDay = (_detailedWeekIndex! * 7) + 1;
      final shortDays = labels is List ? List<String>.from(labels) : ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
      return List.generate(7, (i) => '${shortDays[i]} ${startDay + i}');
    }
    return List.generate(4, (i) => lang.translate('stats.week_label').toString().replaceAll('{count}', (i + 1).toString()));
  }

  Widget _buildChartToggleBtn(int index, String label, AppTranslationService lang) {
    bool active = _selectedChartType == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedChartType = index;
          if (index == 0) _detailedWeekIndex = null;
        });
        _animationController.reset();
        _animationController.forward();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
        ),
        child: Text(
          label,
          style: lang.getFont(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? const Color(0xFF1C1C1E) : const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonForecastCard(AppTranslationService lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF007AFF), Color(0xFFA855F7), Color(0xFFEC4899)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: const Color(0xFFA855F7).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lang.translate('stats.smart_analysis'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('PRO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Streak Forecast (New)
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.fire, size: 14, color: Color(0xFFFFD700)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.translate('stats.streak_forecast').replaceAll('{days}', '2'), 
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Daily Comparison
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.clockRotateLeft, size: 12, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.translate('stats.daily_comparison').replaceAll('{diff}', '45${lang.translate('stats.unit_m')}'), 
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white24, height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.chartLine, size: 14, color: Color(0xFF34C759)),
                        const SizedBox(width: 6),
                        Text(
                          lang.translate('stats.comparison'), 
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('+18.4%', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text(lang.translate('stats.vs_last_week'), style: GoogleFonts.inter(fontSize: 10, color: Colors.white60)),
                  ],
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white24),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 14, color: Color(0xFFFFD700)),
                        const SizedBox(width: 6),
                        Text(
                          lang.translate('stats.forecast'), 
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('28${lang.translate('stats.unit_h')} 45${lang.translate('stats.unit_m')}', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text(lang.translate('stats.week_end_forecast'), style: GoogleFonts.inter(fontSize: 10, color: Colors.white60)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(AppTranslationService lang) {
    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildGridMetric(lang.translate('stats.metrics_sessions'), '42 ${lang.translate('stats.unit_session')}', CupertinoIcons.cube_box_fill, const Color(0xFF5856D6)),
        _buildGridMetric(lang.translate('stats.metrics_longest'), '2${lang.translate('stats.unit_h')} 15${lang.translate('stats.unit_m')}', CupertinoIcons.timer_fill, const Color(0xFFFF9500)),
      ],
    );
  }

  Widget _buildGridMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.w500)),
          Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildTopDistractors(AppTranslationService lang) {
    final distractors = [
      {'name': 'Instagram', 'count': '45 ${lang.translate('stats.unit_attempt')}', 'icon': FontAwesomeIcons.instagram, 'color': const Color(0xFFE1306C)},
      {'name': 'TikTok', 'count': '38 ${lang.translate('stats.unit_attempt')}', 'icon': FontAwesomeIcons.tiktok, 'color': Colors.black},
      {'name': 'YouTube', 'count': '22 ${lang.translate('stats.unit_attempt')}', 'icon': FontAwesomeIcons.youtube, 'color': const Color(0xFFFF0000)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.translate('stats.top_distractors'), 
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)
          ),
          const SizedBox(height: 16),
          ...distractors.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: (d['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: FaIcon(d['icon'] as dynamic, color: d['color'] as Color, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(d['name'] as String, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600))),
                Text(d['count'] as String, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFFF3B30), fontWeight: FontWeight.bold)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSessionItem(BuildContext context, String title, String duration, String time, Color color) {
    return GestureDetector(
      onTap: () => _showSessionDetails(context, title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(time, style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                ],
              ),
            ),
            Text(duration, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
  Widget _buildPremiumBanner(BuildContext context, AppTranslationService lang) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF007AFF), Color(0xFFA855F7), Color(0xFFEC4899)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFFA855F7).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const FaIcon(FontAwesomeIcons.crown, color: Color(0xFFFFD700), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.translate('stats.pro_banner_title'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(lang.translate('stats.pro_banner_desc'), style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  void _showSessionDetails(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Haftalik tahlil', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 32),
            Expanded(
              child: CustomPaint(
                size: Size.infinite,
                painter: _BarChartPainter(
                  data: _weeklyHours,
                  labels: _weekDays,
                  animationValue: 1.0,
                  activeColor: Theme.of(context).primaryColor,
                  onSurfaceColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildMiniMetric('O\'rtacha fokus', '4.2 s', CupertinoIcons.time, const Color(0xFF34C759)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _FocusScorePainter extends CustomPainter {
  final double score;
  final double animationValue;

  _FocusScorePainter({required this.score, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 8.0;

    final bgPaint = Paint()
      ..color = const Color(0xFFF2F2F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF34C759), Color(0xFF30D158)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    final sweepAngle = (score / 100) * 2 * math.pi * animationValue;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BarChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final double animationValue;
  final Color activeColor;
  final Color onSurfaceColor;
  
  _BarChartPainter({required this.data, required this.labels, required this.animationValue, required this.activeColor, required this.onSurfaceColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double barWidth = (size.width - (labels.length - 1) * 16) / labels.length;
    final double maxVal = data.reduce(math.max);
    
    for (int i = 0; i < data.length; i++) {
      final double barHeight = (data[i] / maxVal) * size.height * animationValue;
      final double left = i * (barWidth + 16);
      final double top = size.height - barHeight;
      
      final RRect rrect = RRect.fromLTRBR(
        left, top, left + barWidth, size.height,
        const Radius.circular(8),
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [activeColor, activeColor.withOpacity(0.4)],
        ).createShader(rrect.outerRect);

      canvas.drawRRect(rrect, paint);
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: onSurfaceColor.withOpacity(0.6)),
        ),
        textDirection: TextDirection.ltr,
      )..layout(minWidth: barWidth, maxWidth: barWidth);
      
      textPainter.paint(canvas, Offset(left, size.height + 8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
