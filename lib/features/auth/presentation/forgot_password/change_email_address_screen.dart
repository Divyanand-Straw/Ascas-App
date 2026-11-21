import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/otp_input.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';

class ChangeEmailAddressScreen extends StatefulWidget {
  final String newEmail;
  final String initialMessage;
  final String initialChallengeId;
  final Future<void> Function() onVerified;
  final Future<SendEmailOtpResponse> Function(String email)? requestOtp;
  final Future<VerifyEmailOtpResponse> Function(
    String challengeId,
    String email,
    String otp,
  )?
  verifyOtp;

  const ChangeEmailAddressScreen({
    super.key,
    required this.newEmail,
    required this.initialMessage,
    required this.initialChallengeId,
    required this.onVerified,
    this.requestOtp,
    this.verifyOtp,
  });

  @override
  State<ChangeEmailAddressScreen> createState() =>
      _ChangeEmailAddressScreenState();
}

class _ChangeEmailAddressScreenState extends State<ChangeEmailAddressScreen> {
  final _otpInputKey = GlobalKey<OtpInputState>();
  Timer? _countdownTimer;
  int _remainingSeconds = 30;
  bool _isLoading = false;
  String? _errorMessage;
  late String _successMessage;
  late String _challengeId;

  @override
  void initState() {
    super.initState();
    _successMessage = widget.initialMessage;
    _challengeId = widget.initialChallengeId;
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
      final requestOtp =
          widget.requestOtp ??
          (String email) => AuthRepository.instance.sendEmailOtp(
            email: email,
            purpose: EmailOtpPurpose.emailChange,
          );
      final response = await requestOtp(widget.newEmail);
      if (!mounted) return;
      _otpInputKey.currentState?.clear();
      _challengeId = response.challengeId;
      setState(() => _successMessage = 'A verification code has been sent.');
      _startCountdown();
    } on StateError catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = localizedText(context, error.message.toString()),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = localizedText(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;
    final otp = _otpInputKey.currentState?.value ?? '';
    if (otp.length != 6 || !RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      setState(() => _errorMessage = 'Enter the six-digit OTP.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final verifyOtp =
          widget.verifyOtp ??
          (String challengeId, String email, String code) =>
              AuthRepository.instance.verifyEmailOtp(
                challengeId: challengeId,
                email: email,
                purpose: EmailOtpPurpose.emailChange,
                otp: code,
              );
      final result = await verifyOtp(_challengeId, widget.newEmail, otp);
      if (result is! EmailChangeOtpVerificationResponse ||
          result.email != normalizeEmail(widget.newEmail)) {
        throw StateError('The server did not verify this email address.');
      }
      await widget.onVerified();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('Email updated successfully')),
      );
      Navigator.pop(context, true);
    } on StateError catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = localizedText(context, error.message.toString()),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = localizedText(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
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
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const LocalizedText('Verify Email Address'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const LocalizedText(
            'Enter verification code',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const LocalizedText(
            'Enter the six-digit code sent to:',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 5),
          Text(
            widget.newEmail,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_successMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _successMessage,
              style: const TextStyle(color: AppColors.success, fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          OtpInput(
            key: _otpInputKey,
            fieldKeyPrefix: 'change-email-otp',
            fillColor: AppColors.white,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              localizedText(context, _errorMessage!),
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 53,
            child: ElevatedButton(
              key: const ValueKey('change-email-verify-otp'),
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                  : const LocalizedText('Verify OTP'),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _isLoading || _remainingSeconds > 0
                  ? null
                  : _resendOtp,
              child: _remainingSeconds > 0
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LocalizedText(
                          'Please wait before requesting another OTP',
                        ),
                        Text(' (${_remainingSeconds}s)'),
                      ],
                    )
                  : const LocalizedText('Resend OTP'),
            ),
          ),
        ],
      ),
    );
  }
}
