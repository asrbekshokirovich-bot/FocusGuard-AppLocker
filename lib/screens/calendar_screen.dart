import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/app_translation_service.dart';
import '../services/focus_history_service.dart';

/// Mening Kalendarim — foydalanuvchining kunlik fokus tarixini
/// vizual ko'rsatadi. Har bir kun uchun ✅ yoki ❌ chiqadi (joriy
/// kunning maqsadiga erishganmi yo'qmi).
///
/// Ma'lumot manbai — `FocusHistoryService`. Bu sahifa hech qachon
/// to'g'ridan-to'g'ri SharedPreferences'ga tegmaydi — har doim
/// service orqali ishlaydi.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _displayedMonth;
  Map<int, DayRecord> _records = {};
  MonthSummary _summary = const MonthSummary(focused: 0, missed: 0);
  int _streak = 0;
  bool _loading = true;
  // Bugungi maqsad va progress — tepa qismida alohida ko'rsatiladi
  DayRecord? _todayRecord;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await FocusHistoryService.instance.getMonthRecords(
      _displayedMonth.year,
      _displayedMonth.month,
    );
    final summary = await FocusHistoryService.instance.getMonthSummary(
      _displayedMonth.year,
      _displayedMonth.month,
    );
    final streak = await FocusHistoryService.instance.getStreak();
    final today = await FocusHistoryService.instance.getDay(DateTime.now());
    if (!mounted) return;
    setState(() {
      _records = records;
      _summary = summary;
      _streak = streak;
      _todayRecord = today;
      _loading = false;
    });
  }

  void _prevMonth() {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final candidate =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    // Kelajak oyga chiqib ketmaymiz (foydasi yo'q — bo'sh).
    if (candidate.isAfter(DateTime(now.year, now.month + 1, 1))) return;
    setState(() {
      _displayedMonth = candidate;
    });
    _load();
  }

  String _monthName(int month, AppTranslationService lang) {
    final keys = [
      'calendar.month_jan',
      'calendar.month_feb',
      'calendar.month_mar',
      'calendar.month_apr',
      'calendar.month_may',
      'calendar.month_jun',
      'calendar.month_jul',
      'calendar.month_aug',
      'calendar.month_sep',
      'calendar.month_oct',
      'calendar.month_nov',
      'calendar.month_dec',
    ];
    return lang.translate(keys[month - 1]) ??
        ['Yan', 'Fev', 'Mar', 'Apr', 'May', 'Iyn', 'Iyl', 'Avg', 'Sen', 'Okt', 'Noy', 'Dek'][month - 1];
  }

  List<String> _weekdayShortNames(AppTranslationService lang) {
    // Du, Se, Ch, Pa, Ju, Sh, Ya
    return [
      lang.translate('calendar.wd_mon') ?? 'Du',
      lang.translate('calendar.wd_tue') ?? 'Se',
      lang.translate('calendar.wd_wed') ?? 'Ch',
      lang.translate('calendar.wd_thu') ?? 'Pa',
      lang.translate('calendar.wd_fri') ?? 'Ju',
      lang.translate('calendar.wd_sat') ?? 'Sh',
      lang.translate('calendar.wd_sun') ?? 'Ya',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppTranslationService();
    return ValueListenableBuilder<String>(
      valueListenable: lang.languageNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              lang.translate('calendar.title') ?? 'Mening Kalendarim',
              style: lang.getFont(fontWeight: FontWeight.w800),
            ),
            elevation: 0,
            backgroundColor: Theme.of(context).colorScheme.surface,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Bugungi maqsad va progress — tepada alohida karta.
                      // Foydalanuvchi Calendar'ga kirishi bilan bugungi
                      // maqsadi nima va qancha bajarganini darrov ko'radi.
                      _buildTodayCard(lang),
                      const SizedBox(height: 12),
                      _buildMonthHeader(lang),
                      const SizedBox(height: 12),
                      _buildWeekdayHeader(lang),
                      const SizedBox(height: 8),
                      Expanded(child: _buildCalendarGrid(lang)),
                      const SizedBox(height: 12),
                      _buildLegend(lang),
                      const SizedBox(height: 12),
                      _buildSummaryRow(lang),
                    ],
                  ),
                ),
        );
      },
    );
  }

  /// Sekundlarni "5s 45d" yoki "45d" yoki "5s" formatiga aylantirish.
  /// Calendar bugungi karta va boshqa joylarda foydalanuvchi tushunarli
  /// formatda ko'rsatish uchun.
  String _formatSecondsToHm(int seconds) {
    if (seconds <= 0) return '0d';
    final totalMinutes = seconds ~/ 60;
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}d';
    if (m == 0) return '${h}s';
    return '${h}s ${m}d';
  }

  /// Bugungi maqsad va progress kartasi. Calendar tepasida turadi,
  /// foydalanuvchi maqsadi nima va qancha bajarganini darrov ko'radi.
  Widget _buildTodayCard(AppTranslationService lang) {
    final rec = _todayRecord;
    // Agar today_focus_seconds yoki daily_goal_seconds saqlanmagan
    // bo'lsa (ilova hali ishlatilmagan), default qiymatlar bilan
    // ko'rsatamiz.
    final seconds = rec?.seconds ?? 0;
    final goal = (rec?.goal ?? 14400);
    final met = rec?.met ?? false;
    final percent = goal > 0
        ? ((seconds / goal) * 100).clamp(0.0, 100.0)
        : 0.0;
    final progressRatio = goal > 0
        ? (seconds / goal).clamp(0.0, 1.0)
        : 0.0;

    final Color accent = met
        ? const Color(0xFF34C759)
        : const Color(0xFF007AFF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: met
              ? [
                  const Color(0xFF34C759).withOpacity(0.18),
                  const Color(0xFF34C759).withOpacity(0.06),
                ]
              : [
                  const Color(0xFF007AFF).withOpacity(0.15),
                  const Color(0xFF007AFF).withOpacity(0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  met ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.flag_fill,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.translate('calendar.today_goal') ?? 'Bugungi maqsad',
                      style: lang.getFont(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_formatSecondsToHm(seconds)} / ${_formatSecondsToHm(goal)}',
                        maxLines: 1,
                        style: lang.getFont(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${percent.toInt()}%',
                  style: lang.getFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressRatio,
              backgroundColor: accent.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(AppTranslationService lang) {
    final now = DateTime.now();
    final isFuture = _displayedMonth.isAfter(DateTime(now.year, now.month, 1));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _prevMonth,
            icon: const Icon(CupertinoIcons.chevron_left),
          ),
          Text(
            '${_monthName(_displayedMonth.month, lang)} ${_displayedMonth.year}',
            style: lang.getFont(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          IconButton(
            onPressed: isFuture ? null : _nextMonth,
            icon: Icon(CupertinoIcons.chevron_right,
                color: isFuture ? Colors.grey : null),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader(AppTranslationService lang) {
    final names = _weekdayShortNames(lang);
    return Row(
      children: names
          .map((n) => Expanded(
                child: Center(
                  child: Text(
                    n,
                    style: lang.getFont(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid(AppTranslationService lang) {
    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    // DateTime.weekday: Monday=1 ... Sunday=7. Bizning grid Mondaydan
    // boshlanadi, shuning uchun 1-Du, 7-Ya.
    final leadingEmpty = firstOfMonth.weekday - 1;
    final daysInMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.95,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        if (index < leadingEmpty || index >= leadingEmpty + daysInMonth) {
          return const SizedBox.shrink();
        }
        final day = index - leadingEmpty + 1;
        final cellDate = DateTime(_displayedMonth.year, _displayedMonth.month, day);
        final isToday = cellDate == today;
        final isFuture = cellDate.isAfter(today);
        final record = _records[day];
        return _buildDayCell(day, record, isToday, isFuture);
      },
    );
  }

  Widget _buildDayCell(int day, DayRecord? record, bool isToday, bool isFuture) {
    Color background;
    Widget? indicator;

    // Bugungi kun uchun PROGRESS indikator: agar foydalanuvchi maqsadni
    // hali to'liq bajarmagan, lekin biroz fokus qilgan bo'lsa — foiz
    // (masalan "32%") ko'rsatamiz. To'liq bajargan bo'lsa ✅. Hech
    // narsa qilmagan bo'lsa just ko'k chiziq (today border).
    if (isFuture) {
      // Kelajak — yengil kulrang
      background = Theme.of(context).colorScheme.onSurface.withOpacity(0.04);
      indicator = null;
    } else if (isToday) {
      // Bugun — alohida logika: progress'ga qarab indikator
      if (record == null || record.seconds == 0) {
        // Hali boshlanmagan — ko'k border bilan, ichida hech narsa yo'q
        background = const Color(0xFF007AFF).withOpacity(0.06);
        indicator = null;
      } else if (record.met) {
        // Bugun maqsad bajarildi
        background = const Color(0xFF34C759).withOpacity(0.18);
        indicator = const Icon(
          CupertinoIcons.checkmark_alt,
          color: Color(0xFF34C759),
          size: 16,
        );
      } else {
        // Bugun qisman bajarilgan — foiz ko'rsatamiz
        final percent =
            ((record.seconds / record.goal) * 100).clamp(0, 99).toInt();
        background = const Color(0xFF007AFF).withOpacity(0.12);
        indicator = Text(
          '$percent%',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Color(0xFF007AFF),
          ),
        );
      }
    } else if (record == null) {
      // O'tgan kun, lekin ma'lumot yo'q — qoraroq kulrang
      background = Theme.of(context).colorScheme.onSurface.withOpacity(0.06);
      indicator = const Icon(
        CupertinoIcons.minus,
        color: Color(0xFF8E8E93),
        size: 14,
      );
    } else if (record.met) {
      background = const Color(0xFF34C759).withOpacity(0.18);
      indicator = const Icon(
        CupertinoIcons.checkmark_alt,
        color: Color(0xFF34C759),
        size: 16,
      );
    } else {
      background = const Color(0xFFFF3B30).withOpacity(0.12);
      indicator = const Icon(
        CupertinoIcons.xmark,
        color: Color(0xFFFF3B30),
        size: 14,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: isToday
            ? Border.all(color: const Color(0xFF007AFF), width: 2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: isFuture
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.35)
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 16,
            child: indicator ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(AppTranslationService lang) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 8,
      children: [
        _legendItem(
          color: const Color(0xFF34C759),
          icon: CupertinoIcons.checkmark_alt,
          label: lang.translate('calendar.legend_focused') ?? 'Fokusladim',
          lang: lang,
        ),
        _legendItem(
          color: const Color(0xFFFF3B30),
          icon: CupertinoIcons.xmark,
          label: lang.translate('calendar.legend_missed') ?? "Bo'shashdim",
          lang: lang,
        ),
        _legendItem(
          color: const Color(0xFF007AFF),
          icon: CupertinoIcons.calendar_today,
          label: lang.translate('calendar.legend_today') ?? 'Bugun',
          lang: lang,
        ),
      ],
    );
  }

  Widget _legendItem({
    required Color color,
    required IconData icon,
    required String label,
    required AppTranslationService lang,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 12),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: lang.getFont(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(AppTranslationService lang) {
    final monthSummary =
        '${_summary.focused} ✓  /  ${_summary.missed} ✗';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.translate('calendar.this_month') ?? 'Bu oy',
                style: lang.getFont(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                monthSummary,
                style: lang.getFont(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                lang.translate('calendar.streak_label') ?? 'Uzluksiz kunlar',
                style: lang.getFont(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(CupertinoIcons.flame_fill,
                      color: Color(0xFFFF9500), size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$_streak',
                    style: lang.getFont(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFF9500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
