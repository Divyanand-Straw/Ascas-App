import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';
import 'forgot_password_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final Future<SendEmailOtpResponse> Function(String phone, String email)?
  requestOtp;
  final Future<VerifyEmailOtpResponse> Function(
    String challengeId,
    String email,
    String otp,
  )?
  verifyOtp;

  const ForgotPasswordScreen({super.key, this.requestOtp, this.verifyOtp});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isValidEmail =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
          .hasMatch(_emailController.text.trim());

  bool get _isValidPhone {
    final phone = _phoneController.text
        .replaceAll(RegExp(r'[\s\-\(\)]'), '')
        .trim();
    return RegExp(r'^(?:[6-9]\d{9}|\+?[1-9]\d{9,14})$').hasMatch(phone);
  }

  bool get _isFormValid => _isValidPhone && _isValidEmail;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_isFormValid || _isLoading) return;
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final requestOtp =
          widget.requestOtp ??
          (phone, email) => AuthRepository.instance.sendPasswordResetOtp(
            phone: phone,
            email: email,
          );
      final response = await requestOtp(phone, email);
      final verifyOtp =
          widget.verifyOtp ??
          (challengeId, email, otp) => AuthRepository.instance.verifyEmailOtp(
            challengeId: challengeId,
            email: email,
            purpose: EmailOtpPurpose.passwordReset,
            otp: otp,
          );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForgotPasswordOtpScreen(
            mobileNumber: phone,
            emailAddress: email,
            initialMessage: 'If this email is eligible, an OTP has been sent.',
            initialChallengeId: response.challengeId,
            initialRetryAfterSeconds: response.retryAfterSeconds,
            requestOtp: requestOtp,
            verifyOtp: verifyOtp,
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              const SizedBox(height: 32),
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
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: l10n.registeredMobile,
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    color: AppColors.secondaryText,
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  errorText: _phoneController.text.isNotEmpty && !_isValidPhone
                      ? l10n.validMobileNumber
                      : null,
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
              const SizedBox(height: 20),
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
                autofillHints: const [AutofillHints.email],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: l10n.enterRegisteredEmail,
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: AppColors.secondaryText,
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  errorText: _emailController.text.isNotEmpty && !_isValidEmail
                      ? l10n.validEmailAddress
                      : null,
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
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  key: const ValueKey('forgot-password-send-otp'),
                  onPressed: _isFormValid && !_isLoading ? _sendOtp : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    disabledBackgroundColor: AppColors.dustyPink,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const LocalizedText(
                          'Send Verification',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
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
