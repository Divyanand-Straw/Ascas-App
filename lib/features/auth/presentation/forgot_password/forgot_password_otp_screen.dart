import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/otp_input.dart';
import 'reset_password_screen.dart';

class ForgotPasswordOtpScreen extends StatefulWidget {
  final String registeredMobile;
  final String emailAddress;
  final String initialMessage;
  final Future<String> Function(String email) requestOtp;
  final Future<String> Function(String email, String otp) verifyOtp;

  const ForgotPasswordOtpScreen({
    super.key,
    required this.registeredMobile,
    required this.emailAddress,
    required this.initialMessage,
    required this.requestOtp,
    required this.verifyOtp,
  });

  @override
  State<ForgotPasswordOtpScreen> createState() =>
      _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  final _otpInputKey = GlobalKey<OtpInputState>();
  Timer? _countdownTimer;
  int _remainingSeconds = 30;
  bool _isLoading = false;
  String? _errorMessage;
  late String _successMessage;

  String get _enteredOtp => _otpInputKey.currentState?.value ?? '';

  @override
  void initState() {
    super.initState();
    _successMessage = widget.initialMessage;
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _remainingSeconds = 30;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_isLoading || _remainingSeconds > 0) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = '';
    });
    try {
      final message = await widget.requestOtp(widget.emailAddress);
      if (!mounted) return;
      _otpInputKey.currentState?.clear();
      setState(() {
        _successMessage = message;
      });
      _startCountdown();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;
    if (_enteredOtp.length != 6 ||
        !RegExp(r'^[0-9]{6}$').hasMatch(_enteredOtp)) {
      setState(() => _errorMessage = 'Enter the six-digit OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.verifyOtp(widget.emailAddress, _enteredOtp);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ResetPasswordScreen(
            registeredMobile: widget.registeredMobile,
            registeredEmail: widget.emailAddress,
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

  Widget _buildOtpInput() => OtpInput(
    key: _otpInputKey,
    fieldKeyPrefix: 'forgot-password-otp',
    boxWidth: 48,
    boxHeight: 60,
    textStyle: const TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.bold,
      color: AppColors.primaryText,
    ),
    fillColor: AppColors.white,
    borderRadius: const BorderRadius.all(Radius.circular(12)),
    borderColor: AppColors.divider,
    focusedBorderColor: AppColors.burgundy,
    contentPadding: const EdgeInsets.symmetric(vertical: 14),
  );

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
              const SizedBox(height: 30),
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.blushPink,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    color: AppColors.burgundy,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              const Center(
                child: LocalizedText(
                  'Verify your email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: LocalizedText(
                  'Enter the six-digit code sent to:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Center(
                child: Text(
                  widget.emailAddress,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_successMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _successMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              _buildOtpInput(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.white,
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
                          'Verify OTP',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isLoading || _remainingSeconds > 0
                      ? null
                      : _resendOtp,
                  child: Text(
                    _remainingSeconds > 0
                        ? 'Resend OTP in ${_remainingSeconds}s'
                        : 'Resend OTP',
                    style: const TextStyle(
                      color: AppColors.burgundy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
