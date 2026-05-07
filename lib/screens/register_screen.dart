import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/language_service.dart';
import '../services/firebase_service.dart';
import 'dashboard_screen.dart';
import 'legal_screen.dart';
import 'permissions_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _termsAccepted = false;
  bool _obscurePassword = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  
  bool _isLoading = false;
  bool _nameError = false;
  bool _emailError = false;
  bool _passwordError = false;

  @override
  void initState() {
    super.initState();
    _termsAccepted = false;
    _obscurePassword = true;

    _nameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));

    // Yozishni boshlaganda xatolikni yo'qotish
    _nameController.addListener(() {
      if (_nameError && _nameController.text.isNotEmpty) {
        setState(() => _nameError = false);
      }
    });
    _emailController.addListener(() {
      if (_emailError && _emailController.text.isNotEmpty) {
        setState(() => _emailError = false);
      }
    });
    _passwordController.addListener(() {
      if (_passwordError && _passwordController.text.isNotEmpty) {
        setState(() => _passwordError = false);
      }
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
                top: MediaQuery.of(context).padding.top + 40,
                left: 24,
                right: 24,
                bottom: 24,
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
                      fontSize: 32,
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
                      fontSize: 14,
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
                    controller: _nameController,
                    isError: _nameError,
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  _buildLabel(context, LanguageService().translate('register.email_label')),
                  _buildTextField(
                    context,
                    hint: 'Username@gmail.com',
                    icon: CupertinoIcons.mail_solid,
                    focusNode: _emailFocus,
                    controller: _emailController,
                    isError: _emailError,
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
                    controller: _passwordController,
                    isError: _passwordError,
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
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
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
                      onPressed: (_termsAccepted && !_isLoading)
                          ? () async {
                              // Validatsiya
                              setState(() {
                                _nameError = _nameController.text.trim().isEmpty;
                                _emailError = _emailController.text.trim().isEmpty;
                                _passwordError = _passwordController.text.trim().isEmpty;
                              });

                              if (_nameError || _emailError || _passwordError) return;

                              setState(() => _isLoading = true);
                              try {
                                await FirebaseService().registerWithEmail(
                                  _nameController.text.trim(),
                                  _emailController.text.trim(),
                                  _passwordController.text.trim(),
                                );
                                
                                if (!mounted) return;
                                
                                // Xush kelibsiz xabari
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("${LanguageService().translate('register.welcome_new').replaceAll('{name}', _nameController.text.trim())}. ${LanguageService().translate('register.check_spam') ?? 'Pochtangizning spam papkasini ham tekshiring.'}"),
                                    backgroundColor: const Color(0xFF34C759),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );

                                // Sessiyani saqlash
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('is_logged_in', true);

                                // Dashboard oynasiga o'tish
                                if (mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context, 
                                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                                    (route) => false,
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                  _showErrorMessage(e.toString());
                                }
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
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
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading 
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : Text(
                              LanguageService().translate('register.title'),
                              style: GoogleFonts.inter(
                                fontSize: 18,
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
                                    fontSize: 13,
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
                              width: 26,
                              height: 26,
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
                                fontSize: 15,
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
                                  fontSize: 15,
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
          fontSize: 12,
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
    TextEditingController? controller,
    bool isPassword = false,
    bool obscureText = false,
    bool isError = false,
    VoidCallback? onToggleVisibility,
  }) {
    final bool isFocused = focusNode?.hasFocus ?? false;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isError 
              ? const Color(0xFFFF3B30)
              : isFocused 
                  ? const Color(0xFF007AFF).withOpacity(0.5) 
                  : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isError
                ? const Color(0xFFFF3B30).withOpacity(0.1)
                : isFocused 
                    ? const Color(0xFF007AFF).withOpacity(0.12)
                    : Colors.black.withOpacity(0.02),
            blurRadius: isFocused ? 12 : 8,
            offset: isFocused ? const Offset(0, 4) : const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        focusNode: focusNode,
        controller: controller,
        obscureText: obscureText,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: isFocused ? FontWeight.w600 : FontWeight.w500,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: Colors.black.withOpacity(isFocused ? 0.4 : 0.3),
            fontWeight: FontWeight.w400,
            fontSize: 15,
          ),
          prefixIcon: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isFocused ? 1.0 : 0.5,
            child: Icon(
              icon,
              size: 22,
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
                      size: 22,
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

  void _showErrorMessage(String error) {
    String message;
    if (error.contains('email-already-in-use')) {
      message = LanguageService().translate('errors.email_already_in_use');
    } else if (error.contains('weak-password')) {
      message = LanguageService().translate('errors.weak_password');
    } else if (error.contains('invalid-email')) {
      message = LanguageService().translate('errors.invalid_email');
    } else if (error.contains('network-request-failed')) {
      message = LanguageService().translate('errors.network_error');
    } else {
      message = LanguageService().translate('errors.unknown_error');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(CupertinoIcons.exclamationmark_circle_fill, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
