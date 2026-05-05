import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_translation_service.dart';


class InterfaceLanguageScreen extends StatefulWidget {
  const InterfaceLanguageScreen({super.key});

  @override
  State<InterfaceLanguageScreen> createState() => _InterfaceLanguageScreenState();
}

class _InterfaceLanguageScreenState extends State<InterfaceLanguageScreen> {
  final List<Map<String, String>> _languages = [
    {'code': 'uz', 'name': 'O\'zbekcha'},
    {'code': 'en', 'name': 'English'},
    {'code': 'ru', 'name': 'Русский'},
    {'code': 'ko', 'name': '한국어'},
    {'code': 'de', 'name': 'Deutsch'},
    {'code': 'fr', 'name': 'Français'},
  ];

  void _onLanguageTap(String code) async {
    await AppTranslationService().setLanguage(code);
    // Til o'zgargandan so'ng UI-ni yangilash uchun biroz kutamiz yoki shunchaki notification yuboramiz
  }

  @override
  Widget build(BuildContext context) {
    final translationService = AppTranslationService();
    return ValueListenableBuilder<String>(
      valueListenable: translationService.languageNotifier,
      builder: (context, currentLang, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(translationService),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(translationService.translate('settings.language.section_title')),
                      _buildLanguageList(currentLang),
                      const SizedBox(height: 40),
                      _buildNotice(translationService),
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

  Widget _buildSliverAppBar(AppTranslationService translationService) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF007AFF),
      leading: IconButton(
        icon: const Icon(CupertinoIcons.left_chevron, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          translationService.translate('settings.language.title'),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        background: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -50,
              top: -20,
              child: Icon(
                CupertinoIcons.globe,
                size: 200,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: AppTranslationService().getFont(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8E8E93),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLanguageList(String currentLang) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: _languages.asMap().entries.map((entry) {
          final index = entry.key;
          final lang = entry.value;
          final isSelected = currentLang == lang['code'];
          final isLast = index == _languages.length - 1;

          return Column(
            children: [
              _buildLanguageItem(lang, isSelected),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Colors.grey.withOpacity(0.1),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLanguageItem(Map<String, String> lang, bool isSelected) {
    final translationService = AppTranslationService();
    return InkWell(
      onTap: () => _onLanguageTap(lang['code']!),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lang['name']!,
                style: translationService.getFont(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF007AFF)
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: Color(0xFF007AFF),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotice(AppTranslationService translationService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF007AFF).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.info_circle_fill,
            color: Color(0xFF007AFF),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              translationService.translate('settings.language.notice'),
              style: AppTranslationService().getFont(
                fontSize: 14,
                color: const Color(0xFF8E8E93),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
