import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/language_service.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      "title": LanguageService().translate('onboarding.0.title'),
      "text": LanguageService().translate('onboarding.0.text'),
      "icon": CupertinoIcons.sparkles
    },
    {
      "title": LanguageService().translate('onboarding.1.title'),
      "text": LanguageService().translate('onboarding.1.text'),
      "icon": CupertinoIcons.lock_shield_fill
    },
    {
      "title": LanguageService().translate('onboarding.2.title'),
      "text": LanguageService().translate('onboarding.2.text'),
      "icon": CupertinoIcons.chart_pie_fill
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) {
                  setState(() {
                    _currentPage = value;
                  });
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              _onboardingData[index]["icon"] as IconData,
                              size: 110,
                              color: const Color(0xFF007AFF),
                            ),
                          ),
                        ),
                        const SizedBox(height: 50),
                        Text(
                          _onboardingData[index]["title"] as String,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _onboardingData[index]["text"] as String,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.8), height: 1.5, letterSpacing: 0),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _onboardingData.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 8),
                  height: 8,
                  width: _currentPage == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? const Color(0xFF007AFF) : const Color(0xFFD1D1D6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton(
                onPressed: () {
                  if (_currentPage == _onboardingData.length - 1) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                  } else {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 2,
                ),
                child: Text(
                  _currentPage == _onboardingData.length - 1 
                    ? LanguageService().translate('common.login') 
                    : LanguageService().translate('common.continue'),
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2),
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
