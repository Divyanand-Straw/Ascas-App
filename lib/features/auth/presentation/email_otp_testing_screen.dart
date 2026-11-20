import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/email_otp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/otp_input.dart';

class EmailOtpTestingScreen extends StatefulWidget {
  final Future<String> Function(String email)? requestOtp;
  final Future<String> Function(String email, String otp)? verifyOtp;

  const EmailOtpTestingScreen({super.key, this.requestOtp, this.verifyOtp});

  @override
  State<EmailOtpTestingScreen> createState() => _EmailOtpTestingScreenState();
}

class _EmailOtpTestingScreenState extends State<EmailOtpTestingScreen> {
  final _emailController = TextEditingController();
  final _otpInputKey = GlobalKey<OtpInputState>();
  Timer? _resendTimer;
  String? _requestedEmail;
  String? _statusMessage;
  String? _errorMessage;
  int _resendSeconds = 0;
  bool _isLoading = false;
  bool _isVerified = false;

  bool get _isValidEmail =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
          .hasMatch(_emailController.text.trim());

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!_isValidEmail || _isLoading || _resendSeconds > 0) return;
    final email = _emailController.text.trim();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
      _isVerified = false;
    });

    try {
      final requestOtp = widget.requestOtp ?? EmailOtpService.requestOtp;
      final message = await requestOtp(email);
      if (!mounted) return;
      _otpInputKey.currentState?.clear();
      setState(() {
        _requestedEmail = email;
        _statusMessage = message;
      });
      _startResendCountdown();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;
    final otp = _otpInputKey.currentState?.value ?? '';
    if (otp.length != 6 || !RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      setState(() => _errorMessage = 'Enter the six-digit OTP.');
      return;
    }

    final email = _requestedEmail;
    if (email == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      final verifyOtp = widget.verifyOtp ?? EmailOtpService.verifyOtp;
      final message = await verifyOtp(email, otp);
      if (!mounted) return;
      setState(() {
        _isVerified = true;
        _statusMessage = message;
      });
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Email OTP Testing'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryText,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 56,
                color: AppColors.burgundy,
              ),
              const SizedBox(height: 16),
              const Text(
                'Send a real verification code through the configured email '
                'service, then verify it here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText, height: 1.5),
              ),
              const SizedBox(height: 28),
              TextField(
                key: const ValueKey('email-otp-testing-email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                onChanged: (_) => setState(() {
                  _errorMessage = null;
                }),
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              if (_emailController.text.isNotEmpty && !_isValidEmail) ...[
                const SizedBox(height: 8),
                const Text(
                  'Enter a valid email address.',
                  style: TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                key: const ValueKey('email-otp-testing-send'),
                onPressed: _isLoading || !_isValidEmail || _resendSeconds > 0
                    ? null
                    : _requestOtp,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _resendSeconds > 0
                            ? 'Resend OTP in ${_resendSeconds}s'
                            : _requestedEmail == null
                            ? 'Send OTP'
                            : 'Resend OTP',
                      ),
              ),
              if (_requestedEmail != null) ...[
                const SizedBox(height: 28),
                Text(
                  'Enter the six-digit OTP sent to $_requestedEmail',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.primaryText),
                ),
                const SizedBox(height: 16),
                OtpInput(
                  key: _otpInputKey,
                  fieldKeyPrefix: 'email-otp-testing-otp',
                  boxHeight: 54,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  key: const ValueKey('email-otp-testing-verify'),
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text('Verify OTP'),
                ),
              ],
              if (_statusMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _statusMessage!,
                  key: const ValueKey('email-otp-testing-status'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isVerified ? AppColors.success : AppColors.burgundy,
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  key: const ValueKey('email-otp-testing-error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
