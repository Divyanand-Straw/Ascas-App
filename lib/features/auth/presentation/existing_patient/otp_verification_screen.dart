import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';

import 'clinic_record_access_screen.dart';
import '../../../../core/widgets/step_progress_bar.dart';
import '../../../../core/widgets/otp_input.dart';
import '../../../../core/theme/app_colors.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String mobileNumber;
  final bool fromExistingPatient;

  const OtpVerificationScreen({
    super.key,
    required this.mobileNumber,
    this.fromExistingPatient = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpInputKey = GlobalKey<OtpInputState>();

  Timer? _timer;

  int _remainingSeconds = 42;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();

    setState(() {
      _remainingSeconds = 42;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();

        setState(() {
          _canResend = true;
        });
      }
    });
  }

  String get _maskedMobileNumber {
    if (widget.mobileNumber.length != 10) {
      return widget.mobileNumber;
    }

    return '•••••• ${widget.mobileNumber.substring(6)}';
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');

    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  String get _enteredOtp => _otpInputKey.currentState?.value ?? '';

  void _resendOtp() {
    if (!_canResend) return;

    _otpInputKey.currentState?.clear();
    _startCountdown();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: LocalizedText('OTP resend is a prototype action.'),
      ),
    );
  }

  void _verifyOtp() {
    final otp = _enteredOtp;

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('Please enter the 6-digit OTP.')),
      );
      return;
    }

    if (otp != '123456') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText('Incorrect OTP. Please try again.'),
        ),
      );
      return;
    }

    _timer?.cancel();

    if (widget.fromExistingPatient) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ClinicRecordAccessScreen(mobileNumber: widget.mobileNumber),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ClinicRecordAccessScreen(mobileNumber: widget.mobileNumber),
        ),
      );
    }
  }

  Widget _buildOtpInput() {
    return OtpInput(
      key: _otpInputKey,
      boxWidth: 50,
      boxHeight: 64,
      textStyle: const TextStyle(
        color: Colors.black,
        fontSize: 23,
        fontWeight: FontWeight.normal,
      ),
      fillColor: AppColors.white,
      borderRadius: const BorderRadius.all(Radius.circular(11)),
      borderColor: AppColors.divider,
      focusedBorderColor: AppColors.burgundy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left),
                    color: AppColors.primaryText,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        LocalizedText(
                          'STEP 3 OF 8',
                          style: TextStyle(
                            color: AppColors.dustyPink,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        LocalizedText(
                          'OTP verification',
                          style: TextStyle(
                            color: AppColors.burgundy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    child: const LocalizedText(
                      'Exit',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              const Divider(color: AppColors.divider, height: 1),

              const SizedBox(height: 16),

              const StepProgressBar(currentStep: 3),

              const SizedBox(height: 35),

              const LocalizedText(
                'OTP VERIFICATION',
                style: TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),

              const SizedBox(height: 14),

              const LocalizedText(
                'Enter the 6-digit code',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 25,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'Sent to +91 '),
                    TextSpan(
                      text: _maskedMobileNumber,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [_buildOtpInput()],
              ),

              const SizedBox(height: 35),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const LocalizedText(
                    'Verify OTP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Center(
                child: _canResend
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const LocalizedText(
                            'Didn’t receive the code?',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                          TextButton(
                            onPressed: _resendOtp,
                            child: const LocalizedText(
                              'Resend OTP',
                              style: TextStyle(
                                color: AppColors.burgundy,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      )
                    : LocalizedText(
                        'Resend OTP in $_formattedTime',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
