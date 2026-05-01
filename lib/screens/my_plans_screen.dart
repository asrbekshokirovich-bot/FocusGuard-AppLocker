import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/app_translation_service.dart';

class MyPlansScreen extends StatefulWidget {
  const MyPlansScreen({super.key});

  @override
  State<MyPlansScreen> createState() => _MyPlansScreenState();
}

class _MyPlansScreenState extends State<MyPlansScreen> {
  final lang = AppTranslationService();
  
  final List<Map<String, String>> _plans = [
    {'title': 'Dasturlash darsi', 'time': '30.04.2026 10:00', 'status': 'plans.status_upcoming'},
    {'title': 'Kitob o\'qish', 'time': '01.05.2026 15:30', 'status': 'plans.status_upcoming'},
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: lang.languageNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      left: 20,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.left_chevron, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      right: 20,
                      child: GestureDetector(
                        onTap: () => _showAddPlanDialog(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.plus, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          const FaIcon(FontAwesomeIcons.calendarCheck, color: Colors.white, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            lang.translate('plans.title'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPremiumNotice(),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lang.translate('plans.today_plans'), 
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                lang.translate('plans.count_suffix').replaceAll('{count}', _plans.length.toString()), 
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._plans.map((plan) => _buildPlanItem(plan)).toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildPremiumNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9500).withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const FaIcon(FontAwesomeIcons.circleInfo, color: Color(0xFFFF9500), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lang.translate('plans.notice'),
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8B5E00), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanItem(Map<String, String> plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: FaIcon(FontAwesomeIcons.clock, color: Theme.of(context).primaryColor, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan['title']!, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                Text(
                  lang.translate(plan['status']!), 
                  style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(plan['time']!, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Theme.of(context).primaryColor)),
              const FaIcon(FontAwesomeIcons.bell, color: Color(0xFFFF3B30), size: 12),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddPlanDialog() {
    final titleController = TextEditingController();
    final dayController = TextEditingController();
    final monthController = TextEditingController();
    final yearController = TextEditingController();
    final hourController = TextEditingController();
    final minuteController = TextEditingController();

    DateTime now = DateTime.now();
    dayController.text = now.day.toString().padLeft(2, '0');
    monthController.text = now.month.toString().padLeft(2, '0');
    yearController.text = now.year.toString();
    hourController.text = now.hour.toString().padLeft(2, '0');
    minuteController.text = now.minute.toString().padLeft(2, '0');

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: anim1.value * 10, sigmaY: anim1.value * 10),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: const Offset(0, 0.48)).animate(anim1),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                String previewText = "";

                void updatePreview() {
                  if (dayController.text.length == 2 &&
                      monthController.text.length == 2 &&
                      yearController.text.length == 4 &&
                      hourController.text.length == 2 &&
                      minuteController.text.length == 2) {
                    try {
                      int d = int.parse(dayController.text);
                      int m = int.parse(monthController.text);
                      int y = int.parse(yearController.text);
                      int hh = int.parse(hourController.text);
                      int mm = int.parse(minuteController.text);
                      
                      if (m < 1 || m > 12 || d < 1 || d > 31 || hh > 23 || mm > 59) {
                        setDialogState(() => previewText = lang.translate('plans.error_date'));
                        return;
                      }

                      DateTime target = DateTime(y, m, d, hh, mm);
                      DateTime now = DateTime.now();
                      DateTime currentMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
                      
                      int diffDays = DateTime(target.year, target.month, target.day)
                          .difference(DateTime(now.year, now.month, now.day))
                          .inDays;
                      
                      List<dynamic> weekdays = lang.translate('plans.weekdays');
                      String dayName = weekdays[target.weekday];
                      
                      String relative = "";
                      if (diffDays == 0) relative = lang.translate('plans.today');
                      else if (diffDays == 1) relative = lang.translate('plans.tomorrow');
                      else if (diffDays > 1) relative = lang.translate('plans.days_later').replaceAll('{days}', diffDays.toString());
                      else relative = lang.translate('plans.days_ago').replaceAll('{days}', diffDays.abs().toString());

                      setDialogState(() {
                        if (target.isBefore(currentMinute)) {
                          previewText = "${lang.translate('plans.error_past')} ($relative, $dayName)";
                        } else {
                          previewText = "$relative, $dayName, $hh:$mm";
                        }
                      });
                    } catch (e) {
                      setDialogState(() => previewText = lang.translate('plans.error_date'));
                    }
                  } else {
                    setDialogState(() => previewText = "");
                  }
                }

                updatePreview();

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(lang.translate('plans.cancel'), style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 15)),
                            ),
                            Text(lang.translate('plans.new_plan'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17, color: Theme.of(context).colorScheme.onSurface)),
                            TextButton(
                              onPressed: () {
                                if (titleController.text.isNotEmpty &&
                                    dayController.text.length == 2 &&
                                    monthController.text.length == 2 &&
                                    yearController.text.length == 4 &&
                                    hourController.text.length == 2 &&
                                    minuteController.text.length == 2) {
                                  
                                  setState(() {
                                    _plans.add({
                                      'title': titleController.text,
                                      'time': "${dayController.text}.${monthController.text}.${yearController.text} ${hourController.text}:${minuteController.text}",
                                      'status': 'plans.status_upcoming',
                                    });
                                  });
                                  Navigator.pop(context);
                                }
                              },
                              child: Text(lang.translate('plans.done'), style: GoogleFonts.inter(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(lang.translate('plans.plan_name'), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                        const SizedBox(height: 6),
                        CupertinoTextField(
                          controller: titleController,
                          placeholder: lang.translate('plans.plan_name_hint'),
                          placeholderStyle: GoogleFonts.inter(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lang.translate('plans.date'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildSmallField(dayController, '00', 2, updatePreview),
                                _buildSeparator('.'),
                                _buildSmallField(monthController, '00', 2, updatePreview),
                                _buildSeparator('.'),
                                _buildSmallField(yearController, '0000', 4, updatePreview, width: 60),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () {
                                    showCupertinoModalPopup(
                                      context: context,
                                      builder: (context) => Container(
                                        height: 300,
                                        color: CupertinoColors.systemBackground.resolveFrom(context),
                                        child: SafeArea(
                                          top: false,
                                          child: Column(
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[50],
                                                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    CupertinoButton(
                                                      child: Text(lang.translate('plans.cancel'), style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 16)),
                                                      onPressed: () => Navigator.pop(context),
                                                    ),
                                                    CupertinoButton(
                                                      child: Text(lang.translate('plans.done'), style: GoogleFonts.inter(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                                      onPressed: () => Navigator.pop(context),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: CupertinoDatePicker(
                                                  mode: CupertinoDatePickerMode.date,
                                                  initialDateTime: DateTime.now(),
                                                  onDateTimeChanged: (picked) {
                                                    setDialogState(() {
                                                      dayController.text = picked.day.toString().padLeft(2, '0');
                                                      monthController.text = picked.month.toString().padLeft(2, '0');
                                                      yearController.text = picked.year.toString();
                                                      updatePreview();
                                                    });
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Icon(CupertinoIcons.calendar, color: Theme.of(context).primaryColor, size: 22),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lang.translate('plans.time'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildSmallField(hourController, '00', 2, updatePreview),
                                _buildSeparator(':'),
                                _buildSmallField(minuteController, '00', 2, updatePreview),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () {
                                    showCupertinoModalPopup(
                                      context: context,
                                      builder: (context) => Container(
                                        height: 300,
                                        color: CupertinoColors.systemBackground.resolveFrom(context),
                                        child: SafeArea(
                                          top: false,
                                          child: Column(
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[50],
                                                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    CupertinoButton(
                                                      child: Text(lang.translate('plans.cancel'), style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 16)),
                                                      onPressed: () => Navigator.pop(context),
                                                    ),
                                                    CupertinoButton(
                                                      child: Text(lang.translate('plans.done'), style: GoogleFonts.inter(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                                      onPressed: () => Navigator.pop(context),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: CupertinoDatePicker(
                                                  mode: CupertinoDatePickerMode.time,
                                                  use24hFormat: true,
                                                  initialDateTime: DateTime.now(),
                                                  onDateTimeChanged: (picked) {
                                                    setDialogState(() {
                                                      hourController.text = picked.hour.toString().padLeft(2, '0');
                                                      minuteController.text = picked.minute.toString().padLeft(2, '0');
                                                      updatePreview();
                                                    });
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Icon(CupertinoIcons.clock, color: Theme.of(context).primaryColor, size: 22),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (previewText.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: (previewText.contains(lang.translate('plans.error_date')) || previewText.contains(lang.translate('plans.error_past'))) ? Colors.red.withOpacity(0.1) : Theme.of(context).primaryColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              previewText,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: (previewText.contains(lang.translate('plans.error_date')) || previewText.contains(lang.translate('plans.error_past'))) ? Colors.red : Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmallField(TextEditingController controller, String hint, int maxLen, VoidCallback onChanged, {double width = 50}) {
    return SizedBox(
      width: width,
      child: CupertinoTextField(
        controller: controller,
        placeholder: hint,
        textAlign: TextAlign.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        keyboardType: TextInputType.number,
        maxLength: maxLen,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (val) {
          if (val.length == maxLen) FocusScope.of(context).nextFocus();
          onChanged();
        },
      ),
    );
  }

  Widget _buildSeparator(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(text, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[400])),
    );
  }
}
