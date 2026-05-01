import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import '../services/language_service.dart';
import 'dashboard_screen.dart';
import 'legal_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _termsAccepted = false;
  bool _obscurePassword = true;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _termsAccepted = false;
    _obscurePassword = true;

    _nameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Block
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 24,
                right: 24,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LanguageService().translate('register.title'),
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                      color: Colors.black,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LanguageService().translate('register.subtitle'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Name Field
                  _buildLabel(context, LanguageService().translate('register.name_label')),
                  _buildTextField(
                    context,
                    hint: LanguageService().translate('register.name_hint'),
                    icon: CupertinoIcons.person_fill,
                    focusNode: _nameFocus,
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  _buildLabel(context, LanguageService().translate('register.email_label')),
                  _buildTextField(
                    context,
                    hint: 'Username@gmail.com',
                    icon: CupertinoIcons.mail_solid,
                    focusNode: _emailFocus,
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  _buildLabel(context, LanguageService().translate('register.password_label')),
                  _buildTextField(
                    context,
                    hint: '••••••••',
                    icon: CupertinoIcons.lock_fill,
                    isPassword: true,
                    obscureText: _obscurePassword,
                    focusNode: _passwordFocus,
                    onToggleVisibility: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Register Button
                  Container(
                    width: double.infinity,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (_termsAccepted)
                          BoxShadow(
                            color: const Color(0xFF007AFF).withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _termsAccepted 
                          ? () {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _termsAccepted 
                            ? const Color(0xFF007AFF) 
                            : Colors.grey.shade200,
                        foregroundColor: _termsAccepted ? Colors.white : Colors.grey.shade400,
                        disabledBackgroundColor: Colors.grey.shade200,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        LanguageService().translate('register.title'),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                          color: _termsAccepted ? Colors.white : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Footer
                  Column(
                    children: [
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LegalScreen()));
                                },
                                child: Text(
                                  LanguageService().translate('login.terms'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.black.withOpacity(0.4),
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.black.withOpacity(0.2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CupertinoCheckbox(
                                value: _termsAccepted == true,
                                onChanged: (val) {
                                  setState(() {
                                    _termsAccepted = val ?? false;
                                  });
                                },
                                activeColor: const Color(0xFF007AFF),
                                checkColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.black.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              LanguageService().translate('register.have_account'),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.black.withOpacity(0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Text(
                                LanguageService().translate('register.login_now'),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF007AFF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.black.withOpacity(0.4),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
  }) {
    final bool isFocused = focusNode?.hasFocus ?? false;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused 
              ? const Color(0xFF007AFF).withOpacity(0.5) 
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isFocused 
                ? const Color(0xFF007AFF).withOpacity(0.12)
                : Colors.black.withOpacity(0.02),
            blurRadius: isFocused ? 12 : 8,
            offset: isFocused ? const Offset(0, 4) : const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        focusNode: focusNode,
        obscureText: obscureText,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: isFocused ? FontWeight.w600 : FontWeight.w500,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: Colors.black.withOpacity(isFocused ? 0.4 : 0.3),
            fontWeight: FontWeight.w400,
            fontSize: 13,
          ),
          prefixIcon: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isFocused ? 1.0 : 0.5,
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFF007AFF),
            ),
          ),
          suffixIcon: isPassword
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onToggleVisibility,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isFocused ? 1.0 : 0.4,
                    child: Icon(
                      obscureText
                          ? CupertinoIcons.eye_slash_fill
                          : CupertinoIcons.eye_fill,
                      size: 18,
                      color: Colors.black
                    ),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
