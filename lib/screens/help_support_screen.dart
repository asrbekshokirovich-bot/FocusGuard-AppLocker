import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_translation_service.dart';

import '../services/language_service.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _expandedIndex;

  Future<void> _launchEmail() async {
    final String email = 'support@focusguard.com';
    final String subject = Uri.encodeComponent('Support Request - FocusGuard App');
    final String body = Uri.encodeComponent('\n\n---\nDevice Info: Web\nApp Version: 1.0.0');
    final Uri emailUrl = Uri.parse('mailto:$email?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(emailUrl)) {
        await launchUrl(emailUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $emailUrl';
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Xatolik'),
            content: const Text('Elektron pochta dasturini ochib bo\'lmadi. Iltimos, support@focusguard.com manzili orqali bog\'laning.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppTranslationService();
    return ValueListenableBuilder<String>(
      valueListenable: lang.languageNotifier,
      builder: (context, _, __) {
        final primaryColor = Theme.of(context).primaryColor;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black;
        final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
        final bgColor = isDark ? Colors.black : const Color(0xFFF2F2F7);

        final List faqs = lang.translate('help.faqs');

        return Scaffold(
          backgroundColor: bgColor,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(primaryColor, textColor, cardColor, lang),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(lang.translate('help.faq_title'), textColor),
                      const SizedBox(height: 16),
                      ...List.generate(faqs.length, (index) {
                        return _buildFAQTile(
                          index,
                          faqs[index]['q'],
                          faqs[index]['a'],
                          cardColor,
                          textColor,
                          primaryColor,
                        );
                      }),
                      const SizedBox(height: 40),
                      _buildSectionTitle(lang.translate('help.contact_title'), textColor),
                      const SizedBox(height: 16),
                      _buildContactCard(primaryColor, cardColor, textColor, lang),
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

  Widget _buildSliverAppBar(Color primaryColor, Color textColor, Color cardColor, AppTranslationService lang) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      stretch: true,
      backgroundColor: cardColor,
      elevation: 0,
      leading: CupertinoButton(
        onPressed: () => Navigator.pop(context),
        child: Icon(CupertinoIcons.back, color: textColor),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        centerTitle: false,
        title: Text(
          lang.translate('help.title'),
          style: LanguageService.getFont(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        background: Stack(
          children: [
            Positioned(
              right: -50,
              top: -20,
              child: Icon(
                CupertinoIcons.question_circle_fill,
                size: 200,
                color: primaryColor.withOpacity(0.05),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: LanguageService.getFont(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: textColor.withOpacity(0.4),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildFAQTile(int index, String question, String answer, Color cardColor, Color textColor, Color primaryColor) {
    final isExpanded = _expandedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isExpanded ? 0.05 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          question,
                          style: LanguageService.getFont(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 300),
                        turns: isExpanded ? 0.5 : 0,
                        child: Icon(
                          CupertinoIcons.chevron_down,
                          size: 18,
                          color: isExpanded ? primaryColor : textColor.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Text(
                      answer,
                      style: LanguageService.getFont(
                        fontSize: 14,
                        color: textColor.withOpacity(0.6),
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(Color primaryColor, Color cardColor, Color textColor, AppTranslationService lang) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _launchEmail,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(CupertinoIcons.mail_solid, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.translate('help.email_support'),
                        style: LanguageService.getFont(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lang.translate('help.email_desc'),
                        style: LanguageService.getFont(
                          fontSize: 13,
                          color: textColor.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(CupertinoIcons.chevron_right, size: 18, color: textColor.withOpacity(0.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
