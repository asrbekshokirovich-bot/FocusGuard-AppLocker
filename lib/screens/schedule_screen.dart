import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chuqur Fokus → Kengaytirilgan: kundalik tartib uchun vaqt oynasi
/// jadvallari. Har bir jadval belgilangan vaqt oynasida (masalan
/// 23:00–07:00) tanlangan ilovalarni bloklaydi. Jadvallar
/// `focus_schedules` kalitida JSON ro'yxat sifatida saqlanadi va
/// background service har tickda o'qib, faol oynada bloklashni qo'shadi.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const String _prefsKey = 'focus_schedules';

  // Jadval tanlovi uchun mashhur chalg'ituvchi ilovalar.
  static const List<Map<String, String>> _popularApps = [
    {'pkg': 'com.instagram.android', 'name': 'Instagram'},
    {'pkg': 'com.google.android.youtube', 'name': 'YouTube'},
    {'pkg': 'com.zhiliaoapp.musically', 'name': 'TikTok'},
    {'pkg': 'org.telegram.messenger', 'name': 'Telegram'},
    {'pkg': 'com.facebook.katana', 'name': 'Facebook'},
    {'pkg': 'com.snapchat.android', 'name': 'Snapchat'},
    {'pkg': 'com.twitter.android', 'name': 'X (Twitter)'},
  ];

  static const List<String> _dayLabels = [
    'Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'
  ];

  List<Map<String, dynamic>> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    List<Map<String, dynamic>> list = [];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _schedules = list;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_schedules));
  }

  String _fmt(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _daysSummary(List<dynamic> days) {
    if (days.isEmpty || days.length == 7) return 'Har kuni';
    final ds = days.map((e) => (e as num).toInt()).toList()..sort();
    return ds.map((d) => _dayLabels[d - 1]).join(', ');
  }

  Future<void> _openEditor({Map<String, dynamic>? existing, int? index}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleEditor(
        existing: existing,
        popularApps: _popularApps,
        dayLabels: _dayLabels,
      ),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _schedules[index] = result;
      } else {
        _schedules.add(result);
      }
    });
    await _save();
  }

  Future<void> _toggleEnabled(int index, bool value) async {
    setState(() => _schedules[index]['enabled'] = value);
    await _save();
  }

  Future<void> _delete(int index) async {
    setState(() => _schedules.removeAt(index));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text('Kengaytirilgan jadval',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primary.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.moon_stars_fill, color: primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Kundalik tartib uchun vaqt oynasi belgilang — masalan 23:00–07:00. Shu vaqtda tanlangan ilovalar avtomatik bloklanadi.',
                          style: GoogleFonts.inter(
                              fontSize: 12.5,
                              height: 1.35,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_schedules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('Hali jadval yo\'q. "+ Yangi jadval" bilan qo\'shing.',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                    ),
                  )
                else
                  ...List.generate(_schedules.length, (i) => _scheduleCard(i, primary)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _openEditor(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text('+ Yangi jadval',
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _scheduleCard(int i, Color primary) {
    final s = _schedules[i];
    final enabled = s['enabled'] == true;
    final apps = (s['apps'] as List?) ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s['name']?.toString() ?? 'Jadval',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface)),
              ),
              Switch.adaptive(
                value: enabled,
                activeColor: primary,
                onChanged: (v) => _toggleEnabled(i, v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(CupertinoIcons.clock, size: 15, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text('${_fmt((s['start'] as num).toInt())} – ${_fmt((s['end'] as num).toInt())}',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primary)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_daysSummary((s['days'] as List?) ?? []),
                    style: GoogleFonts.inter(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(CupertinoIcons.shield_lefthalf_fill, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45)),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${apps.length} ta ilova bloklanadi',
                    style: GoogleFonts.inter(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55))),
              ),
              GestureDetector(
                onTap: () => _openEditor(existing: s, index: i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('Tahrirlash', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: primary)),
                ),
              ),
              GestureDetector(
                onTap: () => _delete(i),
                child: Icon(CupertinoIcons.delete, size: 18, color: const Color(0xFFFF3B30).withOpacity(0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleEditor extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<Map<String, String>> popularApps;
  final List<String> dayLabels;
  const _ScheduleEditor({this.existing, required this.popularApps, required this.dayLabels});

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late TextEditingController _nameCtrl;
  int _start = 23 * 60;
  int _end = 7 * 60;
  Set<int> _days = {1, 2, 3, 4, 5};
  Set<String> _apps = {};

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name']?.toString() ?? 'Tungi rejim');
    if (e != null) {
      _start = (e['start'] as num?)?.toInt() ?? _start;
      _end = (e['end'] as num?)?.toInt() ?? _end;
      _days = ((e['days'] as List?) ?? []).map((x) => (x as num).toInt()).toSet();
      _apps = ((e['apps'] as List?) ?? []).map((x) => x.toString()).toSet();
    } else {
      // Standart: barcha mashhur ilovalar tanlangan.
      _apps = widget.popularApps.map((a) => a['pkg']!).toSet();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = TimeOfDay(hour: (isStart ? _start : _end) ~/ 60, minute: (isStart ? _start : _end) % 60);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        final mins = picked.hour * 60 + picked.minute;
        if (isStart) {
          _start = mins;
        } else {
          _end = mins;
        }
      });
    }
  }

  String _fmt(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Jadval', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.inter(fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Nomi',
                labelStyle: GoogleFonts.inter(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _timeBox('Boshlanish', _start, () => _pickTime(true), primary)),
                const SizedBox(width: 12),
                Expanded(child: _timeBox('Tugash', _end, () => _pickTime(false), primary)),
              ],
            ),
            if (_start == _end)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Boshlanish va tugash bir xil bo\'lmasligi kerak',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFFF3B30))),
              ),
            const SizedBox(height: 16),
            Text('Kunlar', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = i + 1;
                final on = _days.contains(day);
                return GestureDetector(
                  onTap: () => setState(() => on ? _days.remove(day) : _days.add(day)),
                  child: Container(
                    width: 38, height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? primary.withOpacity(0.12) : Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: on ? primary : Colors.grey.withOpacity(0.25)),
                    ),
                    child: Text(widget.dayLabels[i],
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: on ? primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Text('Bloklanadigan ilovalar', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
            const SizedBox(height: 8),
            ...widget.popularApps.map((a) {
              final pkg = a['pkg']!;
              final on = _apps.contains(pkg);
              return GestureDetector(
                onTap: () => setState(() => on ? _apps.remove(pkg) : _apps.add(pkg)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: on ? primary.withOpacity(0.4) : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(a['name']!, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500))),
                      Icon(on ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                          color: on ? primary : Colors.grey.withOpacity(0.4), size: 22),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                if (_start == _end) return;
                final result = {
                  'id': widget.existing?['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': _nameCtrl.text.trim().isEmpty ? 'Jadval' : _nameCtrl.text.trim(),
                  'start': _start,
                  'end': _end,
                  'days': _days.toList()..sort(),
                  'apps': _apps.toList(),
                  'enabled': widget.existing?['enabled'] ?? true,
                };
                Navigator.pop(context, result);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _start == _end ? Colors.grey : primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text('Saqlash', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeBox(String label, int minutes, VoidCallback onTap, Color primary) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            const SizedBox(height: 2),
            Text(_fmt(minutes), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: primary)),
          ],
        ),
      ),
    );
  }
}
