import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'forgot_password/forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showBackendPending() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(localizedText(context, 'No backend is integrated yet.')),
      ),
    );
  }

  Widget _buildSocialButton({
    required Widget icon,
    required String label,
  }) => Expanded(
    child: OutlinedButton(
      onPressed: _showBackendPending,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryText,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.divider),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 9),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
    prefixIcon: Icon(icon, color: AppColors.secondaryText),
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.burgundy, width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: screenHeight * 0.34,
                child: ClipPath(
                  clipper: LoginCurveClipper(),
                  child: Container(color: AppColors.burgundy),
                ),
              ),
              Column(
                children: [
                  SizedBox(
                    height: screenHeight * 0.32,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 95,
                            height: 95,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 15),
                        const LocalizedText(
                          'THAAI SEYAZHI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const LocalizedText(
                          'தாய் செயழி',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 18),
                        Text(
                          l10n.welcome,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const LocalizedText(
                          'Log in to continue your journey.',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.emailAddress,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: const ValueKey('login-email-field'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _fieldDecoration(
                            hint: l10n.enterEmailAddress,
                            icon: Icons.email_outlined,
                          ),
                          validator: (value) =>
                              RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                                  .hasMatch(value?.trim() ?? '')
                              ? null
                              : l10n.validEmailAddress,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.password,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const ValueKey('login-password-field'),
                          controller: _passwordController,
                          obscureText: true,
                          decoration: _fieldDecoration(
                            hint: l10n.enterPassword,
                            icon: Icons.lock_outline,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                            child: Text(
                              l10n.forgotPasswordQuestion,
                              style: const TextStyle(
                                color: AppColors.burgundy,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 53,
                          child: ElevatedButton(
                            onPressed: _showBackendPending,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.burgundy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              l10n.login,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Center(
                          child: Text(
                            l10n.orLoginWith,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _buildSocialButton(
                              icon: const FaIcon(
                                FontAwesomeIcons.google,
                                size: 17,
                              ),
                              label: 'Google',
                            ),
                            const SizedBox(width: 12),
                            _buildSocialButton(
                              icon: const FaIcon(
                                FontAwesomeIcons.apple,
                                size: 21,
                              ),
                              label: 'Apple',
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              Text(
                                l10n.noAccount,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                                child: Text(
                                  l10n.createAccount,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.burgundy,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 45);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 35,
      size.width,
      size.height - 45,
    );
    path
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
