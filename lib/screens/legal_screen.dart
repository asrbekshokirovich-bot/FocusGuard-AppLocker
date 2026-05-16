import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import '../services/language_service.dart';

class LegalScreen extends StatefulWidget {
  /// Til tanlash chiplarini ko'rsatish. Login/register'da false (foydalanuvchi
  /// onboarding'da til tanlagan), Profil ichidan ochilganda true.
  final bool showLanguageSwitcher;
  const LegalScreen({super.key, this.showLanguageSwitcher = false});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  // Lokal til — faqat shu ekran uchun. Ilova umumiy tiliga tegmaydi.
  // Initial: ilovaning joriy tili.
  late String _displayLang = LanguageService().currentLanguage;

  /// Tanlangan tilda tarjima — global tilga ta'sir qilmaydi.
  dynamic _t(String key) =>
      LanguageService().translateInLang(key, _displayLang);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          // Pinned Header Block
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10, // Higher header
              left: 32,
              right: 32,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.back, color: Colors.black, size: 22),
                          const SizedBox(width: 4),
                          Text(
                            _t('legal.close') ?? 'Close',
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Til tanlash chiplari — faqat Profil orqali ochilganda.
                    if (widget.showLanguageSwitcher) _buildLanguageChips(),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _t('legal.title') ?? 'Legal',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                    color: Colors.black,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...(((_t('legal.sections') ?? []) as List)
                      .map((section) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: _buildSection(
                            context,
                            section['title'],
                            section['content'],
                          ),
                        );
                      })),
                  const SizedBox(height: 48),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.shield_fill,
                          size: 14,
                          color: Colors.black.withOpacity(0.3),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Focus Guard',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.black.withOpacity(0.3),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3 til chiplari — faqat Profil'dan ochilganda ko'rinadi. Bosilsa
  /// faqat shu ekranda til o'zgaradi. Ilova umumiy tiliga tegmaydi.
  Widget _buildLanguageChips() {
    const langs = [
      {'code': 'uz', 'label': 'O\'z'},
      {'code': 'ru', 'label': 'Ру'},
      {'code': 'en', 'label': 'En'},
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: langs.map((l) {
        final selected = _displayLang == l['code'];
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GestureDetector(
            onTap: () =>
                setState(() => _displayLang = l['code']!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF007AFF)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                l['label']!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: const Color(0xFF007AFF),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: GoogleFonts.inter(
            fontSize: 15,
            height: 1.6,
            color: Colors.black.withOpacity(0.8),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
