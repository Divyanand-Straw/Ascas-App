import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';

import 'package:flutter/services.dart';

import '../../../../core/widgets/step_progress_bar.dart';
import '../../../../core/theme/app_colors.dart';
import 'patient_details_screen.dart';
import '../existing_patient/clinic_record_access_screen.dart';

class NewPatientOtpScreen extends StatefulWidget {
  final String mobileNumber;
  final bool fromExistingPatient;

  const NewPatientOtpScreen({
    super.key,
    required this.mobileNumber,
    this.fromExistingPatient = false,
  });

  @override
  State<NewPatientOtpScreen> createState() => _NewPatientOtpScreenState();
}

class _NewPatientOtpScreenState extends State<NewPatientOtpScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

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

    for (final controller in _otpControllers) {
      controller.dispose();
    }

    for (final node in _focusNodes) {
      node.dispose();
    }

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

  String get _enteredOtp =>
      _otpControllers.map((controller) => controller.text).join();

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    setState(() {});
  }

  void _resendOtp() {
    if (!_canResend) return;

    for (final controller in _otpControllers) {
      controller.clear();
    }

    _focusNodes[0].requestFocus();
    _startCountdown();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: LocalizedText('A new verification code has been requested.'),
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

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => widget.fromExistingPatient
            ? ClinicRecordAccessScreen(mobileNumber: widget.mobileNumber)
            : PatientDetailsScreen(mobileNumber: widget.mobileNumber),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 48,
      height: 60,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          color: Colors.black,
          fontSize: 23,
          fontWeight: FontWeight.normal,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: AppColors.burgundy, width: 1.5),
          ),
        ),
        onChanged: (value) => _onOtpChanged(value, index),
      ),
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
                children: List.generate(6, (index) => _buildOtpBox(index)),
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
