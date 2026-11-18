import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/step_progress_bar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dashboard/presentation/dashboard_screen.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';
import 'patient_details_screen.dart';
import '../existing_patient/clinic_record_access_screen.dart';

class NewPatientOtpScreen extends StatefulWidget {
  final String mobileNumber;
  final String? challengeId;
  final int initialCountdownSeconds;
  final OtpPurpose purpose;
  final bool fromExistingPatient;

  const NewPatientOtpScreen({
    super.key,
    required this.mobileNumber,
    this.challengeId,
    this.initialCountdownSeconds = 45,
    this.purpose = OtpPurpose.registration,
    this.fromExistingPatient = false,
  });

  @override
  State<NewPatientOtpScreen> createState() => _NewPatientOtpScreenState();
}

class _NewPatientOtpScreenState extends State<NewPatientOtpScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());

  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

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

    for (final controller in _otpControllers) {
      controller.dispose();
    }

    for (final node in _focusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  Future<void> _requestInitialOtp() async {
    try {
      final res = await AuthRepository.instance.sendOtp(
        phone: widget.mobileNumber,
        purpose: widget.purpose,
      );
      if (mounted) {
        setState(() {
          _currentChallengeId = res.challengeId;
          _remainingSeconds = res.retryAfterSeconds;
        });
        _startCountdown();
      }
    } catch (_) {}
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

  Future<void> _resendOtp() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final res = await AuthRepository.instance.sendOtp(
        phone: widget.mobileNumber,
        purpose: widget.purpose,
      );

      for (final controller in _otpControllers) {
        controller.clear();
      }

      _focusNodes[0].requestFocus();

      setState(() {
        _currentChallengeId = res.challengeId;
        _remainingSeconds = res.retryAfterSeconds;
        _remainingAttempts = null;
      });

      _startCountdown();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new verification code has been dispatched to your mobile.'),
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend code: $e')),
      );
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
        const SnackBar(
          content: Text('Please enter the full 6-digit verification code.'),
        ),
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
        purpose: widget.purpose,
        otp: otp,
      );

      _timer?.cancel();

      if (!mounted) return;

      if (session.hasCompletedProfile && session.profile != null) {
        // Patient has existing profile -> navigate to Dashboard
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
        // Patient requires initial profile onboarding
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => widget.fromExistingPatient
                ? ClinicRecordAccessScreen(
                    mobileNumber: widget.mobileNumber,
                  )
                : PatientDetailsScreen(
                    mobileNumber: widget.mobileNumber,
                  ),
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
              'Maximum attempts exceeded. Please request a new verification code.',
            ),
          ),
        );
      } else if (e.errorCode == 'OTP_EXPIRED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code has expired. Please request a new one.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
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
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
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
            borderSide: const BorderSide(
              color: AppColors.burgundy,
              width: 1.5,
            ),
          ),
        ),
        onChanged: (value) => _onOtpChanged(value, index),
      ),
    );
  }

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
                        Text(
                          'STEP 3 OF 8',
                          style: TextStyle(
                            color: AppColors.dustyPink,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Verification',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 12),
              const StepProgressBar(currentStep: 3, totalSteps: 8),
              const SizedBox(height: 24),
              const Text(
                'Verify Phone Number',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We have sent a 6-digit verification code to $_maskedMobileNumber',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildOtpBox(index)),
              ),
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
                      disabledForegroundColor:
                          AppColors.secondaryText.withValues(alpha: 0.5),
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
                height: 50,
                child: ElevatedButton(
                  onPressed: isLockedOut || _isVerifying ? null : _verifyOtp,
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Verify Code'),
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
