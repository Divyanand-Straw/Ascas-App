import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/otp_input.dart';
import '../data/models/auth_models.dart';
import '../data/repositories/auth_repository.dart';

class EmailPasswordSetupScreen extends StatefulWidget {
  final String initialEmail;
  final Future<SendEmailOtpResponse> Function(String email)? requestOtp;
  final Future<EmailActivationOtpVerificationResponse> Function(
    String challengeId,
    String email,
    String otp,
  )?
  verifyOtp;
  final Future<void> Function(String password)? setupPassword;

  const EmailPasswordSetupScreen({
    super.key,
    required this.initialEmail,
    this.requestOtp,
    this.verifyOtp,
    this.setupPassword,
  });

  @override
  State<EmailPasswordSetupScreen> createState() =>
      _EmailPasswordSetupScreenState();
}

class _EmailPasswordSetupScreenState extends State<EmailPasswordSetupScreen> {
  final _emailController = TextEditingController();
  final _otpInputKey = GlobalKey<OtpInputState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  Timer? _countdownTimer;
  String? _challengeId;
  String? _errorMessage;
  int _remainingSeconds = 0;
  bool _isLoading = false;
  bool _emailVerified = false;
  bool _setupComplete = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<SendEmailOtpResponse> _requestOtp(String email) =>
      widget.requestOtp?.call(email) ??
      AuthRepository.instance.sendEmailActivationOtp(email: email);

  Future<EmailActivationOtpVerificationResponse> _verifyOtp(
    String challengeId,
    String email,
    String otp,
  ) =>
      widget.verifyOtp?.call(challengeId, email, otp) ??
      AuthRepository.instance.verifyEmailActivationOtp(
        challengeId: challengeId,
        email: email,
        otp: otp,
      );

  Future<void> _setup(String password) =>
      widget.setupPassword?.call(password) ??
      AuthRepository.instance.setupPassword(password: password);

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() => _remainingSeconds = seconds < 0 ? 0 : seconds);
    if (_remainingSeconds == 0) return;
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

  Future<void> _sendOtp({bool resend = false}) async {
    if (_isLoading || (resend && _remainingSeconds > 0)) return;
    final email = normalizeEmail(_emailController.text);
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _errorMessage = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _requestOtp(email);
      if (!mounted) return;
      _otpInputKey.currentState?.clear();
      setState(() => _challengeId = response.challengeId);
      _startCountdown(response.retryAfterSeconds);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } on Exception {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to send an email code right now.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyEmail() async {
    if (_isLoading) return;
    final challengeId = _challengeId;
    final email = normalizeEmail(_emailController.text);
    final otp = _otpInputKey.currentState?.value ?? '';
    if (challengeId == null ||
        otp.length != 6 ||
        !RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      setState(() => _errorMessage = 'Enter the six-digit email code.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _verifyOtp(challengeId, email, otp);
      if (!mounted) return;
      setState(() => _emailVerified = true);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } on Exception {
      if (!mounted) return;
      setState(() => _errorMessage = 'Email verification failed.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setPassword() async {
    if (_isLoading) return;
    final password = _passwordController.text;
    if (password.length < 12 ||
        password.length > 128 ||
        utf8.encode(password).length > 72) {
      setState(
        () => _errorMessage =
            'Password must be 12-128 characters and at most 72 UTF-8 bytes.',
      );
      return;
    }
    if (password != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _setup(password);
      if (!mounted) return;
      setState(() => _setupComplete = true);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } on Exception {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to set up a password right now.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Optional email and password'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Mobile OTP registration remains available without email '
            'verification. This optional setup is only available to eligible '
            'new accounts.',
            style: TextStyle(color: AppColors.secondaryText, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('email-password-setup-email'),
            controller: _emailController,
            enabled: _challengeId == null && !_isLoading,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (!_emailVerified)
            _challengeId == null
                ? ElevatedButton(
                    key: const ValueKey('email-password-setup-send'),
                    onPressed: _isLoading ? null : () => _sendOtp(),
                    child: _loadingOrText('Send verification code'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OtpInput(
                        key: _otpInputKey,
                        fieldKeyPrefix: 'email-password-setup-otp',
                        fillColor: AppColors.white,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const ValueKey('email-password-setup-verify'),
                        onPressed: _isLoading ? null : _verifyEmail,
                        child: _loadingOrText('Verify email'),
                      ),
                      TextButton(
                        key: const ValueKey('email-password-setup-resend'),
                        onPressed: _isLoading || _remainingSeconds > 0
                            ? null
                            : () => _sendOtp(resend: true),
                        child: Text(
                          _remainingSeconds > 0
                              ? 'Resend in ${_remainingSeconds}s'
                              : 'Resend code',
                        ),
                      ),
                    ],
                  ),
          if (_emailVerified && !_setupComplete) ...[
            TextField(
              key: const ValueKey('email-password-setup-password'),
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (12+ characters)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('email-password-setup-confirm'),
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const ValueKey('email-password-setup-submit'),
              onPressed: _isLoading ? null : _setPassword,
              child: _loadingOrText('Set up password'),
            ),
          ],
          if (_setupComplete) ...[
            const Text(
              'Email and password setup is complete.',
              key: ValueKey('email-password-setup-success'),
              style: TextStyle(color: AppColors.success),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Return to registration'),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              key: const ValueKey('email-password-setup-error'),
              style: const TextStyle(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _loadingOrText(String text) => _isLoading
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Text(text);
}
