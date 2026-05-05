import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/language_service.dart';
import 'onboarding_screen.dart';

class LanguageScreen extends StatefulWidget {
  final bool isSettings;
  const LanguageScreen({super.key, this.isSettings = false});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = LanguageService().currentLanguage;

  final List<Map<String, String>> _languages = [
    {
      'code': 'uz',
      'name': 'O\'zbekcha',
      'asset': 'assets/uz.png',
      'emoji': '🇺🇿',
    },
    {
      'code': 'en',
      'name': 'English',
      'asset': 'assets/us.png',
      'emoji': '🇺🇸',
    },
    {
      'code': 'ru',
      'name': 'Русский',
      'asset': 'assets/ru.png',
      'emoji': '🇷🇺',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Entrance screen - strictly LIGHT MODE for design stability
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.isSettings)
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8),
                  child: IconButton(
                    icon: const Icon(CupertinoIcons.back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      if (!widget.isSettings) ...[
                        const SizedBox(height: 40),
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.translate,
                              size: 80,
                              color: Color(0xFF007AFF),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: widget.isSettings ? 20 : 32),
                      Text(
                        LanguageService().translate('language.title'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LanguageService().translate('language.subtitle'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.8),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ..._languages.map((lang) {
                        final String code = lang['code'] ?? '';
                        final String name = lang['name'] ?? '';
                        final String asset = lang['asset'] ?? '';
                        final String emoji = lang['emoji'] ?? '';
                        final isSelected = _selectedLanguage == code;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedLanguage = code;
                                LanguageService().setLanguageImmediate(code);
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF007AFF)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? const Color(0xFF007AFF)
                                            .withOpacity(0.12)
                                        : Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey.withOpacity(0.1),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        asset,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Center(
                                          child: Text(
                                            emoji,
                                            style:
                                                const TextStyle(fontSize: 22),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF007AFF),
                                      size: 22,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton(
                onPressed: () async {
                  await LanguageService().setLanguage(_selectedLanguage);
                  if (widget.isSettings) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const OnboardingScreen()));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  widget.isSettings
                      ? LanguageService().translate('common.save')
                      : LanguageService().translate('language.continue'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
