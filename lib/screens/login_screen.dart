import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_usage/app_usage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/language_service.dart';
import '../services/firebase_service.dart';
import 'language_screen.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';
import 'legal_screen.dart';
import 'permissions_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscureText = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  
  bool _isLoading = false;
  bool _emailError = false;
  bool _passwordError = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    
    // Yozishni boshlaganda xatolikni yo'qotish
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
    _emailFocus.dispose();
    _passwordFocus.dispose();
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Edge-to-edge top header block
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
                  // Back Button
                  Visibility(
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    visible: true,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LanguageScreen()));
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.back,
                            color: Colors.black,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            LanguageService().translate('common.back'),
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LanguageService().translate('login.welcome'),
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.8,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      LanguageService().translate('login.subtitle'), 
                      softWrap: false,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withOpacity(0.7),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Rest of the login form content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    context,
                    hint: 'Username@gmail.com',
                    icon: CupertinoIcons.mail_solid,
                    focusNode: _emailFocus,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    isError: _emailError,
                  ),
                  const SizedBox(height: 14),

                  _buildLabel(context, LanguageService().translate('login.password_label')),
                  _buildTextField(
                    context,
                    hint: LanguageService().translate('login.password_hint'),
                    icon: CupertinoIcons.lock_fill,
                    focusNode: _passwordFocus,
                    controller: _passwordController,
                    isPassword: true,
                    obscureText: _obscureText,
                    isError: _passwordError,
                    onToggleVisibility: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        // Parolni tiklash dialogini chiqarish
                        _showForgotPasswordDialog(context);
                      },
                      child: Text(
                        LanguageService().translate('login.forgot_password') ?? 'Parolni unutdingizmi?',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF007AFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  Container(
                    height: 56,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007AFF).withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                      ],
                    ),
                    child: ElevatedButton(
                        onPressed: _isLoading ? null : () async {
                        // Validatsiya
                        setState(() {
                          _emailError = _emailController.text.trim().isEmpty;
                          _passwordError = _passwordController.text.trim().isEmpty;
                        });

                        if (_emailError || _passwordError) return;

                        setState(() => _isLoading = true);
                        try {
                          final result = await FirebaseService().signInWithEmail(
                            _emailController.text.trim(),
                            _passwordController.text.trim(),
                          );
                          
                          if (result != null && result.user != null) {
                            // Ismni olish
                            final userData = await FirebaseService().getUserData(result.user!.uid);
                            final String userName = userData?['name'] ?? result.user!.displayName ?? 'User';

                            if (!mounted) return;

                            // Tizimga kirganligini eslab qolish
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('is_logged_in', true);

                            // Ro'yxatdan o'tgan sanani saqlash
                            final registrationDate = await FirebaseService().getRegistrationDate(result.user!.uid);
                            if (registrationDate != null) {
                              await prefs.setString('registration_date', registrationDate.toIso8601String());
                            }
                            
                            // Xush kelibsiz xabari
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(LanguageService().translate('login.welcome_back').replaceAll('{name}', userName)),
                                backgroundColor: const Color(0xFF34C759),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );

                            // Har doim birinchi bo'lib Dashboardga o'tamiz
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _isLoading = false);
                            _showErrorMessage(e.toString());
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading 
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : Text(
                              LanguageService().translate('common.login'),
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.1,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Footer Actions
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            LanguageService().translate('login.no_account'),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.black.withOpacity(0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                            },
                            child: Text(
                              LanguageService().translate('login.register'),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF007AFF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Center(
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
                      const SizedBox(height: 24),
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

  void _showErrorMessage(String error) {
    String message;
    if (error.contains('user-not-found')) {
      message = LanguageService().translate('errors.user_not_found');
    } else if (error.contains('wrong-password') || error.contains('invalid-credential')) {
      message = LanguageService().translate('errors.wrong_password');
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
    TextInputType keyboardType = TextInputType.text,
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
        keyboardType: keyboardType,
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
                          ? Icons.visibility_off_rounded 
                          : Icons.visibility_rounded,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final TextEditingController resetEmailController = TextEditingController();
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          LanguageService().translate('login.forgot_password_title') ?? 'Parolni Tiklash',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              LanguageService().translate('login.forgot_password_desc') ?? 'Ro\'yxatdan o\'tgan pochtangizni kiriting. Biz sizga parolni yangilash havolasini yuboramiz.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: resetEmailController,
              placeholder: 'Email',
              keyboardType: TextInputType.emailAddress,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.extraLightBackgroundGray,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(
              LanguageService().translate('common.cancel') ?? 'Bekor qilish',
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(
              LanguageService().translate('common.continue') ?? 'Yuborish',
              style: const TextStyle(color: Color(0xFF007AFF)),
            ),
            onPressed: () async {
              final String email = resetEmailController.text.trim();
              if (email.isEmpty) return;
              
              // Navigator.pop dan oldin tekshiramiz
              try {
                // Email formatini tekshirish (ixtiyoriy lekin yaxshi)
                if (!email.contains('@')) {
                   _showErrorMessage('invalid-email');
                   return;
                }

                bool exists = await FirebaseService().checkEmailExists(email);
                
                if (!exists) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  _showErrorMessage('user-not-found');
                  return;
                }

                await FirebaseService().sendPasswordResetEmail(email);
                if (!mounted) return;
                Navigator.pop(context);
                _showSuccessDialog(context);
              } catch (e) {
                if (!mounted) return;
                _showErrorMessage(e.toString());
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Icon(Icons.check_circle, color: Color(0xFF34C759), size: 40),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            LanguageService().translate('login.reset_link_sent') ?? 'Havola Gmail pochtangizga yuborildi. Iltimos, pochtangizni tekshiring.',
            style: GoogleFonts.inter(),
          ),
        ),
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
