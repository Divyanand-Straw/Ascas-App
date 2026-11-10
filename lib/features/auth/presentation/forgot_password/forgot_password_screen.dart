import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'forgot_password_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool get _isValidMobile =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(_mobileController.text.trim());
  bool get _isValidEmail =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(_emailController.text.trim());

  @override
  void dispose() {
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_isValidMobile || !_isValidEmail) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordOtpScreen(
          mobileNumber: _mobileController.text.trim(),
          emailAddress: _emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 45),
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.blushPink,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.burgundy,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: LocalizedText(
                  'FORGOT PASSWORD',
                  style: TextStyle(
                    color: AppColors.dustyPink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Center(
                child: Text(
                  l10n.forgotPasswordTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.resetPasswordDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 38),
              Text(
                l10n.registeredMobileNumber,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('forgot-password-mobile-field'),
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: l10n.enterTenDigitMobile,
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    color: AppColors.secondaryText,
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(
                      color: AppColors.burgundy,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                l10n.registeredEmailAddress,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('forgot-password-email-field'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.enterRegisteredEmail,
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: AppColors.secondaryText,
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(
                      color: AppColors.burgundy,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  key: const ValueKey('forgot-password-continue'),
                  onPressed: _isValidMobile && _isValidEmail ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    disabledBackgroundColor: AppColors.dustyPink,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: Text(
                    l10n.continueText,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const LocalizedText(
                    'Back to login',
                    style: TextStyle(
                      color: AppColors.burgundy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
