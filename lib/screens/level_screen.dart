import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/app_translation_service.dart';

class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  final double _currentProgress = 0.45; // 45% progress to next level
  final int _currentLevel = 4;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _progressAnimation = Tween<double>(begin: 0, end: _currentProgress).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
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
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(lang),
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCurrentStatusCard(lang),
                      const SizedBox(height: 16),
                      Text(
                        lang.translate('levels.all_levels'),
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildLevelsList(lang),
                      const SizedBox(height: 32),
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
          lang.translate('levels.title'),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 16,
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
                colors: [Theme.of(context).primaryColor, const Color(0xFF434190)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(
                    CupertinoIcons.graph_square_fill,
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

  Widget _buildCurrentStatusCard(AppTranslationService lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: FaIcon(
              FontAwesomeIcons.medal,
              color: Theme.of(context).primaryColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            lang.translate('levels.master'),
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            lang.translate('levels.level') + ' $_currentLevel',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.translate('levels.progress'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                '${(_currentProgress * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _progressAnimation.value,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  minHeight: 10,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            lang.translate('levels.remaining_hours').replaceAll('{hours}', '4.5'),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelsList(AppTranslationService lang) {
    final List<Map<String, dynamic>> levels = [
      {'level': 1, 'name': lang.translate('levels.rank_1'), 'hours': '0-1 ${lang.translate('levels.hour_suffix')}', 'unlocked': true},
      {'level': 2, 'name': lang.translate('levels.rank_2'), 'hours': '1-3 ${lang.translate('levels.hour_suffix')}', 'unlocked': true},
      {'level': 3, 'name': lang.translate('levels.rank_3'), 'hours': '3-7 ${lang.translate('levels.hour_suffix')}', 'unlocked': true},
      {'level': 4, 'name': lang.translate('levels.rank_4'), 'hours': '7-15 ${lang.translate('levels.hour_suffix')}', 'unlocked': true},
      {'level': 5, 'name': lang.translate('levels.rank_5'), 'hours': '15-30 ${lang.translate('levels.hour_suffix')}', 'unlocked': false},
      {'level': 6, 'name': lang.translate('levels.rank_6'), 'hours': '30-50 ${lang.translate('levels.hour_suffix')}', 'unlocked': false},
      {'level': 7, 'name': lang.translate('levels.rank_7'), 'hours': '50-80 ${lang.translate('levels.hour_suffix')}', 'unlocked': false},
      {'level': 8, 'name': lang.translate('levels.rank_8'), 'hours': '80-120 ${lang.translate('levels.hour_suffix')}', 'unlocked': false},
      {'level': 9, 'name': lang.translate('levels.rank_9'), 'hours': '120-180 ${lang.translate('levels.hour_suffix')}', 'unlocked': false},
      {'level': 10, 'name': lang.translate('levels.rank_10'), 'hours': '180-250 ${lang.translate('levels.hour_suffix')}', 'unlocked': false},
      {'level': 11, 'name': lang.translate('levels.rank_11'), 'hours': '250-400 ${lang.translate('levels.hour_suffix')}', 'unlocked': false},
      {'level': 12, 'name': lang.translate('levels.rank_12'), 'hours': '400-600 ${lang.translate('levels.hour_suffix')}', 'unlocked': false},
      {'level': 13, 'name': lang.translate('levels.rank_13'), 'hours': '600-900 ${lang.translate('levels.hour_suffix')}', 'unlocked': false},
      {'level': 14, 'name': lang.translate('levels.rank_14'), 'hours': '900-1300 ${lang.translate('levels.hour_suffix')}', 'unlocked': false},
      {'level': 15, 'name': lang.translate('levels.rank_15'), 'hours': '1300-1800 ${lang.translate('levels.hour_suffix')}', 'unlocked': false},
      {'level': 16, 'name': lang.translate('levels.rank_16'), 'hours': '1800+ ${lang.translate('levels.hour_suffix')}', 'unlocked': false},
    ];

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: levels.length,
      itemBuilder: (context, index) {
        final level = levels[index];
        final bool isCurrent = level['level'] == _currentLevel;
        final bool isUnlocked = level['unlocked'];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrent ? Theme.of(context).primaryColor.withOpacity(0.05) : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCurrent ? Theme.of(context).primaryColor.withOpacity(0.3) : Colors.transparent,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isUnlocked 
                      ? (isCurrent ? Theme.of(context).primaryColor : Theme.of(context).primaryColor.withOpacity(0.1))
                      : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isUnlocked 
                      ? Text(
                          '${level['level']}',
                          style: GoogleFonts.inter(
                            color: isCurrent ? Colors.white : Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : const Icon(CupertinoIcons.lock_fill, size: 18, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level['name'],
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                      ),
                    ),
                    Text(
                      level['hours'],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    lang.translate('levels.current_tag'),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (!isUnlocked)
                const Icon(CupertinoIcons.lock_circle, color: Colors.grey, size: 24),
            ],
          ),
        );
      },
    );
  }
}
