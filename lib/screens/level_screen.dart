import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/app_translation_service.dart';
import '../services/level_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Real data variables will be used from StreamBuilder

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
        return StreamBuilder<DocumentSnapshot>(
          stream: LevelService().getUserStatsStream(),
          builder: (context, snapshot) {
            int xp = 0;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              xp = (data['xp'] as num?)?.toInt() ?? 0;
            }

            // Yagona helper'dan barcha daraja ma'lumotlarini olamiz.
            final info = LevelService.levelInfoFromXp(xp);
            final int level = info.level;
            final double progress = info.progress;

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
                          _buildCurrentStatusCard(lang, level, progress, xp),
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
                          _buildLevelsList(lang, level),
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

  Widget _buildCurrentStatusCard(AppTranslationService lang, int currentLevel,
      double currentProgress, int xp) {
    String rankTitle = LevelService().getRankTitle(currentLevel, lang);
    // Yagona helper'dan ma'lumot olamiz — formula bir joyda (LevelService).
    // 1 daqiqa fokus = 10 XP. Daraja chegaralari level_service.dart'da.
    final info = LevelService.levelInfoFromXp(xp);
    final currentLevelXp = info.currentLevelXp;
    final currentLevelMinutes = currentLevelXp ~/ 10;
    final remainingMinutes = info.remainingXp ~/ 10;
    final minLabel = lang.translate('focus_timer.min') ?? 'daq';
    final hourLabel = lang.translate('levels.hour_suffix') ?? 's';

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
      child: Stack(
        children: [
          Column(
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
                rankTitle,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                lang.translate('levels.level') + ' $currentLevel',
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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                  Text(
                    '${(currentProgress * 100).toInt()}%',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: currentProgress,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                info.isMaxLevel
                    ? (lang.translate('levels.max_reached') ??
                        'Eng yuqori darajaga yetdingiz! 🏆')
                    : _formatRemainingTime(
                        remainingMinutes, hourLabel, minLabel, lang),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          // Top-right XP badge — joriy XP va uning daqiqalar ekvivalenti.
          // 1 daqiqa = 10 XP formulasiga asoslangan, foydalanuvchiga
          // qancha daqiqa fokus qilganini ko'rsatadi.
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.star_fill,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$currentLevelXp XP',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$currentLevelMinutes $minLabel',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Qolgan vaqtni "1 s 25 daq" yoki "45 daq" yoki "2 s" ko'rinishida
  /// formatlash. Avval "1.4 soat" deb ko'rinardi — bu noqulay edi.
  String _formatRemainingTime(int remainingMinutes, String hourLabel,
      String minLabel, AppTranslationService lang) {
    final h = remainingMinutes ~/ 60;
    final m = remainingMinutes % 60;
    String timeStr;
    if (h == 0) {
      timeStr = '$m $minLabel';
    } else if (m == 0) {
      timeStr = '$h $hourLabel';
    } else {
      timeStr = '$h $hourLabel $m $minLabel';
    }
    // `levels.remaining_time` — yangi key, formatlangan vaqtni qabul qiladi.
    // Eski `remaining_hours` o'rniga ishlatamiz.
    final template = lang.translate('levels.remaining_time');
    if (template != null && template.contains('{time}')) {
      return template.replaceAll('{time}', timeStr);
    }
    return 'Keyingi darajagacha $timeStr qoldi';
  }

  Widget _buildLevelsList(AppTranslationService lang, int currentLevel) {
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
        final bool isCurrent = level['level'] == currentLevel;
        final bool isUnlocked = level['level'] <= currentLevel;

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
