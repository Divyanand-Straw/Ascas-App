import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';

import 'reset_password_screen.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/otp_input.dart';

class ForgotPasswordOtpScreen extends StatefulWidget {
  final String mobileNumber;
  final String emailAddress;
  final VoidCallback? onVerified;

  const ForgotPasswordOtpScreen({
    super.key,
    required this.mobileNumber,
    required this.emailAddress,
    this.onVerified,
  });

  @override
  State<ForgotPasswordOtpScreen> createState() =>
      _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  final _otpInputKey = GlobalKey<OtpInputState>();

  String get _enteredOtp => _otpInputKey.currentState?.value ?? '';

  void _verifyOtp() {
    if (_enteredOtp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText('Please enter the complete 6-digit OTP.'),
        ),
      );
      return;
    }

    if (widget.onVerified != null) {
      widget.onVerified!();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResetPasswordScreen(
          registeredMobile: widget.mobileNumber,
          registeredEmail: widget.emailAddress,
        ),
      ),
    );
  }

  Widget _buildOtpInput() {
    return OtpInput(
      key: _otpInputKey,
      fieldKeyPrefix: 'forgot-password-otp',
      boxWidth: 46,
      boxHeight: 55,
      textStyle: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      fillColor: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      borderColor: AppColors.divider,
      focusedBorderColor: AppColors.burgundy,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
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

              const SizedBox(height: 30),

              const LocalizedText(
                'STEP 2 OF 3',
                style: TextStyle(
                  color: AppColors.dustyPink,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),

              const SizedBox(height: 38),

              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.blushPink,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.sms_outlined,
                    color: AppColors.burgundy,
                    size: 38,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Center(
                child: LocalizedText(
                  'VERIFY OTP',
                  style: TextStyle(
                    color: AppColors.dustyPink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 13),

              const Center(
                child: LocalizedText(
                  'Enter verification code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              LocalizedText(
                'Verify the account for +91 ${widget.mobileNumber} and ${widget.emailAddress}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 38),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_buildOtpInput()],
              ),

              const SizedBox(height: 35),

              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.dustyPink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const LocalizedText(
                    'Verify & Continue',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
