import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/localized_text.dart';

import 'clinic_record_access_screen.dart';
import '../../../../core/widgets/step_progress_bar.dart';
import '../../../../core/widgets/otp_input.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dashboard/presentation/dashboard_screen.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String mobileNumber;
  final String? challengeId;
  final int initialCountdownSeconds;
  final bool fromExistingPatient;

  const OtpVerificationScreen({
    super.key,
    required this.mobileNumber,
    this.challengeId,
    this.initialCountdownSeconds = 45,
    this.fromExistingPatient = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpInputKey = GlobalKey<OtpInputState>();

  Timer? _timer;
  late int _remainingSeconds;
  bool _canResend = false;
  bool _isVerifying = false;
  bool _isResending = false;

  late String _currentChallengeId;
  int? _remainingAttempts;

  @override
  void initState() {
    super.initState();
    _currentChallengeId = widget.challengeId ?? '';
    _remainingSeconds = widget.initialCountdownSeconds;
    _startCountdown();

    if (_currentChallengeId.isEmpty) {
      _requestInitialOtp();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  Future<void> _requestInitialOtp() async {
    try {
      final res = await AuthRepository.instance.sendOtp(
        phone: widget.mobileNumber,
        purpose: OtpPurpose.login,
      );
      if (!mounted) return;
      setState(() {
        _currentChallengeId = res.challengeId;
        _remainingSeconds = res.retryAfterSeconds;
      });
      _startCountdown();
    } on ApiError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to request verification code: $error')),
      );
    }
  }

  void _startCountdown() {
    _timer?.cancel();

    setState(() {
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

  Future<void> _resendOtp() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final res = await AuthRepository.instance.sendOtp(
        phone: widget.mobileNumber,
        purpose: OtpPurpose.login,
      );

      if (!mounted) return;
      _otpInputKey.currentState?.clear();

      setState(() {
        _currentChallengeId = res.challengeId;
        _remainingSeconds = res.retryAfterSeconds;
        _remainingAttempts = null;
      });

      _startCountdown();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new verification code has been dispatched.'),
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to resend code: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _enteredOtp.trim();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('Please enter the 6-digit OTP.')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final session = await AuthRepository.instance.verifyOtp(
        challengeId: _currentChallengeId,
        phone: widget.mobileNumber,
        purpose: OtpPurpose.login,
        otp: otp,
      );

      _timer?.cancel();

      if (!mounted) return;

      if (session.hasCompletedProfile && session.profile != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              patientName: session.profile!.fullName,
              mobileNumber: widget.mobileNumber,
              dateOfBirth: session.profile!.dob ?? '',
              preferredLanguage: session.profile!.preferredLanguage,
              accountId: session.user.id,
            ),
          ),
          (route) => false,
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ClinicRecordAccessScreen(mobileNumber: widget.mobileNumber),
          ),
        );
      }
    } on ApiError catch (e) {
      if (!mounted) return;

      if (e.errorCode == 'INVALID_OTP') {
        setState(() {
          _remainingAttempts = e.remainingAttempts;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.remainingAttempts != null
                  ? 'Incorrect verification code. ${e.remainingAttempts} attempt(s) remaining.'
                  : 'Incorrect verification code. Please try again.',
            ),
          ),
        );
      } else if (e.errorCode == 'MAX_ATTEMPTS_EXCEEDED') {
        setState(() {
          _remainingAttempts = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Maximum attempts exceeded. Please request a new code.',
            ),
          ),
        );
      } else if (e.errorCode == 'OTP_EXPIRED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification code expired. Please request a new one.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Verification failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Widget _buildOtpInput() => OtpInput(
    key: _otpInputKey,
    boxWidth: 54,
    boxHeight: 68,
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

  @override
  Widget build(BuildContext context) {
    final isLockedOut = _remainingAttempts == 0;

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
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 4),
                        LocalizedText(
                          'OTP verification',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
                  const SizedBox(width: 24),
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
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit verification code sent to $_maskedMobileNumber',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 35),
              _buildOtpInput(),
              const SizedBox(height: 35),
              if (_remainingAttempts != null && _remainingAttempts! > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '$_remainingAttempts attempt(s) remaining',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formattedTime,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: _canResend && !_isResending ? _resendOtp : null,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.burgundy,
                      disabledForegroundColor: AppColors.secondaryText
                          .withValues(alpha: 0.5),
                    ),
                    child: _isResending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Resend Code',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLockedOut || _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Verify and proceed'),
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
