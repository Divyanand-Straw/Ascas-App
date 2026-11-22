import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/otp_input.dart';
import '../data/models/auth_models.dart';
import '../data/repositories/auth_repository.dart';

enum _DeveloperEmailOtpWaitReason { resend, hourlyLimit, providerLimit }

class DeveloperEmailOtpTestingScreen extends StatefulWidget {
  final Future<SendEmailOtpResponse> Function(String email)? requestOtp;
  final Future<DeveloperEmailTestOtpVerificationResponse> Function(
    String challengeId,
    String email,
    String otp,
  )?
  verifyOtp;
  final DateTime Function()? currentTime;

  const DeveloperEmailOtpTestingScreen({
    super.key,
    this.requestOtp,
    this.verifyOtp,
    this.currentTime,
  });

  @override
  State<DeveloperEmailOtpTestingScreen> createState() =>
      _DeveloperEmailOtpTestingScreenState();
}

class _DeveloperEmailOtpTestingScreenState
    extends State<DeveloperEmailOtpTestingScreen> {
  final _emailController = TextEditingController();
  final _otpInputKey = GlobalKey<OtpInputState>();
  Timer? _countdownTimer;
  String? _challengeId;
  String? _errorMessage;
  DateTime? _resendAvailableAt;
  DateTime? _otpExpiresAt;
  int _remainingSeconds = 0;
  int _otpRemainingSeconds = 0;
  _DeveloperEmailOtpWaitReason _waitReason =
      _DeveloperEmailOtpWaitReason.resend;
  bool _isLoading = false;
  bool _isVerified = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<SendEmailOtpResponse> _request(String email) =>
      widget.requestOtp?.call(email) ??
      AuthRepository.instance.sendDeveloperEmailTestOtp(email: email);

  Future<DeveloperEmailTestOtpVerificationResponse> _verify(
    String challengeId,
    String email,
    String otp,
  ) =>
      widget.verifyOtp?.call(challengeId, email, otp) ??
      AuthRepository.instance.verifyDeveloperEmailTestOtp(
        challengeId: challengeId,
        email: email,
        otp: otp,
      );

  String _formatWaitDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes == 0) return '${seconds}s';
    if (remainingSeconds == 0) return '${minutes}m';
    return '${minutes}m ${remainingSeconds}s';
  }

  String _countdownLabel(bool hasChallenge) {
    final wait = _formatWaitDuration(_remainingSeconds);
    switch (_waitReason) {
      case _DeveloperEmailOtpWaitReason.hourlyLimit:
        return 'Hourly limit: $wait';
      case _DeveloperEmailOtpWaitReason.providerLimit:
        return 'Provider wait: $wait';
      case _DeveloperEmailOtpWaitReason.resend:
        return hasChallenge ? 'Resend in $wait' : 'Try again in $wait';
    }
  }

  String _apiErrorMessage(ApiError error) {
    if (error.errorCode == 'EMAIL_OTP_RATE_LIMITED') {
      return 'The hourly Developer Email OTP limit has been reached. This '
          'security limit is separate from the normal 30-second resend cooldown.';
    }
    if (error.errorCode == 'BREVO_RATE_LIMITED') {
      final details = error.details;
      final providerRetryAfterSeconds = details is Map
          ? details['providerRetryAfterSeconds']
          : null;
      if (providerRetryAfterSeconds is int && providerRetryAfterSeconds > 30) {
        return 'Brevo rate-limited delivery and requested a '
            '${_formatWaitDuration(providerRetryAfterSeconds)} wait. This '
            'provider limit is separate from the normal 30-second resend cooldown.';
      }
      return 'Brevo rate-limited delivery. No longer provider wait was '
          'provided; the normal 30-second resend cooldown still applies. '
          'Avoid repeated retries.';
    }
    return error.message;
  }

  void _startCountdown(int seconds) {
    _resendAvailableAt = seconds > 0
        ? _currentTime.add(Duration(seconds: seconds))
        : null;
    _refreshCountdown();
  }

  void _startOtpExpiryCountdown(int seconds) {
    _otpExpiresAt = seconds > 0
        ? _currentTime.add(Duration(seconds: seconds))
        : null;
    _refreshCountdown();
  }

  int _secondsUntil(DateTime? deadline) {
    if (deadline == null) return 0;
    final milliseconds = deadline.difference(_currentTime).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
  }

  DateTime get _currentTime => widget.currentTime?.call() ?? DateTime.now();

  void _refreshCountdown() {
    if (!mounted) return;
    final resendSeconds = _secondsUntil(_resendAvailableAt);
    final otpSeconds = _secondsUntil(_otpExpiresAt);
    if (resendSeconds != _remainingSeconds ||
        otpSeconds != _otpRemainingSeconds) {
      setState(() {
        _remainingSeconds = resendSeconds;
        _otpRemainingSeconds = otpSeconds;
      });
    }

    if (resendSeconds == 0 && otpSeconds == 0) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    } else {
      _countdownTimer ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => _refreshCountdown(),
      );
    }
  }

  Future<void> _sendOtp() async {
    if (_isLoading || _remainingSeconds > 0) return;
    final email = normalizeEmail(_emailController.text);
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _errorMessage = 'Enter a valid test email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _request(email);
      if (!mounted) return;
      _otpInputKey.currentState?.clear();
      setState(() {
        _challengeId = response.challengeId;
        _isVerified = false;
        _waitReason = _DeveloperEmailOtpWaitReason.resend;
      });
      _startCountdown(response.retryAfterSeconds);
      _startOtpExpiryCountdown(response.expiresInSeconds);
    } on ApiError catch (error) {
      if (!mounted) return;
      final retryAfterSeconds = error.retryAfterSeconds;
      setState(() {
        _errorMessage = _apiErrorMessage(error);
        _waitReason = switch (error.errorCode) {
          'EMAIL_OTP_RATE_LIMITED' => _DeveloperEmailOtpWaitReason.hourlyLimit,
          'BREVO_RATE_LIMITED' =>
            error.details is Map &&
                    error.details['providerRetryAfterSeconds'] is int &&
                    error.details['providerRetryAfterSeconds'] > 30
                ? _DeveloperEmailOtpWaitReason.providerLimit
                : _DeveloperEmailOtpWaitReason.resend,
          _ => _DeveloperEmailOtpWaitReason.resend,
        };
      });
      if (retryAfterSeconds != null && retryAfterSeconds > 0) {
        _startCountdown(retryAfterSeconds);
      }
    } on Exception {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Unable to request an email code right now.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
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
      await _verify(challengeId, email, otp);
      if (!mounted) return;
      setState(() {
        _isVerified = true;
        _otpExpiresAt = null;
        _otpRemainingSeconds = 0;
      });
      _refreshCountdown();
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } on Exception {
      if (!mounted) return;
      setState(() => _errorMessage = 'Email code verification failed.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasChallenge = _challengeId != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Staging Email Delivery Test'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Developer-only test: send and verify a Brevo email OTP '
            'without a patient account. It does not create an account, change '
            'a password, or verify an email. The OTP is never shown in the app.',
            style: TextStyle(color: AppColors.secondaryText, height: 1.5),
            key: ValueKey('developer-email-otp-eligibility'),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('developer-email-otp-email'),
            controller: _emailController,
            enabled: !hasChallenge && !_isLoading,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Test recipient email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (!hasChallenge)
            ElevatedButton(
              key: const ValueKey('developer-email-otp-send'),
              onPressed: _isLoading || _remainingSeconds > 0 ? null : _sendOtp,
              child: _remainingSeconds > 0
                  ? Text(_countdownLabel(false))
                  : _loadingOrText('Send Test OTP'),
            )
          else ...[
            Text(
              'Brevo accepted the send request. Check the inbox; acceptance '
              'does not guarantee delivery.',
            ),
            const SizedBox(height: 8),
            Text(
              _isVerified
                  ? 'This code has been verified and cannot be reused.'
                  : _otpRemainingSeconds > 0
                  ? 'This code expires in '
                        '${_formatWaitDuration(_otpRemainingSeconds)}.'
                  : 'This code has expired. Request a new OTP.',
              key: const ValueKey('developer-email-otp-expiry'),
            ),
            const SizedBox(height: 16),
            OtpInput(
              key: _otpInputKey,
              fieldKeyPrefix: 'developer-email-otp-code',
              fillColor: AppColors.white,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const ValueKey('developer-email-otp-verify'),
              onPressed: _isLoading || _isVerified ? null : _verifyOtp,
              child: _loadingOrText('Verify OTP'),
            ),
            TextButton(
              key: const ValueKey('developer-email-otp-resend'),
              onPressed: _isLoading || _remainingSeconds > 0 ? null : _sendOtp,
              child: Text(
                _remainingSeconds > 0 ? _countdownLabel(true) : 'Resend OTP',
              ),
            ),
          ],
          if (_isVerified)
            const Text(
              'Test email OTP verified successfully.',
              key: ValueKey('developer-email-otp-success'),
              style: TextStyle(color: AppColors.success),
            ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              key: const ValueKey('developer-email-otp-error'),
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
